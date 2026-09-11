"""Livreur : disponibilite, offres, positions, gains.

Le fil conducteur de ce fichier est le **hors ligne**. Un livreur d'Antananarivo
passe une partie de sa journee sans reseau : il accepte une course dans une rue
couverte, l'execute dans une zone qui ne l'est pas, et tout remonte a la
reconnexion. Les routes sont donc concues pour recevoir des paquets tardifs,
desordonnes et parfois doubles, sans jamais compter deux fois.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.deps import current_account, require_role
from app.core.errors import forbidden, unprocessable
from app.core.geo import MAX_ACCEPT_KM, haversine_km, point_of
from app.db import get_db
from app.models import (
    DELIVERED_STATES,
    VEHICLE_TYPES,
    Account,
    Delivery,
    DeliveryStatus,
    DriverState,
    DriverVehicle,
    KycStatus,
    PositionSample,
    UserRole,
    as_utc,
)

router = APIRouter(prefix="/driver", tags=["driver"])

# Au-dela de cet age, une position ne dit plus ou est le livreur, seulement ou
# il etait. L'exploitation doit voir la difference (EXI-A02).
POSITION_FRESHNESS = timedelta(minutes=3)


class OnlineToggle(BaseModel):
    online: bool


class PositionIn(BaseModel):
    lat: float
    lng: float
    accuracyM: float | None = None
    fixedAt: datetime
    deliveryId: int | None = None


class PositionBatch(BaseModel):
    # Un paquet, pas un point : envoyer chaque position separement sur 2G
    # couterait plus en entetes qu'en donnees utiles.
    samples: list[PositionIn] = Field(default_factory=list)


def _state(db: Session, account: Account) -> DriverState:
    state = db.get(DriverState, account.id)
    if state is None:
        state = DriverState(account_id=account.id)
        db.add(state)
        db.commit()
    return state


class VehicleBody(BaseModel):
    type: str = "moto"
    brand: str | None = None
    model: str | None = None
    plate: str | None = None
    insuranceExpiry: str | None = None


@router.get("/vehicle")
async def read_vehicle(
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Fiche vehicule du livreur (§22). Vide tant qu'il n'a rien renseigne."""
    vehicle = db.get(DriverVehicle, account.id)
    if vehicle is None:
        return {"type": None, "validation": "pending"}
    return vehicle.to_json()


@router.patch("/vehicle")
async def upsert_vehicle(
    body: VehicleBody,
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Cree ou met a jour la fiche. Toute modification remet la validation en
    attente : une fiche changee n'est plus celle que l'exploitation avait vue."""
    if body.type not in VEHICLE_TYPES:
        raise unprocessable("invalid_type", "Type de vehicule inconnu")

    vehicle = db.get(DriverVehicle, account.id)
    if vehicle is None:
        vehicle = DriverVehicle(account_id=account.id)
        db.add(vehicle)

    vehicle.vehicle_type = body.type
    vehicle.brand = (body.brand or "").strip() or None
    vehicle.model = (body.model or "").strip() or None
    vehicle.plate = (body.plate or "").strip() or None
    vehicle.insurance_expiry = (body.insuranceExpiry or "").strip() or None
    vehicle.validation = "pending"
    vehicle.updated_at = datetime.now(timezone.utc)
    db.commit()
    return vehicle.to_json()


@router.post("/status")
async def set_online(
    body: OnlineToggle,
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    # Un livreur ne peut pas travailler tant que son dossier n'est pas valide
    # (EXI-L01). Le refus est porte ici, au seul endroit ou l'on passe en ligne,
    # plutot que replique sur chaque route d'execution.
    if body.online and account.kyc_status is not KycStatus.approved:
        raise forbidden("kyc_not_approved", "Votre dossier n'est pas encore valide")

    state = _state(db, account)
    state.online = body.online
    state.updated_at = datetime.now(timezone.utc)
    db.commit()
    return state.to_json()


@router.get("/offers")
async def list_offers(
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Courses libres, proposees au livreur.

    Elles ne sont servies qu'a un livreur **en ligne et valide** : proposer une
    course a quelqu'un qui ne peut pas l'accepter produit une frustration et un
    refus serveur, pas une livraison.
    """
    state = _state(db, account)
    if not state.online or account.kyc_status is not KycStatus.approved:
        return {"items": []}

    offers = db.scalars(
        select(Delivery)
        .where(
            Delivery.status == DeliveryStatus.pending,
            Delivery.driver_id.is_(None),
        )
        .order_by(Delivery.created_at)
    ).all()

    # Position courante du livreur, pour ne proposer que ce qu'il peut accepter.
    origin = (
        (state.lat, state.lng)
        if state.lat is not None and state.lng is not None
        else None
    )

    # L'adresse exacte du destinataire n'est pas donnee avant acceptation : le
    # livreur a besoin du quartier pour decider, pas du numero de porte de
    # quelqu'un qui n'a rien demande.
    items = []
    for offer in offers:
        distance_km: float | None = None
        if origin is not None:
            pickup = point_of(offer.pickup_json)
            if pickup is not None:
                distance_km = round(
                    haversine_km(origin[0], origin[1], pickup[0], pickup[1]), 1
                )
                # Trop loin pour etre acceptee (meme regle que l'acceptation) :
                # inutile de la montrer, elle ne ferait qu'un refus a l'ecran.
                if distance_km > MAX_ACCEPT_KM:
                    continue

        items.append(
            {
                "id": offer.id,
                "kind": offer.kind,
                "pickup": _summary_only(offer.pickup_json),
                "dropoff": _summary_only(offer.dropoff_json),
                "package": _json(offer.package_json),
                "price": offer.price_ariary,
                "distanceKm": distance_km,
                "createdAt": as_utc(offer.created_at).isoformat(),
            }
        )

    return {"items": items}


@router.post("/positions")
async def push_positions(
    body: PositionBatch,
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Recoit un paquet de positions tamponnees hors ligne (EXI-L09).

    Deux proprietes rendent l'envoi sur reprise inoffensif. Les doublons sont
    ignores un a un — le renvoi d'un paquet deja recu ne cree rien. Et seule la
    position **la plus recente par sa mesure** met a jour l'etat courant : un
    paquet ancien arrivant apres un recent ne fait pas reculer le livreur sur la
    carte de l'exploitation.
    """
    accepted = 0
    for sample in body.samples:
        entry = PositionSample(
            driver_id=account.id,
            delivery_id=sample.deliveryId,
            lat=sample.lat,
            lng=sample.lng,
            accuracy_m=sample.accuracyM,
            fixed_at=sample.fixedAt,
        )
        db.add(entry)
        try:
            db.commit()
            accepted += 1
        except IntegrityError:
            # Meme livreur, meme instant : point deja recu. On repart proprement
            # et on continue le paquet — un doublon n'invalide pas les autres.
            db.rollback()

    state = _state(db, account)
    latest = max(body.samples, key=lambda s: s.fixedAt, default=None)
    if latest is not None:
        known = as_utc(state.fixed_at) if state.fixed_at else None
        if known is None or as_utc(latest.fixedAt) > known:
            state.lat = latest.lat
            state.lng = latest.lng
            state.fixed_at = latest.fixedAt
            state.updated_at = datetime.now(timezone.utc)
            db.commit()

    return {"accepted": accepted, "received": len(body.samples)}


@router.get("/earnings")
async def read_earnings(
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Gains du livreur, sur ses courses **remises**.

    Une course acceptee n'est pas un gain, et une course annulee non plus.
    Compter autrement afficherait un montant que le livreur ne touchera pas —
    la premiere cause de defiance envers une application de livraison.
    """
    delivered = db.scalars(
        select(Delivery).where(
            Delivery.driver_id == account.id,
            Delivery.status.in_(DELIVERED_STATES),
        )
    ).all()

    today = datetime.now(timezone.utc).date()
    total = sum(d.price_ariary or 0 for d in delivered)
    today_total = sum(
        d.price_ariary or 0
        for d in delivered
        if as_utc(d.updated_at).date() == today
    )

    return {
        "deliveredCount": len(delivered),
        "totalAriary": total,
        "todayAriary": today_total,
    }


def _json(raw: str) -> dict:
    import json

    if not raw:
        return {}
    try:
        value = json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _summary_only(raw: str) -> dict:
    return {"summary": _json(raw).get("summary", "")}

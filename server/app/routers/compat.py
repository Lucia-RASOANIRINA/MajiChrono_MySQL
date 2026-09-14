"""Couche de compatibilite : les chemins et formes attendus par l'application.

L'application mobile et le serveur ont ete concus en parallele, et leur contrat
a diverge sur quelques points : l'application appelle `/deliveries/available` la
ou le serveur expose `/driver/offers`, `/deliveries/{id}/status` la ou il expose
`/deliveries/{id}/transition`, et attend parfois une forme differente (offre
imbriquee, gains ventiles par jour/semaine/mois). Plutot que de reecrire l'un ou
l'autre, ce module **traduit** : il pose les portes que l'application connait, et
les branche sur la logique et les modeles canoniques. Le jour ou les deux
contrats convergent, il disparait d'un bloc.

Le vocabulaire des statuts, lui, est deja aligne : les valeurs de `DeliveryStatus`
sont les mots francais que porte le fil, si bien que `to_json` emet et
`transition` accepte directement ce que l'application envoie.
"""

from __future__ import annotations

import base64
import binascii
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request, Response
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.deps import Idempotency, current_account, idempotency, require_role
from app.config import get_settings
from app.core.errors import conflict, forbidden, not_found, unprocessable
from app.core.geo import MAX_ACCEPT_KM, haversine_km, point_of
from app.db import get_db
from app.models import (
    ALLOWED_TRANSITIONS,
    DELIVERED_STATES,
    Account,
    Delivery,
    DeliveryStatus,
    DriverState,
    KYC_KINDS,
    KycDocument,
    KycMessage,
    KycStatus,
    PositionSample,
    UserRole,
)

# Toutes les pieces sont requises pour soumettre : un dossier incomplet ne se
# juge pas.
KYC_REQUIRED = set(KYC_KINDS)
_MAX_KYC_BYTES = 1024 * 1024  # 1 Mo par piece, redimensionnee cote mobile
_ALLOWED_KYC_TYPES = {"image/jpeg", "image/png", "image/webp"}


class KycDocUpload(BaseModel):
    imageBase64: str
    contentType: str


def _uploaded_kinds(db: Session, account_id: str) -> list[str]:
    rows = db.scalars(
        select(KycDocument.kind).where(KycDocument.account_id == account_id)
    ).all()
    # Rendus dans l'ordre de l'ecran, pour un affichage stable.
    present = set(rows)
    return [kind for kind in KYC_KINDS if kind in present]
from app.routers.deliveries import _record, _visible_to

router = APIRouter(tags=["compat"])

# Commission de la plateforme, provisoire (§19.2, DO-3). Elle determine ce que le
# livreur voit comme gain net, ici comme dans le simulateur du mobile.
def _net(price: int | None) -> int:
    # La taxe de facturation et la commission livreur sont deux règles
    # différentes : TAX_RATE ne doit pas modifier le gain net du livreur.
    return round((price or 0) * 0.80)


# --- Offres (l'application interroge `/deliveries/available`) -----------------


@router.get("/deliveries/available")
async def available_deliveries(
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Courses libres, dans la forme attendue par l'application.

    Chaque entree emballe la course complete, la distance a vide jusqu'au retrait
    et le gain net estime — les trois choses sur lesquelles un livreur decide
    d'accepter ou non (EXI-L04).
    """
    state = db.get(DriverState, account.id)
    if state is None or not state.online or account.kyc_status is not KycStatus.approved:
        return {"items": []}

    offers = db.scalars(
        select(Delivery)
        .where(Delivery.status == DeliveryStatus.pending, Delivery.driver_id.is_(None))
        .order_by(Delivery.created_at)
    ).all()

    origin = (
        (state.lat, state.lng)
        if state.lat is not None and state.lng is not None
        else None
    )

    items = []
    for offer in offers:
        pickup_distance = 0.0
        if origin is not None:
            pickup = point_of(offer.pickup_json)
            if pickup is not None:
                pickup_distance = round(
                    haversine_km(origin[0], origin[1], pickup[0], pickup[1]), 1
                )
                if pickup_distance > MAX_ACCEPT_KM:
                    continue
        items.append(
            {
                "delivery": offer.to_json(),
                "pickupDistanceKm": pickup_distance,
                "estimatedEarning": _net(offer.price_ariary),
            }
        )

    return {"items": items}


# --- Transition (l'application appelle `/deliveries/{id}/status`) -------------


class StatusChange(BaseModel):
    # L'application envoie soit un statut cible, soit un incident. Un incident se
    # traduit par un echec de livraison, avec le motif en note.
    status: str | None = None
    incident: str | None = None
    note: str | None = None


@router.post("/deliveries/{delivery_id}/status")
async def change_status(
    delivery_id: str,
    body: StatusChange,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /deliveries/status")),
) -> dict:
    replayed = idem.replay()
    if replayed is not None:
        return replayed[1]

    delivery = db.get(Delivery, delivery_id)
    if delivery is None:
        raise not_found("Course inconnue")
    if not _visible_to(delivery, account):
        raise not_found("Course inconnue")

    if body.incident is not None:
        target = DeliveryStatus.failed
        note = body.incident
    elif body.status is not None:
        try:
            target = DeliveryStatus(body.status)
        except ValueError:
            raise unprocessable("invalid_status", "Statut inconnu")
        note = body.note
    else:
        raise unprocessable("invalid_status", "Statut ou incident requis")

    if target not in ALLOWED_TRANSITIONS.get(delivery.status, set()):
        raise conflict(
            "illegal_transition",
            "Transition impossible depuis l'etat courant",
            {"currentState": delivery.status.value},
        )

    delivery.status = target
    _record(db, delivery, account.id, note)
    db.commit()

    payload = delivery.to_json()
    idem.remember(200, payload)
    return payload


# --- Positions (l'application appelle `/tracking/batch`) ----------------------


class _Point(BaseModel):
    point: dict = Field(default_factory=dict)
    at: datetime
    accuracy: float | None = None
    deliveryId: str | None = None


class _Batch(BaseModel):
    points: list[_Point] = Field(default_factory=list)


@router.post("/tracking/batch")
async def tracking_batch(
    body: _Batch,
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Recoit un lot de positions dans la forme du mobile (`{points:[...]}`).

    Les doublons sont ignores un a un — rejouer un lot deja recu ne cree rien —
    et seule la position la plus recente met a jour l'etat courant du livreur.
    """
    if len(body.points) > 50:
        raise unprocessable("batch_too_large", "Lot de plus de 50 points")

    accepted = 0
    latest: _Point | None = None
    for sample in body.points:
        lat = (sample.point.get("lat") or sample.point.get("latitude"))
        lng = (sample.point.get("lng") or sample.point.get("longitude"))
        if lat is None or lng is None:
            continue
        entry = PositionSample(
            driver_id=account.id,
            delivery_id=sample.deliveryId,
            lat=float(lat),
            lng=float(lng),
            accuracy_m=sample.accuracy,
            fixed_at=sample.at,
        )
        db.add(entry)
        try:
            db.commit()
            accepted += 1
        except IntegrityError:
            db.rollback()
            continue
        if latest is None or sample.at > latest.at:
            latest = sample

    if latest is not None:
        state = db.get(DriverState, account.id)
        if state is None:
            state = DriverState(account_id=account.id)
            db.add(state)
        lat = latest.point.get("lat") or latest.point.get("latitude")
        lng = latest.point.get("lng") or latest.point.get("longitude")
        state.lat = float(lat)
        state.lng = float(lng)
        state.fixed_at = latest.at
        state.updated_at = datetime.now(timezone.utc)
        db.commit()

    return {"accepted": accepted}


# --- Suivi public (l'application appelle `/public/track/{token}`) -------------


@router.get("/public/track/{token}")
async def public_track(token: str, db: Session = Depends(get_db)) -> dict:
    """Suivi public dans la forme attendue par l'application.

    Le destinataire ne voit que l'essentiel : l'etat, le repere de destination,
    le prenom du livreur et sa position. Ni numeros, ni prix (EXI-C24).
    """
    delivery = db.scalar(select(Delivery).where(Delivery.tracking_token == token))
    if delivery is None:
        raise not_found("Lien de suivi inconnu")

    driver_first_name = None
    driver_position = None
    if delivery.driver_id is not None:
        driver = db.get(Account, delivery.driver_id)
        if driver is not None and driver.display_name:
            driver_first_name = driver.display_name.split(" ")[0]
        state = db.get(DriverState, delivery.driver_id)
        if state is not None and state.lat is not None and state.lng is not None:
            driver_position = {"lat": state.lat, "lng": state.lng}

    dropoff = json.loads(delivery.dropoff_json)
    return {
        "status": delivery.status.value,
        "destinationLandmark": dropoff.get("summary", ""),
        "driverFirstName": driver_first_name,
        "driverPosition": driver_position,
        "etaMinutes": None,
        "expiresAt": None,
    }


# --- Gains (l'application appelle `/drivers/earnings`) ------------------------


@router.get("/drivers/earnings")
async def earnings(
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Gains ventiles par jour / semaine / mois, avec le detail par course.

    Seules les courses **remises** comptent : une course en cours n'est pas un
    gain. Le detail permet au livreur de pointer une course precise (EXI-L12).
    """
    delivered = db.scalars(
        select(Delivery)
        .where(
            Delivery.driver_id == account.id,
            Delivery.status.in_(DELIVERED_STATES),
        )
        .order_by(Delivery.updated_at.desc())
    ).all()

    now = datetime.now(timezone.utc)
    today = now.date()
    week_start = today.fromordinal(today.toordinal() - today.weekday())
    month_key = (today.year, today.month)

    def when(d: Delivery):
        at = d.updated_at
        return at if at.tzinfo else at.replace(tzinfo=timezone.utc)

    today_total = week_total = month_total = today_count = 0
    entries = []
    for d in delivered:
        net = _net(d.price_ariary)
        at = when(d)
        if at.date() == today:
            today_total += net
            today_count += 1
        if at.date() >= week_start:
            week_total += net
        if (at.year, at.month) == month_key:
            month_total += net
        dropoff = json.loads(d.dropoff_json)
        entries.append(
            {
                "deliveryId": d.id,
                "amount": net,
                "at": at.isoformat(),
                "label": dropoff.get("summary", ""),
            }
        )

    return {
        "today": today_total,
        "week": week_total,
        "month": month_total,
        "todayCount": today_count,
        "entries": entries,
    }


# --- KYC (l'application appelle `/drivers/kyc*`) ------------------------------


@router.get("/drivers/kyc/status")
async def kyc_status(
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    uploaded = _uploaded_kinds(db, account.id)
    return {
        "status": account.kyc_status.value if account.kyc_status else "draft",
        # Toutes les pieces attendues, et celles deja fournies : de quoi
        # afficher l'avancement du dossier piece par piece.
        "documents": list(KYC_KINDS),
        "uploaded": uploaded,
        "missing": [k for k in KYC_KINDS if k not in uploaded],
        "rejectionReason": None,
    }


class KycMessageBody(BaseModel):
    body: str = Field(min_length=1, max_length=2000)


@router.get("/drivers/kyc/messages")
async def kyc_messages(
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Fil de suivi du dossier, cote livreur : ses echanges avec l'exploitation."""
    rows = db.scalars(
        select(KycMessage)
        .where(KycMessage.account_id == account.id)
        .order_by(KycMessage.created_at)
    ).all()
    return {"items": [m.to_json() for m in rows]}


@router.post("/drivers/kyc/messages")
async def kyc_send_message(
    body: KycMessageBody,
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Le livreur ecrit a l'exploitation pour connaitre le suivi de son dossier."""
    text = body.body.strip()
    if not text:
        raise unprocessable("empty_message", "Message vide")
    message = KycMessage(account_id=account.id, from_admin=False, body=text)
    db.add(message)
    db.commit()
    db.refresh(message)
    return message.to_json()


@router.post("/drivers/kyc/documents/{kind}")
async def kyc_upload_document(
    kind: str,
    body: KycDocUpload,
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Depose (ou remplace) une piece du dossier. Image en base64, rangee en
    base — donnee d'identite sensible, jamais servie publiquement."""
    if kind not in KYC_REQUIRED:
        raise unprocessable("unknown_kind", "Piece inconnue")
    content_type = body.contentType.strip().lower()
    if content_type not in _ALLOWED_KYC_TYPES:
        raise unprocessable("unsupported_type", "Format d'image non accepte")

    raw = body.imageBase64
    if "," in raw and raw.strip().startswith("data:"):
        raw = raw.split(",", 1)[1]
    try:
        data = base64.b64decode(raw, validate=True)
    except (binascii.Error, ValueError):
        raise unprocessable("invalid_image", "Image illisible") from None
    if not data:
        raise unprocessable("invalid_image", "Image vide")
    if len(data) > _MAX_KYC_BYTES:
        raise unprocessable(
            "image_too_large", "Image trop lourde", {"maxBytes": _MAX_KYC_BYTES}
        )

    doc = db.get(KycDocument, (account.id, kind))
    if doc is None:
        doc = KycDocument(account_id=account.id, kind=kind)
        db.add(doc)
    doc.data = data
    doc.content_type = content_type
    doc.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"uploaded": _uploaded_kinds(db, account.id)}


@router.delete("/drivers/kyc/documents/{kind}")
async def kyc_delete_document(
    kind: str,
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    doc = db.get(KycDocument, (account.id, kind))
    if doc is not None:
        db.delete(doc)
        db.commit()
    return {"uploaded": _uploaded_kinds(db, account.id)}


@router.get("/accounts/{account_id}/kyc/{kind}")
async def kyc_read_document(
    account_id: int,
    kind: str,
    db: Session = Depends(get_db),
    viewer: Account = Depends(current_account),
) -> Response:
    """Sert une piece. Contrairement a l'avatar, elle **exige un jeton** : seul
    le proprietaire du dossier ou l'exploitation peut la voir."""
    if viewer.id != account_id and not viewer.is_admin:
        raise forbidden("not_allowed", "Acces reserve")
    doc = db.get(KycDocument, (account_id, kind))
    if doc is None:
        raise not_found("Piece inconnue")
    return Response(content=doc.data, media_type=doc.content_type)


@router.post("/drivers/kyc")
async def kyc_submit(
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Soumission du dossier : il passe en **verification** (EXI-L02).

    On ne valide pas soi-meme son dossier — c'est l'exploitation qui tranche
    (EXI-A04). La soumission ne fait que le mettre dans la file, et seulement si
    **toutes les pieces** sont fournies : un dossier incomplet renverrait la file
    a l'expediteur pour rien.
    """
    if account.kyc_status in (KycStatus.approved, KycStatus.submitted):
        return {"status": account.kyc_status.value}

    uploaded = set(_uploaded_kinds(db, account.id))
    missing = [k for k in KYC_KINDS if k not in uploaded]
    if missing:
        raise unprocessable(
            "kyc_incomplete", "Dossier incomplet", {"missing": missing}
        )

    account.kyc_status = KycStatus.submitted
    db.commit()
    return {"status": account.kyc_status.value}

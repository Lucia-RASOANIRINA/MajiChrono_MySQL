"""Courses : creation, consultation, transitions, annulation.

Deux invariants tiennent ce fichier.

**Une transition illegale n'est jamais silencieuse.** Le serveur repond 409 en
rappelant l'etat courant, ce qui permet a l'application de reafficher la verite
plutot que de laisser l'utilisateur reessayer dans le vide (EXI-B02). Accepter
en silence serait pire : deux appareils croiraient des choses differentes.

**Chaque transition laisse une trace.** `DeliveryEvent` est en ajout seul. En
cas de litige, on peut dire qui a fait passer la course dans quel etat et quand
— ce qu'une colonne `status` seule ne raconte pas.
"""

from __future__ import annotations

import json
import secrets
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.deps import Idempotency, current_account, idempotency, require_role
from app.core.errors import conflict, forbidden, not_found, unprocessable
from app.core.geo import (
    MAX_ACCEPT_KM,
    haversine_km,
    is_in_madagascar,
    point_of,
)
from app.core.security import new_opaque_token
from app.db import get_db
from app.models import (
    ALLOWED_TRANSITIONS,
    CLIENT_CANCELLABLE,
    INCIDENT_KINDS,
    Delivery,
    DeliveryEvent,
    DeliveryIncident,
    DeliveryStatus,
    Account,
    DriverState,
    KycStatus,
    UserRole,
)

router = APIRouter(tags=["deliveries"])


class GeoPoint(BaseModel):
    lat: float
    lng: float


class Place(BaseModel):
    point: GeoPoint | None = None
    summary: str = ""


class CreateDelivery(BaseModel):
    pickup: Place
    dropoff: Place
    kind: str = "standard"
    package: dict = {}
    price: int | None = None
    # Point relais de remise, optionnel (differenciant D6, §7). Quand il est
    # fourni, un code de retrait est genere pour le destinataire.
    relayPointId: str | None = None
    # Qui paie (EXI-C42) et liste d'achats pour compte (EXI-C07), optionnels.
    payer: str | None = None
    shopping: dict | None = None


class Transition(BaseModel):
    status: str
    note: str | None = None


def _record(db: Session, delivery: Delivery, actor_id: str | None, note: str | None = None) -> None:
    db.add(
        DeliveryEvent(
            delivery_id=delivery.id,
            status=delivery.status,
            actor_id=actor_id,
            note=note,
        )
    )
    delivery.updated_at = datetime.now(timezone.utc)


def _visible_to(delivery: Delivery, account: Account) -> bool:
    """Une course se voit par ses deux parties, ou par l'exploitation.

    Un livreur qui n'a pas la course ne doit pas pouvoir la lire : la liste des
    offres est un autre point d'entree, filtre, et qui ne donne pas l'adresse
    exacte du destinataire avant acceptation.
    """
    if account.is_admin:
        return True
    return account.id in (delivery.client_id, delivery.driver_id)


@router.post("/deliveries", status_code=201)
async def create_delivery(
    body: CreateDelivery,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /deliveries")),
) -> dict:
    replayed = idem.replay()
    if replayed is not None:
        # Meme cle rejouee : on rend la course deja creee, sans en creer une
        # seconde. Le client ne peut pas distinguer ce cas d'un succes, et c'est
        # exactement le but (EXI-S01).
        return replayed[1]

    if account.role is not UserRole.client:
        raise forbidden("role_forbidden", "Seul un expediteur cree une course")

    pickup_point = body.pickup.point
    dropoff_point = body.dropoff.point
    if pickup_point is None or dropoff_point is None:
        raise unprocessable(
            "location_required",
            "Les localisations de depart et d'arrivee sont obligatoires",
        )
    if not is_in_madagascar(pickup_point.lat, pickup_point.lng) or not is_in_madagascar(
        dropoff_point.lat, dropoff_point.lng
    ):
        raise unprocessable(
            "location_outside_madagascar",
            "Les localisations doivent se trouver a Madagascar",
        )
    distance_km = haversine_km(
        pickup_point.lat,
        pickup_point.lng,
        dropoff_point.lat,
        dropoff_point.lng,
    )
    if distance_km < 0.05:
        raise unprocessable(
            "invalid_distance",
            "Le depart et l'arrivee doivent etre differents",
        )

    # Code de retrait au relais : six chiffres, assez pour identifier un colis
    # au comptoir sans etre un secret durable. Genere seulement si un relais est
    # choisi (§7 : selection, code de retrait).
    relay_code = None
    if body.relayPointId:
        relay_code = f"{secrets.randbelow(1000000):06d}"

    delivery = Delivery(
        client_id=account.id,
        kind=body.kind,
        pickup_address=body.pickup.summary.strip()[:255],
        dropoff_address=body.dropoff.summary.strip()[:255],
        pickup_lat=pickup_point.lat,
        pickup_lng=pickup_point.lng,
        dropoff_lat=dropoff_point.lat,
        dropoff_lng=dropoff_point.lng,
        pickup_json=body.pickup.model_dump_json(),
        dropoff_json=body.dropoff.model_dump_json(),
        package_json=json.dumps(body.package),
        distance_km=round(distance_km, 3),
        price_ariary=body.price,
        relay_point_id=body.relayPointId,
        relay_pickup_code=relay_code,
        payer=body.payer,
        shopping_json=json.dumps(body.shopping) if body.shopping else None,
        tracking_token=new_opaque_token()[:40],
    )
    db.add(delivery)
    db.commit()

    _record(db, delivery, account.id, "creation")
    db.commit()

    payload = delivery.to_json()
    idem.remember(201, payload)
    return payload


@router.get("/deliveries")
async def list_deliveries(
    db: Session = Depends(get_db), account: Account = Depends(current_account)
) -> dict:
    query = select(Delivery).order_by(Delivery.created_at.desc())
    if account.role is UserRole.client:
        query = query.where(Delivery.client_id == account.id)
    elif account.role is UserRole.driver:
        query = query.where(Delivery.driver_id == account.id)

    return {"items": [d.to_json() for d in db.scalars(query).all()]}


@router.get("/deliveries/{delivery_id}")
async def read_delivery(
    delivery_id: str,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    delivery = db.get(Delivery, delivery_id)
    if delivery is None or not _visible_to(delivery, account):
        # Meme reponse pour « inexistante » et « pas la votre » : distinguer les
        # deux permettrait de decouvrir quels identifiants existent.
        raise not_found("Course inconnue")

    events = db.scalars(
        select(DeliveryEvent)
        .where(DeliveryEvent.delivery_id == delivery.id)
        .order_by(DeliveryEvent.occurred_at)
    ).all()

    return {**delivery.to_json(), "events": [e.to_json() for e in events]}


def _enforce_accept_distance(
    db: Session, driver: Account, delivery: Delivery
) -> None:
    """Refuse l'acceptation d'une course hors de portee du livreur.

    On compare la derniere position connue du livreur au point de retrait. Si
    l'une des deux manque — livreur sans fix GPS, adresse sans coordonnees — on
    ne peut pas juger : on laisse passer plutot que de bloquer sur une donnee
    absente. Des que les deux sont connues, la course trop eloignee est refusee
    avec la distance, que l'application peut afficher telle quelle.
    """
    state = db.get(DriverState, driver.id)
    pickup = point_of(delivery.pickup_json)
    if state is None or state.lat is None or state.lng is None or pickup is None:
        return

    distance = haversine_km(state.lat, state.lng, pickup[0], pickup[1])
    if distance > MAX_ACCEPT_KM:
        raise unprocessable(
            "too_far",
            "Course trop eloignee pour etre acceptee",
            {"distanceKm": round(distance, 1), "maxKm": MAX_ACCEPT_KM},
        )


@router.post("/deliveries/{delivery_id}/transition")
async def transition_delivery(
    delivery_id: str,
    body: Transition,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /deliveries/transition")),
) -> dict:
    replayed = idem.replay()
    if replayed is not None:
        return replayed[1]

    delivery = db.get(Delivery, delivery_id)
    if delivery is None:
        raise not_found("Course inconnue")

    try:
        target = DeliveryStatus(body.status)
    except ValueError:
        raise unprocessable("invalid_status", "Statut inconnu")

    # Un livreur n'est pas encore partie prenante quand il **accepte** : c'est
    # l'acceptation qui l'y fait entrer. Le controle de visibilite seul le
    # rejetait par un 404, et aucune course n'aurait jamais pu etre prise.
    #
    # La condition ne verifie pas que la course est libre. Deux livreurs
    # touchent souvent « accepter » a la meme seconde : le perdant doit lire
    # « course deja prise » (409) et non « course inconnue » (404). Il vient
    # d'en voir l'offre a l'ecran — lui repondre qu'elle n'existe pas serait
    # faux, et il rechargerait la liste sans comprendre. Le 409 est produit plus
    # bas, avec l'etat courant.
    tente_une_acceptation = (
        account.role is UserRole.driver and target is DeliveryStatus.assigned
    )
    if not (_visible_to(delivery, account) or tente_une_acceptation):
        raise not_found("Course inconnue")

    # L'acceptation est la seule transition qui attribue un livreur. Ses
    # controles passent **avant** la regle generale des transitions : sans cela,
    # le perdant de la course a l'acceptation lirait « transition impossible »
    # au lieu de « course deja prise ». Les deux sont des 409, mais un seul lui
    # dit ce qui s'est passe, et l'application affiche ce message tel quel.
    if target is DeliveryStatus.assigned:
        if account.role is not UserRole.driver:
            raise forbidden("role_forbidden", "Seul un livreur accepte une course")
        if delivery.driver_id is not None:
            raise conflict(
                "already_taken",
                "Course deja prise",
                {"currentState": delivery.status.value},
            )
        _enforce_accept_distance(db, account, delivery)

    if target not in ALLOWED_TRANSITIONS[delivery.status]:
        raise conflict(
            "illegal_transition",
            "Transition impossible depuis l'etat courant",
            {"currentState": delivery.status.value},
        )

    if target is DeliveryStatus.assigned:
        delivery.driver_id = account.id

    delivery.status = target
    _record(db, delivery, account.id, body.note)
    db.commit()

    payload = delivery.to_json()
    idem.remember(200, payload)
    return payload


@router.post("/deliveries/{delivery_id}/accept")
async def accept_delivery(
    delivery_id: str,
    db: Session = Depends(get_db),
    account: Account = Depends(require_role(UserRole.driver)),
) -> dict:
    """Acceptation d'une course par un livreur (EXI-L05).

    C'est le geste qui assigne le livreur et ouvre la discussion avec
    l'expediteur. Deux garde-fous : la course doit etre encore libre, et son
    point de retrait doit etre a portee du livreur (regle de distance). Le
    second acceptant lit « course deja prise » ; un livreur qui reaccepte sa
    propre course relit simplement son etat, sans erreur.
    """
    # Un livreur dont le dossier n'est pas valide ne peut pas prendre de course
    # (EXI-L01) : on le refuse ici, avec un code que le mobile reconnait pour
    # afficher « compte pas encore actif » et proposer de suivre le dossier.
    if account.kyc_status is not KycStatus.approved:
        raise forbidden(
            "kyc_not_approved",
            "Votre compte n'est pas encore actif : dossier en cours de validation",
        )

    delivery = db.get(Delivery, delivery_id)
    if delivery is None:
        raise not_found("Course inconnue")

    if delivery.driver_id is not None:
        if delivery.driver_id == account.id:
            return delivery.to_json()
        raise conflict(
            "already_taken",
            "Course deja prise",
            {"currentState": delivery.status.value},
        )

    if delivery.status is not DeliveryStatus.pending:
        raise conflict(
            "illegal_transition",
            "La course n'est plus a prendre",
            {"currentState": delivery.status.value},
        )

    _enforce_accept_distance(db, account, delivery)

    delivery.driver_id = account.id
    delivery.status = DeliveryStatus.assigned
    _record(db, delivery, account.id, "acceptation")
    db.commit()
    return delivery.to_json()


class CancelBody(BaseModel):
    reason: str | None = None


@router.post("/deliveries/{delivery_id}/cancel")
async def cancel_delivery(
    delivery_id: str,
    body: CancelBody = CancelBody(),
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    delivery = db.get(Delivery, delivery_id)
    if delivery is None or not _visible_to(delivery, account):
        raise not_found("Course inconnue")

    if delivery.status not in CLIENT_CANCELLABLE:
        raise conflict(
            "illegal_transition",
            "La course ne peut plus etre annulee",
            {"currentState": delivery.status.value},
        )

    # Frais d'annulation : rien tant qu'aucun livreur n'est engage (course encore
    # en recherche) ; sinon on retient une part, car un livreur a deja avance
    # vers l'expediteur pour rien (EXI-C26). La part reste modeste et plafonnee
    # par un plancher lisible.
    fee = 0
    if delivery.status is DeliveryStatus.assigned:
        base = delivery.price_ariary or 5000
        fee = max(1000, round(base * 0.20))

    delivery.status = DeliveryStatus.cancelled
    delivery.cancel_reason = (body.reason or "").strip() or None
    delivery.cancel_fee_ariary = fee
    _record(db, delivery, account.id, "annulation")
    db.commit()
    return delivery.to_json()


@router.get("/track/{token}")
async def public_tracking(token: str, db: Session = Depends(get_db)) -> dict:
    """Suivi public, sans compte (EXI-C24).

    Le destinataire n'installe rien. Il recoit un lien par SMS et doit voir ou
    en est son colis — **et rien d'autre**. Ni le numero de l'expediteur, ni
    celui du livreur, ni le prix : ce sont des donnees des deux parties, pas de
    celui qui attend a la porte.
    """
    delivery = db.scalar(select(Delivery).where(Delivery.tracking_token == token))
    if delivery is None:
        raise not_found("Lien de suivi inconnu")

    events = db.scalars(
        select(DeliveryEvent)
        .where(DeliveryEvent.delivery_id == delivery.id)
        .order_by(DeliveryEvent.occurred_at)
    ).all()

    return {
        "status": delivery.status.value,
        "dropoffSummary": json.loads(delivery.dropoff_json).get("summary", ""),
        "updatedAt": delivery.updated_at.isoformat(),
        "events": [
            {"status": e.status.value, "occurredAt": e.occurred_at.isoformat()}
            for e in events
        ],
    }


# --- Incidents (EXI-L14, §19) -----------------------------------------------


class IncidentBody(BaseModel):
    kind: str
    description: str | None = None
    # Photo optionnelle, deja televersee via `POST /media` : on ne stocke que
    # sa reference.
    photoId: str | None = None
    lat: float | None = None
    lng: float | None = None


@router.post("/deliveries/{delivery_id}/incidents", status_code=201)
async def report_incident(
    delivery_id: str,
    body: IncidentBody,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /deliveries/incidents")),
) -> dict:
    """Declare un incident sur une course dont l'appelant est partie prenante.

    L'incident est une **main courante**, pas un verdict : il n'echoue pas la
    course de lui-meme (le sort du colis se joue au constat de remise). On le
    documente — type, description, photo, position — et l'exploitation le clot.
    """
    replayed = idem.replay()
    if replayed is not None:
        return replayed[1]

    delivery = db.get(Delivery, delivery_id)
    if delivery is None or not _visible_to(delivery, account):
        raise not_found("Course inconnue")

    if body.kind not in INCIDENT_KINDS:
        raise unprocessable("invalid_kind", "Type d'incident inconnu")

    incident = DeliveryIncident(
        delivery_id=delivery.id,
        reporter_id=account.id,
        kind=body.kind,
        description=(body.description or "").strip() or None,
        photo_media_id=body.photoId,
        lat=body.lat,
        lng=body.lng,
    )
    db.add(incident)
    db.commit()
    db.refresh(incident)

    payload = incident.to_json()
    idem.remember(201, payload)
    return payload


@router.get("/deliveries/{delivery_id}/incidents")
async def list_incidents(
    delivery_id: str,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    """Incidents d'une course, les plus recents d'abord. Visibles des deux
    parties et de l'exploitation, comme la course elle-meme."""
    delivery = db.get(Delivery, delivery_id)
    if delivery is None or not _visible_to(delivery, account):
        raise not_found("Course inconnue")

    rows = db.scalars(
        select(DeliveryIncident)
        .where(DeliveryIncident.delivery_id == delivery.id)
        .order_by(DeliveryIncident.created_at.desc())
    ).all()
    return {"items": [i.to_json() for i in rows]}

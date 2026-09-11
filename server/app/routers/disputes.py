"""Litiges sur une course (EXI-A05 exploitation, §13 client).

Un litige est un **dossier contradictoire** : le client ou le livreur l'ouvre
sur une course, chacun y expose sa version dans un fil de messages, et
l'exploitation tranche avec un motif. Les deux parties et l'exploitation voient
le meme dossier — c'est la condition pour qu'il vaille comme preuve (EXI-CC31).

Trois frontieres portent l'essentiel de la valeur du routeur :

  - on n'ouvre un litige que sur une course dont on est partie prenante ;
  - on ne lit et on n'ecrit que dans un litige qui nous concerne (ou en tant
    qu'exploitation) ;
  - seule l'exploitation tranche, et sa decision se motive.
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.deps import Idempotency, current_account, idempotency
from app.core.errors import conflict, forbidden, not_found, unprocessable
from app.db import get_db
from app.models import Account, Delivery, Dispute, DisputeMessage, UserRole

router = APIRouter(prefix="/disputes", tags=["disputes"])

# Un motif de decision qui tranche entre deux versions se justifie : meme seuil
# que le front (ModerationAction.minReasonLength).
MIN_REASON_LENGTH = 10


class OpenDispute(BaseModel):
    deliveryId: int
    reason: str


class MessageBody(BaseModel):
    body: str


class DecisionBody(BaseModel):
    resolve: bool
    reason: str = ""


def _is_party(delivery: Delivery, account: Account) -> bool:
    return account.id in (delivery.client_id, delivery.driver_id)


def _can_see(dispute: Dispute, delivery: Delivery, account: Account) -> bool:
    return account.is_admin or _is_party(delivery, account)


def _role_label(account: Account) -> tuple[str, bool]:
    """Libelle d'auteur et drapeau exploitation, sans reveler l'identite."""
    if account.is_admin:
        return "Exploitation", True
    if account.role is UserRole.driver:
        return "Livreur", False
    return "Client", False


@router.post("", status_code=201)
async def open_dispute(
    body: OpenDispute,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /disputes")),
) -> dict:
    """Ouvre un litige sur une course dont l'appelant est partie prenante (§13)."""
    replayed = idem.replay()
    if replayed is not None:
        return replayed[1]

    delivery = db.get(Delivery, body.deliveryId)
    if delivery is None or not _is_party(delivery, account):
        # Meme reponse pour « inconnue » et « pas la votre » : distinguer les deux
        # revelerait quels identifiants existent.
        raise not_found("Course inconnue")

    reason = body.reason.strip()
    if not reason:
        raise unprocessable("reason_required", "Motif obligatoire")

    dispute = Dispute(
        delivery_id=delivery.id,
        status="open",
        reason=reason,
        opened_by=account.role.value,
    )
    db.add(dispute)
    db.commit()
    db.refresh(dispute)

    payload = dispute.to_json()
    idem.remember(201, payload)
    return payload


@router.get("")
async def list_disputes(
    status: str | None = None,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    """Liste des litiges, les plus recents d'abord.

    L'exploitation voit tout ; une partie ne voit que les litiges sur ses
    propres courses. C'est la meme frontiere que pour la lecture d'une course.
    """
    query = select(Dispute).order_by(Dispute.opened_at.desc())
    if status is not None:
        query = query.where(Dispute.status == status)

    disputes = list(db.scalars(query).all())

    if not account.is_admin:
        visible = []
        for d in disputes:
            delivery = db.get(Delivery, d.delivery_id)
            if delivery is not None and _is_party(delivery, account):
                visible.append(d)
        disputes = visible

    return {"items": [d.to_json() for d in disputes]}


def _load_visible(db: Session, dispute_id: str, account: Account) -> Dispute:
    dispute = db.get(Dispute, dispute_id)
    if dispute is None:
        raise not_found("Litige inconnu")
    delivery = db.get(Delivery, dispute.delivery_id)
    if delivery is None or not _can_see(dispute, delivery, account):
        raise not_found("Litige inconnu")
    return dispute


@router.get("/{dispute_id}")
async def read_dispute(
    dispute_id: str,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    return _load_visible(db, dispute_id, account).to_json()


@router.post("/{dispute_id}/messages")
async def add_message(
    dispute_id: str,
    body: MessageBody,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    """Ajoute un message au fil. Toute partie ou l'exploitation peut ecrire."""
    dispute = _load_visible(db, dispute_id, account)

    if dispute.is_closed:
        raise conflict(
            "dispute_closed", "Litige clos", {"currentState": dispute.status}
        )

    text = body.body.strip()
    if not text:
        raise unprocessable("empty_message", "Message vide")

    label, from_ops = _role_label(account)
    db.add(
        DisputeMessage(
            dispute_id=dispute.id,
            author_label=label,
            body=text,
            from_operations=from_ops,
        )
    )

    # Le premier echange fait passer le litige en instruction : l'etat suit ce
    # qui se passe, il n'attend pas qu'on pense a le changer.
    if dispute.status == "open":
        dispute.status = "investigating"

    db.commit()
    db.refresh(dispute)
    return dispute.to_json()


@router.post("/{dispute_id}/decision")
async def decide_dispute(
    dispute_id: str,
    body: DecisionBody,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /disputes/decision")),
) -> dict:
    """Tranche et clot le litige. Reserve a l'exploitation, motif obligatoire."""
    if not account.is_admin:
        raise forbidden("role_forbidden", "Seule l'exploitation tranche")

    replayed = idem.replay()
    if replayed is not None:
        return replayed[1]

    dispute = db.get(Dispute, dispute_id)
    if dispute is None:
        raise not_found("Litige inconnu")

    if dispute.is_closed:
        raise conflict(
            "already_decided",
            "Litige deja tranche",
            {"currentState": dispute.status},
        )

    reason = body.reason.strip()
    if len(reason) < MIN_REASON_LENGTH:
        raise unprocessable("reason_required", "Motif obligatoire")

    dispute.status = "resolved" if body.resolve else "rejected"
    dispute.decision_action = (
        "resolve_dispute" if body.resolve else "reject_dispute"
    )
    dispute.decision_reason = reason
    dispute.decided_at = datetime.now(timezone.utc)
    dispute.decided_by = account.id

    db.commit()
    db.refresh(dispute)

    payload = dispute.to_json()
    idem.remember(200, payload)
    return payload

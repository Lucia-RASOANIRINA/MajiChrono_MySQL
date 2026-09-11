"""Evaluation d'une course, de l'expediteur vers le livreur (EXI-C40, EXI-C41).

Deux regles tiennent tout ce fichier. On ne note que ce qu'on a vecu : seul
l'expediteur d'une course **remise** peut la noter, et il note le livreur qui
l'a portee. Et une note se corrige mais ne s'empile pas : la meme course, notee
deux fois, met a jour la note existante plutot que d'en creer une seconde.

La note globale du livreur — celle qui s'affiche sur son profil — est
**recalculee** a chaque avis, jamais tenue a la main. Une moyenne recopiee
divergerait de ses avis au premier oubli.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.deps import current_account
from app.core.errors import forbidden, not_found, unprocessable
from app.db import get_db
from app.models import DELIVERED_STATES, Account, Delivery, Review

router = APIRouter(tags=["reviews"])


class CreateReview(BaseModel):
    deliveryId: int
    stars: int = Field(ge=1, le=5)
    punctuality: int | None = Field(default=None, ge=1, le=5)
    service: int | None = Field(default=None, ge=1, le=5)
    comment: str | None = None


def _recompute_rating(db: Session, ratee_id: str) -> None:
    """Remet la note du livreur a la moyenne de ses avis.

    Arrondie au dixieme : afficher « 4,7 » est honnete, afficher
    « 4,6923076923 » ne dit rien de plus et ne fait que trahir la mecanique.
    """
    average = db.scalar(
        select(func.avg(Review.stars)).where(Review.ratee_id == ratee_id)
    )
    account = db.get(Account, ratee_id)
    if account is not None:
        account.rating = round(float(average), 1) if average is not None else None


@router.post("/reviews", status_code=201)
async def create_review(
    body: CreateReview,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    delivery = db.get(Delivery, body.deliveryId)
    if delivery is None:
        raise not_found("Course inconnue")

    # Seul l'expediteur de la course la note.
    if delivery.client_id != account.id:
        raise forbidden("not_client", "Seul l'expediteur note la course")

    # Et seulement une fois remise : noter une course en cours, c'est noter ce
    # qui n'a pas encore eu lieu. « Remise avec reserves » compte comme remise —
    # la course a bien eu lieu, elle merite d'etre notee.
    if delivery.status not in DELIVERED_STATES:
        raise unprocessable(
            "not_delivered",
            "La course n'est pas encore remise",
            {"currentState": delivery.status.value},
        )
    if delivery.driver_id is None:
        raise unprocessable("no_driver", "Aucun livreur a evaluer")

    existing = db.scalar(
        select(Review).where(
            Review.delivery_id == delivery.id, Review.rater_id == account.id
        )
    )
    if existing is not None:
        # Correction plutot que doublon : on met a jour la note existante.
        existing.stars = body.stars
        existing.punctuality = body.punctuality
        existing.service = body.service
        existing.comment = body.comment
        review = existing
    else:
        review = Review(
            delivery_id=delivery.id,
            rater_id=account.id,
            ratee_id=delivery.driver_id,
            stars=body.stars,
            punctuality=body.punctuality,
            service=body.service,
            comment=body.comment,
        )
        db.add(review)

    db.flush()
    _recompute_rating(db, delivery.driver_id)
    db.commit()
    return review.to_json()


@router.get("/reviews/delivery/{delivery_id}")
async def read_review_for_delivery(
    delivery_id: str,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    """L'avis que l'expediteur a deja laisse sur une course, s'il existe.

    L'application s'en sert pour savoir s'il faut proposer de noter ou montrer la
    note deja donnee — plutot que de reproposer un formulaire deja rempli.
    """
    review = db.scalar(
        select(Review).where(
            Review.delivery_id == delivery_id, Review.rater_id == account.id
        )
    )
    if review is None:
        raise not_found("Aucun avis pour cette course")
    return review.to_json()

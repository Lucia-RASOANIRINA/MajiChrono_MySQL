"""Carnet d'adresses du compte (EXI-C05).

Le carnet appartient au compte et le suit d'un appareil a l'autre. On n'expose
que les entrees de l'appelant : une adresse de domicile est une donnee que seul
son proprietaire doit voir.
"""

from __future__ import annotations

import json

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.deps import current_account
from app.core.errors import not_found, unprocessable
from app.db import get_db
from app.models import Account, SavedAddress

router = APIRouter(prefix="/addresses", tags=["addresses"])

# Un compte n'a qu'un seul domicile et un seul lieu de travail : poser un
# nouveau « home » deplace l'ancien vers « other » plutot que d'en garder deux,
# qui se disputeraient le raccourci de l'accueil.
_UNIQUE_KINDS = {"home", "work"}
_KINDS = {"home", "work", "favorite", "other"}


class AddressBody(BaseModel):
    label: str = Field(default="", max_length=120)
    kind: str = "other"
    # L'adresse composite, opaque pour le serveur : il la range et la rend telle
    # quelle. Sa validation de forme est faite cote application (§4.3).
    address: dict


def _point(address: dict) -> tuple[float, float]:
    point = address.get("point")
    if isinstance(point, dict):
        return float(point.get("lat", 0)), float(point.get("lng", 0))
    return float(address.get("lat", 0)), float(address.get("lng", 0))


def _demote_existing(db: Session, account_id: str, kind: str, keep_id: str | None) -> None:
    if kind not in _UNIQUE_KINDS:
        return
    for row in db.scalars(
        select(SavedAddress).where(
            SavedAddress.account_id == account_id,
            SavedAddress.kind == kind,
        )
    ).all():
        if row.id != keep_id:
            row.kind = "other"


@router.get("")
async def list_addresses(
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    rows = db.scalars(
        select(SavedAddress)
        .where(SavedAddress.account_id == account.id)
        # Les plus utilisees d'abord : sur un carnet de dix entrees, cela evite
        # de faire defiler a chaque envoi.
        .order_by(SavedAddress.use_count.desc().nullslast(), SavedAddress.created_at.desc())
    ).all()
    return {"items": [row.to_json() for row in rows]}


@router.post("", status_code=201)
async def create_address(
    body: AddressBody,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    if body.kind not in _KINDS:
        raise unprocessable("invalid_kind", "Type d'adresse inconnu")

    lat, lng = _point(body.address)
    entry = SavedAddress(
        account_id=account.id,
        kind=body.kind,
        label=body.label.strip(),
        payload=json.dumps(body.address),
        full_address=str(body.address.get("summary", "")).strip()[:255],
        city=str(body.address.get("city", "")).strip()[:80] or None,
        latitude=lat,
        longitude=lng,
        use_count=0,
    )
    db.add(entry)
    db.flush()
    _demote_existing(db, account.id, body.kind, entry.id)
    db.commit()
    return entry.to_json()


@router.patch("/{address_id}")
async def update_address(
    address_id: str,
    body: AddressBody,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    if body.kind not in _KINDS:
        raise unprocessable("invalid_kind", "Type d'adresse inconnu")

    entry = db.get(SavedAddress, address_id)
    if entry is None or entry.account_id != account.id:
        raise not_found("Adresse inconnue")

    entry.label = body.label.strip()
    entry.kind = body.kind
    entry.payload = json.dumps(body.address)
    entry.full_address = str(body.address.get("summary", "")).strip()[:255]
    entry.city = str(body.address.get("city", "")).strip()[:80] or None
    entry.latitude, entry.longitude = _point(body.address)
    _demote_existing(db, account.id, body.kind, entry.id)
    db.commit()
    return entry.to_json()


@router.delete("/{address_id}", status_code=204, response_class=Response)
async def delete_address(
    address_id: str,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
):
    entry = db.get(SavedAddress, address_id)
    if entry is not None and entry.account_id == account.id:
        db.delete(entry)
        db.commit()

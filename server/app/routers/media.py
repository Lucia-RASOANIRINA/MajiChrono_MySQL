"""Media : photos televersees (photo du colis a la declaration, EXI-C09).

Une image arrive en base64, repart avec un identifiant opaque. La lecture exige
un jeton — pas un secret, mais pas non plus une galerie ouverte a l'internet.
"""

from __future__ import annotations

import base64
import binascii

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.deps import current_account
from app.core.errors import not_found, unprocessable
from app.db import get_db
from app.models import Account, Media

router = APIRouter(prefix="/media", tags=["media"])

_MAX_BYTES = 1024 * 1024  # 1 Mo, redimensionnee cote mobile
_ALLOWED = {"image/jpeg", "image/png", "image/webp"}


class MediaUpload(BaseModel):
    imageBase64: str
    contentType: str


@router.post("", status_code=201)
async def upload_media(
    body: MediaUpload,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    content_type = body.contentType.strip().lower()
    if content_type not in _ALLOWED:
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
    if len(data) > _MAX_BYTES:
        raise unprocessable("image_too_large", "Image trop lourde", {"maxBytes": _MAX_BYTES})

    media = Media(account_id=account.id, data=data, content_type=content_type)
    db.add(media)
    db.commit()
    return {"id": media.id, "url": f"/media/{media.id}"}


@router.get("/{media_id}")
async def read_media(
    media_id: str,
    db: Session = Depends(get_db),
    _: Account = Depends(current_account),
) -> Response:
    media = db.get(Media, media_id)
    if media is None:
        raise not_found("Image inconnue")
    return Response(content=media.data, media_type=media.content_type)

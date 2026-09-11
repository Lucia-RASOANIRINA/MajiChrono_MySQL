"""Le compte de la session courante."""

from __future__ import annotations

import base64
import binascii
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request, Response
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.deps import current_account
from app.core.errors import conflict, forbidden, not_found, unprocessable
from app.db import get_db
from app.models import Account, Avatar, KycStatus, UserRole

router = APIRouter(tags=["me"])

# Une photo de profil compressee tient largement sous 700 Ko. Au-dela, on refuse
# plutot que d'engraisser la base : l'application redimensionne avant d'envoyer.
_MAX_AVATAR_BYTES = 700 * 1024
_ALLOWED_AVATAR_TYPES = {"image/jpeg", "image/png", "image/webp"}


class PatchMe(BaseModel):
    role: str | None = None
    firstName: str | None = None
    lastName: str | None = None
    displayName: str | None = None


class AvatarUpload(BaseModel):
    imageBase64: str
    contentType: str


def _avatar_url(request: Request, account_id: str, version: datetime) -> str:
    # URL absolue + version : la balise image du mobile la charge telle quelle,
    # et le `?v=` casse le cache des qu'une nouvelle photo est posee.
    base = str(request.base_url).rstrip("/")
    return f"{base}/accounts/{account_id}/avatar?v={int(version.timestamp())}"


@router.get("/me")
async def read_me(account: Account = Depends(current_account)) -> dict:
    return account.to_json()


@router.patch("/me")
async def patch_me(
    body: PatchMe,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    if body.role is not None:
        # Le role d'exploitation est attribue **cote serveur uniquement**
        # (EXI-T02). Une application qui le reclame doit etre refusee, pas
        # ignoree : ignorer laisserait croire que la demande a abouti.
        if body.role == UserRole.admin.value:
            raise forbidden(
                "role_not_assignable",
                "Le role administrateur est attribue cote serveur",
            )
        if body.role not in (UserRole.client.value, UserRole.driver.value):
            raise unprocessable("invalid_role", "Role inconnu")

        # Le profil ne se choisit qu'une fois : en changer changerait la nature
        # du compte et l'historique qui s'y rattache.
        if account.role is not None and account.role.value != body.role:
            raise conflict("role_already_set", "Profil deja defini")

        account.role = UserRole(body.role)
        if account.role is UserRole.driver and account.kyc_status is None:
            account.kyc_status = KycStatus.draft

    # Prenom / nom : on met a jour ce qui est fourni, puis on recompose le nom
    # d'usage. Le detail (prenom, nom) prime sur `displayName` envoye seul, qui
    # ne subsiste que pour l'ancien parcours et les tests.
    if body.firstName is not None or body.lastName is not None:
        if body.firstName is not None:
            account.first_name = body.firstName.strip() or None
        if body.lastName is not None:
            account.last_name = body.lastName.strip() or None
        account.display_name = " ".join(
            part
            for part in (account.first_name, account.last_name)
            if part
        ).strip()
    elif body.displayName is not None:
        account.display_name = body.displayName

    db.commit()
    return account.to_json()


@router.post("/me/avatar")
async def upload_avatar(
    body: AvatarUpload,
    request: Request,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    """Pose (ou remplace) la photo de profil du compte connecte.

    La photo est rangee **en base** et non sur le disque : celui d'un plan
    gratuit est ephemere et l'effacerait au premier redeploiement. On recoit
    l'image en base64 (le reste de l'API est en JSON, on ne monte pas une
    gestion de multipart pour une seule route), on la borne, puis on pointe
    `avatarUrl` sur la route de lecture.
    """
    content_type = body.contentType.strip().lower()
    if content_type not in _ALLOWED_AVATAR_TYPES:
        raise unprocessable("unsupported_type", "Format d'image non accepte")

    raw = body.imageBase64
    # Tolere un prefixe « data:image/...;base64, » colle par certains encodeurs.
    if "," in raw and raw.strip().startswith("data:"):
        raw = raw.split(",", 1)[1]
    try:
        data = base64.b64decode(raw, validate=True)
    except (binascii.Error, ValueError):
        raise unprocessable("invalid_image", "Image illisible") from None

    if not data:
        raise unprocessable("invalid_image", "Image vide")
    if len(data) > _MAX_AVATAR_BYTES:
        raise unprocessable(
            "image_too_large",
            "Image trop lourde",
            {"maxBytes": _MAX_AVATAR_BYTES},
        )

    now = datetime.now(timezone.utc)
    avatar = db.get(Avatar, account.id)
    if avatar is None:
        avatar = Avatar(account_id=account.id)
        db.add(avatar)
    avatar.data = data
    avatar.content_type = content_type
    avatar.updated_at = now

    account.avatar_url = _avatar_url(request, account.id, now)
    db.commit()
    return account.to_json()


@router.delete("/me/avatar")
async def delete_avatar(
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    avatar = db.get(Avatar, account.id)
    if avatar is not None:
        db.delete(avatar)
    account.avatar_url = None
    db.commit()
    return account.to_json()


@router.get("/accounts/{account_id}/avatar")
async def read_avatar(account_id: str, db: Session = Depends(get_db)) -> Response:
    """Sert l'image. Volontairement **sans jeton** : la balise image du mobile
    ne peut pas porter d'en-tete d'authentification, et un avatar n'est pas un
    secret. Le chemin est un identifiant opaque, non enumerable en pratique."""
    avatar = db.get(Avatar, account_id)
    if avatar is None:
        raise not_found("Aucune photo pour ce compte")
    return Response(
        content=avatar.data,
        media_type=avatar.content_type,
        headers={"Cache-Control": "public, max-age=86400"},
    )

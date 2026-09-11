"""Empreintes, jetons, et le vocabulaire d'erreur attendu par le mobile."""

from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.config import get_settings


def hash_secret(value: str) -> str:
    """Empreinte compatible avec le site PHP (bcrypt ``$2y$``)."""
    hashed = bcrypt.hashpw(value.encode("utf-8"), bcrypt.gensalt(rounds=10))
    return hashed.decode("ascii").replace("$2b$", "$2y$", 1)


def verify_secret(hashed: str, value: str) -> bool:
    """Verifie une empreinte sans jamais lever pour un simple echec.

    PHP produit souvent le prefixe ``$2y$`` alors que Python utilise ``$2b$``.
    Les deux formats bcrypt sont verifies avec le meme algorithme.
    """
    try:
        normalized = hashed.replace("$2y$", "$2b$", 1)
        return bcrypt.checkpw(value.encode("utf-8"), normalized.encode("ascii"))
    except (ValueError, TypeError):
        return False


def new_numeric_code(digits: int = 6) -> str:
    """Code a usage unique, tire d'une source cryptographique.

    `secrets` et non `random` : le second est previsible a partir de quelques
    tirages, ce qui suffirait a deviner le code d'un autre.
    """
    upper = 10**digits
    return str(secrets.randbelow(upper)).zfill(digits)


def new_opaque_token() -> str:
    return secrets.token_urlsafe(48)


def issue_access_token(
    account_id: str, role: str | None, family: str | None = None
) -> tuple[str, datetime]:
    settings = get_settings()
    expires = datetime.now(timezone.utc) + timedelta(minutes=settings.access_ttl_minutes)
    payload = {
        "sub": str(account_id),
        "role": role,
        "typ": "access",
        # Famille de la session courante : permet a la liste des sessions de
        # marquer « cet appareil-ci » sans le confondre avec les autres.
        "fam": family,
        "exp": expires,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256"), expires


def read_access_token(token: str) -> dict | None:
    """Rend les revendications, ou `None` si le jeton ne vaut rien.

    Toute anomalie — signature, expiration, format — donne le meme resultat :
    l'appelant n'a pas a distinguer un jeton expire d'un jeton forge, et le lui
    dire renseignerait un attaquant.
    """
    settings = get_settings()
    try:
        claims = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except jwt.PyJWTError:
        return None
    return claims if claims.get("typ") == "access" else None

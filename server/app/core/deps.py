"""Dependances communes : session courante, roles, idempotence."""

from __future__ import annotations

import json

from fastapi import Depends, Header, Request
from sqlalchemy.orm import Session

from app.core.errors import ApiError, forbidden, unauthorized
from app.core.security import read_access_token
from app.db import get_db
from app.models import Account, DriverState, IdempotencyRecord, UserRole


def current_account(
    db: Session = Depends(get_db),
    authorization: str | None = Header(default=None),
) -> Account:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise unauthorized()

    claims = read_access_token(authorization[7:].strip())
    if claims is None:
        raise unauthorized()

    subject = claims.get("sub")
    try:
        account_id = int(subject)
    except (TypeError, ValueError):
        raise unauthorized()
    account = db.get(Account, account_id)
    if account is None:
        raise unauthorized()
    if account.role is UserRole.driver and account.kyc_status is None:
        driver = db.get(DriverState, account.id)
        if driver is not None and driver.kyc_status:
            try:
                account.kyc_status = driver.kyc_status
            except ValueError:
                pass

    # Un compte suspendu garde un jeton valide jusqu'a son expiration. On le
    # refuse ici plutot que d'attendre quinze minutes : une suspension decidee
    # par l'exploitation doit prendre effet a la requete suivante.
    if account.suspended_at is not None:
        raise forbidden("account_suspended", "Compte suspendu")

    return account


def require_role(*roles: UserRole):
    """Restreint une route a certains profils.

    Le controle est fait a partir du **compte en base**, jamais de la
    revendication du jeton : un role change par l'exploitation doit s'appliquer
    sans attendre que le porteur rafraichisse sa session.
    """

    def dependency(account: Account = Depends(current_account)) -> Account:
        if account.is_admin and UserRole.admin in roles:
            return account
        if account.role not in roles:
            raise forbidden("role_forbidden", "Profil non autorise")
        return account

    return dependency


class Idempotency:
    """Rejoue la reponse d'une cle deja traitee.

    Le mobile pose la cle **a l'enregistrement** de l'action et ne la regenere
    jamais, y compris apres un redemarrage. C'est ce qui garantit qu'une reprise
    de synchronisation ne cree pas une seconde course, un second debit ou un
    second constat (EXI-B01, EXI-S01).
    """

    def __init__(self, db: Session, key: str | None, endpoint: str, account_id: str | None):
        self.db = db
        self.key = key
        self.endpoint = endpoint
        self.account_id = account_id

    def replay(self) -> tuple[int, dict] | None:
        if not self.key:
            return None
        record = self.db.get(IdempotencyRecord, self.key)
        if record is None:
            return None
        if record.endpoint != self.endpoint:
            # Meme cle sur une autre route : c'est une erreur d'appelant, pas
            # une reprise. La signaler evite de rendre une reponse qui n'a rien
            # a voir avec la demande.
            raise ApiError(422, "idempotency_key_reused", "Cle deja utilisee ailleurs")
        return record.status_code, json.loads(record.response_json)

    def remember(self, status_code: int, body: dict) -> None:
        if not self.key:
            return
        self.db.add(
            IdempotencyRecord(
                key=self.key,
                account_id=self.account_id,
                endpoint=self.endpoint,
                status_code=status_code,
                response_json=json.dumps(body),
            )
        )
        self.db.commit()


def idempotency(endpoint: str):
    def dependency(
        request: Request,
        db: Session = Depends(get_db),
        idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    ) -> Idempotency:
        claims = None
        authorization = request.headers.get("authorization")
        if authorization and authorization.lower().startswith("bearer "):
            claims = read_access_token(authorization[7:].strip())
        return Idempotency(db, idempotency_key, endpoint, claims.get("sub") if claims else None)

    return dependency

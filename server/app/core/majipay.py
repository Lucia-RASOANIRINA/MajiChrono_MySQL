"""Passerelle vers MajiPay, le prestataire de paiement qui tient les soldes.

Le partage des roles est le meme que celui porte par le mobile (§11.2) :
**MajiPay tient les soldes et execute les mouvements**, MajiChrono ne fait
qu'arbitrer. Trois operations suffisent a tout le parcours :

  - `balance`  : lire le solde disponible d'un compte ;
  - `transfer` : deplacer un montant d'un compte a un autre (le paiement) ;
  - `withdraw` : sortir un montant vers un moyen externe (le **retrait**).

Deux implementations partagent ce contrat. `HttpMajiPay` parle au vrai
prestataire des que `MAJIPAY_API_KEY` est renseignee. Sans cle, `SandboxMajiPay`
prend le relais : il tient des soldes fictifs en base, deplace de l'argent pour
de faux et rend des recus credibles. C'est ce qui permet de developper et de
tester le parcours de bout en bout avant que le vrai MajiPay n'existe (EXI-MP12),
et de verifier que le mobile ne peut jamais debiter seul.

Rien ici ne journalise un montant, un solde, un jeton ni un numero de compte
(EXI-MP11). Les traces se limitent a l'operation et a son issue.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Protocol

import httpx
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import Account, MajiPaySandboxAccount, MajiPaySandboxTxn, UserRole

logger = logging.getLogger("majichrono.majipay")

# Point d'entree du prestataire. En clair car ce n'est pas un secret : seule la
# cle en est un.
MAJIPAY_URL = "https://api.majipay.mg/v1"

# Soldes de depart du bac a sable, par role. Assez pour regler quelques courses
# cote client, une recette de journee cote livreur — de quoi demontrer le
# parcours sans avoir a recharger.
_SANDBOX_SEED = {UserRole.client: 42000, UserRole.driver: 18500}


class MajiPayError(Exception):
    """Refus du prestataire, rendu tel quel a l'utilisateur.

    Le `failure` reprend le vocabulaire du mobile (`insufficient_funds`,
    `unavailable`, `declined`) pour que l'ecran sache proposer le bon repli —
    en pratique, presque toujours les especes (EXI-MP08).
    """

    def __init__(self, failure: str, message: str) -> None:
        super().__init__(message)
        self.failure = failure
        self.message = message


@dataclass(frozen=True)
class Balance:
    available_ariary: int
    # Reference masquee, du type `MP ** ** 4821`. Le numero complet n'a aucune
    # raison de transiter (EXI-MP11).
    account_ref: str


@dataclass(frozen=True)
class Receipt:
    ref: str


class MajiPayGateway(Protocol):
    def balance(self, account: Account) -> Balance: ...

    def transfer(
        self, payer: Account, payee: Account, amount: int, idem_key: str
    ) -> Receipt: ...

    def withdraw(
        self, account: Account, amount: int, destination: str, idem_key: str
    ) -> Receipt: ...


class SandboxMajiPay:
    """MajiPay simule, adosse a deux tables de bac a sable.

    Il provisionne un compte a sa premiere apparition (solde selon le role),
    deplace de l'argent entre deux lignes, et refuse un solde insuffisant. Son
    idempotence est stricte : la meme cle rend le meme recu sans rejouer le
    mouvement.
    """

    def __init__(self, db: Session) -> None:
        self._db = db

    def _account(self, account: Account) -> MajiPaySandboxAccount:
        row = self._db.get(MajiPaySandboxAccount, account.id)
        if row is None:
            row = MajiPaySandboxAccount(
                account_id=account.id,
                balance_ariary=_SANDBOX_SEED.get(account.role, 0),
                account_ref=_mask(account.phone),
            )
            self._db.add(row)
            self._db.flush()
        return row

    def balance(self, account: Account) -> Balance:
        row = self._account(account)
        return Balance(available_ariary=row.balance_ariary, account_ref=row.account_ref)

    def _replay(self, idem_key: str) -> Receipt | None:
        txn = self._db.get(MajiPaySandboxTxn, idem_key)
        return Receipt(ref=txn.receipt_ref) if txn else None

    def _remember(self, idem_key: str, ref: str) -> Receipt:
        self._db.add(MajiPaySandboxTxn(idem_key=idem_key, receipt_ref=ref))
        return Receipt(ref=ref)

    def transfer(
        self, payer: Account, payee: Account, amount: int, idem_key: str
    ) -> Receipt:
        replayed = self._replay(idem_key)
        if replayed is not None:
            return replayed

        payer_row = self._account(payer)
        payee_row = self._account(payee)
        if payer_row.balance_ariary < amount:
            raise MajiPayError("insufficient_funds", "Solde MajiPay insuffisant")

        payer_row.balance_ariary -= amount
        payee_row.balance_ariary += amount
        logger.info("majipay transfert ok")
        return self._remember(idem_key, f"MP-{idem_key[-12:]}")

    def withdraw(
        self, account: Account, amount: int, destination: str, idem_key: str
    ) -> Receipt:
        replayed = self._replay(idem_key)
        if replayed is not None:
            return replayed

        if amount <= 0:
            raise MajiPayError("declined", "Montant de retrait invalide")

        row = self._account(account)
        if row.balance_ariary < amount:
            raise MajiPayError("insufficient_funds", "Solde MajiPay insuffisant")

        row.balance_ariary -= amount
        logger.info("majipay retrait ok")
        return self._remember(idem_key, f"WD-{idem_key[-12:]}")


class HttpMajiPay:
    """MajiPay reel, joignable par HTTP des que la cle est renseignee.

    Le corps de chaque appel porte la cle d'idempotence : c'est le prestataire,
    et non nous, qui garantit en dernier ressort qu'un mouvement ne part pas deux
    fois. On lui fait confiance sur ce point comme on le ferait a une banque.
    """

    def __init__(self, api_key: str) -> None:
        self._headers = {
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json",
        }

    def _post(self, path: str, payload: dict) -> dict:
        with httpx.Client(timeout=20) as client:
            response = client.post(
                f"{MAJIPAY_URL}{path}", json=payload, headers=self._headers
            )
        if response.status_code == 402:
            raise MajiPayError("insufficient_funds", "Solde MajiPay insuffisant")
        if response.status_code >= 400:
            logger.error("majipay refuse status=%s", response.status_code)
            raise MajiPayError("unavailable", "MajiPay indisponible")
        return response.json()

    def balance(self, account: Account) -> Balance:
        with httpx.Client(timeout=20) as client:
            response = client.get(
                f"{MAJIPAY_URL}/accounts/{account.id}/balance", headers=self._headers
            )
        if response.status_code >= 400:
            raise MajiPayError("unavailable", "MajiPay indisponible")
        data = response.json()
        return Balance(
            available_ariary=int(data.get("available", 0)),
            account_ref=str(data.get("accountRef", "")),
        )

    def transfer(
        self, payer: Account, payee: Account, amount: int, idem_key: str
    ) -> Receipt:
        data = self._post(
            "/transfers",
            {
                "from": payer.id,
                "to": payee.id,
                "amount": amount,
                "idempotencyKey": idem_key,
            },
        )
        return Receipt(ref=str(data.get("receiptRef", f"MP-{idem_key[-12:]}")))

    def withdraw(
        self, account: Account, amount: int, destination: str, idem_key: str
    ) -> Receipt:
        data = self._post(
            "/withdrawals",
            {
                "account": account.id,
                "amount": amount,
                "destination": destination,
                "idempotencyKey": idem_key,
            },
        )
        return Receipt(ref=str(data.get("receiptRef", f"WD-{idem_key[-12:]}")))


def get_gateway(db: Session) -> MajiPayGateway:
    """Retourne uniquement le bac à sable jusqu'à validation du vrai MajiPay."""
    if get_settings().majipay_api_key:
        logger.warning(
            "MajiPay réel à venir — clé ignorée, paiement sandbox utilisé"
        )
    return SandboxMajiPay(db)


def _mask(phone: str) -> str:
    """`+261340000001` devient `MP ** ** 0001` (EXI-MP11)."""
    return f"MP ** ** {phone[-4:]}" if len(phone) >= 4 else "MP ** ** ****"

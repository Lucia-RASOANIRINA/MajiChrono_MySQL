"""Paiement par code QR, adosse aux soldes MajiPay (§11.2).

Le mobile conduit le parcours ; **MajiPay tient l'argent**. Une regle domine
tout le reste et elle est portee par le code, pas par la documentation :
**scanner n'autorise jamais un debit**. Le scan ne fait qu'apparier deux
appareils. Celui qui paie confirme toujours sur son propre telephone. Sans cette
regle, quiconque scanne un code affiche par un tiers pourrait se servir.

Trois refus font l'essentiel de la valeur de ce routeur :

  - un jeton faux ou perime n'apparie rien ;
  - une confirmation qui ne vient pas du payeur est rejetee ;
  - une intention deja capturee n'est jamais debitee deux fois (EXI-MP06).

Payeur et beneficiaire sont **derives de la course** — expediteur et livreur
assigne — jamais d'un champ du mobile : c'est ce qui empeche un beneficiaire de
se payer lui-meme.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.deps import Idempotency, current_account, idempotency
from app.core.errors import ApiError, conflict, forbidden, not_found, unprocessable
from app.core.majipay import MajiPayError, get_gateway
from app.core.security import hash_secret, new_opaque_token, verify_secret
from app.db import get_db
from app.models import (
    Account,
    Delivery,
    PaymentDirection,
    PaymentIntent,
    PaymentStatus,
    UserRole,
)

router = APIRouter(prefix="/payments", tags=["payment"])

# Duree de validite d'un code : assez pour tendre un telephone et scanner, trop
# courte pour qu'un code oublie sur un comptoir serve une heure plus tard.
INTENT_LIFETIME = timedelta(minutes=5)


def _now() -> datetime:
    return datetime.now(timezone.utc)


class CreateIntent(BaseModel):
    deliveryId: int
    amount: int
    direction: str = PaymentDirection.collect.value
    # Le mobile transmet un role par commodite, mais le serveur ne s'y fie
    # jamais pour l'identite : elle vient du jeton et de la course.
    role: str | None = None


class ClaimBody(BaseModel):
    token: str


class ConfirmBody(BaseModel):
    role: str | None = None


class WithdrawBody(BaseModel):
    amount: int
    # Vers ou l'argent sort : un numero Mobile Money, un compte. Opaque cote
    # serveur, c'est MajiPay qui l'interprete.
    destination: str = ""


def _expire_if_needed(db: Session, intent: PaymentIntent) -> bool:
    """Perime une intention en vol dont le code a expire. Retourne vrai si oui."""
    if intent.is_final:
        return False
    if not intent.is_expired:
        return False
    intent.status = PaymentStatus.failed
    intent.failure = "expired"
    db.commit()
    return True


def _settle(db: Session, intent: PaymentIntent) -> dict:
    """Deplace l'argent chez MajiPay, une seule fois par intention.

    C'est le seul endroit ou un solde bouge. Le garde-fou est double : l'etat
    `captured` bloque un second passage cote MajiChrono, et la cle
    `settle_<id>` bloque un second mouvement cote MajiPay. L'un tient si l'autre
    est contourne.
    """
    if intent.status == PaymentStatus.captured:
        return intent.to_json()

    payer = db.get(Account, intent.payer_id)
    payee = db.get(Account, intent.payee_id)
    gateway = get_gateway(db)

    try:
        receipt = gateway.transfer(
            payer, payee, intent.amount_ariary, idem_key=f"settle_{intent.id}"
        )
    except MajiPayError as exc:
        intent.status = PaymentStatus.failed
        intent.failure = exc.failure
        db.commit()
        # 422 plutot que 500 : un solde insuffisant n'est pas une panne, c'est
        # une reponse. L'ecran propose alors le repli especes (EXI-MP08).
        raise unprocessable(exc.failure, exc.message, {"failure": exc.failure})

    intent.status = PaymentStatus.captured
    intent.captured_at = _now()
    intent.receipt_ref = receipt.ref
    db.commit()
    return intent.to_json()


@router.get("/balance")
async def balance(
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    """Solde MajiPay du compte courant.

    Il est **lu**, jamais recopie : MajiPay en est la source de verite. Un solde
    mis en cache afficherait un montant faux au moment de payer.
    """
    result = get_gateway(db).balance(account)
    db.commit()  # le bac a sable a pu provisionner la ligne du compte
    return {
        "available": result.available_ariary,
        "accountRef": result.account_ref,
        "fetchedAt": _now().isoformat(),
    }


@router.get("/history")
async def history(
    limit: int = 50,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    """Historique des paiements du compte courant (§11, EXI-C39).

    On rend les intentions ou le compte est **payeur ou beneficiaire**, les plus
    recentes d'abord. C'est le journal que le client consulte pour retrouver un
    paiement, et le livreur pour rapprocher ses encaissements. Les intentions
    encore en vol (`pending`) en font partie : un paiement en cours a autant sa
    place dans le journal qu'un paiement solde.
    """
    capped = max(1, min(limit, 100))
    rows = (
        db.query(PaymentIntent)
        .filter(
            (PaymentIntent.payer_id == account.id)
            | (PaymentIntent.payee_id == account.id)
        )
        .order_by(PaymentIntent.created_at.desc())
        .limit(capped)
        .all()
    )
    # `role` dit au mobile de quel cote de la transaction il se trouve, sans lui
    # faire deviner en comparant des identifiants.
    items = []
    for intent in rows:
        data = intent.to_json()
        data["role"] = "payer" if intent.payer_id == account.id else "payee"
        items.append(data)
    return {"items": items}


@router.post("/intent", status_code=201)
async def create_intent(
    body: CreateIntent,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /payments/intent")),
) -> dict:
    replayed = idem.replay()
    if replayed is not None:
        # Meme cle rejouee : on rend l'intention deja creee, jeton compris. Le
        # demandeur retrouve son code au lieu d'en obtenir un second, qui
        # resterait encaissable en parallele (EXI-MP06).
        return replayed[1]

    if body.amount <= 0:
        raise unprocessable("invalid_amount", "Montant invalide")

    direction = PaymentDirection(
        body.direction if body.direction in PaymentDirection._value2member_map_ else "collect"
    )

    delivery = db.get(Delivery, body.deliveryId)
    if delivery is None:
        raise not_found("Course inconnue")
    if delivery.driver_id is None:
        # Sans livreur assigne, il n'y a personne a payer. On refuse plutot que
        # de creer une intention orpheline.
        raise unprocessable("no_driver", "Aucun livreur assigne a cette course")

    payer_id, payee_id = delivery.client_id, delivery.driver_id
    if account.id not in (payer_id, payee_id):
        raise forbidden("not_a_party", "Course etrangere au compte")

    # Le sens dit qui presente le code : le livreur pour une demande
    # d'encaissement, le client pour une offre deja pre-autorisee.
    presenter = payee_id if direction == PaymentDirection.collect else payer_id
    if account.id != presenter:
        raise forbidden("wrong_presenter", "Ce n'est pas a ce compte de presenter le code")

    # Une offre est pre-autorisee par le client : on verifie le solde des la
    # creation, pour ne pas afficher un code que personne ne pourra encaisser.
    if direction == PaymentDirection.offer:
        payer = db.get(Account, payer_id)
        if get_gateway(db).balance(payer).available_ariary < body.amount:
            db.commit()
            raise unprocessable(
                "insufficient_funds",
                "Solde MajiPay insuffisant",
                {"failure": "insufficient_funds"},
            )

    token = new_opaque_token()
    intent = PaymentIntent(
        delivery_id=delivery.id,
        payer_id=payer_id,
        payee_id=payee_id,
        amount_ariary=body.amount,
        direction=direction,
        status=PaymentStatus.pending,
        token_hash=hash_secret(token),
        expires_at=_now() + INTENT_LIFETIME,
    )
    db.add(intent)
    db.commit()

    # Le jeton en clair ne sort qu'ici, et seulement a celui qui presente le
    # code. Il n'est jamais journalise (EXI-MP11).
    payload = {**intent.to_json(), "token": token}
    idem.remember(201, payload)
    return payload


@router.get("/{intent_id}")
async def read_intent(
    intent_id: str,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    intent = db.get(PaymentIntent, intent_id)
    if intent is None:
        raise not_found("Intention inconnue")
    if account.id not in (intent.payer_id, intent.payee_id):
        raise forbidden("not_a_party", "Intention etrangere au compte")
    _expire_if_needed(db, intent)
    return intent.to_json()


@router.post("/{intent_id}/claim")
async def claim(
    intent_id: str,
    body: ClaimBody,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /payments/claim")),
) -> dict:
    replayed = idem.replay()
    if replayed is not None:
        return replayed[1]

    intent = db.get(PaymentIntent, intent_id)
    if intent is None:
        raise not_found("Intention inconnue")

    # Le jeton est la seule preuve que le scanneur avait le code sous les yeux.
    # On le verifie avant tout le reste : un code faux ne doit rien apprendre.
    if not verify_secret(intent.token_hash, body.token):
        raise forbidden("bad_token", "Code invalide")

    if _expire_if_needed(db, intent):
        raise ApiError(410, "expired", "Code expire", {"failure": "expired"})

    if intent.is_final:
        # Rejouer un scan sur une intention deja reglee ne redebite rien : on
        # rend l'etat tel quel (EXI-MP06).
        return intent.to_json()

    intent.status = PaymentStatus.claimed
    db.commit()

    # Pour une offre, le payeur a deja donne son accord : la capture suit
    # immediatement. Pour une demande, on s'arrete la — le payeur devra
    # confirmer sur son propre telephone.
    if intent.direction == PaymentDirection.offer:
        body_out = _settle(db, intent)
    else:
        body_out = intent.to_json()

    idem.remember(200, body_out)
    return body_out


@router.post("/{intent_id}/confirm")
async def confirm(
    intent_id: str,
    body: ConfirmBody,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /payments/confirm")),
) -> dict:
    replayed = idem.replay()
    if replayed is not None:
        return replayed[1]

    intent = db.get(PaymentIntent, intent_id)
    if intent is None:
        raise not_found("Intention inconnue")

    # Seul le payeur fait bouger l'argent. Le controle porte sur le compte en
    # base, pas sur un champ du corps : un beneficiaire ne peut pas se payer
    # lui-meme, meme si le mobile le lui demandait.
    if account.id != intent.payer_id:
        raise forbidden("not_payer", "Seul le payeur peut confirmer")

    if _expire_if_needed(db, intent):
        raise ApiError(410, "expired", "Code expire", {"failure": "expired"})

    body_out = _settle(db, intent)
    idem.remember(200, body_out)
    return body_out


@router.post("/{intent_id}/cash")
async def fallback_cash(
    intent_id: str,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /payments/cash")),
) -> dict:
    replayed = idem.replay()
    if replayed is not None:
        return replayed[1]

    intent = db.get(PaymentIntent, intent_id)
    if intent is None:
        raise not_found("Intention inconnue")
    if account.id not in (intent.payer_id, intent.payee_id):
        raise forbidden("not_a_party", "Intention etrangere au compte")

    # Deja regle par MajiPay : on ne repasse pas en especes ce qui a ete debite,
    # sinon la course serait payee deux fois.
    if intent.status == PaymentStatus.captured:
        raise conflict(
            "already_captured",
            "Deja regle par MajiPay",
            {"currentState": PaymentStatus.captured.value},
        )

    intent.status = PaymentStatus.cash
    intent.captured_at = _now()
    intent.receipt_ref = f"ESP-{intent.id}"
    db.commit()

    body_out = intent.to_json()
    idem.remember(200, body_out)
    return body_out


@router.post("/withdraw")
async def withdraw(
    body: WithdrawBody,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
    idem: Idempotency = Depends(idempotency("POST /payments/withdraw")),
) -> dict:
    """Retrait du solde MajiPay vers un moyen externe (le retrait, EXI-MP09).

    Le processus vit dans MajiChrono ; la sortie d'argent, elle, se fait chez
    MajiPay. On ne fait que la declencher et en rendre le recu. Reserve au
    livreur : c'est lui qui accumule des recettes a sortir.
    """
    replayed = idem.replay()
    if replayed is not None:
        return replayed[1]

    if account.role is not UserRole.driver:
        raise forbidden("role_forbidden", "Seul un livreur peut retirer ses gains")
    if body.amount <= 0:
        raise unprocessable("invalid_amount", "Montant de retrait invalide")

    # La cle vient de l'en-tete d'idempotence, jamais du montant : deux retraits
    # legitimes du meme montant sont deux operations distinctes, pas un doublon.
    # A defaut d'en-tete, une cle aleatoire garantit qu'on ne dedoublonne rien.
    idem_key = f"withdraw_{idem.key}" if idem.key else f"withdraw_{new_opaque_token()}"

    gateway = get_gateway(db)
    try:
        receipt = gateway.withdraw(
            account, body.amount, body.destination, idem_key=idem_key
        )
    except MajiPayError as exc:
        db.commit()
        raise unprocessable(exc.failure, exc.message, {"failure": exc.failure})

    remaining = gateway.balance(account)
    db.commit()

    body_out = {
        "receiptRef": receipt.ref,
        "amount": body.amount,
        "available": remaining.available_ariary,
        "accountRef": remaining.account_ref,
        "withdrawnAt": _now().isoformat(),
    }
    idem.remember(200, body_out)
    return body_out

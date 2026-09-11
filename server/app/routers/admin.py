"""Exploitation : tableau de bord, flotte, dossiers, suspensions.

Une regle traverse ce fichier : **une decision qui touche le gagne-pain de
quelqu'un exige un motif ecrit**. Refuser un dossier, suspendre un livreur —
ces gestes se justifient, et le motif est stocke avec la decision. Ce n'est pas
une politesse : c'est ce qui permet de repondre a un livreur qui demande
pourquoi il ne peut plus travailler, six mois plus tard.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.deps import require_role
from app.core.errors import not_found, unprocessable
from app.db import get_db
from app.models import (
    DELIVERED_STATES,
    KYC_KINDS,
    Account,
    Delivery,
    DeliveryEvent,
    DeliveryIncident,
    DeliveryStatus,
    Dispute,
    DriverState,
    KycDocument,
    KycMessage,
    KycStatus,
    ModerationLog,
    UserRole,
    as_utc,
)

router = APIRouter(prefix="/admin", tags=["admin"])

# Longueur minimale d'un motif. Dix caracteres n'empechent pas d'ecrire « ok »
# suivi de huit espaces, mais ils empechent le champ vide — et c'est le champ
# vide qui rend une decision inexplicable des le lendemain.
MIN_REASON_LENGTH = 10

POSITION_FRESHNESS = timedelta(minutes=3)


class Review(BaseModel):
    approve: bool
    reason: str


class Suspension(BaseModel):
    suspend: bool
    reason: str


def _require_reason(reason: str) -> str:
    cleaned = reason.strip()
    if len(cleaned) < MIN_REASON_LENGTH:
        raise unprocessable(
            "reason_too_short",
            "Un motif d'au moins dix caracteres est exige",
            {"minLength": MIN_REASON_LENGTH},
        )
    return cleaned


@router.get("/dashboard")
async def dashboard(
    db: Session = Depends(get_db), _: Account = Depends(require_role(UserRole.admin))
) -> dict:
    def compter(*conditions) -> int:
        return db.scalar(select(func.count()).select_from(Delivery).where(*conditions)) or 0

    actives = [
        DeliveryStatus.assigned,
        DeliveryStatus.at_pickup,
        DeliveryStatus.picked_up,
        DeliveryStatus.in_transit,
        DeliveryStatus.at_destination,
    ]
    today = datetime.now(timezone.utc).date()

    delivered = db.scalars(
        select(Delivery).where(Delivery.status.in_(DELIVERED_STATES))
    ).all()

    def compter_comptes(*conditions) -> int:
        return db.scalar(select(func.count()).select_from(Account).where(*conditions)) or 0

    return {
        "pendingKyc": compter_comptes(Account.kyc_status == KycStatus.submitted),
        "activeDeliveries": compter(Delivery.status.in_(actives)),
        "pendingDeliveries": compter(Delivery.status == DeliveryStatus.pending),
        "onlineDrivers": db.scalar(
            select(func.count()).select_from(DriverState).where(DriverState.online.is_(True))
        )
        or 0,
        # Effectifs : combien de clients, combien de livreurs. Le tableau de bord
        # les affiche pour donner la taille du reseau d'un coup d'oeil.
        "totalClients": compter_comptes(Account.role == UserRole.client),
        "totalDrivers": compter_comptes(Account.role == UserRole.driver),
        # Litiges ouverts et incidents non resolus : ce qui attend l'exploitation.
        # Calcules ici cote serveur (le simulateur les fournissait deja).
        "openDisputes": db.scalar(
            select(func.count())
            .select_from(Dispute)
            .where(Dispute.status.in_(["open", "investigating"]))
        )
        or 0,
        "openIncidents": db.scalar(
            select(func.count())
            .select_from(DeliveryIncident)
            .where(DeliveryIncident.resolution == "open")
        )
        or 0,
        # Recette du jour : seules les courses **remises**. Compter les courses
        # en cours gonflerait le chiffre d'affaires d'argent pas encore gagne.
        "revenueToday": sum(
            d.price_ariary or 0
            for d in delivered
            if as_utc(d.updated_at).date() == today
        ),
        "byStatus": {
            status.value: compter(Delivery.status == status) for status in DeliveryStatus
        },
    }


# Part reversee au livreur : le reste est la commission de la plateforme. Une
# constante ici, arbitrable plus tard sans toucher au calcul.
DRIVER_SHARE = 0.85


@router.get("/stats")
async def stats(
    db: Session = Depends(get_db), _: Account = Depends(require_role(UserRole.admin))
) -> dict:
    """Rapport d'activite (§13, EXI-A08) : volumes, taux, temps, zones, heures.

    Tout est calcule a la lecture, sur l'ensemble des courses. A l'echelle d'un
    tableau de bord d'exploitation, c'est suffisant et toujours juste ; on
    n'introduit pas de table d'agregats qui pourrait diverger de la realite.
    """
    import json as _json

    deliveries = db.scalars(select(Delivery)).all()
    total = len(deliveries)
    delivered = [d for d in deliveries if d.status in DELIVERED_STATES]
    cancelled = [d for d in deliveries if d.status == DeliveryStatus.cancelled]
    refused = [d for d in deliveries if d.status == DeliveryStatus.failed]

    done = len(delivered)
    failed = len(cancelled) + len(refused)
    # Taux de reussite : remis / (remis + echoue). Les courses encore en cours ne
    # comptent dans aucun des deux — juger une course non finie fausserait le ratio.
    settled = done + failed
    success_rate = round(done / settled, 3) if settled else 0.0
    cancellation_rate = round(len(cancelled) / total, 3) if total else 0.0

    revenue = sum(d.price_ariary or 0 for d in delivered)

    # Temps moyen de livraison : de la creation a l'evenement « livree ».
    delivered_ids = [d.id for d in delivered]
    durations: list[float] = []
    if delivered_ids:
        created_at = {d.id: as_utc(d.created_at) for d in delivered}
        events = db.scalars(
            select(DeliveryEvent).where(
                DeliveryEvent.delivery_id.in_(delivered_ids),
                DeliveryEvent.status.in_(DELIVERED_STATES),
            )
        ).all()
        seen: set[str] = set()
        for e in events:
            if e.delivery_id in seen:
                continue
            seen.add(e.delivery_id)
            start = created_at.get(e.delivery_id)
            if start is not None:
                durations.append((as_utc(e.occurred_at) - start).total_seconds() / 60)
    avg_minutes = round(sum(durations) / len(durations)) if durations else 0

    # Zones les plus actives : par libelle de destination.
    zones: dict[str, int] = {}
    hours = [0] * 24
    for d in deliveries:
        try:
            zone = (_json.loads(d.dropoff_json).get("summary") or "").strip()
        except Exception:  # noqa: BLE001
            zone = ""
        if zone:
            zones[zone] = zones.get(zone, 0) + 1
        hours[as_utc(d.created_at).hour] += 1
    top_zones = sorted(zones.items(), key=lambda kv: kv[1], reverse=True)[:5]

    # Performance des livreurs : nombre de courses remises, par livreur.
    per_driver: dict[str, int] = {}
    for d in delivered:
        if d.driver_id:
            per_driver[d.driver_id] = per_driver.get(d.driver_id, 0) + 1
    drivers: dict[str, Account] = {}
    if per_driver:
        drivers = {
            a.id: a
            for a in db.scalars(
                select(Account).where(Account.id.in_(list(per_driver)))
            ).all()
        }
    performance = sorted(per_driver.items(), key=lambda kv: kv[1], reverse=True)[:5]

    return {
        "totalDeliveries": total,
        "delivered": done,
        "cancelled": len(cancelled),
        "successRate": success_rate,
        "cancellationRate": cancellation_rate,
        "revenueAriary": revenue,
        "driverEarningsAriary": round(revenue * DRIVER_SHARE),
        "totalClients": db.scalar(
            select(func.count()).select_from(Account).where(Account.role == UserRole.client)
        )
        or 0,
        "totalDrivers": db.scalar(
            select(func.count()).select_from(Account).where(Account.role == UserRole.driver)
        )
        or 0,
        "avgDeliveryMinutes": avg_minutes,
        "incidents": db.scalar(select(func.count()).select_from(DeliveryIncident)) or 0,
        "disputes": db.scalar(select(func.count()).select_from(Dispute)) or 0,
        "topZones": [{"zone": z, "count": c} for z, c in top_zones],
        "peakHours": [{"hour": h, "count": hours[h]} for h in range(24)],
        "driverPerformance": [
            {
                "driverId": did,
                "displayName": drivers[did].display_name if did in drivers else "",
                "delivered": count,
                "rating": drivers[did].rating if did in drivers else None,
            }
            for did, count in performance
        ],
    }


@router.get("/fleet")
async def fleet(
    db: Session = Depends(get_db), _: Account = Depends(require_role(UserRole.admin))
) -> dict:
    """Les livreurs et leur derniere position connue.

    Chaque ligne porte `stale` : vrai quand la position a plus de trois minutes.
    Un point sur une carte qui ne dit pas son age est un mensonge — on croit
    voir ou est quelqu'un alors qu'on voit ou il etait.
    """
    now = datetime.now(timezone.utc)
    rows = db.execute(
        select(Account, DriverState)
        .join(DriverState, DriverState.account_id == Account.id, isouter=True)
        .where(Account.role == UserRole.driver)
    ).all()

    items = []
    for account, state in rows:
        fixed_at = as_utc(state.fixed_at) if state and state.fixed_at else None
        items.append(
            {
                "driverId": account.id,
                "displayName": account.display_name,
                "phone": account.phone,
                "kycStatus": account.kyc_status.value if account.kyc_status else None,
                "suspended": account.suspended_at is not None,
                "online": bool(state and state.online),
                "lat": state.lat if state else None,
                "lng": state.lng if state else None,
                "fixedAt": fixed_at.isoformat() if fixed_at else None,
                "stale": fixed_at is None or (now - fixed_at) > POSITION_FRESHNESS,
            }
        )
    return {"items": items}


@router.get("/kyc")
async def kyc_queue(
    db: Session = Depends(get_db), _: Account = Depends(require_role(UserRole.admin))
) -> dict:
    pending = db.scalars(
        select(Account)
        .where(
            Account.kyc_status.in_([KycStatus.submitted, KycStatus.under_review])
            | select(KycMessage.id)
            .where(
                KycMessage.account_id == Account.id,
                KycMessage.from_admin.is_(False),
            )
            .exists()
        )
        .order_by(Account.created_at)
    ).all()

    # Pieces fournies par livreur, en une seule requete plutot qu'une par
    # dossier : la file affiche la completude sans attendre.
    uploaded_by: dict[str, set[str]] = {}
    if pending:
        rows = db.execute(
            select(KycDocument.account_id, KycDocument.kind).where(
                KycDocument.account_id.in_([a.id for a in pending])
            )
        ).all()
        for account_id, kind in rows:
            uploaded_by.setdefault(account_id, set()).add(kind)

    return {
        "items": [
            {
                "driverId": a.id,
                "displayName": a.display_name,
                "phone": a.phone,
                "status": a.kyc_status.value,
                "submittedAt": as_utc(a.created_at).isoformat(),
                "documents": [
                    {
                        "code": kind,
                        "provided": kind in uploaded_by.get(a.id, set()),
                        "url": f"/accounts/{a.id}/kyc/{kind}",
                    }
                    for kind in KYC_KINDS
                ],
            }
            for a in pending
        ]
    }


@router.get("/kyc/{driver_id}/documents")
async def kyc_documents(
    driver_id: str,
    db: Session = Depends(get_db),
    _: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    """Pieces fournies par un livreur, pour que l'exploitation les examine avant
    de trancher. On rend le type de chaque piece et son URL de lecture (servie,
    jeton exige, par `/accounts/{id}/kyc/{kind}`)."""
    driver = db.get(Account, driver_id)
    if driver is None or driver.role is not UserRole.driver:
        raise not_found("Livreur inconnu")
    rows = db.scalars(
        select(KycDocument.kind).where(KycDocument.account_id == driver_id)
    ).all()
    return {
        "driverId": driver_id,
        "documents": [
            {"kind": kind, "url": f"/accounts/{driver_id}/kyc/{kind}"}
            for kind in rows
        ],
    }


class KycReplyBody(BaseModel):
    body: str


@router.get("/kyc/{driver_id}/messages")
async def kyc_thread(
    driver_id: str,
    db: Session = Depends(get_db),
    _: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    """Fil de suivi du dossier d'un livreur, cote exploitation."""
    driver = db.get(Account, driver_id)
    if driver is None or driver.role is not UserRole.driver:
        raise not_found("Livreur inconnu")
    rows = db.scalars(
        select(KycMessage)
        .where(KycMessage.account_id == driver_id)
        .order_by(KycMessage.created_at)
    ).all()
    return {"items": [m.to_json() for m in rows]}


@router.post("/kyc/{driver_id}/messages")
async def kyc_reply(
    driver_id: str,
    body: KycReplyBody,
    db: Session = Depends(get_db),
    _: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    """L'exploitation repond au livreur sur le suivi de son dossier."""
    driver = db.get(Account, driver_id)
    if driver is None or driver.role is not UserRole.driver:
        raise not_found("Livreur inconnu")
    text = body.body.strip()
    if not text:
        raise unprocessable("empty_message", "Message vide")
    message = KycMessage(account_id=driver_id, from_admin=True, body=text)
    db.add(message)
    db.commit()
    db.refresh(message)
    return message.to_json()


@router.post("/kyc/{driver_id}/review")
async def review_kyc(
    driver_id: str,
    body: Review,
    db: Session = Depends(get_db),
    admin: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    reason = _require_reason(body.reason)

    driver = db.get(Account, driver_id)
    if driver is None or driver.role is not UserRole.driver:
        raise not_found("Livreur inconnu")

    driver.kyc_status = KycStatus.approved if body.approve else KycStatus.rejected
    db.add(
        ModerationLog(
            actor_id=admin.id,
            subject_id=driver.id,
            action="kyc_approved" if body.approve else "kyc_rejected",
            reason=reason,
        )
    )
    db.commit()

    return {"driverId": driver.id, "kycStatus": driver.kyc_status.value}


@router.post("/drivers/{driver_id}/suspension")
async def suspend_driver(
    driver_id: str,
    body: Suspension,
    db: Session = Depends(get_db),
    admin: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    reason = _require_reason(body.reason)

    driver = db.get(Account, driver_id)
    if driver is None or driver.role is not UserRole.driver:
        raise not_found("Livreur inconnu")

    driver.suspended_at = datetime.now(timezone.utc) if body.suspend else None

    # Une suspension coupe aussi la disponibilite : laisser un suspendu « en
    # ligne » le ferait apparaitre sur la carte et recevoir des offres qu'il ne
    # peut pas accepter.
    state = db.get(DriverState, driver.id)
    if state is not None and body.suspend:
        state.online = False

    db.add(
        ModerationLog(
            actor_id=admin.id,
            subject_id=driver.id,
            action="suspended" if body.suspend else "unsuspended",
            reason=reason,
        )
    )
    db.commit()

    return {"driverId": driver.id, "suspended": driver.suspended_at is not None}


@router.get("/users")
async def list_users(
    role: str | None = None,
    q: str | None = None,
    db: Session = Depends(get_db),
    _: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    """Annuaire des comptes (clients ou livreurs), cherchable par nom ou numero.

    C'est la base de la gestion des utilisateurs : lister, retrouver, puis
    suspendre ou reactiver. On plafonne a 200 lignes — au-dela, la recherche est
    le bon outil, pas le defilement.
    """
    query = select(Account)
    if role in ("client", "driver"):
        query = query.where(Account.role == UserRole(role))
    if q and q.strip():
        like = f"%{q.strip()}%"
        query = query.where(
            Account.display_name.ilike(like) | Account.phone.ilike(like)
        )
    rows = db.scalars(
        query.order_by(Account.created_at.desc()).limit(200)
    ).all()
    return {
        "items": [
            {
                "id": a.id,
                "displayName": a.display_name,
                "phone": a.phone,
                "role": a.role.value if a.role else None,
                "kycStatus": a.kyc_status.value if a.kyc_status else None,
                "rating": a.rating,
                "suspended": a.suspended_at is not None,
                "createdAt": as_utc(a.created_at).isoformat(),
            }
            for a in rows
        ]
    }


@router.post("/users/{account_id}/suspension")
async def suspend_user(
    account_id: str,
    body: Suspension,
    db: Session = Depends(get_db),
    admin: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    """Suspend ou reactive un compte, client comme livreur, avec motif.

    Un admin ne se suspend pas lui-meme, ni un autre admin : couper l'acces a
    l'exploitation depuis l'exploitation serait une porte vers le blocage total.
    """
    reason = _require_reason(body.reason)

    account = db.get(Account, account_id)
    if account is None or account.is_admin:
        raise not_found("Compte inconnu")

    account.suspended_at = datetime.now(timezone.utc) if body.suspend else None

    # Un livreur suspendu passe hors ligne : il ne doit plus recevoir d'offres.
    if account.role is UserRole.driver and body.suspend:
        state = db.get(DriverState, account.id)
        if state is not None:
            state.online = False

    db.add(
        ModerationLog(
            actor_id=admin.id,
            subject_id=account.id,
            action="suspended" if body.suspend else "unsuspended",
            reason=reason,
        )
    )
    db.commit()
    return {"id": account.id, "suspended": account.suspended_at is not None}


@router.get("/moderation")
async def moderation_history(
    db: Session = Depends(get_db), _: Account = Depends(require_role(UserRole.admin))
) -> dict:
    """Journal des decisions, en ajout seul.

    Aucune route ne le modifie ni ne l'efface. C'est ce qui permet de repondre a
    « pourquoi ce livreur a-t-il ete suspendu ? » longtemps apres, et de savoir
    qui a decide.
    """
    entries = db.scalars(
        select(ModerationLog).order_by(ModerationLog.decided_at.desc())
    ).all()
    return {"items": [e.to_json() for e in entries]}

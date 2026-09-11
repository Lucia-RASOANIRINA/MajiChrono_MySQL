"""Cree un jeu de donnees de developpement : un expediteur, un livreur et une
poignee de courses dans des etats varies, avec leur journal.

    .venv\\Scripts\\python -m app.tools.seed_test_data

Idempotent : les comptes sont retrouves par numero, et les courses ne sont
semees qu'une fois (si l'expediteur n'en a aucune). Relancer ne cree pas de
doublon. C'est un outil de developpement — les numeros et adresses sont fictifs
mais valides (prefixes reels d'Antananarivo).
"""

from __future__ import annotations

import json
import base64
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.core.security import hash_secret, new_opaque_token
from app.db import SessionLocal, ensure_schema
from app.models import (
    Account,
    Delivery,
    DeliveryEvent,
    DeliveryStatus,
    DriverState,
    KycStatus,
    KycDocument,
    DriverVehicle,
    UserRole,
)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _place(lat: float, lng: float, summary: str) -> str:
    return json.dumps({"point": {"lat": lat, "lng": lng}, "summary": summary})


def _upsert_account(
    db, phone, *, role, name, email=None, password=None, rating=None, kyc=None
):
    account = db.scalar(select(Account).where(Account.phone == phone))
    if account is None:
        account = Account(phone=phone)
        db.add(account)
    account.role = role
    account.display_name = name
    account.email = email
    if password is not None:
        account.password_hash = hash_secret(password)
    account.rating = rating
    account.kyc_status = kyc
    return account


# Antananarivo : quelques reperes reels pour que la carte tombe juste.
ANALAKELY = (-18.9100, 47.5256)
ANKORONDRANO = (-18.8770, 47.5220)
IVANDRY = (-18.8680, 47.5430)
AMBOHIPO = (-18.9200, 47.5490)
TSARALALANA = (-18.9080, 47.5210)


def main() -> int:
    ensure_schema()

    with SessionLocal() as db:
        client = _upsert_account(
            db,
            "+261340000001",
            role=UserRole.client,
            name="Rina Rakoto",
            email="rina.client@example.mg",
            password="MajiClient2026!",
            rating=4.8,
        )
        driver = _upsert_account(
            db,
            "+261330000002",
            role=UserRole.driver,
            name="Tovo Livreur",
            email="tovo.driver@example.mg",
            password="MajiDriver2026!",
            rating=4.9,
            kyc=KycStatus.approved,
        )
        test_account = _upsert_account(
            db,
            "+261340000003",
            role=UserRole.client,
            name="Compte Test",
            email="test.client@majichrono.mg",
            password="MajiTest2026!",
        )
        db.flush()

        # Dossier de demonstration complet : les octets sont une image PNG
        # neutre, uniquement pour permettre de parcourir l'ecran valide sans
        # utiliser de vrais documents d'identite.
        placeholder = base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
            "YAAAAAYAAjCB0C8AAAAASUVORK5CYII="
        )
        for kind in ("cin_front", "cin_back", "licence", "selfie", "registration", "vehicle", "plate"):
            document = db.get(KycDocument, (driver.id, kind))
            if document is None:
                document = KycDocument(account_id=driver.id, kind=kind)
                db.add(document)
            document.data = placeholder
            document.content_type = "image/png"
            document.updated_at = _now()

        vehicle = db.get(DriverVehicle, driver.id)
        if vehicle is None:
            vehicle = DriverVehicle(account_id=driver.id)
            db.add(vehicle)
        vehicle.vehicle_type = "moto"
        vehicle.brand = "Honda"
        vehicle.model = "Click 125"
        vehicle.plate = "1234 TAB"
        vehicle.insurance_expiry = "2027-12-31"
        vehicle.validation = "validated"
        vehicle.updated_at = _now()
        db.flush()

        # Livreur en ligne, derniere position a Ankorondrano.
        state = db.get(DriverState, driver.id)
        if state is None:
            state = DriverState(account_id=driver.id)
            db.add(state)
        state.online = True
        state.lat, state.lng = ANKORONDRANO
        state.fixed_at = _now()
        state.updated_at = _now()

        # Ne semer les courses qu'une fois.
        existing = db.scalar(
            select(Delivery).where(Delivery.client_id == client.id).limit(1)
        )
        if existing is not None:
            db.commit()
            print("Comptes a jour. Courses deja presentes — rien de plus a semer.")
            _summary(client, driver, test_account)
            return 0

        # (statut, livreur assigne ?, depart, arrivee, prix Ar, colis)
        plan = [
            (DeliveryStatus.pending, False, ANALAKELY, "Analakely - Pavillon",
             IVANDRY, "Ivandry - Rue du Dr Ranaivo", 8000, "Documents"),
            (DeliveryStatus.assigned, True, TSARALALANA, "Tsaralalana - Epicerie",
             AMBOHIPO, "Ambohipo - Campus", 12000, "Repas chaud"),
            (DeliveryStatus.in_transit, True, ANKORONDRANO, "Ankorondrano - City",
             ANALAKELY, "Analakely - Marche", 15000, "Colis fragile"),
            (DeliveryStatus.delivered, True, IVANDRY, "Ivandry - La City",
             TSARALALANA, "Tsaralalana - Bureau", 10000, "Pieces auto"),
            (DeliveryStatus.pending, False, AMBOHIPO, "Ambohipo - Fac",
             ANKORONDRANO, "Ankorondrano - Zital", 9000, "Medicaments"),
        ]

        # Chemin des transitions par etat cible, pour ecrire un journal credible.
        path = {
            DeliveryStatus.pending: [DeliveryStatus.pending],
            DeliveryStatus.assigned: [DeliveryStatus.pending, DeliveryStatus.assigned],
            DeliveryStatus.in_transit: [
                DeliveryStatus.pending,
                DeliveryStatus.assigned,
                DeliveryStatus.picked_up,
                DeliveryStatus.in_transit,
            ],
            DeliveryStatus.delivered: [
                DeliveryStatus.pending,
                DeliveryStatus.assigned,
                DeliveryStatus.picked_up,
                DeliveryStatus.in_transit,
                DeliveryStatus.delivered,
            ],
        }

        for i, (status, assigned, pu, pu_s, do, do_s, price, item) in enumerate(plan):
            created = _now() - timedelta(hours=len(plan) - i, minutes=i * 7)
            delivery = Delivery(
                client_id=client.id,
                driver_id=driver.id if assigned else None,
                status=status,
                kind="standard",
                pickup_json=_place(pu[0], pu[1], pu_s),
                dropoff_json=_place(do[0], do[1], do_s),
                package_json=json.dumps({"description": item}),
                price_ariary=price,
                tracking_token=new_opaque_token()[:40],
                created_at=created,
                updated_at=created,
            )
            db.add(delivery)
            db.flush()

            steps = path[status]
            for j, step in enumerate(steps):
                actor = client.id if step == DeliveryStatus.pending else driver.id
                db.add(
                    DeliveryEvent(
                        delivery_id=delivery.id,
                        status=step,
                        actor_id=actor,
                        note=None,
                        occurred_at=created + timedelta(minutes=j * 6),
                    )
                )
            delivery.updated_at = created + timedelta(minutes=(len(steps) - 1) * 6)

        db.commit()
        print(f"{len(plan)} courses semees pour {client.display_name}.")
        _summary(client, driver, test_account)
    return 0


def _summary(client: Account, driver: Account, test_account: Account) -> None:
    print()
    print("Comptes de test :")
    print(f"  Expediteur : {client.phone}  ({client.display_name})")
    print(f"  Livreur    : {driver.phone}  ({driver.display_name})")
    print(f"  Test e-mail: {test_account.email} / mot de passe: MajiTest2026!")
    print()
    print("Connexion depuis l'app (mode live) : ecran telephone -> le code OTP")
    print("est renvoye dans la reponse (debugCode) et journalise cote serveur.")


if __name__ == "__main__":
    raise SystemExit(main())

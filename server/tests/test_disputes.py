"""Litiges (§13 client, EXI-A05 exploitation).

Trois frontieres portent la valeur du routeur : on n'ouvre un litige que sur une
course dont on est partie prenante, on ne lit que ce qui nous concerne (ou en
tant qu'exploitation), et seule l'exploitation tranche — avec un motif.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.models import Account, UserRole
from tests.conftest import sign_in

CLIENT_PHONE = "+261340000001"
OTHER_CLIENT_PHONE = "+261340000042"

COURSE = {
    "pickup": {"point": {"lat": -18.9, "lng": 47.5}, "summary": "Analakely"},
    "dropoff": {"point": {"lat": -18.87, "lng": 47.52}, "summary": "Ivandry"},
    "kind": "standard",
    "package": {"weight": "under5"},
    "price": 6000,
}


def _session():
    from app.db import get_db
    from app.main import app

    return next(app.dependency_overrides[get_db]())


def _admin(client: TestClient) -> dict:
    headers = sign_in(client, "+261320000003")
    db = _session()
    account = db.query(Account).filter(Account.phone == "+261320000003").one()
    account.role = UserRole.admin
    db.commit()
    return headers


def _course(client: TestClient, headers: dict, key: str = "c-1") -> str:
    return client.post(
        "/deliveries", json=COURSE, headers={**headers, "Idempotency-Key": key}
    ).json()["id"]


def _open(client: TestClient, headers: dict, delivery_id: str, key: str = "o-1") -> dict:
    return client.post(
        "/disputes",
        json={"deliveryId": delivery_id, "reason": "Colis abime a la reception"},
        headers={**headers, "Idempotency-Key": key},
    )


class TestOuverture:
    def test_une_partie_ouvre_un_litige_sur_sa_course(self, client: TestClient):
        headers = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, headers)
        response = _open(client, headers, delivery_id)
        assert response.status_code == 201
        body = response.json()
        assert body["status"] == "open"
        assert body["openedBy"] == "client"
        assert body["messages"] == []
        assert body["decision"] is None

    def test_un_tiers_n_ouvre_pas_de_litige(self, client: TestClient):
        owner = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, owner)
        intruder = sign_in(client, OTHER_CLIENT_PHONE, role="client")
        response = _open(client, intruder, delivery_id, key="intrus")
        assert response.status_code == 404

    def test_un_motif_vide_est_refuse(self, client: TestClient):
        headers = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, headers)
        response = client.post(
            "/disputes",
            json={"deliveryId": delivery_id, "reason": "   "},
            headers={**headers, "Idempotency-Key": "vide"},
        )
        assert response.status_code == 422

    def test_la_meme_cle_n_ouvre_pas_deux_litiges(self, client: TestClient):
        headers = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, headers)
        first = _open(client, headers, delivery_id, key="reprise").json()
        second = _open(client, headers, delivery_id, key="reprise").json()
        assert first["id"] == second["id"]


class TestVisibilite:
    def test_le_client_ne_voit_que_ses_litiges(self, client: TestClient):
        owner = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, owner)
        _open(client, owner, delivery_id)

        intruder = sign_in(client, OTHER_CLIENT_PHONE, role="client")
        items = client.get("/disputes", headers=intruder).json()["items"]
        assert items == []

    def test_l_exploitation_voit_tout(self, client: TestClient):
        owner = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, owner)
        opened = _open(client, owner, delivery_id).json()

        admin = _admin(client)
        items = client.get("/disputes", headers=admin).json()["items"]
        assert opened["id"] in {d["id"] for d in items}

    def test_un_tiers_ne_lit_pas_le_detail(self, client: TestClient):
        owner = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, owner)
        opened = _open(client, owner, delivery_id).json()

        intruder = sign_in(client, OTHER_CLIENT_PHONE, role="client")
        response = client.get(f"/disputes/{opened['id']}", headers=intruder)
        assert response.status_code == 404


class TestEchangesEtDecision:
    def test_un_message_fait_passer_en_instruction(self, client: TestClient):
        headers = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, headers)
        opened = _open(client, headers, delivery_id).json()

        replied = client.post(
            f"/disputes/{opened['id']}/messages",
            json={"body": "Le carton etait enfonce"},
            headers=headers,
        ).json()
        assert replied["status"] == "investigating"
        assert len(replied["messages"]) == 1
        assert replied["messages"][0]["fromOperations"] is False

    def test_seule_l_exploitation_tranche(self, client: TestClient):
        headers = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, headers)
        opened = _open(client, headers, delivery_id).json()

        response = client.post(
            f"/disputes/{opened['id']}/decision",
            json={"resolve": True, "reason": "Remboursement accorde au client"},
            headers={**headers, "Idempotency-Key": "d-1"},
        )
        assert response.status_code == 403

    def test_une_decision_sans_motif_suffisant_est_refusee(self, client: TestClient):
        owner = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, owner)
        opened = _open(client, owner, delivery_id).json()

        admin = _admin(client)
        response = client.post(
            f"/disputes/{opened['id']}/decision",
            json={"resolve": True, "reason": "ok"},
            headers={**admin, "Idempotency-Key": "d-2"},
        )
        assert response.status_code == 422

    def test_l_exploitation_tranche_et_clot(self, client: TestClient):
        owner = sign_in(client, CLIENT_PHONE, role="client")
        delivery_id = _course(client, owner)
        opened = _open(client, owner, delivery_id).json()

        admin = _admin(client)
        decided = client.post(
            f"/disputes/{opened['id']}/decision",
            json={"resolve": True, "reason": "Remboursement accorde au client"},
            headers={**admin, "Idempotency-Key": "d-3"},
        ).json()
        assert decided["status"] == "resolved"
        assert decided["decision"]["action"] == "resolve_dispute"

        # Un litige clos n'accepte plus de message.
        closed = client.post(
            f"/disputes/{opened['id']}/messages",
            json={"body": "encore un mot"},
            headers=owner,
        )
        assert closed.status_code == 409

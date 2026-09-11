"""Evaluation d'une course (EXI-C40).

Ces tests protegent qui a le droit de noter, quand, et le fait qu'une note
recalcule la moyenne du livreur sans jamais s'empiler sur elle-meme.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.models import Account, KycStatus
from tests.conftest import sign_in

CLIENT_PHONE = "+261340000001"
DRIVER_PHONE = "+261330000002"

COURSE = {
    "pickup": {"point": {"lat": -18.9, "lng": 47.5}, "summary": "Analakely"},
    "dropoff": {"point": {"lat": -18.87, "lng": 47.52}, "summary": "Ivandry"},
    "kind": "standard",
    "package": {"weight": "under5"},
    "price": 6000,
}


def _approve_kyc(phone: str) -> None:
    from app.db import get_db
    from app.main import app

    db = next(app.dependency_overrides[get_db]())
    account = db.query(Account).filter(Account.phone == phone).one()
    account.kyc_status = KycStatus.approved
    db.commit()


def _delivered_course(client: TestClient) -> tuple[dict, dict, str]:
    """Mene une course jusqu'a la remise ; rend (client, livreur, id)."""
    expediteur = sign_in(client, CLIENT_PHONE, role="client")
    course = client.post(
        "/deliveries", json=COURSE, headers={**expediteur, "Idempotency-Key": "c-1"}
    ).json()
    cid = course["id"]

    livreur = sign_in(client, DRIVER_PHONE, role="driver")
    _approve_kyc(DRIVER_PHONE)
    client.post("/driver/status", json={"online": True}, headers=livreur)
    client.post(f"/deliveries/{cid}/accept", headers=livreur)
    for step in ("prise_en_charge", "en_transit", "livree"):
        r = client.post(
            f"/deliveries/{cid}/transition",
            json={"status": step},
            headers=livreur,
        )
        assert r.status_code == 200, r.text
    return expediteur, livreur, cid


def _driver_rating(client: TestClient, livreur: dict) -> float | None:
    return client.get("/me", headers=livreur).json()["rating"]


class TestNotation:
    def test_l_expediteur_note_une_course_remise(self, client: TestClient):
        expediteur, livreur, cid = _delivered_course(client)

        response = client.post(
            "/reviews",
            json={
                "deliveryId": cid,
                "stars": 5,
                "punctuality": 5,
                "service": 4,
                "comment": "Rapide et soigneux",
            },
            headers=expediteur,
        )
        assert response.status_code == 201, response.text
        assert response.json()["stars"] == 5
        assert _driver_rating(client, livreur) == 5.0

    def test_une_seconde_note_corrige_sans_empiler(self, client: TestClient):
        expediteur, livreur, cid = _delivered_course(client)
        client.post(
            "/reviews", json={"deliveryId": cid, "stars": 5}, headers=expediteur
        )
        client.post(
            "/reviews", json={"deliveryId": cid, "stars": 2}, headers=expediteur
        )
        # Une seule note demeure, corrigee : la moyenne suit la derniere valeur.
        assert _driver_rating(client, livreur) == 2.0
        got = client.get(f"/reviews/delivery/{cid}", headers=expediteur).json()
        assert got["stars"] == 2

    def test_seul_l_expediteur_note(self, client: TestClient):
        expediteur, livreur, cid = _delivered_course(client)
        response = client.post(
            "/reviews", json={"deliveryId": cid, "stars": 5}, headers=livreur
        )
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "not_client"

    def test_on_ne_note_pas_avant_la_remise(self, client: TestClient):
        expediteur = sign_in(client, CLIENT_PHONE, role="client")
        course = client.post(
            "/deliveries", json=COURSE, headers={**expediteur, "Idempotency-Key": "c-1"}
        ).json()

        response = client.post(
            "/reviews", json={"deliveryId": course["id"], "stars": 5}, headers=expediteur
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "not_delivered"

    def test_une_note_hors_bornes_est_refusee(self, client: TestClient):
        expediteur, _, cid = _delivered_course(client)
        response = client.post(
            "/reviews", json={"deliveryId": cid, "stars": 6}, headers=expediteur
        )
        assert response.status_code == 422

    def test_pas_d_avis_pour_une_course_non_notee(self, client: TestClient):
        expediteur, _, cid = _delivered_course(client)
        response = client.get(f"/reviews/delivery/{cid}", headers=expediteur)
        assert response.status_code == 404

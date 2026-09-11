"""Incidents declares sur une course (EXI-L14, §19).

Un incident est une main courante : il se documente et se liste, mais il ne fait
pas echouer la course de lui-meme. Les frontieres protegees : on ne declare et on
ne lit que sur une course dont on est partie prenante, et un type inconnu est
refuse.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import sign_in

CLIENT_PHONE = "+261340000001"
DRIVER_PHONE = "+261330000002"
OTHER_PHONE = "+261340000077"

COURSE = {
    "pickup": {"point": {"lat": -18.9, "lng": 47.5}, "summary": "Analakely"},
    "dropoff": {"point": {"lat": -18.87, "lng": 47.52}, "summary": "Ivandry"},
    "kind": "standard",
    "package": {"weight": "under5"},
    "price": 6000,
}


def _course(client: TestClient) -> tuple[dict, str]:
    headers = sign_in(client, CLIENT_PHONE, role="client")
    delivery = client.post(
        "/deliveries", json=COURSE, headers={**headers, "Idempotency-Key": "c-1"}
    ).json()
    return headers, delivery["id"]


class TestSignalement:
    def test_une_partie_declare_un_incident_complet(self, client: TestClient):
        headers, delivery_id = _course(client)
        response = client.post(
            f"/deliveries/{delivery_id}/incidents",
            json={
                "kind": "recipient_absent",
                "description": "Portail ferme, personne ne repond",
                "lat": -18.87,
                "lng": 47.52,
            },
            headers={**headers, "Idempotency-Key": "i-1"},
        )
        assert response.status_code == 201
        body = response.json()
        assert body["kind"] == "recipient_absent"
        assert body["resolution"] == "open"
        assert body["lat"] == -18.87

    def test_un_type_inconnu_est_refuse(self, client: TestClient):
        headers, delivery_id = _course(client)
        response = client.post(
            f"/deliveries/{delivery_id}/incidents",
            json={"kind": "invente"},
            headers={**headers, "Idempotency-Key": "i-2"},
        )
        assert response.status_code == 422

    def test_un_incident_n_echoue_pas_la_course(self, client: TestClient):
        headers, delivery_id = _course(client)
        client.post(
            f"/deliveries/{delivery_id}/incidents",
            json={"kind": "gps_problem"},
            headers={**headers, "Idempotency-Key": "i-3"},
        )
        # La course reste en attente : une main courante ne condamne pas le colis.
        delivery = client.get(f"/deliveries/{delivery_id}", headers=headers).json()
        assert delivery["status"] == "en_attente"

    def test_un_tiers_ne_declare_pas(self, client: TestClient):
        _, delivery_id = _course(client)
        intruder = sign_in(client, OTHER_PHONE, role="client")
        response = client.post(
            f"/deliveries/{delivery_id}/incidents",
            json={"kind": "accident"},
            headers={**intruder, "Idempotency-Key": "i-4"},
        )
        assert response.status_code == 404


class TestListe:
    def test_les_incidents_se_listent_du_plus_recent(self, client: TestClient):
        headers, delivery_id = _course(client)
        for i, kind in enumerate(("sender_absent", "vehicle_problem")):
            client.post(
                f"/deliveries/{delivery_id}/incidents",
                json={"kind": kind},
                headers={**headers, "Idempotency-Key": f"k-{i}"},
            )
        items = client.get(
            f"/deliveries/{delivery_id}/incidents", headers=headers
        ).json()["items"]
        assert len(items) == 2
        assert {i["kind"] for i in items} == {"sender_absent", "vehicle_problem"}

    def test_un_tiers_ne_lit_pas_les_incidents(self, client: TestClient):
        headers, delivery_id = _course(client)
        client.post(
            f"/deliveries/{delivery_id}/incidents",
            json={"kind": "other"},
            headers={**headers, "Idempotency-Key": "k-9"},
        )
        intruder = sign_in(client, OTHER_PHONE, role="client")
        response = client.get(
            f"/deliveries/{delivery_id}/incidents", headers=intruder
        )
        assert response.status_code == 404

"""Points relais (differenciant D6, §7) et code de retrait.

Deux choses a proteger : le reseau de relais se lit (filtre par quartier, trie
par proximite quand une position est donnee), et une course adressee a un relais
recoit un code de retrait a six chiffres — genere seulement dans ce cas.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import sign_in

CLIENT_PHONE = "+261340000001"

COURSE = {
    "pickup": {"point": {"lat": -18.9, "lng": 47.5}, "summary": "Analakely"},
    "dropoff": {"point": {"lat": -18.87, "lng": 47.52}, "summary": "Ivandry"},
    "kind": "standard",
    "package": {"weight": "under5"},
    "price": 6000,
}


class TestReseauRelais:
    def test_le_reseau_se_lit(self, client: TestClient):
        headers = sign_in(client, CLIENT_PHONE, role="client")
        response = client.get("/relay-points", headers=headers)
        assert response.status_code == 200
        items = response.json()["items"]
        assert len(items) >= 3
        assert {"rel_1", "rel_2", "rel_3"} <= {p["id"] for p in items}

    def test_le_filtre_par_quartier_restreint(self, client: TestClient):
        headers = sign_in(client, CLIENT_PHONE, role="client")
        items = client.get(
            "/relay-points", params={"district": "Ambohipo"}, headers=headers
        ).json()["items"]
        assert [p["id"] for p in items] == ["rel_1"]

    def test_la_position_trie_du_plus_proche_et_donne_la_distance(
        self, client: TestClient
    ):
        headers = sign_in(client, CLIENT_PHONE, role="client")
        # Proche d'Ivandry (rel_3) : il doit remonter en tete, distance en main.
        items = client.get(
            "/relay-points",
            params={"lat": -18.876, "lng": 47.531},
            headers=headers,
        ).json()["items"]
        assert items[0]["id"] == "rel_3"
        assert items[0]["distanceKm"] == 0.0
        # La liste est bien triee par distance croissante.
        distances = [p["distanceKm"] for p in items]
        assert distances == sorted(distances)

    def test_le_reseau_exige_un_compte(self, client: TestClient):
        response = client.get("/relay-points")
        assert response.status_code == 401


class TestCodeDeRetrait:
    def test_une_course_vers_un_relais_recoit_un_code(self, client: TestClient):
        headers = sign_in(client, CLIENT_PHONE, role="client")
        course = client.post(
            "/deliveries",
            json={**COURSE, "relayPointId": "rel_1"},
            headers={**headers, "Idempotency-Key": "relay-1"},
        ).json()
        assert course["relayPointId"] == "rel_1"
        code = course["relayPickupCode"]
        assert code is not None
        assert len(code) == 6 and code.isdigit()

    def test_une_course_a_domicile_n_a_pas_de_code(self, client: TestClient):
        headers = sign_in(client, CLIENT_PHONE, role="client")
        course = client.post(
            "/deliveries",
            json=COURSE,
            headers={**headers, "Idempotency-Key": "home-1"},
        ).json()
        assert course["relayPointId"] is None
        assert course["relayPickupCode"] is None

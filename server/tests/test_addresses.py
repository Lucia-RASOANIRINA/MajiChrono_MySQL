"""Carnet d'adresses : CRUD, unicite du domicile/travail, cloisonnement.

Le carnet appartient au compte : ces tests protegent surtout la frontiere — on
ne voit, ne modifie et ne supprime que ses propres adresses — et l'invariant
« un seul domicile, un seul lieu de travail ».
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import sign_in

_ADDRESS = {
    "point": {"lat": -18.9, "lng": 47.5},
    "district": "Analakely",
    "landmark": "Face a l escalier",
    "contactPhone": "+261340000009",
}


def _create(client: TestClient, headers: dict, *, kind: str, label: str) -> dict:
    return client.post(
        "/addresses",
        json={"kind": kind, "label": label, "address": _ADDRESS},
        headers=headers,
    ).json()


class TestCarnet:
    def test_cree_puis_liste(self, client: TestClient):
        headers = sign_in(client, "+261340000100")
        created = _create(client, headers, kind="home", label="Maison")
        assert created["kind"] == "home"
        assert created["address"]["district"] == "Analakely"

        listing = client.get("/addresses", headers=headers).json()["items"]
        assert len(listing) == 1
        assert listing[0]["id"] == created["id"]

    def test_un_seul_domicile(self, client: TestClient):
        headers = sign_in(client, "+261340000101")
        first = _create(client, headers, kind="home", label="Ancienne maison")
        _create(client, headers, kind="home", label="Nouvelle maison")

        items = client.get("/addresses", headers=headers).json()["items"]
        homes = [a for a in items if a["kind"] == "home"]
        assert len(homes) == 1
        # L'ancienne a ete retrogradee, pas supprimee.
        old = next(a for a in items if a["id"] == first["id"])
        assert old["kind"] == "other"

    def test_modifie_et_supprime(self, client: TestClient):
        headers = sign_in(client, "+261340000102")
        created = _create(client, headers, kind="other", label="Bureau")
        updated = client.patch(
            f"/addresses/{created['id']}",
            json={"kind": "work", "label": "Travail", "address": _ADDRESS},
            headers=headers,
        ).json()
        assert updated["kind"] == "work"
        assert updated["label"] == "Travail"

        gone = client.delete(f"/addresses/{created['id']}", headers=headers)
        assert gone.status_code == 204
        assert client.get("/addresses", headers=headers).json()["items"] == []

    def test_un_autre_compte_ne_voit_ni_ne_touche(self, client: TestClient):
        owner = sign_in(client, "+261340000103")
        created = _create(client, owner, kind="favorite", label="Chez maman")

        other = sign_in(client, "+261340000104")
        assert client.get("/addresses", headers=other).json()["items"] == []
        assert (
            client.delete(f"/addresses/{created['id']}", headers=other).status_code
            == 204
        )
        # Toujours la pour le proprietaire : la suppression d'un autre n'a rien fait.
        assert len(client.get("/addresses", headers=owner).json()["items"]) == 1

    def test_un_type_inconnu_est_refuse(self, client: TestClient):
        headers = sign_in(client, "+261340000105")
        r = client.post(
            "/addresses",
            json={"kind": "secret", "label": "x", "address": _ADDRESS},
            headers=headers,
        )
        assert r.status_code == 422

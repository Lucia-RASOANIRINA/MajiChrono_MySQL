"""Dossier KYC du livreur : depot des pieces, soumission, revue par l'admin.

Le dossier est **bloquant** (EXI-L01) : ces tests protegent surtout la porte —
on ne soumet pas un dossier incomplet, et les pieces d'identite ne se lisent
qu'avec un jeton, par leur proprietaire ou l'exploitation.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import sign_in
from tests.test_admin import admin_headers

_PNG = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
    "YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
)
_KINDS = [
    "cin_front",
    "cin_back",
    "licence",
    "selfie",
    "registration",
    "vehicle",
    "plate",
]


def _upload(client: TestClient, headers: dict, kind: str) -> None:
    client.post(
        f"/drivers/kyc/documents/{kind}",
        json={"imageBase64": _PNG, "contentType": "image/png"},
        headers=headers,
    )


def _upload_all(client: TestClient, headers: dict) -> None:
    for kind in _KINDS:
        _upload(client, headers, kind)


class TestDepot:
    def test_les_pieces_deposees_apparaissent_dans_le_suivi(self, client: TestClient):
        headers = sign_in(client, "+261330000070", role="driver")
        _upload(client, headers, "cin_front")
        _upload(client, headers, "selfie")
        status = client.get("/drivers/kyc/status", headers=headers).json()
        assert set(status["uploaded"]) == {"cin_front", "selfie"}
        assert "licence" in status["missing"]

    def test_une_piece_inconnue_est_refusee(self, client: TestClient):
        headers = sign_in(client, "+261330000071", role="driver")
        r = client.post(
            "/drivers/kyc/documents/passeport",
            json={"imageBase64": _PNG, "contentType": "image/png"},
            headers=headers,
        )
        assert r.status_code == 422


class TestSoumission:
    def test_un_dossier_incomplet_ne_se_soumet_pas(self, client: TestClient):
        headers = sign_in(client, "+261330000072", role="driver")
        _upload(client, headers, "cin_front")
        r = client.post("/drivers/kyc", headers=headers)
        assert r.status_code == 422
        assert "licence" in r.json()["error"]["details"]["missing"]

    def test_un_dossier_complet_passe_en_verification(self, client: TestClient):
        headers = sign_in(client, "+261330000073", role="driver")
        _upload_all(client, headers)
        status = client.get("/drivers/kyc/status", headers=headers).json()
        assert len(status["uploaded"]) == 7
        r = client.post("/drivers/kyc", headers=headers)
        assert r.status_code == 200
        assert r.json()["status"] == "submitted"


class TestRevueAdmin:
    def test_l_admin_voit_les_pieces_et_la_lecture_est_protegee(self, client: TestClient):
        driver = sign_in(client, "+261330000074", role="driver")
        _upload_all(client, driver)
        driver_id = client.get("/me", headers=driver).json()["id"]

        admin = admin_headers(client)
        listing = client.get(f"/admin/kyc/{driver_id}/documents", headers=admin)
        assert listing.status_code == 200
        docs = listing.json()["documents"]
        assert len(docs) == 7

        url = docs[0]["url"]
        # Le proprietaire et l'admin lisent la piece ; un autre livreur, non.
        assert client.get(url, headers=driver).status_code == 200
        assert client.get(url, headers=admin).status_code == 200
        other = sign_in(client, "+261330000075", role="driver")
        assert client.get(url, headers=other).status_code == 403


class TestSuiviDossier:
    """Fil de suivi du dossier : le livreur ecrit, l'exploitation repond."""

    def test_echange_livreur_exploitation(self, client: TestClient):
        driver = sign_in(client, "+261330000080", role="driver")

        # Le livreur demande ou en est son dossier.
        sent = client.post(
            "/drivers/kyc/messages",
            json={"body": "Bonjour, ou en est mon dossier ?"},
            headers=driver,
        )
        assert sent.status_code == 200
        assert sent.json()["fromAdmin"] is False

        # L'exploitation lit le fil et repond.
        admin = admin_headers(client)
        driver_id = client.get("/me", headers=driver).json()["id"]
        thread = client.get(
            f"/admin/kyc/{driver_id}/messages", headers=admin
        ).json()["items"]
        assert len(thread) == 1

        replied = client.post(
            f"/admin/kyc/{driver_id}/messages",
            json={"body": "Bonjour, dossier en cours d'examen."},
            headers=admin,
        )
        assert replied.status_code == 200
        assert replied.json()["fromAdmin"] is True

        # Le livreur voit la reponse dans son fil.
        seen = client.get("/drivers/kyc/messages", headers=driver).json()["items"]
        assert [m["fromAdmin"] for m in seen] == [False, True]

    def test_un_message_vide_est_refuse(self, client: TestClient):
        driver = sign_in(client, "+261330000081", role="driver")
        response = client.post(
            "/drivers/kyc/messages", json={"body": "   "}, headers=driver
        )
        assert response.status_code == 422

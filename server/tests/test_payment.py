"""Paiement par code QR adosse aux soldes MajiPay (§11.2).

Ces tests protegent la promesse centrale du module : **scanner n'autorise
jamais un debit**, et un debit ne part jamais deux fois. Ils tournent contre le
bac a sable MajiPay (aucune cle configuree), qui tient des soldes fictifs et
refuse un solde insuffisant exactement comme le ferait le vrai prestataire.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.models import Account, KycStatus, PaymentIntent
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


def _course_assignee(client: TestClient) -> tuple[dict, dict, str]:
    """Ouvre une course acceptee par un livreur ; rend (entetes client, livreur, id)."""
    expediteur = sign_in(client, CLIENT_PHONE, role="client")
    course = client.post(
        "/deliveries", json=COURSE, headers={**expediteur, "Idempotency-Key": "c-1"}
    ).json()

    livreur = sign_in(client, DRIVER_PHONE, role="driver")
    _approve_kyc(DRIVER_PHONE)
    client.post("/driver/status", json={"online": True}, headers=livreur)
    accepted = client.post(f"/deliveries/{course['id']}/accept", headers=livreur)
    assert accepted.status_code == 200, accepted.text
    return expediteur, livreur, course["id"]


def _balance(client: TestClient, headers: dict) -> int:
    return client.get("/payments/balance", headers=headers).json()["available"]


class TestSoldeMajiPay:
    def test_le_solde_se_lit_par_role(self, client: TestClient):
        expediteur, livreur, _ = _course_assignee(client)
        assert _balance(client, expediteur) == 42000
        assert _balance(client, livreur) == 18500

    def test_la_reference_est_masquee(self, client: TestClient):
        expediteur = sign_in(client, CLIENT_PHONE, role="client")
        ref = client.get("/payments/balance", headers=expediteur).json()["accountRef"]
        # Aucun numero complet ne transite (EXI-MP11).
        assert ref.startswith("MP ** ** ")
        assert CLIENT_PHONE not in ref


class TestDemandeEncaissement:
    """Sens `collect` : le livreur presente le code, le client confirme."""

    def test_scanner_ne_debite_pas_seul_seule_la_confirmation_debite(self, client: TestClient):
        expediteur, livreur, course_id = _course_assignee(client)

        # Le livreur cree l'intention et affiche le code.
        intent = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "collect"},
            headers={**livreur, "Idempotency-Key": "i-1"},
        ).json()
        assert intent["status"] == "pending"
        token = intent["token"]

        # Le client scanne : l'appariement revele le montant, mais ne debite rien.
        claimed = client.post(
            f"/payments/{intent['id']}/claim",
            json={"token": token},
            headers={**expediteur, "Idempotency-Key": "cl-1"},
        ).json()
        assert claimed["status"] == "claimed"
        assert _balance(client, expediteur) == 42000  # rien n'a bouge

        # Le client confirme sur son propre telephone : c'est ici que l'argent bouge.
        captured = client.post(
            f"/payments/{intent['id']}/confirm",
            json={},
            headers={**expediteur, "Idempotency-Key": "co-1"},
        ).json()
        assert captured["status"] == "captured"
        assert captured["receiptRef"].startswith("MP-")
        assert _balance(client, expediteur) == 36000
        assert _balance(client, livreur) == 24500

    def test_un_jeton_faux_n_apparie_rien(self, client: TestClient):
        expediteur, livreur, course_id = _course_assignee(client)
        intent = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "collect"},
            headers={**livreur, "Idempotency-Key": "i-1"},
        ).json()

        response = client.post(
            f"/payments/{intent['id']}/claim",
            json={"token": "jeton-invente"},
            headers={**expediteur, "Idempotency-Key": "cl-1"},
        )
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "bad_token"

    def test_seul_le_payeur_confirme(self, client: TestClient):
        expediteur, livreur, course_id = _course_assignee(client)
        intent = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "collect"},
            headers={**livreur, "Idempotency-Key": "i-1"},
        ).json()
        client.post(
            f"/payments/{intent['id']}/claim",
            json={"token": intent["token"]},
            headers={**expediteur, "Idempotency-Key": "cl-1"},
        )

        # Le beneficiaire ne peut pas se payer lui-meme.
        response = client.post(
            f"/payments/{intent['id']}/confirm",
            json={},
            headers={**livreur, "Idempotency-Key": "co-x"},
        )
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "not_payer"

    def test_deux_confirmations_ne_debitent_qu_une_fois(self, client: TestClient):
        expediteur, livreur, course_id = _course_assignee(client)
        intent = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "collect"},
            headers={**livreur, "Idempotency-Key": "i-1"},
        ).json()
        client.post(
            f"/payments/{intent['id']}/claim",
            json={"token": intent["token"]},
            headers={**expediteur, "Idempotency-Key": "cl-1"},
        )

        headers = {**expediteur, "Idempotency-Key": "co-1"}
        first = client.post(f"/payments/{intent['id']}/confirm", json={}, headers=headers)
        second = client.post(f"/payments/{intent['id']}/confirm", json={}, headers=headers)

        assert first.json()["status"] == "captured"
        assert second.json() == first.json()  # meme reponse rejouee
        assert _balance(client, expediteur) == 36000  # un seul debit


class TestOffrePaiement:
    """Sens `offer` : le client presente le code deja pre-autorise, le livreur encaisse."""

    def test_le_scan_du_livreur_regle_dans_la_foulee(self, client: TestClient):
        expediteur, livreur, course_id = _course_assignee(client)

        intent = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "offer"},
            headers={**expediteur, "Idempotency-Key": "i-1"},
        ).json()
        assert intent["status"] == "pending"

        captured = client.post(
            f"/payments/{intent['id']}/claim",
            json={"token": intent["token"]},
            headers={**livreur, "Idempotency-Key": "cl-1"},
        ).json()
        assert captured["status"] == "captured"
        assert _balance(client, expediteur) == 36000
        assert _balance(client, livreur) == 24500

    def test_une_offre_au_dela_du_solde_est_refusee_a_la_creation(self, client: TestClient):
        expediteur, _, course_id = _course_assignee(client)

        response = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 50000, "direction": "offer"},
            headers={**expediteur, "Idempotency-Key": "i-1"},
        )
        assert response.status_code == 422
        body = response.json()["error"]
        assert body["code"] == "insufficient_funds"
        assert body["details"]["failure"] == "insufficient_funds"


class TestRepliEspeces:
    def test_le_repli_especes_est_toujours_possible_avant_capture(self, client: TestClient):
        expediteur, livreur, course_id = _course_assignee(client)
        intent = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "collect"},
            headers={**livreur, "Idempotency-Key": "i-1"},
        ).json()

        cashed = client.post(
            f"/payments/{intent['id']}/cash",
            headers={**expediteur, "Idempotency-Key": "cash-1"},
        ).json()
        assert cashed["status"] == "cash"
        assert cashed["receiptRef"].startswith("ESP-")
        assert _balance(client, expediteur) == 42000  # aucun mouvement MajiPay

    def test_on_ne_bascule_pas_en_especes_ce_qui_est_deja_regle(self, client: TestClient):
        expediteur, livreur, course_id = _course_assignee(client)
        intent = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "collect"},
            headers={**livreur, "Idempotency-Key": "i-1"},
        ).json()
        client.post(
            f"/payments/{intent['id']}/claim",
            json={"token": intent["token"]},
            headers={**expediteur, "Idempotency-Key": "cl-1"},
        )
        client.post(
            f"/payments/{intent['id']}/confirm",
            json={},
            headers={**expediteur, "Idempotency-Key": "co-1"},
        )

        response = client.post(
            f"/payments/{intent['id']}/cash",
            headers={**expediteur, "Idempotency-Key": "cash-1"},
        )
        assert response.status_code == 409
        assert response.json()["error"]["code"] == "already_captured"


class TestRetrait:
    """Le retrait : le processus vit dans l'app, la sortie d'argent chez MajiPay."""

    def test_le_livreur_retire_et_son_solde_baisse(self, client: TestClient):
        _, livreur, _ = _course_assignee(client)

        response = client.post(
            "/payments/withdraw",
            json={"amount": 5000, "destination": "mvola:0340000002"},
            headers={**livreur, "Idempotency-Key": "wd-1"},
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["receiptRef"].startswith("WD-")
        assert body["available"] == 13500

    def test_le_meme_retrait_rejoue_ne_sort_pas_deux_fois(self, client: TestClient):
        _, livreur, _ = _course_assignee(client)
        headers = {**livreur, "Idempotency-Key": "wd-1"}

        first = client.post("/payments/withdraw", json={"amount": 5000}, headers=headers)
        second = client.post("/payments/withdraw", json={"amount": 5000}, headers=headers)

        assert first.json() == second.json()
        assert _balance(client, livreur) == 13500  # une seule sortie

    def test_un_expediteur_ne_retire_pas(self, client: TestClient):
        expediteur = sign_in(client, CLIENT_PHONE, role="client")
        response = client.post(
            "/payments/withdraw", json={"amount": 1000}, headers=expediteur
        )
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "role_forbidden"

    def test_un_retrait_au_dela_du_solde_est_refuse(self, client: TestClient):
        _, livreur, _ = _course_assignee(client)
        response = client.post(
            "/payments/withdraw", json={"amount": 99000}, headers=livreur
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "insufficient_funds"


class TestGardeFous:
    def test_une_intention_sur_une_course_sans_livreur_est_refusee(self, client: TestClient):
        expediteur = sign_in(client, CLIENT_PHONE, role="client")
        course = client.post(
            "/deliveries", json=COURSE, headers={**expediteur, "Idempotency-Key": "c-1"}
        ).json()

        response = client.post(
            "/payments/intent",
            json={"deliveryId": course["id"], "amount": 6000, "direction": "offer"},
            headers={**expediteur, "Idempotency-Key": "i-1"},
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "no_driver"

    def test_un_tiers_ne_lit_pas_une_intention(self, client: TestClient):
        expediteur, livreur, course_id = _course_assignee(client)
        intent = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "collect"},
            headers={**livreur, "Idempotency-Key": "i-1"},
        ).json()

        tiers = sign_in(client, "+261340000009", role="client")
        response = client.get(f"/payments/{intent['id']}", headers=tiers)
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "not_a_party"

    def test_la_meme_cle_ne_cree_pas_deux_intentions(self, client: TestClient):
        expediteur, livreur, course_id = _course_assignee(client)
        headers = {**livreur, "Idempotency-Key": "i-1"}
        first = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "collect"},
            headers=headers,
        ).json()
        second = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "collect"},
            headers=headers,
        ).json()
        # Meme code rejoue, pas un second code encaissable en parallele (EXI-MP06).
        assert first["id"] == second["id"]
        assert first["token"] == second["token"]
        assert len(_all_intents()) == 1


class TestHistorique:
    """Journal des paiements (§11, EXI-C39)."""

    def _regle_une_course(self, client: TestClient) -> tuple[dict, dict, str]:
        expediteur, livreur, course_id = _course_assignee(client)
        intent = client.post(
            "/payments/intent",
            json={"deliveryId": course_id, "amount": 6000, "direction": "collect"},
            headers={**livreur, "Idempotency-Key": "i-1"},
        ).json()
        client.post(
            f"/payments/{intent['id']}/claim",
            json={"token": intent["token"]},
            headers={**expediteur, "Idempotency-Key": "cl-1"},
        )
        client.post(
            f"/payments/{intent['id']}/confirm",
            json={},
            headers={**expediteur, "Idempotency-Key": "co-1"},
        )
        return expediteur, livreur, course_id

    def test_le_journal_rend_les_paiements_du_compte(self, client: TestClient):
        expediteur, livreur, _ = self._regle_une_course(client)

        cote_client = client.get("/payments/history", headers=expediteur)
        assert cote_client.status_code == 200
        items = cote_client.json()["items"]
        assert len(items) == 1
        assert items[0]["status"] == "captured"
        # Le client est le payeur : le journal le lui dit sans qu'il compare des ids.
        assert items[0]["role"] == "payer"

        cote_livreur = client.get("/payments/history", headers=livreur).json()["items"]
        assert cote_livreur[0]["role"] == "payee"

    def test_un_tiers_ne_voit_pas_le_paiement(self, client: TestClient):
        self._regle_une_course(client)
        tiers = sign_in(client, "+261340000123", role="client")
        items = client.get("/payments/history", headers=tiers).json()["items"]
        assert items == []


def _all_intents() -> list[PaymentIntent]:
    from app.db import get_db
    from app.main import app

    db = next(app.dependency_overrides[get_db]())
    return db.query(PaymentIntent).all()

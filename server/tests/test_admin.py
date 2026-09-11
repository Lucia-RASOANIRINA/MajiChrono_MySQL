"""Espace exploitation.

Deux invariants sont proteges ici. Le profil d'exploitation ne s'obtient jamais
depuis le mobile (EXI-T02) — il est pose en base, comme le fera l'equipe. Et
aucune decision touchant le gagne-pain d'un livreur ne passe sans motif ecrit.
"""

from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app.models import Account, KycStatus, UserRole
from tests.conftest import sign_in

COURSE = {
    "pickup": {"point": {"lat": -18.9, "lng": 47.5}, "summary": "Analakely"},
    "dropoff": {"point": {"lat": -18.87, "lng": 47.52}, "summary": "Ivandry"},
    "price": 6000,
}


def _session():
    from app.db import get_db
    from app.main import app

    return next(app.dependency_overrides[get_db]())


def admin_headers(client: TestClient) -> dict:
    """Ouvre une session d'exploitation.

    Le role est pose **en base**, jamais par l'API : c'est exactement ce que le
    serveur refuse au mobile, et le test s'en sert comme d'un rappel.
    """
    headers = sign_in(client, "+261320000003")
    db = _session()
    account = db.query(Account).filter(Account.phone == "+261320000003").one()
    account.role = UserRole.admin
    db.commit()
    return headers


def livreur(client: TestClient, phone: str = "+261330000002", soumis: bool = True) -> str:
    sign_in(client, phone, role="driver")
    db = _session()
    account = db.query(Account).filter(Account.phone == phone).one()
    if soumis:
        account.kyc_status = KycStatus.submitted
    db.commit()
    return account.id


class TestAcces:
    def test_un_expediteur_n_atteint_pas_l_exploitation(self, client: TestClient):
        headers = sign_in(client, "+261340000001", role="client")

        assert client.get("/admin/dashboard", headers=headers).status_code == 403

    def test_un_livreur_non_plus(self, client: TestClient):
        headers = sign_in(client, "+261330000002", role="driver")

        assert client.get("/admin/fleet", headers=headers).status_code == 403


class TestDossiers:
    def test_les_dossiers_soumis_apparaissent_dans_la_file(self, client: TestClient):
        admin = admin_headers(client)
        livreur(client)

        file = client.get("/admin/kyc", headers=admin).json()["items"]

        assert len(file) == 1
        assert file[0]["status"] == "submitted"

    def test_un_refus_sans_motif_est_impossible(self, client: TestClient):
        admin = admin_headers(client)
        driver_id = livreur(client)

        response = client.post(
            f"/admin/kyc/{driver_id}/review",
            json={"approve": False, "reason": "non"},
            headers=admin,
        )

        # Six mois plus tard, « non » ne repondra pas au livreur qui demande
        # pourquoi il ne travaille pas.
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "reason_too_short"

    def test_une_approbation_ouvre_le_travail_au_livreur(self, client: TestClient):
        admin = admin_headers(client)
        driver_id = livreur(client)
        headers_livreur = sign_in(client, "+261330000002")

        client.post(
            f"/admin/kyc/{driver_id}/review",
            json={"approve": True, "reason": "Permis et carte grise conformes"},
            headers=admin,
        )

        # Le livreur peut desormais passer en ligne — ce qui lui etait refuse.
        assert (
            client.post(
                "/driver/status", json={"online": True}, headers=headers_livreur
            ).status_code
            == 200
        )

    def test_la_decision_est_tracee_avec_son_auteur(self, client: TestClient):
        admin = admin_headers(client)
        driver_id = livreur(client)

        client.post(
            f"/admin/kyc/{driver_id}/review",
            json={"approve": False, "reason": "Photo du permis illisible"},
            headers=admin,
        )

        journal = client.get("/admin/moderation", headers=admin).json()["items"]
        assert journal[0]["action"] == "kyc_rejected"
        assert journal[0]["reason"] == "Photo du permis illisible"
        assert journal[0]["subjectId"] == driver_id


class TestSuspension:
    def test_un_livreur_suspendu_perd_l_acces(self, client: TestClient):
        admin = admin_headers(client)
        driver_id = livreur(client)
        headers_livreur = sign_in(client, "+261330000002")

        client.post(
            f"/admin/drivers/{driver_id}/suspension",
            json={"suspend": True, "reason": "Colis non remis, litige en cours"},
            headers=admin,
        )

        # Le jeton reste valide quinze minutes, mais la suspension prend effet a
        # la requete suivante : on ne fait pas attendre une decision.
        response = client.get("/me", headers=headers_livreur)
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "account_suspended"

    def test_la_suspension_coupe_la_disponibilite(self, client: TestClient):
        admin = admin_headers(client)
        driver_id = livreur(client)
        headers_livreur = sign_in(client, "+261330000002")
        client.post(
            f"/admin/kyc/{driver_id}/review",
            json={"approve": True, "reason": "Dossier complet et conforme"},
            headers=admin,
        )
        client.post("/driver/status", json={"online": True}, headers=headers_livreur)

        client.post(
            f"/admin/drivers/{driver_id}/suspension",
            json={"suspend": True, "reason": "Comportement signale par un client"},
            headers=admin,
        )

        # Laisser un suspendu « en ligne » le ferait apparaitre sur la carte et
        # recevoir des offres qu'il ne peut pas accepter.
        flotte = client.get("/admin/fleet", headers=admin).json()["items"]
        assert flotte[0]["online"] is False
        assert flotte[0]["suspended"] is True

    def test_la_levee_de_suspension_rend_l_acces(self, client: TestClient):
        admin = admin_headers(client)
        driver_id = livreur(client)
        headers_livreur = sign_in(client, "+261330000002")
        client.post(
            f"/admin/drivers/{driver_id}/suspension",
            json={"suspend": True, "reason": "Verification en cours du dossier"},
            headers=admin,
        )

        client.post(
            f"/admin/drivers/{driver_id}/suspension",
            json={"suspend": False, "reason": "Verification terminee, rien a signaler"},
            headers=admin,
        )

        assert client.get("/me", headers=headers_livreur).status_code == 200


class TestFlotte:
    def test_une_position_ancienne_est_signalee_comme_perimee(self, client: TestClient):
        admin = admin_headers(client)
        driver_id = livreur(client)
        headers_livreur = sign_in(client, "+261330000002")
        client.post(
            f"/admin/kyc/{driver_id}/review",
            json={"approve": True, "reason": "Dossier complet et conforme"},
            headers=admin,
        )
        client.post("/driver/status", json={"online": True}, headers=headers_livreur)

        vieux = (datetime.now(timezone.utc) - timedelta(minutes=30)).isoformat()
        client.post(
            "/driver/positions",
            json={"samples": [{"lat": -18.9, "lng": 47.5, "fixedAt": vieux}]},
            headers=headers_livreur,
        )

        flotte = client.get("/admin/fleet", headers=admin).json()["items"]

        # Un point qui ne dit pas son age est un mensonge : on croit voir ou est
        # quelqu'un alors qu'on voit ou il etait.
        assert flotte[0]["stale"] is True

    def test_une_position_fraiche_ne_l_est_pas(self, client: TestClient):
        admin = admin_headers(client)
        driver_id = livreur(client)
        headers_livreur = sign_in(client, "+261330000002")
        client.post(
            f"/admin/kyc/{driver_id}/review",
            json={"approve": True, "reason": "Dossier complet et conforme"},
            headers=admin,
        )
        client.post("/driver/status", json={"online": True}, headers=headers_livreur)

        maintenant = datetime.now(timezone.utc).isoformat()
        client.post(
            "/driver/positions",
            json={"samples": [{"lat": -18.9, "lng": 47.5, "fixedAt": maintenant}]},
            headers=headers_livreur,
        )

        flotte = client.get("/admin/fleet", headers=admin).json()["items"]
        assert flotte[0]["stale"] is False


class TestTableauDeBord:
    def test_la_recette_ne_compte_que_les_courses_remises(self, client: TestClient):
        admin = admin_headers(client)
        expediteur = sign_in(client, "+261340000001", role="client")
        driver_id = livreur(client)
        headers_livreur = sign_in(client, "+261330000002")
        client.post(
            f"/admin/kyc/{driver_id}/review",
            json={"approve": True, "reason": "Dossier complet et conforme"},
            headers=admin,
        )

        remise = client.post(
            "/deliveries", json=COURSE, headers={**expediteur, "Idempotency-Key": "a"}
        ).json()
        client.post(
            "/deliveries", json=COURSE, headers={**expediteur, "Idempotency-Key": "b"}
        )
        for etape in ("acceptee", "prise_en_charge", "en_transit", "livree"):
            client.post(
                f"/deliveries/{remise['id']}/transition",
                json={"status": etape},
                headers=headers_livreur,
            )

        tableau = client.get("/admin/dashboard", headers=admin).json()

        # Compter les courses en cours gonflerait le chiffre d'affaires
        # d'argent pas encore gagne.
        assert tableau["revenueToday"] == 6000
        assert tableau["pendingDeliveries"] == 1
        assert tableau["byStatus"]["livree"] == 1


class TestGestionUtilisateurs:
    """Annuaire des comptes et suspension client/livreur."""

    def test_l_annuaire_liste_par_role_et_cherche(self, client: TestClient):
        # On cree un client et un livreur, puis on interroge l'annuaire.
        sign_in(client, "+261340000001", role="client")
        sign_in(client, "+261330000002", role="driver")
        admin = admin_headers(client)

        clients = client.get(
            "/admin/users", params={"role": "client"}, headers=admin
        ).json()["items"]
        assert all(u["role"] == "client" for u in clients)
        assert any(u["phone"] == "+261340000001" for u in clients)

        drivers = client.get(
            "/admin/users", params={"role": "driver"}, headers=admin
        ).json()["items"]
        assert all(u["role"] == "driver" for u in drivers)

        # Recherche par numero.
        found = client.get(
            "/admin/users", params={"q": "340000001"}, headers=admin
        ).json()["items"]
        assert len(found) == 1

    def test_on_suspend_et_reactive_un_client(self, client: TestClient):
        sign_in(client, "+261340000001", role="client")
        db = _session()
        client_id = (
            db.query(Account).filter(Account.phone == "+261340000001").one().id
        )
        admin = admin_headers(client)

        suspended = client.post(
            f"/admin/users/{client_id}/suspension",
            json={"suspend": True, "reason": "Comportement signale a repetition"},
            headers=admin,
        ).json()
        assert suspended["suspended"] is True

        back = client.post(
            f"/admin/users/{client_id}/suspension",
            json={"suspend": False, "reason": "Explication recue, compte retabli"},
            headers=admin,
        ).json()
        assert back["suspended"] is False

    def test_un_motif_est_obligatoire(self, client: TestClient):
        sign_in(client, "+261340000001", role="client")
        db = _session()
        client_id = (
            db.query(Account).filter(Account.phone == "+261340000001").one().id
        )
        admin = admin_headers(client)
        response = client.post(
            f"/admin/users/{client_id}/suspension",
            json={"suspend": True, "reason": "non"},
            headers=admin,
        )
        assert response.status_code == 422

    def test_le_tableau_de_bord_compte_clients_livreurs_litiges(
        self, client: TestClient
    ):
        sign_in(client, "+261340000001", role="client")
        sign_in(client, "+261330000002", role="driver")
        admin = admin_headers(client)
        board = client.get("/admin/dashboard", headers=admin).json()
        assert board["totalClients"] >= 1
        assert board["totalDrivers"] >= 1
        assert "openDisputes" in board
        assert "openIncidents" in board


class TestStatistiques:
    """Rapport d'activite : volumes, taux, temps, zones, heures, performance."""

    def test_le_rapport_calcule_volumes_taux_et_zones(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        db = _session()
        db.query(Account).filter(Account.phone == "+261330000002").one().kyc_status = (
            KycStatus.approved
        )
        db.commit()

        # Une course menee jusqu'a la remise.
        course = client.post(
            "/deliveries", json=COURSE, headers={**expediteur, "Idempotency-Key": "s-1"}
        ).json()
        client.post(f"/deliveries/{course['id']}/accept", headers=livreur)
        for step in ("prise_en_charge", "en_transit", "livree"):
            client.post(
                f"/deliveries/{course['id']}/transition",
                json={"status": step},
                headers=livreur,
            )

        admin = admin_headers(client)
        report = client.get("/admin/stats", headers=admin).json()

        assert report["totalDeliveries"] >= 1
        assert report["delivered"] >= 1
        assert 0.0 <= report["successRate"] <= 1.0
        assert report["revenueAriary"] >= 6000
        # Le livreur touche moins que la recette (commission plateforme).
        assert report["driverEarningsAriary"] < report["revenueAriary"] or report[
            "revenueAriary"
        ] == 0
        assert len(report["peakHours"]) == 24
        # La zone de destination (« Ivandry ») remonte dans les zones actives.
        assert any(z["zone"] == "Ivandry" for z in report["topZones"])
        assert any(p["delivered"] >= 1 for p in report["driverPerformance"])

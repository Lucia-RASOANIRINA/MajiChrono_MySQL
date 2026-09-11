"""Module livreur.

Ces tests protegent deux choses que le terrain impose. Un livreur dont le
dossier n'est pas valide ne travaille pas (EXI-L01). Et une remontee de
positions faite apres une coupure — donc tardive, desordonnee, parfois envoyee
deux fois — ne doit ni echouer ni fausser ce que voit l'exploitation.
"""

from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app.models import Account, KycStatus
from tests.conftest import sign_in

COURSE = {
    "pickup": {"point": {"lat": -18.9, "lng": 47.5}, "summary": "Analakely"},
    "dropoff": {"point": {"lat": -18.87, "lng": 47.52}, "summary": "Ivandry"},
    "kind": "standard",
    "package": {"weight": "under5"},
    "price": 6000,
}


def approuver_kyc(client: TestClient, phone: str) -> None:
    """Valide le dossier en base.

    Il n'existe pas encore de route d'exploitation pour le faire ; ce test porte
    sur le livreur, pas sur le parcours d'approbation.
    """
    from app.db import get_db
    from app.main import app

    db = next(app.dependency_overrides[get_db]())
    account = db.query(Account).filter(Account.phone == phone).one()
    account.kyc_status = KycStatus.approved
    db.commit()


def livreur_pret(client: TestClient, phone: str = "+261330000002") -> dict:
    headers = sign_in(client, phone, role="driver")
    approuver_kyc(client, phone)
    client.post("/driver/status", json={"online": True}, headers=headers)
    return headers


class TestDisponibilite:
    def test_un_dossier_non_valide_interdit_de_passer_en_ligne(self, client: TestClient):
        headers = sign_in(client, "+261330000002", role="driver")

        response = client.post("/driver/status", json={"online": True}, headers=headers)

        assert response.status_code == 403
        assert response.json()["error"]["code"] == "kyc_not_approved"

    def test_un_expediteur_n_a_pas_acces_au_module_livreur(self, client: TestClient):
        headers = sign_in(client, "+261340000001", role="client")

        assert client.get("/driver/offers", headers=headers).status_code == 403

    def test_un_dossier_valide_permet_de_passer_en_ligne(self, client: TestClient):
        headers = sign_in(client, "+261330000002", role="driver")
        approuver_kyc(client, "+261330000002")

        response = client.post("/driver/status", json={"online": True}, headers=headers)

        assert response.status_code == 200
        assert response.json()["online"] is True


class TestOffres:
    def test_un_livreur_hors_ligne_ne_recoit_aucune_offre(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        client.post("/deliveries", json=COURSE, headers=expediteur)

        headers = sign_in(client, "+261330000002", role="driver")
        approuver_kyc(client, "+261330000002")

        assert client.get("/driver/offers", headers=headers).json()["items"] == []

    def test_les_courses_libres_sont_proposees(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        client.post("/deliveries", json=COURSE, headers=expediteur)
        livreur = livreur_pret(client)

        offres = client.get("/driver/offers", headers=livreur).json()["items"]

        assert len(offres) == 1
        assert offres[0]["price"] == 6000

    def test_l_offre_ne_livre_pas_l_adresse_exacte(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        client.post("/deliveries", json=COURSE, headers=expediteur)
        livreur = livreur_pret(client)

        offre = client.get("/driver/offers", headers=livreur).json()["items"][0]

        # Le quartier suffit pour decider ; le point exact appartient a
        # quelqu'un qui n'a rien demande.
        assert offre["dropoff"] == {"summary": "Ivandry"}
        assert "point" not in offre["dropoff"]

    def test_une_course_prise_disparait_des_offres(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        course = client.post("/deliveries", json=COURSE, headers=expediteur).json()
        premier = livreur_pret(client, "+261330000002")
        second = livreur_pret(client, "+261330000003")

        client.post(
            f"/deliveries/{course['id']}/transition",
            json={"status": "acceptee"},
            headers=premier,
        )

        assert client.get("/driver/offers", headers=second).json()["items"] == []


class TestPositions:
    def test_un_paquet_renvoye_ne_cree_pas_de_doublon(self, client: TestClient):
        livreur = livreur_pret(client)
        instant = datetime.now(timezone.utc).replace(microsecond=0)
        paquet = {
            "samples": [
                {"lat": -18.9, "lng": 47.5, "fixedAt": instant.isoformat()},
                {
                    "lat": -18.91,
                    "lng": 47.51,
                    "fixedAt": (instant + timedelta(seconds=30)).isoformat(),
                },
            ]
        }

        premier = client.post("/driver/positions", json=paquet, headers=livreur).json()
        second = client.post("/driver/positions", json=paquet, headers=livreur).json()

        assert premier["accepted"] == 2
        # Meme paquet rejoue apres une reponse perdue : rien de neuf, et surtout
        # aucune erreur.
        assert second == {"accepted": 0, "received": 2}

    def test_un_point_ancien_ne_fait_pas_reculer_le_livreur(self, client: TestClient):
        livreur = livreur_pret(client)
        recent = datetime.now(timezone.utc).replace(microsecond=0)
        ancien = recent - timedelta(minutes=20)

        client.post(
            "/driver/positions",
            json={"samples": [{"lat": -18.80, "lng": 47.60, "fixedAt": recent.isoformat()}]},
            headers=livreur,
        )
        # Paquet tamponne pendant la coupure, remonte apres le point recent.
        client.post(
            "/driver/positions",
            json={"samples": [{"lat": -18.95, "lng": 47.40, "fixedAt": ancien.isoformat()}]},
            headers=livreur,
        )

        etat = client.post(
            "/driver/status", json={"online": True}, headers=livreur
        ).json()
        assert etat["lat"] == -18.80

    def test_un_paquet_vide_est_accepte(self, client: TestClient):
        # Le mobile vide sa file meme quand elle ne contient rien : refuser
        # ferait remonter une erreur pour un non-evenement.
        livreur = livreur_pret(client)

        response = client.post("/driver/positions", json={"samples": []}, headers=livreur)

        assert response.status_code == 200
        assert response.json() == {"accepted": 0, "received": 0}


class TestGains:
    def test_seules_les_courses_remises_comptent(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = livreur_pret(client)

        remise = client.post(
            "/deliveries", json=COURSE, headers={**expediteur, "Idempotency-Key": "a"}
        ).json()
        en_cours = client.post(
            "/deliveries", json=COURSE, headers={**expediteur, "Idempotency-Key": "b"}
        ).json()

        for etape in ("acceptee", "prise_en_charge", "en_transit", "livree"):
            client.post(
                f"/deliveries/{remise['id']}/transition",
                json={"status": etape},
                headers=livreur,
            )
        client.post(
            f"/deliveries/{en_cours['id']}/transition",
            json={"status": "acceptee"},
            headers=livreur,
        )

        gains = client.get("/driver/earnings", headers=livreur).json()

        # Une course acceptee n'est pas un gain. Afficher 12 000 quand le
        # livreur en touchera 6 000 est la premiere cause de defiance.
        assert gains["deliveredCount"] == 1
        assert gains["totalAriary"] == 6000

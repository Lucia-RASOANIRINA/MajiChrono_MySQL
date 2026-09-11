"""Cycle de vie d'une course.

Les transitions sont ce que ce fichier protege. Une course ne saute pas d'etape
et ne revient jamais en arriere : un colis remis ne redevient pas un colis en
attente. Le serveur refuse par un 409 qui rappelle l'etat courant, ce qui permet
a l'application de reafficher la verite plutot que de laisser reessayer dans le
vide (EXI-B02).
"""

from fastapi.testclient import TestClient

from tests.conftest import sign_in

COURSE = {
    "pickup": {"point": {"lat": -18.9, "lng": 47.5}, "summary": "Analakely"},
    "dropoff": {"point": {"lat": -18.87, "lng": 47.52}, "summary": "Ivandry"},
    "kind": "standard",
    "package": {"weight": "under5"},
    "price": 6000,
}


def creer(client: TestClient, headers: dict, key: str = "k-1") -> dict:
    return client.post(
        "/deliveries", json=COURSE, headers={**headers, "Idempotency-Key": key}
    ).json()


class TestCreation:
    def test_seul_un_expediteur_cree_une_course(self, client: TestClient):
        livreur = sign_in(client, "+261330000002", role="driver")

        response = client.post("/deliveries", json=COURSE, headers=livreur)

        assert response.status_code == 403

    def test_la_meme_cle_ne_cree_pas_deux_courses(self, client: TestClient):
        # Le defaut que le scenario §16.2-3 cherche precisement : une reprise
        # apres coupure ne doit pas facturer deux fois le meme envoi.
        client_headers = sign_in(client, "+261340000001", role="client")

        premiere = creer(client, client_headers, key="reprise")
        seconde = creer(client, client_headers, key="reprise")

        assert premiere["id"] == seconde["id"]
        assert len(client.get("/deliveries", headers=client_headers).json()["items"]) == 1

    def test_deux_cles_distinctes_creent_deux_courses(self, client: TestClient):
        client_headers = sign_in(client, "+261340000001", role="client")

        creer(client, client_headers, key="a")
        creer(client, client_headers, key="b")

        assert len(client.get("/deliveries", headers=client_headers).json()["items"]) == 2

    def test_le_payeur_et_l_achat_pour_compte_sont_conserves(self, client: TestClient):
        # Ces champs etaient auparavant perdus au premier rafraichissement : le
        # mobile les envoyait, le serveur les ignorait (EXI-C07, EXI-C42).
        client_headers = sign_in(client, "+261340000001", role="client")
        shopping = {"cap": 20000, "items": [{"label": "Riz", "quantity": 2}]}
        created = client.post(
            "/deliveries",
            json={**COURSE, "payer": "recipient", "shopping": shopping},
            headers={**client_headers, "Idempotency-Key": "achat"},
        ).json()
        assert created["payer"] == "recipient"
        assert created["shopping"]["cap"] == 20000

        # Et ils survivent a une relecture.
        reread = client.get(f"/deliveries/{created['id']}", headers=client_headers).json()
        assert reread["payer"] == "recipient"
        assert reread["shopping"]["items"][0]["label"] == "Riz"


class TestTransitions:
    def test_un_livreur_accepte_puis_enleve_puis_remet(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        course = creer(client, expediteur)

        for etape in ("acceptee", "prise_en_charge", "en_transit", "livree"):
            response = client.post(
                f"/deliveries/{course['id']}/transition",
                json={"status": etape},
                headers=livreur,
            )
            assert response.status_code == 200, f"{etape} refuse"
            assert response.json()["status"] == etape

    def test_sauter_une_etape_est_refuse(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        course = creer(client, expediteur)
        client.post(
            f"/deliveries/{course['id']}/transition",
            json={"status": "acceptee"},
            headers=livreur,
        )

        response = client.post(
            f"/deliveries/{course['id']}/transition",
            json={"status": "livree"},
            headers=livreur,
        )

        assert response.status_code == 409
        # L'etat courant est rappele : l'application peut reafficher la verite.
        assert response.json()["error"]["details"]["currentState"] == "acceptee"

    def test_une_course_remise_ne_bouge_plus(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        course = creer(client, expediteur)
        for etape in ("acceptee", "prise_en_charge", "en_transit", "livree"):
            client.post(
                f"/deliveries/{course['id']}/transition",
                json={"status": etape},
                headers=livreur,
            )

        response = client.post(
            f"/deliveries/{course['id']}/transition",
            json={"status": "en_transit"},
            headers=livreur,
        )

        assert response.status_code == 409

    def test_deux_livreurs_ne_prennent_pas_la_meme_course(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        premier = sign_in(client, "+261330000002", role="driver")
        second = sign_in(client, "+261330000003", role="driver")
        course = creer(client, expediteur)

        client.post(
            f"/deliveries/{course['id']}/transition",
            json={"status": "acceptee"},
            headers=premier,
        )
        perdant = client.post(
            f"/deliveries/{course['id']}/transition",
            json={"status": "acceptee"},
            headers=second,
        )

        # Cas normal de la course a l'acceptation, pas une anomalie.
        assert perdant.status_code == 409
        assert perdant.json()["error"]["code"] == "already_taken"


class TestAnnulation:
    def test_l_expediteur_annule_avant_l_enlevement(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        course = creer(client, expediteur)

        response = client.post(f"/deliveries/{course['id']}/cancel", headers=expediteur)

        assert response.status_code == 200
        assert response.json()["status"] == "annulee"

    def test_apres_l_enlevement_l_annulation_devient_un_litige(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        course = creer(client, expediteur)
        for etape in ("acceptee", "prise_en_charge"):
            client.post(
                f"/deliveries/{course['id']}/transition",
                json={"status": etape},
                headers=livreur,
            )

        response = client.post(f"/deliveries/{course['id']}/cancel", headers=expediteur)

        # Le colis est chez le livreur : ce n'est plus un bouton, c'est un
        # litige.
        assert response.status_code == 409


class TestVisibilite:
    def test_un_livreur_etranger_ne_voit_pas_la_course(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        etranger = sign_in(client, "+261330000009", role="driver")
        course = creer(client, expediteur)

        response = client.get(f"/deliveries/{course['id']}", headers=etranger)

        # Meme reponse que pour une course inexistante : distinguer les deux
        # permettrait de decouvrir quels identifiants existent.
        assert response.status_code == 404

    def test_le_journal_retrace_chaque_transition(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        course = creer(client, expediteur)
        for etape in ("acceptee", "prise_en_charge"):
            client.post(
                f"/deliveries/{course['id']}/transition",
                json={"status": etape},
                headers=livreur,
            )

        detail = client.get(f"/deliveries/{course['id']}", headers=expediteur).json()

        # Creation, acceptation, enlevement. Une colonne `status` seule ne
        # raconterait rien du chemin, ni de qui l'a fait parcourir.
        assert [e["status"] for e in detail["events"]] == [
            "en_attente",
            "acceptee",
            "prise_en_charge",
        ]
        assert detail["events"][1]["actorId"] is not None


class TestSuiviPublic:
    def test_le_destinataire_voit_l_avancement_et_rien_d_autre(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        course = creer(client, expediteur)

        # Aucun en-tete d'autorisation : le destinataire n'installe rien.
        public = client.get(f"/track/{course['trackingToken']}")

        assert public.status_code == 200
        corps = public.json()
        assert corps["status"] == "en_attente"
        assert corps["dropoffSummary"] == "Ivandry"
        # Ni prix, ni numeros : ce sont des donnees des deux parties, pas de
        # celui qui attend a la porte.
        assert "price" not in corps
        assert "clientId" not in corps
        assert "driverId" not in corps

    def test_un_jeton_devine_n_ouvre_rien(self, client: TestClient):
        assert client.get("/track/nimportequoi").status_code == 404


class TestAnnulation:
    """Annulation par l'expediteur (EXI-C26) : possible avant la prise en
    charge, motivee, et facturee seulement si un livreur etait deja engage."""

    def test_avant_tout_livreur_est_gratuite(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        course = creer(client, expediteur)
        r = client.post(
            f"/deliveries/{course['id']}/cancel",
            json={"reason": "Changement d avis"},
            headers=expediteur,
        )
        assert r.status_code == 200
        body = r.json()
        assert body["status"] == "annulee"
        assert body["cancelFee"] == 0
        assert body["cancelReason"] == "Changement d avis"

    def test_apres_acceptation_retient_des_frais(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        course = creer(client, expediteur)
        client.post(
            f"/deliveries/{course['id']}/transition",
            json={"status": "acceptee"},
            headers=livreur,
        )
        r = client.post(
            f"/deliveries/{course['id']}/cancel",
            json={"reason": "Trop long"},
            headers=expediteur,
        )
        assert r.status_code == 200
        assert r.json()["status"] == "annulee"
        # 20 % de 6000 = 1200, au-dessus du plancher de 1000.
        assert r.json()["cancelFee"] == 1200

    def test_apres_prise_en_charge_est_refusee(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        course = creer(client, expediteur)
        for etape in ("acceptee", "prise_en_charge"):
            client.post(
                f"/deliveries/{course['id']}/transition",
                json={"status": etape},
                headers=livreur,
            )
        r = client.post(
            f"/deliveries/{course['id']}/cancel", json={}, headers=expediteur
        )
        assert r.status_code == 409

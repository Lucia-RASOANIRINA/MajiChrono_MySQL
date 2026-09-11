"""Parcours d'identite.

Ce que ces tests protegent tient en une phrase : **une adresse ne cree jamais un
compte**. Elle en ouvre un qui existe deja, ou elle renvoie vers le numero. Un
jour, quelqu'un trouvera plus court d'ouvrir la session directement apres le
code e-mail — ces tests sont la pour que ce raccourci casse bruyamment.
"""

from fastapi.testclient import TestClient

from tests.conftest import sign_in


class TestPhone:
    def test_un_numero_hors_plage_est_refuse(self, client: TestClient):
        # 035 n'est exploite par aucun operateur malgache. Le refuser tot evite
        # qu'un numero mal recopie parte en inscription et attende un SMS qui
        # n'arrivera jamais.
        response = client.post("/auth/otp/request", json={"phone": "+261350000001"})

        assert response.status_code == 422
        assert response.json()["error"]["code"] == "invalid_phone"

    def test_le_fixe_telma_est_accepte(self, client: TestClient):
        # Beaucoup de boutiques d'Antananarivo n'ont qu'un 020.
        assert client.post("/auth/otp/request", json={"phone": "+261200000001"}).status_code == 200

    def test_un_compte_nait_sans_profil(self, client: TestClient):
        headers = sign_in(client, "+261340000001")
        account = client.get("/me", headers=headers).json()

        # Le profil se pose ensuite, par PATCH /me (EXI-T02).
        assert account["role"] is None
        assert account["phone"] == "+261340000001"

    def test_trois_codes_faux_brulent_le_defi(self, client: TestClient):
        opened = client.post("/auth/otp/request", json={"phone": "+261340000001"}).json()
        assert opened["debugCode"] != "000000"

        for _ in range(3):
            client.post(
                "/auth/otp/verify",
                json={"challengeId": opened["challengeId"], "code": "000000"},
            )

        # Le defi n'existe plus : le bon code lui-meme ne l'ouvre plus.
        response = client.post(
            "/auth/otp/verify",
            json={"challengeId": opened["challengeId"], "code": opened["debugCode"]},
        )
        assert response.status_code == 422


class TestProfil:
    def test_le_role_exploitation_est_refuse_au_mobile(self, client: TestClient):
        headers = sign_in(client, "+261340000001")

        response = client.patch("/me", json={"role": "admin"}, headers=headers)

        # Refuse, et non ignore : ignorer laisserait croire que la demande a
        # abouti (EXI-T02).
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "role_not_assignable"

    def test_le_profil_ne_se_choisit_qu_une_fois(self, client: TestClient):
        headers = sign_in(client, "+261340000001", role="client")

        response = client.patch("/me", json={"role": "driver"}, headers=headers)

        # En changer changerait la nature du compte et l'historique qui s'y
        # rattache.
        assert response.status_code == 409

    def test_un_livreur_recoit_un_dossier_a_remplir(self, client: TestClient):
        headers = sign_in(client, "+261330000002", role="driver")

        assert client.get("/me", headers=headers).json()["kycStatus"] == "draft"


class TestEmail:
    def test_la_demande_ne_revele_pas_si_l_adresse_est_connue(self, client: TestClient):
        # Deux adresses, l'une rattachee et l'autre non : les reponses doivent
        # etre indiscernables, sinon ce point d'entree permet d'enumerer les
        # comptes.
        headers = sign_in(client, "+261340000001", role="client")
        client.post("/auth/email/link", json={"email": "connu@gmail.com"}, headers=headers)

        connu = client.post("/auth/email/request", json={"email": "connu@gmail.com"})
        inconnu = client.post("/auth/email/request", json={"email": "inconnu@gmail.com"})

        assert connu.status_code == inconnu.status_code == 200
        assert set(connu.json()) == set(inconnu.json())

    def test_une_adresse_inconnue_n_ouvre_aucune_session(self, client: TestClient):
        opened = client.post(
            "/auth/email/request", json={"email": "visiteur@gmail.com"}
        ).json()

        verified = client.post(
            "/auth/email/verify",
            json={"challengeId": opened["challengeId"], "code": opened["debugCode"]},
        ).json()

        # Adresse prouvee, compte inconnu. Aucune session : un compte sans
        # numero ne pourrait ni etre appele par un livreur, ni recevoir le SMS
        # de suivi (EXI-C24).
        assert verified == {"linked": False, "email": "visiteur@gmail.com"}

    def test_rattacher_puis_entrer_par_l_adresse(self, client: TestClient):
        headers = sign_in(client, "+261340000001", role="client")
        assert (
            client.post(
                "/auth/email/link", json={"email": "hery@gmail.com"}, headers=headers
            ).status_code
            == 204
        )

        opened = client.post("/auth/email/request", json={"email": "hery@gmail.com"}).json()
        verified = client.post(
            "/auth/email/verify",
            json={"challengeId": opened["challengeId"], "code": opened["debugCode"]},
        ).json()

        assert verified["linked"] is True
        assert verified["account"]["phone"] == "+261340000001"

    def test_une_adresse_ne_vaut_que_pour_un_compte(self, client: TestClient):
        premier = sign_in(client, "+261340000001", role="client")
        client.post("/auth/email/link", json={"email": "pris@gmail.com"}, headers=premier)

        second = sign_in(client, "+261340000009", role="client")
        response = client.post(
            "/auth/email/link", json={"email": "pris@gmail.com"}, headers=second
        )

        # Sinon un meme e-mail ouvrirait deux identites, et le prochain code
        # recu ne dirait plus laquelle.
        assert response.status_code == 409


class TestSession:
    def test_un_jeton_rejoue_revoque_toute_la_famille(self, client: TestClient):
        opened = client.post("/auth/otp/request", json={"phone": "+261340000001"}).json()
        session = client.post(
            "/auth/otp/verify",
            json={"challengeId": opened["challengeId"], "code": opened["debugCode"]},
        ).json()["session"]

        premier = client.post(
            "/auth/refresh", json={"refreshToken": session["refreshToken"]}
        )
        assert premier.status_code == 200

        # Meme jeton presente une seconde fois : quelqu'un rejoue un jeton vole.
        rejeu = client.post(
            "/auth/refresh", json={"refreshToken": session["refreshToken"]}
        )
        assert rejeu.status_code == 401

        # Toute la famille tombe — y compris le jeton legitime issu de la
        # premiere rotation. Mieux vaut une reconnexion qu'un acces partage a
        # son insu.
        nouveau = premier.json()["session"]["refreshToken"]
        assert client.post("/auth/refresh", json={"refreshToken": nouveau}).status_code == 401

    def test_sans_jeton_me_est_refuse(self, client: TestClient):
        assert client.get("/me").status_code == 401

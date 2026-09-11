"""Gestion du compte : mot de passe, changement d'e-mail/numero, photo.

Ces parcours ont un point commun : ils **modifient** un compte deja ouvert, la
ou l'inscription ne fait que le creer. On verifie donc surtout les garde-fous —
preuve de possession avant de deplacer une cle d'identite, ancien mot de passe
avant d'en poser un nouveau, unicite du numero et de l'adresse.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import sign_in

# PNG 1x1 transparent, le plus petit fichier image valide.
_PNG_1x1 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
    "YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
)


def _open_email_change(client: TestClient, email: str, headers: dict) -> dict:
    """Demande un code de changement d'adresse et rend {challengeId, debugCode}."""
    return client.post(
        "/auth/email/change/request", json={"email": email}, headers=headers
    ).json()


class TestMotDePasse:
    def test_un_compte_par_numero_peut_se_poser_un_mot_de_passe(self, client: TestClient):
        headers = sign_in(client, "+261340000010")
        # Pas de mot de passe encore : on le pose sans ancien.
        r = client.post(
            "/auth/password/change", json={"newPassword": "motdepasse1"}, headers=headers
        )
        assert r.status_code == 204

    def test_changer_exige_l_ancien_mot_de_passe(self, client: TestClient):
        headers = sign_in(client, "+261340000011")
        client.post(
            "/auth/password/change", json={"newPassword": "premier12"}, headers=headers
        )
        # Mauvais ancien -> refuse.
        bad = client.post(
            "/auth/password/change",
            json={"currentPassword": "faux", "newPassword": "second12x"},
            headers=headers,
        )
        # 403 (session valide, preuve fausse) et non 401 (jeton expire).
        assert bad.status_code == 403
        # Bon ancien -> accepte.
        ok = client.post(
            "/auth/password/change",
            json={"currentPassword": "premier12", "newPassword": "second12x"},
            headers=headers,
        )
        assert ok.status_code == 204

    def test_mot_de_passe_trop_court_refuse(self, client: TestClient):
        headers = sign_in(client, "+261340000012")
        r = client.post(
            "/auth/password/change", json={"newPassword": "court"}, headers=headers
        )
        assert r.status_code == 422

    def test_oublie_repose_le_mot_de_passe_via_le_code_email(self, client: TestClient):
        headers = sign_in(client, "+261340000013")
        # Rattache une adresse, puis pose un premier mot de passe.
        opened = _open_email_change(client, "rina@example.com", headers)
        client.post(
            "/auth/email/change/verify",
            json={"challengeId": opened["challengeId"], "code": opened["debugCode"]},
            headers=headers,
        )
        client.post(
            "/auth/password/change", json={"newPassword": "ancien123"}, headers=headers
        )

        # Oublie : on demande un code par e-mail, puis on repose le mot de passe.
        opened = client.post(
            "/auth/email/request", json={"email": "rina@example.com"}
        ).json()
        reset = client.post(
            "/auth/password/reset",
            json={
                "challengeId": opened["challengeId"],
                "code": opened["debugCode"],
                "newPassword": "nouveau123",
            },
        )
        assert reset.status_code == 204

        # Le nouveau mot de passe ouvre une session, l'ancien non.
        good = client.post(
            "/auth/password/signin",
            json={"email": "rina@example.com", "password": "nouveau123"},
        )
        assert good.status_code == 200 and good.json()["linked"] is True
        bad = client.post(
            "/auth/password/signin",
            json={"email": "rina@example.com", "password": "ancien123"},
        )
        assert bad.status_code == 401


class TestChangementEmail:
    def test_rattache_apres_verification_du_code(self, client: TestClient):
        headers = sign_in(client, "+261340000020")
        opened = _open_email_change(client, "tovo@example.com", headers)
        r = client.post(
            "/auth/email/change/verify",
            json={"challengeId": opened["challengeId"], "code": opened["debugCode"]},
            headers=headers,
        )
        assert r.status_code == 200
        assert r.json()["email"] == "tovo@example.com"

    def test_une_adresse_deja_prise_est_refusee(self, client: TestClient):
        # Un premier compte prend l'adresse.
        h1 = sign_in(client, "+261340000021")
        opened = _open_email_change(client, "occupe@example.com", h1)
        client.post(
            "/auth/email/change/verify",
            json={"challengeId": opened["challengeId"], "code": opened["debugCode"]},
            headers=h1,
        )
        # Un second ne peut pas la reprendre.
        h2 = sign_in(client, "+261340000022")
        r = client.post(
            "/auth/email/change/request", json={"email": "occupe@example.com"}, headers=h2
        )
        assert r.status_code == 409


class TestChangementNumero:
    def test_deplace_le_numero_apres_sms(self, client: TestClient):
        headers = sign_in(client, "+261340000030")
        opened = client.post(
            "/auth/phone/change/request", json={"phone": "+261340000031"}, headers=headers
        ).json()
        r = client.post(
            "/auth/phone/change/verify",
            json={"challengeId": opened["challengeId"], "code": opened["debugCode"]},
            headers=headers,
        )
        assert r.status_code == 200
        assert r.json()["phone"] == "+261340000031"

    def test_un_numero_deja_pris_est_refuse(self, client: TestClient):
        sign_in(client, "+261340000040")  # occupe ce numero
        headers = sign_in(client, "+261340000041")
        r = client.post(
            "/auth/phone/change/request", json={"phone": "+261340000040"}, headers=headers
        )
        assert r.status_code == 409


class TestAvatar:
    def test_pose_lit_puis_efface_la_photo(self, client: TestClient):
        headers = sign_in(client, "+261340000050")
        up = client.post(
            "/me/avatar",
            json={"imageBase64": _PNG_1x1, "contentType": "image/png"},
            headers=headers,
        )
        assert up.status_code == 200
        url = up.json()["avatarUrl"]
        assert url and "/avatar" in url

        # La route de lecture rend bien une image, sans jeton.
        path = url.split(str(client.base_url))[-1] if str(client.base_url) in url else url
        got = client.get(path)
        assert got.status_code == 200
        assert got.headers["content-type"].startswith("image/")

        # Suppression : plus d'URL, la lecture retombe en 404.
        gone = client.delete("/me/avatar", headers=headers)
        assert gone.status_code == 200 and gone.json()["avatarUrl"] is None
        assert client.get(path).status_code == 404

    def test_un_format_non_image_est_refuse(self, client: TestClient):
        headers = sign_in(client, "+261340000051")
        r = client.post(
            "/me/avatar",
            json={"imageBase64": _PNG_1x1, "contentType": "application/pdf"},
            headers=headers,
        )
        assert r.status_code == 422


def _sign_in_device(client: TestClient, phone: str, device: str) -> dict:
    opened = client.post("/auth/otp/request", json={"phone": phone}).json()
    verified = client.post(
        "/auth/otp/verify",
        json={"challengeId": opened["challengeId"], "code": opened["debugCode"]},
        headers={"X-Device": device},
    ).json()
    return {"Authorization": f"Bearer {verified['session']['accessToken']}"}


class TestNomPrenom:
    def test_pose_prenom_et_nom_puis_recompose_le_nom_d_usage(self, client: TestClient):
        headers = sign_in(client, "+261340000060")
        r = client.patch(
            "/me",
            json={"firstName": "Rina", "lastName": "Rakoto"},
            headers=headers,
        )
        assert r.status_code == 200
        body = r.json()
        assert body["firstName"] == "Rina"
        assert body["lastName"] == "Rakoto"
        assert body["displayName"] == "Rina Rakoto"


class TestSessions:
    def test_liste_les_appareils_marque_le_courant_et_revoque(self, client: TestClient):
        # Deux connexions du meme compte = deux sessions distinctes.
        _sign_in_device(client, "+261340000061", "Pixel 9")
        current = _sign_in_device(client, "+261340000061", "iPhone")

        sessions = client.get("/auth/sessions", headers=current).json()
        assert len(sessions) == 2
        assert {s["deviceLabel"] for s in sessions} == {"Pixel 9", "iPhone"}
        # Exactement une session marquee « cet appareil-ci ».
        assert sum(1 for s in sessions if s["current"]) == 1

        other = next(s for s in sessions if not s["current"])
        gone = client.delete(f"/auth/sessions/{other['id']}", headers=current)
        assert gone.status_code == 204

        after = client.get("/auth/sessions", headers=current).json()
        assert len(after) == 1
        assert after[0]["current"] is True

    def test_revoquer_une_session_inconnue_repond_404(self, client: TestClient):
        headers = sign_in(client, "+261340000062")
        assert client.delete("/auth/sessions/inexistante", headers=headers).status_code == 404

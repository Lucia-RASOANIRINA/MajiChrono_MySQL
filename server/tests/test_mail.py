"""Comportement du serveur quand l'envoi echoue.

Le cas nominal — un e-mail qui part — ne peut pas etre teste sans compte
fournisseur. Ce qui **peut** l'etre, et qui compte autant, c'est ce que voit
l'utilisateur quand l'envoi echoue : ni une erreur 500, ni un faux « code
envoye ».
"""

from contextlib import contextmanager
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.config import get_settings


@contextmanager
def _environment(value: str):
    """Force l'environnement du serveur le temps d'un test.

    L'echec d'envoi se comporte differemment selon l'environnement : une vraie
    panne signalee en production, une gene sans consequence en developpement.
    On teste donc les deux, en fixant l'environnement plutot qu'en dependant de
    celui de la machine.
    """
    settings = get_settings()
    saved = settings.environment
    settings.environment = value
    try:
        yield
    finally:
        settings.environment = saved


class TestEchecEnvoi:
    def test_un_envoi_refuse_ne_remonte_pas_en_500(self, client: TestClient):
        with _environment("prod"), patch(
            "app.routers.auth.send_login_code",
            side_effect=RuntimeError("mail_provider_rejected"),
        ):
            response = client.post(
                "/auth/email/request", json={"email": "hery@gmail.com"}
            )

        # 502 et non 500 : la panne est chez le fournisseur, pas chez nous, et
        # l'application sait afficher un message pour ce code.
        assert response.status_code == 502
        assert response.json()["error"]["code"] == "mail_delivery_failed"

    def test_un_defi_non_envoye_est_brule_en_production(self, client: TestClient):
        # Personne n'a recu ce code : le laisser ouvert cinq minutes reviendrait
        # a laisser six chiffres devinables proteger un compte.
        with _environment("prod"), patch(
            "app.routers.auth.send_login_code", side_effect=RuntimeError()
        ):
            client.post("/auth/email/request", json={"email": "hery@gmail.com"})

        from app.db import get_db
        from app.main import app
        from app.models import Challenge

        db = next(app.dependency_overrides[get_db]())
        challenge = db.query(Challenge).one()
        assert challenge.consumed_at is not None
        assert challenge.is_usable is False

    def test_en_developpement_un_envoi_refuse_ne_bloque_pas(self, client: TestClient):
        # En dev, Resend refuse toute adresse autre que celle du proprietaire du
        # compte tant qu'un domaine n'est pas verifie. Faire capoter le parcours
        # pour cette seule raison rendrait l'inscription par e-mail intestable en
        # local : on journalise, on garde le defi ouvert, et le code reste
        # disponible via `debugCode`.
        with _environment("dev"), patch(
            "app.routers.auth.send_login_code", side_effect=RuntimeError()
        ):
            response = client.post(
                "/auth/email/request", json={"email": "hery@gmail.com"}
            )

        assert response.status_code == 200
        assert response.json()["debugCode"]

        from app.db import get_db
        from app.main import app
        from app.models import Challenge

        db = next(app.dependency_overrides[get_db]())
        challenge = db.query(Challenge).one()
        # Le defi reste utilisable : le developpeur peut saisir le code.
        assert challenge.is_usable is True

    def test_un_sms_refuse_se_dit_franchement(self, client: TestClient):
        with patch("app.routers.auth.send_sms_code", side_effect=RuntimeError()):
            response = client.post(
                "/auth/otp/request", json={"phone": "+261340000001"}
            )

        assert response.status_code == 502
        assert response.json()["error"]["code"] == "sms_delivery_failed"

"""Acceptation avec regle de distance, et discussion de course.

On verifie trois choses d'un coup : qu'une course trop eloignee ne peut pas
etre acceptee, que l'acceptation ouvre bien la discussion, et que cette
discussion reste fermee a qui n'est pas l'expediteur ou le livreur assigne.
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi.testclient import TestClient

from tests.conftest import approve_kyc, sign_in

# Retrait a Analakely. Un livreur pose au meme point est a portee ; un livreur a
# plus de cent kilometres ne l'est pas.
COURSE = {
    "pickup": {"point": {"lat": -18.9, "lng": 47.5}, "summary": "Analakely"},
    "dropoff": {"point": {"lat": -18.87, "lng": 47.52}, "summary": "Ivandry"},
    "kind": "standard",
    "package": {"weight": "under5"},
    "price": 6000,
}


def _creer(client: TestClient, headers: dict, key: str = "c-1") -> dict:
    return client.post(
        "/deliveries", json=COURSE, headers={**headers, "Idempotency-Key": key}
    ).json()


def _poser_position(client: TestClient, livreur: dict, lat: float, lng: float):
    now = datetime.now(timezone.utc).isoformat()
    client.post(
        "/driver/positions",
        json={"samples": [{"lat": lat, "lng": lng, "fixedAt": now}]},
        headers=livreur,
    )


class TestDistanceAcceptation:
    def test_course_trop_loin_est_refusee(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        approve_kyc("+261330000002")
        course = _creer(client, expediteur)

        # Cent kilometres au sud : hors de portee.
        _poser_position(client, livreur, -20.0, 47.5)
        response = client.post(f"/deliveries/{course['id']}/accept", headers=livreur)

        assert response.status_code == 422
        assert response.json()["error"]["code"] == "too_far"

    def test_course_proche_est_acceptee(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        approve_kyc("+261330000002")
        course = _creer(client, expediteur)

        _poser_position(client, livreur, -18.9, 47.5)
        response = client.post(f"/deliveries/{course['id']}/accept", headers=livreur)

        assert response.status_code == 200
        assert response.json()["status"] == "acceptee"
        assert response.json()["driverId"] is not None

    def test_un_livreur_non_valide_ne_peut_pas_accepter(self, client: TestClient):
        # EXI-L01 : tant que le dossier n'est pas valide, pas de course. Le mobile
        # reconnait `kyc_not_approved` pour afficher « compte pas encore actif ».
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        course = _creer(client, expediteur)

        response = client.post(
            f"/deliveries/{course['id']}/accept", headers=livreur
        )
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "kyc_not_approved"

    def test_sans_position_l_acceptation_passe(self, client: TestClient):
        # Faute de position, on ne peut pas juger : on laisse passer plutot que
        # de bloquer un livreur dont le GPS n'a pas encore accroche.
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        approve_kyc("+261330000002")
        course = _creer(client, expediteur)

        response = client.post(f"/deliveries/{course['id']}/accept", headers=livreur)
        assert response.status_code == 200


class TestDiscussion:
    def _course_acceptee(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        approve_kyc("+261330000002")
        course = _creer(client, expediteur)
        client.post(f"/deliveries/{course['id']}/accept", headers=livreur)
        return expediteur, livreur, course

    def test_pas_de_discussion_avant_acceptation(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        course = _creer(client, expediteur)
        response = client.get(
            f"/deliveries/{course['id']}/messages", headers=expediteur
        )
        assert response.status_code == 404

    def test_les_deux_parties_echangent(self, client: TestClient):
        expediteur, livreur, course = self._course_acceptee(client)

        envoi = client.post(
            f"/deliveries/{course['id']}/messages",
            json={"body": "Je suis en bas"},
            headers=livreur,
        )
        assert envoi.status_code == 200

        vu = client.get(
            f"/deliveries/{course['id']}/messages", headers=expediteur
        ).json()
        assert [m["body"] for m in vu["items"]] == ["Je suis en bas"]

    def test_un_tiers_ne_voit_pas_la_discussion(self, client: TestClient):
        _, _, course = self._course_acceptee(client)
        intrus = sign_in(client, "+261320000009", role="client")
        response = client.get(
            f"/deliveries/{course['id']}/messages", headers=intrus
        )
        assert response.status_code == 404

    def test_accuse_de_lecture(self, client: TestClient):
        # Le livreur ecrit ; tant que l'expediteur n'a pas ouvert, c'est
        # « envoye » (readAt nul). Des qu'il marque lu, l'accuse se pose, et le
        # livreur le voit sur son propre message.
        expediteur, livreur, course = self._course_acceptee(client)
        client.post(
            f"/deliveries/{course['id']}/messages",
            json={"body": "Je suis en bas"},
            headers=livreur,
        )

        avant = client.get(
            f"/deliveries/{course['id']}/messages", headers=livreur
        ).json()
        assert avant["items"][0]["readAt"] is None

        marque = client.post(
            f"/deliveries/{course['id']}/messages/read", headers=expediteur
        )
        assert marque.status_code == 200
        assert marque.json()["marked"] == 1

        apres = client.get(
            f"/deliveries/{course['id']}/messages", headers=livreur
        ).json()
        assert apres["items"][0]["readAt"] is not None

        # Idempotent : rien de neuf a marquer au second passage.
        rejoue = client.post(
            f"/deliveries/{course['id']}/messages/read", headers=expediteur
        )
        assert rejoue.json()["marked"] == 0

    def test_on_ne_marque_pas_ses_propres_messages(self, client: TestClient):
        # Marquer « lu » ne concerne que les messages recus : celui qu'on a
        # ecrit soi-meme ne devient pas « lu » parce qu'on rouvre l'ecran.
        expediteur, livreur, course = self._course_acceptee(client)
        client.post(
            f"/deliveries/{course['id']}/messages",
            json={"body": "Bien recu"},
            headers=expediteur,
        )
        marque = client.post(
            f"/deliveries/{course['id']}/messages/read", headers=expediteur
        )
        assert marque.json()["marked"] == 0

    def test_le_curseur_after_ne_rend_que_le_nouveau(self, client: TestClient):
        expediteur, livreur, course = self._course_acceptee(client)
        premier = client.post(
            f"/deliveries/{course['id']}/messages",
            json={"body": "un"},
            headers=expediteur,
        ).json()

        client.post(
            f"/deliveries/{course['id']}/messages",
            json={"body": "deux"},
            headers=livreur,
        )

        apres = client.get(
            f"/deliveries/{course['id']}/messages",
            params={"after": premier["createdAt"]},
            headers=expediteur,
        ).json()
        assert [m["body"] for m in apres["items"]] == ["deux"]


class TestBoiteDeReception:
    """Espace « Messages » : la liste des conversations."""

    def _course_acceptee(self, client: TestClient):
        expediteur = sign_in(client, "+261340000001", role="client")
        livreur = sign_in(client, "+261330000002", role="driver")
        approve_kyc("+261330000002")
        course = _creer(client, expediteur)
        client.post(f"/deliveries/{course['id']}/accept", headers=livreur)
        return expediteur, livreur, course

    def test_une_conversation_apparait_avec_dernier_message_et_non_lus(
        self, client: TestClient
    ):
        expediteur, livreur, course = self._course_acceptee(client)
        client.post(
            f"/deliveries/{course['id']}/messages",
            json={"body": "Je suis en bas"},
            headers=livreur,
        )

        inbox = client.get("/conversations", headers=expediteur).json()["items"]
        assert len(inbox) == 1
        convo = inbox[0]
        assert convo["deliveryId"] == course["id"]
        assert convo["lastMessage"] == "Je suis en bas"
        # Message recu du livreur, pas encore lu par l'expediteur.
        assert convo["unread"] == 1

        # Une fois lu, la conversation ne compte plus de non-lus.
        client.post(f"/deliveries/{course['id']}/messages/read", headers=expediteur)
        inbox = client.get("/conversations", headers=expediteur).json()["items"]
        assert inbox[0]["unread"] == 0

    def test_une_course_sans_message_n_apparait_pas(self, client: TestClient):
        expediteur, _livreur, _course = self._course_acceptee(client)
        inbox = client.get("/conversations", headers=expediteur).json()["items"]
        assert inbox == []

    def test_un_tiers_n_a_pas_la_conversation(self, client: TestClient):
        _expediteur, livreur, course = self._course_acceptee(client)
        client.post(
            f"/deliveries/{course['id']}/messages",
            json={"body": "coucou"},
            headers=livreur,
        )
        intrus = sign_in(client, "+261340000055", role="client")
        inbox = client.get("/conversations", headers=intrus).json()["items"]
        assert inbox == []

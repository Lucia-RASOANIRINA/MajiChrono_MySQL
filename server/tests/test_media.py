"""Media : televersement et lecture d'une photo (photo du colis, EXI-C09)."""

from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import sign_in

_PNG = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
    "YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
)


class TestMedia:
    def test_televerse_puis_lit(self, client: TestClient):
        headers = sign_in(client, "+261340000200")
        up = client.post(
            "/media",
            json={"imageBase64": _PNG, "contentType": "image/png"},
            headers=headers,
        )
        assert up.status_code == 201
        media_id = up.json()["id"]

        got = client.get(f"/media/{media_id}", headers=headers)
        assert got.status_code == 200
        assert got.headers["content-type"].startswith("image/")

    def test_un_format_non_image_refuse(self, client: TestClient):
        headers = sign_in(client, "+261340000201")
        r = client.post(
            "/media",
            json={"imageBase64": _PNG, "contentType": "text/plain"},
            headers=headers,
        )
        assert r.status_code == 422

    def test_lecture_exige_un_jeton(self, client: TestClient):
        headers = sign_in(client, "+261340000202")
        media_id = client.post(
            "/media",
            json={"imageBase64": _PNG, "contentType": "image/png"},
            headers=headers,
        ).json()["id"]
        # Sans en-tete d'autorisation : refuse.
        assert client.get(f"/media/{media_id}").status_code == 401

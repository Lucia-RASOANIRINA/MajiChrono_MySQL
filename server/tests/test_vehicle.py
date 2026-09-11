"""Fiche vehicule du livreur (§22).

Ce que ces tests protegent : la fiche appartient au livreur (un client n'y
touche pas), un type inconnu est refuse, et toute modification remet la
validation en attente — une fiche changee n'est plus celle qu'on avait vue.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.models import Account, DriverVehicle
from tests.conftest import sign_in

DRIVER_PHONE = "+261330000002"
CLIENT_PHONE = "+261340000001"


def _session():
    from app.db import get_db
    from app.main import app

    return next(app.dependency_overrides[get_db]())


class TestFicheVehicule:
    def test_vide_par_defaut(self, client: TestClient):
        driver = sign_in(client, DRIVER_PHONE, role="driver")
        body = client.get("/driver/vehicle", headers=driver).json()
        assert body["type"] is None

    def test_enregistrement_et_relecture(self, client: TestClient):
        driver = sign_in(client, DRIVER_PHONE, role="driver")
        saved = client.patch(
            "/driver/vehicle",
            json={
                "type": "moto",
                "brand": "Yamaha",
                "model": "Crux",
                "plate": "1234 TBA",
                "insuranceExpiry": "2027-01-31",
            },
            headers=driver,
        ).json()
        assert saved["brand"] == "Yamaha"
        assert saved["validation"] == "pending"

        reread = client.get("/driver/vehicle", headers=driver).json()
        assert reread["plate"] == "1234 TBA"

    def test_un_type_inconnu_est_refuse(self, client: TestClient):
        driver = sign_in(client, DRIVER_PHONE, role="driver")
        response = client.patch(
            "/driver/vehicle", json={"type": "avion"}, headers=driver
        )
        assert response.status_code == 422

    def test_une_modification_remet_en_attente(self, client: TestClient):
        driver = sign_in(client, DRIVER_PHONE, role="driver")
        client.patch("/driver/vehicle", json={"type": "moto"}, headers=driver)

        # L'exploitation valide la fiche...
        db = _session()
        account = db.query(Account).filter(Account.phone == DRIVER_PHONE).one()
        vehicle = db.get(DriverVehicle, account.id)
        vehicle.validation = "validated"
        db.commit()

        # ... puis le livreur la retouche : elle repasse en attente.
        after = client.patch(
            "/driver/vehicle",
            json={"type": "moto", "brand": "Honda"},
            headers=driver,
        ).json()
        assert after["validation"] == "pending"

    def test_un_client_n_a_pas_de_fiche_vehicule(self, client: TestClient):
        clt = sign_in(client, CLIENT_PHONE, role="client")
        assert client.get("/driver/vehicle", headers=clt).status_code == 403
        assert (
            client.patch(
                "/driver/vehicle", json={"type": "moto"}, headers=clt
            ).status_code
            == 403
        )

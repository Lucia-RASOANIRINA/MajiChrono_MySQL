"""Envoi de SMS par la passerelle malgache mAPI.

Choisie parce qu'elle est **locale** : les codes partent d'un numero court
malgache, arrivent sur Orange, Airtel et Telma sans transiter par un
agregateur etranger, et ne se font pas filtrer comme du trafic international.
C'est la difference entre un code qui arrive en trois secondes et un code qui
n'arrive pas.

Tant que `SMS_API_KEY` est vide, **rien n'est envoye** : le code part dans le
journal. C'est volontaire et c'est une consigne — le quota d'essai gratuit ne
doit pas etre consomme par les tests automatises ni par le developpement. Le
premier vrai envoi doit etre un geste humain, decide.
"""

from __future__ import annotations

import logging

import httpx

from app.config import get_settings

logger = logging.getLogger("majichrono.sms")

# Point d'entree de la passerelle. Il est ici, en clair, parce que ce n'est pas
# un secret : seule la cle en est un.
MAPI_URL = "https://messaging.mapi.mg/api/sms/send"


async def send_login_code(phone_e164: str, code: str) -> None:
    """Signale que l'envoi SMS réel n'est pas encore disponible.

    Le fournisseur est volontairement désactivé tant que son intégration n'a
    pas été validée en production. Aucun code ni appel réseau n'est effectué.
    """
    logger.info(
        "SMS réel à venir — code non envoyé (fonctionnalité indisponible), "
        "destinataire=%s",
        _mask(phone_e164),
    )
    return

    # Message court et sans lien. Deux raisons : un SMS depasse 160 caracteres
    # devient deux SMS factures, et un lien dans un SMS de code entraine les
    # utilisateurs a cliquer — exactement le reflexe qu'exploite l'hameconnage.
    text = (
        f"MajiChrono : votre code est {code}. "
        "Valable 5 min. Ne le communiquez a personne."
    )

    payload = {
        "to": phone_e164,
        "message": text,
        "sender": settings.sms_sender,
    }

    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.post(
            MAPI_URL,
            json=payload,
            headers={
                "Authorization": f"Bearer {settings.sms_api_key}",
                "Accept": "application/json",
            },
        )

    if response.status_code >= 400:
        # Le detail du fournisseur reste dans le journal : il peut contenir le
        # numero, qui n'a pas a remonter jusqu'au mobile (EXI-T10).
        logger.error(
            "envoi SMS refuse status=%s corps=%s",
            response.status_code,
            response.text[:500],
        )
        raise RuntimeError("sms_provider_rejected")

    logger.info("code SMS envoye a %s", _mask(phone_e164))


def _mask(phone: str) -> str:
    """`+261340000001` devient `+261 ** ** *** 01` (EXI-T10)."""
    return f"{phone[:4]} ** ** *** {phone[-2:]}" if len(phone) >= 6 else "***"

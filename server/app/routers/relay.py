"""Reseau de points relais partenaires (differenciant D6, §7 client).

Les relais sont des **donnees de reference** : des boutiques de quartier avec
leurs vraies contraintes — horaires, poids maximal, duree de garde. Elles ne
dependent d'aucun compte et ne changent pas d'une requete a l'autre, si bien
qu'elles vivent ici en dur plutot que dans une table que personne n'editerait.
Un relais qui accepterait tout ne serait pas un relais, ce serait un entrepot.

Le service se contente de filtrer par quartier et, si l'appelant donne sa
position, de trier du plus proche au plus loin : proposer les relais de toute
l'agglomeration a quelqu'un qui livre a Ambohipo lui ferait faire defiler une
liste dont dix-neuf entrees sur vingt sont hors sujet.
"""

from __future__ import annotations

from math import asin, cos, radians, sin, sqrt

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import current_account
from app.db import get_db
from app.models import Account

router = APIRouter(prefix="/relay-points", tags=["relay"])

# Reseau partenaire. Aligne sur le simulateur (differentiators_mock_module) pour
# que le contrat soit identique entre le bac a sable et le serveur reel.
RELAY_POINTS: list[dict] = [
    {
        "id": "rel_1",
        "name": "Epicerie Tsiky",
        "district": "Ambohipo",
        "landmark": "Portail vert, apres le pont",
        "point": {"lat": -18.9105, "lng": 47.5570},
        "openingHours": "Lun-Sam 7h-19h",
        "phone": "+261340000011",
        "acceptsDropoff": True,
        "acceptsPickup": True,
        "maxWeightKg": 15.0,
        "storageDays": 3,
    },
    {
        "id": "rel_2",
        "name": "Quincaillerie Rary",
        "district": "Analakely",
        "landmark": "Face a l escalier, boutique bleue",
        "point": {"lat": -18.9080, "lng": 47.5250},
        "openingHours": "Lun-Ven 8h-18h",
        "phone": "+261320000022",
        "acceptsDropoff": True,
        "acceptsPickup": True,
        # Une quincaillerie a de la place : elle prend plus lourd.
        "maxWeightKg": 30.0,
        "storageDays": 5,
    },
    {
        "id": "rel_3",
        "name": "Kiosque Ivandry",
        "district": "Ivandry",
        "landmark": "Derriere la station, mur blanc",
        "point": {"lat": -18.8760, "lng": 47.5310},
        "openingHours": "Tous les jours 6h-20h",
        "acceptsDropoff": False,
        "acceptsPickup": True,
        "maxWeightKg": 5.0,
        "storageDays": 2,
    },
]


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Distance a vol d'oiseau, la meme mesure que le mobile utilise pour le prix."""
    r = 6371.0
    d_lat = radians(lat2 - lat1)
    d_lng = radians(lng2 - lng1)
    a = (
        sin(d_lat / 2) ** 2
        + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lng / 2) ** 2
    )
    return 2 * r * asin(sqrt(a))


@router.get("")
async def list_relay_points(
    district: str | None = None,
    lat: float | None = None,
    lng: float | None = None,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    """Liste des relais, filtree par quartier et triee par proximite si possible.

    La position est facultative : sans elle, l'ordre de reference suffit. Avec
    elle, on ajoute a chaque relais sa distance et on remonte les plus proches —
    ce que l'ecran affiche pour aider a choisir (§7 : liste, distance, horaires).
    """
    items = [
        p for p in RELAY_POINTS if district is None or p["district"] == district
    ]

    if lat is not None and lng is not None:
        enriched = []
        for p in items:
            distance = _haversine_km(
                lat, lng, p["point"]["lat"], p["point"]["lng"]
            )
            enriched.append({**p, "distanceKm": round(distance, 2)})
        enriched.sort(key=lambda p: p["distanceKm"])
        items = enriched

    return {"items": items}

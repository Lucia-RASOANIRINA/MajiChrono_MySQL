"""Distance a vol d'oiseau entre deux points, et la regle qui en decoule.

Un livreur ne peut accepter une course que si son point de retrait est **assez
proche** de la ou il se trouve. La regle protege deux personnes a la fois : le
livreur, a qui l'on ne fait pas traverser la ville pour une course mal payee, et
l'expediteur, qui n'attend pas trente minutes qu'un scooter arrive de l'autre
bout d'Antananarivo. La distance retenue est celle a vol d'oiseau — la vraie,
par la route, est plus longue, mais la calculer demanderait un service de
routage ; le rayon a vol d'oiseau suffit a ecarter ce qui est manifestement trop
loin.
"""

from __future__ import annotations

import json
import math

# Rayon maximal d'acceptation, a vol d'oiseau. Dix kilometres couvrent
# l'agglomeration d'Antananarivo sans imposer une course a l'autre bout de la
# ville. C'est un choix de produit, pose ici en un seul endroit.
MAX_ACCEPT_KM = 10.0
MADAGASCAR_BOUNDS = (-26.0, -11.0, 43.0, 51.5)

_EARTH_RADIUS_KM = 6371.0


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Distance a vol d'oiseau entre deux points, en kilometres."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    )
    return 2 * _EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def is_in_madagascar(lat: float, lng: float) -> bool:
    """Reject impossible map points before they become delivery data."""
    south, north, west, east = MADAGASCAR_BOUNDS
    return south <= lat <= north and west <= lng <= east


def point_of(place_json: str) -> tuple[float, float] | None:
    """Extrait (lat, lng) d'un lieu serialise, ou None s'il n'en porte pas.

    Le lieu est stocke sous la forme `{"point": {"lat": .., "lng": ..}, ...}`.
    On accepte aussi un lat/lng a plat, par tolerance : mieux vaut lire une
    coordonnee ecrite differemment que refuser d'appliquer la regle de distance.
    """
    try:
        data = json.loads(place_json)
    except (TypeError, ValueError):
        return None
    if not isinstance(data, dict):
        return None

    point = data.get("point")
    src = point if isinstance(point, dict) else data
    lat, lng = src.get("lat"), src.get("lng")
    if isinstance(lat, (int, float)) and isinstance(lng, (int, float)):
        return float(lat), float(lng)
    return None

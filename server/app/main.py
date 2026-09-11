"""Point d'entree du serveur MajiChrono."""

from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.requests import Request

from app.config import get_settings
from app.core.errors import ApiError, api_error_handler, error_body
from app.db import engine, ensure_schema, get_db
from app.routers import (
    addresses,
    admin,
    auth,
    chat,
    compat,
    deliveries,
    disputes,
    driver,
    me,
    media,
    payment,
    relay,
    reviews,
    support,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

settings = get_settings()

logger = logging.getLogger("majichrono.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Au demarrage, on aligne les colonnes manquantes du schema MySQL heberge.

    Aucune table n'est creee automatiquement : les tables ``users``,
    ``addresses``, ``deliveries`` et autres du schema partage sont la source de
    verite. Une nouvelle table necessite une migration explicite.

    L'alignement tourne **en tache de fond**, sans bloquer la fin du demarrage.
    Uvicorn n'ouvre le port qu'une fois le `lifespan` startup termine ; or une
    une base MySQL peut rendre `ensure_schema` lent (connexion a etablir,
    inspection, ALTER TABLE), assez pour qu'une sonde d'hebergement expire
    alors que le serveur allait tres bien demarrer.
    On ouvre donc le port tout de suite et on aligne le schema juste apres ; les
    colonnes ajoutees sont additives, la breve fenetre avant la fin est sans
    danger. L'echec eventuel n'est pas fatal — il est seulement journalise.

    On **saute** l'operation en test : la suite remplace `get_db` par une base en
    memoire creee de zero par la fixture, et toucher la vraie base n'aurait ni
    sens ni interet.
    """
    task: asyncio.Task[None] | None = None
    if get_db not in app.dependency_overrides:

        async def _align() -> None:
            try:
                await asyncio.to_thread(ensure_schema)
                logger.info("Schema aligne au demarrage")
            except Exception:  # noqa: BLE001 — un schema deja a jour ne bloque pas le boot
                logger.exception("Alignement du schema au demarrage impossible")

        task = asyncio.create_task(_align())
    yield
    # A l'arret, on laisse la tache d'alignement se terminer proprement si elle
    # court encore, sans faire trainer la fermeture.
    if task is not None and not task.done():
        task.cancel()


app = FastAPI(
    title="MajiChrono",
    version="0.1.0",
    lifespan=lifespan,
    # La documentation interactive n'est ouverte qu'en dehors de la production :
    # elle expose la forme exacte de chaque route, ce qui rend le travail d'un
    # attaquant plus court sans rien apporter aux utilisateurs.
    docs_url="/docs" if settings.environment != "prod" else None,
    redoc_url=None,
)

app.add_exception_handler(ApiError, api_error_handler)


@app.exception_handler(RequestValidationError)
async def validation_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    """Traduit les erreurs de Pydantic dans le format que le mobile sait lire.

    Sans cela, FastAPI rend un corps `{"detail": [...]}` que `ErrorMapper`
    ignore : l'utilisateur verrait « erreur inconnue » sur une simple faute de
    saisie.
    """
    fields = {}
    for error in exc.errors():
        location = [str(part) for part in error["loc"] if part != "body"]
        fields[".".join(location) or "body"] = error["type"]

    return JSONResponse(
        status_code=422,
        content=error_body("validation_failed", "Requete invalide", {"fields": fields}),
    )


@app.get("/health", tags=["socle"])
async def health() -> dict:
    """Sonde applicative.

    Elle repond sans toucher la base : c'est une sonde de **vivacite**, pas de
    disponibilite complete. Un equilibreur de charge qui redemarre le serveur
    parce que MySQL est lent aggraverait la panne au lieu de la reduire.
    """
    return {"status": "ok", "environment": settings.environment}


@app.get("/health/ready", tags=["socle"])
async def readiness() -> dict:
    """Sonde de disponibilite : processus et connexion a la base."""
    def _check_database() -> None:
        with engine.connect():
            pass

    try:
        await asyncio.to_thread(_check_database)
    except Exception as exc:
        logger.warning("Base indisponible pour la sonde readiness: %s", exc)
        return {"status": "unready", "environment": settings.environment}
    return {"status": "ready", "environment": settings.environment}


app.include_router(auth.router)
app.include_router(me.router)
app.include_router(addresses.router)
app.include_router(media.router)
# La couche de compatibilite est montee **avant** les courses : sa route
# `GET /deliveries/available` doit l'emporter sur `GET /deliveries/{id}`, qui
# prendrait sinon « available » pour un identifiant.
app.include_router(compat.router)
app.include_router(deliveries.router)
app.include_router(driver.router)
app.include_router(admin.router)
app.include_router(chat.router)
app.include_router(disputes.router)
app.include_router(payment.router)
app.include_router(relay.router)
app.include_router(reviews.router)
app.include_router(support.router)

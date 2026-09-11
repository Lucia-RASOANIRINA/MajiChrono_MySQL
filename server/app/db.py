"""Session de base de donnees, injectee par requete."""

from __future__ import annotations

from collections.abc import Iterator

import logging

from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import Session, sessionmaker

from app.config import get_settings
from app.models import Base

logger = logging.getLogger("majichrono.db")

_settings = get_settings()

# SQLAlchemy needs an explicit driver for each supported database URL. This copy
# is intended for the local MySQL instance shipped with XAMPP.
_database_url = _settings.database_url
if _database_url.startswith("mysql://"):
    _database_url = _database_url.replace("mysql://", "mysql+pymysql://", 1)

# `pool_pre_ping` : la connexion est testee avant usage. Sans lui, un serveur
# reveille apres une nuit d'inactivite sert une premiere requete en erreur,
# parce que MySQL a ferme la connexion de son cote entre-temps.
_is_sqlite = _settings.database_url.startswith("sqlite")

# `check_same_thread` : SQLite refuse par defaut qu'une connexion serve deux fils,
# or FastAPI en utilise plusieurs. La contrainte n'a pas lieu d'etre ici, chaque
# requete ouvrant sa propre session.
engine = create_engine(
    _database_url,
    pool_pre_ping=True,
    future=True,
    connect_args={"check_same_thread": False} if _is_sqlite else {},
)

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db() -> Iterator[Session]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_all() -> None:
    """Cree le schema depuis zero. Utile pour les tests et le premier amorcage."""
    Base.metadata.create_all(engine)


def ensure_schema() -> None:
    """Inspecte le schema heberge sans le modifier.

    La base MySQL distante est la source de verite. Le demarrage ne doit donc
    jamais appeler ``create_all`` ni ``ALTER TABLE``. Les tables et colonnes
    existantes sont seulement inspectees et journalisees. Pour appliquer les
    ajouts non destructifs valides, lancer explicitement
    ``python -m tools.migrate_legacy_mysql --apply``.

      - Les **tables manquantes** sont ignorees : elles doivent faire l'objet
        d'une migration MySQL explicite, apres verification du schema heberge.
      - Les **colonnes manquantes** sont journalisees et doivent etre ajoutees
        par la migration explicite, apres verification du schema.

    Fonctionne sur MySQL comme sur SQLite (tests) : le type est compile via le
    dialecte et les identifiants sont cites par le dialecte actif.
    """
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())

    for table in Base.metadata.sorted_tables:
        if table.name not in tables:
            logger.warning("Table hebergee absente: %s", table.name)
            continue
        present = {col["name"] for col in inspector.get_columns(table.name)}
        missing = [column.name for column in table.columns if column.name not in present]
        if missing:
            logger.error(
                "Mapping incompatible pour %s; colonnes absentes: %s",
                table.name,
                ", ".join(missing),
            )

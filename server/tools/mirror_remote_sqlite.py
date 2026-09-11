"""Create a local SQLite mirror of the hosted MySQL database.

The hosted database is read only for this command.  The existing SQLite file is
backed up, replaced, and populated with the current rows from all hosted tables.
This is intended for local development and must not be used as a production
database migration.

Run from ``server``:

    python -m tools.mirror_remote_sqlite --dry-run
    python -m tools.mirror_remote_sqlite --replace
"""

from __future__ import annotations

import argparse
import json
import logging
import shutil
from datetime import datetime
from pathlib import Path

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    Index,
    Integer,
    LargeBinary,
    MetaData,
    Numeric,
    String,
    Table,
    Text,
    Time,
    create_engine,
    inspect,
    select,
)
from sqlalchemy.sql.sqltypes import BigInteger

from app.db import engine as remote_engine

logger = logging.getLogger("majichrono.mirror")


def _sqlite_type(column_type):
    """Map MySQL-specific reflected types to portable SQLite types."""
    type_name = column_type.__class__.__name__.lower()
    if type_name in {"json", "enum", "set", "uuid"}:
        return Text()
    if isinstance(column_type, (Boolean,)):
        return Boolean()
    if isinstance(column_type, (DateTime,)):
        return DateTime()
    if isinstance(column_type, Date):
        return Date()
    if isinstance(column_type, Time):
        return Time()
    if isinstance(column_type, (LargeBinary,)):
        return LargeBinary()
    if isinstance(column_type, (Float,)):
        return Float()
    if isinstance(column_type, (Numeric,)):
        return Numeric(
            precision=getattr(column_type, "precision", None),
            scale=getattr(column_type, "scale", None),
        )
    if isinstance(column_type, BigInteger):
        return BigInteger()
    if isinstance(column_type, Integer):
        return Integer()
    length = getattr(column_type, "length", None)
    return String(length) if length else Text()


def _copy_value(value, target_column) -> object:
    if value is None:
        return None
    if isinstance(target_column.type, Text) and isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    return value


def _mirror_table(source_table, target_metadata: MetaData) -> Table:
    columns = [
        Column(
            column.name,
            _sqlite_type(column.type),
            primary_key=column.primary_key,
            nullable=column.nullable,
            unique=column.unique,
        )
        for column in source_table.columns
    ]
    target = Table(source_table.name, target_metadata, *columns)

    for source_index in source_table.indexes:
        if source_index.name:
            Index(
                source_index.name,
                *(target.c[column.name] for column in source_index.columns),
                unique=source_index.unique,
            )
    return target


def _backup_path(database_path: Path) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return database_path.with_name(f"{database_path.stem}.before_remote_mirror_{timestamp}.db")


def mirror(*, database_path: Path, replace: bool) -> None:
    inspector = inspect(remote_engine)
    table_names = inspector.get_table_names()
    if not table_names:
        raise RuntimeError("La base distante ne contient aucune table.")

    logger.info("Base distante: %s tables", len(table_names))
    if not replace:
        logger.info("Dry-run: aucune modification de %s", database_path)
        return

    database_path.parent.mkdir(parents=True, exist_ok=True)
    if database_path.exists():
        backup = _backup_path(database_path)
        shutil.copy2(database_path, backup)
        logger.info("Sauvegarde locale: %s", backup)

    sqlite_engine = create_engine(f"sqlite:///{database_path}", future=True)
    source_metadata = MetaData()
    source_metadata.reflect(bind=remote_engine, only=table_names)
    target_metadata = MetaData()
    target_tables = {
        name: _mirror_table(source_metadata.tables[name], target_metadata)
        for name in table_names
    }

    existing_metadata = MetaData()
    existing_metadata.reflect(bind=sqlite_engine)
    existing_metadata.drop_all(sqlite_engine, checkfirst=True)
    target_metadata.create_all(sqlite_engine)

    total_rows = 0
    with remote_engine.connect() as source_connection, sqlite_engine.begin() as target_connection:
        for name in table_names:
            source_table = source_metadata.tables[name]
            target_table = target_tables[name]
            rows = source_connection.execute(select(source_table)).mappings()
            batch = []
            table_rows = 0
            for row in rows:
                batch.append(
                    {
                        column.name: _copy_value(row[column.name], target_table.c[column.name])
                        for column in source_table.columns
                    }
                )
                if len(batch) >= 500:
                    target_connection.execute(target_table.insert(), batch)
                    table_rows += len(batch)
                    batch.clear()
            if batch:
                target_connection.execute(target_table.insert(), batch)
                table_rows += len(batch)
            total_rows += table_rows
            logger.info("%s: %s lignes", name, table_rows)

    logger.info("Miroir local terminé: %s tables, %s lignes", len(table_names), total_rows)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--database",
        type=Path,
        default=Path("majichrono.db"),
        help="Chemin de la base SQLite locale.",
    )
    parser.add_argument("--replace", action="store_true", help="Remplacer la base locale.")
    parser.add_argument("--dry-run", action="store_true", help="Ne rien modifier.")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    mirror(database_path=args.database, replace=args.replace and not args.dry_run)

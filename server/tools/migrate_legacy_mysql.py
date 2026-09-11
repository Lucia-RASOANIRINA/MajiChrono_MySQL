"""Align the hosted MySQL schema without destructive changes.

The hosted database remains authoritative. This migration never renames, drops,
or overwrites an existing table. It creates missing tables from the application's
metadata and adds missing columns as nullable compatibility columns. Existing
columns are deliberately left untouched because the web application already
depends on them.

Run from ``server`` with:

    python -m tools.migrate_legacy_mysql --dry-run
    python -m tools.migrate_legacy_mysql --apply

The command requires DATABASE_URL to point at the target MySQL database. Take a
database backup before running it.
"""

from __future__ import annotations

import logging
import argparse

from sqlalchemy import Column, MetaData, Table, inspect, text

from app.db import Base, engine

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("majichrono.migration")

def _missing_schema() -> tuple[list, dict]:
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    missing_tables = [
        table for table in Base.metadata.sorted_tables if table.name not in tables
    ]
    missing_columns = {}
    for table in Base.metadata.sorted_tables:
        if table.name not in tables:
            continue
        present = {column["name"] for column in inspector.get_columns(table.name)}
        missing = [column.name for column in table.columns if column.name not in present]
        if missing:
            missing_columns[table.name] = [
                column for column in table.columns if column.name in missing
            ]
    return missing_tables, missing_columns


def migrate(*, apply: bool) -> None:
    missing_tables, missing_columns = _missing_schema()
    if not missing_tables and not missing_columns:
        logger.info("Schema heberge compatible; aucune modification necessaire.")
        return

    for table in missing_tables:
        logger.info("%s table missing: %s", "CREATE" if apply else "WOULD CREATE", table.name)
    for table_name, columns in missing_columns.items():
        logger.info(
            "%s columns %s: %s",
            "ADD" if apply else "WOULD ADD",
            table_name,
            ", ".join(column.name for column in columns),
        )

    if not apply:
        logger.info("Dry run: aucune modification effectuee.")
        return

    # Create only absent tables. Existing tables are never passed to create_all.
    # Foreign keys are omitted for compatibility tables: the hosted schema uses
    # integer user IDs while the legacy ORM metadata uses opaque string IDs.
    # Keeping the columns without an invalid FK lets the application migrate data
    # explicitly later instead of blocking the whole schema migration.
    for table in missing_tables:
        metadata = MetaData()
        compatible = Table(
            table.name,
            metadata,
            *[
                Column(
                    column.name,
                    column.type,
                    primary_key=column.primary_key,
                    nullable=column.nullable,
                    unique=column.unique,
                )
                for column in table.columns
            ],
        )
        metadata.create_all(engine, tables=[compatible], checkfirst=True)

    dialect = engine.dialect
    with engine.begin() as connection:
        for table_name, columns in missing_columns.items():
            for source in columns:
                # Compatibility columns must not invalidate existing rows.
                column = Column(
                    source.name,
                    source.type,
                    nullable=True,
                )
                type_sql = column.type.compile(dialect=dialect)
                identifier = dialect.identifier_preparer.quote(source.name)
                table_identifier = dialect.identifier_preparer.quote(table_name)
                connection.execute(
                    text(
                        f"ALTER TABLE {table_identifier} "
                        f"ADD COLUMN {identifier} {type_sql}"
                    )
                )
    logger.info("Schema heberge aligne sans suppression ni renommage.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Apply additions.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview additions without changing the database.",
    )
    args = parser.parse_args()
    migrate(apply=args.apply and not args.dry_run)

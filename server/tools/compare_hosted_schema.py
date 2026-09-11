"""Read-only comparison between SQLAlchemy mappings and the hosted MySQL schema.

This command deliberately never calls ``create_all`` or executes DDL.  It is the
gate to run before enabling routes against the shared database.
"""

from __future__ import annotations

from sqlalchemy import inspect

from app.db import Base, engine


def compare() -> int:
    inspector = inspect(engine)
    hosted = set(inspector.get_table_names())
    problems = 0

    for table in Base.metadata.sorted_tables:
        if table.name not in hosted:
            print(f"MISSING TABLE {table.name}")
            problems += 1
            continue

        actual = {column["name"] for column in inspector.get_columns(table.name)}
        mapped = {column.name for column in table.columns}
        for name in sorted(mapped - actual):
            print(f"MISSING COLUMN {table.name}.{name}")
            problems += 1

        # Extra hosted columns are expected: the hosted schema contains fields
        # used by the web application as well as by this API.
        for name in sorted(actual - mapped):
            print(f"HOSTED-ONLY {table.name}.{name}")

    print(f"schema comparison: {'FAIL' if problems else 'OK'} ({problems} problems)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(compare())

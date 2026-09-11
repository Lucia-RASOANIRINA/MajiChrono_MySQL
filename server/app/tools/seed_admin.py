"""Cree (ou met a jour) l'unique compte administrateur.

    .venv\\Scripts\\python -m app.tools.seed_admin

Le role administrateur est **attribue cote serveur** et ne se choisit jamais
depuis l'application (le choix de profil n'offre que « expediteur » et
« livreur »). Ce script est donc le seul point d'entree du role admin : tant
qu'on ne le lance qu'une fois, il n'existe qu'un seul administrateur.

Idempotent : relance sans creer de doublon. Le compte est retrouve par son
adresse e-mail, puis par son numero reserve ; a defaut il est cree. Le numero
est obligatoire (c'est la cle d'identite de tout compte), mais l'administrateur
se connecte par **e-mail + mot de passe**, jamais par SMS.
"""

from __future__ import annotations

import os

from sqlalchemy import select

from app.core.security import hash_secret
from app.db import SessionLocal, ensure_schema
from app.models import Account, UserRole

# Identifiants fournis uniquement par l'environnement : aucun mot de passe
# administrateur ne doit apparaitre dans le depot.
ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "")
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "")
ADMIN_NAME = os.environ.get("ADMIN_NAME", "MajiTech")

# Numero reserve a l'administration. Valide (prefixe Telma 034) et unique, il
# n'est la que parce que le schema exige un numero ; il ne recoit pas de SMS.
ADMIN_PHONE = "+261340000000"


def main() -> int:
    if not ADMIN_EMAIL or not ADMIN_PASSWORD:
        raise RuntimeError("ADMIN_EMAIL et ADMIN_PASSWORD sont requis")

    ensure_schema()

    with SessionLocal() as db:
        account = db.scalar(select(Account).where(Account.email == ADMIN_EMAIL))
        if account is None:
            account = db.scalar(select(Account).where(Account.phone == ADMIN_PHONE))
        created = account is None
        if account is None:
            account = Account(phone=ADMIN_PHONE)
            db.add(account)

        account.email = ADMIN_EMAIL
        account.password_hash = hash_secret(ADMIN_PASSWORD)
        account.role = UserRole.admin
        account.display_name = ADMIN_NAME
        db.commit()

        # Garde-fou : signaler tout autre administrateur, pour tenir la promesse
        # « un seul acces admin ». On ne le supprime pas d'office — ce serait
        # brutal — mais on le rend visible.
        others = db.scalars(
            select(Account).where(
                Account.role == UserRole.admin, Account.id != account.id
            )
        ).all()

    verb = "cree" if created else "mis a jour"
    print(f"Administrateur {verb} : {ADMIN_EMAIL}")
    print(f"  mot de passe : {ADMIN_PASSWORD}")
    print(f"  numero reserve : {ADMIN_PHONE}")
    print("  connexion : ecran e-mail -> mot de passe")
    if others:
        print()
        print(f"ATTENTION : {len(others)} autre(s) compte(s) admin existe(nt) :")
        for other in others:
            print(f"  - {other.email or other.phone} ({other.id})")
        print("  Retirez-leur le role si l'acces admin doit rester unique.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

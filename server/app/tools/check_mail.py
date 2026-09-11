"""Diagnostic d'envoi d'e-mail.

    .venv\\Scripts\\python -m app.tools.check_mail [destinataire]

Il se connecte vraiment au serveur SMTP configure et **nomme la cause** quand
cela echoue. Sans cet outil, un envoi refuse se lit `535 5.7.8` dans un journal,
et il faut connaitre les habitudes de chaque fournisseur pour savoir quoi
corriger. Ici, le message dit quoi faire.
"""

from __future__ import annotations

import asyncio
import smtplib
import ssl
import sys

from app.config import get_settings
from app.core.mail import send_login_code


def _diagnose(error: Exception, user: str) -> str:
    """Traduit une erreur SMTP en action concrete."""
    if isinstance(error, smtplib.SMTPAuthenticationError):
        code = error.smtp_code
        if code == 535 and "gmail" in get_settings().smtp_host:
            return (
                "Gmail refuse ces identifiants.\n\n"
                "  Cause quasi certaine : vous utilisez le mot de passe du\n"
                "  COMPTE. Depuis 2022, Google ne l'accepte plus pour SMTP.\n\n"
                "  Il faut un MOT DE PASSE D'APPLICATION, en trois etapes :\n"
                "    1. Activer la validation en deux etapes sur\n"
                "       https://myaccount.google.com/security\n"
                "       (sans elle, l'etape 2 n'apparait pas dans le menu)\n"
                "    2. https://myaccount.google.com/apppasswords\n"
                "    3. Creer un mot de passe pour « MajiChrono »\n"
                "       -> 16 caracteres, en 4 blocs\n\n"
                f"  Puis dans .env :  SMTP_PASSWORD=les 16 caracteres\n"
                f"  (SMTP_USER reste {user})"
            )
        return f"Identifiants refuses par le serveur SMTP (code {code})."

    if isinstance(error, smtplib.SMTPRecipientsRefused):
        return (
            "Le destinataire a ete refuse.\n"
            "  Sur Resend et la plupart des fournisseurs, l'adresse\n"
            "  d'expedition doit d'abord etre verifiee dans leur console."
        )

    if isinstance(error, (smtplib.SMTPConnectError, OSError, ssl.SSLError)):
        return (
            "Connexion impossible au serveur SMTP.\n"
            "  Verifiez SMTP_HOST et SMTP_PORT (587 en general, 465 en SSL),\n"
            "  et qu'aucun pare-feu ne bloque la sortie sur ce port."
        )

    return f"Echec inattendu : {type(error).__name__} — {error}"


def main() -> int:
    settings = get_settings()
    destination = sys.argv[1] if len(sys.argv) > 1 else settings.mail_from_address

    print("Configuration lue dans .env")
    print(f"  hote        : {settings.smtp_host or '(vide)'}")
    print(f"  port        : {settings.smtp_port}")
    print(f"  utilisateur : {settings.smtp_user or '(vide)'}")
    print(f"  mot de passe: {'defini' if settings.smtp_password else '(vide)'}")
    print(f"  expediteur  : {settings.mail_from_address}")
    print(f"  destinataire: {destination}")
    print()

    if not settings.emails_are_real:
        print("AUCUN SMTP CONFIGURE.")
        print("  Le serveur journalise les codes au lieu de les envoyer.")
        print("  Le parcours reste testable : le code apparait dans")
        print("  `debugCode` et dans server.err.log.")
        return 1

    try:
        asyncio.run(send_login_code(destination, "123456"))
    except Exception as error:  # noqa: BLE001 — c'est precisement le but
        cause = error.__cause__ or error
        print("ECHEC.\n")
        print(_diagnose(cause, settings.smtp_user))
        return 2

    print(f"ENVOI REUSSI — regardez la boite de {destination}")
    print("  (pensez au dossier indesirables au premier envoi)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

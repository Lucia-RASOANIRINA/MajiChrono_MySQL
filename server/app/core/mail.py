"""Envoi d'e-mail transactionnel, par SMTP.

SMTP plutot qu'une API propriétaire, et ce choix se defend : **tout fournisseur
en parle**. Gmail, Resend, Mailgun, SendGrid, un serveur d'entreprise — tous
exposent un point SMTP. Changer de fournisseur devient donc une affaire de
quatre variables d'environnement, pas de reecriture. Une API maison, elle,
enferme : le jour ou le fournisseur ne convient plus, il faut rouvrir le code.

Sans configuration, le code part dans le journal du serveur. Ce mode est
**volontairement bruyant** — il ecrit « AUCUN SMTP » a chaque envoi — parce
qu'un serveur de production qui aurait perdu sa configuration ne doit pas donner
l'illusion d'envoyer des e-mails.
"""

from __future__ import annotations

import asyncio
import logging
import smtplib
from email.message import EmailMessage

from app.config import get_settings

logger = logging.getLogger("majichrono.mail")


async def send_login_code(to_address: str, code: str) -> None:
    """Poste le code de connexion, ou le journalise faute de configuration."""
    settings = get_settings()

    if not settings.emails_are_real:
        logger.warning(
            "AUCUN SMTP CONFIGURE — code non envoye. destinataire=%s code=%s",
            to_address,
            code,
        )
        return

    message = EmailMessage()
    message["Subject"] = f"{code} — votre code MajiChrono"
    message["From"] = f"{settings.mail_from_name} <{settings.mail_from_address}>"
    message["To"] = to_address
    message.set_content(
        f"Votre code de connexion MajiChrono est : {code}\n\n"
        "Il est valable cinq minutes et ne sert qu'une fois.\n"
        "Si vous n'avez rien demande, ignorez ce message : "
        "personne ne peut entrer sans ce code."
    )
    message.add_alternative(_html_body(code), subtype="html")

    # `smtplib` est bloquant. On le pousse dans un fil pour ne pas geler la
    # boucle d'evenements : un serveur SMTP lent bloquerait sinon toutes les
    # requetes en cours, pas seulement celle-ci.
    try:
        await asyncio.to_thread(_send_blocking, message)
    except Exception as error:  # noqa: BLE001 — on veut vraiment tout attraper
        # Le detail part dans le journal ; l'appelant ne recoit qu'un echec
        # generique. Le message du fournisseur peut contenir l'adresse, qui n'a
        # pas a circuler jusqu'au mobile.
        logger.error("envoi SMTP refuse : %s", error)
        raise RuntimeError("mail_provider_rejected") from error

    logger.info("code envoye a %s", _mask(to_address))


def _send_blocking(message: EmailMessage) -> None:
    settings = get_settings()

    if settings.smtp_port == 465:
        client = smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=15)
    else:
        client = smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15)

    with client:
        if settings.smtp_port != 465:
            # STARTTLS sur le port 587 : sans lui, identifiants et message
            # circulent en clair.
            client.starttls()
        client.login(settings.smtp_user, settings.smtp_password)
        client.send_message(message)


def _mask(address: str) -> str:
    """`hery.rakoto@gmail.com` devient `h***o@gmail.com`.

    Les journaux d'un serveur sont lus, copies et parfois exportes : l'adresse
    complete d'un utilisateur n'a pas a s'y trouver (EXI-T10).
    """
    local, _, domain = address.partition("@")
    if len(local) <= 2:
        return f"{local[:1]}***@{domain}"
    return f"{local[0]}***{local[-1]}@{domain}"


def _html_body(code: str) -> str:
    return f"""\
<div style="font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
            max-width:480px;margin:0 auto;padding:32px 24px;color:#12181D">
  <p style="font-size:20px;font-weight:700;color:#1E2A78;margin:0 0 24px">
    MajiChrono
  </p>
  <p style="font-size:16px;line-height:1.5;margin:0 0 24px">
    Votre code de connexion :
  </p>
  <p style="font-size:34px;font-weight:700;letter-spacing:10px;
            color:#1E2A78;margin:0 0 24px">{code}</p>
  <p style="font-size:14px;line-height:1.5;color:#5B6670;margin:0">
    Il est valable cinq minutes et ne sert qu'une fois.<br>
    Si vous n'avez rien demande, ignorez ce message : personne ne peut
    entrer sans ce code.
  </p>
</div>"""

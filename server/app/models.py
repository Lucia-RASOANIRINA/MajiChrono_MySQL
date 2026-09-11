"""Schema de la base.

Le numero de telephone est la **cle d'identite** : une adresse e-mail, un mot de
passe, un compte Google ne sont que des portes vers un compte qui, lui, possede
toujours un numero. Cette regle vient du terrain â€” a Antananarivo, un livreur
appelle son client et un client appelle son livreur ; un compte sans numero
serait un compte avec lequel on ne peut pas livrer. Le schema l'impose : la
colonne `phone` est obligatoire et unique.
"""

from __future__ import annotations

import enum
import json
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def _now() -> datetime:
    return datetime.now(timezone.utc)


def as_utc(value: datetime) -> datetime:
    """Ramene une date lue en base au fuseau UTC.

    MySQL et SQLite peuvent rendre des dates sans fuseau â€” ils ne
    stocke pas cette information. Comparer les deux leve
    `can't compare offset-naive and offset-aware datetimes`, et le fait au
    moment le plus penible : a la verification d'un code, en production comme en
    developpement selon la base. On normalise donc a la lecture, une fois, ici.
    """
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def _uid(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:16]}"


def _decode_place(payload: str | None, summary: str | None) -> dict:
    if payload:
        try:
            value = json.loads(payload)
        except (TypeError, json.JSONDecodeError):
            value = None
        if isinstance(value, dict):
            return value
    return {"summary": summary or ""}


def _decode_json(payload: str | None, default: dict | None = None) -> dict:
    if payload:
        try:
            value = json.loads(payload)
        except (TypeError, json.JSONDecodeError):
            value = None
        if isinstance(value, dict):
            return value
    return default or {}


class Base(DeclarativeBase):
    pass


class UserRole(str, enum.Enum):
    client = "client"
    driver = "driver"
    admin = "admin"
    superadmin = "superadmin"


class KycStatus(str, enum.Enum):
    draft = "draft"
    pending = "pending"
    not_submitted = "not_submitted"
    submitted = "submitted"
    under_review = "under_review"
    approved = "approved"
    rejected = "rejected"


class Account(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # Cle d'identite. Format canonique `+261XXXXXXXXX`, valide en amont.
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)

    # Seconde porte, facultative et unique. Deux comptes ne peuvent pas partager
    # une adresse : le prochain code recu ne dirait plus laquelle ouvrir.
    email: Mapped[str | None] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255))

    role: Mapped[UserRole | None] = mapped_column(Enum(UserRole, name="user_role"))

    # Prenom et nom, separes. `display_name` reste le nom d'usage, recompose a
    # partir des deux : les ecrans (en-tete, salutation, cartes) n'ont ainsi
    # qu'un seul champ a lire, et l'ancien contrat continue de fonctionner pour
    # les comptes anterieurs qui n'ont pas encore rempli le detail.
    first_name: Mapped[str | None] = mapped_column(String(80))
    last_name: Mapped[str | None] = mapped_column(String(80))
    display_name: Mapped[str] = mapped_column("full_name", String(120), default="")
    avatar_url: Mapped[str | None] = mapped_column("avatar_path", String(500))
    rating: Mapped[float | None] = mapped_column()
    status: Mapped[str] = mapped_column(String(20), default="pending")
    kyc_status: Mapped[KycStatus | None] = mapped_column(
        Enum(KycStatus, name="user_kyc_status")
    )

    suspended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    @property
    def is_admin(self) -> bool:
        return self.role in (UserRole.admin, UserRole.superadmin)

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "phone": self.phone,
            "email": self.email,
            "role": self.role.value if self.role else None,
            "firstName": self.first_name,
            "lastName": self.last_name,
            "displayName": self.display_name,
            "avatarUrl": self.avatar_url,
            "rating": self.rating,
            "kycStatus": self.kyc_status.value if self.kyc_status else None,
            "createdAt": self.created_at.isoformat(),
        }


class Avatar(Base):
    """Photo de profil, rangee en base plutot que sur le disque.

    Le disque d'un hebergement web est potentiellement ephemere : une photo posee la
    disparaitrait au premier redeploiement. En base, elle survit et suit le
    compte. On la garde dans une **table a part** : une colonne binaire sur
    `users` grossirait chaque lecture de compte pour rien, alors que l'avatar
    n'est lu que par la balise `<img>`. Une ligne par compte au plus.
    """

    __tablename__ = "avatars"

    account_id: Mapped[str] = mapped_column(
        String(40), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    data: Mapped[bytes] = mapped_column(LargeBinary)
    content_type: Mapped[str] = mapped_column(String(80))
    # Sert de version dans l'URL (`?v=...`) pour casser le cache quand la photo
    # change, sans changer le chemin.
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True)
    type: Mapped[str] = mapped_column(String(40))
    title: Mapped[str] = mapped_column(String(120))
    message: Mapped[str | None] = mapped_column(String(255))
    related_id: Mapped[int | None] = mapped_column(Integer)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "type": self.type,
            "title": self.title,
            "message": self.message,
            "relatedId": self.related_id,
            "isRead": self.is_read,
            "createdAt": as_utc(self.created_at).isoformat(),
        }


class ContactMessage(Base):
    __tablename__ = "contact_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    client_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True)
    subject: Mapped[str] = mapped_column(String(160))
    message: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="open", index=True)
    admin_reply: Mapped[str | None] = mapped_column(Text)
    replied_by: Mapped[int | None] = mapped_column(Integer)
    replied_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class ReclamationFile(Base):
    __tablename__ = "reclamation_files"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    reclamation_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("reclamations.id", ondelete="CASCADE"), index=True
    )
    file_path: Mapped[str] = mapped_column(String(255))
    original_name: Mapped[str] = mapped_column(String(255))
    mime_type: Mapped[str] = mapped_column(String(80))
    size_bytes: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Setting(Base):
    __tablename__ = "settings"

    key_name: Mapped[str] = mapped_column(String(80), primary_key=True)
    value: Mapped[str | None] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class LoginAttempt(Base):
    __tablename__ = "login_attempts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    attempt_key: Mapped[str] = mapped_column(String(64), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class PasswordReset(Base):
    __tablename__ = "password_resets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class ApiToken(Base):
    __tablename__ = "api_tokens"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    device_label: Mapped[str | None] = mapped_column(String(120))
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Media(Base):
    """Un fichier image range en base, adresse par un identifiant opaque.

    Sert la photo du colis posee a la declaration (EXI-C09) : elle est televersee
    avant meme que la course existe, puis referencee par son `photoId`. En base
    comme l'avatar â€” le disque d'un plan gratuit est ephemere.
    """

    __tablename__ = "media"

    id: Mapped[str] = mapped_column(String(40), primary_key=True, default=lambda: _uid("med"))
    account_id: Mapped[str] = mapped_column(
        String(40), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    data: Mapped[bytes] = mapped_column(LargeBinary)
    content_type: Mapped[str] = mapped_column(String(80))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class SavedAddress(Base):
    """Une entree du carnet d'adresses d'un compte (EXI-C05).

    Le carnet suit le compte : rangee sur le serveur, elle se retrouve d'un
    appareil a l'autre et survit a une reinstallation. L'application en garde une
    copie locale pour rester utilisable hors reseau.

    L'adresse composite (point, quartier, repere, contact...) est serialisee en
    JSON dans `payload` plutot qu'eclatee en colonnes : sa forme evolue (photo de
    facade, note vocale, point relais) et chaque ajout imposerait sinon une
    migration.
    """

    __tablename__ = "addresses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    account_id: Mapped[int] = mapped_column(
        "user_id", Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )

    # Â« home Â», Â« work Â», Â« favorite Â» ou Â« other Â». Un compte n'a qu'un domicile
    # et qu'un lieu de travail ; les favoris et les autres sont libres.
    kind: Mapped[str] = mapped_column(String(20), default="other")
    label: Mapped[str] = mapped_column(String(120), default="")
    # The website stores the display value in `full_address`; `payload` keeps
    # the richer mobile representation when it is available.
    full_address: Mapped[str] = mapped_column(String(255), default="")
    city: Mapped[str | None] = mapped_column(String(80))
    latitude: Mapped[float] = mapped_column("lat", default=0)
    longitude: Mapped[float] = mapped_column("lng", default=0)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    payload: Mapped[str | None] = mapped_column(Text)

    use_count: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    def to_json(self) -> dict:
        import json as _json

        return {
            "id": self.id,
            "kind": self.kind,
            "label": self.label,
            "address": _json.loads(self.payload)
            if self.payload
            else {"summary": self.full_address},
            "useCount": self.use_count or 0,
            "createdAt": self.created_at.isoformat(),
        }


# Pieces attendues au dossier KYC d'un livreur, dans l'ordre de l'ecran. Defini
# ici pour etre partage sans dependance croisee entre routeurs.
KYC_KINDS: tuple[str, ...] = (
    "cin_front",
    "cin_back",
    "licence",
    "selfie",
    "registration",
    "vehicle",
    "plate",
)


class KycDocument(Base):
    """Une piece du dossier KYC d'un livreur (CIN, permis, selfie, carte grise,
    photo du vehicule, plaque...), rangee en base comme l'avatar.

    Une ligne par (compte, type de piece) : reposer une piece remplace la
    precedente. Ce sont des donnees d'identite sensibles â€” elles ne sont servies
    qu'a leur proprietaire et a l'exploitation, jamais publiquement.
    """

    __tablename__ = "kyc_documents"

    account_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    kind: Mapped[str] = mapped_column(String(40), primary_key=True)
    data: Mapped[bytes] = mapped_column(LargeBinary)
    content_type: Mapped[str] = mapped_column(String(80))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class ChallengeChannel(str, enum.Enum):
    sms = "sms"
    email = "email"


class Challenge(Base):
    """Code a usage unique, par SMS ou par e-mail.

    Le code n'est **jamais** stocke en clair : seule son empreinte l'est. Une
    fuite de la base ne donne donc pas les codes en vol. C'est la meme exigence
    que pour les mots de passe, et elle vaut ici aussi : cinq minutes suffisent
    a ouvrir une session.
    """

    __tablename__ = "challenges"

    id: Mapped[str] = mapped_column(String(40), primary_key=True, default=lambda: _uid("chg"))
    channel: Mapped[ChallengeChannel] = mapped_column(Enum(ChallengeChannel, name="challenge_channel"))

    # Numero ou adresse, selon le canal.
    destination: Mapped[str] = mapped_column(String(255), index=True)
    code_hash: Mapped[str] = mapped_column(String(255))

    attempts_left: Mapped[int] = mapped_column(Integer)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    __table_args__ = (Index("ix_challenges_destination_created", "destination", "created_at"),)

    @property
    def is_expired(self) -> bool:
        return _now() > as_utc(self.expires_at)

    @property
    def is_usable(self) -> bool:
        return self.consumed_at is None and not self.is_expired


class RefreshToken(Base):
    """Jeton de rafraichissement, tracable et revocable.

    Il est stocke par empreinte, et **tourne a chaque usage** (EXI-T03). Un
    jeton presente apres rotation signale un vol : la famille entiere est alors
    revoquee, ce qui deconnecte l'attaquant comme le porteur legitime â€” c'est le
    comportement voulu.
    """

    __tablename__ = "refresh_tokens"

    id: Mapped[str] = mapped_column(String(40), primary_key=True, default=lambda: _uid("rt"))
    account_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(255), unique=True)

    # Toutes les rotations issues d'une meme connexion partagent cette famille :
    # c'est elle qui identifie une **session** (un appareil connecte) dans la
    # liste que l'utilisateur peut consulter et revoquer.
    family: Mapped[str] = mapped_column(String(40), index=True)

    # Libelle lisible de l'appareil a l'origine de la session (Â« Android 14 Â»,
    # etc.), pose a la connexion et conserve a travers les rotations.
    device_label: Mapped[str | None] = mapped_column(String(120))

    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    account: Mapped[Account] = relationship()


class IdempotencyRecord(Base):
    """Cle d'idempotence deja traitee, avec la reponse qui avait ete rendue.

    Sans ce registre, une reprise apres coupure creerait une seconde course, un
    second debit, un second constat. Le mobile envoie la cle a l'enregistrement
    et ne la regenere jamais ; le serveur rejoue la meme reponse.
    """

    __tablename__ = "idempotency_records"

    key: Mapped[str] = mapped_column(String(120), primary_key=True)
    account_id: Mapped[str | None] = mapped_column(String(40), index=True)
    endpoint: Mapped[str] = mapped_column(String(120))
    status_code: Mapped[int] = mapped_column(Integer)
    response_json: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    __table_args__ = (UniqueConstraint("key", name="uq_idempotency_key"),)


class DeliveryStatus(str, enum.Enum):
    """Cycle de vie d'une course.

    L'ordre de declaration est celui du parcours reel. Les transitions
    autorisees sont declarees explicitement plus bas : une course ne peut pas
    sauter une etape, et surtout pas revenir en arriere â€” un colis remis ne
    redevient pas un colis en attente.
    """

    # La **valeur** de chaque etat est le mot que porte le fil (wire), et c'est
    # celui qu'attend l'application : `en_attente`, `acceptee`, ... â€” pas un
    # equivalent anglais. Emettre autre chose forcerait le mobile a retomber sur
    # un etat par defaut, et toutes les courses s'afficheraient Â« en attente Â».
    # Le nom du membre reste en anglais pour le code ; seul le wire est en
    # francais, cote reseau.
    pending = "en_attente"
    assigned = "acceptee"          # course acceptee par un livreur
    at_pickup = "au_depart"        # livreur arrive chez l'expediteur
    picked_up = "prise_en_charge"  # colis en main
    in_transit = "en_transit"
    at_destination = "a_destination"  # livreur arrive chez le destinataire
    delivered = "livree"
    delivered_with_reserves = "livree_avec_reserves"
    cancelled = "annulee"
    failed = "refusee"             # remise refusee / echec de livraison


# Transitions permises, par etat de depart (Â§8.3). Toute transition absente d'ici
# est refusee par un 409 qui rappelle l'etat courant (EXI-B02) : l'application
# peut alors reafficher la verite plutot que de laisser reessayer dans le vide.
#
# Le graphe suit celui du mobile : l'arrivee chez l'expediteur puis chez le
# destinataire sont des etapes a part entiere, parce que ce sont elles qui
# horodatent un constat de prise en charge et un constat de remise.
# Les etats Â« arrive chez l'expediteur Â» (at_pickup) et Â« arrive chez le
# destinataire Â» (at_destination) sont **facultatifs** : ils horodatent une
# arrivee quand l'application les traverse, mais un client plus sobre peut passer
# directement a l'enlevement ou a la remise. Le graphe autorise donc les deux
# chemins, sans jamais laisser sauter par-dessus une prise en charge.
ALLOWED_TRANSITIONS: dict[DeliveryStatus, set[DeliveryStatus]] = {
    DeliveryStatus.pending: {DeliveryStatus.assigned, DeliveryStatus.cancelled},
    DeliveryStatus.assigned: {
        DeliveryStatus.at_pickup,
        DeliveryStatus.picked_up,
        DeliveryStatus.cancelled,
        DeliveryStatus.failed,
    },
    DeliveryStatus.at_pickup: {
        DeliveryStatus.picked_up,
        DeliveryStatus.cancelled,
        DeliveryStatus.failed,
    },
    DeliveryStatus.picked_up: {
        DeliveryStatus.in_transit,
        DeliveryStatus.at_destination,
        DeliveryStatus.delivered,
        DeliveryStatus.delivered_with_reserves,
        DeliveryStatus.failed,
    },
    DeliveryStatus.in_transit: {
        DeliveryStatus.at_destination,
        DeliveryStatus.delivered,
        DeliveryStatus.delivered_with_reserves,
        DeliveryStatus.failed,
    },
    DeliveryStatus.at_destination: {
        DeliveryStatus.delivered,
        DeliveryStatus.delivered_with_reserves,
        DeliveryStatus.failed,
    },
    DeliveryStatus.delivered: set(),
    DeliveryStatus.delivered_with_reserves: set(),
    DeliveryStatus.cancelled: set(),
    DeliveryStatus.failed: set(),
}

# Etats ou l'expediteur peut encore annuler seul. Au-dela, le colis est chez le
# livreur : l'annulation devient un litige, pas un bouton.
CLIENT_CANCELLABLE = {DeliveryStatus.pending, DeliveryStatus.assigned}

# Etats consideres comme une remise reussie (pour les gains, la notation).
DELIVERED_STATES = {
    DeliveryStatus.delivered,
    DeliveryStatus.delivered_with_reserves,
}


class Delivery(Base):
    __tablename__ = "deliveries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    client_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True)
    driver_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("users.id"), index=True)

    status: Mapped[DeliveryStatus] = mapped_column(
        Enum(DeliveryStatus, name="delivery_status"), default=DeliveryStatus.pending, index=True
    )
    kind: Mapped[str] = mapped_column(String(30), default="standard")

    pickup_address: Mapped[str | None] = mapped_column(String(255))
    dropoff_address: Mapped[str | None] = mapped_column(String(255))
    pickup_lat: Mapped[float | None] = mapped_column()
    pickup_lng: Mapped[float | None] = mapped_column()
    dropoff_lat: Mapped[float | None] = mapped_column()
    dropoff_lng: Mapped[float | None] = mapped_column()
    recipient_name: Mapped[str] = mapped_column(String(120), default="")
    recipient_phone: Mapped[str] = mapped_column(String(24), default="")
    package_type: Mapped[str] = mapped_column(String(20), default="petit")
    vehicle_type: Mapped[str] = mapped_column(String(20), default="moto")
    dispatch_mode: Mapped[str] = mapped_column(String(20), default="available")
    payment_method: Mapped[str] = mapped_column(String(20), default="cash")
    payment_status: Mapped[str] = mapped_column(String(20), default="pending")
    pickup_json: Mapped[str | None] = mapped_column(Text)
    dropoff_json: Mapped[str | None] = mapped_column(Text)
    package_json: Mapped[str] = mapped_column(Text, default="{}")

    price_ariary: Mapped[int | None] = mapped_column(Integer)
    distance_km: Mapped[float | None] = mapped_column()

    # Annulation par l'expediteur (EXI-C26) : le motif, et les frais eventuels
    # retenus quand un livreur etait deja engage. Nuls tant que la course n'est
    # pas annulee.
    cancel_reason: Mapped[str | None] = mapped_column(Text)
    cancel_fee_ariary: Mapped[int | None] = mapped_column(Integer)

    # Point relais de remise, quand l'expediteur en choisit un (differenciant D6,
    # Â§7). Le code de retrait est genere a la creation et remis au destinataire :
    # il le presente au relais pour recuperer son colis. Nuls pour une livraison
    # a domicile classique.
    relay_point_id: Mapped[str | None] = mapped_column(String(40))
    relay_pickup_code: Mapped[str | None] = mapped_column(String(12))

    # Qui paie la course (EXI-C42) : expediteur (port paye) par defaut, ou
    # destinataire (port du). Le mobile l'envoie ; sans persistance il serait
    # perdu au premier rafraichissement.
    payer: Mapped[str | None] = mapped_column(String(20))

    # Liste d'achats pour compte (EXI-C07, D5), payload JSON opaque quand le type
    # de course est Â« achat pour compte Â». Nul autrement.
    shopping_json: Mapped[str | None] = mapped_column(Text)

    # Jeton du lien de suivi public, partage par SMS (EXI-C24). Il est distinct
    # de l'identifiant : un lien devine ne doit pas ouvrir une autre course.
    tracking_token: Mapped[str] = mapped_column(String(64), unique=True, index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    def to_json(self) -> dict:
        import json as _json

        return {
            "id": self.id,
            "clientId": self.client_id,
            "driverId": self.driver_id,
            "status": self.status.value,
            "kind": self.kind,
            "pickup": _decode_place(self.pickup_json, self.pickup_address),
            "dropoff": _decode_place(self.dropoff_json, self.dropoff_address),
            "package": _decode_json(self.package_json),
            "price": self.price_ariary,
            "distanceKm": self.distance_km,
            "cancelReason": self.cancel_reason,
            "cancelFee": self.cancel_fee_ariary,
            "relayPointId": self.relay_point_id,
            "relayPickupCode": self.relay_pickup_code,
            "payer": self.payer,
            "shopping": _decode_json(self.shopping_json) if self.shopping_json else None,
            "trackingToken": self.tracking_token,
            "createdAt": as_utc(self.created_at).isoformat(),
            "updatedAt": as_utc(self.updated_at).isoformat(),
        }


class DeliveryEvent(Base):
    """Journal des transitions d'une course.

    Il est **ajout seul** : aucune route ne le modifie ni ne l'efface. C'est ce
    qui permet, en cas de litige, de dire qui a fait passer la course dans quel
    etat et quand â€” une colonne `status` seule ne raconte rien du chemin.
    """

    __tablename__ = "delivery_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    delivery_id: Mapped[int] = mapped_column(ForeignKey("deliveries.id", ondelete="CASCADE"), index=True)
    status: Mapped[DeliveryStatus] = mapped_column(Enum(DeliveryStatus, name="delivery_status"))
    actor_id: Mapped[str | None] = mapped_column(String(40))
    note: Mapped[str | None] = mapped_column(Text)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    def to_json(self) -> dict:
        return {
            "status": self.status.value,
            "actorId": self.actor_id,
            "note": self.note,
            "occurredAt": as_utc(self.occurred_at).isoformat(),
        }


class Conversation(Base):
    """Fil de discussion hébergé, un par course.

    La table ``conversations`` appartient au schéma MySQL partagé. Les messages
    sont stockés dans ``conversation_messages`` ; ce modèle permet à l'API de
    référencer le fil existant sans recréer une table de chat locale.
    """

    __tablename__ = "conversations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    delivery_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("deliveries.id", ondelete="CASCADE"), unique=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Message(Base):
    """Message de la discussion entre l'expediteur et le livreur d'une course.

    La discussion n'existe qu'a partir de l'acceptation : avant, il n'y a pas de
    livreur a qui parler. Elle est rattachee a la course, pas a une paire de
    comptes â€” c'est la course qui donne le contexte (Â« ou en est mon colis ? Â»),
    et elle se ferme avec elle. Seuls l'expediteur et le livreur assigne y ont
    acces ; le controle est porte par la route, pas par cette table.
    """

    __tablename__ = "conversation_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    delivery_id: Mapped[int] = mapped_column(
        "conversation_id", Integer, ForeignKey("conversations.id", ondelete="CASCADE"), index=True
    )
    sender_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True)
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    # Horodatage de lecture par l'autre partie. Nul tant que le destinataire n'a
    # pas ouvert la discussion : c'est ce que l'accuse de lecture affiche â€”
    # Â« envoye Â» (nul) puis Â« lu Â» (pose). On garde un seul instant plutot qu'un
    # drapeau : il porte le Â« lu a telle heure Â», et suffit a deux interlocuteurs.
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), default=None
    )

    __table_args__ = (
        Index("ix_messages_conversation_created", "conversation_id", "created_at"),
    )

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "deliveryId": self.delivery_id,
            "senderId": self.sender_id,
            "body": self.body,
            "createdAt": as_utc(self.created_at).isoformat(),
            "readAt": as_utc(self.read_at).isoformat() if self.read_at else None,
        }


class DriverState(Base):
    """Etat de travail d'un livreur : en ligne, et derniere position connue.

    La position vit ici plutot que dans une table d'historique interrogee a
    chaque affichage : l'exploitation veut savoir **ou est chacun maintenant**,
    et lire une seule ligne par livreur reste rapide avec mille livreurs. Les
    positions passees, elles, ne servent qu'a reconstituer un trajet apres coup,
    et vont dans `PositionSample`.
    """

    __tablename__ = "drivers"

    account_id: Mapped[int] = mapped_column(
        "user_id", Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    online: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    kyc_status: Mapped[str | None] = mapped_column(String(20))

    lat: Mapped[float | None] = mapped_column()
    lng: Mapped[float | None] = mapped_column()

    # Horodatage **de la mesure**, pas de sa reception. Un point remonte apres
    # deux heures de tunnel reseau ne doit pas passer pour frais : c'est cette
    # date que l'exploitation compare a l'heure courante pour decider si un
    # livreur est encore localise (EXI-A02).
    fixed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    def to_json(self) -> dict:
        return {
            "driverId": self.account_id,
            "online": self.online,
            "lat": self.lat,
            "lng": self.lng,
            "fixedAt": as_utc(self.fixed_at).isoformat() if self.fixed_at else None,
        }


class PositionSample(Base):
    """Un point du trajet, tel que le mobile l'a mesure.

    Le livreur travaille souvent sans reseau : son application tamponne les
    points et les envoie par paquets a la reconnexion (EXI-L09). La cle
    d'unicite `(livreur, instant)` rend le renvoi d'un meme paquet inoffensif â€”
    ce qui arrive des qu'une reponse se perd en chemin.
    """

    __tablename__ = "location_pings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    driver_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    delivery_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("deliveries.id"), index=True)

    lat: Mapped[float] = mapped_column()
    lng: Mapped[float] = mapped_column()
    accuracy_m: Mapped[float | None] = mapped_column()
    fixed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        UniqueConstraint("driver_id", "fixed_at", name="uq_position_driver_instant"),
    )


class PaymentDirection(str, enum.Enum):
    """Sens de l'appariement d'un paiement par code QR.

    L'argent va toujours de l'expediteur (client) au livreur ; ce qui change,
    c'est qui presente le code et qui le scanne.
    """

    # Le livreur presente le code, le client le scanne puis confirme : demande
    # d'encaissement, rien n'est debite avant confirmation du payeur.
    collect = "collect"
    # Le client presente le code, deja pre-autorise ; le livreur le scanne pour
    # encaisser, et le mouvement suit immediatement.
    offer = "offer"


class PaymentStatus(str, enum.Enum):
    pending = "pending"     # creee, en attente d'appariement
    claimed = "claimed"     # code scanne, les deux appareils se connaissent
    captured = "captured"   # confirmee par le payeur, mouvement MajiPay effectue
    failed = "failed"       # refusee, expiree, ou solde insuffisant
    cash = "cash"           # bascule en especes


class PaymentIntent(Base):
    """Intention de paiement adossee a un solde MajiPay (Â§11.2).

    Le partage des roles gouverne toute la table : **MajiPay tient les soldes et
    execute le mouvement**, MajiChrono ne fait qu'arbitrer. On ne stocke donc ni
    solde ni numero de compte ici â€” ils vivent chez le prestataire et sont lus a
    chaque fois. Ce qui vit ici, c'est l'etat de la transaction et son garde-fou
    d'unicite : une intention capturee ne se debite jamais deux fois (EXI-MP06).

    Le jeton du code QR n'est **jamais** conserve en clair : seule son empreinte
    l'est, comme pour un mot de passe ou un code SMS. Un code photographie a
    distance ne revele rien, et une fuite de la base ne rend aucun code
    encaissable.
    """

    __tablename__ = "payments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    delivery_id: Mapped[int] = mapped_column(ForeignKey("deliveries.id", ondelete="CASCADE"), index=True)

    # Payeur et beneficiaire sont **derives de la course**, jamais du mobile : le
    # payeur est l'expediteur, le beneficiaire le livreur assigne. C'est ce qui
    # empeche un beneficiaire de se payer lui-meme en falsifiant un champ.
    payer_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True)
    payee_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True)

    amount_ariary: Mapped[int] = mapped_column(Integer)
    direction: Mapped[PaymentDirection] = mapped_column(Enum(PaymentDirection, name="payment_direction"))
    status: Mapped[PaymentStatus] = mapped_column(
        Enum(PaymentStatus, name="payment_status"), default=PaymentStatus.pending, index=True
    )

    # Empreinte du jeton a usage unique. Le jeton en clair ne sort qu'une fois, a
    # la creation, et uniquement a celui qui presente le code.
    token_hash: Mapped[str] = mapped_column(String(255))

    failure: Mapped[str] = mapped_column(String(30), default="none")
    receipt_ref: Mapped[str | None] = mapped_column(String(60))

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    @property
    def is_expired(self) -> bool:
        return _now() > as_utc(self.expires_at)

    @property
    def is_final(self) -> bool:
        return self.status in (PaymentStatus.captured, PaymentStatus.failed, PaymentStatus.cash)

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "deliveryId": self.delivery_id,
            "amount": self.amount_ariary,
            "direction": self.direction.value,
            "status": self.status.value,
            "payerLabel": "Client",
            "payeeLabel": "Livreur",
            "failure": self.failure,
            "receiptRef": self.receipt_ref,
            "createdAt": as_utc(self.created_at).isoformat(),
            "expiresAt": as_utc(self.expires_at).isoformat(),
            "capturedAt": as_utc(self.captured_at).isoformat() if self.captured_at else None,
        }


class Review(Base):
    """Evaluation d'une course, de l'expediteur vers le livreur (EXI-C40).

    Une note sans course n'a pas de sens : on ne juge pas un livreur dans
    l'abstrait, mais la course qu'il vient de faire. L'unicite `(course,
    auteur)` l'impose et interdit du meme coup de noter deux fois la meme
    course â€” la note se corrige, elle ne s'empile pas.

    Trois axes plutot qu'un seul : la note globale dit la satisfaction, la
    ponctualite et la qualite disent **pourquoi**. Un livreur mal note sur la
    seule ponctualite ne se corrige pas comme un livreur mal note sur le soin â€”
    et il ne peut se corriger que s'il sait lequel des deux on lui reproche.
    """

    __tablename__ = "reviews"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    delivery_id: Mapped[int] = mapped_column(ForeignKey("deliveries.id", ondelete="CASCADE"), index=True)
    rater_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True)
    ratee_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), index=True)

    # Note globale, de 1 a 5. Les deux axes fins sont facultatifs : une note
    # rapide reste possible, mais quand ils sont donnes, ils eclairent.
    stars: Mapped[int] = mapped_column(Integer)
    punctuality: Mapped[int | None] = mapped_column(Integer)
    service: Mapped[int | None] = mapped_column(Integer)
    comment: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    __table_args__ = (
        UniqueConstraint("delivery_id", "rater_id", name="uq_review_delivery_rater"),
    )

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "deliveryId": self.delivery_id,
            "raterId": self.rater_id,
            "rateeId": self.ratee_id,
            "stars": self.stars,
            "punctuality": self.punctuality,
            "service": self.service,
            "comment": self.comment,
            "createdAt": as_utc(self.created_at).isoformat(),
        }


class MajiPaySandboxAccount(Base):
    """Solde fictif d'un compte chez le **prestataire de paiement** MajiPay.

    Cette table n'existe que tant que le vrai MajiPay n'est pas branche : elle
    tient lieu de bac a sable pour developper et tester le parcours de bout en
    bout. En production, ces lignes n'existent pas â€” les soldes vivent chez
    MajiPay, et la passerelle HTTP les lit par-dessus le reseau. Rien dans le
    routeur de paiement ne lit cette table directement : tout passe par la
    passerelle, exactement comme avec le vrai prestataire.
    """

    __tablename__ = "majipay_sandbox_accounts"

    account_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    balance_ariary: Mapped[int] = mapped_column(Integer, default=0)
    account_ref: Mapped[str] = mapped_column(String(40))


class MajiPaySandboxTxn(Base):
    """Mouvement MajiPay deja honore, retrouve par sa cle d'idempotence.

    Un prestataire de paiement serieux rend la meme reponse a la meme cle sans
    rejouer le debit. Le bac a sable en fait autant : c'est la derniere barriere
    contre un double mouvement, celle qui tient meme si l'appelant s'y reprend.
    """

    __tablename__ = "majipay_sandbox_txns"

    idem_key: Mapped[str] = mapped_column(String(120), primary_key=True)
    receipt_ref: Mapped[str] = mapped_column(String(60))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class ModerationLog(Base):
    """Decision d'exploitation, avec son motif et son auteur.

    Table en **ajout seul** : aucune route ne modifie ni n'efface une ligne. Une
    suspension qu'on pourrait effacer ne vaudrait rien le jour ou un livreur
    conteste â€” et c'est precisement ce jour-la qu'on a besoin de ce journal.

    Le motif est obligatoire, et la longueur minimale est controlee en amont.
    Une decision qui touche le gagne-pain de quelqu'un se justifie.
    """

    __tablename__ = "moderation_logs"

    id: Mapped[str] = mapped_column(String(40), primary_key=True, default=lambda: _uid("mod"))
    actor_id: Mapped[str] = mapped_column(String(40), index=True)
    subject_id: Mapped[str] = mapped_column(String(40), index=True)
    action: Mapped[str] = mapped_column(String(40))
    reason: Mapped[str] = mapped_column(Text)
    decided_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    def to_json(self) -> dict:
        subject_id = int(self.subject_id) if self.subject_id.isdigit() else self.subject_id
        return {
            "id": self.id,
            "actorId": self.actor_id,
            "subjectId": subject_id,
            "action": self.action,
            "reason": self.reason,
            "decidedAt": as_utc(self.decided_at).isoformat(),
        }


class Dispute(Base):
    """Litige ouvert sur une course (EXI-A05, Â§13 client).

    Il nait le plus souvent d'une remise sous reserves, ou d'une contestation
    du client. Les deux parties et l'exploitation voient **le meme dossier** :
    une vue reservee a l'exploitation ne serait plus une preuve contradictoire,
    ce serait un dossier a charge (EXI-CC31). Le fil de messages est ce qui
    permet a chacun d'exposer sa version avant que l'exploitation ne tranche.
    """

    __tablename__ = "reclamations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    delivery_id: Mapped[int] = mapped_column(ForeignKey("deliveries.id", ondelete="CASCADE"), index=True)

    # open / investigating / resolved / rejected. Une chaine plutot qu'un enum
    # SQL : les valeurs suivent le contrat front sans table de traduction.
    status: Mapped[str] = mapped_column(String(20), default="open", index=True)
    reason: Mapped[str] = mapped_column(Text)

    # Qui a ouvert : client, driver ou ops. Sert a l'affichage, jamais a filtrer
    # ce que l'autre partie voit â€” les deux voient le meme dossier.
    opened_by: Mapped[str | None] = mapped_column(String(20))
    opened_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    # Decision finale, nulle tant que le litige est ouvert. Le motif est
    # obligatoire a la cloture : une decision qui tranche entre deux versions se
    # justifie.
    decision_action: Mapped[str | None] = mapped_column(String(30))
    decision_reason: Mapped[str | None] = mapped_column(Text)
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    decided_by: Mapped[int | None] = mapped_column(Integer, ForeignKey("users.id"))

    messages: Mapped[list[DisputeMessage]] = relationship(
        "DisputeMessage",
        cascade="all, delete-orphan",
        order_by="DisputeMessage.sent_at",
    )

    @property
    def is_closed(self) -> bool:
        return self.status in ("resolved", "rejected")

    def to_json(self) -> dict:
        decision = None
        if self.decision_action is not None:
            decision = {
                "action": self.decision_action,
                "reason": self.decision_reason or "",
                "decidedAt": as_utc(self.decided_at).isoformat() if self.decided_at else None,
                "decidedBy": self.decided_by,
            }
        return {
            "id": self.id,
            "deliveryId": self.delivery_id,
            "status": self.status,
            "reason": self.reason,
            "openedBy": self.opened_by,
            "openedAt": as_utc(self.opened_at).isoformat(),
            "messages": [m.to_json() for m in self.messages],
            "decision": decision,
        }


class DisputeMessage(Base):
    """Un echange dans le fil d'un litige.

    En ajout seul : un message ne se modifie ni ne s'efface, sans quoi le fil ne
    serait plus une preuve de ce que chacun a dit et quand.
    """

    __tablename__ = "reclamation_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    dispute_id: Mapped[int] = mapped_column(ForeignKey("reclamations.id", ondelete="CASCADE"), index=True)
    author_label: Mapped[str] = mapped_column(String(60))
    body: Mapped[str] = mapped_column(Text)
    # Vrai quand le message vient de l'exploitation : l'affichage le distingue des
    # messages des parties, sans revelation d'identite au-dela du role.
    from_operations: Mapped[bool] = mapped_column(Boolean, default=False)
    sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "authorLabel": self.author_label,
            "body": self.body,
            "sentAt": as_utc(self.sent_at).isoformat(),
            "fromOperations": self.from_operations,
        }


# Types d'incident que le livreur peut declarer (EXI-L14, Â§19). Un incident est
# un **rapport**, pas une fatalite : la plupart (client absent, probleme GPS,
# panne) n'echouent pas la course, ils la documentent. Seuls quelques-uns
# debouchent sur un echec, decide par ailleurs via le constat de remise.
INCIDENT_KINDS: tuple[str, ...] = (
    "sender_absent",
    "recipient_absent",
    "address_incorrect",
    "package_damaged",
    "package_refused",
    "accident",
    "gps_problem",
    "vehicle_problem",
    "payment_problem",
    "other",
)


class DeliveryIncident(Base):
    """Incident declare par le livreur sur une course (EXI-L14, Â§19).

    Ajout seul : un incident se documente et se resout, il ne s'efface pas. Il
    porte de quoi instruire â€” type, description, photo, position, horodatage â€”
    et un statut de resolution que l'exploitation fait avancer. Le decoupler de
    l'etat de la course est deliberÐµ : declarer Â« client absent Â» ne condamne
    pas la livraison, cela ouvre une main courante.
    """

    __tablename__ = "delivery_incidents"

    id: Mapped[str] = mapped_column(String(40), primary_key=True, default=lambda: _uid("inc"))
    delivery_id: Mapped[str] = mapped_column(ForeignKey("deliveries.id", ondelete="CASCADE"), index=True)
    reporter_id: Mapped[str] = mapped_column(String(40), index=True)

    kind: Mapped[str] = mapped_column(String(30))
    description: Mapped[str | None] = mapped_column(Text)

    # Photo optionnelle, rangee comme les autres medias (table `media`).
    photo_media_id: Mapped[str | None] = mapped_column(String(40))

    # Position au moment du signalement, quand le telephone la connait.
    lat: Mapped[float | None] = mapped_column()
    lng: Mapped[float | None] = mapped_column()

    # open / resolved. L'exploitation clot l'incident une fois traite.
    resolution: Mapped[str] = mapped_column(String(20), default="open", index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "deliveryId": self.delivery_id,
            "kind": self.kind,
            "description": self.description,
            "photoId": self.photo_media_id,
            "lat": self.lat,
            "lng": self.lng,
            "resolution": self.resolution,
            "createdAt": as_utc(self.created_at).isoformat(),
        }


# Types de vehicule d'un livreur (Â§22). La moto domine a Antananarivo, mais le
# velo (courses legeres) et le tricycle (volumes) existent aussi.
VEHICLE_TYPES: tuple[str, ...] = ("moto", "bicycle", "car", "tricycle")


class DriverVehicle(Base):
    """Fiche vehicule structuree d'un livreur (Â§22).

    Complementaire du dossier KYC, qui porte les *pieces* (carte grise, photo,
    plaque) : ici vivent les *informations* â€” type, marque, modele, plaque,
    echeance d'assurance. Une ligne par livreur au plus. La validation suit le
    meme cycle que le KYC : toute modification la remet en attente, car une fiche
    changee n'est plus celle que l'exploitation avait vue.
    """

    __tablename__ = "driver_vehicles"

    account_id: Mapped[str] = mapped_column(
        String(40), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    vehicle_type: Mapped[str] = mapped_column(String(20), default="moto")
    brand: Mapped[str | None] = mapped_column(String(80))
    model: Mapped[str | None] = mapped_column(String(80))
    plate: Mapped[str | None] = mapped_column(String(40))
    insurance_expiry: Mapped[str | None] = mapped_column(String(20))

    # pending / validated / rejected. Pose par l'exploitation ; remis a pending
    # a chaque modification par le livreur.
    validation: Mapped[str] = mapped_column(String(20), default="pending")

    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    def to_json(self) -> dict:
        return {
            "type": self.vehicle_type,
            "brand": self.brand,
            "model": self.model,
            "plate": self.plate,
            "insuranceExpiry": self.insurance_expiry,
            "validation": self.validation,
        }


class KycMessage(Base):
    """Message du fil de suivi de dossier, entre un livreur et l'exploitation.

    Tant que le dossier KYC n'est pas valide, le livreur ne peut pas prendre de
    course (EXI-L01). Ce fil lui donne un canal pour demander ou en est son
    dossier, et a l'exploitation pour repondre. Ajout seul : un echange sur une
    validation d'identite se conserve. Rattache au **compte du livreur**, pas a
    une course â€” un dossier n'est pas une livraison.
    """

    __tablename__ = "kyc_messages"

    id: Mapped[str] = mapped_column(String(40), primary_key=True, default=lambda: _uid("kmsg"))
    account_id: Mapped[str] = mapped_column(
        String(40), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    # Vrai quand le message vient de l'exploitation ; faux quand il vient du
    # livreur. Sert a poser la bulle du bon cote, sans reveler d'identite.
    from_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "fromAdmin": self.from_admin,
            "body": self.body,
            "createdAt": as_utc(self.created_at).isoformat(),
        }

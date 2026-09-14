"""Configuration du serveur, lue dans l'environnement.

Aucune valeur secrete n'a de defaut utilisable. Un serveur qui demarre avec une
cle de signature « changez-moi » est un serveur dont personne ne remarque que la
cle n'a pas ete changee — le demarrage echoue donc franchement en production
plutot que de laisser passer.
"""

from functools import lru_cache
from typing import Literal
from urllib.parse import quote_plus

from pydantic import AliasChoices, Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    app_name: str = "MajiChrono"
    app_url: str = ""
    environment: Literal["dev", "staging", "prod"] = Field(
        default="dev", validation_alias=AliasChoices("ENVIRONMENT", "APP_ENV")
    )

    # --- Base de donnees ---------------------------------------------------
    # MySQL XAMPP est la base locale de cette variante. SQLAlchemy permet de
    # garder les routes identiques tout en conservant SQLite pour les tests.
    database_url: str = ""
    db_host: str = ""
    db_name: str = ""
    db_user: str = ""
    db_pass: str = ""
    db_port: int = 3306

    @model_validator(mode="after")
    def _build_database_url(self) -> "Settings":
        """Support the DB_* convention used by the hosting environment."""
        # An explicit SQLite URL is useful for switching to the local mirror
        # without editing the hosted DB_* variables. The hosting convention
        # remains authoritative for MySQL configuration.
        if self.database_url.startswith("sqlite://"):
            return self
        if self.db_host and self.db_name and self.db_user:
            password = quote_plus(self.db_pass)
            user = quote_plus(self.db_user)
            database = quote_plus(self.db_name)
            self.database_url = (
                f"mysql+pymysql://{user}:{password}@{self.db_host}:"
                f"{self.db_port}/{database}"
            )
        elif not self.database_url:
            self.database_url = "sqlite:///./majichrono.db"
        return self

    # --- Jetons ------------------------------------------------------------
    #
    # Quinze minutes d'acces et trente jours de rafraichissement, comme le
    # mobile les attend (EXI-T03). Le jeton court limite la fenetre d'un vol ;
    # le long evite de redemander une identite tous les matins a un livreur.
    jwt_secret: str = Field(default="", min_length=0)
    access_ttl_minutes: int = 15
    refresh_ttl_days: int = 30

    # --- Codes a usage unique ---------------------------------------------
    otp_ttl_minutes: int = 5
    otp_max_attempts: int = 3
    otp_debug_codes: bool = False

    # --- Limites et suivi -------------------------------------------------
    max_file_size: int = 5 * 1024 * 1024
    allowed_extensions: str = "jpg,jpeg,png,pdf,webp"
    ping_interval_seconds: int = 10
    offline_grace_minutes: int = 5
    tracking_stale_seconds: int = 30
    tracking_offline_seconds: int = 120

    # --- Tarification et carte -------------------------------------------
    base_fare: int = 2000
    price_per_km: int = 800
    tax_rate: float = 0.10
    currency: str = "MGA"
    map_default_lat: float = -15.7167
    map_default_lng: float = 46.3167
    map_default_zoom: int = 13

    @field_validator("environment", mode="before")
    @classmethod
    def _normalize_environment(cls, value: str) -> str:
        return {
            "development": "dev",
            "production": "prod",
        }.get(str(value).lower(), str(value).lower())

    # --- Envoi d'e-mail (SMTP) ---------------------------------------------
    #
    # SMTP est le denominateur commun : Gmail, Resend, Mailgun, SendGrid, un
    # serveur d'entreprise — tous l'exposent. Changer de fournisseur ne coute
    # alors que quatre variables, jamais une reecriture.
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = Field(
        default="",
        validation_alias=AliasChoices("SMTP_USER", "SMTP_USERNAME"),
    )
    smtp_password: str = ""
    mail_from_address: str = "no-reply@majichrono.mg"
    mail_from_name: str = "MajiChrono"

    # --- SMS ---------------------------------------------------------------
    #
    # Volontairement vide : l'envoi de SMS est le **dernier** chantier, pour ne
    # pas consommer le quota d'essai en developpement. Tant que cette cle est
    # absente, les codes telephoniques sont journalises au lieu d'etre envoyes.
    sms_api_key: str = ""
    sms_enabled: bool = False
    sms_provider: str = ""
    sms_sender: str = "MajiChrono"

    # --- Paiement (MajiPay) ------------------------------------------------
    #
    # Le prestataire qui tient les soldes et execute les mouvements. Tant que
    # cette cle est vide, un bac a sable en base joue son role : le parcours de
    # paiement par QR se teste de bout en bout sans compte MajiPay, et le mobile
    # ne peut toujours pas debiter seul. Poser la cle bascule vers le vrai
    # prestataire sans changer une ligne du routeur.
    majipay_api_key: str = ""

    @field_validator("jwt_secret")
    @classmethod
    def _secret_must_be_real(cls, value: str, info) -> str:
        environment = info.data.get("environment", "dev")
        if environment != "dev" and len(value) < 32:
            raise ValueError(
                "JWT_SECRET doit faire au moins 32 caracteres hors developpement"
            )
        return value or "developpement-uniquement-jamais-en-production"

    @property
    def emails_are_real(self) -> bool:
        """Vrai quand le serveur peut vraiment poster un e-mail.

        Sans cle, le code est ecrit dans le journal : c'est ce qui permet de
        developper sans compte fournisseur, et ce qui rend visible, en
        production, qu'une cle manque.
        """
        return bool(self.smtp_host and self.smtp_user and self.smtp_password)

    @property
    def allowed_file_extensions(self) -> set[str]:
        return {
            value.strip().lower().lstrip(".")
            for value in self.allowed_extensions.split(",")
            if value.strip()
        }

    def estimate_delivery_price(self, distance_km: float) -> int:
        subtotal = self.base_fare + round(max(distance_km, 0) * self.price_per_km)
        return round(subtotal * (1 + self.tax_rate))


@lru_cache
def get_settings() -> Settings:
    return Settings()

# Serveur MajiChrono

FastAPI + MySQL/MariaDB. Il sert le contrat d'API que l'application mobile
consomme aujourd'hui contre son simulateur embarque : memes chemins, memes noms
de champs, meme format d'erreur.

## Ce qui est ecrit

| Domaine | Etat |
|---|---|
| Socle : configuration, base, securite, format d'erreur, idempotence | ecrit |
| Authentification telephone (OTP) | ecrit |
| Authentification e-mail (code) **avec envoi reel** | ecrit |
| Authentification mot de passe | ecrit |
| Rotation et revocation de session | ecrit |
| `GET` / `PATCH /me` | ecrit |
| Courses : creation, transitions, annulation, journal | ecrit, teste |
| Suivi public par jeton | ecrit, teste |
| Livreur : disponibilite, offres, positions, gains | ecrit, teste |
| Exploitation : tableau de bord, flotte, dossiers, suspensions | ecrit, teste |
| Chaine de garde | partiel : journal et médias écrits, preuve opposable à finaliser |
| Paiement MajiPay | sandbox uniquement ; intégration réelle à venir |
| Envoi de SMS | fonctionnalité indisponible ; aucun SMS réel envoyé |

**156 tests** couvrent ces routes. Lancez-les depuis `server/` :

```bash
.venv\Scripts\python -m pytest -q
```

Chaque test recoit sa propre base en memoire : ils sont independants de l'ordre
d'execution, et un compte cree par l'un ne fait pas echouer l'unicite chez
l'autre.

Ces tests ont deja trouve deux defauts qu'une relecture avait laisses passer :
un livreur ne pouvait accepter aucune course — le controle de visibilite le
rejetait avant que la logique d'acceptation ne soit atteinte — et le perdant de
la course a l'acceptation lisait « transition impossible » au lieu de « course
deja prise ».

## Demarrer

```bash
# 1. Python 3.12 (les versions epinglees ont des paquets precompiles pour 3.12 ;
#    3.13/3.14 obligeraient a compiler psycopg et pydantic-core a la main)
py -3.12 -m venv .venv          # ou : python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt

# 2. MySQL/MariaDB
# Utilisez MySQL XAMPP en local ou la base MySQL creee dans DirectAdmin.
# Le script suivant prepare uniquement une installation XAMPP locale :
.\tools\setup_mysql_xampp.ps1

# 3. Configuration
copy .env.example .env
python -c "import secrets;print(secrets.token_urlsafe(48))"   # -> JWT_SECRET

# 4. Schema (developpement)
python -c "from app.db import create_all; create_all()"

# 5. Lancer
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

L'application mobile doit alors pointer sur `http://VOTRE_IP:8000`. Depuis un
emulateur Android, `10.0.2.2` designe la machine hote.

## Recevoir un vrai e-mail

L'envoi passe par **SMTP** — le denominateur commun de tous les fournisseurs.
Changer de fournisseur ne coute que quatre variables d'environnement, jamais une
reecriture. Recommande : **Resend** (3 000 envois/mois, sans carte bancaire).

1. Creez un compte sur [resend.com](https://resend.com).
2. **API Keys → Create API Key** : copiez la cle (`re_...`, affichee une seule
   fois).
3. **Domains → Add Domain** : ajoutez votre domaine et publiez les
   enregistrements **SPF, DKIM et DMARC** affiches par Resend.
4. Renseignez `.env` :

   ```env
   SMTP_HOST=smtp.resend.com
   SMTP_PORT=587
   SMTP_USER=resend
   SMTP_PASSWORD=re_votre_cle
   MAIL_FROM_ADDRESS=no-reply@votre-domaine.mg
   ```

L'etape 3 n'est pas optionnelle. Sans elle, vos codes partent en indesirables —
ce qui est pire qu'une absence d'e-mail, parce que l'utilisateur ne sait pas ou
chercher et conclut que l'application ne marche pas.

Sans configuration SMTP, le serveur ecrit le code dans son journal, precede de
`AUCUN SMTP CONFIGURE`. Le parcours complet se deroule donc sans compte
fournisseur. Le guide detaille (Resend et variante Gmail) est dans le README
racine.

## Deployer sur DirectAdmin

Dans DirectAdmin, utilisez **Setup Python App** (ou **Application Manager**) :

1. Creez une application Python 3.12 dont le repertoire racine est `server/`.
2. Choisissez `passenger_wsgi.py` comme fichier de demarrage.
3. Creez un environnement virtuel et installez `requirements.txt`.
4. Ajoutez les variables d'environnement de `.env.example` dans le panneau,
   notamment `ENVIRONMENT=prod`, `JWT_SECRET` (au moins 32 caracteres), ainsi
   que `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS` et `DB_PORT`.
5. Configurez le domaine ou sous-domaine vers l'application et redemarrez-la.

Le fichier `passenger_wsgi.py` adapte l'application ASGI FastAPI au serveur
Passenger de DirectAdmin. La base MySQL/MariaDB doit etre creee dans
**MySQL Management** avant le premier demarrage. N'utilisez jamais SQLite en
production.

## Utiliser la base MySQL existante

Le lien phpMyAdmin sert uniquement à administrer la base : il ne peut pas être
utilisé comme `DATABASE_URL` et ne contient pas les identifiants MySQL. Demandez
à l'hébergeur l'hôte MySQL, le port, l'utilisateur et le mot de passe, puis
définissez par exemple :

```env
DATABASE_URL=mysql+pymysql://utilisateur:mot_de_passe@hote:3306/nellfaag_majichrono
```

L'API accepte aussi `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS` et `DB_PORT`.
Les variables `DB_*` sont prioritaires pour MySQL. Pour choisir localement la
copie SQLite sans modifier les paramètres distants, utilisez explicitement une
URL `sqlite://`.

L'API utilise directement les tables existantes (`users`, `addresses`,
`deliveries`, `delivery_events`, `drivers`, `location_pings`, `payments`,
`reviews`, `conversations`, `conversation_messages`, `reclamations`). Après une
sauvegarde, depuis `server/`, lancez :

```powershell
python -m tools.migrate_legacy_mysql
```

La commande ne renomme, ne supprime, ne crée et ne modifie aucune table. Les
tables ou colonnes absentes sont signalées et doivent faire l'objet d'une
migration MySQL explicite et revue.

Les paramètres applicatifs compatibles avec le site sont lus depuis
`.env.example` : limites de fichiers, suivi GPS, tarification en ariary,
devise et position par défaut de la carte. `APP_ENV=development` ou
`APP_ENV=production` est accepté comme alias de `ENVIRONMENT=dev` ou
`ENVIRONMENT=prod`. Les variables `SMS_ENABLED` et `SMS_API_KEY` restent
désactivées tant que l'intégration SMS n'est pas validée.

### Reproduire la base distante en local

Pour inspecter localement les mêmes tables et données sans modifier MySQL,
utilisez le miroir SQLite. La commande crée d'abord une sauvegarde horodatée de
`majichrono.db`, puis remplace son contenu par les 31 tables distantes :

```powershell
python -m tools.mirror_remote_sqlite --dry-run
python -m tools.mirror_remote_sqlite --replace
```

Pour démarrer l'API avec cette copie locale malgré les variables MySQL de
`.env`, définissez explicitement :

```powershell
$env:DATABASE_URL = "sqlite:///./majichrono.db"
uvicorn app.main:app --reload
```

Le miroir est destiné au développement uniquement. Les identifiants et les
secrets ne sont jamais écrits dans le dépôt ; la base SQLite et ses sauvegardes
restent locales.

Avant d'activer l'API sur cette base, comparez aussi les colonnes réelles :

```powershell
python -m tools.compare_hosted_schema
```

Cette vérification est actuellement bloquante : les tables sont bien présentes,
mais leur contrat n'est pas encore celui des modèles. Par exemple, `users`
expose `full_name`/`status` (pas `display_name`/`kyc_status`), `deliveries`
expose des colonnes structurées (`pickup_address`, `dropoff_address`, etc.) et
non `pickup_json`/`dropoff_json`, et `conversation_messages` exige
`conversation_id`. Les identifiants hébergés sont entiers alors que plusieurs
modèles génèrent encore des identifiants texte. Il faut donc un adaptateur ou
une réécriture des modèles avant tout déploiement ; le simple renommage des
tables ne suffit pas.

## Deux principes qui gouvernent ce code

**Le numero de telephone est la cle du compte.** Une adresse e-mail, un mot de
passe, un compte Google ne sont que des portes vers un compte qui possede deja
un numero. C'est pourquoi `/auth/email/verify` peut repondre « adresse prouvee,
aucun compte » : ce n'est pas un echec, c'est le parcours normal d'un nouvel
utilisateur. Le schema l'impose — `accounts.phone` est obligatoire et unique.

**Aucun secret n'est stocke en clair.** Mots de passe et codes a usage unique
partagent la meme empreinte bcrypt compatible avec le site PHP. Une fuite de la base ne donne ni les mots de
passe, ni les codes en vol.

## Ce que le serveur ne dit jamais

- Si une adresse porte un compte, avant que la possession de la boite ne soit
  prouvee. Le dire permettrait d'enumerer les comptes.
- La difference entre « adresse inconnue » et « mot de passe faux ». Meme raison.
- Le detail d'un refus du fournisseur d'e-mail. Il est journalise cote serveur ;
  le mobile n'a rien a apprendre de cette plomberie.

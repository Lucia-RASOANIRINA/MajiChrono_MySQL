# Déploiement FastAPI sur DirectAdmin

## Préparation

Le dossier à publier est `server/`. Le fichier d'entrée Passenger est
`passenger_wsgi.py`.

Ne publiez jamais :

- `server/.env` ;
- `server/majichrono.db` ;
- `server/*.before_remote_mirror_*.db` ;
- `server/.venv/`.

Un `.venv` créé sous Windows contient des binaires compilés pour Windows :
publié tel quel sur un hébergement Linux, il casse l'application (et parfois
l'installation pip elle-même, qui tente de composer avec un environnement
incompatible déjà présent). Pour éviter toute erreur d'oubli, régénérez
toujours l'archive avec le script fourni plutôt qu'en zippant le dossier à la
main :

```powershell
powershell -ExecutionPolicy Bypass -File server/tools/build_api_mobile_zip.ps1
```

Il produit `server/api_mobile.zip` à partir d'une liste blanche de fichiers
sources (code de `app/`, `tools/`, `passenger_wsgi.py`, `requirements.txt`,
`install.sh`, les `.env.*.example`, la documentation) et exclut donc
systématiquement `.venv/`, `.env`, les `*.db` et les caches Python.

La production doit utiliser MySQL/MariaDB via les variables `DB_*`. SQLite est
réservée au développement local.

## Configuration DirectAdmin

Dans **Setup Python App** ou **Application Manager** :

1. Créez une application Python 3.12.
2. Définissez le répertoire de l'application sur le dossier `server`.
3. Définissez le fichier de démarrage sur `passenger_wsgi.py`.
4. Créez ou sélectionnez l'environnement virtuel Python.
5. Installez les dépendances. Deux options :

   - Via le champ « pip install » du panneau DirectAdmin (Setup Python App) :

     ```text
     -r requirements.txt
     ```

   - Si ce champ échoue ou si le terminal DirectAdmin est indisponible,
     exécutez `install.sh` (livré dans l'archive) via une tâche cron
     ponctuelle (panneau **Cron Jobs**) :

     ```bash
     bash /chemin/vers/server/install.sh
     ```

     Le script détecte seul le Python du virtualenv créé par DirectAdmin,
     met à jour pip/setuptools/wheel puis installe `requirements.txt` en
     privilégiant les paquets binaires (`--prefer-binary`), ce qui évite la
     plupart des échecs de compilation native (Rust/gcc absents sur
     l'hébergement mutualisé). Le résultat est journalisé dans
     `server/install.log`, consultable depuis le gestionnaire de fichiers
     même sans terminal fonctionnel. Si l'auto-détection du virtualenv
     échoue, indiquez son chemin explicitement :

     ```bash
     VENV_PYTHON=/home/<user>/virtualenv/<app>/<version>/bin/python bash install.sh
     ```

   `requirements.txt` ne contient que les dépendances de production ; en
   particulier il n'installe pas `uvicorn`, qui n'est jamais utilisé par
   Passenger (l'application est servie via `passenger_wsgi.py` + `a2wsgi`) et
   dont les extras `[standard]` (uvloop, httptools…) sont une cause fréquente
   d'échec de compilation sur ce type d'hébergement. Pour lancer le serveur
   en local avec rechargement automatique, utilisez plutôt
   `requirements-dev.txt` (voir `README.md`).

6. Ajoutez les variables d'environnement dans le panneau :

   ```text
   ENVIRONMENT=prod
   DB_HOST=<hôte MySQL fourni par DirectAdmin>
   DB_NAME=<base MySQL partagée>
   DB_USER=<utilisateur MySQL>
   DB_PASS=<mot de passe MySQL>
   DB_PORT=3306
   JWT_SECRET=<clé aléatoire d'au moins 32 caractères>
   OTP_DEBUG_CODES=false
   SMTP_HOST=<serveur SMTP validé>
   SMTP_PORT=587
   SMTP_USER=<compte SMTP>
   SMTP_PASSWORD=<mot de passe SMTP>
   MAIL_FROM_ADDRESS=<adresse autorisée>
   MAIL_FROM_NAME=MajiChrono
   ```

   Ne définissez pas `DATABASE_URL` vers SQLite en production. Lorsque `DB_*`
   est renseigné, la configuration construit l'URL MySQL automatiquement.

7. Redémarrez l'application Passenger.

## Vérifications après redémarrage

Depuis un navigateur ou PowerShell :

```text
https://api.votre-domaine.mg/health
https://api.votre-domaine.mg/health/ready
```

Résultats attendus :

```json
{"status":"ok","environment":"prod"}
{"status":"ready","environment":"prod"}
```

`/health` vérifie seulement que le processus répond. `/health/ready` vérifie
également l'ouverture d'une connexion MySQL.

Ensuite, testez sans modifier de données :

```text
GET /docs                 # uniquement si ENVIRONMENT n'est pas prod
GET /health/ready
GET /auth/email/request   # seulement avec une adresse de recette autorisée
```

Les premiers tests métier en production doivent utiliser un compte et une
course de recette dédiés. Ne lancez pas les scripts de seed contre la base du
site.

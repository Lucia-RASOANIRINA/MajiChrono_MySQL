# Déploiement FastAPI sur DirectAdmin

## Préparation

Le dossier à publier est `server/`. Le fichier d'entrée Passenger est
`passenger_wsgi.py`.

Ne publiez jamais :

- `server/.env` ;
- `server/majichrono.db` ;
- `server/*.before_remote_mirror_*.db` ;
- `server/.venv/`.

La production doit utiliser MySQL/MariaDB via les variables `DB_*`. SQLite est
réservée au développement local.

## Configuration DirectAdmin

Dans **Setup Python App** ou **Application Manager** :

1. Créez une application Python 3.12.
2. Définissez le répertoire de l'application sur le dossier `server`.
3. Définissez le fichier de démarrage sur `passenger_wsgi.py`.
4. Créez ou sélectionnez l'environnement virtuel Python.
5. Installez les dépendances :

   ```bash
   pip install -r requirements.txt
   ```

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

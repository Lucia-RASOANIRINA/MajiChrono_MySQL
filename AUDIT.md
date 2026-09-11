# Audit technique MajiChrono — 11 septembre 2026

## Résumé

Le backend FastAPI démarre avec MySQL/MariaDB distant par défaut et peut être
lancé avec la copie SQLite locale. La copie locale contient les 31 tables
distantes et les données exportées au moment de la synchronisation. Aucune
écriture de migration n'a été exécutée sur MySQL distant.

## Validation effectuée

| Contrôle | Résultat |
|---|---|
| Tables distantes inspectées | 31 |
| Tables SQLite locales | 31 |
| Lignes copiées dans SQLite | 503 |
| Sauvegarde avant remplacement | Oui |
| Tests backend | 156 réussis |
| Health check avec SQLite miroir | HTTP 200 |
| Comparaison ORM / schéma | 0 colonne ORM manquante |
| Flutter tests | Réussis lors de l'audit précédent |
| Flutter analyze | 0 problème après nettoyage |

La comparaison ORM signale de nombreuses colonnes `HOSTED-ONLY`. Elles sont
conservées dans la copie locale et restent disponibles pour les fonctionnalités
du site, même lorsqu'une route mobile ne les expose pas encore.

## Utilisation des tables par le mobile

Les tables directement utilisées par les parcours API sont :

- `users`, `addresses`, `drivers`, `driver_vehicles` ;
- `deliveries`, `delivery_events`, `location_pings`, `delivery_incidents` ;
- `conversations`, `conversation_messages` ;
- `payments`, `reviews`, `reclamations`, `reclamation_messages` ;
- `kyc_documents`, `kyc_messages`, `media` ;
- `notifications`, `refresh_tokens`, `idempotency_records`,
  `moderation_logs`.

Les tables historiques du site restent dans le schéma partagé et sont
préservées : `api_tokens`, `avatars`, `contact_messages`, `login_attempts`,
`password_resets`, `reclamation_files`, `settings`.

Elles ne doivent pas être artificiellement écrites par le mobile uniquement
pour prétendre qu'elles sont utilisées. Elles sont administrées par les
parcours web ou par des fonctionnalités mobiles futures.

## Fonctionnalités non finalisées

- **MajiPay réel** : à venir. Le backend force désormais le bac à sable, même
  si une clé est présente, afin d'éviter tout débit réel non validé.
- **SMS réel** : fonctionnalité indisponible. Aucun appel fournisseur n'est
  effectué ; le serveur journalise seulement que le code n'a pas été envoyé.
- **Chaîne de garde** : les événements, incidents et médias sont conservés,
  mais la preuve opposable, la signature et la validation terrain restent à
  finaliser.
- **DirectAdmin** : le point d'entrée Passenger est présent mais ne peut pas
  être validé sans accès au serveur et à son panneau.

## Lancer avec les données locales miroirs

Depuis `server/` :

```powershell
$env:DATABASE_URL = "sqlite:///./majichrono.db"
uvicorn app.main:app --reload
```

Pour renouveler la copie depuis MySQL distant :

```powershell
python -m tools.mirror_remote_sqlite --dry-run
python -m tools.mirror_remote_sqlite --replace
```

La commande crée une sauvegarde locale avant chaque remplacement. Elle ne
modifie jamais la base distante.

## Risques et prochaines validations

1. Tester les écritures métier sur une base MySQL de préproduction avant le
   serveur du site.
2. Valider les contraintes obligatoires du site pour création de livraison,
   paiement, discussion et réclamation.
3. Obtenir les spécifications officielles MajiPay et du fournisseur SMS avant
   toute activation.
4. Effectuer une recette DirectAdmin avec HTTPS, variables d'environnement,
   Passenger et connexion MySQL.

# MajiChrono — application mobile Flutter

Refonte Flutter de l'application mobile MajiChrono, plateforme de livraison à la
demande pour Madagascar.

Ce dépôt met en oeuvre le cahier des charges
`MajiChrono_Cahier_des_Charges_Mobile_Flutter.md` version 1.0. Les références
`§x.y` et `EXI-xx##` qui apparaissent dans ce document et dans les commentaires
du code renvoient à ce cahier des charges.

---

## Sommaire

1. [Démarrer](#1-démarrer)
2. [Les trois profils](#2-les-trois-profils)
3. [Architecture](#3-architecture)
4. [Le backend simulé](#4-le-backend-simulé)
5. [Règles de conception](#5-règles-de-conception)
6. [Avancement par module](#6-avancement-par-module)
7. [Détail des tâches par module](#7-détail-des-tâches-par-module)
8. [Tests](#8-tests)
9. [Environnement de développement](#9-environnement-de-développement)
10. [Décisions à arbitrer](#10-décisions-à-arbitrer)
11. [Fonctionnalités disponibles](#11-fonctionnalités-disponibles)
12. [Technologies utilisées](#12-technologies-utilisées)
13. [Base de données](#13-base-de-données)
14. [Comptes de test](#14-comptes-de-test)

---

## 1. Démarrer

### Prérequis

| Élément | Version | Remarque |
|---|---|---|
| Flutter | 3.44 ou plus, canal stable | Dart 3.12 |
| JDK | 21 | Celui d'Android Studio (`jbr`). Voir §9. |
| Android SDK | API 35 pour compiler | Minimum d'exécution : API 26 |

### Installation

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
```

### Lancer

```bash
# Backend simulé — à demander explicitement pour le développement hors ligne
flutter run --dart-define=API_MODE=mock

# Backend réel hébergé (mode par défaut)
flutter run --dart-define=API_MODE=live \
            --dart-define=API_BASE_URL=https://majichrono.majitech.mg/mobile-api
```

### Vérifier

```bash
flutter analyze
flutter test
```

---

## 2. Les trois profils

Une application unique sert trois populations. Le profil détermine la coquille
de navigation et les écrans accessibles.

| Profil | Nom dans l'interface | Ce qu'il fait |
|---|---|---|
| Expéditeur | Client | Crée une course, suit son colis, paie, note le livreur |
| Livreur | Livreur | Accepte, exécute, produit les constats, encaisse |
| Exploitation | Administrateur | Valide les KYC, supervise la flotte, arbitre les litiges |

Un quatrième acteur n'installe rien : le **destinataire**. Il reçoit un lien de
suivi par SMS et signe à la remise sur l'écran du livreur.

Le profil administrateur n'est jamais choisi par l'utilisateur : il est attribué
côté serveur (EXI-T02).

---

## 3. Architecture

Découpage en quatre couches, conforme au §8.1. La règle de dépendance est
stricte : **une couche ne connaît que celle du dessous, et le domaine ne connaît
personne**. Toute violation est bloquante en revue.

```
Présentation    écrans, widgets, contrôleurs
      |
Domaine         entités, cas d'usage, interfaces      (aucune dépendance externe)
      |
Données         implémentations, sources, DTO
      |
Socle           réseau, stockage, journaux, i18n
```

### Organisation des fichiers

```
lib/
  main.dart, bootstrap.dart     amorçage, injection des dépendances prêtes
  app/
    router/                     go_router, redirections par profil
    theme/                      jetons, palette, thèmes clair et sombre
    shell/                      coquille commune aux trois profils
  core/
    config/                     configuration injectée à la compilation
    error/                      hiérarchie de Failure typées
    i18n/                       bascule français / malgache à chaud
    logging/                    journal circulaire, expurgation
    network/                    client HTTP, intercepteurs, sonde, transport simulé
    providers/                  injection Riverpod du socle
    session/                    profil actif
    storage/                    base drift, stockage sécurisé, préférences
  features/
    <fonctionnalité>/           chacune en data/ · domain/ · presentation/
  shared/                       composants et utilitaires transverses
  l10n/arb/                     traductions français et malgache
```

### Choix techniques

| Domaine | Choix | Motif |
|---|---|---|
| État et injection | Riverpod 2 | Testable sans widget, un seul mécanisme |
| Navigation | go_router | Liens profonds requis par EXI-N04 et EXI-C24 |
| Réseau | dio | Intercepteurs, reprise, annulation |
| Base locale | drift, SQLite en mode WAL | SQL réel, migrations versionnées, requêtes réactives |
| Secrets | flutter_secure_storage | Keystore Android, Keychain iOS |
| Traductions | ARB, deux langues | Français et malgache |

---

## 4. Les backends et le déploiement

Le backend actuellement destiné au mobile et déployé sur DirectAdmin est
Laravel/PHP dans [`server-php/`](./server-php/). C'est le seul backend du
projet : l'ancien backend Python (FastAPI) a été retiré. Pour travailler sans
serveur, l'application embarque un backend simulé (voir plus bas).

### Backend Laravel (production mobile)

Le point d'entrée public est :

```text
https://majichrono.majitech.mg/mobile-api
```

Le contenu de `server-php/laravel-deploy.zip` doit être extrait directement
dans :

```text
domains/majichrono.majitech.mg/public_html/mobile-api/
```

Le ZIP contient directement `index.php`, `.htaccess`, `app/`, `routes/` et
`vendor/`, sans les dépendances de développement. Il est produit par
`server-php/build-deploy-zip.ps1`. Les dossiers internes et les fichiers de la
racine (`.env`, `composer.*`, `artisan`) sont protégés par `.htaccess` :
`/mobile-api/.env` doit répondre 403.

Après chaque déploiement :

1. appliquer les migrations : `php artisan migrate --force` ;
2. vérifier `/health`, puis `/health/ready` (`"status":"ready"`) ;
3. vérifier qu'un fichier interne est refusé :
   `curl -s -o /dev/null -w "%{http_code}" https://majichrono.majitech.mg/mobile-api/.env`
   doit afficher `403` ;
4. dérouler les parcours authentifiés avec un compte de préproduction.

Points de configuration de production (`.env.production`) :

- `MAJIPAY_SANDBOX=false`. Les portefeuilles MajiPay de démonstration ne sont
  jamais crédités en production. Un règlement sans solde échoue proprement et
  bascule en espèces.
- `JWT_SECRET` a été renouvelé le 3 octobre 2026. Au premier déploiement
  qui l'embarque, chaque utilisateur se reconnecte une fois.
- Les points relais viennent du réglage `relay_points`, posé par un
  administrateur via `PUT /admin/settings/relay_points`. Sa valeur est un
  tableau JSON de relais (`id`, `name`, `district`, `landmark`, `point`,
  `openingHours`, `phone`, `acceptsDropoff`, `acceptsPickup`, `maxWeightKg`,
  `storageDays`). Sans réglage, aucun relais n'est proposé.
- **Pare-feu de l'hébergeur.** Il bloque une IP après une rafale de requêtes.
  À Majunga, beaucoup d'abonnés mobiles sortent par la même IP (CGNAT). Le
  seuil doit donc rester large, car l'API limite déjà elle-même les essais
  (voir ci-dessous).

Limites de requêtes appliquées par l'API (réponse 429
`too_many_requests` ou `too_many_attempts`) :

| Usage | Plafond |
|---|---|
| Connexion (mot de passe, clé d'appareil, vérification de code) | 10/min par identifiant, 60/min par IP |
| Échecs de mot de passe | 5 par identifiant, blocage 15 min |
| Envoi d'un code SMS ou e-mail | 3 par quart d'heure et par destination, 30/h par IP |
| Inscription, rafraîchissement de session | 30/min par IP |
| Suivi public, formulaire de contact | 30/min par IP |
| Reste de l'API | 300/min par session |

Les rapports d'exploitation sont exportables par un administrateur avec :

```text
GET /admin/reports/deliveries.csv?from=2026-09-01&to=2026-09-30
```

La route répond en CSV UTF-8 et impose un jeton administrateur.

### Recette terrain

Avant publication, exécuter sur un appareil Android physique :

1. couper complètement le réseau pendant la création d'une course ;
2. vérifier la présence de la course dans la file locale ;
3. rétablir le réseau et vérifier une seule synchronisation ;
4. tester le GPS écran verrouillé pendant 15 minutes ;
5. répéter en 2G/EDGE et vérifier l'adaptation de la cadence ;
6. mesurer la batterie après 30 minutes de suivi ;
7. vérifier les permissions refusées puis réaccordées ;
8. fermer et rouvrir l'application pendant la synchronisation.

Chaque scénario doit être contrôlé avec les journaux de synchronisation et
l'absence de doublons côté serveur.

### Livraison rapide à Majunga : véhicule, prix fixe, attribution immédiate

MajiChrono est une plateforme de **livraison uniquement**, entre un client
expéditeur et un livreur. Elle dessert **Majunga (Mahajanga) et ses environs,
dans un rayon de 25 km**.

D'inDrive, elle ne reprend que la **rapidité** :

1. **Choisir le véhicule selon la taille du colis.** Quatre véhicules sont
   proposés : moto (jusqu'à 15 kg), tricycle ou bajaj (jusqu'à 30 kg), voiture
   (colis volumineux ou fragiles) et camionnette (gros volumes). Un véhicule
   est proposé d'office d'après le poids déclaré. La moto est refusée au-delà
   de 15 kg.
2. **Voir un prix fixe avant de commander.** Chaque véhicule a sa grille :
   prise en charge, prix au kilomètre et minimum, auxquels s'ajoutent les
   suppléments existants (poids, nature du colis, créneau programmé,
   assurance). Le mobile (`DeliveryVehicle`) et Laravel
   (`App\Support\DeliveryFare`) appliquent la même formule. Le serveur
   recalcule le prix et fait foi ; un prix envoyé par le téléphone n'est
   jamais repris tel quel.
3. **Attribuer la course immédiatement.** La demande n'est proposée qu'aux
   livreurs en ligne équipés du bon véhicule, les plus proches du point de
   retrait en premier. Le premier qui accepte prend la course.

| Véhicule | Prise en charge | Par km | Minimum |
|---|---|---|---|
| Moto | 2 000 Ar | 800 Ar | 2 000 Ar |
| Tricycle (bajaj) | 3 000 Ar | 1 000 Ar | 3 000 Ar |
| Voiture | 5 000 Ar | 1 200 Ar | 5 000 Ar |
| Camionnette | 15 000 Ar | 2 500 Ar | 15 000 Ar |

Ces montants sont provisoires, en attendant l'arbitrage DO-3.

Pour gagner du temps à la saisie, le formulaire d'adresse propose aussi les
lieux connus de Majunga : un toucher remplit le point GPS, le quartier et le
repère. Après une commande en ligne, l'application ouvre directement le suivi,
qui affiche « En attente d'un livreur », puis l'approche du livreur.

Règles appliquées par le serveur :

- **Avancement.** Le livreur assigné mène la course du départ à la remise.
  Le client ne peut que confirmer la réception une fois le livreur arrivé.
  « Acceptée » s'obtient seulement par l'acceptation, ou par une
  réaffectation de l'exploitation.
- **Acceptation.** Le livreur doit être en ligne, validé et équipé du bon
  véhicule. Un livreur sans véhicule déclaré ne reçoit aucune course.
  L'attribution est atomique : deux livreurs qui acceptent à la même seconde
  ne peuvent pas obtenir la même course.
- **Avant acceptation**, le livreur voit le trajet et le colis, mais pas les
  numéros de contact.
- **Annulation.**
  - Le livreur qui renonce avant la prise en charge rend la course, qui
    repart aux autres livreurs.
  - Le client annule sans frais pendant 3 minutes après l'acceptation.
    Ensuite, les frais valent 20 % du prix, avec un minimum de 1 000 Ar.
- **Paiement.**
  - Le montant est le prix fixe de la course, et une course se règle une
    seule fois.
  - Confirmer deux fois ne débite qu'une fois.
  - Un retrait ne dépasse jamais le solde.
- **Suivi public.** Le code `MC-<course>-<contrôle>` est signé et ne se devine
  pas. Il donne le statut et le quartier, jamais l'adresse.
- **Terrain.** Le serveur enregistre l'alerte SOS (`/drivers/emergency`) et
  prévient chaque administrateur. Les constats de prise en charge et de
  remise (`/deliveries/{id}/custody/...`) sont vérifiés par empreinte et
  chaînés. La trace en direct (`/deliveries/{id}/trace`) ne montre le livreur
  que pendant la course. La réaffectation (`/admin/deliveries/{id}/reassign`)
  exige un motif.

Après déploiement du code, appliquer les migrations : `vehicle` sur
`deliveries`, la table `device_credentials`, puis les tables
`emergency_alerts` et `custody_reports`.

```text
php artisan migrate --force
```

### Fond de carte

La carte utilise les tuiles d'OpenStreetMap, gardées 30 jours dans un cache
disque de 150 Mo. Le 2 octobre 2026, elles ont été vérifiées pour Majunga,
avec l'identifiant de l'application. Chaque carte affiche la mention
« © OpenStreetMap », exigée par la licence.

- **CARTO** exige désormais une clé. Sans clé, chaque tuile est remplacée par
  une image « API KEY REQUIRED ». Cette source n'est donc plus utilisée.
- **Pour un trafic important**, fournissez une clé MapTiler à la
  compilation : `--dart-define=MAP_TILES_KEY=...`. La politique d'usage du
  serveur OpenStreetMap ne convient pas à une forte charge.
- **En mode économie**, si l'option « tuiles à la demande » est désactivée,
  la carte se limite aux tuiles déjà en cache.

### Entrée par numéro de téléphone

Le numéro fonctionne **sans SMS**. À l'inscription, le téléphone demande son
propre verrouillage (code, schéma, empreinte ou visage), puis crée une clé
secrète. Il la garde dans son stockage sécurisé et la confie au serveur
(`POST /auth/phone/register`), qui n'en conserve que l'empreinte. Se connecter
consiste à déverrouiller le téléphone pour présenter cette clé
(`POST /auth/phone/login`).

Le mot de passe sert de secours. Il est obligatoire si le téléphone n'a aucun
verrouillage. Sur un nouveau téléphone, il est demandé une fois, puis ce
téléphone est lié au compte (`POST /auth/devices`). Changer de mot de passe
ferme les autres sessions. Une réinitialisation ferme toutes les sessions et
délie tous les téléphones. Le champ du numéro affiche un préfixe `+261` fixe
et ajoute les espaces automatiquement (`34 12 345 67`). Il accepte aussi un
numéro collé sous la forme `034…`, `+261…` ou `00261…`.

Tant que `SMS_ENABLED` vaut `false` (valeur par défaut), l'API n'envoie jamais
de code OTP. Elle répond `phone_not_registered` (404) pour un numéro inconnu et
`password_not_set` (409) pour un ancien compte sans mot de passe. Le numéro
d'un compte créé ainsi reste **non vérifié** (`phone_verified_at` nul) jusqu'au
branchement d'une passerelle SMS. Il faudra alors passer `SMS_ENABLED=true` et
implémenter `App\Support\SmsSender`.

### Messagerie et push

La messagerie serveur supporte désormais :

- les conversations libres avec l'administration ;
- la recherche par contenu ;
- les pièces jointes référencées par le stockage `/media` ;
- l'archivage, la restauration, le blocage, le déblocage et la suppression
  synchronisés.

Après déploiement du code Laravel, appliquer la migration avant d'ouvrir ces
routes :

```text
php artisan migrate --force
```

Le push distant Android nécessite encore la configuration opérationnelle FCM :
`android/app/google-services.json` côté Flutter et un compte de service Firebase
configuré hors Git côté Laravel. Sans ce compte, l'application conserve le
transport de notifications locales et l'API ne doit pas être considérée comme
un push distant actif.

### Le backend simulé (mode `mock`)

Lancée avec `--dart-define=API_MODE=mock`, l'application n'appelle aucun
serveur : chaque module métier enregistre ses routes simulées dans
`MockBackend`.

Le point important est l'endroit où la simulation se branche. `MockHttpAdapter`
remplace le `HttpClientAdapter` de dio, c'est-à-dire l'octet qui part sur le
réseau, et rien d'autre. Toute la pile réelle est traversée à l'identique :
intercepteur d'idempotence, compteur de données, journalisation expurgée,
traduction des erreurs.

Trois conséquences :

- passer de `mock` à `live` ne change aucune ligne hors du socle ;
- les chemins consommés sont les constantes de `ApiEndpoints`, donc exactement
  ceux du §12.2 ;
- le simulateur reproduit le réseau malgache décrit au §4.1 : latence par profil
  (4G, 3G, 2G), temps de transfert proportionnel au débit, coupures injectées.

Ce dernier point rend jouables les scénarios de recette obligatoires du §16.2
sans quitter le bureau. Le **panneau développeur**, accessible par l'icône en
forme d'insecte ou par Réglages, pilote le profil réseau et le taux d'échec.

Chaque module métier enregistre ses propres routes simulées au moyen d'un
`MockModule`, sans toucher au socle.

---

## 5. Règles de conception

Reprises du §9.3 du cahier des charges. Elles sont vérifiées en revue, et pour
certaines par des tests automatiques.

| Règle | Vérification |
|---|---|
| Aucune logique métier dans un widget | Revue |
| Aucun appel réseau depuis la présentation, toujours via un cas d'usage | Revue |
| Toute écriture passe par la file de synchronisation, jamais par le réseau | Revue |
| Toute erreur est typée, aucun message technique affiché | `error_mapper_test.dart` |
| Tout texte affiché vient des fichiers ARB | `no_literal_strings_test.dart` |
| Une dépendance de plus de 2 Mo doit être justifiée | Revue |

---

## 6. Avancement par module

Chaque module est construit, testé sur émulateur, puis validé avant le suivant.

| Module | Objet | Lot du cahier des charges | État |
|---|---|---|---|
| 0 | Socle technique et coquille navigable | Lot 0 | Livré |
| 1 | Authentification et session | Lot 1 | Implémenté, validation live à poursuivre |
| 2 | Expéditeur : création de course | Lot 1 | Implémenté |
| 3 | Suivi cartographique et notifications | Lot 1 | Implémenté, SMS réel à venir |
| 4 | Livreur : KYC, file, progression | Lot 2 | Implémenté |
| 5 | Chaîne de responsabilité et preuve | Lot 2 | Partiel, preuve opposable à finaliser |
| 6 | Mode hors ligne intégral | Lot 2 | Implémenté côté mobile, recette terrain à poursuivre |
| 7 | Paiement délégué à MajiPay | Lot 3 | Sandbox uniquement, MajiPay réel à venir |
| 8 | Supervision depuis mobile | Lot 4 | Implémenté |
| 9 | Différenciants concurrentiels | Lot 5 | Partiel |
| 10 | Durcissement et recette terrain | Lot 6 | En validation |

Le module 5 est le coeur différenciant du produit. C'est lui qui produit la
preuve opposable qu'aucun concurrent local ne fournit aujourd'hui (§3.3).

### État réel des intégrations

- **MajiPay réel : à venir.** Les routes de paiement utilisent uniquement le
  bac à sable local ; une clé `MAJIPAY_API_KEY` ne déclenche plus d'appel réel.
- **SMS réel : fonctionnalité indisponible.** Aucun SMS fournisseur n'est
  envoyé ; l'API journalise uniquement qu'un code n'a pas été envoyé.
- **Chaîne de garde : partielle.** Les événements, médias et incidents sont
  conservés, mais la preuve juridiquement opposable et sa validation terrain
  restent à finaliser.
- **DirectAdmin : non validé sur le serveur de production.** Le point d'entrée
  Passenger est prêt, mais une recette avec accès administrateur reste requise.

---

## 7. Détail des tâches par module

La colonne **Profil** indique qui utilise la fonction : *Transverse* désigne ce
qui sert les trois profils.

### Module 0 — Socle technique (livré)

| Tâche | Profil | Exigences | État |
|---|---|---|---|
| Projet Flutter, découpage en quatre couches, organisation par fonctionnalité | Transverse | §8.1, §8.2 | Fait |
| Design system : jetons, palette, thèmes clair et sombre, composants partagés | Transverse | §15.1 | Fait |
| Bascule français / malgache à chaud, sans redémarrage | Transverse | EXI-T05 | Fait |
| Libellés intégrés de Flutter en malgache, repli français | Transverse | Critère 7 du §18 | Fait |
| Bandeau permanent d'état réseau, au-dessus de tout écran empilé | Transverse | EXI-T06 | Fait |
| Sonde applicative réelle, qualification du profil réseau par temps de réponse | Transverse | §9.2, EXI-C20 | Fait |
| Compteur de données consommées, ventilé par usage | Transverse | EXI-T07, D8 | Fait |
| Client HTTP, intercepteurs, clé d'idempotence stable entre reprises | Transverse | EXI-S01, EXI-B01 | Fait |
| Transport simulé reproduisant 4G, 3G, 2G et coupure | Transverse | §4.1, §16.2 | Fait |
| Hiérarchie d'erreurs typées et restitution en langage courant | Transverse | §9.3, §15.2 | Fait |
| Journal local circulaire, expurgé des données personnelles | Transverse | EXI-T10, EXI-P10 | Fait |
| Base locale drift en mode WAL, table de file de synchronisation | Transverse | EXI-P08, §10.2 | Fait |
| Stockage sécurisé des secrets au Keystore | Transverse | EXI-SEC03 | Fait |
| Routage, redirections par profil, cloisonnement des routes | Transverse | EXI-N04 | Fait |
| Coquille navigable des trois profils | Transverse | §2.1 | Fait |
| Panneau développeur pilotant le réseau simulé | Transverse | §16.2 | Fait |
| Configuration Android : API 26 minimum, HTTPS exclusif, obfuscation | Transverse | EXI-P09, EXI-SEC01, EXI-SEC09 | Fait |

Reste ouvert sur ce module : l'épinglage de certificat à double empreinte
(EXI-SEC02), qui attend le certificat de production, et sera posé au module 10.

### Module 1 — Authentification et session

| Tâche | Profil | Exigences |
|---|---|---|
| Inscription par numéro malgache `+261 3x xx xxx xx` | Transverse | EXI-T01 |
| Vérification par code OTP à 6 chiffres, 5 minutes, 3 tentatives | Transverse | EXI-T01 |
| Choix du profil à l'inscription, client ou livreur | Transverse | EXI-T02 |
| Jeton d'accès de 15 minutes, jeton de rafraîchissement de 30 jours, rotation | Transverse | EXI-T03 |
| Reconnexion par biométrie ou code PIN à 4 chiffres | Transverse | EXI-T04 |
| Verrouillage automatique après 5 minutes d'inactivité | Livreur, Exploitation | EXI-SEC07 |
| Effacement complet des données locales à la déconnexion | Transverse | EXI-SEC10 |
| Écran de profil et modification du compte | Transverse | §12.2 |

### Module 2 — Expéditeur : création de course

| Tâche | Profil | Exigences |
|---|---|---|
| Adresse composite : point GPS, quartier, point de repère, téléphone | Expéditeur | EXI-C02 |
| Saisie par carte, position actuelle, favoris ou point relais | Expéditeur | EXI-C01 |
| Photo de façade attachable et réutilisée au prochain envoi | Expéditeur | EXI-C03 |
| Note vocale d'itinéraire de 30 secondes | Expéditeur | EXI-C04 |
| Carnet d'adresses avec favoris nommés | Expéditeur | EXI-C05 |
| Type de course, dont achat pour compte | Expéditeur | EXI-C06 |
| Déclaration du colis : poids, dimensions, valeur | Expéditeur | EXI-C08 |
| Photo du colis obligatoire à la création | Expéditeur | EXI-C09 |
| Estimation de prix ventilée, affichée avant confirmation | Expéditeur | EXI-C10 |
| Créneau immédiat ou programmé | Expéditeur | EXI-C11 |
| Création de course entièrement hors ligne, mise en file | Expéditeur | EXI-C13 |
| Historique consultable hors ligne, reçu partageable | Expéditeur | EXI-C33, EXI-C34 |

### Module 3 — Suivi et notifications

| Tâche | Profil | Exigences |
|---|---|---|
| Carte temps réel, tuiles pré-téléchargeables hors ligne | Expéditeur | EXI-C20, §9.2 |
| Rafraîchissement adaptatif : 10 s en 4G, 45 s en 2G | Expéditeur | EXI-C20 |
| Frise chronologique horodatée des statuts | Expéditeur | EXI-C21 |
| Fiche livreur : photo, note, plaque, véhicule | Expéditeur | EXI-C22 |
| Appel et messagerie interne, numéros masqués des deux côtés | Expéditeur, Livreur | EXI-C23, EXI-B07 |
| Lien de suivi public partageable par SMS, sans installation | Destinataire | EXI-C24, D9 |
| Notifications distantes, canaux Android paramétrables | Transverse | EXI-N01, EXI-N02 |
| Ouverture de l'écran concerné par lien profond | Transverse | EXI-N04 |
| Notification traduite selon la langue du compte | Transverse | EXI-N05 |
| Repli SMS sous 60 s pour les événements critiques | Transverse | EXI-N06 |
| Annulation avant prise en charge, grille de frais affichée | Expéditeur | EXI-C26 |

### Module 4 — Livreur : KYC, file et progression

| Tâche | Profil | Exigences |
|---|---|---|
| Dossier KYC : CIN, permis, visage, carte grise, véhicule, plaque | Livreur | EXI-L01 |
| Suivi de l'état du dossier, refus motivé | Livreur | EXI-L02 |
| Interrupteur en ligne et hors ligne, persistant après redémarrage | Livreur | EXI-L03 |
| File des courses disponibles, triée par distance, gain estimé | Livreur | EXI-L04 |
| Acceptation en un geste, compte à rebours de 30 secondes | Livreur | EXI-L05 |
| Navigation déléguée à l'application cartographique installée | Livreur | EXI-L07 |
| Progression par bouton unique plein écran | Livreur | EXI-L08, §15.3 |
| Émission de position en arrière-plan, écran verrouillé | Livreur | EXI-L09 |
| Cadence adaptative : 15 s en mouvement, 60 s à l'arrêt | Livreur | EXI-L11 |
| Tableau de bord des gains par jour, semaine et mois | Livreur | EXI-L12 |
| Signalement d'incident avec photo et conséquence définie | Livreur | EXI-L14 |
| Notation reçue et historique | Livreur | EXI-L16 |

### Module 5 — Chaîne de responsabilité et preuve

Coeur différenciant du produit (D2, D11). Le principe : à chaque transfert de
responsabilité, l'application produit un constat contradictoire, horodaté,
géolocalisé, photographié et signé par les deux parties.

| Tâche | Profil | Exigences |
|---|---|---|
| Constat de prise en charge : 4 photos guidées par gabarit | Livreur, Expéditeur | EXI-CC10 |
| Prise de vue dans l'application uniquement, import galerie interdit | Livreur | EXI-CC11 |
| Grille d'état à cocher, photo et commentaire imposés par anomalie | Livreur | EXI-CC12, EXI-CC13 |
| Numéro de scellé par saisie ou scan de code-barres | Livreur | EXI-CC14 |
| Signature manuscrite de l'expéditeur et contre-signature du livreur | Expéditeur, Livreur | EXI-CC16, EXI-CC17 |
| Constat de remise au même gabarit, affichage côte à côte | Livreur, Destinataire | EXI-CC20, EXI-CC21 |
| Vérification du scellé, incident automatique si rompu ou absent | Livreur | EXI-CC22 |
| Signature du destinataire et code OTP, double preuve d'identité | Destinataire | EXI-CC24 |
| Réception avec réserves, refus de réception, remise à un tiers | Destinataire | EXI-CC26 à EXI-CC28 |
| Écran comparateur avant et après, écarts surlignés | Expéditeur, Livreur, Exploitation | EXI-CC30, EXI-CC31 |
| Signature capturée en vectoriel, rendu PNG dérivé | Transverse | EXI-CC40 |
| Empreinte SHA-256 du constat, chaînage remise sur prise en charge | Transverse | EXI-CC43, EXI-CC44 |
| Constat scellé à la validation, aucune modification ultérieure | Transverse | EXI-CC04 |
| Constat stocké chiffré tant qu'il n'est pas accusé par le serveur | Transverse | EXI-CC46 |
| Export du constat en PDF signé | Expéditeur, Exploitation | EXI-CC32 |

### Module 6 — Mode hors ligne intégral

| Tâche | Profil | Exigences |
|---|---|---|
| File de synchronisation, écriture locale avant toute tentative réseau | Transverse | §10.2 |
| Ordre de priorité : constats, transitions, positions, notations | Transverse | EXI-S02 |
| Reprise exponentielle jusqu'à 15 essais, puis signalement | Transverse | §10.2 |
| Conflit détecté : le serveur fait foi, l'utilisateur est informé | Transverse | EXI-S04 |
| Un constat n'est jamais abandonné automatiquement | Transverse | EXI-S05 |
| Écran « éléments en attente » : liste, âge, cause, relance manuelle | Transverse | EXI-S06 |
| Positions en tampon local, envoi par lots compressés de 50 points | Livreur | EXI-L10, EXI-S03 |
| Purge des photos transmises et accusées | Transverse | EXI-S07 |
| Parcours livreur complet exécutable hors ligne | Livreur | EXI-L15, EXI-P07 |

### Module 7 — Paiement délégué à MajiPay

| Tâche | Profil | Exigences |
|---|---|---|
| Simulateur MajiPay implémentant le contrat, avant livraison du vrai | Transverse | EXI-MP12 |
| Intention de paiement créée côté serveur, aucun secret sur le mobile | Transverse | EXI-MP02 |
| Ouverture app-to-app par lien profond, retour automatique | Expéditeur | EXI-MP03 |
| Écran d'attente et consigne USSD si MajiPay n'est pas installé | Expéditeur | EXI-MP04 |
| État du paiement par notification, sondage de repli plafonné à 120 s | Expéditeur | EXI-MP05 |
| Idempotence stricte, jamais deux débits pour une intention | Transverse | EXI-MP06 |
| Repli espèces automatique, la course n'est jamais bloquée | Expéditeur | EXI-MP08, EXI-C43 |
| Reçu consultable et partageable depuis l'historique | Expéditeur | EXI-MP10 |
| Aucune donnée de paiement dans les journaux | Transverse | EXI-MP11 |

### Module 8 — Supervision depuis mobile

| Tâche | Profil | Exigences |
|---|---|---|
| Tableau de bord : courses, livreurs en ligne, incidents, chiffre du jour | Exploitation | EXI-A01 |
| Carte de flotte temps réel, filtrable par statut | Exploitation | EXI-A02 |
| File de validation KYC, visionneuse de pièces, refus motivé | Exploitation | EXI-A03 |
| Liste des courses, filtres multicritères, accès aux deux constats | Exploitation | EXI-A04 |
| Gestion des litiges : comparateur, échange, décision, clôture | Exploitation | EXI-A05 |
| Suspension et réactivation d'un compte, motif obligatoire | Exploitation | EXI-A06 |
| Réaffectation manuelle d'une course | Exploitation | EXI-A07 |

### Module 9 — Différenciants concurrentiels

| Tâche | Profil | Exigences |
|---|---|---|
| Achat pour compte : liste d'articles, plafond, photo du ticket | Expéditeur, Livreur | EXI-C07, D5 |
| Groupage de 2 à 3 courses sur un même axe | Livreur | EXI-L06, D7 |
| Bouton d'urgence accessible en deux appuis | Livreur | EXI-L13, D10 |
| Réseau de points relais partenaires | Expéditeur, Destinataire | D6 |
| Mode économie : tuiles pré-téléchargées, photos différées | Transverse | EXI-T08 |
| Option assurance sur valeur déclarée | Expéditeur | EXI-C12 |
| Payeur désignable, port dû | Expéditeur, Destinataire | EXI-C42 |

### Module 10 — Durcissement et recette terrain

| Tâche | Profil | Exigences |
|---|---|---|
| Budgets tenus : démarrage, mémoire, taille, batterie, données | Transverse | EXI-P01 à EXI-P06 |
| Épinglage de certificat à double empreinte et rotation | Transverse | EXI-SEC02 |
| Détection d'appareil rooté, capture d'écran interdite sur les écrans sensibles | Transverse | EXI-SEC05, EXI-SEC06 |
| Accessibilité : contraste AA, cibles de 48 dp, TalkBack | Transverse | EXI-T09 |
| Les 8 scénarios de recette du §16.2 sur trois appareils réels | Transverse | §16.2 |
| Recette terrain par 10 livreurs sur 5 jours | Livreur | Critère 10 du §18 |
| Préparation de la publication iOS | Transverse | §2.1 |

---

### Publier l'application Android

Le Play Store exige une clé de signature propre à MajiChrono. Créez-la une
fois et gardez-la hors du dépôt : la perdre empêche toute mise à jour.

```bash
keytool -genkey -v -keystore android/majichrono-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias majichrono
```

Décrivez-la ensuite dans `android/key.properties`, que Git ignore :

```text
storeFile=majichrono-release.jks
storePassword=...
keyAlias=majichrono
keyPassword=...
```

Sans ce fichier, `flutter build apk --release` signe avec la clé de debug.
L'APK s'installe pour essai, mais le Play Store le refuse.

## 8. Tests

| Suite | Ce qu'elle verrouille |
|---|---|
| `mock_transport_test.dart` | Comportement du transport simulé : hors ligne, latence 2G, erreurs au format du §12.1, compteur de données |
| `idempotency_test.dart` | La clé d'idempotence est posée sur les écritures et **reste identique entre deux reprises** |
| `error_mapper_test.dart` | Traduction des codes HTTP en erreurs typées, état serveur conservé en cas de conflit |
| `redaction_test.dart` | Numéros, OTP, soldes et positions absents des journaux |
| `translation_completeness_test.dart` | Aucune clé manquante ni orpheline entre français et malgache, paramètres cohérents |
| `no_literal_strings_test.dart` | Aucun libellé écrit en dur dans les widgets |
| `widget_test.dart` | Démarrage, bascule de langue, coquille par profil, permanence du bandeau réseau |

Deux de ces tests méritent une explication, car ils protègent contre des défauts
qui ne cassent rien à la compilation :

- **Complétude des traductions.** Une clé oubliée dans `app_mg.arb` ne provoque
  aucune erreur : Flutter retombe silencieusement sur le français. Le défaut ne
  se verrait qu'en recette terrain, chez un livreur malgachophone.
- **Absence de chaînes littérales.** Un libellé écrit en dur reste en français
  au milieu d'un écran par ailleurs traduit. C'est arrivé sur l'accueil du socle
  et cela ne se voyait qu'à l'écran, en malgache.

---

## 9. Environnement de développement

### JDK

Gradle doit utiliser le JDK 21 fourni par Android Studio. Avec un JDK plus
récent, la compilation Kotlin échoue par intermittence sur des verrous de cache
sous Windows.

```bash
flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"
```

La compilation incrémentale Kotlin est désactivée dans `android/gradle.properties`
pour la même raison. Le coût est de quelques dizaines de secondes par
compilation, le gain est un build reproductible.

### Tests sur le poste

`flutter test` s'exécute sur la machine de développement, où la bibliothèque
native SQLite livrée pour Android n'est pas chargée. Les tests de widget
n'ouvrent donc pas la base locale : ils substituent les providers concernés. La
file de synchronisation aura ses propres tests d'intégration au module 6.

---

## 10. Décisions à arbitrer

Reprises du §19.2 du cahier des charges, dans l'ordre où elles bloquent le
développement mobile.

| Décision | Échéance | Impact sur le mobile |
|---|---|---|
| DO-5 — valeur juridique des constats, à valider par un conseil juridique local | Avant le module 5 | Fixe la rédaction des mentions d'engagement affichées au-dessus des signatures |
| DO-2 — fond cartographique : OpenStreetMap seul ou repli commercial | Avant le module 3 | Coût récurrent et qualité de la carte en province |
| DO-3 — modèle de commission et grille tarifaire | Avant le module 2 | Écrans d'estimation de prix et de gains |
| DO-1 — trajectoire réglementaire de MajiPay : passerelle ou établissement de monnaie électronique | Avant le module 7 | Détermine 4 des 26 modules MajiPay. En l'absence d'arbitrage, la trajectoire passerelle est retenue |
| DO-4 — recrutement du réseau de points relais | Avant le module 9 | Couverture hors Antananarivo |
| DO-6 — publication iOS en phase 1 ou 2 | Avant le module 10 | Coût du compte développeur et de la recette |

---

## Déploiement de l'API

L'API Laravel se déploie sur DirectAdmin. Construire l'archive avec
`server-php/build-deploy-zip.ps1`, qui produit `server-php/laravel-deploy.zip`
(voir §4), l'extraire dans `public_html/mobile-api/`, puis lancer
`php artisan migrate --force`. `/health` vérifie la vivacité de l'API.

---

## 11. Fonctionnalités disponibles

### Fonctionnalités communes

- Connexion par téléphone + mot de passe ou code OTP, et inscription par e-mail.
- Sessions sécurisées avec renouvellement de jeton, déconnexion et appareils
  connectés (date et heure).
- Profil, avatar, modification des informations, changement de mot de passe et
  suppression des sessions.
- Français et malgache, changement immédiat de langue, thème clair et sombre.
- Bandeau réseau, reprise automatique, file hors ligne et synchronisation.
- Notifications locales, appels, liens de suivi et partage du reçu.

### Client / expéditeur

- Carnet d'adresses, favoris, GPS et points relais.
- Création d'une course en plusieurs étapes : adresses, colis, photo, poids,
  dimensions, valeur, créneau et mode de paiement.
- Estimation détaillée, historique, suivi cartographique et chronologie des
  statuts.
- Messagerie avec le livreur, incidents, paiement, notation et litiges.

### Livreur

- Dossier KYC et suivi de validation, véhicule et plaque.
- Passage en ligne/hors ligne, courses disponibles et acceptation.
- Navigation, progression de course, partage de position et preuve de remise.
- Photos guidées, signatures, constats PDF, incidents, gains et évaluations.

### Exploitation / administration

- Tableau de bord, statistiques, utilisateurs et flotte.
- Validation ou refus KYC avec motif, modération et suspension de compte.
- Suivi des courses, litiges, messages KYC et décisions administratives.

---

## 12. Technologies utilisées

### Application mobile

- **Flutter 3.47 / Dart 3.12** : application Android et architecture UI.
- **Riverpod** : état, injection et synchronisation des providers.
- **GoRouter** : navigation et liens profonds.
- **Dio** : client HTTP, intercepteurs, reprise et idempotence.
- **Drift + SQLite WAL** : cache local et file de synchronisation hors ligne.
- **SharedPreferences** : préférences de langue et de thème.
- **flutter_secure_storage** : jetons et secrets dans le Keystore Android.
- **flutter_map + OpenStreetMap** : cartes et suivi.
- **geolocator** : position du livreur.
- **camera, image_picker, image** : capture et compression des images.
- **signature, pdf, printing** : signatures et constats PDF.
- **flutter_local_notifications** : notifications locales.
- **local_auth + crypto** : biométrie et protection PIN.
- **connectivity_plus** : état de connectivité.
- **mobile_scanner / qr_flutter** : scan et affichage de QR codes.

### Serveur et exploitation

- **Laravel/PHP** : API mobile actuellement déployée.
- **MySQL/MariaDB** : base partagée.
- **bcrypt et JWT** : compatibilité d'authentification.
- **DirectAdmin/Passenger** : hébergement de l'API Laravel.

---

## 13. Base de données

Les tables principales utilisées par l'API sont :

| Table | Usage |
|---|---|
| `accounts` | Comptes, rôles, profils, KYC et suspension |
| `avatars`, `media` | Avatars et photos envoyées |
| `saved_addresses` | Carnet d'adresses et favoris |
| `challenges` | Défis OTP e-mail/téléphone |
| `refresh_tokens` | Sessions et renouvellement des accès |
| `idempotency_records` | Protection contre les doublons réseau |
| `deliveries`, `delivery_events` | Courses et historique des statuts |
| `messages`, `kyc_messages` | Messagerie de course et échanges KYC |
| `driver_states`, `position_samples` | Disponibilité et positions |
| `driver_vehicles`, `kyc_documents` | Véhicules et pièces KYC |
| `payment_intents`, `majipay_sandbox_accounts`, `majipay_sandbox_txns` | Paiements |
| `reviews` | Notes et avis |
| `delivery_incidents` | Incidents de livraison |
| `disputes`, `dispute_messages` | Litiges et messages associés |
| `moderation_logs` | Journal des actions d'administration |

---

## 14. Comptes de test

En mode `mock`, ces comptes de démonstration sont disponibles. Ils se
connectent par numéro et mot de passe `majichrono` :

| Profil | Téléphone |
|---|---|
| Client — Hery Rakoto | `034 00 000 01` |
| Livreur — Naina Andria (KYC approuvé) | `033 00 000 02` |
| Exploitation — Miora Rasoa | `032 00 000 03` |

En mode `live`, créez les comptes depuis l'application (« Créer mon compte »).
Les comptes d'exploitation sont attribués côté serveur. Ils ne doivent jamais
être réutilisés en production.

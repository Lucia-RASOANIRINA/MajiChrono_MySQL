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
            --dart-define=API_BASE_URL=https://majichrono.majitech.mg/api/v1
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

## 4. Le backend FastAPI + MySQL

Le contrat d'interface est disponible sous `server/`. Le serveur FastAPI
implémente les routes d'authentification, livraisons, suivi, paiement, KYC,
litiges et administration. Cette variante utilise MySQL fourni par XAMPP :

```text
DATABASE_URL=mysql+pymysql://root:@127.0.0.1:3306/majichrono_mysql
```

Lancez MySQL depuis XAMPP, créez la base avec
`server/tools/setup_mysql_xampp.ps1`, puis démarrez l'API depuis `server/`.
Le schéma SQLAlchemy est créé automatiquement au démarrage. Les tests utilisent
SQLite en mémoire afin de rester rapides et isolés.

Cette copie est volontairement séparée du projet PostgreSQL d'origine :
`D:\MajiChrono_MySQL`.

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

Le serveur se déploie dans DirectAdmin via **Setup Python App**. Sélectionnez
Python 3.12, le dossier `server/` et le fichier de démarrage
`passenger_wsgi.py`, puis installez `requirements.txt`. Renseignez dans le
panneau `ENVIRONMENT=prod`, `JWT_SECRET`, les paramètres `DB_*` de MySQL/MariaDB
et les paramètres SMTP. `/health` vérifie la vivacité de l'API.

Pour un déploiement manuel : `cd server && python -m venv .venv && pip install -r requirements.txt && uvicorn app.main:app`.

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

- **Python 3.12 + FastAPI + Uvicorn** : API REST.
- **Pydantic Settings** : configuration par variables d'environnement.
- **SQLAlchemy + Alembic** : modèle de données et schéma SQL.
- **MySQL XAMPP** : base locale de cette variante.
- **PyMySQL + SQLAlchemy** : connexion et mapping relationnel.
- **bcrypt** : hachage compatible avec le site web PHP.
- **JWT** : jetons d'accès et de rafraîchissement.
- **DirectAdmin/Passenger** : hébergement de l'API.

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

Les comptes ci-dessous sont créés par `server/app/tools/seed_test_data.py`.
Ils utilisent des données fictives et ne doivent pas être utilisés en production.

| Profil | Téléphone | E-mail | Accès |
|---|---|---|---|
| Client — Rina Rakoto | `+261340000001` | `rina.client@example.mg` | OTP téléphone |
| Livreur — Tovo Livreur | `+261330000002` | `tovo.driver@example.mg` | OTP téléphone ; KYC approuvé |
| Client e-mail — Compte Test | `+261340000003` | `test.client@majichrono.mg` | Mot de passe : `MajiTest2026!` |

Pour créer ou actualiser les données :

```bash
cd server
.venv\Scripts\python -m app.tools.seed_test_data
```

Les comptes téléphone reçoivent un OTP via le fournisseur SMS configuré. En
production, `OTP_DEBUG_CODES=false` doit rester désactivé ; sans fournisseur
SMS, aucun code de test ne doit être affiché dans l'application.

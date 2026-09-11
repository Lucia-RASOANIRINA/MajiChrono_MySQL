# Illustrations de marque

Deposez ici les visuels fournis par le studio. Ils sont **references par nom** :
le code cherche exactement ces fichiers, et se rabat sur son dessin vectoriel
quand ils sont absents. Aucun n'est obligatoire pour compiler.

| Fichier attendu | Ou il apparait | Format |
|---|---|---|
| `splash.png` | Ecran de demarrage, sous le nom | PNG, fond transparent, 1024 px de large |
| `two_roads.png` | Bas de « Comment voulez-vous continuer ? » | PNG, fond transparent, 900 px de large |
| `pillar_speed.png` | Element « Rapidite » de l'accueil | PNG, fond transparent, 240 px |
| `pillar_sender.png` | Element « expediteur » | idem |
| `pillar_driver.png` | Element « livreur » | idem |
| `pillar_trust.png` | Element « Confiance MajiChrono » | idem |

## Deux regles, et elles ne sont pas negociables

**Ces fichiers partent dans l'APK et se retrouvent sur les telephones des
utilisateurs.** N'y deposez que des visuels dont MajiChrono detient les droits :
commandes a un illustrateur, produits par un outil generatif dont la licence
autorise l'usage commercial, ou achetes avec une licence explicite. Une image
trouvee dans un moteur de recherche n'entre pas dans ces cas, meme si elle
« ressemble » a ce qu'on veut.

**Le budget d'APK est de 25 Mo et il est deja depasse.** Chaque visuel doit etre
compresse avant d'etre depose — un PNG d'illustration non optimise pese
facilement 2 Mo, et six d'entre eux mettraient le budget hors d'atteinte.
Passez-les par `pngquant` ou equivalent, et visez moins de 150 Ko piece.

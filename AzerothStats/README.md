# Azeroth Stats 1.5.0-beta.1

Release **bêta** pour Azeroth Survivors Windows, interface 11200. Addon autonome, sans dépendance à un autre addon ni connexion externe.

## Bêta publique 1.5

Records de DPS moyen de partie observé (échantillons serveur après 10 secondes), son natif optionnel et suivi des coéquipiers observés dans Utilisation / Coop. Commandes : `/azstats sound` et `/azstats sound test`. Les victoires associées sont celles de vos parties avec présence observée ; ce ne sont pas des hauts faits partagés. Aucun auteur de coup fatal n’est inventé.

Cette bêta regroupe les records de DPS observé, le comparatif coop, les favoris par catégories et Némésis avec niveaux de preuve explicites. Les fonctionnalités ont fait l’objet de tests automatisés et de retours en jeu ; toutes les configurations et langues ne sont pas exhaustivement validées.

## Installation et mise à jour

1. Quitter normalement le jeu pour enregistrer les données de la session.
2. Si l’addon est déjà installé, conserver une copie de son fichier SavedVariables (`saved/AzerothStats.lua`, selon l’installation du client).
3. Extraire cette archive dans le dossier `AddOns` utilisé par le client. Le chemin final doit être `AddOns/AzerothStats/AzerothStats.toc`, sans double sous-dossier.
4. Pour une mise à jour, remplacer les fichiers du dossier AzerothStats ; conserver le fichier SavedVariables.
5. Relancer le jeu, activer l’addon si nécessaire et saisir `/azstats`. Vérifier la version **1.5.0-beta.1**.

## Fonctionnalités

- Tableau de bord global/par classe, historique, records et progression.
- Dégâts, soins, dégâts subis, dernier boss et journal officiel, par partie ou en cumul lorsque le compteur le permet.
- Sorts/rangs, équipement de collection et bijoux, descriptions natives et historiques.
- Utilisation des sorts et accessoires : fréquence par partie, rang maximal et changements observés ; variantes de bijoux regroupées.
- Barre compacte, bouton de minimap, filtres, pagination et réglages persistants.
- 14 langues : anglais, polonais, tchèque, allemand, portugais du Brésil, espagnol, français, roumain, turc, russe, ukrainien, chinois simplifié, japonais et coréen.

Le survol affiche les détails et valeurs complètes. Un record peut ouvrir sa partie si les détails sont conservés. Le menu de partie est disponible dans Combat, Personnage et Utilisation. Les réglages d’échelle et de taille du texte s’appliquent au relâchement.

## Commandes principales

- `/azstats` : ouvrir/fermer ; `/azstats show` et `/azstats hide`.
- `/azstats history`, `/azstats diagnose`, `/azstats help`.
- `/azstats bar`, `/azstats minimap`, `/azstats lock`, `/azstats resetpos`.
- `/azstats scale 0.9`, `/azstats opacity 1`, `/azstats lang auto` ou `/azstats lang fr`.
- `/azstats class all` ou `/azstats class rogue`, `/azstats retention 200`.

## Données et exactitude

Les données sont locales et enregistrées par le client lors de sa sauvegarde normale. L’addon ne lit pas les fichiers `.sav`, n’importe pas RSE1 et ne modifie aucun autre addon. Une donnée indisponible reste indisponible ; elle n’est pas transformée en zéro.

Le nombre exact de coffres est fourni par le bilan final. Le champ de progression du prochain coffre est un prix. Les fréquences d’utilisation décrivent les builds observés depuis la 1.3, pas des clics ni des lancements exacts. Les migrations corrigent les anciennes confusions de coffres et regroupent les variantes d’accessoires, en conservant les agrégats antérieurs pour audit.

Consulter `LIMITES-CONNUES.md` et `VALIDATION.md` pour le périmètre de la bêta. Pour un retour de bug : indiquer version de l’addon/client, classe, étape reproduite, compteur attendu/observé et sortie de `/azstats diagnose` ; joindre une capture si utile. Éviter de partager une sauvegarde personnelle complète sans l’avoir vérifiée.

## Comparatif coop (préversion 1.5.0-beta.1)

`/azstats coop` ouvre votre dernière partie avec les joueurs observés, dégâts, DPS et meilleur sort disponible. Le menu des parties permet de consulter l’historique. « Toutes les parties » affiche les coéquipiers ; cliquer sur un nom ouvre leurs parties conservées. Les totaux, parts et rangs exigent un relevé de groupe commun. Les anciennes données indépendantes restent partielles. Les soins et victimes des autres joueurs ne sont pas exposés.

## Favoris et Némésis (préversion 1.5.0-beta.1)

Cliquez sur le cœur d’une ligne pour enregistrer une partie, un sort, un accessoire, une pièce de collection ou un coéquipier. Le cœur en haut à droite protège la partie affichée ; `/azstats favorite` fait de même. `/azstats favorites` ouvre les raccourcis. Limites : 300 favoris, dont au plus 200 parties protégées, en plus du quota d’historique ordinaire. Les fiches d’objets restent consultables au survol ; si leur partie source a été purgée, le raccourci ne prétend pas rouvrir cette ancienne partie.

`/azstats nemesis` affiche les morts observées à partir de cette version. Un dernier attaquant reçu dans les deux secondes avant la mort est **probable**, pas confirmé. Seul un message natif explicite désignant le tueur permet la confirmation, si le client l’émet. Les messages non reconnus sont conservés sans inventer de nom ; un ancien coup ou une mort découverte au chargement ne crée pas d’attribution. Le compteur de victoires contre une créature précise n’est pas disponible.

Les favoris sont séparés dans six onglets : **Historique, Combat, Sorts, Équipement, Bijoux et Coop**. Le compteur de chaque onglet respecte le filtre de classe. Les anciens favoris sont classés automatiquement. Un nouveau favori de combat ouvert depuis une partie historique conserve cette partie et la protège ; un ancien raccourci enregistré comme global conserve sa portée globale. La limite de 200 parties protégées inclut les références des favoris de combat.

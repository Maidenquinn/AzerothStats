# Contrats des extensions fonctionnelles

Audit de référence : client SHA-256
8829953418a4d996cc5287f0e9fad25407ca30ceb64d105a4f57833caef78016,
API e34cf5bcd300de80686824c253778c7d9b2f8164e925e5febebee737f33326a9.
Ces champs ont été identifiés dans l'installation locale ; aucune nouvelle API
n'est créée pour justifier la maquette. Toute capacité reste optionnelle.

## Caractéristiques et équipement

Conserver les quinze caractéristiques actuelles et étendre avec echo, pick,
thn, liv, bp, dots, doth, big, exe, cc, dotd, shd, auto, pet. Contributions
déclarées par le client : ghp, gdmg, gcd, gcrit, gcm, garm, garea, gcnt, gecho,
gspd, greg, gpick, ggold. Les unités/formules seront centralisées dans un registre
unique et couvertes par tests : pas de conversions copiées dans plusieurs vues.
pick est une portée native (yd dans le code audité), gpick un bonus proportionnel.
Pas de causalité « cette carte a donné ce bonus » par simple différence.

## Contextes, affixes, comparaison et progression

AZS_ZONE.heroic est déjà exploité. AZS_ZONE.affixes est étayé par le sérialiseur
et le parseur générique ; format/IDs/fraîcheur à valider en Heroic III/V. Conserver
absence distincte d'une liste explicitement vide. Clés nouvelles affichées comme
non reconnues plutôt que traduites arbitrairement ou devinées à partir de la date.

Comparer classe, zone, difficulté, mode et nombre de joueurs **observé**, puis
affixes quand connus. Montrer les différences ; ne pas attribuer un gagnant global.
Les objectifs sont personnels, calculés sur un périmètre conservé visible, et
ne représentent pas l'état de déblocage officiel ni les hauts faits natifs.

## Courbes et rythme

Réutiliser timeline V1 (un point / 15 s, plafond 240) ; ajouter les compteurs de
combat dans l'extension V2. Pentes = moyennes d'intervalle. Réinitialisation de
compteur, trous, pause et reload cassent une série : pas de pic extrapolé ni de
ligne masquant une interruption. Or possédé ≠ gains bruts. Les anciennes valeurs
absentes ne sont pas reconstruites à partir d'un total final.

## Rencontres et annonces

AZS_SCHEDULE, AZS_UNITS, AZS_BOSSMETER et AZS_BANNERS. Lire des copies bornées,
éviter les helpers qui mutent les globals si les tables brutes suffisent. Ne pas
envoyer de message pour solliciter un relevé. Une disparition d'unité ne prouve
pas une mort. Les boss simultanés peuvent partager un compteur. L'historique
native de bannières ne conserve que vingt entrées ; échantillonnage/dédoublonnage
et débordement doivent être explicites. Stocker les événements d'une rencontre
seulement quand sa frontière et sa fraîcheur sont suffisantes, sinon partiel.

## Coop et soutien

Garder l'actuelle comparaison synchronisée AZS_PARTY. Ajouter AZS_REVIVE.down,
by/share/reviving/rshare pour les transitions locales. Une barre interrompue n'est
pas une réanimation réussie. Identifier prudemment une fin cohérente ; conserver
les tentatives comme observations distinctes. Ne pas prétendre aux soins/reçus/
équipement complets des alliés, absents du contrat natif vérifié.

## Familiers, invocations, totems et effets

AZS_PETS/GetSummons/GetSummonGroups : nature, présence et
maximum simultané observés. Pas de casts/dégâts exacts déduits d'une présence. Aucun champ dédié
AZS_TOTEMS/GetTotems n’a été confirmé dans le helper 0.121 local : le contrat
antérieur qui les citait était trop affirmatif. Les totems non présents dans
AZS_PETS restent indisponibles.
Les tables peuvent manquer avant leur premier paquet. AZS_BUFFS et AZS_DEBUFFS :
effets documentés et cumuls. Un uptime est échantillonné, pas exact ; le périmètre
des cibles et les périodes manquantes sont conservés.

## Endless, HUD et éléments non exposés

endl/won/continuation existent mais le sens précis de endl doit être confirmé.
Séparer victoire initiale et continuation sans double partie ou double victoire.
Dans le HUD, statistiques dérivées avec dénominateur clair ; zéro distinct du repli
« aucune valeur ». Aucun appel AZS_OpenStoredLevels, SetStoringLevels ou réglage de
difficulté : lecture/analyse, pas automatisation du jeu.

Marques/étoiles/set/unlocks structurés, détail causal de chaque carte et attribution
universelle du coup fatal restent indisponibles. Conserver les descriptions natives
capturées sans les transformer en compteurs structurés non prouvés. L'import RSE1
reste hors périmètre ; il n'est pas nécessaire à la compatibilité V1/V2.

## Écriture, limites et tests

Écritures communes via le ledger V1 ; enrichissements dans l'extension proposée.
Valeur, source, instant, portée, complétude et version du module accompagnent les
observations. V1 reçoit les mêmes métriques communes qu'aujourd'hui. Aucune
estimation ne devient une valeur officielle au retour en V1.

Tests requis pour chaque module : absence/paquet incomplet, extrêmes/NaN/types
invalides, ordre inversé, duplicata, nouveau run/reload, compteurs en baisse,
pause, résumé tardif, purge/reset, budget de rétention et roundtrip V1/V2.
UI : colonnes longues, textes traduits, écrans réduits, grands chiffres, thème
clair/sombre, navigation clavier, fermeture/réouverture de toutes les modales.

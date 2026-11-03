# Azeroth Stats V2 — étude produit et maquette navigable

Branche : `codex/v2-product-preview`. Base V1 conservée : commit `0a3b414`.
Ce dossier ne fait pas partie du paquet joueur. Aucun addon V2 n'est installé.

## Ouvrir la maquette

Ouvrir `prototype/index.html` dans un navigateur, même hors ligne. Aucune commande
de compilation ou dépendance web n'est nécessaire. Toutes les images et polices
sont locales. Pour la servir en local depuis la racine du dépôt :

```powershell
python -m http.server 8765 --bind 127.0.0.1 --directory design/v2/prototype
```

Puis ouvrir `http://127.0.0.1:8765`. Le serveur est limité à la boucle locale.
Le ZIP de maquette contient le même dossier autonome ; ce n'est pas un ZIP addon.

## Le changement de produit

La V2 succède à la V1. La V1 restera téléchargeable pour retour arrière, mais
deviendra dépréciée et ne sera plus soutenue après la transition. On ne construit
pas deux produits indépendants ou deux bases d'historique qui divergent.

**Contrat requis : V1 → V2 → V1 → V2 sans perte des données communes ni double
comptage.** Les parties commencées après passage en V2 doivent aussi rester
lisibles en V1 avec leurs compteurs/builds communs. Les détails exclusivement V2
ne sont pas affichés par V1. Voir `DATA-COMPATIBILITY.md` pour la stratégie et
les limites des premières sondes. Une restauration d'un ancien backup V1 n'est
pas un mécanisme de retour arrière acceptable : elle perdrait les nouvelles parties.

## Ce qui est interactif

- Navigation principale : Vue d'ensemble, Mes parties, Analyser une partie,
  Ma progression, Mes favoris et Némésis. Réglages et diagnostic à part.
- Historique : classe, difficulté, solo/coop, résultat, recherche et pagination.
- Bilan d'une partie : contexte, note privée de démonstration, favori, graphique
  changeable, accès aux vues Combat / Build / Rencontres / Coop.
- Comparaison de deux parties avec avertissement de contexte et courbes.
- Combat : dégâts/soins/reçus, part séparée du nom, provenance et effets observés.
- Build : sorts/rangs, 29 caractéristiques filtrables, contribution équipement,
  descriptions, journal de changements et scénario séparé d'invocations.
- Rencontre : panneau de détail avec bornes d'observation et limites de kill.
- Coop : relevé commun, détail joueur et soutien observé ; pas de chiffres
  inventés pour les soins/reçus/équipement des alliés.
- Endless : scénario de continuation sur la partie Voleur des Arènes du 29 octobre.
- Progression : records ciblés, classes, tendances regroupées et objectifs personnels.
- Favoris par catégories ; édition de lignes et confirmation de remise à zéro.
- Cinq thèmes : Chroniques, Warcraft, Atelier, Essentiel, Grimoire ; densité réglable.
- Barre en brouillon : 1–8 blocs, métriques/portées, ordre, largeur, hauteur,
  texte, icônes/libellés ; Apply/Cancel. Le chrono du jeu n'est pas dupliqué.
- Gestion des exemples : sélection d'une partie/catégorie, récap latéral,
  première étape sans suppression, confirmation explicite et restauration du scénario.
- Recherche globale avec `/`, fermeture avec Échap, focus contenu dans les modales.

Le français est la langue de cette étude. Les quatorze langues restent une
exigence du produit ; cette maquette ne prétend pas être une traduction complète.

## Nature et confidentialité des données

Tout est **fictif**, y compris noms de joueurs du scénario, chiffres, contextes,
bonus et événements. La maquette n'appelle aucune API du jeu, ne lit aucune
sauvegarde et n'expose aucun téléversement. Aucun réseau sortant n'est nécessaire ;
la CSP interdit les connexions de l'application. Aucun script, police ou image
ne vient d'un CDN.

Les préférences/notes/favoris de la maquette utilisent uniquement la clé navigateur
`azerothstats-v2-prototype-20261030`. Cela n'a aucun rapport avec AzerothStatsDB.
« Données & diagnostic → Restaurer les exemples » permet de reprendre le scénario.

Les événements de nouveaux modules sont des démonstrations d'UX, pas des captures
de terrain ni une preuve d'API complète. Affixes, réanimations, limites des
rencontres et sens de `endl` demandent une validation native avant activation.

## Design et faisabilité client

Le navigateur sert à valider les parcours et l'organisation avant le portage en
Lua 5.0 / interface 11200. Il ne démontre pas le rendu du moteur natif. On utilise
les polices, glyphes et textures déjà possédés par le projet afin de limiter
l'écart entre concept et implémentation. Le thème Warcraft n'embarque aucun asset
Blizzard : la future interface Lua devra référencer les textures installées.

Les thèmes changent les matériaux, contrastes et densités, pas le sens des actions
ni la source des statistiques. Graphiques, tableaux et panneaux auront des pools
bornés de frames/textures ; on n'introduira pas de dépendance web dans l'addon.
Chaque écran approuvé devra être vérifié en jeu avant de déclarer sa fidélité.

## Fichiers et contrôles

- `prototype/` : maquette autonome HTML/CSS/JS et assets existants convertis.
- `PRODUCT-SPEC.md` : architecture UX et couverture des fonctions.
- `DATA-COMPATIBILITY.md` : contrat d'aller-retour, format candidat et tests requis.
- `FEATURE-CONTRACTS.md` : preuves, mesures et limites des nouveaux modules.
- `tests/compatibility_probe.py` : sondes synthétiques sur du code V1 figé.
- `reports/` : résultats non personnels de validation.
- `previews/` : captures du navigateur ; aucune n'est une capture du client Lua.
- `build_assets.py` : conversion déterministe d'assets existants via Pillow.
  `prototype/assets/provenance.json` conserve leurs sources et empreintes.

Le dépôt de production, les releases, le dossier installé, le fichier .sav et
les addons tiers restent inchangés. Aucune publication ou approbation de la V2
n'est revendiquée.

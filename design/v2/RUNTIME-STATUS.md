# V2 native — premier incrément, 30 octobre 2026

Branche isolée : `codex/v2-runtime`, issue de la maquette validée et intégrant
le hotfix public 1.7.1-beta.1. Aucun paquet V2 n'est installé ni publié.

## Implémenté

- `V2Data.lua` : espace `extensions.azerothStatsV2`, versionné séparément du
  schéma commun 1. Les identifiants, migrations et écritures comptables V1 restent
  utilisés. Les nouveautés ne sont pas ajoutées aux maps numériques communes.
- 42 champs natifs autorisés : totaux/caractéristiques avancées et contributions
  équipement, sans conversion implicite des unités ni attribution à une carte.
- Capture uniquement après notification fraîche AZSSTATS pour une partie active
  retenue. Échantillonnage de 15 secondes serveur au minimum.
- Budget prudent : 32 parties enrichies, 32 points par partie et 100 000 nœuds
  dans l'extension. La saturation est signalée ; aucun compteur commun n'est effacé.
  Ces limites sont provisoires et devront être exposées dans le diagnostic V2.
- Réconciliation après chargement/purge et suppression : pas de recréation d'une
  partie effacée via V1. Reset complet efface notre extension, sans toucher aux
  autres espaces éventuels. Version future/invalide préservée, écriture V2 refusée.
- Contrôles de données finies, types, profondeur et budget global compatible V1.

## Validation

Suite V1 + thèmes + V2 : Lua 5.1 et Lua 5.0.3 natif réussis. Tests de zéro réel,
donnée périmée, champ absent/invalide, unités distinctes, répétitions, limite,
version future, suppression et reset. La politique statique ne détecte aucune
capacité interdite dans les 28 modules.

`tests/runtime_roundtrip.py` utilise le vrai nouveau module avec trois lecteurs
V1 gelés et des données synthétiques : V1 → extension V2 → V1 → V2, y compris
les nouvelles parties communes. Trois parties / 370 unités d'or, aucun doublon.
Voir `reports/runtime-roundtrip.json`. La sérialisation réelle du client reste
à tester ; cette suite ne prouve pas encore une migration en jeu.

## Prochain travail requis

1. Porter les composants et six parcours de la maquette au moteur Lua.
2. Brancher l'édition/masquage/restauration par vue, en conservant toutes les
   fonctions V1, puis afficher le build enrichi et les courbes.
3. Ajouter les collecteurs affixes, rencontres, soutien coop, invocations/effets
   uniquement après confirmation des contrats et de la fraîcheur native.
4. Diagnostic des limites, budget final, quatorze langues et recette en jeu.

La validation de maquette ne rend pas ces étapes déjà terminées.

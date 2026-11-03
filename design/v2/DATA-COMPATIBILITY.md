# Contrat de données : un aller-retour, pas deux historiques

## Décision produit confirmée par le mainteneur

V2 remplacera V1. V1 sera dépréciée, accessible en téléchargement pour retour
arrière et non soutenue. V2 reprend toutes les données communes V1 ; V1 doit
relire ces données et celles des nouvelles parties V2. Les nouvelles analyses
V2 sont ignorées par V1. Elles doivent également survivre à un aller-retour normal
si le format le permet ; jamais recréer ce que l'utilisateur a explicitement effacé.

## Stratégie candidate

Conserver le même addon installé `AzerothStats` et le même SavedVariable racine
`AzerothStatsDB`, avec le **schéma commun 1**. Ne pas faire une migration globale
irréversible vers `database.schema = 2`, que la V1 refuserait. Ne pas utiliser une
seconde DB pour les nouvelles parties : elle divergerait au premier retour V1.

Conserver exactement les contrats communs : identifiants `azstats-N`, sequence,
run.values, run.accounted, counted/winCounted, compteurs par source, classes,
totaux, couverture, favoris, masques de remise à zéro, descriptions historiques
et réglages V1. Le futur collecteur V2 doit réutiliser l'écriture commune V1 et
ses invariants avant de produire ses analyses supplémentaires.

Placer les nouveautés dans un espace séparé et versionné à l'intérieur de la
même donnée sérialisée :

```lua
AzerothStatsDB = {
  schema = 1, -- contrat commun conservé
  -- runs, sequence, totals, classes, settings, favorites... inchangés
  extensions = {
    azerothStatsV2 = {
      schema = 1, -- version de cette extension, distincte de la version produit
      runs = {
        ["azstats-42"] = {
          -- rencontres, affixes, observations de soutien, effets...
        },
      },
      preferences = {},
    },
  },
}
```

Ce schéma est une proposition **testée en faisabilité**, pas un module de
migration de production. Les validateurs V1 inspectés admettent des clés de
racine inconnues composées de données simples. En revanche, `values`, `accounted`
et `sum` contiennent des valeurs numériques : aucun objet/texte V2 dans ces maps.

Le client sauvegarde le global déclaré ; la V1 n'a pas besoin d'une nouvelle
ligne TOC ni d'une dépendance pour conserver une extension simple inconnue. Une
vérification de la sérialisation réellement effectuée par le client reste
obligatoire. Ne pas promettre que tous les anciens clients ou toutes les V1
historiques ont été couverts.

## Sondes déjà réalisées

`tests/compatibility_probe.py` charge le code figé des références
`v1.6.2-beta.1`, `v1.7.0-beta.1` et `0a3b414` (preview V1 1.8.0-dev.3).
Le code n'est ni modifié ni exécuté dans le jeu ; tous les inputs sont synthétiques.

Le test construit une partie commune V1, une seconde partie via le ledger commun
candidat, ajoute des données V2 dans `extensions`, fait relire la base par la V1,
ajoute une troisième partie après le retour, puis vérifie IDs, parties/victoires,
totaux, absence de double compte et conservation de l'extension. Une suppression
de run est aussi vérifiée : sa présence dans l'extension n'autorise pas sa
recréation dans l'historique. Voir le rapport pour les moteurs réellement passés.

La seconde sonde, optionnelle `--lua50`, effectue un cycle de sérialisation Lua
synthétique et relecture dans un processus natif Lua 5.0.3. Ce n'est **pas** le
sérialiseur du client et ce n'est pas un test d'un addon V2 complet inexistant.

## Contraintes de conception

- Aucun collecteur V1 et V2 simultané. Une mise à jour remplace les sources du
  même addon ; on ne fait pas tourner deux copieurs du même ledger.
- Nouvelle feature absente sur une partie V1 = indisponible. Pas de faux boss,
  affixe, carte ou réanimation reconstruits dans les parties historiques.
- Renommage et migration de l'extension idempotents, versionnés et bornés.
  Ne pas toucher les identifiants de run pour enrichir une partie existante.
- Préserver `recordResets`, `trendsReset`, `nemesisReset`, accounted et migrations.
  Aucun recalcul naïf à partir du seul historique retenu : des détails ont pu être purgés.
- Une purge V1 peut laisser un détail V2 orphelin. Au retour V2, réconcilier les IDs
  et appliquer la politique de rétention ; ne pas ressusciter le run ou ses favoris.
- Une réinitialisation explicite complète peut détruire toutes les extensions :
  c'est une suppression utilisateur annoncée, pas un retour arrière ordinaire.
- La V1 peut normaliser ses réglages. Garder les préférences exclusives V2 dans
  l'extension et garantir la lisibilité des réglages communs par les deux versions.
- Les plafonds V1 (profondeur 32, quatre millions de nœuds) restent applicables
  à toute la base. Proposer un budget V2 conservateur et une rétention adaptative,
  bien avant ces limites ; la validation V1 doit continuer à accepter le résultat.
- Aucun appel fichier/OS ajouté au runtime. Sauvegarde par SavedVariables ; copie
  de secours des fichiers faite par le joueur/outillage normal, jeu fermé.

## Critères bloquants avant la vraie V2

1. Tests croisés avec le vrai collecteur V2, puis les lecteurs V1 de retour pris
   en charge, à partir de bases synthétiques complètes (pas seulement trois runs).
2. Sauvegarde réelle par le client, fermeture complète, remplacement V2 → V1,
   nouvelle partie V1, fermeture, retour V2 et contrôle des données communes/enrichies.
3. Début/fin/résumé tardif, reload en partie, coop, pause, endless, compteur en baisse,
   données manquantes, favoris, tooltip, imports historiques déjà réparés.
4. Suppressions ciblées, reset par catégorie et full reset : aucune résurrection ni
   réaddition des records/compteurs. Purge automatique et favoris protégés.
5. Bases proches de la rétention maximum ; taille/temps de chargement ; extension
   inconnue ou invalide. Ne jamais écraser une base incompatible pour démarrer.
6. Procédure documentée de backup et retour à la V1 compatible ; release V1 figée
   disponible et statut de dépréciation affiché sans prétendre à son support futur.

La demande est « aucune perte au changement de version », dans les capacités de
sauvegarde normale du client. Elle ne permet pas de garantir la récupération d'un
fichier corrompu ou d'un crash avant écriture disque ; ne pas promettre cela.

# Validation de la maquette — 30 octobre 2026

## Périmètre

Étude produit sur `codex/v2-product-preview`, base V1 `0a3b414`.
Aucun module chargé par le TOC, outil de release ou fichier du client installé
n'a été modifié. La maquette ne constitue pas un addon V2 livrable.

## Contrôles exécutés

- `python tools/checks.py` : 27 modules de production, syntaxe Lua/upvalues,
  TOC, manifeste, notices de polices et **6 265 assertions réussies**.
- `node --check` sur les deux scripts de la maquette : réussi.
- `python design/v2/tests/check_prototype.py` : chemins statiques, provenance
  des 34 ressources, notices et interdiction de connexions externes : réussi.
- Sonde de compatibilité : lecteurs gelés `v1.6.2-beta.1`, `v1.7.0-beta.1`
  et `0a3b414`, sous Lua 5.1 et Lua 5.0.3 natif : réussi. Les trois parties
  synthétiques et les 370 unités d'or passent les allers-retours sans doublon.
  Voir `compatibility-probe.json` et les limites dans DATA-COMPATIBILITY.md.

## Recette navigateur réellement parcourue

- Historique et filtre coop, ouverture d'une partie conservée.
- Conservation du contexte Mage / Naxxramas / deux joueurs entre les onglets.
- Sorts Mage, équipement Mage, description puis fermeture du panneau.
- Caractéristiques : 29 entrées ; filtre avancé : 14 entrées.
- Coop : deux joueurs sur la partie historique ; trois sur la partie courante,
  soi-même et contribution explicitement identifiés.
- Endless : victoire initiale, continuation et un seul décompte de partie.
- Comparaison avec sélection de deux contextes et changement de métrique.
- Barre : changement d'une information dans le brouillon puis annulation ;
  la barre effective conserve ses informations précédentes.
- Cinq thèmes sélectionnés successivement avec état actif vérifié.
- Contrat V1 ↔ V2 visible et explicitement indiqué comme non livré.
- Gestion des exemples : aperçu de la partie, étape de vérification,
  avertissement favori et annulation sans supprimer.
- Aucune erreur ni alerte de console collectée pendant cette recette.

Les captures JPEG du navigateur sont dans `previews/`. La fenêtre de recette
mesurait 1440 × 1050 ; la surcharge de viewport a été retirée après les essais.

## Ce qui reste à valider avant la vraie V2

- Collecteurs et rendu Lua 5.0 / interface 11200 : non implémentés par la maquette.
- Sérialisation du client après une session V2 puis V1, sur copies de sauvegardes.
- Tests de données volumineuses, purge et reset, versions réelles de retour arrière.
- Affixes, bornes des rencontres, transitions de réanimation et sens de `endl`.
- Localisation des quatorze langues et accessibilité dans le moteur du jeu.
- Transposition fidèle des thèmes et dimensions aux textures du client.

Les exemples ne prouvent aucune statistique réelle ni API encore non validée.

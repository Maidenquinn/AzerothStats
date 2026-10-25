# 1.5.0-beta.1 — bêta publique

Nouveautés depuis la 1.4.0-beta.1 :

- Records globaux/par classe du meilleur DPS moyen de partie observé après 10 secondes serveur, avec alerte sonore optionnelle limitée à une par partie.
- Comparatif coop par partie : votre personnage et les coéquipiers observés, dégâts, DPS et meilleur sort ; classement et parts uniquement sur un relevé de groupe commun. Historique par coéquipier et sélection des anciennes parties.
- Favoris persistants avec cœurs et six catégories séparées : Historique, Combat, Sorts, Équipement, Bijoux et Coop. Les parties favorites et les sources des nouveaux favoris de combat historique sont protégées de la purge.
- Némésis : morts observées, derniers coups conservés et distinction confirmé/probable/inconnu. Un dernier attaquant seul ne prouve pas le coup fatal.
- Interface et diagnostics traduits dans les 14 langues ; conservation des données existantes, schéma SavedVariables 1.
- Nouvelles commandes : `/azstats coop`, `/azstats favorites`, `/azstats favorite`, `/azstats nemesis`, `/azstats sound [test]`.

Validation : 3 048 assertions sous Lua 5.0.3 et Lua 5.1, 2 663 assertions indépendantes hors ligne, 27 cas multiclasse dans 81 processus Lua neufs (1 467 assertions), et contrôle du ZIP réellement distribué. Les essais en jeu ont confirmé les favoris, la présentation et une attribution Némésis probable ; ils ne garantissent pas toutes les configurations multijoueurs ni l’émission d’une preuve fatale explicite.

# 1.5.0-dev.3 — catégories de favoris et cœurs

- Six catégories séparées avec compteurs et sélection persistante : Historique, Combat, Sorts, Équipement, Bijoux et Coop.
- Les anciens favoris sont classés sans modifier leurs identifiants ni perdre leurs descriptions.
- Cœurs originaux en TGA RGBA : contour doré pour ajouter, rouge rempli pour retirer ; même icône dans la navigation.
- Les nouveaux favoris de combat conservent leur partie et leur mode ; leurs parties sources sont protégées de la purge. Les anciens raccourcis globaux restent globaux, sans reconstitution inventée.
- États vides, traductions, pagination et tests de compatibilité renforcés.

# 1.5.0-dev.2 — favoris et preuves de mort

- Page Favoris, étoiles sur les parties/sorts/équipements/accessoires/coéquipiers et accès rapide aux vues correspondantes.
- Protection des parties favorites contre la purge, stockage borné et persistance sans réécrire les sauvegardes externes.
- Page Némésis : morts observées, derniers coups, compteurs par classe et globaux ; tueur confirmé uniquement sur message explicite, dernier attaquant récent marqué probable.
- Formats natifs localisés, protection contre doublons, vieux coups, morts au chargement et attribution aux mauvaises parties.
- 13 libellés supplémentaires dans les 14 langues et glyphes CJK ; navigation adaptée à 11 pages.

# 1.5.0-dev.1 — comparatif coop

- Tableau par partie incluant votre personnage et vos coéquipiers : dégâts, DPS et meilleur sort reçu.
- Classement et parts de dégâts à partir d’un relevé de groupe commun, conservé après la sortie du groupe.
- Accès direct `/azstats coop`, sélection des anciennes parties et historique par coéquipier.
- Anciennes observations affichées avec leur provenance ; aucun total ou classement fabriqué à partir de relevés indépendants.
- Nouveaux libellés traduits dans les 14 langues ; tests des paquets incomplets, doublons et relevés tardifs.

# 1.5.0-dev — en préparation

- Pic observé de DPS moyen de partie, après 10 secondes serveur ; records globaux et par classe, sans addition des taux.
- Alerte sonore native désactivable, au plus une fois par partie contre un ancien record ; premier repère silencieux et protection au rechargement.
- Utilisation / Coop : coéquipiers réellement observés, fréquence par partie et par classe, résultats associés avec libellés explicites.
- Garde-fous contre anciens paquets, compteurs en baisse, doublons et confusion entre présence observée et hauts faits partagés.
- Diagnostic explicite des limites Nemesis/auteur du coup fatal et hauts faits partagés.
- 12 nouveaux libellés dans les 14 langues et glyphes CJK complémentaires.

# 1.4.0-beta.1 — première release bêta

Fonctionnalités : tableaux de bord, historique, combat, équipement, records, réglages et suivi d’utilisation dans 14 langues.

Correctifs inclus : prix des coffres séparé des ouvertures officielles ; variantes d’accessoires regroupées par partie ; anciennes fiches de collection enrichies avec une référence native et des sources de butin ; réglage d’échelle au relâchement ; zones tardives sans fausses nouvelles parties.

Préparation : recette de release multiclasse, restaurations dans des processus neufs, archive épurée et manifeste SHA-256. Le schéma SavedVariables reste 1. Les migrations sont exécutées par l’addon au chargement normal.

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

# Validation de la release

Les validations ci-dessous sont automatisées hors jeu avec le script API Lua réellement embarqué dans le client testé. Les widgets et événements de jeu sont simulés.

- Suite principale : **2 383 assertions**, sous Lua 5.0.3 natif et Lua 5.1. Syntaxe, TOC, neuf pages, traductions, migrations, compteurs et scénarios de suivi.
- Matrice de release : **27 scénarios**, neuf classes × trois types de fin (défaite, abandon, victoire avec continuation). **1 359 assertions** dans **81 processus Lua 5.0.3 neufs**.
- Chaque scénario part d’une base vierge, sérialise un état en cours de partie, recharge les données dans un deuxième processus, finalise la partie puis les restaure dans un troisième processus. Les cumuls, registres, fréquences, descriptions, réglages et absence de doublons sont contrôlés.
- Une copie de base existante est contrôlée séparément pour les migrations et la stabilité après parcours des pages/langues ; aucun fichier utilisateur n’est inclus dans ce paquet.
- Les tables de glyphes des polices sont contrôlées ; cela ne remplace pas leur rendu dans le client.
- L’archive finale est extraite et soumise à la même matrice pour vérifier l’installation propre du contenu livré. Le manifeste SHA-256 décrit les fichiers de ce dossier.

L’utilisateur a confirmé en jeu le fonctionnement des correctifs de collection et de regroupement de bijoux de la 1.4. Aucune nouvelle partie réelle ni fermeture/relance native n’a été effectuée par l’agent durant cette préparation. Les tests simulés ne sont pas présentés comme des parties jouées.

## Recette de bêta en jeu

1. Après installation, ouvrir `/azstats`, vérifier version, langue et accès aux neuf pages.
2. Commencer une partie et vérifier classe/carte, durée, kills, or et compteurs disponibles.
3. Choisir une amélioration de sort, obtenir/améliorer un bijou et vérifier les changements observés sans nouvelle partie artificielle.
4. Survoler les objets actuels puis ceux d’une ancienne partie ; distinguer description enregistrée et référence actuelle de collection.
5. Terminer la partie, comparer le bilan officiel et les coffres, rester sur l’écran de fin et vérifier l’absence de doublons.
6. Quitter normalement, relancer et vérifier historique, cumuls, descriptions, fréquences et réglages.
7. Refaire avec une autre classe, un abandon et, si possible, une victoire suivie d’une continuation. Signaler tout écart reproductible avec `/azstats diagnose`.

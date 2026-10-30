# V2 — conserver la profondeur, simplifier le parcours

## Audit de la V1 utilisée comme base

Base : 27 modules Lua, interface 11200, Lua 5.0, DB schéma 1. La V1 dispose déjà
des agrégats globaux/classes, détails de parties, filtres, compteur de combat,
dernier boss, builds/rangs, équipement et tooltips, journal observé, records,
tendances, coop, Némésis, favoris par catégorie, édition ciblée, gestion locale,
barre configurable, minimap, diagnostics et localisation en 14 langues.

Le principal problème produit est la dispersion : historique/report/compare ont
plusieurs sélecteurs ; build et combat se retrouvent dans différents contextes ;
plusieurs concepts numériques (totaux, historique retenu, relevé, record) se
ressemblent. Une page chargée ne devrait pas obliger le joueur à comprendre le
pipeline de données pour choisir sa partie ou découvrir ce qu'il peut effacer.

## Les six entrées principales

1. **Vue d'ensemble** : partie en cours, quatre chiffres essentiels avec portée,
   dernières parties, progression et raccourcis vers le détail.
2. **Mes parties** : une seule liste, recherche, filtres, accès au bilan et à
   Comparer. Le contexte d'une partie reste fixé dans toutes ses sous-vues.
3. **Analyser une partie** : accès direct au même espace d'analyse pour la partie
   choisie, sans devoir passer par la liste. Bilan, Combat, Build, Rencontres, Coop ;
   Endless uniquement si une continuation a été documentée.
4. **Ma progression** : Records, Par classe, Tendances et Objectifs personnels.
5. **Mes favoris** : catégories clairement séparées, retour direct au bon contexte.
6. **Némésis** : distinction confirmé/probable/inconnu, derniers impacts, édition ciblée.

Réglages et Données/diagnostic restent dans le pied de navigation ; ils ne sont
pas au même niveau visuel que les usages quotidiens. Ma barre est accessible aussi
par son engrenage. La minimap et les commandes habituelles seront préservées.

## Aucune fonction V1 retirée

- Vue globale/classes : accueil, filtre de portée, Ma progression/Par classe.
- Historique : Mes parties. Report/compare : bilan et action Comparer.
- Dégâts/soins/reçus/dernier boss : Combat et Rencontres, avec périmètre indiqué.
- Sorts/rangs, stuff, attributs, progression, journal : Build et courbes du bilan.
- Records/sources/mises à zéro : Ma progression/Records, action Modifier.
- Tendances sorts/bijoux/compagnons : Ma progression/Tendances ; bijoux groupés.
- Coop et snapshots communs : sous-vue Coop du même run, badge dans l'historique.
- Némésis : entrée dédiée. Pas d'inférence fatale ajoutée.
- Favoris triés : Mes favoris et cœurs contextuels. Protection de la purge automatique.
- Édition/visibilité par ligne : Modifier cette vue et restauration visible.
- Gestion des données : Personnaliser/Données ; résumé des éléments et conséquences.
- Barre, minimap, commandes, verrous, opacité, échelle, texte, sons, rétention :
  même périmètre cible. La maquette simule les thèmes/densité et le brouillon de
  barre, mais ne connecte pas tous les réglages du client.
- Diagnostique et provenance : entrées compréhensibles et détails techniques à part.
- Cinq thèmes et 14 langues : conservés dans la cible ; maquette française uniquement.

## Hiérarchie et comportements

- Le haut de page dit toujours ce qui est analysé : classe/période ou partie précise.
- Un seul sélecteur de partie pour le bilan et ses vues. Ne pas sélectionner une
  partie historique et afficher ensuite les alliés de la partie actuelle.
- Coop visible dans la liste, le bandeau de partie et son bilan. Nombre **observé**,
  pas taille supposée constante du groupe.
- Totaux lifetime et historique retenu ont des périmètres distincts et explicites.
- Colonnes séparées pour nom, contribution, total et action ; détails dans un panneau.
- Les tooltips item sont historiques. Le catalogue peut aider, mais ne remplace
  pas un tooltip exact d'un équipement à étoiles différent.
- Les métriques nouvelles n'envahissent pas l'accueil : filtres de caractéristiques,
  sous-vues d'analyse et blocs de barre optionnels.
- Appliquer principal, Annuler secondaire, suppression explicitement nommée.
  Le premier clic de gestion ne supprime rien. Réinitialiser un record n'efface
  pas toutes ses parties. Masquer une source ne change pas les dégâts totaux.
- Une modale est au premier plan, garde son focus, se ferme par Échap et restaure
  la sélection. Ma barre est un brouillon indépendant, pas un réglage caché derrière
  la fenêtre principale.
- Des états vides orientent : pas de coop en solo, pas de résultat de filtre,
  catégorie de favoris vide. Une donnée absente n'est pas dessinée comme zéro.

## Direction artistique commune

Chroniques constitue la signature principale : ardoise bleutée, bronze discret,
titres serif, chiffres lisibles et images de zones. Warcraft utilise l'habillage
natif dans le futur client, Atelier une structure plus architecturale, Essentiel
une densité sobre et Grimoire du papier/une encre lisible. Les rôles des couleurs,
icônes, actions et badges restent stables entre thèmes.

La maquette utilise une fenêtre et un contenu qui défile, comme un addon de bureau,
plutôt qu'une longue page marketing. Une adaptation étroite permet la revue dans
le panneau Codex ; cela ne signifie pas qu'un addon mobile est prévu.

## Livraison par étapes

1. Valider ce parcours et le vocabulaire avec la maquette réelle, pas seulement une image.
2. Établir le socle de compatibilité et les tests aller-retour bloquants.
3. Porter la bibliothèque de composants en Lua, vérifier un écran natif pour chaque thème.
4. Rebrancher toutes les fonctions V1 sans changer leur ledger ou leur provenance.
5. Ajouter caractéristiques/contextes/affixes/courbes, puis rencontres/coop/effets.
6. Localiser et tester les cas limites, performance/rétention, puis beta V2 séparée.
7. Publication V2 et dépréciation V1 après validation, avec procédure de retour compatible.

L'accord sur une maquette n'est pas l'accord de publication d'une migration non testée.

# V2 native — candidat 2.0.0-dev.11, 31 octobre 2026

Branche isolée : `codex/v2-runtime`. La V1 publique 1.7.1-beta.1 reste inchangée. Le candidat dev.3
n'a pas été installé : l'installation locale précédente reste en place. Ce candidat n'est pas une release stable.

## Implémentation

- Six parcours : Vue d'ensemble, Mes parties, Analyser, Ma progression, Favoris,
  Némésis ; Réglages et Diagnostic restent accessibles. Les anciennes vues
  Classes, Personnage et Tendances restent accessibles dans ces parcours.
- `V2Data` garde le schéma commun 1 et tous les compteurs/IDs/ledgers V1.
  `extensions.azerothStatsV2.schema=1` contient uniquement les enrichissements.
  Une version future ou une structure invalide est conservée et refusée en écriture.
- 42 champs autorisés ; 29 caractéristiques avec contributions équipement séparées.
  Unités vérifiées contre les formules natives : points de vie, multiplicateurs,
  pourcentages et portée restent distincts. Notification fraîche **AZS**, pas AZSSTATS.
- Courbes en points mesurés : timeline V1 et nouveaux compteurs de combat,
  axe commun de temps écoulé et contexte de comparaison. Aucun point absent
  reconstruit depuis le total final ; aucune interpolation dessinée.
- Affixes : chaîne brute AZSZONE fraîche correspondant à la classe/zone.
  Absence distincte d'une liste explicitement vide. Format réel Heroic III/V
  encore à confirmer ; aucune signification des IDs n'est devinée.
- Rencontres : apparitions/disparitions observées par ID natif, sans faux kill.
  Relevés du compteur boss partagé consultables par source ; aucune attribution
  arbitraire d'un compteur commun à un boss particulier.
- Soutien coop : état local à terre/retour, tentatives entrantes/sortantes et
  arrêts observés. Aucun arrêt de tentative présenté comme une réussite.
  Les comparaisons natives de dégâts V1 restent disponibles.
- Familiers/effets facultatifs, désactivés par défaut : présence/maxima
  échantillonnés ; ni casts ni uptime exact. Pas d'API dédiée aux totems inventée.
- Notes locales et objectifs personnels classe/zone/difficulté calculés sur les
  victoires conservées, sans prétendre aux déblocages officiels.
- Masquage/restauration par contexte/langue ; confirmation existante pour supprimer
  une observation terminée ou un objectif. Les chiffres communs dérivés se masquent ;
  ils ne sont pas falsifiés pour effacer une ligne.

## Limites et persistance

32 parties enrichies ; 32 points de caractéristiques, 120 points de combat,
16 rencontres, 12 relevés boss (8 sources), 40 événements de soutien et 24 types
par catégorie de présence par partie. Budget d'extension : 240 000 nœuds.
Caractéristiques/progression espacées de 15 secondes serveur au minimum.

À saturation, les plus anciennes observations d'une partie terminée non protégée
expirent. **La partie V1, ses compteurs et sa note restent conservés.** Les références
favorites protègent aussi les observations ; si les 32 places sont protégées,
la limite est diagnostiquée sans suppression. Notes : 500 octets UTF-8 par partie
retenue ; 12 objectifs. Aucune purge ne recrée une partie effacée via V1.

## Validation disponible

Lua 5.1 et Lua 5.0.3 natif, politique statique, manifestes, catalogues, cinq thèmes
et données invalides. Aller-retour avec les vrais modules V2, sérialisation Lua
synthétique et lecteurs V1 gelés : 1.6.2, 1.7.0, 1.7.1 beta. Notes, objectifs,
observations et nouvelles parties communes survivent sans double comptage.
Voir `reports/runtime-roundtrip.json` et `docs/V2-ACCEPTANCE.md`.

## Conditions avant le mot « stable »

1. Installation jeu fermé, rendu/interaction des six parcours, cinq thèmes,
   modales, grandes polices et écrans réduits dans le vrai client.
2. Partie solo/coop, fin officielle, reprise normale, Heroic III/V et paquets natifs.
3. Aller-retour V2 → V1 → V2 avec SavedVariables réellement écrites par le client,
   sur profil de test sauvegardé, sans toucher aux fichiers `.sav`.
4. Correction des régressions constatées puis validation du candidat final.

Les widgets simulés et la maquette ne remplacent pas ces étapes natives.

## Relecture des 15 captures natives du 31 octobre

Les captures du candidat précédent ont révélé des chevauchements réels :
Attributs et courbes entraient dans le bandeau de partie. La dev.3 réserve une
zone commune au bandeau, aux onglets et au contenu. L'historique utilise un résumé
compact ; les sections de progression deviennent des onglets visibles. Les
caractéristiques séparent le total observé et la contribution de l'équipement.
La navigation d'analyse et les compteurs de catégories favorites sont simplifiés.

Vérifications hors jeu : 6 984 assertions Lua 5.1, tests Lua 5.0.3, politique
statique et catalogues. Le rendu initial, les données historiques V1 et un tracé
natif avaient été observés sur dev.2 ; cela ne valide pas visuellement dev.3.
Aucune prise de contrôle ni installation effectuée pendant cette relecture.

Écarts encore ouverts : finition du bilan et des réglages, qualité des icônes
historiques lorsque le client a fourni un substitut, recette réelle des paquets
et de la persistance. Le texte natif « Bougez pour commencer » reste indépendant
de l'addon ; aucun masquage global du jeu n'est ajouté.

## Seconde relecture — candidat dev.4

19 nouvelles captures confirment les écarts de composition. Deux modules de
présentation (`V2Summary`, `V2SummaryUI`) composent maintenant les écrans :

- Accueil : contexte actif/préparation distinct de l'historique, compteurs globaux
  ou par classe, trois parties compactes, courbe mesurée d'une partie identifiée,
  faits observés et prochain objectif personnel incomplet.
- Bilan : quatre indicateurs, courbe, changements récents du journal observé,
  contexte/difficulté/affixes disponibles, aperçu de note et bouton de saisie.
- Sélection explicite par le bouton ou par le bandeau de zone cliquable.
- Filtres d'historique regroupés, actions Objectifs séparées, favoris sur deux rangées.
- Champ de note avec focus explicite et plaque décorative située en dessous.

Les courbes cumulées sont celles de la partie nommée, jamais une histoire
reconstruite à partir des totaux globaux. Une préparation n'est ni enregistrée
ni comptée ; elle n'a aucun bilan avant que le suivi commence. Les faits
marquants sont des changements observés, pas des cartes attribuées par déduction.
Les blocs ajoutés se masquent/restaurent dans le mode édition existant.

La vérification native de la dev.4 reste à faire. L'installation locale n'a pas
été modifiée et aucun contrôle du PC n'a été repris.

## Troisième relecture — dev.5

Les trois captures de dev.4 montrent des résultats absents des lignes compactes,
un graphe en carrés isolés et un menu de parties dont les métadonnées débordent.
La dev.5 rétablit un résultat coloré séparé de la durée, relie les observations
par des guides en paliers et remplace ce menu par six lignes illustrées avec
recherche locale littérale, pagination et sélection par ID conservé.

Les paliers sont une aide visuelle entre relevés, pas une mesure continue : aucun
point n'est créé et aucun trou déclaré n'est relié. Temps minimal de l'axe : deux
minutes ; axe de valeurs arrondi. Pools bornés : 240 marqueurs et 714 textures de
guidage au maximum pour deux séries de 120 points affichés. Les points écartés
pour affichage sont inspectés pour conserver une rupture si un trou est présent.
Le choix de partie ne touche ni aux données observées ni aux compteurs globaux.
La nouvelle révision n'a pas été installée ou contrôlée dans le jeu.

## Retour captures du 31 octobre — dev.6

32 captures examinées. Les écarts fonctionnels corrigés sont l'absence d'objectif
libre, l'objectif créé pour une ancienne classe sélectionnée, la superposition du
filtre d'attributs avec Comparer, et le statut actif conservé après redémarrage en
préparation. Le contexte de préparation passe avant une observation active.
Une ancienne zone inconnue n'est pas réécrite sans preuve historique.

Objectifs : nom libre, cible numérique, huit métriques, périmètres toutes classes /
toutes zones / toutes difficultés ou ciblés. Maximum douze. Les niveaux suivent
le meilleur niveau ; les autres données connues des parties terminées conservées
s'additionnent. Valeurs absentes exclues, couverture consultable.

Némésis : 201 portraits natifs statiques, 2449 alias exacts, un nom ambigu exclu.
Le catalogue d'apparences provient de l'audit local du 22 octobre, avec alias
présents dans le client installé lors de cette préparation. Les nouveaux ennemis
absents du catalogue gardent une icône neutre. Les rendus ne prouvent pas
l'identité du dernier attaquant : la confiance probable/confirmée reste séparée.

Aucun contrôle du PC, aucune fermeture du jeu et aucun changement de sauvegarde
joueur dans cette itération. Candidat préparé sur fichiers ; la recette visuelle
native de dev.6 reste à effectuer. La maquette est une référence de parcours,
pas une preuve de conformité parfaite des widgets natifs.

Vérification dev.6 : 7 325 assertions Lua 5.1, exécution de la même recette sous
Lua 5.0.3, 16 tests Python, polices dans les quatorze langues, catalogues
reproductibles et politique runtime sans capacité interdite détectée. Aller-retour
synthétique V2/V1/V2 vérifié avec les lecteurs figés 1.6.2, 1.7.0 et 1.7.1,
y compris les objectifs personnalisés. La série Lua 5.0 a une assertion de moins
car un test natif dispose de branches selon le runtime. Ce n'est pas une recette
native des SavedVariables. Archive : 293 fichiers vérifiés (manifest inclus).

## Correctif des listes d'objectifs — dev.7

Le retour natif du mainteneur valide les portraits Némésis et le contexte de
préparation de dev.6, mais révèle que les quatre listes d'objectifs étaient sous
la modale. Cause : ShowMenu ne reconnaissait pas l'éditeur V2 comme propriétaire.
Le test de régression reproduit ce défaut avant correction. Les options réutilisées
reçoivent également un niveau explicite au-dessus du menu, sans dépendre de la
propagation native des niveaux du parent. Les callbacks OnClick des quatre
sélecteurs, la sauvegarde de leurs valeurs, Annuler et le retour aux menus de la
fenêtre principale sont vérifiés hors jeu. Confirmation visuelle native dev.7
encore nécessaire ; aucun contrôle du PC pris pendant cette correction.

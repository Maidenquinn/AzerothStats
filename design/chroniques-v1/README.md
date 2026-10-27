# Chroniques d’Azeroth — proposition de direction artistique V1

Statut : **direction validée**, implémentation native en développement dans `1.6.0-dev.6` (voir [CHRONIQUES.md](../../docs/CHRONIQUES.md)). La planche est une référence artistique ; les nombres, dates, paysages et états sont illustratifs. Ce n’est pas une capture du client. Le rendu réel reste à valider en jeu.


## Intention

Une famille visuelle commune aux addons de Maidenhead : l’allure d’un instrument d’aventurier, forgé et entretenu. Ardoise sombre, bronze patiné, gravure discrète, textes ivoire. L’inspiration est celle des interfaces fantasy WoW modernes ; le sceau et les ornements proposés sont originaux et ne prétendent pas être des ressources officielles Blizzard.

La qualité vient de la hiérarchie, des espacements et des états cohérents. Les dorures restent secondaires à la lecture. Les interfaces ont des fonds opaques par défaut, avec opacité réglable. Éviter les boutons tous identiques, les listes sans contexte, les bordures criardes et les grands aplats noirs sans structure.

## Ce que montre la planche

- Une vue d’ensemble avec quatre indicateurs principaux, les dernières parties et une synthèse des records.
- Une navigation regroupée par usage, avec un état sélectionné visible par le fond, le texte et un repère latéral.
- Un configurateur de barre et un aperçu, sans chronomètre de partie par défaut.
- Trois préréglages : Discrète, Ma classe et Mon parcours.

## Signature réutilisable

Le sceau de boussole, les angles métalliques, les espacements, la typographie et les états des contrôles constituent la famille commune. Chaque addon conserve son nom et un petit symbole métier ; les palettes de base et les composants ne changent pas arbitrairement entre Stats et FieldKit.

Utiliser la sérif pour le nom du produit et les titres courts. Utiliser une sans-sérif pour la navigation, les listes, les formulaires et les nombres. Réutiliser les polices locales existantes avec leurs licences et leurs variantes CJK. Pas de téléchargement de police.

La palette et les dimensions initiales sont dans `tokens.json`. Elles sont des valeurs de conception, pas encore des paramètres Lua chargés par le TOC.

## Hiérarchie et navigation

Les usages fréquents restent directement accessibles : Vue d’ensemble, Historique, Combat, Personnage. Statistiques accueille les données globales/par classe et les usages observés, sans supprimer les écrans existants. Records et Némésis forment la progression. Favoris reste une destination explicite, avec ses catégories conservées. Réglages et Diagnostic sont des utilitaires visuellement secondaires.

La nouvelle navigation ne doit pas perdre les filtres ni le contexte de partie sélectionné. Un détail historique affiche toujours la classe, la carte, la date et le résultat. Une vue cumulative indique sa portée. Les descriptions importantes restent au survol, mais les valeurs indisponibles ou partielles restent repérables sans survol.

## Composants

- **Fenêtre** : objectif initial 1120 × 740 unités UI, marges de 24, grille de 8. Tester l’échelle et les écrans réduits avant de fixer une taille minimale.
- **Navigation** : hauteur cible 42–46, zone de clic entière, icônes cohérentes. Un choix actif ne dépend jamais de la couleur seule.
- **Listes** : colonnes fixes pour les valeurs, place réservée aux actions, nom et métadonnées séparés verticalement. Cœurs indépendants de la zone qui ouvre le détail.
- **Statistiques** : chiffres mis en avant, unités explicites, précision appropriée ; pas de petites répétitions de « depuis l’installation » sous chaque carte. La provenance et la couverture restent accessibles.
- **Menus** : vrai chevron à droite, zone de clic confortable, libellés longs gérés ; jamais la lettre « v » ajoutée au nom de la classe.
- **Formulaires** : aperçu immédiat, boutons Appliquer/Annuler, réinitialisation du seul groupe de réglages concerné. Ne jamais effacer les statistiques via une remise à zéro visuelle.
- **Accessibilité** : viser un contraste texte normal d’au moins 4,5:1 ; taille normale 13–14, détails au moins 11 aux dimensions de référence. Ne pas réduire automatiquement les traductions jusqu’à les rendre illisibles. Survol, sélection, désactivation et données manquantes ont chacun un état dédié.

## Barre de statistiques configurable

Chaque bloc possède une **mesure**, une **portée**, une position et un mode d’affichage. La portée se configure par bloc : partie actuelle, classe actuelle, classe fixée ou toutes les classes. « Classe actuelle » suit le personnage ; une classe fixée reste explicitement nommée.

Mesures envisagées à partir des données existantes : parties suivies, victoires, temps de jeu observé, victimes, or, dégâts, soins effectifs, dégâts subis, boss, élites, gardiens, coffres, aimants, niveau record et record du DPS moyen de partie observé. Toutes les combinaisons mesure/portée ne sont pas valides : désactiver celles qui n’ont pas de sens plutôt que produire un faux total.

Le temps total est la somme des durées observées depuis l’installation, pas une connaissance rétroactive de tout le temps joué. Les niveaux et records de DPS sont des maxima, jamais des sommes. Les coffres ne sont exacts qu’avec le résumé officiel ; le prix du coffre n’est jamais une mesure de coffres ouverts. Les valeurs absentes restent indisponibles, pas zéro.

Le rapport victoires/parties suivies inclut potentiellement une partie en cours : le libeller précisément. Un véritable taux sur parties terminées exige un dénominateur vérifié, sans le reconstituer à partir d’un historique purgé.

Réglages : ajouter/retirer des blocs, ordre par poignées et boutons monter/descendre, largeur, hauteur, taille du texte, icônes, libellés, précision des nombres, espacement, opacité et verrouillage de position. Prévoir des préréglages et un retour aux valeurs par défaut. Le chronomètre natif du jeu reste intact ; le bloc temps de partie de notre barre est optionnel et désactivé par défaut.

Objectifs de dimensions : largeur manuelle environ 240–1600 et hauteur 28–96, toujours bornées par l’écran et le contenu. Une hauteur plus grande peut afficher deux lignes ou davantage de contexte. Ne pas écraser les nombres pour faire rentrer trop de blocs : indiquer le débordement, permettre le retour automatique à la largeur utile ou proposer une seconde ligne.

Interaction : clic sur un bloc → vue correspondante avec la bonne portée ; survol → nom complet, valeur précise, classe et couverture ; action dédiée → personnalisation. Quand le déplacement est verrouillé, les blocs restent cliquables. Prévoir un moyen explicite de déverrouiller ou réinitialiser une barre hors écran.

Préréglages proposés :

- **Discrète** : parties + victoires globales, faible largeur, sceau miniature facultatif.
- **Ma classe** : parties + victoires + temps observé + victimes de la classe actuelle.
- **Mon parcours** : compteurs globaux plus riches, largeur supérieure et éventuellement deux lignes.

## Précisions à respecter lors de l’intégration

La planche est une exploration artistique. Le gros sceau de présentation doit devenir optionnel et plus petit dans un HUD compact. Les blocs à portées différentes doivent porter un indice de portée lisible ; un sélecteur global « Toutes les classes » ne doit pas masquer des portées mixtes. L’aperçu reflète exactement le brouillon de réglages. L’onglet Apparence doit réellement contrôler son panneau, plutôt que mélanger arbitrairement des contenus d’onglets.

Les miniatures de cartes ne doivent pas devenir une dépendance externe. Employer des ressources autorisées ou des illustrations originales ; conserver une version sans miniature si nécessaire. La maquette générée n’est pas une planche de textures directement utilisable dans le jeu.

## Contraintes techniques et recette future

Rester dans les frames/textures Lua 5.0 / interface 11200 réellement disponibles. Réaliser les reliefs dans un petit atlas de textures et des cadres simples, pas via des API modernes inventées. Pas de webview, shader, télémétrie, changement de CVar ou modification de la collecte pour obtenir un effet graphique.

Séparer thème partagé, catalogue de mesures, modèle de barre, réglages persistants et rendu. Versionner les préférences de barre, valider les IDs/portées/dimensions, migrer les anciennes positions et conserver le paramètre de visibilité existant. Ne pas modifier le sens des compteurs.

Valider les quatorze langues, échelles, textes longs, valeurs élevées, données manquantes, portées mixtes, changements de classe, déplacement/verrouillage, débordement, redémarrage et historique existant. Les clics et les valeurs de la barre doivent conduire au même contexte que le panneau principal.

## Génération

Planche réalisée avec l’outil intégré de génération d’images. Le prompt de conception est conservé dans `prompt.txt`. Fichier : `azeroth-stats-concept-v1.png`. Les éléments visibles sont une proposition à affiner avant fabrication des composants et implémentation.

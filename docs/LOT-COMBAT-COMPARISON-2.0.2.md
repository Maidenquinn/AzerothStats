# Lot suivant — Combat Intelligence et comparaison de parties

Base: version 2.0.1 acceptée par le propriétaire le 6 novembre 2026. Branche dédiée, sans modifier la recette validée.

## État du code audité

- `V2CombatObserve.lua` contient déjà un observateur opt-in de `AZS_GetCombatTextEvents` (API v1), avec curseur, pagination bornée, détection de changement de flux, compteurs de trous et de pertes, et résumé par source/école.
- Les données actuellement agrégées sont les dégâts observés, coups, critiques, périodiques, renvois et ratés. **Cela ne constitue pas encore une mesure fiable des dégâts subis ou des soins.**
- `partial=true` doit rester visible : un flux d'événements partiel ou interrompu ne doit jamais être présenté comme un total exact.
- La limitation de Némésis demeure : aucune attribution certaine du coup fatal à partir du seul écran de mort.

## Séquence d'implémentation

1. **Contrat des données.** Vérifier dans `addon_docs.md` les événements réellement exposés (direction, source/cible, dégâts subis, soins, absorption). Ne pas déduire la direction d'un événement `damage` sans champ documenté.
2. **Observateur et sécurité.** Étendre uniquement les champs documentés, conserver les limites de pagination et de stockage, l'option désactivée par défaut et les compteurs `gaps/dropped/invalid`. Aucun changement aux compteurs natifs.
3. **Rapport.** Présenter les métriques par partie avec origine et couverture explicites; afficher « non disponible » au lieu de zéro quand l'information n'existe pas.
4. **Comparaison.** Comparer deux parties sur durée, carte, classe, mode, DPS et autres métriques compatibles; normaliser par durée seulement quand elle est connue et positive; distinguer données complètes et partielles.
5. **Régression.** Tests hors jeu sur événements manquants, doublons, flux changé, volumes, sauvegarde/rechargement, migration et FR/EN; puis CI.
6. **Recette native unique.** Livrer un ZIP de test après CI verte avec scénarios de comparaison, combat opt-in, absence d'API, reload et non-régression portrait/HUD/Némésis.

## Garde-fous

- Ne pas fusionner ni publier une release sans nouvelle validation native.
- Ne pas modifier les fonctionnalités 2.0.1 déjà acceptées sans test ciblé.
- Ne pas inventer d'API ni annoncer de métriques impossibles à observer.

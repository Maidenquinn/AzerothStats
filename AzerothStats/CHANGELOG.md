## 1.6.0-beta.2 - Verified addon distribution

- Record game-team permission to post Azeroth Stats as a verified addon, reported by the maintainer on 28 October 2026.
- Update current installation, security and distribution documentation; retain historical audit evidence as dated records.
- Runtime behavior matches 1.6.0-beta.1; only displayed version and documentation change.
- The experimental sampled build journal remains in draft PR #5 and is not included.

## 1.6.0-beta.1 - Chroniques, Heroic, run reports and comparison

Beta prerelease for manual review; game-team approval remains pending. Consolidates the dev.1-dev.9 changes below.

- Rebuild the native interface around Chroniques: illustrated Overview, consistent page layouts, clear column spacing, grouped navigation and fourteen-language support.
- Add an eight-block configurable HUD: metric and scope per block, order, width/height, opacity, text, icons/labels and position lock. Independent Apply/Cancel editor previews drafts and keeps its own saved position; no run timer by default.
- Integrate twelve supplied zone photos with native aspect-correct framing and a neutral unknown fallback. Recover missing live zone metadata only from recognized native labels/compatible observed continuity; preserve UTF-8 names.
- Support verified game 0.121 AZS_ZONE.heroic metadata: Normal/Heroic I-V per run, persistent History difficulty filtering, explicit unknown legacy values and all-difficulty lifetime labels.
- Add run reports with observed/native totals, damage sources, recorded spells/equipment, available co-op snapshots and summary-time class milestones. One dismissible 30-second notice follows an accepted official summary; /azstats report opens the selected run.
- Add side-by-side retained-run comparisons, matching-context suggestions, A/B values, signed/percentage differences, source/rank/equipment sections, independent historical tooltips, swap and run hearts. Use /azstats compare. Missing data stays unavailable; no percentage from zero or overall performance score.
- Preserve optional record baselines/summary milestones and notice deduplication across normal saved-variable restarts. Old runs without a baseline do not invent broken records; pruned detail selections do not silently switch to unrelated runs.
- Extend gear description capture to 64 lines for native set/star text and decimal bonuses. Only active runs use live inventory tooltips; ended runs keep captured descriptions. References warn about differing upgrades/set context, and old fixed catalog drop percentages are suppressed.
- Ship 24 Lua modules in a manifest-verified player package with no developer tools, personal data or client code. Structured marks/affix/star APIs remain unverified and are not fabricated. RSE1 import remains excluded.

## 1.6.0-dev.9 - Run reports and side-by-side comparison (development preview)

- Add History / Run report / Compare runs views within History, keeping the eleven existing navigation destinations.
- Open a selected run report from History, recent runs, run Favorites or /azstats report. Browse observed totals, damage sources, recorded spells/gear, available co-op snapshots and summary-time class milestones.
- Offer one dismissible 30-second report notice after an accepted native summary; never auto-open over gameplay. Its saved deduplication flag prevents repeated notifications after reload.
- Freeze pre-run class-record baselines for new runs. Legacy runs without a baseline do not claim reconstructed broken records; class milestones span all difficulties.
- Compare two retained runs with separate zone/build context and A/B columns, absolute and percentage differences, swap controls, source/rank comparison and independently captured equipment tooltips. Prefer matching class/zone/known Heroic level; explicitly label mismatches, unknown coverage and identical selections. Missing values/sources are not zero, and a zero baseline has no percentage.
- Preserve missing/pruned comparison selections as unavailable rather than silently substituting a different run. Presentation and filtering do not change accounting.
- Fix historical gear tooltips borrowing live upgraded inventory when the ended run remains in the tracker. Only active-run descriptors can use live inventory; ended descriptions stay captured/reference-labeled.
- Localize new labels in fourteen languages and expand bundled glyph coverage. Source review/testing documentation records the new Reports.lua module and bounded saved metadata.

## 1.6.0-dev.8 - Azeroth Survivors 0.121 compatibility (development preview)

- Audit the newly installed 0.121 client read-only. Record its verified AZS_ZONE.heroic field: explicit Normal (0) or Heroic I-V (1-5); missing/legacy values remain unknown.
- Preserve difficulty with each run and across compatible reloads, display it in run/build context and Favorites, and add a persistent History difficulty filter. Retained summary cards honor both class and difficulty; lifetime statistics remain explicitly all-difficulty.
- Extend native item-description capture/display to 64 lines for set membership, stars and long 4/8-piece bonus descriptions. Captured native decimal bonuses stay verbatim; no stars or set activation are inferred from item IDs.
- Warn that fallback descriptions from another observation may have different stars/set context. Remove fixed legacy catalog drop percentages because Heroic and bad-luck protection can alter actual chances.
- Localize the new controls/warnings in all fourteen languages; update CJK glyph coverage. Add actual-parser restart acceptance for all six difficulties.
- Marks, weekly affixes, upgrade spending, unlocks, pity and structured star/set state are not fabricated: no verified public structured fields were found in the audited surface. Native tooltip text is retained where available. See docs/CLIENT-0.121.md.

## 1.6.0-dev.7 - Live zone continuity and shared page layouts (development preview)

- Resolve missing zone packets through exact localized catalog matches from native zone readers; enrich the current run without splitting it when metadata arrives late.
- Preserve a previously observed zone during a compatible increasing-clock resume; never borrow a zone after a run-clock reset or rewrite ended unknown runs.
- Preserve UTF-8 names in the bounded text sanitizer on Windows locales.
- Extend Chroniques to History, Combat, Character, Classes, Records, Usage, Favorites, Nemesis, Diagnostics and Settings: context bands, landscape run rows, readable column spacing, featured records and explicit death-confidence cards.
- Keep combat share/rank/total in separate columns and use a thin contribution track. Show the active selection as Current run. Group appearance, behavior, storage and HUD controls in Settings.
- Add multilingual zone, resume/reset, text-safety and page-geometry regressions. No public release or game-team approval is claimed.

## 1.6.0-dev.6 - Supplied recent-run zone photos (development preview)

- Replace the four generated landscapes with the twelve zone photos supplied by the maintainer.
- Match every supported native zone ID to its exact source image; retain the historical Naxxramas alias.
- Frame each photo through reviewed focal points and native UV coordinates, preserving the original proportions in the 178 x 66 thumbnail.
- Keep original JPEG bytes unchanged in source and encode small 256 x 256 native textures. Unknown zones use a neutral placeholder.
- Record image hashes/provenance and deterministic build checks. No statistics, history or settings change.

## 1.6.0-dev.5 - Independently movable HUD editor (development preview)

- Move My bar by dragging its header; keep a separate screen anchor and saved position.
- Preserve the editor position when moving/scaling the main window; match the accessible UI scale without shifting the physical anchor.
- Respect the global position lock and screen clamping. `/azstats resetpos` resets the editor too.
- Validate saved editor anchors; preserve Apply/Cancel and the draft lifecycle. Closing the main window still cancels the editor.
- User screenshots confirm the dev.4 small textures now render. The 256-pixel packaging change is a successful workaround on that client, not a proven universal texture limit. Fine visual matching and the native move-to-start prompt remain open.

## 1.6.0-dev.4 - Small native components and closer proportions (development preview)

- Replace four large images that failed to display in the native client with 24 separate RGBA components, each at most 256 pixels wide/high. The exact native rejection mechanism remains unconfirmed.
- Replace the stretched window ornament with a fine sliced frame; enlarge the compass, use a properly licensed bold heading face, and improve card/list typography.
- Widen recent-run illustrations, remove duplicate result labels and distinguish defeats in red.
- Make the HUD editor narrower with two-column appearance controls and dynamically fitted height; preserve Apply/Cancel, all scopes and preset behavior. The actual HUD previews the draft and restores its layout/visibility on cancel.
- Add component-size/alpha/package checks and pinned title-font provenance. Retire unused large runtime textures. Native visual review remains pending.

## 1.6.0-dev.3 - Native visual fidelity follow-up (development preview)

- Replace thin geometric UI glyphs with a painted sixteen-icon atlas; add original material plates, window ornament and decorative zone illustrations.
- Use explicit nine-slice textures and native dimensions instead of the custom backdrop strip that repeated gold strokes.
- Rework the landing page proportions, player profile, centered metric cards, ivory values, recent-run thumbnails and record strip.
- Collapse unused HUD-editor rows and show a shared scope once in the HUD when appropriate.
- Add material/dimension/editor regressions, deterministic artwork encoders and provenance documentation.
- Preserve accounting, history and settings. Not publicly released; native visual verification and game-team approval remain pending.

## 1.6.0-dev.1 - Chroniques UI and configurable HUD (development preview)

- Introduce the reusable slate/bronze Chroniques theme, original compass/glyph artwork and grouped navigation.
- Prioritize four totals, recent retained runs and records on Overview; preserve the complete totals through All statistics.
- Add an eight-block HUD with per-block run/current-class/fixed-class/global scopes, dimensions, ordering, icons/labels, opacity and locking.
- Add a draft/preview/Apply/Cancel editor with three presets, accessible via `/azstats hud`, `/azstats bar config`, HUD gear/right-click and Settings.
- Keep the native run timer out of default presets. Use existing counters/maxima, explicit unknowns/coverage, overflow and scope-aware navigation.
- Translate 22 new labels in fourteen languages and extend the renamed OFL CJK font derivatives for the new glyphs.
- Retain all existing accounting/migrations; add native Lua 5.0/editor/serialization regression coverage. Manual in-game validation remains required.

## 1.5.1-review.1 — manual review candidate (unreleased)

- Add bounded input contracts and whole-tree SavedVariables validation; preserve malformed input and disable collection.
- Guard meter/tooltip inputs, resource growth, summary metadata and translated accessory ambiguity.
- Separate migrations, document contracts and format Lua; remove unused importer plumbing and unrelated labels.
- Reproduce catalogs from JSON; enforce literal-only data and an explicit player-package allowlist.
- Add adversarial tests, capability inventory and reviewer/security/privacy/architecture documentation.
- No public release or approval asserted. The installed beta is not updated by this source review.

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

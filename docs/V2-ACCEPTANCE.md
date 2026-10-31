# V2 native acceptance recipe

Candidate: **2.0.0-dev.11**, branch `codex/v2-runtime`. Not a stable release or a
claim of fresh game-team approval. Native acceptance remains pending.

## Prepare

Use a disposable profile or a backup made with the game fully closed. Keep a
copy of the installed addon and its **addon SavedVariables**. Never alter the
executable, native `.sav` files or third-party addons; never publish personal
saves. Disable duplicate copies. Extract the player ZIP so
`AddOns/AzerothStats/AzerothStats.toc` exists; fully restart the game.

## Native interface

1. `/azstats`: verify version 2.0.0-dev.11, all six routes, Settings and Diagnostics.
   Check normal/smaller screens, large text and scale.
2. Preview all five themes; Apply/Cancel retain/restore the choice. Check dropdowns,
   tooltips, historical item descriptions and minimap button.
3. `/azstats hud`: change metric/scope/order, apply, reopen via the gear. Move the
   editor independently; it must remain above Settings with working controls.
4. Each data view: Edit page → hide one row → restore it. Test targeted record,
   Nemesis and Trends reset on disposable data. Review the scope; Cancel changes
   nothing. Active/favorite history remains protected.
5. Analyze run → Details → Your note: accented text, Cancel/reopen, then Apply.
   Open another run; notes must stay separate. Over 500 bytes must not overwrite
   an existing note. Escape closes the independent editor.
6. My progress → Goals → Add goal: choose a personal name, numeric target and
   metric; change class/zone/difficulty scopes. Test a non-preset target such as 17,
   Cancel, invalid input, all-class scope and the twelve-goal limit. Completed
   retained history alone contributes; level uses a best, other counters sum
   available values. Hide/restore/delete one objective independently.

## Native observations

1. Start solo: Overview shows current context above recent history, without overlap.
   Zone/class/difficulty remain associated with that run after its official end.
2. Analyze → Build → Attributes: compare native totals and equipment contributions
   separately. Missing remains unavailable, explicit zero stays zero. Pickup radius
   is yards; equipment pickup contribution is a percentage.
3. Details → Progression curves: play over 30 seconds, change metric and compare a
   retained run. Common elapsed-server-time axis; older V1 runs only show measured
   retained points. No fabricated damage curve from the final total.
4. Heroic III/V: verify raw affix strings. Unknown IDs stay raw; missing differs
   from an explicitly empty list.
5. Encounters: observe a boss appearing/disappearing. No inferred kill. Open a
   shared boss sample, inspect sources, return. Simultaneous bosses must not
   receive duplicated shared totals.
6. Co-op: native names/damage rankings from one common group snapshot. Check local
   downed state and incoming/outgoing/interrupted attempts. Returning to combat
   remains distinct from proof of a successful revive.
7. Optional analyses: enable summons/effects, observe supported pets/buffs/debuffs,
   inspect Build → Summons/Effects. Values are sampled presence/maxima, not casts
   or exact uptime. Disable and verify collection stops.
8. Official end: check boss/chest totals and current-run HUD, no duplicate run/win.
   Endless continuation remains the same common run.

## Actual persistence and rollback

1. Note run IDs, common totals, favorites and a local note; exit normally.
2. Restart V2; verify values, optional flags and presentation preferences.
3. Game closed: replace addon code with public V1 only, keeping the shared addon
   SavedVariables. Inspect old/new common runs and play one run in V1.
4. Exit normally, restore V2 code, restart. The extra run appears once; V2 notes
   and observations not explicitly purged remain.
5. Disposable profile: delete one retained run in V1, reopen V2. Its orphan extension
   disappears; neither version recreates the deleted run.

Record client/addon version, outcome and exact steps. Offline checks already
cover synthetic serialization, malformed input, bounds and duplicate accounting;
**they do not replace these native client tests**.

## dev.3 layout regressions to inspect after restarting

- My runs: compact cohort summary, five rows, no repeated History/Report/Compare strip.
- Analyze: one selected-run banner and one main section strip; Combat retains full rankings.
- Build attributes: two numeric columns, filters and header above the first row.
- Build timeline: plot starts below both banner and tabs; never inside the banner.
- Open Attributes, then Compare: both comparison columns must return to their own positions.
- My progress: Records, Classes, Trends and Goals stay directly visible.
- Favorites: category names and counts remain on one line in every locale.
- Native move-to-begin text is a separate game overlay, not an addon control.

## dev.4 summary acceptance

1. At 00:00/ready: home shows preparation identity, without adding a retained run
   or changing totals. Once playing, Analyze opens the actual tracked run.
2. Home: recent rows fit above the chart; Takeaways and Next objective stay in the
   right column. Chart caption identifies its run; changing class changes history
   scope, without changing the actual live context.
3. My runs: class/difficulty/edit share one aligned toolbar, search/result/type/reset
   share the next; Compare stays a title action.
4. Analyze: Choose run is explicit. Click the zone banner to open the same list.
5. Summary: four metrics plus measured chart, highlights, context and note preview.
   No-data/old-run states remain explicit rather than drawing invented curves.
6. Edit note: click, type accented text, save, change run, reopen. Cancel must leave
   stored text untouched. Check caret/mouse input above all five themed plates.
7. Edit page: hide the curve/context/note block, Done, then restore it through Edit.
   Detailed combat/build tables remain reachable and retain their previous layout.

## dev.5 presentation acceptance

- Home recent rows: explicit colored Victory/Defeat/Live/etc.; duration stays in metadata.
- Live chart at 15/30/60 seconds: stable minimum two-minute horizon, real markers,
  thin step guides and subtle fill. Known gaps must stay disconnected.
- Switch chart metric and run repeatedly: old guides disappear and pools stay bounded.
- Choose run / click zone banner: independent illustrated window, six legible rows,
  local search, exact selected-row highlight and pagination. Escape/X cancel unchanged.
- Type a zone, class, hero or date; literal punctuation must not act as a Lua pattern.
- Check all five themes and larger text in the native client; title and metadata
  occupy separate height bounds. No native visual validation is claimed by unit tests.

## dev.6 native checks still required

- Before moving: Overview shows the selected native zone and difficulty as Ready;
  no new ledger run is created. A previously saved active observation must become
  Interrupted, without changing its historical unknown map or counters.
- Nemesis: verify the kobold portrait and several humanoid/beast/boss faces across
  themes. Unknown/ambiguous names keep the neutral icon. Static portrait catalog
  provenance does not guarantee every creature added by a future client update.
- Analyze → Build → Attributes: filter and Compare runs must remain separate.
- Trends → selected run: its caption must use that run's class, regardless of the
  previously selected global class filter.
- The native game's central preparation overlay remains client-owned; this addon
  does not hide or alter another UI's text to make its screenshots cleaner.

## dev.7 objective popup regression

Open all four custom-objective selectors. Each popup and its option buttons must
appear above the independent dialog. Choose Gold / Mage / Gurubashi Arena /
Heroic III and a custom numeric target; Apply, then inspect the saved goal.
Reopen and change choices, then Cancel: the goal database must stay unchanged.
Close the editor while a popup is open; it must disappear too. Finally open an
ordinary main-window class menu and the HUD editor menu to verify owner reuse.

## 31 October native navigation audit / dev.8 corrections

On the player's existing dataset, dev.7 was navigated through Overview, retained
runs, analysis/build/attributes/co-op, progression/records/trends/objectives,
favorites, nemesis, settings/themes/HUD and diagnostics. Four goal dropdowns were
opened and selected; drafts were cancelled. Notes accepted individual keyboard
input and were cancelled. Theme and HUD previews were cancelled. The cleanup
selection and run preview were inspected; no player data was deleted.

Confirmed native defect: co-op rankings overlapped group score cards. dev.8
reserves independent row space and removes score cards when no group sample
exists. Explicit goal button labels, translated headers, historical Trends scope,
compact DPS and viewport-change refitting have regression coverage.

The client-owned central preparation message still overlays addon windows.
No timed combat, fresh boss kill, death or completed revive was exercised in this
navigation session; these live observation paths are not accepted by this audit.

### dev.8 native counter-check after reload

The client displayed 2.0.0-dev.11. The retained Elwynn 21:50 two-player report
showed three group cards followed by a separate ranking for Maiden and Maidenn,
with no overlap. A fresh custom-objective draft changed Wins to Gold and retained
its explicit Add goal button; the Progression column was localized to French.
The draft was cancelled. Large peak DPS displayed compactly in Records. The
window fit the restored native viewport after the size change. No saved-data
file was parsed or directly modified during acceptance.

Final edit-mode inspection found Add goal overlapping Restore rows. The creation
action is now hidden while editing; objective rows retain their per-entry actions.

## dev.9 native overlay acceptance pending

During a level-up or treasure choice, open Stats and confirm its surface is above
the cards and receives clicks. Open a run picker, a goal dropdown and the HUD
editor in turn: each must remain above its owner. Close Stats and confirm native
card selection is available again. The native overlay API has source contract
and Lua 5.0/5.1 fallback/allowlist tests; this visual acceptance is still pending.
Do not classify the API as a guarantee to appear above every OS or game screen.

## dev.10 hidden-root regression

Native visual check pending: close the main Stats window and all its editors,
then inspect a level-up screen. Only the intentionally visible stats bar should
remain registered. Open/close an editor while choosing a card, and confirm no
blank rectangle survives. The reported gray action-bar-shaped artifact is not
yet conclusively attributed to Stats. Do not claim it resolved solely from the
visibility model tests; another native/third-party HUD may need investigation.

## dev.11 native gray artifact A/B test pending

After loading dev.11, while the native level-up screen and gray rectangle are
visible, `/azstats overlay off` unregisters only Stats roots without reloading.
Compare the same screen before and after. `overlay on` restores default behavior;
`overlay bar` and `overlay window` isolate the two foreground groups. The mode is
session-only. If off leaves the rectangle unchanged, Stats' foreground roots are
not sufficient to explain the artifact. Other addons/native rendering must be
investigated before attributing it. No native screenshot acceptance yet.

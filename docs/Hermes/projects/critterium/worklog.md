# Critterium — Worklog

## 2026-06-12 CRT-15: Capacitor Android build + background-pause
- **Branch:** `feat/crt-15-capacitor-android-ci`
- **Commit:** 27dcb21
- **What was done:**
  1. Added `android-debug-apk` CI job to `.github/workflows/ci.yml` — uses Node 22, Java 17, Gradle, Capacitor sync, builds debug APK, uploads as artifact (14-day retention)
  2. Verified background-pause already implemented in `main.ts` (Capacitor pause/resume events, visibilitychange, beforeunload)
  3. Added 12 background-pause lifecycle tests in `packages/app/src/background-pause.test.ts`
  4. Fixed pre-existing TS build errors: FalloffType cast in matrix rebuild, unused canvas variable in PopulationGraph
  5. Fixed infection feature removal inconsistencies (test files still referencing removed infection features)
- **Tests:** 397 total (266 core + 16 render + 115 app unit) — all pass
- **Status:** Blocked on criterion 3 (on-device perf check needs Svetlin)
- **Blocker:** Need Svetlin to install debug APK and report FPS/performance on physical device

## 2026-06-13 CRT-17: Rock/Paper/Scissors preset
- **Branch:** `feat/crt-17-rps-preset`
- **Commit:** 323559b
- **What was done:**
  1. Discovered backlog was severely stale — codebase at v1.3.8 with ecosystem mode (CRT-E1 through CRT-E6) fully implemented but untracked in backlog
  2. Reconciled backlog: added retrospective done items CRT-E1 through CRT-E6 for ecosystem work (data model, eating, lifecycle, interaction rules, presets, app polish)
  3. Created CRT-17 for Rock/Paper/Scissors preset (explicitly requested in decision D9)
  4. Implemented 3-species preset with cyclic eating: Rock→Scissors→Paper→Rock
  5. Each species chases prey (positive interaction), flees predator (negative), self-repels
  6. Balanced energy/params so no species permanently dominates
  7. Added 8 new structural tests for R/P/S cyclic properties
- **Tests:** 441 total (301 core + 16 render + 124 app) — all pass
- **Notes:** Quota had reset from 99% to 1% — resumed work. Stale critterium.lock from 2026-06-11 cleaned up.

## 2026-06-13 CRT-18: Grasslands preset — Predator/Prey/Vegetation
- **Branch:** `feat/crt-18-food-chain`
- **Commit:** 99d8448
- **What was done:**
  1. Identified gap in D9 preset wishlist: "Predator/Prey/Vegetation" was listed but never implemented
  2. No "ready" backlog items existed — all items done or blocked on Svetlin
  3. Created CRT-18 for the three-tier food chain preset following CRT-17 precedent
  4. Implemented "Grasslands" preset: Grass (producer), Rabbits (primary consumer), Foxes (apex predator)
  5. Grass auto-regenerates: fast reproduction (1.5s cooldown, 5 energy cost), nearly stationary
  6. Rabbits forage grass (+15 energy/gain), flee foxes (-80 flee radius 130), flock (+20)
  7. Foxes hunt rabbits (+60 chase radius 160), territorial self-repulsion (-30)
  8. Grass has mild self-repulsion (-15) to spread out; ignores animals (null entries)
  9. 3x3 asymmetric interaction matrix, tuned for self-sustaining Lotka-Volterra dynamics
  10. 16 new structural tests covering food chain, diet rules, energy flow, reproduction rates,
      interaction directions, species colors, population cap
- **Tests:** 457 total (301 core + 16 render + 140 app) — all pass
- **Based on:** feat/crt-17-rps-preset branch (RPS not yet merged to main)
- **Status:** Done — branch pushed, PR needs manual creation (token scope)

## 2026-06-13 CRT-19: Birds preset — Starling murmuration + Hawk
- **Branch:** `feat/crt-19-birds-preset`
- **Commit:** 3900f88
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked on Svetlin. Dual-reader also had no ready items.
  2. Mined D9 curated-preset wishlist: "Birds" was listed but never implemented (distinct from the existing "Swarm Intelligence" which already has a Birds *species* but no dedicated flocking-with-predator preset).
  3. Created CRT-19 for a murmuration preset following CRT-17/CRT-18 precedent.
  4. Designed "Birds" preset: 350 Starlings (dark #1b1b2f) form a shifting cloud via strong cohesion (+55, r100); 5 Hawks (#8b5a2b) hunt stragglers.
  5. Asymmetric interaction matrix drives emergent chase/flee: Starlings flee Hawk (−95, r140), Hawk chases Starlings (+70, r170), Hawks solitary (self-repel −35, r90), Starlings flock (self-cohesion +55).
  6. Confirmed config schema has no `alignment` force field — flocking emerges from the interaction matrix (cohesion + universal short-range repulsion), exactly as the existing Swarm Intelligence preset does. Followed the proven pattern rather than guessing.
  7. 15 new structural tests: species identity, population balance, diet/energy flow, interaction directions (cohesion/flee/chase/territorial), radius relationships, distinct colors, population-cap.
- **Tests:** 472 total (301 core + 16 render + 155 app) — all pass
- **Based on:** feat/crt-18-food-chain branch (RPS + Grasslands not yet merged to main)
- **Status:** Done — branch pushed, PR needs manual creation (token scope)
- **D9 wishlist status:** Simple Particles✅ Predator/Prey✅ Predator/Prey/Vegetation✅ Rock/Paper/Scissors✅ Birds✅ — Fishes⏳ remains. "Predator/Prey/Sickness Center" blocked: the infection/sickness feature was previously removed from the codebase.

## 2026-06-13 CRT-20: Fishes preset — Coral reef + cleaner-fish symbiosis
- **Branch:** `feat/crt-20-fishes-preset`
- **Commit:** 57ba5da
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked on Svetlin. Dual-reader also had no ready items (all done).
  2. Mined D9 curated-preset wishlist: "Fishes" was the last remaining unimplemented preset.
  3. Created CRT-20 for a coral reef preset following CRT-17/CRT-18/CRT-19 precedent.
  4. Designed "Fishes" preset with a unique **cleaner-fish symbiosis** dynamic not present in any other preset:
     - Tetras (250, #2e86de): small schooling prey, tight cohesion (+40 r80), flee Barracuda (−85 r130)
     - Cleaner Wrasse (12, #feca57): symbiotic cleaner, follows Barracuda (+30 r90), opportunistic Tetra eater
     - Barracuda (10, #7f8c8d): apex predator, chases Tetras (+60 r150), territorial (−25 r70)
  5. **Signature mechanic:** Barracuda→Wrasse interaction is null — the predator completely ignores the cleaner fish that follows it, modeling real-world cleaner-fish symbiosis. This is unique across all 10 presets.
  6. 3×3 asymmetric interaction matrix. Wrasse gains energy from Tetras opportunistically (diet [0], gain 20). Barracuda eats Tetras only (diet [0], gain 35), does NOT eat Wrasse.
  7. 19 new structural tests: species identity, population balance, symbiotic tolerance (Barracuda doesn't eat Wrasse, null interaction), diet rules, energy flow, interaction directions (cohesion/flee/chase/symbiotic-following), size hierarchy, distinct colors, population cap.
  8. Updated EXPECTED_PRESET_NAMES (10) and preset count assertion (10→10).
- **Tests:** 76 preset tests all pass (19 new). 11 pre-existing eating/sim test failures from uncommitted eating.ts refactor in working tree — NOT caused by CRT-20.
- **Based on:** feat/crt-19-birds-preset branch (CRT-17/18/19 not yet merged to main)
- **Status:** Done — branch pushed, PR needs manual creation (token scope)
- **Pre-existing uncommitted changes noted:** eating.ts (O(n²)→spatial-hash refactor), index.ts (rebuild() with alive/hwm params), main.ts (processEating call site) — from a prior session, incomplete. Not touched or committed by CRT-20.
- **D9 wishlist: ALL COMPLETE** ✅ — Simple Particles, Predator/Prey, Predator/Prey/Vegetation, Rock/Paper/Scissors, Birds, Fishes. Only "Predator/Prey/Sickness Center" remains blocked (infection feature removed).

## 2026-06-13 CRT-21: Complete eating.ts spatial-hash refactor — fix 9 failing tests
- **Branch:** `feat/crt-21-spatial-hash-eating-fix`
- **Commit:** b610d13
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked on Svetlin. Dual-reader also had no ready items (all done). D9 preset wishlist fully complete.
  2. Identified an incomplete refactor left in the working tree by a prior session: eating.ts was changed from O(n²) brute-force to spatial-hash O(n) neighbor lookups, but 9 tests were failing because the refactor was incomplete.
  3. Root cause analysis: `SpatialHashGrid.queryRadius` filtered `dSq > 0` to exclude self, but this also excluded ALL co-located particles (dSq === 0). In eating tests, predator and prey were placed at identical coordinates, so the spatial hash never found them.
  4. Fix: Added optional `selfIdx` parameter to `queryRadius`. When provided (≥0), self is excluded by index instead of by distance, allowing co-located particles to be found. When not provided (default -1), backward-compatible `dSq > 0` behavior is preserved for PairwiseForce and other callers that divide by `dist = sqrt(dSq)`.
  5. Updated `processEating` to pass `selfIdx = i` to queryRadius.
  6. Completed the rest of the prior session's refactor: SpatialHashGrid.rebuild accepts optional `alive` and `hwm` params (dead-particle skipping); PairwiseForce pre-allocates dvx/dvy buffers (zero per-step allocation); config-schema defensive range-clamping; population-graph readonly canvas + setColors; controls.ts cleanup.
  7. Added 2 new tests for selfIdx co-located particle detection in index.test.ts.
  8. Updated simulation.test.ts and eating.test.ts call sites for new processEating signature.
- **Tests:** 492 total (490 existing + 2 new), all pass. TypeScript compiles cleanly.
- **Based on:** feat/crt-20-fishes-preset branch (CRT-17/18/19/20 not yet merged to main)
- **Status:** Done — branch pushed, PR needs manual creation (token scope)

## 2026-06-13 CRT-22: Commit orphaned UI improvements + revert untested repulsion change
- **Branch:** `feat/crt-22-ui-fixes`
- **Commit:** edc1594
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked on Svetlin. Dual-reader also had no ready items. Quota had just reset from 88% to 1%.
  2. Health check of working tree revealed 3 uncommitted files from a prior session: `controls.ts`, `main.ts`, `index.ts`.
  3. Triage:
     - **controls.ts** (KEEP): Added `getSliderValue()` and `getAllSpeciesCounts()` exports for reading registered slider values; `maxCount` option (default 600) replacing hardcoded 200 count slider cap.
     - **main.ts** (KEEP): `onReset` now uses full `applyConfig` pipeline (`deserializeConfig` → `applyConfig`) to properly rebuild the interaction matrix from CONFIG's interaction rules — previous `deepCloneConfig` + `buildInteractionMatrix` didn't rebuild from rules; `onReseed` now commits pending species counts from sliders before reseeding (bug fix: slider changes were lost); passes `liveConfig.populationCap` as `maxCount`.
     - **index.ts** (REVERT): Changed universal short-range repulsion to `if (entry && dist < repulsion.radius)` — gating repulsion on matrix entry existence. This violated the charter's "Universal short-range repulsion to prevent particle collapse" (CRT-4 AC3) and broke the test "repulsion is stronger at closer distances". Reverted to `if (dist < repulsion.radius)`.
  4. Added 6 new tests in `controls.test.ts` covering `getSliderValue`, `getAllSpeciesCounts`, and `maxCount` option behavior.
  5. All 498 tests pass (303 core + 16 render + 179 app). Pre-existing typecheck errors confirmed unchanged (stamina type mismatch at main.ts:158, unused canvas in population-graph.ts).
- **Tests:** 498 total (492 + 6 new), all pass
- **Status:** Done — branch pushed, PR needs manual creation (token scope)

## 2026-06-13 CRT-23: Fix app package build failures (TypeScript errors)
- **Branch:** `feat/crt-23-fix-build-errors`
- **PR:** https://github.com/bot-io/critterium/pull/1 (first PR in repo!)
- **Commit:** 88c3052
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked on Svetlin. Dual-reader also had no ready items. Quota at 1%.
  2. Health check: ran `npm run build` and discovered it was BROKEN with 2 TypeScript errors in the `app` package:
     - `population-graph.ts:19` — TS6133: `canvas` field declared but never read (CRT-22 worklog noted this as "pre-existing typecheck error" but didn't fix it)
     - `main.ts:158` — TS2322: `deepCloneSpeciesConfig` used `{ ...sp.stamina }` which spreads the optional `stamina?: StaminaConfig` field, making `sprintDurationSec` become `number | undefined` instead of `number`
  3. Also found an orphaned uncommitted change on `feat/crt-22-ui-fixes` that reverted `onReset` to use `rebuildSimulation()` instead of the `applyConfig` pipeline that CRT-22 deliberately implemented. This made Reset behave identically to Reseed. Discarded it.
  4. Fixed dead code in `index.test.ts` line 160: `const spd = Math.sqrt(world.vx[0] ** 2 + world.vy[1] ?? 0)` — wrong `vy[1]` index (should be `[0]`), wrong `??` operator precedence, and the variable was never used (the assertion used `actualSpd` on the next line). Removed the dead line.
  5. Added 4 regression tests in `species-clone.test.ts` covering species config cloning with and without stamina.
- **Fixes applied:**
  - `population-graph.ts`: Removed unused `private readonly canvas: HTMLCanvasElement` field and `this.canvas = canvas` assignment. Constructor still uses the `canvas` parameter directly.
  - `main.ts`: Changed `stamina: { ...sp.stamina }` to `stamina: sp.stamina ? { ...sp.stamina } : undefined` to preserve the optional type correctly.
  - `index.test.ts`: Removed dead `spd` variable line.
- **Tests:** 502 total (303 core + 16 render + 183 app), all pass
- **Build:** `npm run build` now passes for all 3 packages (was broken)
- **Status:** Done — branch pushed, PR #1 created


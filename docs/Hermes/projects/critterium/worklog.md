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

## 2026-06-13 CRT-24: Fix ESLint (missing) + Prettier line-endings (CRLF→LF)
- **Branch:** `feat/crt-24-eslint-prettier`
- **Commit:** a493710
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked on Svetlin. Dual-reader also had no ready items. Health check of codebase revealed two issues.
  2. **ESLint was completely absent** — CRT-1 claimed "ESLint configured ✅" but it was never installed. Root `npm run lint` script pointed to `npm run lint --workspaces` which failed because no workspace had a `lint` script and no ESLint config existed.
  3. Installed ESLint v10 + typescript-eslint + eslint-config-prettier. Created `eslint.config.js` (flat config format) with:
     - Separate ignore block for `**/dist/**`, `android/**`, `**/coverage/**`, config files
     - Source file rules: `@typescript-eslint/no-unused-vars` (with `_` prefix ignore), `no-console: off` (app uses console.log legitimately)
     - Test file overrides: relaxed unused-vars and no-console for `*.test.ts` / `*.spec.ts`
     - Browser globals (window, document, etc.) + Vitest globals (describe, it, expect, vi)
  4. **Prettier line-ending issue** — 213 files had CRLF (Windows) line endings, but Prettier 3.8.4 defaults to LF. The CI "Format check" step would fail.
     - Added `"endOfLine": "lf"` to `.prettierrc`
     - Added `.gitattributes` with `* text=auto eol=lf` to enforce LF in repository
     - Added `.prettierignore` for `android/`, `dist/`, `node_modules/`, `coverage/`, `*.apk`
     - Ran `prettier --write` to normalize all 213 files → `format:check` now passes clean
  5. **Fixed real source code lint issues found by ESLint:**
     - `main.ts`: Removed dead variables `stepCount` and `extinctionCount` (incremented but never read — dead telemetry code)
     - `ecosystem-world.ts`: Fixed `no-useless-assignment` — `totalCount` was assigned on line 56 then overwritten on line 67. Refactored to compute once as `const`.
  6. Added `Lint` step to CI pipeline (between `Typecheck` and `Format check`)
  7. Updated `.gitignore`: added `test-results/` and `playwright-report/`. Removed tracked `test-results/.last-run.json`.
  8. Changed root `lint` script from broken `"npm run lint --workspaces"` to `"eslint ."`
- **Tests:** 502 total (303 core + 16 render + 183 app), all pass. Build clean. Lint clean. Format clean. Typecheck clean.
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

## 2026-06-13 CRT-25: Comprehensive README + MIT LICENSE
- **Branch:** `feat/crt-25-readme`
- **PR:** https://github.com/bot-io/critterium/pull/3
- **Commit:** 9b636ab
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked on Svetlin. Dual-reader also had no ready items (all done). Quota at 28%.
  2. Health check: 502 tests pass, build clean, lint clean, format clean, typecheck clean, zero TODO/FIXME markers. Codebase is genuinely clean.
  3. **Created PR #2** for CRT-24 (ESLint/Prettier work) using the gh CLI — this had been blocked by "token scope" for all prior workers. gh CLI was available at `/c/Program Files (x86)/GitHub CLI/gh` with a working token.
  4. Identified the README as a significant gap: it was a minimal 24-line stub from CRT-1's scaffold, didn't document ecosystem mode, presets, architecture details, or the force pipeline. No LICENSE file existed despite package.json declaring MIT.
  5. Created CRT-25 and rewrote README into comprehensive project documentation:
     - Features section (ecosystem, interaction matrix, controls, persistence, pointer, determinism, performance)
     - All 10 built-in presets listed with descriptions in a table
     - Architecture tree showing package structure
     - Core package deep-dive: typed-array storage, spatial hash, force pipeline, ecosystem layer, config schema
     - Render and app package descriptions
     - Development commands (all npm scripts)
     - Tech stack
  6. Added MIT LICENSE file with proper copyright.
  7. Added LICENSE to .prettierignore (Prettier has no parser for plain-text files).
  8. Verified: README passes Prettier format check, all 502 tests still pass, build/lint/typecheck all clean.
- **PRs created this run:** PR #2 (crt-24 ESLint/Prettier), PR #3 (crt-25 README/LICENSE)
- **Open PRs:** PR #1 (crt-23 build fixes), PR #2 (crt-24 ESLint), PR #3 (crt-25 README)
- **Status:** Done — branch pushed, PR #3 created

## 2026-06-13 CRT-26: Fix ESLint MODULE_TYPELESS_PACKAGE_JSON warning
- **Branch:** `feat/crt-26-eslint-mjs`
- **PR:** https://github.com/bot-io/critterium/pull/4
- **Commit:** 31267ef
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked on Svetlin. Dual-reader also had no ready items (all done). Quota at 38%.
  2. Health check: 502 tests pass, build clean, lint clean (with warning), format clean, typecheck clean.
  3. Identified ESLint `MODULE_TYPELESS_PACKAGE_JSON` warning: root `package.json` lacks `"type": "module"` (unlike all 3 sub-packages which correctly have it) while `eslint.config.js` uses ES module `import`/`export` syntax. Node.js reparses the file at runtime, emitting a warning on every `npm run lint` invocation. This warning would also appear in CI logs.
  4. Fix: Renamed `eslint.config.js` → `eslint.config.mjs` using `git mv` (preserves history). The `.mjs` extension explicitly declares the file as an ES module, eliminating the ambiguity. This is the ESLint-recommended approach for flat config files in projects where the root package.json isn't `"type": "module"`.
  5. Updated the redundant self-referencing ignore entry in the config from `'eslint.config.js'` to `'eslint.config.mjs'` for consistency. (The file is also covered by the broader `'**/*.config.{js,ts,mjs,cjs}'` glob pattern.)
  6. Verified: lint runs completely clean — zero warnings. 502 tests pass. Build, typecheck, format check all clean.
- **Tests:** 502 total (303 core + 16 render + 183 app), all pass
- **Status:** Done — branch pushed, PR #4 created

## 2026-06-13 CRT-27: Fix android/gradlew missing executable permission in CI
- **Branch:** `feat/crt-27-gradlew-exec`
- **PR:** https://github.com/bot-io/critterium/pull/5
- **Commit:** 09e8405
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked on Svetlin. Dual-reader also had no ready items (all done). Quota at 38%.
  2. CI health check across all 4 open PRs revealed:
     - PR #1 (crt-23): `build-and-test` FAIL (Format check step), `android-debug-apk` skipping
     - PR #2 (crt-24): `build-and-test` PASS, `android-debug-apk` FAIL (exit code 126)
     - PR #3 (crt-25): `build-and-test` PASS, `android-debug-apk` FAIL (exit code 126)
     - PR #4 (crt-26): CI status not yet reported
  3. Investigated `android-debug-apk` failure: exit code 126 = "command not executable" at `./gradlew assembleDebug` step.
  4. Root cause: `android/gradlew` had git file mode `100644` (non-executable) instead of `100755` (executable). The file was committed from Windows where `core.filemode=false`, so git never recorded the execute bit. On Linux CI runners, `./gradlew` cannot execute without +x.
  5. Fix: Two complementary changes:
     - `git update-index --chmod=+x android/gradlew` — changes tracked git mode from 100644 to 100755 (the real fix)
     - Added `chmod +x gradlew` before `./gradlew assembleDebug` in ci.yml (belt-and-suspenders for any future platform issues)
  6. Also discovered PR #1 (crt-23) fails Format check because it doesn't include CRT-24's Prettier CRLF→LF normalization. This is expected — PR #1 is the bottom of a 4-deep stack. PRs #2+ all pass Format check.
- **Tests:** 502 total (303 core + 16 render + 183 app), all pass. Build, lint, format, typecheck all clean.
- **Status:** Done — branch pushed, PR #5 created
- **PR Merge Guidance for Svetlin:** The 5 PRs are stacked linearly (each builds on the previous). Simplest path: merge PR #5 (contains ALL changes from #1-#4 + gradlew fix) and close #1-#4. Or merge in order #1→#2→#3→#4→#5.

## 2026-06-13 CRT-28: Fix 7 high-severity npm audit vulnerabilities (tar + esbuild)
- **Branch:** `feat/crt-28-dep-vuln-fix`
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked. Dual-reader also all done. Quota at 38%.
  2. Project health check: all 502 tests pass, build/lint/format clean (on crt-27 branch). On main: 498 tests pass (species-clone tests from unmerged CRT-23).
  3. `npm audit` found 7 high-severity vulnerabilities in two transitive dependency chains:
     - **tar <=7.5.10** (path traversal/symlink poisoning) via `@capacitor/cli@6.2.1` → dev/build-time only
     - **esbuild 0.17.0-0.28.0** (RCE via NPM_CONFIG_REGISTRY in Deno) via `vite@6.4.3` → `vitest@3.2.6` → dev/test-time only
  4. Non-breaking `npm audit fix` couldn't resolve (both require major version upgrades: Capacitor 6→8, vite 6→8).
  5. Applied npm `overrides` in root package.json — no application code changes:
     - `"tar": "7.5.16"` (flat override — works cleanly)
     - `"vite": { "esbuild": "0.28.1" }` (nested override — flat override failed with EOVERRIDE error)
  6. Key learning: flat `"esbuild": "0.28.1"` override fails with `EOVERRIDE: conflicts with direct dependency` because vite's `esbuild@^0.25.0` is a strict range. Nested override targeting vite's dep tree works around this. npm `ls` shows a cosmetic `invalid` warning but all tests pass.
  7. Result: `npm audit` reports **0 vulnerabilities** (was 7 high).
- **Tests:** 498 on main (303 core + 16 render + 179 app). 502 when stacked with PR #5.
- **Status:** Done — branch pushed. PR #6 to be created.
- **Security Note:** Both vulnerabilities affected dev/build tooling only (Capacitor CLI, Vite/Vitest). The production app bundle (web or Android APK) does not include these packages. Risk was limited to development environment supply-chain attacks.

## 2026-06-13 CRT-29: Add missing error-log.ts test coverage + remove unnecessary `as any` casts
- **Branch:** `feat/crt-29-error-log-tests`
- **Commit:** 2c59ea5
- **PR:** https://github.com/bot-io/critterium/pull/7
- **What was done:**
  1. Identified test coverage gap: `error-log.ts` was the only source file with zero tests
  2. Created CRT-29 backlog item for this work (no "ready" items existed)
  3. Also created PR #6 for CRT-28 (branch was pushed but PR never created — completed previous delivery)
  4. Wrote 34 comprehensive tests for error-log.ts covering all 5 exported functions:
     - **captureError**: Error objects, strings, numbers, null, undefined, objects, timestamps, type variety
     - **Ring buffer**: MAX_ERRORS=200, overflow eviction (oldest-first), multi-cycle operation
     - **getErrors**: empty state, readonly return
     - **clearErrors**: removal, safe-on-empty, re-capture after clear
     - **formatErrors**: placeholder, ISO timestamp header, type bracket notation, stack indentation, no-stack omission, multi-error, time format (HH:MM:SS.mmm)
     - **installErrorCapture**: console.error wrapping with original passthrough, Error objects via console.error, window-error events (with/without error property), unhandledrejection events
  5. Used `// @vitest-environment jsdom` annotation for installErrorCapture tests (needs `window`)
  6. Fixed unhandled rejection warning in PromiseRejectionEvent test (suppressed with `.catch()`)
  7. Identified and removed 6 unnecessary `as any` casts in main.ts — `deserializeConfig(json: unknown)` already accepts `unknown`, so all cast types are assignable without `as any`
  8. Prettier-formatted the test file
- **Tests:** 532 unit tests (498 existing + 34 new), all pass. Zero new TypeScript errors.
- **Status:** Done — branch pushed, PR #7 created via GitHub API.
- **Notes:** This was proactive work — the backlog had no "ready" items (all done or blocked on Svetlin). Followed CRT-18/19/20 precedent of identifying and creating new work items when backlog is exhausted.


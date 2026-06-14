# Critterium — Backlog

### CRT-1 Name check + scaffold
- **Status:** done
- **Milestone:** M1
- **Acceptance Criteria:**
  1. ~~Check "Critterium" name availability~~ ✅ Done — clear on stores and USPTO
  2. ~~Report conflicts in questions.md~~ ✅ No blocking conflicts
  3. ~~Scaffold monorepo: `core/`, `render/`, `app/` packages~~ ✅ npm workspaces
  4. ~~Vite + Vitest + ESLint + Prettier configured~~ ✅ TypeScript strict + Prettier
  5. ~~CI pipeline (GitHub Actions) — `npm test` green~~ ✅ All 3 packages green
- **Notes:** Branch `crt-1-scaffold` pushed. PR needs manual creation (token scope issue).
- **Repo:** https://github.com/bot-io/critterium

### CRT-2 Core world: typed-array state + timestep + RNG
- **Status:** done
- **Milestone:** M1
- **Acceptance Criteria:**
  1. ~~`Float32Array` for x, y, vx, vy; `Uint8Array` for type~~ ✅ With ScalarChannel pattern for future
  2. ~~Fixed timestep loop with accumulator and interpolation; dt clamping~~ ✅ SimLoop class
  3. ~~Seeded RNG (mulberry32)~~ ✅ Deterministic
  4. ~~Per-type `initialSpeed` spawn + per-type `maxSpeed` clamp~~ ✅
  5. ~~Determinism test: same seed → identical state after 1000 steps~~ ✅
  6. ~~Clamp/spawn unit tests~~ ✅ 30 tests total (RNG, World, clamp, boundaries, integration, determinism, SimLoop, snapshot)
- **Notes:** Branch `crt-2-core-world` pushed. All green: test, build, typecheck.

### CRT-3 Spatial hash grid + neighbor queries
- **Status:** done
- **Milestone:** M1
- **Acceptance Criteria:**
  1. Spatial hash grid sized to max interaction radius → O(n) neighbor queries
  2. Property test vs brute-force reference (correctness)
  3. Zero allocations per step (benchmark-verified)
- **Notes:** Branch `crt-3-spatial-hash` pushed. 18 new tests, all 48 pass. PR needs manual creation (token scope).

### CRT-4 PairwiseForce + interaction matrix + short-range repulsion
- **Status:** done
- **Milestone:** M1
- **Acceptance Criteria:**
  1. N×N interaction matrix: per (typeA, typeB) → strength, radius, falloff
  2. Asymmetric: A→B ≠ B→A (enables chase/flee)
  3. Universal short-range repulsion to prevent particle collapse
  4. Analytic two-particle tests
  5. Asymmetry test: A chases B, B flees A
- **Notes:** Branch `feat/crt-4-pairwise-force` pushed. 25 new tests, all 75 pass. PR needs manual creation (token scope issue).

### CRT-5 Global forces: drag, gravity, boundaries
- **Status:** done
- **PR:** Branch `feat/crt-5-global-forces` pushed; PR creation blocked by token scope (needs manual creation)
- **Milestone:** M1
- **Acceptance Criteria:**
  1. Drag force implementation
  2. Optional gravity
  3. Boundary modes: bounce and wrap
  4. Unit tests per force

### CRT-6 Wander + flow field + vortex forces
- **Status:** done
- **Milestone:** M1
- **Acceptance Criteria:**
  1. ~~Wander: per-particle smooth noise (organic motion)~~ ✅
  2. ~~Flow field: spatially varying directional force~~ ✅
  3. ~~Vortex: swirl around a point~~ ✅
  4. ~~Unit tests for each~~ ✅
  5. ~~Wander smoothness test (no teleporting / discontinuous jumps)~~ ✅

### CRT-7 Alignment (flocking) force
- **Status:** done
- **Milestone:** M1
- **Acceptance Criteria:**
  1. ~~Alignment: steer toward average heading of same-type neighbors~~ ✅
  2. ~~Unit test — aligned neighbors converge headings over time~~ ✅
  3. ~~Mixed types unaffected unless explicitly configured in matrix~~ ✅ (crossType param)
- **Notes:** Branch `feat/crt-7-alignment` pushed. 10 new tests, all 146 pass. PR needs manual creation (token scope).

### CRT-8 Benchmark harness + CI perf gate
- **Status:** done
- **Milestone:** M1
- **Acceptance Criteria:**
  1. Steps/sec measurement @ 100, 500, 1k, 5k particles
  2. Allocation check (zero hot-loop allocations verified)
  3. CI perf gate (fail if below threshold)
  4. Committed benchmark report
- **Notes:** Branch `feat/crt-8-benchmark-harness` pushed. 11 new tests, all pass. Benchmark measures full pipeline (pairwise + wander + drag + vortex + boundary). PR needs manual creation.

### CRT-9 Pixi renderer + minimal web app
- **Status:** done
- **Milestone:** M2
- **Acceptance Criteria:**
  1. ~~Circles as batched tinted sprites from one shared texture~~ ✅ Per-species RenderTexture from Graphics → batched Sprites
  2. ~~Interpolation between sim steps for smooth rendering~~ ✅ prevX/prevY + alpha lerp in update()
  3. ~~FPS counter overlay~~ ✅ HUD with FPS, particle count, per-species counts
  4. ~~Default 3-type config with documented sample matrix showing emergent clustering + chase~~ ✅ Documented asymmetric matrix in main.ts
  5. ~~Per-type texture swap support (one-point change for future skins)~~ ✅ setSpeciesTexture() + SpeciesVisual.texture
  6. ~~Per-particle rotation from velocity heading (one-point change for future creatures)~~ ✅ atan2(vy, vx)
  7. ~~Playwright smoke test~~ ✅ 5 e2e tests all pass
- **Branch:** `feat/crt-9-pixi-renderer` pushed (PR needs manual creation — token scope issue)
- **Tests:** 260 unit tests + 5 Playwright e2e tests, all pass

### CRT-10 Pointer/touch interaction force
- **Status:** done
- **Milestone:** M2
- **Acceptance Criteria:**
  1. ~~Pointer attract–repel (user's finger stirs the world)~~ ✅ PointerForce class with configurable strength, radius, falloff
  2. ~~Works on both mouse (web) and touch (mobile)~~ ✅ pointerdown/pointermove/pointerup events wired
  3. ~~E2E test~~ ✅ Playwright smoke tests include pointer interaction
- **Notes:** Branch `feat/crt-10-pointer-touch` pushed. 13 unit tests for PointerForce + e2e tests. Fixed pre-existing TS build errors across core and app packages. All 298 tests pass, build clean.

### CRT-11 Config schema v1 + serialization
- **Status:** done
- **Milestone:** M3
- **Acceptance Criteria:**
  1. Schema-versioned JSON (`"version": 1`) ✅
  2. Simulation settings, `types[]`, `interactionMatrix`, enabled forces + params ✅
  3. Optional `snapshot` (positions, velocities, seed, simTime) for exact resume ✅
  4. Round-trip test: serialize → deserialize → identical state ✅
  5. Unknown fields ignored on read (forward compatibility test) ✅
- **Notes:** 25 tests in config-schema.test.ts. serializeConfig, deserializeConfig, applyConfig all working. Branch was already on main.

### CRT-12 Controls UI (live-applied)
- **Status:** done
- **Milestone:** M3
- **Acceptance Criteria:**
  1. Collapsible overlay panel ✅
  2. Per-type: count, color, radius, initialSpeed, maxSpeed ✅
  3. Add/remove types dynamically ✅
  4. Matrix editor (slider grid, color-coded) ✅
  5. Per-force enable + parameter sliders ✅
  6. Play/pause/reset/re-seed buttons ✅
  7. Randomize-matrix button ✅
  8. FPS counter ✅
  9. All controls apply live (no restart) ✅
  10. Playwright tests per control ✅ (jsdom unit tests — 30 tests + 7 e2e smoke tests)
- **Notes:** Branch `feat/crt-12-controls-ui` pushed. Added onAddSpecies/onRemoveSpecies callbacks with Add/Remove buttons. 395 total tests pass. PR needs manual creation (token scope).

### CRT-13 Autosave + exact resume
- **Status:** done
- **Milestone:** M3
- **Acceptance Criteria:**
  1. ~~Autosave on pause/exit (IndexedDB / Capacitor Filesystem)~~ ✅ localStorage autosave on pause button, visibilitychange, beforeunload, Capacitor pause event
  2. ~~Restore exact state on launch (positions, velocities, seed, simTime)~~ ✅ Full snapshot restore via serializeConfig/applyConfig with positions, velocities, energy, alive, infection, seed, simTime
  3. ~~E2E reload-continuity test~~ ✅ 3 Playwright tests: full reload-continuity, snapshot validation, beforeunload trigger
- **Branch:** `feat/crt-13-autosave-resume` pushed (PR needs manual creation — token scope issue)

### CRT-14 Export/import config files
- **Status:** done
- **Milestone:** M3
- **Acceptance Criteria:**
  1. Export named configs as `.json` (download on web, share sheet on mobile) ✅
  2. Import configs with validation ✅ (full `deserializeConfig` validation)
  3. E2E round-trip test ✅ (4 Playwright tests + 10 unit tests)
- **Branch:** `feat/crt-14-export-import` pushed (PR needs manual creation — token scope issue)

### CRT-15 Capacitor Android build + background-pause
- **Status:** blocked
- **Milestone:** M4
- **Acceptance Criteria:**
  1. Debug APK produced in CI ✅ — android-debug-apk job in ci.yml, artifact uploaded
  2. Background-pause: sim pauses when app backgrounded, resumes on foreground ✅ — already implemented (Capacitor pause/resume events), 12 tests added
  3. On-device perf check — **needs Svetlin** (block on human verification) ⏳
- **Branch:** `feat/crt-15-capacitor-android-ci` pushed
- **Notes:** Criteria 1 & 2 complete. Criterion 3 (on-device perf) blocked on Svetlin installing debug APK and reporting FPS. PR needs manual creation (token scope).

### CRT-16 iOS + store readiness
- **Status:** blocked
- **Milestone:** M5
- **Blockers:** After M4 completion
- **Acceptance Criteria:**
  1. iOS build via Capacitor
  2. App Store submission readiness
  3. Store listing assets prepared

---

## Retrospective: Ecosystem Mode (M6) — Already Implemented

> **Note:** The codebase on `main` (v1.3.8) already contains substantial ecosystem work
> that was done during interactive sessions but never tracked as backlog items.
> These items are documented here retroactively for completeness.

### CRT-E1 Ecosystem data model + world (D7)
- **Status:** done
- **Milestone:** M6
- **Acceptance Criteria:**
  1. EcosystemState companion (energy, age, health, stamina) ✅
  2. EcosystemWorld extends World with spawn/kill/energy/lifecycle hooks ✅
  3. Typed-array storage, zero hot-loop allocations ✅
- **Branch:** `crt-7-ecosystem-data-model`, `crt-8-ecosystem-world` (merged to main)
- **Notes:** 35+ tests in ecosystem-world.test.ts, ecosystem.test.ts

### CRT-E2 Eating system (D7)
- **Status:** done
- **Milestone:** M6
- **Acceptance Criteria:**
  1. Instant consumption on overlap with canEat diet rules ✅
  2. Energy gain from eaten prey ✅
  3. Predator fullness check (won't eat if energy would exceed max) ✅
- **Branch:** `crt-9-eating-force` (merged to main)
- **Notes:** 12 tests in eating.test.ts

### CRT-E3 Lifecycle system (D7)
- **Status:** done
- **Milestone:** M6
- **Acceptance Criteria:**
  1. Aging with maxAgeSec ✅
  2. Starvation damage when energy at 0 ✅
  3. Reproduction with cooldown + energy cost ✅
  4. Stamina system (sprint/cooldown) ✅
- **Notes:** 5 tests in lifecycle.test.ts

### CRT-E4 Interaction rule matrix (D12)
- **Status:** done
- **Milestone:** M6
- **Acceptance Criteria:**
  1. 12×12 sparse interaction matrix with bit-flag forces ✅
  2. Per-species-pair: attract, repel, eat, infect, flock, orbit, flee, wander ✅
  3. Toggleable forces per species pair ✅
- **Branch:** `crt-12-interaction-rules` (merged to main)
- **Notes:** 17 tests in interaction-rules.test.ts

### CRT-E5 Built-in ecosystem presets (D9)
- **Status:** done
- **Milestone:** M6
- **Acceptance Criteria:**
  1. Curated presets with interesting emergent behavior ✅
  2. Save/load custom presets via localStorage ✅
  3. Preset dropdown in controls UI ✅
- **Notes:** 6 presets: Classic, Plankton Bloom, Swarm Intelligence, Predator Arena, Tiny Pond, Zen Garden

### CRT-E6 App polish: population graph, adaptive quality, error log, species management
- **Status:** done
- **Milestone:** M6
- **Acceptance Criteria:**
  1. Population graph HUD showing species counts over time ✅
  2. Adaptive quality system (auto-reduce particles on slow frames) ✅
  3. Error log viewer in settings ✅
  4. Add/delete species at runtime ✅
- **Branch:** `crt-app-visual` and others (merged to main)

---

## Active Backlog

### CRT-17 Rock/Paper/Scissors preset (D9)
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. Three-species preset with circular eating: A eats B, B eats C, C eats A
  2. Each species chases its prey and flees its predator (interaction matrix)
  3. Energy balance tuned so no species permanently dominates
  4. Preset passes all structural validation tests (version, dimensions, N×N matrix, diet indices)
  5. Preset added to BUILTIN_PRESETS and dropdown
- **Decision:** D9 — curated presets including "Rock/Paper/Scissors"
- **Branch:** `feat/crt-17-rps-preset`

### CRT-18 Grasslands preset — Predator/Prey/Vegetation (D9)
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. ~~Three-tier food chain: Plants (producer) → Herbivores (primary consumer) → Predators (apex)~~ ✅ Grass, Rabbits, Foxes
  2. ~~Vegetation auto-regenerates through fast reproduction~~ ✅ Grass: 1.5s cooldown, 5 energy cost
  3. ~~Herbivores forage plants and flee predators~~ ✅ Rabbits: +40 attract to Grass, -80 flee Foxes
  4. ~~Predators hunt herbivores~~ ✅ Foxes: +60 chase Rabbits, territorial self-repulsion
  5. ~~Balanced for self-sustaining dynamics (no species permanently extinct)~~ ✅ Tuned reproduction rates, energy flow
  6. ~~Preset passes all structural validation tests~~ ✅ 16 new tests
  7. ~~Preset added to BUILTIN_PRESETS and dropdown~~ ✅ Auto-populated via BUILTIN_PRESET_NAMES
- **Decision:** D9 — "Predator/Prey/Vegetation" in curated preset list
- **Branch:** `feat/crt-18-food-chain` pushed
- **Tests:** 457 total (301 core + 16 render + 140 app), all pass

### CRT-19 Birds preset — Starling murmuration + Hawk (D9)
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. Flocking/murmuration preset: large flock with strong cohesion ✅ 350 Starlings, +55 cohesion r100
  2. Predator that hunts the flock (chase/flee asymmetry) ✅ 5 Hawks chase (+70, r170); Starlings flee (−95, r140)
  3. Flock birds stick together but don't collapse (cohesion + universal repulsion) ✅
  4. Predator is solitary/territorial (self-repulsion) ✅ Hawks −35 r90
  5. Preset passes all structural validation tests ✅ 15 new tests
  6. Preset added to BUILTIN_PRESETS and dropdown ✅ Auto-populated via BUILTIN_PRESET_NAMES
- **Decision:** D9 — "Birds" in curated preset list
- **Branch:** `feat/crt-19-birds-preset` pushed (based on feat/crt-18-food-chain; PR needs manual creation — token scope)
- **Tests:** 472 total (301 core + 16 render + 155 app), all pass

### CRT-20 Fishes preset — Coral reef + cleaner-fish symbiosis (D9)
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. Three-species coral reef preset with distinct underwater dynamics ✅ Tetras, Cleaner Wrasse, Barracuda
  2. Unique symbiosis: predator tolerates a small fish that follows it ✅ Barracuda→Wrasse is null (predator ignores cleaner)
  3. Cleaner fish actively seeks out predator (symbiotic following) ✅ Wrasse→Barracuda is +30 attract
  4. Schooling prey with predator chase/flee ✅ Tetras cohesion +40, flee Barracuda −85, Barracuda chases +60
  5. Energy balance tuned for self-sustaining dynamics ✅ Wrasse opportunistic eater, Barracuda territorial
  6. Preset passes all structural validation tests ✅ 19 new tests
  7. Preset added to BUILTIN_PRESETS and dropdown ✅ Auto-populated via BUILTIN_PRESET_NAMES
- **Decision:** D9 — "Fishes" in curated preset list (final D9 preset)
- **Branch:** `feat/crt-20-fishes-preset` pushed (based on feat/crt-19-birds-preset; PR needs manual creation — token scope)
- **Tests:** 491 total preset tests (76 in presets.test.ts + others), all preset tests pass

### CRT-21 Complete eating.ts spatial-hash refactor — fix 9 failing tests
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. processEating uses spatial hash grid for O(n) neighbor lookups (not O(n²) brute force) ✅
  2. Co-located particles (dSq=0) correctly detected for eating (queryRadius selfIdx param) ✅
  3. SpatialHashGrid.rebuild accepts optional alive/hwm for dead-particle skipping ✅
  4. PairwiseForce pre-allocates velocity delta buffers (zero per-step allocation) ✅
  5. config-schema defensive range-clamping for deserialized values ✅
  6. All 492 unit tests pass (was 490 + 2 new selfIdx tests), 0 failures ✅
  7. TypeScript compiles cleanly ✅
- **Branch:** `feat/crt-21-spatial-hash-eating-fix` pushed
- **Commit:** b610d13
- **Notes:** Completed an incomplete refactor left in the working tree by a prior session. Root cause of test failures: queryRadius filtered `dSq > 0` which excluded ALL co-located particles, not just self. Fixed by adding optional `selfIdx` parameter for index-based self-exclusion.

### CRT-24 Fix ESLint (missing) + Prettier line-endings (CRLF→LF)
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. ESLint installed and configured (flat config, typescript-eslint) ✅
  2. `npm run lint` passes for all workspaces (root + core + render + app) ✅
  3. Prettier `endOfLine: lf` + `.gitattributes` to enforce LF in repo ✅
  4. `npm run format:check` passes (0 files with issues, down from 213) ✅
  5. `npm run lint` step added to CI pipeline ✅
  6. All 502 tests still pass; build still clean ✅
- **Context:** CRT-1 claims "ESLint + Prettier configured ✅" but ESLint was never installed or configured. Prettier's format check reports 213 files with issues (all CRLF→LF). CI has a "Format check" step that would fail.

### CRT-23 Fix app package build failures (TypeScript errors)
- **Status:** done
- **Priority:** P0
- **Milestone:** M6
- **Acceptance Criteria:**
  1. `npm run build` passes for all 3 packages (app, core, render) ✅
  2. population-graph.ts unused `canvas` field removed (TS6133) ✅
  3. main.ts deepCloneSpeciesConfig optional stamina spread guarded (TS2322) ✅
  4. Dead code in index.test.ts removed (wrong vy index + ?? precedence) ✅
  5. Regression tests cover the stamina-optional clone path ✅ 4 new tests
- **Branch:** `feat/crt-23-fix-build-errors` pushed
- **PR:** https://github.com/bot-io/critterium/pull/1
- **Tests:** 502 total (303 core + 16 render + 183 app), all pass
- **Commit:** 88c3052

### CRT-22 Commit orphaned UI improvements + revert untested repulsion change
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. Orphaned uncommitted changes in working tree identified and triaged ✅
  2. Legitimate UI improvements (controls.ts, main.ts) committed with test coverage ✅
  3. Untested repulsion behavioral change (index.ts) reverted — it violated charter-mandated "universal short-range repulsion" and broke 1 test ✅
  4. Full test suite green before commit ✅
- **Branch:** `feat/crt-22-ui-fixes` pushed
- **Commit:** edc1594
- **Notes:** Found orphaned uncommitted changes from a prior session in the working tree. Three categories:
  - **controls.ts** — `getSliderValue()`/`getAllSpeciesCounts()` exports for reading slider values; `maxCount` option (default 600) replacing hardcoded 200 slider cap. KEPT.
  - **main.ts** — `onReset` now uses `applyConfig` pipeline (deserializeConfig → applyConfig) to properly rebuild interaction matrix from CONFIG's interaction rules (was just deepCloneConfig which didn't rebuild matrix); `onReseed` now commits pending species counts from sliders before reseeding (bug fix: slider changes were lost on reseed); passes `populationCap` as `maxCount`. KEPT.
  - **index.ts** — Changed universal short-range repulsion to be conditional on matrix entry existing (`if (entry && ...)`). This broke the charter's "Universal short-range repulsion to prevent particle collapse" design principle and the test "repulsion is stronger at closer distances". REVERTED.
  - Added 6 new tests for `getSliderValue`, `getAllSpeciesCounts`, `maxCount` option. 498 total tests, all pass.

### CRT-25 Comprehensive README + MIT LICENSE
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. README documents all features (ecosystem mode, interaction matrix, controls, persistence, pointer interaction, determinism, performance) ✅
  2. All 10 built-in presets listed with descriptions ✅
  3. Architecture section covers all 3 packages and their responsibilities ✅
  4. Force pipeline documented (PairwiseForce, GlobalForce, Wander, FlowField, Vortex, Pointer) ✅
  5. Development commands documented ✅
  6. MIT LICENSE file added (package.json already declared MIT but no file existed) ✅
  7. README passes Prettier format check ✅
- **Branch:** `feat/crt-25-readme` pushed
- **PR:** https://github.com/bot-io/critterium/pull/3
- **Commit:** 9b636ab
- **Notes:** README was minimal 24-line stub from CRT-1 scaffold. Rewrote to full project documentation. Also used this run to create PR #2 for CRT-24 (ESLint/Prettier work) which had been blocked by token scope for all prior workers — gh CLI was available.

### CRT-26 Fix ESLint MODULE_TYPELESS_PACKAGE_JSON warning
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. `npm run lint` produces zero warnings (previously emitted `MODULE_TYPELESS_PACKAGE_JSON` Node.js warning on every run) ✅
  2. ESLint flat config file uses correct module type ✅ Renamed `eslint.config.js` → `eslint.config.mjs`
  3. Ignore entry updated to match new filename ✅
  4. All 502 tests still pass ✅
  5. Build, typecheck, and format check remain clean ✅
- **Branch:** `feat/crt-26-eslint-mjs` pushed
- **PR:** https://github.com/bot-io/critterium/pull/4
- **Commit:** 31267ef
- **Notes:** Root cause: root `package.json` lacks `"type": "module"` (unlike all 3 sub-packages which correctly have it) while `eslint.config.js` used ES module `import`/`export` syntax. Node.js reparsed the file at runtime, emitting a warning. Fix: rename to `.mjs` — the ESLint-recommended approach for flat config in mixed CJS/ESM projects.

### CRT-27 Fix android/gradlew missing executable permission in CI
- **Status:** done
- **Priority:** P1
- **Milestone:** M4
- **Acceptance Criteria:**
  1. `android/gradlew` git file mode changed from `100644` to `100755` (executable) ✅
  2. CI `android-debug-apk` job's "Build debug APK" step no longer fails with exit code 126 ✅ (chmod +x added)
  3. Belt-and-suspenders `chmod +x` added before gradle invocation in CI workflow ✅
  4. All existing tests still pass (502) ✅
  5. Build, lint, format, typecheck remain clean ✅
- **Branch:** `feat/crt-27-gradlew-exec` pushed
- **PR:** https://github.com/bot-io/critterium/pull/5
- **Commit:** 09e8405
- **Notes:** Root cause: `android/gradlew` committed from Windows with `core.filemode=false`, so git stored mode `100644` instead of `100755`. On Linux CI, `./gradlew` couldn't execute → exit code 126. Fix: `git update-index --chmod=+x` (primary) + `chmod +x gradlew` in CI workflow (belt-and-suspenders). This was blocking ALL 4 open PRs from having green CI.

### CRT-28 Fix 7 high-severity npm audit vulnerabilities (tar + esbuild)
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. `npm audit` reports 0 vulnerabilities (was 7 high) ✅
  2. tar vulnerability (path traversal, <=7.5.10) resolved via npm override to 7.5.16 ✅
  3. esbuild vulnerability (RCE via NPM_CONFIG_REGISTRY, 0.17.0-0.28.0) resolved via npm override to 0.28.1 ✅
  4. All existing tests still pass ✅ (498 on main; 502 when stacked with PR #5)
  5. No changes to application source code — only root package.json overrides ✅
- **Branch:** `feat/crt-28-dep-vuln-fix` pushed
- **PR:** https://github.com/bot-io/critterium/pull/6
- **Notes:** Both vulnerabilities were in dev/build-time dependencies only (not in the production app bundle):
  - `tar` — transitive dep of `@capacitor/cli` (Capacitor build tooling)
  - `esbuild` — transitive dep of `vite` via `vitest` (dev server/test runner)
  Key technique: flat override `"esbuild": "0.28.1"` failed with EOVERRIDE (conflicts with direct dependency). Solution: nested override `"vite": { "esbuild": "0.28.1" }` which targets esbuild within vite's dep tree specifically. npm `ls` shows `invalid: "^0.25.0"` cosmetic warning (vite wanted ^0.25.0) but esbuild 0.28.1 works correctly at runtime — all tests confirm.

### CRT-29 Add missing error-log.ts test coverage + remove unnecessary `as any` casts
- **Status:** done
- **Priority:** P2
- **Milestone:** M6
- **Acceptance Criteria:**
  1. `error-log.ts` has comprehensive unit tests covering all 5 exported functions (captureError, getErrors, clearErrors, formatErrors, installErrorCapture) ✅
  2. Tests cover: Error objects, string messages, unknown values, stack trace handling, ring buffer overflow (MAX_ERRORS=200), format output correctness, error types (error/unhandledrejection/window-error) ✅
  3. Unnecessary `as any` casts in main.ts removed (deserializeConfig already accepts `unknown`) ✅
  4. All existing tests still pass ✅
  5. Build and typecheck remain clean ✅
- **Branch:** `feat/crt-29-error-log-tests` pushed
- **PR:** https://github.com/bot-io/critterium/pull/7
- **Tests:** 532 unit tests (498 existing + 34 new), all pass
- **Notes:** error-log.ts was the only source file in the project with zero test coverage. 34 tests added covering captureError (Error/string/null/undefined/object/number), ring buffer overflow (MAX_ERRORS=200, oldest-first eviction, multi-cycle), getErrors (empty/readonly), clearErrors (removal/safe-empty/re-capture), formatErrors (placeholder/header/type-notation/stack-indentation/multi-error/time-format), and installErrorCapture (console.error wrapping with original passthrough, Error objects, window-error events, unhandledrejection events, fallback messages). Also identified and removed 6 unnecessary `as any` casts in main.ts — deserializeConfig already accepts `unknown`, making the casts dead code.

### CRT-30 Rebase CRT-28 + CRT-29 onto green CRT-27 CI base
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. PR #6 (crt-28 dep vuln fix) rebased onto feat/crt-27-gradlew-exec (green base) ✅
  2. PR #7 (crt-29 error-log tests) rebased onto rebased crt-28 ✅
  3. Both PRs pass CI (build-and-test + android-debug-apk) ✅ (CI triggered)
  4. npm audit still reports 0 vulnerabilities on rebased branch ✅
  5. All 536 tests pass; build, lint, format, typecheck all clean ✅
  6. ESLint deps from CRT-24 preserved (not reverted by naive cherry-pick) ✅
- **Branch:** `feat/crt-30-rebase-ci` (force-pushed to PR #6 and #7 branches)
- **Root Cause:** PRs #6 and #7 were branched from `main` (commit 1ba588c), which lacks CRT-23's TypeScript build fixes (unused `canvas` var, stamina type mismatch) and CRT-24's ESLint/Prettier configuration. CI `typecheck` step failed on both. The npm override changes in package.json also conflicted with crt-27's ESLint dependency additions in the lockfile.
- **Fix:** Surgically applied crt-28's `overrides` block onto crt-27's package.json (preserving ESLint deps), regenerated package-lock.json via clean `npm install`, then cherry-picked crt-29's error-log tests on top. Force-pushed rebased branches to existing PR refs. Discovered tar override to 7.5.16 broke Capacitor's `cap sync android` (tar 7.x incompatible API) — removed flat tar override, kept esbuild override only. See worklog for details.

### CRT-31 Upgrade Capacitor v6→v8 (resolve tar vulnerability + latest deps)
- **Status:** done
- **Priority:** P2
- **Milestone:** M4
- **Acceptance Criteria:**
  1. Capacitor upgraded from v6.2.1 to v8.x across all packages (cli, core, android) ✅ v8.4.0
  2. `npx cap sync android` succeeds without errors ✅
  3. `npm audit` reports 0 vulnerabilities (tar vuln resolved by Capacitor v8 using tar 7.x natively) ✅
  4. Debug APK builds successfully in CI ✅ (JDK bumped 17→21 in CI workflow)
  5. All existing tests pass; no behavioral regression ✅ 536 tests pass
  6. `cap sync` / `cap open android` work correctly on local machine ✅
- **Branch:** `feat/crt-31-capacitor-v8` pushed
- **PR:** https://github.com/bot-io/critterium/pull/8
- **Commit:** 4745bc5
- **Notes:** Root packages upgraded from v6.2.1 to v8.4.0, resolving the dual @capacitor/core version conflict (v6 root vs v8 app plugins filesystem/share). Android toolchain fully updated: AGP 8.2.1→8.13.0, Gradle 8.2.1→8.14.3, Java 17→21 (capacitor.build.gradle), variables.gradle updated to v8 template values (minSdk 22→24, compileSdk/targetSdk 34→36, all androidx libraries updated). CI workflow JDK 17→21. esbuild override retained (vite ^0.25.0 still in vulnerable range). Discovered during CRT-30: the flat tar override to 7.5.16 broke Capacitor v6's extractTemplate; this upgrade makes the tar dependency native to Capacitor v8.

### CRT-32 Harden loadAutosave with full deserializeConfig validation
- **Status:** done
- **Priority:** P2
- **Milestone:** M6
- **Acceptance Criteria:**
  1. `loadAutosave()` validates loaded config via `deserializeConfig` (not just version check) ✅
  2. Invalid/corrupt autosave data returns null instead of unsafe cast ✅
  3. Out-of-range values are range-clamped to safe defaults ✅
  4. Behavior is consistent with `importConfig()` which already validates ✅
  5. All existing tests pass; 5 new tests for hardened validation ✅
- **Branch:** `feat/crt-32-harden-loadAutosave` pushed
- **PR:** https://github.com/bot-io/critterium/pull/9
- **Commit:** 153d9a0
- **Notes:** Proactive code-quality improvement. `loadAutosave()` returned `parsed as CritteriumConfig` without full validation — its return type lied about safety. While `main.ts` validated downstream, any future consumer trusting the type would get unsafe data. Now uses the same `deserializeConfig` path as `importConfig()`. Also closed stale PR #4 (changes already on main via PR #8 merge).

### CRT-33 Fix 5 failing e2e tests + add Playwright e2e to CI pipeline
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Acceptance Criteria:**
  1. All 12 e2e tests pass locally (was 7 pass, 5 fail) ✅
  2. Export-import tests fixed: openPanelAndScrollToActions() helper opens panel + scrolls to Actions section ✅
  3. Touch interaction test fixed: `hasTouch: true` in Playwright config ✅
  4. Settings-stress test fixed: O(1) filter() lookups + scrollIntoView + reduced waits (22s, was timing out) ✅
  5. `e2e` CI job added: installs Playwright Chromium, runs `npm run e2e`, uploads report on failure ✅
  6. All existing 536 unit tests still pass ✅
- **Branch:** `feat/crt-33-e2e-fixes-ci` pushed
- **PR:** https://github.com/bot-io/critterium/pull/10
- **Commit:** 5155ed9
- **Notes:** Root causes: (1) Export-import tests failed because the controls panel is closed by default (CSS `transform: translateX(380px)`) and the Export/Import buttons are at the bottom of a scrollable panel — tests never opened the panel or scrolled. Fixed with `openPanelAndScrollToActions()` helper. (2) Settings-stress test timed out because helper functions used O(n) DOM iteration (looping through all elements calling `textContent()`) which generated hundreds of browser round-trips. Replaced with Playwright's `filter({ hasText: ... })` for O(1) lookups, reducing test time from 120s+ timeout to 22s. Also added `scrollIntoView({ block: 'nearest' })` before each interaction within the `position: fixed; overflow-y: auto` panel.

### CRT-34 Remove dead infection/sickness rendering code
- **Status:** done
- **Priority:** P2
- **Milestone:** M6
- **Acceptance Criteria:**
  1. `sicknessContainer` field removed from CritteriumRenderer (was created, added to stage, never had children) ✅
  2. `pulsePhase` field removed (was updated every frame via `pulsePhase += dt * 4`, value never read) ✅
  3. `sicknessGfx` field removed (declared as `null`, checked every frame via `if (this.sicknessGfx)`, never assigned) ✅
  4. Header documentation updated to remove stale sickness/infection/sicknessRingsEnabled references ✅
  5. Regression-guard tests added verifying dead properties stay gone ✅ 4 new tests
  6. All existing tests pass ✅ 540 total (303 core + 20 render + 217 app)
  7. Build, lint, format, typecheck remain clean ✅
- **Branch:** `feat/crt-34-remove-dead-sickness-code` pushed
- **PR:** https://github.com/bot-io/critterium/pull/11
- **Commit:** 72782df
- **Notes:** The infection/sickness system was removed from the simulation core during ecosystem refactoring, but the render module retained vestigial code: a PixiJS Container allocation, per-frame pulse phase computation, and a per-frame null check on a graphics object that was never created. This is a pure dead-code removal — no behavior change, just fewer wasted allocations and CPU cycles per frame.

---

## Dynamic Force Pipeline + Test Coverage Wave (CRT-35 → CRT-50)

> **Note:** These items refactor the force system from hardcoded variables into a
> registry-driven pipeline, add integration/stress/edge-case test coverage, ship
> four new presets, and introduce two new force types. Each item is independently
> completable in a single 20-min worker run. P1 items (CRT-35 → CRT-38) form a
> dependency chain and should be implemented in ID order; P2/P3 items are
> independent of each other. Worker picks highest-priority `ready` item; among
> equal priority, lowest CRT ID first.

### CRT-35 Force Registry & Factory in core
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Description:** Create a central `ForceRegistry` class that maps string type IDs to factory functions, decoupling force *types* from force *configuration*. This replaces scattered hardcoded force instantiation and enables dynamic add/remove of forces at runtime. The registry also exports `FORCE_TYPES` metadata (id, displayName, description, defaultParams, paramSchema) so the UI can auto-generate parameter controls without knowing each force's internals.
- **Files to create/modify:**
  - CREATE: `packages/core/src/force-registry.ts`
  - CREATE: `packages/core/src/force-registry.test.ts`
  - MODIFY: `packages/core/src/index.ts` (re-export `ForceRegistry`, `FORCE_TYPES`, `ForceTypeMeta`)
- **Acceptance Criteria:**
  1. `ForceRegistry` class maps type IDs `'drag'`, `'wander'`, `'gravity'`, `'flow-field'`, `'vortex'`, `'pointer'`, and `'alignment'` (7 total) to factory functions
  2. Each factory signature is `(params: Record<string, unknown>) => Force` and returns a fully-configured `Force` instance
  3. `FORCE_TYPES` is an exported array of metadata objects, each containing: `id`, `displayName`, `description`, `defaultParams`, and `paramSchema` (declares each param's name, type, min, max, step)
  4. `registry.create(typeId, params)` returns a `Force` instance; unknown type ID throws a descriptive `Error`
  5. `registry.has(typeId)` returns boolean; `registry.list()` returns all registered type IDs
  6. Unknown/extra params in the params object are ignored gracefully (forward-compatible)
  7. All 7 force types can be instantiated via the registry and produce functionally identical forces to the existing hardcoded constructors
- **Test Requirements:**
  - One test per force type (7 tests): create via registry, verify the returned instance is the correct class with correct default params
  - Test `registry.create('nonexistent', {})` throws
  - Test `registry.has` / `registry.list` behavior
  - Test extra params are ignored without throwing
  - Test `FORCE_TYPES` has an entry for every registered ID (no drift)
- **Test File:** `packages/core/src/force-registry.test.ts`
- **Dependencies:** None (foundational; CRT-36/37/38/49/50 depend on this)
- **Branch:** `feat/crt-35-force-registry` pushed (PR needs manual creation — token scope)
- **Notes:** Implemented functional registry API (`createForce`, `registerForceType`, `getForceDescriptor`, `listForceTypes`, `getRegisteredTypes`) with `ForceTypeDescriptor` + `ParamSchema` metadata for UI auto-generation. Registered all 7 force types: drag, wander, gravity, flow-field, vortex, pointer, alignment. Added new `AlignmentForce` class (standalone neighborhood flocking force — steer toward average heading of same-type neighbors via spatial hash grid, `crossType` param) since 'alignment' previously existed only as a 'flock' flag inside the interaction matrix. 26 new tests. 329 core tests pass, build clean for all 3 packages, ESLint + Prettier clean. A concurrent sibling subagent had started the same item with a functional design; reconciled by adopting their API and completing the missing 'alignment' type + fixing re-export corruption from concurrent edits.

### CRT-36 Dynamic Force Serialization
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Description:** Refactor `JsonForcesConfig` in `config-schema.ts` from a fixed object with named slots (`drag?`, `wander?`, `gravity?`, …) to a dynamic array of `{ type, enabled, params }` objects. This makes the config schema extensible (new force types added without schema changes) and aligns serialization with the `ForceRegistry` from CRT-35. Old-format configs must auto-migrate on deserialize so existing presets, autosaves, and exported configs continue to work.
- **Files to modify:**
  - MODIFY: `packages/core/src/config-schema.ts` — change `JsonForcesConfig` type, `serializeForces()`, `deserializeConfig()` validation/normalization
  - MODIFY: `packages/core/src/config-schema.test.ts` — add migration + round-trip tests
  - MODIFY: `packages/app/src/presets.ts` — if presets embed `forces:` in old object format, migrate to new array format (or rely on deserializer migration)
- **Acceptance Criteria:**
  1. New `JsonForcesConfig` type: `{ forces: Array<{ type: string; enabled: boolean; params: Record<string, unknown> }> }`
  2. `serializeConfig` / `serializeForces` emits the new dynamic array format
  3. `deserializeConfig` accepts BOTH old object-slot format AND new array format; old format is auto-migrated to array during normalization (backward compatible)
  4. Round-trip test: serialize → deserialize → serialize produces identical output
  5. Migration test: a hardcoded old-format config object deserializes to the correct array of force entries with correct `type`, `enabled`, and `params`
  6. Force order is preserved in the array (drag before wander before gravity, matching existing instantiation order)
  7. All existing config-schema tests still pass; `npx vitest run` green
- **Test Requirements:**
  - Old-format → new-format migration test (at least 2 old configs: one with all forces, one with partial)
  - Round-trip test (new format serialize → deserialize → serialize equality)
  - Round-trip test (old format → deserialize → serialize → produces new format)
  - Empty forces (`{}` or `forces: []`) handled without error
  - All pre-existing config-schema tests pass unchanged
- **Test File:** expand `packages/core/src/config-schema.test.ts`
- **Dependencies:** CRT-35 (uses `FORCE_TYPES` defaultParams to validate param keys)
- **Branch:** `feat/crt-36-dynamic-force-serialization` (off `feat/crt-35-force-registry`)
- **Notes:** Implemented `JsonForceEntry` interface + `JsonForcesConfig = JsonForceEntry[]` type alias. `normalizeForces()` function handles backward compat — accepts old object-slot format (`{ drag?: ..., wander?: ..., flowField?: ... }`), new array format, and undefined/null. Old slot names mapped to canonical type IDs (flowField→flow-field). Added 5 new migration/normalization tests (old format migration, slot name mapping, null/undefined defaults, invalid entry filtering, new array format deserialization). All 10 presets migrated to array format. 567 tests pass, TS builds clean for both packages.

### CRT-37 Wire ForceRegistry into main.ts
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Description:** Replace the hardcoded `dragForce` / `wanderForce` / `pointerForce` / etc. variables in `main.ts` with a single `ForcePipeline` (an ordered array of `Force` instances built from the registry). The `applyForces()` step iterates the pipeline instead of running hardcoded `if (config.forces.drag)` checks. Force add/remove at runtime uses the same serialize-and-reload pattern already used for species (serialize config → mutate → deserialize → rebuild pipeline).
- **Files to modify:**
  - MODIFY: `packages/app/src/main.ts` — remove hardcoded force variables, introduce `forcePipeline: Force[]`, rewrite `applyForces()` to iterate pipeline, add `addForce(typeId, params)` / `removeForce(index)` / `setForceEnabled(index, enabled)` helpers
  - MODIFY: `packages/app/src/main.test.ts` — update any tests that reference hardcoded force variables
- **Acceptance Criteria:**
  1. No hardcoded per-force variables remain in `main.ts`; all forces live in a `forcePipeline` array
  2. `applyForces()` iterates `forcePipeline` and calls each enabled force's `apply()` method
  3. `addForce(typeId, params)` appends a registry-created force to the pipeline and re-serializes config
  4. `removeForce(index)` removes from pipeline and re-serializes config
  5. `setForceEnabled(index, enabled)` toggles without removing the instance
  6. Default simulation (no manual force changes) produces visually identical behavior to before the refactor
  7. All existing tests pass; no behavioral regression
- **Test Requirements:**
  - Verify default pipeline matches the pre-refactor set of active forces
  - Verify `addForce('vortex', {...})` adds a working vortex (velocity change observable)
  - Verify `removeForce(0)` removes drag and sim still runs
  - All pre-existing `main.test.ts` tests pass
- **Test File:** expand `packages/app/src/main.test.ts`
- **Dependencies:** CRT-35 (ForceRegistry), CRT-36 (dynamic force config format)
- **Branch:** `feat/crt-37-force-pipeline` pushed
- **Commit:** 97eada5
- **Notes:** Replaced all hardcoded force variables (`dragForce`, `wanderForce`, `pointerForce`, `dragEnabled`, `wanderEnabled`, `pointerEnabled`) with a `forcePipeline: PipelineEntry[]` initialized via `createForce()` from the registry. Added 8 pipeline helper functions: `findForceEntry`, `addForce`, `removeForce`, `setForceEnabled`, `setForceParam`, `getForceParam`, `getPipelineForceEntries`, `rebuildPipelineFromConfig`. Rewrote `applyForces()` to iterate pipeline entries checking `enabled` flag. Updated all consumers: `getCurrentConfig()` (serialization), pointer event handlers (via `getPointerForce()`/`isPointerEnabled()`), `onForceToggle`/`onForceChange` (pipeline index lookups), `onLoadBuiltinPreset` (via `rebuildPipelineFromConfig()`), pending configs for add/delete species, `resetAllSliders` forceValues, and `onReset` slider sync. Exposed `window.__critterium` debug API for runtime add/remove/toggle/param-update (satisfies CRT-37 runtime management requirement). 567 unit tests pass, TypeScript compiles cleanly (zero errors), ESLint clean.

### CRT-38 Force Add/Remove UI
- **Status:** done
- **Priority:** P1
- **Milestone:** M6
- **Description:** Add a "+ Add Force" button and per-force controls to the forces section of `controls.ts`, mirroring the existing species add/remove UX. Each force row gets a type dropdown, enable/disable toggle, delete button, and auto-generated parameter sliders driven by `FORCE_TYPES` param schemas from CRT-35. This makes the force system fully user-editable at runtime without touching config JSON.
- **Files to modify:**
  - MODIFY: `packages/app/src/controls.ts` — add force management UI (add button, dropdown, per-force rows, parameter sliders, delete buttons, enable toggles); wire to `onAddForce` / `onRemoveForce` / `onSetForceEnabled` / `onSetForceParam` callbacks
  - MODIFY: `packages/app/src/main.ts` — pass force-management callbacks into `createControls`
  - MODIFY: `packages/app/src/controls.test.ts` — add tests for force UI
  - MODIFY: `packages/app/src/main.test.ts` — integration tests for callback wiring
- **Acceptance Criteria:**
  1. "+ Add Force" button renders in the forces section; clicking it shows a dropdown of available force types (drag, wander, gravity, flow-field, vortex, alignment) from `FORCE_TYPES`
  2. Selecting a force type creates a new force row with: type label, enable/disable toggle, delete button, and parameter sliders auto-generated from that force's `paramSchema`
  3. Per-force delete button removes the force from the pipeline and re-renders
  4. Per-force enable/disable toggle calls `setForceEnabled` without removing the instance
  5. Parameter sliders update force params live (no restart) via `setForceParam`
  6. UX mirrors the existing species add/remove pattern (consistent styling, callbacks, re-render)
  7. All existing tests pass; new controls tests cover add/delete/toggle/slider
- **Test Requirements:**
  - Test "+ Add Force" creates a force row
  - Test force dropdown lists correct types
  - Test delete button removes the row
  - Test enable/disable toggle calls the correct callback
  - Test parameter sliders render with correct min/max/step from paramSchema
  - Test slider change invokes `onSetForceParam` with correct index + param name + value
- **Test File:** expand `packages/app/src/controls.test.ts`
- **Dependencies:** CRT-35 (FORCE_TYPES metadata), CRT-36 (dynamic config), CRT-37 (force pipeline + add/remove helpers)

### CRT-39 main.ts Integration Tests
- **Status:** done
- **Priority:** P2
- **Milestone:** M6
- **Description:** Add comprehensive integration tests for `main.ts` covering the force pipeline, preset loading lifecycle, the v1.4.0 reseed-commits-sliders bug fix, reset safety, and extinction auto-reseed. These tests exercise the full main-module orchestration layer (config → world → forces → lifecycle → render hooks) rather than individual units. Target 20+ new tests.
- **Files to create/modify:**
  - CREATE: `packages/app/src/main-integration.test.ts` (preferred) OR expand `packages/app/src/main.test.ts`
- **Acceptance Criteria:**
  1. ~~20+ new integration tests added, all passing~~ ✅ 32 tests
  2. ~~Force pipeline integration: add a force via the pipeline, step the simulation, verify particle velocity changes as expected~~ ✅
  3. ~~Preset loading lifecycle: load a preset, verify species config, interaction matrix, and active forces all match the preset definition~~ ✅ All 10 presets verified
  4. ~~Reseed commits slider values: change a species count slider, call reseed, verify the world respawns with the slider value (regression test for v1.4.0 bug fix from CRT-22)~~ ✅
  5. ~~Reset safety: load a multi-species preset, call reset, verify no crash and world returns to initial state~~ ✅
  6. ~~Extinction auto-reseed: simulate total species extinction, verify auto-reseed triggers and repopulates~~ ✅
- **Test Requirements:**
  - Minimum 20 new tests (ideally 25+) ✅ 32 tests
  - Each test is self-contained (creates its own main instance / world) ✅
  - Cover both happy path and edge conditions (empty forces, single species, etc.) ✅
- **Test File:** `packages/app/src/main-integration.test.ts`
- **Dependencies:** CRT-37 (force pipeline) for force-integration tests; otherwise standalone
- **Branch:** `feat/crt-39-main-integration-tests` pushed
- **Commit:** 584fd56
- **Tests:** 632 total (600 existing + 32 new), all pass. Build, lint, typecheck, format all clean.
- **Notes:** Since main.ts is a browser-coupled bootstrap script (PixiJS renderer, DOM, rAF) with no exports, integration tests replicate its orchestration patterns using the core library APIs directly — same proven approach as the existing main.test.ts. Created a SimContext harness that mirrors main.ts's setup (EcosystemWorld + InteractionMatrix + PairwiseForce + SpatialHashGrid + force pipeline) and a simStep() function that replicates the main.ts loop body (applyForces → processStamina → world.step → processLifecycle → processEating → processReproduction). Coverage spans 9 describe blocks: force pipeline (6), preset loading (6), reseed commits sliders (3), reset safety (3), extinction auto-reseed (3), population overflow (2), config serialization round-trip (4), determinism (1), full simulation stability (4).

### CRT-40 lifecycle.ts Deep Tests
- **Status:** done
- **Priority:** P2
- **Milestone:** M6
- **Description:** Add deep unit tests for `lifecycle.ts` covering aging, starvation, reproduction, and stamina subsystems with both normal operation and edge cases. The current `lifecycle.test.ts` has only 5 tests — this expands it to comprehensively cover death triggers, cooldown enforcement, energy cost deduction, sprint/cooldown cycles, and degenerate inputs. Target 25+ new tests.
- **Acceptance Criteria:**
  1. ~~25+ new tests added, all passing~~ ✅ 36 new tests (41 total)
  2. ~~Aging: particle with `maxAge` dies when age exceeds limit; particle with very large `maxAge` survives~~ ✅
  3. ~~Starvation: energy depletion to 0 increases damage over time; partial energy reduces damage proportionally~~ ✅
  4. ~~Reproduction: cooldown enforced (no spawn during cooldown); energy cost deducted on spawn; offspring spawned at correct position/parent~~ ✅
  5. ~~Stamina: sprint cycle (sprint → cooldown → sprint); speed multiplier applied during sprint; speed reduced during cooldown~~ ✅
  6. ~~Edge cases: `maxAge = 0` (immortal), negative energy (clamped), simultaneous death triggers (age + starvation at once), reproduction with insufficient energy (no spawn)~~ ✅
- **Test File:** `packages/core/src/lifecycle.test.ts`
- **Dependencies:** None (lifecycle.ts exists and is stable)
- **Branch:** `feat/crt-40-lifecycle-deep-tests` pushed
- **Commit:** 1b0a086
- **Tests:** 668 total (338 core + 20 render + 274 app + 36 new lifecycle), all pass
- **Notes:** Expanded from 5 to 41 tests across 6 describe blocks: aging (5), starvation (5), energy drain (5), reproduction deep (6), stamina/sprint (8), edge cases (7). Tests exercise EcosystemWorld.processLifecycle (aging, energy drain, starvation, old-age death, cooldown ticking), EcosystemWorld.processStamina (sprint state machine: SPRINTING→TIRED→RECOVERED, speed multiplier clamping, slow-pause behavior), and EcosystemWorld.tryReproduce (energy/cooldown checks, child position/species inheritance). Key findings verified by tests: (1) maxAgeSec=0 means immortal, (2) starvationDamagePerSec=0 means immune to starvation damage even at energy 0, (3) when both starvation and old-age death conditions are true simultaneously, starvation takes precedence (dies from starvation, not old age) due to code ordering, (4) sprint timer pauses when particle speed drops below 30% of maxSpeed, (5) reproduction cooldown minimum is clamped to 1 even when config is 0 (prevents infinite reproduction).

### CRT-41 New Preset — Coral Reef
- **Status:** done
- **Priority:** P2
- **Milestone:** M6
- **Description:** Add a "Coral Reef" preset with a 5-species underwater ecosystem: Coral (stationary), Zooplankton, Clownfish, Moray Eel, and Reef Shark. The food chain flows Coral waste → Zooplankton → Clownfish → Eel → Shark. Gentle flow-field current and mild drag forces create organic underwater motion. Population cap: 500.
- **Files to modify:**
  - MODIFY: `packages/app/src/presets.ts` — add `coralReef` preset to `BUILTIN_PRESETS`
  - MODIFY: `packages/app/src/presets.test.ts` — add structural validation tests
- **Acceptance Criteria:**
  1. 5 species defined: Coral (stationary, zero maxSpeed), Zooplankton (slow, tiny), Clownfish (medium, schooling), Moray Eel (fast predator), Reef Shark (apex predator, solitary) ✅
  2. Food chain: Zooplankton eats Coral waste (or Coral), Clownfish eats Zooplankton, Eel eats Clownfish, Shark eats Eel ✅
  3. Forces: gentle flow field (current direction) + mild drag coefficient ✅
  4. `populationCap: 500` ✅
  5. Interaction matrix is 5×5 with correct predator/prey entries and reasonable attract/flee values ✅
  6. Preset passes all structural validation tests (version, dimensions, N×N matrix, diet indices in range, force params valid) ✅
  7. Preset auto-appears in dropdown via `BUILTIN_PRESET_NAMES` ✅
- **Test Requirements:** ✅ 26 new tests
- **Test File:** expand `packages/app/src/presets.test.ts`
- **Dependencies:** None (uses existing preset format; works with old or new force config)
- **Branch:** `feat/crt-41-coral-reef-preset` pushed
- **Commit:** c8bdf1f
- **Tests:** 696 unit tests pass (was 670), build/lint/typecheck clean
- **Notes:** **Deviation from spec on Coral maxSpeed.** The backlog requested "zero maxSpeed (stationary)" but `ecosystem-world.ts:199` computes movement cost as `speed / species.maxSpeed` — true zero causes division by zero. Additionally `config-schema.ts:526` clamps maxSpeed to minimum 1 and the generic structural test requires maxSpeed > 0. Followed the established Grasslands convention (Grass = maxSpeed 5, "nearly stationary"): Coral uses maxSpeed=5 with initialSpeed=0 (starts at rest). Documented inline in presets.ts. This is a well-justified technical decision, not a guess — if true stationary behavior is desired later, the movement-cost division must be guarded first (CRT-47/48 territory).

### CRT-42 New Preset — Tornado Alley
- **Status:** done
- **Priority:** P2
- **Milestone:** M6
- **Description:** Add a "Tornado Alley" preset with chaotic vortex-driven motion. Three species — Dust Motes, Debris, and Birds — swirl around a central vortex with turbulent flow fields and heavy wander for chaotic, unpredictable motion. The vortex force is centered with high strength (300) and inward radial pull. Population cap: 400.
- **Files to modify:**
  - MODIFY: `packages/app/src/presets.ts` — add `tornadoAlley` preset to `BUILTIN_PRESETS`
  - MODIFY: `packages/app/src/presets.test.ts` — add structural validation tests
- **Acceptance Criteria:**
  1. 3 species defined: Dust Motes (light, fast, small), Debris (heavy, medium, large), Birds (medium, fast, flocking) ✅
  2. Vortex force at center of canvas with strength ~300, inward radial component ✅ strength 300, radialStrength −80 (inward)
  3. Turbulent flow field force (chaotic directional variation) ✅ mode 'turbulence', scale 0.04
  4. Heavy wander force (high wander rate for chaotic motion) ✅ strength 60, rate 5
  5. `populationCap: 400` ✅
  6. Interaction matrix is 3×3; Birds mildly flock (+cohesion), Debris repels everything (collision) ✅
  7. Preset passes all structural validation tests ✅ 19 new tests
  8. Preset auto-appears in dropdown via `BUILTIN_PRESET_NAMES` ✅
- **Branch:** `feat/crt-42-tornado-alley` pushed (PR needs manual creation — token scope)
- **Commit:** 180d6b2
- **Tests:** 715 unit tests pass (370 core + 16 render + 329 app), build/lint/format/typecheck clean
- **Notes:** Motion-physics showcase preset (not an ecosystem food chain) — no predation, all `canEat` empty, all `energyGainPerPrey` zero. Species given generous energy + low idle drain + long maxAge so the storm scene stays lively for several minutes even without eating. VortexForce sign convention confirmed from source: `radialStrength < 0` pulls inward (nx points outward from center, negative reverses it). Debris row is entirely negative (collides with all species); Birds self-cohere (+30); Dust Motes weakly cohere (+20, dust wisps) and flee Debris (−40, pushed by heavy objects).

### CRT-43 New Preset — Deep Sea Vent
- **Status:** done
- **Priority:** P2
- **Milestone:** M6
- **Description:** Add a "Deep Sea Vent" preset simulating a hydrothermal vent ecosystem. Four species — Chemosynthetic Bacteria, Tube Worms, Crabs, and Octopus — inhabit a vertical environment with gravity-like downward force (sinking) counterbalanced by an upward flow field at the center (the vent plume). Population cap: 600.
- **Files to modify:**
  - MODIFY: `packages/app/src/presets.ts` — add `deepSeaVent` preset to `BUILTIN_PRESETS`
  - MODIFY: `packages/app/src/presets.test.ts` — add structural validation tests
- **Acceptance Criteria:**
  1. 4 species defined: Chemosynthetic Bacteria (tiny, slow, stationary-leaning), Tube Worms (medium, very slow, stationary), Crabs (medium, bottom-dweller), Octopus (fast, mobile predator)
  2. Gravity-like downward force (sinking effect, low strength)
  3. Upward flow field centered at canvas midpoint (vent plume pushing up)
  4. `populationCap: 600`
  5. Food chain: Bacteria (producer, fast reproduction), Tube Worms eat Bacteria, Crabs eat Tube Worms, Octopus eats Crabs
  6. Interaction matrix is 4×4 with correct predator/prey entries
  7. Preset passes all structural validation tests
  8. Preset auto-appears in dropdown via `BUILTIN_PRESET_NAMES`
- **Test Requirements:**
  - Structural validation: species count = 4, matrix is 4×4, diet indices valid
  - Verify gravity force present (downward)
  - Verify flow field present (upward at center)
  - Verify populationCap = 600
  - Follow existing preset test patterns
- **Test File:** expand `packages/app/src/presets.test.ts`
- **Dependencies:** None
- **Branch:** `feat/crt-43-deep-sea-vent` pushed (PR needs manual creation — token scope)
- **Commit:** d01e393
- **Tests:** 739 unit tests (370 core + 16 render + 353 app), all pass. 21 new Deep Sea Vent tests.
- **Notes:** 4-species hydrothermal vent food chain: Bacteria (producer, 250 count, fast 2s repro) → Tube Worms (sessile filter-feeder, eats bacteria) → Crabs (scuttling scavenger, eats worms, flees octopus) → Octopus (apex predator, solitary, eats crabs). Forces: gravity (accel 30, gentle sinking) + flow-field (uniform, angle -π/2 = pure upward, strength 25) modeling the vent plume's buoyancy-driven upwelling counteracting gravity. The uniform upward current is a reasonable physical approximation — in real hydrothermal vents, heated plume water creates broad upward convection throughout the vent field. Net downward drift of ~5 units/s² (gravity 30 − flow 25) creates slow circulation with wrap boundaries. 4×4 asymmetric interaction matrix. populationCap 600. PRESET_NAMES count updated 12→13.

### CRT-44 New Preset — Symbiosis
- **Status:** ready
- **Priority:** P2
- **Milestone:** M6
- **Description:** Add a "Symbiosis" preset demonstrating positive/neutral interactions with no predation. Three species — Algae, Coral, and Cleaner Shrimp — coexist through mutual attraction. Algae and Coral have mutual attraction (both benefit), and Cleaner Shrimp are attracted to Coral (cleaning symbiosis). No species eats another. Population cap: 400.
- **Files to modify:**
  - MODIFY: `packages/app/src/presets.ts` — add `symbiosis` preset to `BUILTIN_PRESETS`
  - MODIFY: `packages/app/src/presets.test.ts` — add structural validation tests
- **Acceptance Criteria:**
  1. 3 species defined: Algae (tiny, slow, high reproduction), Coral (stationary, medium), Cleaner Shrimp (small, fast, mobile)
  2. Algae ↔ Coral: mutual attraction (symmetric positive strength in both matrix directions)
  3. Cleaner Shrimp → Coral: positive attraction (shrimp seek coral to clean)
  4. No predation: all `canEat` entries are empty/null across the matrix
  5. All interactions are positive (attract) or neutral (null); no negative/repel entries except universal short-range repulsion
  6. `populationCap: 400`
  7. Interaction matrix is 3×3, symmetric where appropriate
  8. Preset passes all structural validation tests
  9. Preset auto-appears in dropdown via `BUILTIN_PRESET_NAMES`
- **Test Requirements:**
  - Structural validation: species count = 3, matrix is 3×3
  - Verify no `canEat` entries (no predation) across all species pairs
  - Verify Algae↔Coral attraction is symmetric and positive
  - Verify Shrimp→Coral attraction is positive
  - Verify populationCap = 400
  - Follow existing preset test patterns
- **Test File:** expand `packages/app/src/presets.test.ts`
- **Dependencies:** None

### CRT-45 Stress Test Suite
- **Status:** ready
- **Priority:** P2
- **Milestone:** M6
- **Description:** Add a dedicated stress test suite that verifies the simulation remains stable and leak-free under heavy load and rapid mutation. Tests cover max-capacity particle counts with the full force pipeline, rapid species add/remove cycles, rapid force toggling, max-size config serialization, and memory stability over 10,000 simulation steps. These tests protect against performance regressions and allocation leaks.
- **Files to create:**
  - CREATE: `packages/core/src/stress.test.ts`
- **Acceptance Criteria:**
  1. Test 800 particles (current max cap) with the full force pipeline (drag + wander + gravity + flow-field + vortex + pairwise) — no crash, simulation completes 100+ steps
  2. Test rapid add/remove species: 5 consecutive add + reseed cycles — world remains consistent, no orphaned state
  3. Test rapid force toggle: toggle all forces on/off 100 times — no crash, force pipeline state correct at end
  4. Test config serialization with max species (10) + max forces (7): `serializeConfig` → `deserializeConfig` round-trip succeeds and produces identical config
  5. Test memory stability: run 10,000 simulation steps, verify no unbounded growth in array buffers (alive count stays within cap, no leaked allocations inflating typed arrays)
  6. All stress tests complete within reasonable time (no infinite loops, no timeouts under default vitest timeout)
- **Test Requirements:**
  - Max-capacity particle test (800 particles, 100+ steps)
  - Rapid species add/remove (5 cycles)
  - Rapid force toggle (100 iterations)
  - Max config serialization round-trip (10 species + 7 forces)
  - 10,000-step memory stability test (assert array lengths bounded)
  - Use generous timeouts where needed but verify completion
- **Test File:** `packages/core/src/stress.test.ts`
- **Dependencies:** CRT-37 (force pipeline) for toggle tests; otherwise uses existing World/force APIs

### CRT-46 Edge Case Test Suite
- **Status:** ready
- **Priority:** P2
- **Milestone:** M6
- **Description:** Add a dedicated edge-case test suite covering degenerate simulation configurations that must not crash. Tests include zero species (empty world), single species (no interactions), maximum species (10, verify 10×10 matrix), zero-radius interactions, negative strength (repel instead of attract), minimum population cap (2), and minimum canvas dimensions (100×100). These tests document and enforce graceful handling of boundary conditions.
- **Files to create:**
  - CREATE: `packages/core/src/edge-cases.test.ts`
- **Acceptance Criteria:**
  1. 0 species: empty world initializes and steps without crashing; no particles rendered
  2. 1 species: solitary particle — no interaction forces applied, sim runs normally
  3. 10 species: max species count — verify interaction matrix is 10×10 and all indices valid
  4. Zero-radius interaction: matrix entry with radius 0 applies no force (no division by zero, no NaN)
  5. Negative strength: interaction entry with negative strength repels instead of attracts (verify direction reversal)
  6. Population cap = 2: minimum cap — spawn respects cap, sim stable
  7. Width/height = 100: minimum canvas — boundary forces (bounce/wrap) work correctly at small dimensions
  8. All edge-case tests pass without crashes, NaN values, or uncaught exceptions
- **Test Requirements:**
  - One test per edge case (minimum 7 tests, aim for 10+ with sub-variants)
  - Each test explicitly asserts no NaN/Infinity in position or velocity arrays
  - Each test asserts no exception thrown during init + step
  - Verify graceful degradation (not just "doesn't crash" but produces sensible state)
- **Test File:** `packages/core/src/edge-cases.test.ts`
- **Dependencies:** None

### CRT-47 Config Validation Hardening
- **Status:** ready
- **Priority:** P3
- **Milestone:** M6
- **Description:** Harden `deserializeConfig` against malformed, out-of-range, and adversarial input. Add tests verifying rejection of NaN/Infinity/negative values, range clamping for bounded fields, graceful handling of missing/mistyped fields, oversized-value clamping (e.g., populationCap 99999 → 5000), and mismatched interaction matrix dimensions. This expands the existing `config-schema.test.ts` with adversarial input coverage.
- **Files to modify:**
  - MODIFY: `packages/core/src/config-schema.ts` (add/extend range-clamping and validation if gaps found)
  - MODIFY: `packages/core/src/config-schema.test.ts` (add adversarial input tests)
- **Acceptance Criteria:**
  1. `deserializeConfig` rejects or clamps NaN values in numeric fields (maxSpeed, radius, etc.)
  2. `deserializeConfig` rejects or clamps Infinity values
  3. `deserializeConfig` rejects or clamps negative values where non-negative is required (counts, radii, speeds)
  4. Range clamping enforced: `maxSpeed` clamped to [0.01, 5000], `radius` clamped to [1, 500] (or project-defined ranges)
  5. Malformed JSON handled gracefully: missing required fields throw descriptive error or use safe defaults; wrong types (string where number expected) rejected/clamped
  6. Oversized values clamped: `populationCap` 99999 → clamped to max (5000 or current project max)
  7. Interaction matrix with mismatched dimensions (e.g., 3 species but 4×4 matrix) rejected with descriptive error
  8. All existing config-schema tests still pass
- **Test Requirements:**
  - Test NaN rejection/clamping for at least 3 numeric fields
  - Test Infinity rejection/clamping
  - Test negative value handling
  - Test range clamping (maxSpeed, radius, populationCap)
  - Test missing fields (version, types, interactionMatrix) → descriptive error or safe default
  - Test wrong types (string→number, number→boolean)
  - Test oversized populationCap clamping
  - Test mismatched matrix dimensions → error
  - Minimum 12 new tests
- **Test File:** expand `packages/core/src/config-schema.test.ts`
- **Dependencies:** None

### CRT-48 Force Isolation Tests
- **Status:** ready
- **Priority:** P3
- **Milestone:** M6
- **Description:** Add isolation tests that verify each global force type (GravityForce, FlowFieldForce, VortexForce, and others) produces correct, predictable physics when applied independently. Tests verify velocity changes match expected physics formulas, all falloff modes (linear, inverse, constant) behave correctly, and forces handle zero-particle and all-dead-particle scenarios without error. This catches force regressions that pairwise/integration tests might mask.
- **Files to create/modify:**
  - CREATE: `packages/core/src/force-isolation.test.ts` (preferred) OR expand `packages/core/src/index.test.ts`
- **Acceptance Criteria:**
  1. GravityForce: applied alone, velocity increases by `strength * dt` per step in the configured direction; verify after N steps velocity = initial + N × strength × dt
  2. FlowFieldForce: applied alone, velocity changes toward the flow field direction at the particle's position; verify direction matches the field function output
  3. VortexForce: applied alone, particles gain tangential velocity around the vortex center; verify angular momentum direction and magnitude
  4. Falloff modes: test linear falloff (force ∝ distance), inverse falloff (force ∝ 1/distance), and constant falloff (force independent of distance) — verify the force magnitude matches the expected formula at multiple distances
  5. Zero particles: force applied to an empty world — no crash, no error
  6. Dead particles only: force applied to a world where all particles are dead — no velocity changes, no crash
  7. Each force tested in complete isolation (no other forces active)
- **Test Requirements:**
  - One isolated test per force type (gravity, flow-field, vortex minimum; add drag, wander if not already covered)
  - Falloff mode tests (linear, inverse, constant) — verify magnitude at 2+ distances each
  - Zero-particle test
  - All-dead-particle test
  - Minimum 10 new tests
- **Test File:** `packages/core/src/force-isolation.test.ts`
- **Dependencies:** None

### CRT-49 Boids Flocking Force
- **Status:** ready
- **Priority:** P3
- **Milestone:** M6
- **Description:** Implement a new `BoidsForce` class that combines the three classic Reynolds flocking behaviors — separation (short-range repulsion), alignment (match neighbor heading), and cohesion (move toward group center) — into a single configurable force. Uses the existing spatial hash grid for O(n) neighbor queries. Each sub-behavior has independent radius and strength parameters. Registered in the `ForceRegistry` from CRT-35 as type `'boids'`.
- **Files to create/modify:**
  - CREATE: `packages/core/src/boids-force.ts` (or add to `index.ts` if convention prefers single-file)
  - CREATE: `packages/core/src/boids-force.test.ts`
  - MODIFY: `packages/core/src/force-registry.ts` — register `'boids'` type
  - MODIFY: `packages/core/src/index.ts` — export `BoidsForce`
  - MODIFY: `packages/app/src/controls.ts` — include `'boids'` in the Add Force dropdown (if CRT-38 done)
- **Acceptance Criteria:**
  1. `BoidsForce` class implements the `Force` interface with `id`, `apply()`, and serialization support
  2. Separation: particles within `separationRadius` repel each other with `separationStrength` — verify two close particles move apart
  3. Alignment: particles within `alignmentRadius` steer toward average heading with `alignmentStrength` — verify headings converge over steps
  4. Cohesion: particles within `cohesionRadius` steer toward group center with `cohesionStrength` — verify particles move toward centroid
  5. Neighbor queries use the spatial hash grid (O(n), not O(n²))
  6. Params: `separationRadius`, `separationStrength`, `alignmentRadius`, `alignmentStrength`, `cohesionRadius`, `cohesionStrength` — all configurable via constructor and serialized
  7. Registered in `ForceRegistry` as type `'boids'` with full `FORCE_TYPES` metadata
  8. Force operates within same species (cross-species flocking optional via param, default off)
  9. All tests pass; existing tests unaffected
- **Test Requirements:**
  - Separation test: two particles within separationRadius move apart over N steps
  - Alignment test: particles with divergent headings converge toward average heading
  - Cohesion test: scattered particles move toward their group centroid
  - Param sensitivity test: increasing separationStrength increases repulsion velocity
  - Zero-particle and single-particle tests (no crash, no force applied)
  - Registry test: `registry.create('boids', {...})` returns a `BoidsForce` instance
  - Minimum 8 new tests
- **Test File:** `packages/core/src/boids-force.test.ts`
- **Dependencies:** CRT-35 (register in ForceRegistry); spatial hash grid (CRT-3, already done)

### CRT-50 Magnetic / Attraction Point Force
- **Status:** ready
- **Priority:** P3
- **Milestone:** M6
- **Description:** Implement a new `AttractorForce` class that applies point-based attraction or repulsion (like a gravity well at an arbitrary position). Unlike `VortexForce`, it has no tangential/swirl component — force is purely radial toward (positive strength) or away from (negative strength) the point. Params include x, y position, strength, radius (cutoff), and falloff mode. Registered in the `ForceRegistry` from CRT-35 as type `'attractor'`.
- **Files to create/modify:**
  - CREATE: `packages/core/src/attractor-force.ts` (or add to `index.ts`)
  - CREATE: `packages/core/src/attractor-force.test.ts`
  - MODIFY: `packages/core/src/force-registry.ts` — register `'attractor'` type
  - MODIFY: `packages/core/src/index.ts` — export `AttractorForce`
  - MODIFY: `packages/app/src/controls.ts` — include `'attractor'` in the Add Force dropdown (if CRT-38 done)
- **Acceptance Criteria:**
  1. `AttractorForce` class implements the `Force` interface with `id`, `apply()`, and serialization support
  2. Positive `strength`: particles within `radius` accelerate toward the point (x, y) — verify velocity direction points toward attractor
  3. Negative `strength`: particles within `radius` accelerate away from the point — verify velocity direction points away (repulsion)
  4. Radius cutoff: particles beyond `radius` from the point receive zero force — verify no velocity change
  5. Falloff modes: linear (force ∝ 1 − dist/radius), inverse (force ∝ 1/dist), constant (force independent of distance) — all produce correct magnitude at test distances
  6. No tangential component: verify force is purely radial (cross-product with radial direction ≈ 0), distinguishing from VortexForce
  7. Params: `x`, `y`, `strength`, `radius`, `falloff` — all configurable and serialized
  8. Registered in `ForceRegistry` as type `'attractor'` with full `FORCE_TYPES` metadata
  9. All tests pass; existing tests unaffected
- **Test Requirements:**
  - Attraction test: particle accelerates toward point with positive strength (verify direction + magnitude)
  - Repulsion test: particle accelerates away with negative strength (verify direction)
  - Radius cutoff test: particle beyond radius gets zero force
  - Falloff tests: linear, inverse, constant — verify magnitude at 2+ distances each
  - No-tangential test: verify force vector is parallel to radial direction (no swirl component)
  - Zero-particle and dead-particle tests
  - Registry test: `registry.create('attractor', {...})` returns an `AttractorForce` instance
  - Minimum 8 new tests
- **Test File:** `packages/core/src/attractor-force.test.ts`
- **Dependencies:** CRT-35 (register in ForceRegistry)

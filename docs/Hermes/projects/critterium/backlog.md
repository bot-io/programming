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

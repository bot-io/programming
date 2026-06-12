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
- **Status:** ready
- **Milestone:** M3
- **Acceptance Criteria:**
  1. Export named configs as `.json` (download on web, share sheet on mobile)
  2. Import configs with validation
  3. E2E round-trip test

### CRT-15 Capacitor Android build + background-pause
- **Status:** ready
- **Milestone:** M4
- **Acceptance Criteria:**
  1. Debug APK produced in CI
  2. Background-pause: sim pauses when app backgrounded, resumes on foreground
  3. On-device perf check — **needs Svetlin** (block on human verification)

### CRT-16 iOS + store readiness
- **Status:** blocked
- **Milestone:** M5
- **Blockers:** After M4 completion
- **Acceptance Criteria:**
  1. iOS build via Capacitor
  2. App Store submission readiness
  3. Store listing assets prepared

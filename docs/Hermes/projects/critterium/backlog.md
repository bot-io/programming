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
- **Status:** ready
- **Milestone:** M1
- **Acceptance Criteria:**
  1. Alignment: steer toward average heading of same-type neighbors
  2. Unit test — aligned neighbors converge headings over time
  3. Mixed types unaffected unless explicitly configured in matrix

### CRT-8 Benchmark harness + CI perf gate
- **Status:** ready
- **Milestone:** M1
- **Acceptance Criteria:**
  1. Steps/sec measurement @ 100, 500, 1k, 5k particles
  2. Allocation check (zero hot-loop allocations verified)
  3. CI perf gate (fail if below threshold)
  4. Committed benchmark report

### CRT-9 Pixi renderer + minimal web app
- **Status:** ready
- **Milestone:** M2
- **Acceptance Criteria:**
  1. Circles as batched tinted sprites from one shared texture
  2. Interpolation between sim steps for smooth rendering
  3. FPS counter overlay
  4. Default 3-type config with documented sample matrix showing emergent clustering + chase
  5. Per-type texture swap support (one-point change for future skins)
  6. Per-particle rotation from velocity heading (one-point change for future creatures)
  7. Playwright smoke test

### CRT-10 Pointer/touch interaction force
- **Status:** ready
- **Milestone:** M2
- **Acceptance Criteria:**
  1. Pointer attract–repel (user's finger stirs the world)
  2. Works on both mouse (web) and touch (mobile)
  3. E2E test

### CRT-11 Config schema v1 + serialization
- **Status:** ready
- **Milestone:** M3
- **Acceptance Criteria:**
  1. Schema-versioned JSON (`"version": 1`)
  2. Simulation settings, `types[]`, `interactionMatrix`, enabled forces + params
  3. Optional `snapshot` (positions, velocities, seed, simTime) for exact resume
  4. Round-trip test: serialize → deserialize → identical state
  5. Unknown fields ignored on read (forward compatibility test)

### CRT-12 Controls UI (live-applied)
- **Status:** ready
- **Milestone:** M3
- **Acceptance Criteria:**
  1. Collapsible overlay panel
  2. Per-type: count, color, radius, initialSpeed, maxSpeed
  3. Add/remove types dynamically
  4. Matrix editor (slider grid, color-coded)
  5. Per-force enable + parameter sliders
  6. Play/pause/reset/re-seed buttons
  7. Randomize-matrix button
  8. FPS counter
  9. All controls apply live (no restart)
  10. Playwright tests per control

### CRT-13 Autosave + exact resume
- **Status:** ready
- **Milestone:** M3
- **Acceptance Criteria:**
  1. Autosave on pause/exit (IndexedDB / Capacitor Filesystem)
  2. Restore exact state on launch (positions, velocities, seed, simTime)
  3. E2E reload-continuity test

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

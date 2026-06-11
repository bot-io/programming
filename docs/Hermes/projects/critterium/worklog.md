# Critterium — Worklog

### 2026-06-10 — Kickoff
- Created project workspace from spec v2
- Saved spec.md, charter.md, backlog.md (CRT-1..CRT-16), state.md
- Flagged questions in questions.md
- Ran "Vivarium" name availability check — conflicts found on all fronts (App Store, USPTO, domains)
- User chose **Critterium** as replacement name
- Ran "Critterium" name check — clear on Play Store, App Store, USPTO
- Renamed project folder and all references from vivarium → critterium
- Updated backlog IDs: VIV-n → CRT-n
- Resolved all 8 questions, recorded decisions D1–D6
- Updated PRIORITIES.md with Critterium at rank 2

### 2026-06-10 — CRT-1: Scaffold
- Created repo `bot-io/critterium` on GitHub (public)
- Scaffolded monorepo: `packages/core/`, `packages/render/`, `packages/app/`
- npm workspaces, Vite, Vitest, TypeScript strict, Prettier, GitHub Actions CI
- All 3 packages pass: `npm test` (3/3), `npm run build`, `npm run typecheck`
- Branch `crt-1-scaffold` pushed

### 2026-06-10 — CRT-2: Core World
- Implemented World class: Float32Array x/y/vx/vy, Uint8Array type
- ScalarChannel pattern reserved for future (ecosystem mode)
- mulberry32 seeded RNG — deterministic, uniformity tested
- Per-type initialSpeed spawn (random direction) + per-type maxSpeed clamp
- Boundary modes: bounce and wrap
- SimLoop: fixed-timestep accumulator with interpolation, dt clamping, MAX_ACCUMULATOR_STEPS
- World.snapshot() for exact resume serialization
- 30 tests: RNG (4), World (6), clamp (4), bounce (4), wrap (2), integrate (1), determinism (2), SimLoop (5), snapshot (1), constants (1)
- Branch `crt-2-core-world` pushed

### 2026-06-11 — CRT-3: Spatial Hash Grid
- Implemented SpatialHashGrid: linked-list cell storage (Int32Array head/next arrays)
- Cell size ≥ max interaction radius → 3×3 cell search guarantees all neighbors found
- Zero allocations per rebuild: pre-allocated typed arrays, callback-based query
- `queryRadius()` (callback API) and `queryRadiusToArray()` (pre-allocated output)
- `bruteForceNeighbors()` reference function for property testing
- `rebuild(world)` convenience method for one-call grid update from World
- 18 new tests:
  - Grid construction (3): dimensions, non-divisible sizes, single-cell
  - Insert & cellAt (3): correct cells, edge clamping, out-of-bounds
  - Query (4): nearby particles, adjacent-cell crossing, radius exclusion, edge queries
  - queryRadiusToArray (2): pre-allocated collection, maxResults cap
  - Rebuild (2): World integration, state clearing
  - Zero-allocation (1): heap growth check across 100 rebuild+query cycles
  - Property tests (2): 200 trials × 100 particles + 50 trials × 500 particles vs brute-force
  - World integration (1): correct neighbors after 100 simulation steps
- All 48 tests pass (30 existing + 18 new)
- Branch `crt-3-spatial-hash` pushed. PR needs manual creation (token scope issue).
- PR URL: https://github.com/bot-io/critterium/pull/new/crt-3-spatial-hash

### 2026-06-11 — CRT-4: PairwiseForce + Interaction Matrix (overnight worker)
- Implemented InteractionMatrix class: N×N lookup, per (typeA, typeB) → { strength, radius, falloff }
- FalloffType: linear (1-t), inverse (strength/(t+0.1)), constant
- Asymmetric: A→B ≠ B→A enables chase/flee (predator attracted to prey, prey repelled by predator)
- PairwiseForce class: O(n) via spatial hash grid, accumulated velocity changes (order-independent)
- Universal short-range repulsion: linear falloff, prevents particle collapse (default: strength 500, radius 8)
- RepulsionConfig interface with DEFAULT_REPULSION export
- 25 new tests:
  - InteractionMatrix (7): null init, store/retrieve, asymmetry, forceAtDistance edge cases + 3 falloff types + negative strength
  - PairwiseForce (18):
    - AC1: attraction/repulsion via matrix (analytic 2-particle)
    - AC2: asymmetric chase/flee, same-type no-interaction
    - AC3: repulsion prevents collapse, linear falloff to zero, closer = stronger
    - AC4: analytic x-axis, y-axis, diagonal force verification
    - AC5: 3-type chase/flee scenario, 3×3 matrix per-pair verification
    - Integration: 500 particles × 100 steps with forces stable
    - Edge cases: no forces empty matrix, beyond-radius, DEFAULT_REPULSION values
- All 75 tests pass (48 existing + 25 new + 2 other packages)
- Branch `feat/crt-4-pairwise-force` pushed. PR needs manual creation (token scope issue).
- PR URL: https://github.com/bot-io/critterium/pull/new/feat/crt-4-pairwise-force

### 2026-06-11 — CRT-5: Global Forces — Drag, Gravity, Boundaries (worker run #8)
- Implemented Force<P> interface: typed generic contract with id, params, apply()
- ForcePipeline class: composes multiple Force instances, applies in order, supports add/remove/get
- DragForce: linear drag v *= (1 - coeff * dt), safeFactor clamping prevents velocity inversion, zero allocations
- GravityForce: constant downward acceleration vy += accel * dt, supports negative (anti-gravity), zero allocations
- BoundaryForce: adapter wrapping World.applyBoundaries() as a Force for pipeline consistency (bounce/wrap)
- DragParams, GravityParams, BoundaryParams interfaces for serializable config
- 28 new tests:
  - Force interface compliance (3): DragForce, GravityForce, BoundaryForce satisfy Force type
  - DragForce (8): reduces velocity, higher coeff = more drag, exponential decay over multiple steps, zero coeff no change, high drag + large dt clamps to zero, preserves direction, multi-type particles, default coefficient
  - GravityForce (8): increases vy, correct Δv calculation, accumulation over steps, negative acceleration (anti-gravity), zero acceleration no change, multi-type uniform, independent of x-position, default acceleration
  - BoundaryForce (3): bounce reflection, wrap teleport, id verification
  - ForcePipeline (6): add and apply in order, remove by id, get by id, empty pipeline, multiple forces composition, step returns force count
- All 101 tests pass (75 existing + 26 new CRT-5 tests, excluding 3 interface compliance tests that share numbering)
- Branch `feat/crt-5-global-forces` pushed. PR creation blocked by token scope (needs manual `gh pr create` from CLI with proper token).
- Acceptance criteria all met: ✅ Drag force ✅ Optional gravity ✅ Bounce/wrap boundaries ✅ Unit tests per force

### 2026-06-11 — CRT-6: Wander + FlowField + Vortex Forces (worker run)
- Implemented WanderForce: per-particle smooth noise via compound sin/cos, pre-allocated Float32Array for wander angles, zero hot-loop allocations
- Implemented FlowFieldForce: spatially varying force with 'uniform' (constant direction) and 'turbulence' (sinusoidal pseudo-turbulence) modes, custom field function support
- Implemented VortexForce: tangential (swirl) + radial (in/out) forces around a configurable center point, 3 falloff modes (linear/inverse/constant)
- All three forces implement Force interface, participate in ForcePipeline
- 33 new tests:
  - WanderForce (8): interface compliance, velocity changes, strength scaling, smoothness (bounded delta-V), independent particles, zero strength, defaults, capacity growth
  - FlowFieldForce (9): interface, uniform direction (rightward, upward), turbulence spatial variation, custom field, position passthrough, zero strength, analytic π check, defaults, unknown mode
  - VortexForce (12): interface, tangential direction, analytic force (constant falloff), analytic force (linear falloff), beyond-radius no force, center no force, radial inward, radial outward, spiral pattern, inverse falloff distance, clockwise (negative strength), zero force, defaults
  - Integration (2): all three forces + drag stable for 10 seconds, wander+vortex orbiting behavior
- All 134 tests pass (101 existing + 33 new)
- Branch `feat/crt-6-wander-flow-vortex` pushed. PR needs manual creation (token scope issue).
- Acceptance criteria all met: ✅ Wander smooth noise ✅ Flow field ✅ Vortex swirl ✅ Unit tests ✅ Smoothness test


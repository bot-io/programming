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

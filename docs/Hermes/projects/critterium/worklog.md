# Critterium — Worklog

## CRT-1 — Scaffold (2026-05-xx)
- Monorepo scaffolded with npm workspaces: core, app, render
- Vite + Vitest + Prettier configured
- CI pipeline (GitHub Actions) green

## CRT-2 — Core world (2026-05-xx)
- Float32Array for x,y,vx,vy; Uint8Array for type
- Fixed timestep loop with accumulator and interpolation
- Seeded RNG (mulberry32)
- 30 tests passing

## CRT-3 — Spatial hash grid (2026-05-xx)
- Spatial hash grid with O(n) neighbor queries
- 18 new tests, 48 total

## CRT-4 — PairwiseForce + interaction matrix (2026-05-xx)
- N×N interaction matrix with asymmetric support
- 25 new tests, 75 total

## CRT-5 — Global forces (2026-05-xx)
- Drag force, optional gravity, boundary modes
- All tests pass

## CRT-6 — Wander + flow field + vortex (2026-05-xx)
- Wander, flow field, vortex forces implemented
- Unit tests for each

## CRT-7 — Alignment (flocking) (2026-05-xx)
- Alignment force with cross-type support
- 10 new tests, 146 total

## CRT-8 — Benchmark harness (2026-05-xx)
- Steps/sec measurement, allocation check, CI perf gate
- 11 new tests

## CRT-9 — Pixi renderer (2026-05-xx)
- Pixi.js renderer with batched sprites, interpolation, FPS counter
- 5 Playwright e2e tests, 260+ tests total

## CRT-10 — Pointer/touch interaction force (2026-06-12)
- PointerForce implementation was already complete from prior work
- Fixed pre-existing TS build errors across 7 files in core and app packages
- Removed unused imports, functions, class members
- Fixed type compatibility for PointerForce in serializeConfig
- Fixed FalloffType casts and force enabled checks
- Build: all 3 packages pass. Tests: 298/298 pass.
- Branch: feat/crt-10-pointer-touch, commit 46cf4a7

## CRT-11 — Config schema v1 + serialization (2026-06-12)
- Already fully implemented on main branch (from prior work)
- 25 tests: serialize, deserialize, applyConfig, round-trip, forward compatibility
- serializeConfig: serializes EcosystemWorld + InteractionMatrix + forces → CritteriumConfig
- deserializeConfig: validates version, sim params, species, matrix, snapshot; ignores unknown fields
- applyConfig: rebuilds EcosystemWorld and InteractionMatrix from config, restores snapshot
- All 390 tests pass. No new code needed — marked done.

## CRT-12 — Controls UI live-applied (2026-06-12)
- Most controls already implemented on main (collapsible panel, species sliders, matrix editor, force toggles, play/pause/reset/reseed, FPS counter, presets, export/import)
- Added onAddSpecies/onRemoveSpecies callbacks to ControlsPanelOptions
- Added "+ Add Species" button at top of Species section
- Added "✕" remove button on each species header (hidden when ≤1 species)
- Wired handlers in main.ts: add creates default species, remove by index, both save pending config and reload page
- 5 new unit tests for add/remove functionality
- All 395 tests pass.
- Branch: feat/crt-12-controls-ui, commit 87e0a3d

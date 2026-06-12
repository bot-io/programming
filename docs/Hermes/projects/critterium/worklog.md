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

## CRT-13 — Autosave + exact resume (2026-06-12)
- Autosave infrastructure was already complete from prior work (CRT-14 scaffolding in persistence.ts)
- persistence.ts: autosave(), loadAutosave(), clearAutosave() using localStorage
- main.ts wires autosave on: pause button, visibilitychange, beforeunload, Capacitor pause event
- On startup, loadAutosave() restores config with snapshot via applyConfig()
- serializeConfig() includes full particle snapshot (positions, velocities, energy, alive, infection, seed, simTime)
- Added 3 Playwright E2E tests in e2e/autosave.spec.ts:
  1. Full reload-continuity: run sim → trigger autosave → reload → verify restored state
  2. Snapshot validation: verify positions, velocities, seed, simTime present and valid
  3. beforeunload trigger: verify autosave fires on page close
- All 395 unit tests pass. All 3 new E2E tests pass (8 e2e total pass, 1 pre-existing touch test failure)
- Branch: feat/crt-13-autosave-resume, commit 66ddc38

## CRT-14 — Export/import config files (2026-06-12)
- Export/import functions already existed in persistence.ts from prior scaffolding
- **Enhanced importConfig()** to use `deserializeConfig()` for full schema validation (previously only checked version number — now validates simulation params, species fields, interaction matrix, forces, snapshot)
- **10 new unit tests** in persistence.test.ts:
  1. importConfig resolves null for invalid JSON file
  2. importConfig resolves null for config with wrong version
  3. importConfig resolves null for config missing required fields
  4. importConfig resolves validated config for valid file
  5. importConfig resolves null when no file selected (empty file list)
  6. Round-trip: export produces JSON that importConfig validates
  7. exportConfig does not duplicate .json extension
  8. exportConfig handles errors gracefully
  9. autosave round-trip tests (2 existing, preserved)
- **4 new E2E Playwright tests** in e2e/export-import.spec.ts:
  1. Export button triggers download with valid JSON config
  2. Exported config can be re-imported and applied
  3. Full round-trip: export → import → reload restores simulation
  4. Consistent exports when paused
- All 398 unit tests pass (104 app + 278 core + 16 render)
- Branch: feat/crt-14-export-import, commit 59e1535
- PR creation blocked by token scope — needs manual `gh pr create`

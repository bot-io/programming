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

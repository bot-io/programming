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

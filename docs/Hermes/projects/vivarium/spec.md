# Vivarium — Project Specification v2

> **KICKOFF (for the agent).** When given this file, execute this section first:
> 1. Create `projects/vivarium/` in the vault (same structure as the other projects). Save this file verbatim as `projects/vivarium/spec.md`.
> 2. Fill `charter.md` from this spec; create a new GitHub repo `vivarium`.
> 3. Populate `backlog.md` with items VIV-1..VIV-15 below, statuses as specified.
> 4. Add vivarium to `PRIORITIES.md` at rank 2, active. Commit the vault.
> 5. Confirm by listing the backlog, and flag anything ambiguous or technically questionable in `projects/vivarium/questions.md` BEFORE starting any implementation.
> The stack and architecture below are mandated decisions, not suggestions. Do not start coding until step 5 is acknowledged by Svetlin or the items are unambiguous. Day-to-day work on this project happens in its dedicated Telegram chat under the vault protocol (AGENTS.md).

## Vision

**Vivarium** — a living world in your pocket. A fast 2D particle sandbox where multiple particle types interact through configurable behaviors, producing emergent, lifelike patterns: clusters, chases, orbits, flocks. v1 particles are colored circles; the architecture must anticipate creature-like rendering (birds, fish — oriented sprites/skins) and predator–prey ecosystem dynamics. Runs on web, Android, iOS from one codebase. End goal: app stores.

## Stack (mandated — do not substitute)

- **TypeScript** (strict), **PixiJS v8** (WebGL/WebGPU), **Capacitor** (Android/iOS shells), **Vite**, **Vitest** + **Playwright**, ESLint/Prettier.
- UI: lightweight HTML/CSS overlay; React permitted for the control panel only. The simulation core has ZERO dependencies.
- Rationale: one widely-adopted language across all targets; PixiJS is the dominant, future-proof 2D web renderer; Capacitor is the standard store-approved native wrapper; pure-TS core is headless-testable for autonomous TDD.

## Architecture (mandated principles)

Three modules, strict boundaries:

1. **`core`** — pure TS, deterministic given a seed.
   - Typed-array storage (`Float32Array` x, y, vx, vy; `Uint8Array` type). No per-particle objects, no hot-loop allocations.
   - **Spatial hash grid** sized to max interaction radius → O(n) neighbor queries; particles interact only within radius.
   - Fixed timestep (accumulator) decoupled from render, with interpolation; dt clamping; seeded RNG (e.g. mulberry32).
2. **`render`** — Pixi adapter. Circles as batched tinted sprites from one shared texture. Must support per-type texture swap (future skins) and per-particle rotation from velocity heading (future creatures) as one-point changes.
3. **`app`** — controls, persistence, Capacitor glue.

### Force/behavior model (the reusability core)

Single interface `Force { id, params, apply(world, grid, dt) }`, serializable params, registered in a pipeline. Families:

- **PairwiseForce** (one implementation, matrix-driven): N×N **interaction matrix** — per (typeA, typeB): `strength` (+attract / −repel), `radius`, `falloff`, plus universal short-range repulsion to prevent collapse. Asymmetric (A→B ≠ B→A) — this is also how chase/flee (predator–prey movement) emerges for free.
- **NeighborhoodForce** (boids-style, uses the same grid):
  - **Alignment** — steer toward average heading of same-type neighbors (flocking; key to the birds/fish future).
  - **Cohesion/Separation** are covered by the matrix; alignment is the genuinely new primitive.
- **GlobalForce**: **drag**, optional gravity, boundaries (bounce | wrap), **wander** (per-particle smooth noise — organic, lifelike motion), **flow field** (directional/spatially varying wind or current), **vortex** (swirl around a point).
- **InteractionForce**: pointer/touch attract–repel — the user's finger stirs the world. Cheap and the single most fun feature; include in v1.

### Per-type motion parameters

Each type has: `initialSpeed` (spawn velocity magnitude, random direction), `maxSpeed` (per-type clamp — prey can be faster than predators!), `radius`, `color`, `count`. Max-speed clamping happens in the integrator, per type.

## Performance requirements (acceptance-tested)

1,000 particles @ 60 fps on mid-range Android (headroom for ~5k); zero hot-loop allocations (benchmark-verified); pause when backgrounded; headless benchmark with CI perf gate.

## Configuration & persistence

Schema-versioned JSON (`"version": 1`): simulation settings, `types[]` (incl. initialSpeed/maxSpeed), `interactionMatrix`, enabled forces + params, optional `snapshot` (positions, velocities, seed, simTime) for exact resume. Autosave on pause/exit (IndexedDB / Capacitor Filesystem), restore on launch. Export/import named configs as `.json` (download / share sheet). Unknown fields ignored on read (forward compatibility).

## UI requirements

Collapsible overlay: per-type count/color/radius/initialSpeed/maxSpeed; add/remove types; matrix editor; per-force enable + sliders; play/pause/reset/re-seed; randomize-matrix button; FPS counter. All live, no restart.

## Future (design for, do NOT build in v1)

- **Ecosystem mode (predator–prey, planned M6+)**: energy per particle, eating on contact (prey consumed → predator energy), starvation death, reproduction. Core data layout must allow adding per-particle scalar channels (energy) without redesign — reserve the pattern, don't implement.
- Creature skins (oriented sprites), user skins, WebGPU/worker sim, sound, online config sharing.

## Milestones

M1 core sim headless+tested · M2 live web build · M3 full controls + persistence · M4 Android validated on Svetlin's phone · M5 iOS + store readiness · (M6 ecosystem mode — not in scope yet)

## Initial backlog (IDs: VIV-n; `ready` unless noted)

1. **VIV-1** Check "Vivarium" name availability (Play Store, App Store, domain, trademark scan); report findings as a question if conflicts found. Then scaffold: monorepo (core/render/app), Vite, Vitest, ESLint, CI. AC: `npm test` green in CI.
2. **VIV-2** Core world: typed-array state (with room for future scalar channels), fixed-timestep loop, seeded RNG, per-type initialSpeed spawn + per-type maxSpeed clamp. AC: determinism test (same seed → identical state after 1000 steps); clamp/spawn unit tests.
3. **VIV-3** Spatial hash grid + neighbor queries. AC: property test vs brute-force reference; zero allocations per step.
4. **VIV-4** PairwiseForce + interaction matrix + short-range repulsion. AC: analytic two-particle tests; asymmetry test (A chases B, B flees A).
5. **VIV-5** Global forces: drag, gravity, bounce/wrap. AC: unit tests per force.
6. **VIV-6** Wander + flow field + vortex forces. AC: unit tests; wander smoothness (no teleporting) test.
7. **VIV-7** Alignment (flocking) force. AC: unit test — aligned neighbors converge headings; mixed types unaffected unless configured.
8. **VIV-8** Benchmark harness: steps/sec @ 100/500/1k/5k, allocation check, CI perf gate. AC: committed report.
9. **VIV-9** Pixi renderer + minimal web app: interpolation, FPS counter, default 3-type config with documented sample matrix showing emergent clustering + a chase. AC: Playwright smoke test.
10. **VIV-10** Pointer/touch interaction force. AC: e2e test.
11. **VIV-11** Config schema v1 + (de)serialization incl. snapshot. AC: round-trip + unknown-field tests.
12. **VIV-12** Controls UI, live-applied. AC: Playwright tests per control.
13. **VIV-13** Autosave + exact resume on launch. AC: e2e reload-continuity test.
14. **VIV-14** Export/import config files. AC: e2e round-trip.
15. **VIV-15** Capacitor Android build + background-pause. AC: debug APK in CI; on-device perf check — *needs Svetlin* (block on human verification once APK exists). — **VIV-16** iOS + store readiness: status blocked (after M4).

## Working rules

Vault protocol (AGENTS.md) applies: tests green before commit, feature branches + PRs, ambiguities → questions.md, never guess.

# Vivarium — Project Charter

---
aliases: [Vivarium]
tags: [project, active]
---

## Summary

A living world in your pocket. Fast 2D particle sandbox where multiple particle types interact through configurable behaviors, producing emergent, lifelike patterns: clusters, chases, orbits, flocks. v1 particles are colored circles; architecture anticipates creature-like rendering (oriented sprites/skins) and predator–prey ecosystem dynamics.

## Goals

- Web, Android, iOS from one codebase → app stores
- 1,000+ particles @ 60 fps on mid-range Android
- Fully configurable forces and interaction matrix
- Snapshot save/resume with exact determinism

## Stack (mandated)

- **TypeScript** (strict), **PixiJS v8**, **Capacitor**, **Vite**, **Vitest + Playwright**, ESLint/Prettier
- React for control panel only; simulation core has ZERO dependencies
- Pure TS core → headless-testable for autonomous TDD

## Architecture

Three modules, strict boundaries:

1. **`core`** — pure TS, deterministic, typed-array storage, spatial hash grid, fixed timestep with interpolation
2. **`render`** — Pixi adapter, batched tinted sprites, per-type texture swap, per-particle rotation from velocity heading
3. **`app`** — controls, persistence (schema-versioned JSON), Capacitor glue

### Force model

- `Force { id, params, apply(world, grid, dt) }` — serializable, pipelined
- **PairwiseForce** — N×N interaction matrix (asymmetric, drives chase/flee)
- **NeighborhoodForce** — alignment (flocking)
- **GlobalForce** — drag, gravity, boundaries, wander, flow field, vortex
- **InteractionForce** — pointer/touch attract–repel

## Milestones

| Milestone | Scope |
|-----------|-------|
| M1 | Core sim headless + tested |
| M2 | Live web build |
| M3 | Full controls + persistence |
| M4 | Android validated on device |
| M5 | iOS + store readiness |
| M6 | Ecosystem mode (future, not in v1) |

## Performance Requirements

- 1,000 particles @ 60 fps on mid-range Android (headroom for ~5k)
- Zero hot-loop allocations (benchmark-verified)
- Pause when backgrounded
- Headless benchmark with CI perf gate

## Constraints

- Stack and architecture are mandated — no substitutions
- Future features (ecosystem, skins, WebGPU worker) designed for but NOT built in v1
- Core data layout must allow per-particle scalar channels without redesign (pattern reserved)

## Related

- [[spec]] — full project specification
- Dual Reader — existing Android project (shared CI patterns)

## GitHub

- Repo: `vivarium` (to be created under bot-io org)

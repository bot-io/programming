# Critterium — Requirements & Feature Specification

> **Living document.** Update this whenever a feature is added, changed, or removed.
> Last updated: 2026-06-16 (v1.5.3+ with two-zone interaction model + determinism)

## 1. Overview

Critterium is a **particle ecosystem simulation** mobile app (Android, via Capacitor).
It simulates interacting species of particles with emergent behaviors — flocking,
predation, reproduction, and energy flow — rendered in real-time with PixiJS.

## 2. Core Simulation

### 2.1 World & Particles
- **Typed-array storage**: Float32Array for x/y/vx/vy, Uint8Array for type — cache-friendly, zero GC pressure
- **Fixed-timestep loop**: accumulator pattern with interpolation for smooth rendering; dt clamping
- **Seeded PRNG** (mulberry32): fully deterministic given the same seed
- **Spatial hash grid**: O(n) neighbor queries sized to max interaction radius
- **Particle properties**: position (x, y), velocity (vx, vy), type (species index), radius
- **Boundary modes**: bounce (reflect off walls) and wrap (toroidal)
- **Population cap**: configurable global maximum (default varies by preset)

### 2.2 Species Configuration
Each species has:
- **count**: initial particle count
- **color**: hex color for rendering
- **radius**: particle radius (affects eating distance and rendering size)
- **initialSpeed**: speed assigned at spawn
- **maxSpeed**: velocity clamp
- **energy**: maxEnergy, reproductionCost, energyGainPerPrey (per-species array)
- **lifecycle**: maxAgeSec, starvationDamagePerSec, reproductionCooldownSec
- **diet**: canEat set (which species indices this species can consume)
- **stamina**: sprintSpeedMultiplier, sprintDurationSec, sprintCooldownSec, tiredSpeedMultiplier (optional)

### 2.3 Two-Zone Interaction Model (v1.6+)
Each species-pair (A→B) has a configurable interaction:
- **innerStrength**: force magnitude within inner radius (close range)
- **outerStrength**: force magnitude in outer ring (detection range)
- **innerRadius**: boundary between inner and outer zones
- **outerRadius**: maximum range — no force beyond this
- **falloff**: how force decays within a zone (linear, inverse, constant)

Force logic: distance < innerRadius → innerStrength; innerRadius ≤ distance < outerRadius → outerStrength; ≥ outerRadius → no force.

**Backward compatibility**: old configs with `{ strength, radius, falloff }` auto-migrate to `innerStrength = outerStrength = strength`, `innerRadius = 0`, `outerRadius = radius`.

**Backward compatibility**: old configs with `{ strength, radius, falloff }` auto-migrate to `innerStrength = outerStrength = strength`, `innerRadius = 0`, `outerRadius = radius`.

### 2.4 Forces (Global)
- **Drag**: velocity-proportional damping
- **Gravity**: constant downward force (optional)
- **Wander**: smooth per-particle pseudo-random motion (sin/cos-based, deterministic)
- **Flow Field**: spatially varying directional force
- **Vortex**: swirling force around a point
- **Alignment (Boids)**: steer toward average heading of same-type neighbors (optional cross-type)
- **Pointer**: user touch/mouse interaction (attract or repel within radius)
- **Universal short-range repulsion**: prevents all particles from collapsing to a point

### 2.5 Ecosystem Mechanics

#### Eating
- Instant consumption: predator touches prey → prey dies, predator gains energy
- Energy gain from per-species `energyGainPerPrey` array
- Predator satiation: predators above 75% of maxEnergy skip eating (prevents over-predation)
- O(n) via spatial hash grid neighbor queries

#### Lifecycle
- **Aging**: particles die when `age > maxAgeSec`
- **Starvation**: particles lose energy over time; die when energy reaches 0
- **Reproduction**: cooldown-gated, energy-cost reproduction
  - Child spawns **behind** the parent (opposite of motion direction)
  - **Round-robin queue**: alternates between species for fairness — no single species dominates
  - No per-species population cap (removed — flattens trophic pyramids)
  - No endangered species boost (removed — user wants constant, well-defined rules)
- **Stamina**: sprint/cooldown cycle affecting max speed

### 2.6 Determinism (v1.6+)
- **Zero `Math.random()` in production code** — all randomness uses seeded PRNG
- Same seed → identical simulation every time
- Reset/Reseed uses incrementing deterministic seed counter
- Randomize matrix uses seeded PRNG derived from current seed
- Reproduction spawns child behind parent at fixed offset (not random)

## 3. Rendering

### 3.1 PixiJS Renderer
- Batched tinted sprites from per-species RenderTextures (Graphics → Texture)
- Interpolation between sim steps (prevX/prevY + alpha lerp)
- Per-particle rotation from velocity heading
- Energy-based opacity (particles fade as energy decreases)
- Death/birth visual effects (expand/fade sprites)

### 3.2 HUD & Overlays
- **FPS counter**: real-time FPS, particle count, per-species counts
- **Population graph**: live line graph showing species counts over time
- **Adaptive quality**: auto-reduces visual effects on slow devices (3-tier: high/medium/low)
  - High (≥45 FPS): all effects, no skip
  - Medium (25-45 FPS): disable energy opacity
  - Low (<25 FPS): disable all effects, render skip 2

## 4. User Interface

### 4.1 Controls Panel (Collapsible)
- **Simulation**: play/pause, reset, reseed, speed slider, population cap slider
- **Species**: per-type count, color picker, radius, initialSpeed, maxSpeed
- **Add/Remove species**: dynamic species management at runtime
- **Forces**: per-force enable toggle + parameter sliders (drag, wander, pointer)
- **Interaction Matrix**: N×N grid editor — color-coded cells, click to edit with 4 sliders (inner/outer strength + inner/outer radius) + falloff dropdown
- **Randomize matrix**: generates random interaction values (seeded)
- **Preset selector**: dropdown with built-in and saved presets
- **Actions**: export config, import config, error log viewer

### 4.2 Presets (14 built-in)
1. Classic (2 species: predator/prey)
2. Plankton Bloom
3. Swarm Intelligence
4. Predator Arena
5. Tiny Pond
6. Zen Garden
7. Rock/Paper/Scissors (circular eating)
8. Grasslands (Plants → Rabbits → Foxes)
9. Birds (Starling murmuration + Hawk)
10. Fishes (Coral reef + cleaner-fish symbiosis)
11-14. Additional curated presets

## 5. Persistence

### 5.1 Autosave
- Saves to localStorage on: pause, visibility change, beforeunload, Capacitor pause event
- Full snapshot: positions, velocities, energy, alive, infection, seed, simTime
- Restore on launch via `deserializeConfig` validation

### 5.2 Config Export/Import
- Export: `.json` file (Capacitor Filesystem → Share sheet on mobile, download blob on web)
- Import: validated via `deserializeConfig` (range-clamping, schema validation)
- 3-tier export strategy: (1) Capacitor Filesystem + Share, (2) Web Share API, (3) download blob

### 5.3 Simulation Logger
- Ring buffer of simulation events
- Auto-persisted to localStorage (crash-safe)
- Exportable as text via share mechanism

## 6. Architecture

### 6.1 Monorepo (npm workspaces)
- **`packages/core`**: Simulation engine — World, forces, ecosystem, spatial hash, config schema
- **`packages/render`**: PixiJS renderer — sprites, interpolation, effects, HUD
- **`packages/app`**: Entry point — main.ts, controls UI, presets, persistence, adaptive quality

### 6.2 Force Registry
- Dynamic force registration: type ID → factory function + metadata
- Forces added/removed at runtime via registry, not hardcoded
- Auto-generates UI sliders from param schema

### 6.3 Config Schema (versioned JSON)
- Versioned: `"version": 2`
- Contains: simulation settings, species[], interactionMatrix, enabled forces + params
- Optional snapshot (positions, velocities, seed, simTime) for exact resume
- Forward-compatible: unknown fields ignored on read
- Defensive range-clamping on deserialization (NaN → 0, Infinity → clamped)

## 7. Build & Deployment

### 7.1 Android (Capacitor v8)
- AGP 9.2.1, Kotlin 2.3.21, JDK 21, compileSdk 37, Compose BOM 2026.05.01
- `gradle.properties` permanently sets `org.gradle.java.home` to Android Studio JBR
- APK output: `android/app/build/outputs/apk/debug/app-debug.apk`
- Version tracked in `packages/app/package.json`

### 7.2 Testing
- **Vitest**: unit tests across all packages (600+ tests)
- **Playwright**: e2e tests (12 tests: reload continuity, config round-trip, touch interaction, controls)
- **Preset stability tests**: 180s timeout, excluded from main suite
- CI pipeline: build-and-test + android-debug-apk + e2e + lint + format

## 8. Performance

- Zero per-step heap allocations in hot loops (pre-allocated typed arrays, free list for particles)
- Spatial hash grid for O(n) neighbor queries
- Batched sprite rendering
- Adaptive quality system with FPS hysteresis
- Population cap as safety valve

## 9. Decisions & Constraints

- **Constant mechanics**: user explicitly prefers well-defined, constant reproduction rules over adaptive/dynamic ones
- **No per-species cap**: removed — it flattens trophic pyramids; round-robin queue handles fairness
- **No endangered boost**: removed — user wants deterministic, predictable rules
- **Two-zone model (not N-zone)**: user explicitly wanted exactly 2 zones
- **Every reported bug MUST get a regression test**: user mandate
- **APK naming**: include app name + version (e.g. `critterium-1.6.0.apk`)

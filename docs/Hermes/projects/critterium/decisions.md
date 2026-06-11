# Critterium — Decisions

### D1: Monorepo structure — npm workspaces, core exports types
- **Date:** 2026-06-10
- **Context:** Q4 — how to structure the monorepo packages
- **Decision:** Single npm workspace root. Core exports types/interfaces; render and app import from core. No separate shared package.
- **Rationale:** Matches the "core has zero dependencies" mandate. Simple dependency graph: app → render → core.

### D2: Max 16 particle types
- **Date:** 2026-06-10
- **Context:** Q5 — cap on number of types for live add/remove
- **Decision:** 16 types maximum. Enforced in config validation.
- **Rationale:** Keeps 16×16 matrix editor usable (256 cells). Uint8Array type index fits. Well above any practical v1 use case.

### D3: Forces may own pre-allocated typed arrays
- **Date:** 2026-06-10
- **Context:** Q6 — wander noise needs per-particle state without hot-loop allocations
- **Decision:** Forces can own their own Float32Array/Uint8Array, allocated at construction, resized only on particle count change.
- **Rationale:** No per-particle objects, no hot-loop allocations. Memory is pre-allocated but force-scoped.

### D4: CI on GitHub Actions
- **Date:** 2026-06-10
- **Context:** Q7 — CI platform choice
- **Decision:** GitHub Actions. Standard for bot-io repos.
- **Rationale:** Native to GitHub, free for public repos, well-known patterns for Vite/Vitest.

### D5: Matrix editor — slider grid, color-coded
- **Date:** 2026-06-10
- **Context:** Q8 — matrix editor UX
- **Decision:** N×N slider grid. Each cell independent (asymmetric). Color-coded by strength (green attract, red repel).
- **Rationale:** Simple, functional, handles asymmetry naturally.

### D6: Project name — Critterium
- **Date:** 2026-06-10
- **Context:** Q3 — "Vivarium" had conflicts on app stores, domains, and trademark
- **Decision:** Rename to **Critterium**. Clear on Google Play, App Store, USPTO (software/gaming class). critterium.app and critterium.io likely available.
- **Rationale:** "Vivarium" had high conflict risk (App Store rejections, live USPTO trademark, all domains taken). Critterium is clean, distinctive, and carries the critter/living-world theme.

### D7: Ecosystem mode in scope — spawn, hunger, aging, reproduction, death, sickness
- **Date:** 2026-06-11
- **Context:** User direction — Critterium is not just a particle sim, it's a living ecosystem
- **Decision:** Full lifecycle: particles can eat, get hungry, age, reproduce, get sick, die. Hunger drives food-seeking behavior. Reproduction requires being fed. Death from old age or starvation.
- **Rationale:** User explicitly wants this. Makes the product distinctive and replayable.

### D8: 1k particles baseline at 60fps
- **Date:** 2026-06-11
- **Context:** Performance target
- **Decision:** Target 1000 particles at 60fps as the baseline. Optimize spatial hash and force pipeline for this.
- **Rationale:** User-specified. 1k gives enough complexity for ecosystem behaviors while staying achievable on 5-year-old Android phones.

### D9: Curated presets
- **Date:** 2026-06-11
- **Context:** User-defined preset scenarios
- **Decision:** Ship with presets: Birds, Fishes, Simple Particles, Predator/Prey, Predator/Prey/Vegetation, Predator/Prey/Sickness Center, Rock/Paper/Scissors, and more to be designed.
- **Rationale:** Presets showcase the system's range and give users instant gratification.

### D10: Visuals — colored circles, skin-ready renderer
- **Date:** 2026-06-11
- **Context:** Visual style decision
- **Decision:** Colored circles for v1. Renderer architecture supports per-type texture swap (one-point change for future skins/creatures).
- **Rationale:** User confirmed. Keeps M1-M2 scope manageable while not painting into a corner.

### D11: Android first, target 5-year-old phones
- **Date:** 2026-06-11
- **Context:** Platform priority and device target
- **Decision:** Android via Capacitor first. Target phones from ~2021 onward (mid-range specs). iOS deferred to CRT-16.
- **Rationale:** User-specified. 5-year-old phone target means we need to be careful with GPU draw calls and JS performance.

### D12: Per-species configurable interactions — all forces/behaviors optional
- **Date:** 2026-06-11
- **Context:** User's vision for the interaction model
- **Decision:** Each species independently configures: (1) which other species it interacts with, (2) which forces/behaviors apply to each interaction, (3) distance ranges per interaction. Example: species 1 attracted to own (range A→B), repelled from own (range B→C), repelled by species 2, attracted to species 3, eats species 3. All toggles are per-species-pair.
- **Rationale:** Maximum flexibility. Enables complex ecosystems without code changes.

### D13: Free vs paid — species count limit
- **Date:** 2026-06-11
- **Context:** Monetization model
- **Decision:** Up to 12 species in the config. Free version has a lower cap (exact number TBD). Paid version unlocks full species count and possibly more forces/presets.
- **Rationale:** User-specified. Details to be finalized when we design the paywall.

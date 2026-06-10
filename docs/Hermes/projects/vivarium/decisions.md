# Vivarium — Decisions

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

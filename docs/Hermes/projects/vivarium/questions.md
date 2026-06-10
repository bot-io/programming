# Vivarium — Questions

_Questions flagged during kickoff review._

## Q1: PRIORITIES.md — ✅ RESOLVED
User authorized the edit. Vivarium added at rank 2.

## Q2: GitHub repo — ✅ RESOLVED
Under `bot-io` org. Use existing credentials.

## Q3: "Vivarium" name availability — ⚠️ BLOCKING

**Conflicts found across all dimensions:**

- **Google Play** — No exact-name app, but a VR game "Vivarium" on Meta Quest and a developer "Persei Vivarium" exist. Soft conflict.
- **Apple App Store** — Multiple apps using the name (Vivarium by Hans Renz, Vivarium by Vetic SA, getvivarium.com exotic pet app). High conflict — Apple likely to flag/reject exact-name submission.
- **Domains** — vivarium.com, vivarium.app, vivarium.io all taken and active.
- **USPTO** — Live registered trademark "VIVARIUM+" (KMKUS INC, Class 42 — software for animal facility control). Also Vivarium Inc. (Japanese game studio, common-law trademark in gaming).

**Decision needed from Svetlin:** Keep "Vivarium" and accept the risk, or pick an alternative name now before we scaffold? If renaming, the repo, config namespace, and all references should use the new name from day one.

## Q4: Monorepo package structure — ✅ RESOLVED (agent call)
Single npm workspace. Core exports its types and interfaces; render/app import directly from core. No separate shared/types package — keeps the dependency graph simple and matches the "core has zero dependencies" mandate.

## Q5: Max types — ✅ RESOLVED (agent call)
Cap at **16 types**. This keeps the 16×16 matrix editor manageable (256 cells), the typed-array `Uint8Array` type index fits in 4 bits, and it's well above any practical v1 use case. Enforced in config validation.

## Q6: Wander noise state — ✅ RESOLVED (agent call)
Forces may own pre-allocated typed arrays. The wander force allocates a `Float32Array` (one float per particle for noise phase) at construction, resized only when particle count changes. No hot-loop allocations — all memory is pre-allocated.

## Q7: CI platform — ✅ RESOLVED (agent call)
GitHub Actions. Standard for bot-io repos.

## Q8: Matrix editor UX — ✅ RESOLVED
Slider grid as default. Each cell is independent (asymmetric matrix). Color-coded by strength (green attract, red repel).

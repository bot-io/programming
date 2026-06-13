# Critterium — Worklog

## 2026-06-12 CRT-15: Capacitor Android build + background-pause
- **Branch:** `feat/crt-15-capacitor-android-ci`
- **Commit:** 27dcb21
- **What was done:**
  1. Added `android-debug-apk` CI job to `.github/workflows/ci.yml` — uses Node 22, Java 17, Gradle, Capacitor sync, builds debug APK, uploads as artifact (14-day retention)
  2. Verified background-pause already implemented in `main.ts` (Capacitor pause/resume events, visibilitychange, beforeunload)
  3. Added 12 background-pause lifecycle tests in `packages/app/src/background-pause.test.ts`
  4. Fixed pre-existing TS build errors: FalloffType cast in matrix rebuild, unused canvas variable in PopulationGraph
  5. Fixed infection feature removal inconsistencies (test files still referencing removed infection features)
- **Tests:** 397 total (266 core + 16 render + 115 app unit) — all pass
- **Status:** Blocked on criterion 3 (on-device perf check needs Svetlin)
- **Blocker:** Need Svetlin to install debug APK and report FPS/performance on physical device

## 2026-06-13 CRT-17: Rock/Paper/Scissors preset
- **Branch:** `feat/crt-17-rps-preset`
- **Commit:** 323559b
- **What was done:**
  1. Discovered backlog was severely stale — codebase at v1.3.8 with ecosystem mode (CRT-E1 through CRT-E6) fully implemented but untracked in backlog
  2. Reconciled backlog: added retrospective done items CRT-E1 through CRT-E6 for ecosystem work (data model, eating, lifecycle, interaction rules, presets, app polish)
  3. Created CRT-17 for Rock/Paper/Scissors preset (explicitly requested in decision D9)
  4. Implemented 3-species preset with cyclic eating: Rock→Scissors→Paper→Rock
  5. Each species chases prey (positive interaction), flees predator (negative), self-repels
  6. Balanced energy/params so no species permanently dominates
  7. Added 8 new structural tests for R/P/S cyclic properties
- **Tests:** 441 total (301 core + 16 render + 124 app) — all pass
- **Notes:** Quota had reset from 99% to 1% — resumed work. Stale critterium.lock from 2026-06-11 cleaned up.

## 2026-06-13 CRT-18: Grasslands preset — Predator/Prey/Vegetation
- **Branch:** `feat/crt-18-food-chain`
- **Commit:** 99d8448
- **What was done:**
  1. Identified gap in D9 preset wishlist: "Predator/Prey/Vegetation" was listed but never implemented
  2. No "ready" backlog items existed — all items done or blocked on Svetlin
  3. Created CRT-18 for the three-tier food chain preset following CRT-17 precedent
  4. Implemented "Grasslands" preset: Grass (producer), Rabbits (primary consumer), Foxes (apex predator)
  5. Grass auto-regenerates: fast reproduction (1.5s cooldown, 5 energy cost), nearly stationary
  6. Rabbits forage grass (+15 energy/gain), flee foxes (-80 flee radius 130), flock (+20)
  7. Foxes hunt rabbits (+60 chase radius 160), territorial self-repulsion (-30)
  8. Grass has mild self-repulsion (-15) to spread out; ignores animals (null entries)
  9. 3x3 asymmetric interaction matrix, tuned for self-sustaining Lotka-Volterra dynamics
  10. 16 new structural tests covering food chain, diet rules, energy flow, reproduction rates,
      interaction directions, species colors, population cap
- **Tests:** 457 total (301 core + 16 render + 140 app) — all pass
- **Based on:** feat/crt-17-rps-preset branch (RPS not yet merged to main)
- **Status:** Done — branch pushed, PR needs manual creation (token scope)

## 2026-06-13 CRT-19: Birds preset — Starling murmuration + Hawk
- **Branch:** `feat/crt-19-birds-preset`
- **Commit:** 3900f88
- **What was done:**
  1. No "ready" backlog items existed — all done or blocked on Svetlin. Dual-reader also had no ready items.
  2. Mined D9 curated-preset wishlist: "Birds" was listed but never implemented (distinct from the existing "Swarm Intelligence" which already has a Birds *species* but no dedicated flocking-with-predator preset).
  3. Created CRT-19 for a murmuration preset following CRT-17/CRT-18 precedent.
  4. Designed "Birds" preset: 350 Starlings (dark #1b1b2f) form a shifting cloud via strong cohesion (+55, r100); 5 Hawks (#8b5a2b) hunt stragglers.
  5. Asymmetric interaction matrix drives emergent chase/flee: Starlings flee Hawk (−95, r140), Hawk chases Starlings (+70, r170), Hawks solitary (self-repel −35, r90), Starlings flock (self-cohesion +55).
  6. Confirmed config schema has no `alignment` force field — flocking emerges from the interaction matrix (cohesion + universal short-range repulsion), exactly as the existing Swarm Intelligence preset does. Followed the proven pattern rather than guessing.
  7. 15 new structural tests: species identity, population balance, diet/energy flow, interaction directions (cohesion/flee/chase/territorial), radius relationships, distinct colors, population-cap.
- **Tests:** 472 total (301 core + 16 render + 155 app) — all pass
- **Based on:** feat/crt-18-food-chain branch (RPS + Grasslands not yet merged to main)
- **Status:** Done — branch pushed, PR needs manual creation (token scope)
- **D9 wishlist status:** Simple Particles✅ Predator/Prey✅ Predator/Prey/Vegetation✅ Rock/Paper/Scissors✅ Birds✅ — Fishes⏳ remains. "Predator/Prey/Sickness Center" blocked: the infection/sickness feature was previously removed from the codebase.

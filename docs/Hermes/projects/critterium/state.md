# Critterium — Worker State

## Current Version
- **Version:** 1.6.9
- **Main commit:** 2537a4a (code review fixes)
- **Previous:** d640694 (CRT-51 merge), 7a1ba12 (CRT-64 dep upgrades)

## Test Status
- 1206 tests pass (568 core + 29 render + 609 app)
- Typecheck ✅, Lint ✅, Format ✅

## Code Review Round 1 — Completed Fixes (CRT-82, commit 2537a4a)
- Render: update() array bounds, DPR clamp, destroy() cleanup, birth speciesIdx, HUD throttle, effect clear
- App: stamina serialization, deepCloneConfig, pop-cap debounce, clipboard .catch, pause lastTime, delete confirm name, matrix slider sync

## Code Review Round 1 — Backlog Items (CRT-83 through CRT-90)
- CRT-83 (P1): Config-load desync family — 5 paths partially apply configs
- CRT-84 (P1): Dynamic force add/remove UI never rebuilds panel
- CRT-85 (P2): Capacitor pause/resume events use wrong API
- CRT-86 (P2): Array.shift() O(n) in fake "ring buffers"
- CRT-87 (P2): No window/orientation resize handling
- CRT-88 (P3): Duplicate global error capture
- CRT-89 (P3): importConfig promise hangs if oncancel doesn't fire
- CRT-90 (P3): Population-overflow kills lowest-index, not oldest

## Still Open (from prior milestones)
- CRT-15: Install debug APK, measure FPS on device
- CRT-16: iOS build + store readiness
- CRT-76: On-device visual check of REPULSION=80 boundary physics
- CRT-78: Inverse falloff discontinuity (zero preset impact)
- CRT-79: Render path coverage gap
- PRs #9/#10/#11: Close manually on GitHub (token lacks permission)

## Core Package Review
- Status: NOT YET DONE (rate-limited during subagent delegation)
- Next step: Manual read of all core source files

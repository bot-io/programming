# tradesim — Worklog

## 2026-09-09 — MVP built end-to-end (session 1)
- Scaffolded npm-workspaces monorepo (critterium pattern): `@tradesim/core` pure TS + `@tradesim/app` Vite.
- Live-captured Yahoo AAPL fixture (21 bars) → parser TDD: 8 tests green; any-null bar dropped (constant rule).
- Broker sim TDD: 26 tests. Mechanics: next-bar-open market fills, gap-aware limit/stop, SL-before-TP same-bar, $1/fill commission, whole shares, netting flips, all-in P&L with proportional entry-commission allocation. Found+fixed 4 spec bugs in my own tests while tracing cash flows.
- Chart geometry pure functions TDD (11 tests): layout, price/time scales, visibleRange clamp, candleAtX snap, timeToIndex.
- Canvas renderer: candles + volume + axes + crosshair + entry/exit markers + SL/TP/order lines + P&L shading, DPR-aware.
- ReplayEngine TDD (8 tests): cursor, step, tick(speed), runToEnd, warm-up at 70%, no look-ahead.
- UI: dark theme, order ticket (market/limit/stop × buy/sell, qty/SL/TP), position/fills/trades panels, play/pause/step/speed, wheel zoom, localStorage session persistence.
- E2E in real browser: AAPL 251 bars live; buy 10 @306.1 → SL 295 exit -113.2; reload restore verified.
- 6 commits on main; vault folder created.

### Pitfalls hit (Windows/MSYS)
- `vitest run` piped through grep/head in this terminal HANGS (TTY artifact) — run in background, redirect to log, read log.
- git 2.19: no `init -b`; init → commit → `git branch -m master main`.
- Vite build needs `--outDir dist` under packages/app; app tsconfig needs `lib: DOM` for canvas/window types.

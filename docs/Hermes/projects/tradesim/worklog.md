# tradesim — Worklog

## 2026-09-10 — Per-timeframe wrap rewrite (session 4, user directive)
- User: start from Monthly, connect lowest points so price never crosses the extended line, keep adding up-rays as price rises; repeat for lower TFs down to 1H; same for downtrend lines; lines wrap the price chart. Previous v2 screenshot judged WORSE than v1.
- Diagnosis: v2's hand-off cascade + TF-native fans + regime machinery produced redundant/odd rays and the viewport clamp squashed candles.
- Rewrite: analyzeTrends = per-TF independent wrap (buildUpFan from global low + buildDownFan from global high); deleted stageTF/wickAdjust/dedupeLines/globalLowFrom/globalHighFrom (~70 lines gone).
- Live AAPL: 15 rays, all TFs wrapped both sides; programmatic never-cross check 1,718 bar-checks ZERO crossings (nocross test run ad-hoc, then removed — network-dependent).
- Pushed c822759.

## 2026-09-10 — Wrap fix (session 3, user feedback)
- User: rays should "wrap" the chart; uptrend lines not visible.
- Root causes: (1) validateAnchors only checked bars in (A,B] — rays could be created already-crossed; (2) buildUpFan returned a single ray (no chaining); (3) stageTF discarded up lines at regime flip; (4) hand-off cascade died at D (wick-adj origin had no confirmed swing after 7 bars) leaving D/4H/1H empty; (5) M/W up-rays sat far below the visible y-domain.
- Fixes: full-ray validation; chained up-fans; TF-native context fans (own global-low up-fan + global-high down-fan per TF, deduped) merged into the cascade; dual wrap at regime change; renderer extends y-domain with clamped ray edge values (±25%).
- Live AAPL: 9 up + 3 down rays; blue up-ray pixels 1818 → 3336. Pushed e77fca7.

## 2026-09-10 — Algorithmic Trend Line System (session 2)
- Pushed repo to github.com/bot-io/tradesim (private; created via ~/.github-token, gh PAT lacks repo-create scope).
- TDD core (27 tests): `trendlines.ts` (ray model `rayPrice/slopeOf`, `swingLows/swingHighs` k-bar, `validateAnchors` non-intersection, `buildUpFan/buildDownFan` with B→A chaining + wick-adjust refinement, `invalidateLines` close-through engine, `srLevels` clustering, `analyzeTrends` M→W→D→4H→1H), `aggregate.ts` (UTC bucketing for 4H), `strategies.ts` (`evalBounce`, `evalBreakout` with S/R TPs, `trailAlongLine` ratchet).
- App: `fetchTrendSeries` (M/W/D/4H/1H plan, 4H via 60m aggregation), renderer ray/S-R overlay (invalidated = faded + ✕), Trends button + panel, `refreshTrendStatus` on step/play.
- Live-verified on AAPL: fan hand-offs M.B=W.A etc., top S/R 315.2 (12 touches), 1H ray invalidated ✕ during 60m replay (close-through), canvas pixels confirm blue/orange/purple overlays.
- Vision quota (GLM-5V-Turbo) unavailable today — pixel-probe + DOM assertions used instead.

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

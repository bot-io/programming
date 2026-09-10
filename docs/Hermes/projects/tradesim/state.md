# tradesim — State

## Status: v0.2.2 — per-timeframe wrap (user model)

- **Remote:** github.com/bot-io/tradesim (private), branch `main` @ c822759
- **Commits:** 11
- **Tests:** 82/82 green (62 core incl. 29 trendline + 20 app), tsc clean, vite build OK
- **Trend model v3 (user directive 2026-09-10, definitive):** each timeframe (M→W→D→4H→1H) INDEPENDENTLY wraps its own price chart: up-fan = global low chained through higher lows (A_new = B_previous, each ray steeper, never crossed by any bar); down-fan = global high chained through lower highs (same rule mirrored). No inter-TF hand-off, no regime machine, no wick adjustment — removed stageTF/wickAdjust/dedupeLines/globalLowFrom/globalHighFrom. Live AAPL: 15 rays — M 3↑1↓, W 1↑2↓, D 2↑2↓, 4H 1↑1↓, 1H 1↑1↓; verified programmatically 1,718 bar-checks, ZERO crossings.
- **Renderer:** rays anchor-A → right edge; invalidated rays faded + ✕; y-domain extends ±25% of candle range for nearby rays.
- **Live verification (2026-09-09):** AAPL 1d/1y loaded in browser (251 bars), market buy 10 @ 306.1 filled next-bar-open, SL 295 → realized -113.2, equity 9887; second trade SL 290 → -163.2; session restore across reload works.

## Architecture
```
packages/core (pure TS, zero deps beyond vitest)
├── types.ts        Candle, Series, Interval, DEFAULT_RANGE_FOR_INTERVAL
├── yahoo.ts        parseYahooChart — validates + drops null bars
├── broker.ts       Broker class — the trading simulation
└── broker.test.ts  26 tests
packages/app (Vite, DOM)
├── src/chart/geometry.ts   pure scales/layout/snap (11 tests)
├── src/chart/renderer.ts   canvas draw: candles, volume, axes, crosshair, markers, SL/TP/order lines
├── src/replay.ts           ReplayEngine — cursor over series, broker stepping, playback (8 tests)
├── src/data.ts             fetchSeries via /yahoo proxy
├── src/session.ts          localStorage persistence
├── src/main.ts             DOM wiring, order ticket, stats panels
└── index.html              dark-theme UI
```

## Key mechanics (constant)
- Market orders fill at NEXT bar open; limit fills at min(open, limit) once traded to; stop fills at max(open, stop) on a stop-through.
- Same-bar SL checked before TP (conservative).
- Commission $1/fill flat; whole shares; flips net then open the remainder.
- Replay starts at 70% of the series (warm-up history visible, trading starts there).

## Dev commands
```
cd D:\programming\Tools\tradesim
npm test                     # both packages
npm run dev -w @tradesim/app  # vite on :3100 with /yahoo proxy
```

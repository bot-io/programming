# tradesim — State

## Status: v0.2.3 — same-granularity display rule

- **Remote:** github.com/bot-io/tradesim (private), branch `main` @ 00c7a45
- **Commits:** 12
- **Tests:** 86/86 green (66 core incl. 33 trendline + 20 app), tsc clean, vite build OK
- **Trend model v3 (user model, definitive):** each timeframe (M→W→D→4H→1H) INDEPENDENTLY wraps its own price chart: up-fan = global low chained through higher lows (A_new = B_previous, each ray steeper, never crossed by any bar); down-fan = global high chained through lower highs. No inter-TF hand-off. Live AAPL: 15 rays — M 3↑1↓, W 1↑2↓, D 2↑2↓, 4H 1↑1↓, 1H 1↑1↓; verified programmatically 1,718 bar-checks, ZERO crossings.
- **Display rule (user invariant "a trend line must touch ≥2 points and price never crosses it" applies to what's ON the chart):** a chart may only draw lines validated at its own granularity — `tfmap.ts` `linesForInterval` maps 1mo→M, 1wk→W, 1d→D, 60m→1H, active lines only (invalidated = crossed by definition; 4H has no matching chart interval and stays panel-only). Verified live: daily chart at replay end draws exactly its 4 rays (1,513 up + 921 down px); 60m chart draws the 1H pair (811 up + 257 down px).
- **Renderer:** rays anchor-A → right edge; y-domain extends ±25% clamp retained (own-TF rays hug candles so it rarely binds).
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

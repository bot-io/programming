# tradesim — State

## Status: v0.1.0 — MVP complete, e2e verified live

- **Commits:** 6 on `main` (5c48956 scaffold → 5df4785 e2e verify)
- **Tests:** 45/45 green (26 core + 19 app), tsc clean both packages, production build clean (21 KB JS gzip ~8 KB)
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

# tradesim — State

## Status: v0.2.0 — Algorithmic Trend Line System shipped

- **Remote:** github.com/bot-io/tradesim (private), branch `main` @ 67f9043
- **Commits:** 9 (scaffold → yahoo → broker → geometry → renderer → replay+UI → e2e → core trendlines → app trends UI)
- **Tests:** 80/80 green (61 core incl. 27 trendline + 19 app), tsc clean, vite build OK
- **Trend system:** ray model, swing detection (k-bar), non-intersection validation, fan chaining (B→A hand-off), invalidation engine (close-through), S/R clustering, top-down M→W→D→4H→1H orchestrator, bounce/breakout strategies, trailing SL along ray. UI: 📊 Trends button, trend/S-R panel, live invalidation refresh during replay.
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

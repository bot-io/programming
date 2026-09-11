# tradesim — State

## Status: v0.3.0 — SGLD dataset + EUR backtest harness

- **Remote:** github.com/bot-io/tradesim (private), branch `main` @ 72eadd0
- **Commits:** 13
- **Tests:** 96/96 green, tsc ×2 clean, vite build OK
- **SGLD canonical dataset (user directive 2026-09-11):** real Yahoo candles, downloaded once via `scripts/fetch-sgld.cjs`, stored `packages/core/src/fixtures/`: daily 4,347 bars (2009-06-26→2026-09-11), weekly 900, monthly 209, hourly 199, EURUSD 4,500 (FX for EUR conversion). 650 bars OHLC-sanitized (vendor low/high clamps, counted + logged, never silent). SGLD.L is now the app's default symbol. AAPL fixture retained for unit tests.
- **FX layer (`fx.ts`):** `convertCurrency(candles, rates)` — forward-filled same-day EURUSD, no look-ahead, proven by test.
- **Backtest harness (`backtest.ts`):** `runBacktest(symbol, candles, strategy, cfg)` drives the SAME Broker semantics as the interactive replay (market fills next-bar-open, stops/limits intra-bar, commission per fill); `Strategy { name, onBar(ctx) }` with BarContext exposing visible candles/index/cash/equity/position/submit. Result: equity curve, win rate, profit factor, max drawdown, open position, trades/fills. 1,000 EUR buy-and-hold on full history passes sanity band (2k<eq<8k).
- **Trend model v3 + display rule (v0.2.2/0.2.3):** per-TF independent wrap (up-fan global-low→higher lows chained, down-fan mirrored), same-granularity rendering via tfmap.ts (chart draws only own-TF active lines). Live-proven 0 crossings / 1,718 checks.
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

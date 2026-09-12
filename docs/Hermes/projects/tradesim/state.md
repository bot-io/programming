# tradesim — State

## Status: v0.5.0 — Backtest Theater (visual replay of any strategy)

- **Remote:** github.com/bot-io/tradesim (private), branch `main` @ a1eeb86
- **Commits:** 15
- **Tests:** 108/108 green (81 core + 27 app), tsc ×2 clean, vite build OK
- **Backtest Theater (user directive 2026-09-12):** 🧪 Backtest button → pick strategy (ATL 2%, ATL 1%, buy & hold) + initial cash + warm-up % → runs `recordBacktest` → app enters theater mode: chart develops bar-by-bar with the STRATEGY'S OWN trend lines building/invalidating per frame (via `Strategy.inspect()`), trade markers, live position/SL, equity sparkline, stats panel (return, trades, win rate, PF, max DD), footer Play/Step/Speed + seek slider + prev/next-trade jumps. Exit returns to live mode. Verified in-browser on SGLD.L 5y dailies: ATL 7 trades +13.4%, buy&hold +117.5%, zero JS errors.
- **Core additions:** `record.ts` — recordBacktest (identical replay semantics to runBacktest, plus per-bar frames `{view, position, fills, trades, equity, cash, visibleCount}`); `buyhold.ts` — mkBuyHold benchmark; `Strategy.inspect?()` optional analytics hook; 1d default range now 5y.
- **SGLD canonical dataset (user directive 2026-09-11):** real Yahoo candles, downloaded once via `scripts/fetch-sgld.cjs`, stored `packages/core/src/fixtures/`: daily 4,347 bars (2009-06-26→2026-09-11), weekly 900, monthly 209, hourly 199 + deep 1H 4,536 (2024-09-12→2026-09-11), EURUSD 4,500 (FX for EUR conversion). 650 bars OHLC-sanitized (vendor low/high clamps, counted + logged, never silent). SGLD.L is now the app's default symbol. AAPL fixture retained for unit tests.
- **FX layer (`fx.ts`):** `convertCurrency(candles, rates)` — forward-filled same-day EURUSD, no look-ahead, proven by test.
- **Backtest harness (`backtest.ts`):** `runBacktest(symbol, candles, strategy, cfg)` drives the SAME Broker semantics as the interactive replay (market fills next-bar-open, stops/limits intra-bar, commission per fill); `Strategy { name, onBar(ctx), inspect?() }` with BarContext exposing visible candles/index/cash/equity/position/submit. Result: equity curve, win rate, profit factor, max drawdown, open position, trades/fills. 1,000 EUR buy-and-hold on full history passes sanity band (2k<eq<8k).
- **ATL strategy (`atl.ts`, v0.4.0):** full spec implementation — 1H execution lock, HTF context bias gate, Setup A bounce (3rd-touch rejection entries, ATR-scaled outer stop, ray-slope trailing, line-break exit), Setup B breakout (1H close across ≥5-day line, safety-line stop, cooldown), 1–2% equity risk sizing. 1,000 EUR @ 2% on deep 1H: +36% (1,361.83), DD 24.5%, 14 trades.
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

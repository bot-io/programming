# tradesim — Backlog

## Open

### TS-1. [decision] Intraday data coverage for 1m/5m/15m [auto]
**Problem:** Yahoo 1m range caps at 7d, 5m/15m/60m at 60d — the DEFAULT_RANGE table may pick ranges that return fewer bars than the UI expects.
**Fix:** Verify each interval's default range; consider `range=max` for 1d+.
**Acceptance:** Every interval option loads ≥ 50 bars for AAPL without manual range tweaks.

### TS-2. [decision] Chart pan (drag) + keyboard navigation [auto]
**Problem:** Only wheel-zoom (viewport count) exists; no panning back through history.
**Fix:** Drag-to-pan on the canvas offsetting `start`, clamped to [0, len-count].
**Acceptance:** Drag pans smoothly; replay edge-pinning resumes when cursor advances.

### TS-3. [auto] Limit/stop order line x-start follows submit time
**Problem:** Pending-order lines start at x=0 of the plot if submittedAtTime has no matching candle.
**Fix:** `submittedAtTime` should be set from the engine's cursor bar time on submit.
**Acceptance:** Order lines visually begin at the submission bar.

### TS-4. [auto] Trade list export (CSV)
**Fix:** Button in Fills panel → download trades+fills as CSV.
**Acceptance:** Exported file opens in Excel with correct columns.

### TS-5. [decision] Multiple simultaneous symbols (watchlist)
**Problem:** Single-symbol engine; switching symbol mid-session orphans the position.
**Fix:** Either multi-engine map keyed by symbol or confirm-dialog on switch.
**Acceptance:** Switching symbols never loses cash/position state unexpectedly.

### TS-6. [decision] Indicators (SMA/EMA/RSI overlays)
**Fix:** Pure functions in core + overlay toggle in app; on-chart via renderer.
**Acceptance:** Toggling SMA(20) draws correct line vs candles.

## Done
- 2026-09-09 — MVP: scaffold, Yahoo parser, broker sim, geometry, renderer, replay+UI, e2e verified.

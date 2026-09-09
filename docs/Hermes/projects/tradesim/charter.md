# tradesim — Project Charter

## Mission
A web app that consumes live stock price data, renders candlestick charts, and simulates trade execution — with every trading decision and its parameters (entry, exit, SL, TP, order type, size) reflected directly on the chart.

## Scope
- **In:** Yahoo Finance chart API (keyless, via Vite proxy), candlestick + volume chart, canvas renderer with trade overlays (entry/exit markers, SL/TP/order lines, P&L shading), broker simulation (market/limit/stop fills, shorting, SL/TP auto-exits, commissions, whole shares), bar-by-bar replay engine with play/pause/step/speed, order ticket UI, localStorage session persistence.
- **Out (for now):** real money, broker APIs, multi-asset portfolios, indicators (RSI/MACD), streaming live tick data, mobile packaging (Capacitor possible later).

## Location
- **Repo:** `D:\programming\Tools\tradesim` (standalone git repo, branch `main`)
- **Stack:** npm workspaces monorepo — `@tradesim/core` (pure TS, Vitest TDD) + `@tradesim/app` (Vite + TS + canvas)
- **Data:** Yahoo v8 chart endpoint through dev/preview proxy (injects User-Agent, bypasses CORS)

## Non-negotiables
- Broker mechanics are CONSTANT and well-defined: market fills at next-bar open (no look-ahead), SL-before-TP same-bar conservative rule, flat commission per fill, whole shares, position netting with flips.
- Pure-function core; UI reads engine state, never mutates broker internals directly.
- Tests use real live API captures as fixtures; every bug gets a regression test.

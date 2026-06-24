# Technical Stock Screener & Strategy Backtester — NSE Equities

## About this project

I'm a BSc Data Science student with a genuine interest in how markets 
work — not just reading about strategies, but actually testing whether 
they hold up against real historical data.

This project screens NIFTY 500 stocks using Minervini Trend Template 
rules and Wyckoff Stage 2 breakout logic, backtests those signals 
across 2021–2026, and measures strategy performance through proper 
risk metrics. The full pipeline runs from raw data download to a 
formatted Excel report and Tableau dashboard — built entirely using 
Python, SQL, R, Excel, and Tableau.

This is my second project. My first was a trade settlement 
reconciliation pipeline focused on operations and cash risk. This one 
focuses on markets and strategy — two different sides of how finance 
actually works.

## Strategy and approach

**Screening logic — Minervini Trend Template:**
- Price above 50-day, 150-day, and 200-day moving averages
- 200-day MA trending upward
- Price within 25% of 52-week high
- Price at least 30% above 52-week low

**Wyckoff Stage 2 breakout filter:**
- Price breaking above a consolidation base
- Volume confirmation on breakout day

**Exit rules:**
- Stop loss: ATR-based trailing stop
- Target: defined risk/reward ratio
- Time-based exit if neither triggered within holding period

## What the backtest found

- Screened NIFTY 500 stocks across 5+ years of historical data
- Strategy produced consistent cumulative profit growth across 
  2021–2026
- Drawdowns visible but controlled throughout the testing period
- Profit Factor above 6 — total profits significantly outweighed 
  total losses
- Win rate consistent across years — strategy did not deteriorate 
  in volatile periods
- Sharpe Ratio confirmed positive risk-adjusted return across the 
  full backtest window

## Tools used

**Python** — data pipeline (yfinance), indicator calculation 
(moving averages, ATR, 52-week levels), screening engine, 
backtesting engine, trade log generation

**SQL** — win rate analysis by stock, year, and signal type

**R** — ROI, Profit Factor, Sharpe Ratio, maximum drawdown 
calculation, equity curve and drawdown charts

**Excel** — multi-sheet formatted report (KPI summary, trade log, 
sector breakdown)

**Tableau** — equity curve, P&L trend, win rate scatter, KPI cards

## Files

```text
data_pipeline.py     — downloads NIFTY 500 data, calculates 
                        technical indicators
backtest_engine.py   — screening logic + trade simulation + 
                        trade log output
r_analysis.R         — risk metrics and equity curve/drawdown 
                        charts
excel_reporting.py   — formatted Excel report generation
trade_log.csv        — full trade-level backtest output
trade_report.xlsx    — Excel report
dashboard.png        — Tableau dashboard screenshot
```

## Dashboard

[Add Tableau Public link here]

## Related project

[Trade Settlement Reconciliation](https://github.com/BCHARANVSS/Trade-Settlement-Reconciliation) 
— operations and cash risk pipeline (Project 1)

## Honest note

This is a learning project using historical data and simulated 
trades. It does not represent live trading, real money, or 
guaranteed future performance. Past backtest results do not 
predict live market behaviour.

The purpose was to understand how screening and backtesting logic 
actually works — how analysts think about entries, exits, risk 
sizing, and performance measurement — and to practice building a 
complete data pipeline from raw market data to structured reporting.

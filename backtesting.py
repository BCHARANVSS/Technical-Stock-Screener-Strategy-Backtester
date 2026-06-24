import pandas as pd
# step 1 : load screened watchlist
df = pd.read_csv("data/daily_watchlist.csv")

# normalize column names to avoid case/whitespace mismatches
df.columns = df.columns.str.strip().str.lower()

# handle common misspelling variants (e.g. wycoff -> wyckoff)
if "wycoff" in df.columns and "wyckoff" not in df.columns:
    df = df.rename(columns={"wycoff": "wyckoff"})

# quick diagnostics for required columns
required = {"ticker", "date", "close"}
missing = required - set(df.columns)
if missing:
    raise KeyError(f"Missing required columns in daily_watchlist.csv: {missing}")

# step 2 : initialize trade log
trades = []

# step 3: loop through signals
for ticker in df['ticker'].unique():
    stock_data = df[df["ticker"] == ticker].copy()
    stock_data = stock_data.sort_values("date").reset_index(drop=True)

    # prepare fast numpy-backed arrays and boolean signal arrays (safe defaults)
    closes = stock_data["close"].to_numpy()
    dates = stock_data["date"].to_numpy()
    minervini_arr = stock_data.get("minervini", pd.Series([False] * len(stock_data))).to_numpy()
    wyckoff_arr = stock_data.get("wyckoff", pd.Series([False] * len(stock_data))).to_numpy()

    for i in range(len(stock_data)):
        if bool(minervini_arr[i]) or bool(wyckoff_arr[i]):
            entry_date = dates[i]
            entry_price = closes[i]

            stop_loss = entry_price*0.93  # 7% stop
            target = entry_price*1.25   # 25% target

            exit_date, exit_price = None, None

            # simulate next 60 days
            for j in range(i+1, min(i+61, len(stock_data))):
                close = closes[j]
                date = dates[j]

                if close <= stop_loss:
                    exit_date, exit_price = date, close
                    break
                elif close >= target:
                    exit_date, exit_price = date, close
                    break
            # time exit if no stop/target hit

            if exit_date is None:
                k = min(i+60, len(stock_data)-1)
                exit_date = dates[k]
                exit_price = closes[k]

            pnl = exit_price - entry_price
            pct_return = (exit_price / entry_price - 1) * 100

            trades.append({
                "Ticker": ticker,
                "Entrydate": entry_date,
                "Entryprice": entry_price,
                "Exitdate": exit_date,
                "Exitprice": exit_price,
                "PnL": pnl,
                "Returnpct": pct_return
            })

# step 4 : save trade log
trade_log = pd.DataFrame(trades)
trade_log.to_csv("data/trade_log.csv", index=False)
print("Trade log saved successfully.")


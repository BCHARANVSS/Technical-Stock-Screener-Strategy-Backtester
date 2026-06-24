import pandas as pd

# step 1 : load master csv from module 1
df = pd.read_csv("data/nifty500_master.csv")
df.columns = df.columns.str.lower()

# drop malformed header/repeat rows and convert numeric columns
valid_rows = df["date"].notna() & df["ticker"].notna()
df = df.loc[valid_rows].copy()
num_cols = ["close", "high", "low", "open", "volume"]
df[num_cols] = df[num_cols].apply(pd.to_numeric, errors="coerce")
df = df.dropna(subset=num_cols)

# step 2 : moving averages (trend confirmation)

df["MA50"] = df.groupby("ticker")["close"].transform(lambda x: x.rolling(50).mean())
df["MA150"] = df.groupby("ticker")["close"].transform(lambda x: x.rolling(150).mean())
df["MA200"] = df.groupby("ticker")["close"].transform(lambda x: x.rolling(200).mean())

# step 3: volume average (liquidity filter)
df["vol50"] = df.groupby("ticker")["volume"].transform(lambda x: x.rolling(252).mean())

# step 4 : 52 week high/low (breakout potential)
df["52w_high"] = df.groupby("ticker")["close"].transform(lambda x: x.rolling(252).max())
df["52w_low"] = df.groupby("ticker")["close"].transform(lambda x: x.rolling(252).min())

# step 5 atr (average true range, volatility measure)
df["h-l"] = df["high"] - df["low"]
df["prev_close"] = df.groupby("ticker")["close"].shift(1)
df["h-pc"] = (df["high"] - df["prev_close"]).abs()
df["l-pc"] = (df["low"] - df["prev_close"]).abs()
df["tr"] = df[["h-l", "h-pc", "l-pc"]].max(axis=1)
df["atr14"] = df.groupby("ticker")["tr"].transform(lambda x: x.rolling(14).mean())

# step6 : save enriched dataset

df.to_csv("data/nifty500_indicators.csv", index=False)
print("indicators file saved successfully")
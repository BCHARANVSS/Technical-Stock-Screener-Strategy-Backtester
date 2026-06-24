import os
import yfinance as yf
import pandas as pd
import time

# create output folder if it does not exist
os.makedirs("data", exist_ok=True)

# step 1 : define nifty 500 tickers
# for demo , showing a short list in practice replace with full nifty 500

nse_list = pd.read_csv(r"D:\GOLDMAN SACHS PREPARATION\GS_PROJECTS\Technical Stock Screener Strategy Backtester\NIFTY-500 list recent.csv", encoding='utf-8') # file from nse website
nse_list.columns = nse_list.columns.str.strip()  # remove whitespace from column names
nifty500_tickers = [symbol.strip() + ".NS" for symbol in nse_list["SYMBOL"]]

# step 2 track failed tickers
failed_tickers=[]
successful_tickers=[]

# step 3 loop through tickers and download OHLCV

for ticker in nifty500_tickers:
    print(f"Downloading {ticker}...")
    try:
        
        df = yf.download(ticker, start="2020-01-01", end="2026-06-19")

        if df.empty:
            print(f"No data for {ticker}")
            failed_tickers.append(ticker)
            continue # skip to next ticker 
        df.dropna(inplace=True)   # cleaning missing values
        df.reset_index(inplace=True) # reset index to make date a column 
        df["Ticker"] = ticker        # adding ticker column for identification

        # save individual csv per stock
        df.to_csv(f"data/{ticker}_data.csv", index=False)
        successful_tickers.append(ticker)

        # sleep briefly to avoid hitting request limits
        time.sleep(1)
    except Exception as e:
        print(f"Filed to download {ticker}: {e}")
        failed_tickers.append(ticker)

# step 4 concatenate individual CSVs into master CSV (memory efficient - reads in chunks)
if successful_tickers:
    print(f"\nCombining {len(successful_tickers)} successful downloads into master CSV...")
    master_list = []
    for i, ticker in enumerate(successful_tickers):
        if (i + 1) % 50 == 0:
            print(f"  Processed {i+1}/{len(successful_tickers)} files...")
        try:
            df = pd.read_csv(f"data/{ticker}_data.csv")
            master_list.append(df)
            
            # Write in chunks to avoid memory overload
            if len(master_list) >= 50:
                chunk_df = pd.concat(master_list, ignore_index=True)
                if i == 49:  # first chunk
                    chunk_df.to_csv("data/nifty500_master.csv", index=False, mode='w')
                else:
                    chunk_df.to_csv("data/nifty500_master.csv", index=False, mode='a', header=False)
                master_list = []
        except Exception as e:
            print(f"  Error reading {ticker}_data.csv: {e}")
    
    # write remaining data
    if master_list:
        chunk_df = pd.concat(master_list, ignore_index=True)
        if len(successful_tickers) <= 50:
            chunk_df.to_csv("data/nifty500_master.csv", index=False)
        else:
            chunk_df.to_csv("data/nifty500_master.csv", index=False, mode='a', header=False)
    
    print("Master CSV saved successfully")
else:
    print("No data downloaded")

if failed_tickers:
    with open("data/failed_tickers.txt", "w") as f:
        for t in failed_tickers:
            f.write(t+ "\n")
    print("Failed tickers saved to failed_tickers.txt")

'''import shutil

if os.path.exists("data"):
    shutil.rmtree("data")
os.makedirs("data", exist_ok=True)'''
import os
from pathlib import Path

import pandas as pd
import xlsxwriter

INPUT_CSV = Path("data/trade_log.csv")
OUTPUT_XLSX = Path("outputs/trade_report.xlsx")

OUTPUT_XLSX.parent.mkdir(parents=True, exist_ok=True)

def safe_rate(series: pd.Series) -> float:
    if series.empty:
        return 0.0
    return round((series > 0).mean() * 100, 2)


def write_header(worksheet, headers, workbook):
    bold = workbook.add_format({"bold": True})
    for col_idx, header in enumerate(headers):
        worksheet.write(0, col_idx, header, bold)


def write_dataframe(worksheet, df: pd.DataFrame):
    write_header(worksheet, list(df.columns), workbook)
    for row_idx, row in enumerate(df.itertuples(index=False), start=1):
        for col_idx, value in enumerate(row):
            worksheet.write(row_idx, col_idx, value)


if not INPUT_CSV.exists():
    raise FileNotFoundError(f"Input file not found: {INPUT_CSV}")


df = pd.read_csv(INPUT_CSV)

with xlsxwriter.Workbook(OUTPUT_XLSX) as workbook:
    summary = workbook.add_worksheet("summary")

    summary.write("A1", "Total Trades")
    summary.write("B1", len(df))

    summary.write("A2", "Win Rate (%)")
    summary.write("B2", safe_rate(df["PnL"]) if "PnL" in df.columns else 0.0)

    summary.write("A3", "Net Profit")
    summary.write("B3", round(df["PnL"].sum(), 2) if "PnL" in df.columns else 0.0)

    summary.write("A4", "Average Trade PnL")
    summary.write("B4", round(df["PnL"].mean(), 2) if "PnL" in df.columns else 0.0)

    log = workbook.add_worksheet("trade log")
    write_header(log, list(df.columns), workbook)
    for row_idx, row in enumerate(df.itertuples(index=False), start=1):
        for col_idx, value in enumerate(row):
            log.write(row_idx, col_idx, value)

    if "minervini" in df.columns or "wyckoff" in df.columns:
        strat = workbook.add_worksheet("strategy breakdown")
        write_header(strat, ["strategy", "trades", "win rate (%)"], workbook)

        output_row = 1
        if "minervini" in df.columns:
            min_trades = df[df["minervini"] == 1]
            strat.write(output_row, 0, "minervini")
            strat.write(output_row, 1, len(min_trades))
            strat.write(output_row, 2, safe_rate(min_trades["PnL"]) if "PnL" in min_trades.columns else 0.0)
            output_row += 1

        if "wyckoff" in df.columns:
            wy_trades = df[df["wyckoff"] == 1]
            strat.write(output_row, 0, "wyckoff")
            strat.write(output_row, 1, len(wy_trades))
            strat.write(output_row, 2, safe_rate(wy_trades["PnL"]) if "PnL" in wy_trades.columns else 0.0)

    if "sector" in df.columns:
        sector = workbook.add_worksheet("sector analysis")
        grouped = df.groupby("sector")["PnL"].agg(["count", "mean", "sum"]).reset_index()
        write_header(sector, ["sector", "trades", "avg PnL", "net profit"], workbook)
        for row_idx, row in enumerate(grouped.itertuples(index=False), start=1):
            sector.write(row_idx, 0, row.sector)
            sector.write(row_idx, 1, int(row.count))
            sector.write(row_idx, 2, round(row.mean, 2))
            sector.write(row_idx, 3, round(row.sum, 2))

print(f"Excel report saved to {OUTPUT_XLSX}")
library(dplyr)
library(ggplot2)
library(scales)

# Step 1: Load trade log
trades <- read.csv("data/trade_log.csv", stringsAsFactors = FALSE)

# Normalize header names to avoid case or formatting mismatches
names(trades) <- tolower(trimws(names(trades)))

required_cols <- c(
  "ticker", "entrydate", "entryprice", "exitdate",
  "exitprice", "pnl", "returnpct"
)
missing_cols <- setdiff(required_cols, names(trades))
if (length(missing_cols) > 0) {
  stop(
    "Missing required columns in trade_log.csv: ",
    paste(missing_cols, collapse = ", ")
  )
}

# Convert the expected columns to the proper type
trades <- trades |>
  mutate(
    entrydate = as.Date(entrydate, format = "%Y-%m-%d"),
    exitdate = as.Date(exitdate, format = "%Y-%m-%d"),
    entryprice = as.numeric(entryprice),
    exitprice = as.numeric(exitprice),
    returnpct = as.numeric(returnpct),
    pnl = as.numeric(pnl)
  )

if (nrow(trades) == 0) {
  stop("trade_log.csv contains no trades.")
}

if (any(is.na(trades$entrydate)) || any(is.na(trades$exitdate))) {
  stop(
    "Some entrydate or exitdate values could not be parsed as dates.",
    " Check the data/trade_log.csv format."
  )
}

if (any(is.na(trades$entryprice))) {
  stop("Some entryprice values are missing or not numeric.")
}

if (any(is.na(trades$exitprice))) {
  stop("Some exitprice values are missing or not numeric.")
}

if (any(is.na(trades$returnpct))) {
  stop("Some returnpct values are missing or not numeric.")
}

if (any(is.na(trades$pnl))) {
  stop("Some pnl values are missing or not numeric.")
}

# Step 2: Risk metrics and performance summary
trades <- trades |> arrange(exitdate)
trade_returns <- trades$returnpct / 100
mean_return <- mean(trade_returns, na.rm = TRUE)
sd_return <- sd(trade_returns, na.rm = TRUE)
sharpe <- ifelse(
  sd_return <= 0 || is.na(sd_return),
  NA_real_,
  mean_return / sd_return
)

net_profit <- sum(trades$pnl, na.rm = TRUE)
avg_trade <- mean(trades$pnl, na.rm = TRUE)
avg_win <- mean(trades$pnl[trades$pnl > 0], na.rm = TRUE)
avg_loss <- mean(trades$pnl[trades$pnl < 0], na.rm = TRUE)
largest_win <- max(trades$pnl, na.rm = TRUE)
largest_loss <- min(trades$pnl, na.rm = TRUE)
profit_factor <- ifelse(
  sum(trades$pnl[trades$pnl < 0], na.rm = TRUE) == 0,
  NA_real_,
  sum(trades$pnl[trades$pnl > 0], na.rm = TRUE) /
    abs(sum(trades$pnl[trades$pnl < 0], na.rm = TRUE))
)

start_capital <- 100000
ending_capital <- start_capital + net_profit
roi_pct <- ifelse(
  start_capital == 0,
  NA_real_,
  net_profit / start_capital * 100
)

best_trade <- trades |> filter(pnl == largest_win) |> slice_head(n = 1)
worst_trade <- trades |> filter(pnl == largest_loss) |> slice_head(n = 1)

total_trades <- nrow(trades)
wins <- sum(trades$pnl > 0, na.rm = TRUE)
losses <- sum(trades$pnl < 0, na.rm = TRUE)
win_rate <- ifelse(total_trades == 0, NA_real_, wins / total_trades)

cat("Total Trades:", total_trades, "\n")
cat("Winning Trades:", wins, "\n")
cat("Losing Trades:", losses, "\n")
cat("Win Rate:", scales::percent(win_rate, accuracy = 0.1), "\n")
cat("Net Profit:", round(net_profit, 2), "\n")
cat("ROI on ₹100000:", round(roi_pct, 2), "%", "\n")
cat("Ending Capital:", round(ending_capital, 2), "\n")
cat("Average Trade PnL:", round(avg_trade, 2), "\n")
cat("Average Win:", round(avg_win, 2), "\n")
cat("Average Loss:", round(avg_loss, 2), "\n")
cat("Largest Win:", round(largest_win, 2), "\n")
cat("Largest Loss:", round(largest_loss, 2), "\n")
cat("Profit Factor:", ifelse(is.na(profit_factor), "NA",
    round(profit_factor, 3)), "\n")
cat("Sharpe Ratio (trade-level):", ifelse(is.na(sharpe), "NA",
    round(sharpe, 3)), "\n")

if (wins > 0) {
  cat("Best winning trade:", best_trade$exitdate[1], 
      "with PnL", round(largest_win, 2), "\n")
}
if (losses > 0) {
  cat("Worst losing trade:", worst_trade$exitdate[1], 
      "with PnL", round(largest_loss, 2), "\n")
}

if (!is.na(profit_factor) && profit_factor < 1) {
  cat("Recommendation: Reduce losses or improve entry/exit rules.", "\n")
} else if (!is.na(profit_factor)) {
  cat("Recommendation: Maintain discipline and keep losses smaller than wins.", "\n")
}

cat("Note: Profit/loss is calculated from sum of pnl values.", "\n")
cat("This script cannot infer exact reasons for losses without trade-level context.", "\n")

# Trade-level diagnostics for entry and exit
trade_reason_cols <- intersect(
  c("ticker", "entrydate", "entryprice", "exitdate", "exitprice", "pnl", "returnpct"),
  names(trades)
)

trade_summary <- trades |>
  mutate(
    duration_days = as.numeric(exitdate - entrydate),
    direction = ifelse(pnl >= 0, "win", "loss"),
    gain_loss_pct = returnpct
  )

write.csv(trade_summary, trade_csv, row.names = FALSE)
cat("✓ Saved trade-level summary to outputs/trade_summary.csv\n")

# Step 3: Equity curve and drawdown
trades <- trades |> mutate(EquityCurve = cumsum(pnl))
cummax_curve <- cummax(trades$EquityCurve)
drawdown <- trades$EquityCurve - cummax_curve
max_drawdown <- min(drawdown, na.rm = TRUE)
max_drawdown_magnitude <- abs(max_drawdown)

cat("Max Drawdown (negative):", round(max_drawdown, 2), "\n")
cat("Max Drawdown (magnitude):", round(max_drawdown_magnitude, 2), "\n")

# ============================================================================
# Step 3B: Validate strategy for fees, slippage, and sustainability
# ============================================================================
cat("\n========== VALIDATION CHECKS ==========\n\n")

# Fee and slippage analysis
assumed_brokerage_pct <- 0.01
assumed_slippage_pct <- 0.02
total_cost_pct <- assumed_brokerage_pct + assumed_slippage_pct

gross_profit <- net_profit
avg_entry_price <- mean(abs(trades$entryprice), na.rm = TRUE)
fee_slippage_loss <- total_trades * (total_cost_pct / 100) * avg_entry_price
net_profit_after_fees <- gross_profit - fee_slippage_loss
roi_after_fees <- (net_profit_after_fees / start_capital) * 100

cat("FEE & SLIPPAGE IMPACT ANALYSIS\n")
cat(strrep("-", 80), "\n")
cat(sprintf("Assumed Brokerage:         %.3f%% per trade\n", assumed_brokerage_pct))
cat(sprintf("Assumed Slippage:          %.3f%% per trade\n", assumed_slippage_pct))
cat(sprintf("Gross Profit (before fees):₹%,.2f\n", gross_profit))
cat(sprintf("Est. Fees & Slippage Loss: ₹%,.2f\n", fee_slippage_loss))
cat(sprintf("Net Profit (after fees):   ₹%,.2f\n", net_profit_after_fees))
cat(sprintf("ROI After Fees:            %.2f%%\n", roi_after_fees))
if (roi_after_fees < roi_pct * 0.5) {
  cat("⚠ WARNING: Fees reduce returns significantly.\n")
} else {
  cat("✓ Strategy remains profitable after typical fees.\n")
}

# Trade frequency sustainability
date_range <- as.numeric(max(trades$exitdate) - min(trades$exitdate))
years_trading <- date_range / 365.25
trades_per_day <- total_trades / date_range
trades_per_year <- total_trades / years_trading

cat("\nTRADE FREQUENCY & SUSTAINABILITY\n")
cat(strrep("-", 80), "\n")
cat(sprintf("Backtest Period:           %.2f years\n", years_trading))
cat(sprintf("Date Range:                %s to %s\n", 
    min(trades$exitdate), max(trades$exitdate)))
cat(sprintf("Total Trades:              %d trades\n", total_trades))
cat(sprintf("Avg Trades Per Day:        %.1f trades/day\n", trades_per_day))
cat(sprintf("Avg Trades Per Year:       %.0f trades/year\n", trades_per_year))

if (trades_per_day > 100) {
  cat("⚠ WARNING: Very high trade frequency (>100/day).\n")
  cat("   → May be difficult to execute in live markets\n")
} else if (trades_per_day > 20) {
  cat("⚠ CAUTION: High trade frequency (>20/day).\n")
  cat("   → Verify broker can handle this volume\n")
} else {
  cat("✓ Trade frequency is moderate and achievable.\n")
}

# Overfitting detection
if (nrow(trades) > 1000) {
  cutoff_idx <- nrow(trades) * 0.75
  recent_trades <- trades[(cutoff_idx + 1):nrow(trades), ]
  older_trades <- trades[1:cutoff_idx, ]
  
  old_wr <- sum(older_trades$pnl > 0) / nrow(older_trades)
  recent_wr <- sum(recent_trades$pnl > 0) / nrow(recent_trades)
  
  old_profit <- sum(older_trades$pnl, na.rm = TRUE)
  recent_profit <- sum(recent_trades$pnl, na.rm = TRUE)
  
  cat("\nOVERFITTING DETECTION (Recent vs. Overall)\n")
  cat(strrep("-", 80), "\n")
  cat(sprintf("Older Trades (75%% dataset):   WR %.1f%% | Profit ₹%.0f\n",
      old_wr * 100, old_profit))
  cat(sprintf("Recent Trades (25%% dataset):  WR %.1f%% | Profit ₹%.0f\n",
      recent_wr * 100, recent_profit))
  
  wr_diff <- abs(old_wr - recent_wr)
  profit_diff_pct <- abs(old_profit - recent_profit) / max(old_profit, recent_profit) * 100
  
  if (wr_diff > 0.10 || profit_diff_pct > 30) {
    cat("⚠ CRITICAL: Performance degrades in recent data.\n")
    cat("   → Possible overfitting to historical conditions\n")
  } else if (wr_diff > 0.05 || profit_diff_pct > 15) {
    cat("⚠ WARNING: Performance varies between periods.\n")
  } else {
    cat("✓ Consistent performance - less likely overfitted.\n")
  }
}

cat("\n========== END VALIDATION ==========\n\n")

# Ensure output directories exist
if (!dir.exists("outputs")) {
  dir.create("outputs", recursive = TRUE)
}

# Get current working directory
work_dir <- getwd()
cat("\n========== SAVE LOCATIONS ==========\n")
cat("Working Directory:", work_dir, "\n\n")

# Define file paths in outputs/ folder
pdf_file <- file.path(work_dir, "outputs", "r_report_plots.pdf")
png_equity <- file.path(work_dir, "outputs", "equity_curve.png")
png_drawdown <- file.path(work_dir, "outputs", "drawdown.png")
trade_csv <- file.path(work_dir, "outputs", "trade_summary.csv")
report_txt <- file.path(work_dir, "outputs", "trading_report_summary.txt")

# Also save copies directly to project root for easy access
png_equity_root <- file.path(work_dir, "equity_curve.png")
png_drawdown_root <- file.path(work_dir, "drawdown.png")
pdf_file_root <- file.path(work_dir, "r_report_plots.pdf")

# Create summary statistics text for annotation
summary_text <- paste(
  "Total Trades:", total_trades, "| Wins:", wins, "| Losses:", losses,
  "\nWin Rate:", round(win_rate * 100, 1), "% | ROI:", round(roi_pct, 2), "%",
  "\nNet PnL: ₹", round(net_profit, 0), " | Max DD: ₹", round(max_drawdown_magnitude, 0),
  "\nSharpe:", ifelse(is.na(sharpe), "N/A", round(sharpe, 3)), "| Profit Factor:", 
  ifelse(is.na(profit_factor), "N/A", round(profit_factor, 2))
)

# Step 4: Equity curve plot with annotations
equity_plot <- ggplot(trades, aes(x = exitdate, y = EquityCurve)) +
  geom_line(color = "blue", size = 0.7) +
  geom_point(color = "blue", size = 1, alpha = 0.7) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "3 months") +
  scale_y_continuous(
    labels = label_number(
      scale_cut = cut_short_scale(),
      accuracy = 0.1
    )
  ) +
  labs(
    title = "Equity Curve",
    subtitle = summary_text,
    x = "Exit Date",
    y = "Cumulative PnL (₹)"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 9, color = "darkblue")
  )

tryCatch({
  png(png_equity, width = 1000, height = 600, res = 100)
  print(equity_plot)
  dev.off()
  cat("✓ Saved equity curve to outputs/equity_curve.png\n")
  
  # Also save copy to project root
  png(png_equity_root, width = 1000, height = 600, res = 100)
  print(equity_plot)
  dev.off()
  cat("✓ Copied equity curve to PROJECT ROOT: equity_curve.png\n")
}, error = function(e) {
  cat("Error saving equity PNG:", e$message, "\n")
})

# Step 5: Drawdown plot with annotations
drawdown_text <- paste(
  "Max Drawdown: ₹", round(max_drawdown_magnitude, 0),
  " | Mean Drawdown: ₹", round(mean(drawdown, na.rm = TRUE), 0),
  " | Latest DD: ₹", round(drawdown[nrow(trades)], 0)
)

plot_drawdown <- trades |> mutate(Drawdown = drawdown) |>
  ggplot(aes(x = exitdate, y = Drawdown)) +
  geom_col(fill = "firebrick", alpha = 0.7) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "3 months") +
  scale_y_continuous(
    labels = label_number(
      scale_cut = cut_short_scale(),
      accuracy = 0.1
    )
  ) +
  labs(
    title = "Drawdown Analysis",
    subtitle = drawdown_text,
    x = "Exit Date",
    y = "Drawdown (₹)"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 9, color = "darkred")
  )

tryCatch({
  png(png_drawdown, width = 1000, height = 600, res = 100)
  print(plot_drawdown)
  dev.off()
  cat("✓ Saved drawdown chart to outputs/drawdown.png\n")
  
  # Also save copy to project root
  png(png_drawdown_root, width = 1000, height = 600, res = 100)
  print(plot_drawdown)
  dev.off()
  cat("✓ Copied drawdown chart to PROJECT ROOT: drawdown.png\n")
}, error = function(e) {
  cat("Error saving drawdown PNG:", e$message, "\n")
})

# Save PDF version
tryCatch({
  pdf(pdf_file, width = 11, height = 7)
  print(equity_plot)
  print(plot_drawdown)
  dev.off()
  cat("✓ Saved combined report to outputs/r_report_plots.pdf\n")
  
  # Also save copy to project root
  pdf(pdf_file_root, width = 11, height = 7)
  print(equity_plot)
  print(plot_drawdown)
  dev.off()
  cat("✓ Copied combined report to PROJECT ROOT: r_report_plots.pdf\n")
}, error = function(e) {
  cat("Error saving PDF:", e$message, "\n")
})

print(equity_plot)
print(plot_drawdown)

# ============================================================================
# Step 6: Generate comprehensive summary report
# ============================================================================
report_file <- report_txt

tryCatch({
  sink(report_file)
  
  separator_line <- strrep("=", 80)
  dash_line <- strrep("-", 80)
  
  cat(separator_line, "\n")
  cat("TECHNICAL STOCK SCREENER STRATEGY BACKTEST REPORT\n")
  cat("Report Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
  cat("Working Directory:", work_dir, "\n")
  cat(separator_line, "\n\n")
  
  cat("OVERALL PERFORMANCE SUMMARY\n")
  cat(dash_line, "\n")
  cat(sprintf("Total Trades:              %d\n", total_trades))
  cat(sprintf("Winning Trades:            %d (%.1f%%)\n", wins, win_rate * 100))
  cat(sprintf("Losing Trades:             %d (%.1f%%)\n", losses, (1 - win_rate) * 100))
  cat(sprintf("Win Rate:                  %.1f%%\n", win_rate * 100))
  
  cat("\nPROFITABILITY ANALYSIS\n")
  cat(dash_line, "\n")
  cat(sprintf("Initial Capital:           ₹%,.2f\n", start_capital))
  cat(sprintf("Total Net Profit/Loss:     ₹%,.2f\n", net_profit))
  cat(sprintf("Ending Capital:            ₹%,.2f\n", ending_capital))
  cat(sprintf("ROI (Return on Investment):%.2f%%\n", roi_pct))
  
  cat("\nTRADE-LEVEL STATISTICS\n")
  cat(dash_line, "\n")
  cat(sprintf("Average Trade PnL:         ₹%,.2f\n", avg_trade))
  cat(sprintf("Average Win:               ₹%,.2f\n", avg_win))
  cat(sprintf("Average Loss:              ₹%,.2f\n", avg_loss))
  cat(sprintf("Largest Win:               ₹%,.2f\n", largest_win))
  cat(sprintf("Largest Loss:              ₹%,.2f\n", largest_loss))
  
  cat("\nRISK METRICS\n")
  cat(dash_line, "\n")
  cat(sprintf("Max Drawdown (Magnitude):  ₹%,.2f\n", max_drawdown_magnitude))
  cat(sprintf("Max Drawdown (Percentage): %.2f%%\n", (max_drawdown_magnitude / start_capital) * 100))
  cat(sprintf("Profit Factor:             %s\n", ifelse(is.na(profit_factor), "N/A", round(profit_factor, 3))))
  cat(sprintf("Sharpe Ratio:              %s\n", ifelse(is.na(sharpe), "N/A", round(sharpe, 3))))
  
  cat("\nTRADE DURATION ANALYSIS\n")
  cat(dash_line, "\n")
  cat(sprintf("Average Trade Duration:    %.1f days\n", mean(trades$duration_days, na.rm = TRUE)))
  cat(sprintf("Longest Trade:             %.0f days\n", max(trades$duration_days, na.rm = TRUE)))
  cat(sprintf("Shortest Trade:            %.0f days\n", min(trades$duration_days, na.rm = TRUE)))
  
  cat("\nFEE & SLIPPAGE IMPACT ANALYSIS\n")
  cat(dash_line, "\n")
  cat(sprintf("Assumed Brokerage:         %.3f%% per trade\n", assumed_brokerage_pct))
  cat(sprintf("Assumed Slippage:          %.3f%% per trade\n", assumed_slippage_pct))
  cat(sprintf("Est. Fees & Slippage Loss: ₹%,.2f\n", fee_slippage_loss))
  cat(sprintf("Net Profit (after fees):   ₹%,.2f\n", net_profit_after_fees))
  cat(sprintf("ROI After Fees:            %.2f%%\n", roi_after_fees))
  
  cat("\nTRADE FREQUENCY ANALYSIS\n")
  cat(dash_line, "\n")
  cat(sprintf("Backtest Period:           %.2f years\n", years_trading))
  cat(sprintf("Avg Trades Per Day:        %.1f trades/day\n", trades_per_day))
  cat(sprintf("Avg Trades Per Year:       %.0f trades/year\n", trades_per_year))
  
  if (nrow(trades) > 1000) {
    cutoff_idx <- nrow(trades) * 0.75
    recent_trades_txt <- trades[(cutoff_idx + 1):nrow(trades), ]
    older_trades_txt <- trades[1:cutoff_idx, ]
    old_wr_txt <- sum(older_trades_txt$pnl > 0) / nrow(older_trades_txt)
    recent_wr_txt <- sum(recent_trades_txt$pnl > 0) / nrow(recent_trades_txt)
    
    cat("\nOVERFITTING DETECTION\n")
    cat(dash_line, "\n")
    cat(sprintf("Older Trades (75%% dataset):   Win Rate %.1f%%\n", old_wr_txt * 100))
    cat(sprintf("Recent Trades (25%% dataset):  Win Rate %.1f%%\n", recent_wr_txt * 100))
  }
  
  cat("\nRECOMMENDATIONS\n")
  cat(dash_line, "\n")
  if (!is.na(profit_factor) && profit_factor < 1) {
    cat("⚠ CRITICAL: Profit factor < 1.0\n")
    cat("  → Losses exceed gains. Review entry/exit strategy.\n")
    cat("  → Improve stop-loss placement or entry conditions.\n")
  } else if (!is.na(profit_factor)) {
    cat("✓ Profit factor > 1.0. Wins exceed losses.\n")
    cat("  → Maintain discipline and consistency.\n")
    cat("  → Track drawdown periods and optimize position sizing.\n")
  }
  
  if (win_rate < 0.5) {
    cat("⚠ Win rate < 50%. Consider:\n")
    cat("  → Tighter entry conditions (Wyckoff/Minervini signals)\n")
    cat("  → Improved stop-loss logic\n")
    cat("  → Better risk/reward ratio\n")
  } else {
    cat("✓ Win rate >= 50%. Strategy is profitable.\n")
  }
  
  if (roi_after_fees < roi_pct * 0.5) {
    cat("⚠ Fees significantly impact returns. Impact Strategy:\n")
    cat("  → Reduce trade frequency if possible\n")
    cat("  → Increase position size per trade\n")
    cat("  → Negotiate lower brokerage rates\n")
  } else {
    cat("✓ Strategy remains profitable after typical fees and slippage.\n")
  }
  
  if (trades_per_day > 100) {
    cat("⚠ Very high trade frequency (>100/day):\n")
    cat("  → High execution risk in live markets\n")
    cat("  → Consider position sizing limits\n")
    cat("  → Test with realistic order execution delays\n")
  } else if (trades_per_day > 20) {
    cat("⚠ High trade frequency (>20/day):\n")
    cat("  → Verify broker infrastructure can handle volume\n")
    cat("  → Monitor actual execution vs. backtest\n")
  } else {
    cat("✓ Trade frequency is achievable in live markets.\n")
  }
  
  cat("\nLIVE TRADING READINESS\n")
  cat(dash_line, "\n")
  cat("Before deploying to live trading:\n")
  cat("  1. Paper trade for at least 1-3 months\n")
  cat("  2. Verify actual execution matches backtest (fees, slippage, fills)\n")
  cat("  3. Test strategy on out-of-sample data\n")
  cat("  4. Monitor for overfitting signs\n")
  cat("  5. Gradually increase position size\n")
  cat("  6. Keep detailed trade journal for review\n")
  
  cat("\nFILES GENERATED\n")
  cat(dash_line, "\n")
  cat("✓ outputs/equity_curve.png        - Cumulative P&L chart\n")
  cat("✓ outputs/drawdown.png             - Drawdown analysis chart\n")
  cat("✓ outputs/r_report_plots.pdf       - Combined PDF report\n")
  cat("✓ outputs/trade_summary.csv        - Per-trade details\n")
  cat("✓ outputs/trading_report_summary.txt - This report\n")
  cat("\nCOPIES IN PROJECT ROOT (for easy access):\n")
  cat("✓ equity_curve.png                 - Cumulative P&L chart\n")
  cat("✓ drawdown.png                     - Drawdown analysis chart\n")
  cat("✓ r_report_plots.pdf               - Combined PDF report\n")
  
  cat("\n", separator_line, "\n")
  cat("END OF REPORT\n")
  cat(separator_line, "\n")
  
  sink()
  cat("✓ Saved comprehensive report to outputs/trading_report_summary.txt\n")
}, error = function(e) {
  cat("Error generating report:", e$message, "\n")
  sink()
})

cat("\n========== EXECUTION COMPLETE ==========\n")
cat("All outputs saved to:\n")
cat("  📁 outputs/ folder\n")
cat("  📁 Project ROOT folder (main copies)\n")
cat("\nWorking Directory: ", work_dir, "\n")
cat("Look for:\n")
cat("  📊 equity_curve.png (in project root)\n")
cat("  📉 drawdown.png (in project root)\n")
cat("  📄 r_report_plots.pdf (in project root)\n")
cat("========================================\n")


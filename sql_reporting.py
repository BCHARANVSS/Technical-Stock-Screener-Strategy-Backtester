import sqlite3
import pandas as pd

# step 1: load trade log into SQLite

df = pd.read_csv("data/trade_log.csv")
conn = sqlite3.connect(":memory:")
df.to_sql("trade_log", conn, index=False, if_exists= "replace")

# step 2: win rate by stock

query_stock = """
select ticker,
count(*) as trades,
sum(case when pnl > 0 then 1 else 0 end) as wins,
round(sum(case when pnl > 0 then 1 else 0 end) * 100.0 / count(*), 2) as winratepct
from trade_log
group by ticker
order by winratepct desc;
"""
print(pd.read_sql(query_stock, conn))

# step 3: win rate by strategy
cols_map = {c.lower(): c for c in df.columns}

if 'minervini' in cols_map or 'wyckoff' in cols_map:
	min_col = cols_map.get('minervini', None)
	wy_col = cols_map.get('wyckoff', None)
	parts = []
	if min_col:
		parts.append(f"when {min_col} = 1 then 'minervini'")
	if wy_col:
		parts.append(f"when {wy_col} = 1 then 'wyckoff'")
	case_when = '\n        '.join(parts)
	pnl_col = cols_map.get('pnl', cols_map.get('pnl'.upper(), 'pnl'))
	query_strategy = f"""
select case
		{case_when}
	end as strategy,
	count(*) as trades,
	sum(case when {pnl_col} > 0 then 1 else 0 end) as wins,
	round(sum(case when {pnl_col} > 0 then 1 else 0 end) * 100.0 / count(*), 2) as winratepct
from trade_log
group by strategy;
"""
	print(pd.read_sql(query_strategy, conn))
else:
	# no strategy columns present — show overall stats
	pnl_col = cols_map.get('pnl', cols_map.get('pnl'.upper(), 'pnl'))
	query_overall = f"""
select 'all' as strategy,
	count(*) as trades,
	sum(case when {pnl_col} > 0 then 1 else 0 end) as wins,
	round(sum(case when {pnl_col} > 0 then 1 else 0 end) * 100.0 / count(*), 2) as winratepct
from trade_log;
"""
	print("No strategy flag columns found; showing overall win rate:")
	print(pd.read_sql(query_overall, conn))
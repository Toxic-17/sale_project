# Sales Analytics Dashboard (Power BI & SQL)

An end-to-end sales performance analytics project: a messy raw transaction
export is cleaned and modeled with SQL, then analyzed with KPI/window-function
queries and surfaced in an interactive BI-style dashboard.

> **Note on tooling:** the resume bullet names Power BI specifically. Power BI
> Desktop is Windows-only desktop software and can't run in this environment,
> so the dashboard layer here is built as a self-contained interactive HTML
> page (vanilla JS + Chart.js) that reproduces the same deliverable — KPI
> cards, drill-through, dynamic visualizations — driven by the exact same
> cleaned data and SQL aggregations a Power BI report would use. Section 5
> below shows how to load the same cleaned data straight into Power BI if
> you have access to it.

## What's in this project

```
sales_dashboard/
├── data/
│   ├── sales_raw.csv          synthetic raw transaction export (~9,750 rows, intentionally dirty)
│   ├── customers.csv          customer master file (650 customers)
│   ├── sales.db               SQLite database after running the pipeline
│   └── dashboard_data.json    KPI query results, consumed by the dashboard
├── sql/
│   ├── 01_schema.sql          star-schema table definitions
│   ├── 02_data_cleaning.sql   cleaning & transformation (the "Power Query + SQL" step)
│   └── 03_kpi_queries.sql     9 analytical queries: joins, CTEs, window functions
├── dashboard/
│   └── index.html             the interactive dashboard (open this file in a browser)
├── generate_data.py            generates the synthetic dataset
└── run_pipeline.py             runs schema → load → clean → KPI export, end to end
```

## 1. The data

`generate_data.py` simulates 2 years (2024–2025) of order-line transactions
for a consumer electronics & home-goods retailer: 20 products across 7
categories, 650 customers across 5 Indian regions, 11 sales reps, with
realistic seasonality (festive-season spike in Oct–Nov), weekend lift, and
18% year-over-year growth.

It also **deliberately injects** the kind of mess a real sales export has:
- inconsistent text casing (`"NORTH"` vs `"North"`)
- leading/trailing whitespace and lowercase category values
- missing customer names
- exact duplicate order lines
- sign-flipped (negative) quantities from data-entry errors

That's the raw input the SQL layer below has real work to do on.

## 2. Cleaning & transformation (`02_data_cleaning.sql`)

Mirrors what you'd otherwise do by hand in Power Query, but in SQL so it's
auditable and re-runnable:

| Issue | Fix |
|---|---|
| Inconsistent region/category casing | `CASE` + `UPPER(TRIM(...))` standardization |
| Duplicate order lines | `SELECT DISTINCT` on the full row |
| Negative quantities | `ABS(Quantity)`, with Revenue/Profit recomputed consistently |
| Customer attributes mixed into transactional data | Modeled separately as a `dim_customer` table, sourced from the customer master file rather than the noisy transaction log |

Running it drops the raw 9,751-row export to **9,627 clean rows** (124
duplicate/invalid rows removed) in a proper star schema: `fact_sales` +
`dim_customer`.

## 3. KPI & analytical queries (`03_kpi_queries.sql`)

Nine queries covering everything the dashboard needs, demonstrating joins,
CTEs, and window functions (`RANK`, `LAG`, partitioned `SUM() OVER()`):

1. Headline KPIs (revenue, profit, orders, AOV, margin %)
2. Monthly revenue & profit trend
3. Top products by revenue, ranked, with % of total
4. Regional performance with each region's share of revenue
5. Year-over-year growth by region (`LAG` across years)
6. Top 15 customers by lifetime revenue (join + rank)
7. Sales rep leaderboard
8. Category mix by region
9. Top products **within each region** (`RANK() OVER (PARTITION BY Region ...)`) — this is what powers the drill-through

## 4. The dashboard (`dashboard/index.html`)

Open the file directly in any browser — it's fully self-contained (Chart.js
is bundled inline, no internet connection needed). It reproduces the
resume bullet's feature list:

- **KPI cards** — total revenue, profit, margin, orders, average order value, with a year filter (All / 2024 / 2025)
- **Dynamic visualizations** — monthly revenue & profit trend, regional bar chart, category-mix donut
- **Drill-through** — click any region in the "Revenue by region" panel and the top-products table, category mix, sales-rep leaderboard, and YoY panel all filter down to that region. Click it again (or the "region filter" pill) to clear it.
- **Automated reporting** — the whole thing regenerates from `run_pipeline.py`; there's no manual report-building step

To regenerate everything from scratch:
```bash
python generate_data.py   # creates data/sales_raw.csv + customers.csv
python run_pipeline.py    # schema → load → clean → KPI export → dashboard_data.json
```
Then open `dashboard/index.html`.

## 5. Using this with real Power BI

If you have Power BI Desktop available, the cleaned `fact_sales` /
`dim_customer` tables in `data/sales.db` (or re-pointed at a real MySQL/
PostgreSQL database using the same `sql/01_schema.sql` and
`02_data_cleaning.sql`) drop straight into **Get Data → SQLite/ODBC**, and
each query in `03_kpi_queries.sql` maps directly onto a Power BI visual:
the monthly trend → a line chart, regional performance → a map or bar
chart with a slicer, and the region-partitioned top-products query →
a table with **Region** set as the drill-through field on its own page.

## Key results (synthetic data)

- ₹5.03 crore total revenue, ₹2.44 crore profit, 48.5% margin, across 6,464 orders
- South is the top region (23.5% of revenue); South also has the strongest YoY growth (+36%)
- 27-inch Monitor is the top product by revenue, despite ranking only 8th by unit volume among the top 10 — a classic margin-vs-volume insight a BI dashboard is built to surface

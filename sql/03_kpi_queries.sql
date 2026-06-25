-- ============================================================
-- Sales Analytics Dashboard — KPI & Analytical Queries
-- Uses CTEs, window functions, joins and aggregations to power
-- the KPI cards / drill-through views in the dashboard.
-- ============================================================

-- 1) Headline KPIs (Total Revenue, Profit, Orders, AOV, Margin %)
SELECT
    ROUND(SUM(Revenue), 2)                          AS total_revenue,
    ROUND(SUM(Profit), 2)                           AS total_profit,
    COUNT(DISTINCT OrderID)                         AS total_orders,
    ROUND(SUM(Revenue) * 1.0 / COUNT(DISTINCT OrderID), 2) AS avg_order_value,
    ROUND(SUM(Profit) * 100.0 / SUM(Revenue), 2)    AS profit_margin_pct
FROM fact_sales;

-- 2) Monthly revenue & profit trend (time-series for the dashboard line chart)
SELECT
    strftime('%Y-%m', OrderDate)               AS month,
    ROUND(SUM(Revenue), 2)                     AS revenue,
    ROUND(SUM(Profit), 2)                      AS profit,
    COUNT(DISTINCT OrderID)                    AS orders
FROM fact_sales
GROUP BY month
ORDER BY month;

-- 3) Top-performing products by revenue, with rank and contribution %
--    (window functions: RANK + running share of total)
WITH product_totals AS (
    SELECT ProductName,
           Category,
           SUM(Revenue) AS revenue,
           SUM(Profit)  AS profit,
           SUM(Quantity) AS units_sold
    FROM fact_sales
    GROUP BY ProductName, Category
)
SELECT
    ProductName,
    Category,
    revenue,
    profit,
    units_sold,
    RANK() OVER (ORDER BY revenue DESC)                         AS revenue_rank,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 2)            AS pct_of_total_revenue
FROM product_totals
ORDER BY revenue_rank
LIMIT 10;

-- 4) Regional performance with each region's share of company-wide revenue
SELECT
    Region,
    ROUND(SUM(Revenue), 2)                              AS revenue,
    ROUND(SUM(Profit), 2)                               AS profit,
    COUNT(DISTINCT OrderID)                             AS orders,
    ROUND(SUM(Revenue) * 100.0 / SUM(SUM(Revenue)) OVER (), 2) AS pct_of_total
FROM fact_sales
GROUP BY Region
ORDER BY revenue DESC;

-- 5) Year-over-year growth by region (window function LAG across years)
WITH yearly AS (
    SELECT Region,
           strftime('%Y', OrderDate) AS yr,
           SUM(Revenue) AS revenue
    FROM fact_sales
    GROUP BY Region, yr
)
SELECT
    Region,
    yr,
    revenue,
    LAG(revenue) OVER (PARTITION BY Region ORDER BY yr)              AS prior_year_revenue,
    ROUND((revenue - LAG(revenue) OVER (PARTITION BY Region ORDER BY yr))
          * 100.0 / LAG(revenue) OVER (PARTITION BY Region ORDER BY yr), 2) AS yoy_growth_pct
FROM yearly
ORDER BY Region, yr;

-- 6) Top 15 customers by lifetime revenue (join fact -> dim, CTE for ranking)
WITH customer_revenue AS (
    SELECT f.CustomerID,
           c.CustomerName,
           c.Segment,
           c.Region,
           SUM(f.Revenue) AS lifetime_revenue,
           COUNT(DISTINCT f.OrderID) AS order_count
    FROM fact_sales f
    JOIN dim_customer c ON c.CustomerID = f.CustomerID
    GROUP BY f.CustomerID, c.CustomerName, c.Segment, c.Region
)
SELECT *,
       RANK() OVER (ORDER BY lifetime_revenue DESC) AS customer_rank
FROM customer_revenue
ORDER BY lifetime_revenue DESC
LIMIT 15;

-- 7) Sales rep leaderboard (drill-through target when a region is clicked)
SELECT
    SalesRep,
    Region,
    ROUND(SUM(Revenue), 2) AS revenue,
    ROUND(SUM(Profit), 2)  AS profit,
    COUNT(DISTINCT OrderID) AS orders
FROM fact_sales
GROUP BY SalesRep, Region
ORDER BY revenue DESC;

-- 8) Category mix per region (for the dashboard's category-by-region breakdown)
SELECT
    Region,
    Category,
    ROUND(SUM(Revenue), 2) AS revenue,
    SUM(Quantity)          AS units_sold
FROM fact_sales
GROUP BY Region, Category
ORDER BY Region, revenue DESC;

-- 9) Top products WITHIN each region (window function partitioned by Region)
--    — powers the drill-through: click a region, see its top products.
--    SQLite/MySQL lack QUALIFY, so the rank filter is applied in an outer
--    SELECT instead (equivalent result, broader compatibility).
SELECT Region, ProductName, Category, revenue, units_sold, rank_in_region
FROM (
    SELECT Region, ProductName, Category,
           SUM(Revenue) AS revenue, SUM(Quantity) AS units_sold,
           RANK() OVER (PARTITION BY Region ORDER BY SUM(Revenue) DESC) AS rank_in_region
    FROM fact_sales
    GROUP BY Region, ProductName, Category
)
WHERE rank_in_region <= 5
ORDER BY Region, rank_in_region;

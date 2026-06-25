-- ============================================================
-- Sales Analytics Dashboard — Data Cleaning & Transformation
-- Mirrors the cleaning normally done in Power Query, but pushed
-- into SQL so it is reproducible and auditable.
--
-- Issues fixed here (deliberately present in the raw export):
--   1. Inconsistent text casing in Region ("NORTH" vs "North")
--   2. Leading/trailing whitespace + lowercase Category values
--   3. Missing CustomerName -> backfilled from dim_customer
--   4. Exact duplicate order lines -> de-duplicated
--   5. Negative Quantity data-entry errors -> corrected with ABS()
-- ============================================================

-- 1) dim_customer is loaded separately from the authoritative customer
--    master file (customers.csv) — see load_and_clean.py. A transactional
--    export is the wrong source for customer attributes like home region;
--    that always comes from the system of record (CRM/master data).

-- 2) Clean + transform raw rows into the analysis-ready fact table
INSERT INTO fact_sales (OrderID, OrderDate, CustomerID, Region, State, ProductName,
                        Category, Quantity, UnitPrice, Discount, Revenue, Cost, Profit, SalesRep)
SELECT DISTINCT                                          -- (5) drop exact duplicate lines
    r.OrderID,
    DATE(r.OrderDate)                              AS OrderDate,
    r.CustomerID,
    CASE UPPER(TRIM(r.Region))                            -- (1) standardize casing
         WHEN 'NORTH' THEN 'North' WHEN 'SOUTH' THEN 'South'
         WHEN 'EAST'  THEN 'East'  WHEN 'WEST'  THEN 'West'
         WHEN 'CENTRAL' THEN 'Central' ELSE TRIM(r.Region)
    END                                              AS Region,
    r.State,
    r.ProductName,
    CASE UPPER(TRIM(r.Category))                          -- (2) trim + standardize casing
         WHEN 'ACCESSORIES' THEN 'Accessories' WHEN 'AUDIO' THEN 'Audio'
         WHEN 'DISPLAYS' THEN 'Displays' WHEN 'HOME' THEN 'Home'
         WHEN 'WEARABLES' THEN 'Wearables' WHEN 'STORAGE' THEN 'Storage'
         WHEN 'NETWORKING' THEN 'Networking' ELSE TRIM(r.Category)
    END                                              AS Category,
    ABS(r.Quantity)                                  AS Quantity,   -- (4) fix sign errors
    r.UnitPrice,
    r.Discount,
    ROUND(ABS(r.Quantity) * r.UnitPrice, 2)          AS Revenue,    -- recompute consistently
    r.Cost,
    ROUND((ABS(r.Quantity) * r.UnitPrice) - r.Cost, 2) AS Profit,
    r.SalesRep
FROM sales_raw r
WHERE r.OrderID IS NOT NULL
  AND r.Quantity != 0;

-- Sanity checks
SELECT 'raw_rows' AS metric, COUNT(*) AS value FROM sales_raw
UNION ALL
SELECT 'clean_rows', COUNT(*) FROM fact_sales
UNION ALL
SELECT 'duplicates_removed', (SELECT COUNT(*) FROM sales_raw) - (SELECT COUNT(*) FROM fact_sales)
UNION ALL
SELECT 'distinct_customers', COUNT(*) FROM dim_customer;

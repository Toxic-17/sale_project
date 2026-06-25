-- ============================================================
-- Sales Analytics Dashboard — Schema
-- Compatible with MySQL 8+ / PostgreSQL 13+ (and SQLite, used
-- here to execute and demo the project without a DB server).
-- ============================================================

DROP TABLE IF EXISTS sales_raw;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS fact_sales;

-- Staging table: raw, uncleaned data exactly as it lands from source export
CREATE TABLE sales_raw (
    OrderID       TEXT,
    OrderDate     TEXT,
    CustomerID    TEXT,
    CustomerName  TEXT,
    Segment       TEXT,
    Region        TEXT,
    State         TEXT,
    ProductName   TEXT,
    Category      TEXT,
    Quantity      INTEGER,
    UnitPrice     REAL,
    Discount      REAL,
    Revenue       REAL,
    Cost          REAL,
    Profit        REAL,
    SalesRep      TEXT
);

-- Dimension: customers
CREATE TABLE dim_customer (
    CustomerID    TEXT PRIMARY KEY,
    CustomerName  TEXT,
    Region        TEXT,
    Segment       TEXT
);

-- Fact table: cleaned, transformed, analysis-ready sales lines
CREATE TABLE fact_sales (
    OrderLineID   INTEGER PRIMARY KEY AUTOINCREMENT,
    OrderID       TEXT,
    OrderDate     DATE,
    CustomerID    TEXT,
    Region        TEXT,
    State         TEXT,
    ProductName   TEXT,
    Category      TEXT,
    Quantity      INTEGER,
    UnitPrice     REAL,
    Discount      REAL,
    Revenue       REAL,
    Cost          REAL,
    Profit        REAL,
    SalesRep      TEXT,
    FOREIGN KEY (CustomerID) REFERENCES dim_customer(CustomerID)
);

CREATE INDEX idx_fact_sales_date ON fact_sales(OrderDate);
CREATE INDEX idx_fact_sales_region ON fact_sales(Region);
CREATE INDEX idx_fact_sales_category ON fact_sales(Category);

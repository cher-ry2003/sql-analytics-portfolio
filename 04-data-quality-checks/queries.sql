-- ============================================================
-- Data Quality Checks
-- The kind of checks that belong in every dbt test suite or
-- data contract validation layer.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Null rate per column in the orders table
--
-- Run this after every load to catch upstream schema changes
-- or extraction failures before they corrupt downstream models.
-- ------------------------------------------------------------
SELECT 'order_id'     AS col, COUNT(*)-COUNT(order_id)     AS nulls, ROUND((COUNT(*)-COUNT(order_id))*100.0/COUNT(*),2) AS null_pct FROM orders
UNION ALL
SELECT 'customer_id',          COUNT(*)-COUNT(customer_id),  ROUND((COUNT(*)-COUNT(customer_id))*100.0/COUNT(*),2)  FROM orders
UNION ALL
SELECT 'order_date',           COUNT(*)-COUNT(order_date),   ROUND((COUNT(*)-COUNT(order_date))*100.0/COUNT(*),2)   FROM orders
UNION ALL
SELECT 'total_amount',         COUNT(*)-COUNT(total_amount), ROUND((COUNT(*)-COUNT(total_amount))*100.0/COUNT(*),2) FROM orders
ORDER BY null_pct DESC;


-- ------------------------------------------------------------
-- 2. Duplicate primary key detection
--
-- A single duplicate order_id breaks joins silently.
-- This surfaces dupes with their count so you can investigate.
-- ------------------------------------------------------------
SELECT order_id, COUNT(*) AS occurrences
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;


-- ------------------------------------------------------------
-- 3. Referential integrity — orders with no matching customer
--
-- Every order must have a parent customer. Orphaned rows mean
-- either a load sequencing problem or a delete-without-cascade.
-- ------------------------------------------------------------
SELECT o.order_id, o.customer_id, o.order_date
FROM orders o
LEFT JOIN customers c USING (customer_id)
WHERE c.customer_id IS NULL
ORDER BY o.order_date;


-- ------------------------------------------------------------
-- 4. Business-rule validation
--    a) Negative or zero amounts
--    b) Order dates before customer signup date
--    c) Quantity outside plausible range
-- ------------------------------------------------------------
-- a) Invalid amounts
SELECT 'negative_or_zero_amount' AS check_name, COUNT(*) AS failing_rows
FROM orders WHERE total_amount <= 0

UNION ALL

-- b) Order before signup (temporal inconsistency)
SELECT 'order_before_signup', COUNT(*)
FROM orders o
JOIN customers c USING (customer_id)
WHERE o.order_date < c.signup_date

UNION ALL

-- c) Unrealistic quantity
SELECT 'quantity_out_of_range', COUNT(*)
FROM orders WHERE quantity <= 0 OR quantity > 100;


-- ------------------------------------------------------------
-- 5. Freshness check — flag if no orders in the last 2 days
--
-- Used in monitoring pipelines to alert on stale data.
-- Replace CURRENT_DATE with your pipeline's expected load date.
-- ------------------------------------------------------------
SELECT
    MAX(order_date)                                     AS latest_order_date,
    CURRENT_DATE - MAX(order_date)                      AS days_since_last_load,
    CASE
        WHEN CURRENT_DATE - MAX(order_date) > 2
        THEN 'STALE — investigate pipeline'
        ELSE 'OK'
    END                                                 AS freshness_status
FROM orders;


-- ------------------------------------------------------------
-- 6. Row count reconciliation by load date
--
-- Compare expected vs actual row counts per day.
-- In practice, "expected" comes from a source system count
-- stored in a control table — here we show the pattern.
-- ------------------------------------------------------------
SELECT
    order_date,
    COUNT(*)                                AS row_count,
    SUM(total_amount)                       AS daily_revenue,
    COUNT(DISTINCT customer_id)             AS unique_customers,
    COUNT(DISTINCT product_id)              AS unique_products
FROM orders
GROUP BY order_date
ORDER BY order_date;

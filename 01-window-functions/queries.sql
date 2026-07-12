-- ============================================================
-- Window Functions
-- Dataset: orders.csv (8 000 rows, 2024-2025)
-- Run: python run_queries.py (DuckDB — no database setup needed)
-- ============================================================


-- ------------------------------------------------------------
-- 1. Daily revenue with 7-day rolling average
--
-- Rolling averages smooth noise and surface real trends.
-- ROWS BETWEEN 6 PRECEDING AND CURRENT ROW gives a trailing
-- window so every row uses only data available at that point.
-- ------------------------------------------------------------
SELECT
    order_date,
    SUM(total_amount)                                           AS daily_revenue,
    SUM(SUM(total_amount)) OVER (
        ORDER BY order_date
    )                                                           AS running_total,
    ROUND(AVG(SUM(total_amount)) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2)                                                       AS rolling_7d_avg
FROM orders
GROUP BY order_date
ORDER BY order_date;


-- ------------------------------------------------------------
-- 2. Customer revenue ranking with percentile buckets
--
-- NTILE(4) splits customers into quartiles — useful for
-- tiering loyalty programs or identifying high-value segments.
-- DENSE_RANK is used instead of RANK to avoid gaps.
-- ------------------------------------------------------------
SELECT
    customer_id,
    ROUND(SUM(total_amount), 2)                                 AS lifetime_value,
    DENSE_RANK() OVER (ORDER BY SUM(total_amount) DESC)         AS revenue_rank,
    NTILE(4) OVER (ORDER BY SUM(total_amount))                  AS value_quartile
FROM orders
GROUP BY customer_id
ORDER BY revenue_rank;


-- ------------------------------------------------------------
-- 3. Day-over-day revenue change using LAG
--
-- LAG lets you compare each day to the previous without a
-- self-join. NULLIF prevents division-by-zero on the first row.
-- ------------------------------------------------------------
WITH daily AS (
    SELECT
        order_date,
        SUM(total_amount) AS revenue
    FROM orders
    GROUP BY order_date
)
SELECT
    order_date,
    revenue,
    LAG(revenue) OVER (ORDER BY order_date)                     AS prev_day_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY order_date))
        / NULLIF(LAG(revenue) OVER (ORDER BY order_date), 0)
        * 100, 1
    )                                                           AS pct_change
FROM daily
ORDER BY order_date;


-- ------------------------------------------------------------
-- 4. Deduplication — keep the most recent order per customer
--    per product using ROW_NUMBER
--
-- ROW_NUMBER with PARTITION + ORDER lets you pick exactly one
-- row per group; filtering on rn = 1 is the standard pattern.
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, product_id
            ORDER BY order_date DESC
        ) AS rn
    FROM orders
)
SELECT order_id, customer_id, product_id, order_date, total_amount
FROM ranked
WHERE rn = 1
ORDER BY customer_id, product_id;


-- ------------------------------------------------------------
-- 5. Gaps and islands — consecutive active sales days
--
-- Classic gaps-and-islands: subtract the row number from the
-- date to get an island ID that stays constant while dates
-- are consecutive.
-- ------------------------------------------------------------
WITH daily AS (
    SELECT DISTINCT order_date FROM orders
),
numbered AS (
    SELECT
        order_date,
        order_date - INTERVAL (ROW_NUMBER() OVER (ORDER BY order_date)) DAY
            AS island_id
    FROM daily
)
SELECT
    MIN(order_date) AS streak_start,
    MAX(order_date) AS streak_end,
    COUNT(*)        AS consecutive_days
FROM numbered
GROUP BY island_id
ORDER BY streak_start;

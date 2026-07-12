-- ============================================================
-- Cohort Retention Analysis
-- Dataset: orders.csv + customers.csv
-- ============================================================


-- ------------------------------------------------------------
-- 1. Monthly signup cohort sizes
--
-- The starting point for retention: how many customers signed
-- up in each month (the cohort).
-- ------------------------------------------------------------
SELECT
    DATE_TRUNC('month', signup_date)    AS cohort_month,
    COUNT(*)                            AS cohort_size
FROM customers
GROUP BY cohort_month
ORDER BY cohort_month;


-- ------------------------------------------------------------
-- 2. Retention curve — % of each cohort that ordered in
--    months 0, 1, 2, 3 after signup
--
-- month_number = 0 is the signup month itself (first purchase
-- rate). This form uses PIVOT-style conditional aggregation so
-- all months are visible in one row per cohort.
-- ------------------------------------------------------------
WITH first_order AS (
    SELECT customer_id, MIN(order_date) AS first_order_date
    FROM orders
    GROUP BY customer_id
),
cohort_base AS (
    SELECT
        c.customer_id,
        DATE_TRUNC('month', c.signup_date)          AS cohort_month,
        DATE_TRUNC('month', fo.first_order_date)    AS first_order_month
    FROM customers c
    LEFT JOIN first_order fo USING (customer_id)
),
monthly_activity AS (
    SELECT
        cb.cohort_month,
        cb.customer_id,
        DATEDIFF('month', cb.cohort_month,
            DATE_TRUNC('month', o.order_date))      AS month_number
    FROM cohort_base cb
    JOIN orders o USING (customer_id)
    WHERE month_number BETWEEN 0 AND 5
),
cohort_counts AS (
    SELECT DATE_TRUNC('month', signup_date) AS cohort_month, COUNT(*) AS cohort_size
    FROM customers GROUP BY cohort_month
)
SELECT
    ma.cohort_month,
    cc.cohort_size,
    ROUND(COUNT(DISTINCT CASE WHEN month_number=0 THEN ma.customer_id END)*100.0/cc.cohort_size,1) AS m0_pct,
    ROUND(COUNT(DISTINCT CASE WHEN month_number=1 THEN ma.customer_id END)*100.0/cc.cohort_size,1) AS m1_pct,
    ROUND(COUNT(DISTINCT CASE WHEN month_number=2 THEN ma.customer_id END)*100.0/cc.cohort_size,1) AS m2_pct,
    ROUND(COUNT(DISTINCT CASE WHEN month_number=3 THEN ma.customer_id END)*100.0/cc.cohort_size,1) AS m3_pct,
    ROUND(COUNT(DISTINCT CASE WHEN month_number=4 THEN ma.customer_id END)*100.0/cc.cohort_size,1) AS m4_pct,
    ROUND(COUNT(DISTINCT CASE WHEN month_number=5 THEN ma.customer_id END)*100.0/cc.cohort_size,1) AS m5_pct
FROM monthly_activity ma
JOIN cohort_counts cc USING (cohort_month)
GROUP BY ma.cohort_month, cc.cohort_size
ORDER BY ma.cohort_month;


-- ------------------------------------------------------------
-- 3. Revenue retention by cohort
--
-- Same structure as customer retention, but using revenue
-- instead of distinct customer count — shows whether retained
-- customers are spending more or less over time.
-- ------------------------------------------------------------
WITH cohort_base AS (
    SELECT
        c.customer_id,
        DATE_TRUNC('month', c.signup_date) AS cohort_month
    FROM customers c
),
monthly_revenue AS (
    SELECT
        cb.cohort_month,
        DATEDIFF('month', cb.cohort_month,
            DATE_TRUNC('month', o.order_date))  AS month_number,
        SUM(o.total_amount)                     AS revenue
    FROM cohort_base cb
    JOIN orders o USING (customer_id)
    WHERE DATEDIFF('month', cb.cohort_month,
            DATE_TRUNC('month', o.order_date)) BETWEEN 0 AND 5
    GROUP BY cb.cohort_month, month_number
),
m0 AS (
    SELECT cohort_month, revenue AS base_revenue
    FROM monthly_revenue WHERE month_number = 0
)
SELECT
    mr.cohort_month,
    mr.month_number,
    ROUND(mr.revenue, 2)                                AS revenue,
    ROUND(mr.revenue / m0.base_revenue * 100, 1)        AS revenue_retention_pct
FROM monthly_revenue mr
JOIN m0 USING (cohort_month)
ORDER BY mr.cohort_month, mr.month_number;

-- ============================================================
-- Funnel Analysis
-- Dataset: events.csv (sessions through page_view → purchase)
-- Steps: page_view → product_view → add_to_cart → checkout → purchase
-- ============================================================


-- ------------------------------------------------------------
-- 1. Overall funnel conversion rates
--
-- Count distinct sessions that reached each step and compute
-- the step-over-step drop-off rate. This is the standard
-- funnel query pattern in e-commerce analytics.
-- ------------------------------------------------------------
WITH step_counts AS (
    SELECT
        event_type,
        COUNT(DISTINCT session_id)                          AS sessions
    FROM events
    WHERE event_type IN ('page_view','product_view','add_to_cart','checkout','purchase')
    GROUP BY event_type
),
ordered AS (
    SELECT
        event_type,
        sessions,
        CASE event_type
            WHEN 'page_view'     THEN 1
            WHEN 'product_view'  THEN 2
            WHEN 'add_to_cart'   THEN 3
            WHEN 'checkout'      THEN 4
            WHEN 'purchase'      THEN 5
        END AS step_num
    FROM step_counts
)
SELECT
    step_num,
    event_type,
    sessions,
    LAG(sessions) OVER (ORDER BY step_num)          AS prev_step_sessions,
    ROUND(
        sessions * 100.0
        / FIRST_VALUE(sessions) OVER (ORDER BY step_num),
        1
    )                                               AS pct_of_top,
    ROUND(
        sessions * 100.0
        / NULLIF(LAG(sessions) OVER (ORDER BY step_num), 0),
        1
    )                                               AS step_conversion_pct
FROM ordered
ORDER BY step_num;


-- ------------------------------------------------------------
-- 2. Funnel by channel (Web / Mobile / In-Store)
--
-- Join events back to orders to get the channel for sessions
-- that converted; treat non-converting sessions separately.
-- Shows which channel has the highest checkout conversion.
-- ------------------------------------------------------------
WITH session_channel AS (
    SELECT DISTINCT e.session_id, o.channel
    FROM events e
    LEFT JOIN orders o ON e.customer_id = o.customer_id
        AND DATE_TRUNC('day', CAST(e.event_timestamp AS TIMESTAMP))
            = CAST(o.order_date AS DATE)
    WHERE o.channel IS NOT NULL
),
step_channel AS (
    SELECT
        COALESCE(sc.channel, 'Unknown') AS channel,
        e.event_type,
        COUNT(DISTINCT e.session_id)    AS sessions
    FROM events e
    LEFT JOIN session_channel sc USING (session_id)
    WHERE e.event_type IN ('page_view','add_to_cart','purchase')
    GROUP BY channel, e.event_type
)
SELECT * FROM step_channel ORDER BY channel, event_type;


-- ------------------------------------------------------------
-- 3. Time between funnel steps (median seconds)
--
-- Slow steps are friction points. Computing the median time
-- between consecutive events per session shows where users
-- hesitate — useful for UX prioritisation.
-- ------------------------------------------------------------
WITH step_times AS (
    SELECT
        session_id,
        event_type,
        event_timestamp,
        LEAD(event_timestamp) OVER (
            PARTITION BY session_id ORDER BY event_timestamp
        )                               AS next_event_timestamp,
        LEAD(event_type) OVER (
            PARTITION BY session_id ORDER BY event_timestamp
        )                               AS next_event_type
    FROM events
)
SELECT
    event_type                          AS from_step,
    next_event_type                     AS to_step,
    COUNT(*)                            AS transitions,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EPOCH(
                CAST(next_event_timestamp AS TIMESTAMP)
                - CAST(event_timestamp AS TIMESTAMP)
            )
        ), 0
    )                                   AS median_seconds
FROM step_times
WHERE next_event_type IS NOT NULL
GROUP BY from_step, to_step
ORDER BY from_step, to_step;

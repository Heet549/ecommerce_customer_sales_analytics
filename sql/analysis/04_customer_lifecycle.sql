-- =====================================================================
-- 04_customer_lifecycle.sql
-- PHASE 2D — Customer lifecycle analysis
--
-- METHODOLOGY NOTE (full detail in docs/customer_lifecycle_definition.md):
-- Phase 1 established that signup_date is NOT chronologically reliable
-- relative to order_date (~49.7% of orders predate the customer's own
-- signup_date). Therefore this lifecycle analysis does NOT use
-- signup_date at all — no "days since signup", "new vs. existing at
-- signup" or "time to first purchase" logic appears anywhere below.
--
-- Instead, lifecycle segments are built entirely from internally
-- consistent data within the orders table itself:
--   - order_count   = how many orders a customer has placed
--   - recency_days  = days between a customer's most recent order and
--                     the dataset's own snapshot date (MAX(order_date)
--                     across all orders, i.e. 2025-11-14) — a standard
--                     RFM-style approach that never compares order_date
--                     against another table's date column.
--
-- Segments:
--   One-Time         : exactly 1 order (recency not relevant)
--   Repeat - Active   : 2+ orders AND most recent order within 180 days
--                        of the dataset snapshot date
--   Repeat - Lapsed   : 2+ orders AND most recent order more than 180
--                        days before the dataset snapshot date
--   Never Purchased   : registered user, 0 orders (shown separately,
--                        not part of the 3 buying segments above)
-- The 180-day cutoff is a business judgment call over a ~22.5-month
-- data window, not a value discovered in the data — this is documented
-- explicitly (not hidden) in docs/customer_lifecycle_definition.md.
-- =====================================================================

USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- Business Question: What does each customer's order-based lifecycle
-- segment look like, and how many customers fall into each segment?
-- Why it matters: gives the business an actionable, defensible view of
-- who is a new/one-time buyer, who is actively repeating, and who is a
-- repeat customer that has gone quiet (win-back candidate) — without
-- relying on the unreliable signup_date field.
-- Calculation:
--   1. `customer_orders` CTE: one row per customer with order_count,
--      last_order_date, total_spend (safe aggregation, no join yet).
--   2. `snapshot` CTE: single-row scalar for MAX(order_date) across all
--      orders, computed once and reused (avoids repeating the subquery).
--   3. Final SELECT classifies each customer using CASE logic against
--      those two CTEs.
-- ---------------------------------------------------------------------
WITH customer_orders AS (
    SELECT
        user_id,
        COUNT(order_id)     AS order_count,
        MAX(order_date)     AS last_order_date,
        SUM(total_amount)   AS total_spend
    FROM orders
    GROUP BY user_id
),
snapshot AS (
    SELECT MAX(order_date) AS snapshot_date FROM orders
)
SELECT
    co.user_id,
    co.order_count,
    co.last_order_date,
    co.total_spend,
    TIMESTAMPDIFF(MICROSECOND, co.last_order_date, s.snapshot_date) / 86400000000.0                      AS recency_days,
    CASE
        WHEN co.order_count = 1 THEN 'One-Time'
        WHEN co.order_count > 1 AND TIMESTAMPDIFF(MICROSECOND, co.last_order_date, s.snapshot_date) / 86400000000.0 <= 180
            THEN 'Repeat - Active'
        WHEN co.order_count > 1 AND TIMESTAMPDIFF(MICROSECOND, co.last_order_date, s.snapshot_date) / 86400000000.0 > 180
            THEN 'Repeat - Lapsed'
    END                                                                 AS lifecycle_segment
FROM customer_orders co
CROSS JOIN snapshot s
ORDER BY co.total_spend DESC;

-- ---------------------------------------------------------------------
-- Business Question: Summary — how many customers, and how much
-- revenue/average spend, does each lifecycle segment represent?
-- Why it matters: this is the number the business actually acts on
-- (e.g. sizing a win-back campaign for "Repeat - Lapsed").
-- ---------------------------------------------------------------------
WITH customer_orders AS (
    SELECT
        user_id,
        COUNT(order_id)     AS order_count,
        MAX(order_date)     AS last_order_date,
        SUM(total_amount)   AS total_spend
    FROM orders
    GROUP BY user_id
),
snapshot AS (
    SELECT MAX(order_date) AS snapshot_date FROM orders
),
segmented AS (
    SELECT
        co.user_id,
        co.total_spend,
        CASE
            WHEN co.order_count = 1 THEN 'One-Time'
            WHEN co.order_count > 1 AND TIMESTAMPDIFF(MICROSECOND, co.last_order_date, s.snapshot_date) / 86400000000.0 <= 180
                THEN 'Repeat - Active'
            WHEN co.order_count > 1 AND TIMESTAMPDIFF(MICROSECOND, co.last_order_date, s.snapshot_date) / 86400000000.0 > 180
                THEN 'Repeat - Lapsed'
        END AS lifecycle_segment
    FROM customer_orders co
    CROSS JOIN snapshot s
)
SELECT
    lifecycle_segment,
    COUNT(*)                                                           AS num_customers,
    SUM(total_spend)                                                   AS segment_revenue,
    ROUND(AVG(total_spend), 2)                                         AS avg_spend_per_customer
FROM segmented
GROUP BY lifecycle_segment
ORDER BY segment_revenue DESC;

-- ---------------------------------------------------------------------
-- Business Question: How many registered users fall entirely outside
-- the buying lifecycle (never placed an order)?
-- Why it matters: completes the picture alongside the 3 buying segments
-- above — shown separately because they have no order to base a
-- lifecycle stage on.
-- ---------------------------------------------------------------------
SELECT
    COUNT(*) AS never_purchased_users
FROM users u
LEFT JOIN orders o ON o.user_id = u.user_id
WHERE o.order_id IS NULL;

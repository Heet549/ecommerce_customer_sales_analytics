-- =====================================================================
-- 03_customer_analysis.sql
-- PHASE 2C — Customer-level metrics based on actual order history.
--
-- All metrics here are built from a single per-customer aggregation
-- (orders GROUP BY user_id). Grouping first, then joining to users for
-- display attributes (gender/city), keeps the grain at 1 row per
-- customer throughout and avoids any risk of an order being counted
-- more than once.
-- =====================================================================

USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- Business Question: For every purchasing customer, what does their
-- order history look like — order count, total spend, AOV, first/last
-- order date?
-- Why it matters: this is the base customer-metrics table that every
-- other query in this file (and the lifecycle analysis in
-- 04_customer_lifecycle.sql) builds on.
-- Calculation: one row per user_id via GROUP BY on orders directly
-- (order_id is the order grain, so COUNT(order_id) here is a safe,
-- non-inflated order count per customer).
-- ---------------------------------------------------------------------
SELECT
    o.user_id,
    u.name,
    u.gender,
    u.city,
    COUNT(o.order_id)                                                  AS order_count,
    SUM(o.total_amount)                                                AS total_spend,
    ROUND(SUM(o.total_amount) / COUNT(o.order_id), 2)                  AS avg_order_value,
    MIN(o.order_date)                                                  AS first_order_date,
    MAX(o.order_date)                                                  AS latest_order_date
FROM orders o
INNER JOIN users u ON u.user_id = o.user_id
GROUP BY o.user_id, u.name, u.gender, u.city
ORDER BY total_spend DESC;

-- ---------------------------------------------------------------------
-- Business Question: Who are the top 20 highest-value customers by
-- total spend?
-- Why it matters: PROJECT_OVERVIEW.md business question 4.
-- ---------------------------------------------------------------------
SELECT
    o.user_id,
    u.name,
    u.city,
    COUNT(o.order_id)                                                  AS order_count,
    SUM(o.total_amount)                                                AS total_spend
FROM orders o
INNER JOIN users u ON u.user_id = o.user_id
GROUP BY o.user_id, u.name, u.city
ORDER BY total_spend DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- Business Question: What does purchase frequency look like across the
-- customer base — how many customers place 1, 2, 3... orders?
-- Why it matters: PROJECT_OVERVIEW.md business question 5; also the
-- direct evidence behind the repeat/one-time KPI in 01_business_kpis.sql.
-- Calculation: CTE aggregates orders per customer first; outer query
-- then groups customers by that count (a group-of-groups pattern) —
-- this two-step CTE avoids the mistake of counting orders directly
-- against a non-aggregated customer list.
-- ---------------------------------------------------------------------
WITH orders_per_customer AS (
    SELECT user_id, COUNT(order_id) AS order_count
    FROM orders
    GROUP BY user_id
)
SELECT
    order_count,
    COUNT(*)                                                           AS num_customers,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders_per_customer), 2)
                                                                         AS pct_of_purchasing_customers
FROM orders_per_customer
GROUP BY order_count
ORDER BY order_count;

-- ---------------------------------------------------------------------
-- Business Question: One-time vs. repeat customer classification, with
-- comparative spend behavior.
-- Why it matters: repeat customers are typically the more valuable
-- segment — this quantifies that for this dataset specifically instead
-- of assuming it.
-- Definition used (matches project instructions):
--   One-time customer = exactly 1 order
--   Repeat customer    = more than 1 order
-- ---------------------------------------------------------------------
WITH orders_per_customer AS (
    SELECT
        user_id,
        COUNT(order_id)   AS order_count,
        SUM(total_amount) AS total_spend
    FROM orders
    GROUP BY user_id
)
SELECT
    CASE WHEN order_count = 1 THEN 'One-Time Customer' ELSE 'Repeat Customer' END AS customer_type,
    COUNT(*)                                                           AS num_customers,
    SUM(total_spend)                                                   AS segment_total_revenue,
    ROUND(AVG(total_spend), 2)                                         AS avg_spend_per_customer,
    ROUND(AVG(order_count), 2)                                         AS avg_orders_per_customer
FROM orders_per_customer
GROUP BY CASE WHEN order_count = 1 THEN 'One-Time Customer' ELSE 'Repeat Customer' END;

-- ---------------------------------------------------------------------
-- Business Question: How is the (purchasing) customer base distributed
-- by gender and by city?
-- Why it matters: PROJECT_OVERVIEW.md business question 7.
-- ---------------------------------------------------------------------
SELECT
    u.gender,
    COUNT(DISTINCT u.user_id)                                          AS registered_customers,
    COUNT(DISTINCT o.user_id)                                          AS purchasing_customers,
    SUM(o.total_amount)                                                AS revenue
FROM users u
LEFT JOIN orders o ON o.user_id = u.user_id
GROUP BY u.gender
ORDER BY revenue DESC;

SELECT
    u.city,
    COUNT(DISTINCT u.user_id)                                          AS registered_customers,
    COUNT(DISTINCT o.user_id)                                          AS purchasing_customers,
    SUM(o.total_amount)                                                AS revenue
FROM users u
LEFT JOIN orders o ON o.user_id = u.user_id
GROUP BY u.city
ORDER BY revenue DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- Business Question: Which registered users have never placed an order?
-- Why it matters: a "registered but never purchased" segment is a real,
-- addressable marketing audience (Phase 1 Issue 6 — 1,365 such users).
-- Calculation: LEFT JOIN from users, filtering WHERE the joined order_id
-- IS NULL — the standard, correct anti-join pattern (no orphaned FK is
-- involved here; this is expected business reality, not a data defect).
-- ---------------------------------------------------------------------
SELECT
    u.user_id,
    u.name,
    u.gender,
    u.city
FROM users u
LEFT JOIN orders o ON o.user_id = u.user_id
WHERE o.order_id IS NULL;

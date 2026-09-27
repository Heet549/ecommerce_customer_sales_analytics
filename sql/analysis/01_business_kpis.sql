-- =====================================================================
-- 01_business_kpis.sql
-- PHASE 2A — Top-line business KPIs
--
-- Data source: ecommerce_analytics database, built in Phase 1
-- (sql/02_create_tables.sql). All figures below come from the actual
-- 20,000-row orders table and 43,525-row order_items table.
--
-- KEY VALIDATION FACT (from Phase 1 data_quality_report.md, re-confirmed
-- here in sql/validation/): orders.total_amount is verified identical to
-- SUM(order_items.item_total) for every one of the 20,000 orders. This
-- means:
--   - Revenue can be summed directly from orders.total_amount WITHOUT
--     joining order_items, which avoids the classic 1-order-to-many-items
--     double-counting mistake.
--   - Any KPI that genuinely needs order_items (e.g. items sold) is
--     calculated from order_items directly, not by multiplying order-level
--     values across joined rows.
--
-- order_status values observed: processing, shipped, completed, cancelled,
-- returned. Because cancelled/returned orders did not result in kept
-- revenue, KPIs are shown in two versions where relevant:
--   - GROSS  = all orders, any status (what was originally transacted)
--   - NET    = excludes cancelled and returned orders (what the business
--              actually kept)
-- Neither version is "more correct" than the other; they answer different
-- questions and are both labeled explicitly below.
-- =====================================================================

USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- KPI 1: Total Revenue (Gross vs Net)
-- Calculation: Gross = SUM(orders.total_amount) across all orders.
--              Net   = SUM(orders.total_amount) excluding order_status
--                      IN ('cancelled','returned').
-- Why it matters: baseline revenue figure for every other ratio KPI.
-- ---------------------------------------------------------------------
SELECT
    SUM(total_amount)                                                   AS gross_revenue_all_orders,
    SUM(CASE WHEN order_status NOT IN ('cancelled','returned')
             THEN total_amount ELSE 0 END)                               AS net_revenue_excl_cancel_return,
    SUM(CASE WHEN order_status IN ('cancelled','returned')
             THEN total_amount ELSE 0 END)                               AS revenue_lost_to_cancel_return
FROM orders;

-- ---------------------------------------------------------------------
-- KPI 2: Total Orders
-- Calculation: COUNT(DISTINCT order_id). DISTINCT is defensive (order_id
-- is already the primary key / verified unique in Phase 1), it guards
-- against accidental row multiplication if this query is ever adapted
-- to include a JOIN.
-- Why it matters: order volume is the denominator for AOV and a core
-- health metric on its own.
-- ---------------------------------------------------------------------
SELECT
    COUNT(DISTINCT order_id)                                            AS total_orders_all_status,
    COUNT(DISTINCT CASE WHEN order_status NOT IN ('cancelled','returned')
                        THEN order_id END)                               AS total_orders_net
FROM orders;

-- ---------------------------------------------------------------------
-- KPI 3: Total Customers
-- Calculation: two distinct populations, both useful:
--   - registered_customers = every row in users (whether or not they
--     ever ordered; 1,365 of them never did — see Issue 6 in Phase 1
--     data_quality_report.md)
--   - purchasing_customers = COUNT(DISTINCT user_id) in orders
-- Why it matters: "how many customers do we have" is ambiguous without
-- separating registered base from actual buyers.
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(DISTINCT user_id) FROM users)                         AS registered_customers,
    (SELECT COUNT(DISTINCT user_id) FROM orders)                        AS purchasing_customers,
    (SELECT COUNT(DISTINCT user_id) FROM users) -
    (SELECT COUNT(DISTINCT user_id) FROM orders)                        AS registered_never_purchased;

-- ---------------------------------------------------------------------
-- KPI 4: Total Items Sold
-- Calculation: SUM(order_items.quantity) across all line items. This is
-- the one KPI that legitimately requires order_items (there is no
-- item-count column on orders itself).
-- Why it matters: distinguishes "how many orders" from "how many units"
-- — an order can contain multiple units of multiple products
-- (avg ~2.18 line items per order, verified in Phase 1 data_model.md;
-- note: total units sold = 60,818, giving ~3.04 units per order).
-- ---------------------------------------------------------------------
SELECT
    SUM(quantity)                                                       AS total_items_sold,
    COUNT(DISTINCT order_id)                                            AS orders_represented,
    ROUND(SUM(quantity) / COUNT(DISTINCT order_id), 2)                  AS avg_units_per_order
FROM order_items;

-- ---------------------------------------------------------------------
-- KPI 5: Average Order Value (AOV)
-- Calculation: SUM(total_amount) / COUNT(DISTINCT order_id), computed
-- directly from the orders table (grain = 1 row per order, so no
-- order_items join is needed and no double-counting risk exists here).
-- Why it matters: standard e-commerce health metric; tracked over time
-- in 02_sales_analysis.sql.
-- ---------------------------------------------------------------------
SELECT
    ROUND(SUM(total_amount) / COUNT(DISTINCT order_id), 2)              AS avg_order_value_gross,
    ROUND(
        SUM(CASE WHEN order_status NOT IN ('cancelled','returned')
                 THEN total_amount ELSE 0 END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_status NOT IN ('cancelled','returned')
                                      THEN order_id END), 0)
    , 2)                                                                 AS avg_order_value_net
FROM orders;

-- ---------------------------------------------------------------------
-- KPI 6: Average Revenue per Customer
-- Calculation: SUM(total_amount) / COUNT(DISTINCT user_id), scoped to
-- users who placed at least one order (purchasing_customers). Using the
-- full registered base as the denominator would understate the figure
-- for no analytical reason, since never-purchased users contribute 0.
-- Why it matters: customer-value benchmark independent of order count.
-- ---------------------------------------------------------------------
SELECT
    ROUND(SUM(total_amount) / COUNT(DISTINCT user_id), 2)               AS avg_revenue_per_purchasing_customer
FROM orders;

-- ---------------------------------------------------------------------
-- KPI 7 & 8: Repeat Customer Rate and One-Time Customer Rate
-- Calculation:
--   1. CTE `orders_per_customer` collapses orders to one row per
--      user_id with COUNT(order_id) — this pre-aggregation is what
--      prevents the later classification from double-counting a
--      customer once per order.
--   2. A customer is "one-time" if their order count = 1, "repeat" if
--      order count > 1 (definition explicitly requested — based on
--      actual order history, not signup/order date sequencing).
--   3. Rates are expressed as a % of purchasing customers (customers
--      with >= 1 order), not of the full registered base, because
--      never-purchased users cannot logically be "one-time" or
--      "repeat" buyers.
-- Why it matters: core retention signal available from this dataset
-- (see Phase 2D for why a date-based lifecycle metric is NOT used).
-- ---------------------------------------------------------------------
WITH orders_per_customer AS (
    SELECT
        user_id,
        COUNT(order_id) AS order_count
    FROM orders
    GROUP BY user_id
)
SELECT
    COUNT(*)                                                            AS purchasing_customers,
    SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END)                    AS one_time_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)                    AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                                 AS one_time_customer_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                                 AS repeat_customer_rate_pct
FROM orders_per_customer;

-- ---------------------------------------------------------------------
-- KPI 9: Order Status Mix (supporting context for Gross vs Net above)
-- Calculation: COUNT and SUM(total_amount) grouped by order_status.
-- Why it matters: answers PROJECT_OVERVIEW.md business question 3 —
-- "what share of orders end up cancelled or returned, and what revenue
-- does that represent?"
-- ---------------------------------------------------------------------
SELECT
    order_status,
    COUNT(*)                                                            AS order_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders), 2)          AS pct_of_orders,
    SUM(total_amount)                                                   AS revenue,
    ROUND(100.0 * SUM(total_amount) / (SELECT SUM(total_amount) FROM orders), 2)
                                                                          AS pct_of_gross_revenue
FROM orders
GROUP BY order_status
ORDER BY revenue DESC;

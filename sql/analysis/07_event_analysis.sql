-- =====================================================================
-- 07_event_analysis.sql
-- PHASE 2G — Event / behavioral analysis
--
-- ACTUAL EVENT TYPES OBSERVED (verified against the provided data, not
-- assumed): 'view', 'cart', 'wishlist', 'purchase' — 4 distinct values,
-- 80,000 total event rows. events has no order_id column, so an
-- individual event row cannot be tied back to a specific row in the
-- orders table; it is an independent behavioral log keyed on
-- (user_id, product_id, event_type, event_timestamp) only.
--
-- FUNNEL SCOPE NOTE: Phase 1 established that event_timestamp is not
-- chronologically reliable relative to signup_date (~49.6% of events
-- predate the acting user's signup_date), and events cannot be linked to
-- a specific order at all. Therefore the funnel below is an AGGREGATE
-- funnel — how many distinct users/products reached each stage overall
-- — NOT a per-user chronological sequence (view happened before cart
-- before purchase, etc.). This is stated explicitly in every funnel
-- query's comment and again in docs/sql_analysis_summary.md.
-- =====================================================================

USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- Business Question: What is the overall volume and reach of each event
-- type?
-- Why it matters: PROJECT_OVERVIEW.md business question 11 — which
-- event type is most common, and how does engagement break down.
-- Calculation: GROUP BY event_type on the events table directly (1 row
-- = 1 event, no join, no double-counting risk).
-- ---------------------------------------------------------------------
SELECT
    event_type,
    COUNT(*)                                                            AS event_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM events), 2)          AS pct_of_all_events,
    COUNT(DISTINCT user_id)                                             AS distinct_users,
    COUNT(DISTINCT product_id)                                          AS distinct_products
FROM events
GROUP BY event_type
ORDER BY event_count DESC;

-- ---------------------------------------------------------------------
-- Business Question: Aggregate engagement funnel — how many distinct
-- users are represented at each stage (view / cart / wishlist /
-- purchase-event)?
-- Why it matters: PROJECT_OVERVIEW.md business question 10. This is the
-- only funnel version the data legitimately supports (see scope note
-- above) — a count of distinct users reaching each stage at all, not a
-- verified per-user progression through the stages in order.
-- Calculation: four independent scalar subqueries, one per event_type,
-- each using COUNT(DISTINCT user_id) so a user with many view events is
-- still counted once at the "view" stage.
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(DISTINCT user_id) FROM events WHERE event_type = 'view')      AS users_viewed,
    (SELECT COUNT(DISTINCT user_id) FROM events WHERE event_type = 'cart')      AS users_carted,
    (SELECT COUNT(DISTINCT user_id) FROM events WHERE event_type = 'wishlist')  AS users_wishlisted,
    (SELECT COUNT(DISTINCT user_id) FROM events WHERE event_type = 'purchase')  AS users_purchase_event;

-- Same funnel expressed as a stage-over-stage drop-off percentage
-- (each stage as % of the 'view' stage, the widest part of the funnel).
WITH stage_users AS (
    SELECT
        (SELECT COUNT(DISTINCT user_id) FROM events WHERE event_type = 'view')     AS view_u,
        (SELECT COUNT(DISTINCT user_id) FROM events WHERE event_type = 'cart')     AS cart_u,
        (SELECT COUNT(DISTINCT user_id) FROM events WHERE event_type = 'wishlist') AS wishlist_u,
        (SELECT COUNT(DISTINCT user_id) FROM events WHERE event_type = 'purchase') AS purchase_u
)
SELECT
    'view'      AS stage, view_u      AS distinct_users, 100.0 AS pct_of_view_stage FROM stage_users
UNION ALL
SELECT
    'cart', cart_u, ROUND(100.0 * cart_u / view_u, 2) FROM stage_users
UNION ALL
SELECT
    'wishlist', wishlist_u, ROUND(100.0 * wishlist_u / view_u, 2) FROM stage_users
UNION ALL
SELECT
    'purchase_event', purchase_u, ROUND(100.0 * purchase_u / view_u, 2) FROM stage_users;

-- ---------------------------------------------------------------------
-- Business Question: Which products generate the most engagement
-- (views), and which have a comparatively high purchase-event share of
-- their engagement (view-to-purchase-event ratio)?
-- Why it matters: PROJECT_OVERVIEW.md business question 9 — products
-- purchased most vs. most viewed. A high ratio flags products that
-- convert engagement efficiently; a low ratio flags high-interest,
-- low-conversion products worth investigating.
-- Calculation: conditional aggregation (CASE inside SUM) pivots
-- event_type into columns per product in a single pass, avoiding 4
-- separate GROUP BY queries joined together. Minimum 10 views applied
-- in HAVING to avoid a low-traffic product showing a noisy/misleading
-- ratio (e.g. 1 view + 1 purchase-event = 100%).
-- ---------------------------------------------------------------------
SELECT
    e.product_id,
    p.product_name,
    p.category,
    SUM(CASE WHEN e.event_type = 'view'      THEN 1 ELSE 0 END)         AS views,
    SUM(CASE WHEN e.event_type = 'cart'      THEN 1 ELSE 0 END)         AS cart_adds,
    SUM(CASE WHEN e.event_type = 'wishlist'  THEN 1 ELSE 0 END)         AS wishlist_adds,
    SUM(CASE WHEN e.event_type = 'purchase'  THEN 1 ELSE 0 END)         AS purchase_events,
    ROUND(
        100.0 * SUM(CASE WHEN e.event_type = 'purchase' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN e.event_type = 'view' THEN 1 ELSE 0 END), 0)
    , 2)                                                                 AS view_to_purchase_event_pct
FROM events e
INNER JOIN products p ON p.product_id = e.product_id
GROUP BY e.product_id, p.product_name, p.category
HAVING SUM(CASE WHEN e.event_type = 'view' THEN 1 ELSE 0 END) >= 10
ORDER BY views DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- Business Question: Which product categories generate the most overall
-- engagement, and does engagement volume line up with actual sales
-- volume from order_items (association only, no causal claim)?
-- Why it matters: shows whether browsing/cart/wishlist interest at a
-- category level lines up with what the category actually sells.
-- Calculation: events aggregated to category grain in one CTE, actual
-- sales (order_items, the correct line-item grain) aggregated to
-- category grain in a second CTE, then joined on category. Two separate
-- source-of-truth aggregations joined at the end avoids inflating either
-- figure by joining events directly to order_items (they share no key).
-- ---------------------------------------------------------------------
WITH category_events AS (
    SELECT
        p.category,
        SUM(CASE WHEN e.event_type = 'view'     THEN 1 ELSE 0 END) AS views,
        SUM(CASE WHEN e.event_type = 'cart'     THEN 1 ELSE 0 END) AS cart_adds,
        SUM(CASE WHEN e.event_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_events
    FROM events e
    INNER JOIN products p ON p.product_id = e.product_id
    GROUP BY p.category
),
category_sales AS (
    SELECT
        p.category,
        SUM(oi.quantity)   AS units_sold,
        SUM(oi.item_total) AS revenue
    FROM order_items oi
    INNER JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.category
)
SELECT
    ce.category,
    ce.views,
    ce.cart_adds,
    ce.purchase_events,
    cs.units_sold,
    cs.revenue
FROM category_events ce
INNER JOIN category_sales cs ON cs.category = ce.category
ORDER BY ce.views DESC;

-- ---------------------------------------------------------------------
-- Business Question: How does logged event activity compare between
-- users who are actual purchasing customers (>=1 row in orders) and
-- users who are not?
-- Why it matters: sanity-check on whether behavioral activity in events
-- relates at all to real purchasing behavior in orders — reported as an
-- association between two independently-sourced tables (both joined
-- only on user_id, never on date), not a chronological or causal claim.
-- Calculation: LEFT JOIN from users to orders classifies every user as
-- purchasing/non-purchasing (anti-join pattern, same as Phase 2C/2D);
-- LEFT JOIN from users to events aggregates event counts per user
-- (LEFT JOIN keeps the 5 users with zero events, per Phase 1 Issue 7,
-- showing 0 rather than disappearing).
-- ---------------------------------------------------------------------
WITH user_purchase_flag AS (
    SELECT u.user_id,
           CASE WHEN o.user_id IS NULL THEN 'Never Purchased' ELSE 'Purchasing Customer' END AS purchase_flag
    FROM users u
    LEFT JOIN (SELECT DISTINCT user_id FROM orders) o ON o.user_id = u.user_id
),
user_event_counts AS (
    SELECT u.user_id, COUNT(e.event_id) AS total_events
    FROM users u
    LEFT JOIN events e ON e.user_id = u.user_id
    GROUP BY u.user_id
)
SELECT
    upf.purchase_flag,
    COUNT(*)                                                            AS num_users,
    ROUND(AVG(uec.total_events), 2)                                     AS avg_events_per_user
FROM user_purchase_flag upf
INNER JOIN user_event_counts uec ON uec.user_id = upf.user_id
GROUP BY upf.purchase_flag;

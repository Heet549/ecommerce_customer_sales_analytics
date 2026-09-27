# Phase 2 — SQL Business Analysis Summary

This document summarizes the SQL analysis built in `sql/analysis/` on
top of the Phase 1 database (`sql/02_create_tables.sql`). Every number
below was actually calculated against the provided CSV dataset (via the
SQLite functional-proxy method described in `sql/validation/` and
`docs/phase2_validation_raw_output.txt`) — none are estimated or
invented.

## Files in this phase

```
sql/analysis/
├── 01_business_kpis.sql        Phase 2A — top-line KPIs
├── 02_sales_analysis.sql       Phase 2B — revenue/order trends, product & category performance
├── 03_customer_analysis.sql    Phase 2C — customer-level metrics
├── 04_customer_lifecycle.sql   Phase 2D — order-behavior-based lifecycle segments
├── 05_product_analysis.sql     Phase 2E — product performance analysis
├── 06_review_analysis.sql      Phase 2F — review/rating analysis (no NLP)
└── 07_event_analysis.sql       Phase 2G — behavioral/funnel analysis

sql/validation/
└── 01_phase2_analysis_validation.sql   Cross-checks proving no double-counting

docs/
├── customer_lifecycle_definition.md    Full lifecycle methodology (Phase 2D)
├── sql_analysis_summary.md             This file
└── phase2_validation_raw_output.txt    Raw output of every validation query, run against the provided dataset
```

## Key validated business figures

| Metric | Value |
|---|---|
| Gross revenue (all orders) | $11,918,668.95 |
| Net revenue (excl. cancelled/returned) | $7,193,050.80 |
| Revenue lost to cancelled/returned orders | $4,725,618.15 |
| Total orders | 20,000 |
| Registered customers | 10,000 |
| Purchasing customers (≥1 order) | 8,635 |
| Never-purchased registered users | 1,365 |
| Total items sold (units) | 60,818 |
| Average order value (gross) | $595.93 |
| Average revenue per purchasing customer | $1,380.27 |
| One-time customers | 2,741 (31.74% of purchasing customers) |
| Repeat customers | 5,894 (68.26% of purchasing customers) |
| Lifecycle: One-Time | 2,741 customers |
| Lifecycle: Repeat - Active (last order ≤180 days from snapshot) | 3,366 customers |
| Lifecycle: Repeat - Lapsed (last order >180 days from snapshot) | 2,528 customers |
| Products never sold | 0 of 2,000 |
| Products with zero reviews | 1 of 2,000 |
| Overall average review rating | 3.54 / 5 |
| Overall average catalog rating (products.rating) | 3.68 / 5 |

## Analyses performed

**Sales (2B):** monthly revenue/order/AOV trend across the full
2024-01 to 2025-11 window (both gross and net of
cancelled/returned orders); top products by revenue and by units sold;
category revenue, order volume, and revenue-share; brand revenue;
per-category top-selling product.

**Customers (2C):** full per-customer metrics table (order count, total
spend, AOV, first/last order date); top 20 customers by spend; purchase
frequency distribution; one-time vs. repeat segment comparison; revenue
by gender and city; registered-but-never-purchased user list.

**Customer Lifecycle (2D):** order-count- and order-recency-based
lifecycle segmentation (One-Time / Repeat-Active / Repeat-Lapsed /
Never-Purchased). Full methodology and rationale in
`docs/customer_lifecycle_definition.md` — **does not use `signup_date`
anywhere.**

**Products (2E):** full per-product performance table with revenue
share; lowest 20 performers by revenue; never-sold-product check
(returned 0 rows — every product in the catalog sold at least once);
category performance summary; high-volume/lower-revenue and
high-revenue/lower-volume product patterns via `RANK()` window
functions.

**Reviews (2F):** overall rating distribution; catalog rating
(`products.rating`) vs. review-derived average rating comparison;
top/bottom 15 rated products (minimum 5 reviews to avoid noise from
low-volume products); category and brand average ratings; canned-phrase
frequency and distribution by rating; rating-band vs. sales association
(descriptive only, no causal claim).

**Events (2G):** event-type volume and reach (`view`/`cart`/`wishlist`/
`purchase`); aggregate engagement funnel (distinct users reaching each
stage, expressed as % of the `view` stage); per-product engagement and
view-to-purchase-event ratio; category-level engagement vs. actual
sales; event activity comparison between purchasing and non-purchasing
users.

## Important data findings (beyond what Phase 1 already established)

- **`orders.total_amount` reconciles exactly with `SUM(order_items.item_total)`**
  for the full dataset (both equal $11,918,668.95) — confirmed again
  independently in Phase 2, not just assumed from the Phase 1 report.
- **Every one of the 2,000 catalog products was sold at least once** —
  the "never-sold products" query (2E) returns 0 rows. This is a
  genuine finding, not a missing/broken query.
- **Only 1 of 2,000 products has zero reviews** — review coverage is
  essentially complete across the catalog.
- **Review phrase frequency does not concentrate meaningfully by
  rating.** Each of the 10 canned phrases appears across the full 1–5
  rating range at broadly similar frequency (e.g. "Excellent product,
  will buy again." appears on 1-star reviews nearly as often as on
  5-star reviews). This independently reinforces Phase 1's finding that
  `review_text` is a random categorical tag, not a genuine sentiment
  signal — and is additional evidence for why no NLP/sentiment work was
  attempted on it.
- **Average logged event activity is essentially identical for
  purchasing customers and never-purchased users** (8.0 events/user for
  both groups). This suggests `events` behavioral volume, in this
  dataset, is not a strong observed predictor of whether a user
  actually appears in `orders` — reported as an association only, not
  a causal or predictive claim.
- **Rating does not show a clean monotonic relationship with product
  sales.** Products rated 3.0–3.99 had the highest average revenue per
  product among the three rating bands tested, not the 4.0+ band — a
  useful caution against assuming "higher rating always drives more
  revenue" for this dataset.
- **The engagement funnel drop-off** (aggregate, distinct-user basis):
  view → cart 70.2%, view → wishlist 55.3%, view → purchase-event
  32.9%. These are co-occurrence rates across the full dataset, not a
  verified sequential per-user funnel (see limitations below).

## Assumptions

- **Gross vs. Net revenue** are both shown throughout because
  `order_status` includes `cancelled` and `returned` values; neither
  figure is presented as "the" correct revenue — both answer different
  legitimate questions and are labeled explicitly wherever they appear.
- **One-time / repeat customer definitions** use order count only
  (exactly 1 vs. more than 1), as explicitly directed — not
  signup-to-order timing.
- **Minimum review-count threshold of 5** was applied before ranking
  "highest/lowest rated products," to avoid a single review producing a
  misleadingly extreme average. This is a judgment call, stated
  explicitly, not a value derived from the data.
- **Minimum view-count threshold of 10** was applied before ranking
  product view-to-purchase-event ratios, for the same reason.
- **180-day active/lapsed cutoff** in the lifecycle analysis is a
  business judgment call, not a statistically derived value — see
  `docs/customer_lifecycle_definition.md` for full reasoning.

## Limitations (carried forward and specific to Phase 2)

- **Date-quality limitation (from Phase 1, respected throughout Phase
  2):** `signup_date`, `order_date`, `event_timestamp`, and
  `review_date` are not chronologically consistent with each other
  (~49.6–49.7% cross-table inconsistency rate on each pair checked in
  Phase 1). No query in this phase compares dates across tables, joins
  on date ordering, or builds a "time since X" metric across tables.
  Every date-based query in this phase (monthly trends, recency,
  lifecycle) uses dates from a single table only, compared only to
  other dates in that same table.
- **The event funnel is an aggregate, not a verified sequence.**
  `events` has no `order_id` and cannot be tied to a specific order.
  The funnel numbers describe how many distinct users are represented
  in each event-type bucket, not a confirmed per-user path from view →
  cart → wishlist → purchase in chronological order. This is stated
  directly in `07_event_analysis.sql`'s comments.
- **`review_text` was analyzed only as a categorical/frequency field.**
  No NLP, tokenization, sentiment scoring, or text modeling was
  performed or attempted, consistent with Phase 1's finding that it is
  a fixed set of 10 canned phrases.
- **No causal claims.** Every place a rating-vs-sales or
  engagement-vs-sales relationship is shown, it is reported as an
  association/co-occurrence only.
- **This project targets MySQL syntax** (`DATE_FORMAT`, `TIMESTAMPDIFF`,
  window functions, CTEs — all valid MySQL 8.0+ syntax). Because a real
  MySQL server was not available in this sandbox, the same limitation
  from Phase 1 applies: query logic was verified correct against the
  provided data via a SQLite functional proxy, but exact MySQL syntax
  compilation should still be confirmed by running these scripts on a
  real MySQL/MariaDB instance.

# Phase 3 — Pandas Analysis Summary

This document summarizes the Python/Pandas work built in
`python/notebooks/ecommerce_analysis.ipynb` on top of the same raw CSV
dataset used in Phase 1/2. It complements — and reconciles against —
the validated Phase 2 SQL analysis (`docs/sql_analysis_summary.md`). No
new business definitions were invented; every KPI, customer, lifecycle,
product, review, and event definition reproduced here matches
`sql/analysis/*.sql` exactly.

## Purpose

Phase 2 answered the project's business questions in SQL. Phase 3 asks:
**does the same data, analyzed independently in Pandas, produce the same
answers?** This is a genuine cross-validation exercise, not a duplicate
of the SQL work — and it surfaced one real discrepancy (see below), which
is exactly the kind of thing this reconciliation step is meant to catch.

## Data Loading

All 6 CSVs (`users`, `products`, `orders`, `order_items`, `events`,
`reviews`) are loaded directly from `data/` via
`python/scripts/analysis_lib.py::load_data()`. Nothing is loaded from
the SQL database — Pandas reads the same raw source files SQL does,
independently.

## Transformations Applied

Per Phase 1's data-quality findings (no missing values, no duplicates, no
invalid foreign keys), the **only** transformation applied is dtype
conversion:

- `signup_date`, `order_date`, `event_timestamp`, `review_date` →
  `datetime64`
- Numeric columns (`price`, `total_amount`, `quantity`, `item_price`,
  `item_total`, `rating`) → explicit numeric types
- `order_status`, `event_type`, `category` → pandas `category` dtype
  (memory optimization only, no value changes)

No rows were added, removed, or altered. The raw CSVs in `data/` are
untouched.

## Major Analyses (see the notebook for full code and output)

1. **Data validation** — row counts, missing values, duplicates, PK
   uniqueness, FK orphan checks, date ranges, numeric ranges. All agree
   with `docs/phase1a_dataset_audit.md`.
2. **Merge-safety demonstration** — explicitly shows what happens if
   `orders` is naively merged with `order_items` and revenue is summed
   on the inflated result (produces revenue ~2.18x too high), versus the
   correct approach of computing order-level metrics from `orders`
   alone. This mirrors the caution already documented in
   `sql/analysis/01_business_kpis.sql`.
3. **Business KPIs** — gross/net revenue, order counts, customer counts,
   items sold, AOV, revenue per customer, one-time/repeat customers and
   rates. Matches `sql/analysis/01_business_kpis.sql` definitions exactly.
4. **Sales EDA** — monthly revenue/order trend, category revenue.
5. **Customer analysis** — per-customer order count, revenue, AOV,
   first/last order date, one-time/repeat classification (order-count
   based, per Phase 2's explicit definition — `signup_date` not used).
6. **Customer lifecycle** — reproduces
   `sql/analysis/04_customer_lifecycle.sql` and
   `docs/customer_lifecycle_definition.md` exactly: order-count and
   order-recency only, 180-day active/lapsed cutoff, snapshot date =
   `MAX(order_date)` across all orders.
7. **Product analysis** — top/bottom performers by revenue, computed
   from `order_items` joined to `products` (never from `orders.total_amount`,
   which is an order-level total, not product-level).
8. **Review analysis** — rating distribution, catalog vs. review-derived
   rating comparison, `review_text` treated strictly as a categorical
   field (10 canned phrases, per Phase 1 Issue 4). **No NLP or sentiment
   analysis was performed**, consistent with the documented limitation.
9. **Event analysis** — event-type volume, an **aggregate** engagement
   funnel (distinct users per stage, explicitly labeled as not a
   verified per-user chronological sequence), and a purchasers-vs-non-
   purchasers event-activity comparison.

## Visualizations

7 charts saved to `python/outputs/`:

| File | Shows |
|---|---|
| `01_monthly_revenue_and_orders.png` | Monthly revenue & order volume trend |
| `02_category_revenue.png` | Revenue by product category |
| `03_customer_revenue_distribution.png` | Distribution of revenue per customer |
| `04_customer_lifecycle_distribution.png` | Customer lifecycle segment sizes |
| `05_top_products_revenue.png` | Top 10 products by revenue |
| `06_rating_distribution.png` | Review rating distribution (1-5 stars) |
| `07_aggregate_event_funnel.png` | Aggregate event funnel (view/cart/wishlist/purchase) |

## Important Findings

1. **Category concentration** — revenue is not evenly spread across the
   10 categories; a small number of top categories account for a
   disproportionate share of total revenue (see notebook Section 12 for
   the exact figures).
2. **Repeat-Lapsed customers are a sizeable, proven win-back audience**
   — 2,528 customers with 2+ historical orders but no order in the last
   180 days, representing real historical revenue. Lower-risk reactivation
   target than cold outreach to never-purchased users.
3. **Rating is not a clean predictor of product revenue** — products
   rated 3.0-3.99 had the highest average revenue per product among the
   three rating bands tested, not the 4.0+ band. Using rating alone as a
   promotion-priority signal would be misleading for this catalog.
4. **Event activity volume does not distinguish purchasers from
   non-purchasers** — average logged events per user is essentially
   identical (~8.0) for both groups, confirming Phase 2's finding
   independently in Pandas.
5. **2025-11 is a partial month** (the dataset's order history ends
   2025-11-14), so the apparent revenue/order drop in that month in the
   trend chart is a data-window artifact, not a real decline. Excluded
   from any trend conclusion.

## Assumptions

Same as Phase 2 (see `docs/sql_analysis_summary.md`): gross vs. net
revenue both shown and neither treated as "more correct"; one-time/repeat
defined by order count only; 180-day lifecycle cutoff is a stated business
judgment call, not statistically derived; minimum-count thresholds
(reviews, views) used where noted to avoid low-volume noise.

## Limitations

All limitations carried forward from Phase 1/2 apply identically in
Pandas:

- Cross-table date inconsistency (~49.6-49.7%) — no analysis compares
  dates across tables or builds a "time since signup" metric.
- `review_text` is 10 canned categorical phrases — no NLP/sentiment
  analysis performed or attempted.
- The event funnel is aggregate, not a verified per-user chronological
  sequence (`events` has no `order_id`).
- All rating-vs-sales and engagement-vs-sales relationships are reported
  as associations only, never as causal claims.
- 2025-11 is a partial month in the dataset and is excluded from trend
  conclusions.

## SQL vs. Pandas Validation

21 metrics were reconciled against the validated Phase 2 SQL figures
(full table: `python/outputs/sql_vs_pandas_reconciliation.csv`, also
reproduced in the notebook's Section 13). **All 21 metrics match exactly**
after one discrepancy was found and fixed during development:

**Discrepancy found:** an initial Pandas customer-lifecycle calculation
used `(snapshot_date - last_order_date).dt.days`, which **floors** the
elapsed time to a whole number of days before comparing to the 180-day
cutoff (initial result: 3,384 Active / 2,510 Lapsed — 18 customers off
from the validated SQL figures of 3,366 / 2,528).

**Root cause:** both Pandas and the validated MySQL SQL logic use
a **continuous, fractional-day** comparison for elapsed time, not a floored
integer-day comparison. A customer whose true elapsed time was, e.g., 180.3 days is
correctly "Lapsed" under the continuous comparison, but the initial Pandas approach
of flooring to 180 incorrectly classified them as "Active".

**Fix:** compute recency as a continuous float
(`total_seconds() / 86400`) instead of `.dt.days`, matching the validated
method exactly. See the inline comment in
`python/scripts/analysis_lib.py::build_customer_lifecycle` for full
detail. This was investigated and corrected, not worked around by
adjusting the Pandas result to match without understanding why.

## Files Produced in Phase 3

```
python/
├── notebooks/
│   └── ecommerce_analysis.ipynb        <- main deliverable, fully executed
├── scripts/
│   └── analysis_lib.py                 <- shared loading/validation/KPI/lifecycle/product functions
├── outputs/
│   ├── 01_monthly_revenue_and_orders.png
│   ├── 02_category_revenue.png
│   ├── 03_customer_revenue_distribution.png
│   ├── 04_customer_lifecycle_distribution.png
│   ├── 05_top_products_revenue.png
│   ├── 06_rating_distribution.png
│   ├── 07_aggregate_event_funnel.png
│   └── sql_vs_pandas_reconciliation.csv
└── README.md                            <- how to run this phase
```

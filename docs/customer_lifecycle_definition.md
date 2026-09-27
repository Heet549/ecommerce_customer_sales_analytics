# Customer Lifecycle Definition (Phase 2D)

This document explains the customer lifecycle methodology used in
`sql/analysis/04_customer_lifecycle.sql`, why it was chosen, and its
limitations. It exists so the lifecycle logic doesn't need to be
re-derived or second-guessed in Phase 3.

## Why signup_date is NOT used

Phase 1's audit (`docs/data_quality_report.md`, Issues 1–3) established
that `signup_date`, `order_date`, `event_timestamp`, and `review_date`
were generated independently per table and are **not chronologically
consistent** with each other:

- ~49.7% of orders (9,930 of 20,000) have an `order_date` earlier than
  the ordering customer's `signup_date`.
- ~49.6% of events have an `event_timestamp` earlier than the acting
  user's `signup_date`.
- ~49.7% of reviews have a `review_date` earlier than the `order_date`
  of the order they belong to.

Any lifecycle metric built on "time since signup" (e.g. "days from
signup to first order," "new customer in their first 30 days," "signup
cohort") would therefore be **meaningless** for roughly half the
dataset — it would describe a chronology the data does not actually
contain. Building such a metric anyway would produce numbers that look
precise but are not defensible.

**Decision: `signup_date` is excluded entirely from lifecycle
classification.**

## Definition used

Lifecycle segments are built only from data that is internally
consistent within the `orders` table itself (`order_date` compared only
to other `order_date` values, never to another table's date column):

| Segment | Definition |
|---|---|
| **Never Purchased** | Registered user (exists in `users`) with 0 rows in `orders`. |
| **One-Time** | Exactly 1 order. |
| **Repeat - Active** | 2+ orders AND most recent `order_date` is within 180 days of the dataset's snapshot date. |
| **Repeat - Lapsed** | 2+ orders AND most recent `order_date` is more than 180 days before the dataset's snapshot date. |

**Snapshot date:** `MAX(order_date)` across the entire `orders` table
(2025-11-14), not today's real-world date — this keeps the whole
analysis self-contained within the dataset's own time window
(2024-01-01 to 2025-11-14, ~22.5 months) rather than comparing dataset
dates to the actual current date, which would produce a huge and
meaningless recency gap for a synthetic/historical dataset.

## Calculation

1. A `customer_orders` CTE aggregates `orders` to one row per `user_id`
   with `order_count`, `last_order_date` (`MAX(order_date)`), and
   `total_spend` (`SUM(total_amount)`).
2. A `snapshot` CTE computes `MAX(order_date)` across all orders once.
3. Each customer is classified with `CASE` logic against those two
   CTEs; Recency is based on the continuous elapsed timestamp difference.
4. Never-Purchased users are identified separately via a `LEFT JOIN`
   anti-join from `users` to `orders` (they have no order row to
   classify against).

## Why this definition was chosen

- **Order count and order recency are directly, reliably observable**
  — they come from a single table (`orders`) and require no
  cross-table date comparison.
- It answers the same underlying business need a signup-based
  lifecycle would have (who is new/one-time, who is actively repeating,
  who has gone quiet) without relying on data known to be unreliable
  for that purpose.
- The 3-segment (+ Never Purchased) structure is simple enough to be
  directly actionable (e.g. "Repeat - Lapsed" is a natural win-back
  campaign audience) without over-engineering a large number of
  segments the data doesn't clearly support.

## The 180-day cutoff is a judgment call, not a discovered value

The 180-day active/lapsed threshold was **chosen**, not derived
statistically from the data (e.g. not a percentile or clustering
result). Over the dataset's ~22.5-month window, 180 days is roughly the
midpoint of a customer's possible repeat-purchase gap and is a common,
easy-to-explain business rule of thumb (roughly 6 months of inactivity).
This is stated explicitly here so it is never mistaken for a data-driven
threshold in Phase 3 reporting.

## Limitations

- **No true "new vs. existing" lifecycle stage.** Because signup timing
  can't be trusted relative to order timing, this analysis cannot say
  whether a customer is "new" in the traditional sense (recently
  acquired). "One-Time" describes order count, not tenure.
- **The 180-day cutoff is arbitrary** (see above) and would need
  revisiting against real business context (e.g. actual typical
  repurchase cycle for this product mix) before being used to size a
  real marketing budget.
- **No cohort/retention-curve analysis** (e.g. "% of Month 1 customers
  who ordered again in Month 2") is included, because that style of
  analysis requires trustworthy signup-to-order sequencing, which this
  dataset does not have.
- **Snapshot date is the dataset's own max order date, not a live
  "today."** If this dataset is ever refreshed with new data, the
  snapshot date — and therefore the Active/Lapsed cutoff for every
  customer — will shift accordingly.

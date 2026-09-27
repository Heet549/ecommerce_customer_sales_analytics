# Data Quality Report

This report documents every data-quality observation found during the
Phase 1A audit, and the decision made for each one. No records were deleted.
No values were invented. Every issue below was independently re-verified in
`python/audit_phase1a.py` (raw output: `docs/phase1a_audit_raw_output.txt`).

---

## Issue 1 — Orders dated before the customer's signup date

**Problem:** 9,930 of 20,000 orders (~49.7%) have an `order_date` earlier
than the ordering customer's `signup_date`.

**Why it is a problem:** Logically, a customer should not be able to place
an order before they created an account. If unaddressed, this would break
any "days between signup and first purchase" or "new customer" style metric.

**Action:** **Document and leave the data as-is.** Do not delete or alter
any rows.

**Why this action was chosen:**
- This pattern is spread across essentially half the dataset (49.7%), not a
  handful of outlier rows — it is a structural characteristic of how the
  data was generated (`signup_date`, `order_date`, `event_timestamp`, and
  `review_date` all appear to be randomly generated independently within the
  same 2024-01-01 to 2025-11-14 window, rather than being generated as a
  logically ordered sequence per customer).
- Deleting ~half the orders would destroy the dataset's usefulness for
  revenue/behavioral analysis and is not justified — the `order_id`,
  `total_amount`, `order_items`, and `order_status` values themselves are
  internally consistent and usable.
- Correcting the dates would mean inventing data, which violates the
  project's core rule of never inventing values.
- **Practical guidance for later phases:** avoid building any metric that
  depends on `order_date` occurring after `signup_date` (e.g. "time from
  signup to first order"). Metrics that use `order_date`, `total_amount`,
  `order_status`, or product/category performance on their own are not
  affected by this issue.

---

## Issue 2 — Reviews dated before the order they belong to

**Problem:** 7,455 of 15,000 reviews (~49.7%) have a `review_date` earlier
than the `order_date` of the order referenced in `reviews.order_id`.

**Why it is a problem:** A review should logically be written after the
order that generated it. This affects any "time to review" style metric.

**Action:** **Document and leave the data as-is.**

**Why this action was chosen:** Same root cause as Issue 1 — dates were
generated independently per table. The `rating` and `review_text` values are
still valid and usable for rating-distribution and product-quality analysis;
only date-sequencing metrics involving `review_date` vs `order_date` should
be avoided.

---

## Issue 3 — Events dated before the user's signup date

**Problem:** 39,703 of 80,000 events (~49.6%) have an `event_timestamp`
earlier than the acting user's `signup_date`.

**Why it is a problem:** A browsing/cart/wishlist/purchase event should not
happen before the user's account existed.

**Action:** **Document and leave the data as-is.**

**Why this action was chosen:** Same root cause as Issues 1 and 2. Event
counts, event-type distribution, and product-level engagement (views, carts,
wishlists, purchases) remain valid; only "time since signup" style
event metrics should be avoided.

---

## Issue 4 — `review_text` is a fixed set of 10 canned phrases, not free text

**Problem:** Across all 15,000 reviews, `review_text` only contains 10
distinct strings (e.g. "Item arrived damaged.", "Fast shipping and good
packaging.", "Works perfectly!").

**Why it is a problem:** It is not a problem in the sense of "bad data" —
the field is complete and consistent — but it is a **limitation on the type
of analysis that is realistic.** True NLP/sentiment analysis on this field
would not add genuine value, because the "text" is really a closed set of
categorical tags.

**Action:** Treat `review_text` as a **categorical field**, not free text.
Realistic analysis: frequency of each phrase, phrase distribution by
`rating`, and phrase distribution by product `category`.

**Why this action was chosen:** This matches the actual structure of the
data and avoids over-engineering (e.g. building unnecessary NLP/ML
sentiment models on data that is already categorical) — consistent with the
project's "no unnecessary machine learning" rule.

---

## Issue 5 — `order_items.user_id` is redundant with `orders.user_id`

**Problem:** `order_items` stores its own `user_id` column, which duplicates
information already available via `order_items.order_id → orders.user_id`.

**Why it is a problem:** Not a data-quality defect (verified 0 mismatches
across all 43,525 rows), but a normalization note worth documenting so it
isn't mistaken for an independent relationship.

**Action:** Keep the column in the SQL schema (it exists in the source
file and doing otherwise would mean altering the source structure), but
treat `orders.user_id` as the source of truth in analysis, and avoid joining
on `order_items.user_id` when `orders.user_id` is already available in the
same query.

**Why this action was chosen:** Keeps the schema faithful to the actual CSV
while avoiding confusion during later analysis phases.

---

## Issue 6 — 1,365 users have never placed an order

**Problem:** Only 8,635 of 10,000 users appear in `orders.user_id`; the
remaining 1,365 users have signed up but never ordered.

**Why it is a problem:** Not a data defect — this is expected and realistic
for an e-commerce platform (visitors who register but don't buy). Flagged
here so it isn't mistaken for a broken join later ("why does my `users`
LEFT JOIN `orders` produce NULLs?").

**Action:** No action needed. This is valid business reality and is
actually useful for later analysis (e.g. registered-but-never-purchased
segment).

**Why this action was chosen:** Confirms the join type to use later is a
`LEFT JOIN` from `users`, not an `INNER JOIN`, whenever the analysis needs
to include never-purchased users.

---

## Issue 7 — 5 users and 1 product have no recorded events

**Problem:** 9,995 of 10,000 users appear in `events.user_id` (5 users have
zero browsing activity); 2,000 of 2,000 products appear in
`events.product_id` (all products have at least one event) — so this issue
is limited to 5 users only.

**Why it is a problem:** Not a defect — simply means 5 users have no logged
behavioral activity.

**Action:** No action needed; use `LEFT JOIN` from `users` when an analysis
needs to include users with zero events.

---

## Issues Checked and NOT Found (confirms clean data)

The following were explicitly checked and **no problems were found**:

- **No missing/NULL values** in any of the 6 tables, any column
- **No duplicate rows** in any of the 6 tables
- **No duplicate primary keys** in any of the 6 tables
- **No invalid/orphaned foreign keys** anywhere (every child ID has a valid parent)
- **No negative values** in `price`, `total_amount`, `item_price`, `item_total`, `quantity`
- **No ratings outside 1–5** in `products.rating` or `reviews.rating`
- **No malformed emails** (all contain "@")
- **No placeholder/sentinel null values** (no "N/A", "unknown", "-", empty strings, etc.)
- **No inconsistent category casing/spelling** in `category`, `brand`, `gender`,
  `order_status`, `event_type` (each is a small, clean, consistent set of values)
- **`item_price` always matches the product catalog price** — no pricing inconsistencies
- **`orders.total_amount` always matches `SUM(order_items.item_total)`** exactly, for all 20,000 orders

## Summary

This is a clean, well-formed synthetic dataset. The only real data-quality
issue category is **cross-table date inconsistency** (Issues 1–3, all one
root cause), which is documented and must simply be respected — not
"fixed" — by avoiding chronological-sequence metrics across tables in
later phases. No rows need to be deleted or altered for Phase 2/3 work.

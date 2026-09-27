# Final Business Insights

This document highlights the key findings from the unified e-commerce analytics project, leveraging the reconciled multi-tool pipeline (SQL, Pandas, and Excel).

### Finding 1: Repeat Customer Reactivation
- **Observation:** Of the 5,894 repeat customers, exactly 2,528 are classified as "Lapsed" (no purchase in >180 days).
- **Insight:** A significant portion (42.8%) of customers with multiple historical purchases have not placed an order in the last 180 days.
- **Business Impact:** This represents a large historical buyer base that may be responsive to re-engagement efforts, depending on the typical repurchase cycle.
- **Recommendation:** Consider testing a targeted win-back email campaign for customers crossing the 160-day or 180-day inactivity threshold to evaluate reactivation rates.

### Finding 2: Event Funnel Engagement
- **Observation:** The aggregate event data shows 9,961 users with view events, 6,994 with cart events, 5,504 with wishlist events, and 3,281 with purchase events. Relative to view users, cart reaches 70.2% and purchase events reach 32.9%.
- **Insight:** A substantial gap exists between broad product-view activity and users recorded with purchase events.
- **Limitation:** The dataset cannot establish that this gap represents checkout abandonment or identify the cause because the event records do not form a verified chronological purchase funnel.
- **Recommendation:** In a production environment, investigate potential checkout and conversion friction using session-level or order-linked funnel data.

### Finding 3: Balanced Review Distribution
- **Observation:** With 15,000 total ratings, the average sits at 3.54. Notably, 3-star (28.6%) and 4-star (30.8%) ratings form the majority of the distribution, with 5-star receiving 22.7%.
- **Insight:** The product catalog receives predominantly mid-to-high ratings rather than extreme scores.
- **Limitation:** As documented, the dataset shows rating does not have a clean monotonic relationship with product sales, and review text is categorical rather than generative.
- **Recommendation:** Prioritize product quality investigations on items receiving 1- or 2-star reviews, using returns data where available, to address demonstrable product defects before broadly adjusting standard products.

### Finding 4: Broad Revenue Distribution
- **Observation:** The top 15 products contribute approximately 7.1% of total revenue.
- **Insight:** Revenue is broadly distributed across the catalog rather than being dominated by a very small group of hero products.
- **Business implication:** The business may have less dependence on a handful of SKUs, while category-level concentration can still be examined separately.
- **Recommendation:** Maintain broad inventory coverage and evaluate category-level revenue concentration before making SKU-level dependency decisions.

### Finding 5: One-Time Buyer Segment
- **Observation:** 2,741 customers (31.7% of all purchasers) bought exactly once and have not placed a repeat order within the dataset's timeframe.
- **Insight:** Almost a third of acquired purchasing customers currently remain in the one-time buyer segment.
- **Business Impact:** Converting a portion of these one-time buyers into repeat buyers could improve overall revenue efficiency per acquired customer, if acquisition costs were known.
- **Recommendation:** Evaluate post-purchase engagement strategies such as helpful product usage guides or targeted follow-ups to encourage a second purchase.

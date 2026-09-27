"""
analysis_lib.py
PHASE 3 - Shared data loading, validation, and analysis functions.

This module exists so the same logic can be reused by both the Jupyter
notebook (python/notebooks/ecommerce_analysis.ipynb) and any standalone
script, without repeating calculations. It intentionally reuses the SAME
KPI / lifecycle / segment definitions established in Phase 2 SQL
(sql/analysis/*.sql) and documented in docs/sql_analysis_summary.md and
docs/customer_lifecycle_definition.md. No new business logic is invented
here.
"""

import pandas as pd
import numpy as np
from pathlib import Path

# Project-relative path: this file lives at python/scripts/analysis_lib.py
# so going up two levels reaches the project root, then into data/
DATA_DIR = str(Path(__file__).resolve().parent.parent.parent / "data")

# ---------------------------------------------------------------------
# 3B — Data loading
# ---------------------------------------------------------------------

def load_data(data_dir: str = DATA_DIR) -> dict:
    """Load the 6 raw CSV files, unmodified, into a dict of DataFrames."""
    files = {
        "users": "users.csv",
        "products": "products.csv",
        "orders": "orders.csv",
        "order_items": "order_items.csv",
        "events": "events.csv",
        "reviews": "reviews.csv",
    }
    dfs = {name: pd.read_csv(f"{data_dir}/{fname}") for name, fname in files.items()}
    return dfs


def convert_types(dfs: dict) -> dict:
    """
    3D — Data cleaning (type conversion only).

    Phase 1 established there are no missing values, no duplicate rows,
    and no invalid foreign keys. Therefore the ONLY transformation
    genuinely needed here is converting date columns from text to
    datetime and confirming numeric columns are numeric. No rows are
    added, removed, or altered.
    """
    dfs["users"]["signup_date"] = pd.to_datetime(dfs["users"]["signup_date"])
    dfs["orders"]["order_date"] = pd.to_datetime(dfs["orders"]["order_date"])
    dfs["events"]["event_timestamp"] = pd.to_datetime(dfs["events"]["event_timestamp"])
    dfs["reviews"]["review_date"] = pd.to_datetime(dfs["reviews"]["review_date"])

    # Numeric columns (already numeric on read, this is a defensive/explicit cast)
    dfs["products"]["price"] = dfs["products"]["price"].astype(float)
    dfs["products"]["rating"] = dfs["products"]["rating"].astype(float)
    dfs["orders"]["total_amount"] = dfs["orders"]["total_amount"].astype(float)
    dfs["order_items"]["quantity"] = dfs["order_items"]["quantity"].astype(int)
    dfs["order_items"]["item_price"] = dfs["order_items"]["item_price"].astype(float)
    dfs["order_items"]["item_total"] = dfs["order_items"]["item_total"].astype(float)
    dfs["reviews"]["rating"] = dfs["reviews"]["rating"].astype(int)

    # order_status / event_type / category as pandas category dtype
    # (memory-efficient, no change in values — purely a dtype optimization)
    dfs["orders"]["order_status"] = dfs["orders"]["order_status"].astype("category")
    dfs["events"]["event_type"] = dfs["events"]["event_type"].astype("category")
    dfs["products"]["category"] = dfs["products"]["category"].astype("category")

    return dfs


# ---------------------------------------------------------------------
# 3F — Business KPIs (definitions must match sql/analysis/01_business_kpis.sql)
# ---------------------------------------------------------------------

CANCEL_RETURN_STATUSES = ("cancelled", "returned")


def compute_kpis(dfs: dict) -> dict:
    orders = dfs["orders"]
    order_items = dfs["order_items"]
    users = dfs["users"]

    is_kept = ~orders["order_status"].isin(CANCEL_RETURN_STATUSES)

    gross_revenue = orders["total_amount"].sum()
    net_revenue = orders.loc[is_kept, "total_amount"].sum()
    revenue_lost = orders.loc[~is_kept, "total_amount"].sum()

    total_orders_all = orders["order_id"].nunique()
    total_orders_net = orders.loc[is_kept, "order_id"].nunique()

    registered_customers = users["user_id"].nunique()
    purchasing_customers = orders["user_id"].nunique()
    never_purchased = registered_customers - purchasing_customers

    # NOTE on terminology (matches sql/analysis/01_business_kpis.sql KPI 4):
    # total_items_sold = SUM(quantity) = 60,818 *units*
    # avg_items_per_order here = 60,818 / 20,000 = ~3.04 *units* per order
    # This is distinct from 43,525 / 20,000 = ~2.18 *line items* per order
    # (i.e. number of distinct order_item rows, not total units)
    total_items_sold = int(order_items["quantity"].sum())
    avg_items_per_order = round(total_items_sold / total_orders_all, 2)

    aov_gross = round(gross_revenue / total_orders_all, 2)
    aov_net = round(net_revenue / total_orders_net, 2) if total_orders_net else None

    avg_revenue_per_customer = round(gross_revenue / purchasing_customers, 2)

    orders_per_customer = orders.groupby("user_id")["order_id"].count()
    one_time_customers = int((orders_per_customer == 1).sum())
    repeat_customers = int((orders_per_customer > 1).sum())
    one_time_rate = round(100 * one_time_customers / purchasing_customers, 2)
    repeat_rate = round(100 * repeat_customers / purchasing_customers, 2)

    return {
        "gross_revenue": round(gross_revenue, 2),
        "net_revenue": round(net_revenue, 2),
        "revenue_lost_to_cancel_return": round(revenue_lost, 2),
        "total_orders_all_status": total_orders_all,
        "total_orders_net": total_orders_net,
        "registered_customers": registered_customers,
        "purchasing_customers": purchasing_customers,
        "never_purchased_users": never_purchased,
        "total_items_sold": total_items_sold,
        "avg_items_per_order": avg_items_per_order,
        "avg_order_value_gross": aov_gross,
        "avg_order_value_net": aov_net,
        "avg_revenue_per_purchasing_customer": avg_revenue_per_customer,
        "one_time_customers": one_time_customers,
        "repeat_customers": repeat_customers,
        "one_time_customer_rate_pct": one_time_rate,
        "repeat_customer_rate_pct": repeat_rate,
    }


# ---------------------------------------------------------------------
# 3H — Customer-level analytical dataset
# ---------------------------------------------------------------------

def build_customer_analytics(dfs: dict) -> pd.DataFrame:
    orders = dfs["orders"]

    cust = orders.groupby("user_id").agg(
        total_orders=("order_id", "count"),
        total_revenue=("total_amount", "sum"),
        first_order_date=("order_date", "min"),
        last_order_date=("order_date", "max"),
    ).reset_index()

    cust["avg_order_value"] = (cust["total_revenue"] / cust["total_orders"]).round(2)
    cust["customer_type"] = np.where(cust["total_orders"] == 1, "One-Time", "Repeat")

    # order frequency: orders per active month of the customer's own
    # order history (first->last order span), only defined for repeat
    # customers with a non-zero span; avoids div-by-zero for one-timers.
    span_days = (cust["last_order_date"] - cust["first_order_date"]).dt.days
    span_months = (span_days / 30.44).replace(0, np.nan)
    cust["order_frequency_per_month"] = (cust["total_orders"] / span_months).round(3)

    return cust


# ---------------------------------------------------------------------
# 3I — Customer lifecycle (must match sql/analysis/04_customer_lifecycle.sql
#      and docs/customer_lifecycle_definition.md EXACTLY — order-behavior
#      based, 180-day active/lapsed cutoff, does NOT use signup_date)
# ---------------------------------------------------------------------

LIFECYCLE_CUTOFF_DAYS = 180


def build_customer_lifecycle(dfs: dict, cust_analytics: pd.DataFrame = None) -> pd.DataFrame:
    orders = dfs["orders"]
    users = dfs["users"]

    if cust_analytics is None:
        cust_analytics = build_customer_analytics(dfs)

    snapshot_date = orders["order_date"].max()

    lifecycle = cust_analytics.copy()
    # IMPORTANT (found during the Phase 3O SQL-vs-Pandas reconciliation —
    # see docs/pandas_analysis_summary.md for the full writeup):
    # sql/analysis/04_customer_lifecycle.sql defines recency with MySQL's
    # TIMESTAMPDIFF() to provide a continuous, fractional elapsed-time calculation.
    # The validated figures are: Repeat-Active 3,366 / Repeat-Lapsed 2,528.
    #
    # An initial pandas attempt used `(snapshot - last_order_date).dt.days`,
    # which FLOORS the elapsed duration to a whole number before comparing.
    # For any customer whose true elapsed time was e.g. 180.3 days, flooring
    # gives 180 (<=180 -> wrongly "Active"), while the continuous comparison
    # correctly gives 180.3 (> 180 -> "Lapsed"). This floored-vs-continuous
    # mismatch was the entire cause of an 18-customer discrepancy between
    # initial Pandas output and the equivalent continuous SQL logic.
    # Fix: compute recency as a continuous (float) number of days, matching
    # the MySQL continuous elapsed-time logic exactly.
    recency_days = (
        snapshot_date - lifecycle["last_order_date"]
    ).dt.total_seconds() / 86400.0
    lifecycle["recency_days"] = recency_days

    def classify(row):
        if row["total_orders"] == 1:
            return "One-Time"
        elif row["recency_days"] <= LIFECYCLE_CUTOFF_DAYS:
            return "Repeat - Active"
        else:
            return "Repeat - Lapsed"

    lifecycle["lifecycle_segment"] = lifecycle.apply(classify, axis=1)

    # Never-purchased users: registered users absent from orders entirely
    never_purchased_ids = set(users["user_id"]) - set(orders["user_id"])
    never_df = pd.DataFrame({
        "user_id": list(never_purchased_ids),
        "total_orders": 0,
        "total_revenue": 0.0,
        "lifecycle_segment": "Never Purchased",
    })

    full = pd.concat([lifecycle, never_df], ignore_index=True, sort=False)
    return full, snapshot_date


# ---------------------------------------------------------------------
# 3J — Product analytics (must match sql/analysis/05_product_analysis.sql)
# ---------------------------------------------------------------------

def build_product_analytics(dfs: dict) -> pd.DataFrame:
    order_items = dfs["order_items"]
    products = dfs["products"]

    merged = order_items.merge(
        products[["product_id", "product_name", "category", "brand", "price"]],
        on="product_id", how="inner",
    )

    prod = merged.groupby(
        ["product_id", "product_name", "category", "brand", "price"], observed=True
    ).agg(
        total_units_sold=("quantity", "sum"),
        total_revenue=("item_total", "sum"),
    ).reset_index()

    prod["avg_selling_price"] = (prod["total_revenue"] / prod["total_units_sold"]).round(2)
    total_rev = prod["total_revenue"].sum()
    prod["pct_of_total_revenue"] = (100 * prod["total_revenue"] / total_rev).round(4)

    return prod.sort_values("total_revenue", ascending=False).reset_index(drop=True)

"""
PHASE 1A - Dataset Audit Script
Inspects all 6 CSV files and prints/saves a full audit report.
This script only READS the raw CSVs. It does not modify or clean anything.
"""

import pandas as pd
import os
from pathlib import Path

# Resolve paths relative to this script's location:
# audit_phase1a.py lives in python/, so go up one level for project root
_HERE = Path(__file__).resolve().parent          # python/
_ROOT = _HERE.parent                              # project root
DATA_DIR = str(_ROOT / "data")
OUT_PATH = str(_ROOT / "docs" / "phase1a_audit_raw_output.txt")

files = {
    "users": "users.csv",
    "products": "products.csv",
    "orders": "orders.csv",
    "order_items": "order_items.csv",
    "events": "events.csv",
    "reviews": "reviews.csv",
}

dfs = {}
lines = []

def log(msg=""):
    print(msg)
    lines.append(str(msg))

log("=" * 80)
log("PHASE 1A - FULL DATASET AUDIT")
log("=" * 80)

for name, fname in files.items():
    path = os.path.join(DATA_DIR, fname)
    df = pd.read_csv(path)
    dfs[name] = df

    log(f"\n{'#' * 80}")
    log(f"# TABLE: {name}  ({fname})")
    log(f"{'#' * 80}")

    log(f"Rows: {len(df)}")
    log(f"Columns: {len(df.columns)}")
    log(f"Column names: {list(df.columns)}")

    log("\n-- dtypes (as read by pandas, before any cleaning) --")
    log(df.dtypes.to_string())

    log("\n-- missing values per column --")
    miss = df.isnull().sum()
    miss_pct = (df.isnull().mean() * 100).round(2)
    miss_df = pd.DataFrame({"missing_count": miss, "missing_pct": miss_pct})
    log(miss_df.to_string())

    log(f"\n-- duplicate full rows --")
    log(f"Full duplicate rows: {df.duplicated().sum()}")

    # Candidate primary key: first column ending in _id matching table pattern
    id_cols = [c for c in df.columns if c.endswith("_id")]
    log(f"\n-- ID-like columns: {id_cols} --")
    for c in id_cols:
        n_unique = df[c].nunique(dropna=False)
        n_total = len(df)
        log(f"   {c}: unique={n_unique} / total={n_total}  -> {'UNIQUE (possible PK)' if n_unique == n_total else 'NOT unique (likely FK)'}")

    log("\n-- unique value counts for low-cardinality object columns (<=30 uniques) --")
    for c in df.columns:
        if df[c].dtype == object:
            nun = df[c].nunique(dropna=True)
            if 1 <= nun <= 30:
                log(f"   {c} ({nun} unique): {sorted(df[c].dropna().unique().tolist())}")

    # date columns - try to detect
    log("\n-- date-like columns (by name or parse test) --")
    for c in df.columns:
        cl = c.lower()
        if "date" in cl or "timestamp" in cl:
            parsed = pd.to_datetime(df[c], errors="coerce")
            n_fail = parsed.isna().sum() - df[c].isna().sum()
            log(f"   {c}: min={parsed.min()}  max={parsed.max()}  unparsable_non_null={n_fail}")

    # numeric columns summary
    log("\n-- numeric column summary --")
    num_df = df.select_dtypes(include="number")
    if len(num_df.columns) > 0:
        log(num_df.describe().to_string())
    else:
        log("   (no native numeric columns detected)")

    log("\n-- sample rows (head 3) --")
    log(df.head(3).to_string())

log(f"\n\n{'=' * 80}")
log("CROSS-TABLE RELATIONSHIP CHECKS")
log(f"{'=' * 80}")

def fk_check(child_name, child_col, parent_name, parent_col):
    child = dfs[child_name]
    parent = dfs[parent_name]
    child_vals = set(child[child_col].dropna().unique())
    parent_vals = set(parent[parent_col].dropna().unique())
    orphans = child_vals - parent_vals
    log(f"\n{child_name}.{child_col}  ->  {parent_name}.{parent_col}")
    log(f"   distinct values in child: {len(child_vals)}")
    log(f"   distinct values in parent: {len(parent_vals)}")
    log(f"   orphan values (in child but not in parent): {len(orphans)}")
    if orphans:
        sample = list(orphans)[:5]
        log(f"   sample orphan values: {sample}")

# Candidate relationships to verify
fk_check("orders", "user_id", "users", "user_id")
fk_check("order_items", "order_id", "orders", "order_id")
fk_check("order_items", "product_id", "products", "product_id")
fk_check("order_items", "user_id", "users", "user_id")
fk_check("events", "user_id", "users", "user_id")
fk_check("events", "product_id", "products", "product_id")
fk_check("reviews", "order_id", "orders", "order_id")
fk_check("reviews", "product_id", "products", "product_id")
fk_check("reviews", "user_id", "users", "user_id")

# Extra consistency check: order_items.user_id vs orders.user_id (same order should belong to same user)
log("\n-- Consistency check: does order_items.user_id match orders.user_id for the same order_id? --")
merged = dfs["order_items"].merge(dfs["orders"][["order_id", "user_id"]], on="order_id", suffixes=("_item", "_order"))
mismatch = merged[merged["user_id_item"] != merged["user_id_order"]]
log(f"   Rows checked: {len(merged)}")
log(f"   Mismatched user_id rows: {len(mismatch)}")

# order_items total vs orders total_amount check
log("\n-- Consistency check: sum(order_items.item_total) per order vs orders.total_amount --")
sums = dfs["order_items"].groupby("order_id")["item_total"].sum().reset_index()
comp = dfs["orders"][["order_id", "total_amount"]].merge(sums, on="order_id", how="left")
comp["item_total"] = comp["item_total"].fillna(0)
comp["diff"] = (comp["total_amount"] - comp["item_total"]).round(2)
log(f"   Orders with no matching order_items rows: {(comp['item_total']==0).sum()}")
log(f"   Orders where total_amount == sum(item_total) (rounded): {(comp['diff'].abs() < 0.01).sum()} / {len(comp)}")
log(f"   Orders where they differ: {(comp['diff'].abs() >= 0.01).sum()}")
log(comp[comp['diff'].abs() >= 0.01].head(5).to_string())

# events.event_type values
log("\n-- events.event_type value counts --")
log(dfs["events"]["event_type"].value_counts().to_string())

# orders.order_status value counts
log("\n-- orders.order_status value counts --")
log(dfs["orders"]["order_status"].value_counts().to_string())

# reviews rating range
log("\n-- reviews.rating value counts --")
log(dfs["reviews"]["rating"].value_counts().sort_index().to_string())

# products category / brand
log("\n-- products.category value counts --")
log(dfs["products"]["category"].value_counts().to_string())

log("\n-- products.rating stats --")
log(dfs["products"]["rating"].describe().to_string())

# Negative / zero / impossible values check
log("\n-- Sanity checks for impossible values --")
log(f"order_items: quantity <= 0 count = {(dfs['order_items']['quantity'] <= 0).sum()}")
log(f"order_items: item_price < 0 count = {(dfs['order_items']['item_price'] < 0).sum()}")
log(f"order_items: item_total < 0 count = {(dfs['order_items']['item_total'] < 0).sum()}")
log(f"orders: total_amount < 0 count = {(dfs['orders']['total_amount'] < 0).sum()}")
log(f"products: price < 0 count = {(dfs['products']['price'] < 0).sum()}")
log(f"products: rating out of 1-5 range count = {((dfs['products']['rating'] < 1) | (dfs['products']['rating'] > 5)).sum()}")
log(f"reviews: rating out of 1-5 range count = {((dfs['reviews']['rating'] < 1) | (dfs['reviews']['rating'] > 5)).sum()}")

# email format quick check
log("\n-- users.email basic format check --")
bad_email = ~dfs["users"]["email"].astype(str).str.contains("@", na=False)
log(f"emails without '@': {bad_email.sum()}")

# duplicate emails / duplicate user rows by user_id
log("\n-- users duplicate checks --")
log(f"duplicate user_id: {dfs['users']['user_id'].duplicated().sum()}")
log(f"duplicate email: {dfs['users']['email'].duplicated().sum()}")

os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
with open(OUT_PATH, "w") as f:
    f.write("\n".join(lines))

print(f"\n\nSaved full audit output to {OUT_PATH}")

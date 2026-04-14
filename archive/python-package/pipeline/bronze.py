"""Bronze layer — load Dealroom CSV, select columns, parse types."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

logger = logging.getLogger(__name__)

# 76 columns to keep from the raw Dealroom export (original header names)
BRONZE_COLUMNS = [
    # Identity (6)
    "ID", "Name", "Dealroom URL", "Website", "Tagline", "Long description",
    # Location (6)
    "Address", "Zipcode", "HQ region", "HQ country", "HQ state", "HQ city",
    # Coordinates (2)
    "Latitude", "Longitude",
    # Tags/Classification (5)
    "Tags", "All tags", "Industries", "Sub industries", "Technologies",
    # Funding (8)
    "Total funding (EUR M)", "Total funding (USD M)",
    "Last round", "Last funding amount", "Last funding date",
    "First funding date", "Seed year", "Total rounds number",
    # Round details (4)
    "Each round type", "Each round amount", "Each round date", "Each round investors",
    # Investors (4)
    "Investors names", "Each investor type", "Lead investors", "Ownerships",
    # Lifecycle (6)
    "Launch year", "Launch month", "Launch date",
    "Closing year", "Closing month", "Closing date",
    # Team (4)
    "Employees Range", "Employees latest number",
    "Employee growth % (last 3 months)", "Employee growth % (last 12 months)",
    # Founders (11)
    "Founders", "Founders statuses", "Founders genders",
    "Is serial founder (yes/no)", "Founders backgrounds", "Founders universities",
    "Founders company experience", "Founders first degree",
    "Is top past founder (yes/no)", "Founder is from top university (yes/no)",
    "Founders strength",
    # Social (5)
    "LinkedIn", "Twitter", "Facebook", "Crunchbase",
    "Website traffic estimate yearly growth",
    # Status/Signals (6)
    "Company status",
    "Dealroom Signal - Rating", "Dealroom Signal - Completeness",
    "Dealroom Signal - Team strength", "Dealroom Signal - Growth rate",
    "Dealroom Signal - Timing",
    # Business model (2)
    "Client focus", "Revenue model",
    # Registry (3)
    "Trade register number", "Trade register name", "Trade register URL",
    # Valuation (2)
    "Valuation (USD)", "Valuation (EUR)",
]

# Map original column names → snake_case internal names
RENAME_MAP = {
    "ID": "dealroom_id",
    "Name": "name",
    "Dealroom URL": "dealroom_url",
    "Website": "website",
    "Tagline": "tagline",
    "Long description": "long_description",
    "Address": "address",
    "Zipcode": "zipcode",
    "HQ region": "hq_region",
    "HQ country": "hq_country",
    "HQ state": "hq_state",
    "HQ city": "hq_city",
    "Latitude": "latitude",
    "Longitude": "longitude",
    "Tags": "tags",
    "All tags": "all_tags",
    "Industries": "industries",
    "Sub industries": "sub_industries",
    "Technologies": "technologies",
    "Total funding (EUR M)": "total_funding_eur_m",
    "Total funding (USD M)": "total_funding_usd_m",
    "Last round": "last_round",
    "Last funding amount": "last_funding_amount",
    "Last funding date": "last_funding_date",
    "First funding date": "first_funding_date",
    "Seed year": "seed_year",
    "Total rounds number": "total_rounds_number",
    "Each round type": "each_round_type",
    "Each round amount": "each_round_amount",
    "Each round date": "each_round_date",
    "Each round investors": "each_round_investors",
    "Investors names": "investors_names",
    "Each investor type": "each_investor_type",
    "Lead investors": "lead_investors",
    "Ownerships": "ownerships",
    "Launch year": "launch_year",
    "Launch month": "launch_month",
    "Launch date": "launch_date",
    "Closing year": "closing_year",
    "Closing month": "closing_month",
    "Closing date": "closing_date",
    "Employees Range": "employees_range",
    "Employees latest number": "employees_latest_number",
    "Employee growth % (last 3 months)": "employee_growth_3m",
    "Employee growth % (last 12 months)": "employee_growth_12m",
    "Founders": "founders",
    "Founders statuses": "founders_statuses",
    "Founders genders": "founders_genders",
    "Is serial founder (yes/no)": "is_serial_founder",
    "Founders backgrounds": "founders_backgrounds",
    "Founders universities": "founders_universities",
    "Founders company experience": "founders_company_experience",
    "Founders first degree": "founders_first_degree",
    "Is top past founder (yes/no)": "is_top_past_founder",
    "Founder is from top university (yes/no)": "founder_is_from_top_university",
    "Founders strength": "founders_strength",
    "LinkedIn": "linkedin",
    "Twitter": "twitter",
    "Facebook": "facebook",
    "Crunchbase": "crunchbase",
    "Website traffic estimate yearly growth": "website_traffic_growth",
    "Company status": "company_status",
    "Dealroom Signal - Rating": "dealroom_signal_rating",
    "Dealroom Signal - Completeness": "dealroom_signal_completeness",
    "Dealroom Signal - Team strength": "dealroom_signal_team",
    "Dealroom Signal - Growth rate": "dealroom_signal_growth",
    "Dealroom Signal - Timing": "dealroom_signal_timing",
    "Client focus": "client_focus",
    "Revenue model": "revenue_model",
    "Trade register number": "trade_register_number",
    "Trade register name": "trade_register_name",
    "Trade register URL": "trade_register_url",
    "Valuation (USD)": "valuation_usd",
    "Valuation (EUR)": "valuation_eur",
}

# Columns to parse as numeric (after rename)
NUMERIC_COLS = [
    "latitude", "longitude",
    "total_funding_eur_m", "total_funding_usd_m",
    "last_funding_amount", "seed_year", "total_rounds_number",
    "launch_year", "closing_year",
    "employees_latest_number", "employee_growth_3m", "employee_growth_12m",
    "dealroom_signal_rating", "dealroom_signal_completeness",
    "dealroom_signal_team", "dealroom_signal_growth", "dealroom_signal_timing",
    "valuation_usd", "valuation_eur",
    "website_traffic_growth",
]

# Columns to parse as dates (after rename)
DATE_COLS = [
    "last_funding_date", "first_funding_date",
    "launch_date", "closing_date",
]

# Yes/No → bool columns (after rename)
BOOL_COLS = [
    "is_serial_founder", "is_top_past_founder", "founder_is_from_top_university",
]


def _parse_bool(series: pd.Series) -> pd.Series:
    """Convert yes/no strings to nullable boolean."""
    s = series.astype(str).str.strip().str.lower()
    return s.map({"yes": True, "no": False}).where(s.isin({"yes", "no"}), other=None)


def build_bronze(data_dir: Path) -> pd.DataFrame:
    """Load Dealroom CSV, select columns, parse types. Returns DataFrame with original column names preserved for classifier."""
    csv_path = data_dir / "01_raw_input" / "dealroom_startups_qc_2025_12_09.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"Dealroom CSV not found: {csv_path}")

    logger.info("Loading dealroom CSV: %s", csv_path)
    df_raw = pd.read_csv(csv_path, dtype=str, keep_default_na=False)
    logger.info("Loaded %d rows, %d columns", len(df_raw), len(df_raw.columns))

    # Select only the columns we need
    missing = [c for c in BRONZE_COLUMNS if c not in df_raw.columns]
    if missing:
        logger.warning("Missing columns in CSV (will be filled with None): %s", missing)
    available = [c for c in BRONZE_COLUMNS if c in df_raw.columns]
    df = df_raw[available].copy()
    for c in missing:
        df[c] = None

    # Replace empty strings with None
    df = df.replace({"": None, "nan": None, "NaN": None, "None": None, "null": None})

    # Rename to snake_case
    df = df.rename(columns=RENAME_MAP)

    # Parse numerics
    for col in NUMERIC_COLS:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # Parse dates
    for col in DATE_COLS:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")

    # Parse booleans
    for col in BOOL_COLS:
        if col in df.columns:
            df[col] = _parse_bool(df[col])

    # Ensure dealroom_id is integer
    df["dealroom_id"] = pd.to_numeric(df["dealroom_id"], errors="coerce").astype("Int64")

    logger.info("Bronze: %d rows, %d columns", len(df), len(df.columns))
    return df

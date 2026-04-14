"""Gold layer — final column selection + metadata."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

logger = logging.getLogger(__name__)

# Internal columns to drop from the gold output
DROP_COLUMNS = ["match_text", "hq_city_key"]

PIPELINE_VERSION = "1.0.0"

# Columns for the startup master table — identifiers and key attributes
MASTER_TABLE_COLUMNS = [
    # Identifiers (for entity matching across sources)
    "dealroom_id",
    "name",
    "name_norm",
    "website",
    "website_domain",
    "linkedin",
    "linkedin_slug",
    "trade_register_number",
    "neq_norm",
    "dealroom_url",
    "dealroom_url_norm",
    "crunchbase",
    # Location
    "hq_city",
    "region_admin",
    "hq_country",
    # Classification
    "lifecycle_bucket",
    "rating_letter_effective",
    "startup_status_effective",
    "confidence_level",
    "is_current_active_startup",
    "is_startup_broad",
    # Key attributes
    "top_industry",
    "top_technology",
    "launch_year",
    "employees_range",
    "employees_latest_number",
    "total_funding_usd_m",
    "funding_stage",
    "activity_status",
    "company_status",
]


def build_gold(df: pd.DataFrame) -> pd.DataFrame:
    """Produce the gold DataFrame from silver."""
    # Drop internal columns
    drop = [c for c in DROP_COLUMNS if c in df.columns]
    df = df.drop(columns=drop)

    # Add metadata
    df["_pipeline_version"] = PIPELINE_VERSION
    df["_gold_built_at"] = datetime.now(timezone.utc).isoformat()

    # Sort by dealroom_id
    if "dealroom_id" in df.columns:
        df = df.sort_values("dealroom_id").reset_index(drop=True)

    logger.info("Gold: %d rows, %d columns", len(df), len(df.columns))
    return df


def build_startup_master(df: pd.DataFrame, output_dir: Path) -> Path:
    """Extract the startup master table from the gold DataFrame.

    Contains one row per startup (is_startup_broad == True) with identifiers
    and key attributes for entity matching against external data sources.
    """
    master = df[df["is_startup_broad"]].copy()

    # Select only master table columns (skip any that don't exist)
    cols = [c for c in MASTER_TABLE_COLUMNS if c in master.columns]
    master = master[cols].reset_index(drop=True)

    path = output_dir / "gold" / "startup_master.parquet"
    master.to_parquet(path, index=False)

    logger.info(
        "Startup master: %d rows, %d columns → %s",
        len(master), len(master.columns), path,
    )
    return path

"""Cross-source entity matching (HubSpot ↔ Dealroom).

Migrated from ~/Desktop/match_hubspot_dealroom.py.

Usage:
    from ecosystem.processing.matcher import match_datasets, ColumnMapping
    hubspot_df, dealroom_df = match_datasets(hubspot_df, dealroom_df)
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass

import pandas as pd

logger = logging.getLogger(__name__)


# ============================================================
# Column mapping configuration
# ============================================================

@dataclass
class ColumnMapping:
    """Maps source-specific column names for matching."""

    # Dealroom columns
    dealroom_id: str = "ID"
    dealroom_name: str = "Name"
    dealroom_website: str = "Website"
    dealroom_linkedin: str = "LinkedIn"
    dealroom_register: str = "Trade register number"

    # HubSpot columns
    hubspot_name: str = "Nom de l'entreprise"
    hubspot_dealroom_id: str = "Dealroom - ID"
    hubspot_website: str = "URL du site web"
    hubspot_linkedin: str = "Page d'entreprise LinkedIn"
    hubspot_neq: str = "(NEQ) Numéro d'entreprise du Québec"


DEFAULT_COLUMNS = ColumnMapping()

# Identifier fields used for matching
MATCH_FIELDS = ["name", "id", "website", "linkedin", "reg"]


# ============================================================
# Normalization helpers
# ============================================================

def normalize_text(x: object) -> str | None:
    """Lowercase, strip, collapse whitespace. Return None if empty."""
    if pd.isna(x):
        return None
    s = str(x).strip().lower()
    s = re.sub(r"\s+", " ", s)
    return s or None


def normalize_url(x: object) -> str | None:
    """Normalize URLs: lowercase, remove protocol/www/trailing slash."""
    if pd.isna(x):
        return None
    s = str(x).strip().lower()
    s = re.sub(r"^https?://", "", s)
    s = re.sub(r"^www\.", "", s)
    s = s.rstrip("/")
    return s or None


def normalize_register_number(x: object) -> str | None:
    """Normalize register numbers: keep only alphanumeric, uppercase."""
    if pd.isna(x):
        return None
    s = str(x).strip().upper()
    s = re.sub(r"[^0-9A-Z]", "", s)
    return s or None


# ============================================================
# Core matching logic
# ============================================================

def _add_normalized_columns(
    df: pd.DataFrame,
    name_col: str | None,
    id_col: str | None,
    website_col: str | None,
    linkedin_col: str | None,
    register_col: str | None,
    prefix: str,
) -> pd.DataFrame:
    """Add normalized identifier columns with the given prefix."""
    col_map = {
        "name": (name_col, normalize_text),
        "id": (id_col, normalize_text),
        "website": (website_col, normalize_url),
        "linkedin": (linkedin_col, normalize_url),
        "reg": (register_col, normalize_register_number),
    }
    for field, (src_col, norm_fn) in col_map.items():
        target = f"{prefix}_{field}_norm"
        if src_col and src_col in df.columns:
            df[target] = df[src_col].apply(norm_fn)
        else:
            df[target] = None
    return df


def _build_identifier_sets(df: pd.DataFrame, prefix: str) -> dict[str, set[str]]:
    """Build sets of unique normalized values for fast membership tests."""
    sets: dict[str, set[str]] = {}
    for field in MATCH_FIELDS:
        col = f"{prefix}_{field}_norm"
        if col in df.columns:
            vals = df[col].dropna().unique()
            sets[field] = {v for v in vals if v}
        else:
            sets[field] = set()
    return sets


def _flag_matches(df: pd.DataFrame, target_sets: dict[str, set[str]], prefix: str) -> pd.Series:
    """For each row, return True if any normalized identifier exists in target_sets."""
    def row_match(row: pd.Series) -> bool:
        for field in MATCH_FIELDS:
            val = row.get(f"{prefix}_{field}_norm")
            if val and val in target_sets[field]:
                return True
        return False

    return df.apply(row_match, axis=1)


def match_datasets(
    hubspot_df: pd.DataFrame,
    dealroom_df: pd.DataFrame,
    columns: ColumnMapping | None = None,
    matched_col_hubspot: str = "matched with Dealroom",
    matched_col_dealroom: str = "matched with Hubspot",
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Match companies between HubSpot and Dealroom DataFrames.

    Adds a boolean match flag column to each DataFrame indicating
    whether the row has a match in the other dataset, based on:
    name, Dealroom ID, website, LinkedIn, and register/NEQ number.

    Args:
        hubspot_df: HubSpot companies DataFrame.
        dealroom_df: Dealroom companies DataFrame.
        columns: Column name mapping (uses defaults if None).
        matched_col_hubspot: Name of the match flag column added to hubspot_df.
        matched_col_dealroom: Name of the match flag column added to dealroom_df.

    Returns:
        Tuple of (hubspot_df_with_flag, dealroom_df_with_flag).
    """
    cols = columns or DEFAULT_COLUMNS

    # Work on copies to avoid mutating originals
    hs = hubspot_df.copy()
    dr = dealroom_df.copy()

    # Add normalized columns
    hs = _add_normalized_columns(
        hs,
        name_col=cols.hubspot_name,
        id_col=cols.hubspot_dealroom_id,
        website_col=cols.hubspot_website,
        linkedin_col=cols.hubspot_linkedin,
        register_col=cols.hubspot_neq,
        prefix="hs",
    )
    dr = _add_normalized_columns(
        dr,
        name_col=cols.dealroom_name,
        id_col=cols.dealroom_id,
        website_col=cols.dealroom_website,
        linkedin_col=cols.dealroom_linkedin,
        register_col=cols.dealroom_register,
        prefix="dr",
    )

    # Build identifier sets
    dealroom_sets = _build_identifier_sets(dr, prefix="dr")
    hubspot_sets = _build_identifier_sets(hs, prefix="hs")

    # Flag matches
    hs[matched_col_hubspot] = _flag_matches(hs, dealroom_sets, prefix="hs")
    dr[matched_col_dealroom] = _flag_matches(dr, hubspot_sets, prefix="dr")

    # Drop temp normalized columns
    norm_cols_hs = [c for c in hs.columns if c.startswith("hs_") and c.endswith("_norm")]
    norm_cols_dr = [c for c in dr.columns if c.startswith("dr_") and c.endswith("_norm")]
    hs = hs.drop(columns=norm_cols_hs)
    dr = dr.drop(columns=norm_cols_dr)

    hs_matched = hs[matched_col_hubspot].sum()
    dr_matched = dr[matched_col_dealroom].sum()
    logger.info(
        "Matching complete: %d/%d HubSpot matched, %d/%d Dealroom matched",
        hs_matched, len(hs), dr_matched, len(dr),
    )

    return hs, dr

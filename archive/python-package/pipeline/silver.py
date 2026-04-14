"""Silver layer — orchestrate 12 enrichment steps."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

logger = logging.getLogger(__name__)


def build_silver(df: pd.DataFrame, data_dir: Path) -> pd.DataFrame:
    """Run all 12 enrichment steps sequentially on a bronze DataFrame."""
    from ecosystem.processing.enrichment import (
        enrich_accelerators,
        enrich_activity_status,
        enrich_classification,
        enrich_founders,
        enrich_funding,
        enrich_geo,
        enrich_industries,
        enrich_lifecycle,
        enrich_manual_reviews,
        enrich_normalize,
        enrich_technologies,
        enrich_website_active,
    )

    logger.info("Silver: starting 12 enrichment steps on %d rows", len(df))

    df = enrich_normalize(df)
    df = enrich_geo(df, data_dir)
    df = enrich_industries(df, data_dir)
    df = enrich_technologies(df, data_dir)
    df = enrich_website_active(df, data_dir)
    df = enrich_manual_reviews(df, data_dir)
    df = enrich_classification(df)
    df = enrich_activity_status(df)
    df = enrich_accelerators(df)
    df = enrich_funding(df)
    df = enrich_founders(df)
    df = enrich_lifecycle(df)

    logger.info("Silver: done — %d rows, %d columns", len(df), len(df.columns))
    return df

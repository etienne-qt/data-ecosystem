"""Optional Snowflake upload for pipeline outputs."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

logger = logging.getLogger(__name__)


def upload_gold(parquet_path: Path) -> None:
    """Upload gold parquet to Snowflake."""
    from ecosystem.connectors.snowflake import SnowflakeClient

    df = pd.read_parquet(parquet_path)
    client = SnowflakeClient()
    client.upload_df(df, table="DRM_COMPANY_GOLD", overwrite=True)
    logger.info("Uploaded %d rows to Snowflake DRM_COMPANY_GOLD", len(df))

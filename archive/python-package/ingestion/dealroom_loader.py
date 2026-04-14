"""Load Dealroom CSV/Excel exports into Snowflake."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from ecosystem.connectors.snowflake import SnowflakeClient

logger = logging.getLogger(__name__)


def load_dealroom_file(
    path: str | Path,
    snowflake_client: SnowflakeClient | None = None,
    table: str = "DRM_COMPANY_BRONZE",
    sheet_name: str = "Sheet1",
    upload: bool = True,
) -> pd.DataFrame:
    """Read a Dealroom CSV or Excel file and optionally upload to Snowflake.

    Args:
        path: Path to CSV or Excel file.
        snowflake_client: Optional SnowflakeClient. Created with defaults if None.
        table: Target Snowflake table name.
        sheet_name: Excel sheet name (ignored for CSV).
        upload: Whether to upload to Snowflake.

    Returns:
        The loaded DataFrame.
    """
    path = Path(path)
    logger.info("Loading Dealroom file: %s", path)

    if path.suffix in (".xlsx", ".xls"):
        df = pd.read_excel(path, sheet_name=sheet_name)
    else:
        df = pd.read_csv(path)

    logger.info("Loaded %d rows, %d columns", len(df), len(df.columns))

    if upload:
        client = snowflake_client or SnowflakeClient()
        client.upload_df(df, table=table, overwrite=True)

    return df

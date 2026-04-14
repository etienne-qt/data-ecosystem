"""Sync HubSpot companies to/from Snowflake."""

from __future__ import annotations

import logging

import pandas as pd

from ecosystem.connectors.hubspot import HubSpotClient
from ecosystem.connectors.snowflake import SnowflakeClient

logger = logging.getLogger(__name__)


def pull_hubspot_to_snowflake(
    hubspot: HubSpotClient | None = None,
    snowflake: SnowflakeClient | None = None,
    table: str = "HUBSPOT_COMPANIES",
    max_pages: int = 0,
) -> int:
    """Pull all HubSpot companies and upload to Snowflake.

    Returns:
        Number of companies synced.
    """
    hs = hubspot or HubSpotClient()
    sf = snowflake or SnowflakeClient()

    companies = hs.get_all_companies(max_pages=max_pages)
    if not companies:
        logger.warning("No companies fetched from HubSpot")
        return 0

    df = pd.DataFrame(companies)
    sf.upload_df(df, table=table, overwrite=True)
    logger.info("Synced %d HubSpot companies to Snowflake", len(df))
    return len(df)


def push_enrichments_to_hubspot(
    snowflake: SnowflakeClient | None = None,
    hubspot: HubSpotClient | None = None,
    query: str = "",
) -> int:
    """Push enrichment data from Snowflake back to HubSpot.

    Args:
        query: SQL query that returns rows with 'hs_object_id' and properties to update.

    Returns:
        Number of companies updated.
    """
    if not query:
        logger.warning("No query provided for push_enrichments_to_hubspot")
        return 0

    sf = snowflake or SnowflakeClient()
    hs = hubspot or HubSpotClient()

    df = sf.query(query)
    if df.empty:
        logger.info("No enrichments to push")
        return 0

    updates = []
    for _, row in df.iterrows():
        row_dict = row.to_dict()
        hs_id = str(row_dict.pop("hs_object_id", row_dict.pop("HS_OBJECT_ID", "")))
        if not hs_id:
            continue
        # Convert remaining columns to string properties
        props = {k.lower(): str(v) for k, v in row_dict.items() if pd.notna(v)}
        updates.append({"id": hs_id, "properties": props})

    if not updates:
        return 0

    # Batch in groups of 100 (HubSpot API limit)
    total = 0
    for i in range(0, len(updates), 100):
        batch = updates[i : i + 100]
        total += hs.batch_update_companies(batch)

    logger.info("Pushed enrichments to %d HubSpot companies", total)
    return total

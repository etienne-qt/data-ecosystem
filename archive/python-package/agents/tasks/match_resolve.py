"""Entity resolution — match new entries across HubSpot and Dealroom."""

from __future__ import annotations

import logging
from datetime import datetime

from ecosystem.agents.runner import TaskResult, TaskStatus, register_task

logger = logging.getLogger(__name__)


@register_task("match_resolve")
def handle_match_resolve(**kwargs) -> TaskResult:
    """Run entity matching between HubSpot and Dealroom datasets.

    Steps:
    1. Pull latest HubSpot and Dealroom data from Snowflake
    2. Run matcher to flag cross-source matches
    3. Upload match flags back to Snowflake
    """
    from ecosystem.connectors.snowflake import SnowflakeClient
    from ecosystem.processing.matcher import match_datasets, ColumnMapping

    try:
        sf = SnowflakeClient()

        hs_query = kwargs.get("hubspot_query", "SELECT * FROM HUBSPOT_COMPANIES")
        dr_query = kwargs.get("dealroom_query", "SELECT * FROM DRM_COMPANY_SILVER")

        hubspot_df = sf.query(hs_query)
        dealroom_df = sf.query(dr_query)

        if hubspot_df.empty or dealroom_df.empty:
            return TaskResult(
                task_name="match_resolve",
                status=TaskStatus.SKIPPED,
                started_at=datetime.now(),
                message="One or both datasets empty",
            )

        # Use Snowflake column names (uppercase)
        columns = ColumnMapping(
            dealroom_id="ID",
            dealroom_name="NAME",
            dealroom_website="WEBSITE",
            dealroom_linkedin="LINKEDIN",
            dealroom_register="TRADE_REGISTER_NUMBER",
            hubspot_name="NAME",
            hubspot_dealroom_id="DEALROOM___ID",
            hubspot_website="DOMAIN",
            hubspot_linkedin="LINKEDIN_COMPANY_PAGE",
            hubspot_neq="NEQ__NUMERO_D_ENTREPRISE_DU_QUEBEC",
        )

        hs_out, dr_out = match_datasets(hubspot_df, dealroom_df, columns=columns)

        # Upload match results
        hs_matches = hs_out[["hs_object_id", "matched with Dealroom"]].copy() if "hs_object_id" in hs_out.columns else None
        if hs_matches is not None:
            sf.upload_df(hs_matches, table="HUBSPOT_MATCH_FLAGS", overwrite=True)

        hs_matched = hs_out.get("matched with Dealroom", []).sum() if "matched with Dealroom" in hs_out.columns else 0
        dr_matched = dr_out.get("matched with Hubspot", []).sum() if "matched with Hubspot" in dr_out.columns else 0

        return TaskResult(
            task_name="match_resolve",
            status=TaskStatus.SUCCESS,
            started_at=datetime.now(),
            message=f"Matched {hs_matched} HubSpot / {dr_matched} Dealroom companies",
            details={"hubspot_matched": int(hs_matched), "dealroom_matched": int(dr_matched)},
        )
    except Exception as e:
        return TaskResult(
            task_name="match_resolve",
            status=TaskStatus.FAILED,
            started_at=datetime.now(),
            error=str(e),
        )

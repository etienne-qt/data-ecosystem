"""Nightly data sync — pull HubSpot companies to Snowflake."""

from __future__ import annotations

import logging
from datetime import datetime

from ecosystem.agents.runner import TaskResult, TaskStatus, register_task

logger = logging.getLogger(__name__)


@register_task("nightly_sync")
def handle_nightly_sync(**kwargs) -> TaskResult:
    """Sync HubSpot companies to Snowflake.

    Steps:
    1. Pull all companies from HubSpot API
    2. Upload to Snowflake HUBSPOT_COMPANIES table
    """
    from ecosystem.ingestion.hubspot_sync import pull_hubspot_to_snowflake

    try:
        count = pull_hubspot_to_snowflake(
            max_pages=kwargs.get("max_pages", 0),
        )
        return TaskResult(
            task_name="nightly_sync",
            status=TaskStatus.SUCCESS,
            started_at=datetime.now(),
            message=f"Synced {count} companies from HubSpot to Snowflake",
            details={"companies_synced": count},
        )
    except Exception as e:
        return TaskResult(
            task_name="nightly_sync",
            status=TaskStatus.FAILED,
            started_at=datetime.now(),
            error=str(e),
        )

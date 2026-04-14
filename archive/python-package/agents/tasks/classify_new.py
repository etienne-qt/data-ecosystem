"""Classify newly added companies — run the Dealroom classifier on unrated rows."""

from __future__ import annotations

import logging
from datetime import datetime

from ecosystem.agents.runner import TaskResult, TaskStatus, register_task

logger = logging.getLogger(__name__)


@register_task("classify_new")
def handle_classify_new(**kwargs) -> TaskResult:
    """Classify unrated companies in Snowflake using the Dealroom classifier.

    Steps:
    1. Query Snowflake for companies without a startup_rating
    2. Run classifier on them
    3. Upload results back to Snowflake
    """
    from ecosystem.connectors.snowflake import SnowflakeClient
    from ecosystem.processing.classifier import rate_companies

    try:
        sf = SnowflakeClient()

        # Fetch unrated companies
        query = kwargs.get("query", """
            SELECT * FROM DRM_COMPANY_SILVER
            WHERE startup_rating_letter IS NULL
            LIMIT 1000
        """)
        df = sf.query(query)

        if df.empty:
            return TaskResult(
                task_name="classify_new",
                status=TaskStatus.SUCCESS,
                started_at=datetime.now(),
                message="No unrated companies found",
            )

        # Run classifier
        ratings = rate_companies(df, score_version=kwargs.get("score_version", "v5"))

        # Upload results
        sf.upload_df(ratings, table="STARTUP_RATINGS_STAGING", overwrite=False)

        return TaskResult(
            task_name="classify_new",
            status=TaskStatus.SUCCESS,
            started_at=datetime.now(),
            message=f"Classified {len(ratings)} companies",
            details={
                "total": len(ratings),
                "breakdown": ratings["startup_rating_letter"].value_counts().to_dict(),
            },
        )
    except Exception as e:
        return TaskResult(
            task_name="classify_new",
            status=TaskStatus.FAILED,
            started_at=datetime.now(),
            error=str(e),
        )

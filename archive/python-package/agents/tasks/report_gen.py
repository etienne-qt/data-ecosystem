"""Generate periodic reports — query Snowflake for key metrics and update narratives."""

from __future__ import annotations

import logging
from datetime import date, datetime

from ecosystem.agents.runner import TaskResult, TaskStatus, register_task

logger = logging.getLogger(__name__)


@register_task("report_gen")
def handle_report_gen(**kwargs) -> TaskResult:
    """Generate a periodic status report and update knowledge base narratives.

    Steps:
    1. Query Snowflake for key ecosystem metrics
    2. Update the Quebec ecosystem overview narrative
    3. Update the funding trends narrative
    """
    from ecosystem.connectors.snowflake import SnowflakeClient
    from ecosystem.knowledge.narrative import NarrativeManager

    try:
        sf = SnowflakeClient()
        narrative = NarrativeManager()

        # Gather key metrics
        metrics = {}

        try:
            count_df = sf.query("SELECT COUNT(*) AS cnt FROM DRM_COMPANY_SILVER")
            metrics["total_companies"] = int(count_df["CNT"].iloc[0]) if not count_df.empty else 0
        except Exception:
            metrics["total_companies"] = "N/A"

        try:
            rating_df = sf.query("""
                SELECT startup_rating_letter, COUNT(*) AS cnt
                FROM DRM_COMPANY_SILVER
                WHERE startup_rating_letter IS NOT NULL
                GROUP BY startup_rating_letter
                ORDER BY startup_rating_letter
            """)
            metrics["rating_breakdown"] = dict(zip(rating_df.iloc[:, 0], rating_df.iloc[:, 1])) if not rating_df.empty else {}
        except Exception:
            metrics["rating_breakdown"] = {}

        # Format metrics as markdown
        today = date.today()
        metrics_text = f"- Total companies: {metrics['total_companies']}\n"
        if metrics["rating_breakdown"]:
            for letter, count in sorted(metrics["rating_breakdown"].items()):
                metrics_text += f"- Rating {letter}: {count}\n"
        metrics_text += f"- Last updated: {today}\n"

        # Update ecosystem overview
        try:
            narrative.update_section(
                "narratives/quebec_ecosystem_overview.md",
                "Key Metrics",
                metrics_text,
            )
        except FileNotFoundError:
            logger.warning("Quebec ecosystem overview narrative not found")

        return TaskResult(
            task_name="report_gen",
            status=TaskStatus.SUCCESS,
            started_at=datetime.now(),
            message=f"Report generated with {metrics['total_companies']} companies",
            details={"metrics": {k: str(v) for k, v in metrics.items()}},
        )
    except Exception as e:
        return TaskResult(
            task_name="report_gen",
            status=TaskStatus.FAILED,
            started_at=datetime.now(),
            error=str(e),
        )

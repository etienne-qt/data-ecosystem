"""Pipeline orchestrator — run bronze → silver → gold → optional upload."""

from __future__ import annotations

import logging
import time
from pathlib import Path

logger = logging.getLogger(__name__)


def run_pipeline(
    data_dir: Path = Path("data"),
    output_dir: Path = Path("data/05_pipeline_output"),
    upload_to_snowflake: bool = False,
    steps: list[str] | None = None,
) -> dict[str, Path]:
    """Execute the Dealroom data pipeline.

    Args:
        data_dir: Directory containing input CSV files.
        output_dir: Directory for parquet outputs.
        upload_to_snowflake: If True, upload gold to Snowflake.
        steps: Which steps to run. Default: ["bronze", "silver", "gold"].

    Returns:
        Dict mapping step name to output parquet path.
    """
    import pandas as pd

    if steps is None:
        steps = ["bronze", "silver", "gold"]

    # Ensure output dirs exist
    for sub in ("bronze", "silver", "gold"):
        (output_dir / sub).mkdir(parents=True, exist_ok=True)

    outputs: dict[str, Path] = {}
    t0 = time.time()

    # ── Bronze ──
    if "bronze" in steps:
        from ecosystem.pipeline.bronze import build_bronze

        logger.info("═══ BRONZE ═══")
        df_bronze = build_bronze(data_dir)
        bronze_path = output_dir / "bronze" / "drm_company_bronze.parquet"
        df_bronze.to_parquet(bronze_path, index=False)
        outputs["bronze"] = bronze_path
        logger.info("Bronze written: %s (%d rows, %d cols)",
                     bronze_path, len(df_bronze), len(df_bronze.columns))
    else:
        # Load existing bronze
        bronze_path = output_dir / "bronze" / "drm_company_bronze.parquet"
        df_bronze = pd.read_parquet(bronze_path)
        logger.info("Loaded existing bronze: %s", bronze_path)

    # ── Silver ──
    if "silver" in steps:
        from ecosystem.pipeline.silver import build_silver

        logger.info("═══ SILVER ═══")
        df_silver = build_silver(df_bronze, data_dir)
        silver_path = output_dir / "silver" / "drm_company_silver.parquet"
        df_silver.to_parquet(silver_path, index=False)
        outputs["silver"] = silver_path
        logger.info("Silver written: %s (%d rows, %d cols)",
                     silver_path, len(df_silver), len(df_silver.columns))
    else:
        silver_path = output_dir / "silver" / "drm_company_silver.parquet"
        df_silver = pd.read_parquet(silver_path)
        logger.info("Loaded existing silver: %s", silver_path)

    # ── Gold ──
    if "gold" in steps:
        from ecosystem.pipeline.gold import build_gold, build_startup_master

        logger.info("═══ GOLD ═══")
        df_gold = build_gold(df_silver)
        gold_path = output_dir / "gold" / "drm_company_gold.parquet"
        df_gold.to_parquet(gold_path, index=False)
        outputs["gold"] = gold_path
        logger.info("Gold written: %s (%d rows, %d cols)",
                     gold_path, len(df_gold), len(df_gold.columns))

        # Build startup master table
        master_path = build_startup_master(df_gold, output_dir)
        outputs["startup_master"] = master_path

    # ── Upload ──
    if upload_to_snowflake and "gold" in outputs:
        from ecosystem.pipeline.upload import upload_gold

        logger.info("═══ UPLOAD ═══")
        upload_gold(outputs["gold"])

    elapsed = time.time() - t0
    logger.info("Pipeline complete in %.1fs — outputs: %s",
                elapsed, {k: str(v) for k, v in outputs.items()})
    return outputs

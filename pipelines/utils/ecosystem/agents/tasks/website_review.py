"""Website-based auto-review of companies — crawl and classify via website signals."""

from __future__ import annotations

import logging
from datetime import datetime
from pathlib import Path

from ecosystem.agents.runner import TaskResult, TaskStatus, register_task

logger = logging.getLogger(__name__)

_COMPANIES_CSV = Path("data/intermediate/companies_to_review.csv")
_CHECKPOINT_CSV = Path("data/intermediate/website_review_checkpoint.csv")
_CACHE_DIR = "data/cache/website_cache"
_BATCH_SIZE = 50
_CHECKPOINT_INTERVAL = 100
_MAX_PAGES = 8
_MAX_WORKERS = 10


@register_task("website_review")
def handle_website_review(**kwargs) -> TaskResult:
    """Auto-review companies by crawling their websites and scoring signals.

    Steps:
    1. Load companies_to_review.csv and filter by tier / website availability
    2. Skip already-processed companies from checkpoint (if any)
    3. Crawl websites in batches using WebsiteChecker
    4. Extract signals, compute score, and classify each company
    5. Save checkpoint every 100 companies; delete it on success
    6. Write auto_reviews_{date}.csv and website_review_detail_{date}.csv
    """
    try:
        import pandas as pd

        from ecosystem.processing.website_checker import WebsiteChecker
        from ecosystem.processing.website_reviewer import (
            classify,
            compute_review_score,
            extract_website_signals,
        )

        started_at = datetime.now()
        date_str = started_at.strftime("%Y-%m-%d")

        # ------------------------------------------------------------------
        # 1. Load companies
        # ------------------------------------------------------------------
        logger.info("Loading companies from %s", _COMPANIES_CSV)
        df = pd.read_csv(_COMPANIES_CSV, dtype=str)

        # ------------------------------------------------------------------
        # 2. Filter by tier
        # ------------------------------------------------------------------
        tier = kwargs.get("tier", "1_high")
        if "review_priority" in df.columns:
            df = df[df["review_priority"] == tier].copy()
            logger.info("Filtered to tier '%s': %d companies", tier, len(df))
        else:
            logger.warning("Column 'review_priority' not found — skipping tier filter")

        # ------------------------------------------------------------------
        # 3. Filter to companies with a website; respect website_active flag
        # ------------------------------------------------------------------
        if "website" not in df.columns:
            return TaskResult(
                task_name="website_review",
                status=TaskStatus.FAILED,
                started_at=started_at,
                error="Column 'website' is missing from companies_to_review.csv",
            )

        df = df[df["website"].notna() & (df["website"].str.strip() != "")].copy()

        if "website_active" in df.columns:
            # Exclude rows where website_active is explicitly False (string or bool)
            not_inactive = ~df["website_active"].astype(str).str.strip().str.lower().eq("false")
            df = df[not_inactive].copy()
            logger.info("After website_active filter: %d companies", len(df))
        else:
            logger.info(
                "Column 'website_active' not found — including all companies with a website (%d)",
                len(df),
            )

        if df.empty:
            return TaskResult(
                task_name="website_review",
                status=TaskStatus.SUCCESS,
                started_at=started_at,
                message="No companies to review after filtering",
                details={"total_processed": 0},
            )

        # ------------------------------------------------------------------
        # 4. Load checkpoint — skip already-processed dealroom_ids
        # ------------------------------------------------------------------
        processed_ids: set[str] = set()
        checkpoint_rows: list[dict] = []

        if _CHECKPOINT_CSV.exists():
            try:
                checkpoint_df = pd.read_csv(_CHECKPOINT_CSV, dtype=str)
                if "dealroom_id" in checkpoint_df.columns:
                    processed_ids = set(checkpoint_df["dealroom_id"].dropna().unique())
                    checkpoint_rows = checkpoint_df.to_dict(orient="records")
                    logger.info(
                        "Checkpoint loaded: %d already-processed companies",
                        len(processed_ids),
                    )
            except Exception as exc:
                logger.warning("Could not read checkpoint file: %s — starting fresh", exc)

        if processed_ids:
            df = df[~df["dealroom_id"].isin(processed_ids)].copy()
            logger.info(
                "After skipping checkpoint: %d companies remaining",
                len(df),
            )

        # ------------------------------------------------------------------
        # 5 & 6. Crawl in batches, score and classify
        # ------------------------------------------------------------------
        all_result_rows: list[dict] = list(checkpoint_rows)  # carry forward checkpoint data
        total_processed = len(processed_ids)

        rows_list = df.to_dict(orient="records")
        total_remaining = len(rows_list)

        with WebsiteChecker(cache_dir=_CACHE_DIR, max_pages=_MAX_PAGES) as checker:
            for batch_start in range(0, total_remaining, _BATCH_SIZE):
                batch = rows_list[batch_start : batch_start + _BATCH_SIZE]
                urls = [str(r.get("website", "")).strip() for r in batch]

                logger.info(
                    "Crawling batch %d-%d / %d",
                    batch_start + 1,
                    min(batch_start + _BATCH_SIZE, total_remaining),
                    total_remaining,
                )

                results = checker.check_batch(urls, crawl=True, max_workers=_MAX_WORKERS)

                for row, result in zip(batch, results):
                    signals = extract_website_signals(result)
                    score, reason = compute_review_score(
                        pd.Series(row), signals
                    )
                    classification = classify(score)

                    result_row = dict(row)
                    result_row.update(signals)
                    result_row["review_score"] = score
                    result_row["review_reason"] = reason
                    result_row["auto_classification"] = classification

                    all_result_rows.append(result_row)
                    total_processed += 1

                # Checkpoint every _CHECKPOINT_INTERVAL companies
                if total_processed % _CHECKPOINT_INTERVAL < _BATCH_SIZE or (
                    batch_start + _BATCH_SIZE >= total_remaining
                ):
                    try:
                        _CHECKPOINT_CSV.parent.mkdir(parents=True, exist_ok=True)
                        pd.DataFrame(all_result_rows).to_csv(
                            _CHECKPOINT_CSV, index=False
                        )
                        logger.info(
                            "Checkpoint saved: %d companies processed so far",
                            total_processed,
                        )
                    except Exception as exc:
                        logger.warning("Failed to save checkpoint: %s", exc)

        # ------------------------------------------------------------------
        # 7. Write output CSVs
        # ------------------------------------------------------------------
        detail_df = pd.DataFrame(all_result_rows)

        # auto_reviews_{date}.csv — only definitive classifications
        auto_review_path = Path(f"data/04_auto_reviews/auto_reviews_{date_str}.csv")
        definitive_mask = detail_df["auto_classification"].isin(["startup", "non-startup"])
        auto_review_df = detail_df[definitive_mask][["dealroom_url", "auto_classification"]].copy()
        auto_review_df = auto_review_df.rename(
            columns={"dealroom_url": "DEALROOM_URL", "auto_classification": "reviewStatus"}
        )
        auto_review_path.parent.mkdir(parents=True, exist_ok=True)
        auto_review_df.to_csv(auto_review_path, index=False)
        logger.info(
            "Wrote auto reviews to %s (%d rows)",
            auto_review_path,
            len(auto_review_df),
        )

        # website_review_detail_{date}.csv — all rows with full diagnostics
        detail_path = Path(f"data/04_auto_reviews/detail/website_review_detail_{date_str}.csv")
        detail_df.to_csv(detail_path, index=False)
        logger.info(
            "Wrote detail report to %s (%d rows)",
            detail_path,
            len(detail_df),
        )

        # ------------------------------------------------------------------
        # 8. Delete checkpoint on success
        # ------------------------------------------------------------------
        if _CHECKPOINT_CSV.exists():
            try:
                _CHECKPOINT_CSV.unlink()
                logger.info("Checkpoint file deleted after successful completion")
            except Exception as exc:
                logger.warning("Could not delete checkpoint file: %s", exc)

        # ------------------------------------------------------------------
        # Summary counts
        # ------------------------------------------------------------------
        counts = detail_df["auto_classification"].value_counts().to_dict()
        auto_startup = counts.get("startup", 0)
        auto_non_startup = counts.get("non-startup", 0)
        for_review = counts.get("for-review", 0)

        return TaskResult(
            task_name="website_review",
            status=TaskStatus.SUCCESS,
            started_at=started_at,
            message=(
                f"Processed {total_processed} companies: "
                f"{auto_startup} startup, {auto_non_startup} non-startup, "
                f"{for_review} for-review"
            ),
            details={
                "total_processed": total_processed,
                "auto_startup": auto_startup,
                "auto_non_startup": auto_non_startup,
                "for_review": for_review,
                "tier": tier,
                "auto_reviews_csv": str(auto_review_path),
                "detail_csv": str(detail_path),
            },
        )

    except Exception as e:
        return TaskResult(
            task_name="website_review",
            status=TaskStatus.FAILED,
            started_at=datetime.now(),
            error=str(e),
        )

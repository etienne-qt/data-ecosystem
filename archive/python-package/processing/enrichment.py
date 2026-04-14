"""Twelve enrichment steps for the Silver layer.

Each function takes a DataFrame and returns it with new columns added.
"""

from __future__ import annotations

import logging
from pathlib import Path

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


# ============================================================
# Step 1: Normalize core fields
# ============================================================

def enrich_normalize(df: pd.DataFrame) -> pd.DataFrame:
    """Add normalized fields for matching/joining."""
    from ecosystem.processing.normalizers import (
        build_match_text,
        clean_city_key,
        norm_domain,
        norm_linkedin,
        norm_name,
        norm_neq,
        normalize_dealroom_url,
    )

    df["website_domain"] = df["website"].apply(norm_domain)
    df["linkedin_slug"] = df["linkedin"].apply(norm_linkedin)
    df["neq_norm"] = df["trade_register_number"].apply(norm_neq)
    df["hq_city_key"] = df["hq_city"].apply(clean_city_key)
    df["dealroom_url_norm"] = df["dealroom_url"].apply(normalize_dealroom_url)
    df["name_norm"] = df["name"].apply(norm_name)
    df["match_text"] = df.apply(
        lambda r: build_match_text(
            r.get("name"), r.get("tagline"), r.get("long_description"),
            r.get("industries"), r.get("tags"), r.get("technologies"),
        ),
        axis=1,
    )
    logger.info("Step 1: normalize — added 7 columns")
    return df


# ============================================================
# Step 2: Geo enrichment
# ============================================================

def enrich_geo(df: pd.DataFrame, data_dir: Path) -> pd.DataFrame:
    """Join on hq_city_key with city_to_admin_geo.csv."""
    from ecosystem.processing.normalizers import clean_city_key

    geo_path = data_dir / "02_reference" / "city_to_admin_geo.csv"
    if not geo_path.exists():
        logger.warning("city_to_admin_geo.csv not found, skipping geo enrichment")
        for col in ["region_admin", "mrc", "agglomeration", "agglomeration_details", "geo_match_status"]:
            df[col] = None
        return df

    geo = pd.read_csv(geo_path, dtype=str, keep_default_na=False)
    geo = geo.replace({"": None})
    geo["_city_key"] = geo["HQ city"].apply(clean_city_key)

    geo_dedup = geo.drop_duplicates(subset="_city_key").rename(columns={
        "Region_admin": "region_admin",
        "MRC": "mrc",
        "Agglomeration": "agglomeration",
        "Agglomeration_details": "agglomeration_details",
    })

    before = len(df)
    df = df.merge(
        geo_dedup[["_city_key", "region_admin", "mrc", "agglomeration", "agglomeration_details"]],
        left_on="hq_city_key",
        right_on="_city_key",
        how="left",
    ).drop(columns=["_city_key"])

    matched = df["region_admin"].notna().sum()
    df["geo_match_status"] = np.where(df["region_admin"].notna(), "matched", "unmatched")
    logger.info("Step 2: geo — %d/%d matched (%.0f%%)", matched, before, 100 * matched / max(before, 1))
    return df


# ============================================================
# Step 3: Industry keyword matching
# ============================================================

def enrich_industries(df: pd.DataFrame, data_dir: Path) -> pd.DataFrame:
    """Match industry keywords against match_text."""
    from ecosystem.processing.keyword_matcher import load_keywords, match_keywords

    kw_path = data_dir / "02_reference" / "industry_keywords_simplified.csv"
    if not kw_path.exists():
        logger.warning("Industry keywords CSV not found, skipping")
        for col in ["industry_labels", "top_industry", "top_industry_score", "industry_match_count"]:
            df[col] = None if col != "industry_match_count" else 0
        return df

    kw_df = load_keywords(kw_path, label_col="INDUSTRY_LABEL")
    results = match_keywords(df["match_text"], kw_df, label_col="INDUSTRY_LABEL")

    df["industry_labels"] = [results[i].labels if i in results else [] for i in df.index]
    df["top_industry"] = [results[i].top_label if i in results else None for i in df.index]
    df["top_industry_score"] = [results[i].top_score if i in results else 0.0 for i in df.index]
    df["industry_match_count"] = [results[i].match_count if i in results else 0 for i in df.index]

    has_label = sum(1 for i in df.index if results.get(i) and results[i].labels)
    logger.info("Step 3: industries — %d/%d with labels (%.0f%%)", has_label, len(df), 100 * has_label / max(len(df), 1))
    return df


# ============================================================
# Step 4: Technology keyword matching
# ============================================================

def enrich_technologies(df: pd.DataFrame, data_dir: Path) -> pd.DataFrame:
    """Match technology keywords against match_text."""
    from ecosystem.processing.keyword_matcher import load_keywords, match_keywords

    kw_path = data_dir / "02_reference" / "technology_keywords_simplified.csv"
    if not kw_path.exists():
        logger.warning("Technology keywords CSV not found, skipping")
        for col in ["technology_labels", "top_technology", "top_technology_score", "technology_match_count"]:
            df[col] = None if col != "technology_match_count" else 0
        return df

    kw_df = load_keywords(kw_path, label_col="TECHNOLOGY_LABEL")
    results = match_keywords(df["match_text"], kw_df, label_col="TECHNOLOGY_LABEL")

    df["technology_labels"] = [results[i].labels if i in results else [] for i in df.index]
    df["top_technology"] = [results[i].top_label if i in results else None for i in df.index]
    df["top_technology_score"] = [results[i].top_score if i in results else 0.0 for i in df.index]
    df["technology_match_count"] = [results[i].match_count if i in results else 0 for i in df.index]

    has_label = sum(1 for i in df.index if results.get(i) and results[i].labels)
    logger.info("Step 4: technologies — %d/%d with labels (%.0f%%)", has_label, len(df), 100 * has_label / max(len(df), 1))
    return df


# ============================================================
# Step 5: Website active status
# ============================================================

def enrich_website_active(df: pd.DataFrame, data_dir: Path) -> pd.DataFrame:
    """Left join DRM_WEBSITE_ACTIVE.csv on dealroom_id."""
    wa_path = data_dir / "02_reference" / "DRM_WEBSITE_ACTIVE.csv"
    if not wa_path.exists():
        logger.warning("DRM_WEBSITE_ACTIVE.csv not found, skipping")
        df["website_active"] = None
        df["website_last_checked"] = None
        return df

    wa = pd.read_csv(wa_path, dtype=str, keep_default_na=False)
    wa["DEALROOM_ID"] = pd.to_numeric(wa["DEALROOM_ID"], errors="coerce").astype("Int64")
    wa["_active"] = wa["ACTIVE"].str.strip().str.lower().map({"yes": True, "no": False})
    wa["_checked"] = pd.to_datetime(wa["LAST_DATE_CHECKED"], errors="coerce")

    wa_dedup = wa.drop_duplicates(subset="DEALROOM_ID")

    df = df.merge(
        wa_dedup[["DEALROOM_ID", "_active", "_checked"]].rename(columns={
            "DEALROOM_ID": "dealroom_id",
            "_active": "website_active",
            "_checked": "website_last_checked",
        }),
        on="dealroom_id",
        how="left",
    )

    matched = df["website_active"].notna().sum()
    logger.info("Step 5: website_active — %d/%d matched", matched, len(df))
    return df


# ============================================================
# Step 6: Manual review status
# ============================================================

def enrich_manual_reviews(df: pd.DataFrame, data_dir: Path) -> pd.DataFrame:
    """Load manual reviews and auto-reviews, join on normalized dealroom_url.

    Manual reviews take priority over auto-reviews when both exist for the
    same company.
    """
    from ecosystem.processing.normalizers import normalize_dealroom_url

    status_map = {
        "startup": "startup",
        "non-startup": "non_startup",
        "non_startup": "non_startup",
        "for-review": "for_review",
        "for_review": "for_review",
        "for review": "for_review",
    }

    review_frames: list[pd.DataFrame] = []

    # --- Auto-reviews (loaded first so manual reviews override them) ---
    auto_path = data_dir / "04_auto_reviews" / "auto_reviews_combined.csv"
    if auto_path.exists():
        auto = pd.read_csv(auto_path, dtype=str, keep_default_na=False)
        auto["_url_norm"] = auto["DEALROOM_URL"].apply(normalize_dealroom_url)
        auto["_status"] = auto["reviewStatus"].str.strip().str.lower().map(status_map)
        auto["_source"] = "auto"
        review_frames.append(auto[["_url_norm", "_status", "_source"]])
        logger.info("Step 6: loaded %d auto-reviews from %s", len(auto), auto_path.name)

    # --- Manual reviews (take priority) ---
    mr_path = data_dir / "03_reviews" / "reviews_export_2026-03-06.csv"
    if not mr_path.exists():
        mr_path = data_dir / "03_reviews" / "manual_reviews_2026-02-10.csv"
    if mr_path.exists():
        mr = pd.read_csv(mr_path, dtype=str, keep_default_na=False)
        mr["_url_norm"] = mr["DEALROOM_URL"].apply(normalize_dealroom_url)
        mr["_status"] = mr["reviewStatus"].str.strip().str.lower().map(status_map)
        mr["_source"] = "manual"
        review_frames.append(mr[["_url_norm", "_status", "_source"]])
        logger.info("Step 6: loaded %d manual reviews from %s", len(mr), mr_path.name)

    if not review_frames:
        logger.warning("No review CSVs found, skipping")
        df["manual_review_status"] = None
        df["review_source"] = None
        df["has_manual_review"] = False
        return df

    # Merge reviews: manual overrides auto, EXCEPT when manual is "for_review"
    # (meaning the human couldn't decide) — in that case auto's definitive
    # answer (startup/non_startup) takes priority.
    all_reviews = pd.concat(review_frames, ignore_index=True)

    # For each URL, pick the best review:
    # 1. Manual definitive (startup/non_startup) > everything
    # 2. Auto definitive > manual for_review
    # 3. Manual for_review > auto for_review > algo
    def _pick_best(group: pd.DataFrame) -> pd.Series:
        if len(group) == 1:
            return group.iloc[0]
        manual = group[group["_source"] == "manual"]
        auto = group[group["_source"] == "auto"]
        # If manual gave a definitive answer, use it
        if len(manual) and manual.iloc[0]["_status"] in ("startup", "non_startup"):
            return manual.iloc[0]
        # If auto gave a definitive answer, prefer it over manual for_review
        if len(auto) and auto.iloc[0]["_status"] in ("startup", "non_startup"):
            return auto.iloc[0]
        # Fall back to manual (for_review)
        if len(manual):
            return manual.iloc[0]
        return group.iloc[-1]

    all_reviews = all_reviews.groupby("_url_norm", sort=False).apply(
        _pick_best, include_groups=False,
    ).reset_index()

    df = df.merge(
        all_reviews.rename(columns={
            "_url_norm": "dealroom_url_norm",
            "_status": "manual_review_status",
            "_source": "review_source",
        }),
        on="dealroom_url_norm",
        how="left",
    )

    df["has_manual_review"] = df["manual_review_status"].notna()
    total = df["has_manual_review"].sum()
    auto_count = (df["review_source"] == "auto").sum()
    manual_count = (df["review_source"] == "manual").sum()
    logger.info("Step 6: reviews — %d tagged (%d manual, %d auto)", total, manual_count, auto_count)
    return df


# ============================================================
# Step 7: Startup classification
# ============================================================

def enrich_classification(df: pd.DataFrame) -> pd.DataFrame:
    """Run the existing classifier and merge results. Apply manual review overrides."""
    from ecosystem.processing.classifier import attach_flags_for_qc, rate_companies
    from ecosystem.pipeline.bronze import RENAME_MAP

    # Build a DataFrame with original column names for the classifier
    reverse_map = {v: k for k, v in RENAME_MAP.items()}
    cols_for_classifier = {}
    for snake, orig in reverse_map.items():
        if snake in df.columns:
            cols_for_classifier[orig] = df[snake]
    df_orig = pd.DataFrame(cols_for_classifier)
    # Ensure ID column exists
    if "ID" not in df_orig.columns and "dealroom_id" in df.columns:
        df_orig["ID"] = df["dealroom_id"]

    # Rate companies
    ratings = rate_companies(df_orig)
    ratings["drm_company_id"] = pd.to_numeric(ratings["drm_company_id"], errors="coerce").astype("Int64")

    # Attach QC flags
    flags_df = attach_flags_for_qc(df_orig)

    # Merge ratings
    df["rating_letter"] = ratings["startup_rating_letter"].values
    df["rating_reason"] = ratings["rating_reason"].values
    df["startup_score"] = ratings["startup_score"].values

    # Merge flags
    for col in ["is_gov_nonprofit", "has_accelerator", "is_service_provider",
                 "has_tech_indication", "is_consumer_only", "is_vc_backed",
                 "completeness", "tech_strength"]:
        if col in flags_df.columns:
            df[col] = flags_df[col].values

    # Apply manual review overrides
    df["rating_letter_effective"] = df["rating_letter"].copy()
    df["is_manual_override"] = False

    if "manual_review_status" in df.columns:
        startup_mask = df["manual_review_status"] == "startup"
        non_startup_mask = df["manual_review_status"] == "non_startup"
        for_review_mask = df["manual_review_status"] == "for_review"

        df.loc[startup_mask, "rating_letter_effective"] = "A+"
        df.loc[non_startup_mask, "rating_letter_effective"] = "D"
        df.loc[for_review_mask, "rating_letter_effective"] = "C"
        df.loc[startup_mask | non_startup_mask | for_review_mask, "is_manual_override"] = True

    # Derive startup status (three-tier: startup / uncertain / non_startup)
    def _startup_status(letter):
        if letter in {"A+", "A", "B"}:
            return "startup"
        if letter == "C":
            return "uncertain"
        return "non_startup"

    df["startup_status"] = df["rating_letter"].apply(_startup_status)
    df["startup_status_effective"] = df["rating_letter_effective"].apply(_startup_status)

    # Confidence level
    def _confidence(row):
        if row.get("is_manual_override"):
            return "manual"
        letter = row.get("rating_letter_effective", "D")
        if letter in ("A+", "D"):
            return "high"
        if letter == "A":
            return "medium"
        return "low"

    df["confidence_level"] = df.apply(_confidence, axis=1)

    logger.info("Step 7: classification — rated %d companies", len(df))
    return df


# ============================================================
# Step 8: Activity status
# ============================================================

def enrich_activity_status(df: pd.DataFrame) -> pd.DataFrame:
    """Score activity: base 50 + recent funding + website signals - closed penalty."""
    score = pd.Series(50.0, index=df.index)

    # +20 for recent funding (last 3 years)
    if "last_funding_date" in df.columns:
        recent_cutoff = pd.Timestamp.now() - pd.DateOffset(years=3)
        has_recent = df["last_funding_date"].notna() & (df["last_funding_date"] >= recent_cutoff)
        score = score + has_recent.astype(float) * 20

    # +10 if has website
    if "website" in df.columns:
        has_website = df["website"].notna() & (df["website"].astype(str).str.strip() != "")
        score = score + has_website.astype(float) * 10

    # +15 if website is active, -25 if website is inactive
    # For manually-reviewed startups, soften the inactive penalty (-10 instead
    # of -25) because Dealroom's website check can be stale/wrong.
    if "website_active" in df.columns:
        is_manual_startup = (
            df.get("manual_review_status", pd.Series(dtype=str)) == "startup"
        )
        wa_true = (df["website_active"] == True)   # noqa: E712
        wa_false = (df["website_active"] == False)  # noqa: E712
        score = score + wa_true.astype(float) * 15
        score = score - (wa_false & ~is_manual_startup).astype(float) * 25
        score = score - (wa_false & is_manual_startup).astype(float) * 10

    # +10 if employee growth > 0 in last 12 months
    if "employee_growth_12m" in df.columns:
        has_growth = pd.to_numeric(df["employee_growth_12m"], errors="coerce").fillna(0) > 0
        score = score + has_growth.astype(float) * 10

    # -80 if company is closed
    if "company_status" in df.columns:
        is_closed = df["company_status"].astype(str).str.strip().str.lower().isin({"closed", "dead"})
        score = score - is_closed.astype(float) * 80

    # -80 if closing_year is set (not null)
    if "closing_year" in df.columns:
        has_closing_year = df["closing_year"].notna()
        # Only apply if not already penalized by company_status
        if "company_status" in df.columns:
            already_closed = df["company_status"].astype(str).str.strip().str.lower().isin({"closed", "dead"})
            score = score - (has_closing_year & ~already_closed).astype(float) * 80
        else:
            score = score - has_closing_year.astype(float) * 80

    # -5 if launch_year < 2005 AND no recent funding AND no employee growth (dormant old company)
    if "launch_year" in df.columns:
        old_company = pd.to_numeric(df["launch_year"], errors="coerce").fillna(9999) < 2005
        has_recent_funding = pd.Series(False, index=df.index)
        if "last_funding_date" in df.columns:
            recent_cutoff = pd.Timestamp.now() - pd.DateOffset(years=3)
            has_recent_funding = df["last_funding_date"].notna() & (df["last_funding_date"] >= recent_cutoff)
        has_emp_growth = pd.Series(False, index=df.index)
        if "employee_growth_12m" in df.columns:
            has_emp_growth = pd.to_numeric(df["employee_growth_12m"], errors="coerce").fillna(0) > 0
        dormant_old = old_company & ~has_recent_funding & ~has_emp_growth
        score = score - dormant_old.astype(float) * 5

    # Clamp 0-100
    score = score.clip(0, 100)

    df["activity_score"] = score

    def _status(s):
        if s >= 65:
            return "active"
        if s <= 25:
            return "inactive"
        return "unknown"

    df["activity_status"] = score.apply(_status)

    # Build reason string
    reasons = []
    for i in df.index:
        parts = [f"base=50"]
        if "last_funding_date" in df.columns and pd.notna(df.at[i, "last_funding_date"]):
            recent_cutoff = pd.Timestamp.now() - pd.DateOffset(years=3)
            if df.at[i, "last_funding_date"] >= recent_cutoff:
                parts.append("recent_funding=+20")
        if "website_active" in df.columns and df.at[i, "website_active"] is True:
            parts.append("website_active=+15")
        elif "website_active" in df.columns and df.at[i, "website_active"] is False:
            parts.append("website_bad=-25")
        if "employee_growth_12m" in df.columns:
            try:
                if float(df.at[i, "employee_growth_12m"]) > 0:
                    parts.append("emp_growth=+10")
            except (ValueError, TypeError):
                pass
        if "company_status" in df.columns:
            status_val = str(df.at[i, "company_status"]).strip().lower()
            if status_val in ("closed", "dead"):
                parts.append("closed=-80")
        if "closing_year" in df.columns and pd.notna(df.at[i, "closing_year"]):
            status_val = str(df.at[i, "company_status"]).strip().lower() if "company_status" in df.columns else ""
            if status_val not in ("closed", "dead"):
                parts.append("closing_year=-80")
        reasons.append("; ".join(parts))

    df["activity_reason"] = reasons
    logger.info("Step 8: activity_status — active=%d, inactive=%d, unknown=%d",
                (df["activity_status"] == "active").sum(),
                (df["activity_status"] == "inactive").sum(),
                (df["activity_status"] == "unknown").sum())
    return df


# ============================================================
# Step 9: Accelerator detail
# ============================================================

def enrich_accelerators(df: pd.DataFrame) -> pd.DataFrame:
    """Extract matched accelerator/incubator names."""
    from ecosystem.processing.classifier import ACCELERATOR_LIST
    from ecosystem.processing.normalizers import _accent_fold

    def _find_accels(row):
        text_parts = []
        for col in ["each_investor_type", "investors_names", "lead_investors",
                     "tags", "all_tags", "long_description"]:
            val = row.get(col)
            if val and isinstance(val, str) and val.strip():
                text_parts.append(val)
        haystack = _accent_fold(" ".join(text_parts))
        return [a for a in ACCELERATOR_LIST if a in haystack]

    df["accelerator_names"] = df.apply(_find_accels, axis=1)
    has_accel = sum(1 for names in df["accelerator_names"] if names)
    logger.info("Step 9: accelerators — %d companies with accelerator matches", has_accel)
    return df


# ============================================================
# Step 10: Funding enrichment
# ============================================================

def enrich_funding(df: pd.DataFrame) -> pd.DataFrame:
    """Derive funding flags from existing columns."""
    # is_financed
    has_funding = (df.get("total_funding_usd_m", pd.Series(dtype=float)).fillna(0) > 0) | \
                  (df.get("total_funding_eur_m", pd.Series(dtype=float)).fillna(0) > 0)
    has_rounds = df.get("total_rounds_number", pd.Series(dtype=float)).fillna(0) > 0
    df["is_financed"] = has_funding | has_rounds

    # funding_stage from last_round
    stage_map = {
        "pre-seed": "early", "pre seed": "early", "seed": "early", "angel": "early",
        "series a": "growth", "series b": "growth", "series c": "growth",
        "series d": "late", "series e": "late", "series f": "late",
        "ipo": "late", "secondary": "late",
        "grant": "grant", "crowdfunding": "other", "debt": "other",
    }

    def _map_stage(round_val):
        if not round_val or not isinstance(round_val, str):
            return None
        key = round_val.strip().lower()
        return stage_map.get(key, "other")

    df["funding_stage"] = df.get("last_round", pd.Series(dtype=str)).apply(_map_stage)

    # has_vc_funding
    from ecosystem.processing.classifier import VC_TYPE_KEYWORDS, nz
    def _has_vc(row):
        for col in ["each_investor_type", "investors_names", "lead_investors", "each_round_type"]:
            val = nz(row.get(col, ""))
            if val and any(k in val for k in VC_TYPE_KEYWORDS):
                return True
        return False

    df["has_vc_funding"] = df.apply(_has_vc, axis=1)

    logger.info("Step 10: funding — is_financed=%d, has_vc=%d",
                df["is_financed"].sum(), df["has_vc_funding"].sum())
    return df


# ============================================================
# Step 11: Founder enrichment
# ============================================================

def enrich_founders(df: pd.DataFrame) -> pd.DataFrame:
    """Derive founder metrics from existing columns."""

    # founder_count: count semicolon-separated founders
    def _count_founders(val):
        if not val or not isinstance(val, str) or not val.strip():
            return 0
        return len([p for p in val.split(";") if p.strip()])

    df["founder_count"] = df.get("founders", pd.Series(dtype=str)).apply(_count_founders)

    # has_serial_founder
    df["has_serial_founder"] = df.get("is_serial_founder", pd.Series(dtype=object)).fillna(False).astype(bool)

    # has_top_university_founder
    df["has_top_university_founder"] = df.get("founder_is_from_top_university", pd.Series(dtype=object)).fillna(False).astype(bool)

    # has_experienced_founder: serial OR top_past OR strength contains "strong"
    is_top_past = df.get("is_top_past_founder", pd.Series(dtype=object)).fillna(False).astype(bool)
    strength_strong = df.get("founders_strength", pd.Series(dtype=str)).fillna("").astype(str).str.lower().str.contains("strong", na=False)
    df["has_experienced_founder"] = df["has_serial_founder"] | is_top_past | strength_strong

    # founder_experience_score (0-3 additive)
    df["founder_experience_score"] = (
        df["has_serial_founder"].astype(int)
        + is_top_past.astype(int)
        + df["has_top_university_founder"].astype(int)
    )

    logger.info("Step 11: founders — avg_count=%.1f, experienced=%d",
                df["founder_count"].mean(), df["has_experienced_founder"].sum())
    return df


# ============================================================
# Step 12: Lifecycle bucketing
# ============================================================

def enrich_lifecycle(df: pd.DataFrame) -> pd.DataFrame:
    """Assign lifecycle bucket based on priority rules.

    Buckets: not_startup, mature_startup, closed_startup, founded_before_1990,
    growth_startup, early_startup, active_startup, legacy_active, legacy_dormant,
    uncertain, unknown.
    """

    def _bucket(row):
        effective = row.get("startup_status_effective", "non_startup")
        activity = row.get("activity_status", "unknown")
        status_val = str(row.get("company_status", "")).strip().lower()

        # Resolve activity for startups with unknown activity:
        # 1. Active website → presumed active
        # 2. Manually reviewed as startup → presumed active (human > algo)
        resolved_activity = activity
        if effective == "startup" and activity == "unknown":
            wa = row.get("website_active")
            review_status = row.get("manual_review_status")
            if wa is True:
                resolved_activity = "active"
            elif review_status == "startup":
                resolved_activity = "active"

        # Priority 1: not a startup (D-rated)
        if effective == "non_startup":
            return "not_startup"

        # Priority 2: mature startup (exit, 1000+ emp, 1B+ valuation)
        if status_val in ("acquired", "ipo", "merged"):
            return "mature_startup"
        emp = row.get("employees_latest_number")
        if pd.notna(emp) and emp >= 1000:
            return "mature_startup"
        val_usd = row.get("valuation_usd")
        if pd.notna(val_usd) and val_usd >= 1_000_000_000:
            return "mature_startup"

        # Priority 3: closed startup
        if status_val in ("closed", "dead"):
            return "closed_startup"

        # Priority 4: founded before 1990
        launch = row.get("launch_year")
        launch_val = None
        if pd.notna(launch):
            try:
                launch_val = float(launch)
            except (ValueError, TypeError):
                pass

        if launch_val is not None and launch_val < 1990:
            return "founded_before_1990"

        # From here on, only startup or uncertain statuses remain
        is_startup = effective == "startup"

        # Priority 5: growth_startup — startup + active + funded + employees > 10
        if is_startup and resolved_activity == "active":
            is_funded = row.get("is_financed", False)
            emp_val = None
            if pd.notna(emp):
                try:
                    emp_val = float(emp)
                except (ValueError, TypeError):
                    pass
            if is_funded and emp_val is not None and emp_val > 10:
                return "growth_startup"

        # Priority 6: early_startup — startup + active + launch 2015+ + employees <= 10
        if is_startup and resolved_activity == "active":
            if launch_val is not None and launch_val >= 2015:
                emp_val = None
                if pd.notna(emp):
                    try:
                        emp_val = float(emp)
                    except (ValueError, TypeError):
                        pass
                if emp_val is None or emp_val <= 10:
                    return "early_startup"

        # Priority 7: active_startup — startup + active + (launch 2010+ or null)
        if is_startup and resolved_activity == "active":
            if launch_val is None or launch_val >= 2010:
                return "active_startup"

        # Priority 8: legacy_active — startup or uncertain + active + launch 1990-2010
        if effective in ("startup", "uncertain") and resolved_activity == "active":
            if launch_val is not None and 1990 <= launch_val <= 2010:
                return "legacy_active"

        # Priority 9: legacy_dormant — startup or uncertain + NOT active + launch 1990-2010
        if effective in ("startup", "uncertain") and resolved_activity != "active":
            if launch_val is not None and 1990 <= launch_val <= 2010:
                return "legacy_dormant"

        # Priority 10: uncertain — rating C + not closed + activity not inactive
        if effective == "uncertain" and status_val not in ("closed", "dead") and resolved_activity != "inactive":
            return "uncertain"

        return "unknown"

    df["lifecycle_bucket"] = df.apply(_bucket, axis=1)
    df["is_current_active_startup"] = df["lifecycle_bucket"].isin({
        "active_startup", "growth_startup", "early_startup",
    })
    df["is_startup_broad"] = df["lifecycle_bucket"].isin({
        "active_startup", "growth_startup", "early_startup",
        "mature_startup", "legacy_active",
    })

    logger.info("Step 12: lifecycle buckets — %s",
                df["lifecycle_bucket"].value_counts().to_dict())
    return df

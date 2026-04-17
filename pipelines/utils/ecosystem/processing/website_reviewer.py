"""Website-based auto-reviewer for startup classification.

Extracts signals from crawled website content and combines them with
existing classifier data to auto-classify obvious startups / non-startups.
Ambiguous cases are flagged as ``for-review`` for manual inspection.
"""

from __future__ import annotations

import logging
import re
from typing import Any

import pandas as pd

from ecosystem.processing.classifier import has_any_keyword, nz
from ecosystem.processing.website_checker import WebsiteCheckResult

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Keyword lists for website signal extraction
# ---------------------------------------------------------------------------

# Startup indicators (checked in titles/headings only — too generic for body)
PRODUCT_LANGUAGE = [
    "platform", "saas", "api", "dashboard", "sdk", "app",
]

# Startup indicators (checked in all text)
SIGNUP_CTA = [
    "sign up", "free trial", "book a demo", "get started",
    "create account", "start free", "try for free", "request a demo",
]

FUNDING_LANGUAGE = [
    "backed by", "raised", "series a", "series b", "series c",
    "seed round", "pre-seed", "funding round",
]

TECH_PRODUCT_DESC = [
    "algorithm", "machine learning", "data platform", "real-time",
    "scalable", "artificial intelligence", "deep learning", "neural network",
    "cloud-native", "microservices",
]

# Non-startup indicators
CONSULTING_DOMINANT = [
    "consulting firm", "advisory", "our consultants", "digital agency",
    "management consulting", "consulting services",
]

PHYSICAL_RETAIL = [
    "visit our store", "our restaurant", "opening hours", "our menu",
    "walk-in", "in-store", "visit us",
]

QUOTE_REQUEST = [
    "request a quote", "free estimate", "contact us for pricing",
    "get a quote", "request estimate",
]

# Regex for established-business language
_ESTABLISHED_RE = re.compile(
    r"(?:since\s+19\d{2}|over\s+(?:30|40|50|60)\s+years|established\s+in\s+19\d{2})",
    re.IGNORECASE,
)

# Structural URL paths that signal a startup
STARTUP_URL_PATHS = {
    "pricing", "plans", "docs", "api", "developers", "product",
    "features", "documentation", "sdk",
}


# ---------------------------------------------------------------------------
# Signal extraction from crawled website
# ---------------------------------------------------------------------------


def extract_website_signals(result: WebsiteCheckResult) -> dict[str, Any]:
    """Analyse crawled pages and return a dict of boolean signals.

    Parameters
    ----------
    result : WebsiteCheckResult
        Output from ``WebsiteChecker.check(url, crawl=True)``.

    Returns
    -------
    dict with keys:
        crawl_ok, has_product_language, has_signup_cta, has_pricing_page,
        has_funding_language, has_tech_product_desc, has_consulting_dominant,
        has_established_language, has_physical_retail, has_quote_request,
        has_startup_url_paths, career_pages_dominant
    """
    signals: dict[str, Any] = {
        "crawl_ok": result.is_alive and len(result.pages) > 0,
        "is_parked": getattr(result, "is_parked", False),
        "has_product_language": False,
        "has_signup_cta": False,
        "has_pricing_page": False,
        "has_funding_language": False,
        "has_tech_product_desc": False,
        "has_consulting_dominant": False,
        "has_established_language": False,
        "has_physical_retail": False,
        "has_quote_request": False,
        "has_startup_url_paths": False,
        "career_pages_dominant": False,
    }

    if not signals["crawl_ok"]:
        return signals

    pages = result.pages
    total_pages = len(pages)

    # Collect all text across pages
    all_titles_headings = " ".join(
        f"{nz(p.title)} {nz(p.headings)}" for p in pages
    )
    all_text = " ".join(nz(p.text) for p in pages)
    all_content = f"{all_titles_headings} {all_text}"

    # ---- Startup signals ----

    # Product language: in titles/headings only
    signals["has_product_language"] = any(
        has_any_keyword(all_titles_headings, [kw]) for kw in PRODUCT_LANGUAGE
    )

    # Signup CTA: in all text
    signals["has_signup_cta"] = any(
        has_any_keyword(all_content, [kw]) for kw in SIGNUP_CTA
    )

    # Pricing page: check URL paths
    page_urls = [p.url.lower() for p in pages]
    signals["has_pricing_page"] = any(
        "/pricing" in u or "/plans" in u for u in page_urls
    )

    # Funding language: in all text
    signals["has_funding_language"] = any(
        has_any_keyword(all_content, [kw]) for kw in FUNDING_LANGUAGE
    )

    # Tech product description: in body text
    signals["has_tech_product_desc"] = any(
        has_any_keyword(all_text, [kw]) for kw in TECH_PRODUCT_DESC
    )

    # ---- Non-startup signals ----

    # Consulting dominance: appears in 50%+ of page titles/headings
    consulting_count = sum(
        1 for p in pages
        if any(
            has_any_keyword(f"{nz(p.title)} {nz(p.headings)}", [kw])
            for kw in CONSULTING_DOMINANT
        )
    )
    signals["has_consulting_dominant"] = (
        consulting_count >= max(1, total_pages * 0.5)
    )

    # Established language: regex across all text
    signals["has_established_language"] = bool(
        _ESTABLISHED_RE.search(all_content)
    )

    # Physical retail: in all text
    signals["has_physical_retail"] = any(
        has_any_keyword(all_content, [kw]) for kw in PHYSICAL_RETAIL
    )

    # Quote request: in all text
    signals["has_quote_request"] = any(
        has_any_keyword(all_content, [kw]) for kw in QUOTE_REQUEST
    )

    # ---- Structural signals ----

    # Startup URL paths
    for url in page_urls:
        path = url.split("//", 1)[-1] if "//" in url else url
        segments = {s.strip("/") for s in path.split("/") if s.strip("/")}
        if segments & STARTUP_URL_PATHS:
            signals["has_startup_url_paths"] = True
            break

    # Career pages dominant (3+ career-like pages)
    career_count = sum(
        1 for u in page_urls
        if any(k in u for k in ("/careers", "/jobs", "/career", "/job"))
    )
    signals["career_pages_dominant"] = career_count >= 3

    return signals


# ---------------------------------------------------------------------------
# Combined scoring: classifier data + website signals
# ---------------------------------------------------------------------------

# Points from existing classifier data
_CLASSIFIER_RULES: list[tuple[str, int]] = []  # populated via function

# Points from website signals
_WEBSITE_SIGNAL_POINTS: dict[str, int] = {
    "has_product_language": 15,
    "has_signup_cta": 12,
    "has_pricing_page": 10,
    "has_funding_language": 8,
    "has_tech_product_desc": 8,
    "has_consulting_dominant": -20,
    "has_established_language": -15,
    "has_physical_retail": -20,
    "has_quote_request": -10,
}

# Classification thresholds
STARTUP_THRESHOLD = 50
NON_STARTUP_THRESHOLD = -20


def _safe_float(x: object) -> float:
    """Convert to float, returning 0.0 for NaN/None/empty."""
    if x is None:
        return 0.0
    try:
        v = float(x)
        return 0.0 if pd.isna(v) else v
    except (ValueError, TypeError):
        return 0.0


def _safe_bool(x: object) -> bool:
    """Convert to bool, handling string 'True'/'False' and NaN."""
    if x is None or (isinstance(x, float) and pd.isna(x)):
        return False
    if isinstance(x, bool):
        return x
    s = str(x).strip().lower()
    return s in ("true", "1", "yes")


def compute_classifier_score(row: pd.Series) -> tuple[float, list[str]]:
    """Score a company using only its existing classifier data.

    Returns (score, list_of_reasons).
    """
    score = 0.0
    reasons: list[str] = []

    # Positive signals
    if _safe_bool(row.get("is_vc_backed")):
        score += 25
        reasons.append("vc_backed(+25)")

    if _safe_bool(row.get("has_accelerator")):
        score += 20
        reasons.append("accelerator(+20)")

    ts = _safe_float(row.get("tech_strength"))
    if ts >= 5:
        score += 20
        reasons.append(f"tech_str={ts:.0f}(+20)")
    elif ts >= 3:
        score += 10
        reasons.append(f"tech_str={ts:.0f}(+10)")

    funding = _safe_float(row.get("total_funding_usd_m"))
    if funding >= 1.0:
        score += 15
        reasons.append(f"funding={funding:.1f}M(+15)")
    elif funding > 0:
        score += 5
        reasons.append(f"funding={funding:.2f}M(+5)")

    ds = _safe_float(row.get("dealroom_signal_rating"))
    if ds >= 50:
        score += 10
        reasons.append(f"dr_signal={ds:.0f}(+10)")

    launch = _safe_float(row.get("launch_year"))
    if launch >= 2015:
        score += 5
        reasons.append(f"launch={launch:.0f}(+5)")

    # Negative signals
    if _safe_bool(row.get("is_service_provider")):
        score -= 15
        reasons.append("service_provider(-15)")

    if _safe_bool(row.get("is_consumer_only")):
        score -= 10
        reasons.append("consumer_only(-10)")

    if 0 < launch < 2000:
        score -= 10
        reasons.append(f"old_launch={launch:.0f}(-10)")

    employees = _safe_float(row.get("employees_latest_number"))
    if employees > 500:
        score -= 10
        reasons.append(f"large_co={employees:.0f}(-10)")

    return score, reasons


def compute_review_score(
    row: pd.Series,
    website_signals: dict[str, Any],
) -> tuple[float, str]:
    """Combine classifier score with website signals.

    Returns (total_score, reason_string).
    """
    score, reasons = compute_classifier_score(row)

    # Add website signal points (only if crawl succeeded)
    if website_signals.get("crawl_ok"):
        for signal_key, points in _WEBSITE_SIGNAL_POINTS.items():
            if website_signals.get(signal_key):
                score += points
                sign = "+" if points > 0 else ""
                reasons.append(f"{signal_key}({sign}{points})")

        # Bonus: startup URL paths
        if website_signals.get("has_startup_url_paths"):
            score += 5
            reasons.append("startup_urls(+5)")
    else:
        reasons.append("no_crawl")

    return score, " | ".join(reasons)


def classify(score: float) -> str:
    """Map a score to a review status.

    Returns one of: ``"startup"``, ``"non-startup"``, ``"for-review"``.
    """
    if score >= STARTUP_THRESHOLD:
        return "startup"
    if score <= NON_STARTUP_THRESHOLD:
        return "non-startup"
    return "for-review"


# ---------------------------------------------------------------------------
# Validation helper — run against already-reviewed companies
# ---------------------------------------------------------------------------


def validate_reviewer(
    df: pd.DataFrame,
    ground_truth_col: str = "reviewStatus",
) -> pd.DataFrame:
    """Score already-reviewed companies and report precision/recall.

    Only uses classifier signals (no crawling). Returns a DataFrame with
    scores and predictions at multiple thresholds for threshold tuning.

    Parameters
    ----------
    df : DataFrame
        Must contain classifier columns (is_vc_backed, tech_strength, etc.)
        and a ground-truth column with "startup" / "non-startup" values.
    ground_truth_col : str
        Column name containing ground truth labels.

    Returns
    -------
    DataFrame with added columns: review_score, predicted_status,
    plus a printed summary of precision/recall at various thresholds.
    """
    scores = []
    for _, row in df.iterrows():
        s, reason = compute_classifier_score(row)
        scores.append({"review_score": s, "review_reason": reason})

    result = df.copy()
    score_df = pd.DataFrame(scores)
    result["review_score"] = score_df["review_score"].values

    # Print precision/recall at various thresholds
    gt = result[ground_truth_col].str.strip().str.lower()
    is_startup = gt == "startup"
    is_non_startup = gt == "non-startup"

    print("\n=== Startup threshold calibration ===")
    for threshold in [30, 35, 40, 45, 50, 55, 60]:
        predicted = result["review_score"] >= threshold
        tp = (predicted & is_startup).sum()
        fp = (predicted & ~is_startup).sum()
        fn = (~predicted & is_startup).sum()
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        coverage = predicted.sum() / len(result) * 100
        print(
            f"  threshold={threshold:3d}: "
            f"precision={precision:.1%} recall={recall:.1%} "
            f"coverage={coverage:.1f}% (TP={tp} FP={fp})"
        )

    print("\n=== Non-startup threshold calibration ===")
    for threshold in [-30, -25, -20, -15, -10, -5, 0]:
        predicted = result["review_score"] <= threshold
        tp = (predicted & is_non_startup).sum()
        fp = (predicted & ~is_non_startup).sum()
        fn = (~predicted & is_non_startup).sum()
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        coverage = predicted.sum() / len(result) * 100
        print(
            f"  threshold={threshold:3d}: "
            f"precision={precision:.1%} recall={recall:.1%} "
            f"coverage={coverage:.1f}% (TP={tp} FP={fp})"
        )

    # Apply default thresholds for the output
    result["predicted_status"] = result["review_score"].apply(classify)

    return result

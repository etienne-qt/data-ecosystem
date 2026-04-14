"""Tests for ecosystem.processing.website_reviewer."""

import pandas as pd
import pytest

from ecosystem.processing.website_checker import PageContent, WebsiteCheckResult
from ecosystem.processing.website_reviewer import (
    STARTUP_THRESHOLD,
    NON_STARTUP_THRESHOLD,
    classify,
    compute_classifier_score,
    compute_review_score,
    extract_website_signals,
)


# ============================================================================
# Test 1: Signal extraction with startup signals
# ============================================================================


def test_extract_website_signals_startup_signals():
    """Extract startup signals: product language, signup CTA, pricing page."""
    pages = [
        PageContent(
            url="http://example.com/pricing",
            title="Our Platform",
            headings="SaaS Dashboard",
            text="sign up for free trial with our platform",
            snippet="sign up",
        ),
    ]
    result = WebsiteCheckResult(
        url="http://example.com",
        is_alive=True,
        status_code=200,
        pages=pages,
    )

    signals = extract_website_signals(result)

    assert signals["crawl_ok"] is True
    assert signals["has_product_language"] is True
    assert signals["has_signup_cta"] is True
    assert signals["has_pricing_page"] is True


# ============================================================================
# Test 2: Signal extraction with non-startup signals
# ============================================================================


def test_extract_website_signals_non_startup_signals():
    """Extract non-startup signals: consulting, established, retail, quote."""
    pages = [
        PageContent(
            url="http://example.com",
            title="Consulting Firm - Advisory Services",
            headings="Our Consultants",
            text="We are established in 1985. Visit our store to request a quote.",
            snippet="consulting",
        ),
    ]
    result = WebsiteCheckResult(
        url="http://example.com",
        is_alive=True,
        status_code=200,
        pages=pages,
    )

    signals = extract_website_signals(result)

    assert signals["crawl_ok"] is True
    assert signals["has_consulting_dominant"] is True
    assert signals["has_established_language"] is True
    assert signals["has_physical_retail"] is True
    assert signals["has_quote_request"] is True


# ============================================================================
# Test 3: Signal extraction with dead website
# ============================================================================


def test_extract_website_signals_dead_website():
    """Dead website: crawl_ok=False, all other signals False."""
    result = WebsiteCheckResult(
        url="http://example.com",
        is_alive=False,
        status_code=404,
        pages=[],
    )

    signals = extract_website_signals(result)

    assert signals["crawl_ok"] is False
    assert signals["has_product_language"] is False
    assert signals["has_signup_cta"] is False
    assert signals["has_pricing_page"] is False
    assert signals["has_consulting_dominant"] is False
    assert signals["has_established_language"] is False
    assert signals["has_physical_retail"] is False
    assert signals["has_quote_request"] is False


# ============================================================================
# Test 4: Signal extraction with empty pages
# ============================================================================


def test_extract_website_signals_empty_pages():
    """Empty pages: crawl_ok=True, but all content signals False."""
    pages = [
        PageContent(
            url="http://example.com",
            title="",
            headings="",
            text="",
            snippet="",
        ),
    ]
    result = WebsiteCheckResult(
        url="http://example.com",
        is_alive=True,
        status_code=200,
        pages=pages,
    )

    signals = extract_website_signals(result)

    assert signals["crawl_ok"] is True
    assert signals["has_product_language"] is False
    assert signals["has_signup_cta"] is False
    assert signals["has_pricing_page"] is False
    assert signals["has_consulting_dominant"] is False
    assert signals["has_established_language"] is False
    assert signals["has_physical_retail"] is False
    assert signals["has_quote_request"] is False


# ============================================================================
# Test 5: Classifier scoring — strong startup
# ============================================================================


def test_compute_classifier_score_strong_startup():
    """Strong startup: vc_backed(25) + accelerator(20) + tech_str=5(20)
    + funding=2M(15) + dealroom=60(10) + launch=2020(5) = 95."""
    row = pd.Series({
        "is_vc_backed": True,
        "has_accelerator": True,
        "tech_strength": 5,
        "total_funding_usd_m": 2.0,
        "dealroom_signal_rating": 60,
        "launch_year": 2020,
    })

    score, reasons = compute_classifier_score(row)

    assert score == 95
    assert "vc_backed(+25)" in reasons
    assert "accelerator(+20)" in reasons
    assert "tech_str=5(+20)" in reasons
    assert "funding=2.0M(+15)" in reasons
    assert "dr_signal=60(+10)" in reasons
    assert "launch=2020(+5)" in reasons


# ============================================================================
# Test 6: Classifier scoring — non-startup signals
# ============================================================================


def test_compute_classifier_score_non_startup_signals():
    """Non-startup: service_provider(-15) + consumer_only(-10)
    + launch=1990(-10) + employees=600(-10) = -45."""
    row = pd.Series({
        "is_service_provider": True,
        "is_consumer_only": True,
        "launch_year": 1990,
        "employees_latest_number": 600,
    })

    score, reasons = compute_classifier_score(row)

    assert score == -45
    assert "service_provider(-15)" in reasons
    assert "consumer_only(-10)" in reasons
    assert "old_launch=1990(-10)" in reasons
    assert "large_co=600(-10)" in reasons


# ============================================================================
# Test 7: Combined scoring with website signals
# ============================================================================


def test_compute_review_score_with_website_signals():
    """Combined: classifier(25 for vc_backed) + website signals
    (15 for product + 12 for signup) = 52."""
    row = pd.Series({
        "is_vc_backed": True,
    })
    website_signals = {
        "crawl_ok": True,
        "has_product_language": True,
        "has_signup_cta": True,
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

    score, reason_str = compute_review_score(row, website_signals)

    assert score == 52
    assert "vc_backed(+25)" in reason_str
    assert "has_product_language(+15)" in reason_str
    assert "has_signup_cta(+12)" in reason_str


# ============================================================================
# Test 8: Classification thresholds
# ============================================================================


def test_classify_startup_threshold():
    """STARTUP_THRESHOLD = 50: >= 50 is startup."""
    assert classify(50) == "startup"
    assert classify(51) == "startup"
    assert classify(49) == "for-review"


def test_classify_non_startup_threshold():
    """NON_STARTUP_THRESHOLD = -20: <= -20 is non-startup."""
    assert classify(-20) == "non-startup"
    assert classify(-21) == "non-startup"
    assert classify(-19) == "for-review"


def test_classify_for_review():
    """Scores between thresholds are for-review."""
    assert classify(0) == "for-review"
    assert classify(25) == "for-review"
    assert classify(-10) == "for-review"


# ============================================================================
# Test 9: No crawl — website signals ignored
# ============================================================================


def test_compute_review_score_no_crawl_ignores_website_signals():
    """When crawl_ok=False, website signal points are NOT added."""
    row = pd.Series({
        "is_vc_backed": True,  # 25 points
    })
    website_signals = {
        "crawl_ok": False,
        "has_product_language": True,  # Would be +15, but ignored
        "has_signup_cta": True,        # Would be +12, but ignored
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

    score, reason_str = compute_review_score(row, website_signals)

    # Should be 25 (vc_backed) + 0 (no website signals) = 25
    assert score == 25
    assert "vc_backed(+25)" in reason_str
    assert "has_product_language" not in reason_str
    assert "has_signup_cta" not in reason_str
    assert "no_crawl" in reason_str


# ============================================================================
# Additional edge case tests
# ============================================================================


def test_compute_classifier_score_with_nans():
    """NaN values in classifier data should be treated as 0 or False."""
    row = pd.Series({
        "is_vc_backed": float("nan"),
        "tech_strength": float("nan"),
        "total_funding_usd_m": float("nan"),
    })

    score, reasons = compute_classifier_score(row)

    # All NaNs → no points added
    assert score == 0
    assert len(reasons) == 0


def test_compute_classifier_score_mixed_signals():
    """Mix of positive and negative signals."""
    row = pd.Series({
        "is_vc_backed": True,           # +25
        "is_service_provider": True,    # -15
        "tech_strength": 3,             # +10
        "launch_year": 1990,            # -10 (old, < 2000)
    })

    score, reasons = compute_classifier_score(row)

    # 25 - 15 + 10 - 10 = 10
    assert score == 10


def test_extract_website_signals_multiple_pages():
    """Multiple pages: consulting dominance requires 50%+ of pages."""
    pages = [
        PageContent(
            url="http://example.com",
            title="Consulting Firm",
            headings="Our Consultants",
            text="",
        ),
        PageContent(
            url="http://example.com/about",
            title="About Us",
            headings="",
            text="",
        ),
    ]
    result = WebsiteCheckResult(
        url="http://example.com",
        is_alive=True,
        status_code=200,
        pages=pages,
    )

    signals = extract_website_signals(result)

    # 1 out of 2 pages = 50%, so consulting_dominant should be True
    assert signals["has_consulting_dominant"] is True


def test_extract_website_signals_startup_url_paths():
    """Detect startup URL paths like /pricing, /api, /developers."""
    pages = [
        PageContent(
            url="http://example.com/api",
            title="API Documentation",
            headings="",
            text="",
        ),
    ]
    result = WebsiteCheckResult(
        url="http://example.com",
        is_alive=True,
        status_code=200,
        pages=pages,
    )

    signals = extract_website_signals(result)

    assert signals["has_startup_url_paths"] is True


def test_extract_website_signals_career_pages_dominant():
    """Career pages dominant: 3+ pages with career keywords."""
    pages = [
        PageContent(url="http://example.com/careers", title="", headings="", text=""),
        PageContent(url="http://example.com/jobs", title="", headings="", text=""),
        PageContent(url="http://example.com/job/engineer", title="", headings="", text=""),
    ]
    result = WebsiteCheckResult(
        url="http://example.com",
        is_alive=True,
        status_code=200,
        pages=pages,
    )

    signals = extract_website_signals(result)

    assert signals["career_pages_dominant"] is True


def test_extract_website_signals_funding_language():
    """Detect funding language: 'backed by', 'series a', 'raised'."""
    pages = [
        PageContent(
            url="http://example.com",
            title="",
            headings="",
            text="We are backed by leading VCs and raised Series A funding.",
        ),
    ]
    result = WebsiteCheckResult(
        url="http://example.com",
        is_alive=True,
        status_code=200,
        pages=pages,
    )

    signals = extract_website_signals(result)

    assert signals["has_funding_language"] is True


def test_extract_website_signals_tech_product_desc():
    """Detect tech product description: 'machine learning', 'data platform'."""
    pages = [
        PageContent(
            url="http://example.com",
            title="",
            headings="",
            text="Our AI platform uses machine learning to analyze data in real-time.",
        ),
    ]
    result = WebsiteCheckResult(
        url="http://example.com",
        is_alive=True,
        status_code=200,
        pages=pages,
    )

    signals = extract_website_signals(result)

    assert signals["has_tech_product_desc"] is True


def test_compute_classifier_score_partial_signals():
    """Some signals present, others missing."""
    row = pd.Series({
        "is_vc_backed": True,           # +25
        "has_accelerator": False,
        "tech_strength": 2,             # < 3, no points
        "total_funding_usd_m": 0.5,     # > 0, < 1.0: +5
    })

    score, reasons = compute_classifier_score(row)

    assert score == 30  # 25 + 5


def test_compute_review_score_with_startup_url_bonus():
    """Startup URL paths bonus: +5 points when crawl_ok=True."""
    row = pd.Series({})
    website_signals = {
        "crawl_ok": True,
        "has_startup_url_paths": True,
        "has_product_language": False,
        "has_signup_cta": False,
        "has_pricing_page": False,
        "has_funding_language": False,
        "has_tech_product_desc": False,
        "has_consulting_dominant": False,
        "has_established_language": False,
        "has_physical_retail": False,
        "has_quote_request": False,
        "career_pages_dominant": False,
    }

    score, reason_str = compute_review_score(row, website_signals)

    assert score == 5  # Only startup_urls(+5)
    assert "startup_urls(+5)" in reason_str


def test_compute_review_score_negative_website_signals():
    """Negative website signals reduce the score."""
    row = pd.Series({
        "is_vc_backed": True,  # +25
    })
    website_signals = {
        "crawl_ok": True,
        "has_consulting_dominant": True,      # -20
        "has_established_language": True,     # -15
        "has_product_language": False,
        "has_signup_cta": False,
        "has_pricing_page": False,
        "has_funding_language": False,
        "has_tech_product_desc": False,
        "has_physical_retail": False,
        "has_quote_request": False,
        "has_startup_url_paths": False,
        "career_pages_dominant": False,
    }

    score, reason_str = compute_review_score(row, website_signals)

    # 25 (vc_backed) - 20 (consulting) - 15 (established) = -10
    assert score == -10
    assert "has_consulting_dominant(-20)" in reason_str
    assert "has_established_language(-15)" in reason_str


def test_extract_website_signals_empty_result():
    """WebsiteCheckResult with empty pages list."""
    result = WebsiteCheckResult(
        url="http://example.com",
        is_alive=True,
        status_code=200,
        pages=[],
    )

    signals = extract_website_signals(result)

    assert signals["crawl_ok"] is False
    assert signals["has_product_language"] is False


def test_classify_boundary_cases():
    """Test exact threshold boundaries."""
    # At startup threshold
    assert classify(float(STARTUP_THRESHOLD)) == "startup"

    # At non-startup threshold
    assert classify(float(NON_STARTUP_THRESHOLD)) == "non-startup"

    # Just below startup
    assert classify(float(STARTUP_THRESHOLD) - 0.1) == "for-review"

    # Just above non-startup
    assert classify(float(NON_STARTUP_THRESHOLD) + 0.1) == "for-review"

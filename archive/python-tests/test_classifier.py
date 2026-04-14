"""Tests for ecosystem.processing.classifier."""

import pandas as pd

from ecosystem.processing.classifier import (
    ClassifierConfig,
    ecommerce_only,
    has_any_keyword,
    has_tech_indication,
    is_gov_or_nonprofit,
    is_service_provider,
    is_vc_backed,
    nz,
    rate_companies,
    rate_company,
    safe_float,
)


def test_nz_normalizes():
    assert nz("  Hello World  ") == "hello world"
    assert nz(None) == ""
    assert nz(float("nan")) == ""
    assert nz("Café") == "cafe"


def test_safe_float():
    assert safe_float("1,234.56") == 1234.56
    assert safe_float("nan") == 0.0
    assert safe_float(None) == 0.0
    assert safe_float("") == 0.0
    assert safe_float("42") == 42.0


def test_has_any_keyword():
    assert has_any_keyword("We build AI models", ["ai", "ml"])
    assert not has_any_keyword("We sell furniture", ["ai", "ml"])
    assert not has_any_keyword("", ["ai"])


def test_has_any_keyword_word_boundary():
    """Short keywords (<=3 chars) use word-boundary matching."""
    # "ai" should NOT match inside "maintenance"
    assert not has_any_keyword("maintenance", ["ai"])
    # "ai" should match in "ai-powered" (non-alphanumeric boundary)
    assert has_any_keyword("ai-powered tools", ["ai"])
    # "ar" should NOT match inside "software"
    assert not has_any_keyword("software", ["ar"])
    # "ar" should match in "ar/vr"
    assert has_any_keyword("ar/vr headset", ["ar"])
    # "bi" should NOT match inside "ability"
    assert not has_any_keyword("ability", ["bi"])
    # Longer keywords still use substring matching
    assert has_any_keyword("predictive analytics dashboard", ["analytics"])


def _make_row(**kwargs) -> pd.Series:
    return pd.Series(kwargs)


def test_is_gov_or_nonprofit():
    row = _make_row(Website="https://example.gouv.qc.ca", Name="MinSante")
    assert is_gov_or_nonprofit(row)

    row = _make_row(Website="https://startup.com", Name="TechCo")
    assert not is_gov_or_nonprofit(row)


def test_is_service_provider():
    row = _make_row(Tagline="Digital marketing agency", Name="AgencyX")
    assert is_service_provider(row)

    row = _make_row(Tagline="AI-powered analytics platform", Name="AnalyticsCo")
    assert not is_service_provider(row)


def test_has_tech_indication():
    row = _make_row(Industries="artificial intelligence, machine learning")
    assert has_tech_indication(row)

    row = _make_row(Industries="restaurants, food delivery")
    assert not has_tech_indication(row)


def test_is_vc_backed():
    row = _make_row(**{"Each investor type": "venture capital, angel"})
    assert is_vc_backed(row)

    row = _make_row(**{"Each investor type": "government grant"})
    assert not is_vc_backed(row)


def test_ecommerce_only():
    row = _make_row(Technologies="ecommerce, marketplace")
    assert ecommerce_only(row)

    row = _make_row(Technologies="ecommerce, AI")
    assert not ecommerce_only(row)

    row = _make_row(Technologies="")
    assert not ecommerce_only(row)


def test_rate_company_a_plus():
    """VC-backed tech company with high Dealroom signal → A+."""
    row = _make_row(
        ID="1",
        Name="DeepTech Inc",
        Industries="artificial intelligence",
        **{
            "Each investor type": "venture capital",
            "Dealroom Signal - Rating": "60",
            "Website": "https://deeptech.io",
        },
    )
    result = rate_company(row)
    assert result["rating"] == "A+"


def test_rate_company_gov_catches_as_c_or_d():
    """Government org with no other signals hits C path (no signals) before D gov check.

    This matches the original decision tree: gov check is a late fallback.
    The is_gov_or_nonprofit flag is checked at the end, after all A-D paths.
    """
    row = _make_row(
        ID="2",
        Name="Ministere de la Sante",
        Website="https://sante.gouv.qc.ca",
    )
    result = rate_company(row)
    assert result["rating"] in ("C", "D")

    # Verify the flag itself works correctly
    assert is_gov_or_nonprofit(row) is True


def test_rate_company_manual_override():
    row = _make_row(ID="99", Name="Test", **{"Manual override": "A+"})
    result = rate_company(row)
    assert result["rating"] == "A+"
    assert result["reason"] == "manual_override_column"


def test_rate_companies_api():
    """Test the public API returns correct DataFrame structure."""
    df = pd.DataFrame({
        "ID": ["1", "2"],
        "Name": ["TechStartup", "GovOrg"],
        "Industries": ["artificial intelligence", "public health"],
        "Website": ["https://tech.io", "https://sante.gouv.qc.ca"],
        "Each investor type": ["venture capital", ""],
        "Dealroom Signal - Rating": ["60", "0"],
    })
    result = rate_companies(df, score_version="test_v1")
    assert list(result.columns) == [
        "drm_company_id", "startup_rating_letter", "rating_reason", "score_version", "startup_score",
    ]
    assert len(result) == 2
    assert result["score_version"].iloc[0] == "test_v1"
    assert result["startup_rating_letter"].iloc[0] == "A+"


def test_rate_companies_config_override():
    """Test that ClassifierConfig.manual_overrides works."""
    df = pd.DataFrame({"ID": ["42"], "Name": ["Test"]})
    config = ClassifierConfig(manual_overrides={"42": "B"})
    result = rate_companies(df, config=config)
    assert result["startup_rating_letter"].iloc[0] == "B"


def test_weak_tech_no_vc_downgrade_to_b():
    """tech_strength < 3 + no VC/accel on dominant A path → B."""
    row = _make_row(
        ID="100",
        Name="OldSoftware Co",
        Tagline="data solutions",       # one tech hit (data)
        Industries="technology",
        **{
            "Dealroom Signal - Rating": "10",
            "Website": "https://example.com",
        },
    )
    result = rate_company(row)
    assert result["rating"] == "B"
    assert result["reason"] == "B_weak_tech_no_vc_no_accel_downgrade"


def test_old_company_no_vc_override_to_c():
    """Launch year < 2005 + no VC/accel → C."""
    row = _make_row(
        ID="101",
        Name="LegacyTech",
        Industries="artificial intelligence, machine learning, deep learning",
        Technologies="ai, machine learning",
        **{
            "Launch year": "1998",
            "Dealroom Signal - Rating": "10",
            "Website": "https://legacy.com",
        },
    )
    result = rate_company(row)
    assert result["rating"] == "C"
    assert result["reason"] == "C_old_company_no_vc_no_accel_override"


def test_old_company_with_vc_stays_a():
    """Launch year < 2005 but VC-backed → stays A (not overridden)."""
    row = _make_row(
        ID="102",
        Name="RevivedTech",
        Industries="artificial intelligence, machine learning, deep learning",
        Technologies="ai, machine learning",
        **{
            "Launch year": "1998",
            "Each investor type": "venture capital",
            "Dealroom Signal - Rating": "10",
            "Website": "https://revived.com",
        },
    )
    result = rate_company(row)
    assert result["rating"] == "A"


def test_a_plus_still_passes():
    """Regression: existing A+ path still works."""
    row = _make_row(
        ID="200",
        Name="TopStartup",
        Industries="artificial intelligence",
        **{
            "Each investor type": "venture capital",
            "Dealroom Signal - Rating": "60",
            "Website": "https://topstartup.io",
        },
    )
    result = rate_company(row)
    assert result["rating"] == "A+"

"""Tests for ecosystem.processing.matcher."""

import pandas as pd

from ecosystem.processing.matcher import (
    ColumnMapping,
    match_datasets,
    normalize_register_number,
    normalize_text,
    normalize_url,
)


def test_normalize_text():
    assert normalize_text("  Hello   World  ") == "hello world"
    assert normalize_text(None) is None
    assert normalize_text("") is None


def test_normalize_url():
    assert normalize_url("https://www.Example.com/path/") == "example.com/path"
    assert normalize_url("http://example.com") == "example.com"
    assert normalize_url(None) is None


def test_normalize_register_number():
    assert normalize_register_number("123-456-7890") == "1234567890"
    assert normalize_register_number("ABC 123") == "ABC123"
    assert normalize_register_number(None) is None


def test_match_datasets_basic():
    """Companies matched on name."""
    hubspot = pd.DataFrame({
        "Nom de l'entreprise": ["Acme Corp", "Unique HS Co"],
        "URL du site web": ["https://acme.com", "https://unique.com"],
    })
    dealroom = pd.DataFrame({
        "ID": ["1", "2"],
        "Name": ["acme corp", "Only DR Co"],
        "Website": ["https://acme.com", "https://onlydr.com"],
    })

    hs_out, dr_out = match_datasets(hubspot, dealroom)

    assert "matched with Dealroom" in hs_out.columns
    assert "matched with Hubspot" in dr_out.columns

    # Acme Corp should match on both name and website
    assert hs_out["matched with Dealroom"].iloc[0] == True
    assert dr_out["matched with Hubspot"].iloc[0] == True

    # Unique ones should not match
    assert hs_out["matched with Dealroom"].iloc[1] == False
    assert dr_out["matched with Hubspot"].iloc[1] == False


def test_match_datasets_by_website():
    """Companies matched on website URL normalization."""
    hubspot = pd.DataFrame({
        "Nom de l'entreprise": ["Different Name"],
        "URL du site web": ["https://www.Example.com/"],
    })
    dealroom = pd.DataFrame({
        "ID": ["1"],
        "Name": ["Also Different"],
        "Website": ["http://example.com"],
    })

    hs_out, dr_out = match_datasets(hubspot, dealroom)
    assert hs_out["matched with Dealroom"].iloc[0] == True
    assert dr_out["matched with Hubspot"].iloc[0] == True


def test_match_datasets_by_register():
    """Companies matched on NEQ / register number."""
    hubspot = pd.DataFrame({
        "Nom de l'entreprise": ["Company A"],
        "(NEQ) Numéro d'entreprise du Québec": ["1234-567-890"],
    })
    dealroom = pd.DataFrame({
        "ID": ["1"],
        "Name": ["Company B"],
        "Trade register number": ["1234567890"],
    })

    hs_out, dr_out = match_datasets(hubspot, dealroom)
    assert hs_out["matched with Dealroom"].iloc[0] == True


def test_match_datasets_no_norm_cols_leaked():
    """Normalized columns should not appear in output."""
    hubspot = pd.DataFrame({"Nom de l'entreprise": ["Test"]})
    dealroom = pd.DataFrame({"ID": ["1"], "Name": ["Test"]})

    hs_out, dr_out = match_datasets(hubspot, dealroom)
    assert not any(c.endswith("_norm") for c in hs_out.columns)
    assert not any(c.endswith("_norm") for c in dr_out.columns)

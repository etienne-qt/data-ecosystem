"""Tests for ecosystem.connectors.google_auth."""

import json

import pytest

from ecosystem.connectors.google_auth import (
    ALL_SCOPES,
    DEFAULT_TOKEN_PATH,
    _load_token,
    _save_token,
)


def test_all_scopes_defined():
    """All required scopes should be present."""
    assert any("documents" in s for s in ALL_SCOPES)
    assert any("drive" in s for s in ALL_SCOPES)
    assert any("gmail" in s for s in ALL_SCOPES)
    assert any("calendar" in s for s in ALL_SCOPES)


def test_default_token_path():
    assert "ecosystem" in str(DEFAULT_TOKEN_PATH)
    assert str(DEFAULT_TOKEN_PATH).endswith("google_token.json")


def test_load_token_missing_file(tmp_path):
    """Loading from a nonexistent file should return None."""
    result = _load_token(tmp_path / "nonexistent.json", ALL_SCOPES)
    assert result is None


def test_load_token_invalid_json(tmp_path):
    """Loading from a corrupt file should return None (not crash)."""
    bad_file = tmp_path / "bad.json"
    bad_file.write_text("not valid json{{{")
    result = _load_token(bad_file, ALL_SCOPES)
    assert result is None


def test_get_credentials_no_client_file_raises(tmp_path, monkeypatch):
    """get_google_credentials should raise FileNotFoundError when no client file exists."""
    monkeypatch.setattr("ecosystem.connectors.google_auth.settings.google.oauth_client_file", str(tmp_path / "nonexistent.json"))
    monkeypatch.setattr("ecosystem.connectors.google_auth.settings.google.oauth_token_file", str(tmp_path / "token.json"))

    from ecosystem.connectors.google_auth import get_google_credentials

    with pytest.raises(FileNotFoundError, match="client secrets"):
        get_google_credentials(interactive=True, token_file=tmp_path / "token.json", client_file=str(tmp_path / "nonexistent.json"))


def test_get_credentials_non_interactive_no_token_raises(tmp_path, monkeypatch):
    """Non-interactive mode should raise RuntimeError when no token exists."""
    monkeypatch.setattr("ecosystem.connectors.google_auth.settings.google.oauth_client_file", "")
    monkeypatch.setattr("ecosystem.connectors.google_auth.settings.google.oauth_token_file", str(tmp_path / "token.json"))

    from ecosystem.connectors.google_auth import get_google_credentials

    with pytest.raises(RuntimeError, match="eco google-auth"):
        get_google_credentials(interactive=False, token_file=tmp_path / "token.json")

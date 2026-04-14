"""Tests for ecosystem.connectors.asana_auth — token management (no API calls)."""

import json

import pytest

from ecosystem.connectors.asana_auth import (
    DEFAULT_TOKEN_PATH,
    _load_token,
    _save_token,
)


def test_default_token_path():
    assert "ecosystem" in str(DEFAULT_TOKEN_PATH)
    assert str(DEFAULT_TOKEN_PATH).endswith("asana_token.json")


def test_load_token_missing_file(tmp_path):
    result = _load_token(tmp_path / "nonexistent.json")
    assert result is None


def test_load_token_invalid_json(tmp_path):
    bad_file = tmp_path / "bad.json"
    bad_file.write_text("not json{{{")
    result = _load_token(bad_file)
    assert result is None


def test_save_and_load_token(tmp_path):
    token_path = tmp_path / "subdir" / "token.json"
    data = {"access_token": "test_token", "refresh_token": "test_refresh"}

    _save_token(data, token_path)

    assert token_path.exists()
    loaded = _load_token(token_path)
    assert loaded["access_token"] == "test_token"
    assert loaded["refresh_token"] == "test_refresh"


def test_get_asana_access_token_no_creds_raises(tmp_path, monkeypatch):
    """Should raise RuntimeError when no credentials are configured."""
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.client_id", "")
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.client_secret", "")
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.access_token", "")
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.oauth_token_file", str(tmp_path / "token.json"))

    from ecosystem.connectors.asana_auth import get_asana_access_token

    with pytest.raises(RuntimeError, match="No valid Asana credentials"):
        get_asana_access_token(interactive=False, token_file=tmp_path / "token.json")


def test_get_asana_access_token_falls_back_to_pat(tmp_path, monkeypatch):
    """Should fall back to PAT when OAuth is not configured."""
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.client_id", "")
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.client_secret", "")
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.access_token", "my_pat_token")
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.oauth_token_file", str(tmp_path / "token.json"))

    from ecosystem.connectors.asana_auth import get_asana_access_token

    token = get_asana_access_token(interactive=False, token_file=tmp_path / "token.json")
    assert token == "my_pat_token"


def test_get_asana_access_token_loads_stored_token(tmp_path, monkeypatch):
    """Should load access token from stored file."""
    token_path = tmp_path / "token.json"
    token_path.write_text(json.dumps({"access_token": "stored_token"}))

    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.client_id", "")
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.client_secret", "")
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.access_token", "")
    monkeypatch.setattr("ecosystem.connectors.asana_auth.settings.asana.oauth_token_file", str(token_path))

    from ecosystem.connectors.asana_auth import get_asana_access_token

    token = get_asana_access_token(interactive=False, token_file=token_path)
    assert token == "stored_token"

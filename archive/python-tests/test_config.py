"""Test that config loads without errors."""

from ecosystem.config import Settings, PROJECT_ROOT


def test_settings_load():
    """Settings should instantiate and load from .env."""
    s = Settings()
    assert s.project_root == PROJECT_ROOT
    assert isinstance(s.snowflake.warehouse, str)
    assert isinstance(s.snowflake.database, str)
    assert len(s.snowflake.database) > 0


def test_project_root_exists():
    assert PROJECT_ROOT.exists()

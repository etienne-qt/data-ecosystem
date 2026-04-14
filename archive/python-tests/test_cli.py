"""Tests for ecosystem.cli — Click command smoke tests."""

import pytest
from click.testing import CliRunner

from ecosystem.cli import cli


@pytest.fixture
def runner():
    return CliRunner()


def test_cli_help(runner):
    result = runner.invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "Startup Ecosystem" in result.output


def test_run_agent_list(runner):
    result = runner.invoke(cli, ["run-agent", "list"])
    assert result.exit_code == 0
    assert "Available tasks" in result.output


def test_run_agent_unknown(runner):
    result = runner.invoke(cli, ["run-agent", "nonexistent_xyz"])
    assert result.exit_code == 0
    assert "Failed" in result.output


def test_search_no_store(runner, tmp_path, monkeypatch):
    """Search with no documents should report no results."""
    monkeypatch.setattr("ecosystem.config.settings.knowledge_base_dir", tmp_path / "kb")
    (tmp_path / "kb").mkdir()
    result = runner.invoke(cli, ["search", "anything"])
    # May say "No results" or show empty table — shouldn't crash
    assert result.exit_code == 0


def test_status_command(runner):
    result = runner.invoke(cli, ["status"])
    assert result.exit_code == 0
    assert "Knowledge Base" in result.output


def test_reindex_command(runner, tmp_path, monkeypatch):
    monkeypatch.setattr("ecosystem.config.settings.knowledge_base_dir", tmp_path / "kb")
    (tmp_path / "kb").mkdir()
    result = runner.invoke(cli, ["reindex"])
    assert result.exit_code == 0
    assert "Reindexed" in result.output


def test_schedule_generate(runner, tmp_path, monkeypatch):
    """Schedule command should generate plist files without --install."""
    monkeypatch.setattr("ecosystem.config.settings.project_root", tmp_path)
    result = runner.invoke(cli, ["schedule"])
    assert result.exit_code == 0
    assert "Generated" in result.output


def test_ingest_nonexistent_file(runner):
    result = runner.invoke(cli, ["ingest", "/nonexistent/file.md"])
    assert result.exit_code != 0  # click.Path(exists=True) should reject

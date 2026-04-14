"""Tests for ecosystem.agents.runner."""

import pytest
from datetime import datetime

from ecosystem.agents.runner import (
    AgentRunner,
    TaskResult,
    TaskStatus,
    _TASK_REGISTRY,
    get_registered_tasks,
    register_task,
)


@pytest.fixture(autouse=True)
def _clean_registry():
    """Save and restore the task registry around each test."""
    saved = dict(_TASK_REGISTRY)
    yield
    _TASK_REGISTRY.clear()
    _TASK_REGISTRY.update(saved)


def test_register_task():
    @register_task("test_task")
    def my_task(**kwargs):
        return TaskResult(
            task_name="test_task",
            status=TaskStatus.SUCCESS,
            started_at=datetime.now(),
            message="done",
        )

    assert "test_task" in _TASK_REGISTRY
    assert "test_task" in get_registered_tasks()


def test_run_task_success(tmp_path):
    @register_task("good_task")
    def good(**kwargs):
        return TaskResult(
            task_name="good_task",
            status=TaskStatus.SUCCESS,
            started_at=datetime.now(),
            message="all good",
        )

    runner = AgentRunner(logs_dir=tmp_path / "logs")
    result = runner.run_task("good_task")

    assert result.status == TaskStatus.SUCCESS
    assert result.message == "all good"
    assert result.duration_seconds >= 0


def test_run_task_failure(tmp_path):
    @register_task("bad_task")
    def bad(**kwargs):
        raise ValueError("something broke")

    runner = AgentRunner(logs_dir=tmp_path / "logs")
    result = runner.run_task("bad_task")

    assert result.status == TaskStatus.FAILED
    assert "something broke" in result.error


def test_run_unknown_task(tmp_path):
    runner = AgentRunner(logs_dir=tmp_path / "logs")
    result = runner.run_task("nonexistent_task")

    assert result.status == TaskStatus.FAILED
    assert "Unknown task" in result.error


def test_log_and_get_last_run(tmp_path):
    @register_task("logged_task")
    def logged(**kwargs):
        return TaskResult(
            task_name="logged_task",
            status=TaskStatus.SUCCESS,
            started_at=datetime.now(),
            message="logged run",
        )

    runner = AgentRunner(logs_dir=tmp_path / "logs")
    runner.run_task("logged_task")

    last = runner.get_last_run("logged_task")
    assert last is not None
    assert last.status == TaskStatus.SUCCESS
    assert last.task_name == "logged_task"


def test_get_last_run_not_found(tmp_path):
    runner = AgentRunner(logs_dir=tmp_path / "logs")
    assert runner.get_last_run("never_ran") is None


def test_task_result_duration():
    start = datetime(2026, 1, 1, 12, 0, 0)
    end = datetime(2026, 1, 1, 12, 0, 5)
    result = TaskResult(
        task_name="test",
        status=TaskStatus.SUCCESS,
        started_at=start,
        finished_at=end,
    )
    assert result.duration_seconds == 5.0


def test_default_tasks_registered(tmp_path):
    """Importing the task modules should register the default tasks."""
    import importlib
    from ecosystem.agents.tasks import nightly_sync, classify_new, match_resolve, report_gen, notes_ingest

    # Force re-execution of decorators after _clean_registry cleared the registry
    for mod in [nightly_sync, classify_new, match_resolve, report_gen, notes_ingest]:
        importlib.reload(mod)

    tasks = get_registered_tasks()
    expected = {"nightly_sync", "classify_new", "match_resolve", "report_gen", "notes_ingest"}
    assert expected.issubset(set(tasks))

"""Tests for ecosystem.agents.scheduler."""

import plistlib

import pytest

from ecosystem.agents.scheduler import DEFAULT_SCHEDULES, PLIST_PREFIX, ScheduleConfig, Scheduler


def test_schedule_config_defaults():
    cfg = ScheduleConfig(task_name="my_task")
    assert cfg.hour == 2
    assert cfg.minute == 0
    assert cfg.weekday is None
    assert cfg.label == f"{PLIST_PREFIX}.my-task"


def test_schedule_config_custom_label():
    cfg = ScheduleConfig(task_name="x", label="custom.label")
    assert cfg.label == "custom.label"


def test_default_schedules():
    names = [s.task_name for s in DEFAULT_SCHEDULES]
    assert "nightly_sync" in names
    assert "report_gen" in names
    assert len(DEFAULT_SCHEDULES) == 5


def test_generate_plist(tmp_path):
    scheduler = Scheduler(plist_dir=tmp_path / "plists", project_root=tmp_path / "project")
    config = ScheduleConfig(task_name="test_task", hour=4, minute=30)

    plist_path = scheduler.generate_plist(config)

    assert plist_path.exists()
    assert plist_path.suffix == ".plist"

    with open(plist_path, "rb") as f:
        data = plistlib.load(f)

    assert data["Label"] == f"{PLIST_PREFIX}.test-task"
    assert data["StartCalendarInterval"]["Hour"] == 4
    assert data["StartCalendarInterval"]["Minute"] == 30
    assert "Weekday" not in data["StartCalendarInterval"]
    assert "run-agent" in data["ProgramArguments"]
    assert "test_task" in data["ProgramArguments"]


def test_generate_plist_with_weekday(tmp_path):
    scheduler = Scheduler(plist_dir=tmp_path / "plists", project_root=tmp_path / "project")
    config = ScheduleConfig(task_name="weekly", hour=6, minute=0, weekday=1)

    plist_path = scheduler.generate_plist(config)

    with open(plist_path, "rb") as f:
        data = plistlib.load(f)

    assert data["StartCalendarInterval"]["Weekday"] == 1


def test_generate_all(tmp_path):
    scheduler = Scheduler(plist_dir=tmp_path / "plists", project_root=tmp_path / "project")
    paths = scheduler.generate_all()

    assert len(paths) == len(DEFAULT_SCHEDULES)
    for p in paths:
        assert p.exists()


def test_generate_all_custom_schedules(tmp_path):
    scheduler = Scheduler(plist_dir=tmp_path / "plists", project_root=tmp_path / "project")
    custom = [ScheduleConfig(task_name="a"), ScheduleConfig(task_name="b")]
    paths = scheduler.generate_all(custom)

    assert len(paths) == 2


def test_uninstall_plist_not_found(tmp_path):
    scheduler = Scheduler(plist_dir=tmp_path / "plists", project_root=tmp_path / "project")
    # Should return False for non-existent plist
    assert scheduler.uninstall_plist("nonexistent.label") is False


def test_plist_working_directory(tmp_path):
    project = tmp_path / "myproject"
    scheduler = Scheduler(plist_dir=tmp_path / "plists", project_root=project)
    config = ScheduleConfig(task_name="wd_test")
    plist_path = scheduler.generate_plist(config)

    with open(plist_path, "rb") as f:
        data = plistlib.load(f)

    assert data["WorkingDirectory"] == str(project)


def test_plist_log_paths(tmp_path):
    scheduler = Scheduler(plist_dir=tmp_path / "plists", project_root=tmp_path / "project")
    config = ScheduleConfig(task_name="log_test")
    scheduler.generate_plist(config)

    log_dir = tmp_path / "project" / "logs"
    assert log_dir.exists()

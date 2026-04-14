"""Launchd plist generator and missed-run recovery.

Generates macOS launchd plist files for scheduled agent tasks.
Launchd natively handles wake-from-sleep scheduling.

Usage:
    from ecosystem.agents.scheduler import Scheduler
    scheduler = Scheduler()
    scheduler.generate_plist("nightly_sync", hour=2, minute=0)
    scheduler.install_all()
    scheduler.check_missed_runs()
"""

from __future__ import annotations

import logging
import plistlib
import subprocess
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path

from ecosystem.config import settings

logger = logging.getLogger(__name__)

LAUNCHD_DIR = Path.home() / "Library" / "LaunchAgents"
PLIST_PREFIX = "com.ecosystem"


@dataclass
class ScheduleConfig:
    """Configuration for a scheduled task."""

    task_name: str
    hour: int = 2
    minute: int = 0
    weekday: int | None = None  # 0=Sunday, 1=Monday, ..., 6=Saturday. None = daily.
    label: str = ""

    def __post_init__(self) -> None:
        if not self.label:
            self.label = f"{PLIST_PREFIX}.{self.task_name.replace('_', '-')}"


# Default schedules
DEFAULT_SCHEDULES = [
    ScheduleConfig(task_name="nightly_sync", hour=2, minute=0),
    ScheduleConfig(task_name="classify_new", hour=3, minute=0),
    ScheduleConfig(task_name="match_resolve", hour=3, minute=30),
    ScheduleConfig(task_name="report_gen", hour=6, minute=0, weekday=1),  # Monday mornings
    ScheduleConfig(task_name="notes_ingest", hour=7, minute=0),
]


class Scheduler:
    """Generate and manage launchd plists for agent tasks."""

    def __init__(
        self,
        plist_dir: str | Path | None = None,
        project_root: str | Path | None = None,
    ) -> None:
        self.plist_dir = Path(plist_dir) if plist_dir else settings.project_root / "agents" / "launchd"
        self.plist_dir.mkdir(parents=True, exist_ok=True)
        self.project_root = Path(project_root or settings.project_root)

    def generate_plist(self, config: ScheduleConfig) -> Path:
        """Generate a launchd plist file for a scheduled task.

        Args:
            config: Schedule configuration.

        Returns:
            Path to the generated plist file.
        """
        venv_python = self.project_root / ".venv" / "bin" / "python"
        log_dir = self.project_root / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)

        calendar_interval: dict[str, int] = {
            "Hour": config.hour,
            "Minute": config.minute,
        }
        if config.weekday is not None:
            calendar_interval["Weekday"] = config.weekday

        plist_data = {
            "Label": config.label,
            "ProgramArguments": [
                str(venv_python),
                "-m", "ecosystem.cli",
                "run-agent", config.task_name,
            ],
            "WorkingDirectory": str(self.project_root),
            "StartCalendarInterval": calendar_interval,
            "StandardOutPath": str(log_dir / f"{config.task_name}.stdout.log"),
            "StandardErrorPath": str(log_dir / f"{config.task_name}.stderr.log"),
            "EnvironmentVariables": {
                "PATH": "/usr/local/bin:/usr/bin:/bin",
                "PYTHONPATH": str(self.project_root / "src"),
            },
            # Run missed jobs when waking from sleep
            "StartInterval": 0,  # Placeholder — CalendarInterval is primary
        }

        plist_path = self.plist_dir / f"{config.label}.plist"
        with open(plist_path, "wb") as f:
            plistlib.dump(plist_data, f)

        logger.info("Generated plist: %s", plist_path)
        return plist_path

    def generate_all(self, schedules: list[ScheduleConfig] | None = None) -> list[Path]:
        """Generate plist files for all scheduled tasks.

        Args:
            schedules: List of schedule configs. Uses DEFAULT_SCHEDULES if None.

        Returns:
            List of paths to generated plist files.
        """
        configs = schedules or DEFAULT_SCHEDULES
        return [self.generate_plist(config) for config in configs]

    def install_plist(self, plist_path: Path) -> bool:
        """Install a plist by symlinking to ~/Library/LaunchAgents and loading.

        Args:
            plist_path: Path to the plist file.

        Returns:
            True if successful.
        """
        LAUNCHD_DIR.mkdir(parents=True, exist_ok=True)
        target = LAUNCHD_DIR / plist_path.name

        # Remove existing symlink/file
        if target.exists() or target.is_symlink():
            # Unload first
            subprocess.run(
                ["launchctl", "unload", str(target)],
                capture_output=True,
            )
            target.unlink()

        # Create symlink
        target.symlink_to(plist_path.resolve())

        # Load
        result = subprocess.run(
            ["launchctl", "load", str(target)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            logger.error("Failed to load plist %s: %s", target, result.stderr)
            return False

        logger.info("Installed and loaded: %s", target)
        return True

    def install_all(self, schedules: list[ScheduleConfig] | None = None) -> int:
        """Generate and install all plists. Returns count of successfully installed."""
        paths = self.generate_all(schedules)
        return sum(1 for p in paths if self.install_plist(p))

    def uninstall_plist(self, label: str) -> bool:
        """Unload and remove a plist from LaunchAgents."""
        target = LAUNCHD_DIR / f"{label}.plist"
        if not target.exists():
            return False

        subprocess.run(["launchctl", "unload", str(target)], capture_output=True)
        target.unlink()
        logger.info("Uninstalled: %s", label)
        return True

    def uninstall_all(self) -> int:
        """Uninstall all ecosystem plists."""
        count = 0
        for plist in LAUNCHD_DIR.glob(f"{PLIST_PREFIX}.*.plist"):
            label = plist.stem
            if self.uninstall_plist(label):
                count += 1
        return count

    def check_missed_runs(self, max_age_hours: int = 26) -> list[str]:
        """Check for tasks that should have run but didn't (e.g. after sleep).

        Looks at log files to find tasks whose last run is older than
        expected. Returns list of task names that need to be re-run.

        Args:
            max_age_hours: Tasks not run within this many hours are considered missed.

        Returns:
            List of task names that missed their schedule.
        """
        from ecosystem.agents.runner import AgentRunner

        runner = AgentRunner()
        missed: list[str] = []
        cutoff = datetime.now() - timedelta(hours=max_age_hours)

        for config in DEFAULT_SCHEDULES:
            last_run = runner.get_last_run(config.task_name)
            if last_run is None or last_run.started_at < cutoff:
                missed.append(config.task_name)
                logger.warning("Missed run detected: %s (last: %s)", config.task_name, last_run)

        return missed

    def recover_missed_runs(self) -> list[str]:
        """Run any tasks that missed their schedule.

        Returns:
            List of task names that were re-run.
        """
        from ecosystem.agents.runner import AgentRunner

        missed = self.check_missed_runs()
        if not missed:
            logger.info("No missed runs to recover")
            return []

        runner = AgentRunner()
        recovered = []
        for task_name in missed:
            logger.info("Recovering missed run: %s", task_name)
            result = runner.run_task(task_name)
            if result.status.value in ("success", "failed"):
                recovered.append(task_name)

        return recovered

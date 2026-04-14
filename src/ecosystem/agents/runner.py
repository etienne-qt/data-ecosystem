"""Agent runner — picks up tasks from Asana or CLI, dispatches to handlers.

Usage:
    from ecosystem.agents.runner import AgentRunner
    runner = AgentRunner()
    runner.run_task("nightly_sync")          # Run by name
    runner.run_from_asana()                  # Poll Asana for assigned tasks
"""

from __future__ import annotations

import logging
import traceback
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Callable

from ecosystem.config import settings

logger = logging.getLogger(__name__)


class TaskStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    SUCCESS = "success"
    FAILED = "failed"
    SKIPPED = "skipped"


@dataclass
class TaskResult:
    """Result of running an agent task."""

    task_name: str
    status: TaskStatus
    started_at: datetime
    finished_at: datetime | None = None
    message: str = ""
    error: str = ""
    details: dict[str, Any] = field(default_factory=dict)

    @property
    def duration_seconds(self) -> float:
        if self.finished_at and self.started_at:
            return (self.finished_at - self.started_at).total_seconds()
        return 0.0


# Type for task handler functions
TaskHandler = Callable[..., TaskResult]

# Global task registry
_TASK_REGISTRY: dict[str, TaskHandler] = {}


def register_task(name: str) -> Callable[[TaskHandler], TaskHandler]:
    """Decorator to register a task handler.

    Usage:
        @register_task("nightly_sync")
        def handle_nightly_sync(**kwargs) -> TaskResult:
            ...
    """
    def decorator(fn: TaskHandler) -> TaskHandler:
        _TASK_REGISTRY[name] = fn
        return fn
    return decorator


def get_registered_tasks() -> list[str]:
    """List all registered task names."""
    return sorted(_TASK_REGISTRY.keys())


class AgentRunner:
    """Runs agent tasks by name or from Asana."""

    def __init__(self, logs_dir: str | Path | None = None) -> None:
        self.logs_dir = Path(logs_dir or settings.logs_dir)
        self.logs_dir.mkdir(parents=True, exist_ok=True)
        # Import task modules to trigger registration
        self._ensure_tasks_registered()

    def _ensure_tasks_registered(self) -> None:
        """Import all task modules to populate the registry.

        As of 2026-04-14, only `website_review` is active. The other five
        tasks (nightly_sync, classify_new, match_resolve, report_gen,
        notes_ingest) were never executed and have been moved to
        archive/python-package/agents/tasks/. If you revive one, add it
        back to this import list.
        """
        try:
            from ecosystem.agents.tasks import website_review  # noqa: F401
        except ImportError as e:
            logger.warning("Could not import task modules: %s", e)

    def run_task(self, task_name: str, **kwargs: Any) -> TaskResult:
        """Run a single task by name.

        Args:
            task_name: Registered task name (e.g. "nightly_sync").
            **kwargs: Additional arguments passed to the task handler.

        Returns:
            TaskResult with status and details.
        """
        handler = _TASK_REGISTRY.get(task_name)
        if handler is None:
            available = ", ".join(get_registered_tasks()) or "(none)"
            return TaskResult(
                task_name=task_name,
                status=TaskStatus.FAILED,
                started_at=datetime.now(),
                finished_at=datetime.now(),
                error=f"Unknown task: {task_name}. Available: {available}",
            )

        started = datetime.now()
        logger.info("Starting task: %s", task_name)

        try:
            result = handler(**kwargs)
            result.started_at = started
            result.finished_at = datetime.now()
            logger.info(
                "Task %s completed: %s (%.1fs)",
                task_name, result.status.value, result.duration_seconds,
            )
        except Exception as e:
            result = TaskResult(
                task_name=task_name,
                status=TaskStatus.FAILED,
                started_at=started,
                finished_at=datetime.now(),
                error=str(e),
                details={"traceback": traceback.format_exc()},
            )
            logger.error("Task %s failed: %s", task_name, e)

        self._log_result(result)
        return result

    def run_from_asana(self, tag_filter: str = "agent") -> list[TaskResult]:
        """Poll Asana for tasks tagged for the agent and run them.

        Looks for incomplete tasks in the configured Asana project
        whose name matches a registered task (or has a matching tag).
        After running, posts a comment with the result and optionally
        marks the task complete.

        Args:
            tag_filter: Only process Asana tasks with this tag name.

        Returns:
            List of TaskResult for each task processed.
        """
        from ecosystem.connectors.asana import AsanaClient

        try:
            asana = AsanaClient()
        except Exception as e:
            logger.error("Could not connect to Asana: %s", e)
            return []

        results: list[TaskResult] = []

        try:
            tasks = asana.get_tasks()
        except Exception as e:
            logger.error("Failed to fetch Asana tasks: %s", e)
            return []

        for task in tasks:
            task_name = task.get("name", "").strip().lower().replace(" ", "_")
            tags = [t.get("name", "").lower() for t in task.get("tags", [])]

            # Skip tasks not tagged for the agent
            if tag_filter and tag_filter.lower() not in tags:
                continue

            if task_name not in _TASK_REGISTRY:
                logger.info("Skipping unrecognized Asana task: %s", task.get("name"))
                continue

            # Run the task
            result = self.run_task(task_name)
            results.append(result)

            # Post result as comment
            task_gid = task.get("gid", "")
            if task_gid:
                status_emoji = "+" if result.status == TaskStatus.SUCCESS else "x"
                comment = (
                    f"[{status_emoji}] Agent ran '{task_name}': {result.status.value}\n"
                    f"Duration: {result.duration_seconds:.1f}s\n"
                )
                if result.message:
                    comment += f"Message: {result.message}\n"
                if result.error:
                    comment += f"Error: {result.error}\n"

                try:
                    asana.add_comment(task_gid, comment)
                except Exception as e:
                    logger.error("Failed to post comment to Asana task %s: %s", task_gid, e)

                # Mark complete on success
                if result.status == TaskStatus.SUCCESS:
                    try:
                        asana.complete_task(task_gid)
                    except Exception as e:
                        logger.error("Failed to complete Asana task %s: %s", task_gid, e)

        return results

    def _log_result(self, result: TaskResult) -> None:
        """Append task result to the daily log file."""
        import json

        log_file = self.logs_dir / f"{datetime.now().strftime('%Y-%m-%d')}.jsonl"
        entry = {
            "task": result.task_name,
            "status": result.status.value,
            "started_at": result.started_at.isoformat(),
            "finished_at": result.finished_at.isoformat() if result.finished_at else None,
            "duration_s": result.duration_seconds,
            "message": result.message,
            "error": result.error,
        }
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry) + "\n")

    def get_last_run(self, task_name: str) -> TaskResult | None:
        """Get the most recent result for a task from log files."""
        import json

        # Search log files in reverse chronological order
        log_files = sorted(self.logs_dir.glob("*.jsonl"), reverse=True)
        for log_file in log_files[:30]:  # Look back up to 30 days
            for line in reversed(log_file.read_text(encoding="utf-8").strip().split("\n")):
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    if entry.get("task") == task_name:
                        return TaskResult(
                            task_name=entry["task"],
                            status=TaskStatus(entry["status"]),
                            started_at=datetime.fromisoformat(entry["started_at"]),
                            finished_at=datetime.fromisoformat(entry["finished_at"]) if entry.get("finished_at") else None,
                            message=entry.get("message", ""),
                            error=entry.get("error", ""),
                        )
                except (json.JSONDecodeError, KeyError, ValueError):
                    continue
        return None

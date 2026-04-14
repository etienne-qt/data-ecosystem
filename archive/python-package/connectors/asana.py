"""Asana API client — read tasks, update status, post comments.

Supports two authentication methods:
1. OAuth2 (preferred) — uses client ID/secret with browser flow
2. Personal Access Token (legacy) — uses a static token string

Uses asana v5.x API (asana.ApiClient + resource-specific API classes).
"""

from __future__ import annotations

import logging
from typing import Any

import asana

from ecosystem.config import settings

logger = logging.getLogger(__name__)


class AsanaClient:
    """Wrapper around the Asana Python client for task management."""

    def __init__(
        self,
        access_token: str | None = None,
        workspace_gid: str | None = None,
        project_gid: str | None = None,
    ) -> None:
        token = access_token or self._resolve_token()
        configuration = asana.Configuration()
        configuration.access_token = token
        self._api_client = asana.ApiClient(configuration)
        self.workspace_gid = workspace_gid or settings.asana.workspace_gid
        self.project_gid = project_gid or settings.asana.project_gid

    @staticmethod
    def _resolve_token() -> str:
        """Try OAuth2 token first, fall back to PAT."""
        if settings.asana.client_id and settings.asana.client_secret:
            try:
                from ecosystem.connectors.asana_auth import get_asana_access_token
                return get_asana_access_token(interactive=False)
            except Exception as e:
                logger.debug("Asana OAuth not available: %s", e)

        if settings.asana.access_token:
            return settings.asana.access_token

        raise RuntimeError(
            "No Asana credentials configured. Set ASANA_CLIENT_ID + ASANA_CLIENT_SECRET "
            "in .env and run `eco asana-auth`, or set ASANA_ACCESS_TOKEN."
        )

    def get_tasks(
        self,
        project_gid: str | None = None,
        completed_since: str = "now",
        opt_fields: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        """Get incomplete tasks from a project."""
        gid = project_gid or self.project_gid
        fields = opt_fields or [
            "name",
            "notes",
            "completed",
            "due_on",
            "assignee.name",
            "tags.name",
        ]
        api = asana.TasksApi(self._api_client)
        opts = {
            "completed_since": completed_since,
            "opt_fields": ",".join(fields),
        }
        tasks = list(api.get_tasks_for_project(gid, opts))
        logger.info("Fetched %d tasks from project %s", len(tasks), gid)
        return [_to_dict(t) for t in tasks]

    def get_task(self, task_gid: str) -> dict[str, Any]:
        """Get a single task by GID."""
        api = asana.TasksApi(self._api_client)
        return _to_dict(api.get_task(task_gid, {}))

    def update_task(self, task_gid: str, data: dict[str, Any]) -> dict[str, Any]:
        """Update a task's fields (name, notes, completed, etc.)."""
        api = asana.TasksApi(self._api_client)
        body = {"data": data}
        result = api.update_task(body, task_gid, {})
        logger.info("Updated task %s", task_gid)
        return _to_dict(result)

    def complete_task(self, task_gid: str) -> dict[str, Any]:
        """Mark a task as completed."""
        return self.update_task(task_gid, {"completed": True})

    def add_comment(self, task_gid: str, text: str) -> dict[str, Any]:
        """Add a comment (story) to a task."""
        api = asana.StoriesApi(self._api_client)
        body = {"data": {"text": text}}
        result = api.create_story_for_task(body, task_gid, {})
        logger.info("Added comment to task %s", task_gid)
        return _to_dict(result)

    def create_task(
        self,
        name: str,
        notes: str = "",
        project_gid: str | None = None,
        due_on: str | None = None,
    ) -> dict[str, Any]:
        """Create a new task in the project."""
        gid = project_gid or self.project_gid
        data: dict[str, Any] = {
            "name": name,
            "notes": notes,
            "projects": [gid],
        }
        if due_on:
            data["due_on"] = due_on
        api = asana.TasksApi(self._api_client)
        result = api.create_task({"data": data}, {})
        logger.info("Created task: %s", name)
        return _to_dict(result)


def _to_dict(obj: Any) -> dict[str, Any]:
    """Convert an Asana API response object to a plain dict."""
    if isinstance(obj, dict):
        return obj
    if hasattr(obj, "to_dict"):
        return obj.to_dict()
    return dict(obj)

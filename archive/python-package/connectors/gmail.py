"""Gmail API client — search and read emails.

Usage:
    from ecosystem.connectors.gmail import GmailClient
    gmail = GmailClient()
    results = gmail.search("from:partner@company.com startup")
    message = gmail.get_message(results[0]["id"])
"""

from __future__ import annotations

import base64
import logging
from datetime import datetime
from email.utils import parsedate_to_datetime
from typing import Any

from googleapiclient.discovery import build

from ecosystem.connectors.google_auth import get_google_credentials

logger = logging.getLogger(__name__)

GMAIL_SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]


class GmailClient:
    """Read-only Gmail client for searching and reading emails."""

    def __init__(self, credentials=None) -> None:
        creds = credentials or get_google_credentials(scopes=GMAIL_SCOPES, interactive=False)
        self._service = build("gmail", "v1", credentials=creds)

    def search(
        self,
        query: str,
        max_results: int = 20,
        user_id: str = "me",
    ) -> list[dict[str, Any]]:
        """Search emails using Gmail query syntax.

        Args:
            query: Gmail search query (e.g. "from:alice subject:startup").
            max_results: Maximum number of results to return.
            user_id: Gmail user ID (default "me" for authenticated user).

        Returns:
            List of dicts with id, thread_id, subject, from, date, snippet.
        """
        response = self._service.users().messages().list(
            userId=user_id,
            q=query,
            maxResults=max_results,
        ).execute()

        messages = response.get("messages", [])
        if not messages:
            return []

        results: list[dict[str, Any]] = []
        for msg_stub in messages:
            msg = self._service.users().messages().get(
                userId=user_id,
                id=msg_stub["id"],
                format="metadata",
                metadataHeaders=["Subject", "From", "Date"],
            ).execute()
            results.append(_parse_message_metadata(msg))

        logger.info("Gmail search '%s': %d results", query, len(results))
        return results

    def get_message(
        self,
        message_id: str,
        user_id: str = "me",
    ) -> dict[str, Any]:
        """Get a full message with body text.

        Args:
            message_id: Gmail message ID.
            user_id: Gmail user ID.

        Returns:
            Dict with id, thread_id, subject, from, date, snippet, body.
        """
        msg = self._service.users().messages().get(
            userId=user_id,
            id=message_id,
            format="full",
        ).execute()

        result = _parse_message_metadata(msg)
        result["body"] = _extract_body(msg.get("payload", {}))
        return result

    def get_thread(
        self,
        thread_id: str,
        user_id: str = "me",
    ) -> list[dict[str, Any]]:
        """Get all messages in a thread.

        Args:
            thread_id: Gmail thread ID.
            user_id: Gmail user ID.

        Returns:
            List of message dicts (same format as get_message), ordered chronologically.
        """
        thread = self._service.users().threads().get(
            userId=user_id,
            id=thread_id,
            format="full",
        ).execute()

        messages = []
        for msg in thread.get("messages", []):
            result = _parse_message_metadata(msg)
            result["body"] = _extract_body(msg.get("payload", {}))
            messages.append(result)

        return messages


def _get_header(msg: dict, name: str) -> str:
    """Extract a header value from a Gmail message."""
    headers = msg.get("payload", {}).get("headers", [])
    for h in headers:
        if h.get("name", "").lower() == name.lower():
            return h.get("value", "")
    return ""


def _parse_message_metadata(msg: dict) -> dict[str, Any]:
    """Parse common metadata from a Gmail message."""
    date_str = _get_header(msg, "Date")
    try:
        date = parsedate_to_datetime(date_str) if date_str else None
    except Exception:
        date = None

    return {
        "id": msg.get("id", ""),
        "thread_id": msg.get("threadId", ""),
        "subject": _get_header(msg, "Subject"),
        "from": _get_header(msg, "From"),
        "date": date.isoformat() if date else date_str,
        "snippet": msg.get("snippet", ""),
    }


def _extract_body(payload: dict) -> str:
    """Extract plain text body from a Gmail message payload.

    Walks the MIME tree looking for text/plain parts.
    Falls back to text/html with tag stripping if no plain text found.
    """
    # Direct body (simple messages)
    if payload.get("mimeType") == "text/plain" and payload.get("body", {}).get("data"):
        return _decode_body(payload["body"]["data"])

    # Multipart — walk parts
    parts = payload.get("parts", [])
    plain_text = ""
    html_text = ""

    for part in parts:
        mime = part.get("mimeType", "")
        if mime == "text/plain" and part.get("body", {}).get("data"):
            plain_text += _decode_body(part["body"]["data"])
        elif mime == "text/html" and part.get("body", {}).get("data"):
            html_text += _decode_body(part["body"]["data"])
        elif mime.startswith("multipart/"):
            # Recurse into nested multipart
            nested = _extract_body(part)
            if nested:
                plain_text += nested

    if plain_text:
        return plain_text

    # Fallback: strip HTML tags
    if html_text:
        import re
        return re.sub(r"<[^>]+>", "", html_text).strip()

    return ""


def _decode_body(data: str) -> str:
    """Decode base64url-encoded body data."""
    return base64.urlsafe_b64decode(data).decode("utf-8", errors="replace")

"""Google Docs reader — pull meeting notes from Google Docs/Drive.

Supports two authentication methods:
1. OAuth2 (preferred) — uses shared credentials from google_auth module
2. Service account (legacy) — uses a service account JSON key file
"""

from __future__ import annotations

import logging
from typing import Any

from googleapiclient.discovery import build

from ecosystem.config import settings

logger = logging.getLogger(__name__)

SCOPES = [
    "https://www.googleapis.com/auth/documents.readonly",
    "https://www.googleapis.com/auth/drive.readonly",
]


class GoogleDocsClient:
    """Read Google Docs and list files in Drive folders."""

    def __init__(self, service_account_file: str | None = None, credentials=None) -> None:
        creds = credentials or self._resolve_credentials(service_account_file)
        self._docs_service = build("docs", "v1", credentials=creds)
        self._drive_service = build("drive", "v3", credentials=creds)

    @staticmethod
    def _resolve_credentials(service_account_file: str | None = None):
        """Try OAuth2 first, fall back to service account."""
        # Try OAuth2
        if settings.google.oauth_client_file or settings.google.oauth_token_file:
            try:
                from ecosystem.connectors.google_auth import get_google_credentials
                return get_google_credentials(scopes=SCOPES, interactive=False)
            except Exception as e:
                logger.debug("OAuth2 not available, trying service account: %s", e)

        # Fall back to service account
        sa_file = service_account_file or settings.google.service_account_file
        if sa_file:
            from google.oauth2 import service_account
            return service_account.Credentials.from_service_account_file(sa_file, scopes=SCOPES)

        raise RuntimeError(
            "No Google credentials configured. Set GOOGLE_OAUTH_CLIENT_FILE or "
            "GOOGLE_SERVICE_ACCOUNT_FILE in .env, then run `eco google-auth`."
        )

    def get_document_text(self, document_id: str) -> str:
        """Extract plain text from a Google Doc."""
        doc = self._docs_service.documents().get(documentId=document_id).execute()
        return self._extract_text(doc)

    def get_document_metadata(self, document_id: str) -> dict[str, Any]:
        """Get document title and metadata."""
        doc = self._docs_service.documents().get(documentId=document_id).execute()
        return {
            "id": doc["documentId"],
            "title": doc.get("title", ""),
        }

    def list_files_in_folder(
        self,
        folder_id: str | None = None,
        mime_type: str = "application/vnd.google-apps.document",
    ) -> list[dict[str, str]]:
        """List Google Docs in a Drive folder."""
        fid = folder_id or settings.google.docs_folder_id
        query = f"'{fid}' in parents and mimeType='{mime_type}' and trashed=false"
        results = self._drive_service.files().list(
            q=query,
            fields="files(id, name, modifiedTime)",
            orderBy="modifiedTime desc",
        ).execute()
        return results.get("files", [])

    @staticmethod
    def _extract_text(doc: dict) -> str:
        """Walk the Google Docs JSON structure and extract text."""
        text_parts: list[str] = []
        for element in doc.get("body", {}).get("content", []):
            paragraph = element.get("paragraph")
            if not paragraph:
                continue
            for pe in paragraph.get("elements", []):
                text_run = pe.get("textRun")
                if text_run:
                    text_parts.append(text_run.get("content", ""))
        return "".join(text_parts)

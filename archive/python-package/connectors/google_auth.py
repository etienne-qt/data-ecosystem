"""Google OAuth2 authentication — shared credential management.

Handles OAuth2 token storage, refresh, and interactive browser flow.
Used by all Google connectors (Docs, Drive, Gmail, Calendar).

Usage:
    from ecosystem.connectors.google_auth import get_google_credentials
    creds = get_google_credentials()  # Uses all default scopes
    creds = get_google_credentials(scopes=["https://www.googleapis.com/auth/gmail.readonly"])
"""

from __future__ import annotations

import json
import logging
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

from ecosystem.config import settings

logger = logging.getLogger(__name__)

# All scopes needed across Google connectors.
# The token is authorized for all of these on first auth so we don't
# need to re-authorize when adding a new connector.
ALL_SCOPES = [
    # Docs & Drive (existing)
    "https://www.googleapis.com/auth/documents.readonly",
    "https://www.googleapis.com/auth/drive.readonly",
    # Gmail
    "https://www.googleapis.com/auth/gmail.readonly",
    # Calendar
    "https://www.googleapis.com/auth/calendar.readonly",
]

DEFAULT_TOKEN_PATH = Path.home() / ".config" / "ecosystem" / "google_token.json"


def get_google_credentials(
    scopes: list[str] | None = None,
    client_file: str | None = None,
    token_file: str | Path | None = None,
    interactive: bool = True,
) -> Credentials:
    """Load or create Google OAuth2 credentials.

    Tries in order:
    1. Load existing token from file → refresh if expired
    2. Run interactive browser flow (if interactive=True)
    3. Raise RuntimeError if non-interactive and no valid token

    Args:
        scopes: OAuth2 scopes. Defaults to ALL_SCOPES.
        client_file: Path to OAuth2 client secrets JSON. Defaults to settings.
        token_file: Path to stored token JSON. Defaults to settings or ~/.config/ecosystem/.
        interactive: Whether to launch browser flow if no token exists.

    Returns:
        Valid Google OAuth2 Credentials.

    Raises:
        FileNotFoundError: If client_file doesn't exist.
        RuntimeError: If no valid credentials and interactive=False.
    """
    scopes = scopes or ALL_SCOPES
    client_path = Path(client_file or settings.google.oauth_client_file)
    token_path = Path(token_file or settings.google.oauth_token_file or DEFAULT_TOKEN_PATH)

    creds = _load_token(token_path, scopes)

    if creds and creds.expired and creds.refresh_token:
        logger.info("Refreshing expired Google token")
        creds.refresh(Request())
        _save_token(creds, token_path)
        return creds

    if creds and creds.valid:
        return creds

    # Need new credentials via browser flow
    if not interactive:
        raise RuntimeError(
            "No valid Google credentials found. Run `eco google-auth` to authorize."
        )

    if not client_path.exists():
        raise FileNotFoundError(
            f"OAuth2 client secrets file not found: {client_path}\n"
            "Download it from Google Cloud Console → APIs & Services → Credentials.\n"
            "Set GOOGLE_OAUTH_CLIENT_FILE in .env to the path."
        )

    logger.info("Starting Google OAuth2 browser flow")
    flow = InstalledAppFlow.from_client_secrets_file(str(client_path), scopes)
    creds = flow.run_local_server(port=0)
    _save_token(creds, token_path)
    logger.info("Google credentials saved to %s", token_path)
    return creds


def _load_token(token_path: Path, scopes: list[str]) -> Credentials | None:
    """Load credentials from a stored token file."""
    if not token_path.exists():
        return None

    try:
        creds = Credentials.from_authorized_user_file(str(token_path), scopes)
        return creds
    except Exception as e:
        logger.warning("Could not load token from %s: %s", token_path, e)
        return None


def _save_token(creds: Credentials, token_path: Path) -> None:
    """Save credentials to a JSON file."""
    token_path.parent.mkdir(parents=True, exist_ok=True)
    token_path.write_text(creds.to_json(), encoding="utf-8")

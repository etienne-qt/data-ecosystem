"""Asana OAuth2 authentication — authorization code flow.

Handles OAuth2 token storage, refresh, and interactive browser flow.
Uses a local HTTP server to receive the callback.

Usage:
    from ecosystem.connectors.asana_auth import get_asana_access_token
    token = get_asana_access_token()  # Returns a valid access token string
"""

from __future__ import annotations

import http.server
import json
import logging
import secrets
import threading
import urllib.parse
import webbrowser
from pathlib import Path

import httpx

from ecosystem.config import settings

logger = logging.getLogger(__name__)

ASANA_AUTHORIZE_URL = "https://app.asana.com/-/oauth_authorize"
ASANA_TOKEN_URL = "https://app.asana.com/-/oauth_token"
DEFAULT_TOKEN_PATH = Path.home() / ".config" / "ecosystem" / "asana_token.json"
REDIRECT_PORT = 8345
REDIRECT_URI = f"http://localhost:{REDIRECT_PORT}/callback"


def get_asana_access_token(
    client_id: str | None = None,
    client_secret: str | None = None,
    token_file: str | Path | None = None,
    interactive: bool = True,
) -> str:
    """Get a valid Asana access token.

    Tries in order:
    1. Load existing token from file → refresh if expired
    2. Run interactive browser flow (if interactive=True)
    3. Fall back to PAT from settings (if configured)

    Args:
        client_id: Asana OAuth client ID.
        client_secret: Asana OAuth client secret.
        token_file: Path to stored token JSON.
        interactive: Whether to launch browser flow if no token exists.

    Returns:
        Valid access token string.

    Raises:
        RuntimeError: If no valid token and interactive=False and no PAT.
    """
    cid = client_id or settings.asana.client_id
    csecret = client_secret or settings.asana.client_secret
    token_path = Path(token_file or settings.asana.oauth_token_file or DEFAULT_TOKEN_PATH)

    # Try loading stored OAuth token
    token_data = _load_token(token_path)
    if token_data:
        # Try refresh
        if token_data.get("refresh_token") and cid and csecret:
            try:
                new_data = _refresh_token(cid, csecret, token_data["refresh_token"])
                _save_token(new_data, token_path)
                return new_data["access_token"]
            except Exception as e:
                logger.warning("Token refresh failed: %s", e)
        elif token_data.get("access_token"):
            # No refresh token — might be a PAT stored as token
            return token_data["access_token"]

    # Try interactive browser flow
    if interactive and cid and csecret:
        logger.info("Starting Asana OAuth2 browser flow")
        token_data = _run_auth_flow(cid, csecret)
        _save_token(token_data, token_path)
        return token_data["access_token"]

    # Fall back to PAT
    if settings.asana.access_token:
        return settings.asana.access_token

    raise RuntimeError(
        "No valid Asana credentials found. Either:\n"
        "  - Set ASANA_CLIENT_ID and ASANA_CLIENT_SECRET in .env, then run `eco asana-auth`\n"
        "  - Or set ASANA_ACCESS_TOKEN (Personal Access Token) in .env"
    )


def _run_auth_flow(client_id: str, client_secret: str) -> dict:
    """Run the OAuth2 authorization code flow with a local callback server."""
    state = secrets.token_urlsafe(32)
    auth_code: dict[str, str | None] = {"code": None, "error": None}
    server_ready = threading.Event()

    class CallbackHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            params = urllib.parse.parse_qs(parsed.query)

            received_state = params.get("state", [None])[0]
            if received_state != state:
                auth_code["error"] = "State mismatch — possible CSRF attack"
            elif "error" in params:
                auth_code["error"] = params["error"][0]
            elif "code" in params:
                auth_code["code"] = params["code"][0]
            else:
                auth_code["error"] = "No code in callback"

            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            if auth_code["code"]:
                self.wfile.write(b"<h2>Asana authorized! You can close this tab.</h2>")
            else:
                self.wfile.write(f"<h2>Error: {auth_code['error']}</h2>".encode())

        def log_message(self, format, *args):
            pass  # Suppress HTTP logs

    server = http.server.HTTPServer(("localhost", REDIRECT_PORT), CallbackHandler)
    server.timeout = 120  # 2 minute timeout

    def serve():
        server_ready.set()
        server.handle_request()  # Handle exactly one request

    thread = threading.Thread(target=serve, daemon=True)
    thread.start()
    server_ready.wait()

    # Build authorization URL
    params = {
        "client_id": client_id,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "state": state,
        "scope": "projects:read tasks:read tasks:write attachments:read attachments:write custom_fields:read custom_fields:write",
    }
    auth_url = f"{ASANA_AUTHORIZE_URL}?{urllib.parse.urlencode(params)}"
    webbrowser.open(auth_url)

    thread.join(timeout=130)
    server.server_close()

    if auth_code["error"]:
        raise RuntimeError(f"Asana OAuth failed: {auth_code['error']}")
    if not auth_code["code"]:
        raise RuntimeError("Asana OAuth timed out — no authorization code received")

    # Exchange code for token
    return _exchange_code(client_id, client_secret, auth_code["code"])


def _exchange_code(client_id: str, client_secret: str, code: str) -> dict:
    """Exchange authorization code for access + refresh tokens."""
    response = httpx.post(
        ASANA_TOKEN_URL,
        data={
            "grant_type": "authorization_code",
            "client_id": client_id,
            "client_secret": client_secret,
            "redirect_uri": REDIRECT_URI,
            "code": code,
        },
    )
    response.raise_for_status()
    return response.json()


def _refresh_token(client_id: str, client_secret: str, refresh_token: str) -> dict:
    """Refresh an expired access token."""
    response = httpx.post(
        ASANA_TOKEN_URL,
        data={
            "grant_type": "refresh_token",
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
        },
    )
    response.raise_for_status()
    data = response.json()
    # Preserve refresh token if not returned in response
    if "refresh_token" not in data:
        data["refresh_token"] = refresh_token
    return data


def _load_token(token_path: Path) -> dict | None:
    """Load token data from a JSON file."""
    if not token_path.exists():
        return None
    try:
        return json.loads(token_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as e:
        logger.warning("Could not load Asana token from %s: %s", token_path, e)
        return None


def _save_token(data: dict, token_path: Path) -> None:
    """Save token data to a JSON file."""
    token_path.parent.mkdir(parents=True, exist_ok=True)
    token_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    logger.info("Asana token saved to %s", token_path)

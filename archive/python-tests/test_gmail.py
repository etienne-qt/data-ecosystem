"""Tests for ecosystem.connectors.gmail — parsing helpers (no API calls)."""

from ecosystem.connectors.gmail import _decode_body, _extract_body, _get_header, _parse_message_metadata


def test_get_header():
    msg = {
        "payload": {
            "headers": [
                {"name": "Subject", "value": "Hello World"},
                {"name": "From", "value": "alice@example.com"},
            ]
        }
    }
    assert _get_header(msg, "Subject") == "Hello World"
    assert _get_header(msg, "from") == "alice@example.com"  # case insensitive
    assert _get_header(msg, "Missing") == ""


def test_parse_message_metadata():
    msg = {
        "id": "msg123",
        "threadId": "thread456",
        "snippet": "Preview text...",
        "payload": {
            "headers": [
                {"name": "Subject", "value": "Test Email"},
                {"name": "From", "value": "bob@example.com"},
                {"name": "Date", "value": "Mon, 04 Mar 2026 10:00:00 -0500"},
            ]
        },
    }
    result = _parse_message_metadata(msg)
    assert result["id"] == "msg123"
    assert result["thread_id"] == "thread456"
    assert result["subject"] == "Test Email"
    assert result["from"] == "bob@example.com"
    assert result["snippet"] == "Preview text..."
    assert "2026-03-04" in result["date"]


def test_parse_message_metadata_bad_date():
    msg = {
        "id": "x",
        "threadId": "y",
        "snippet": "",
        "payload": {"headers": [{"name": "Date", "value": "not-a-date"}]},
    }
    result = _parse_message_metadata(msg)
    assert result["date"] == "not-a-date"  # falls back to raw string


def test_decode_body():
    import base64
    data = base64.urlsafe_b64encode(b"Hello, world!").decode()
    assert _decode_body(data) == "Hello, world!"


def test_extract_body_plain():
    payload = {
        "mimeType": "text/plain",
        "body": {"data": "SGVsbG8="},  # base64url("Hello")
    }
    assert _extract_body(payload) == "Hello"


def test_extract_body_multipart():
    import base64
    plain_data = base64.urlsafe_b64encode(b"Plain text body").decode()
    payload = {
        "mimeType": "multipart/alternative",
        "parts": [
            {"mimeType": "text/plain", "body": {"data": plain_data}},
            {"mimeType": "text/html", "body": {"data": "SFRNTA=="}},
        ],
    }
    assert _extract_body(payload) == "Plain text body"


def test_extract_body_html_fallback():
    import base64
    html_data = base64.urlsafe_b64encode(b"<p>Hello</p>").decode()
    payload = {
        "mimeType": "multipart/alternative",
        "parts": [
            {"mimeType": "text/html", "body": {"data": html_data}},
        ],
    }
    assert "Hello" in _extract_body(payload)
    assert "<p>" not in _extract_body(payload)


def test_extract_body_empty():
    assert _extract_body({}) == ""

"""Tests for ecosystem.connectors.calendar — parsing helpers (no API calls)."""

from ecosystem.connectors.calendar import _parse_event


def test_parse_event_basic():
    event = {
        "id": "evt123",
        "summary": "Team Standup",
        "start": {"dateTime": "2026-03-04T09:00:00-05:00"},
        "end": {"dateTime": "2026-03-04T09:30:00-05:00"},
        "location": "Room A",
        "description": "Daily standup meeting",
        "htmlLink": "https://calendar.google.com/event/evt123",
        "status": "confirmed",
        "organizer": {"email": "alice@example.com"},
        "attendees": [
            {"email": "alice@example.com", "displayName": "Alice", "responseStatus": "accepted", "organizer": True},
            {"email": "bob@example.com", "displayName": "Bob", "responseStatus": "tentative"},
        ],
    }
    result = _parse_event(event)
    assert result["id"] == "evt123"
    assert result["summary"] == "Team Standup"
    assert result["start"] == "2026-03-04T09:00:00-05:00"
    assert result["location"] == "Room A"
    assert result["organizer"] == "alice@example.com"
    assert len(result["attendees"]) == 2
    assert result["attendees"][0]["name"] == "Alice"
    assert result["attendees"][1]["response"] == "tentative"


def test_parse_event_all_day():
    """All-day events use 'date' instead of 'dateTime'."""
    event = {
        "id": "allday1",
        "summary": "Company Holiday",
        "start": {"date": "2026-12-25"},
        "end": {"date": "2026-12-26"},
    }
    result = _parse_event(event)
    assert result["start"] == "2026-12-25"
    assert result["end"] == "2026-12-26"


def test_parse_event_no_attendees():
    event = {
        "id": "solo1",
        "summary": "Focus Time",
        "start": {"dateTime": "2026-03-04T14:00:00Z"},
        "end": {"dateTime": "2026-03-04T16:00:00Z"},
    }
    result = _parse_event(event)
    assert result["attendees"] == []
    assert result["location"] == ""
    assert result["description"] == ""


def test_parse_event_minimal():
    """Event with almost no fields should not crash."""
    result = _parse_event({})
    assert result["id"] == ""
    assert result["summary"] == ""
    assert result["attendees"] == []

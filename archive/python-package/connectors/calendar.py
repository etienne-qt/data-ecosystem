"""Google Calendar API client — list events and calendars.

Usage:
    from ecosystem.connectors.calendar import GoogleCalendarClient
    cal = GoogleCalendarClient()
    events = cal.get_events(time_min="2026-03-01T00:00:00Z", time_max="2026-03-31T23:59:59Z")
    calendars = cal.list_calendars()
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from googleapiclient.discovery import build

from ecosystem.connectors.google_auth import get_google_credentials

logger = logging.getLogger(__name__)

CALENDAR_SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]


class GoogleCalendarClient:
    """Read-only Google Calendar client."""

    def __init__(self, credentials=None) -> None:
        creds = credentials or get_google_credentials(scopes=CALENDAR_SCOPES, interactive=False)
        self._service = build("calendar", "v3", credentials=creds)

    def list_calendars(self) -> list[dict[str, Any]]:
        """List all calendars the user has access to.

        Returns:
            List of dicts with id, summary (name), primary, time_zone.
        """
        result = self._service.calendarList().list().execute()
        calendars = []
        for item in result.get("items", []):
            calendars.append({
                "id": item["id"],
                "summary": item.get("summary", ""),
                "primary": item.get("primary", False),
                "time_zone": item.get("timeZone", ""),
            })
        logger.info("Found %d calendars", len(calendars))
        return calendars

    def get_events(
        self,
        time_min: str | None = None,
        time_max: str | None = None,
        calendar_id: str = "primary",
        max_results: int = 50,
        query: str | None = None,
    ) -> list[dict[str, Any]]:
        """Get events from a calendar within a time range.

        Args:
            time_min: Start of time range (RFC3339, e.g. "2026-03-01T00:00:00Z").
                Defaults to now.
            time_max: End of time range (RFC3339). Defaults to 7 days from now.
            calendar_id: Calendar ID. "primary" for the user's main calendar.
            max_results: Maximum number of events.
            query: Free-text search query to filter events.

        Returns:
            List of event dicts with id, summary, start, end, attendees, location, description.
        """
        now = datetime.now(timezone.utc)
        t_min = time_min or now.isoformat()
        t_max = time_max or (now + timedelta(days=7)).isoformat()

        kwargs: dict[str, Any] = {
            "calendarId": calendar_id,
            "timeMin": t_min,
            "timeMax": t_max,
            "maxResults": max_results,
            "singleEvents": True,
            "orderBy": "startTime",
        }
        if query:
            kwargs["q"] = query

        result = self._service.events().list(**kwargs).execute()
        events = [_parse_event(e) for e in result.get("items", [])]
        logger.info("Found %d events in %s", len(events), calendar_id)
        return events

    def get_event(
        self,
        event_id: str,
        calendar_id: str = "primary",
    ) -> dict[str, Any]:
        """Get a single event by ID.

        Args:
            event_id: The event ID.
            calendar_id: Calendar ID.

        Returns:
            Event dict with id, summary, start, end, attendees, location, description.
        """
        event = self._service.events().get(
            calendarId=calendar_id,
            eventId=event_id,
        ).execute()
        return _parse_event(event)

    def get_upcoming_meetings(
        self,
        days: int = 7,
        calendar_id: str = "primary",
    ) -> list[dict[str, Any]]:
        """Convenience: get meetings (events with attendees) in the next N days."""
        now = datetime.now(timezone.utc)
        events = self.get_events(
            time_min=now.isoformat(),
            time_max=(now + timedelta(days=days)).isoformat(),
            calendar_id=calendar_id,
            max_results=100,
        )
        # Filter to events that have attendees (i.e. actual meetings)
        return [e for e in events if e.get("attendees")]


def _parse_event(event: dict) -> dict[str, Any]:
    """Parse a Google Calendar event into a clean dict."""
    start = event.get("start", {})
    end = event.get("end", {})

    attendees = []
    for a in event.get("attendees", []):
        attendees.append({
            "email": a.get("email", ""),
            "name": a.get("displayName", ""),
            "response": a.get("responseStatus", ""),
            "organizer": a.get("organizer", False),
        })

    return {
        "id": event.get("id", ""),
        "summary": event.get("summary", ""),
        "start": start.get("dateTime") or start.get("date", ""),
        "end": end.get("dateTime") or end.get("date", ""),
        "location": event.get("location", ""),
        "description": event.get("description", ""),
        "attendees": attendees,
        "html_link": event.get("htmlLink", ""),
        "status": event.get("status", ""),
        "organizer": event.get("organizer", {}).get("email", ""),
    }

"""Python ports of Snowflake UDFs for field normalization."""

from __future__ import annotations

import re
import unicodedata
from urllib.parse import urlparse


def _accent_fold(s: str) -> str:
    """Remove accents/diacritics and return ASCII lowercase."""
    return (
        unicodedata.normalize("NFKD", s)
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )


def norm_domain(url: str | None) -> str | None:
    """Extract bare domain from a URL: strip scheme, www, path."""
    if not url or not isinstance(url, str):
        return None
    s = url.strip()
    if not s:
        return None
    # Remove scheme
    s = re.sub(r"^https?://", "", s, flags=re.IGNORECASE)
    # Remove userinfo
    s = re.sub(r"^[^@]+@", "", s)
    # Take hostname only (before /, ?, #, :)
    hostname = re.split(r"[/?#:]", s)[0].lower().strip()
    # Strip leading www.
    hostname = re.sub(r"^www\.", "", hostname)
    if not hostname or "." not in hostname:
        return None
    return hostname


def norm_linkedin(url: str | None) -> str | None:
    """Extract LinkedIn company slug from a URL."""
    if not url or not isinstance(url, str):
        return None
    s = url.strip().rstrip("/")
    if not s:
        return None
    m = re.search(r"linkedin\.com/company/([^/?#]+)", s, re.IGNORECASE)
    if m:
        return m.group(1).lower()
    return None


def norm_neq(s: str | None) -> str | None:
    """Validate and normalize a 10-digit Quebec enterprise number (NEQ)."""
    if not s or not isinstance(s, str):
        return None
    digits = re.sub(r"\D", "", s.strip())
    if len(digits) == 10:
        return digits
    return None


def clean_city_key(city: str | None) -> str | None:
    """Accent-fold, uppercase, keep only alphanumeric chars."""
    if not city or not isinstance(city, str):
        return None
    s = city.strip()
    if not s:
        return None
    folded = _accent_fold(s)
    key = re.sub(r"[^a-z0-9]", "", folded).upper()
    return key if key else None


def normalize_dealroom_url(url: str | None) -> str | None:
    """Lowercase, strip query string and trailing slash."""
    if not url or not isinstance(url, str):
        return None
    s = url.strip()
    if not s:
        return None
    s = s.lower().split("?")[0].rstrip("/")
    return s if s else None


def norm_name(s: str | None) -> str | None:
    """Lowercase + accent-fold a company name."""
    if not s or not isinstance(s, str):
        return None
    val = s.strip()
    if not val:
        return None
    return _accent_fold(val)


def build_match_text(
    name: str | None,
    tagline: str | None,
    description: str | None,
    industries: str | None,
    tags: str | None,
    technologies: str | None,
) -> str:
    """Concatenate text fields into a single accent-folded, lowercased string for keyword matching."""
    parts = []
    for val in (name, tagline, description, industries, tags, technologies):
        if val and isinstance(val, str) and val.strip():
            parts.append(val.strip())
    text = " ".join(parts)
    return _accent_fold(text)

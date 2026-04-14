"""Tests for ecosystem.processing.website_checker."""

from ecosystem.processing.website_checker import (
    FetchResult,
    WebsiteCheckResult,
    _canonicalize_url,
    _discover_candidate_pages,
    _extract_text,
    _extract_title_and_headings,
    _hash_url,
    _normalize_text,
    _truncate,
)


def test_normalize_text():
    assert _normalize_text("  hello   world  ") == "hello world"
    assert _normalize_text("") == ""


def test_truncate():
    assert _truncate("short", 100) == "short"
    assert _truncate("a" * 50, 10) == "aaaaaaa..."
    assert _truncate("", 10) == ""
    assert _truncate(None, 10) == ""


def test_hash_url():
    h = _hash_url("https://example.com")
    assert len(h) == 64  # SHA256 hex


def test_canonicalize_url():
    assert _canonicalize_url("https://WWW.Example.COM/path?q=1#frag") == "https://www.example.com/path"
    assert _canonicalize_url("http://example.com") == "http://example.com/"


def test_extract_text_html():
    html = "<html><body><p>Hello world</p></body></html>"
    text = _extract_text(html)
    assert "Hello world" in text


def test_extract_title_and_headings():
    html = "<html><head><title>My Title</title></head><body><h1>Heading 1</h1><h2>Heading 2</h2></body></html>"
    title, headings = _extract_title_and_headings(html)
    assert title == "My Title"
    assert "Heading 1" in headings
    assert "Heading 2" in headings


def test_discover_candidate_pages():
    homepage_html = """
    <html><body>
        <a href="/pricing">Pricing</a>
        <a href="/about">About</a>
        <a href="/product">Product</a>
        <a href="https://external.com/page">External</a>
        <a href="mailto:info@example.com">Email</a>
    </body></html>
    """
    pages = _discover_candidate_pages(
        "https://example.com",
        homepage_html,
        max_pages=5,
    )
    # Should include homepage + same-domain links, excluding external/mailto
    assert pages[0] == "https://example.com/"
    urls_str = " ".join(pages)
    assert "pricing" in urls_str
    assert "about" in urls_str
    assert "product" in urls_str
    assert "external.com" not in urls_str


def test_discover_pages_priority_ordering():
    """Pages matching priority list should come first."""
    homepage_html = """
    <html><body>
        <a href="/zzz">ZZZ</a>
        <a href="/pricing">Pricing</a>
        <a href="/about">About</a>
    </body></html>
    """
    pages = _discover_candidate_pages(
        "https://example.com",
        homepage_html,
        max_pages=10,
    )
    # After homepage, pricing should come before about, and both before zzz
    non_home = pages[1:]
    pricing_idx = next(i for i, u in enumerate(non_home) if "pricing" in u)
    about_idx = next(i for i, u in enumerate(non_home) if "about" in u)
    zzz_idx = next(i for i, u in enumerate(non_home) if "zzz" in u)
    assert pricing_idx < about_idx
    assert about_idx < zzz_idx


def test_website_check_result_defaults():
    r = WebsiteCheckResult(url="https://example.com", is_alive=True, status_code=200)
    assert r.pages == []
    assert r.error == ""
    assert r.redirect_url == ""

"""Website validation — check if company URLs are alive, crawl pages, extract text.

Consolidated from ~/test_startup_sifter/ (fetcher, crawler, extractor, utils).

Usage:
    from ecosystem.processing.website_checker import WebsiteChecker
    checker = WebsiteChecker()
    result = checker.check("https://example.com")
    batch_results = checker.check_batch(urls)
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from urllib.parse import urljoin, urlparse, urlunparse

import httpx
from bs4 import BeautifulSoup
from tenacity import Retrying, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

WHITESPACE_RE = re.compile(r"\s+")

# Domain registrar / parking page domains — redirect to these means website is inactive
PARKING_DOMAINS = {
    "godaddy.com", "www.godaddy.com", "parking.godaddy.com",
    "namecheap.com", "www.namecheap.com",
    "sedoparking.com", "www.sedoparking.com",
    "hugedomains.com", "www.hugedomains.com",
    "dan.com", "www.dan.com",
    "afternic.com", "www.afternic.com",
    "bodis.com", "www.bodis.com",
    "parkingcrew.net", "www.parkingcrew.net",
    "above.com", "www.above.com",
    "domainmarket.com", "www.domainmarket.com",
    "register.com", "www.register.com",
    "networksolutions.com", "www.networksolutions.com",
    "name.com", "www.name.com",
    "dynadot.com", "www.dynadot.com",
    "wix.com", "www.wix.com",  # only when it's the parking page, not user sites
    "squarespace.com", "www.squarespace.com",  # only the main domain
}

# Text patterns that indicate a parked / for-sale domain
PARKING_TEXT_PATTERNS = re.compile(
    r"(?:this domain (?:is|may be) for sale"
    r"|buy this domain"
    r"|domain has expired"
    r"|parked free"
    r"|this page is parked"
    r"|domain is pending renewal"
    r"|this website is for sale"
    r"|get this domain"
    r"|make an offer on this domain"
    r"|domain parking"
    r"|coming soon.*godaddy"
    r"|this site can.t be reached)",
    re.IGNORECASE,
)

# Priority paths for page discovery (ordered by importance)
DEFAULT_PAGE_PRIORITY = [
    "pricing", "product", "platform", "solutions", "features",
    "docs", "developers", "api", "about", "careers",
]


# ============================================================
# Data classes
# ============================================================

@dataclass
class FetchResult:
    """Result of fetching a single URL."""

    url: str
    status_code: int
    html: str = ""
    content_type: str = ""
    from_cache: bool = False
    error: str = ""


@dataclass
class PageContent:
    """Extracted content from a web page."""

    url: str
    title: str = ""
    headings: str = ""
    text: str = ""
    snippet: str = ""


@dataclass
class WebsiteCheckResult:
    """Result of checking a company website."""

    url: str
    is_alive: bool
    status_code: int
    redirect_url: str = ""
    is_parked: bool = False
    pages_crawled: int = 0
    pages: list[PageContent] = field(default_factory=list)
    error: str = ""


# ============================================================
# Text utilities
# ============================================================

def _normalize_text(text: str) -> str:
    if not text:
        return ""
    return WHITESPACE_RE.sub(" ", text).strip()


def _truncate(text: str, max_len: int) -> str:
    if not text or len(text) <= max_len:
        return text or ""
    return text[:max_len - 3] + "..."


def _hash_url(url: str) -> str:
    return hashlib.sha256(url.encode("utf-8")).hexdigest()


def _canonicalize_url(url: str) -> str:
    parts = urlparse(url)
    scheme = parts.scheme or "http"
    netloc = parts.netloc.lower()
    path = parts.path or "/"
    return urlunparse((scheme, netloc, path, "", "", ""))


# ============================================================
# Fetch cache
# ============================================================

class _FetchCache:
    def __init__(self, cache_dir: Path) -> None:
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)

    def get(self, url: str) -> dict | None:
        path = self.cache_dir / f"{_hash_url(url)}.json"
        if not path.exists():
            return None
        try:
            return json.loads(path.read_text())
        except Exception:
            return None

    def set(self, url: str, data: dict) -> None:
        path = self.cache_dir / f"{_hash_url(url)}.json"
        path.write_text(json.dumps(data))


# ============================================================
# Text extraction
# ============================================================

def _extract_text(html: str) -> str:
    """Extract main text from HTML using trafilatura with BS4 fallback."""
    if not html:
        return ""
    try:
        import trafilatura

        text = trafilatura.extract(html, include_comments=False, include_tables=False)
        if text:
            return _normalize_text(text)
    except Exception:
        pass
    soup = BeautifulSoup(html, "html.parser")
    return _normalize_text(soup.get_text(" "))


def _extract_title_and_headings(html: str) -> tuple[str, str]:
    """Extract title tag and h1/h2/h3 tags from HTML."""
    if not html:
        return "", ""
    soup = BeautifulSoup(html, "html.parser")
    title = _normalize_text(soup.title.get_text(" ") if soup.title else "")
    headings = [
        _normalize_text(tag.get_text(" "))
        for tag in soup.find_all(["h1", "h2", "h3"])
    ]
    return title, _normalize_text(" ".join(h for h in headings if h))


# ============================================================
# Page discovery (crawler)
# ============================================================

def _discover_candidate_pages(
    homepage_url: str,
    homepage_html: str,
    max_pages: int = 8,
    path_priority: list[str] | None = None,
) -> list[str]:
    """Discover candidate pages on a website by crawling links from the homepage."""
    if not homepage_url:
        return []

    priority = path_priority or DEFAULT_PAGE_PRIORITY
    parsed_home = urlparse(homepage_url)
    base = f"{parsed_home.scheme}://{parsed_home.netloc}"
    homepage_canon = _canonicalize_url(homepage_url)

    selected = [homepage_canon]
    seen = {homepage_canon}

    if not homepage_html:
        return selected

    soup = BeautifulSoup(homepage_html, "html.parser")
    candidates: dict[str, tuple[int, int]] = {}

    for link in soup.find_all("a", href=True):
        href = link.get("href")
        if not href or href.startswith(("mailto:", "tel:", "#")):
            continue
        full = urljoin(base, href)
        parsed = urlparse(full)
        if parsed.scheme not in {"http", "https"} or parsed.netloc != parsed_home.netloc:
            continue
        canon = _canonicalize_url(full)
        if canon in seen:
            continue
        path = parsed.path.lower()
        prio = len(priority) + 1
        for idx, token in enumerate(priority):
            if token in path:
                prio = idx
                break
        candidates[canon] = (prio, len(path))

    for url, _ in sorted(candidates.items(), key=lambda x: x[1]):
        selected.append(url)
        seen.add(url)
        if len(selected) >= max_pages:
            break

    return selected


# ============================================================
# Main checker
# ============================================================

class WebsiteChecker:
    """Check website availability, crawl pages, and extract content."""

    def __init__(
        self,
        cache_dir: str | Path | None = None,
        timeout: float = 10.0,
        retries: int = 2,
        use_cache: bool = True,
        max_pages: int = 8,
        max_chars_per_page: int = 3000,
        user_agent: str = "ecosystem-checker/0.1",
    ) -> None:
        self.timeout = timeout
        self.retries = retries
        self.use_cache = use_cache
        self.max_pages = max_pages
        self.max_chars_per_page = max_chars_per_page
        self._cache = _FetchCache(Path(cache_dir)) if cache_dir else None
        self._client = httpx.Client(
            timeout=timeout,
            follow_redirects=True,
            headers={"User-Agent": user_agent},
        )

    def close(self) -> None:
        self._client.close()

    def __enter__(self) -> WebsiteChecker:
        return self

    def __exit__(self, *args: Any) -> None:
        self.close()

    def _fetch(self, url: str) -> FetchResult:
        """Fetch a single URL with caching and retries."""
        if self._cache and self.use_cache:
            cached = self._cache.get(url)
            if cached:
                return FetchResult(
                    url=cached.get("url", url),
                    status_code=cached.get("status_code", 0),
                    html=cached.get("html", ""),
                    content_type=cached.get("content_type", ""),
                    from_cache=True,
                )

        try:
            retrying = Retrying(
                stop=stop_after_attempt(max(1, self.retries + 1)),
                wait=wait_exponential(multiplier=1, min=1, max=6),
                retry=retry_if_exception_type(httpx.HTTPError),
                reraise=True,
            )
            result = None
            for attempt in retrying:
                with attempt:
                    resp = self._client.get(url)
                    result = FetchResult(
                        url=str(resp.url),
                        status_code=resp.status_code,
                        html=resp.text or "",
                        content_type=resp.headers.get("content-type", ""),
                    )
        except Exception as e:
            return FetchResult(url=url, status_code=0, error=str(e))

        if result is None:
            return FetchResult(url=url, status_code=0, error="No response")

        if self._cache and self.use_cache:
            self._cache.set(url, {
                "url": result.url,
                "status_code": result.status_code,
                "html": result.html,
                "content_type": result.content_type,
                "fetched_at": int(time.time()),
            })

        return result

    def check(self, url: str, crawl: bool = False) -> WebsiteCheckResult:
        """Check a single website URL.

        Args:
            url: The website URL to check.
            crawl: If True, discover and crawl sub-pages.

        Returns:
            WebsiteCheckResult with status and optionally extracted content.
        """
        if not url or not url.strip():
            return WebsiteCheckResult(url=url or "", is_alive=False, status_code=0, error="Empty URL")

        # Ensure URL has scheme
        clean_url = url.strip()
        if not clean_url.startswith(("http://", "https://")):
            clean_url = f"https://{clean_url}"

        homepage = self._fetch(clean_url)

        if homepage.error or homepage.status_code >= 400:
            return WebsiteCheckResult(
                url=clean_url,
                is_alive=False,
                status_code=homepage.status_code,
                error=homepage.error or f"HTTP {homepage.status_code}",
            )

        redirect_url = homepage.url if homepage.url != clean_url else ""

        # Detect parking / domain-for-sale pages
        is_parked = False
        if redirect_url:
            redirect_host = urlparse(redirect_url).netloc.lower()
            if redirect_host in PARKING_DOMAINS:
                is_parked = True
        if not is_parked and homepage.html:
            # Check first 5000 chars for parking text (fast)
            if PARKING_TEXT_PATTERNS.search(homepage.html[:5000]):
                is_parked = True

        if is_parked:
            return WebsiteCheckResult(
                url=clean_url,
                is_alive=False,
                is_parked=True,
                status_code=homepage.status_code,
                redirect_url=redirect_url,
                error="Parked/for-sale domain",
            )

        result = WebsiteCheckResult(
            url=clean_url,
            is_alive=True,
            status_code=homepage.status_code,
            redirect_url=redirect_url,
        )

        if not crawl:
            return result

        # Discover and crawl pages
        page_urls = _discover_candidate_pages(
            homepage.url, homepage.html, self.max_pages
        )
        result.pages_crawled = len(page_urls)

        for page_url in page_urls:
            if page_url == homepage.url or page_url == clean_url:
                html = homepage.html
            else:
                fetch = self._fetch(page_url)
                if fetch.error or fetch.status_code >= 400:
                    continue
                html = fetch.html

            text = _extract_text(html)
            title, headings = _extract_title_and_headings(html)
            snippet = _truncate(f"{headings} {text}".strip(), self.max_chars_per_page)

            result.pages.append(PageContent(
                url=page_url,
                title=title,
                headings=headings,
                text=text[:self.max_chars_per_page],
                snippet=snippet,
            ))

        return result

    def check_batch(
        self,
        urls: list[str],
        crawl: bool = False,
        max_workers: int = 10,
    ) -> list[WebsiteCheckResult]:
        """Check multiple URLs concurrently.

        Args:
            urls: List of website URLs to check.
            crawl: If True, discover and crawl sub-pages for each.
            max_workers: Maximum concurrent threads.

        Returns:
            List of WebsiteCheckResult in the same order as input urls.
        """
        results: dict[int, WebsiteCheckResult] = {}

        with ThreadPoolExecutor(max_workers=max_workers) as pool:
            futures = {
                pool.submit(self.check, url, crawl): idx
                for idx, url in enumerate(urls)
            }
            for future in as_completed(futures):
                idx = futures[future]
                try:
                    results[idx] = future.result()
                except Exception as e:
                    results[idx] = WebsiteCheckResult(
                        url=urls[idx], is_alive=False, status_code=0, error=str(e)
                    )

        return [results[i] for i in range(len(urls))]

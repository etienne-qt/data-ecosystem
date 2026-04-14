"""
Dealroom → Website validity checks (HTTP + parked-domain detection)

What this script does
---------------------
1) Reads candidate company websites from Snowflake (Dealroom SILVER tables).
2) Checks a limited batch incrementally:
   - only companies never checked or checked > N days ago
3) Performs an HTTP GET with redirects and short timeouts.
4) Classifies the website:
   - valid    (reachable, not parked)
   - invalid  (404/410/etc.)
   - parked   (domain-for-sale / registrar landing page)
   - error    (dns/ssl/timeout)
5) Appends results into BRONZE.DRM_WEBSITE_CHECKS_BRONZE

Why BRONZE?
-----------
This is operationally derived data, typed and debuggable, used by SILVER rules.

Prereqs
-------
pip install snowflake-connector-python pandas requests

Auth
----
Uses standard env vars:
  SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD
  SNOWFLAKE_WAREHOUSE, SNOWFLAKE_DATABASE, SNOWFLAKE_SCHEMA (optional)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import time
from dataclasses import dataclass
from typing import Any, Dict, Optional, Tuple
from urllib.parse import urlparse

import pandas as pd
import requests
import snowflake.connector
from concurrent.futures import ThreadPoolExecutor, as_completed
from snowflake.connector.pandas_tools import write_pandas


# -----------------------------
# Parked-domain heuristics
# -----------------------------
PARKED_DOMAIN_HOSTS = {
    "sedoparking.com",
    "dan.com",
    "undeveloped.com",
    "hugedomains.com",
    "namebright.com",
    "bodis.com",
    "parkingcrew.net",
    "afternic.com",
    "domainmarket.com",
    "godaddy.com",
    "namecheap.com",
    "google.com",  # sometimes safe browsing interstitials; treat carefully via content patterns
}

PARKED_TEXT_PATTERNS = [
    r"domain (is )?for sale",
    r"buy this domain",
    r"this domain is parked",
    r"parking page",
    r"register this domain",
    r"make an offer",
    r"inquire about this domain",
    r"the domain .* may be for sale",
]


def normalize_url(url_or_domain: str) -> str:
    """Ensure a usable URL; if only a domain is provided, default to https://."""
    s = (url_or_domain or "").strip()
    if not s:
        return s
    if not re.match(r"^https?://", s, re.IGNORECASE):
        s = "https://" + s
    return s


def extract_domain(url: str) -> str:
    """Extract the hostname without 'www.'."""
    try:
        host = urlparse(url).netloc.lower()
        host = host.split("@")[-1]  # remove basic auth if present
        if host.startswith("www."):
            host = host[4:]
        return host
    except Exception:
        return ""


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="ignore")).hexdigest()


def is_parked_page(final_domain: str, html: str) -> Tuple[bool, Optional[str]]:
    """
    Detect common parked-domain / domain-for-sale pages.
    We use two signals:
      - known parking hostnames
      - content patterns in HTML
    """
    d = (final_domain or "").lower()
    if any(d == h or d.endswith("." + h) for h in PARKED_DOMAIN_HOSTS):
        return True, f"final_domain_matches_parker:{d}"

    low = (html or "").lower()
    for pat in PARKED_TEXT_PATTERNS:
        if re.search(pat, low):
            return True, f"html_pattern:{pat}"
    return False, None


@dataclass
class CheckResult:
    company_id: str
    checked_at: str
    input_url: str
    input_domain: str
    final_url: Optional[str]
    final_domain: Optional[str]
    http_status: Optional[int]
    error_type: Optional[str]
    error_message: Optional[str]
    response_time_ms: Optional[int]
    num_redirects: Optional[int]
    is_https: Optional[bool]
    is_valid: bool
    is_parked: bool
    parked_reason: Optional[str]
    content_sha256: Optional[str]
    raw_result: Dict[str, Any]


def check_website(company_id: str, website: str, timeout_s: float = 12.0) -> CheckResult:
    """
    Perform an HTTP GET with redirects. If HTTPS fails due to SSL, fallback to HTTP.
    Only read a limited amount of HTML to keep things fast and polite.
    """
    checked_at = time.strftime("%Y-%m-%d %H:%M:%S")
    input_url = normalize_url(website)
    input_domain = extract_domain(input_url)

    session = requests.Session()
    headers = {
        "User-Agent": "QC-Startup-Directory-Bot/1.0 (+https://example.org)",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    }

    t0 = time.time()
    final_url = None
    final_domain = None
    http_status = None
    error_type = None
    error_message = None
    num_redirects = None
    is_https = None
    is_valid = False
    is_parked = False
    parked_reason = None
    content_hash = None
    html_snippet = ""

    def do_get(url: str) -> requests.Response:
        return session.get(url, headers=headers, allow_redirects=True, timeout=timeout_s, stream=True)

    try:
        resp = do_get(input_url)
    except requests.exceptions.SSLError as e:
        # Try http:// fallback
        try:
            http_url = re.sub(r"^https://", "http://", input_url, flags=re.IGNORECASE)
            resp = do_get(http_url)
        except Exception as e2:
            dt = int((time.time() - t0) * 1000)
            return CheckResult(
                company_id=company_id,
                checked_at=checked_at,
                input_url=input_url,
                input_domain=input_domain,
                final_url=None,
                final_domain=None,
                http_status=None,
                error_type="ssl_error",
                error_message=str(e2)[:500],
                response_time_ms=dt,
                num_redirects=0,
                is_https=None,
                is_valid=False,
                is_parked=False,
                parked_reason=None,
                content_sha256=None,
                raw_result={"exception": "ssl_error", "message": str(e2)},
            )
    except requests.exceptions.Timeout as e:
        dt = int((time.time() - t0) * 1000)
        return CheckResult(
            company_id=company_id,
            checked_at=checked_at,
            input_url=input_url,
            input_domain=input_domain,
            final_url=None,
            final_domain=None,
            http_status=None,
            error_type="timeout",
            error_message=str(e)[:500],
            response_time_ms=dt,
            num_redirects=0,
            is_https=None,
            is_valid=False,
            is_parked=False,
            parked_reason=None,
            content_sha256=None,
            raw_result={"exception": "timeout", "message": str(e)},
        )
    except requests.exceptions.RequestException as e:
        dt = int((time.time() - t0) * 1000)
        return CheckResult(
            company_id=company_id,
            checked_at=checked_at,
            input_url=input_url,
            input_domain=input_domain,
            final_url=None,
            final_domain=None,
            http_status=None,
            error_type="request_error",
            error_message=str(e)[:500],
            response_time_ms=dt,
            num_redirects=0,
            is_https=None,
            is_valid=False,
            is_parked=False,
            parked_reason=None,
            content_sha256=None,
            raw_result={"exception": "request_error", "message": str(e)},
        )

    dt = int((time.time() - t0) * 1000)
    http_status = resp.status_code
    final_url = resp.url
    final_domain = extract_domain(final_url)
    num_redirects = len(resp.history)
    is_https = final_url.lower().startswith("https://") if final_url else None

    # Read up to ~64KB of body for HTML classification
    try:
        content_type = (resp.headers.get("Content-Type") or "").lower()
        if "text/html" in content_type or content_type == "" or "application/xhtml" in content_type:
            chunk = resp.raw.read(65536, decode_content=True)
            html_snippet = chunk.decode("utf-8", errors="ignore")
            content_hash = sha256_text(html_snippet)
    except Exception:
        # Don't fail the whole check if body read fails
        pass

    # Determine parked vs valid
    if html_snippet:
        is_parked, parked_reason = is_parked_page(final_domain or "", html_snippet)

    # Validity:
    # - 2xx/3xx is potentially valid, unless parked
    # - 4xx/5xx => invalid
    if http_status is not None and 200 <= http_status < 400 and not is_parked:
        is_valid = True
    else:
        is_valid = False

    raw_result = {
        "company_id": company_id,
        "input_url": input_url,
        "final_url": final_url,
        "http_status": http_status,
        "redirect_chain": [h.url for h in resp.history] if resp.history else [],
        "final_domain": final_domain,
        "content_type": resp.headers.get("Content-Type"),
    }

    return CheckResult(
        company_id=company_id,
        checked_at=checked_at,
        input_url=input_url,
        input_domain=input_domain,
        final_url=final_url,
        final_domain=final_domain,
        http_status=http_status,
        error_type=error_type,
        error_message=error_message,
        response_time_ms=dt,
        num_redirects=num_redirects,
        is_https=is_https,
        is_valid=is_valid,
        is_parked=is_parked,
        parked_reason=parked_reason,
        content_sha256=content_hash,
        raw_result=raw_result,
    )


def connect_snowflake():
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE"),
        database=os.environ.get("SNOWFLAKE_DATABASE"),
        schema=os.environ.get("SNOWFLAKE_SCHEMA"),
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stale-days", type=int, default=30, help="Recheck websites older than N days")
    ap.add_argument("--limit", type=int, default=500, help="Max companies to check in this run")
    ap.add_argument("--max-workers", type=int, default=16, help="Concurrency for HTTP checks")
    ap.add_argument("--startups-only", action="store_true", help="Only check companies that are startup/uncertain")
    args = ap.parse_args()

    conn = connect_snowflake()

    # 1) Pull candidate websites + last checked timestamp
    startups_filter = ""
    if args.startups_only:
        startups_filter = "WHERE cls.startup_status IN ('startup','uncertain')"

    sql = f"""
    WITH candidates AS (
        SELECT
            c.company_id,
            COALESCE(NULLIF(TRIM(c.website_url),''), NULLIF(TRIM(c.website_domain),'')) AS website
        FROM SILVER.DRM_COMPANY_SILVER c
        LEFT JOIN SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
            ON c.company_id = cls.company_id
        {startups_filter}
    ),
    last_check AS (
        SELECT
            company_id,
            MAX(checked_at) AS last_checked_at
        FROM BRONZE.DRM_WEBSITE_CHECKS_BRONZE
        GROUP BY 1
    )
    SELECT
        cand.company_id,
        cand.website,
        lc.last_checked_at
    FROM candidates cand
    LEFT JOIN last_check lc
        ON cand.company_id = lc.company_id
    WHERE cand.website IS NOT NULL
      AND (
        lc.last_checked_at IS NULL
        OR lc.last_checked_at < DATEADD(day, -{args.stale_days}, CURRENT_TIMESTAMP())
      )
    ORDER BY COALESCE(lc.last_checked_at, '1970-01-01'::TIMESTAMP_NTZ) ASC
    LIMIT {args.limit}
    """

    df = pd.read_sql(sql, conn)
    if df.empty:
        print("Nothing to check (all websites recently checked).")
        return

    # 2) Run HTTP checks concurrently
    results = []
    with ThreadPoolExecutor(max_workers=args.max_workers) as ex:
        futs = {
            ex.submit(check_website, row["COMPANY_ID"], row["WEBSITE"]): row["COMPANY_ID"]
            for _, row in df.iterrows()
        }
        for fut in as_completed(futs):
            res = fut.result()
            results.append(res)

    # 3) Write results to Snowflake (append)
    out = pd.DataFrame([{
        "COMPANY_ID": r.company_id,
        "CHECKED_AT": r.checked_at,
        "INPUT_URL": r.input_url,
        "INPUT_DOMAIN": r.input_domain,
        "FINAL_URL": r.final_url,
        "FINAL_DOMAIN": r.final_domain,
        "HTTP_STATUS": r.http_status,
        "ERROR_TYPE": r.error_type,
        "ERROR_MESSAGE": r.error_message,
        "RESPONSE_TIME_MS": r.response_time_ms,
        "NUM_REDIRECTS": r.num_redirects,
        "IS_HTTPS": r.is_https,
        "IS_VALID": r.is_valid,
        "IS_PARKED": r.is_parked,
        "PARKED_REASON": r.parked_reason,
        "CONTENT_SHA256": r.content_sha256,
        "RAW_RESULT": json.dumps(r.raw_result),
    } for r in results])

    # RAW_RESULT is stored as VARIANT; writing JSON text is ok if you parse on insert,
    # but simplest is to insert as STRING and cast using a staging approach.
    # Here we write as string; you can adapt to use PARSE_JSON in a staging insert if desired.

    success, nchunks, nrows, _ = write_pandas(
        conn,
        out,
        table_name="DRM_WEBSITE_CHECKS_BRONZE",
        schema="BRONZE",
        quote_identifiers=False,
        auto_create_table=False,
    )
    print(f"write_pandas success={success}, rows={nrows}, chunks={nchunks}")


if __name__ == "__main__":
    main()

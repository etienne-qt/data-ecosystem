/* ============================================================
   Q4 — RC_ONLY DELTA AUDIT
   ============================================================
   Context: extending the canonical startup filter to include
   RC_ONLY grows the startup universe from ~4,670 (QT-anchored)
   toward ~7,000. This diagnostic audits that delta along two
   dimensions stakeholders will ask about:

     (1) Matching sensitivity — are we missing DR↔RC matches
         that we should be catching? Near-miss categories:
            - Same domain ROOT, different TLD
            - Name similarity just below the 0.85 threshold
            - Shared REQ NEQ
         If present, these are double-counts, not new rows.

     (2) Non-tech pollution — RC is VC-driven but VCs fund CPG,
         retail, services, traditional manufacturing, cannabis,
         etc. Break RC_ONLY by broader_sector and flag Harmonic-
         only dark matter (no sector assignment at all).

   Output is a RANGE of the delta:
     - Upper bound:  raw RC_ONLY count passing the filter
     - Lower bound:  upper bound minus near-misses minus
                     likely-non-tech rows

   Run All in Snowsight. Read-only.

   Author: AI Agent (Quebec Tech Data & Analytics)
   Date:   2026-04-14
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA GOLD;


/* ------------------------------------------------------------
   Shared temp: RC_ONLY rows post canonical filter.
   ------------------------------------------------------------ */
CREATE OR REPLACE TEMPORARY TABLE _Q4_RC_ONLY AS
SELECT
    r.*,
    COALESCE(r.DRM_LAUNCH_YEAR, r.RC_FOUNDING_YEAR) AS UNIFIED_LAUNCH_YEAR
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY r
WHERE r.ENTITY_TYPE = 'RC_ONLY'
  AND NOT COALESCE(r.IS_STARTUP_BLACKLISTED, FALSE)
  AND (COALESCE(r.DRM_LAUNCH_YEAR, r.RC_FOUNDING_YEAR) IS NULL
       OR COALESCE(r.DRM_LAUNCH_YEAR, r.RC_FOUNDING_YEAR) > 1990)
;


/* ------------------------------------------------------------
   Shared temp: QT-anchored DR rows (for near-miss matching).
   We need normalized domain and name for comparison.
   ------------------------------------------------------------ */
CREATE OR REPLACE TEMPORARY TABLE _Q4_DR AS
SELECT
    r.DEALROOM_ID,
    r.DRM_NAME,
    UTIL.NORM_NAME(r.DRM_NAME)                       AS DRM_NAME_NORM,
    r.DRM_DOMAIN                                     AS DRM_DOMAIN_NORM,
    REGEXP_REPLACE(r.DRM_DOMAIN, '\\.[a-z]{2,4}$', '') AS DRM_DOMAIN_ROOT,
    LOWER(TRIM(r.DRM_CITY))                          AS DRM_CITY_NORM,
    r.REQ_NEQ
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY r
WHERE r.ENTITY_TYPE IN ('MATCHED', 'QT_ONLY')
  AND r.DRM_NAME IS NOT NULL
;


/* ============================================================
   SECTION A — RC_ONLY waterfall through the canonical filter
   Upper bound of the delta contribution.
   ============================================================ */

SELECT 'rc_only_total'                           AS CUT, COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY WHERE ENTITY_TYPE = 'RC_ONLY'
UNION ALL
SELECT 'minus blacklisted',                       COUNT(*)
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE ENTITY_TYPE = 'RC_ONLY'
  AND NOT COALESCE(IS_STARTUP_BLACKLISTED, FALSE)
UNION ALL
SELECT 'minus pre-1990 (unified launch year)',    COUNT(*)
FROM _Q4_RC_ONLY
UNION ALL
SELECT '  of which founding_year IS NULL',        COUNT(*)
FROM _Q4_RC_ONLY WHERE UNIFIED_LAUNCH_YEAR IS NULL
UNION ALL
SELECT '  of which post-1990',                    COUNT(*)
FROM _Q4_RC_ONLY WHERE UNIFIED_LAUNCH_YEAR > 1990;


/* ============================================================
   SECTION B — RC_ONLY by record type and data completeness
   PB-enriched vs Harmonic-only tells us how much data we have
   for each row. PB rows have broader_sector, financing status,
   funding amounts. Harmonic-only rows often have just a name,
   domain, city.
   ============================================================ */

SELECT
    RC_RECORD_TYPE,
    COUNT(*)                                 AS N,
    COUNT_IF(RC_DOMAIN IS NOT NULL)          AS HAS_DOMAIN,
    COUNT_IF(RC_LINKEDIN IS NOT NULL)        AS HAS_LINKEDIN,
    COUNT_IF(RC_BROADER_SECTOR IS NOT NULL)  AS HAS_SECTOR,
    COUNT_IF(RC_BUSINESS_STATUS IS NOT NULL) AS HAS_STATUS,
    COUNT_IF(RC_TOTAL_RAISED_CAD > 0)        AS HAS_FUNDING,
    COUNT_IF(RC_HEADCOUNT IS NOT NULL)       AS HAS_HEADCOUNT,
    COUNT_IF(RC_FOUNDING_YEAR IS NOT NULL)   AS HAS_FOUNDING_YEAR
FROM _Q4_RC_ONLY
GROUP BY RC_RECORD_TYPE
ORDER BY N DESC;


/* ============================================================
   SECTION C — Near-miss match: same domain ROOT, different TLD
   For RC_ONLY rows with a domain, find DR rows whose normalized
   domain root (stripped of TLD) matches. These are very likely
   the same company — the match failed because the TLDs differ.
   ============================================================ */

-- C.1 count by how we'd categorize the near-miss
WITH rc_with_root AS (
    SELECT
        RC_COMPANY_ID,
        REGEXP_REPLACE(RC_DOMAIN, '\\.[a-z]{2,4}$', '') AS RC_DOMAIN_ROOT
    FROM _Q4_RC_ONLY
    WHERE RC_DOMAIN IS NOT NULL
)
SELECT
    'same_domain_root_different_tld' AS NEAR_MISS_CATEGORY,
    COUNT(DISTINCT rc.RC_COMPANY_ID) AS N_RC_ROWS_WITH_CANDIDATE
FROM rc_with_root rc
JOIN _Q4_DR dr
  ON dr.DRM_DOMAIN_ROOT = rc.RC_DOMAIN_ROOT
 AND dr.DRM_DOMAIN_ROOT IS NOT NULL
 AND dr.DRM_DOMAIN_ROOT != ''
WHERE rc.RC_DOMAIN_ROOT IS NOT NULL
  AND rc.RC_DOMAIN_ROOT != '';

-- C.2 sample 20 domain-root near-miss pairs for eyeballing
WITH rc_with_root AS (
    SELECT
        RC_COMPANY_ID,
        RC_NAME,
        RC_DOMAIN,
        RC_CITY,
        REGEXP_REPLACE(RC_DOMAIN, '\\.[a-z]{2,4}$', '') AS RC_DOMAIN_ROOT
    FROM _Q4_RC_ONLY
    WHERE RC_DOMAIN IS NOT NULL
)
SELECT
    rc.RC_COMPANY_ID,
    rc.RC_NAME,
    rc.RC_DOMAIN,
    dr.DEALROOM_ID,
    dr.DRM_NAME,
    dr.DRM_DOMAIN_NORM,
    rc.RC_CITY,
    rc.RC_DOMAIN_ROOT AS SHARED_ROOT
FROM rc_with_root rc
JOIN _Q4_DR dr
  ON dr.DRM_DOMAIN_ROOT = rc.RC_DOMAIN_ROOT
 AND rc.RC_DOMAIN_ROOT IS NOT NULL
 AND rc.RC_DOMAIN_ROOT != ''
ORDER BY RANDOM()
LIMIT 20;


/* ============================================================
   SECTION D — Near-miss match: sub-threshold name similarity
   RC_ONLY rows where we can find a DR row in the same city
   with name_sim between 0.70 and 0.85 (below the matcher's cut).
   Uses p4 blocking key so this stays cheap.
   ============================================================ */

-- D.1 count of RC_ONLY rows with at least one candidate
SELECT
    COUNT(DISTINCT rc.RC_COMPANY_ID) AS N_RC_WITH_SUBTHRESHOLD_CANDIDATE
FROM _Q4_RC_ONLY rc
JOIN _Q4_DR dr
  ON LEFT(rc.RC_NAME, 4) = LEFT(dr.DRM_NAME_NORM, 4)
 AND LOWER(TRIM(rc.RC_CITY)) = dr.DRM_CITY_NORM
 AND UTIL.NAME_SIM(rc.RC_NAME, dr.DRM_NAME_NORM) >= 0.70
 AND UTIL.NAME_SIM(rc.RC_NAME, dr.DRM_NAME_NORM) <  0.85
WHERE rc.RC_NAME IS NOT NULL
  AND rc.RC_CITY IS NOT NULL;

-- D.2 sample 20 sub-threshold name pairs for eyeballing
SELECT
    rc.RC_COMPANY_ID,
    rc.RC_NAME,
    dr.DEALROOM_ID,
    dr.DRM_NAME,
    rc.RC_CITY,
    ROUND(UTIL.NAME_SIM(rc.RC_NAME, dr.DRM_NAME_NORM), 3) AS NAME_SIM
FROM _Q4_RC_ONLY rc
JOIN _Q4_DR dr
  ON LEFT(rc.RC_NAME, 4) = LEFT(dr.DRM_NAME_NORM, 4)
 AND LOWER(TRIM(rc.RC_CITY)) = dr.DRM_CITY_NORM
 AND UTIL.NAME_SIM(rc.RC_NAME, dr.DRM_NAME_NORM) >= 0.70
 AND UTIL.NAME_SIM(rc.RC_NAME, dr.DRM_NAME_NORM) <  0.85
WHERE rc.RC_NAME IS NOT NULL
  AND rc.RC_CITY IS NOT NULL
ORDER BY NAME_SIM DESC
LIMIT 20;


/* ============================================================
   SECTION E — RC_ONLY by PitchBook broader_sector
   Where we HAVE sector data. Tech vs non-tech eyeball.
   ============================================================ */

SELECT
    COALESCE(RC_BROADER_SECTOR, '(null — no PB sector)') AS BROADER_SECTOR,
    COUNT(*)                                              AS N,
    COUNT_IF(RC_RECORD_TYPE = 'HARMONIC_ONLY')            AS HARMONIC_ONLY,
    COUNT_IF(RC_RECORD_TYPE = 'PB_ONLY')                  AS PB_ONLY,
    COUNT_IF(RC_RECORD_TYPE = 'BOTH')                     AS BOTH
FROM _Q4_RC_ONLY
GROUP BY BROADER_SECTOR
ORDER BY N DESC;


/* ============================================================
   SECTION F — RC_ONLY by detailed PitchBook industry_sector
   Only for rows where we have it. Lets us spot CPG / retail /
   services / traditional manufacturing by name.
   ============================================================ */

SELECT
    RC_INDUSTRY_SECTOR,
    COUNT(*) AS N
FROM _Q4_RC_ONLY
WHERE RC_INDUSTRY_SECTOR IS NOT NULL
GROUP BY RC_INDUSTRY_SECTOR
ORDER BY N DESC
LIMIT 30;


/* ============================================================
   SECTION G — Harmonic-only dark matter
   The rows with no PB sector at all. These are the hardest to
   classify; likely need name-based keyword filtering or manual
   review. Show data completeness breakdown.
   ============================================================ */

SELECT
    'HARMONIC_ONLY_no_sector' AS CUT,
    COUNT(*)                                  AS N,
    COUNT_IF(RC_DOMAIN IS NOT NULL)           AS HAS_DOMAIN,
    COUNT_IF(RC_LINKEDIN IS NOT NULL)         AS HAS_LINKEDIN,
    COUNT_IF(UNIFIED_LAUNCH_YEAR IS NOT NULL) AS HAS_FOUNDING_YEAR,
    COUNT_IF(RC_CITY IS NOT NULL)             AS HAS_CITY
FROM _Q4_RC_ONLY
WHERE RC_BROADER_SECTOR IS NULL;


/* ============================================================
   SECTION H — 50-row random sample for manual review
   Pick 50 RC_ONLY rows across record types + sector presence so
   the user can eyeball-tag them tech / non-tech / duplicate.
   ============================================================ */

SELECT
    RC_COMPANY_ID,
    RC_RECORD_TYPE,
    RC_NAME,
    RC_DOMAIN,
    RC_CITY,
    UNIFIED_LAUNCH_YEAR AS FOUNDING_YEAR,
    RC_BROADER_SECTOR,
    RC_INDUSTRY_SECTOR,
    RC_BUSINESS_STATUS,
    RC_HEADCOUNT,
    ROUND(RC_TOTAL_RAISED_CAD / 1000000, 2) AS TOTAL_RAISED_M_CAD,
    FLAG_SECTOR_PHARMA_BIOTECH,
    FLAG_SECTOR_GAMING,
    FLAG_SECTOR_SERVICES
FROM _Q4_RC_ONLY
ORDER BY RANDOM()
LIMIT 50;


/* ============================================================
   SECTION I — Sample stratified by record type
   Extra 15 per record type so the sample hits each tier of data
   quality (BOTH has best data, HARMONIC_ONLY the worst).
   ============================================================ */

WITH stratified AS (
    SELECT
        RC_COMPANY_ID,
        RC_RECORD_TYPE,
        RC_NAME,
        RC_DOMAIN,
        RC_CITY,
        UNIFIED_LAUNCH_YEAR AS FOUNDING_YEAR,
        RC_BROADER_SECTOR,
        RC_INDUSTRY_SECTOR,
        ROUND(RC_TOTAL_RAISED_CAD / 1000000, 2) AS TOTAL_RAISED_M_CAD,
        RC_HEADCOUNT,
        ROW_NUMBER() OVER (PARTITION BY RC_RECORD_TYPE ORDER BY RANDOM()) AS rn
    FROM _Q4_RC_ONLY
)
SELECT *
FROM stratified
WHERE rn <= 15
ORDER BY RC_RECORD_TYPE, rn;


/* ============================================================
   END — Q4 RC_ONLY delta audit
   What to read from the results:

   §A  — upper-bound headline: how many RC_ONLY rows pass the
         filter, before any quality adjustment.
   §B  — data quality by tier. BOTH = best, HARMONIC_ONLY = worst.
   §C  — domain near-misses. Every row in the count is a likely
         double-count. Real delta = A minus C near-misses.
   §D  — name-similarity near-misses. Same story.
   §E  — sector distribution. What fraction of the delta is in
         "Information Technology" vs "Retail, Consumer & Media"
         etc. Non-tech sectors = likely pollution.
   §F  — detailed industry. CPG / retail / cannabis / services
         etc. will show up here.
   §G  — Harmonic-only dark matter count + data completeness.
   §H  — 50-row random sample for eyeballing.
   §I  — 45-row stratified sample (15 per record type).

   Use §H and §I to tag rows manually as tech / non-tech / dup.
   Feed the counts back to refine the delta range.
   ============================================================ */

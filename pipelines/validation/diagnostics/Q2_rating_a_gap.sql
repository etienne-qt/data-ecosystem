/* ============================================================
   Q2 — RATING-A MATCH-RATE GAP INVESTIGATION
   ============================================================
   Q1 revealed a non-monotonic match rate:
     A+ 74%  →  A 28%  →  B 61%
   B beats A by 33 points. That's not noise — there's something
   systematically different about the A cohort.

   Hypotheses to test (cheap):
     H1. A includes foreign-HQ / non-Quebec-state companies that
         DR rates by presence, but RC scopes out by HQ_STATE.
     H2. A captures a size band below PB/Harmonic coverage
         thresholds (too small for deal-driven data sources).
     H3. A is disproportionately old or dead companies (status,
         closing date, vintage skew).
     H4. A is dominated by a specific industry that RC under-
         covers (e.g. services, agencies, consulting).

   Approach: build a temp with matched vs unmatched A, plus
   reference rows from A+ and B, then compare distributions on
   HQ_COUNTRY, HQ_STATE, funding, employees, status, launch year,
   industry. No cross-joins, no UDFs, ~4K-row temp.

   Run with Run All in Snowsight. Read-only.

   Inputs:
     - DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER
     - DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER
     - DEV_QUEBECTECH.SILVER.DRM_INDUSTRY_SIGNALS_SILVER
     - DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP

   Sections:
     A. Build temp (adds HQ_COUNTRY, HQ_STATE, funding, employees,
        status to the Q1 temp)
     B. Matched vs unmatched A by HQ_COUNTRY         (H1)
     C. Matched vs unmatched A by HQ_STATE           (H1)
     D. Matched vs unmatched A by funding bucket     (H2)
     E. Matched vs unmatched A by employee bucket    (H2)
     F. Matched vs unmatched A by COMPANY_STATUS     (H3)
     G. Matched vs unmatched A by LAUNCH_YEAR bucket (H3)
     H. Matched vs unmatched A by top industry       (H4)
     I. Cross-rating reference: same H1/H2 cuts for A+ and B
     J. 50-row eyeball sample of unmatched A

   Author: AI Agent (Quebec Tech Data & Analytics)
   Date:   2026-04-10
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA UTIL;


/* ============================================================
   SECTION A — Build temp
   ============================================================ */

CREATE OR REPLACE TEMPORARY TABLE _Q2_DR_STARTUPS AS
SELECT
    drm.DEALROOM_ID,
    drm.NAME                                AS DRM_NAME,
    cls.RATING_LETTER                       AS DRM_RATING,
    drm.HQ_COUNTRY,
    drm.HQ_STATE,
    drm.HQ_CITY,
    drm.LAUNCH_YEAR,
    drm.COMPANY_STATUS,
    drm.TOTAL_FUNDING_USD_M,
    drm.EMPLOYEES_RANGE,
    drm.EMPLOYEES_LATEST_NUMBER,
    ind.TOP_INDUSTRY                        AS DRM_TOP_INDUSTRY,
    IFF(m.RC_ID IS NOT NULL, TRUE, FALSE)   AS IS_MATCHED_TO_RC,
    m.MATCH_TIER                            AS DR_RC_MATCH_TIER
FROM DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER drm
JOIN DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
  ON drm.DEALROOM_ID = cls.DEALROOM_ID
 AND cls.RATING_LETTER IN ('A+', 'A', 'B')
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_INDUSTRY_SIGNALS_SILVER ind
  ON drm.DEALROOM_ID = ind.DEALROOM_ID
LEFT JOIN DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP m
  ON m.DRM_ID = drm.DEALROOM_ID::VARCHAR
WHERE drm.NAME IS NOT NULL;


/* ============================================================
   SECTION B — Rating A by HQ_COUNTRY   (H1: foreign-HQ theory)
   If a big chunk of unmatched A has HQ_COUNTRY != Canada, RC's
   state-scoped filter is the culprit.
   ============================================================ */

SELECT
    COALESCE(HQ_COUNTRY, '(null)') AS HQ_COUNTRY,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q2_DR_STARTUPS
WHERE DRM_RATING = 'A'
GROUP BY HQ_COUNTRY
ORDER BY N DESC;


/* ============================================================
   SECTION C — Rating A by HQ_STATE
   Among Canada-HQ A rows, how many are outside Quebec?
   ============================================================ */

SELECT
    COALESCE(HQ_STATE, '(null)') AS HQ_STATE,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q2_DR_STARTUPS
WHERE DRM_RATING = 'A'
  AND LOWER(COALESCE(HQ_COUNTRY, '')) IN ('canada', 'ca', '')
GROUP BY HQ_STATE
ORDER BY N DESC;


/* ============================================================
   SECTION D — Rating A by funding bucket   (H2: size band)
   ============================================================ */

SELECT
    CASE
        WHEN TOTAL_FUNDING_USD_M IS NULL                      THEN '00_null'
        WHEN TOTAL_FUNDING_USD_M = 0                          THEN '01_zero'
        WHEN TOTAL_FUNDING_USD_M <  1                         THEN '02_lt_1M'
        WHEN TOTAL_FUNDING_USD_M <  5                         THEN '03_1_5M'
        WHEN TOTAL_FUNDING_USD_M <  20                        THEN '04_5_20M'
        WHEN TOTAL_FUNDING_USD_M <  100                       THEN '05_20_100M'
        ELSE                                                       '06_100M_plus'
    END AS FUNDING_BUCKET,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q2_DR_STARTUPS
WHERE DRM_RATING = 'A'
GROUP BY FUNDING_BUCKET
ORDER BY FUNDING_BUCKET;


/* ============================================================
   SECTION E — Rating A by employee bucket   (H2)
   ============================================================ */

SELECT
    CASE
        WHEN EMPLOYEES_LATEST_NUMBER IS NULL THEN '00_null'
        WHEN EMPLOYEES_LATEST_NUMBER <   5   THEN '01_lt_5'
        WHEN EMPLOYEES_LATEST_NUMBER <  10   THEN '02_5_10'
        WHEN EMPLOYEES_LATEST_NUMBER <  25   THEN '03_10_25'
        WHEN EMPLOYEES_LATEST_NUMBER <  50   THEN '04_25_50'
        WHEN EMPLOYEES_LATEST_NUMBER < 100   THEN '05_50_100'
        WHEN EMPLOYEES_LATEST_NUMBER < 500   THEN '06_100_500'
        ELSE                                      '07_500_plus'
    END AS EMP_BUCKET,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q2_DR_STARTUPS
WHERE DRM_RATING = 'A'
GROUP BY EMP_BUCKET
ORDER BY EMP_BUCKET;


/* ============================================================
   SECTION F — Rating A by COMPANY_STATUS   (H3: dead companies)
   ============================================================ */

SELECT
    COALESCE(COMPANY_STATUS, '(null)') AS COMPANY_STATUS,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q2_DR_STARTUPS
WHERE DRM_RATING = 'A'
GROUP BY COMPANY_STATUS
ORDER BY N DESC;


/* ============================================================
   SECTION G — Rating A by LAUNCH_YEAR bucket   (H3: vintage)
   ============================================================ */

SELECT
    CASE
        WHEN LAUNCH_YEAR IS NULL     THEN '00_null'
        WHEN LAUNCH_YEAR <  2000     THEN '01_pre_2000'
        WHEN LAUNCH_YEAR <  2010     THEN '02_2000s'
        WHEN LAUNCH_YEAR <  2015     THEN '03_2010_2014'
        WHEN LAUNCH_YEAR <  2020     THEN '04_2015_2019'
        WHEN LAUNCH_YEAR <  2024     THEN '05_2020_2023'
        ELSE                              '06_2024_plus'
    END AS VINTAGE,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q2_DR_STARTUPS
WHERE DRM_RATING = 'A'
GROUP BY VINTAGE
ORDER BY VINTAGE;


/* ============================================================
   SECTION H — Rating A by top industry   (H4: sector under-cover)
   Top 20 industries; compare matched vs unmatched.
   ============================================================ */

SELECT
    COALESCE(DRM_TOP_INDUSTRY, '(null)') AS TOP_INDUSTRY,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q2_DR_STARTUPS
WHERE DRM_RATING = 'A'
GROUP BY TOP_INDUSTRY
ORDER BY N DESC
LIMIT 20;


/* ============================================================
   SECTION I — Cross-rating reference
   Same country / funding / employee cuts for A+ and B.
   If the A-gap disappears when we condition on (Canada + Quebec +
   has funding + has employees), the H1+H2 story is confirmed.
   ============================================================ */

-- I.1 country × rating
SELECT
    DRM_RATING,
    CASE
        WHEN LOWER(COALESCE(HQ_COUNTRY, '')) IN ('canada', 'ca') THEN 'CANADA'
        WHEN HQ_COUNTRY IS NULL OR HQ_COUNTRY = ''               THEN 'NULL'
        ELSE                                                          'FOREIGN'
    END AS COUNTRY_GROUP,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q2_DR_STARTUPS
GROUP BY DRM_RATING, COUNTRY_GROUP
ORDER BY DRM_RATING, COUNTRY_GROUP;

-- I.2 funding × rating (has-funding vs no-funding)
SELECT
    DRM_RATING,
    IFF(COALESCE(TOTAL_FUNDING_USD_M, 0) > 0, 'HAS_FUNDING', 'NO_FUNDING') AS FUNDING_FLAG,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q2_DR_STARTUPS
GROUP BY DRM_RATING, FUNDING_FLAG
ORDER BY DRM_RATING, FUNDING_FLAG;

-- I.3 the full conditional: Quebec + has-funding, by rating
SELECT
    DRM_RATING,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q2_DR_STARTUPS
WHERE LOWER(COALESCE(HQ_COUNTRY, '')) IN ('canada', 'ca', '')
  AND LOWER(COALESCE(HQ_STATE,   '')) IN ('quebec', 'québec', 'qc', 'que', '')
  AND COALESCE(TOTAL_FUNDING_USD_M, 0) > 0
GROUP BY DRM_RATING
ORDER BY DRM_RATING;


/* ============================================================
   SECTION J — 50-row eyeball sample of unmatched A
   Full row: name, country, state, city, year, status, funding,
   employees, industry. Eyeball for failure modes.
   ============================================================ */

SELECT
    DEALROOM_ID,
    DRM_NAME,
    HQ_COUNTRY,
    HQ_STATE,
    HQ_CITY,
    LAUNCH_YEAR,
    COMPANY_STATUS,
    TOTAL_FUNDING_USD_M,
    EMPLOYEES_LATEST_NUMBER,
    DRM_TOP_INDUSTRY
FROM _Q2_DR_STARTUPS
WHERE DRM_RATING = 'A'
  AND NOT IS_MATCHED_TO_RC
ORDER BY RANDOM()
LIMIT 50;


/* ============================================================
   END — Q2 RATING-A GAP
   What to look for in the results:

   - If §B shows HQ_COUNTRY is dominated by Canada but §C shows
     unmatched A skews to non-Quebec states → RC scope filter.
     Action: nothing, this is correct behavior (RC is Quebec-only).
   - If §D/§E show unmatched A clusters in no-funding / small-
     employee buckets → A captures companies below RC's coverage
     threshold. Action: accept ceiling, possibly demote these
     from "A" in the classifier.
   - If §F shows unmatched A skews to closed/dead status → old
     records DR still rates but RC has dropped. Action: filter
     by COMPANY_STATUS in 80_ registry build.
   - If §G shows vintage skew → similar, consider launch-year cap.
   - If §H shows a dominant under-covered industry → flag in
     registry (`ambiguous sector` or `rc_under_covers` column).
   - §I.3 is the critical control: matched rate of A on
     (Quebec + has funding) should land near A+ or B. If it
     doesn't, our hypotheses are wrong and we need to look
     deeper (classifier definition of "A").
   ============================================================ */

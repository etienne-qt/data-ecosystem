/* ============================================================
   Q3 — STARTUP FILTER + LIFECYCLE BUCKETS
   ============================================================
   Applies our working definition of a Quebec tech startup to
   GOLD.STARTUP_REGISTRY and breaks the survivors down across
   several lifecycle dimensions. Also cuts the pharma and gaming
   populations as standalone questions.

   Working definition of a startup (v3, 2026-04-13 — includes RC_ONLY):
     - ENTITY_TYPE IN ('MATCHED','QT_ONLY','RC_ONLY')
     - NOT IS_STARTUP_BLACKLISTED               [manual veto]
     - NOT FLAG_NON_TECH_NAME_HIT               [Q2 name veto, DR side]
     - UNIFIED_LAUNCH_YEAR > 1990  OR  UNIFIED_LAUNCH_YEAR IS NULL
       [pre-internet cutoff — applied to the COALESCED launch year
        across DR and RC sources]

   UNIFIED_LAUNCH_YEAR = COALESCE(DRM_LAUNCH_YEAR, RC_FOUNDING_YEAR)
   UNIFIED_STATUS      = CASE
     WHEN DRM_COMPANY_STATUS IS NOT NULL    THEN DRM_COMPANY_STATUS
     WHEN RC_BUSINESS_STATUS matches acquir THEN 'acquired'
     WHEN RC_BUSINESS_STATUS matches closed THEN 'closed'
     WHEN RC_BUSINESS_STATUS IS NOT NULL    THEN 'operational'
     WHEN ENTITY_TYPE = 'RC_ONLY'           THEN 'operational' (Harmonic alive)
     ELSE NULL

   Sector flags are NOT used to exclude — legitimate startups
   exist in pharma/gaming/services. We surface them separately.

   5-bucket lifecycle (simplified 2026-04-13, age-only):
     - acquired    = DRM_COMPANY_STATUS='acquired'
     - closed      = DRM_COMPANY_STATUS IN ('closed','low-activity')
     - mature      = operational AND 1991 ≤ launch_year ≤ 2010
     - active      = operational AND launch_year ≥ 2011
     - unknown_age = operational AND launch_year IS NULL

   Rationale: age alone is the lifecycle signal. Post-internet
   companies born 1991-2010 are "mature startups" by our definition
   (20+ years in); 2011+ are "active startups". Size/capital
   triggers dropped — they surface as separate flags elsewhere
   and weren't discriminating (only 6% size/1.5% capital in the
   previous Q3 run).

   Run All in Snowsight. Read-only.

   Author: AI Agent (Quebec Tech Data & Analytics)
   Date:   2026-04-13
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA GOLD;


/* ============================================================
   SECTION 0 — RC_BUSINESS_STATUS value distribution
   Exposes the actual values so we can verify the mapping below
   catches all "acquired" / "closed" variants.
   ============================================================ */
SELECT
    COALESCE(RC_BUSINESS_STATUS, '(null)') AS RC_BUSINESS_STATUS,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE ENTITY_TYPE = 'RC_ONLY'
GROUP BY RC_BUSINESS_STATUS
ORDER BY N DESC;


/* ------------------------------------------------------------
   Shared filter as a temp table (reused everywhere below).
   v3 CHANGES (2026-04-13):
     - ENTITY_TYPE now includes RC_ONLY
     - UNIFIED_LAUNCH_YEAR = COALESCE(DR, RC)
     - UNIFIED_STATUS derived from DR status, then RC status,
       then defaulting to 'operational' for RC-only rows
     - Pre-1990 cut applied to UNIFIED_LAUNCH_YEAR
     - LIFECYCLE_BUCKET uses unified fields
   ------------------------------------------------------------ */
CREATE OR REPLACE TEMPORARY TABLE _Q3_STARTUPS AS
WITH unified AS (
    SELECT
        r.*,
        COALESCE(r.DRM_LAUNCH_YEAR, r.RC_FOUNDING_YEAR) AS UNIFIED_LAUNCH_YEAR,
        CASE
            WHEN r.DRM_COMPANY_STATUS IS NOT NULL
                THEN r.DRM_COMPANY_STATUS
            WHEN LOWER(r.RC_BUSINESS_STATUS) RLIKE
                 '.*(acquir|merged).*'
                THEN 'acquired'
            WHEN LOWER(r.RC_BUSINESS_STATUS) RLIKE
                 '.*(out of business|closed|dissolv|wound|bankrupt|defunct).*'
                THEN 'closed'
            WHEN r.RC_BUSINESS_STATUS IS NOT NULL
                THEN 'operational'
            WHEN r.ENTITY_TYPE = 'RC_ONLY'
                THEN 'operational'  -- Harmonic tracking = alive signal
            ELSE NULL
        END                                           AS UNIFIED_STATUS,

        -- Policy E non-tech name veto, applied to ALL sides.
        -- DR-side rows already carry FLAG_NON_TECH_NAME_HIT from
        -- the 80 script. For RC_ONLY we compute it inline against
        -- RC_NAME using an expanded keyword list informed by Q4
        -- eyeball results (Apr 14). Snowflake RLIKE is POSIX
        -- without lookaheads — keywords kept simple on purpose.
        CASE
            WHEN COALESCE(r.FLAG_NON_TECH_NAME_HIT, FALSE)
                THEN TRUE
            WHEN r.ENTITY_TYPE = 'RC_ONLY'
                 AND LOWER(r.RC_NAME) RLIKE
                     '.*(consulting|consultant|agency|' ||
                     'r[ée]novation|construction|' ||
                     'd[ée]m[ée]nagement|immobilier|enseigne|' ||
                     'cabinet|conseil|' ||
                     -- expansions from Q4 2026-04-14 sample
                     'funds|insurance|assurance|benefits|' ||
                     'restaurant|caf[ée]|grill|cuisine|resto|bistro|' ||
                     'yogourt|yogurt|buanderie|laundry|' ||
                     'juris|avocat|notaire|' ||
                     'dermo|dermato|esth[ée]tique|cosmetic|cosm[ée]tique|' ||
                     'clinique|chiro|dentiste|dental|optom[ée]trie|' ||
                     'galerie|shopping|boutique).*'
                THEN TRUE
            ELSE FALSE
        END                                           AS UNIFIED_NON_TECH_NAME_HIT
    FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY r
    WHERE r.ENTITY_TYPE IN ('MATCHED', 'QT_ONLY', 'RC_ONLY')
      AND NOT COALESCE(r.IS_STARTUP_BLACKLISTED, FALSE)
)
SELECT
    u.*,
    CASE
        WHEN u.UNIFIED_STATUS = 'acquired'                  THEN 'acquired'
        WHEN u.UNIFIED_STATUS IN ('closed','low-activity')  THEN 'closed'
        WHEN u.UNIFIED_STATUS = 'operational'
             AND u.UNIFIED_LAUNCH_YEAR IS NULL              THEN 'unknown_age'
        WHEN u.UNIFIED_STATUS = 'operational'
             AND u.UNIFIED_LAUNCH_YEAR >= 2011              THEN 'active'
        WHEN u.UNIFIED_STATUS = 'operational'               THEN 'mature'
        ELSE                                                     'unknown_status'
    END                                                    AS LIFECYCLE_BUCKET
FROM unified u
WHERE NOT u.UNIFIED_NON_TECH_NAME_HIT
  AND (u.UNIFIED_LAUNCH_YEAR IS NULL
       OR u.UNIFIED_LAUNCH_YEAR > 1990)
;


/* ============================================================
   SECTION A — Sanity: how many survive the filter?
   ============================================================ */

SELECT 'registry_total'                        AS CUT, COUNT(*) AS N FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
UNION ALL
SELECT 'qt_anchored (MATCHED+QT_ONLY)',           COUNT(*) FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE ENTITY_TYPE IN ('MATCHED','QT_ONLY')
UNION ALL
SELECT 'rc_only',                                  COUNT(*) FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE ENTITY_TYPE = 'RC_ONLY'
UNION ALL
SELECT 'startups_v3 (after filters, incl RC)',     COUNT(*) FROM _Q3_STARTUPS
UNION ALL
SELECT '  of which MATCHED',                       COUNT(*) FROM _Q3_STARTUPS WHERE ENTITY_TYPE = 'MATCHED'
UNION ALL
SELECT '  of which QT_ONLY',                       COUNT(*) FROM _Q3_STARTUPS WHERE ENTITY_TYPE = 'QT_ONLY'
UNION ALL
SELECT '  of which RC_ONLY',                       COUNT(*) FROM _Q3_STARTUPS WHERE ENTITY_TYPE = 'RC_ONLY'
UNION ALL
SELECT 'excluded: blacklisted',                    COUNT(*) FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE COALESCE(IS_STARTUP_BLACKLISTED, FALSE)
UNION ALL
SELECT 'excluded: non_tech_name_hit',              COUNT(*) FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE COALESCE(FLAG_NON_TECH_NAME_HIT, FALSE)
UNION ALL
SELECT 'excluded: pre-1990 (pre-internet)',        COUNT(*) FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
    WHERE NOT COALESCE(IS_STARTUP_BLACKLISTED, FALSE)
      AND NOT COALESCE(FLAG_NON_TECH_NAME_HIT, FALSE)
      AND COALESCE(DRM_LAUNCH_YEAR, RC_FOUNDING_YEAR) IS NOT NULL
      AND COALESCE(DRM_LAUNCH_YEAR, RC_FOUNDING_YEAR) <= 1990;


/* ============================================================
   SECTION B — Lifecycle bucket: UNIFIED_STATUS
   ============================================================ */

SELECT
    COALESCE(UNIFIED_STATUS, '(null)')      AS COMPANY_STATUS,
    COUNT(*)                                AS N,
    COUNT_IF(ENTITY_TYPE = 'MATCHED')       AS N_MATCHED,
    COUNT_IF(ENTITY_TYPE = 'QT_ONLY')       AS N_QT_ONLY,
    COUNT_IF(ENTITY_TYPE = 'RC_ONLY')       AS N_RC_ONLY
FROM _Q3_STARTUPS
GROUP BY COMPANY_STATUS
ORDER BY N DESC;


/* ============================================================
   SECTION C — Lifecycle bucket: launch-year vintage (unified)
   ============================================================ */

SELECT
    CASE
        WHEN UNIFIED_LAUNCH_YEAR IS NULL     THEN '00_null'
        WHEN UNIFIED_LAUNCH_YEAR <  2000     THEN '01_1991_1999'
        WHEN UNIFIED_LAUNCH_YEAR <  2010     THEN '02_2000s'
        WHEN UNIFIED_LAUNCH_YEAR <  2015     THEN '03_2010_2014'
        WHEN UNIFIED_LAUNCH_YEAR <  2020     THEN '04_2015_2019'
        WHEN UNIFIED_LAUNCH_YEAR <  2024     THEN '05_2020_2023'
        ELSE                                      '06_2024_plus'
    END                                     AS VINTAGE,
    COUNT(*)                                AS N,
    COUNT_IF(ENTITY_TYPE = 'MATCHED')       AS N_MATCHED,
    COUNT_IF(ENTITY_TYPE = 'QT_ONLY')       AS N_QT_ONLY,
    COUNT_IF(ENTITY_TYPE = 'RC_ONLY')       AS N_RC_ONLY
FROM _Q3_STARTUPS
GROUP BY VINTAGE
ORDER BY VINTAGE;


/* ============================================================
   SECTION D — Funding stage (DR-side only; RC-side funding
   is in CAD and not directly comparable — skipped for now)
   ============================================================ */

SELECT
    CASE
        WHEN DRM_FUNDING_USD_M IS NULL OR DRM_FUNDING_USD_M = 0 THEN '01_no_funding'
        WHEN DRM_FUNDING_USD_M <    1                            THEN '02_pre_seed_lt_1M'
        WHEN DRM_FUNDING_USD_M <    5                            THEN '03_seed_1_5M'
        WHEN DRM_FUNDING_USD_M <   20                            THEN '04_early_5_20M'
        WHEN DRM_FUNDING_USD_M <  100                            THEN '05_growth_20_100M'
        ELSE                                                          '06_late_100M_plus'
    END                                     AS FUNDING_STAGE,
    COUNT(*)                                AS N,
    COUNT_IF(ENTITY_TYPE = 'MATCHED')       AS N_MATCHED,
    COUNT_IF(ENTITY_TYPE = 'QT_ONLY')       AS N_QT_ONLY
FROM _Q3_STARTUPS
WHERE ENTITY_TYPE IN ('MATCHED','QT_ONLY')
GROUP BY FUNDING_STAGE
ORDER BY FUNDING_STAGE;


/* ============================================================
   SECTION G — 4-bucket lifecycle (active/acquired/closed/mature)
   This is the headline lifecycle cut.
   ============================================================ */

-- G.1 global lifecycle bucket counts
SELECT
    LIFECYCLE_BUCKET,
    COUNT(*)                                AS N,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 1)         AS PCT,
    COUNT_IF(ENTITY_TYPE = 'MATCHED')       AS N_MATCHED,
    COUNT_IF(ENTITY_TYPE = 'QT_ONLY')       AS N_QT_ONLY,
    COUNT_IF(ENTITY_TYPE = 'RC_ONLY')       AS N_RC_ONLY,
    ROUND(AVG(COALESCE(YEAR(CURRENT_DATE()) - UNIFIED_LAUNCH_YEAR, 0)), 1) AS AVG_AGE
FROM _Q3_STARTUPS
GROUP BY LIFECYCLE_BUCKET
ORDER BY CASE LIFECYCLE_BUCKET
             WHEN 'active' THEN 1
             WHEN 'mature' THEN 2
             WHEN 'acquired' THEN 3
             WHEN 'closed' THEN 4
             ELSE 5
         END;

-- G.2 mature distribution across the 1991-2010 window (5-year cohorts)
SELECT
    CASE
        WHEN UNIFIED_LAUNCH_YEAR BETWEEN 1991 AND 1995 THEN '1991_1995'
        WHEN UNIFIED_LAUNCH_YEAR BETWEEN 1996 AND 2000 THEN '1996_2000'
        WHEN UNIFIED_LAUNCH_YEAR BETWEEN 2001 AND 2005 THEN '2001_2005'
        WHEN UNIFIED_LAUNCH_YEAR BETWEEN 2006 AND 2010 THEN '2006_2010'
    END AS MATURE_COHORT,
    COUNT(*) AS N,
    COUNT_IF(ENTITY_TYPE = 'MATCHED') AS N_MATCHED,
    COUNT_IF(ENTITY_TYPE = 'QT_ONLY') AS N_QT_ONLY,
    COUNT_IF(ENTITY_TYPE = 'RC_ONLY') AS N_RC_ONLY
FROM _Q3_STARTUPS
WHERE LIFECYCLE_BUCKET = 'mature'
GROUP BY MATURE_COHORT
ORDER BY MATURE_COHORT;

-- G.3 lifecycle × inclusion reason
SELECT
    LIFECYCLE_BUCKET,
    QT_INCLUSION_REASON,
    COUNT(*) AS N
FROM _Q3_STARTUPS
GROUP BY LIFECYCLE_BUCKET, QT_INCLUSION_REASON
ORDER BY LIFECYCLE_BUCKET, N DESC;


/* ============================================================
   SECTION E — Pharma / biotech
   ============================================================ */

-- E.1 pharma population by source
SELECT
    ENTITY_TYPE,
    COUNT(*)                                     AS N,
    COUNT_IF(COALESCE(DRM_FUNDING_USD_M, 0) > 0) AS WITH_FUNDING,
    COUNT_IF(UNIFIED_STATUS = 'operational')     AS OPERATIONAL,
    COUNT_IF(UNIFIED_STATUS = 'acquired')        AS ACQUIRED,
    COUNT_IF(UNIFIED_STATUS = 'closed')          AS CLOSED
FROM _Q3_STARTUPS
WHERE FLAG_SECTOR_PHARMA_BIOTECH
GROUP BY ENTITY_TYPE
ORDER BY ENTITY_TYPE;

-- E.2 pharma by vintage
SELECT
    CASE
        WHEN UNIFIED_LAUNCH_YEAR IS NULL     THEN '00_null'
        WHEN UNIFIED_LAUNCH_YEAR <  2000     THEN '01_1991_1999'
        WHEN UNIFIED_LAUNCH_YEAR <  2010     THEN '02_2000s'
        WHEN UNIFIED_LAUNCH_YEAR <  2015     THEN '03_2010_2014'
        WHEN UNIFIED_LAUNCH_YEAR <  2020     THEN '04_2015_2019'
        WHEN UNIFIED_LAUNCH_YEAR <  2024     THEN '05_2020_2023'
        ELSE                                      '06_2024_plus'
    END                                     AS VINTAGE,
    COUNT(*)                                AS N
FROM _Q3_STARTUPS
WHERE FLAG_SECTOR_PHARMA_BIOTECH
GROUP BY VINTAGE
ORDER BY VINTAGE;

-- E.3 pharma by funding stage
SELECT
    CASE
        WHEN DRM_FUNDING_USD_M IS NULL OR DRM_FUNDING_USD_M = 0 THEN '01_no_funding'
        WHEN DRM_FUNDING_USD_M <    1                            THEN '02_pre_seed_lt_1M'
        WHEN DRM_FUNDING_USD_M <    5                            THEN '03_seed_1_5M'
        WHEN DRM_FUNDING_USD_M <   20                            THEN '04_early_5_20M'
        WHEN DRM_FUNDING_USD_M <  100                            THEN '05_growth_20_100M'
        ELSE                                                          '06_late_100M_plus'
    END                                     AS FUNDING_STAGE,
    COUNT(*)                                AS N
FROM _Q3_STARTUPS
WHERE FLAG_SECTOR_PHARMA_BIOTECH
GROUP BY FUNDING_STAGE
ORDER BY FUNDING_STAGE;

-- E.4 pharma lifecycle bucket
SELECT
    LIFECYCLE_BUCKET,
    COUNT(*) AS N,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM _Q3_STARTUPS
WHERE FLAG_SECTOR_PHARMA_BIOTECH
GROUP BY LIFECYCLE_BUCKET
ORDER BY N DESC;


/* ============================================================
   SECTION F — Gaming
   ============================================================ */

-- F.1 gaming population by source
SELECT
    ENTITY_TYPE,
    COUNT(*)                                     AS N,
    COUNT_IF(COALESCE(DRM_FUNDING_USD_M, 0) > 0) AS WITH_FUNDING,
    COUNT_IF(UNIFIED_STATUS = 'operational')     AS OPERATIONAL,
    COUNT_IF(UNIFIED_STATUS = 'acquired')        AS ACQUIRED,
    COUNT_IF(UNIFIED_STATUS = 'closed')          AS CLOSED
FROM _Q3_STARTUPS
WHERE FLAG_SECTOR_GAMING
GROUP BY ENTITY_TYPE
ORDER BY ENTITY_TYPE;

-- F.2 gaming by vintage
SELECT
    CASE
        WHEN UNIFIED_LAUNCH_YEAR IS NULL     THEN '00_null'
        WHEN UNIFIED_LAUNCH_YEAR <  2000     THEN '01_1991_1999'
        WHEN UNIFIED_LAUNCH_YEAR <  2010     THEN '02_2000s'
        WHEN UNIFIED_LAUNCH_YEAR <  2015     THEN '03_2010_2014'
        WHEN UNIFIED_LAUNCH_YEAR <  2020     THEN '04_2015_2019'
        WHEN UNIFIED_LAUNCH_YEAR <  2024     THEN '05_2020_2023'
        ELSE                                      '06_2024_plus'
    END                                     AS VINTAGE,
    COUNT(*)                                AS N
FROM _Q3_STARTUPS
WHERE FLAG_SECTOR_GAMING
GROUP BY VINTAGE
ORDER BY VINTAGE;

-- F.3 gaming by funding stage
SELECT
    CASE
        WHEN DRM_FUNDING_USD_M IS NULL OR DRM_FUNDING_USD_M = 0 THEN '01_no_funding'
        WHEN DRM_FUNDING_USD_M <    1                            THEN '02_pre_seed_lt_1M'
        WHEN DRM_FUNDING_USD_M <    5                            THEN '03_seed_1_5M'
        WHEN DRM_FUNDING_USD_M <   20                            THEN '04_early_5_20M'
        WHEN DRM_FUNDING_USD_M <  100                            THEN '05_growth_20_100M'
        ELSE                                                          '06_late_100M_plus'
    END                                     AS FUNDING_STAGE,
    COUNT(*)                                AS N
FROM _Q3_STARTUPS
WHERE FLAG_SECTOR_GAMING
GROUP BY FUNDING_STAGE
ORDER BY FUNDING_STAGE;

-- F.4 gaming lifecycle bucket
SELECT
    LIFECYCLE_BUCKET,
    COUNT(*) AS N,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS PCT
FROM _Q3_STARTUPS
WHERE FLAG_SECTOR_GAMING
GROUP BY LIFECYCLE_BUCKET
ORDER BY N DESC;


/* ============================================================
   END — Q3 startup filter + lifecycle buckets
   ============================================================ */

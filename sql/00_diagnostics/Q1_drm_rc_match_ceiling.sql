/* ============================================================
   Q1 — DR ↔ RC MATCHING CEILING DIAGNOSIS
   ============================================================
   Goal: before investing in a REQ→RC bridge or other matching
   improvements, understand WHY the current DR↔RC match rate
   is only ~42% (1,797 of 4,321 DR A+/A/B startups), and what
   the realistic ceiling is.

   Run section by section. Each section answers one question.
   No tables are created or modified.

   Sections:
     A.  Population sizes & current match rate
     B.  RC Quebec — what identifiers are present?
     C.  DR A+/A/B — what identifiers are present?
     D.  NEQ coverage on each side
     E.  Unmatched DR sample (50 rows for eyeballing)
     F.  Unmatched RC sample (50 rows for eyeballing)
     G.  Token-overlap upper bound (cheap proxy for max additional matches)
     H.  City + name overlap (tighter proxy)
     I.  Tier-4 NAME_SIM score distribution
     J.  Match rate by DR rating × NEQ presence
     K.  Ambiguous-sector entity counts (gaming/pharma/biotech)

   Inputs:
     - DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER
     - DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER
     - DEV_QUEBECTECH.SILVER.DRM_INDUSTRY_SIGNALS_SILVER
     - DEV_QUEBECTECH.SILVER.DRM_REGISTRY_BRIDGE_SILVER
     - DEV_QUEBECTECH.UTIL.T_ENTITIES
     - DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP
     - DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-09
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA UTIL;


/* ------------------------------------------------------------
   Helper CTE-style temp tables to keep the rest of the file
   short and consistent. Drop on session end.
   ------------------------------------------------------------ */

CREATE OR REPLACE TEMPORARY TABLE _Q1_DR_STARTUPS AS
SELECT
    drm.DEALROOM_ID,
    drm.NAME                                AS DRM_NAME,
    UTIL.NORM_NAME(drm.NAME)                AS DRM_NAME_NORM,
    LEFT(UTIL.NORM_NAME(drm.NAME), 4)       AS DRM_P4,
    drm.WEBSITE_DOMAIN                      AS DRM_DOMAIN_RAW,
    ent.DOMAIN_NORM                         AS DRM_DOMAIN_NORM,
    ent.LINKEDIN_NORM                       AS DRM_LINKEDIN_NORM,
    drm.HQ_CITY                             AS DRM_CITY,
    LOWER(TRIM(drm.HQ_CITY))                AS DRM_CITY_NORM,
    drm.LAUNCH_YEAR                         AS DRM_LAUNCH_YEAR,
    cls.RATING_LETTER                       AS DRM_RATING,
    ind.TOP_INDUSTRY                        AS DRM_TOP_INDUSTRY,
    bridge.NEQ_FINAL                        AS DRM_NEQ,
    bridge.MATCH_SOURCE                     AS DRM_NEQ_SOURCE,
    -- Match status from current 63D output
    IFF(m.RC_ID IS NOT NULL, TRUE, FALSE)   AS IS_MATCHED_TO_RC,
    m.MATCH_TIER                            AS DR_RC_MATCH_TIER,
    m.RC_ID                                 AS RC_COMPANY_ID
FROM DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER drm
JOIN DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER cls
  ON drm.DEALROOM_ID = cls.DEALROOM_ID
 AND cls.RATING_LETTER IN ('A+', 'A', 'B')
LEFT JOIN DEV_QUEBECTECH.UTIL.T_ENTITIES ent
  ON ent.SRC = 'DEALROOM' AND ent.SRC_ID = drm.DEALROOM_ID::VARCHAR
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_INDUSTRY_SIGNALS_SILVER ind
  ON drm.DEALROOM_ID = ind.DEALROOM_ID
LEFT JOIN DEV_QUEBECTECH.SILVER.DRM_REGISTRY_BRIDGE_SILVER bridge
  ON drm.DEALROOM_ID = bridge.DEALROOM_ID
LEFT JOIN DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP m
  ON m.DRM_ID = drm.DEALROOM_ID::VARCHAR
WHERE drm.NAME IS NOT NULL;


CREATE OR REPLACE TEMPORARY TABLE _Q1_RC_QUEBEC AS
SELECT
    COALESCE(cm.HARMONIC_COMPANY_ID::VARCHAR,
             cm.PB_COMPANY_ID::VARCHAR)     AS RC_COMPANY_ID,
    cm.HARMONIC_COMPANY_ID,
    cm.PB_COMPANY_ID,
    cm.RECORD_TYPE,
    COALESCE(cm.H_COMPANY_NAME_NORM,
             cm.PB_COMPANY_NAME_NORM)       AS RC_NAME_NORM,
    COALESCE(cm.H_LEGAL_NAME_NORM,
             cm.PB_LEGAL_NAME_NORM)         AS RC_LEGAL_NAME_NORM,
    LEFT(COALESCE(cm.H_COMPANY_NAME_NORM,
                  cm.PB_COMPANY_NAME_NORM), 4) AS RC_P4,
    COALESCE(NULLIF(TRIM(LOWER(cm.PB_WEBSITE_DOMAIN)), ''),
             NULLIF(TRIM(LOWER(cm.H_WEBSITE_DOMAIN)), '')) AS RC_DOMAIN_NORM,
    COALESCE(NULLIF(TRIM(LOWER(cm.H_LINKEDIN_SLUG)), ''),
             NULLIF(TRIM(LOWER(cm.PB_LINKEDIN_SLUG)), '')) AS RC_LINKEDIN_NORM,
    cm.CRUNCHBASE_SLUG                      AS RC_CRUNCHBASE_SLUG,
    COALESCE(cm.H_CITY, cm.PB_HQ_CITY)      AS RC_CITY,
    LOWER(TRIM(COALESCE(cm.H_CITY, cm.PB_HQ_CITY))) AS RC_CITY_NORM,
    COALESCE(YEAR(cm.H_FOUNDING_DATE),
             cm.PB_YEAR_FOUNDED)            AS RC_FOUNDING_YEAR,
    -- Sector hints (PB only, may be NULL)
    NULL                                    AS RC_SECTOR_PLACEHOLDER,
    -- Match status from current 63D output
    IFF(m.DRM_ID IS NOT NULL, TRUE, FALSE)  AS IS_MATCHED_TO_DR,
    m.DRM_ID                                AS DEALROOM_ID
FROM DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER cm
LEFT JOIN DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP m
  ON m.RC_ID = COALESCE(cm.HARMONIC_COMPANY_ID::VARCHAR,
                        cm.PB_COMPANY_ID::VARCHAR)
WHERE LOWER(COALESCE(cm.H_STATE, cm.PB_HQ_STATE_PROVINCE, '')) IN
        ('quebec','québec','qc','que')
   OR LOWER(COALESCE(cm.H_COUNTRY, cm.PB_HQ_COUNTRY, '')) IN
        ('quebec','québec');


/* ============================================================
   SECTION A — Population sizes & current match rate
   Sanity-check the numbers we already have.
   ============================================================ */

SELECT 'DR A+/A/B startups'   AS POPULATION, COUNT(*) AS N FROM _Q1_DR_STARTUPS
UNION ALL
SELECT 'DR matched to RC',         COUNT(*) FROM _Q1_DR_STARTUPS WHERE IS_MATCHED_TO_RC
UNION ALL
SELECT 'DR unmatched',             COUNT(*) FROM _Q1_DR_STARTUPS WHERE NOT IS_MATCHED_TO_RC
UNION ALL
SELECT 'RC Quebec total',          COUNT(*) FROM _Q1_RC_QUEBEC
UNION ALL
SELECT 'RC matched to DR',         COUNT(*) FROM _Q1_RC_QUEBEC WHERE IS_MATCHED_TO_DR
UNION ALL
SELECT 'RC unmatched',             COUNT(*) FROM _Q1_RC_QUEBEC WHERE NOT IS_MATCHED_TO_DR;


/* ============================================================
   SECTION B — RC Quebec: identifier coverage
   Which join keys do RC records actually carry? This tells us
   whether NEQ matching (via REQ hub) is the right lever, or if
   we should focus on better domain / name matching.
   ============================================================ */

SELECT
    COUNT(*)                                                        AS RC_TOTAL,
    COUNT_IF(RC_DOMAIN_NORM IS NOT NULL)                            AS HAS_DOMAIN,
    COUNT_IF(RC_LINKEDIN_NORM IS NOT NULL)                          AS HAS_LINKEDIN,
    COUNT_IF(RC_CRUNCHBASE_SLUG IS NOT NULL)                        AS HAS_CRUNCHBASE,
    COUNT_IF(RC_LEGAL_NAME_NORM IS NOT NULL)                        AS HAS_LEGAL_NAME,
    COUNT_IF(RC_NAME_NORM IS NOT NULL)                              AS HAS_NAME,
    COUNT_IF(RC_CITY_NORM IS NOT NULL)                              AS HAS_CITY,
    COUNT_IF(RC_FOUNDING_YEAR IS NOT NULL)                          AS HAS_FOUNDING_YEAR,
    -- Worst case: only a name, no other identifier
    COUNT_IF(RC_DOMAIN_NORM IS NULL
             AND RC_LINKEDIN_NORM IS NULL
             AND RC_CRUNCHBASE_SLUG IS NULL)                        AS NAME_ONLY,
    -- Even worse: no identifier at all
    COUNT_IF(RC_DOMAIN_NORM IS NULL
             AND RC_LINKEDIN_NORM IS NULL
             AND RC_CRUNCHBASE_SLUG IS NULL
             AND RC_NAME_NORM IS NULL)                              AS NO_IDENTIFIERS
FROM _Q1_RC_QUEBEC;

-- Same breakdown but only for the UNMATCHED RC records (the gap)
SELECT
    COUNT(*)                                                        AS RC_UNMATCHED,
    COUNT_IF(RC_DOMAIN_NORM IS NOT NULL)                            AS HAS_DOMAIN,
    COUNT_IF(RC_LINKEDIN_NORM IS NOT NULL)                          AS HAS_LINKEDIN,
    COUNT_IF(RC_CRUNCHBASE_SLUG IS NOT NULL)                        AS HAS_CRUNCHBASE,
    COUNT_IF(RC_LEGAL_NAME_NORM IS NOT NULL)                        AS HAS_LEGAL_NAME,
    COUNT_IF(RC_DOMAIN_NORM IS NULL AND RC_LINKEDIN_NORM IS NULL
             AND RC_CRUNCHBASE_SLUG IS NULL)                        AS NAME_ONLY,
    -- RECORD_TYPE distribution (Harmonic-only vs PB vs both)
    COUNT_IF(RECORD_TYPE = 'HARMONIC_ONLY')                         AS RT_HARMONIC_ONLY,
    COUNT_IF(RECORD_TYPE = 'PB_ONLY')                               AS RT_PB_ONLY,
    COUNT_IF(RECORD_TYPE = 'BOTH')                                  AS RT_BOTH
FROM _Q1_RC_QUEBEC
WHERE NOT IS_MATCHED_TO_DR;


/* ============================================================
   SECTION C — DR A+/A/B: identifier coverage
   Same picture from the Dealroom side.
   ============================================================ */

SELECT
    COUNT(*)                                                        AS DR_TOTAL,
    COUNT_IF(DRM_DOMAIN_NORM IS NOT NULL)                           AS HAS_DOMAIN,
    COUNT_IF(DRM_LINKEDIN_NORM IS NOT NULL)                         AS HAS_LINKEDIN,
    COUNT_IF(DRM_NEQ IS NOT NULL)                                   AS HAS_NEQ,
    COUNT_IF(DRM_CITY_NORM IS NOT NULL)                             AS HAS_CITY,
    COUNT_IF(DRM_LAUNCH_YEAR IS NOT NULL)                           AS HAS_LAUNCH_YEAR
FROM _Q1_DR_STARTUPS;

-- Same for unmatched DR
SELECT
    COUNT(*)                                                        AS DR_UNMATCHED,
    COUNT_IF(DRM_DOMAIN_NORM IS NOT NULL)                           AS HAS_DOMAIN,
    COUNT_IF(DRM_LINKEDIN_NORM IS NOT NULL)                         AS HAS_LINKEDIN,
    COUNT_IF(DRM_NEQ IS NOT NULL)                                   AS HAS_NEQ,
    DRM_RATING                                                      AS RATING
FROM _Q1_DR_STARTUPS
WHERE NOT IS_MATCHED_TO_RC
GROUP BY DRM_RATING
ORDER BY DRM_RATING;


/* ============================================================
   SECTION D — NEQ coverage on each side
   Confirms the asymmetry: DR has NEQ via bridge, RC has none
   intrinsically. This is the lever for the REQ-hub approach.
   ============================================================ */

-- DR side: what fraction has NEQ (via bridge)?
SELECT
    'DR A+/A/B' AS POP,
    COUNT(*) AS N,
    COUNT_IF(DRM_NEQ IS NOT NULL) AS WITH_NEQ,
    ROUND(COUNT_IF(DRM_NEQ IS NOT NULL) * 100.0 / COUNT(*), 1) AS PCT_NEQ,
    COUNT_IF(DRM_NEQ_SOURCE = 'number') AS NEQ_BY_NUMBER,
    COUNT_IF(DRM_NEQ_SOURCE = 'name')   AS NEQ_BY_NAME
FROM _Q1_DR_STARTUPS;

-- RC side: does COMPANY_MASTER even have a column that could carry NEQ?
-- Spot-check by sampling raw fields where the value looks like a 10-digit Quebec NEQ.
-- This validates the hypothesis that RC has NO native NEQs.
SELECT COUNT(*) AS N_RC_WITH_NEQ_LIKE_FIELD
FROM DEV_RESEAUCAPITAL.SILVER.COMPANY_MASTER
WHERE REGEXP_LIKE(COALESCE(H_LEGAL_NAME_NORM, ''), '[0-9]{10}')
   OR REGEXP_LIKE(COALESCE(PB_LEGAL_NAME_NORM, ''), '[0-9]{10}');
-- If 0 or near-0, RC needs a NEW REQ bridge built name+city against REQ_CANONICAL.


/* ============================================================
   SECTION E — Unmatched DR sample (50 rows)
   Eyeball-test: what do unmatched A-rated startups look like?
   Useful for spotting obvious failure modes (typo'd domain,
   missing identifier, French legal name, recently rebranded).
   ============================================================ */

SELECT
    DEALROOM_ID, DRM_NAME, DRM_RATING, DRM_DOMAIN_NORM,
    DRM_LINKEDIN_NORM, DRM_NEQ, DRM_CITY, DRM_LAUNCH_YEAR
FROM _Q1_DR_STARTUPS
WHERE NOT IS_MATCHED_TO_RC
  AND DRM_RATING = 'A'
ORDER BY RANDOM()
LIMIT 50;


/* ============================================================
   SECTION F — Unmatched RC sample (50 rows)
   Same eyeball test from the RC side. Helpful for sector triage:
   how many of these are obviously not startups (large pharma,
   subsidiaries of multinationals, services firms)?
   ============================================================ */

SELECT
    RC_COMPANY_ID, RECORD_TYPE, RC_NAME_NORM, RC_LEGAL_NAME_NORM,
    RC_DOMAIN_NORM, RC_LINKEDIN_NORM, RC_CITY, RC_FOUNDING_YEAR
FROM _Q1_RC_QUEBEC
WHERE NOT IS_MATCHED_TO_DR
ORDER BY RANDOM()
LIMIT 50;


/* ============================================================
   SECTION G — Token-overlap upper bound (cheap proxy)
   How many unmatched RC records share their first 4 normalized
   characters with at least one unmatched DR record? This is the
   CHEAPEST upper bound on how many additional matches a smarter
   matcher could find. It's optimistic (lots of P4 collisions)
   but tells us whether the ceiling is "high" or "near zero".
   ============================================================ */

SELECT COUNT(DISTINCT rc.RC_COMPANY_ID) AS RC_UNMATCHED_WITH_P4_OVERLAP
FROM _Q1_RC_QUEBEC rc
JOIN _Q1_DR_STARTUPS dr
  ON dr.DRM_P4 = rc.RC_P4
WHERE NOT rc.IS_MATCHED_TO_DR
  AND NOT dr.IS_MATCHED_TO_RC
  AND rc.RC_P4 IS NOT NULL
  AND dr.DRM_P4 IS NOT NULL;


/* ============================================================
   SECTION H — City + name overlap (tighter proxy)
   The previous query is too loose. Restrict to (a) name
   similarity ≥ 0.75 and (b) same city. This is a much tighter
   estimate of the realistic ceiling.
   WARNING: this is a cross-join with name_sim, will scan a lot.
   May want to LIMIT or run with a warehouse size bump.
   ============================================================ */

SELECT
    COUNT(DISTINCT rc.RC_COMPANY_ID) AS RC_RECOVERABLE_BY_NAME_AND_CITY,
    COUNT(DISTINCT dr.DEALROOM_ID)   AS DR_RECOVERABLE_BY_NAME_AND_CITY
FROM _Q1_RC_QUEBEC rc
JOIN _Q1_DR_STARTUPS dr
  ON dr.DRM_P4 = rc.RC_P4
 AND dr.DRM_CITY_NORM = rc.RC_CITY_NORM
 AND UTIL.NAME_SIM(dr.DRM_NAME_NORM, rc.RC_NAME_NORM) >= 0.75
WHERE NOT rc.IS_MATCHED_TO_DR
  AND NOT dr.IS_MATCHED_TO_RC;


/* ============================================================
   SECTION I — Tier-4 NAME_SIM score distribution
   Where do the 171 fuzzy matches sit on the score axis?
   Helps decide a defensible threshold.
   ============================================================ */

SELECT
    CASE
        WHEN SCORE >= 0.95 THEN '0.95-1.00 (very strong)'
        WHEN SCORE >= 0.90 THEN '0.90-0.95 (strong)'
        WHEN SCORE >= 0.85 THEN '0.85-0.90 (borderline)'
        ELSE '< 0.85 (rejected)'
    END AS BUCKET,
    COUNT(*) AS N
FROM DEV_QUEBECTECH.UTIL.T_DRM_RC_MATCH_EDGES_DEDUP
WHERE MATCH_TIER = 4
GROUP BY BUCKET
ORDER BY BUCKET DESC;


/* ============================================================
   SECTION J — Match rate by DR rating × NEQ presence
   Does having an NEQ correlate with successful RC matching?
   If yes (likely): the REQ-hub strategy has clear leverage.
   If no: the bottleneck is somewhere else (RC just doesn't
   have these companies at all).
   ============================================================ */

SELECT
    DRM_RATING,
    IFF(DRM_NEQ IS NOT NULL, 'HAS_NEQ', 'NO_NEQ') AS NEQ_STATUS,
    COUNT(*) AS N,
    COUNT_IF(IS_MATCHED_TO_RC) AS MATCHED,
    ROUND(COUNT_IF(IS_MATCHED_TO_RC) * 100.0 / COUNT(*), 1) AS PCT_MATCHED
FROM _Q1_DR_STARTUPS
GROUP BY DRM_RATING, NEQ_STATUS
ORDER BY DRM_RATING, NEQ_STATUS;


/* ============================================================
   SECTION K — Ambiguous-sector entity counts
   Gaming, pharma, biotech, services-disguised-as-tech are the
   sectors where Dealroom and the QT classifier disagree most.
   We need to flag these in the registry, not exclude them.
   This counts how many entities will get flagged.
   ============================================================ */

-- DR side: top industries containing each ambiguous keyword
SELECT
    'gaming'  AS KEYWORD, COUNT(*) AS N_DR_STARTUPS
FROM _Q1_DR_STARTUPS
WHERE LOWER(DRM_TOP_INDUSTRY) RLIKE '.*(gaming|game|esports|casino).*'
UNION ALL
SELECT 'pharma', COUNT(*)
FROM _Q1_DR_STARTUPS
WHERE LOWER(DRM_TOP_INDUSTRY) RLIKE '.*(pharma|pharmaceutical|drug).*'
UNION ALL
SELECT 'biotech', COUNT(*)
FROM _Q1_DR_STARTUPS
WHERE LOWER(DRM_TOP_INDUSTRY) RLIKE '.*(biotech|life science|biolog).*'
UNION ALL
SELECT 'consulting/services', COUNT(*)
FROM _Q1_DR_STARTUPS
WHERE LOWER(DRM_TOP_INDUSTRY) RLIKE '.*(consult|service|agency).*';

-- RC side: same keywords against PitchBook industry sector if available.
-- Note: requires joining back to COMPANY_MASTER for PB_INDUSTRY_SECTOR;
-- shown here as a template, may need column-name adjustment.
SELECT
    pb.INDUSTRY_SECTOR,
    COUNT(*) AS N
FROM _Q1_RC_QUEBEC rc
LEFT JOIN DEV_RESEAUCAPITAL.SILVER.PITCHBOOK_ACQ_COMPANIES pb
  ON rc.PB_COMPANY_ID = pb.PB_COMPANY_ID
WHERE LOWER(pb.INDUSTRY_SECTOR) RLIKE '.*(gaming|pharma|biotech|drug|consult).*'
GROUP BY pb.INDUSTRY_SECTOR
ORDER BY N DESC;


/* ============================================================
   END OF Q1 DIAGNOSTICS
   What to do with the results:

   - If Section B shows RC_UNMATCHED is mostly NAME_ONLY with no
     domain/LinkedIn/Crunchbase  →  REQ-hub matching is the
     right lever (build SILVER.RC_REGISTRY_BRIDGE_SILVER).
   - If Section H shows RC_RECOVERABLE > 500 →  also worth
     adding a city+name composite tier 5 to 63D.
   - If Section J shows HAS_NEQ DR rows match RC at 60%+ but
     NO_NEQ rows match at <20%, NEQ is a strong predictor and
     the REQ-hub will be high-impact.
   - If Section J shows little difference, RC simply doesn't
     have these companies — accept the ceiling and don't waste
     effort on more matching.
   ============================================================ */

/* ============================================================
   Q5 — REQ POST-2024 HARD TECH / DEEP TECH DISCOVERY
   ============================================================
   Surfaces companies newly incorporated in Quebec (2024+) whose
   REQ signals suggest hard tech or deep tech: photonics, quantum,
   semiconductors, robotics, biotech / medtech / pharma, nanotech,
   advanced sensors / IoT, cleantech, aerospace.

   This is READ-ONLY. It reuses the silver classification built
   by pipelines/transforms/silver/31_req_product_classification.sql and does NOT
   write back to any table. All output is section-by-section result
   grids intended for Snowsight; save each grid as CSV for analysis.

   Upstream dependency:
     DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
       — run stage 31 first if it does not exist or is stale.

   Method:
     The silver layer already scores ~40 product signals on free-text
     sector descriptions plus CAE codes (see stage 31 lines 219–278).
     Q5 does not re-classify; it filters the silver output to:
       1. DATE_IMMATRICULATION >= 2024-01-01
       2. MATCHED_SIGNALS contains at least one hard/deep-tech token
          OR CAE_CODE is in a curated hardware / life-sciences set
     then layers sub-category and geography breakdowns.

   Hard-tech / deep-tech signal tokens (from silver MATCHED_SIGNALS):
     semiconductor, photonics, quantum, nanotech, robotics, drone,
     iot, aerospace, medtech, pharma, biotech, genomics,
     digital_health, cleantech

   Hard-tech CAE codes (from REGISTRE_ADRESSES.CAE_PRIMAIRE):
     3340, 3341, 3350, 3351, 3352, 3359   — electrical/electronic mfg
     3361                                  — motor vehicle bodies / specialty
     3674                                  — semiconductor devices
     3740, 3741                            — scientific instruments / aerospace
     3827                                  — optical instruments
     3910, 3699                            — misc manufacturing / industrial
     2851                                  — industrial chemicals / biotech inputs
     4823                                  — industrial / scientific services

   Caveats (per INTERNAL-hardware-photonics-req-2026):
     - 73% of historical hard-tech classifications rely on CAE code
       alone — expect noise, esp. CAE 3699 (laser cutting, beauty clinics).
     - REQ captures provincial incorporations only; federally (CBCA)
       incorporated hard-tech companies are systematically missing.
     - DATE_IMMATRICULATION marks shell creation, not operating start.
     - Section 5 separates keyword-confirmed (HIGH) from CAE-only (LOW).

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-17
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;


/* ----------------------------------------------------------
   PRECONDITION — silver table must exist and be populated
   ---------------------------------------------------------- */

SELECT
    'SILVER.REQ_PRODUCT_CLASSIFICATION' AS tbl,
    COUNT(*)                            AS n_rows,
    MIN(DATE_IMMATRICULATION)           AS min_date,
    MAX(DATE_IMMATRICULATION)           AS max_date,
    COUNTIF(INCORPORATION_YEAR >= 2024) AS n_post_2024
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION;


/* ----------------------------------------------------------
   1. POST-2024 VOLUME BY TIER
   Sanity check: how many post-2024 REQ rows in each PRODUCT_TIER?
   ---------------------------------------------------------- */

SELECT
    PRODUCT_TIER,
    COUNT(*)                            AS n,
    COUNTIF(IS_PRODUCT)                 AS n_is_product,
    ROUND(100.0 * COUNTIF(IS_PRODUCT) / NULLIF(COUNT(*),0), 1) AS pct_product
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
WHERE INCORPORATION_YEAR >= 2024
GROUP BY PRODUCT_TIER
ORDER BY CASE PRODUCT_TIER
             WHEN 'HIGH' THEN 1
             WHEN 'MEDIUM' THEN 2
             WHEN 'LOW' THEN 3
             WHEN 'EXCLUDED_SERVICE' THEN 4
             WHEN 'NONE' THEN 5
         END;


/* ----------------------------------------------------------
   2. POST-2024 HARD/DEEP TECH — KEYWORD-CONFIRMED
   Companies whose free-text sector matched at least one
   hard/deep-tech signal in stage 31. This is the high-confidence
   cohort (not CAE-only).
   ---------------------------------------------------------- */

WITH keyword_confirmed AS (
    SELECT *
    FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
    WHERE INCORPORATION_YEAR >= 2024
      AND (
             MATCHED_SIGNALS ILIKE '%semiconductor%'
          OR MATCHED_SIGNALS ILIKE '%photonics%'
          OR MATCHED_SIGNALS ILIKE '%quantum%'
          OR MATCHED_SIGNALS ILIKE '%nanotech%'
          OR MATCHED_SIGNALS ILIKE '%robotics%'
          OR MATCHED_SIGNALS ILIKE '%drone%'
          OR MATCHED_SIGNALS ILIKE '%iot%'
          OR MATCHED_SIGNALS ILIKE '%aerospace%'
          OR MATCHED_SIGNALS ILIKE '%medtech%'
          OR MATCHED_SIGNALS ILIKE '%pharma%'
          OR MATCHED_SIGNALS ILIKE '%biotech%'
          OR MATCHED_SIGNALS ILIKE '%genomics%'
          OR MATCHED_SIGNALS ILIKE '%digital_health%'
          OR MATCHED_SIGNALS ILIKE '%cleantech%'
          )
)
SELECT
    INCORPORATION_YEAR,
    COUNT(*)                              AS n,
    COUNTIF(PRODUCT_TIER = 'HIGH')        AS n_high,
    COUNTIF(PRODUCT_TIER = 'MEDIUM')      AS n_medium,
    COUNTIF(PRODUCT_TIER = 'LOW')         AS n_low,
    COUNTIF(IS_SERVICE)                   AS n_service_flagged
FROM keyword_confirmed
GROUP BY INCORPORATION_YEAR
ORDER BY INCORPORATION_YEAR;


/* ----------------------------------------------------------
   3. POST-2024 HARD-TECH CAE CODES (no keyword confirmation required)
   Useful to surface shells + companies with empty sector text
   that still sit in a hardware / life-sciences CAE bucket.
   Treat as a candidate queue — expect noise.
   ---------------------------------------------------------- */

SELECT
    CAE_CODE,
    COUNT(*)                                     AS n,
    COUNTIF(HAS_DESC)                            AS n_with_description,
    COUNTIF(IS_PRODUCT)                          AS n_is_product,
    COUNTIF(MATCHED_SIGNALS IS NOT NULL
            AND LENGTH(MATCHED_SIGNALS) > 0)     AS n_any_keyword_signal
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
WHERE INCORPORATION_YEAR >= 2024
  AND CAE_CODE IN (
        2851,
        3340, 3341, 3350, 3351, 3352, 3359,
        3361,
        3674,
        3699,
        3740, 3741,
        3827,
        3910,
        4823
      )
GROUP BY CAE_CODE
ORDER BY n DESC;


/* ----------------------------------------------------------
   4. HARD/DEEP-TECH SUB-CATEGORY BREAKDOWN (post-2024)
   One row per sub-category with distinct NEQ count. A single
   company can appear in multiple rows if its MATCHED_SIGNALS
   hit more than one token (expected — biotech + medtech often
   co-occur).
   ---------------------------------------------------------- */

WITH post2024_tech AS (
    SELECT NEQ, MATCHED_SIGNALS, PRODUCT_TIER
    FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
    WHERE INCORPORATION_YEAR >= 2024
      AND IS_PRODUCT = TRUE
)
SELECT 'photonics'       AS subcategory, COUNT(DISTINCT NEQ) AS n FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%photonics%'
UNION ALL SELECT 'quantum',              COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%quantum%'
UNION ALL SELECT 'semiconductor',        COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%semiconductor%'
UNION ALL SELECT 'nanotech',             COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%nanotech%'
UNION ALL SELECT 'robotics',             COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%robotics%'
UNION ALL SELECT 'drone',                COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%drone%'
UNION ALL SELECT 'iot',                  COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%iot%'
UNION ALL SELECT 'aerospace',            COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%aerospace%'
UNION ALL SELECT 'biotech',              COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%biotech%'
UNION ALL SELECT 'genomics',             COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%genomics%'
UNION ALL SELECT 'medtech',              COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%medtech%'
UNION ALL SELECT 'pharma',               COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%pharma%'
UNION ALL SELECT 'digital_health',       COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%digital_health%'
UNION ALL SELECT 'cleantech',            COUNT(DISTINCT NEQ) FROM post2024_tech WHERE MATCHED_SIGNALS ILIKE '%cleantech%'
ORDER BY n DESC;


/* ----------------------------------------------------------
   5. CONFIDENCE-TIERED CANDIDATE LIST (post-2024)
   Combines keyword + CAE evidence into three tiers. Use this
   as the review queue: HIGH is worth direct outreach / enrichment,
   LOW needs manual disambiguation (beauty clinics, laser cutting,
   fiber-optic installers are the usual CAE-3699 / 3827 false hits).
   ---------------------------------------------------------- */

WITH scored AS (
    SELECT
        NEQ,
        NEQ_NORM,
        DATE_IMMATRICULATION,
        INCORPORATION_YEAR,
        FORME_JURIDIQUE,
        N_EMPLOYES,
        EMP_MIN,
        CAE_CODE,
        HQ_CITY,
        DESCRIPTION_RAW,
        MATCHED_SIGNALS,
        PRODUCT_TIER,
        PRODUCT_SCORE,
        IS_SERVICE,
        -- Has any hard/deep-tech keyword hit?
        CASE WHEN MATCHED_SIGNALS ILIKE ANY (
               '%semiconductor%','%photonics%','%quantum%','%nanotech%',
               '%robotics%','%drone%','%iot%','%aerospace%',
               '%medtech%','%pharma%','%biotech%','%genomics%',
               '%digital_health%','%cleantech%'
             ) THEN TRUE ELSE FALSE END                           AS HAS_HARDTECH_KEYWORD,
        -- Is CAE in the hardware / life-sciences bucket?
        CASE WHEN CAE_CODE IN (
               2851,
               3340,3341,3350,3351,3352,3359,
               3361, 3674, 3699, 3740, 3741, 3827, 3910, 4823
             ) THEN TRUE ELSE FALSE END                           AS HAS_HARDTECH_CAE
    FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
    WHERE INCORPORATION_YEAR >= 2024
)
SELECT
    CASE
        WHEN HAS_HARDTECH_KEYWORD AND PRODUCT_TIER IN ('HIGH','MEDIUM')
             AND NOT IS_SERVICE                                  THEN 'HIGH'
        WHEN HAS_HARDTECH_KEYWORD                                THEN 'MEDIUM'
        WHEN HAS_HARDTECH_CAE AND PRODUCT_TIER IN ('HIGH','MEDIUM')
             AND NOT IS_SERVICE                                  THEN 'MEDIUM'
        WHEN HAS_HARDTECH_CAE                                    THEN 'LOW'
        ELSE 'NONE'
    END                                  AS HARDTECH_CONFIDENCE,
    COUNT(*)                             AS n,
    COUNTIF(HAS_HARDTECH_KEYWORD)        AS n_keyword_confirmed,
    COUNTIF(HAS_HARDTECH_CAE)            AS n_cae_match,
    COUNTIF(IS_SERVICE)                  AS n_service_flagged
FROM scored
WHERE HAS_HARDTECH_KEYWORD OR HAS_HARDTECH_CAE
GROUP BY HARDTECH_CONFIDENCE
ORDER BY CASE HARDTECH_CONFIDENCE
             WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2
             WHEN 'LOW' THEN 3 ELSE 4
         END;


/* ----------------------------------------------------------
   6. GEOGRAPHY — POST-2024 HARD TECH BY HQ CITY
   Keyword-confirmed only (excludes CAE-only noise). Top 25.
   ---------------------------------------------------------- */

SELECT
    COALESCE(HQ_CITY, '(unknown)')   AS hq_city,
    COUNT(*)                          AS n,
    COUNT(DISTINCT NEQ)               AS n_distinct
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
WHERE INCORPORATION_YEAR >= 2024
  AND IS_PRODUCT = TRUE
  AND (
         MATCHED_SIGNALS ILIKE '%semiconductor%'
      OR MATCHED_SIGNALS ILIKE '%photonics%'
      OR MATCHED_SIGNALS ILIKE '%quantum%'
      OR MATCHED_SIGNALS ILIKE '%nanotech%'
      OR MATCHED_SIGNALS ILIKE '%robotics%'
      OR MATCHED_SIGNALS ILIKE '%drone%'
      OR MATCHED_SIGNALS ILIKE '%iot%'
      OR MATCHED_SIGNALS ILIKE '%aerospace%'
      OR MATCHED_SIGNALS ILIKE '%medtech%'
      OR MATCHED_SIGNALS ILIKE '%pharma%'
      OR MATCHED_SIGNALS ILIKE '%biotech%'
      OR MATCHED_SIGNALS ILIKE '%genomics%'
      OR MATCHED_SIGNALS ILIKE '%digital_health%'
      OR MATCHED_SIGNALS ILIKE '%cleantech%'
      )
GROUP BY hq_city
ORDER BY n_distinct DESC
LIMIT 25;


/* ----------------------------------------------------------
   7. NET-NEW vs. ALREADY-KNOWN (post-2024, keyword-confirmed)
   A post-2024 hard-tech company already in GOLD.STARTUP_REGISTRY
   (via NEQ bridge) is already on our radar; a company not in the
   registry is a discovery candidate for Dealroom / HubSpot entry.
   Safe-fallback: if the registry table or NEQ column is missing,
   this section will surface an error — comment it out in that case.
   ---------------------------------------------------------- */

WITH post2024_hardtech AS (
    SELECT NEQ, NEQ_NORM
    FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
    WHERE INCORPORATION_YEAR >= 2024
      AND IS_PRODUCT = TRUE
      AND (
             MATCHED_SIGNALS ILIKE '%semiconductor%'
          OR MATCHED_SIGNALS ILIKE '%photonics%'
          OR MATCHED_SIGNALS ILIKE '%quantum%'
          OR MATCHED_SIGNALS ILIKE '%nanotech%'
          OR MATCHED_SIGNALS ILIKE '%robotics%'
          OR MATCHED_SIGNALS ILIKE '%drone%'
          OR MATCHED_SIGNALS ILIKE '%iot%'
          OR MATCHED_SIGNALS ILIKE '%aerospace%'
          OR MATCHED_SIGNALS ILIKE '%medtech%'
          OR MATCHED_SIGNALS ILIKE '%pharma%'
          OR MATCHED_SIGNALS ILIKE '%biotech%'
          OR MATCHED_SIGNALS ILIKE '%genomics%'
          OR MATCHED_SIGNALS ILIKE '%digital_health%'
          OR MATCHED_SIGNALS ILIKE '%cleantech%'
          )
),
registry_neqs AS (
    -- NEQ is surfaced on the DR side via the bridge, or directly
    -- on RC rows that carry a NEQ. Use T_REQ_STARTUP_MATCH_SUMMARY
    -- if available (built by stage 63R); otherwise fall back to
    -- GOLD.STARTUP_REGISTRY's NEQ-carrying columns.
    SELECT DISTINCT NEQ
    FROM DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY
    WHERE NEQ IS NOT NULL
)
SELECT
    CASE WHEN r.NEQ IS NULL THEN 'NET_NEW' ELSE 'ALREADY_KNOWN' END AS bucket,
    COUNT(*)                                                        AS n
FROM post2024_hardtech p
LEFT JOIN registry_neqs r ON p.NEQ = r.NEQ
GROUP BY bucket
ORDER BY bucket;


/* ----------------------------------------------------------
   8. REVIEW QUEUE — TOP 50 HIGH-CONFIDENCE POST-2024 CANDIDATES
   Save this CSV, then cross-check names against Dealroom / HubSpot.
   Ordered by (keyword match strength, employee count desc,
   incorporation date desc) so the most likely real startups
   surface first.
   ---------------------------------------------------------- */

SELECT
    NEQ,
    NEQ_NORM,
    DATE_IMMATRICULATION,
    FORME_JURIDIQUE,
    HQ_CITY,
    N_EMPLOYES,
    EMP_MIN,
    CAE_CODE,
    PRODUCT_TIER,
    PRODUCT_SCORE,
    MATCHED_SIGNALS,
    -- first 200 chars of description for fast scanning
    LEFT(DESCRIPTION_RAW, 200) AS description_preview
FROM DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION
WHERE INCORPORATION_YEAR >= 2024
  AND IS_PRODUCT = TRUE
  AND NOT IS_SERVICE
  AND PRODUCT_TIER IN ('HIGH','MEDIUM')
  AND (
         MATCHED_SIGNALS ILIKE '%semiconductor%'
      OR MATCHED_SIGNALS ILIKE '%photonics%'
      OR MATCHED_SIGNALS ILIKE '%quantum%'
      OR MATCHED_SIGNALS ILIKE '%nanotech%'
      OR MATCHED_SIGNALS ILIKE '%robotics%'
      OR MATCHED_SIGNALS ILIKE '%drone%'
      OR MATCHED_SIGNALS ILIKE '%iot%'
      OR MATCHED_SIGNALS ILIKE '%aerospace%'
      OR MATCHED_SIGNALS ILIKE '%medtech%'
      OR MATCHED_SIGNALS ILIKE '%pharma%'
      OR MATCHED_SIGNALS ILIKE '%biotech%'
      OR MATCHED_SIGNALS ILIKE '%genomics%'
      OR MATCHED_SIGNALS ILIKE '%digital_health%'
      OR MATCHED_SIGNALS ILIKE '%cleantech%'
      )
ORDER BY PRODUCT_SCORE DESC, EMP_MIN DESC NULLS LAST, DATE_IMMATRICULATION DESC
LIMIT 50;


/* ----------------------------------------------------------
   END — expected grids:
   0  precondition             1 row
   1  tier volume              4-5 rows
   2  keyword-confirmed yearly 2-3 rows (2024, 2025, 2026)
   3  CAE code distribution    ~15 rows
   4  sub-category breakdown   14 rows
   5  confidence tier          3-4 rows
   6  top 25 HQ cities         ≤25 rows
   7  net-new vs known         2 rows
   8  top 50 review queue      ≤50 rows
   ---------------------------------------------------------- */

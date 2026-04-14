-- =============================================================================
-- 82_tech_enrichment.sql (NEW LOGIC, DROP-IN)
-- Keyword-only REF.TECHNOLOGY_KEYWORDS (no regex operators)
-- - Compile keywords into Snowflake-safe regex (handles Snowflake implicit anchoring)
-- - Match against SILVER.DRM_COMPANY_MATCH_TEXT_VW.MATCH_TEXT
-- - 1 row per company (LEFT JOIN)
-- =============================================================================
USE DATABASE DEV_QUEBECTECH;

-- -----------------------------------------------------------------------------
-- 0) Keyword -> regex compiler (shared)
-- NOTE: If 81_industry_enrichment.sql already created UTIL.KEYWORD_TO_REGEX,
-- this CREATE OR REPLACE is safe and keeps both scripts runnable independently.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION UTIL.KEYWORD_TO_REGEX(keyword STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
  CONCAT(
    '.*\\b',
    REGEXP_REPLACE(UTIL.NORMALIZE_TEXT_FOR_MATCHING(keyword), '\\s+', '\\\\s+'),
    '\\b.*'
  )
$$;

-- -----------------------------------------------------------------------------
-- 1) Compiled keyword view (tech)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW REF.TECHNOLOGY_KEYWORDS_COMPILED AS
SELECT
  TECHNOLOGY_LABEL,
  KEYWORD,
  WEIGHT,
  ACTIVE,
  NOTES,
  UTIL.KEYWORD_TO_REGEX(KEYWORD) AS KEYWORD_REGEX
FROM REF.TECHNOLOGY_KEYWORDS
WHERE ACTIVE;

-- -----------------------------------------------------------------------------
-- 2) Build technology signals (1 row per company)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE SILVER.DRM_TECHNOLOGY_SIGNALS_SILVER
COPY GRANTS
AS
WITH base_companies AS (
  SELECT DISTINCT DEALROOM_ID
  FROM SILVER.DRM_COMPANY_SILVER
),

matches AS (
  SELECT DISTINCT
    t.DEALROOM_ID,
    k.TECHNOLOGY_LABEL,
    k.KEYWORD,
    k.WEIGHT
  FROM SILVER.DRM_COMPANY_MATCH_TEXT_VW t
  JOIN REF.TECHNOLOGY_KEYWORDS_COMPILED k
    ON REGEXP_LIKE(t.MATCH_TEXT, k.KEYWORD_REGEX)
),

agg AS (
  SELECT
    DEALROOM_ID,
    TECHNOLOGY_LABEL,
    SUM(COALESCE(WEIGHT, 1)) AS TECH_SCORE,
    ARRAY_AGG(DISTINCT KEYWORD) AS MATCHED_KEYWORDS
  FROM matches
  GROUP BY DEALROOM_ID, TECHNOLOGY_LABEL
),

per_company AS (
  SELECT
    DEALROOM_ID,
    ARRAY_AGG(TECHNOLOGY_LABEL) WITHIN GROUP (ORDER BY TECH_SCORE DESC) AS TECHNOLOGY_LABELS,
    MAX_BY(TECHNOLOGY_LABEL, TECH_SCORE) AS TOP_TECHNOLOGY,
    MAX(TECH_SCORE) AS TOP_TECHNOLOGY_SCORE,
    TO_VARIANT(
      ARRAY_AGG(
        OBJECT_CONSTRUCT(
          'technology', TECHNOLOGY_LABEL,
          'score', TECH_SCORE,
          'keywords', MATCHED_KEYWORDS
        )
      ) WITHIN GROUP (ORDER BY TECH_SCORE DESC)
    ) AS TECHNOLOGY_MATCHES
  FROM agg
  GROUP BY DEALROOM_ID
)

SELECT
  b.DEALROOM_ID,
  p.TECHNOLOGY_LABELS,
  p.TOP_TECHNOLOGY,
  p.TOP_TECHNOLOGY_SCORE,
  p.TECHNOLOGY_MATCHES,
  CURRENT_TIMESTAMP() AS TECHNOLOGY_LABELED_AT
FROM base_companies b
LEFT JOIN per_company p
  ON b.DEALROOM_ID = p.DEALROOM_ID;

-- sanity
SELECT
  COUNT(*) AS N_ROWS,
  COUNT_IF(TECHNOLOGY_LABELS IS NOT NULL) AS N_WITH_TECH
FROM SILVER.DRM_TECHNOLOGY_SIGNALS_SILVER;

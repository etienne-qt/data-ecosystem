-- =============================================================================
-- 81_industry_enrichment.sql (NEW LOGIC, DROP-IN)
-- Keyword-only REF.INDUSTRY_KEYWORDS (no regex operators)
-- - Compile keywords into Snowflake-safe regex (handles Snowflake implicit anchoring)
-- - Match against SILVER.DRM_COMPANY_MATCH_TEXT_VW.MATCH_TEXT
-- - 1 row per company (LEFT JOIN)
-- =============================================================================
USE DATABASE DEV_QUEBECTECH;

-- -----------------------------------------------------------------------------
-- 0) Keyword -> regex compiler (shared)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION UTIL.KEYWORD_TO_REGEX(keyword STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
  -- MATCH_TEXT is produced by UTIL.NORMALIZE_TEXT_FOR_MATCHING (lowercase, punctuation->space)
  -- Snowflake REGEXP_LIKE is implicitly anchored, so wrap with .* ... .*
  -- Use \b boundaries and tolerate variable whitespace inside multi-word keywords.
  CONCAT(
    '.*\\b',
    REGEXP_REPLACE(UTIL.NORMALIZE_TEXT_FOR_MATCHING(keyword), '\\s+', '\\\\s+'),
    '\\b.*'
  )
$$;

-- -----------------------------------------------------------------------------
-- 1) Compiled keyword view (industry)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW REF.INDUSTRY_KEYWORDS_COMPILED AS
SELECT
  INDUSTRY_LABEL,
  KEYWORD,
  WEIGHT,
  ACTIVE,
  NOTES,
  UTIL.KEYWORD_TO_REGEX(KEYWORD) AS KEYWORD_REGEX
FROM REF.INDUSTRY_KEYWORDS
WHERE ACTIVE;

-- -----------------------------------------------------------------------------
-- 2) Build industry signals (1 row per company)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE SILVER.DRM_INDUSTRY_SIGNALS_SILVER
COPY GRANTS
AS
WITH base_companies AS (
  SELECT DISTINCT DEALROOM_ID
  FROM SILVER.DRM_COMPANY_SILVER
),

matches AS (
  SELECT DISTINCT
    t.DEALROOM_ID,
    k.INDUSTRY_LABEL,
    k.KEYWORD,
    k.WEIGHT
  FROM SILVER.DRM_COMPANY_MATCH_TEXT_VW t
  JOIN REF.INDUSTRY_KEYWORDS_COMPILED k
    ON REGEXP_LIKE(t.MATCH_TEXT, k.KEYWORD_REGEX)
),

agg AS (
  SELECT
    DEALROOM_ID,
    INDUSTRY_LABEL,
    SUM(COALESCE(WEIGHT, 1)) AS INDUSTRY_SCORE,
    ARRAY_AGG(DISTINCT KEYWORD) AS MATCHED_KEYWORDS
  FROM matches
  GROUP BY DEALROOM_ID, INDUSTRY_LABEL
),

per_company AS (
  SELECT
    DEALROOM_ID,
    ARRAY_AGG(INDUSTRY_LABEL) WITHIN GROUP (ORDER BY INDUSTRY_SCORE DESC) AS INDUSTRY_LABELS,
    MAX_BY(INDUSTRY_LABEL, INDUSTRY_SCORE) AS TOP_INDUSTRY,
    MAX(INDUSTRY_SCORE) AS TOP_INDUSTRY_SCORE,
    TO_VARIANT(
      ARRAY_AGG(
        OBJECT_CONSTRUCT(
          'industry', INDUSTRY_LABEL,
          'score', INDUSTRY_SCORE,
          'keywords', MATCHED_KEYWORDS
        )
      ) WITHIN GROUP (ORDER BY INDUSTRY_SCORE DESC)
    ) AS INDUSTRY_MATCHES
  FROM agg
  GROUP BY DEALROOM_ID
)

SELECT
  b.DEALROOM_ID,
  p.INDUSTRY_LABELS,
  p.TOP_INDUSTRY,
  p.TOP_INDUSTRY_SCORE,
  p.INDUSTRY_MATCHES,
  CURRENT_TIMESTAMP() AS INDUSTRY_LABELED_AT
FROM base_companies b
LEFT JOIN per_company p
  ON b.DEALROOM_ID = p.DEALROOM_ID;

-- sanity
SELECT
  COUNT(*) AS N_ROWS,
  COUNT_IF(INDUSTRY_LABELS IS NOT NULL) AS N_WITH_INDUSTRY
FROM SILVER.DRM_INDUSTRY_SIGNALS_SILVER;

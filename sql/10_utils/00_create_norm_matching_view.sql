-- =============================================================================
-- 06A_SILVER_COMPANY_MATCH_TEXT_VW.sql (DROP-IN)
-- =============================================================================
USE DATABASE DEV_QUEBECTECH;

CREATE OR REPLACE FUNCTION UTIL.NORMALIZE_TEXT_FOR_MATCHING(txt STRING)
RETURNS STRING
LANGUAGE JAVASCRIPT
AS
$$
  var txt = arguments[0];

  // Critical: never return undefined/null
  if (txt === null || txt === undefined) return '';

  var s = String(txt);

  // Accent fold
  var from = "ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÑñÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÝýÿ";
  var to   = "AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiNnOOOOOOooooooUUUUuuuuYyy";
  for (var i = 0; i < from.length; i++) {
    s = s.split(from.charAt(i)).join(to.charAt(i));
  }

  s = s.toLowerCase();

  // keep only [a-z0-9], turn others into spaces
  s = s.replace(/[^a-z0-9]+/g, ' ');

  // collapse whitespace
  s = s.replace(/\s+/g, ' ').trim();

  return s; // always a string
$$;


CREATE OR REPLACE VIEW SILVER.DRM_COMPANY_MATCH_TEXT_VW AS
WITH x AS (
  SELECT
    c.DEALROOM_ID,

    ARRAY_TO_STRING(
      ARRAY_CONSTRUCT_COMPACT(
        c.NAME,
        c.TAGLINE,
        c.LONG_DESCRIPTION,
        c.HQ_CITY,
        c.HQ_STATE,
        c.HQ_COUNTRY,
        c.INDUSTRIES_RAW,
        c.SUB_INDUSTRIES_RAW,
        c.TAGS_RAW,
        c.ALL_TAGS_RAW,
        c.TECHNOLOGIES_RAW,
        c.INVESTORS_NAMES_RAW,
        c.LEAD_INVESTORS_RAW,
        c.WEBSITE,
        c.WEBSITE_DOMAIN,
        c.COMPANY_STATUS
      ),
      ' '
    ) AS MATCH_TEXT_RAW
  FROM SILVER.DRM_COMPANY_SILVER c
)
SELECT
  DEALROOM_ID,
  UTIL.NORMALIZE_TEXT_FOR_MATCHING(COALESCE(MATCH_TEXT_RAW, '')) AS MATCH_TEXT,
  MATCH_TEXT_RAW
FROM x;


SELECT
  COUNT(*) AS n_rows,
  COUNT_IF(MATCH_TEXT IS NULL OR MATCH_TEXT = '') AS n_empty,
  MIN(LENGTH(MATCH_TEXT)) AS min_len,
  APPROX_PERCENTILE(LENGTH(MATCH_TEXT), 0.5) AS p50_len,
  MAX(LENGTH(MATCH_TEXT)) AS max_len
FROM SILVER.DRM_COMPANY_MATCH_TEXT_VW;



SELECT
  COUNT(*) AS n_rows,
  COUNT_IF(MATCH_TEXT IS NULL) AS n_null,
  COUNT_IF(MATCH_TEXT = '') AS n_empty,
  COUNT_IF(MATCH_TEXT IS NOT NULL AND LENGTH(MATCH_TEXT) < 20) AS n_too_short,
  APPROX_PERCENTILE(LENGTH(MATCH_TEXT), 0.5) AS p50_len
FROM SILVER.DRM_COMPANY_MATCH_TEXT_VW;


SELECT
  UTIL.NORMALIZE_TEXT_FOR_MATCHING(NULL)          AS norm_null,
  UTIL.NORMALIZE_TEXT_FOR_MATCHING('')            AS norm_empty,
  UTIL.NORMALIZE_TEXT_FOR_MATCHING('Hello, Inc.') AS norm_sample;


  WITH x AS (
  SELECT
    c.DEALROOM_ID,

    CONCAT_WS(' ',
      TO_VARCHAR(c.NAME),
      TO_VARCHAR(c.TAGLINE),
      TO_VARCHAR(c.LONG_DESCRIPTION),

      TO_VARCHAR(c.HQ_CITY),
      TO_VARCHAR(c.HQ_STATE),
      TO_VARCHAR(c.HQ_COUNTRY),

      TO_VARCHAR(c.INDUSTRIES_RAW),
      TO_VARCHAR(c.SUB_INDUSTRIES_RAW),
      TO_VARCHAR(c.TAGS_RAW),
      TO_VARCHAR(c.ALL_TAGS_RAW),
      TO_VARCHAR(c.TECHNOLOGIES_RAW),

      TO_VARCHAR(c.INVESTORS_NAMES_RAW),
      TO_VARCHAR(c.LEAD_INVESTORS_RAW),

      TO_VARCHAR(c.WEBSITE),
      TO_VARCHAR(c.WEBSITE_DOMAIN)
    ) AS RAW_CONCAT,

    UTIL.NORMALIZE_TEXT_FOR_MATCHING(
      CONCAT_WS(' ',
        TO_VARCHAR(c.NAME),
        TO_VARCHAR(c.TAGLINE),
        TO_VARCHAR(c.LONG_DESCRIPTION),

        TO_VARCHAR(c.HQ_CITY),
        TO_VARCHAR(c.HQ_STATE),
        TO_VARCHAR(c.HQ_COUNTRY),

        TO_VARCHAR(c.INDUSTRIES_RAW),
        TO_VARCHAR(c.SUB_INDUSTRIES_RAW),
        TO_VARCHAR(c.TAGS_RAW),
        TO_VARCHAR(c.ALL_TAGS_RAW),
        TO_VARCHAR(c.TECHNOLOGIES_RAW),

        TO_VARCHAR(c.INVESTORS_NAMES_RAW),
        TO_VARCHAR(c.LEAD_INVESTORS_RAW),

        TO_VARCHAR(c.WEBSITE),
        TO_VARCHAR(c.WEBSITE_DOMAIN)
      )
    ) AS NORM_TEXT
  FROM SILVER.DRM_COMPANY_SILVER c
)
SELECT
  COUNT(*) AS n_rows,
  COUNT_IF(RAW_CONCAT IS NULL) AS n_raw_null,
  COUNT_IF(RAW_CONCAT = '') AS n_raw_empty,
  COUNT_IF(NORM_TEXT IS NULL) AS n_norm_null,
  COUNT_IF(NORM_TEXT = '') AS n_norm_empty
FROM x;


WITH x AS (
  SELECT
    c.*,
    UTIL.NORMALIZE_TEXT_FOR_MATCHING(
      CONCAT_WS(' ',
        TO_VARCHAR(c.NAME),
        TO_VARCHAR(c.TAGLINE),
        TO_VARCHAR(c.LONG_DESCRIPTION),
        TO_VARCHAR(c.INDUSTRIES_RAW),
        TO_VARCHAR(c.TAGS_RAW),
        TO_VARCHAR(c.ALL_TAGS_RAW),
        TO_VARCHAR(c.TECHNOLOGIES_RAW),
        TO_VARCHAR(c.WEBSITE),
        TO_VARCHAR(c.WEBSITE_DOMAIN)
      )
    ) AS NORM_TEXT
  FROM SILVER.DRM_COMPANY_SILVER c
)
SELECT
  COUNT(*) AS n_null_rows,
  COUNT_IF(NAME IS NOT NULL) AS has_name,
  COUNT_IF(TAGLINE IS NOT NULL) AS has_tagline,
  COUNT_IF(LONG_DESCRIPTION IS NOT NULL) AS has_long_description,
  COUNT_IF(INDUSTRIES_RAW IS NOT NULL) AS has_industries_raw,
  COUNT_IF(TAGS_RAW IS NOT NULL) AS has_tags_raw,
  COUNT_IF(ALL_TAGS_RAW IS NOT NULL) AS has_all_tags_raw,
  COUNT_IF(TECHNOLOGIES_RAW IS NOT NULL) AS has_technologies_raw,
  COUNT_IF(WEBSITE_DOMAIN IS NOT NULL) AS has_domain
FROM x
WHERE NORM_TEXT IS NULL OR NORM_TEXT = '';

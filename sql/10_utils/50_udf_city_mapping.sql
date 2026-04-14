-- =============================================================================
-- 01_UTIL_NORMALIZATION.sql
-- =============================================================================
USE DATABASE DEV_QUEBECTECH;

CREATE OR REPLACE FUNCTION UTIL.CLEAN_CITY_KEY(city STRING)
RETURNS STRING
LANGUAGE JAVASCRIPT
AS
$$
  var city = arguments[0];
  if (city === null) return null;

  var s = String(city).trim();
  if (!s) return null;

  // If formatted like "Montreal, QC, Canada" keep first chunk
  var comma = s.indexOf(',');
  if (comma >= 0) s = s.substring(0, comma);

  // Remove parenthetical notes: "Québec (City)" -> "Québec"
  s = s.replace(/\(.*?\)/g, ' ');

  // Manual accent folding (safe for Snowflake JS UDF runtime)
  var from = "ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÑñÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÝýÿ";
  var to   = "AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiNnOOOOOOooooooUUUUuuuuYyy";
  for (var i = 0; i < from.length; i++) {
    s = s.split(from.charAt(i)).join(to.charAt(i));
  }

  s = s.toUpperCase();

  // Replace all non-alphanumeric with spaces
  s = s.replace(/[^A-Z0-9]+/g, ' ');

  // Collapse whitespace
  s = s.replace(/\s+/g, ' ').trim();

  return s.length ? s : null;
$$;


CREATE OR REPLACE FUNCTION UTIL.NORMALIZE_TEXT_FOR_MATCHING(txt STRING)
RETURNS STRING
LANGUAGE JAVASCRIPT
AS
$$
  var txt = arguments[0];
  if (txt === null) return '';

  var s = String(txt);

  // Accent fold (same mapping)
  var from = "ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÑñÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÝýÿ";
  var to   = "AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiNnOOOOOOooooooUUUUuuuuYyy";
  for (var i = 0; i < from.length; i++) {
    s = s.split(from.charAt(i)).join(to.charAt(i));
  }

  s = s.toLowerCase();

  // Keep only [a-z0-9], turn others into spaces
  s = s.replace(/[^a-z0-9]+/g, ' ');

  // Collapse whitespace
  s = s.replace(/\s+/g, ' ').trim();

  return s;
$$;


-- =============================================================================
-- 02_REF_CITY_REGION_MAPPING_NORM.sql
-- =============================================================================

CREATE OR REPLACE VIEW REF.CITY_REGION_MAPPING_NORM AS
SELECT
  UTIL.CLEAN_CITY_KEY("HQ City")              AS HQ_CITY_KEY,
  "HQ City"                                  AS HQ_CITY_REF,
  AGGLOMERATION,
  AGGLOMERATION_DETAILS,
  MRC,
  REGION_ADMIN
FROM REF.CITY_REGION_MAPPING
WHERE "HQ City" IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY UTIL.CLEAN_CITY_KEY("HQ City")
  ORDER BY
    IFF(AGGLOMERATION IS NULL, 1, 0),
    IFF(REGION_ADMIN IS NULL, 1, 0),
    LENGTH(COALESCE(AGGLOMERATION_DETAILS, '')) DESC,
    "HQ City"
) = 1;


-- Cities with multiple mappings (should be rare; investigate if high)
SELECT
  UTIL.CLEAN_CITY_KEY("HQ City") AS HQ_CITY_KEY,
  COUNT(*) AS n_rows
FROM REF.CITY_REGION_MAPPING
WHERE "HQ City" IS NOT NULL
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY n_rows DESC, HQ_CITY_KEY;

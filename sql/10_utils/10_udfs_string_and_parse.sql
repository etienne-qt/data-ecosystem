-- =============================================================================
-- File: 10_udfs_string_and_parse.sql
-- Purpose:
--   Utility functions used across pipeline steps to:
--     - normalize empty strings to NULL
--     - trim consistently
--     - parse numbers that contain commas/spaces
--     - parse dates safely
--
-- Notes:
--   - These UDFs are intentionally conservative.
--   - They do NOT attempt "smart" fixes beyond basic cleaning.
-- =============================================================================

use database DEV_QUEBECTECH;
use schema UTIL;

-- -----------------------------------------------------------------------------
-- NULLIF_BLANK
-- Converts: NULL -> NULL, '' -> NULL, '   ' -> NULL, otherwise trimmed string.
-- -----------------------------------------------------------------------------
create or replace function NULLIF_BLANK(s string)
returns string
language sql
as
$$
  nullif(trim(s), '')
$$;

-- -----------------------------------------------------------------------------
-- CLEAN_NUMBER_STR
-- Removes common formatting from numeric strings:
--   - commas
--   - spaces
-- Leaves minus sign and decimal point intact.
-- Example: ' 1,234.50 ' -> '1234.50'
-- -----------------------------------------------------------------------------
create or replace function CLEAN_NUMBER_STR(s string)
returns string
language sql
as
$$
  case
    when s is null then null
    else regexp_replace(trim(s), '[,\\s]', '')
  end
$$;

-- -----------------------------------------------------------------------------
-- TRY_TO_NUMBER_CLEAN
-- Attempts to parse a NUMBER from a messy numeric string.
-- Returns NULL if parsing fails.
-- -----------------------------------------------------------------------------
create or replace function TRY_TO_NUMBER_CLEAN(s string)
returns number(38, 6)
language sql
as
$$
  try_to_number(UTIL.CLEAN_NUMBER_STR(UTIL.NULLIF_BLANK(s)))
$$;

-- -----------------------------------------------------------------------------
-- TRY_TO_DOUBLE_CLEAN
-- Attempts to parse a DOUBLE from a string.
-- Useful for lat/long.
-- -----------------------------------------------------------------------------
create or replace function TRY_TO_DOUBLE_CLEAN(s string)
returns double
language sql
as
$$
  try_to_double(UTIL.NULLIF_BLANK(s))
$$;

-- -----------------------------------------------------------------------------
-- TRY_TO_DATE_ANY
-- Attempts to parse a DATE from a string.
-- This assumes Dealroom is exporting ISO-like dates.
-- If you discover a different format (e.g., DD/MM/YYYY), adjust here centrally.
-- -----------------------------------------------------------------------------
create or replace function TRY_TO_DATE_ANY(s string)
returns date
language sql
as
$$
  try_to_date(UTIL.NULLIF_BLANK(s))
$$;

-- -----------------------------------------------------------------------------
-- SPLIT_TO_ARRAY_VARIANT
-- Converts a delimited string into a VARIANT array of trimmed strings.
--
-- Example:
--   SPLIT_TO_ARRAY_VARIANT('FinTech; Payments', ';')
--     -> ["FinTech","Payments"]
--
-- Behavior:
--   - NULL / blank input -> NULL
--   - If delimiter not found -> single-element array
--   - Trims elements and drops empty items
--
-- Why JavaScript UDF:
--   Snowflake SQL UDF bodies cannot contain a FROM/FLATTEN query expression.
-- -----------------------------------------------------------------------------
create or replace function SPLIT_TO_ARRAY_VARIANT(s string, delim string)
returns variant
language javascript
as
$$
  if (s === null) return null;

  // normalize + treat blanks as null
  var str = String(s).trim();
  if (str.length === 0) return null;

  // default delimiter if not provided
  var d = (delim === null) ? ';' : String(delim);

  // split
  var parts = str.split(d);

  // trim + remove empties
  var out = [];
  for (var i = 0; i < parts.length; i++) {
    var p = String(parts[i]).trim();
    if (p.length > 0) out.push(p);
  }

  if (out.length === 0) return null;
  return out;
$$;


-- -----------------------------------------------------------------------------
-- SPLIT_TO_ARRAY_VARIANT_AUTO
-- Attempts delimiter detection:
--   - uses ';' if present
--   - else uses ',' if present
--   - else returns single-element array
-- -----------------------------------------------------------------------------
create or replace function SPLIT_TO_ARRAY_VARIANT_AUTO(s string)
returns variant
language javascript
as
$$
  if (s === null) return null;
  var str = String(s).trim();
  if (str.length === 0) return null;

  var delim = null;
  if (str.indexOf(';') >= 0) delim = ';';
  else if (str.indexOf(',') >= 0) delim = ',';

  if (delim === null) return [str];

  var parts = str.split(delim);
  var out = [];
  for (var i = 0; i < parts.length; i++) {
    var p = String(parts[i]).trim();
    if (p.length > 0) out.push(p);
  }
  return (out.length === 0) ? null : out;
$$;


select
  tags,
  UTIL.SPLIT_TO_ARRAY_VARIANT_AUTO(tags) as tags_arr
from DEV_QUEBECTECH.IMPORT.DRM_COMPANY_RAW
where tags is not null
limit 25;


CREATE OR REPLACE FUNCTION UTIL.NORMALIZE_DEALROOM_URL(u STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
  -- lower, trim, remove querystring/fragments, remove trailing slashes
  REGEXP_REPLACE(
    REGEXP_REPLACE(
      LOWER(TRIM(u)),
      '(\\?.*|#.*)$',
      ''
    ),
    '/+$',
    ''
  )
$$;

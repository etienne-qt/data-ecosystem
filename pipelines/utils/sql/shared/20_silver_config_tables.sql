-- =============================================================================
-- File: 20_silver_config_tables.sql
-- Location: /snowflake/sql/10_util/
-- Purpose:
--   Tiny reference tables used by SILVER logic.
-- =============================================================================

use database DEV_QUEBECTECH;
use schema UTIL;

-- Map letter grade to numeric score (ranking + thresholds).
create or replace table RATING_LETTER_TO_SCORE (
  RATING_LETTER string,
  RATING_SCORE number(38,6)
);

insert overwrite into RATING_LETTER_TO_SCORE values
  ('A+', 95), ('A', 85), ('B', 70), ('C', 50), ('D', 20);

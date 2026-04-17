-- =============================================================================
-- File: 95_smoke_tests_silver.sql
-- Location: /snowflake/pipelines/validation/tests/
-- Purpose:
--   Smoke tests for SILVER pipeline.
-- =============================================================================

use database DEV_QUEBECTECH;

-- Company SILVER should roughly match BRONZE distinct IDs
select
  (select count(distinct dealroom_id) from DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE) as bronze_ids,
  (select count(*) from DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER) as silver_company_rows;

-- Startup signals distribution
select
  count(*) as n_rows,
  count_if(rating_letter = 'A+') as n_a_plus,
  count_if(rating_letter = 'A') as n_a,
  count_if(rating_letter = 'B') as n_b,
  count_if(rating_letter = 'C') as n_c,
  count_if(rating_letter = 'D') as n_d,
  count_if(rating_letter is null) as n_null_rating
from DEV_QUEBECTECH.SILVER.DRM_STARTUP_SIGNALS_SILVER;

-- Startup classification coverage
select
  count(*) as n_rows,
  count_if(startup_status = 'startup') as n_startup,
  count_if(startup_status = 'non_startup') as n_non_startup,
  count_if(startup_status = 'uncertain') as n_uncertain,
  count_if(startup_status is null) as n_null_status
from DEV_QUEBECTECH.SILVER.DRM_STARTUP_CLASSIFICATION_SILVER;

-- Activity status coverage
select
  count(*) as n_rows,
  count_if(activity_status = 'active') as n_active,
  count_if(activity_status = 'inactive') as n_inactive,
  count_if(activity_status = 'unknown') as n_unknown,
  count_if(activity_status is null) as n_null_status
from DEV_QUEBECTECH.SILVER.DRM_ACTIVITY_STATUS_SILVER;

-- Review queue size
select
  review_type,
  count(*) as n_rows
from DEV_QUEBECTECH.SILVER.DRM_REVIEW_QUEUE_SILVER
group by 1
order by n_rows desc;

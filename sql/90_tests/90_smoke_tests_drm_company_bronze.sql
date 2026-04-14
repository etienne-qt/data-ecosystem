-- =============================================================================
-- File: 90_smoke_tests_drm_company_bronze.sql
-- Purpose:
--   Quick checks after running the MERGE to ensure:
--     - row counts are sane
--     - keys exist
--     - typing worked (lat/long, dates, amounts)
--   This is not a full data-quality framework yet; it's a fast guardrail.
-- =============================================================================

use database DEV_QUEBECTECH;

-- 1) How many rows in BRONZE?
select count(*) as bronze_rows
from DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE;

-- 2) Any null Dealroom IDs (should be 0)
select count(*) as null_ids
from DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE
where dealroom_id is null;

-- 3) Duplicate Dealroom IDs (should be 0 for current-state BRONZE)
select dealroom_id, count(*) as cnt
from DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE
group by 1
having count(*) > 1
order by cnt desc;

-- 4) Basic parse sanity checks
select
  count_if(latitude is not null) as has_lat,
  count_if(longitude is not null) as has_long,
  count_if(last_funding_date is not null) as has_last_funding_date,
  count_if(total_funding_usd_m is not null) as has_total_funding_usd_m
from DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE;

-- 5) Delimiter distribution (helps validate list parsing assumptions)
select
  parse_notes:"tags_delim"::string as tags_delim,
  count(*) as n
from DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE
group by 1
order by n desc;

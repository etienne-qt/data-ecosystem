-- =============================================================================
-- File: 20_merge_company_silver.sql
-- Location: /snowflake/sql/30_silver/
-- Purpose:
--   Populate SILVER.DRM_COMPANY_SILVER.
--
-- Note:
--   The classifier needs ALL_TAGS / TECHNOLOGIES / EACH_INVESTOR_TYPE / EACH_ROUND_TYPE / LEAD_INVESTORS.
--   If BRONZE doesn’t carry them yet, we pull them from latest IMPORT row as a bridge.
-- =============================================================================

use database DEV_QUEBECTECH;

merge into DEV_QUEBECTECH.SILVER.DRM_COMPANY_SILVER t
using (
  with latest_import as (
  select
    id as dealroom_id,
    website,
    tagline,
    long_description,
    industries,
    sub_industries,
    tags,
    all_tags,
    technologies,
    each_investor_type,
    each_round_type,
    investors_names,
    lead_investors,
    dealroom_signal_rating,

    -- NEW: maturity/age helpers from raw
    try_to_number(valuation_usd) as valuation_usd,
    historical_valuations_values_usd_m,
    loaded_at
  from DEV_QUEBECTECH.IMPORT.DRM_COMPANY_RAW
  qualify row_number() over (partition by id order by loaded_at desc) = 1
)

  select
    b.dealroom_id,
    b.loaded_at,

    b.name,
    b.dealroom_url,

    coalesce(b.website, li.website) as website,
    UTIL.DOMAIN_FROM_URL(coalesce(b.website, li.website)) as website_domain,

    coalesce(b.tagline, li.tagline) as tagline,
    coalesce(b.long_description, li.long_description) as long_description,

    coalesce(b.industries_raw, li.industries) as industries_raw,
    coalesce(b.sub_industries_raw, li.sub_industries) as sub_industries_raw,
    coalesce(b.tags_raw, li.tags) as tags_raw,
    li.all_tags as all_tags_raw,
    li.technologies as technologies_raw,

    li.each_investor_type as each_investor_type_raw,
    li.each_round_type as each_round_type_raw,
    coalesce(b.investors_names_raw, li.investors_names) as investors_names_raw,
    li.lead_investors as lead_investors_raw,
    li.valuation_usd as valuation_usd,
    li.historical_valuations_values_usd_m as historical_valuations_values_usd_m,


    b.hq_country,
    b.hq_state,
    b.hq_city,
    b.latitude,
    b.longitude,

    b.total_funding_usd_m,
    b.total_funding_eur_m,
    b.last_funding_date,
    b.first_funding_date,

    li.dealroom_signal_rating as dealroom_signal_rating_raw,
    try_to_number(li.dealroom_signal_rating) as dealroom_signal_rating_num,

    b.company_status,
    b.closing_date,

    b.launch_date,
    b.launch_month,
    b.launch_year,

    b.employees_range,
    b.employees_latest_number,

    b.tags_arr,
    b.industries_arr,
    b.sub_industries_arr,
    b.investors_names_arr,

    b.dealroom_signal_completeness,
    b.dealroom_signal_team_strength,
    b.dealroom_signal_growth_rate,
    b.dealroom_signal_timing,

    current_timestamp() as silver_loaded_at
  from DEV_QUEBECTECH.BRONZE.DRM_COMPANY_BRONZE b
  left join latest_import li
    on li.dealroom_id = b.dealroom_id
  where b.dealroom_id is not null
) s
on t.dealroom_id = s.dealroom_id

when matched and s.loaded_at >= t.loaded_at then update set
  t.loaded_at = s.loaded_at,
  t.name = s.name,
  t.dealroom_url = s.dealroom_url,
  t.website = s.website,
  t.website_domain = s.website_domain,
  t.tagline = s.tagline,
  t.long_description = s.long_description,
  t.industries_raw = s.industries_raw,
  t.sub_industries_raw = s.sub_industries_raw,
  t.tags_raw = s.tags_raw,
  t.all_tags_raw = s.all_tags_raw,
  t.technologies_raw = s.technologies_raw,
  t.each_investor_type_raw = s.each_investor_type_raw,
  t.investors_names_raw = s.investors_names_raw,
  t.lead_investors_raw = s.lead_investors_raw,
  t.hq_country = s.hq_country,
  t.hq_state = s.hq_state,
  t.hq_city = s.hq_city,
  t.latitude = s.latitude,
  t.longitude = s.longitude,
  t.total_funding_usd_m = s.total_funding_usd_m,
  t.total_funding_eur_m = s.total_funding_eur_m,
  t.last_funding_date = s.last_funding_date,
  t.first_funding_date = s.first_funding_date,
  t.dealroom_signal_rating_raw = s.dealroom_signal_rating_raw,
  t.dealroom_signal_rating_num = s.dealroom_signal_rating_num,
  t.company_status = s.company_status,
  t.closing_date = s.closing_date,
  t.launch_date = s.launch_date,
  t.launch_month = s.launch_month,
  t.launch_year = s.launch_year,
  t.valuation_usd = s.valuation_usd,
  t.historical_valuations_values_usd_m = s.historical_valuations_values_usd_m,
  t.each_round_type_raw = s.each_round_type_raw,
  t.employees_range = s.employees_range,
  t.employees_latest_number = s.employees_latest_number,
  t.tags_arr = s.tags_arr,
  t.industries_arr = s.industries_arr,
  t.sub_industries_arr = s.sub_industries_arr,
  t.investors_names_arr = s.investors_names_arr,
  t.dealroom_signal_completeness = s.dealroom_signal_completeness,
  t.dealroom_signal_team_strength = s.dealroom_signal_team_strength,
  t.dealroom_signal_growth_rate = s.dealroom_signal_growth_rate,
  t.dealroom_signal_timing = s.dealroom_signal_timing,
  t.silver_loaded_at = s.silver_loaded_at

when not matched then insert (
  dealroom_id, loaded_at,
  name, dealroom_url, website, website_domain,
  tagline, long_description,
  industries_raw, sub_industries_raw, tags_raw, all_tags_raw, technologies_raw,
  each_investor_type_raw, each_round_type_raw, investors_names_raw, lead_investors_raw,
  hq_country, hq_state, hq_city, latitude, longitude,
  total_funding_usd_m, total_funding_eur_m, last_funding_date, first_funding_date,
  dealroom_signal_rating_raw, dealroom_signal_rating_num,
  company_status, closing_date, launch_date, launch_month, launch_year,
  valuation_usd, historical_valuations_values_usd_m,
  employees_range, employees_latest_number,
  tags_arr, industries_arr, sub_industries_arr, investors_names_arr,
  dealroom_signal_completeness, dealroom_signal_team_strength, dealroom_signal_growth_rate, dealroom_signal_timing,
  silver_loaded_at
) values (
  s.dealroom_id, s.loaded_at,
  s.name, s.dealroom_url, s.website, s.website_domain,
  s.tagline, s.long_description,
  s.industries_raw, s.sub_industries_raw, s.tags_raw, s.all_tags_raw, s.technologies_raw,
  s.each_investor_type_raw, s.each_round_type_raw, s.investors_names_raw, s.lead_investors_raw,
  s.hq_country, s.hq_state, s.hq_city, s.latitude, s.longitude,
  s.total_funding_usd_m, s.total_funding_eur_m, s.last_funding_date, s.first_funding_date,
  s.dealroom_signal_rating_raw, s.dealroom_signal_rating_num,
  s.company_status, s.closing_date, 
  s.launch_date, s.launch_month, s.launch_year,
  s.valuation_usd, s.historical_valuations_values_usd_m,
  s.employees_range, s.employees_latest_number,
  s.tags_arr, s.industries_arr, s.sub_industries_arr, s.investors_names_arr,
  s.dealroom_signal_completeness, s.dealroom_signal_team_strength, s.dealroom_signal_growth_rate, s.dealroom_signal_timing,
  s.silver_loaded_at
);








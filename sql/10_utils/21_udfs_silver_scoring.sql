-- =============================================================================
-- File: 21_udfs_silver_scoring.sql
-- Purpose:
--   UDFs used by SILVER transforms:
--     - parse/normalize URLs/domains
--     - compute startup_score + reason payload
--     - compute activity_score + reason payload
--
-- Notes:
--   These are deliberately simple v1 rules.
--   You'll improve them as you review edge cases.
-- =============================================================================

use database DEV_QUEBECTECH;
use schema UTIL;

-- -----------------------------------------------------------------------------
-- DOMAIN_FROM_URL
-- Extracts host from a URL and lowercases it.
-- Example: https://www.Example.com/path -> example.com
-- Returns NULL if input is blank/unparseable.
-- -----------------------------------------------------------------------------
create or replace function DOMAIN_FROM_URL(u string)
returns string
language javascript
as
$$
  if (u === null) return null;
  var s = String(u).trim();
  if (s.length === 0) return null;

  // Ensure scheme exists for URL parsing
  if (!s.match(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//)) {
    s = "https://" + s;
  }

  try {
    var host = new URL(s).hostname.toLowerCase();
    // strip leading www.
    host = host.replace(/^www\./, "");
    return host.length ? host : null;
  } catch (e) {
    return null;
  }
$$;

-- -----------------------------------------------------------------------------
-- GET_WEIGHT helper (SQL UDF)
-- -----------------------------------------------------------------------------
create or replace function GET_WEIGHT(weight_name string)
returns number(38,6)
language sql
as
$$
  (
    select weight_value
    from DEV_QUEBECTECH.UTIL.STARTUP_SCORE_WEIGHTS
    where STARTUP_SCORE_WEIGHTS.weight_name = weight_name
  )
$$;

-- -----------------------------------------------------------------------------
-- GET_THRESHOLD helper (SQL UDF)
-- -----------------------------------------------------------------------------
create or replace function GET_THRESHOLD(threshold_name string)
returns number(38,6)
language sql
as
$$
  (
    select threshold_value
    from DEV_QUEBECTECH.UTIL.ACTIVITY_THRESHOLDS
    where ACTIVITY_THRESHOLDS.threshold_name = threshold_name
  )
$$;


-- -----------------------------------------------------------------------------
-- STARTUP_SCORE_V1
-- Inputs are BRONZE columns.
-- Outputs a numeric score 0-100 (approx).
--
-- Scoring signals (v1):
--   - funding total (strong)
--   - funding recency (medium)
--   - small employees range/number (medium)
--   - dealroom signals (medium)
--   - has website (light)
--
-- NOTE: This is deliberately not using "industries/tags" yet to avoid taxonomy noise.
-- -----------------------------------------------------------------------------
create or replace function STARTUP_SCORE_V1(
  total_funding_usd_m number(38,6),
  last_funding_date date,
  employees_latest_number number(38,0),
  employees_range string,
  dealroom_signal_completeness number(38,6),
  dealroom_signal_team_strength number(38,6),
  dealroom_signal_growth_rate number(38,6),
  website string
)
returns number(38,6)
language sql
as
$$
  least(100,
    -- Funding magnitude
    iff(total_funding_usd_m >= 50, UTIL.GET_WEIGHT('W_FUNDING_USD'),
      iff(total_funding_usd_m >= 10, UTIL.GET_WEIGHT('W_FUNDING_USD') * 0.75,
        iff(total_funding_usd_m >= 1, UTIL.GET_WEIGHT('W_FUNDING_USD') * 0.45, 0)
      )
    )
    +
    -- Funding recency
    iff(last_funding_date is not null and last_funding_date >= dateadd(year, -3, current_date()),
      UTIL.GET_WEIGHT('W_RECENT_FUNDING'), 0
    )
    +
    -- Employees small-ish (startups tend to be smaller; imperfect but useful)
    iff(employees_latest_number is not null and employees_latest_number between 1 and 250,
      UTIL.GET_WEIGHT('W_EMPLOYEES_SMALL'),
      iff(employees_range is not null and regexp_like(employees_range, '^(0-9|1[0-9]{0,2}|2[0-4][0-9]|250)'),
        UTIL.GET_WEIGHT('W_EMPLOYEES_SMALL') * 0.7, 0
      )
    )
    +
    -- Dealroom signals (scaled: they may be strings sometimes; assume numeric already in BRONZE)
    iff(dealroom_signal_completeness is not null,
      UTIL.GET_WEIGHT('W_DEALROOM_SIGNAL') * least(1, greatest(0, dealroom_signal_completeness / 100)), 0
    )
    +
    iff(website is not null, UTIL.GET_WEIGHT('W_HAS_WEBSITE'), 0)
  )
$$;

-- -----------------------------------------------------------------------------
-- STARTUP_REASON_V1
-- Returns a VARIANT object describing which signals contributed.
-- -----------------------------------------------------------------------------
create or replace function STARTUP_REASON_V1(
  total_funding_usd_m number(38,6),
  last_funding_date date,
  employees_latest_number number(38,0),
  employees_range string,
  dealroom_signal_completeness number(38,6),
  website string
)
returns variant
language sql
as
$$
  to_variant(
    object_construct(
      'funding_usd_m', total_funding_usd_m,
      'has_recent_funding', iff(last_funding_date is not null and last_funding_date >= dateadd(year, -3, current_date()), true, false),
      'employees_latest_number', employees_latest_number,
      'employees_range', employees_range,
      'signal_completeness', dealroom_signal_completeness,
      'has_website', iff(website is not null, true, false)
    )
  )
$$;




-- -----------------------------------------------------------------------------
-- ACTIVITY_SCORE_V1
-- Activity is a different question than startup-ness.
-- Signals (v1):
--   - explicit company_status / closing_date
--   - website presence
--   - funding recency
--
-- Output: 0-100, higher means more likely active.
-- -----------------------------------------------------------------------------
create or replace function ACTIVITY_SCORE_V1(
  company_status string,
  closing_date date,
  website string,
  last_funding_date date
)
returns number(38,6)
language sql
as
$$
  least(100,
    -- Hard negatives
    iff(closing_date is not null, 0,
      iff(company_status is not null and lower(company_status) in ('closed','bankrupt','acquired','inactive'),
        10,  -- "acquired" can be active; we treat as low but not zero in v1
        50   -- baseline unknown
      )
    )
    +
    iff(website is not null, 20, 0)
    +
    iff(last_funding_date is not null and last_funding_date >= dateadd(year, -UTIL.GET_THRESHOLD('FUNDING_RECENT_YEARS'), current_date()), 30, 0)
  )
$$;

create or replace function ACTIVITY_REASON_V1(
  company_status string,
  closing_date date,
  website string,
  last_funding_date date
)
returns variant
language sql
as
$$
  to_variant(
    object_construct(
      'company_status', company_status,
      'closing_date', closing_date,
      'has_website', iff(website is not null, true, false),
      'has_recent_funding', iff(last_funding_date is not null and last_funding_date >= dateadd(year, -UTIL.GET_THRESHOLD('FUNDING_RECENT_YEARS'), current_date()), true, false)
    )
  )
$$;


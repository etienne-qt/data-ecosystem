-- =============================================================================
-- File: 11_udf_domain_from_url.sql
-- Location: /snowflake/sql/10_util/
-- Purpose:
--   Extract domain/host from a URL (resilient to missing scheme).
-- =============================================================================

use database DEV_QUEBECTECH;
use schema UTIL;

create or replace function DEV_QUEBECTECH.UTIL.DOMAIN_FROM_URL(url string)
returns string
language javascript
as
$$
  var u = arguments[0];
  if (u === null || u === undefined) return null;

  var s = String(u).trim();
  if (s.length === 0) return null;

  // Remove scheme if present
  s = s.replace(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//, '');

  // Remove credentials if present (user:pass@host)
  s = s.replace(/^[^@]+@/, '');

  // Host is up to first / ? # :
  var m = s.match(/^([^\/\?#:]+)/);
  if (!m || !m[1]) return null;

  var host = m[1].toLowerCase();

  // Strip leading www.
  host = host.replace(/^www\./, '');

  // Basic sanity: must contain at least one dot OR be localhost-style
  if (host.length === 0) return null;

  return host;
$$;

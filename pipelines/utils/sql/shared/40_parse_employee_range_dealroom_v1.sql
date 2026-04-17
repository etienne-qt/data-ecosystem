-- -----------------------------------------------------------------------------
-- UTIL.PARSE_EMPLOYEES_RANGE_DEALROOM_V1
-- Parses Dealroom employee fields (range + numeric estimate) into a structured VARIANT.
--
-- Inputs:
--   emp_range: e.g. '11-50', '1001-5000', '10000+'
--   emp_count: numeric estimate if present
--
-- Output VARIANT fields:
--   employees_min, employees_max, employees_est, employees_ge_1000, parse_reason, range_raw
-- -----------------------------------------------------------------------------
USE DATABASE DEV_QUEBECTECH;
USE SCHEMA UTIL;

CREATE OR REPLACE FUNCTION UTIL.PARSE_EMPLOYEES_RANGE_DEALROOM_V1(emp_range STRING, emp_count FLOAT)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
AS
$$
/**
 * Snowflake JS UDF notes:
 * - Use arguments[] (parameter names can be unreliable)
 * - Use FLOAT for numeric interoperability
 */

function toNum(x) {
  if (x === null || x === undefined) return null;
  if (typeof x === 'number') return x;
  let s = String(x).trim().toLowerCase();
  if (!s || s === 'nan' || s === 'none' || s === 'null') return null;
  s = s.replace(/,/g, '').replace(/\+/g, '').trim();
  const n = parseFloat(s);
  return isNaN(n) ? null : n;
}

const rangeRaw = arguments[0];
const empCount = toNum(arguments[1]);

let minV = null;
let maxV = null;
let reason = null;

if (rangeRaw !== null && rangeRaw !== undefined) {
  const r = String(rangeRaw).trim();

  // Case: "10000+"
  if (r.includes('+')) {
    minV = toNum(r);
    maxV = null;
    reason = "range_plus";
  }
  // Case: "11-50"
  else if (r.includes('-')) {
    const parts = r.split('-', 2).map(p => p.trim());
    minV = toNum(parts[0]);
    maxV = toNum(parts[1]);
    reason = "range_hyphen";
  }
  else {
    // Case: "1200" as a string
    minV = toNum(r);
    maxV = toNum(r);
    reason = "range_single_number";
  }
} else {
  reason = "range_missing";
}

// Estimate: prefer numeric emp_count, otherwise midpoint when available
let est = empCount;
if (est === null) {
  if (minV !== null && maxV !== null) est = (minV + maxV) / 2.0;
  else if (minV !== null) est = minV;
}

// >= 1000 rule: if any available signal crosses 1000
const ge1000 =
  (empCount !== null && empCount >= 1000) ||
  (maxV !== null && maxV >= 1000) ||
  (minV !== null && minV >= 1000);

return {
  range_raw: rangeRaw,
  employees_count: empCount,
  employees_min: minV,
  employees_max: maxV,
  employees_est: est,
  employees_ge_1000: ge1000,
  parse_reason: reason
};
$$;

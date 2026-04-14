/* ============================================================
   Updated for new pipeline objects:
   - clusters:        DEV_QUEBECTECH.UTIL.T_CLUSTERS  (includes HUBSPOT nodes)
   - golden:          DEV_QUEBECTECH.UTIL.T_CLUSTER_GOLDEN  (TRANSIENT)
   - safety gate:     DEV_QUEBECTECH.UTIL.T_CLUSTER_FLAGS   (TRANSIENT)
   - hs clean view:   DEV_QUEBECTECH.UTIL.V_HS_CLEAN

   Change vs old:
   - only push enrichments for SAFE clusters (FLAG_ANY_CONFLICT = 0)
   - keep "fill only empty properties" behavior
   ============================================================ */

CREATE OR REPLACE VIEW DEV_QUEBECTECH.UTIL.V_PUSH_HS_ENRICH AS
WITH hs AS (
  SELECT * FROM DEV_QUEBECTECH.UTIL.V_HS_CLEAN
),
hc AS (
  SELECT
    c.CLUSTER_ID,
    TRY_TO_NUMBER(c.SRC_ID) AS HS_COMPANY_ID
  FROM DEV_QUEBECTECH.UTIL.T_CLUSTERS c
  WHERE c.SRC = 'HUBSPOT'
),
g AS (
  SELECT * FROM DEV_QUEBECTECH.UTIL.T_CLUSTER_GOLDEN
),
f AS (
  SELECT CLUSTER_ID
  FROM DEV_QUEBECTECH.UTIL.T_CLUSTER_FLAGS
  WHERE FLAG_ANY_CONFLICT = 0
)
SELECT
  hs.HS_COMPANY_ID,

  /* suggestions (only when target is empty) */
  IFF(hs.HS_NEQ_NORM IS NULL AND g.GOLD_NEQ IS NOT NULL, g.GOLD_NEQ, NULL) AS SUGGEST_NEQ,

  IFF(
    COALESCE(hs.HS_DOMAIN_NORM, hs.HS_DOMAIN_FROM_WEBSITE) IS NULL
    AND g.GOLD_DOMAIN IS NOT NULL,
    g.GOLD_DOMAIN,
    NULL
  ) AS SUGGEST_DOMAIN,

  IFF(
    COALESCE(hs.HS_LINKEDIN_ID_NORM, hs.HS_LINKEDIN_NORM) IS NULL
    AND g.GOLD_LINKEDIN IS NOT NULL,
    g.GOLD_LINKEDIN,
    NULL
  ) AS SUGGEST_LINKEDIN,

  /* cluster for traceability */
  hc.CLUSTER_ID,

  /* convenience: include current values */
  hs.HS_NAME_RAW,
  hs.HS_NEQ_RAW,
  hs.HS_DOMAIN_RAW,
  hs.HS_WEBSITE_RAW,
  hs.HS_LINKEDIN_RAW

FROM hc
JOIN f
  ON f.CLUSTER_ID = hc.CLUSTER_ID
JOIN hs
  ON hs.HS_COMPANY_ID = hc.HS_COMPANY_ID
JOIN g
  ON g.CLUSTER_ID = hc.CLUSTER_ID
WHERE
  /* keep only rows where at least one suggestion exists */
  (hs.HS_NEQ_NORM IS NULL AND g.GOLD_NEQ IS NOT NULL)
  OR (COALESCE(hs.HS_DOMAIN_NORM, hs.HS_DOMAIN_FROM_WEBSITE) IS NULL AND g.GOLD_DOMAIN IS NOT NULL)
  OR (COALESCE(hs.HS_LINKEDIN_ID_NORM, hs.HS_LINKEDIN_NORM) IS NULL AND g.GOLD_LINKEDIN IS NOT NULL)
;

/* ============================================================
   SMOKE TESTS — Consolidated Company Registry Pipeline
   ============================================================
   Run after each pipeline execution to validate data quality.
   Each query is self-contained and labeled for easy reference.
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA UTIL;

------------------------------------------------------------
-- TEST 1: Row count by source in T_ENTITIES
------------------------------------------------------------
SELECT '1. ENTITY_COUNTS_BY_SOURCE' AS TEST, SRC, COUNT(*) AS N
FROM DEV_QUEBECTECH.UTIL.T_ENTITIES
GROUP BY SRC
ORDER BY N DESC;

------------------------------------------------------------
-- TEST 2: Edge count by match type and source pair
------------------------------------------------------------
SELECT '2. EDGE_COUNTS' AS TEST, SRC_A, SRC_B, MATCH_TYPE, COUNT(*) AS N
FROM DEV_QUEBECTECH.UTIL.T_EDGES_ALL_DEDUP
GROUP BY SRC_A, SRC_B, MATCH_TYPE
ORDER BY SRC_A, SRC_B, MATCH_TYPE;

------------------------------------------------------------
-- TEST 3: Cluster size distribution by SOURCE_COUNT
------------------------------------------------------------
SELECT '3. CLUSTER_SIZE_DISTRIBUTION' AS TEST,
  SOURCE_COUNT,
  COUNT(*) AS N_CLUSTERS,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT
FROM DEV_QUEBECTECH.UTIL.T_CLUSTER_GOLDEN
GROUP BY SOURCE_COUNT
ORDER BY SOURCE_COUNT;

------------------------------------------------------------
-- TEST 4: Conflict rate (% of clusters with FLAG_ANY_CONFLICT)
------------------------------------------------------------
SELECT '4. CONFLICT_RATE' AS TEST,
  COUNT(*)                                          AS TOTAL_CLUSTERS,
  SUM(FLAG_ANY_CONFLICT)                            AS CONFLICTED,
  ROUND(100.0 * SUM(FLAG_ANY_CONFLICT) / COUNT(*), 2) AS CONFLICT_PCT,
  SUM(FLAG_NEQ_CONFLICT)                            AS NEQ_CONFLICTS,
  SUM(FLAG_DOMAIN_CONFLICT)                         AS DOMAIN_CONFLICTS,
  SUM(FLAG_LINKEDIN_CONFLICT)                       AS LINKEDIN_CONFLICTS
FROM DEV_QUEBECTECH.UTIL.T_CLUSTER_GOLDEN;

------------------------------------------------------------
-- TEST 5: Golden record completeness
------------------------------------------------------------
SELECT '5. GOLDEN_COMPLETENESS' AS TEST,
  COUNT(*)                                                       AS TOTAL,
  ROUND(100.0 * COUNT(GOLD_NEQ)           / COUNT(*), 2)        AS PCT_WITH_NEQ,
  ROUND(100.0 * COUNT(GOLD_DOMAIN)        / COUNT(*), 2)        AS PCT_WITH_DOMAIN,
  ROUND(100.0 * COUNT(GOLD_LINKEDIN)      / COUNT(*), 2)        AS PCT_WITH_LINKEDIN,
  ROUND(100.0 * COUNT(GOLD_REGISTRY_NEQ)  / COUNT(*), 2)        AS PCT_WITH_REGISTRY,
  ROUND(100.0 * COUNT(GOLD_PITCHBOOK_ID)  / COUNT(*), 2)        AS PCT_WITH_PITCHBOOK,
  ROUND(100.0 * COUNT(GOLD_DEALROOM_ID)   / COUNT(*), 2)        AS PCT_WITH_DEALROOM,
  ROUND(100.0 * COUNT(GOLD_HARMONIC_ID)   / COUNT(*), 2)        AS PCT_WITH_HARMONIC,
  ROUND(100.0 * COUNT(GOLD_HUBSPOT_ID)    / COUNT(*), 2)        AS PCT_WITH_HUBSPOT
FROM DEV_QUEBECTECH.UTIL.T_CLUSTER_GOLDEN;

------------------------------------------------------------
-- TEST 6: Duplicate check — no duplicate GOLD_NEQ or GOLD_DOMAIN
--         in safe (non-conflicted) clusters
------------------------------------------------------------
SELECT '6A. DUPLICATE_NEQ_IN_SAFE_CLUSTERS' AS TEST, GOLD_NEQ, COUNT(*) AS N
FROM DEV_QUEBECTECH.UTIL.T_CLUSTER_GOLDEN
WHERE FLAG_ANY_CONFLICT = 0
  AND GOLD_NEQ IS NOT NULL
GROUP BY GOLD_NEQ
HAVING COUNT(*) > 1
ORDER BY N DESC
LIMIT 20;

SELECT '6B. DUPLICATE_DOMAIN_IN_SAFE_CLUSTERS' AS TEST, GOLD_DOMAIN, COUNT(*) AS N
FROM DEV_QUEBECTECH.UTIL.T_CLUSTER_GOLDEN
WHERE FLAG_ANY_CONFLICT = 0
  AND GOLD_DOMAIN IS NOT NULL
GROUP BY GOLD_DOMAIN
HAVING COUNT(*) > 1
ORDER BY N DESC
LIMIT 20;

------------------------------------------------------------
-- TEST 7: Regression — HS-DRM cluster count vs baseline
--         Compare total HS+DRM entities in clusters
--         (should not decrease significantly run-over-run)
------------------------------------------------------------
SELECT '7. HS_DRM_REGRESSION' AS TEST,
  COUNT(DISTINCT CLUSTER_ID) AS HS_DRM_CLUSTER_COUNT,
  COUNT(*)                   AS HS_DRM_ENTITY_COUNT
FROM DEV_QUEBECTECH.UTIL.T_CLUSTERS
WHERE SRC IN ('HUBSPOT', 'DEALROOM');

------------------------------------------------------------
-- TEST 8: T_COMPANY_REGISTRY row count and freshness
------------------------------------------------------------
SELECT '8. REGISTRY_TABLE_STATUS' AS TEST,
  COUNT(*)                                       AS TOTAL_ROWS,
  SUM(IFF(FLAG_ANY_CONFLICT, 1, 0))              AS CONFLICTED_ROWS,
  MIN(LAST_PIPELINE_RUN_AT)                      AS OLDEST_RUN,
  MAX(LAST_PIPELINE_RUN_AT)                      AS LATEST_RUN
FROM DEV_QUEBECTECH.UTIL.T_COMPANY_REGISTRY;

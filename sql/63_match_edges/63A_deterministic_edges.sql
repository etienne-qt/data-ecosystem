/* ============================================================
   DETERMINISTIC EDGES — Generic SRC < SRC Cross-Join
   ============================================================
   Match priority: DOMAIN (0.95) → LINKEDIN (0.95) → NEQ (1.0)
   Uses a.SRC < b.SRC to avoid duplicate pairs and self-joins.
   Source-count-agnostic: adding a new source to T_ENTITIES
   automatically generates edges without code changes here.
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA UTIL;

CREATE OR REPLACE TRANSIENT TABLE DEV_QUEBECTECH.UTIL.T_EDGES_ALL_RAW AS

-- DOMAIN matches (score 0.95)
SELECT
  a.SRC    AS SRC_A, a.SRC_ID AS ID_A,
  b.SRC    AS SRC_B, b.SRC_ID AS ID_B,
  'DOMAIN' AS MATCH_TYPE,
  0.95::FLOAT AS SCORE
FROM DEV_QUEBECTECH.UTIL.T_ENTITIES a
JOIN DEV_QUEBECTECH.UTIL.T_ENTITIES b
  ON  a.SRC < b.SRC
  AND a.DOMAIN_NORM IS NOT NULL
  AND a.DOMAIN_NORM = b.DOMAIN_NORM

UNION ALL

-- LINKEDIN matches (score 0.95)
SELECT
  a.SRC,    a.SRC_ID,
  b.SRC,    b.SRC_ID,
  'LINKEDIN',
  0.95::FLOAT
FROM DEV_QUEBECTECH.UTIL.T_ENTITIES a
JOIN DEV_QUEBECTECH.UTIL.T_ENTITIES b
  ON  a.SRC < b.SRC
  AND a.LINKEDIN_NORM IS NOT NULL
  AND a.LINKEDIN_NORM = b.LINKEDIN_NORM

UNION ALL

-- NEQ matches (score 1.0)
SELECT
  a.SRC,    a.SRC_ID,
  b.SRC,    b.SRC_ID,
  'NEQ',
  1.0::FLOAT
FROM DEV_QUEBECTECH.UTIL.T_ENTITIES a
JOIN DEV_QUEBECTECH.UTIL.T_ENTITIES b
  ON  a.SRC < b.SRC
  AND a.NEQ_NORM IS NOT NULL
  AND a.NEQ_NORM = b.NEQ_NORM
;

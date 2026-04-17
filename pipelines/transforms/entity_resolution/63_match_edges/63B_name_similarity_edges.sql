/* ============================================================
   NAME SIMILARITY EDGES — Generic Unmatched Fallback
   ============================================================
   Only creates fuzzy name edges for entities that have NO
   deterministic match (domain/linkedin/neq) from 63A.
   Uses SRC < SRC pattern, blocked by (P4, TOK1) with
   stopword filtering. Capped at top 3 per entity.
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA UTIL;

-- Stopwords (shared with clusters_enhanced.sql)
CREATE OR REPLACE TEMP TABLE DEV_QUEBECTECH.UTIL.T_STOPWORDS (W STRING);
INSERT INTO DEV_QUEBECTECH.UTIL.T_STOPWORDS (W) VALUES
  ('the'),('les'),('la'),('le'),('de'),('des'),('du'),
  ('services'),('service'),('solutions'),('solution'),
  ('groupe'),('group'),('technologies'),('technology'),
  ('inc'),('corp'),('company');

-- Find entities with NO deterministic edge (neither side A nor side B)
INSERT INTO DEV_QUEBECTECH.UTIL.T_EDGES_ALL_RAW
WITH
det_nodes AS (
  SELECT DISTINCT SRC_A AS SRC, ID_A AS SRC_ID
  FROM DEV_QUEBECTECH.UTIL.T_EDGES_ALL_RAW
  UNION
  SELECT DISTINCT SRC_B, ID_B
  FROM DEV_QUEBECTECH.UTIL.T_EDGES_ALL_RAW
),

unmatched AS (
  SELECT e.*
  FROM DEV_QUEBECTECH.UTIL.T_ENTITIES e
  LEFT JOIN det_nodes d
    ON d.SRC = e.SRC AND d.SRC_ID = e.SRC_ID
  WHERE d.SRC_ID IS NULL
    AND e.NAME_NORM IS NOT NULL
    AND e.P4 IS NOT NULL
    AND e.TOK1 IS NOT NULL
    AND LENGTH(e.TOK1) >= 3
    AND e.TOK1 NOT IN (SELECT W FROM DEV_QUEBECTECH.UTIL.T_STOPWORDS)
),

cand AS (
  SELECT
    a.SRC    AS SRC_A, a.SRC_ID AS ID_A,
    b.SRC    AS SRC_B, b.SRC_ID AS ID_B,
    DEV_QUEBECTECH.UTIL.NAME_SIM(a.NAME_NORM, b.NAME_NORM)::FLOAT AS SCORE
  FROM unmatched a
  JOIN unmatched b
    ON  a.SRC < b.SRC
    AND a.P4   = b.P4
    AND a.TOK1 = b.TOK1
)

SELECT
  SRC_A, ID_A,
  SRC_B, ID_B,
  'NAME_SIM' AS MATCH_TYPE,
  SCORE
FROM cand
WHERE SCORE >= 0.90
QUALIFY ROW_NUMBER() OVER (PARTITION BY SRC_A, ID_A ORDER BY SCORE DESC) <= 3
;

-- Deduplicate all edges
CREATE OR REPLACE TRANSIENT TABLE DEV_QUEBECTECH.UTIL.T_EDGES_ALL_DEDUP AS
SELECT DISTINCT SRC_A, ID_A, SRC_B, ID_B, MATCH_TYPE, SCORE
FROM DEV_QUEBECTECH.UTIL.T_EDGES_ALL_RAW
;

ALTER TABLE DEV_QUEBECTECH.UTIL.T_EDGES_ALL_DEDUP
  CLUSTER BY (SRC_A, SRC_B, ID_A, ID_B);

/* ----------------------------------------------------------
   Backward-compat aliases for push-list SQL (67/68)
   ---------------------------------------------------------- */
CREATE OR REPLACE VIEW DEV_QUEBECTECH.UTIL.T_EDGES_HS_DRM AS
SELECT * FROM DEV_QUEBECTECH.UTIL.T_EDGES_ALL_RAW
WHERE SRC_A IN ('HUBSPOT','DEALROOM') AND SRC_B IN ('HUBSPOT','DEALROOM');

CREATE OR REPLACE VIEW DEV_QUEBECTECH.UTIL.T_EDGES_HS_DRM_DEDUP AS
SELECT * FROM DEV_QUEBECTECH.UTIL.T_EDGES_ALL_DEDUP
WHERE SRC_A IN ('HUBSPOT','DEALROOM') AND SRC_B IN ('HUBSPOT','DEALROOM');

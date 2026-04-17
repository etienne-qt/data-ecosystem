/* ============================================================
   DROP-IN REWRITE: T_CLUSTER_FLAGS
   Adjusted to the 5-source pipeline:
   - clusters live in:   DEV_QUEBECTECH.UTIL.T_CLUSTERS
   - entities live in:   DEV_QUEBECTECH.UTIL.T_ENTITIES (all sources)
   - Conflicts computed across all commercial entities (non-REGISTRY)
   - Registry ambiguity still surfaced via T_REQ_CLUSTER_CONFLICTS

   Output: DEV_QUEBECTECH.UTIL.T_CLUSTER_FLAGS
   ============================================================ */

CREATE OR REPLACE TEMP TABLE DEV_QUEBECTECH.UTIL.T_CLUSTER_FLAGS AS
WITH
-- All entities within each cluster (ignore REGISTRY nodes for attribute conflicts)
e AS (
  SELECT
    c.CLUSTER_ID,
    t.SRC,
    t.SRC_ID,
    t.NAME_NORM,
    t.DOMAIN_NORM,
    t.LINKEDIN_NORM,
    t.NEQ_NORM
  FROM DEV_QUEBECTECH.UTIL.T_CLUSTERS c
  JOIN DEV_QUEBECTECH.UTIL.T_ENTITIES t
    ON t.SRC = c.SRC
   AND t.SRC_ID = c.SRC_ID
  WHERE c.SRC <> 'REGISTRY'
),

-- basic distinct counts
agg AS (
  SELECT
    CLUSTER_ID,

    COUNT(DISTINCT IFF(NEQ_NORM      IS NOT NULL, NEQ_NORM,      NULL)) AS N_NEQ,
    COUNT(DISTINCT IFF(DOMAIN_NORM   IS NOT NULL, DOMAIN_NORM,   NULL)) AS N_DOMAIN,
    COUNT(DISTINCT IFF(LINKEDIN_NORM IS NOT NULL, LINKEDIN_NORM, NULL)) AS N_LINKEDIN,

    MIN(IFF(NEQ_NORM      IS NOT NULL, NEQ_NORM,      NULL)) AS ANY_NEQ,
    MIN(IFF(DOMAIN_NORM   IS NOT NULL, DOMAIN_NORM,   NULL)) AS ANY_DOMAIN,
    MIN(IFF(LINKEDIN_NORM IS NOT NULL, LINKEDIN_NORM, NULL)) AS ANY_LINKEDIN
  FROM e
  GROUP BY 1
),

-- stronger domain/name mismatch check within cluster:
-- same domain, very different names => likely bad merge
name_domain_pairs AS (
  SELECT
    a.CLUSTER_ID,
    MAX(
      IFF(
        a.DOMAIN_NORM IS NOT NULL
        AND a.DOMAIN_NORM = b.DOMAIN_NORM
        AND a.NAME_NORM IS NOT NULL
        AND b.NAME_NORM IS NOT NULL
        AND DEV_QUEBECTECH.UTIL.NAME_SIM(a.NAME_NORM, b.NAME_NORM) < 0.70,
        1, 0
      )
    ) AS HAS_DOMAIN_NAME_MISMATCH
  FROM e a
  JOIN e b
    ON a.CLUSTER_ID = b.CLUSTER_ID
   AND (a.SRC, a.SRC_ID) < (b.SRC, b.SRC_ID)
  GROUP BY 1
),

-- attach info: does the cluster have a REGISTRY node?
cluster_has_registry AS (
  SELECT
    CLUSTER_ID,
    MAX(IFF(SRC='REGISTRY', 1, 0)) AS HAS_REGISTRY_NODE
  FROM DEV_QUEBECTECH.UTIL.T_CLUSTERS
  GROUP BY 1
),

-- attach ambiguity: any REGISTRY NEQ that is flagged ambiguous (maps to >1 cluster)
cluster_registry_ambiguous AS (
  SELECT
    c.CLUSTER_ID,
    1 AS HAS_REGISTRY_AMBIGUOUS_LINK
  FROM DEV_QUEBECTECH.UTIL.T_CLUSTERS c
  JOIN DEV_QUEBECTECH.UTIL.T_REQ_CLUSTER_CONFLICTS x
    ON x.REQ_NEQ = c.SRC_ID
  WHERE c.SRC = 'REGISTRY'
  GROUP BY 1
)

SELECT
  a.CLUSTER_ID,

  /* core conflict flags */
  IFF(a.N_NEQ > 1, 1, 0)      AS FLAG_NEQ_CONFLICT,
  IFF(a.N_DOMAIN > 1, 1, 0)   AS FLAG_DOMAIN_CONFLICT,
  IFF(a.N_LINKEDIN > 1, 1, 0) AS FLAG_LINKEDIN_CONFLICT,

  COALESCE(p.HAS_DOMAIN_NAME_MISMATCH, 0) AS FLAG_DOMAIN_NAME_MISMATCH,

  /* registry linkage flags */
  COALESCE(r.HAS_REGISTRY_NODE, 0) AS FLAG_HAS_REGISTRY_NODE,
  COALESCE(ra.HAS_REGISTRY_AMBIGUOUS_LINK, 0) AS FLAG_REGISTRY_AMBIGUOUS_LINK,

  /* master "unsafe" flag */
  IFF(
       a.N_NEQ > 1
    OR a.N_DOMAIN > 1
    OR a.N_LINKEDIN > 1
    OR COALESCE(p.HAS_DOMAIN_NAME_MISMATCH, 0) = 1
    OR COALESCE(ra.HAS_REGISTRY_AMBIGUOUS_LINK, 0) = 1,
    1, 0
  ) AS FLAG_ANY_CONFLICT,

  /* debug values */
  a.ANY_NEQ,
  a.ANY_DOMAIN,
  a.ANY_LINKEDIN

FROM agg a
LEFT JOIN name_domain_pairs p
  ON p.CLUSTER_ID = a.CLUSTER_ID
LEFT JOIN cluster_has_registry r
  ON r.CLUSTER_ID = a.CLUSTER_ID
LEFT JOIN cluster_registry_ambiguous ra
  ON ra.CLUSTER_ID = a.CLUSTER_ID
;

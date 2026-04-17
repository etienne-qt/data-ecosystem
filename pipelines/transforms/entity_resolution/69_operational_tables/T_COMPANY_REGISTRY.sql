/* ============================================================
   T_COMPANY_REGISTRY — Permanent Consolidated Company Table
   ============================================================
   Single-source-of-truth registry of resolved company entities.
   Updated via MERGE on each pipeline run.

   Identifiers only — join to source tables via cross-reference
   IDs (GOLD_*_ID) for descriptive/financial fields.
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;
USE SCHEMA UTIL;

------------------------------------------------------------
-- DDL: Create table if it doesn't exist
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS DEV_QUEBECTECH.UTIL.T_COMPANY_REGISTRY (
  CLUSTER_ID              VARCHAR NOT NULL PRIMARY KEY,

  -- Core identifiers
  GOLD_NEQ                VARCHAR,
  GOLD_DOMAIN             VARCHAR,
  GOLD_LINKEDIN           VARCHAR,
  GOLD_WEBSITE            VARCHAR,
  GOLD_NAME               VARCHAR,

  -- Cross-reference IDs (one per source)
  GOLD_REGISTRY_NEQ       VARCHAR,
  GOLD_PITCHBOOK_ID       VARCHAR,
  GOLD_DEALROOM_ID        VARCHAR,
  GOLD_HARMONIC_ID        VARCHAR,
  GOLD_HUBSPOT_ID         VARCHAR,

  -- Conflict flags
  FLAG_ANY_CONFLICT       BOOLEAN DEFAULT FALSE,
  FLAG_NEQ_CONFLICT       BOOLEAN DEFAULT FALSE,
  FLAG_DOMAIN_CONFLICT    BOOLEAN DEFAULT FALSE,
  FLAG_LINKEDIN_CONFLICT  BOOLEAN DEFAULT FALSE,

  -- Metadata
  DATA_SOURCES            VARCHAR,
  SOURCE_COUNT            NUMBER(2,0),
  LAST_PIPELINE_RUN_AT    TIMESTAMP_TZ NOT NULL
) CLUSTER BY (GOLD_NEQ, GOLD_DOMAIN, GOLD_LINKEDIN);

------------------------------------------------------------
-- MERGE: Upsert from latest golden records
------------------------------------------------------------
MERGE INTO DEV_QUEBECTECH.UTIL.T_COMPANY_REGISTRY tgt
USING (
  SELECT
    CLUSTER_ID,
    GOLD_NEQ,
    GOLD_DOMAIN,
    GOLD_LINKEDIN,
    GOLD_WEBSITE,
    GOLD_NAME,
    GOLD_REGISTRY_NEQ,
    GOLD_PITCHBOOK_ID,
    GOLD_DEALROOM_ID,
    GOLD_HARMONIC_ID,
    GOLD_HUBSPOT_ID,
    FLAG_ANY_CONFLICT::BOOLEAN   AS FLAG_ANY_CONFLICT,
    FLAG_NEQ_CONFLICT::BOOLEAN   AS FLAG_NEQ_CONFLICT,
    FLAG_DOMAIN_CONFLICT::BOOLEAN AS FLAG_DOMAIN_CONFLICT,
    FLAG_LINKEDIN_CONFLICT::BOOLEAN AS FLAG_LINKEDIN_CONFLICT,
    DATA_SOURCES,
    SOURCE_COUNT,
    CURRENT_TIMESTAMP()          AS LAST_PIPELINE_RUN_AT
  FROM DEV_QUEBECTECH.UTIL.T_CLUSTER_GOLDEN
) src
ON tgt.CLUSTER_ID = src.CLUSTER_ID

WHEN MATCHED THEN UPDATE SET
  tgt.GOLD_NEQ              = src.GOLD_NEQ,
  tgt.GOLD_DOMAIN           = src.GOLD_DOMAIN,
  tgt.GOLD_LINKEDIN         = src.GOLD_LINKEDIN,
  tgt.GOLD_WEBSITE          = src.GOLD_WEBSITE,
  tgt.GOLD_NAME             = src.GOLD_NAME,
  tgt.GOLD_REGISTRY_NEQ     = src.GOLD_REGISTRY_NEQ,
  tgt.GOLD_PITCHBOOK_ID     = src.GOLD_PITCHBOOK_ID,
  tgt.GOLD_DEALROOM_ID      = src.GOLD_DEALROOM_ID,
  tgt.GOLD_HARMONIC_ID      = src.GOLD_HARMONIC_ID,
  tgt.GOLD_HUBSPOT_ID       = src.GOLD_HUBSPOT_ID,
  tgt.FLAG_ANY_CONFLICT     = src.FLAG_ANY_CONFLICT,
  tgt.FLAG_NEQ_CONFLICT     = src.FLAG_NEQ_CONFLICT,
  tgt.FLAG_DOMAIN_CONFLICT  = src.FLAG_DOMAIN_CONFLICT,
  tgt.FLAG_LINKEDIN_CONFLICT = src.FLAG_LINKEDIN_CONFLICT,
  tgt.DATA_SOURCES          = src.DATA_SOURCES,
  tgt.SOURCE_COUNT          = src.SOURCE_COUNT,
  tgt.LAST_PIPELINE_RUN_AT  = src.LAST_PIPELINE_RUN_AT

WHEN NOT MATCHED THEN INSERT (
  CLUSTER_ID,
  GOLD_NEQ, GOLD_DOMAIN, GOLD_LINKEDIN, GOLD_WEBSITE, GOLD_NAME,
  GOLD_REGISTRY_NEQ, GOLD_PITCHBOOK_ID, GOLD_DEALROOM_ID, GOLD_HARMONIC_ID, GOLD_HUBSPOT_ID,
  FLAG_ANY_CONFLICT, FLAG_NEQ_CONFLICT, FLAG_DOMAIN_CONFLICT, FLAG_LINKEDIN_CONFLICT,
  DATA_SOURCES, SOURCE_COUNT, LAST_PIPELINE_RUN_AT
) VALUES (
  src.CLUSTER_ID,
  src.GOLD_NEQ, src.GOLD_DOMAIN, src.GOLD_LINKEDIN, src.GOLD_WEBSITE, src.GOLD_NAME,
  src.GOLD_REGISTRY_NEQ, src.GOLD_PITCHBOOK_ID, src.GOLD_DEALROOM_ID, src.GOLD_HARMONIC_ID, src.GOLD_HUBSPOT_ID,
  src.FLAG_ANY_CONFLICT, src.FLAG_NEQ_CONFLICT, src.FLAG_DOMAIN_CONFLICT, src.FLAG_LINKEDIN_CONFLICT,
  src.DATA_SOURCES, src.SOURCE_COUNT, src.LAST_PIPELINE_RUN_AT
);

-- Remove clusters that no longer exist in golden records (entities split/deleted)
DELETE FROM DEV_QUEBECTECH.UTIL.T_COMPANY_REGISTRY
WHERE CLUSTER_ID NOT IN (
  SELECT CLUSTER_ID FROM DEV_QUEBECTECH.UTIL.T_CLUSTER_GOLDEN
);

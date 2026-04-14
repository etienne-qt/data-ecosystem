/* ============================================================
   32 — REQ SUCCESSOR CHAIN (Silver Layer)
   ============================================================
   Links radiated/dissolved NEQs to their active successor entities.
   Many Quebec startups re-incorporate, restructure, or merge under
   a new NEQ while the business continues. This table traces those
   corporate chains so we don't lose track of companies.

   Three matching strategies (in priority order):
     1. FusionScissions — explicit NEQ→NEQ linkage (strongest)
     2. ContinuationsTransformations — restructuring events
     3. Name-based — same normalized name, different NEQ (fallback)

   Data sources:
     - DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_FUSIONS_SCISSIONS
       (or DEV_IMPORT.REQ_IMPORT equivalent — verify table name with Q0)
     - DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_CONTINUATIONS
       (or equivalent — verify with Q0)
     - DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS
     - DEV_QUEBECTECH.REF.REQ_CANONICAL

   Output:
     - DEV_QUEBECTECH.SILVER.REQ_SUCCESSOR_CHAIN

   NOTE: The FusionScissions and ContinuationsTransformations tables
   may not yet be loaded in Snowflake. Run Q0 below to check.
   If not available, the SQL falls back to name-based matching only.

   Author:  AI Agent (Quebec Tech Data & Analytics)
   Date:    2026-04-01
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;

/* ----------------------------------------------------------
   Q0: VERIFY DATA SOURCES EXIST
   Run these first. If they fail, the corresponding data needs
   to be loaded from JeuDonnées CSV into Snowflake.
   ---------------------------------------------------------- */

-- Check for FusionScissions table
-- SELECT column_name, data_type
-- FROM DEV_DATAMART.INFORMATION_SCHEMA.COLUMNS
-- WHERE table_schema = 'ENTREPRISES_DU_QUEBEC'
--   AND table_name ILIKE '%fusion%'
-- ORDER BY ordinal_position;

-- Check for ContinuationsTransformations table
-- SELECT column_name, data_type
-- FROM DEV_DATAMART.INFORMATION_SCHEMA.COLUMNS
-- WHERE table_schema = 'ENTREPRISES_DU_QUEBEC'
--   AND table_name ILIKE '%continu%'
-- ORDER BY ordinal_position;

-- If not found in DEV_DATAMART, check DEV_IMPORT
-- SELECT table_name FROM DEV_IMPORT.INFORMATION_SCHEMA.TABLES
-- WHERE table_schema = 'REQ_IMPORT'
-- ORDER BY table_name;


/* ----------------------------------------------------------
   SILVER TABLE
   ----------------------------------------------------------
   Column mapping from JeuDonnées CSV:
     FusionScissions.csv:
       NEQ, NEQ_ASSUJ_REL, DENOMN_SOC, COD_RELA_ASSUJ,
       DAT_EFCTVT, IND_DISP, LIGN1-4_ADR

     ContinuationsTransformations.csv:
       NEQ, COD_TYP_CHANG, COD_REGIM_JURI, AUTR_REGIM_JURI,
       NOM_LOCLT, DAT_EFCTVT

   Adjust table/column names below based on Q0 output.
   The patterns below use the CSV column names as-is since
   REQ_CANONICAL uses the same naming convention.
   ---------------------------------------------------------- */

CREATE OR REPLACE TABLE DEV_QUEBECTECH.SILVER.REQ_SUCCESSOR_CHAIN AS

WITH radiated AS (
    -- All radiated companies from REQ_CANONICAL
    SELECT
        NEQ,
        UTIL.NORM_NEQ(NEQ)                               AS NEQ_NORM,
        COD_STAT_IMMAT                                   AS OLD_STATUS,
        DAT_STAT_IMMAT                                   AS RADIATION_DATE,
        COD_FORME_JURI,
        DAT_CONSTI
    FROM DEV_QUEBECTECH.REF.REQ_CANONICAL
    WHERE COD_STAT_IMMAT IN ('RO', 'RD', 'RX')
),

/* ----------------------------------------------------------
   STRATEGY 1: FusionScissions linkage
   ----------------------------------------------------------
   Pattern: When a company (NEQ_A) is absorbed into another (NEQ_B),
   FusionScissions has:
     - Row: NEQ=NEQ_B, NEQ_ASSUJ_REL=NEQ_A, COD_RELA_ASSUJ='FO'
       (NEQ_A is a "fondateur" — original entity absorbed)

   So for a radiated NEQ, we look for it as NEQ_ASSUJ_REL with
   COD_RELA_ASSUJ='FO'. The parent NEQ is the successor.

   NOTE: If FusionScissions is not yet in Snowflake, comment out
   this CTE and the UNION below. The pipeline will still work
   using strategy 3 (name-based) only.
   ---------------------------------------------------------- */

-- Uncomment when FusionScissions is loaded in Snowflake:
-- fusion_successors AS (
--     SELECT
--         UTIL.NORM_NEQ(fs.NEQ_ASSUJ_REL)                 AS OLD_NEQ_NORM,
--         UTIL.NORM_NEQ(fs.NEQ)                            AS SUCCESSOR_NEQ_NORM,
--         fs.NEQ                                           AS SUCCESSOR_NEQ_RAW,
--         fs.DENOMN_SOC                                    AS SUCCESSOR_NAME,
--         fs.DAT_EFCTVT                                    AS EVENT_DATE,
--         fs.COD_RELA_ASSUJ                                AS RELATIONSHIP_TYPE,
--         'fusion_scission'                                AS MATCH_METHOD,
--         1.0::FLOAT                                       AS MATCH_CONFIDENCE
--     FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_FUSIONS_SCISSIONS fs
--     WHERE fs.COD_RELA_ASSUJ = 'FO'
--       AND fs.NEQ_ASSUJ_REL IS NOT NULL
--       AND fs.NEQ IS NOT NULL
--     QUALIFY ROW_NUMBER() OVER (
--         PARTITION BY UTIL.NORM_NEQ(fs.NEQ_ASSUJ_REL)
--         ORDER BY fs.DAT_EFCTVT DESC  -- most recent event
--     ) = 1
-- ),

/* ----------------------------------------------------------
   STRATEGY 2: ContinuationsTransformations
   ----------------------------------------------------------
   ContinuationsTransformations has the NEW entity's NEQ but
   does not link back to the old NEQ directly. We flag these
   for name-based resolution.

   Uncomment when loaded in Snowflake.
   ---------------------------------------------------------- */

-- continuation_flags AS (
--     SELECT
--         UTIL.NORM_NEQ(ct.NEQ)                            AS NEQ_NORM,
--         ct.COD_TYP_CHANG,
--         ct.DAT_EFCTVT                                    AS EVENT_DATE,
--         'continuation'                                   AS EVENT_TYPE
--     FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_CONTINUATIONS ct
-- ),

/* ----------------------------------------------------------
   STRATEGY 3: Name-based successor matching
   ----------------------------------------------------------
   For radiated companies with no FusionScissions trace:
   find active companies with the same normalized name but
   a different NEQ. High threshold (0.95) to avoid false positives.
   ---------------------------------------------------------- */

current_names AS (
    -- Current name for each NEQ
    SELECT
        NEQ,
        UTIL.NORM_NEQ(NEQ)                               AS NEQ_NORM,
        NOM_ASSUJ                                        AS NAME_RAW,
        UTIL.NORM_NAME(NOM_ASSUJ)                        AS NAME_NORM
    FROM DEV_DATAMART.ENTREPRISES_DU_QUEBEC.REGISTRE_NOMS
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY NEQ
        ORDER BY IFF(DAT_FIN_NOM_ASSUJ IS NULL, 0, 1), DAT_INIT_NOM_ASSUJ DESC
    ) = 1
),

-- Active company names (potential successors)
active_names AS (
    SELECT
        cn.NEQ,
        cn.NEQ_NORM,
        cn.NAME_RAW,
        cn.NAME_NORM,
        SPLIT_PART(cn.NAME_NORM, ' ', 1) AS TOK1,
        LEFT(cn.NAME_NORM, 4) AS P4
    FROM current_names cn
    JOIN DEV_QUEBECTECH.REF.REQ_CANONICAL rc ON cn.NEQ = rc.NEQ
    WHERE rc.COD_STAT_IMMAT = 'IM'  -- active successors only
),

-- Radiated company names
radiated_names AS (
    SELECT
        r.NEQ,
        r.NEQ_NORM,
        r.OLD_STATUS,
        r.RADIATION_DATE,
        cn.NAME_RAW,
        cn.NAME_NORM,
        SPLIT_PART(cn.NAME_NORM, ' ', 1) AS TOK1,
        LEFT(cn.NAME_NORM, 4) AS P4
    FROM radiated r
    JOIN current_names cn ON r.NEQ = cn.NEQ
    WHERE cn.NAME_NORM IS NOT NULL
),

-- Name-based matching (blocked by P4 for performance)
name_successors AS (
    SELECT
        rn.NEQ_NORM                                      AS OLD_NEQ_NORM,
        an.NEQ_NORM                                      AS SUCCESSOR_NEQ_NORM,
        an.NEQ                                           AS SUCCESSOR_NEQ_RAW,
        an.NAME_RAW                                      AS SUCCESSOR_NAME,
        NULL                                             AS EVENT_DATE,
        NULL                                             AS RELATIONSHIP_TYPE,
        'name_match'                                     AS MATCH_METHOD,
        UTIL.NAME_SIM(rn.NAME_NORM, an.NAME_NORM)::FLOAT AS MATCH_CONFIDENCE
    FROM radiated_names rn
    JOIN active_names an
      ON rn.P4 = an.P4
     AND rn.NEQ_NORM != an.NEQ_NORM  -- different entity
    WHERE UTIL.NAME_SIM(rn.NAME_NORM, an.NAME_NORM) >= 0.95
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY rn.NEQ_NORM
        ORDER BY UTIL.NAME_SIM(rn.NAME_NORM, an.NAME_NORM) DESC
    ) = 1  -- keep best match per radiated NEQ
),

/* ----------------------------------------------------------
   COMBINE ALL STRATEGIES
   ---------------------------------------------------------- */

combined AS (
    -- Strategy 3: name-based (always available)
    SELECT * FROM name_successors

    -- Strategy 1: FusionScissions (uncomment when loaded)
    -- UNION ALL
    -- SELECT * FROM fusion_successors

    -- Note: Strategy 1 takes priority over Strategy 3 for the same OLD_NEQ.
    -- The QUALIFY below handles dedup.
),

-- Deduplicate: prefer fusion > name match
deduped AS (
    SELECT
        c.*,
        ROW_NUMBER() OVER (
            PARTITION BY c.OLD_NEQ_NORM
            ORDER BY
                CASE c.MATCH_METHOD
                    WHEN 'fusion_scission' THEN 1
                    WHEN 'continuation'    THEN 2
                    WHEN 'name_match'      THEN 3
                END,
                c.MATCH_CONFIDENCE DESC
        ) AS RN
    FROM combined c
)

SELECT
    d.OLD_NEQ_NORM,
    r.NEQ                                                AS OLD_NEQ_RAW,
    r.OLD_STATUS,
    r.RADIATION_DATE,
    d.SUCCESSOR_NEQ_NORM,
    d.SUCCESSOR_NEQ_RAW,
    d.SUCCESSOR_NAME,
    d.EVENT_DATE,
    d.RELATIONSHIP_TYPE,
    d.MATCH_METHOD,
    d.MATCH_CONFIDENCE,

    -- Successor status
    succ.COD_STAT_IMMAT                                  AS SUCCESSOR_STATUS,
    succ.COD_FORME_JURI                                  AS SUCCESSOR_FORM,
    succ.DAT_CONSTI                                      AS SUCCESSOR_INCORPORATION_DATE,
    succ.COD_INTVAL_EMPLO_QUE                            AS SUCCESSOR_EMPLOYEES,

    CURRENT_TIMESTAMP()                                  AS CHAIN_BUILT_AT

FROM deduped d
JOIN radiated r ON d.OLD_NEQ_NORM = r.NEQ_NORM
LEFT JOIN DEV_QUEBECTECH.REF.REQ_CANONICAL succ
  ON d.SUCCESSOR_NEQ_RAW = succ.NEQ
WHERE d.RN = 1  -- best match per old NEQ
;

ALTER TABLE DEV_QUEBECTECH.SILVER.REQ_SUCCESSOR_CHAIN
  CLUSTER BY (OLD_NEQ_NORM, SUCCESSOR_NEQ_NORM, MATCH_METHOD);


/* ----------------------------------------------------------
   VALIDATION
   ---------------------------------------------------------- */

-- Summary
SELECT
    MATCH_METHOD,
    COUNT(*) AS CHAINS,
    AVG(MATCH_CONFIDENCE) AS AVG_CONFIDENCE,
    SUM(IFF(SUCCESSOR_STATUS = 'IM', 1, 0)) AS SUCCESSOR_ACTIVE
FROM DEV_QUEBECTECH.SILVER.REQ_SUCCESSOR_CHAIN
GROUP BY MATCH_METHOD;

-- Known test cases (from Dealroom analysis)
SELECT
    OLD_NEQ_RAW, SUCCESSOR_NAME, SUCCESSOR_NEQ_RAW,
    MATCH_METHOD, MATCH_CONFIDENCE, SUCCESSOR_STATUS
FROM DEV_QUEBECTECH.SILVER.REQ_SUCCESSOR_CHAIN
WHERE OLD_NEQ_NORM IN (
    '1172813520',  -- Flare → should find Flare Systèmes 1178044542
    '1174951286',  -- Taiga Motors
    '1171711543',  -- POTLOC
    '1173444424'   -- Lexop
)
ORDER BY OLD_NEQ_NORM;

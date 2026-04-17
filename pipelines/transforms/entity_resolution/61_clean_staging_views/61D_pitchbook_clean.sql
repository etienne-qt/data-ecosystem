/* ============================================================
   PITCHBOOK CLEAN VIEW (STUB — Phase 2)
   ============================================================
   This stub returns zero rows with the standard entity schema.
   In Phase 2, replace the body with actual column mappings from
   the Pitchbook raw table once column names are confirmed.

   Expected raw table: DEV_QUEBECTECH.IMPORT.PB_COMPANY_RAW
   ============================================================ */

CREATE OR REPLACE VIEW DEV_QUEBECTECH.UTIL.V_PB_CLEAN AS
SELECT
  NULL::VARCHAR   AS PB_ID,
  NULL::VARCHAR   AS PB_NAME_RAW,
  NULL::VARCHAR   AS PB_NAME_NORM,
  NULL::VARCHAR   AS PB_DOMAIN_NORM,
  NULL::VARCHAR   AS PB_LINKEDIN_NORM,
  NULL::VARCHAR   AS PB_NEQ_NORM
WHERE 1 = 0;

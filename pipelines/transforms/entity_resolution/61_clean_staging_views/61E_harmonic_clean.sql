/* ============================================================
   HARMONIC CLEAN VIEW (STUB — Phase 2)
   ============================================================
   This stub returns zero rows with the standard entity schema.
   In Phase 2, replace the body with actual column mappings from
   the Harmonic raw table once column names are confirmed.

   Expected raw table: DEV_QUEBECTECH.IMPORT.HAR_COMPANY_RAW
   ============================================================ */

CREATE OR REPLACE VIEW DEV_QUEBECTECH.UTIL.V_HAR_CLEAN AS
SELECT
  NULL::VARCHAR   AS HAR_ID,
  NULL::VARCHAR   AS HAR_NAME_RAW,
  NULL::VARCHAR   AS HAR_NAME_NORM,
  NULL::VARCHAR   AS HAR_DOMAIN_NORM,
  NULL::VARCHAR   AS HAR_LINKEDIN_NORM,
  NULL::VARCHAR   AS HAR_NEQ_NORM
WHERE 1 = 0;

/* ============================================================
   71 -- SEED MATCH WHITELIST (Q4 domain near-misses)
   ============================================================
   Adds 8 manually-confirmed DR↔RC match pairs to
   REF.MANUAL_REVIEW_DECISIONS. These are pairs identified by
   Q4 §C (2026-04-14) where both sides carry identical normalized
   domains in the registry but the 63D tier-1 DOMAIN matcher
   missed them — likely a T_ENTITIES.DOMAIN_NORM vs registry-
   surface asymmetry (to be investigated separately).

   After running this script, re-run:
     - 80_consolidated_startup_registry.sql  (to fold these into
       MATCHED via V_MATCH_WHITELIST consumption)

   Safe to re-run — MANUAL_REVIEW_DECISIONS is append-only and
   V_MANUAL_REVIEW_CURRENT dedupes to the latest decision.

   Author: AI Agent (Quebec Tech Data & Analytics)
   Date:   2026-04-14
   ============================================================ */

USE DATABASE DEV_QUEBECTECH;

INSERT INTO DEV_QUEBECTECH.REF.MANUAL_REVIEW_DECISIONS
    (DEALROOM_ID, RC_COMPANY_ID, DECISION_TYPE, DECISION_VALUE,
     DECISION_NOTE, REVIEWED_BY, REVIEW_BATCH, SOURCE_FILE)
VALUES
    ('3761924', '7394313',  'MATCH_CONFIRM', 'YES',
     'Q4 domain near-miss: myfliip.com identical on both sides',
     'agent', 'q4_domain_near_miss_20260414', NULL),

    ('4256719', '49385964', 'MATCH_CONFIRM', 'YES',
     'Q4 domain near-miss: displaid.co identical on both sides',
     'agent', 'q4_domain_near_miss_20260414', NULL),

    ('1586298', '1892709',  'MATCH_CONFIRM', 'YES',
     'Q4 domain near-miss: enjoi.it identical on both sides',
     'agent', 'q4_domain_near_miss_20260414', NULL),

    ('4668507', '12837062', 'MATCH_CONFIRM', 'YES',
     'Q4 domain near-miss: irisarlo.com identical on both sides',
     'agent', 'q4_domain_near_miss_20260414', NULL),

    ('4545499', '3873257',  'MATCH_CONFIRM', 'YES',
     'Q4 domain near-miss: soralink.co identical on both sides',
     'agent', 'q4_domain_near_miss_20260414', NULL),

    ('4462553', '7326083',  'MATCH_CONFIRM', 'YES',
     'Q4 domain near-miss: lipidtech.ca identical on both sides',
     'agent', 'q4_domain_near_miss_20260414', NULL),

    ('5428214', '54932989', 'MATCH_CONFIRM', 'YES',
     'Q4 domain near-miss: propulso.io identical on both sides',
     'agent', 'q4_domain_near_miss_20260414', NULL),

    ('4340757', '26067461', 'MATCH_CONFIRM', 'YES',
     'Q4 domain near-miss: glaciestech.com identical on both sides',
     'agent', 'q4_domain_near_miss_20260414', NULL)
;

-- Verify via the underlying current-decisions view, which exposes
-- all fields (V_MATCH_WHITELIST only projects id/reviewer columns).
SELECT
    DEALROOM_ID,
    RC_COMPANY_ID,
    DECISION_TYPE,
    DECISION_VALUE,
    DECISION_NOTE,
    REVIEW_BATCH,
    REVIEWED_AT
FROM DEV_QUEBECTECH.REF.V_MANUAL_REVIEW_CURRENT
WHERE DECISION_TYPE = 'MATCH_CONFIRM'
  AND REVIEW_BATCH = 'q4_domain_near_miss_20260414'
ORDER BY REVIEWED_AT DESC;

-- Also confirm the whitelist view now surfaces these 8 pairs
SELECT COUNT(*) AS N_MATCH_WHITELIST
FROM DEV_QUEBECTECH.REF.V_MATCH_WHITELIST;

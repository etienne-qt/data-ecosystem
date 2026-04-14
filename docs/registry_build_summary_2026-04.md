# Registry build — summary of work (April 2026)

**Author:** Data & Analytics team · **Dates:** 2026-04-08 to 2026-04-14
**Final dataset:** `DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY`
**Row count:** 7,607
**Build script:** `ecosystem/sql/80_registry/80_consolidated_startup_registry.sql`

---

## TL;DR

We consolidated the Quebec startup registry by doing a **full outer join of Dealroom (filtered to classifier ratings A+/A/B with C promoted when matched to RC) and Réseau Capital's `COMPANY_MASTER` (Harmonic + PitchBook, Quebec-filtered)**. The output lives in `DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY` — 7,607 rows, tagged `MATCHED` (both sources), `QT_ONLY` (Dealroom only), or `RC_ONLY` (Réseau Capital only).

**Applying our working startup definition** (QT-anchored + RC_ONLY, minus blacklist, minus non-tech name hits, minus pre-1990):

| Metric | Value |
|---|---:|
| Registry total | **7,607** |
| Startups (full filter) | **6,507** |
| QT-anchored (Dealroom-classified + C-promoted + whitelist) | 4,651 |
| RC_ONLY contribution | 1,856 |
| Conservative estimate of real tech startups | **~5,100–5,500** |

The range between 6,507 and ~5,300 is the honest uncertainty: ~1,000 of the RC_ONLY rows are probably non-tech (DTC brands, restaurants, insurance, services), but we can't yet classify them programmatically because 97% of RC_ONLY has no sector assignment from PitchBook.

**Lifecycle split (v3 filter, 2026-04-14):**

| Bucket | N | % |
|---|---:|---:|
| Active (post-2010 operational) | **3,355** | 51.6% |
| Mature (1991–2010 operational) | 1,743 | 26.8% |
| Acquired | 495 | 7.6% |
| Closed / low-activity | 235 | 3.6% |
| Unknown age (operational, no launch year) | 650 | 10.0% |
| Unknown status | 29 | 0.4% |

---

## Why we did this

Our mandate is to improve the quality and availability of data on Quebec tech startups. We had three parallel assets:

1. **Dealroom** — licensed, well-structured, with a rating system (A+/A/B/C/D) and broad Quebec coverage but limited VC signal.
2. **Réseau Capital's `COMPANY_MASTER`** — merged Harmonic + PitchBook Quebec data delivered to us, deep on VC signal (deals, funding, acquisitions) but no classification.
3. **HubSpot** — our CRM, with historical partnership context.

Each source alone has gaps. Dealroom A+/A/B misses ~2,000 Quebec companies that Harmonic tracks through broader scraping. Réseau Capital's data is deal-driven and includes non-tech VC-backed businesses we wouldn't classify as startups. HubSpot is incomplete and noisy.

The goal was to **fuse them into a single defensible registry** with full provenance, so that when a stakeholder asks "how many Quebec tech startups are there?", we can point to one table and walk them through every filter.

---

## Timeline

### 2026-04-08 — Initial build
- Ran `63D_drm_rc_matching.sql` → **2,857 DR↔RC match edges** via a tiered waterfall (2,539 domain / 62 LinkedIn / 85 Crunchbase / 171 name-similarity).
- Ran `80_consolidated_startup_registry.sql` → initial `GOLD.STARTUP_REGISTRY`: 1,797 MATCHED / 2,524 QT_ONLY / 2,389 RC_ONLY = 6,710 total.
- First observation: the rating-A DR cohort had a strangely low match rate (26%) compared to A+ (72%) and B (60%). Non-monotonic → something off.

### 2026-04-10 — Q1 match-ceiling diagnostic
- Built `Q1_drm_rc_match_ceiling.sql` (full version + minimal variant) to understand why matching only covers ~42% of DR A+/A/B.
- **Key finding (§J):** NEQ presence (Quebec business registry ID) is *not* a predictor of match success — HAS_NEQ vs NO_NEQ differ by only 3–8pp across ratings. This **killed the REQ→RC bridge hypothesis** (which we had been planning to build). The REQ-hub approach would not improve match rates.
- Memory updated: REQ→RC bridge marked NO-GO.

### 2026-04-10 — Q2 rating-A gap investigation
- Built `Q2_rating_a_gap.sql` to understand why rating A matches RC so poorly.
- **Key finding (§I.2, §I.3):** Only 4.5% of rating A has any VC funding vs 40% for A+ and 30% for B. When we condition on "has funding", A matches RC at 70% — in line with the others. The "gap" was a **classifier scope mismatch**: rating A is dominated by bootstrapped Quebec software companies that never took VC, which are legitimate startups but structurally invisible to Réseau Capital's deal-driven sources.
- **Secondary finding:** ~754 A-rated "ICT / Enterprise Software" rows match RC at only 21% — many of them turn out to be services/agencies/consultancies mislabeled as tech (Rénovation Guy Parisien, Déménagement Transat Montréal, Digital Marketing Consortium of Canada, etc.).
- Decision: add a **non-tech name keyword veto** (`FLAG_NON_TECH_NAME_HIT`) to filter out the obvious mislabels.

### 2026-04-10 — 80-script patches (C→B promotion + flags + review infra)
- Patched `80_consolidated_startup_registry.sql`:
  - Widened `_QT_CANDIDATES` to include C-rated rows
  - Added C→B promotion logic: C + RC match → effective rating B (inclusion reason `C_PROMOTED_RC_MATCH`)
  - Added `RATING_LETTER_EFFECTIVE`, `QT_INCLUSION_REASON`, `IS_STARTUP_WHITELISTED`, `IS_STARTUP_BLACKLISTED`, sector flags (GAMING / PHARMA_BIOTECH / SERVICES), `FLAG_NON_TECH_NAME_HIT`
  - Hooked up the `REF` schema (`REF.V_STARTUP_WHITELIST`, `V_STARTUP_BLACKLIST`) as hard preconditions
- Built `70_manual_review_tables.sql` for the manual review infrastructure (append-only decisions, review queue views, CSV upload procedure).
- Fixed several secondary issues during the same run: SERVICES sector regex word-boundary bug, orphan match metadata on QT_ONLY rows, city-conflict false positives via `UTIL.NORMALIZE_TEXT_FOR_MATCHING`.

### 2026-04-13 — Q3 startup filter + lifecycle taxonomy (v1 → v2)
- Built `Q3_startup_filter_and_lifecycle.sql` to apply a canonical filter and bucket the survivors by lifecycle.
- **v1 filter:** A 10-year-old / 250-employee / $100M-raised "mature" definition. Ran it; 45% of startups were classified mature, which felt wrong.
- Decision: simplify to **age-only** (99% of the v1 mature rows were age-triggered anyway; size and capital barely moved the needle). Add the **pre-1990 cutoff** per user call ("anything before 1990 is not even a mature startup — pre-internet").
- **v2 taxonomy (age-only):**
  - acquired → `DRM_COMPANY_STATUS = 'acquired'`
  - closed → `DRM_COMPANY_STATUS IN ('closed', 'low-activity')`
  - mature → operational AND 1991 ≤ launch_year ≤ 2010
  - active → operational AND launch_year ≥ 2011
  - unknown_age → operational AND launch_year IS NULL
  - excluded → launch_year ≤ 1990
- v2 QT-only results: 4,670 startups, 54% active. Reframed the headline — our registry is not really a startup registry, it's a **tech company registry with 54% active early-stage startups and 46% mature/acquired/closed/unknown**. This matters for stakeholder framing.

### 2026-04-13/14 — Q3 v3: include RC_ONLY
- User flagged a gap: v2 filter excluded RC_ONLY entirely, underselling by ~2,400 rows.
- Patched Q3 to include RC_ONLY via `UNIFIED_LAUNCH_YEAR = COALESCE(DRM_LAUNCH_YEAR, RC_FOUNDING_YEAR)` and `UNIFIED_STATUS` derived from DR status then RC `BUSINESS_STATUS` via regex mapping.

### 2026-04-14 — Q4 RC_ONLY audit
- Before trusting the v3 headline, user raised two concerns: (a) is the DR↔RC matching too strict (false negatives), and (b) is RC polluted with non-tech VC-backed businesses?
- Built `Q4_rc_only_delta_audit.sql` to test both hypotheses.
- **Finding 1 — matching false negatives:** Found **8 pairs with identical normalized domains** in the registry that should have matched at 63D tier-1 but didn't (fliip, displaid, enjoi, iris+arlo, soralink, lipidtech, propulso, glaciestech). Root cause: `T_ENTITIES.DOMAIN_NORM` vs the inline `LOWER(TRIM(...))` on the RC side use different normalization paths. Plus ~2 more probable duplicates from sub-threshold name similarity. Total: ~10 near-miss duplicates. Small absolute impact but worth fixing.
- **Finding 2 — non-tech pollution:** Only **60 of 1,940 RC_ONLY rows post-filter (3.1%) have any PitchBook sector assignment**. The other 1,880 are "dark matter" from Harmonic's long-tail scraping. Manual eyeball of a 95-row random sample (stratified across record types): ~24% clearly tech, ~54% clearly non-tech (DTC brands, restaurants, insurance, cosmetics, clinics, professional services, traditional manufacturing, music schools, yogurt cafes, REM public transit), ~22% ambiguous. The HARMONIC_ONLY tier was ~70% non-tech; MATCHED (H+PB) was ~50% tech; PB_ONLY was mostly unreadable.
- **Honest real delta:** instead of adding ~1,940 "new startups" from RC, we're adding ~460 (conservative) to ~880 (optimistic) real tech startups. The rest is pollution we can't filter programmatically yet.
- Memory logged the feedback principle: *"for the registry, explain > optimize. Decomposable cuts + ranges > single clean number."*

### 2026-04-14 — Policy E + match whitelist
- User chose **Policy E** for RC_ONLY inclusion: keep Harmonic long-tail but apply the same non-tech name veto consistently on both sides.
- Q3 now computes `UNIFIED_NON_TECH_NAME_HIT`: DR rows inherit `FLAG_NON_TECH_NAME_HIT` from the 80 script; RC rows are checked inline with an expanded keyword list informed by Q4 findings (funds, insurance, restaurant, yogurt, buanderie, juris/avocat, dermo/cosmetic, clinique/chiro/dental, galerie/shopping, etc.).
- Seeded the **8 domain near-miss matches** into `REF.MANUAL_REVIEW_DECISIONS` via `sql/10_utils/71_seed_match_whitelist.sql`.
- Patched `80_consolidated_startup_registry.sql` to consume `REF.V_MATCH_WHITELIST`: `match_bridge` CTE now UNIONs whitelist decisions (synthetic tier 0 / score 1.0) with 63D edges, with a QUALIFY ensuring one match per DR side (whitelist wins conflicts). Also added whitelist-aware logic to `_QT_CANDIDATES.HAS_RC_MATCH_AT_CANDIDATE_STAGE` (for C→B promotion) and to the `RC_ONLY` UNION WHERE clause (so whitelisted RC rows don't double-count).

### 2026-04-14 — Final run
- Rebuilt registry: **2,667 MATCHED / 2,559 QT_ONLY / 2,381 RC_ONLY = 7,607 total** (8 pairs moved from RC_ONLY to MATCHED as expected; 7 were C-rated DR rows that got promoted via whitelist, 1 was already QT_ONLY).
- Ran final Q3 v3: **6,507 startups after filter** (4,651 QT-anchored + 1,856 RC_ONLY).

---

## Key decisions

| Decision | Rationale |
|---|---|
| **Full outer join (DR ⟗ RC)** | Neither source alone is complete. DR has classification + coverage, RC has VC signal + deal data. The outer join is what makes the registry defensible as "all Quebec tech companies we know about." |
| **Exclude RC_ONLY from headline... then include it** | v1/v2: excluded, because RC_ONLY hasn't been classified by us. v3: included via Policy E, because stakeholders asking "how many Quebec tech startups" want the broadest defensible count, and the answer with RC_ONLY is more honest (if surfaced with caveats). |
| **Pre-1990 cutoff** | Companies founded before the commercial internet era (~1991) aren't startups by any contemporary definition, regardless of operating status. ~960 rows excluded (between ~485 QT-anchored and ~475 RC_ONLY). |
| **Age-only lifecycle buckets** | v1 used age OR size OR capital triggers for "mature"; in practice 99% of mature was age-driven. Dropping size/capital simplified the story with zero signal loss. |
| **Non-tech name veto applied symmetrically** | Informed by Q2 eyeballs (DR side) and Q4 eyeballs (RC side). The same Rénovation / Déménagement / Restaurant / Insurance / Chiropractor / Yogurt patterns show up on both sides. Catching them consistently is the minimum. |
| **Match whitelist as a manual override path** | 63D's normalization has edge cases that aren't worth chasing on the silver side. A human-curated `REF.MANUAL_REVIEW_DECISIONS` append-only log lets us fix specific pairs without touching the matcher. Whitelist decisions flow through the `80` build automatically. |
| **Explain > optimize** | The user's explicit direction: stakeholders don't need an exact count, they need a defensible story. Publish ranges (6,507 / 5,100–5,500 / 4,651) keyed to different questions rather than a single "right answer." |

---

## Known issues and follow-ups

### Secondary-order data-quality gaps

1. **`RC_BUSINESS_STATUS` doesn't capture acquisitions.** PitchBook tracks acquisitions in `FINANCING_STATUS` or deal-type fields, not `BUSINESS_STATUS`. Our unified status mapping only reads `BUSINESS_STATUS`, so zero RC_ONLY rows show up in the `acquired` lifecycle bucket. Real-world impact: ~20–50 RC_ONLY acquisitions are classified as `mature` instead. Logged as open question for the Réseau Capital partner conversation.

2. **1,880 RC_ONLY rows are "dark matter"** with no sector assignment at all (96.9% of RC_ONLY post-filter). Our name-keyword veto only catches ~50 of the expected ~1,000 non-tech rows. Possible fixes:
   - Richer Harmonic extract from the partner (first preference)
   - Programmatic name/description-based classification on the RC side using positive tech keywords (`.tech`, `.ai`, `.io`, `software`, `platform`, `app`, `SaaS`, `AI`, `ML`, `blockchain`, `cyber`, etc.) + the existing non-tech vetoes
   - Manual triage round for the sector-null subset (expensive but most reliable)

3. **63D tier-1 domain normalization gap** that caused the 8 near-miss matches. `T_ENTITIES.DOMAIN_NORM` on the DR side uses a different normalization than the inline `LOWER(TRIM(COALESCE(PB_WEBSITE_DOMAIN, H_WEBSITE_DOMAIN)))` on the RC side in 63D. Whitelist fix is in place; root-cause fix in 63D is deferred.

4. **Sector flags are DR-side dominant.** `FLAG_SECTOR_PHARMA_BIOTECH`, `FLAG_SECTOR_GAMING`, `FLAG_SECTOR_SERVICES` fire mostly from DR industry fields, with RC contributing only when `PB_INDUSTRY_SECTOR` is populated (<3% of RC_ONLY). Pharma and gaming cuts in Q3 show only QT-anchored rows. Fixing this requires name-based classification on the RC side.

5. **Unknown_age bucket (650 rows)** — operational companies with no launch year on record. Could be reduced via cross-source enrichment (HubSpot, PitchBook year_founded, or website scraping for "about us" pages).

### Filter-level follow-ups

6. **City-conflict false positives fixed** — earlier runs had 2,070 city conflicts (78% of matched). After swapping `LOWER(city) != LOWER(city)` for `UTIL.NORMALIZE_TEXT_FOR_MATCHING(city) != ...`, the count dropped to 585. Those 585 are real disagreements and could feed a cross-check against Google Places / HubSpot for the matched subset.

7. **Match whitelist needs to grow.** 8 decisions in place so far (from Q4). A dedicated triage round on `UTIL.V_REVIEW_QUEUE_MATCHES` (6 genuine low-confidence tier-4 pairs + ~1,306 conflict-flagged rows) will produce more decisions, especially around name/domain conflicts and borderline tier-4 name-similarity matches.

8. **No blacklist decisions yet.** `REF.MANUAL_REVIEW_DECISIONS` is empty on the blacklist side. A first triage round on `UTIL.V_REVIEW_QUEUE_STARTUPS` (64 non-tech-name hits + ambiguous-sector RC rows + 898 C-promotion candidates) would produce the first confirmed blacklist entries.

### Partner conversation (in progress)

French email drafted (in conversation history) covering three questions to Réseau Capital:
1. Does Harmonic expose a richer sector taxonomy we could pull?
2. Where does PitchBook actually track acquisitions?
3. How does your side handle the pre-1990 cutoff?

Target meeting window: week of 2026-04-20.

---

## How to use the registry

### Query patterns

```sql
-- Full registry (no filter — for data quality / audit questions)
SELECT * FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY;

-- Working "Quebec tech startup" definition (apply this for most analyses)
SELECT *
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE ENTITY_TYPE IN ('MATCHED', 'QT_ONLY', 'RC_ONLY')
  AND NOT COALESCE(IS_STARTUP_BLACKLISTED, FALSE)
  AND NOT COALESCE(FLAG_NON_TECH_NAME_HIT, FALSE)
  AND (COALESCE(DRM_LAUNCH_YEAR, RC_FOUNDING_YEAR) IS NULL
       OR COALESCE(DRM_LAUNCH_YEAR, RC_FOUNDING_YEAR) > 1990);

-- Conservative "we trust Dealroom only" count (4,651)
SELECT COUNT(*)
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE ENTITY_TYPE IN ('MATCHED', 'QT_ONLY')
  AND NOT COALESCE(IS_STARTUP_BLACKLISTED, FALSE)
  AND NOT COALESCE(FLAG_NON_TECH_NAME_HIT, FALSE)
  AND (DRM_LAUNCH_YEAR IS NULL OR DRM_LAUNCH_YEAR > 1990);

-- Active early-stage startups only
-- (most natural headline for "how many Quebec startups are there right now")
SELECT *
FROM DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY
WHERE <startup filter above>
  AND DRM_COMPANY_STATUS = 'operational'
  AND DRM_LAUNCH_YEAR >= 2011;
```

### Refresh

The registry is rebuilt by running `ecosystem/sql/80_registry/80_consolidated_startup_registry.sql` in Snowsight. Prerequisites:

- `REF` schema bootstrapped (`sql/10_utils/70_manual_review_tables.sql` run at least once)
- `T_DRM_RC_MATCH_EDGES_DEDUP` current (rerun `63_match_edges/63D_drm_rc_matching.sql` if DR or RC silver has been refreshed)
- `DRM_STARTUP_CLASSIFICATION_SILVER` current (refreshed by the classifier job)

Validation queries run at the end of `80_consolidated_startup_registry.sql` — check entity type totals, inclusion reason breakdown, and conflict summary before using the refreshed registry for reporting.

### Row-count waypoints refresh

Run `ecosystem/sql/00_diagnostics/pipeline_row_counts.sql` and feed the outputs back into `docs/pipeline_overview.md` whenever stakeholder-facing numbers need to be updated.

### Investigating a new question

Write a focused diagnostic in `ecosystem/sql/00_diagnostics/Qn_<question>.sql`, run in Snowsight, save CSVs, analyze. Keep diagnostics read-only and section-by-section so each answer is its own result grid. Follow the Q1–Q4 pattern.

---

## Files produced during this work

### SQL (all in `ecosystem/sql/`)

- `00_diagnostics/Q1_drm_rc_match_ceiling.sql` — match ceiling investigation
- `00_diagnostics/Q1_drm_rc_match_ceiling_minimal.sql` — credit-conscious subset
- `00_diagnostics/Q2_rating_a_gap.sql` — rating-A gap investigation
- `00_diagnostics/Q3_startup_filter_and_lifecycle.sql` — canonical filter + lifecycle buckets (v1 → v2 → v3)
- `00_diagnostics/Q4_rc_only_delta_audit.sql` — RC_ONLY audit (waterfall, near-misses, sector distribution, sample for eyeball)
- `00_diagnostics/pipeline_row_counts.sql` — waypoint refresher
- `10_utils/70_manual_review_tables.sql` — REF schema with decisions table, stage, merge procedure, and consumption views
- `10_utils/71_seed_match_whitelist.sql` — seed 8 domain near-miss pairs
- `80_registry/80_consolidated_startup_registry.sql` — builds `GOLD.STARTUP_REGISTRY` (patched iteratively through the investigation)

### Documentation (all in `ecosystem/docs/`)

- `pipeline_overview.md` — stage-by-stage walkthrough with Mermaid diagram, row-count waypoints, canonical filter, lifecycle taxonomy, and the "why the count changes when we include RC" waterfall narrative
- `registry_build_summary_2026-04.md` — this file

### Memory entries (in `~/.claude/.../memory/`)

- `project_unified_registry.md` — full project state, decisions, Q1–Q4 findings, open items
- `feedback_registry_narrative.md` — the "explain > optimize" principle

### GitHub

All of the above pushed to `https://github.com/etienne-qt/data-ecosystem`:
- Commit `0b0315c` — initial pipeline overview doc
- Commit `d79ec87` — Q3 startup filter + lifecycle taxonomy
- Commit `bbd318f` — Q4 audit + Policy E filter + match whitelist path
- Commit `29d82b4` — v3 waterfall narrative in the doc
- Commit `6439d53` — full SQL pipeline (72 files)
- Commit `2bed2e5` — project cleanup (archive legacy Python, new CLAUDE.md)

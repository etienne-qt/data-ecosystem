---
id: SESSION-2026-04-17-req-post2024-hardtech
title: "Session log — REQ post-2024 hard tech / deep tech discovery"
type: session-log
author: AI Agent (Data & Analytics)
date: 2026-04-17
data_sources: [REQ]
topics: [hard-tech, deep-tech, req-discovery]
status: handed-off-to-human
---

# Session log — REQ post-2024 hard tech / deep tech discovery

## Prompt

> "Claude, fais-moi une analyse sur les données du REQ pour aider à trouver tout ce qui est en hard tech, deep tech au Québec dans les nouvelles inscriptions post 2024. Utilise des sous agents pour faire le travail."

Plus a follow-up: push the resulting scripts and all new markdown files / session logs to `origin/main` on `github.com/etienne-qt/data-ecosystem`.

## Approach

Two exploration sub-agents were dispatched in parallel before writing any code:

1. **REQ data + pipeline recon** — mapped the Snowflake tables under `DEV_DATAMART.ENTREPRISES_DU_QUEBEC` (ENTREPRISES_EN_FONCTION, REGISTRE_ADRESSES, REGISTRE_NOMS), walked the 31→32→51→63R→70 discovery chain, and confirmed the silver classification table `DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION` already exposes `PRODUCT_TIER`, `PRODUCT_SCORE`, `MATCHED_SIGNALS`, `IS_PRODUCT`, `CAE_CODE`, `HQ_CITY`, `INCORPORATION_YEAR`.

2. **Deep-tech definition recon** — surfaced the working definition from `knowledge_base/internal/hardware-photonics-req-2026.md` (photonics core, adjacent hardware, optics/imaging, biotech), the 14 hard/deep-tech keyword tokens already used in stage 31 (semiconductor, photonics, quantum, nanotech, robotics, drone, iot, aerospace, medtech, pharma, biotech, genomics, digital_health, cleantech), and the curated CAE set (2851, 3340–3359, 3361, 3674, 3699, 3740–3741, 3827, 3910, 4823).

## Key non-obvious finding from recon

The silver layer already does the hard work. Writing a fresh classifier would duplicate stage 31. The correct move is a **filter-only diagnostic** on top of `SILVER.REQ_PRODUCT_CLASSIFICATION` — no new tables, no re-scoring, fully read-only.

Caveat from prior analysis (`INTERNAL-hardware-photonics-req-2026`): **73% of historical hard-tech classifications rely on CAE code alone** — the biggest false-positive sources are CAE 3699 (laser cutting / beauty clinics) and 3827 (fiber-optic installers). Q5 separates keyword-confirmed (HIGH / MEDIUM confidence) from CAE-only (LOW) so the human reviewer can prioritize.

## Output produced

- **`sql/00_diagnostics/Q5_req_post2024_hardtech.sql`** — 9 result grids, read-only, runnable in Snowsight. Grids: precondition check, post-2024 tier volume, keyword-confirmed yearly trend, hard-tech CAE distribution, sub-category breakdown (14 rows), confidence-tiered candidate count, top-25 HQ cities, net-new vs. already-known via `T_REQ_STARTUP_MATCH_SUMMARY`, and a 50-row review queue with description previews.

## What the human runs next

1. Open `sql/00_diagnostics/Q5_req_post2024_hardtech.sql` in Snowsight.
2. **Precondition:** confirm `DEV_QUEBECTECH.SILVER.REQ_PRODUCT_CLASSIFICATION` exists and has a `MAX(INCORPORATION_YEAR) >= 2026`. If not, run stage 31 first.
3. Run each section in order; save each result grid as CSV (to `analytics/outputs/req_post2024_hardtech_YYYYMMDD/`).
4. Hand the CSVs back for analysis — the interesting deliverables are:
   - Formation rate change post-2024 vs. the 12–18/quarter baseline from the 2026-03-26 analysis.
   - Sub-category tilt (is the 2025 uptick still in adjacent hardware and optics/imaging, or is photonics core finally moving?).
   - Top 50 review queue → manual disambiguation → Dealroom / HubSpot entry.

## Follow-ups (not done in this session)

- Section 7 depends on `DEV_QUEBECTECH.UTIL.T_REQ_STARTUP_MATCH_SUMMARY` being built by stage 63R. If it's not yet in Snowflake, comment out section 7 or swap to `GOLD.STARTUP_REGISTRY.NEQ` (if populated).
- The diagnostic does not cross-reference INO / MEDTEQ+ / Écotech membership — noted in `hardware-photonics-req-2026.md` as the single most valuable enrichment. Out of scope here.
- Federal CBCA-incorporated hard-tech companies are still systematically missing from any REQ-only analysis. Separate initiative.

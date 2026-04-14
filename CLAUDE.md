# Quebec Tech — Ecosystem Data Platform

**Owner:** Étienne Bernard · **Team:** Data & Analytics
**Mandate:** collect and analyze data on the Quebec tech startup ecosystem, produce reports for decision-makers, and manage our data partnerships (Dealroom, Réseau Capital / Harmonic + PitchBook, HubSpot, Quebec REQ).

This project is the home of:

1. **The SQL pipeline** that builds our single source of truth, `GOLD.STARTUP_REGISTRY` in Snowflake
2. **Diagnostic SQL** (Q0–Q4) we use to investigate the registry and answer ecosystem questions
3. **The knowledge base** of markdown notes, external reports, and living narratives we draw on for the annual portrait and recommendation reports
4. **A small Python task** (`website_review`) for classifying companies via their websites — the only automated Python work still running

---

## How we actually work (2026-04 snapshot)

The real work happens in two places:

1. **Snowflake** — all pipeline tables, classification, matching, and the final registry live here. Work flows as:
   `Raw sources → BRONZE → SILVER → T_ENTITIES → matching → GOLD.STARTUP_REGISTRY`
2. **Markdown + Q-diagnostics** — we pose a question, write a focused SQL diagnostic in `sql/00_diagnostics/` (`Qn_*.sql`), run it in Snowsight, save the CSVs, and analyze. Insights land in `knowledge_base/` or `docs/`.

The Python package in `src/ecosystem/` is **intentionally minimal** — only the `website_review` task. Everything else that used to live there (connectors, knowledge-base engine, scheduler, other agent tasks, local Dealroom pipeline) has been moved to `archive/python-package/` because it was never actually run in production. If you need to revive any of it, it's there untouched.

---

## Project layout

```
ecosystem/
├── sql/                           # THE pipeline — Snowflake SQL, numbered by stage
│   ├── 00_diagnostics/            # Q0–Q4 investigation scripts + pipeline row counts
│   ├── 10_utils/                  # UDFs, config tables, manual review infra
│   ├── 20_bronze/                 # Typed landings from raw imports
│   ├── 30_silver/                 # Classification, signals, geo, industry, REQ bridge
│   ├── 40_dealroom/               # Dealroom ↔ REQ NEQ matching
│   ├── 50_analytics/              # Ad-hoc analyses
│   ├── 61_clean_staging_views/    # Normalized views per source
│   ├── 62_unified_entity_table/   # T_ENTITIES (cross-source union)
│   ├── 63_match_edges/            # DR↔RC and HS↔DR match edges
│   ├── 64_build_clusters/         # Label-propagation clustering
│   ├── 65_cluster_conflicts/      # Cluster audit
│   ├── 66_golden_per_cluster/     # Golden record per cluster
│   ├── 67_push_list_hubspot/      # HubSpot push-back
│   ├── 68_push_list_dealroom/     # Dealroom push-back
│   ├── 69_operational_tables/     # Cluster flags, resolution map
│   ├── 70_req_discovery/          # REQ discovery queue (deprioritized)
│   ├── 80_registry/               # Final GOLD.STARTUP_REGISTRY
│   └── 90_tests/                  # Smoke tests
│
├── docs/
│   ├── pipeline_overview.md       # Stage-by-stage walkthrough with Mermaid diagram,
│   │                              # row-count waypoints, and the canonical startup
│   │                              # filter + lifecycle taxonomy. START HERE.
│   └── methodology_and_statistics.md  # Older methodology notes
│
├── knowledge_base/                # Markdown KB — hand-managed
│   ├── index.md
│   ├── narratives/                # Living narrative documents
│   ├── insights/                  # By-topic and by-geography analytical notes
│   ├── reports/                   # External report summaries (BDC, CVCA, etc.)
│   └── internal/                  # Internal analyses (data dictionary, taxonomy)
│
├── src/ecosystem/                 # Minimal Python for website_review
│   ├── cli.py                     # `eco run-agent website_review`
│   ├── config.py                  # pydantic settings (reads .env)
│   ├── agents/
│   │   ├── runner.py              # AgentRunner, TaskResult, register_task
│   │   └── tasks/website_review.py
│   └── processing/
│       ├── classifier.py          # keyword/utility functions
│       ├── website_checker.py     # fetch / crawl / extract
│       └── website_reviewer.py    # classify startups from website content
│
├── scripts/
│   └── pipeline/run_website_review.py   # the one active entry point
│
├── archive/                       # reversible — all the legacy Python + scripts
│   ├── CLAUDE.md.legacy           # previous CLAUDE.md
│   ├── python-package/            # connectors, ingestion, knowledge, pipeline,
│   │                              # scheduler, 5 never-run agent tasks
│   ├── python-tests/              # pytest suite for the archived code
│   ├── legacy-scripts/            # enrich_corpo, extract_schema, fix_enrichment,
│   │                              # run_agent, ingest_report, query_kb,
│   │                              # run_full_pipeline, upload_to_snowflake
│   └── legacy-agent-config/       # agents/ top-level (asana_config, launchd/)
│
├── pyproject.toml                 # Python package config — only needed to
│                                  # `pip install -e` so `eco` is callable
├── .env.example                   # template — copy to .env and fill in
├── .gitignore
└── CLAUDE.md                      # this file
```

---

## The startup registry, in one paragraph

`DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY` is the full outer join of Dealroom (filtered to classifier ratings A+/A/B with C promoted when matched to RC) and Réseau Capital's `COMPANY_MASTER` (Harmonic + PitchBook, Quebec-filtered). Matching is a tiered waterfall: domain → LinkedIn → Crunchbase → name similarity ≥ 0.85, plus a manual whitelist for known near-misses. Each row carries its provenance (`ENTITY_TYPE` = MATCHED / QT_ONLY / RC_ONLY), coverage flags, conflict markers, and an effective rating after promotion/whitelist/blacklist. The current total is **7,607 rows**; after applying our startup filter (pre-1990 cutoff, non-tech name veto, blacklist), **6,507 lines** survive — of which roughly 5,100–5,500 are clearly tech startups by manual audit. See `docs/pipeline_overview.md` for the full waterfall and framing.

---

## How to do things

### Investigate an ecosystem question

1. Read `docs/pipeline_overview.md` so you know the stages and where to look.
2. Write a focused diagnostic SQL in `sql/00_diagnostics/Qn_<question>.sql`. Keep it read-only, cheap, and section-by-section so each answer is its own result grid.
3. Run it in Snowsight. Save every result grid as CSV.
4. Analyze the CSVs, write up findings in `knowledge_base/insights/` or a note back to the team.
5. If the finding changes the pipeline definition (e.g. a new filter rule), patch the relevant `sql/*.sql` file and rerun downstream stages.

### Rebuild the registry

1. (Optional) Rerun upstream silver jobs if Dealroom/RC data has been refreshed.
2. Run `sql/80_registry/80_consolidated_startup_registry.sql` in Snowsight (Run All).
3. Verify the validation queries at the bottom (entity-type totals, inclusion-reason breakdown, conflict/review counts).
4. Refresh row-count waypoints in `docs/pipeline_overview.md` via `sql/00_diagnostics/pipeline_row_counts.sql` if the counts have shifted meaningfully.

### Apply a manual review decision

1. Seed the decision in `REF.MANUAL_REVIEW_DECISIONS` — either via Snowsight direct insert (for small fixes, see `sql/10_utils/71_seed_match_whitelist.sql` as a template) or via CSV upload through `REF.MERGE_REVIEW_UPLOAD`.
2. Rerun `80_registry/80_consolidated_startup_registry.sql`. Match-whitelist decisions flow in automatically via the `match_bridge` CTE.

### Run the website review task

The only Python task still active. Requires `pip install -e .` once in a fresh venv to make `eco` callable.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

# Then:
python scripts/pipeline/run_website_review.py              # default tier 1_high
python scripts/pipeline/run_website_review.py --tier 2_medium
```

Logs go to `logs/<date>.jsonl`. Outputs go to `data/04_auto_reviews/`. Both directories are gitignored.

---

## Non-negotiables

- **Never commit `.env`.** `.env.example` is the template; real secrets go in `.env` which is gitignored.
- **Read-only queries stay read-only.** Diagnostic SQL in `00_diagnostics/` must never write to tables.
- **Manual review decisions are append-only.** Never UPDATE `REF.MANUAL_REVIEW_DECISIONS` — always insert a newer row; `V_MANUAL_REVIEW_CURRENT` takes the latest.
- **Never delete files from `archive/`** without explicit approval. The whole point of archiving is that it's reversible.
- **When reporting startup counts, prefer decomposable ranges over single numbers** (see `memory/feedback_registry_narrative.md` for the rationale). Example: "6,507 in the raw registry, ~5,100–5,500 clearly tech after accounting for RC_ONLY dark matter, 4,651 if you only trust Dealroom's classification."
- **No raw PII leaves Snowflake.** Aggregates, IDs, and statistics only in outputs that go to external systems.

---

## Current focus (Q2 2026)

1. **Portrait du Québec Tech 2026** — flagship annual report, target October 2026. Driven by the registry.
2. **Recommendation reports** — data-backed policy briefs for government stakeholders.
3. **Data partnership conversations** — clarifying three open questions with Réseau Capital (sector taxonomy in Harmonic-only rows, where PitchBook tracks acquisitions, pre-1990 methodology alignment).
4. **RC_ONLY sector classification** — 97% of RC_ONLY rows have no sector assignment. Next step is either programmatic name-based classification or a richer Harmonic extract from the partner.

---

## Environment notes

- Python ≥3.11 (3.14 via homebrew on the author's machine)
- No `uv` installed — use `python3 -m venv .venv` + `pip install -e ".[dev]"`
- macOS (Darwin), scheduling via launchd when needed (no active schedules right now)
- Snowflake is the only backend that matters; the local machine is a Snowsight client, not a data store

---

## If something is confusing

- **Pipeline question?** Read `docs/pipeline_overview.md`. Every stage and number is explained there.
- **"Why is this number so weird?"** Check `sql/00_diagnostics/` for the Q-file that already investigated it, or write a new one.
- **"What was this function / file for?"** If it's in `archive/`, check the path — we grouped by original purpose. Grep for the filename in `git log archive/` to find its last real use.
- **"Can I run the old knowledge base search?"** Not out of the box — the ChromaDB + DocumentStore engine is in `archive/python-package/knowledge/`. We now manage the KB as plain markdown files in `knowledge_base/` and rely on editor search.

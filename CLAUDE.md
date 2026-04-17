# Quebec Ecosystem Data — Shared Intelligence Repo

## What this repo is

This is the shared data collaboration repo for **Quebec Tech**, **Réseau Capital**, and the **Conseil de l'Innovation du Québec (CIQ)**. It contains taxonomy definitions, data pipeline scripts, extracted insights from ecosystem reports, and shared Claude Code skills.

**This repo does not contain raw data.** All record-level and licensed data lives in Snowflake or on local machines. Only aggregate analytics, publicly available data, code, and documentation are committed here. See `DATA-GOVERNANCE.md` for the full policy.

## Repo structure

```
quebec-ecosystem-data/
├── CLAUDE.md                  ← You are here (root context for Claude Code)
├── CONTRIBUTING.md            ← Collaboration guide for all partners
├── DATA-GOVERNANCE.md         ← Data classification and commitment rules
├── .claude/
│   └── settings.json          ← Shared Claude Code project settings
├── skills/                    ← Shared Claude Code skills (loaded every session)
│   ├── taxonomy-lookup.md
│   ├── snowflake-query.md
│   ├── insight-extractor.md
│   ├── report-builder.md
│   ├── data-enrichment.md
│   └── branch-conventions.md
├── taxonomy/                  ← Canonical definitions (YAML)
│   ├── sectors.yaml           ← Sector/industry classification
│   ├── stages.yaml            ← Funding stage definitions
│   ├── startup-criteria.yaml  ← What qualifies as a startup
│   ├── geographies.yaml       ← Region/city codes
│   └── labels.yaml            ← Tags, categories, flags
├── pipelines/                 ← Shared Python scripts and SQL
│   ├── enrichment/            ← Data enrichment scripts
│   ├── transforms/            ← Snowflake transformation logic
│   ├── validation/            ← Data quality checks
│   └── utils/                 ← Shared utility functions
├── insights/                  ← Structured findings from reports
│   ├── index.yaml             ← Master registry of all insights
│   └── 2026-q2/              ← Insights organized by period
│       ├── vc-overview.md
│       ├── ai-index.md
│       └── ...
├── reports/                   ← Published final documents (PDFs)
│   └── 2026-q2/
├── public-data/               ← Open-source datasets (ok to commit)
│   └── README.md              ← Source attribution for each file
├── docs/                      ← Data dictionary, methodology
│   ├── data-dictionary.md
│   ├── methodology.md
│   └── snowflake-schemas.md
└── data/                      ← LOCAL ONLY (gitignored)
    └── README.md              ← Explains what goes here
```

## Data governance — critical rules

These rules apply to every commit, every PR, every Claude Code session:

1. **No record-level licensed data in this repo.** Dealroom URLs, PitchBook deal IDs, individual company financials from licensed sources — none of these get committed. They stay in Snowflake or in local `data/`.
2. **Aggregate numbers only for insights.** Totals, averages, counts, percentages, medians, ranges. Never individual records.
3. **Public data is fine to commit** if it comes from an open source (StatCan, OECD, REQ, published reports). Attribute the source.
4. **Code is always committable.** Scripts, SQL, pipeline logic — commit freely. But scripts must reference data paths in the gitignored `data/` directory or Snowflake queries, never embed raw data inline.
5. **Company names are ok** only when referencing publicly available information (e.g., a company's website, a published funding announcement). Never commit non-public company information sourced from licensed platforms.

See `DATA-GOVERNANCE.md` for the full data source classification table.

## Taxonomy — shared definitions

All sector codes, funding stage labels, startup criteria, and category definitions live in `taxonomy/*.yaml`. These are the canonical reference for all analyses.

When classifying a company or a deal:
- Always use codes from `taxonomy/sectors.yaml` — never invent ad-hoc categories
- Funding stages follow the definitions in `taxonomy/stages.yaml`
- The startup definition criteria in `taxonomy/startup-criteria.yaml` determine what is and isn't counted in ecosystem metrics

Taxonomy changes require a `taxonomy/` branch and a PR approved by at least one representative from each partner org (QT, RC, CIQ).

## Branch conventions

| Prefix | Purpose | Merges to main? | Lifespan |
|--------|---------|-----------------|----------|
| `report/{name}` | Structured report production | Yes — insights, scripts, final PDF | Weeks to a quarter |
| `taxonomy/{change}` | Definition/classification changes | Yes — requires cross-org PR review | Days to weeks |
| `pipeline/{change}` | New or modified scripts/SQL | Yes — with code review | Days to weeks |
| `scratch/{org}-{description}` | Ad-hoc queries, exploration | **No** — close or cherry-pick | Days |

### Naming examples
- `report/q2-2026-vc-overview`
- `taxonomy/cleantech-sector-rework`
- `pipeline/enrichment-v2-dealroom`
- `scratch/rc-seed-deal-breakdown`
- `scratch/qt-udes-spinoff-count`
- `scratch/ciq-barometer-cross-ref`

### Commit messages
Use the format: `[type] short description`
- `[insight] Add Q2 2026 VC aggregate findings`
- `[taxonomy] Revise cleantech sub-sector codes`
- `[pipeline] Add Dealroom enrichment script`
- `[docs] Update Snowflake schema documentation`
- `[skill] Improve snowflake-query patterns`

## Snowflake context

The shared Snowflake instance contains tables from all three partner organizations. When writing queries:
- Use fully qualified table names: `{database}.{schema}.{table}`
- Reference the shared schema documentation in `docs/snowflake-schemas.md`
- Use the taxonomy codes from `taxonomy/` for any filtering or grouping — never hardcode category strings
- When query results are destined for a commit (an insight or a report), aggregate before extracting
- When exploring locally on a scratch branch, raw queries are fine — they stay local

## Insight format

All insights committed to `insights/` use markdown with YAML frontmatter:

```yaml
---
id: "2026-q2-vc-001"
source: "Réseau Capital Q4 2024 Annual Report"
source_type: licensed          # licensed | public | derived
date_extracted: 2026-04-17
report_branch: "report/q2-2026-vc-overview"
topics:
  - funding
  - seed-stage
geography: quebec
period: "2024"
confidence: high               # high | medium | low
data_points:
  - metric: total_vc_invested
    value: 2000000000
    unit: CAD
    period: "2024"
  - metric: seed_deal_count
    value: 39
    period: "2024"
  - metric: seed_deal_yoy_change
    value: -0.52
    unit: ratio
    period: "2024-vs-2023"
---

Quebec VC investment totaled $2B across 108 deals in 2024.
While total invested amounts rose 35% year-over-year, deal
volume declined 25%. The seed stage saw the most pronounced
contraction: 39 deals representing $112M, down 52% in volume
and 65% in value compared to 2023.
```

Key rules:
- `source_type: licensed` means the insight was derived from Dealroom, PitchBook, or other commercial data — only aggregates are permitted
- `source_type: public` means anyone can verify the number from a public source
- `source_type: derived` means it was computed from a combination of sources
- The narrative section below the frontmatter should be self-contained and readable without the structured data

## Skills reference

Shared skills in `skills/` are loaded by Claude Code at session start. They teach Claude Code how to work within this repo's conventions. Key skills:

- **taxonomy-lookup** — How to read and apply sector codes, stage labels, and startup criteria from the YAML files
- **snowflake-query** — Shared table schemas, SQL patterns, naming conventions
- **insight-extractor** — How to structure findings into the frontmatter format, enforcing aggregation rules
- **report-builder** — How to initialize a report branch with the correct folder structure
- **data-enrichment** — How to enrich datasets using Dealroom, Snowflake, and web sources while respecting data governance
- **branch-conventions** — Naming rules, commit format, PR workflow, scratch-vs-merge decisions

## Partner organizations

| Org | Abbreviation | Primary data contributions |
|-----|-------------|---------------------------|
| Quebec Tech (formerly AQT) | QT | Dealroom/Radar data, ecosystem portraits, startup counts |
| Réseau Capital | RC | PitchBook VC/PE data, deal flow analytics, AI Index |
| Conseil de l'Innovation du Québec | CIQ | Baromètre de l'innovation, policy metrics |

## Quarterly cycle

Each quarter follows this rhythm:
1. **Taxonomy review** — Any needed definition changes are proposed via `taxonomy/` branches and merged early in the quarter
2. **Report production** — Active `report/` branches for the quarter's deliverables, pulling from Snowflake and extracting insights
3. **Insight consolidation** — Report branches merge, new insights land on main
4. **Release tag** — Main is tagged (e.g., `v2026-Q2`) as the quarter's canonical snapshot
5. **Skills refinement** — Any skill improvements discovered during the quarter get PRed to main

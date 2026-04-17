# Data Governance Policy

This document defines what data can and cannot be committed to this repository. All contributors must follow these rules. Violations are difficult to undo — once data enters Git history, it requires a full history rewrite to remove.

## Core principle

**This repo stores intelligence, not data.** Raw data lives in Snowflake or on local machines. What we share here is the knowledge derived from that data: aggregate findings, analysis code, and methodology.

## Data source classification

| Source | Type | Record-level in repo? | Aggregates in repo? | Notes |
|--------|------|----------------------|---------------------|-------|
| Dealroom | Licensed | **No** | Yes — counts, totals, % only | Commercial license via Quebec Tech. No Dealroom URLs, company-level export fields, or proprietary scores. |
| PitchBook | Licensed | **No** | Yes — counts, totals, % only | Commercial license via Réseau Capital. No PitchBook deal IDs, investor profiles, or company-level financials. |
| CVCA Intelligence | Licensed | **No** | Yes — aggregate deal flow | Used by Réseau Capital for VC/PE reports. |
| Snowflake (shared tables) | Internal | **No** | Yes — aggregated query results | Shared instance across QT, RC, CIQ. Query results must be aggregated before committing. |
| Dealroom Radar (Quebec Tech Radar) | Licensed | **No** | Yes — ecosystem-level metrics | Powered by Dealroom. Same restrictions as Dealroom. |
| Statistics Canada | Public | Yes | Yes | Open data. Attribute the specific table/survey. |
| OECD | Public | Yes | Yes | Open data. Cite the database and indicator. |
| Registraire des entreprises du Québec | Public | Yes | Yes | NEQ numbers and basic registration info are public record. |
| ISQ (Institut de la statistique du Québec) | Public | Yes | Yes | Open data. Cite the publication. |
| Published reports (annual reports, press releases) | Public | Yes | Yes | If it's publicly available on a website, it's citable. |
| Internal partner data (CRM, HubSpot, internal metrics) | Internal | **No** | Case by case | Discuss with the data owner before committing any derivative. |

## What "aggregate" means in practice

An aggregate is a statistical summary that cannot be reverse-engineered to identify individual records.

**Acceptable aggregates:**
- "39 seed-stage deals in Quebec in 2024"
- "Total VC invested: $2.0B across 108 deals"
- "AI sector represented 54% of deals"
- "Median seed round size: $2.5M"
- "Year-over-year change: -52%"

**Not acceptable (record-level):**
- "Company X raised $5M from Investor Y on [date]" (from licensed source)
- A CSV with 200 rows of company-level data from Dealroom
- A list of all companies in a specific Dealroom filter with their attributes
- Query results showing individual Snowflake records

**Exception for public information:** If a funding round was announced via press release, news article, or the company's own website, it is publicly available and can be referenced with attribution. The test: could someone find this information without a Dealroom/PitchBook license?

## File-level rules

### Files that should NEVER be committed
- `*.csv` in non-`public-data/` directories (use `public-data/` for open datasets only)
- `*.parquet`, `*.pkl`, `*.feather`, `*.arrow`
- `*.xlsx`, `*.xls` containing raw data exports
- Any file in the `data/` directory (gitignored)
- Snowflake export files
- API response dumps

### Files that are always fine to commit
- Python scripts (`*.py`)
- SQL files (`*.sql`)
- YAML definitions (`*.yaml`, `*.yml`)
- Markdown documentation and insights (`*.md`)
- Published PDFs (`*.pdf`) in `reports/`
- Small CSVs of public data in `public-data/` with source attribution
- Configuration files (non-credential)

### Grey areas — ask before committing
- Derived datasets that combine public and licensed sources
- Anonymized or pseudonymized records
- Sample datasets used for testing pipelines
- Screenshots of dashboards that may show licensed data

## Pre-commit checks

The repo includes pre-commit hooks that run automatically:

1. **File size check**: Warns on files larger than 1MB outside `reports/`
2. **Data file detection**: Blocks `*.csv`, `*.parquet`, `*.xlsx` outside `public-data/`
3. **Taxonomy validation**: Ensures `taxonomy/*.yaml` files are well-formed
4. **Sensitive field scan**: Warns if commit content contains patterns matching known licensed field names (e.g., `dealroom_url`, `pitchbook_id`, `deal_id`)

These are guardrails, not guarantees. PR reviewers should still verify data governance compliance.

## For Claude Code sessions

When working in Claude Code within this repo:

- **Querying Snowflake**: Raw query results are fine for local exploration. Before committing any derived finding, aggregate it.
- **Producing insights**: Use the `insight-extractor` skill, which enforces the `source_type` classification and aggregation rules.
- **Enrichment work**: When enriching datasets, the enriched data stays in `data/` (local). The enrichment script goes in `pipelines/enrichment/`. If the enrichment produces an insight worth sharing, extract the aggregate and commit it to `insights/`.
- **Building reports**: The analysis and narrative are committable. Supporting data tables with record-level detail are not.

## Incident response

If record-level licensed data is accidentally committed:

1. **Do not push.** If you haven't pushed yet, amend the commit: `git reset HEAD~1`
2. **Already pushed?** Alert the repo maintainers immediately. The branch will need to be force-pushed with the data removed, and if merged to main, a history rewrite may be necessary.
3. **Prevention is far easier than remediation.** When in doubt, don't commit — ask first.

## Review checklist for PRs

Reviewers should verify:

- [ ] No raw data files (CSV, Parquet, Excel) outside `public-data/`
- [ ] Insight files use only aggregate numbers for licensed sources
- [ ] Company-specific information is sourced from public references
- [ ] Scripts reference `data/` paths or Snowflake queries, not embedded data
- [ ] Taxonomy changes are well-formed YAML with clear rationale
- [ ] Commit messages follow the `[type] description` format
- [ ] No credentials, API keys, or connection strings in committed files

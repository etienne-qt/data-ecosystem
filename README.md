# Quebec Ecosystem Data

Shared data intelligence repository for Quebec's tech ecosystem, maintained collaboratively by **Quebec Tech**, **Réseau Capital**, and the **Conseil de l'Innovation du Québec (CIQ)**.

## What's in this repo

This repo is the shared analytical brain for Quebec's ecosystem data partnership. It contains:

- **Taxonomy definitions** — Canonical sector codes, funding stage labels, startup criteria, and classification rules that all three organizations use consistently
- **Data pipelines** — Python scripts, SQL transformations, and enrichment logic that run against our shared Snowflake instance
- **Extracted insights** — Structured findings from ecosystem reports, formatted as queryable markdown with YAML frontmatter
- **Published reports** — Final PDF documents produced collaboratively
- **Shared Claude Code skills** — Skills that teach Claude Code how to work within our conventions, query patterns, and governance rules
- **Documentation** — Data dictionary, methodology notes, Snowflake schema docs

**This repo does not contain raw data.** Licensed data (Dealroom, PitchBook) stays in Snowflake. See [DATA-GOVERNANCE.md](DATA-GOVERNANCE.md) for details.

## Quick start

```bash
# Clone
git clone git@github.com:quebec-ecosystem-data/quebec-ecosystem-data.git
cd quebec-ecosystem-data

# Set up local environment
cp .env.example .env        # Edit with your Snowflake credentials
mkdir -p data               # Local data directory (gitignored)
pip install pre-commit && pre-commit install

# Start working
git checkout -b scratch/your-org-your-task
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full setup guide and branch conventions.

## Branch conventions

| Prefix | Use case | Merges to main? |
|--------|----------|-----------------|
| `report/` | Structured report production | Yes |
| `taxonomy/` | Definition changes | Yes (cross-org review required) |
| `pipeline/` | Script/SQL changes | Yes |
| `scratch/` | Ad-hoc queries, exploration | No — close or cherry-pick |

## Using with Claude Code

This repo is designed to work with Claude Code. The `CLAUDE.md` file provides session context, and the `skills/` directory contains shared skills that are loaded automatically. Connect your local Snowflake account via MCP, and Claude Code will use the shared taxonomy and conventions for all queries and analyses.

## Partners

| Organization | Role |
|-------------|------|
| [Quebec Tech](https://quebectech.com) | Dealroom/Radar data, ecosystem portraits, startup metrics |
| [Réseau Capital](https://reseaucapital.com) | PitchBook VC/PE data, deal flow analytics |
| [CIQ](https://conseilinnovation.quebec) | Baromètre de l'innovation, policy metrics |

## Quarterly releases

Main is tagged at the end of each quarter (e.g., `v2026-Q2`) as a canonical snapshot of the shared knowledge base.

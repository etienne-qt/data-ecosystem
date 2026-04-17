# Contributing — Quebec Ecosystem Data Repo

Welcome to the shared data collaboration between Quebec Tech, Réseau Capital, and CIQ. This guide covers everything you need to start contributing.

## Getting started

### 1. Clone the repo

```bash
git clone git@github.com:quebec-ecosystem-data/quebec-ecosystem-data.git
cd quebec-ecosystem-data
```

### 2. Set up your local environment

Create a `.env` file in the repo root (this is gitignored — your credentials stay local):

```bash
# .env — never committed
SNOWFLAKE_ACCOUNT=your_org_account
SNOWFLAKE_USER=your_username
SNOWFLAKE_ROLE=your_role
SNOWFLAKE_WAREHOUSE=your_warehouse
SNOWFLAKE_DATABASE=shared_ecosystem
```

Create the local `data/` directory for any raw exports you need to work with:

```bash
mkdir -p data
# This directory is gitignored — put raw Dealroom/PitchBook exports here
```

### 3. Set up Claude Code

If you're using Claude Code (recommended), the repo is already configured to provide shared context. When you start a Claude Code session in this directory, it will automatically load:

- `CLAUDE.md` — the root context with all conventions and rules
- `skills/` — shared skills that teach Claude Code our patterns
- `taxonomy/` — sector codes, stage definitions, startup criteria

**Snowflake access — current mode (April 2026).** Claude Code does NOT query Snowflake directly yet. The workflow is: Claude writes SQL into a file under `pipelines/`, you run it in Snowsight, save the CSV to `data/` (gitignored), and share the aggregate back with Claude for analysis. This is the same code-generation pattern Quebec Tech has used internally. See `skills/snowflake-query.md` for the full handoff loop and `ONBOARDING.md` Step 6 for what to verify on day 1.

**Future state.** Once the three orgs pick a Snowflake MCP server and wire it up, Claude will be able to query directly. The MCP config at that point will go in `.claude/settings.local.json` (gitignored) with credentials in the `env` block, never hardcoded. Until then, the MCP section below is aspirational.

<details>
<summary>Aspirational MCP config (not active yet)</summary>

```json
{
  "mcpServers": {
    "snowflake": {
      "command": "your-snowflake-mcp-server",
      "args": ["--account", "$SNOWFLAKE_ACCOUNT"],
      "env": {
        "SNOWFLAKE_USER": "$SNOWFLAKE_USER",
        "SNOWFLAKE_ROLE": "$SNOWFLAKE_ROLE"
      }
    }
  }
}
```

</details>

### 4. Install pre-commit hooks

```bash
pip install pre-commit
pre-commit install
```

The hooks will check for accidental data file commits and validate taxonomy YAML on every commit.

## Branch workflow

### Which branch type should I use?

**I'm producing a report or analysis with structured deliverables** → `report/{name}`
```bash
git checkout -b report/q3-2026-ai-index
```
This branch merges to main when the report is finalized. Commit the analysis scripts, extracted insights (aggregate only), and the final PDF.

**I need to change a definition, sector code, or classification** → `taxonomy/{change}`
```bash
git checkout -b taxonomy/add-quantum-computing-sector
```
These require PR approval from at least one person at each partner org before merging.

**I'm building or modifying a shared pipeline or script** → `pipeline/{change}`
```bash
git checkout -b pipeline/dealroom-enrichment-v3
```
Merges to main after code review.

**I have a quick question or ad-hoc query** → `scratch/{org}-{description}`
```bash
git checkout -b scratch/rc-pe-deal-size-distribution
```
These are **never merged wholesale** to main. When you're done, either close the branch or cherry-pick specific artifacts (a reusable script, a valuable insight) into a proper PR.

### The scratch workflow in detail

Scratch branches are your personal workspace. Use them freely:

1. Create the branch: `git checkout -b scratch/rc-exploration-name`
2. Work in Claude Code, commit as you go (commits = save points)
3. When finished, evaluate what you produced:
   - **Nothing reusable?** Close the branch: `git checkout main && git branch -d scratch/rc-exploration-name`
   - **Found a reusable script?** Cherry-pick it to a `pipeline/` PR
   - **Extracted a valuable insight?** Cherry-pick it to an `insights/` PR
   - **Discovered a taxonomy gap?** Open a `taxonomy/` branch for the change
4. The branch history stays searchable in Git even after closing

### Commit message format

```
[type] Short description

[insight] Add Q2 2026 seed-stage aggregate findings
[taxonomy] Add quantum computing sub-sector under deeptech
[pipeline] Refactor Dealroom enrichment to handle missing NEQ
[docs] Update Snowflake schema for new CIQ tables
[skill] Add PitchBook aggregation patterns to snowflake-query
[fix] Correct sector code mapping for healthtech
```

### Pull request process

1. Push your branch and open a PR
2. For `taxonomy/` changes: request review from at least one person per org
3. For `report/` and `pipeline/` changes: request review from at least one other contributor
4. For all PRs: the reviewer checks data governance compliance (no raw data, no record-level licensed info)
5. Merge via squash-and-merge to keep main's history clean
6. After merge, delete the remote branch

## Data governance — what you can and can't commit

**Read `DATA-GOVERNANCE.md` for the full policy.** The short version:

| You can commit | You cannot commit |
|---------------|-------------------|
| Aggregate numbers (totals, averages, counts, %) | Individual company records from Dealroom/PitchBook |
| Python/SQL scripts | Raw data exports (CSVs, Parquet files) |
| Taxonomy definitions (YAML) | Snowflake query results with record-level data |
| Publicly available data (StatCan, OECD, REQ) | Non-public company information |
| Published report PDFs | Intermediate analysis files with raw data |
| Insight files with aggregate findings | Anything in the `data/` directory |

**When in doubt:** if the number could be traced back to a specific record in a licensed database, aggregate it further before committing.

## Working with taxonomy files

Taxonomy files in `taxonomy/` are YAML and serve as the canonical reference for all analyses. Example from `taxonomy/sectors.yaml`:

```yaml
sectors:
  - code: AI
    label_en: "Artificial intelligence"
    label_fr: "Intelligence artificielle"
    parent: ICT
    description: "Companies whose core product/service relies on AI/ML"
    includes:
      - "Machine learning platforms"
      - "NLP/LLM applications"
      - "Computer vision"
      - "AI infrastructure"
    excludes:
      - "Companies that merely use AI as a feature (classify by primary product)"
```

When you need a new code or want to modify a definition:
1. Open a `taxonomy/` branch
2. Edit the relevant YAML file
3. Run the validation: `python pipelines/validation/validate_taxonomy.py`
4. Open a PR with a clear explanation of why the change is needed
5. All three orgs review before merge

## Working with insights

When you extract findings from an analysis or report, format them as markdown with YAML frontmatter and place them in `insights/{period}/`. See the `CLAUDE.md` file for the full format specification.

Key rules:
- Every data point needs a `source_type` (licensed, public, or derived)
- Licensed-source insights may only contain aggregate numbers
- Link the insight to its report branch if applicable
- Use taxonomy codes for topics and geography, not free text

## Quarterly release cycle

At the end of each quarter:
1. All active report branches should be merged or explicitly carried forward
2. Main is tagged: `git tag v2026-Q2`
3. Stale scratch branches (30+ days) get reviewed — close or promote
4. Skills are reviewed for any improvements discovered during the quarter
5. The `insights/index.yaml` is updated to reflect all new entries

## Getting help

- **Repo questions:** Open a GitHub issue or ask in our shared channel
- **Taxonomy debates:** Open a `taxonomy/` branch and use the PR discussion
- **Claude Code issues:** Check that your local MCP config is correct and that you've pulled the latest `skills/` from main
- **Data governance uncertainty:** When in doubt, ask before committing — it's easier to add data than to scrub it from Git history

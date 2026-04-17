# Skill: Branch Conventions

## Purpose
This skill teaches you the branch naming rules, commit message format, and workflow patterns used in this repo.

## When to use
- Starting a new piece of work (choosing the right branch type)
- Committing changes (formatting the message correctly)
- Deciding whether to merge or close a branch
- Helping a collaborator set up their workflow

## Branch types

### `report/{report-name}`
**For:** Producing a structured report or analysis with defined deliverables.
**Examples:** `report/q2-2026-vc-overview`, `report/ai-index-2026`, `report/scaleup-gap-analysis`
**Lifecycle:** Weeks to a quarter. Created when report work begins, merged when the report is finalized.
**What merges:** Insight files (in `insights/`), analysis scripts (in `pipelines/`), the final PDF (in `reports/`).
**Review:** At least one other contributor reviews the PR.

### `taxonomy/{change-description}`
**For:** Changing definitions, sector codes, stage labels, or classification rules.
**Examples:** `taxonomy/add-quantum-computing-sector`, `taxonomy/revise-seed-stage-criteria`, `taxonomy/cleantech-sub-sectors`
**Lifecycle:** Days to weeks. Short and focused.
**What merges:** Modified YAML files in `taxonomy/`.
**Review:** Requires approval from at least one representative of each partner org (QT, RC, CIQ). This is the highest review bar because taxonomy changes affect all analyses.

### `pipeline/{change-description}`
**For:** Adding or modifying shared Python scripts, SQL transformations, or utility functions.
**Examples:** `pipeline/dealroom-enrichment-v3`, `pipeline/snowflake-sync-ciq-tables`, `pipeline/validation-add-neq-check`
**Lifecycle:** Days to weeks.
**What merges:** Code files in `pipelines/`.
**Review:** At least one contributor with relevant technical context.

### `scratch/{org}-{description}`
**For:** Ad-hoc queries, exploratory analysis, one-time investigations.
**Examples:** `scratch/rc-pe-deal-distribution`, `scratch/qt-udes-spinoff-count`, `scratch/ciq-barometer-cross-ref`
**Lifecycle:** Hours to days. Short-lived.
**What merges:** **Nothing directly.** Scratch branches are never merged wholesale to main.
**Promotion path:** If the work produces something reusable:
1. Cherry-pick the specific artifact (script, insight, taxonomy suggestion) into a proper branch type
2. Open a PR from that branch
3. Close the scratch branch

**Key rule:** even after closing, scratch branch history remains searchable in Git via `git log --all`.

## Commit message format

```
[type] Short description (imperative mood, <72 chars)
```

Valid types:
- `[insight]` — New or updated insight files
- `[taxonomy]` — Taxonomy definition changes
- `[pipeline]` — Script or SQL changes
- `[skill]` — Claude Code skill updates
- `[docs]` — Documentation changes
- `[fix]` — Bug fixes or corrections
- `[meta]` — Repo configuration, CI, .gitignore changes

Examples:
```
[insight] Add Q2 2026 seed-stage aggregate findings
[taxonomy] Add quantum computing sub-sector under deeptech
[pipeline] Handle missing NEQ in Dealroom enrichment
[skill] Add aggregation threshold rules to insight-extractor
[docs] Document new CIQ Snowflake tables
[fix] Correct sector code for healthtech-genomics overlap
[meta] Update pre-commit hook to check for PitchBook field names
```

## Decision helper

When starting new work, ask:

1. **Will this produce a report or structured deliverable?** → `report/`
2. **Am I changing how we define or classify things?** → `taxonomy/`
3. **Am I building or fixing shared code?** → `pipeline/`
4. **Am I just exploring or answering a quick question?** → `scratch/`
5. **Am I updating documentation or skills?** → Can often go directly on a short-lived branch or even directly on main for minor docs fixes.

## Stale branch policy

- Scratch branches older than 30 days are flagged for review (via GitHub Actions)
- The owner should either promote useful artifacts or close the branch
- Report branches should not exceed one quarter without a check-in
- Taxonomy and pipeline branches should merge within a few weeks

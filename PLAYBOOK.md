# Playbook — Day-to-Day Workflows

Concrete walkthroughs for the things you'll actually do in this repo.
Each scenario shows the branch you create, the commands you run, what
Claude Code can do for you, and what lands in `main`.

Before anything else, know the four branch types (from
`skills/branch-conventions.md`):

| Prefix | When to use | Merges to main? |
|--------|-------------|-----------------|
| `scratch/{org}-{desc}` | Quick queries, exploration, one-off checks | **No** — close or cherry-pick |
| `pipeline/{desc}` | New or modified SQL / Python scripts | Yes (code review) |
| `taxonomy/{desc}` | Changes to sector codes, stages, criteria | Yes (cross-org review) |
| `report/{desc}` | Structured reports with deliverables | Yes (reviewer) |

Commit messages always use **`[type] Short description`** — e.g.
`[insight] Add Q2 2026 seed-stage aggregate findings`. The valid types
are `insight`, `taxonomy`, `pipeline`, `skill`, `docs`, `fix`, `meta`.

---

## Scenario A — I have a quick question or one-off query

**Goal:** answer a question from a colleague, explore a data pattern,
or scratch out an idea. Nothing here is guaranteed to ship.

**Example:** "What was the average seed round size in Quebec ICT in
2024?"

**Branch:**
```bash
git checkout main && git pull
git checkout -b scratch/rc-seed-ict-2024
```

**The handoff loop** — Claude Code does NOT connect to Snowflake yet.
The workflow has four steps:

1. **Claude writes the SQL.** In Claude Code:
   > "Write a Snowflake query that returns the count of seed-stage deals
   > and median round size for Quebec ICT companies in 2024. Use the
   > taxonomy codes from `taxonomy/sectors.yaml` and stage codes from
   > `taxonomy/stages.yaml`. Aggregate only — don't return company-level
   > rows. Save it to
   > `pipelines/validation/diagnostics/Q_seed_ict_2024.sql`."

2. **You run it in Snowsight.** Open Snowsight, set your warehouse,
   paste the SQL (or open the saved file), run it. Save the result grid
   as CSV to `data/outputs/scratch-rc-seed-ict-2024-YYYYMMDD/seed_ict.csv`.
   That directory is gitignored — the raw results stay on your machine.

3. **Claude reads the CSV.** Back in Claude Code:
   > "Here's the output of the seed-ICT query:
   > @data/outputs/scratch-rc-seed-ict-2024-YYYYMMDD/seed_ict.csv
   > Summarize the aggregate finding in 2-3 sentences."

4. **Decide what's worth keeping.** The SQL file is committable
   (code is always fine). The CSV is not. An aggregate finding can
   be promoted to an insight (see Scenario D).

**When you're done, decide:**

- **Nothing reusable** → close the branch:
  ```bash
  git checkout main && git branch -D scratch/rc-seed-ict-2024
  ```
- **Reusable SQL** → cherry-pick into a `pipeline/` branch (see C).
- **Valuable aggregate finding** → promote into an `insight/` entry
  (see D).

**Never merge a scratch branch wholesale.** The commits stay searchable
in Git history even after the branch closes.

---

## Scenario B — I'm producing a report

**Goal:** a structured, multi-week deliverable like a quarterly AI
Index or a cleantech scaleup report.

**Branch:**
```bash
git checkout -b report/q3-2026-ai-index
```

**Initialize the report skeleton:**
```
reports/2026-q3/ai-index/
├── README.md          # scope, data sources, timeline, contributors
├── analysis/          # working SQL / Python
└── drafts/            # markdown drafts of the narrative
```

**In Claude Code:**
> "Read `skills/report-builder.md` and scaffold a report directory at
> `reports/2026-q3/ai-index/` following that template. Fill the
> README with scope=Quebec, period=2024-Q4, sectors=AI. Leave the
> other fields blank."

Work iteratively. Push draft commits on the branch — they're your save
points.

**When the report is done, what merges to main:**

1. **Extracted insights** → `insights/2026-q3/{topic}.md` with the
   frontmatter format (see `skills/insight-extractor.md`).
2. **Reusable scripts** → `pipelines/` (only if useful beyond this
   report).
3. **Final PDF** → `reports/2026-q3/ai-index.pdf`.
4. **Update** `insights/index.yaml` with the new entries.

Report-specific working scripts stay in the branch history, not on
main.

**PR:** request review from at least one other contributor. Squash and
merge to keep main clean.

---

## Scenario C — I'm building or fixing a pipeline script

**Goal:** new SQL transform, updated enrichment logic, or a fix to an
existing diagnostic.

**Example:** "Our Dealroom matching misses companies with accented
characters in the name."

**Branch:**
```bash
git checkout -b pipeline/fix-accented-name-matching
```

**Where the script goes** (the refactor laid this out; keep to it):

- SQL transforms → `pipelines/transforms/{stage}/`
- Enrichment scripts → `pipelines/enrichment/`
- Diagnostics (read-only Q-files) → `pipelines/validation/diagnostics/`
- Shared UDFs / utilities → `pipelines/utils/sql/shared/`

**In Claude Code:**
> "Read `pipelines/transforms/entity_resolution/63_match_edges/
> 63B_name_similarity_edges.sql` and propose a fix that normalizes
> accented characters before fuzzy matching. Preserve read-compatibility
> with downstream stages."

**Test before merging:** Claude can write or update a smoke test under
`pipelines/validation/tests/`. For SQL changes that affect the registry,
re-run `80_consolidated_startup_registry.sql` in Snowsight yourself
(Claude can't run it) and check the validation queries at the bottom.
Save the validation output as CSV and share it back with Claude for
review.

**PR:** one other contributor with technical context reviews. The PR
body should state what changed, why, and what re-ran to verify.

---

## Scenario D — I extracted a key finding worth keeping

**Goal:** promote an aggregate finding (from a report, a Snowflake
query, or an external publication) into the shared insights library.

**Where it lives:** `insights/{period}/{topic}.md` with YAML frontmatter.

**In Claude Code:**
> "I ran the seed-stage query from scratch/rc-seed-ict-2024 and
> got 39 deals, median $2.5M, down 52% vs. 2023. Read
> `skills/insight-extractor.md` and produce the insight file at
> `insights/2026-q2/seed-ict-overview.md`. Source is `licensed` (via
> PitchBook). Add the entry to `insights/index.yaml`."

Claude will generate:

```markdown
---
id: "2026-q2-seed-ict-001"
source: "PitchBook via shared_ecosystem.rc_schema.vc_deals"
source_type: licensed
date_extracted: 2026-04-17
report_branch: null
topics: [funding, seed-stage, ICT]
geography: CA-QC
period: "2024"
confidence: high
data_points:
  - metric: seed_deal_count
    value: 39
    period: "2024"
  - metric: seed_deal_median_size_cad
    value: 2500000
    unit: CAD
    period: "2024"
  - metric: seed_deal_yoy_change_pct
    value: -0.52
    unit: ratio
    period: "2024-vs-2023"
---

Quebec ICT seed-stage funding contracted sharply in 2024 ...
```

**Key rules** (enforced by reviewers):

- `source_type: licensed` → **aggregate numbers only**, no company
  names.
- Minimum 5 records per group. If you have fewer, combine categories
  or label as "other".
- Use taxonomy codes from `taxonomy/*.yaml`, not free text.

**Branch:** either ride the scratch branch that produced the finding
(cherry-picking the insight file into a PR from main) or commit
directly to an open report branch.

---

## Scenario E — I want to propose a taxonomy change

**Goal:** add a new sector, revise a stage threshold, or clarify a
startup criterion.

**Example:** "Quantum computing needs its own sub-sector under DEEPTECH."

**Branch:**
```bash
git checkout -b taxonomy/add-quantum-computing-sub-sector
```

**Edit the YAML:**
Open `taxonomy/sectors.yaml` and add the new entry below the DEEPTECH
parent, following the same structure (code, label_en, label_fr, parent,
description, includes, excludes).

**Validate before committing:**
```bash
python3 pipelines/validation/hooks/validate_taxonomy.py
```

The pre-commit hook will run this automatically on commit anyway.

**In Claude Code:**
> "I'm adding a QUANTUM sub-sector under DEEPTECH. Read
> `skills/taxonomy-lookup.md` and propose the YAML entry. Include 3-5
> positive examples in `includes:` and the key exclusion ("AI companies
> using quantum-inspired algorithms without quantum hardware")."

**PR:** **cross-org review required.** Request approval from at least
one person at each of QT, RC, and CIQ. Explain in the PR body *why* the
change is needed — what analysis broke or what gap prompted it.

Taxonomy PRs move slower than others on purpose. Budget a few days.

---

## Scenario F — I'm enriching a dataset

**Goal:** fill gaps (sectors, funding amounts, headcounts) on a set of
companies by cross-referencing Dealroom, Snowflake, and public sources.

**Branch:**
```bash
git checkout -b pipeline/enrichment-udes-spinoffs-2026
```

**What gets committed** (from `skills/data-enrichment.md`):

- The **enrichment script** → `pipelines/enrichment/`.
- **Documentation** of the method → inline docstring + brief README
  in the enrichment subfolder if the logic is complex.
- **Aggregate findings** → promote to an insight file if worth sharing.

**What stays local:**

- The input CSV of companies (raw data).
- The enriched CSV output (record-level).
- Any intermediate exports. All under `data/`.

**In Claude Code:**
> "I have a list of 50 UdeS spinoffs in `data/udes-spinoffs-raw.csv`.
> Read `skills/data-enrichment.md` and write an enrichment script that
> fills missing `founded_year`, `sector_primary`, and `city` fields
> by checking Snowflake first, then Dealroom, then the company's
> website. Output the enriched CSV to
> `data/udes-spinoffs-enriched.csv`. Log the source per field."

When Claude suggests committing the enriched CSV, **say no** — it goes
to `data/`, not the repo.

---

## Claude Code — everyday tips

Commands that pay off immediately:

| Command | Use |
|---------|-----|
| `/memory` | Verify `CLAUDE.md` and skills are loaded. First thing to run in any new session. |
| `/help` | Quick reference. |
| `/clear` | Fresh slate, keeps `CLAUDE.md` loaded. |
| `@path/to/file` | Reference a file in your prompt — Claude reads it directly. |
| `/compact` | If you're running long, compact the context. |
| `Ctrl+C` / `Cmd+C` | Cancel the current operation. |

**Prompt patterns that work well in this repo:**

1. **Reference the skill file you want Claude to follow.**
   > "Read `skills/insight-extractor.md` and extract the key findings
   > from this analysis into that format."

2. **Reference the taxonomy explicitly.**
   > "Classify these companies using the codes in
   > `taxonomy/sectors.yaml`. If a company doesn't fit an existing
   > code, flag it rather than inventing one."

3. **State the data governance constraint upfront.**
   > "The source is PitchBook (licensed). Give me only aggregates, no
   > company-level rows."

4. **Tell Claude what branch you're on.**
   > "I'm on scratch/rc-seed-ict-2024. This is exploratory — record-
   > level results are fine."

---

## Role-specific notes

### Quebec Tech
Primary data: Dealroom (via the Quebec Tech Radar), REQ, the internal
Snowflake registry under `DEV_QUEBECTECH.GOLD.STARTUP_REGISTRY`. Your
playbook skews toward ecosystem portraits, coverage audits, and
cross-source match reviews. See `docs/qt-operations.md` for the
QT-internal operational context preserved from the pre-refactor era.

### Réseau Capital
Primary data: PitchBook VC/PE deals (via Snowflake), quarterly stats,
AI Index. Most of your work will use the `rc_schema.vc_deals` table.
Licensed-source rules apply strictly — aggregates only in everything
that merges.

### CIQ
Primary data: Baromètre de l'innovation, policy metrics. The `ciq_schema`
tables. Much of your output feeds policy briefs where provenance and
methodology matter. Favor the `insight-extractor` format so each claim
has explicit `source`, `source_type`, and `confidence`.

---

## Troubleshooting

**"Claude suggested committing a CSV and now the hook is blocking me."**
The hook is right. Move the file to `data/` (gitignored) or, if it's
genuinely public open data, to `public-data/` with a source entry in
`public-data/README.md`.

**"Claude wants to invent a new sector code for a company that doesn't
fit."** Stop. Open a `taxonomy/` branch and propose the change through
the cross-org PR. In the meantime, flag the company as "other" or use
the nearest parent code.

**"My query returned one company and a $5M deal — can I write that up
as an insight?"** No — that's record-level, not aggregate. Either find
5+ comparable deals and aggregate, or cite a public press release if
the deal was announced publicly (then `source_type: public`).

**"I don't know if a finding is licensed or public."** If the number
came from a Dealroom/PitchBook query, it's licensed. If it came from
a public announcement, news article, or the company's own website, it's
public (attribute the URL). Ask before committing if it's mixed.

---

## One last thing

The repo gets better as all three orgs contribute. Don't be shy with
`scratch/` branches — they're cheap and they reveal gaps we can fix.
When you find something that would've saved you half a day if it had
existed, open a PR to add it to the relevant skill file or to this
playbook.

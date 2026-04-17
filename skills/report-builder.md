# Skill: Report Builder

## Purpose
This skill teaches you how to initialize and manage a report branch, following the shared methodology and folder structure.

## When to use
- Starting a new quarterly or thematic report
- Setting up the working structure for a collaborative analysis
- Ensuring report outputs follow the shared conventions

## Initializing a report branch

```bash
git checkout main
git pull origin main
git checkout -b report/{report-name}
```

Create the report working directory:
```
reports/{period}/
├── {report-name}/
│   ├── README.md          # Report brief: scope, data sources, timeline
│   ├── analysis/          # Working scripts for this report
│   │   └── *.py / *.sql
│   └── drafts/            # Iterative drafts (markdown)
│       └── *.md
```

## Report README template

Every report branch should start with a `README.md` in the report directory:

```markdown
# {Report Title}

## Scope
- Period covered:
- Geography:
- Sectors:

## Data sources
- [ ] Dealroom (via Snowflake)
- [ ] PitchBook (via Snowflake)
- [ ] Public sources: (list)

## Key questions
1.
2.
3.

## Timeline
- Branch created:
- Draft due:
- Review deadline:
- Target merge date:

## Contributors
- Lead:
- Reviewers:
```

## What gets merged to main

When the report is complete:
1. **Insights** → `insights/{period}/{report-slug}.md` (aggregate findings with frontmatter)
2. **Reusable scripts** → `pipelines/` (if generally applicable beyond this report)
3. **Final PDF** → `reports/{period}/{report-name}.pdf`
4. **Report-specific scripts** stay in the branch history (accessible but not on main)

## Merge checklist
- [ ] All insights follow the frontmatter format (see `insight-extractor` skill)
- [ ] No raw data files in the branch
- [ ] `insights/index.yaml` updated with new entries
- [ ] Final PDF placed in `reports/{period}/`
- [ ] PR description summarizes key findings

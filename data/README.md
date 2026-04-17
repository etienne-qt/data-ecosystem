# Local Data Directory

This directory is **gitignored** and exists only on your local machine. Use it for:

- Raw exports from Dealroom, PitchBook, or other licensed sources
- Snowflake query result dumps for local analysis
- Intermediate data files produced during analysis
- Any record-level data that cannot be committed to the repo

## Important

Nothing in this directory is shared with collaborators or backed up to GitHub. If you need to share a dataset with a partner, use Snowflake.

If your analysis produces an insight worth sharing, extract the aggregate finding and commit it to `insights/` using the frontmatter format described in `CLAUDE.md`.

## Suggested structure

```
data/
├── dealroom/          # Dealroom exports
├── pitchbook/         # PitchBook exports
├── snowflake/         # Snowflake query dumps
├── enrichment/        # Working files for enrichment tasks
└── scratch/           # Temporary analysis files
```

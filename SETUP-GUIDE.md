# Setup Guide — Bootstrapping the GitHub Repository

This document is designed to be shared with Claude Code to help initialize the `quebec-ecosystem-data` GitHub repository. Follow these steps in order.

## Prerequisites

Before starting, ensure you have:
- A GitHub account with permissions to create organizations
- Git installed locally
- Python 3.10+ installed
- Claude Code installed and configured

## Step 1: Create the GitHub organization

1. Go to https://github.com/organizations/new
2. Create organization: `quebec-ecosystem-data` (or your preferred name)
3. Set visibility to **private** (can be changed later)
4. Add a brief description: "Shared data intelligence for Quebec's tech ecosystem — Quebec Tech, Réseau Capital, CIQ"

## Step 2: Create the repository

1. In the new org, create a repository with the same name: `quebec-ecosystem-data`
2. Initialize with a README (we'll replace it)
3. Set to **private**
4. Clone it locally:

```bash
git clone git@github.com:quebec-ecosystem-data/quebec-ecosystem-data.git
cd quebec-ecosystem-data
```

## Step 3: Copy the starter files

Copy the full set of starter files from this package into the cloned repo. The structure should be:

```
quebec-ecosystem-data/
├── CLAUDE.md
├── CONTRIBUTING.md
├── DATA-GOVERNANCE.md
├── README.md
├── .gitignore
├── .env.example
├── .claude/
│   └── settings.json
├── skills/
│   ├── taxonomy-lookup.md
│   ├── insight-extractor.md
│   └── branch-conventions.md
├── taxonomy/
│   ├── sectors.yaml
│   └── stages.yaml
├── pipelines/
│   ├── enrichment/
│   │   └── .gitkeep
│   ├── transforms/
│   │   └── .gitkeep
│   ├── validation/
│   │   └── .gitkeep
│   └── utils/
│       └── .gitkeep
├── insights/
│   └── index.yaml
├── reports/
│   └── .gitkeep
├── public-data/
│   └── README.md
├── docs/
│   ├── data-dictionary.md
│   └── snowflake-schemas.md
└── data/
    └── README.md
```

## Step 4: Set up pre-commit hooks

Create the pre-commit configuration:

```bash
pip install pre-commit
```

Create `.pre-commit-config.yaml` in the repo root:

```yaml
repos:
  - repo: local
    hooks:
      - id: check-data-files
        name: Check for data files outside public-data/
        entry: python hooks/check_data_files.py
        language: python
        always_run: true
      - id: check-file-size
        name: Check for large files
        entry: python hooks/check_file_size.py
        language: python
        always_run: true
      - id: validate-taxonomy
        name: Validate taxonomy YAML
        entry: python hooks/validate_taxonomy.py
        language: python
        files: ^taxonomy/.*\.yaml$
```

Create the hook scripts in `hooks/`:

**`hooks/check_data_files.py`** — Warns on CSV/Parquet/Excel files outside `public-data/`:
```python
#!/usr/bin/env python3
"""Pre-commit hook: block data files outside public-data/."""
import sys
from pathlib import Path

BLOCKED_EXTENSIONS = {'.csv', '.parquet', '.pkl', '.feather', '.arrow', '.xlsx', '.xls'}
ALLOWED_DIRS = {'public-data'}

def main():
    import subprocess
    result = subprocess.run(['git', 'diff', '--cached', '--name-only'], capture_output=True, text=True)
    violations = []
    for filepath in result.stdout.strip().split('\n'):
        if not filepath:
            continue
        p = Path(filepath)
        if p.suffix.lower() in BLOCKED_EXTENSIONS:
            if not any(part in ALLOWED_DIRS for part in p.parts):
                violations.append(filepath)
    if violations:
        print("⚠️  DATA GOVERNANCE WARNING: The following data files are outside public-data/:")
        for v in violations:
            print(f"   {v}")
        print("\nIf this is intentional (public open data), move the file to public-data/.")
        print("If this is licensed/raw data, it should NOT be committed. See DATA-GOVERNANCE.md.")
        print("\nTo proceed anyway: git commit --no-verify")
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
```

**`hooks/check_file_size.py`** — Warns on files larger than 1MB:
```python
#!/usr/bin/env python3
"""Pre-commit hook: warn on large files."""
import sys, subprocess
from pathlib import Path

MAX_SIZE_MB = 1
EXEMPT_DIRS = {'reports'}  # PDFs in reports/ can be large

def main():
    result = subprocess.run(['git', 'diff', '--cached', '--name-only'], capture_output=True, text=True)
    warnings = []
    for filepath in result.stdout.strip().split('\n'):
        if not filepath:
            continue
        p = Path(filepath)
        if any(part in EXEMPT_DIRS for part in p.parts):
            continue
        if p.exists() and p.stat().st_size > MAX_SIZE_MB * 1024 * 1024:
            size_mb = p.stat().st_size / (1024 * 1024)
            warnings.append(f"   {filepath} ({size_mb:.1f} MB)")
    if warnings:
        print(f"⚠️  Large files detected (>{MAX_SIZE_MB}MB):")
        for w in warnings:
            print(w)
        print("\nLarge files may indicate raw data. See DATA-GOVERNANCE.md.")
        print("To proceed anyway: git commit --no-verify")
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
```

Install the hooks:
```bash
pre-commit install
```

## Step 5: Initial commit

```bash
git add -A
git commit -m "[meta] Initialize repo with shared structure, taxonomy, skills, and governance"
git push origin main
```

## Step 6: Invite collaborators

1. Go to the GitHub org settings → People
2. Invite collaborators from Réseau Capital and CIQ
3. Assign the "Member" role (write access to repos)
4. Share the `CONTRIBUTING.md` guide with each new collaborator

## Step 7: Set up branch protection

In the repo settings → Branches → Add branch protection rule for `main`:

- **Require pull request reviews before merging**: Yes
- **Required number of approving reviews**: 1 (increase to 2 for taxonomy changes via CODEOWNERS)
- **Require status checks to pass**: Yes (once CI is set up)
- **Require branches to be up to date**: Yes

In the repo settings → General → **Pull Requests** section:

- ☑ **Automatically delete head branches** — deletes the remote branch automatically when a PR merges. Single most effective hygiene toggle; enable on day 1 so branches don't accumulate. Full policy: `CONTRIBUTING.md` § Branch lifecycle.

The stale-branch GitHub Action at `.github/workflows/stale-branches.yml` runs every Monday at 09:00 Toronto time and auto-updates a tracking issue with any branch that has had no commits in 30+ days. Reviewers use that issue to decide: resume, promote, or delete — the workflow never deletes branches itself.

Create a `CODEOWNERS` file in the repo root:

```
# Default: any contributor can review
*                       @quebec-ecosystem-data/all-contributors

# Taxonomy changes require cross-org review
/taxonomy/              @quebec-ecosystem-data/taxonomy-reviewers
```

Create two GitHub teams in the org:
- `all-contributors` — everyone
- `taxonomy-reviewers` — at least one person from each org (QT, RC, CIQ)

## Step 8: Set up GitHub Actions (optional but recommended)

Create `.github/workflows/validate.yml`:

```yaml
name: Validate
on:
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Validate taxonomy YAML
        run: python -c "
          import yaml
          from pathlib import Path
          for f in Path('taxonomy').glob('*.yaml'):
            print(f'Validating {f}...')
            yaml.safe_load(f.read_text())
            print(f'  ✓ Valid YAML')
          "
      - name: Check for data files
        run: python hooks/check_data_files.py

  stale-branches:
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule'
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Flag stale scratch branches
        run: |
          echo "Scratch branches older than 30 days:"
          git branch -r --format='%(refname:short) %(committerdate:relative)' | grep 'scratch/' | while read branch date; do
            echo "  $branch — last commit $date"
          done
```

## Step 9: Configure Claude Code project settings

Create `.claude/settings.json`:

```json
{
  "project": {
    "name": "quebec-ecosystem-data",
    "description": "Shared data intelligence for Quebec's tech ecosystem"
  },
  "context": {
    "root": "CLAUDE.md",
    "skills": "skills/"
  }
}
```

## Step 10: Verify the setup

Run this checklist:
- [ ] Repo is private and accessible to all three orgs
- [ ] `.gitignore` blocks data files
- [ ] Pre-commit hooks are installed and working
- [ ] Branch protection is active on main
- [ ] CODEOWNERS is configured for taxonomy reviews
- [ ] Each collaborator has cloned the repo and created their `.env`
- [ ] Claude Code loads `CLAUDE.md` and skills on session start
- [ ] A test `scratch/` branch can be created and closed successfully

## Next steps

Once the repo is set up:
1. **Populate the taxonomy together** — Schedule a working session with RC and CIQ to review and finalize `sectors.yaml`, `stages.yaml`, and `startup-criteria.yaml`
2. **Document Snowflake schemas** — Fill in `docs/snowflake-schemas.md` with the shared table structures
3. **Migrate existing scripts** — Move any existing shared Python scripts into `pipelines/`
4. **Start a first report branch** — Use the next quarterly report as the inaugural `report/` branch workflow
5. **Iterate on skills** — The Claude Code skills will improve as you use them; update via PRs

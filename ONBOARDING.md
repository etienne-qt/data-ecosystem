# Onboarding — Day 1 Setup

Welcome to the **Quebec Ecosystem Data** repo. This guide takes you from
zero to your first contribution in about 45 minutes. You'll install
Claude Code, clone the repo, configure Snowflake access, and open your
first `scratch/` branch.

If you get stuck, ping the repo admin at your partner org or open a
GitHub issue. Don't push ahead with a broken setup — it's easier to fix
now than after you've already committed something wrong.

---

## Before you start

You need:

- **A GitHub account** added to the repo by your partner-org lead.
- **A Claude.ai subscription** — **Pro, Max, Team, or Enterprise**. The
  free plan does not include Claude Code access.
- **A terminal.** On macOS use Terminal or iTerm; on Windows use PowerShell
  (recommended) or WSL2; on Linux any shell works.
- **Git installed.** Verify: `git --version`. If missing, install via
  [git-scm.com](https://git-scm.com) or your package manager.
- **Python 3.11+ installed.** Verify: `python3 --version`.
- **Snowflake credentials** for your org's schema (ask your internal
  data owner: account identifier, username, role, warehouse, database).

---

## Step 1 — Install Claude Code

Claude Code is Anthropic's official CLI that brings an AI assistant
into your terminal with full access to the repo.

**macOS:**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```
(Homebrew alternative, no auto-update: `brew install --cask claude-code`)

**Linux (Ubuntu/Debian):**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows (PowerShell, recommended):**
```powershell
irm https://claude.ai/install.ps1 | iex
```
WinGet alternative (no auto-update): `winget install Anthropic.ClaudeCode`.
If you prefer Linux tooling, use WSL2 and follow the Linux command above.

**Verify the install:**
```bash
claude --version
```

---

## Step 2 — Sign in

From any directory:
```bash
claude
```

On first launch, Claude Code opens your browser to authenticate with
your Claude.ai account. Sign in, approve, and return to the terminal.
After auth, type `/exit` to close the session — we'll open it again once
the repo is cloned.

---

## Step 3 — Get repo access and clone

Your partner-org lead will invite you to the `etienne-qt/data-ecosystem`
GitHub repo (or its successor under a shared org). Once you accept:

```bash
# Pick a parent directory where you want your work to live.
mkdir -p ~/work && cd ~/work

# Clone via HTTPS (simplest) or SSH if your key is set up.
git clone https://github.com/etienne-qt/data-ecosystem.git quebec-ecosystem-data
cd quebec-ecosystem-data
```

Take a minute to look around. The top-level files that matter:

- **`README.md`** — one-page overview.
- **`CLAUDE.md`** — project context loaded automatically into every
  Claude Code session. Read this; it shapes how Claude behaves in this
  repo.
- **`DATA-GOVERNANCE.md`** — the rules. Read this before you commit.
- **`CONTRIBUTING.md`** — branch workflow, commit format, PR process.
- **`PLAYBOOK.md`** — concrete workflow scenarios.
- **`skills/`** — shared knowledge files that Claude Code uses to help
  you produce output that follows our conventions.
- **`taxonomy/`** — canonical sector codes, funding stages, startup
  criteria. Use these in every analysis; don't invent ad-hoc categories.

---

## Step 4 — Set up your local environment

Create your `.env` file (it is gitignored):

```bash
cp .env.example .env    # if a .env.example exists
# then edit .env with your Snowflake credentials:
#   SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_ROLE,
#   SNOWFLAKE_WAREHOUSE, SNOWFLAKE_DATABASE
```

Create the local `data/` directory for any raw exports you work with
(also gitignored):

```bash
mkdir -p data
```

---

## Step 5 — Install pre-commit hooks

Pre-commit hooks run on every commit and block common data-governance
mistakes: committing CSVs outside `public-data/`, oversized files,
malformed taxonomy YAML.

**macOS:**
```bash
brew install pre-commit
pre-commit install
```

**Linux / Windows (WSL):**
```bash
pipx install pre-commit     # if pipx is available
# or: python3 -m pip install --user pre-commit
pre-commit install
```

**Verify the hooks run:**
```bash
pre-commit run --all-files
```
You should see three checks pass (data files, file size, taxonomy).

---

## Step 6 — Confirm Snowflake access (via Snowsight, not MCP)

**Current operating mode: Claude Code does NOT query Snowflake
directly.** There is no wired MCP server yet. You run queries manually
in Snowsight using your org's credentials, save the results as CSV to
the local `data/` directory, and hand the aggregates back to Claude
Code for analysis.

This is intentional: it keeps credentials out of Claude sessions and
keeps record-level results on your machine, not in any shared context.

**What to verify today:**

1. You can log into Snowsight with your org's SSO or user/password.
2. You can see the `shared_ecosystem` database and the schema(s) your
   org uses (`qt_schema`, `rc_schema`, or `ciq_schema`).
3. You have a warehouse you can use to run queries.

If any of those fail, ping your internal data lead — the repo can't
help you past this point without Snowflake access.

**Future state:** once the three orgs agree on a Snowflake MCP server,
we'll wire it up and update this section. Until then, the workflow is
"Claude writes SQL → you run it → you share the aggregate back." See
`skills/snowflake-query.md` for the full handoff loop.

---

## Step 7 — Verify your setup

Open Claude Code inside the repo:

```bash
cd quebec-ecosystem-data
claude
```

In the Claude Code session, run:

1. **`/memory`** — verifies `CLAUDE.md` and shared skills loaded. You
   should see `CLAUDE.md` and the 6 files under `skills/` listed. If
   not, exit and restart from the repo root.
2. **Ask a trivial question** — try: "Summarize what this repo is for
   in two sentences." Claude should answer using the repo context.
3. **Exercise the handoff loop** — try: "Write a Snowflake query that
   returns the count of companies in `shared_ecosystem.qt_schema.companies`
   broken down by sector code. Use the taxonomy codes from
   `taxonomy/sectors.yaml`." Claude should produce SQL. You then open
   Snowsight, paste it, run it, save the CSV, and continue the chat
   with Claude. This is the pattern you'll use daily.

Make your first scratch branch:

```bash
# Use your org prefix: qt, rc, or ciq
git checkout -b scratch/rc-onboarding-check
echo "onboarding verified on $(date)" > onboarding-check.txt
git add onboarding-check.txt
git commit -m "[meta] Onboarding verification"
```

The pre-commit hooks should run. If they pass, your setup works.

**Don't push this branch** — it's throwaway. Delete it:
```bash
git checkout main
git branch -D scratch/rc-onboarding-check
rm onboarding-check.txt
```

---

## What to read next

1. **`PLAYBOOK.md`** — walkthroughs for the workflows you'll actually
   use: quick queries, report production, taxonomy changes, data
   enrichment.
2. **`CONTRIBUTING.md`** — branch conventions and PR process in
   detail.
3. **`DATA-GOVERNANCE.md`** — what's committable and what's not.
   Re-read before your first real commit.
4. **`skills/branch-conventions.md`** and the other skill files — these
   are what Claude Code consults when it produces work for you.
   Skimming them helps you understand Claude's output.

---

## Common first-session pitfalls

| Symptom | Fix |
|---------|-----|
| "Claude doesn't seem to know about the project" | Run `/memory`. If `CLAUDE.md` isn't listed, restart Claude Code from the repo root. |
| "Permission prompt every time I run `git` or `python`" | Normal on first use. Approve, or pre-approve in `.claude/settings.local.json`. |
| "How do I query Snowflake from Claude Code?" | You don't — yet. Claude writes the SQL, you run it in Snowsight, save the CSV to `data/`, and share the aggregate back with Claude. See `skills/snowflake-query.md`. |
| "Pre-commit blocked my commit" | Read the error. Usually you've staged a CSV outside `public-data/`. Move the file or unstage it. |
| "I committed a credential by mistake" | **Do not push.** Run `git reset HEAD~1` if it's the most recent commit, then rotate the credential anyway. If already pushed, alert the repo admin immediately. |

---

## Getting help

- Repo questions: open a GitHub issue.
- Claude Code issues: run `/help` in-session, or see
  `https://code.claude.com/docs/`.
- Data governance uncertainty: ask before committing. It's always
  cheaper to ask than to scrub the Git history.

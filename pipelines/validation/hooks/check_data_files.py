#!/usr/bin/env python3
"""Pre-commit hook: block data files outside public-data/.

Blocks .csv, .parquet, .pkl, .feather, .arrow, .xlsx, .xls files that are
being committed outside the public-data/ directory. Exit status 1 signals
the pre-commit framework to abort the commit.

To override for a genuinely public dataset already attributed in
public-data/README.md, either move the file there or commit with --no-verify.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

BLOCKED_EXTENSIONS = {".csv", ".parquet", ".pkl", ".feather", ".arrow", ".xlsx", ".xls"}
ALLOWED_DIRS = {"public-data"}


def staged_paths() -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
        capture_output=True,
        text=True,
        check=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def main() -> int:
    violations: list[str] = []
    for filepath in staged_paths():
        path = Path(filepath)
        if path.suffix.lower() not in BLOCKED_EXTENSIONS:
            continue
        if any(part in ALLOWED_DIRS for part in path.parts):
            continue
        violations.append(filepath)

    if not violations:
        return 0

    print("DATA GOVERNANCE WARNING: data files are staged outside public-data/:")
    for violation in violations:
        print(f"  {violation}")
    print()
    print("If this is public open data, move it to public-data/ and attribute the source.")
    print("If this is licensed/raw data, it should NOT be committed — see DATA-GOVERNANCE.md.")
    print("To bypass (only for vetted public data): git commit --no-verify")
    return 1


if __name__ == "__main__":
    sys.exit(main())

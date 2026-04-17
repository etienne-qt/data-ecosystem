#!/usr/bin/env python3
"""Pre-commit hook: warn on files larger than 1 MB.

Large files often mean raw data or bundled binaries, which don't belong
outside reports/. PDFs in reports/ are exempt since published deliverables
can be large. Exit 1 blocks the commit; use --no-verify to override.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

MAX_SIZE_MB = 1
EXEMPT_DIRS = {"reports"}


def staged_paths() -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
        capture_output=True,
        text=True,
        check=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def main() -> int:
    warnings: list[str] = []
    max_bytes = MAX_SIZE_MB * 1024 * 1024

    for filepath in staged_paths():
        path = Path(filepath)
        if any(part in EXEMPT_DIRS for part in path.parts):
            continue
        if not path.exists():
            continue
        size = path.stat().st_size
        if size > max_bytes:
            warnings.append(f"  {filepath} ({size / (1024 * 1024):.1f} MB)")

    if not warnings:
        return 0

    print(f"Large files staged (>{MAX_SIZE_MB} MB):")
    for line in warnings:
        print(line)
    print()
    print("Large files often indicate raw data. See DATA-GOVERNANCE.md.")
    print("Published PDFs belong under reports/ and are exempt from this check.")
    print("To bypass: git commit --no-verify")
    return 1


if __name__ == "__main__":
    sys.exit(main())

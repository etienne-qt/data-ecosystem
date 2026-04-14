#!/usr/bin/env python3
"""Run the website auto-review agent task.

Usage:
    python scripts/pipeline/run_website_review.py              # default tier
    python scripts/pipeline/run_website_review.py --tier 2_medium
"""

import argparse
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description="Run website auto-review")
    parser.add_argument("--tier", default="1_high", help="Review priority tier (default: 1_high)")
    args = parser.parse_args()

    cmd = ["eco", "run-agent", "website_review", "--", f"tier={args.tier}"]
    sys.exit(subprocess.call(cmd))


if __name__ == "__main__":
    main()

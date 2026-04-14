#!/usr/bin/env python3
"""Upload the gold parquet to Snowflake.

Thin wrapper around: eco run-pipeline --steps gold --upload
"""

import subprocess
import sys


def main():
    cmd = ["eco", "run-pipeline", "--steps", "gold", "--upload"]
    sys.exit(subprocess.call(cmd))


if __name__ == "__main__":
    main()

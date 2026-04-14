#!/usr/bin/env python3
"""Run the full Dealroom data pipeline (bronze → silver → gold).

Thin wrapper around: eco run-pipeline --steps bronze,silver,gold
"""

import subprocess
import sys


def main():
    steps = sys.argv[1] if len(sys.argv) > 1 else "bronze,silver,gold"
    cmd = ["eco", "run-pipeline", "--steps", steps]
    if "--upload" in sys.argv:
        cmd.append("--upload")
    sys.exit(subprocess.call(cmd))


if __name__ == "__main__":
    main()

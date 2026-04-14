#!/usr/bin/env python3
"""Query the knowledge base via semantic search.

Thin wrapper — delegates to `eco search`.
"""

from ecosystem.cli import cli

if __name__ == "__main__":
    cli(["search"])

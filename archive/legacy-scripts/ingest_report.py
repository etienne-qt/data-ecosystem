#!/usr/bin/env python3
"""Ingest an external report into the knowledge base.

Thin wrapper — delegates to `eco ingest`.
"""

from ecosystem.cli import cli

if __name__ == "__main__":
    cli(["ingest"])

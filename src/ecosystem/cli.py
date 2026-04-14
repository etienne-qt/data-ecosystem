"""Minimal CLI for the Quebec Tech data platform.

As of 2026-04-14, only the `website_review` agent task is active. The
older knowledge-base / scheduler / connector / pipeline commands have
been archived (see `archive/python-package/cli.py.legacy` for the
previous full CLI). The real work has moved to SQL-in-Snowflake; the
Python layer here exists solely to support the website-review task.

Usage:
    eco run-agent list              # show registered tasks
    eco run-agent website_review    # run the website review task
"""

from __future__ import annotations

import click
from rich.console import Console

console = Console()


@click.group()
def cli() -> None:
    """Quebec Tech data platform — minimal CLI (website_review only)."""


@cli.command()
@click.argument("task_name")
def run_agent(task_name: str) -> None:
    """Trigger an agent task (currently only `website_review`)."""
    from ecosystem.agents.runner import AgentRunner, get_registered_tasks

    runner = AgentRunner()

    if task_name == "list":
        console.print("[bold]Available tasks:[/bold]")
        for name in get_registered_tasks():
            last = runner.get_last_run(name)
            status = (
                f"[dim](last: {last.status.value} at {last.started_at:%Y-%m-%d %H:%M})[/dim]"
                if last
                else "[dim](never run)[/dim]"
            )
            console.print(f"  - {name} {status}")
        return

    console.print(f"[bold]Running agent task:[/bold] {task_name}")
    result = runner.run_task(task_name)

    if result.status.value == "success":
        console.print(
            f"[green]Success:[/green] {result.message} "
            f"({result.duration_seconds:.1f}s)"
        )
    else:
        console.print(f"[red]Failed:[/red] {result.error}")


if __name__ == "__main__":
    cli()

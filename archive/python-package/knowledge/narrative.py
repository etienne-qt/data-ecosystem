"""Narrative builder — tools to manage living narrative documents.

Narratives are markdown documents that evolve over time as new data
and analyses are produced. This module provides structured operations
for appending, updating sections, and managing revision history.

Usage:
    from ecosystem.knowledge.narrative import NarrativeManager
    mgr = NarrativeManager()
    mgr.append_section("narratives/funding_trends.md", "## Q1 2026", "Content...")
    mgr.update_section("narratives/funding_trends.md", "## Key Metrics", new_content)
"""

from __future__ import annotations

import logging
import re
from datetime import date, datetime
from typing import Any

from ecosystem.knowledge.store import DocumentStore

logger = logging.getLogger(__name__)


class NarrativeManager:
    """Manage living narrative documents in the knowledge base."""

    def __init__(self, store: DocumentStore | None = None) -> None:
        self.store = store or DocumentStore()

    def append_section(
        self,
        doc_path: str,
        heading: str,
        content: str,
        timestamp: bool = True,
    ) -> None:
        """Append a new section to a narrative document.

        Args:
            doc_path: Relative path to the narrative document.
            heading: Section heading (e.g. "## Q1 2026 Update").
            content: Section content (markdown).
            timestamp: If True, prepend a timestamp comment.
        """
        doc = self.store.get(doc_path)
        if doc is None:
            raise FileNotFoundError(f"Narrative not found: {doc_path}")

        parts = []
        if timestamp:
            parts.append(f"<!-- Added {datetime.now().strftime('%Y-%m-%d %H:%M')} -->")
        parts.append(heading)
        parts.append(content)

        new_section = "\n".join(parts)
        self.store.append(doc_path, new_section)
        logger.info("Appended section '%s' to %s", heading, doc_path)

    def update_section(
        self,
        doc_path: str,
        heading_pattern: str,
        new_content: str,
    ) -> bool:
        """Replace the content under a specific heading in a narrative.

        Finds the section matching heading_pattern (exact or regex) and
        replaces everything between it and the next heading of equal or
        higher level.

        Args:
            doc_path: Relative path to the narrative document.
            heading_pattern: The heading text to find (e.g. "## Key Metrics").
            new_content: New content to replace the section body with.

        Returns:
            True if the section was found and updated, False otherwise.
        """
        doc = self.store.get(doc_path)
        if doc is None:
            raise FileNotFoundError(f"Narrative not found: {doc_path}")

        lines = doc.content.split("\n")
        heading_level = None
        section_start = None
        section_end = None

        # Find the section
        for i, line in enumerate(lines):
            heading_match = re.match(r"^(#{1,6})\s+(.+)$", line)
            if heading_match:
                level = len(heading_match.group(1))
                title = heading_match.group(2).strip()

                if section_start is not None:
                    # Found next heading at same or higher level — end of section
                    if level <= heading_level:
                        section_end = i
                        break
                elif title == heading_pattern or re.search(heading_pattern, title):
                    heading_level = level
                    section_start = i

        if section_start is None:
            logger.warning("Section '%s' not found in %s", heading_pattern, doc_path)
            return False

        if section_end is None:
            section_end = len(lines)

        # Reconstruct: heading line + new content + rest
        updated_lines = (
            lines[:section_start + 1]
            + [new_content]
            + lines[section_end:]
        )
        self.store.update(doc_path, content="\n".join(updated_lines))
        logger.info("Updated section '%s' in %s", heading_pattern, doc_path)
        return True

    def get_sections(self, doc_path: str) -> list[dict[str, Any]]:
        """List all sections (headings) in a narrative document.

        Returns:
            List of dicts with keys: level, title, line_number.
        """
        doc = self.store.get(doc_path)
        if doc is None:
            raise FileNotFoundError(f"Narrative not found: {doc_path}")

        sections = []
        for i, line in enumerate(doc.content.split("\n")):
            match = re.match(r"^(#{1,6})\s+(.+)$", line)
            if match:
                sections.append({
                    "level": len(match.group(1)),
                    "title": match.group(2).strip(),
                    "line_number": i,
                })
        return sections

    def create_narrative(
        self,
        doc_path: str,
        title: str,
        sections: list[str] | None = None,
    ) -> None:
        """Create a new narrative document with optional initial sections.

        Args:
            doc_path: Path within knowledge_base/ (should start with "narratives/").
            title: Document title.
            sections: Optional list of initial section headings.
        """
        content_parts = [f"# {title}", ""]
        content_parts.append("*This is a living document. It is updated as new data and analyses become available.*")
        content_parts.append("")

        for section in (sections or []):
            content_parts.append(f"## {section}")
            content_parts.append(f"<!-- TODO: Add content for {section} -->")
            content_parts.append("")

        self.store.create(
            doc_path,
            title=title,
            content="\n".join(content_parts),
            metadata={
                "type": "narrative",
                "status": "draft",
            },
        )
        logger.info("Created narrative: %s", doc_path)

    def add_entry(
        self,
        doc_path: str,
        section_heading: str,
        entry: str,
        prepend: bool = True,
    ) -> bool:
        """Add a timestamped entry to a section (like a log).

        Useful for "Recent Developments" style sections.

        Args:
            doc_path: Relative path to the narrative.
            section_heading: Heading of the target section.
            entry: Entry text to add.
            prepend: If True, add at the top of the section. Otherwise append.

        Returns:
            True if successful, False if section not found.
        """
        doc = self.store.get(doc_path)
        if doc is None:
            raise FileNotFoundError(f"Narrative not found: {doc_path}")

        lines = doc.content.split("\n")
        heading_level = None
        section_start = None
        section_end = None

        for i, line in enumerate(lines):
            heading_match = re.match(r"^(#{1,6})\s+(.+)$", line)
            if heading_match:
                level = len(heading_match.group(1))
                title = heading_match.group(2).strip()

                if section_start is not None and level <= heading_level:
                    section_end = i
                    break
                elif title == section_heading:
                    heading_level = level
                    section_start = i

        if section_start is None:
            return False

        if section_end is None:
            section_end = len(lines)

        dated_entry = f"- **{date.today()}**: {entry}"

        if prepend:
            insert_at = section_start + 1
            # Skip any blank lines right after the heading
            while insert_at < section_end and not lines[insert_at].strip():
                insert_at += 1
            lines.insert(insert_at, dated_entry)
        else:
            lines.insert(section_end, dated_entry)

        self.store.update(doc_path, content="\n".join(lines))
        logger.info("Added entry to '%s' in %s", section_heading, doc_path)
        return True

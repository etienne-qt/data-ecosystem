"""Markdown file manager — CRUD for knowledge base documents with YAML frontmatter.

Usage:
    from ecosystem.knowledge.store import DocumentStore
    store = DocumentStore()
    doc = store.create("reports/q1_funding.md", title="Q1 Funding Report", content="...")
    doc = store.get("reports/q1_funding.md")
    docs = store.list_documents(category="reports")
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Any

import yaml

from ecosystem.config import settings

logger = logging.getLogger(__name__)


@dataclass
class Document:
    """A knowledge base document with frontmatter metadata and markdown content."""

    path: str  # Relative path within knowledge_base/ (e.g. "reports/q1.md")
    metadata: dict[str, Any] = field(default_factory=dict)
    content: str = ""

    @property
    def title(self) -> str:
        return self.metadata.get("title", "")

    @property
    def category(self) -> str:
        """First path segment (reports, internal, meeting_notes, narratives)."""
        return self.path.split("/")[0] if "/" in self.path else ""

    @property
    def abs_path(self) -> Path:
        return settings.knowledge_base_dir / self.path


# Frontmatter parsing regex
_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def _parse_document(path: str, text: str) -> Document:
    """Parse a markdown file with optional YAML frontmatter."""
    match = _FRONTMATTER_RE.match(text)
    if match:
        try:
            metadata = yaml.safe_load(match.group(1)) or {}
        except yaml.YAMLError:
            metadata = {}
        content = text[match.end():]
    else:
        metadata = {}
        content = text
    return Document(path=path, metadata=metadata, content=content)


def _serialize_document(doc: Document) -> str:
    """Serialize a Document back to markdown with YAML frontmatter."""
    parts = []
    if doc.metadata:
        parts.append("---")
        parts.append(yaml.dump(doc.metadata, default_flow_style=False, allow_unicode=True).strip())
        parts.append("---")
        parts.append("")
    parts.append(doc.content)
    return "\n".join(parts)


class DocumentStore:
    """CRUD operations for markdown documents in the knowledge base."""

    def __init__(self, base_dir: str | Path | None = None) -> None:
        self.base_dir = Path(base_dir) if base_dir else settings.knowledge_base_dir
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def _resolve(self, rel_path: str) -> Path:
        """Resolve a relative path to an absolute path within the knowledge base."""
        resolved = (self.base_dir / rel_path).resolve()
        # Ensure path stays within base_dir
        if not str(resolved).startswith(str(self.base_dir.resolve())):
            raise ValueError(f"Path escapes knowledge base: {rel_path}")
        return resolved

    def get(self, rel_path: str) -> Document | None:
        """Read a document by its relative path. Returns None if not found."""
        abs_path = self._resolve(rel_path)
        if not abs_path.exists():
            return None
        text = abs_path.read_text(encoding="utf-8")
        return _parse_document(rel_path, text)

    def create(
        self,
        rel_path: str,
        content: str = "",
        title: str = "",
        metadata: dict[str, Any] | None = None,
    ) -> Document:
        """Create a new document. Raises FileExistsError if it already exists."""
        abs_path = self._resolve(rel_path)
        if abs_path.exists():
            raise FileExistsError(f"Document already exists: {rel_path}")

        meta = metadata or {}
        if title:
            meta.setdefault("title", title)
        meta.setdefault("created", str(date.today()))
        meta.setdefault("updated", str(date.today()))

        doc = Document(path=rel_path, metadata=meta, content=content)
        abs_path.parent.mkdir(parents=True, exist_ok=True)
        abs_path.write_text(_serialize_document(doc), encoding="utf-8")
        logger.info("Created document: %s", rel_path)
        return doc

    def update(
        self,
        rel_path: str,
        content: str | None = None,
        metadata_updates: dict[str, Any] | None = None,
    ) -> Document:
        """Update an existing document's content and/or metadata."""
        doc = self.get(rel_path)
        if doc is None:
            raise FileNotFoundError(f"Document not found: {rel_path}")

        if content is not None:
            doc.content = content
        if metadata_updates:
            doc.metadata.update(metadata_updates)
        doc.metadata["updated"] = str(date.today())

        abs_path = self._resolve(rel_path)
        abs_path.write_text(_serialize_document(doc), encoding="utf-8")
        logger.info("Updated document: %s", rel_path)
        return doc

    def delete(self, rel_path: str) -> bool:
        """Delete a document. Returns True if deleted, False if not found."""
        abs_path = self._resolve(rel_path)
        if not abs_path.exists():
            return False
        abs_path.unlink()
        logger.info("Deleted document: %s", rel_path)
        return True

    def list_documents(
        self,
        category: str | None = None,
        glob_pattern: str = "**/*.md",
    ) -> list[Document]:
        """List all documents, optionally filtered by category (subdirectory).

        Args:
            category: Filter to a subdirectory (e.g. "reports", "narratives").
            glob_pattern: Glob pattern for file matching.

        Returns:
            List of Documents with metadata loaded (content is loaded too).
        """
        search_dir = self.base_dir / category if category else self.base_dir
        if not search_dir.exists():
            return []

        docs = []
        for abs_path in sorted(search_dir.glob(glob_pattern)):
            if abs_path.is_file():
                rel_path = str(abs_path.relative_to(self.base_dir))
                text = abs_path.read_text(encoding="utf-8")
                docs.append(_parse_document(rel_path, text))
        return docs

    def exists(self, rel_path: str) -> bool:
        """Check if a document exists."""
        return self._resolve(rel_path).exists()

    def append(self, rel_path: str, text: str) -> Document:
        """Append text to an existing document's content."""
        doc = self.get(rel_path)
        if doc is None:
            raise FileNotFoundError(f"Document not found: {rel_path}")

        doc.content = doc.content.rstrip() + "\n\n" + text
        doc.metadata["updated"] = str(date.today())

        abs_path = self._resolve(rel_path)
        abs_path.write_text(_serialize_document(doc), encoding="utf-8")
        logger.info("Appended to document: %s", rel_path)
        return doc

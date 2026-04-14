"""Tests for ecosystem.knowledge.store."""

import pytest
from pathlib import Path

from ecosystem.knowledge.store import DocumentStore, Document, _parse_document, _serialize_document


@pytest.fixture
def tmp_store(tmp_path):
    """Create a DocumentStore with a temporary directory."""
    return DocumentStore(base_dir=tmp_path)


def test_parse_document_with_frontmatter():
    text = "---\ntitle: Test\nstatus: draft\n---\n# Hello\nWorld"
    doc = _parse_document("test.md", text)
    assert doc.metadata["title"] == "Test"
    assert doc.metadata["status"] == "draft"
    assert doc.content.startswith("# Hello")


def test_parse_document_no_frontmatter():
    text = "# Just Markdown\nNo frontmatter here."
    doc = _parse_document("test.md", text)
    assert doc.metadata == {}
    assert doc.content == text


def test_serialize_roundtrip():
    doc = Document(
        path="test.md",
        metadata={"title": "Test Doc", "created": "2026-03-04"},
        content="# Hello\n\nWorld",
    )
    serialized = _serialize_document(doc)
    parsed = _parse_document("test.md", serialized)
    assert parsed.metadata["title"] == "Test Doc"
    assert "# Hello" in parsed.content


def test_create_and_get(tmp_store):
    doc = tmp_store.create("reports/test.md", content="# Test Report", title="Test Report")
    assert doc.title == "Test Report"
    assert doc.category == "reports"

    retrieved = tmp_store.get("reports/test.md")
    assert retrieved is not None
    assert retrieved.title == "Test Report"
    assert "# Test Report" in retrieved.content


def test_create_duplicate_raises(tmp_store):
    tmp_store.create("test.md", content="first")
    with pytest.raises(FileExistsError):
        tmp_store.create("test.md", content="second")


def test_get_nonexistent(tmp_store):
    assert tmp_store.get("does_not_exist.md") is None


def test_update(tmp_store):
    tmp_store.create("test.md", content="original", title="Original")
    updated = tmp_store.update("test.md", content="modified", metadata_updates={"status": "final"})
    assert updated.content == "modified"
    assert updated.metadata["status"] == "final"
    assert updated.metadata["title"] == "Original"  # preserved


def test_update_nonexistent_raises(tmp_store):
    with pytest.raises(FileNotFoundError):
        tmp_store.update("nope.md", content="fail")


def test_delete(tmp_store):
    tmp_store.create("test.md", content="deleteme")
    assert tmp_store.delete("test.md") is True
    assert tmp_store.get("test.md") is None
    assert tmp_store.delete("test.md") is False


def test_list_documents(tmp_store):
    tmp_store.create("reports/a.md", content="A", title="Report A")
    tmp_store.create("reports/b.md", content="B", title="Report B")
    tmp_store.create("narratives/c.md", content="C", title="Narrative C")

    all_docs = tmp_store.list_documents()
    assert len(all_docs) == 3

    reports = tmp_store.list_documents(category="reports")
    assert len(reports) == 2

    narratives = tmp_store.list_documents(category="narratives")
    assert len(narratives) == 1


def test_exists(tmp_store):
    assert tmp_store.exists("nope.md") is False
    tmp_store.create("test.md", content="exists")
    assert tmp_store.exists("test.md") is True


def test_append(tmp_store):
    tmp_store.create("test.md", content="# Start")
    doc = tmp_store.append("test.md", "## New Section\nNew content")
    assert "## New Section" in doc.content
    assert "# Start" in doc.content


def test_path_traversal_rejected(tmp_store):
    with pytest.raises(ValueError, match="escapes"):
        tmp_store.get("../../etc/passwd")


def test_document_properties():
    doc = Document(path="reports/q1.md", metadata={"title": "Q1"}, content="text")
    assert doc.title == "Q1"
    assert doc.category == "reports"

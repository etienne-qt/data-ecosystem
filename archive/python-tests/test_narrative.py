"""Tests for ecosystem.knowledge.narrative."""

import pytest

from ecosystem.knowledge.narrative import NarrativeManager
from ecosystem.knowledge.store import DocumentStore


@pytest.fixture
def mgr(tmp_path):
    store = DocumentStore(base_dir=tmp_path / "kb")
    # Create a test narrative
    store.create(
        "narratives/test.md",
        title="Test Narrative",
        content="# Test Narrative\n\n## Key Metrics\n100 startups\n\n## Recent Developments\n<!-- entries here -->\n",
        metadata={"type": "narrative"},
    )
    return NarrativeManager(store=store)


def test_get_sections(mgr):
    sections = mgr.get_sections("narratives/test.md")
    titles = [s["title"] for s in sections]
    assert "Test Narrative" in titles
    assert "Key Metrics" in titles
    assert "Recent Developments" in titles


def test_append_section(mgr):
    mgr.append_section("narratives/test.md", "## Q1 Update", "New data arrived.")
    doc = mgr.store.get("narratives/test.md")
    assert "## Q1 Update" in doc.content
    assert "New data arrived." in doc.content


def test_update_section(mgr):
    result = mgr.update_section("narratives/test.md", "Key Metrics", "200 startups\n50 funded")
    assert result is True
    doc = mgr.store.get("narratives/test.md")
    assert "200 startups" in doc.content
    assert "100 startups" not in doc.content
    # Heading should still be there
    assert "## Key Metrics" in doc.content


def test_update_section_not_found(mgr):
    result = mgr.update_section("narratives/test.md", "Nonexistent Section", "content")
    assert result is False


def test_add_entry(mgr):
    result = mgr.add_entry("narratives/test.md", "Recent Developments", "New startup launched")
    assert result is True
    doc = mgr.store.get("narratives/test.md")
    assert "New startup launched" in doc.content


def test_add_entry_section_not_found(mgr):
    result = mgr.add_entry("narratives/test.md", "Nonexistent", "entry")
    assert result is False


def test_create_narrative(mgr):
    mgr.create_narrative(
        "narratives/new_topic.md",
        title="New Topic",
        sections=["Overview", "Data", "Conclusions"],
    )
    doc = mgr.store.get("narratives/new_topic.md")
    assert doc is not None
    assert doc.title == "New Topic"
    assert "## Overview" in doc.content
    assert "## Data" in doc.content
    assert "## Conclusions" in doc.content
    assert doc.metadata.get("type") == "narrative"


def test_append_to_nonexistent_raises(mgr):
    with pytest.raises(FileNotFoundError):
        mgr.append_section("nope.md", "## Heading", "content")

"""Tests for ecosystem.knowledge.search."""

import pytest

from ecosystem.knowledge.index import KnowledgeIndex
from ecosystem.knowledge.search import KnowledgeSearch
from ecosystem.knowledge.store import DocumentStore


@pytest.fixture
def kb(tmp_path):
    """Set up a knowledge base with store, index, and some test documents."""
    store = DocumentStore(base_dir=tmp_path / "kb")
    index = KnowledgeIndex(persist_dir=tmp_path / "index", chunk_size=200, chunk_overlap=30)
    search = KnowledgeSearch(store=store, index=index)

    # Create and index test documents
    store.create(
        "reports/ai_report.md",
        title="AI Landscape Report",
        content="Artificial intelligence companies in Quebec raised $800M in 2025. "
                "Montreal is home to Mila and Element AI alumni startups. "
                "Deep learning and NLP are the dominant sub-sectors.",
    )
    store.create(
        "reports/cleantech_report.md",
        title="Cleantech Overview",
        content="Cleantech and climate tech startups are growing rapidly. "
                "Battery technology and carbon capture lead the sector. "
                "Quebec's hydroelectric advantage drives clean energy innovation.",
    )
    store.create(
        "narratives/funding.md",
        title="Funding Trends",
        content="Quebec venture capital activity reached $2.5B in 2025. "
                "Seed stage deals increased by 30%. Series A remained stable.",
        metadata={"type": "narrative"},
    )

    search.reindex_all()
    return search


def test_search_basic(kb):
    results = kb.search("artificial intelligence Montreal")
    assert len(results) > 0
    assert results[0].doc_path == "reports/ai_report.md"


def test_search_category_filter(kb):
    results = kb.search("funding venture capital", category="narratives")
    assert all(r.category == "narratives" for r in results)


def test_search_no_results(kb):
    results = kb.search("xyznonexistentterm12345")
    assert results == []


def test_search_returns_metadata(kb):
    results = kb.search("AI companies Quebec")
    if results:
        assert results[0].title  # Should have document title
        assert results[0].doc_path  # Should have path


def test_reindex_all(kb):
    total = kb.reindex_all()
    assert total > 0


def test_index_single_document(kb):
    kb.store.create("internal/memo.md", title="Internal Memo", content="Test memo about AI.")
    chunks = kb.index_document("internal/memo.md")
    assert chunks > 0

    results = kb.search("internal memo AI")
    assert any(r.doc_path == "internal/memo.md" for r in results)


def test_index_missing_document_raises(kb):
    with pytest.raises(FileNotFoundError):
        kb.index_document("nonexistent.md")

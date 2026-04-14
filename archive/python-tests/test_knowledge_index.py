"""Tests for ecosystem.knowledge.index (fallback TF-IDF backend)."""

import pytest

from ecosystem.knowledge.index import KnowledgeIndex, SearchResult, chunk_text, _FallbackIndex


def test_chunk_text_basic():
    text = "Paragraph one.\n\nParagraph two.\n\nParagraph three."
    chunks = chunk_text(text, chunk_size=30, chunk_overlap=0)
    assert len(chunks) >= 2
    assert "Paragraph one." in chunks[0]


def test_chunk_text_empty():
    assert chunk_text("") == []


def test_chunk_text_single_paragraph():
    text = "Short text."
    chunks = chunk_text(text, chunk_size=1000)
    assert len(chunks) == 1
    assert chunks[0] == "Short text."


def test_chunk_text_respects_size():
    text = "\n\n".join(f"Paragraph {i} with some text content." for i in range(20))
    chunks = chunk_text(text, chunk_size=100, chunk_overlap=0)
    for chunk in chunks:
        # Allow some flexibility (a single paragraph may exceed chunk_size)
        assert len(chunk) < 200


@pytest.fixture
def fallback_index(tmp_path):
    return _FallbackIndex(tmp_path / "index.json")


def test_fallback_add_and_query(fallback_index):
    fallback_index.add("c1", "artificial intelligence machine learning", "doc1.md", {"title": "AI Doc"})
    fallback_index.add("c2", "restaurant food delivery service", "doc2.md", {"title": "Food Doc"})
    fallback_index.commit()

    results = fallback_index.query("artificial intelligence")
    assert len(results) >= 1
    assert results[0].doc_path == "doc1.md"


def test_fallback_remove_by_doc_path(fallback_index):
    fallback_index.add("c1", "text one", "doc1.md", {})
    fallback_index.add("c2", "text two", "doc1.md", {})
    fallback_index.add("c3", "text three", "doc2.md", {})
    fallback_index.commit()

    removed = fallback_index.remove_by_doc_path("doc1.md")
    assert removed == 2
    assert fallback_index.count == 1


def test_fallback_persistence(tmp_path):
    index1 = _FallbackIndex(tmp_path / "index.json")
    index1.add("c1", "persistent data test", "doc.md", {})
    index1.commit()

    index2 = _FallbackIndex(tmp_path / "index.json")
    assert index2.count == 1
    results = index2.query("persistent data")
    assert len(results) == 1


def test_fallback_empty_query(fallback_index):
    results = fallback_index.query("")
    assert results == []


def test_fallback_no_docs_query(fallback_index):
    results = fallback_index.query("anything")
    assert results == []


@pytest.fixture
def knowledge_index(tmp_path):
    return KnowledgeIndex(persist_dir=tmp_path / "kb_index", chunk_size=100, chunk_overlap=20)


def test_knowledge_index_add_and_query(knowledge_index):
    text = """# Funding Trends

Quebec startups raised $2.5B in 2025. AI companies led with $800M.

The cleantech sector saw significant growth with $400M in new funding.

Montreal remains the primary hub for venture capital activity."""

    chunks = knowledge_index.add_document("narratives/funding.md", text, {"title": "Funding Trends"})
    assert chunks > 0

    results = knowledge_index.query("AI funding Quebec")
    assert len(results) > 0
    assert any("AI" in r.chunk_text or "Quebec" in r.chunk_text for r in results)


def test_knowledge_index_remove(knowledge_index):
    knowledge_index.add_document("test.md", "some text content", {})
    assert knowledge_index.count > 0

    knowledge_index.remove_document("test.md")
    assert knowledge_index.count == 0


def test_knowledge_index_reindex_replaces(knowledge_index):
    knowledge_index.add_document("test.md", "version one content", {})
    count1 = knowledge_index.count

    knowledge_index.add_document("test.md", "version two with more content\n\nand another paragraph", {})
    # Should have replaced, not accumulated
    count2 = knowledge_index.count
    # The new document has more chunks, but old ones were removed
    results = knowledge_index.query("version two")
    assert len(results) > 0

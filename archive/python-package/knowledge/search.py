"""Semantic search over the knowledge base.

Combines vector search (via KnowledgeIndex) with document metadata
filtering from the DocumentStore.

Usage:
    from ecosystem.knowledge.search import KnowledgeSearch
    search = KnowledgeSearch()
    results = search.search("AI funding trends in Quebec", top_k=5)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from ecosystem.knowledge.index import KnowledgeIndex, SearchResult
from ecosystem.knowledge.store import DocumentStore

logger = logging.getLogger(__name__)


@dataclass
class SearchHit:
    """An enriched search result with document metadata."""

    doc_path: str
    title: str
    category: str
    chunk_text: str
    score: float
    doc_metadata: dict[str, Any] = field(default_factory=dict)


class KnowledgeSearch:
    """Search interface combining vector search with document metadata."""

    def __init__(
        self,
        store: DocumentStore | None = None,
        index: KnowledgeIndex | None = None,
    ) -> None:
        self.store = store or DocumentStore()
        self.index = index or KnowledgeIndex()

    def search(
        self,
        query: str,
        top_k: int = 5,
        category: str | None = None,
    ) -> list[SearchHit]:
        """Search the knowledge base.

        Args:
            query: Natural language search query.
            top_k: Maximum number of results to return.
            category: Optional filter by category (reports, narratives, etc.).

        Returns:
            List of SearchHit with enriched metadata, sorted by relevance.
        """
        # Fetch more results than needed if filtering by category
        fetch_k = top_k * 3 if category else top_k
        raw_results = self.index.query(query, top_k=fetch_k)

        hits: list[SearchHit] = []
        seen_paths: set[str] = set()

        for result in raw_results:
            # Filter by category if specified
            if category and not result.doc_path.startswith(category + "/"):
                continue

            # Deduplicate by document path (keep best-scoring chunk per doc)
            if result.doc_path in seen_paths:
                continue
            seen_paths.add(result.doc_path)

            # Enrich with document metadata
            doc = self.store.get(result.doc_path)
            doc_meta = doc.metadata if doc else {}
            title = doc_meta.get("title", result.doc_path)
            doc_category = result.doc_path.split("/")[0] if "/" in result.doc_path else ""

            hits.append(SearchHit(
                doc_path=result.doc_path,
                title=title,
                category=doc_category,
                chunk_text=result.chunk_text,
                score=result.score,
                doc_metadata=doc_meta,
            ))

            if len(hits) >= top_k:
                break

        return hits

    def reindex_all(self) -> int:
        """Reindex all documents in the knowledge base.

        Returns:
            Total number of chunks indexed.
        """
        docs = self.store.list_documents()
        total_chunks = 0
        for doc in docs:
            if not doc.content.strip():
                continue
            chunks = self.index.add_document(
                doc.path,
                doc.content,
                metadata={"title": doc.title, "category": doc.category},
            )
            total_chunks += chunks
        logger.info("Reindexed %d documents (%d total chunks)", len(docs), total_chunks)
        return total_chunks

    def index_document(self, doc_path: str) -> int:
        """Index or reindex a single document.

        Returns:
            Number of chunks indexed.
        """
        doc = self.store.get(doc_path)
        if doc is None:
            raise FileNotFoundError(f"Document not found: {doc_path}")
        return self.index.add_document(
            doc.path,
            doc.content,
            metadata={"title": doc.title, "category": doc.category},
        )

"""Vector indexing for the knowledge base.

Uses ChromaDB when available, falls back to a simple TF-IDF index.
Documents are chunked, embedded, and stored for semantic search.

Usage:
    from ecosystem.knowledge.index import KnowledgeIndex
    index = KnowledgeIndex()
    index.add_document("reports/q1.md", text, metadata)
    results = index.query("funding trends in AI", top_k=5)
"""

from __future__ import annotations

import hashlib
import json
import logging
import math
import re
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from ecosystem.config import settings

logger = logging.getLogger(__name__)

# Try to import ChromaDB; fall back gracefully
_HAS_CHROMADB = False
try:
    import chromadb

    _HAS_CHROMADB = True
except Exception:
    logger.info("ChromaDB not available; using fallback TF-IDF index")


@dataclass
class SearchResult:
    """A single search result from the index."""

    doc_path: str
    chunk_text: str
    score: float
    metadata: dict[str, Any] = field(default_factory=dict)


# ============================================================
# Text chunking
# ============================================================

def chunk_text(
    text: str,
    chunk_size: int = 500,
    chunk_overlap: int = 50,
) -> list[str]:
    """Split text into overlapping chunks by character count, respecting paragraph boundaries."""
    if not text:
        return []

    # Split on double newlines (paragraphs) first
    paragraphs = re.split(r"\n\n+", text.strip())
    chunks: list[str] = []
    current_chunk: list[str] = []
    current_len = 0

    for para in paragraphs:
        para = para.strip()
        if not para:
            continue
        para_len = len(para)

        if current_len + para_len > chunk_size and current_chunk:
            chunks.append("\n\n".join(current_chunk))
            # Keep last paragraph for overlap
            if chunk_overlap > 0 and current_chunk:
                last = current_chunk[-1]
                current_chunk = [last] if len(last) <= chunk_overlap else []
                current_len = len(last) if current_chunk else 0
            else:
                current_chunk = []
                current_len = 0

        current_chunk.append(para)
        current_len += para_len

    if current_chunk:
        chunks.append("\n\n".join(current_chunk))

    return chunks if chunks else [text[:chunk_size]]


def _chunk_id(doc_path: str, chunk_idx: int) -> str:
    """Generate a deterministic ID for a chunk."""
    return hashlib.md5(f"{doc_path}::{chunk_idx}".encode()).hexdigest()


# ============================================================
# Fallback TF-IDF index (no external deps beyond stdlib)
# ============================================================

_WORD_RE = re.compile(r"[a-z0-9]+")


def _tokenize(text: str) -> list[str]:
    return _WORD_RE.findall(text.lower())


class _FallbackIndex:
    """Simple TF-IDF-like index stored as JSON. Good enough for small knowledge bases."""

    def __init__(self, index_path: Path) -> None:
        self.index_path = index_path
        self.index_path.parent.mkdir(parents=True, exist_ok=True)
        self._docs: dict[str, dict[str, Any]] = {}  # chunk_id -> {text, doc_path, metadata, tokens}
        self._idf: dict[str, float] = {}
        self._load()

    def _load(self) -> None:
        if self.index_path.exists():
            try:
                data = json.loads(self.index_path.read_text(encoding="utf-8"))
                self._docs = data.get("docs", {})
                self._idf = data.get("idf", {})
            except Exception:
                self._docs = {}
                self._idf = {}

    def _save(self) -> None:
        data = {"docs": self._docs, "idf": self._idf}
        self.index_path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")

    def _rebuild_idf(self) -> None:
        n = len(self._docs)
        if n == 0:
            self._idf = {}
            return
        df: Counter[str] = Counter()
        for doc in self._docs.values():
            unique_tokens = set(doc.get("tokens", []))
            for t in unique_tokens:
                df[t] += 1
        self._idf = {t: math.log(1 + n / count) for t, count in df.items()}

    def add(self, chunk_id: str, text: str, doc_path: str, metadata: dict[str, Any]) -> None:
        tokens = _tokenize(text)
        self._docs[chunk_id] = {
            "text": text,
            "doc_path": doc_path,
            "metadata": metadata,
            "tokens": tokens,
        }

    def remove_by_doc_path(self, doc_path: str) -> int:
        to_remove = [cid for cid, d in self._docs.items() if d["doc_path"] == doc_path]
        for cid in to_remove:
            del self._docs[cid]
        return len(to_remove)

    def commit(self) -> None:
        self._rebuild_idf()
        self._save()

    def query(self, query_text: str, top_k: int = 5) -> list[SearchResult]:
        query_tokens = _tokenize(query_text)
        if not query_tokens or not self._docs:
            return []

        query_tf = Counter(query_tokens)
        scores: list[tuple[str, float]] = []

        for chunk_id, doc in self._docs.items():
            doc_tokens = doc.get("tokens", [])
            doc_tf = Counter(doc_tokens)
            score = 0.0
            for token, qtf in query_tf.items():
                if token in doc_tf:
                    tf = doc_tf[token] / max(len(doc_tokens), 1)
                    idf = self._idf.get(token, 0.0)
                    score += tf * idf * qtf
            if score > 0:
                scores.append((chunk_id, score))

        scores.sort(key=lambda x: x[1], reverse=True)
        results = []
        for chunk_id, score in scores[:top_k]:
            doc = self._docs[chunk_id]
            results.append(SearchResult(
                doc_path=doc["doc_path"],
                chunk_text=doc["text"],
                score=score,
                metadata=doc.get("metadata", {}),
            ))
        return results

    @property
    def count(self) -> int:
        return len(self._docs)


# ============================================================
# ChromaDB index wrapper
# ============================================================

class _ChromaIndex:
    """ChromaDB-backed vector index."""

    def __init__(self, persist_dir: str, collection_name: str = "knowledge_base") -> None:
        self._client = chromadb.PersistentClient(path=persist_dir)
        self._collection = self._client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"},
        )

    def add(self, chunk_id: str, text: str, doc_path: str, metadata: dict[str, Any]) -> None:
        meta = {**metadata, "doc_path": doc_path}
        # ChromaDB metadata values must be str/int/float
        meta = {k: str(v) for k, v in meta.items()}
        self._collection.upsert(
            ids=[chunk_id],
            documents=[text],
            metadatas=[meta],
        )

    def remove_by_doc_path(self, doc_path: str) -> int:
        results = self._collection.get(where={"doc_path": doc_path})
        if results["ids"]:
            self._collection.delete(ids=results["ids"])
            return len(results["ids"])
        return 0

    def commit(self) -> None:
        pass  # ChromaDB auto-persists

    def query(self, query_text: str, top_k: int = 5) -> list[SearchResult]:
        results = self._collection.query(
            query_texts=[query_text],
            n_results=top_k,
        )
        search_results = []
        for i, doc_id in enumerate(results["ids"][0]):
            meta = results["metadatas"][0][i] if results["metadatas"] else {}
            distance = results["distances"][0][i] if results["distances"] else 0.0
            search_results.append(SearchResult(
                doc_path=meta.get("doc_path", ""),
                chunk_text=results["documents"][0][i] if results["documents"] else "",
                score=1.0 - distance,  # Convert distance to similarity
                metadata=meta,
            ))
        return search_results

    @property
    def count(self) -> int:
        return self._collection.count()


# ============================================================
# Public API
# ============================================================

class KnowledgeIndex:
    """Vector index for the knowledge base. Automatically selects backend."""

    def __init__(
        self,
        persist_dir: str | Path | None = None,
        chunk_size: int = 500,
        chunk_overlap: int = 50,
    ) -> None:
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
        persist = str(persist_dir or settings.chromadb_path)

        if _HAS_CHROMADB:
            logger.info("Using ChromaDB index at %s", persist)
            self._backend = _ChromaIndex(persist)
        else:
            fallback_path = Path(persist).parent / "fallback_index.json"
            logger.info("Using fallback TF-IDF index at %s", fallback_path)
            self._backend = _FallbackIndex(fallback_path)

    def add_document(
        self,
        doc_path: str,
        text: str,
        metadata: dict[str, Any] | None = None,
    ) -> int:
        """Index a document by chunking and storing in the vector DB.

        Args:
            doc_path: Relative path of the document in the knowledge base.
            text: Full text content of the document.
            metadata: Optional metadata to attach to each chunk.

        Returns:
            Number of chunks indexed.
        """
        # Remove existing chunks for this document
        self._backend.remove_by_doc_path(doc_path)

        chunks = chunk_text(text, self.chunk_size, self.chunk_overlap)
        meta = metadata or {}

        for i, chunk in enumerate(chunks):
            chunk_id = _chunk_id(doc_path, i)
            self._backend.add(chunk_id, chunk, doc_path, {**meta, "chunk_index": i})

        self._backend.commit()
        logger.info("Indexed %d chunks for %s", len(chunks), doc_path)
        return len(chunks)

    def remove_document(self, doc_path: str) -> int:
        """Remove all chunks for a document from the index.

        Returns:
            Number of chunks removed.
        """
        count = self._backend.remove_by_doc_path(doc_path)
        self._backend.commit()
        logger.info("Removed %d chunks for %s", count, doc_path)
        return count

    def query(self, query_text: str, top_k: int = 5) -> list[SearchResult]:
        """Search the index for relevant chunks.

        Args:
            query_text: Search query.
            top_k: Maximum number of results.

        Returns:
            List of SearchResult sorted by relevance.
        """
        return self._backend.query(query_text, top_k)

    @property
    def count(self) -> int:
        """Total number of chunks in the index."""
        return self._backend.count

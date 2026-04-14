"""Ingest meeting notes from Google Docs into the knowledge base."""

from __future__ import annotations

import logging
import re
from datetime import datetime

from ecosystem.agents.runner import TaskResult, TaskStatus, register_task

logger = logging.getLogger(__name__)


@register_task("notes_ingest")
def handle_notes_ingest(**kwargs) -> TaskResult:
    """Pull meeting notes from Google Docs and add to the knowledge base.

    Steps:
    1. List Google Docs in the configured meeting notes folder
    2. For each new/updated doc, extract text
    3. Create/update markdown files in knowledge_base/meeting_notes/
    4. Index for search
    """
    from ecosystem.connectors.google_docs import GoogleDocsClient
    from ecosystem.knowledge.search import KnowledgeSearch
    from ecosystem.knowledge.store import DocumentStore

    try:
        gdocs = GoogleDocsClient()
        store = DocumentStore()
        search = KnowledgeSearch(store=store)

        folder_id = kwargs.get("folder_id", None)
        files = gdocs.list_files_in_folder(folder_id=folder_id)

        if not files:
            return TaskResult(
                task_name="notes_ingest",
                status=TaskStatus.SUCCESS,
                started_at=datetime.now(),
                message="No meeting notes found in folder",
            )

        created = 0
        updated = 0

        for file_info in files:
            doc_id = file_info["id"]
            doc_name = file_info.get("name", doc_id)
            modified = file_info.get("modifiedTime", "")

            # Sanitize filename
            safe_name = re.sub(r"[^a-zA-Z0-9_\- ]", "", doc_name).strip().replace(" ", "_").lower()
            rel_path = f"meeting_notes/{safe_name}.md"

            # Check if we already have this doc and if it's been modified
            existing = store.get(rel_path)
            if existing:
                existing_modified = existing.metadata.get("google_modified_time", "")
                if existing_modified == modified:
                    continue  # Skip unchanged docs
                # Update
                text = gdocs.get_document_text(doc_id)
                store.update(
                    rel_path,
                    content=text,
                    metadata_updates={
                        "google_doc_id": doc_id,
                        "google_modified_time": modified,
                    },
                )
                updated += 1
            else:
                # Create new
                text = gdocs.get_document_text(doc_id)
                store.create(
                    rel_path,
                    content=text,
                    title=doc_name,
                    metadata={
                        "type": "meeting_notes",
                        "google_doc_id": doc_id,
                        "google_modified_time": modified,
                    },
                )
                created += 1

            # Index for search
            search.index_document(rel_path)

        return TaskResult(
            task_name="notes_ingest",
            status=TaskStatus.SUCCESS,
            started_at=datetime.now(),
            message=f"Ingested {created} new, {updated} updated meeting notes",
            details={"created": created, "updated": updated, "total_docs": len(files)},
        )
    except Exception as e:
        return TaskResult(
            task_name="notes_ingest",
            status=TaskStatus.FAILED,
            started_at=datetime.now(),
            error=str(e),
        )

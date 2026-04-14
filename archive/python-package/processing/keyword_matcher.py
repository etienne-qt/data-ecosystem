"""Vectorized keyword matching engine for industry/technology classification."""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from pathlib import Path

import pandas as pd

logger = logging.getLogger(__name__)


@dataclass
class MatchResult:
    """Per-company keyword match aggregation."""
    labels: list[str]
    top_label: str | None
    top_score: float
    match_count: int


def load_keywords(csv_path: Path, label_col: str, keyword_col: str = "KEYWORD",
                  weight_col: str = "WEIGHT", active_col: str = "ACTIVE") -> pd.DataFrame:
    """Load keyword CSV, filter to active rows."""
    df = pd.read_csv(csv_path)
    # Normalize active column to bool
    df[active_col] = df[active_col].astype(str).str.strip().str.lower().isin({"true", "1", "yes"})
    df = df[df[active_col]].copy()
    df[weight_col] = pd.to_numeric(df[weight_col], errors="coerce").fillna(1.0)
    df[keyword_col] = df[keyword_col].astype(str).str.strip().str.lower()
    # Drop empty keywords
    df = df[df[keyword_col].str.len() > 0]
    logger.info("Loaded %d active keywords from %s", len(df), csv_path.name)
    return df


def _compile_pattern(keyword: str) -> re.Pattern:
    """Compile a keyword to a word-boundary regex."""
    escaped = re.escape(keyword)
    return re.compile(r"\b" + escaped + r"\b", re.IGNORECASE)


def match_keywords(
    texts: pd.Series,
    keywords_df: pd.DataFrame,
    label_col: str,
    keyword_col: str = "KEYWORD",
    weight_col: str = "WEIGHT",
) -> dict[int, MatchResult]:
    """Vectorized keyword matching across all texts.

    Args:
        texts: Series of match_text strings (index = row positions).
        keywords_df: DataFrame with label, keyword, weight columns.
        label_col: Column name for the label (e.g. INDUSTRY_LABEL).
        keyword_col: Column name for keyword.
        weight_col: Column name for weight.

    Returns:
        Dict mapping index → MatchResult.
    """
    n = len(texts)
    if n == 0:
        return {}

    # Fill NaN with empty string
    texts_clean = texts.fillna("").astype(str)

    # Accumulate scores: {row_idx: {label: total_weight}}
    scores: dict[int, dict[str, float]] = {}
    match_counts: dict[int, int] = {}

    for _, kw_row in keywords_df.iterrows():
        keyword = kw_row[keyword_col]
        label = kw_row[label_col]
        weight = kw_row[weight_col]

        pattern = _compile_pattern(keyword)
        hits = texts_clean.str.contains(pattern, na=False)

        for idx in hits[hits].index:
            if idx not in scores:
                scores[idx] = {}
                match_counts[idx] = 0
            scores[idx][label] = scores[idx].get(label, 0.0) + weight
            match_counts[idx] += 1

    # Build results
    results: dict[int, MatchResult] = {}
    for idx in range(n):
        real_idx = texts.index[idx] if hasattr(texts, "index") else idx
        if real_idx in scores:
            label_scores = scores[real_idx]
            sorted_labels = sorted(label_scores.items(), key=lambda x: x[1], reverse=True)
            results[real_idx] = MatchResult(
                labels=[l for l, _ in sorted_labels],
                top_label=sorted_labels[0][0],
                top_score=sorted_labels[0][1],
                match_count=match_counts[real_idx],
            )
        else:
            results[real_idx] = MatchResult(
                labels=[], top_label=None, top_score=0.0, match_count=0,
            )

    return results

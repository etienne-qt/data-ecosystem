#!/usr/bin/env python3
"""Extract a data-safe schema summary from any CSV/Excel/Parquet file.

Outputs column names, types, fill rates, and value distributions — never
actual data values. Safe to share with AI agents.

Usage:
    python scripts/extract_schema.py path/to/file.csv
    python scripts/extract_schema.py path/to/file.csv --output context/schema_pitchbook.md
    python scripts/extract_schema.py path/to/file.xlsx --sheet "Sheet1"
    python scripts/extract_schema.py path/to/file.parquet
"""

import argparse
import sys
from pathlib import Path


def load_file(path: Path, sheet: str | None = None, encoding: str = "utf-8-sig"):
    """Load CSV, Excel, or Parquet into a DataFrame."""
    import pandas as pd

    suffix = path.suffix.lower()
    if suffix == ".parquet":
        return pd.read_parquet(path)
    elif suffix in (".xlsx", ".xls"):
        return pd.read_excel(path, sheet_name=sheet or 0, dtype=str, keep_default_na=False)
    elif suffix == ".csv":
        return pd.read_csv(path, dtype=str, keep_default_na=False, encoding=encoding)
    else:
        raise ValueError(f"Unsupported file type: {suffix}")


def extract_schema(df, source_name: str, file_path: Path) -> str:
    """Generate a markdown schema summary — no raw data values."""
    import pandas as pd

    lines = []
    lines.append(f"## Source: {source_name}")
    lines.append(f"- **File**: `{file_path.name}`")
    lines.append(f"- **Rows**: {len(df):,}")
    lines.append(f"- **Columns**: {len(df.columns)}")
    lines.append(f"- **File size**: {file_path.stat().st_size / 1024 / 1024:.1f} MB")
    lines.append("")

    lines.append("### Column Inventory")
    lines.append("")
    lines.append(f"| # | Column Name | Inferred Type | Non-null | Fill % | Unique | Notes |")
    lines.append(f"|---|-------------|---------------|----------|--------|--------|-------|")

    for i, col in enumerate(df.columns, 1):
        series = df[col]
        # Replace empty strings with NaN for analysis
        mask = series.notna() & (series.astype(str).str.strip() != "")
        non_null = mask.sum()
        fill_pct = non_null / len(df) * 100 if len(df) > 0 else 0
        unique_count = series[mask].nunique()

        # Infer type from content
        inferred = _infer_type(series[mask])

        # Notes: flag low cardinality (likely enum/category)
        notes = []
        if 0 < unique_count <= 20 and non_null > 0:
            notes.append(f"~{unique_count} distinct values (likely categorical)")
        elif unique_count == non_null and non_null > 0:
            notes.append("all unique (likely ID)")
        if fill_pct == 0:
            notes.append("completely empty")
        if fill_pct < 10 and fill_pct > 0:
            notes.append("very sparse")

        notes_str = "; ".join(notes) if notes else ""
        lines.append(
            f"| {i} | {col} | {inferred} | {non_null:,} | {fill_pct:.1f}% | {unique_count:,} | {notes_str} |"
        )

    # Duplicate analysis on likely ID columns
    lines.append("")
    lines.append("### Potential Identifier Columns")
    lines.append("")
    for col in df.columns:
        series = df[col]
        mask = series.notna() & (series.astype(str).str.strip() != "")
        non_null = mask.sum()
        unique_count = series[mask].nunique()
        if non_null > 0 and unique_count == non_null and non_null > len(df) * 0.5:
            dupes = non_null - unique_count
            lines.append(f"- **{col}**: {non_null:,} values, {unique_count:,} unique, {dupes} duplicates")

    # Columns that look like they could be used for matching
    lines.append("")
    lines.append("### Matching Candidate Columns")
    lines.append("")
    match_keywords = ["name", "website", "url", "linkedin", "domain", "neq", "register",
                      "id", "email", "phone", "city", "address"]
    for col in df.columns:
        col_lower = col.lower()
        for kw in match_keywords:
            if kw in col_lower:
                series = df[col]
                mask = series.notna() & (series.astype(str).str.strip() != "")
                fill = mask.sum() / len(df) * 100 if len(df) > 0 else 0
                lines.append(f"- **{col}** ({fill:.0f}% filled) — potential match on `{kw}`")
                break

    return "\n".join(lines)


def _infer_type(series) -> str:
    """Infer the semantic type of a series without exposing values."""
    import pandas as pd

    if len(series) == 0:
        return "empty"

    sample = series.astype(str).head(100)

    # Check for numeric
    try:
        pd.to_numeric(sample, errors="raise")
        if sample.str.contains(r"\.", regex=True).any():
            return "float"
        return "integer"
    except (ValueError, TypeError):
        pass

    # Check for dates
    date_patterns = sample.str.match(r"^\d{4}[-/]\d{1,2}[-/]\d{1,2}", na=False)
    if date_patterns.sum() > len(sample) * 0.5:
        return "date"

    # Check for URLs
    url_patterns = sample.str.match(r"^https?://", na=False)
    if url_patterns.sum() > len(sample) * 0.3:
        return "url"

    # Check for boolean-like
    bool_vals = {"yes", "no", "true", "false", "0", "1", "oui", "non"}
    if set(sample.str.strip().str.lower().unique()) <= bool_vals:
        return "boolean"

    # Check average length
    avg_len = sample.str.len().mean()
    if avg_len > 200:
        return "long_text"
    if avg_len > 50:
        return "text"

    return "short_text"


def main():
    parser = argparse.ArgumentParser(description="Extract a data-safe schema summary")
    parser.add_argument("file", help="Path to CSV, Excel, or Parquet file")
    parser.add_argument("--output", "-o", help="Output .md file (default: print to stdout)")
    parser.add_argument("--source-name", "-n", help="Name for the data source (default: filename)")
    parser.add_argument("--sheet", help="Excel sheet name (for .xlsx files)")
    parser.add_argument("--encoding", default="utf-8-sig", help="CSV encoding (default: utf-8-sig)")
    args = parser.parse_args()

    path = Path(args.file)
    if not path.exists():
        print(f"Error: {path} not found", file=sys.stderr)
        sys.exit(1)

    source_name = args.source_name or path.stem.replace("_", " ").replace("-", " ").title()

    print(f"Loading {path}...", file=sys.stderr)
    df = load_file(path, sheet=args.sheet, encoding=args.encoding)
    print(f"Loaded {len(df):,} rows, {len(df.columns)} columns", file=sys.stderr)

    schema_md = extract_schema(df, source_name, path)

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(schema_md, encoding="utf-8")
        print(f"Schema written to {out_path}", file=sys.stderr)
    else:
        print(schema_md)


if __name__ == "__main__":
    main()

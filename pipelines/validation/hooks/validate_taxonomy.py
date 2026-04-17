#!/usr/bin/env python3
"""Pre-commit hook: validate taxonomy YAML files.

Parses every taxonomy/*.yaml file and enforces basic structural rules:
- Valid YAML syntax.
- `code` fields are unique within each file.
- Every `parent` value (if present) references an existing `code` in the
  same file.
- Required fields are present per file type.

Exit 1 blocks the commit.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - surfaced to the committer
    print("validate_taxonomy: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

TAXONOMY_DIR = Path("taxonomy")

# Files listed here have a top-level "list of code-bearing items" schema
# (sectors: [...], stages: [...], etc.). Each item must have the required
# keys and a unique `code`. startup-criteria.yaml uses a different nested
# schema and is only checked for YAML well-formedness.
LIST_SCHEMAS = {
    "sectors.yaml": ("sectors", {"code", "label_en", "label_fr", "description"}),
    "stages.yaml": ("stages", {"code", "label_en", "label_fr", "order"}),
    "geographies.yaml": ("regions", {"code", "label_en", "label_fr"}),
    "labels.yaml": ("labels", {"code", "label_en", "label_fr", "category"}),
}


def validate_file(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        return [f"{path}: invalid YAML — {exc}"]

    if doc is None:
        return [f"{path}: empty file"]

    spec = LIST_SCHEMAS.get(path.name)
    if spec is None:
        return errors

    root_key, required = spec
    if root_key not in doc:
        return [f"{path}: missing root key `{root_key}`"]

    items = doc[root_key]
    if not isinstance(items, list):
        return [f"{path}: `{root_key}` must be a list"]

    codes: set[str] = set()
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            errors.append(f"{path}[{idx}]: entry must be a mapping")
            continue
        missing = required - item.keys()
        if missing:
            errors.append(f"{path}[{idx}] (code={item.get('code', '?')}): missing {sorted(missing)}")
        code = item.get("code")
        if code is not None:
            if code in codes:
                errors.append(f"{path}: duplicate code `{code}`")
            codes.add(code)

    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            continue
        parent = item.get("parent")
        if parent is not None and parent not in codes:
            errors.append(
                f"{path}[{idx}] (code={item.get('code', '?')}): parent `{parent}` not found in same file"
            )

    return errors


def main() -> int:
    if not TAXONOMY_DIR.exists():
        return 0

    all_errors: list[str] = []
    for yaml_path in sorted(TAXONOMY_DIR.glob("*.yaml")):
        all_errors.extend(validate_file(yaml_path))

    if not all_errors:
        return 0

    print("Taxonomy validation failed:")
    for err in all_errors:
        print(f"  {err}")
    return 1


if __name__ == "__main__":
    sys.exit(main())

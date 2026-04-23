#!/usr/bin/env python3
# encoding: utf-8

from __future__ import annotations

import argparse
from pathlib import Path


def read_text_lines(path: Path) -> list[str]:
    """Reads a UTF-8 text file and returns newline-preserving lines."""
    return path.read_text(encoding="utf-8").splitlines(keepends=True)


def write_text_lines(path: Path, lines: list[str]) -> None:
    """Writes newline-preserving lines back to a UTF-8 text file."""
    path.write_text("".join(lines), encoding="utf-8")


def remove_translator_entries(lines: list[str]) -> list[str]:
    """Drops translator lines that reference optional components removed from the M2 bundle."""
    needles = (
        "lua_translator@calculator_translator",
        "table_translator@custom_phraseQMZ",
        "reverse_lookup_translator",
    )
    return [ln for ln in lines if not any(n in ln for n in needles)]


def strip_reverse_lookup_section(lines: list[str]) -> list[str]:
    """Removes the top-level reverse_lookup block up to (but not including) key_binder."""
    out: list[str] = []
    i = 0
    while i < len(lines):
        if lines[i].startswith("reverse_lookup:"):
            i += 1
            while i < len(lines) and not lines[i].startswith("key_binder:"):
                i += 1
            continue
        out.append(lines[i])
        i += 1
    return out


def strip_schema_dependency_flypydz(lines: list[str]) -> list[str]:
    """Removes flypydz from schema.dependencies, dropping the block if it becomes empty."""
    out: list[str] = []
    i = 0
    while i < len(lines):
        if lines[i].startswith("  dependencies:"):
            j = i + 1
            dep_lines: list[str] = []
            while j < len(lines) and lines[j].startswith("    -"):
                dep_lines.append(lines[j])
                j += 1
            kept = [d for d in dep_lines if "flypydz" not in d]
            if kept:
                out.append(lines[i])
                out.extend(kept)
            i = j
            if i < len(lines) and lines[i].strip() == "":
                i += 1
            continue
        out.append(lines[i])
        i += 1
    return out


def patch_flypy_schema_trimmed(lines: list[str]) -> list[str]:
    """Applies the M2 trimmed-bundle edits to flypy.schema.yaml content."""
    lines = remove_translator_entries(lines)
    lines = strip_reverse_lookup_section(lines)
    lines = strip_schema_dependency_flypydz(lines)
    return lines


def parse_args() -> argparse.Namespace:
    """Parses CLI arguments for in-place schema patching."""
    p = argparse.ArgumentParser(description="Patch staged flypy.schema.yaml for trimmed M2 bundle.")
    p.add_argument("schema_path", type=Path, help="Path to flypy.schema.yaml under build staging.")
    return p.parse_args()


def main() -> None:
    """Entry point: patches the given schema file in place."""
    args = parse_args()
    path: Path = args.schema_path
    original = read_text_lines(path)
    patched = patch_flypy_schema_trimmed(original)
    write_text_lines(path, patched)


if __name__ == "__main__":
    main()

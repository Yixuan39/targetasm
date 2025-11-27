#!/usr/bin/env python3
"""Merge Compleasm + QUAST outputs for a single assembly into a TSV row."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Iterable, List, Tuple


def parse_compleasm(path: Path) -> List[Tuple[str, str]]:
    metrics: List[Tuple[str, str]] = []
    if not path.exists():
        raise FileNotFoundError(f"Compleasm summary not found: {path}")
    with path.open() as handle:
        next(handle, None)  # skip header line
        for line in handle:
            line = line.strip()
            if not line or ":" not in line:
                continue
            key, value = line.split(":", 1)
            metrics.append((key.strip(), value.strip()))
    return metrics


def parse_quast(path: Path) -> List[Tuple[str, str]]:
    metrics: List[Tuple[str, str]] = []
    if not path.exists():
        raise FileNotFoundError(f"QUAST report not found: {path}")
    with path.open() as handle:
        for raw in handle:
            parts = raw.rstrip("\n").split("\t")
            if len(parts) != 2:
                continue
            metrics.append((parts[0].strip(), parts[1].strip()))
    return metrics


def write_row(
    label: str,
    source: Path,
    comp_metrics: Iterable[Tuple[str, str]],
    quast_metrics: Iterable[Tuple[str, str]],
    output_path: Path,
) -> None:
    columns: List[str] = ["Step", "Assembly", "Assembly_Path"]
    columns += [key for key, _ in comp_metrics]
    columns += [key for key, _ in quast_metrics]

    values: List[str] = [label, source.name, str(source)]
    values += [val for _, val in comp_metrics]
    values += [val for _, val in quast_metrics]

    with output_path.open("w") as handle:
        handle.write("\t".join(columns) + "\n")
        handle.write("\t".join(values) + "\n")


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit("Usage: quality_merge.py <label> <source_path> <work_dir> <row_out>")

    label = sys.argv[1]
    source = Path(sys.argv[2])
    work_dir = Path(sys.argv[3])
    row_out = Path(sys.argv[4])

    comp_metrics = parse_compleasm(work_dir / "compleasm" / "summary.txt")
    quast_metrics = parse_quast(work_dir / "quast" / "report.tsv")
    write_row(label, source, comp_metrics, quast_metrics, row_out)


if __name__ == "__main__":
    main()

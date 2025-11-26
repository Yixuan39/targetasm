#!/usr/bin/env python3

"""Generate compleasm + QUAST metrics for assemblies listed in assemblies.tsv."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import List, Sequence, Tuple
import pandas as pd


ASSEMBLY_MANIFEST = Path(os.environ["QUALITY_MANIFEST"])
OUTPUT_TABLE = Path(os.environ["QUALITY_OUTPUT"])
DEFAULT_THREADS = int(os.environ["QUALITY_THREADS"])
DEFAULT_LIBRARY = Path(os.environ["QUALITY_LIBRARY"]).expanduser()
DEFAULT_LINEAGE = os.environ["QUALITY_LINEAGE"]


def run_command(cmd: Sequence[str]) -> None:
    subprocess.run(cmd, check=True)


def safe_name(label: str) -> str:
    return label.replace(' ', '_').replace('/', '_')


def parse_compleasm(summary_path: Path) -> pd.Series:
    df = pd.read_csv(summary_path, sep=",", header=None, skiprows=1, names=["Metric"])
    parts = df["Metric"].str.split(":", n=1, expand=True).fillna("")
    parts[0] = parts[0].str.strip()
    parts[1] = parts[1].str.strip()
    return parts.set_index(0)[1]


def run_compleasm(label: str, assembly: Path, work_root: Path, threads: int, library: Path, lineage: str) -> pd.Series:
    out_dir = work_root / f"compleasm_{safe_name(label)}"
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd = [
        "compleasm",
        "run",
        "--assembly_path",
        str(assembly),
        "--output_dir",
        str(out_dir),
        "--threads",
        str(threads),
        "--library_path",
        str(library),
        "--lineage",
        lineage,
    ]
    run_command(cmd)
    summary = out_dir / "summary.txt"
    return parse_compleasm(summary)


def run_quast(label: str, assembly: Path, work_root: Path, threads: int) -> pd.Series:
    out_dir = work_root / f"quast_{safe_name(label)}"
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd = [
        "quast",
        "--output-dir",
        str(out_dir),
        "--threads",
        str(threads),
        "--eukaryote",
        str(assembly),
    ]
    run_command(cmd)
    report = out_dir / "report.tsv"
    df = pd.read_csv(report, sep="\t", header=None, names=["Metric", "Value"])
    return df.set_index("Metric")["Value"]


def evaluate(label: str, assembly: Path, threads: int, library: Path, lineage: str, work_root: Path) -> pd.DataFrame:
    compleasm_metrics = run_compleasm(label, assembly, work_root, threads, library, lineage)
    quast_metrics = run_quast(label, assembly, work_root, threads)
    row = pd.concat([
        pd.Series({"Step": label, "Assembly": assembly.name, "Assembly_Path": str(assembly)}),
        compleasm_metrics,
        quast_metrics,
    ])
    return row.to_frame().T


def load_manifest(path: Path) -> List[Tuple[str, Path]]:
    if not path.exists():
        raise FileNotFoundError(f"Manifest not found: {path}")
    entries: List[Tuple[str, Path]] = []
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        label, asm_path = line.split("\t", 1)
        entries.append((label.strip(), Path(asm_path.strip())))
    if not entries:
        raise ValueError(f"Manifest is empty: {path}")
    return entries


def main() -> None:
    assemblies = load_manifest(ASSEMBLY_MANIFEST)
    work_root = Path.cwd() / "quality_runs"
    work_root.mkdir(parents=True, exist_ok=True)

    rows: List[pd.DataFrame] = []
    for label, assembly in assemblies:
        if not assembly.exists():
            raise FileNotFoundError(f"Assembly not found: {assembly}")
        rows.append(
            evaluate(
                label=label,
                assembly=assembly,
                threads=DEFAULT_THREADS,
                library=DEFAULT_LIBRARY,
                lineage=DEFAULT_LINEAGE,
                work_root=work_root,
            )
        )

    if not rows:
        raise ValueError("No assembly entries were provided for quality evaluation.")

    result = pd.concat(rows, ignore_index=True)
    OUTPUT_TABLE.parent.mkdir(parents=True, exist_ok=True)
    result.to_csv(OUTPUT_TABLE, sep="\t", index=False)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(
            f"Command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}\n"
        )
        raise

#!/usr/bin/env python3
"""Rebuild or verify the committed UA202013 smoke-test reads.

The file is the first 1,000 FASTQ records, in file order, of the public
PacBio HiFi run for Peronospora effusa isolate UA202013 (Fletcher et al. 2022,
Mol Plant Microbe Interact, doi:10.1094/MPMI-09-21-0227-R).

    BioProject PRJNA745455
    BioSample   SAMN20203776
    SRA run     SRR15142133
    Experiment  SRX11449564

SRA submitted this run as ``demultiplex.bc1010_BAK8A_OA--bc1010_BAK8A_OA.Q20.fastq``.
ENA serves that FASTQ as ``SRR15142133_subreads.fastq.gz``; the ``subreads``
suffix is ENA's PacBio filename, not a separate library. No other isolate is used.

The gzip member is written with an empty name and timestamp so the SHA-256
does not depend on the output path or the clock. ``--check`` only reads the
committed file.
"""

import argparse
import gzip
import hashlib
import subprocess
import sys
from pathlib import Path

SOURCE_URL = (
    "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR151/033/SRR15142133/"
    "SRR15142133_subreads.fastq.gz"
)
READ_COUNT = 1000
BASE_COUNT = 7289312
SHA256 = "43a87a5ddafcea53a1df2d8a8130549e30ce44c3043f8034418310eb0a8d6b75"
HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "testdata" / "UA202013.fastq.gz"


def records_from_source(url, count):
    process = subprocess.Popen(
        ["curl", "--fail", "--location", "--retry", "5", "--retry-delay", "2", "--silent", url],
        stdout=subprocess.PIPE,
    )
    records = []
    bases = 0
    try:
        with gzip.GzipFile(fileobj=process.stdout) as source:
            for _ in range(count):
                header = source.readline()
                sequence = source.readline()
                separator = source.readline()
                quality = source.readline()
                if not quality:
                    raise SystemExit(f"FASTQ ended before {count} records: {url}")
                if not (header.startswith(b"@") and separator.startswith(b"+") and len(sequence.strip()) == len(quality.strip())):
                    raise SystemExit("Source FASTQ record is not well formed")
                records.append(header + sequence + separator + quality)
                bases += len(sequence.strip())
    finally:
        process.stdout.close()
        returncode = process.wait()
    # 23: curl stopped because we closed the pipe after the records we needed.
    if returncode not in (0, 23):
        raise SystemExit(f"curl exited {returncode} while reading {url}")
    return records, bases


def write_fastq(path, records):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, filename="") as handle:
        handle.write(b"".join(records))


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inspect(path):
    reads = 0
    bases = 0
    with gzip.open(path, "rb") as handle:
        while True:
            header = handle.readline()
            if not header:
                break
            sequence = handle.readline()
            separator = handle.readline()
            quality = handle.readline()
            if not quality or not header.startswith(b"@SRR15142133."):
                raise SystemExit(f"{path} is not the SRR15142133 subset")
            reads += 1
            bases += len(sequence.strip())
    return reads, bases


def verify(path):
    if not path.is_file():
        raise SystemExit(f"Missing {path}. Rebuild it with: python3 {Path(__file__).name}")
    digest = sha256(path)
    reads, bases = inspect(path)
    errors = []
    if digest != SHA256:
        errors.append(f"SHA-256 {digest} != {SHA256}")
    if reads != READ_COUNT or bases != BASE_COUNT:
        errors.append(f"{reads} reads / {bases} bases, expected {READ_COUNT} / {BASE_COUNT}")
    if errors:
        raise SystemExit(f"{path} failed verification:\n" + "\n".join(errors))
    print(f"{path}: {reads} reads, {bases} bases, sha256 {digest}")


def rebuild(path):
    records, bases = records_from_source(SOURCE_URL, READ_COUNT)
    if bases != BASE_COUNT:
        raise SystemExit(f"Source subset has {bases} bases, expected {BASE_COUNT}. The ENA file may have changed.")
    temporary = path.with_suffix(path.suffix + ".partial")
    write_fastq(temporary, records)
    # A second compression of the same records must be byte-identical.
    confirm = path.with_suffix(path.suffix + ".confirm")
    write_fastq(confirm, records)
    if sha256(temporary) != sha256(confirm):
        raise SystemExit("gzip output was not deterministic")
    confirm.unlink()
    temporary.replace(path)
    verify(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="verify the committed file and do not download")
    parser.add_argument("--output", type=Path, default=OUTPUT, help="fastq.gz to write or check")
    args = parser.parse_args()
    if args.check:
        verify(args.output)
        return
    if args.output.is_file():
        try:
            verify(args.output)
            return
        except SystemExit as error:
            print(error, file=sys.stderr)
            print("Rebuilding from ENA.", file=sys.stderr)
    rebuild(args.output)


if __name__ == "__main__":
    main()

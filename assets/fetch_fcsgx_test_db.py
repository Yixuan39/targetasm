#!/usr/bin/env python3
"""Download NCBI's FCS-GX test-only database and check the published manifest.

This database only checks that FCS-GX starts and the pipeline can screen a
FASTA. Scientific contamination calls need the complete ``all`` database
(https://github.com/ncbi/fcs/wiki/FCS-GX-quickstart).

Files keep the ``test-only.*`` names from the manifest. Pass that directory
as ``--gx_db``. It is about 4.6 GB, almost all of it ``test-only.gxi``.
"""

import argparse
import hashlib
import subprocess
import sys
import urllib.request
from pathlib import Path

MANIFEST_URL = "https://ftp.ncbi.nlm.nih.gov/genomes/TOOLS/FCS/database/test-only/test-only.manifest"
BASE_URL = "https://ftp.ncbi.nlm.nih.gov/genomes/TOOLS/FCS/database/test-only/"

# name, size, md5 from test-only.manifest (timestamp 2022-11-03T10:09:52.740947)
FILES = (
    ("test-only.taxa.tsv", 6063, "6425dc690849872ea22f5072ed34688a"),
    ("test-only.meta.jsonl", 56, "e1db5eeb49f25ca0f0c1f2febf8ae177"),
    ("test-only.seq_info.tsv.gz", 21847, "c4dae6d238aae59fada93da721b6a254"),
    ("test-only.blast_div.tsv.gz", 8226897, "8b812feb689011a6211ca8011b2852ff"),
    ("test-only.gxs", 70841083, "08c43f619b107d406e0486d53f8732bb"),
    ("test-only.gxi", 4522535378, "d5bec998a22a36be04add0dd0a7776ae"),
)


def md5(path):
    digest = hashlib.md5()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def matches(path, size, digest):
    return path.is_file() and path.stat().st_size == size and md5(path) == digest


def download(url, path):
    temporary = path.with_suffix(path.suffix + ".partial")
    command = [
        "curl",
        "--fail",
        "--location",
        "--retry",
        "5",
        "--retry-delay",
        "2",
        "--continue-at",
        "-",
        "--output",
        str(temporary),
        url,
    ]
    subprocess.run(command, check=True)
    temporary.replace(path)


def fetch_manifest(directory):
    destination = directory / "test-only.manifest"
    request = urllib.request.Request(MANIFEST_URL, headers={"User-Agent": "targetasm-test-db"})
    with urllib.request.urlopen(request, timeout=120) as response:
        payload = response.read()
    destination.write_bytes(payload)
    return payload.decode()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("directory", type=Path, help="directory to create and fill, then pass to --gx_db")
    parser.add_argument("--check", action="store_true", help="verify an existing download and do not fetch files")
    args = parser.parse_args()
    directory = args.directory
    directory.mkdir(parents=True, exist_ok=True)
    if not args.check:
        manifest = fetch_manifest(directory)
        for name, _size, digest in FILES:
            if f'"{name}"' not in manifest or digest not in manifest:
                raise SystemExit(
                    f"{MANIFEST_URL} no longer lists {name} with md5 {digest}. "
                    "Refusing to save a database this pipeline has not pinned."
                )
    failed = False
    for name, size, digest in FILES:
        path = directory / name
        if matches(path, size, digest):
            print(f"ok  {path}")
            continue
        if args.check:
            print(f"BAD {path}", file=sys.stderr)
            failed = True
            continue
        print(f"get {name} ({size} bytes)")
        download(BASE_URL + name, path)
        if not matches(path, size, digest):
            raise SystemExit(f"{path} failed size or md5 check after download")
        print(f"ok  {path}")
    if failed:
        raise SystemExit(f"Database in {directory} does not match the pinned test-only manifest.")
    print(f"FCS-GX test-only database is ready: {directory.resolve()}")


if __name__ == "__main__":
    main()

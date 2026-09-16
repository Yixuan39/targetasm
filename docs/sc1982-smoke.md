# SC1982 functional validation

Run on 2026-09-13 from the `dev` working tree (`0.2.0dev`). This is a small
functional test of the pipeline, not an assembly-quality benchmark.

## Input and environment

The smallest raw FASTQ in `/Volumes/YY3/downy/GSL_Data/fastq/` was
`Pseudoperonospora_cubensis_SC1982.fastq.gz` (approximately 12 GB compressed).
The existing SC1982 assembly script uses tax ID `4762`.

Host rasusa **4.1.0** sampled **159,141 reads / 1,000,004,970 bases** with
seed **1982** and a 1 Gb target. The compressed subset's SHA-256 is
`b76dd5c3de1ab43f38d4e8aef9480493f217b6ec065f7fa520dbef20bccf0971`.
This initial sampling step is separate from the pipeline's pinned rasusa 2.2.2,
which subsamples recruited reads to 100 Mb during the test.

The run uses Nextflow 26.04.3, nf-schema 2.7.2, Docker 29.6.2, and the pinned
pipeline containers. On this Apple Silicon Mac, containers run as linux/amd64;
processes are limited to 4 CPUs and 6 GB, with one task at a time.

The production FCS-GX database was unavailable locally. The run therefore uses
[NCBI's official test-only database](https://ftp.ncbi.nlm.nih.gov/genomes/TOOLS/FCS/database/test-only/test-only.manifest).
All six files were checked against the manifest's sizes and MD5 hashes.
**This database does not establish whether SC1982 contamination is correctly
identified or removed.** Use the complete production database and representative
coverage for scientific validation.

QC was enabled for all four stages with the existing
`/Users/yixuanyang/db/compleasm/stramenopiles_odb12` (2025-07-01 dataset).
The library was copied to `runs/sc1982-smoke/compleasm-library`, avoiding a
whole-home Docker bind mount. Compleasm updates library metadata while it runs,
so the module stages the library by copy. The source copy's size and timestamps
were unchanged after all four QC runs.

## Reproduce on this machine

From the repository root:

```bash
mkdir -p runs/sc1982-smoke/input
rasusa reads --bases 1gb --seed 1982 \
    --output runs/sc1982-smoke/input/SC1982.fastq.gz \
    /Volumes/YY3/downy/GSL_Data/fastq/Pseudoperonospora_cubensis_SC1982.fastq.gz

nextflow -log runs/sc1982-smoke/nextflow.log run main.nf \
    -profile docker \
    -c runs/sc1982-smoke/local.config \
    -params-file runs/sc1982-smoke/params.json \
    -work-dir runs/sc1982-smoke/work -ansi-log false
```

`local.config` contains:

```groovy
process.resourceLimits = [cpus: 4, memory: 6.GB]
executor.queueSize = 1
docker.runOptions = '--platform linux/amd64'
```

`params.json` contains:

```json
{
  "reads": "runs/sc1982-smoke/input/SC1982.fastq.gz",
  "gx_db": "runs/sc1982-smoke/gxdb-test",
  "tax_id": 4762,
  "outdir": "runs/sc1982-smoke/results",
  "threads": 4,
  "target_bases": 100000000,
  "rasusa_seed": 1982,
  "hifiasm_option": "-l 2 -f 0",
  "keep_intermediates": true,
  "quality_library": "runs/sc1982-smoke/compleasm-library",
  "quality_lineage": "stramenopiles"
}
```

The database directory must contain the six verified files named in the linked
manifest. Full run artifacts, configs, input statistics, checksums, and
`provenance.json` are retained under `runs/sc1982-smoke/`, which is git-ignored.
The local Docker credential helper stalled during public image downloads, so
this run uses an empty, task-specific `DOCKER_CONFIG` and explicitly selects the
existing Docker socket; the user's Docker configuration was not changed.

## Code checks

- Parameter schema lint: valid, 12 parameters, no warnings.
- Nine pipeline/input-validation tests: passed, including all QC/subsampling
  combinations, fractional bases, missing lineage/files, and unknown parameters.
- CSV parser regression: passed, including preservation of Compleasm's `I` metric.
- Nextflow syntax: no errors, two style warnings for explicit single-output names.
- Full pipeline lint (nf-core/tools 3.5.2): 166 passed, 4 ignored, 29 warnings,
  56 failures. Remaining failures concern template/configuration conventions,
  nf-core organization naming, and test conventions; full nf-core compliance
  is not claimed. See [migration notes](module-migration.md).

## Actual run result

The resumed run completed all 27 tasks with exit code 0. The principal outputs
are:

| Stage | Contigs | Total bases | Compleasm single-copy | Notes |
| --- | ---: | ---: | ---: | --- |
| metaMDBG | 4,700 | 131,205,660 | 88.95% | 4,705 sequences before QUAST filtering |
| FCS-GX round 1 | 4,686 | 131,035,162 | 88.95% | Test DB excluded 14 sequences / 170,498 bases |
| hifiasm | 75 | 1,357,762 | 2.87% | Built from 100,000,256 recruited-read bases |
| FCS-GX round 2 | 75 | 1,357,762 | 2.87% | Test DB made no further exclusions |

The small final assembly and low final Compleasm score reflect the deliberately
tiny 100 Mb hifiasm input and are not a scientific assessment of SC1982. This run
only verifies data flow, container execution, filtering, publication, and report
generation. The final assembly is `results/SC1982.fasta.gz`; the four-stage table
is `results/quality/quality_trace.csv`.

The first hifiasm attempt used its default `-f 37` Bloom filter and was killed
by the 6 GB smoke-test limit (exit 137). Hifiasm documents that this filter
uses 16 GB initially and recommends `-f 0` for small genomes, so the functional
test disables it. The pipeline default remains unchanged for production runs.

The complete execution trace and pinned tool versions are under
`runs/sc1982-smoke/results/pipeline_info/`. Intermediate failed-attempt logs are
retained in the ignored run directory for diagnosis.

# Community module migration (0.2.0dev)

The analysis still follows metaMDBG → FCS-GX → read recruitment → optional
rasusa → hifiasm → FCS-GX, with optional Compleasm and QUAST at four stages.
The CLI still accepts one sample with `--reads`.

## Reused modules

Installed with `nf-core modules install`; each module's source commit is recorded
in [modules.json](../modules.json). The selected source tree is
[`56155f73713bc32c5343b59f05d968794c1b596d`](https://github.com/nf-core/modules/tree/56155f73713bc32c5343b59f05d968794c1b596d/modules/nf-core).
Module source files are kept unchanged. Pipeline flags, resources, publication
rules and the gfatools environment override are configured separately.

| Existing tool | Community module | Effective version change |
| --- | --- | --- |
| metaMDBG | `metamdbg/asm` | 1.2 → 1.4 |
| minimap2 | `minimap2/align` | 2.28 → 2.30; also uses samtools 1.23.1 |
| samtools read extraction | `samtools/bam2fq` | 1.22.1 → 1.24 |
| hifiasm | `hifiasm` | Remains 0.25.0 |
| gfatools | `gfatools/gfa2fa` | Remains 0.5.5 through a config override; upstream pins 0.5 |
| FCS-GX screening | `fcsgx/rungx` | Remains 0.5.5 |
| FCS-GX cleaning | `fcsgx/cleangenome` | Remains 0.5.5 |
| Compleasm | `compleasm/run` | 0.2.7 → 0.2.9 |
| QUAST | `quast` | Remains 5.3.0, with the upstream container build |
| Assembly decompression | `gunzip` | Uses the upstream pinned environment |
| Clean assembly compression | `htslib/bgziptabix` | HTSlib 1.24; BGZF output is gzip compatible |

`rasusa` remains local at 2.2.2: the community module currently wraps 0.3.0,
with a coverage/genome-size interface instead of `rasusa reads --bases`.
The local module has explicit inputs, a pinned environment, a stub, and version
reporting. Replace it when a compatible community module is available.
targetasm-specific CSV parsing and report merging also remain local.

## Behavior and operational changes

- Requires Nextflow 26.04 or newer. Tested with 26.04.3 and nf-test 0.9.4.
- `--gx_db` is the directory containing the complete database bundle, not a
  single database-prefix file. No database download or RAM-disk copy is added.
- `--target_bases 5e9` remains supported and is normalized to an integer.
- minimap2 emits name-sorted BAM instead of an intermediate SAM. Read extraction
  uses `-n -F 0x904`, preserving the original exclusion of unmapped, secondary and
  supplementary alignments. Sorting may change read order and therefore the
  exact reads selected by a seeded rasusa run. Assemblies are not promised to
  be byte-identical to 0.1.0.
- hifiasm still receives `--primary` and the configured options (default `-l 2`).
- Each FCS round explicitly decompresses before cleaning and compresses afterward.
  The final gzip-compatible assembly remains `<reads.simpleName>.fasta.gz`.
  Intermediate assemblies and FCS reports now include the sample name and stage.
- Compleasm and QUAST run independently, then join by metadata before parsing.
  The report parser accepts the legacy metrics and newer Compleasm comment
  headers, quotes CSV fields, and fails on incomplete or duplicate stage data.
  The `file` column now contains the actual final assembly filename, including
  `.fasta.gz`. Database/lineage compatibility must be checked when reusing older
  Compleasm libraries with 0.2.9. Compleasm may also check or update library
  metadata at runtime; targetasm stages the library by copy to protect the source,
  but fully air-gapped execution is not guaranteed by the tool.
- Tool version outputs and the execution trace are saved under `pipeline_info/`.
- Cluster-specific queue names were removed. Set the queue in a site config
  passed with `-c`; FCS screening still defaults to 500 GB, independently of
  executor and container profiles. Select a container profile explicitly, e.g.
  `-profile slurm,apptainer`.

## Checks

```bash
nextflow lint main.nf workflows subworkflows/local modules/local conf nextflow.config
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tests/run_stub.py

# Real module checks using installed samtools/bgzip and QUAST, respectively:
nf-test test tests/filter.nf.test --ci
nf-test test tests/quast.nf.test --ci
```

`run_stub.py` supplies temporary input files, version-only tool stand-ins and a
gzip-compatible compressor for stub outputs. It tests the four combinations of
QC/subsampling, publication and early input rejection. These are orchestration
tests, not assembly or contamination-screening benchmarks. The vendor tests
reference additional upstream test dependencies such as `fcsgx/fetchdb`; those
tests are not the pipeline smoke suite and may generate discovery warnings.

The SC1982 1 Gb subset completed all 27 real container tasks: metaMDBG, both
FCS-GX rounds, minimap2/samtools recruitment, pipeline rasusa subsampling,
hifiasm/gfatools, four Compleasm/QUAST checks, and final report merging. The
official test-only FCS database verifies execution only; production-database
and full-coverage scientific validation remain incomplete.
The existing 0.1.0 release remains the reference for the original implementation.

Local validation: nine pipeline/input-validation tests and the CSV parser test
passed; real read filtering and QUAST smoke tests passed with host samtools
1.23.1 and QUAST 5.2.0. Those host checks do not validate the pinned container
versions. Community module lint (nf-core/tools 3.5.2) passed 461 checks with no
failures and 15 warnings about newer tool versions and container-link/version
checks. Local module lint had no failures and nine advisory warnings about
flat local-module metadata/environment layout and container checks. Nextflow
lint had no errors and two style warnings about named single outputs, which
are retained for explicit workflow interfaces. CI is configured but has not
run on GitHub yet.

This migration does not by itself establish complete nf-core pipeline compliance.
The parameter schema is now implemented with `nf-schema@2.7.2`, including
runtime validation and generated help. Template synchronization, samplesheet
input and its schema, local module/subworkflow metadata, and scientific
regression data remain separate work before submission. Full pipeline lint
runs but does not pass: it also expects nf-core organization branding and
boilerplate, while this project remains `Yixuan39/targetasm`. Some checks in
the installed nf-core/tools 3.5.2 still expect legacy `versions.yml` outputs
rather than the topic-based version reporting used by current modules.
See [SC1982 smoke validation](sc1982-smoke.md) for the small real-data run.

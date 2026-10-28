# Changelog

All notable changes to `targetasm` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - Unreleased

### Changed
- `--input` samplesheet (`sample,reads,target_bases`) replaces `--reads`, so one
  run can assemble several samples; `target_bases` can be set per sample.
- Reads may be uncompressed (`.fastq`/`.fq`) as well as gzipped.
- QC reports are written per sample as `quality/<sample>.quality_trace.csv` and
  `quality/<sample>.quality_final.csv`.
- Compleasm 0.2.10 replaces the nf-core module's 0.2.9, which crashed on compute
  nodes without internet even with a local library.
- Release tags no longer use a `v` prefix, so `nextflow run Yixuan39/targetasm -r 0.2.1` works.

### Added
- Time limits for every process (4 h, 8 h or 48 h by label), and one retry with
  twice the time after a scheduler kill.
- Inside a SLURM job, the local executor only uses the job's memory allocation.
- Clearer validation messages for `--gx_db` (including the 0.1.0 file prefix),
  `--target_bases`, `--quality_lineage` and samplesheet entries.
- Database download pointers and per-thread memory in `--help` and the README.

### Fixed
- `--help` no longer writes `pipeline_info/` to the current directory.

## [0.2.0] - 2026-10-09

### Changed
- Rebuilt the workflow on 11 pinned nf-core modules; see
  `docs/module-migration.md` for tool version changes.
- `--gx_db` now takes the FCS-GX database directory instead of a file prefix.
- Parameters are validated with `nf-schema` against `nextflow_schema.json`.
- Requires Nextflow 26.04 or newer.

### Added
- `conda` profile and `pipeline_info/` software versions and execution trace.
- nf-test stub tests and GitHub Actions CI.
- `test` profile for a small functional run on a laptop (supply `--reads` and `--gx_db`).

### Removed
- `--fcs_gx_memory`; override `FCSGX_RUNGX` memory with a `-c` config.

## [0.1.0] - 2026-09-06

Initial tagged release. `targetasm` is a Nextflow DSL2 workflow for recovering
a target eukaryotic genome from a contaminated PacBio HiFi read set.

### Added
- Reference-independent recovery pipeline: `metaMDBG` metagenome assembly →
  `FCS-GX` contaminant removal → `minimap2`/`samtools` read recruitment →
  optional `rasusa` downsampling → `hifiasm` reassembly → final `FCS-GX` screen.
- Optional `Compleasm` and `QUAST` quality reporting across assembly stages,
  plus a standalone FASTA QC table workflow (`run_fasta_quality_table.nf`).
- Container definitions (Biocontainers) pinned per process in `nextflow.config`
  for reproducible execution under Docker, Singularity, or Apptainer.
- `standard` and `slurm` executor profiles.
- MIT License.
- `manifest` block in `nextflow.config` recording pipeline name, description,
  and version, enabling `-r <tag>` pinning when run directly from GitHub.

### Notes
- Benchmarked on contaminated PacBio HiFi sequencing of obligate biotrophic
  oomycetes; not oomycete-specific — any target with an NCBI taxonomy ID
  usable by FCS-GX is supported.

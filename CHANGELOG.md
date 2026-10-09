# Changelog

All notable changes to `targetasm` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 0.2.0dev

### Changed
- Rebuilt the workflow on 11 pinned nf-core modules; see
  `docs/module-migration.md` for tool version changes.
- `--gx_db` now takes the FCS-GX database directory instead of a file prefix.
- Parameters are validated with `nf-schema` against `nextflow_schema.json`.
- Requires Nextflow 26.04 or newer.

### Added
- `conda` profile and `pipeline_info/` software versions and execution trace.
- nf-test stub tests and GitHub Actions CI.

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

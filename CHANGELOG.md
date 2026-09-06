# Changelog

All notable changes to `targetasm` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

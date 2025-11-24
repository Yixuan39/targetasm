# patho-asm

## Introduction

`patho-asm` is a modular Nextflow pipeline that assembles and polishes plant pathogen genomes starting from high-quality long-read data. The workflow chains together metaMDBG for the initial draft assembly, two rounds of NCBI FCS-GX decontamination, read mapping, optional rasusa-based downsampling, and a final HiFiasm re-assembly to deliver a curated genome suitable for downstream analysis or publication.

## Workflow Overview

1. **metamdbg_assemble** – Builds an initial draft assembly from the supplied HiFi reads.
2. **fcs_gx_clean (round 1)** – Screens the draft assembly against the configured GX database and removes contaminants.
3. **minimap2_align** – Maps the original reads back to the cleaned draft to retain only well-supported sequences.
4. **rasusa_subset** – Optionally downsamples mapped reads to the requested number of bases (passes the full set through if not specified).
5. **hifiasm_reassemble** – Re-assembles the filtered reads to improve structural accuracy.
6. **fcs_gx_clean (round 2)** – Performs a final contamination screen on the polished assembly to generate the release-ready genome.

## Workflow DAG

```mermaid
graph TD
	RAW[Raw HiFi reads] --> MDBG[metamdbg assemble]
	MDBG --> FCS1[fcs-gx clean (round 1)]
	FCS1 --> MM[minimap2 align]
	RAW --> MM
	MM --> RAS[rasusa subset]
	RAS --> HIFI[hifiasm reassemble]
	HIFI --> FCS2[fcs-gx clean (round 2)]
```

## Quick Start

```bash
nextflow run main.nf \
	--reads /path/to/sample.fastq.gz \
	--gx_db /path/to/gx-db-prefix \
	--tax_id 4762 \
	--rasusa_bases 5e9 \
	--outdir results \
	-profile conda
```

Adjust `params.hifiasm_option`, `params.threads`, or other parameters in your Nextflow config to tailor the run to your system and samples.

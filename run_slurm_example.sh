#!/bin/bash
set -euo pipefail

# Example execution of the TEA pipeline on Slurm with all critical parameters specified.
# Adjust the paths below to match your environment before running.

nextflow run main.nf \
    -profile slurm \
    -resume \
    --reads "${HOME}/project_data/downy/GSL_Data/fastq/filtered/Quesada_SQIIe_SC1982.fastq.gz" \
    --outdir "${HOME}/test" \
    --gx_db "${HOME}/project_data/downy/fcs-db" \
    --tax_id 4762 \
    --rasusa_bases 2500000000 \
    --threads 24 \
    --quality_library "${HOME}/project_data/downy/Compleasm_DB" \
    --quality_lineage stramenopiles

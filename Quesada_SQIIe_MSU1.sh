#!/bin/bash
set -euo pipefail

nextflow run ${HOME}/software/TEA/main.nf \
    -profile slurm \
    -resume \
    --reads "${HOME}/project_data/downy/GSL_Data/fastq/filtered/Quesada_SQIIe_MSU1.fastq.gz" \
    --outdir "${HOME}/project_data/downy/results/Quesada_SQIIe_MSU1" \
    --gx_db "${HOME}/project_data/downy/fcs-db" \
    --tax_id 4762 \
    --rasusa_bases 5400000000 \
    --threads 24 \
    --quality_library "${HOME}/project_data/downy/BUSCO_DB" \
    --quality_lineage stramenopiles
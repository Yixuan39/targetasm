#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/*
 * Standalone FASTA QC table helper.
 *
 * This helper is intentionally separate from modules/quality_check.nf.
 * The TEA quality_check module tracks multiple assembly steps and writes
 * quality_trace.csv plus quality_final.csv for the full TEA workflow.
 *
 * This helper is for already-generated FASTA files only. It runs Compleasm
 * and QUAST for each input FASTA, then merges all samples into one table:
 *
 *   <output.tsv>
 */

params.fasta = null
params.output = 'quality.tsv'
params.quality_library = null
params.quality_lineage = null
params.threads = 24
params.memory = '16 GB'
params.help = false

process HELPER_COMPLEASM_RUN {
    tag "compleasm: ${sample}"
    cpus params.threads
    memory params.memory
    container 'quay.io/biocontainers/compleasm:0.2.7--pyh7e72e81_1'

    input:
    tuple val(sample), path(assembly), path(library_path), val(lineage)

    output:
    tuple val(sample), path(assembly), path("compleasm_out"), emit: compleasm_result

    script:
    """
    compleasm run \\
      --assembly_path ${assembly} \\
      --output_dir compleasm_out \\
      --threads ${task.cpus} \\
      --library_path ${library_path} \\
      --lineage ${lineage}
    """
}

process HELPER_QUAST_RUN {
    tag "quast: ${sample}"
    cpus params.threads
    memory params.memory
    container 'quay.io/biocontainers/quast:5.3.0--py313pl5321h5ca1c30_2'

    input:
    tuple val(sample), path(assembly), path(compleasm_out)

    output:
    tuple val(sample), path("${sample}_metrics.csv"), emit: metrics

    script:
    """
    set -euo pipefail

    quast \\
      --output-dir quast_out \\
      --threads ${task.cpus} \\
      --eukaryote ${assembly}

    compleasm_headers=\$(awk -F: 'NR>1 {printf "%s%s", sep, \$1; sep=","}' ${compleasm_out}/summary.txt)
    compleasm_values=\$(awk -F: 'NR>1 {gsub(/^[ \\t]+/, "", \$2); split(\$2, a, ","); printf "%s%s", sep, a[1]; sep=","}' ${compleasm_out}/summary.txt)

    quast_headers=\$(awk -F'\\t' 'NR>1 {printf "%s%s", sep, \$1; sep=","}' quast_out/report.tsv)
    quast_values=\$(awk -F'\\t' 'NR>1 {printf "%s%s", sep, \$2; sep=","}' quast_out/report.tsv)

    echo "file,\${compleasm_headers},\${quast_headers}" > ${sample}_metrics.csv
    echo "${sample},\${compleasm_values},\${quast_values}" >> ${sample}_metrics.csv
    """
}

process MERGE_FASTA_QC_TABLE {
    tag "write quality table"
    publishDir {
        params.output.toString().contains('/') ? params.output.toString().substring(0, params.output.toString().lastIndexOf('/')) : '.'
    }, mode: 'copy', saveAs: {
        params.output.toString().contains('/') ? params.output.toString().substring(params.output.toString().lastIndexOf('/') + 1) : params.output.toString()
    }
    cpus 1
    memory '1 GB'
    container 'ubuntu:22.04'

    input:
    path metrics_files

    output:
    path "quality.tsv", emit: report

    script:
    """
    set -euo pipefail

    first=1
    for f in *_metrics.csv; do
      if [ "\$first" -eq 1 ]; then
        sed 's/,/\\t/g' "\$f" > quality.tsv
        first=0
      else
        tail -n +2 "\$f" | sed 's/,/\\t/g' >> quality.tsv
      fi
    done
    """
}

workflow {
    if (params.help) {
        log.info """
Standalone FASTA QC table helper.

Usage:
  nextflow run run_fasta_quality_table.nf \\
    --fasta '/path/to/*.fasta.gz' \\
    --output quality.tsv \\
    --quality_library /path/to/BUSCO_DB \\
    --quality_lineage <lineage> \\
    --threads 24 \\
    --memory '16 GB'

Outputs:
  <output.tsv>
"""
        exit 0
    }

    if (!params.fasta) {
        error "Parameter --fasta is required"
    }
    if (!params.quality_library) {
        error "Parameter --quality_library is required"
    }
    if (!params.quality_lineage) {
        error "Parameter --quality_lineage is required"
    }

    def quality_lib_path = file(params.quality_library)

    Channel
        .fromPath(params.fasta)
        .ifEmpty { error "No FASTA files matched: ${params.fasta}" }
        .map { fasta ->
            def sample = fasta.name.replaceFirst(/\.(fa|fna|fasta)(\.gz)?$/, '')
            tuple(sample, fasta, quality_lib_path, params.quality_lineage)
        }
        .set { fasta_ch }

    HELPER_COMPLEASM_RUN(fasta_ch)
    HELPER_QUAST_RUN(HELPER_COMPLEASM_RUN.out.compleasm_result)
    MERGE_FASTA_QC_TABLE(HELPER_QUAST_RUN.out.metrics.map { sample, metrics -> metrics }.collect())
}

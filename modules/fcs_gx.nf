nextflow.enable.dsl=2

process fcs_gx_clean {
    tag "fcs-gx clean: ${assembly.simpleName}"
    publishDir "${params.outdir}/fcs_gx", mode: 'copy'
    cpus params.threads
    memory '512 GB'
    conda "bioconda::ncbi-fcs-gx=0.5.5"

    input:
    path assembly
    path gx_db
    val tax_id

    output:
    path "fcs_gx.clean.fasta", emit: clean_fasta
    path "fcs_gx.fcs_gx_report.txt", emit: report

    script:
    """
    set -euo pipefail
    export GX_NUM_CORES=${task.cpus}

    tmp_dir=$(mktemp -d)
    trap 'rm -rf \${tmp_dir}' EXIT

    # 1. Run screening (writes report files inside the temp dir)
    run_gx.py \
        --fasta ${assembly} \
        --tax-id ${tax_id} \
        --gx-db ${gx_db} \
        --out-dir \${tmp_dir} \
        --out-basename fcs_gx

    # 2. Clean genome using the generated report
    gx clean-genome \
        --input ${assembly} \
        --action-report \${tmp_dir}/fcs_gx.fcs_gx_report.txt \
        --output fcs_gx.clean.fasta

    # 3. Collect outputs in the work directory
    mv \${tmp_dir}/fcs_gx.fcs_gx_report.txt fcs_gx.fcs_gx_report.txt
    """
}

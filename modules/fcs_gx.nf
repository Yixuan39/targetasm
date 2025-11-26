nextflow.enable.dsl=2

process fcs_gx_clean {
    tag "fcs-gx clean: ${assembly.simpleName}"
    publishDir "${params.outdir}/fcs_gx", mode: 'copy'
    cpus params.threads

    input:
    tuple path(assembly), path(gx_db), val(tax_id), val(output_base)

    output:
    path "${output_base}.fasta.gz", emit: gz_fasta
    path "${output_base}.fcs_gx_report.txt", emit: report

    script:

    """
    set -euo pipefail
    export GX_NUM_CORES=${task.cpus}

    # 1. Run screening (writes report files into the work directory)
    run_gx.py \
        --fasta ${assembly} \
        --tax-id ${tax_id} \
        --gx-db ${gx_db} \
        --out-dir . \
        --out-basename ${output_base}

    # 2. Clean genome using the generated report
    gx clean-genome \
        --input ${assembly} \
        --action-report "${output_base}.fcs_gx_report.txt" \
        --output ${output_base}.clean.fasta

    pigz -p ${task.cpus} ${output_base}.clean.fasta > ${output_base}.fasta.gz
    """
}

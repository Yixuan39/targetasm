nextflow.enable.dsl=2

process fcs_gx_clean {
    tag "fcs-gx clean: ${assembly.simpleName}"
    publishDir "${params.outdir}/fcs_gx", mode: 'copy', pattern: "*.fasta.gz", enabled: params.keep_intermediates
    publishDir "${params.outdir}/fcs_gx", mode: 'copy', pattern: "*.fcs_gx_report.txt"
    cpus params.threads
    container 'quay.io/biocontainers/ncbi-fcs-gx:0.5.5--h9948957_0'

    input:
    tuple path(assembly), path(gx_db), val(tax_id), val(output_base)

    output:
    path "${output_base}.fasta.gz", emit: clean_fasta
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

    # 2. Clean genome (gx clean-genome requires uncompressed input)
    gzip -dkc ${assembly} > input.fasta
    gx clean-genome \
        --input input.fasta \
        --action-report "${output_base}.fcs_gx_report.txt" \
        --output output.fasta
    
    gzip -c output.fasta > ${output_base}.fasta.gz
    """
}

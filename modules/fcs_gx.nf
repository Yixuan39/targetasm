nextflow.enable.dsl=2

process fcs_gx_clean {
    tag "fcs-gx clean: ${assembly.simpleName}"
    publishDir "${params.outdir}/fcs_gx", mode: 'copy'
    cpus params.threads
    memory '512 GB'

    input:
    tuple path(assembly), path(gx_db), val(tax_id), val(output_name)

    output:
    path output_name, emit: clean_fasta
    path "${output_name}.fcs_gx_report.txt", emit: report

    script:
    def output_prefix = output_name.replaceFirst(/(\.f(ast|a|na)(\.gz)?)$/, '') ?: output_name
    def report_name = "${output_name}.fcs_gx_report.txt"
    """
    set -euo pipefail
    export GX_NUM_CORES=${task.cpus}

    # 1. Run screening (writes report files into the work directory)
    run_gx.py \
        --fasta ${assembly} \
        --tax-id ${tax_id} \
        --gx-db ${gx_db} \
        --out-dir . \
        --out-basename ${output_prefix}

    # 2. Clean genome using the generated report
    gx clean-genome \
        --input ${assembly} \
        --action-report ${report_name} \
        --output ${output_name}.fasta
    pigz -p ${task.cpus} ${output_name}.fasta
    """
}

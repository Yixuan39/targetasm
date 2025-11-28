nextflow.enable.dsl=2

process rasusa_subset {
    tag "rasusa subset: ${reads.simpleName} (${bases} bases)"
    publishDir "${params.outdir}/rasusa", mode: 'copy', enabled: params.keep_intermediates
    cpus 1
    memory "${params.threads * 8} GB"

    input:
    tuple path(reads), val(bases)

    output:
    path "subset.fastq.gz", emit: subset_reads

    script:
    def seedOption = params.rasusa_seed ? "--seed ${params.rasusa_seed}" : ""
    """
    set -euo pipefail

    rasusa reads \
        --bases ${bases} \
        ${seedOption} \
        --output-type g \
        --output subset.fastq.gz \
        ${reads}
    """
}

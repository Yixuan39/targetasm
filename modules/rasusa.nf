nextflow.enable.dsl=2

process rasusa_subset {
    tag "rasusa subset: ${reads.simpleName} (${bases} bases)"
    publishDir "${params.outdir}/rasusa", mode: 'copy'
    cpus 1
    memory "${params.threads * 8} GB"

    input:
    tuple path(reads), val(bases)

    output:
    path "subset.fastq.gz", emit: subset_reads

    script:
    """
    set -euo pipefail

    rasusa reads \
        --bases ${bases} \
        --seed ${params.rasusa_seed} \
        --output-type g \
        --output subset.fastq.gz \
        ${reads}
    """
}

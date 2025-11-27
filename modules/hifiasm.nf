nextflow.enable.dsl=2

process hifiasm_reassemble {
    tag "hifiasm reassemble: ${reads.simpleName}"
    publishDir "${params.outdir}/hifiasm", mode: 'copy'
    cpus params.threads
    memory "${params.threads * 8} GB"

    input:
    path reads

    output:
    path "assembly.fasta.gz", emit: assembly

    script:
    """
    set -euo pipefail

    hifiasm \
        -t ${task.cpus} \
        ${params.hifiasm_option} \
        --primary \
        -o asm \
        ${reads}

    gfatools gfa2fa asm.p_ctg.gfa \
        | pigz -p ${task.cpus} > assembly.fasta.gz
    """
}

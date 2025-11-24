nextflow.enable.dsl=2

process hifiasm_reassemble {
    tag "hifiasm reassemble: ${reads.simpleName}"
    publishDir "${params.outdir}/hifiasm", mode: 'copy'
    cpus params.threads
    memory "${params.threads * 8} GB"
    conda "bioconda::hifiasm=0.25.0 bioconda::gfatools=0.5 conda-forge::pigz=2.8"

    input:
    path reads

    output:
    path "${reads.simpleName}.fasta.gz", emit: assembly

    script:
    """
    set -euo pipefail

    hifiasm \
        -t ${task.cpus} \
        ${params.hifiasm_option ?: '-l 1'} \
        --primary \
        -o asm \
        ${reads}

    gfatools gfa2fa asm.p_ctg.gfa \
        | pigz -p ${task.cpus} > ${reads.simpleName}.fasta.gz
    """
}

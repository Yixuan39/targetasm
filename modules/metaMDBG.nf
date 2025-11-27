nextflow.enable.dsl=2

process metamdbg_assemble {
    tag "metamdbg assemble: ${reads.simpleName}"
    publishDir "${params.outdir}/metaMDBG", mode: 'copy', enabled: params.keep_intermediates
    cpus params.threads
    memory "${params.threads * 8} GB"

    input:
    path reads

    output:
    path "MAGs.fasta.gz", emit: assembly

    script:
    """
    metaMDBG asm \
        --out-dir . \
        --in-hifi ${reads} \
        --threads ${task.cpus}

    mv contigs.fasta.gz MAGs.fasta.gz
    """
}
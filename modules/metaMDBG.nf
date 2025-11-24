nextflow.enable.dsl=2

process metamdbg_assemble {
    tag "metamdbg assemble: ${reads.simpleName}"
    publishDir "${params.outdir}/metaMDBG", mode: 'copy'
    cpus params.threads
    memory "${params.threads * 8} GB"
    conda "bioconda::metamdbg=1.2"

    input:
    path reads

    output:
    path "${reads.simpleName}.fasta.gz", emit: assembly

    script:
    """
    metaMDBG asm \
        --out-dir metaMDBG_out \
        --in-hifi ${reads} \
        --threads ${task.cpus}

    mv metaMDBG_out/contigs.fasta.gz ${reads.simpleName}.fasta.gz
    """
}
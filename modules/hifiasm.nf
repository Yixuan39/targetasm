nextflow.enable.dsl=2

process hifiasm_run {
    tag "hifiasm run: ${reads.simpleName}"
    cpus params.threads
    memory "${params.threads * 8} GB"

    input:
    path reads

    output:
    path "asm.p_ctg.gfa", emit: gfa

    script:
    """
    set -euo pipefail

    hifiasm \
        -t ${task.cpus} \
        ${params.hifiasm_option} \
        --primary \
        -o asm \
        ${reads}
    """
}

process gfatools_convert {
    tag "gfatools convert & compress"
    publishDir "${params.outdir}/hifiasm", mode: 'copy', enabled: params.keep_intermediates
    cpus 1
    memory "4 GB"

    input:
    path gfa

    output:
    path "assembly.fasta.gz", emit: gzipped

    script:
    """
    set -euo pipefail
    gfatools gfa2fa ${gfa} | gzip -c > assembly.fasta.gz
    """
}

workflow hifiasm_reassemble {
    take:
    reads

    main:
    hifiasm_run(reads)
    gfatools_convert(hifiasm_run.out.gfa)

    emit:
    assembly = gfatools_convert.out.gzipped
}

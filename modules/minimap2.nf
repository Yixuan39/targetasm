nextflow.enable.dsl=2

process minimap2_run {
    tag "minimap2 map: ${draft_assembly.simpleName}"
    cpus params.threads
    memory "${params.threads * 8} GB"

    input:
    tuple path(draft_assembly), path(raw_reads)

    output:
    path "mapped.sam", emit: sam

    script:
    """
    minimap2 -ax map-hifi --secondary=no -t ${task.cpus} ${draft_assembly} ${raw_reads} -o mapped.sam
    """
}

process samtools_filter {
    tag "samtools filter & compress"
    publishDir "${params.outdir}/minimap2", mode: 'copy', enabled: params.keep_intermediates
    cpus params.threads
    memory "8 GB"

    input:
    path sam

    output:
    path "mapped.fastq.gz", emit: gzipped

    script:
    """
    set -euo pipefail
    samtools view -b -F 0x4 ${sam} | samtools fastq -n - | gzip -c > mapped.fastq.gz
    """
}

workflow minimap2_align {
    take:
    inputs

    main:
    minimap2_run(inputs)
    samtools_filter(minimap2_run.out.sam)

    emit:
    mapped_reads = samtools_filter.out.gzipped
}

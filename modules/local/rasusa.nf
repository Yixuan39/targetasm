// nf-core/rasusa still wraps 0.3.0; retain the current reads --bases interface.
process RASUSA_READS {
    tag "${meta.id}"
    label 'process_single'
    conda "${moduleDir}/rasusa.yml"
    container 'quay.io/biocontainers/rasusa:2.2.2--hc1c3326_0'

    input:
    tuple val(meta), path(fastq)
    val bases
    val seed

    output:
    tuple val(meta), path("${meta.id}.subset.fastq.gz"), emit: reads
    tuple val("${task.process}"), val('rasusa'), eval("rasusa --version | sed 's/rasusa //'"), emit: versions_rasusa, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    rasusa reads \\
        ${args} \\
        --bases ${bases} \\
        --seed ${seed} \\
        --output-type g \\
        --output ${meta.id}.subset.fastq.gz \\
        ${fastq}
    """

    stub:
    """
    echo '' | gzip > ${meta.id}.subset.fastq.gz
    """
}

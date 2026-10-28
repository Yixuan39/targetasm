process COLLECT_QUALITY_METRICS {
    tag "${meta.id}"
    label 'process_single'
    conda "${moduleDir}/python.yml"
    container 'python:3.12.12'

    input:
    tuple val(meta), path(compleasm), path(quast)

    output:
    tuple val(meta), path("${meta.stage}_metrics.csv"), emit: metrics
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    collect_quality.py metrics '${meta.stage}' '${compleasm}' '${quast}'
    """

    stub:
    """
    printf 'Step,stub\n${meta.stage},true\n' > ${meta.stage}_metrics.csv
    """
}

process MERGE_QUALITY_REPORTS {
    tag "${sample}"
    label 'process_single'
    conda "${moduleDir}/python.yml"
    container 'python:3.12.12'

    input:
    tuple val(sample), path(metrics)

    output:
    path "${sample}.quality_trace.csv", emit: trace
    path "${sample}.quality_final.csv", emit: final_report
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    collect_quality.py merge '${sample}.fasta.gz' ${metrics}
    mv quality_trace.csv ${sample}.quality_trace.csv
    mv quality_final.csv ${sample}.quality_final.csv
    """

    stub:
    """
    collect_quality.py merge '${sample}.fasta.gz' ${metrics}
    mv quality_trace.csv ${sample}.quality_trace.csv
    mv quality_final.csv ${sample}.quality_final.csv
    """
}

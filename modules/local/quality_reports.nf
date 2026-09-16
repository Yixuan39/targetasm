process COLLECT_QUALITY_METRICS {
    tag "${meta.id}"
    label 'process_single'
    conda "${moduleDir}/python.yml"
    container 'python:3.12.12'

    input:
    tuple val(meta), path(compleasm), path(quast)

    output:
    path "${meta.stage}_metrics.csv", emit: metrics
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
    label 'process_single'
    conda "${moduleDir}/python.yml"
    container 'python:3.12.12'

    input:
    path metrics
    val assembly_name

    output:
    path 'quality_trace.csv', emit: trace
    path 'quality_final.csv', emit: final_report
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //'"), emit: versions_python, topic: versions

    script:
    """
    collect_quality.py merge '${assembly_name}' ${metrics}
    """

    stub:
    """
    collect_quality.py merge '${assembly_name}' ${metrics}
    """
}

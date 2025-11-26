nextflow.enable.dsl=2

process quality_check {
    tag "quality check"
    publishDir "${params.outdir}/quality", mode: 'copy'
    cpus params.threads
    memory '32 GB'

    input:
    tuple val(manifest_entries), val(library_path), val(lineage)

    output:
    path "quality_metrics.tsv", emit: metrics

    script:
    if (!(manifest_entries instanceof List) || manifest_entries.isEmpty()) {
        throw new IllegalArgumentException("quality_check requires a non-empty list of manifest entries")
    }

    def normalized_entries = manifest_entries.collect { entry ->
        if (!(entry instanceof List || entry instanceof nextflow.util.Tuple) || entry.size() < 2) {
            throw new IllegalArgumentException("Each manifest entry must be a [label, path] pair; received: ${entry}")
        }
        [entry[0].toString(), entry[1].toString()]
    }

    def copyCommands = []
    normalized_entries.eachWithIndex { entry, idx ->
        def label = entry[0].replaceAll(/[^A-Za-z0-9_.-]/, '_')
        def source = entry[1]
        def sourceName = new File(source).name
        def dest = "${String.format('%02d', idx)}_${label}_${sourceName}"
        copyCommands << ["cp \"${source}\" \"${dest}\"", "${entry[0]}\t${dest}"]
    }
    def copyScript = copyCommands.collect { cmd -> cmd[0] }.join('\n')
    def manifestContent = copyCommands.collect { cmd -> cmd[1] }.join('\n') + '\n'
    """
    set -euo pipefail
    ${copyScript}
    cat <<'EOF' > assemblies.tsv
    ${manifestContent}
    EOF

    QUALITY_MANIFEST=assemblies.tsv \
    QUALITY_OUTPUT=quality_metrics.tsv \
    QUALITY_THREADS=${task.cpus} \
    QUALITY_LIBRARY="${library_path}" \
    QUALITY_LINEAGE="${lineage}" \
    python bin/quality-check.py
    """
}

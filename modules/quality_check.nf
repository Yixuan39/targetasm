nextflow.enable.dsl=2

process quality_check {
    tag "quality check"
    publishDir "${params.outdir}/quality", mode: 'copy'
    cpus params.threads
    memory "${params.threads * 8} GB"

    input:
    tuple val(manifest_entries), val(library_path), val(lineage)

    output:
    path "quality_metrics.tsv", emit: metrics

    script:
    if (!(manifest_entries instanceof List) || manifest_entries.isEmpty()) {
        throw new IllegalArgumentException("quality_check requires a non-empty list of manifest entries")
    }

    def normalized_entries = manifest_entries.collect { entry ->
        if (!(entry instanceof List) || entry.size() < 2) {
            throw new IllegalArgumentException("Each manifest entry must be a [label, path] pair; received: ${entry}")
        }
        [entry[0].toString(), entry[1].toString()]
    }

    def manifestContent = normalized_entries.collect { entry -> "${entry[0]}\t${entry[1]}" }.join('\n') + '\n'
    """
    set -euo pipefail
    cat <<'EOF' > assemblies.tsv
    ${manifestContent}
    EOF

    while read line || [[ -n "\${line}" ]]; do
        [[ -z "\${line}" ]] && continue

        label="\${line%%$'\t'*}"
        source="\${line#*$'\t'}"

        compleasm run \
            --assembly_path "\${source}" \
            --output_dir "compleasm_\${label}" \
            --threads ${task.cpus} \
            --library_path "${library_path}" \
            --lineage "${lineage}"

        quast \
            --output-dir "quast_\${label}" \
            --threads ${task.cpus} \
            --eukaryote "\${source}"

        python bin/quality_merge.py "\${label}" "\${source}" "." row.tsv

        if [[ ! -f quality_metrics.tsv ]]; then
            cat row.tsv > quality_metrics.tsv
        else
            tail -n +2 row.tsv >> quality_metrics.tsv
        fi
    done < assemblies.tsv
    """
}

nextflow.enable.dsl=2

process quality_check {
    tag "quality check: ${label}"
    publishDir "${params.outdir}/quality", mode: 'copy'
    cpus params.threads
    memory "${params.threads * 8} GB"

    input:
    tuple val(label), val(step_name), path(assembly), val(library_path), val(lineage), val(is_final)

    output:
    path "${label}_metrics.tsv", emit: metrics
    path "${assembly.simpleName}_final.tsv", optional: true, emit: final_metrics

    script:
    """
    set -euo pipefail

    compleasm run \
        --assembly_path ${assembly} \
        --output_dir compleasm_out \
        --threads ${task.cpus} \
        --library_path ${library_path} \
        --lineage ${lineage}

    quast \
        --output-dir quast_out \
        --threads ${task.cpus} \
        --eukaryote ${assembly}

    # Parse compleasm summary and quast report into TSV
    echo -e "Step\\tAssembly\\t\$(tail -n +2 compleasm_out/summary.txt | cut -d: -f1 | tr '\\n' '\\t' | sed 's/\\t\$//')\\t\$(head -1 quast_out/report.tsv)" > ${label}_metrics.tsv
    echo -e "${step_name}\\t${assembly}\\t\$(tail -n +2 compleasm_out/summary.txt | cut -d: -f2 | tr '\\n' '\\t' | sed 's/\\t\$//')\\t\$(tail -1 quast_out/report.tsv)" >> ${label}_metrics.tsv

    # Generate final assembly metrics file if this is the final step
    if [ "${is_final}" = "true" ]; then
        echo -e "Step\\tAssembly\\t\$(tail -n +2 compleasm_out/summary.txt | cut -d: -f1 | tr '\\n' '\\t' | sed 's/\\t\$//')\\t\$(head -1 quast_out/report.tsv)" > ${assembly.simpleName}_final.tsv
        echo -e "${assembly.simpleName}\\t${assembly}\\t\$(tail -n +2 compleasm_out/summary.txt | cut -d: -f2 | tr '\\n' '\\t' | sed 's/\\t\$//')\\t\$(tail -1 quast_out/report.tsv)" >> ${assembly.simpleName}_final.tsv
    fi
    """
}

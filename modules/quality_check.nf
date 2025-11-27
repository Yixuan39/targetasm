nextflow.enable.dsl=2

process quality_check {
    tag "quality check: ${label}"
    cpus params.threads
    memory "${params.threads * 8} GB"

    input:
    tuple val(label), val(step_name), path(assembly), val(library_path), val(lineage), val(is_final)

    output:
    path "${label}_metrics.tsv", emit: metrics

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

    # Extract compleasm percentages (e.g., "95.2%" from "S:95.2%, 123")
    compleasm_headers=\$(awk -F: 'NR>1 {printf "%s%s", sep, \$1; sep="\t"} END {print ""}' compleasm_out/summary.txt)
    compleasm_values=\$(awk -F: 'NR>1 {gsub(/^[ \t]+/, "", \$2); split(\$2, a, ","); printf "%s%s", sep, a[1]; sep="\t"} END {print ""}' compleasm_out/summary.txt)

    # Extract full quast report (transpose: metric names as header, values as row)
    quast_headers=\$(awk -F'\t' '{printf "%s%s", sep, \$1; sep="\t"} END {print ""}' quast_out/report.tsv)
    quast_values=\$(awk -F'\t' '{printf "%s%s", sep, \$2; sep="\t"} END {print ""}' quast_out/report.tsv)

    # Write metrics TSV (Step column only, no Assembly column)
    printf 'Step\t%s\t%s\n' "\${compleasm_headers}" "\${quast_headers}" > ${label}_metrics.tsv
    printf '%s\t%s\t%s\n' '${step_name}' "\${compleasm_values}" "\${quast_values}" >> ${label}_metrics.tsv
    """
}

process merge_quality_reports {
    tag "merge quality reports"
    publishDir "${params.outdir}/quality", mode: 'copy'
    cpus 1
    memory '1 GB'

    input:
    path metrics_files
    val final_assembly_name

    output:
    path "quality_trace.tsv", emit: trace
    path "quality_final.tsv", emit: final_report

    script:
    """
    set -euo pipefail

    # Define processing order
    order=(metamdbg_metrics.tsv fcs_initial_metrics.tsv hifiasm_metrics.tsv fcs_final_metrics.tsv)

    # Write header from first available file
    for f in "\${order[@]}"; do
        if [[ -f "\$f" ]]; then
            head -1 "\$f" > quality_trace.tsv
            break
        fi
    done

    # Append data rows in order
    for f in "\${order[@]}"; do
        [[ -f "\$f" ]] && tail -n +2 "\$f" >> quality_trace.tsv
    done

    # Create quality_final.tsv with 'file' column
    head -1 fcs_final_metrics.tsv | sed 's/^Step/file/' > quality_final.tsv
    tail -n +2 fcs_final_metrics.tsv | sed 's/^fcs_gx round 2/${final_assembly_name}/' >> quality_final.tsv
    """
}

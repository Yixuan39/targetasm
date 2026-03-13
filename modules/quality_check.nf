nextflow.enable.dsl=2

process compleasm_run {
    tag "compleasm run: ${label}"
    cpus params.threads
    memory "${params.threads * 8} GB"

    input:
    tuple val(label), val(step_name), path(assembly), val(library_path), val(lineage), val(is_final)

    output:
    path "compleasm_out", emit: out_dir
    tuple val(label), val(step_name), path(assembly), emit: passthrough

    script:
    """
    compleasm run \
        --assembly_path ${assembly} \
        --output_dir compleasm_out \
        --threads ${task.cpus} \
        --library_path ${library_path} \
        --lineage ${lineage}
    """
}

process quast_run {
    tag "quast run: ${label}"
    cpus params.threads
    memory "${params.threads * 8} GB"

    input:
    tuple val(label), val(step_name), path(assembly)
    path compleasm_out

    output:
    path "${label}_metrics.csv", emit: current_metrics

    script:
    """
    set -euo pipefail

    quast \
        --output-dir quast_out \
        --threads ${task.cpus} \
        --eukaryote ${assembly}

    # Extract compleasm headers and values
    compleasm_headers=\$(awk -F: 'NR>1 {printf "%s%s", sep, \$1; sep=","}' ${compleasm_out}/summary.txt)
    compleasm_values=\$(awk -F: 'NR>1 {gsub(/^[ \\t]+/, "", \$2); split(\$2, a, ","); printf "%s%s", sep, a[1]; sep=","}' ${compleasm_out}/summary.txt)

    # Extract quast headers and values
    quast_headers=\$(awk -F'\\t' 'NR>1 {printf "%s%s", sep, \$1; sep=","}' quast_out/report.tsv)
    quast_values=\$(awk -F'\\t' 'NR>1 {printf "%s%s", sep, \$2; sep=","}' quast_out/report.tsv)

    # Write CSV with Step column
    echo "Step,\${compleasm_headers},\${quast_headers}" > ${label}_metrics.csv
    echo "${step_name},\${compleasm_values},\${quast_values}" >> ${label}_metrics.csv
    """
}

workflow quality_check {
    take:
    inputs

    main:
    compleasm_run(inputs)
    quast_run(compleasm_run.out.passthrough, compleasm_run.out.out_dir)

    emit:
    metrics = quast_run.out.current_metrics
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
    path "quality_trace.csv", emit: trace
    path "quality_final.csv", emit: final_report

    script:
    """
    set -euo pipefail

    # Define processing order
    order=(metamdbg_metrics.csv fcs_initial_metrics.csv hifiasm_metrics.csv fcs_final_metrics.csv)

    # Write header from first available file
    for f in "\${order[@]}"; do
        if [[ -f "\$f" ]]; then
            head -1 "\$f" > quality_trace.csv
            break
        fi
    done

    # Append data rows in order
    for f in "\${order[@]}"; do
        [[ -f "\$f" ]] && tail -n +2 "\$f" >> quality_trace.csv
    done

    # Create quality_final.csv with 'file' column
    sed '1s/^Step/file/; 2s/^fcs_gx round 2/${final_assembly_name}/' fcs_final_metrics.csv > quality_final.csv
    """
}

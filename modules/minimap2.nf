nextflow.enable.dsl=2

process minimap2_align {
    tag "minimap2 align: ${draft_assembly.simpleName}"
    publishDir "${params.outdir}/minimap2", mode: 'copy'
    cpus params.threads
    memory "${params.threads * 8} GB"
    conda "bioconda::minimap2=2.30 bioconda::samtools=1.22.1 conda-forge::pigz=2.8"

    input:
    path draft_assembly
    path raw_reads

    output:
    path "${draft_assembly.simpleName}.mapped.fastq.gz", emit: mapped_reads

    script:
    """
    set -euo pipefail

    minimap2 -ax map-hifi --secondary=no -t ${task.cpus} ${draft_assembly} ${raw_reads} \
    | samtools view -b -F 0x4 \
    | samtools fastq -n - \
    | pigz -p ${task.cpus} > ${draft_assembly.simpleName}.mapped.fastq.gz
    """
}

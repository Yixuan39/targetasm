nextflow.enable.dsl=2

process rasusa_subset {
    tag "rasusa subset: ${reads.simpleName}${bases ? ' (' + bases + ' bases)' : ''}"
    publishDir "${params.outdir}/rasusa", mode: 'copy'
    cpus 2
    conda "bioconda::rasusa"

    input:
    path reads
    val bases

    output:
    path "${reads.simpleName}.fastq.gz", emit: subset_reads

    script:
    def outFile = "${reads.simpleName}.fastq.gz"
    if (bases) {
        return """
        set -euo pipefail

        rasusa reads \
            --bases ${bases} \
            --output-type g \
            --output ${outFile} \
            ${reads}
        """
    } else {
        return """
        set -euo pipefail
        ln -sf ${reads} ${outFile}
        """
    }
}

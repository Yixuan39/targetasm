include { COMPLEASM_RUN           } from '../../modules/nf-core/compleasm/run/main'
include { QUAST                   } from '../../modules/nf-core/quast/main'
include { COLLECT_QUALITY_METRICS } from '../../modules/local/quality_reports'

workflow ASSEMBLY_QC {
    take:
    assembly // [meta (id + stage), fasta.gz]
    library
    lineage

    main:
    COMPLEASM_RUN(assembly, lineage, library)
    QUAST(assembly.map { meta, fasta -> tuple(meta, [fasta]) }, channel.value(tuple([:], [])), channel.value(tuple([:], [])))
    COLLECT_QUALITY_METRICS(COMPLEASM_RUN.out.summary.join(QUAST.out.tsv, failOnDuplicate: true, failOnMismatch: true))

    emit:
    metrics = COLLECT_QUALITY_METRICS.out.metrics
}

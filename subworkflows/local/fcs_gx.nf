include { FCSGX_RUNGX       } from '../../modules/nf-core/fcsgx/rungx/main'
include { FCSGX_CLEANGENOME } from '../../modules/nf-core/fcsgx/cleangenome/main'
include { GUNZIP            } from '../../modules/nf-core/gunzip/main'
include { HTSLIB_BGZIPTABIX } from '../../modules/nf-core/htslib/bgziptabix/main'

workflow FCS_GX {
    take:
    assembly // [meta, fasta.gz]
    database // reusable database directory
    tax_id

    main:
    FCSGX_RUNGX(assembly.map { meta, fasta -> tuple(meta, tax_id, fasta) }, database, '')
    GUNZIP(assembly)
    FCSGX_CLEANGENOME(GUNZIP.out.gunzip.join(FCSGX_RUNGX.out.fcsgx_report, failOnDuplicate: true, failOnMismatch: true))
    HTSLIB_BGZIPTABIX(
        FCSGX_CLEANGENOME.out.cleaned.map { meta, fasta -> tuple(meta, fasta, [], []) },
        'compress',
        false,
        'fasta',
    )

    emit:
    assembly = HTSLIB_BGZIPTABIX.out.output
    report   = FCSGX_RUNGX.out.fcsgx_report
}

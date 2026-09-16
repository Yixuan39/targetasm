#!/usr/bin/env nextflow

include { validateParameters; paramsHelp } from 'plugin/nf-schema'
include { TARGETASM } from './workflows/targetasm'

workflow {
    if (params.help) {
        log.info paramsHelp(beforeText: 'targetasm\n\n', command: 'nextflow run main.nf --reads reads.fastq.gz --gx_db gx-db --tax_id 4762 --outdir results')
        exit 0
    }
    validateParameters()
    def target_bases = null
    if (params.target_bases != null) {
        try {
            target_bases = params.target_bases.toString().toBigDecimal().longValueExact()
        }
        catch (Exception _e) {
            error('--target_bases must be a positive integer number of bases (e.g. 5e9)')
        }
        if (target_bases <= 0) {
            error('--target_bases must be positive')
        }
    }

    def reads = file(params.reads, checkIfExists: true)
    def gx_db = file(params.gx_db, checkIfExists: true)
    if (!(reads.simpleName ==~ /[A-Za-z0-9][A-Za-z0-9_.-]*/)) {
        error 'The reads filename must start with a letter or number and contain only letters, numbers, dots, underscores and hyphens'
    }
    def quality_library = params.quality_library ? file(params.quality_library, checkIfExists: true) : []
    TARGETASM(reads, gx_db, quality_library, target_bases)
}

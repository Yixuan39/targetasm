#!/usr/bin/env nextflow

include { validateParameters; paramsHelp; samplesheetToList } from 'plugin/nf-schema'
include { TARGETASM } from './workflows/targetasm'

// Whole number of bases from e.g. 5400000000 or 5.4e9; null when unset.
def targetBases(value, String name) {
    if (value == null || value == []) {
        return null
    }
    try {
        def bases = value.toString().toBigDecimal().longValueExact()
        if (bases > 0) {
            return bases
        }
    }
    catch (Exception _e) {
        // reported below
    }
    error("${name} must be a positive integer number of bases (e.g. 5e9)")
}

workflow {
    if (params.help) {
        log.info paramsHelp(
            beforeText: 'targetasm\n\n',
            command: 'nextflow run Yixuan39/targetasm -r <version> -profile <singularity|apptainer|docker|conda> --input samplesheet.csv --gx_db <fcs-gx-db-dir> --tax_id <taxid> --outdir results',
        )
        exit 0
    }
    validateParameters()
    def default_bases = targetBases(params.target_bases, '--target_bases')
    def samples = samplesheetToList(params.input, "${projectDir}/assets/schema_input.json").collect { meta, reads ->
        // Without a sample name, name the sample after its reads (isolate1.fastq.gz -> isolate1).
        def id = meta.id ?: reads.simpleName
        if (!(id ==~ /[A-Za-z0-9][A-Za-z0-9_.-]*/)) {
            error("Sample name '${id}' (from ${reads.name}) must start with a letter or number and contain only letters, numbers, dots, underscores and hyphens; set it in the sample column")
        }
        def bases = targetBases(meta.target_bases, "target_bases for sample ${id}") ?: default_bases
        tuple(meta + [id: id, single_end: true, target_bases: bases], reads)
    }
    def duplicates = samples.countBy { meta, _reads -> meta.id }.findAll { _id, n -> n > 1 }.keySet()
    if (duplicates) {
        error("Duplicate sample names: ${duplicates.join(', ')}; give each row a unique sample name")
    }
    def gx_db = file(params.gx_db, checkIfExists: true)
    def quality_library = params.quality_library ? file(params.quality_library, checkIfExists: true) : []
    TARGETASM(channel.fromList(samples), gx_db, quality_library)
}

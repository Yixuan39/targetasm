#!/usr/bin/env nextflow

include { validateParameters; paramsHelp; samplesheetToList } from 'plugin/nf-schema'
include { TARGETASM } from './workflows/targetasm'

// The bundled smoke-test sheet stores a repo-relative reads path. samplesheetToList
// resolves file paths from the launch directory, so rewrite that one sheet with an
// absolute path before validation. Any other samplesheet is unchanged.
def bundledTestSheet(input) {
    def samplesheet = file(input, checkIfExists: true)
    def bundled = file("${projectDir}/assets/samplesheet_test.csv")
    if (samplesheet.toAbsolutePath().normalize() != bundled.toAbsolutePath().normalize()) {
        return samplesheet
    }
    def reads = file("${projectDir}/assets/testdata/UA202013.fastq.gz")
    if (!reads.exists()) {
        error("Bundled test reads not found: ${reads}. Rebuild them with: python3 ${projectDir}/assets/fetch_ua202013_test_reads.py")
    }
    def staged = new File(System.getProperty('java.io.tmpdir'), "targetasm-test-${java.util.UUID.randomUUID()}.csv")
    staged.deleteOnExit()
    staged.text = "sample,reads\nUA202013,${reads.toAbsolutePath()}\n"
    return file(staged.absolutePath)
}

// Directory must contain one FCS-GX index pair. The complete database uses all.*;
// NCBI's test-only database uses test-only.*.
def checkGxDatabase(gx_db) {
    def names = gx_db.isDirectory() ? ((gx_db.list() ?: []) as List) : []
    def indexes = names.findAll { name -> name.endsWith('.gxi') }
    def found = indexes ? indexes.join(', ') : 'none'
    if (indexes.size() != 1) {
        error("--gx_db '${gx_db}' must contain exactly one FCS-GX index pair: all.gxi and all.gxs, or test-only.gxi and test-only.gxs for NCBI's test-only database. Found index files: ${found}. Pass the database directory, not the 'all' file prefix used by targetasm 0.1.0. Download: https://github.com/ncbi/fcs/wiki/FCS-GX-quickstart")
    }
    def indexName = indexes[0].toString()
    def sequences = file("${gx_db}/${indexName.substring(0, indexName.length() - 4)}.gxs")
    if (!sequences.exists()) {
        error("--gx_db '${gx_db}' has ${indexes[0]} but is missing ${sequences.name}. Download: https://github.com/ncbi/fcs/wiki/FCS-GX-quickstart")
    }
}

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
    // validateParameters() also checks reads in the samplesheet, from the launch directory.
    def input_sheet = bundledTestSheet(params.input)
    params.input = input_sheet.toString()
    validateParameters()
    def default_bases = targetBases(params.target_bases, '--target_bases')
    def samples = samplesheetToList(input_sheet, "${projectDir}/assets/schema_input.json").collect { meta, reads ->
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
    checkGxDatabase(gx_db)
    def quality_library = params.quality_library ? file(params.quality_library, checkIfExists: true) : []
    TARGETASM(channel.fromList(samples), gx_db, quality_library)
}

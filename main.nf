nextflow.enable.dsl=2

include { metamdbg_assemble } from './modules/metaMDBG.nf'
include { fcs_gx_clean as fcs_gx_initial_clean } from './modules/fcs_gx.nf'
include { minimap2_align } from './modules/minimap2.nf'
include { rasusa_subset } from './modules/rasusa.nf'
include { hifiasm_reassemble } from './modules/hifiasm.nf'
include { fcs_gx_clean as fcs_gx_final_clean } from './modules/fcs_gx.nf'
include { quality_check } from './modules/quality_check.nf'
include { merge_quality_reports } from './modules/quality_check.nf'

process deliver_final_clean {
    tag "deliver final clean"
    publishDir "${params.outdir}", mode: 'copy'
    cpus 1
    memory '1 GB'

    input:
    tuple path(cleaned), val(target_name)

    output:
    path target_name, emit: delivered

    script:
    """
    set -euo pipefail
    cp ${cleaned} ${target_name}
    """
}

workflow {
    main:
        if (params.help) {
            log.info """
TEA (Target Eukaryotic genome Assembly)

Usage:
    nextflow run main.nf \\
        --reads <reads.fastq.gz> \\
        --gx_db <path/to/gx-db-prefix> \\
        --tax_id <ncbi_tax_id> \\
        --rasusa_bases <bases> \\
        --threads <int> \\
        --hifiasm_option '<opts>' \\
        --outdir <results_dir> \\
        --quality_library <path/to/compleasm_db> \
        --quality_lineage <lineage>

Parameters:
    --reads            Input PacBio HiFi reads in FASTQ.GZ format (required).
    --gx_db            Path prefix to the NCBI FCS-GX database bundle (required).
    --tax_id           NCBI taxonomy identifier used by FCS-GX (required).
    --rasusa_bases     Optional target number of bases for rasusa downsampling (genome size * coverage);
                                         omit to retain all mapped reads.
    --rasusa_seed      Random seed for rasusa subsampling (default: 42).
    --threads          Maximum CPU cores assigned to threaded processes
                                         (default: ${params.threads}).
    --hifiasm_option   Extra options passed to hifiasm (default: '-l 1').
    --outdir           Directory for published outputs (default: ${params.outdir}).
    --quality_library  Path to the Compleasm database; required to enable quality checks.
    --quality_lineage  Compleasm lineage dataset name (required when --quality_library is supplied).

For additional details, consult README.md.
"""
            exit 0
        }
        if (!params.reads) {
            error "Parameter --reads must point to a .fastq.gz file"
        }
        if (!params.gx_db) {
            error "Parameter --gx_db must point to the FCS-GX database"
        }
        if (params.tax_id == null) {
            error "Parameter --tax_id is required for FCS-GX"
        }

        def reads_path = file(params.reads)
        def gx_db_path = file(params.gx_db)

        def reads_channel = channel.of(reads_path)
        def initial_base = 'fcs_initial'
        def final_base = 'fcs_final'

        metamdbg_assemble(reads_channel)

        def meta_for_fcs = metamdbg_assemble.out.assembly
        def initial_fcs_input = meta_for_fcs.map { assembly -> tuple(assembly, gx_db_path, params.tax_id, initial_base) }
        fcs_gx_initial_clean(initial_fcs_input)

        def initial_for_minimap = fcs_gx_initial_clean.out.clean_fasta

        def minimap_input = initial_for_minimap.map { draft -> tuple(draft, reads_path) }
        minimap2_align(minimap_input)

        // Skip rasusa if rasusa_bases is not set
        if (params.rasusa_bases) {
            def rasusa_input = minimap2_align.out.mapped_reads.map { mapped_reads -> tuple(mapped_reads, params.rasusa_bases) }
            rasusa_subset(rasusa_input)
            hifiasm_reassemble(rasusa_subset.out.subset_reads)
        } else {
            hifiasm_reassemble(minimap2_align.out.mapped_reads)
        }

        def hifiasm_for_fcs = hifiasm_reassemble.out.assembly
        def final_fcs_input = hifiasm_for_fcs.map { assembly -> tuple(assembly, gx_db_path, params.tax_id, final_base) }
        fcs_gx_final_clean(final_fcs_input)

        def final_for_delivery = fcs_gx_final_clean.out.clean_fasta

        def delivery_input = final_for_delivery.map { cleaned -> tuple(cleaned, "${reads_path.simpleName}.fasta.gz") }
        deliver_final_clean(delivery_input)

        if (params.quality_library) {
            if (!params.quality_lineage) {
                error "Parameter --quality_lineage is required when --quality_library is provided"
            }

            def qc_metamdbg = metamdbg_assemble.out.assembly.map { asm -> tuple('metamdbg', 'metaMDBG', asm, params.quality_library, params.quality_lineage, 'false') }
            def qc_fcs_initial = fcs_gx_initial_clean.out.clean_fasta.map { asm -> tuple('fcs_initial', 'fcs_gx round 1', asm, params.quality_library, params.quality_lineage, 'false') }
            def qc_hifiasm = hifiasm_reassemble.out.assembly.map { asm -> tuple('hifiasm', 'hifiasm', asm, params.quality_library, params.quality_lineage, 'false') }
            def qc_fcs_final = fcs_gx_final_clean.out.clean_fasta.map { asm -> tuple('fcs_final', 'fcs_gx round 2', asm, params.quality_library, params.quality_lineage, 'true') }

            def qc_inputs = qc_metamdbg.mix(qc_fcs_initial).mix(qc_hifiasm).mix(qc_fcs_final)
            quality_check(qc_inputs)

            def all_metrics = quality_check.out.metrics.collect()
            def final_name = reads_path.simpleName
            merge_quality_reports(all_metrics, final_name)
        } else {
            log.warn "Skipping quality check because --quality_library was not provided."
        }
}

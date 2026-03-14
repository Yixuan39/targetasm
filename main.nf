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
        --target_bases <bases> \\
        --threads <int> \\
        --hifiasm_option '<opts>' \\
        --outdir <results_dir> \\
        --quality_library <path/to/compleasm_db> \\
        --quality_lineage <lineage>

Parameters:
    --reads            Input PacBio HiFi reads in FASTQ.GZ format (required).
    --gx_db            Path prefix to the NCBI FCS-GX database bundle (required).
    --tax_id           NCBI taxonomy identifier used by FCS-GX (required).
    --target_bases     Optional target number of bases for subsampling (genome size * coverage);
                                         omit to use all mapped reads.
    --rasusa_seed      Random seed for rasusa subsampling (default: 0).
    --threads          Maximum CPU cores assigned to threaded processes
                                         (default: ${params.threads}).
    --hifiasm_option   Extra options passed to hifiasm (default: '-l 2').
    --keep_intermediates
                       Keep intermediate files (draft assemblies, mapped reads, etc.);
                                         use this flag to retain them (default: off).
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

        metamdbg_assemble(channel.of(reads_path))

        fcs_gx_initial_clean(
            metamdbg_assemble.out.assembly.map { assembly -> tuple(assembly, gx_db_path, params.tax_id, 'fcs_initial') }
        )

        minimap2_align(
            fcs_gx_initial_clean.out.clean_fasta.map { draft -> tuple(draft, reads_path) }
        )

        // Subsample with rasusa if target_bases is set, otherwise pass through
        if (params.target_bases) {
            log.info "Rasusa subsampling enabled: targeting ${params.target_bases} bases"
            rasusa_subset(
                minimap2_align.out.mapped_reads.map { reads -> tuple(reads, params.target_bases) }
            )
            hifiasm_reassemble(rasusa_subset.out.subset_reads)
        } else {
            log.warn "Rasusa subsampling SKIPPED (--target_bases not set). All mapped reads will be used for reassembly."
            hifiasm_reassemble(minimap2_align.out.mapped_reads)
        }

        fcs_gx_final_clean(
            hifiasm_reassemble.out.assembly.map { assembly -> tuple(assembly, gx_db_path, params.tax_id, 'fcs_final') }
        )

        deliver_final_clean(
            fcs_gx_final_clean.out.clean_fasta.map { cleaned -> tuple(cleaned, "${reads_path.simpleName}.fasta.gz") }
        )

        if (params.quality_library) {
            if (!params.quality_lineage) {
                error "Parameter --quality_lineage is required when --quality_library is provided"
            }

            def quality_lib_path = file(params.quality_library)

            def qc_inputs = metamdbg_assemble.out.assembly.map { asm -> tuple('metamdbg', 'metaMDBG', asm, quality_lib_path, params.quality_lineage, 'false') }
                .mix(fcs_gx_initial_clean.out.clean_fasta.map { asm -> tuple('fcs_initial', 'fcs_gx round 1', asm, quality_lib_path, params.quality_lineage, 'false') })
                .mix(hifiasm_reassemble.out.assembly.map { asm -> tuple('hifiasm', 'hifiasm', asm, quality_lib_path, params.quality_lineage, 'false') })
                .mix(fcs_gx_final_clean.out.clean_fasta.map { asm -> tuple('fcs_final', 'fcs_gx round 2', asm, quality_lib_path, params.quality_lineage, 'true') })

            quality_check(qc_inputs)
            merge_quality_reports(quality_check.out.metrics.collect(), reads_path.simpleName)
        } else {
            log.warn "Skipping quality check because --quality_library was not provided."
        }
}

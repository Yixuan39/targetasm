nextflow.enable.dsl=2

params.threads = params.threads ?: 24
params.help = params.help ?: false
params.fcs_initial_output = params.fcs_initial_output ?: 'fcs_initial.clean.fasta'
params.fcs_final_output = params.fcs_final_output ?: 'fcs_final.clean.fasta'
params.quality_lineage = params.quality_lineage ?: 'stramenopiles'

include { metamdbg_assemble } from './modules/metaMDBG.nf'
include { fcs_gx_clean as fcs_gx_initial_clean } from './modules/fcs_gx.nf'
include { minimap2_align } from './modules/minimap2.nf'
include { rasusa_subset } from './modules/rasusa.nf'
include { hifiasm_reassemble } from './modules/hifiasm.nf'
include { fcs_gx_clean as fcs_gx_final_clean } from './modules/fcs_gx.nf'
include { quality_check } from './modules/quality_check.nf'

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
        --fcs_initial_output <file> \
        --fcs_final_output <file> \
        --outdir <results_dir> \
        --quality_library <path/to/compleasm_db> \
        --quality_lineage <lineage>

Parameters:
    --reads            Input PacBio HiFi reads in FASTQ.GZ format (required).
    --gx_db            Path prefix to the NCBI FCS-GX database bundle (required).
    --tax_id           NCBI taxonomy identifier used by FCS-GX (required).
    --rasusa_bases     Optional target number of bases for rasusa downsampling (genome size * coverage);
                                         omit to retain all mapped reads.
    --threads          Maximum CPU cores assigned to threaded processes
                                         (default: ${params.threads}).
    --hifiasm_option   Extra options passed to hifiasm (default: '-l 1').
    --fcs_initial_output  Filename for the first FCS-GX cleaned assembly (default: ${params.fcs_initial_output}).
    --fcs_final_output    Filename for the final FCS-GX cleaned assembly (default: ${params.fcs_final_output}).
    --outdir           Directory for published outputs (default: ${params.outdir}).
    --quality_library  Path to the Compleasm database; required to enable quality checks.
    --quality_lineage  Compleasm lineage dataset name (default: ${params.quality_lineage}).

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

        metamdbg_assemble(reads_channel)

        def meta_assemblies = metamdbg_assemble.out.assembly.share()

        def initial_fcs_input = meta_assemblies.map { assembly -> tuple(assembly, gx_db_path, params.tax_id, params.fcs_initial_output) }
        fcs_gx_initial_clean(initial_fcs_input)

        def initial_clean_fasta = fcs_gx_initial_clean.out.clean_fasta.share()

        def minimap_input = initial_clean_fasta.map { draft -> tuple(draft, reads_path) }
        minimap2_align(minimap_input)

        def rasusa_input = minimap2_align.out.mapped_reads.map { mapped_reads -> tuple(mapped_reads, params.rasusa_bases) }
        rasusa_subset(rasusa_input)

        hifiasm_reassemble(rasusa_subset.out.subset_reads)

        def reassembly_assemblies = hifiasm_reassemble.out.assembly.share()

        def final_fcs_input = reassembly_assemblies.map { assembly -> tuple(assembly, gx_db_path, params.tax_id, params.fcs_final_output) }
        def final_clean = fcs_gx_final_clean(final_fcs_input)

        def final_clean_fasta = final_clean.out.clean_fasta.share()

        def delivery_input = final_clean_fasta.map { cleaned -> tuple(cleaned, "${reads_path.simpleName}.fasta.gz") }
        deliver_final_clean(delivery_input)

        if (params.quality_library) {
            def qc_manifest = channel.merge(
                meta_assemblies.map { asm -> tuple('metamdbg', asm) },
                initial_clean_fasta.map { asm -> tuple('fcs_initial', asm) },
                reassembly_assemblies.map { asm -> tuple('hifiasm', asm) },
                final_clean_fasta.map { asm -> tuple('fcs_final', asm) }
            )
            .filter { _label, asm ->
                def lower = asm.toString().toLowerCase()
                !(lower.endsWith('.fastq') || lower.endsWith('.fastq.gz') || lower.endsWith('.fq') || lower.endsWith('.fq.gz'))
            }

            def manifest_entries = qc_manifest
                .map { label, asm -> [label, asm.toString()] }
                .collect()
                .filter { entries -> entries && entries.size() > 0 }
                .map { entries -> tuple(entries, params.quality_library, params.quality_lineage) }

            quality_check(manifest_entries)
        } else {
            log.warn "Skipping quality check because --quality_library was not provided."
        }
}

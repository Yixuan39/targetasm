nextflow.enable.dsl=2

include { metamdbg_assemble } from './modules/metaMDBG.nf'
include { fcs_gx_clean as fcs_gx_initial_clean } from './modules/fcs_gx.nf'
include { minimap2_align } from './modules/minimap2.nf'
include { rasusa_subset } from './modules/rasusa.nf'
include { hifiasm_reassemble } from './modules/hifiasm.nf'
include { fcs_gx_clean as fcs_gx_final_clean } from './modules/fcs_gx.nf'

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
        --outdir <results_dir>

Parameters:
    --reads            Input PacBio HiFi reads in FASTQ.GZ format (required).
    --gx_db            Path prefix to the NCBI FCS-GX database bundle (required).
    --tax_id           NCBI taxonomy identifier used by FCS-GX (required).
    --rasusa_bases     Optional target number of bases for rasusa downsampling (genome size * coverage);
                                         omit to retain all mapped reads.
    --threads          Maximum CPU cores assigned to threaded processes
                                         (default: ${params.threads}).
    --hifiasm_option   Extra options passed to hifiasm (default: '-l 1').
    --outdir           Directory for published outputs (default: ${params.outdir}).

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

    def raw_reads_for_meta = channel.of(file(params.reads))
    def raw_reads_for_minimap = channel.of(file(params.reads))

    metamdbg_assemble(raw_reads_for_meta)
    def meta_assembly = metamdbg_assemble.out.assembly

    def initial_fcs_input = meta_assembly.map { assembly -> tuple(assembly, file(params.gx_db), params.tax_id) }
    fcs_gx_initial_clean(initial_fcs_input)
    def initial_clean_fasta = fcs_gx_initial_clean.out.clean_fasta

    def minimap_input = initial_clean_fasta.combine(raw_reads_for_minimap) { draft, reads -> tuple(draft, reads) }
    minimap2_align(minimap_input)
    def mapped_reads = minimap2_align.out.mapped_reads

    def rasusa_input = mapped_reads.map { mapped_reads_file -> tuple(mapped_reads_file, params.rasusa_bases) }
    rasusa_subset(rasusa_input)
    def subset_reads = rasusa_subset.out.subset_reads

    hifiasm_reassemble(subset_reads)
    def reassembly_assembly = hifiasm_reassemble.out.assembly

    def final_fcs_input = reassembly_assembly.map { assembly -> tuple(assembly, file(params.gx_db), params.tax_id) }
    fcs_gx_final_clean(final_fcs_input)
}

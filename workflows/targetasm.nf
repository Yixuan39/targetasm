include { METAMDBG_ASM          } from '../modules/nf-core/metamdbg/asm/main'
include { MINIMAP2_ALIGN        } from '../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_BAM2FQ       } from '../modules/nf-core/samtools/bam2fq/main'
include { HIFIASM               } from '../modules/nf-core/hifiasm/main'
include { GFATOOLS_GFA2FA       } from '../modules/nf-core/gfatools/gfa2fa/main'
include { RASUSA_READS          } from '../modules/local/rasusa'
include { FCS_GX as FCS_INITIAL ; FCS_GX as FCS_FINAL } from '../subworkflows/local/fcs_gx'
include { ASSEMBLY_QC           } from '../subworkflows/local/assembly_qc'
include { MERGE_QUALITY_REPORTS } from '../modules/local/quality_reports'

workflow TARGETASM {
    take:
    reads
    gx_db
    quality_library
    target_bases

    main:
    def meta = [id: reads.simpleName, single_end: true]
    def ch_reads = channel.value(tuple(meta, reads))
    METAMDBG_ASM(ch_reads, 'hifi')
    FCS_INITIAL(METAMDBG_ASM.out.contigs, gx_db, params.tax_id)

    // The CLI currently accepts one sample: reads is a value channel and the reference is a queue.
    MINIMAP2_ALIGN(ch_reads, FCS_INITIAL.out.assembly, true, '', false, false)
    SAMTOOLS_BAM2FQ(MINIMAP2_ALIGN.out.bam, false)

    def ch_reassembly = SAMTOOLS_BAM2FQ.out.reads
    if (target_bases != null) {
        RASUSA_READS(ch_reassembly, target_bases, params.rasusa_seed)
        ch_reassembly = RASUSA_READS.out.reads
    }
    HIFIASM(
        ch_reassembly.map { sample, fastq -> tuple(sample, fastq, []) },
        channel.value(tuple([:], [], [])),
        channel.value(tuple([:], [], [])),
        channel.value(tuple([:], [])),
    )
    // --primary selects p_ctg; the upstream stub also emits bp.p_ctg, so select explicitly.
    def ch_primary = HIFIASM.out.primary_contigs.map { sample, gfa ->
        def files = gfa instanceof List ? gfa : [gfa]
        def primary = files.find { f -> f.name == "${sample.id}.p_ctg.gfa" }
        if (!primary) {
            error("Missing --primary assembly for ${sample.id}")
        }
        tuple(sample, primary)
    }
    GFATOOLS_GFA2FA(ch_primary)
    FCS_FINAL(GFATOOLS_GFA2FA.out.fasta, gx_db, params.tax_id)

    if (params.quality_library) {
        def ch_qc = METAMDBG_ASM.out.contigs
            .map { sample, fasta ->
                tuple(sample + [id: "${sample.id}.metamdbg", stage: 'metamdbg'], fasta)
            }
            .mix(
                FCS_INITIAL.out.assembly.map { sample, fasta ->
                    tuple(sample + [id: "${sample.id}.fcs_initial", stage: 'fcs_initial'], fasta)
                }
            )
            .mix(
                GFATOOLS_GFA2FA.out.fasta.map { sample, fasta ->
                    tuple(sample + [id: "${sample.id}.hifiasm", stage: 'hifiasm'], fasta)
                }
            )
            .mix(
                FCS_FINAL.out.assembly.map { sample, fasta ->
                    tuple(sample + [id: "${sample.id}.fcs_final", stage: 'fcs_final'], fasta)
                }
            )
        ASSEMBLY_QC(ch_qc, quality_library, params.quality_lineage)
        MERGE_QUALITY_REPORTS(ASSEMBLY_QC.out.metrics.collect(), "${meta.id}.fasta.gz")
    }

    channel.topic('versions')
        .map { process_name, tool, version -> "${process_name}\t${tool}\t${version}" }
        .unique()
        .collectFile(name: 'software_versions.tsv', storeDir: "${params.outdir}/pipeline_info", sort: true, newLine: true)

    emit:
    assembly = FCS_FINAL.out.assembly
}

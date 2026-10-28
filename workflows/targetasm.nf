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
    ch_reads // [meta, reads]; meta.target_bases is null to keep all recruited reads
    gx_db
    quality_library

    main:
    METAMDBG_ASM(ch_reads, 'hifi')
    FCS_INITIAL(METAMDBG_ASM.out.contigs, gx_db, params.tax_id)

    // Map each sample's original reads back to its own cleaned draft.
    def ch_mapping = ch_reads
        .join(FCS_INITIAL.out.assembly, failOnDuplicate: true, failOnMismatch: true)
        .multiMap { meta, reads, draft ->
            reads: tuple(meta, reads)
            draft: tuple(meta, draft)
        }
    MINIMAP2_ALIGN(ch_mapping.reads, ch_mapping.draft, true, '', false, false)
    SAMTOOLS_BAM2FQ(MINIMAP2_ALIGN.out.bam, false)

    def ch_recruited = SAMTOOLS_BAM2FQ.out.reads.branch { meta, _fastq ->
        subsample: meta.target_bases != null
        keep: true
    }
    RASUSA_READS(ch_recruited.subsample, params.rasusa_seed)
    def ch_reassembly = ch_recruited.keep.mix(RASUSA_READS.out.reads)
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
                tuple(sample + [id: "${sample.id}.metamdbg", stage: 'metamdbg', sample_id: sample.id], fasta)
            }
            .mix(
                FCS_INITIAL.out.assembly.map { sample, fasta ->
                    tuple(sample + [id: "${sample.id}.fcs_initial", stage: 'fcs_initial', sample_id: sample.id], fasta)
                }
            )
            .mix(
                GFATOOLS_GFA2FA.out.fasta.map { sample, fasta ->
                    tuple(sample + [id: "${sample.id}.hifiasm", stage: 'hifiasm', sample_id: sample.id], fasta)
                }
            )
            .mix(
                FCS_FINAL.out.assembly.map { sample, fasta ->
                    tuple(sample + [id: "${sample.id}.fcs_final", stage: 'fcs_final', sample_id: sample.id], fasta)
                }
            )
        ASSEMBLY_QC(ch_qc, quality_library, params.quality_lineage)
        // One report per sample once all four stages are measured.
        MERGE_QUALITY_REPORTS(
            ASSEMBLY_QC.out.metrics
                .map { meta, metrics -> tuple(meta.sample_id, metrics) }
                .groupTuple(size: 4)
        )
    }

    channel.topic('versions')
        .map { process_name, tool, version -> "${process_name}\t${tool}\t${version}" }
        .unique()
        .collectFile(name: 'software_versions.tsv', storeDir: "${params.outdir}/pipeline_info", sort: true, newLine: true)

    emit:
    assembly = FCS_FINAL.out.assembly
}

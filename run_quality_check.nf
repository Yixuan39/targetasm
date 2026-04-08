#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { quality_check } from './modules/quality_check.nf'
include { merge_quality_reports } from './modules/quality_check.nf'

workflow {
    if (params.help) {
        log.info """
Quality Check Standalone Runner

Usage:
    nextflow run run_quality_check.nf \\
        --fasta <file.fasta or "*.fasta"> \\
        --quality_library <path/to/compleasm_db> \\
        --quality_lineage <lineage> \\
        --outdir <results_dir>

Parameters:
    --fasta            Input fasta file(s). Can be a single file or glob pattern (required).
    --quality_library  Path to the Compleasm database (required).
    --quality_lineage  Compleasm lineage dataset name (required).
    --threads          CPU cores for processes (default: ${params.threads}).
    --outdir           Output directory (default: ${params.outdir}).
"""
        exit 0
    }

    if (!params.fasta) {
        error "Parameter --fasta is required"
    }
    if (!params.quality_library) {
        error "Parameter --quality_library is required"
    }
    if (!params.quality_lineage) {
        error "Parameter --quality_lineage is required"
    }

    def quality_lib_path = file(params.quality_library)

    // Create input channel from fasta files
    // Format: tuple(label, step_name, assembly, library_path, lineage, is_final)
    def qc_inputs = Channel.fromPath(params.fasta)
        .map { fasta -> 
            def label = fasta.simpleName
            tuple(label, label, fasta, quality_lib_path, params.quality_lineage, 'true')
        }

    quality_check(qc_inputs)
    
    // Collect all metrics and merge
    merge_quality_reports(
        quality_check.out.metrics.collect(),
        'combined'
    )
}

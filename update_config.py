import sys

with open("nextflow.config", "r") as f:
    text = f.read()

# Add process block
container_block = """
// Container definitions for Biocontainers
process {
    withName: 'metamdbg_assemble' { container = 'quay.io/biocontainers/metamdbg:1.2--h077b44d_0' }
    withName: 'fcs_gx_run'        { container = 'quay.io/biocontainers/ncbi-fcs-gx:0.5.5--h9948957_0' }
    withName: 'minimap2_run'      { container = 'quay.io/biocontainers/minimap2:2.28--h577a1d6_4' }
    withName: 'samtools_filter'   { container = 'quay.io/biocontainers/samtools:1.22.1--h96c455f_0' }
    withName: 'rasusa_subset'     { container = 'quay.io/biocontainers/rasusa:2.2.2--hc1c3326_0' }
    withName: 'hifiasm_run'       { container = 'quay.io/biocontainers/hifiasm:0.25.0--h5ca1c30_0' }
    withName: 'gfatools_convert'  { container = 'quay.io/biocontainers/gfatools:0.5.5--h577a1d6_0' }
    withName: 'pigz_compress.*'   { container = 'quay.io/biocontainers/pigz:2.8' }
    withName: 'compleasm_run'     { container = 'quay.io/biocontainers/compleasm:0.2.7--pyh7e72e81_1' }
    withName: 'quast_run'         { container = 'quay.io/biocontainers/quast:5.3.0--py313pl5321h5ca1c30_2' }
    withName: 'deliver_final_clean|merge_quality_reports' { container = 'ubuntu:22.04' }
}

profiles {"""

text = text.replace("profiles {", container_block)

# Replace queue labels fcs_gx_clean -> fcs_gx_run
text = text.replace("withName: 'fcs_gx_clean'", "withName: 'fcs_gx_run'")
text = text.replace("withName: quality_check", "withName: 'compleasm_run|quast_run'")

# Add docker/singularity/apptainer profiles inside profiles { ... }
# Find standard and slurm end, we can just append before closing brace of profiles
idx = text.rfind("}")
new_profiles = """
    docker {
        docker.enabled = true
        conda.enabled = false
    }
    singularity {
        singularity.enabled = true
        singularity.autoMounts = true
        conda.enabled = false
    }
    apptainer {
        apptainer.enabled = true
        apptainer.autoMounts = true
        conda.enabled = false
    }
}
"""
text = text[:idx] + new_profiles

with open("nextflow.config", "w") as f:
    f.write(text)

print("Updated nextflow.config successfully")

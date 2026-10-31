#!/usr/bin/env python3
"""Run nf-test orchestration tests with version-only stand-ins, without containers."""
import gzip
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix='targetasm-stub-') as directory:
    root = Path(directory)
    (root / 'gxdb').mkdir()
    (root / 'library').mkdir()
    with gzip.open(root / 'sample.fastq.gz', 'wt') as handle:
        handle.write('@read1\nACGT\n+\nIIII\n')
    (root / 'reads.fq').write_text('@read1\nACGT\n+\nIIII\n')
    samplesheets = {
        'samplesheet.csv': ['sample,sample.fastq.gz'],
        'multi.csv': ['a,sample.fastq.gz,1e3', 'b,reads.fq,'],
        'missing.csv': ['sample,missing.fastq.gz'],
        'duplicate.csv': ['a,sample.fastq.gz', 'a,reads.fq'],
    }
    for name, rows in samplesheets.items():
        lines = ['sample,reads,target_bases'] + [
            ','.join([fields[0], str(root / fields[1])] + fields[2:]) for fields in (row.split(',') for row in rows)
        ]
        (root / name).write_text('\n'.join(lines) + '\n')
    (root / 'reads_only.csv').write_text(f"reads\n{root / 'sample.fastq.gz'}\n{root / 'reads.fq'}\n")
    mock = root / 'version_only.py'
    mock.write_text('''#!/usr/bin/env python3
import gzip, pathlib, sys
tool = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
if tool == 'compleasm' and pathlib.Path('library').is_dir():
    pathlib.Path('library/updated-metadata.txt').write_text('Simulated library metadata update')
if tool == 'bgzip' and args == ['-c']:
    sys.stdout.buffer.write(gzip.compress(sys.stdin.buffer.read(), mtime=0))
elif not args or args in [['--version'], ['version'], ['--help']]:
    print({'metaMDBG': 'Version: 0.0.0-stub', 'gx': 'build:v0.0.0-stub',
           'quast.py': 'QUAST v0.0.0-stub', 'bgzip': 'bgzip (htslib) 0.0.0-stub',
           'gunzip': 'gunzip (gzip) 0.0.0-stub', 'xz': 'xz (XZ Utils) 0.0.0-stub'
    }.get(tool, tool + ' 0.0.0-stub'))
else:
    sys.exit('Stub tests must not run real tool commands: ' + tool + ' ' + ' '.join(args))
''')
    mock.chmod(0o755)
    for tool in ['metaMDBG', 'gx', 'hifiasm', 'gfatools', 'minimap2', 'samtools', 'bgzip', 'gunzip', 'xz', 'rasusa', 'compleasm', 'quast.py']:
        (root / tool).symlink_to(mock)
    env = dict(os.environ, TARGETASM_TEST_ROOT=str(root), PATH=f'{root}:{os.environ["PATH"]}', NXF_OFFLINE='true')
    result = subprocess.run(['nf-test', 'test', 'tests/main.nf.test', '--ci'], cwd=ROOT, env=env)
    assert not any((root / 'library').iterdir()), 'Compleasm must not modify the shared input library'

    # A local run inside a 512 MB Slurm job must refuse FCS-GX up front, not start it and get OOM-killed.
    slurm = subprocess.run(
        ['nextflow', 'run', str(ROOT / 'main.nf'), '-stub-run', '-c', str(ROOT / 'tests/nextflow.config'), '--outdir', str(root / 'slurm')],
        cwd=root, env=dict(env, SLURM_MEM_PER_NODE='512'), capture_output=True, text=True,
    )
    assert slurm.returncode != 0 and 'exceeds available memory' in slurm.stdout + slurm.stderr, slurm.stdout + slurm.stderr
    raise SystemExit(result.returncode)

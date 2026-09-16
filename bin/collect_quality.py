#!/usr/bin/env python3
"""Parse tool reports and merge targetasm's four assembly stages using CSV escaping."""

import csv
import re
import sys
from pathlib import Path

STEPS = {
    'metamdbg': 'metaMDBG',
    'fcs_initial': 'fcs_gx round 1',
    'hifiasm': 'hifiasm',
    'fcs_final': 'fcs_gx round 2',
}


def write_csv(path, rows, fields):
    with Path(path).open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def metrics(stage, compleasm, quast):
    if stage not in STEPS:
        raise ValueError(f'Unknown assembly stage: {stage}')
    row = {'Step': stage}
    for line in Path(compleasm).read_text().splitlines():
        match = re.fullmatch(r'\s*([SDFIMN]):\s*(.+)', line)
        if match:
            key, value = match.groups()
            if key in row:
                raise ValueError(f'Multiple Compleasm result sets in {compleasm}')
            row[key] = value.split(',', 1)[0].strip()
    if not all(key in row for key in 'SDFMN'):
        raise ValueError(f'Missing Compleasm S/D/F/M/N metrics in {compleasm}')
    with Path(quast).open(newline='') as handle:
        reader = csv.reader(handle, delimiter='\t')
        header = next(reader, [])
        if len(header) != 2 or header[0] != 'Assembly':
            raise ValueError(f'Expected a single-assembly QUAST report: {quast}')
        for fields in reader:
            if not fields:
                continue
            if len(fields) != 2 or fields[0] in row:
                raise ValueError(f'Invalid or duplicate QUAST metric: {fields}')
            row[fields[0]] = fields[1]
    if 'N50' not in row:
        raise ValueError(f'Empty QUAST report: {quast}')
    write_csv(f'{stage}_metrics.csv', [row], list(row))


def merge(assembly_name, files):
    by_stage = {}
    fields = ['Step']
    for file in files:
        with Path(file).open(newline='') as handle:
            reader = csv.DictReader(handle)
            rows = list(reader)
            if len(rows) != 1 or None in rows[0] or any(value is None for value in rows[0].values()):
                raise ValueError(f'Expected one complete metrics row in {file}')
            row = rows[0]
            stage = row.get('Step')
            if stage not in STEPS or stage in by_stage:
                raise ValueError(f'Unknown or duplicate stage in {file}: {stage}')
            by_stage[stage] = row
    if set(by_stage) != set(STEPS):
        raise ValueError(f'Missing assembly stages: {set(STEPS) - set(by_stage)}')
    for stage in STEPS:
        fields.extend(key for key in by_stage[stage] if key not in fields)
    rows = [dict(by_stage[stage], Step=label) for stage, label in STEPS.items()]
    write_csv('quality_trace.csv', rows, fields)
    final = {'file': assembly_name, **{key: value for key, value in by_stage['fcs_final'].items() if key != 'Step'}}
    write_csv('quality_final.csv', [final], ['file'] + fields[1:])


if __name__ == '__main__':
    if len(sys.argv) == 5 and sys.argv[1] == 'metrics':
        metrics(*sys.argv[2:])
    elif len(sys.argv) >= 4 and sys.argv[1] == 'merge':
        merge(sys.argv[2], sys.argv[3:])
    else:
        sys.exit('Usage: collect_quality.py metrics STAGE COMPLEASM QUAST | merge ASSEMBLY METRICS...')

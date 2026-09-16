"""Run with python -m unittest discover -s tests -p 'test_*.py'."""
import csv
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('quality', Path(__file__).resolve().parents[1] / 'bin/collect_quality.py')
quality = importlib.util.module_from_spec(spec)
spec.loader.exec_module(quality)


class QualityReports(unittest.TestCase):
    def test_parse_and_merge(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = Path.cwd()
            os.chdir(directory)
            try:
                Path('summary.txt').write_text('## compleasm version: 0.2.9\n## lineage: eukaryota_odb12\nS:90%, 90\nD:2%, 2\nF:3%, 3\nI:0%, 0\nM:5%, 5\nN:100\n')
                Path('quast.tsv').write_text('Assembly\tsample\nN50\t1000\nGC (%)\t50.2\nMetric, with comma\tvalue, with comma\n')
                files = []
                for stage in quality.STEPS:
                    quality.metrics(stage, 'summary.txt', 'quast.tsv')
                    files.append(f'{stage}_metrics.csv')
                quality.merge('sample.fasta.gz', list(reversed(files)))
                with open('quality_trace.csv') as handle:
                    rows = list(csv.DictReader(handle))
                self.assertEqual([row['Step'] for row in rows], list(quality.STEPS.values()))
                self.assertEqual(rows[0]['Metric, with comma'], 'value, with comma')
                self.assertEqual(rows[0]['S'], '90%')
                self.assertEqual(rows[0]['I'], '0%')
                with open('quality_final.csv') as handle:
                    self.assertEqual(next(csv.DictReader(handle))['file'], 'sample.fasta.gz')
                with self.assertRaises(ValueError):
                    quality.merge('sample.fasta.gz', files[:-1])
                with self.assertRaises(ValueError):
                    quality.merge('sample.fasta.gz', files + [files[0]])
                Path('summary.txt').write_text('## lineage: eukaryota\nS:90%\n')
                with self.assertRaises(ValueError):
                    quality.metrics('metamdbg', 'summary.txt', 'quast.tsv')
            finally:
                os.chdir(previous)


if __name__ == '__main__':
    unittest.main()

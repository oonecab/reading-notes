import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
ROOT = Path(__file__).resolve().parents[1]
class LocalVerificationTests(unittest.TestCase):
    def test_doctor_reports_operation_specific_blockers(self):
        result = subprocess.run([sys.executable, str(ROOT/'tools/project.py'), 'doctor'], cwd=ROOT, capture_output=True, text=True, encoding='utf-8')
        report = json.loads(result.stdout)
        self.assertIn('operations', report)
        if os.name == 'nt':
            self.assertEqual(report['operations']['full']['status'], 'blocked')
            self.assertEqual(report['operations']['release']['status'], 'blocked')
            self.assertNotEqual(result.returncode, 0)
    def test_local_command_is_explicitly_available(self):
        result = subprocess.run([sys.executable, str(ROOT/'tools/project.py'), '--help'], cwd=ROOT, capture_output=True, text=True, encoding='utf-8')
        self.assertIn('check-local', result.stdout)
    def test_missing_browser_only_blocks_browser_build(self):
        from project import operation_requirements
        facts = dict.fromkeys(['python','node','pnpm','dependencies','pdftotext','pdfinfo','posix','termios','directory_sync','rsync','clang','make','racket','linux','nginx','openssl','browser-driver'], True)
        facts['browser-driver'] = False
        report = operation_requirements(facts)
        self.assertEqual(report['local']['status'], 'prerequisites_met')
        self.assertEqual(report['build']['missing'], ['browser-driver'])
        self.assertFalse(report['local']['runtime_verified'])
    def test_full_commands_retain_publication_gates(self):
        from project import check_commands, load_books
        full = check_commands(load_books(), True, False, ROOT/'tmp/unused', False)
        local = check_commands(load_books(), True, False, ROOT/'tmp/unused', True)
        names = lambda rows: {Path(str(row[1])).name for row in rows}
        for name in ['test_publish_durability.py', 'test_publish_policy.py', 'test_cache_delivery.py']:
            self.assertIn(name, names(full))
            self.assertNotIn(name, names(local))
        for name in ['check_structure.py', 'test_http_verification.py', 'check-presentation-contract.mjs', 'check_astro_records.py']:
            self.assertIn(name, names(local))
        self.assertTrue(all('--quick' in row for row in local if 'csapp' in str(row)))
if __name__ == '__main__': unittest.main()

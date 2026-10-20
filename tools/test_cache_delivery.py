"""Cache correctness regressions independent of wall-clock speed and HTML content."""
import gzip
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT/'deploy'), str(ROOT/'deploy/scripts')]
from public_policy import inspect, precompress
from cache_validators import assign_validators
from http_checks import probe_release
from publish_release import verified
from public_policy import sums


def rows(site):
    return [{'path': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'bytes': p.stat().st_size}
            for p in sorted(site.iterdir())]


class DeliveryTests(unittest.TestCase):
    def test_equal_size_representations_share_a_url_but_never_a_strong_etag(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);site=root/'site';site.mkdir()
            # Synthetic same-size bytes isolate the validator contract; gzip
            # validity is checked separately by the publication policy tests.
            (site/'index.html').write_bytes(b'first')
            (site/'index.html.gz').write_bytes(b'other')
            assign_validators(root,site,rows(site),now=1700000000)
            self.assertNotEqual((site/'index.html').stat().st_mtime,(site/'index.html.gz').stat().st_mtime)

    def test_historical_policy_is_trusted_only_when_installed_and_hash_bound(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);site=root/'release/site';site.mkdir(parents=True)
            (site/'index.html').write_text('historical content')
            policy={'files':[{'path':'index.html','mode':'copy'}], 'authorized_pdfs':[], 'authorized_pdf_sha256':{}}
            blob=json.dumps(policy).encode();digest=hashlib.sha256(blob).hexdigest()
            (root/'release/release.json').write_text(json.dumps({'release_id':'20261017T210828','files':rows(site),'publish_policy_sha256':digest}))
            (root/'release/SHA256SUMS').write_text(sums(rows(site)))
            policies=root/'policies';policies.mkdir()
            with patch('publish_release.DEPLOY',root):
                with self.assertRaisesRegex(ValueError,'not installed'):verified(root/'release')
                (policies/(digest+'.json')).write_bytes(blob)
                verified(root/'release')
                (policies/(digest+'.json')).write_text('{}')
                with self.assertRaisesRegex(ValueError,'not installed'):verified(root/'release')

    def test_identical_content_reuses_validator_changed_same_size_never_collides(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);site=root/'site';site.mkdir();p=site/'index.html'
            p.write_bytes(b'first');assign_validators(root, site, rows(site), now=1700000000)
            first=int(p.stat().st_mtime)
            p.write_bytes(b'first');assign_validators(root, site, rows(site), now=1700000000)
            self.assertEqual(int(p.stat().st_mtime), first)
            p.write_bytes(b'other');assign_validators(root, site, rows(site), now=1700000000)
            self.assertNotEqual(int(p.stat().st_mtime), first)
            self.assertLessEqual(p.stat().st_mtime,1700000000)
            p.write_bytes(b'first');assign_validators(root, site, rows(site), now=1700000000)
            self.assertEqual(int(p.stat().st_mtime), first)
            # Removed releases do not erase old validators.
            p.write_bytes(b'third');assign_validators(root, site, rows(site), now=1700000000)
            self.assertNotIn(int(p.stat().st_mtime), [first, first-1])

    def test_initial_ledger_imports_existing_file_mtime_only_after_hash_verification(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);old=root/'releases/20261017T210828';(old/'site').mkdir(parents=True)
            p=old/'site/index.html';p.write_bytes(b'known');os.utime(p,(1600000000,1600000000))
            (old/'release.json').write_text(json.dumps({'files':rows(old/'site')}))
            site=root/'site';site.mkdir();(site/'index.html').write_bytes(b'known')
            assign_validators(root,site,rows(site),now=1700000000)
            self.assertEqual(int((site/'index.html').stat().st_mtime),1600000000)
            ledger=root/'.cache-validators.json';before=ledger.read_bytes()
            with patch('cache_validators.atomic_json',side_effect=OSError('failed flush')):
                (site/'index.html').write_bytes(b'new!!')
                with self.assertRaises(OSError):assign_validators(root,site,rows(site),now=1700000000)
            self.assertEqual(ledger.read_bytes(),before)
            p.write_bytes(b'bad!!')
            with self.assertRaisesRegex(ValueError,'damaged cached'):assign_validators(root,site,rows(site),now=1700000000)

    def test_http_200_with_wrong_body_cannot_pass_health(self):
        blob=b'expected chapter'
        meta={'release_id':'fixture','archive_sha256':'archive','navigation':{},'inline_script_csp_sources':[],
              'files':[{'path':'index.html','bytes':len(blob),'sha256':hashlib.sha256(blob).hexdigest()}]}
        headers={'content-type':'text/html','cache-control':'no-cache'}
        with patch('http_checks.request',return_value=(200,headers,b'old release')):
            with self.assertRaisesRegex(ValueError,'content check failed'):probe_release(meta)
        with patch('http_checks.request',return_value=(200,headers,blob)):
            self.assertEqual(probe_release(meta)['archive_sha256'],'archive')

    def test_deterministic_sidecars_and_exact_allowlist(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);site=root/'site';site.mkdir();p=site/'index.html';p.write_bytes(b'<p>readable page</p>'*300)
            policy={'files':[{'path':'index.html','mode':'copy'}], 'authorized_pdfs':[], 'authorized_pdf_sha256':{},'precompression':{'format':'gzip','level':6,'min_bytes':1024,'extensions':['.html','.css','.json','.svg','.txt','.md','.c','.py']}}
            config=root/'policy.json';config.write_text(json.dumps(policy))
            precompress(site, policy=policy);first=(site/'index.html.gz').read_bytes()
            self.assertEqual(gzip.decompress(first),p.read_bytes())
            precompress(site, policy=policy);self.assertEqual((site/'index.html.gz').read_bytes(),first)
            self.assertEqual(len(inspect(site,policy_path=config)),2)
            (site/'index.html.gz').write_bytes(gzip.compress(b'wrong content',mtime=0))
            with self.assertRaises(ValueError):inspect(site,policy_path=config)
            precompress(site,policy=policy);(site/'private.html.gz').write_bytes(first)
            with self.assertRaises(ValueError):inspect(site,policy_path=config)
            (site/'private.html.gz').unlink();(site/'index.html.gz').unlink()
            with self.assertRaises(ValueError):inspect(site,policy_path=config)


if __name__=='__main__': unittest.main()

#!/usr/bin/env python3
"""Independently check controlled sources, retained mirrors and current review bindings."""
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess

from catalog import ROOT, load_books


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()


def matches_reviewed_output(blob, expected):
    if hashlib.sha256(blob).hexdigest() == expected:
        return True
    # I036 approves only this exact head insertion. Removing it must recover
    # every byte of the independently reviewed output; historical hashes stay intact.
    svg = (ROOT/'portal/favicon.svg').read_bytes()
    if hashlib.sha256(svg).hexdigest() != 'f1ab2a8e135a12be4f93a272888396812665e9e095b3479975bc89237bbc1e86':
        return False
    icon = b'<link rel="icon" href="data:image/svg+xml;base64,' + base64.b64encode(svg) + b'" type="image/svg+xml">'
    head, separator, body = blob.partition(b'</head>')
    if not separator or icon not in head or blob.count(icon) != 1:
        return False
    original = head.replace(icon, b'', 1) + separator + body
    return hashlib.sha256(original).hexdigest() == expected


def main():
    state=json.loads((ROOT/'scripts/migration-state.json').read_text())
    books=load_books();count=0
    revision_file=ROOT/'src/content-revisions.json'
    revisions=json.loads(revision_file.read_text())['pages'] if revision_file.exists() else {}
    for name in state['migrated_books']:
        book=books[name]['root'];review=book/'review'
        files=sorted((ROOT/'src/content/books'/name).glob('*.html'))
        assert len(files)==books[name]['expected_pages'],name
        baseline=json.loads((review/'content-baseline-astro.json').read_text())
        release=json.loads((review/'release-astro.json').read_text())
        records={r['page']:r for r in baseline['records']}
        assert len(records)==len(files),name
        validation=json.loads((review/'validation.json').read_text())
        browser=json.loads((review/'browser.json').read_text())
        migration=json.loads((review/'astro-migration.json').read_text())
        assert migration['status']=='Go' and not migration['open_findings']
        assert not validation.get('open_findings',[]) and not validation['astro_migration']['open_findings']
        for binding in [validation['astro_migration'],browser['astro_migration']]:
            assert sha(book/binding['record'])==binding['sha256'],name
        for path,digest in validation.get('file_sha256',{}).items():
            assert sha(book/path)==digest,(name,path)
        for file in files:
            source=file.read_bytes().decode()
            assert source.startswith('---\n')
            front,body=source[4:].split('\n---\n',1);meta=json.loads(front)
            route=f'{name}/notes/{file.name}';legacy='books/'+route
            assert meta['book']==name and meta['route']==route and meta['legacy_path']==legacy
            for key in ['chapter','title','printed_start','printed_end','pdf_start','pdf_end','exercise_range','statement_count','source_manifest']:
                assert key in meta,(file,key)
            assert (ROOT/meta['source_manifest']).is_file()
            def expand(match):
                return (ROOT/'src'/match[1]).read_bytes().decode()
            expanded=re.sub(r'<!-- RN:include ((?:styles|scripts)/[a-f0-9]{20}\.(?:css|js)) -->',expand,body).encode()
            assert b'RN:include' not in expanded
            ref=state.get('page_baselines',{}).get(route,state.get('book_baselines',{}).get(name,state['baseline_ref']))
            frozen=subprocess.check_output(['git','show',ref+':'+legacy],cwd=ROOT)
            assert expanded==(ROOT/legacy).read_bytes(),route
            digest=hashlib.sha256(expanded).hexdigest()
            historical=hashlib.sha256(frozen).hexdigest()
            assert historical==meta['original_sha256']==records[route]['source_sha256']==validation['astro_migration']['source_sha256'][file.name]
            assert release['files'][route]==records[route]['output_sha256']
            if digest!=historical:
                revision=revisions[route]
                assert revision['original_sha256']==historical and revision['source_sha256']==digest,route
                prior=historical
                for change in revision['history']:
                    assert change['from_sha256']==prior and change['reason'] and change['reviewed_anchors']
                    prior=change['to_sha256']
                assert prior==digest
                reviewed=json.loads((ROOT/revision['review_record']).read_text())
                assert reviewed['source_sha256'][route]==digest
                if (ROOT/'dist'/route).exists():assert matches_reviewed_output((ROOT/'dist'/route).read_bytes(),reviewed['output_sha256'][route]),route
            else:
                assert expanded==frozen,route
                if (ROOT/'dist'/route).exists():assert matches_reviewed_output((ROOT/'dist'/route).read_bytes(),release['files'][route]),route
            count+=1
    print(json.dumps({'status':'passed','controlled_pages':count,'current_review_bindings':'passed','historical_source_snapshot':'preserved','reviewed_revision_pages':len(revisions)}))


if __name__=='__main__': main()

#!/usr/bin/env python3
"""Build the checked registered-book release for notes.zzzping.top."""
from __future__ import annotations

import argparse
import base64
from datetime import datetime
import hashlib
from html.parser import HTMLParser
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urljoin, urlsplit
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from catalog import load_books, local_path
BOOKS = load_books()
STOCHASTIC = BOOKS['stochastic']['root']
sys.path.insert(0, str(STOCHASTIC / 'tools'))
sys.path.insert(0, str(STOCHASTIC / 'deploy'))
from html_support import Document, check_resources
from build_release import INDEX, write_archive
from reader_views import EXTERNAL_LINKS
from publication import FROZEN_BOOKS, configure, build_reader_views, transform_reading_page, entry_page, add_catalog_links, with_site_icon
from public_policy import load_policy, static_include
configure(BOOKS)


class Resources(HTMLParser):
    def __init__(self):
        super().__init__()
        self.references, self.scripts, self.ids, self.links = [], [], set(), []
        self.script = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'a' and attrs.get('href'):
            self.links.append({'href': attrs['href'], 'download': 'download' in attrs})
        if any(k.lower().startswith('on') for k in attrs):
            raise ValueError('Inline event handler in release')
        if tag == 'base':
            raise ValueError('A base element changes relative paths')
        if 'id' in attrs:
            if attrs['id'] in self.ids:
                raise ValueError('Duplicate HTML anchor: ' + attrs['id'])
            self.ids.add(attrs['id'])
        for key in ('href', 'src', 'poster', 'data'):
            if attrs.get(key):
                self.references.append((tag, key, attrs[key]))
        if tag == 'script':
            self.script = ''
        if tag == 'meta' and attrs.get('http-equiv', '').lower() == 'refresh':
            match = re.fullmatch(r'0\s*;\s*url=([\w./-]+)', attrs.get('content', ''), re.I)
            if not match:
                raise ValueError('Unexpected redirect')
            self.references.append(('a', 'href', match[1]))

    def handle_data(self, data):
        if self.script is not None:
            self.script += data

    def handle_endtag(self, tag):
        if tag == 'script' and self.script is not None:
            self.scripts.append(self.script)
            self.script = None


def import_checker(path):
    spec = importlib.util.spec_from_file_location('weiss_portal_checker', path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--release-id', default=datetime.now(ZoneInfo('Asia/Shanghai')).strftime('%Y%m%dT%H%M%S'))
    ap.add_argument('--export-directory', type=Path, help='Export checked legacy blobs under ignored tmp/ for migration')
    args = ap.parse_args()
    if not re.fullmatch(r'\d{8}T\d{6}', args.release_id):
        ap.error('Release ID must be YYYYMMDDTHHMMSS')
    parent = ROOT / 'deploy/portal-releases'
    parent.mkdir(parents=True, exist_ok=True)
    out = parent / args.release_id
    if out.exists() and not args.export_directory:
        ap.error(f'Release already exists: {out}')
    checked = subprocess.run([sys.executable, STOCHASTIC / 'tools/check_notes.py', '--extract-only'],
                             capture_output=True, text=True, check=True)
    stochastic_validation = json.loads(checked.stdout)['extracted']
    source_manifest = json.loads((STOCHASTIC / 'notes/source_manifest.json').read_text())
    programs = json.loads((STOCHASTIC / 'code/programs.json').read_text())
    paths = sorted((STOCHASTIC / 'notes').glob('*.html')) + sorted((STOCHASTIC / 'notes').glob('*.json'))
    paths += [STOCHASTIC / 'code/README.md', STOCHASTIC / 'code/Makefile', STOCHASTIC / 'code/programs.json']
    for program in programs['programs']:
        paths += [STOCHASTIC / p for p in program['files'].values()]
        paths.append((STOCHASTIC / program['files']['c']).parent / 'README.md')
    paths.append(STOCHASTIC / source_manifest['web_pdf']['path'])
    sources = {'stochastic/' + p.relative_to(STOCHASTIC).as_posix(): p for p in paths}
    standalone = {name.removeprefix('stochastic/'): path.read_bytes() for name, path in sources.items()}
    standalone['index.html'] = INDEX
    for name, blob in standalone.items():
        if name.endswith('.html'):
            check_resources(blob.decode(), name, packaged=standalone, allow_entry_refresh=True)
        if name.endswith('.json') and (b'/Users/' in blob or b'file:///' in blob):
            raise ValueError('Machine-local path in public metadata: ' + name)

    weiss = BOOKS['weiss']['root']
    weiss_pages = sorted((weiss / 'notes').glob('*.html'))
    if len(weiss_pages) != BOOKS['weiss']['expected_pages']:
        raise ValueError('Expected the Weiss overview and twelve chapters')
    checker = import_checker(weiss / 'notes/tools/check_notes.py')
    weiss_validation = checker.check([checker.Page(p) for p in weiss_pages])
    if weiss_validation['errors']:
        raise ValueError(weiss_validation['errors'])
    for p in weiss_pages + [weiss / 'notes/README.md', weiss / 'notes/tools/check_notes.py']:
        sources['weiss/notes/' + p.relative_to(weiss / 'notes').as_posix()] = p
    sources['weiss/c/ch8.c'] = weiss / 'c/ch8.c'
    book_validations = {'stochastic': stochastic_validation, 'weiss': weiss_validation}
    if 'csapp' in BOOKS:
        csapp = BOOKS['csapp']['root']
        checked = subprocess.run([sys.executable, csapp / 'tools/check_notes.py', '--quick'],
                                 capture_output=True, text=True, check=True)
        book_validations['csapp'] = json.loads(checked.stdout)['structure']
        csapp_paths = sorted((csapp / 'notes').glob('*.html')) + sorted((csapp / 'notes').glob('*.json'))
        csapp_source = json.loads((csapp / 'notes/source_manifest.json').read_text())
        include_pdf = csapp_source['publication']['include_source_pdf']
        if not isinstance(include_pdf, bool):
            raise ValueError('CSAPP include_source_pdf must be a boolean')
        if include_pdf:
            if csapp_source['source_pdf']['path'] != 'csapp.pdf':
                raise ValueError('Expected the registered CSAPP source PDF path')
            csapp_paths.append(csapp / 'csapp.pdf')
        csapp_paths += [csapp / 'code/README.md', csapp / 'code/programs.json']
        csapp_programs = json.loads((csapp / 'code/programs.json').read_text())
        for program in csapp_programs['programs']:
            csapp_paths.extend(csapp / p for p in program['files'].values())
        csapp_paths.extend(csapp / p for p in csapp_programs.get('additional_sources', []))
        for path in csapp_paths:
            sources['csapp/' + path.relative_to(csapp).as_posix()] = path
    if 'visual-group-theory' in BOOKS:
        group_book = BOOKS['visual-group-theory']['root']
        checked = subprocess.run([sys.executable, group_book / 'tools/check_notes.py', '--quick'],
                                 capture_output=True, text=True, check=True)
        book_validations['visual-group-theory'] = json.loads(checked.stdout)['structure']
        group_source = json.loads((group_book / 'notes/source_manifest.json').read_text())
        if group_source['publication']['include_source_pdf'] is not False:
            raise ValueError('Visual Group Theory is registered for reference-only source use')
        group_paths = sorted((group_book / 'notes').glob('*.html')) + sorted((group_book / 'notes').glob('*.json'))
        group_paths += [group_book / 'code/README.md', group_book / 'code/programs.json']
        for program in json.loads((group_book / 'code/programs.json').read_text())['programs']:
            group_paths.extend(group_book / path for path in program['files'].values())
        for path in group_paths:
            sources['visual-group-theory/' + path.relative_to(group_book).as_posix()] = path
    if 'measure-probability' in BOOKS:
        measure_book = BOOKS['measure-probability']['root']
        checked = subprocess.run([sys.executable, measure_book / 'tools/check_notes.py', '--quick'],
                                 capture_output=True, text=True, check=True)
        book_validations['measure-probability'] = json.loads(checked.stdout)['structure']
        measure_source = json.loads((measure_book / 'notes/source_manifest.json').read_text())
        if measure_source['publication']['include_source_pdf'] is not False:
            raise ValueError('Measure and Probability is registered for reference-only source use')
        measure_paths = sorted((measure_book / 'notes').glob('*.html')) + sorted((measure_book / 'notes').glob('*.json'))
        measure_paths += [measure_book / 'code/README.md', measure_book / 'code/programs.json']
        for program in json.loads((measure_book / 'code/programs.json').read_text())['programs']:
            measure_paths.extend(measure_book / path for path in program['files'].values())
        for path in measure_paths:
            sources['measure-probability/' + path.relative_to(measure_book).as_posix()] = path
    for name in BOOKS.keys() - FROZEN_BOOKS:
        book = BOOKS[name]
        checked = subprocess.run([sys.executable, local_path(book['root'], book['checker']), '--quick'],
                                 capture_output=True, text=True, check=True)
        book_validations[name] = json.loads(checked.stdout)
        # New books publish only explicitly allowed source files. Generated entry
        # and document pages are added below; the final exact allowlist catches omissions.
        prefix = book['publish_prefix'] + '/'
        for row in load_policy()['files']:
            if row['path'].startswith(prefix):
                path = local_path(book['root'], row['path'][len(prefix):])
                if path.is_file():
                    sources[row['path']] = path
    for p in sorted((ROOT / 'portal').iterdir()):
        if p.is_file():
            sources[p.name] = p

    original = {name: p.read_bytes() for name, p in sources.items()}
    blobs = dict(original)
    documents, document_views = build_reader_views(blobs)
    for name in list(blobs):
        if any(name.startswith(book['publish_prefix'] + '/notes/') for book in BOOKS.values()) and name.endswith('.html'):
            blobs[name] = transform_reading_page(
                blobs[name], name, document_views,
                csapp_pdf_included='csapp/csapp.pdf' in original)
    blobs.update(documents)
    blobs['index.html'] = add_catalog_links(blobs['index.html'])
    for name in BOOKS.keys() - FROZEN_BOOKS:
        blobs[f'{name}/index.html'] = entry_page(BOOKS[name])
    blobs['stochastic/index.html'] = INDEX
    blobs['weiss/index.html'] = ('<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<meta http-equiv="refresh" content="0;url=notes/book_overview.html">'
        '<title>Weiss 读书笔记</title></head><body><p>'
        '<a href="notes/book_overview.html">进入 Weiss 全书地图</a></p></body></html>\n').encode()
    if 'csapp' in BOOKS:
        blobs['csapp/index.html'] = ('<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<meta http-equiv="refresh" content="0;url=notes/book_overview.html">'
            '<title>CS:APP 读书笔记</title></head><body><p>'
            '<a href="notes/book_overview.html">进入 CS:APP 全书地图</a></p></body></html>\n').encode()
    if 'visual-group-theory' in BOOKS:
        blobs['visual-group-theory/index.html'] = ('<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<meta http-equiv="refresh" content="0;url=notes/book_overview.html">'
            '<title>视觉群论读书笔记</title></head><body><p>'
            '<a href="notes/book_overview.html">进入视觉群论全书地图</a></p></body></html>\n').encode()

    if 'measure-probability' in BOOKS:
        blobs['measure-probability/index.html'] = ('<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<meta http-equiv="refresh" content="0;url=notes/book_overview.html">'
            '<title>测度论与概率论基础读书笔记</title></head><body><p>'
            '<a href="notes/book_overview.html">进入测度论与概率论全书地图</a></p></body></html>\n').encode()

    blobs = {name: with_site_icon(blob, name) if name.endswith('.html') else blob
             for name, blob in blobs.items()}
    scans, scripts, references = {}, set(), 0
    for name, blob in blobs.items():
        if name.endswith('.html'):
            scan = Resources()
            scan.feed(blob.decode('utf-8'))
            scan.close()
            Document(blob.decode('utf-8'))
            scans[name] = scan
            scripts.update(scan.scripts)
    for name, scan in scans.items():
        for tag, key, ref in scan.references:
            url = urlsplit(ref)
            if url.scheme in {'file', 'javascript', 'vbscript'}:
                raise ValueError(f'{name}: nonportable link {ref}')
            if url.scheme or url.netloc:
                if tag != 'a' and url.scheme != 'data':
                    raise ValueError(f'{name}: external dependency {ref}')
                continue
            target = unquote(urlsplit(urljoin('https://notes.zzzping.top/' + name, ref)).path).lstrip('/')
            if not target or target.endswith('/'):
                target += 'index.html'
            if target not in blobs:
                raise ValueError(f'{name}: missing local resource {ref} => {target}')
            if url.fragment and target in scans and unquote(url.fragment) not in scans[target].ids:
                raise ValueError(f'{name}: missing anchor {ref}')
            references += 1
    navigation = []
    for name, scan in scans.items():
        for item in scan.links:
            resolved = urlsplit(urljoin('https://notes.zzzping.top/' + name, item['href']))
            external = resolved.netloc != 'notes.zzzping.top'
            target = unquote(resolved.path).lstrip('/')
            if not target or target.endswith('/'):
                target += 'index.html'
            navigation.append({'source': name, **item, 'target': target, 'fragment': unquote(resolved.fragment),
                               'external': external})
    node = shutil.which('node')
    if not node:
        raise RuntimeError('Node.js is required for inline-script syntax checks')
    with tempfile.TemporaryDirectory(prefix='portal-js-') as directory:
        for i, script in enumerate(sorted(scripts)):
            p = Path(directory) / f'inline-{i}.js'
            p.write_text(script)
            subprocess.run([node, '--check', p], capture_output=True, text=True, check=True)
    for name, p in sources.items():
        if p.read_bytes() != original[name]:
            raise RuntimeError('Source changed during build: ' + name)
    hashes = ["'sha256-" + base64.b64encode(hashlib.sha256(s.encode()).digest()).decode() + "'" for s in sorted(scripts)]
    records = [{'path': name, 'bytes': len(blob), 'sha256': hashlib.sha256(blob).hexdigest(),
                **({'source_sha256': hashlib.sha256(original[name]).hexdigest()} if name in original else {})}
               for name, blob in sorted(blobs.items())]
    config = static_include((ROOT / 'deploy/nginx-portal-static.inc.template').read_text(), hashes)
    server = (ROOT / 'deploy/nginx-notes.zzzping.top.conf.template').read_text().replace('@@RELEASE_ID@@', args.release_id)
    if args.export_directory:
        destination = args.export_directory.resolve()
        if not destination.is_relative_to(ROOT / 'tmp') or destination.exists():
            raise ValueError('Legacy export must be a new directory under ignored tmp/')
        destination.mkdir(parents=True)
        for name, blob in sorted(blobs.items()):
            path = destination / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(blob)
        (destination.parent / 'legacy-files.json').write_text(json.dumps({
            'files': records, 'inline_script_csp_sources': hashes,
            'document_views': document_views, 'validation': book_validations,
            'entry_redirects': {f'/{book}{suffix}': f'/{book}/notes/book_overview.html'
                                for book in BOOKS for suffix in ('', '/', '/index.html')}
        }, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({'mode':'legacy-export', 'files':len(records)}))
        return
    with tempfile.TemporaryDirectory(prefix='.portal-release-', dir=parent) as directory:
        stage = Path(directory)
        write_archive(stage / 'site.tar.gz', blobs)
        metadata = {'release_id': args.release_id, 'domain': 'notes.zzzping.top',
            'source_layout': {key: book['directory'] for key, book in BOOKS.items()},
            'created_at': datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
            'files': records, 'total_bytes': sum(r['bytes'] for r in records),
            'html_pages': len(scans), 'reading_pages': sum(b['expected_pages'] for b in BOOKS.values()), 'local_references_checked': references,
            'archive_sha256': hashlib.sha256((stage / 'site.tar.gz').read_bytes()).hexdigest(),
            'inline_script_csp_sources': hashes, 'inline_script_syntax_check': 'pass',
            'navigation': {key: book['publish_prefix'] + '/' + book['entry'] for key, book in BOOKS.items()},
            'entry_redirects': {f'/{book}{suffix}': f'/{book}/notes/book_overview.html'
                                for book in BOOKS for suffix in ('', '/', '/index.html')},
            'document_views': document_views, 'document_pages': sum(name.endswith('.html') for name in documents),
            'external_link_replacements': EXTERNAL_LINKS,
            'navigation_inventory_file': 'navigation.json', 'navigation_links': len(navigation),
            'page_transformation': 'Add persistent reading navigation, header and footer home links, reader document views and overview run instructions; original mathematical statements and C/Python implementations preserved.',
            'validation': book_validations}
        (stage / 'release.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
        (stage / 'navigation.json').write_text(json.dumps(navigation, ensure_ascii=False, indent=2) + '\n')
        (stage / 'SHA256SUMS').write_text(''.join(f"{r['sha256']}  {r['path']}\n" for r in records))
        (stage / 'archive.sha256').write_text(metadata['archive_sha256'] + '  site.tar.gz\n')
        (stage / 'nginx-static.inc').write_text(config)
        (stage / 'nginx-notes.zzzping.top.conf').write_text(server)
        stage.rename(out)
    print(json.dumps({'release_id': args.release_id, 'directory': str(out), 'files': len(records),
        'html_pages': len(scans), 'reading_pages': metadata['reading_pages'], 'bytes': metadata['total_bytes'],
        'local_references_checked': references, 'inline_scripts': len(scripts),
        'document_pages': metadata['document_pages'], 'navigation_links': len(navigation)}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()

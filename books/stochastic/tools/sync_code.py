#!/usr/bin/env python3
"""Check or synchronize the reading copies of standalone C/Python programs."""
from __future__ import annotations

import argparse
from html import escape
import json
from pathlib import Path
import re
import os
import tempfile
from html_support import Document

ROOT = Path(__file__).resolve().parents[1]


def program_sources():
    manifest = json.loads((ROOT / 'code/programs.json').read_text())
    programs = manifest['programs']
    identities, paths = set(), set()
    sources = {}
    for program in programs:
        name = program['id']
        if name in identities or not re.fullmatch(r'[a-z][a-z0-9_]*', name):
            raise ValueError(f'Invalid or duplicate program: {name}')
        identities.add(name)
        page = ROOT / program['page']
        if page.parent != ROOT / 'notes' or page.suffix != '.html' or not page.is_file():
            raise ValueError(f'Invalid reading page: {page}')
        if set(program['files']) != {'c', 'python'}:
            raise ValueError(f'Expected C/Python pair: {name}')
        for language, relative in program['files'].items():
            path = ROOT / relative
            expected_suffix = '.c' if language == 'c' else '.py'
            if ROOT / 'code' not in path.resolve().parents or path.suffix != expected_suffix:
                raise ValueError(f'Invalid source path: {relative}')
            if relative in paths:
                raise ValueError(f'Duplicate source path: {relative}')
            paths.add(relative)
            raw = path.read_bytes()
            source = raw.decode('utf-8')
            if not source.endswith('\n') or '\r' in source:
                raise ValueError(f'Use UTF-8 and LF with a final newline: {relative}')
            sources[name, language] = source
    return programs, sources


def synchronize(write=False):
    programs, sources = program_sources()
    bindings = {}
    for program in programs:
        for language in program['files']:
            suffix = 'c' if language == 'c' else 'python'
            bindings.setdefault(program['page'], {})[program['id'] + '-' + suffix] = (
                program['id'], language)
    extra = json.loads((ROOT / 'code/programs.json').read_text()).get('additional_code_blocks', {})
    differences = []
    changed = []
    for path in sorted((ROOT / 'notes').glob('*.html')):
        relative = path.relative_to(ROOT).as_posix()
        expected = bindings.get(relative, {})
        original = path.read_text()
        seen = set()
        edits = []
        document = Document(original)
        inline = set()

        def collect_inline(node, ancestors=()):
            if node.tag == 'code' and 'pre' not in ancestors and any(
                    tag in {'p', 'li', 'td', 'th', 'figcaption', 'summary',
                            'h1', 'h2', 'h3', 'h4', 'h5', 'h6'} for tag in ancestors):
                if not node.attrs.get('id') and not node.attrs.get('data-language'):
                    inline.add(id(node))
            for child in node.children:
                if not isinstance(child, str):
                    collect_inline(child, ancestors + (node.tag,))

        collect_inline(document.root)
        for block in document.root.walk('code'):
            # Prose references such as a filename are not executable listings.
            # Every preformatted or explicitly identified program stays registered.
            if id(block) in inline:
                continue
            identity = block.attrs.get('id')
            if identity in seen:
                raise ValueError(f'Duplicate code block: {relative}#{identity}')
            if identity not in expected and identity not in extra.get(relative, {}):
                raise ValueError(f'Unregistered code block: {relative}#{identity}')
            seen.add(identity)
            language = expected[identity][1] if identity in expected else extra[relative][identity]
            if block.attrs.get('data-language') != language:
                raise ValueError(f'Wrong code language: {relative}#{identity}')
            if identity not in expected:
                continue
            source = sources[expected[identity]]
            if block.text() == source:
                continue
            differences.append(f'{relative}#{identity}')
            edits.append((block.content_start, block.content_end, escape(source, quote=False)))
        if seen != set(expected) | set(extra.get(relative, {})):
            raise ValueError(f'Missing code blocks: {relative}: {sorted(set(expected) - seen)}')
        updated = original
        for lo, hi, replacement in reversed(edits):
            updated = updated[:lo] + replacement + updated[hi:]
        if write and updated != original:
            with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=path.parent, delete=False) as temporary:
                temporary.write(updated)
                temporary_path = temporary.name
            os.chmod(temporary_path, path.stat().st_mode & 0o777)
            os.replace(temporary_path, path)
            changed.append(relative)
    return {'program_pairs': len(programs), 'source_files': len(sources),
            'differences': differences, 'updated_pages': changed}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='Update HTML from standalone files')
    args = parser.parse_args()
    result = synchronize(args.write)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if result['differences'] and not args.write:
        raise SystemExit('Source and HTML differ; run python3 tools/sync_code.py --write')


if __name__ == '__main__':
    main()

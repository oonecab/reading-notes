#!/usr/bin/env python3
"""Synchronize only the marked teaching-code copies; never rewrite questions or results."""
import argparse
import html
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    source = (ROOT / 'books/sicp/code/chapter01.rkt').read_text(encoding='utf8').rstrip()
    page = ROOT / 'src/content/books/sicp/chapter01_procedures.html'
    previous = page.read_text(encoding='utf8')

    def replace(match):
        name, body = match.groups()
        snippet = re.search(r';; BEGIN ' + re.escape(name) + r'\n(.*?);; END ' + re.escape(name), source, re.S)
        if snippet is None:
            raise ValueError('Unknown snippet: ' + name)
        code = html.escape(snippet[1].rstrip())
        updated, count = re.subn(r'(<pre><code>).*?(</code></pre>)', lambda m: m[1] + code + m[2], body, flags=re.S)
        if count != 1:
            raise ValueError('Expected one code block: ' + name)
        return '<!-- SICP:snippet ' + name + ' -->' + updated + '<!-- /SICP:snippet -->'

    current, count = re.subn(r'<!-- SICP:snippet ([\w-]+) -->(.*?)<!-- /SICP:snippet -->', replace, previous, flags=re.S)
    if count != 12:
        raise ValueError('Expected twelve registered teaching units')
    current, count = re.subn(r'(<!-- SICP:full-source --><pre><code>).*?(</code></pre><!-- /SICP:full-source -->)',
                             lambda m: m[1] + html.escape(source) + m[2], current, flags=re.S)
    if count != 1:
        raise ValueError('Full source copy missing')
    if current != previous:
        if not args.write:
            raise ValueError('Teaching copies differ; run with --write then sync-legacy')
        page.write_text(current, encoding='utf8', newline='\n')
    print('SICP chapter1 teaching-code copies match')


if __name__ == '__main__':
    main()

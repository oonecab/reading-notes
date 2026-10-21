#!/usr/bin/env python3
"""复用受控 HTML 展开器，同步 EOPL 阅读镜像与可执行源码。"""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
BOOK = ROOT / "books/eopl"
SOURCE = ROOT / "src/content/books/eopl"


def sync(write: bool = False) -> dict:
    program = (BOOK / "code/scope_demo.py").read_text()
    preface = SOURCE / "preface.html"
    text = preface.read_text()
    replacement = ('<!-- EOPL:code-start -->\n<pre><code id="scope-demo-code" '
                   'class="language-python">' + html.escape(program) +
                   '</code></pre>\n<!-- EOPL:code-end -->')
    updated, count = re.subn(r"<!-- EOPL:code-start -->.*?<!-- EOPL:code-end -->",
                            lambda _: replacement, text, flags=re.S)
    if count != 1:
        raise ValueError("expected exactly one maintained code block")
    if updated != text:
        if not write:
            raise ValueError("preface code copy differs; run sync_notes.py --write")
        preface.write_text(updated)
    for chapter in sorted(SOURCE.glob("chapter*.html")):
        source = chapter.read_text()
        def snippet(match):
            filename, block = match.group(1), match.group(2)
            program = (BOOK / "code" / filename).read_text()
            found = re.search(r"^;; BEGIN " + re.escape(block) + r"\n(.*?)^;; END " +
                              re.escape(block) + r"$", program, re.S | re.M)
            if found is None:
                raise ValueError(f"missing program region: {filename} {block}")
            return (f'<!-- EOPL:snippet {filename} {block} -->\n'
                    f'<details class="code-details" open><summary>查看实现 · {block}</summary>'
                    '<pre><code class="language-scheme">' + html.escape(found[1]) +
                    '</code></pre></details>\n<!-- EOPL:end-snippet -->')
        updated = re.sub(r"<!-- EOPL:snippet (\S+) (\S+) -->.*?<!-- EOPL:end-snippet -->",
                         snippet, source, flags=re.S)
        def complete(match):
            filename = match[1]
            program = (BOOK / "code" / filename).read_text()
            ident = Path(filename).stem + "-code"
            return (f'<!-- EOPL:program {filename} --><pre><code id="{ident}" '
                    'class="language-scheme">' + html.escape(program) +
                    '</code></pre><!-- EOPL:end-program -->')
        updated = re.sub(r"<!-- EOPL:program (\S+) -->.*?<!-- EOPL:end-program -->",
                         complete, updated, flags=re.S)
        if source != updated:
            if not write:
                raise ValueError(f"program copy differs: {chapter.name}")
            chapter.write_text(updated)
    js = """
import {readSource,syncMirrors} from './src/lib/controlled-html.mjs';
import fs from 'node:fs';
const names=fs.readdirSync('src/content/books/eopl').filter(n=>n.endsWith('.html'));
const pages=names.map(n=>readSource(`src/content/books/eopl/${n}`));
syncMirrors(pages,{write:process.argv[1]==='write'});
console.log(JSON.stringify({status:'passed',pages:pages.length}));
"""
    result = subprocess.run(["node", "--input-type=module", "-e", js,
                             "write" if write else "check"], cwd=ROOT,
                            capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    print(json.dumps(sync(parser.parse_args().write), ensure_ascii=False))

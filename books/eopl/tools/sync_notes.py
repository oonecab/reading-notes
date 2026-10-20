#!/usr/bin/env python3
"""准备批：复用受控 HTML 展开器，维护两份离线镜像。"""
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
    js = """
import {readSource,syncMirrors} from './src/lib/controlled-html.mjs';
const names=['book_overview','preface'];
const pages=names.map(n=>readSource(`src/content/books/eopl/${n}.html`));
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

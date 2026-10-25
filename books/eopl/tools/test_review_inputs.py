#!/usr/bin/env python3
"""Execute the exact reader-facing repair examples with their downloadable modules."""
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from sync_notes import BOOK


def run(racket, run_dir):
    run_dir = Path(run_dir)
    run_dir.mkdir(parents=True, exist_ok=True)
    expected = {
        "known-procedure-example": "(0 10 1 3)\n(1 10 1 2)\n(2 10 0 2)\n",
        "thread-synchronization-example": "((2 0) 0)\n(45 0)\n((1 2) 0)\n",
        "defunctionalization-example": "(#f 5)\n(#t 5)\n",
        "register-pipeline-example": "(100 1114 18)\n",
    }
    results = []
    with tempfile.TemporaryDirectory(prefix="downloaded-modules-", dir=run_dir) as temp:
        folder = Path(temp)
        for source in (BOOK / "code").glob("*.rkt"):
            shutil.copy2(source, folder / source.name)
        for page in (BOOK / "notes").glob("*.html"):
            for name, encoded in re.findall(
                r'<code class="language-scheme" data-review-example="([^"]+)">(.*?)</code>',
                page.read_text(), re.S
            ):
                source = html.unescape(encoded)
                script = folder / f"{name}.rkt"
                script.write_text("#lang racket\n" + source)
                completed = subprocess.run([racket, str(script)], capture_output=True,
                                           text=True, timeout=30)
                (run_dir / f"{name}.log").write_text(completed.stdout + completed.stderr)
                if completed.returncode or completed.stdout != expected.get(name):
                    raise AssertionError((name, completed.returncode, completed.stdout, completed.stderr))
                results.append(dict(name=name, page=page.name, stdout=completed.stdout,
                                    source_sha256=hashlib.sha256(source.encode()).hexdigest()))
    if sorted(r["name"] for r in results) != sorted(expected):
        raise AssertionError("missing or duplicate reader examples")
    report = dict(status="passed", cases=results)
    (run_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    return report

#!/usr/bin/env python3
"""Check the book registry, maintained Python syntax and documentation links."""
from __future__ import annotations

import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote, urlsplit

from catalog import ROOT, load_books


def main() -> None:
    books = load_books()
    state = json.loads((ROOT / 'scripts/migration-state.json').read_text(encoding='utf8'))
    refs = {state['baseline_ref'], *state.get('book_baselines', {}).values(),
            *state.get('page_baselines', {}).values()}
    for ref in sorted(refs):
        result = subprocess.run(['git', 'merge-base', '--is-ancestor', ref, 'HEAD'],
                                cwd=ROOT, capture_output=True, text=True)
        if result.returncode:
            raise ValueError(f'Build source snapshot must travel with HEAD history: {ref}')
    sources = [*ROOT.glob("tools/*.py"), *ROOT.glob("deploy/*.py")]
    for book in books.values():
        sources += [p for p in book["root"].rglob("*.py")
                    if not any(part in {"tmp", "bin", "build", "__pycache__", "releases", "reports"}
                               for part in p.relative_to(book["root"]).parts)]
    for path in sources:
        ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    provenance = json.loads((books["weiss"]["root"] / "source_manifest.json").read_text())
    records = [provenance["source_pdf"], provenance["original_code_archive"], *provenance["original_figures"]]
    if len(provenance["original_figures"]) != 171:
        raise ValueError("Expected 171 original Weiss figure sources")
    for record in records:
        blob = (books["weiss"]["root"] / record["path"]).read_bytes()
        if len(blob) != record["bytes"] or hashlib.sha256(blob).hexdigest() != record["sha256"]:
            raise ValueError(f"Weiss source identity differs: {record['path']}")
    for path in (books["stochastic"]["root"] / "notes").glob("*.json"):
        data = json.loads(path.read_text())
        for name in data.get("files", {}):
            if any(part in {".DS_Store", "__pycache__", "tmp", "bin", "build", "releases", "reports"}
                   for part in Path(name).parts):
                raise ValueError(f"Ephemeral file in current source bindings: {path.name} -> {name}")
    documents = [ROOT / "README.md", ROOT / "TECH.md", ROOT / "AGENTS.md", ROOT / "deploy/README.md"]
    for folder in ("docs", "issues", "plan", "milestone", "test"):
        documents += list((ROOT / folder).rglob("*.md"))
    for book in books.values():
        documents.append(book["root"] / "README.md")
    links = 0
    for path in documents:
        content = path.read_text(encoding="utf-8")
        if re.search(r"/Users/[^\s)`]+|file:///", content):
            raise ValueError(f"Machine-specific path in maintained documentation: {path.relative_to(ROOT)}")
        # Fenced examples may contain illustrative paths; actual Markdown links must resolve.
        content = re.sub(r"```.*?```", "", content, flags=re.S)
        for match in re.finditer(r"\[[^\]\n]+\]\(([^)\n]+)\)", content):
            target = urlsplit(match[1].strip("<>"))
            if target.scheme or target.netloc or not target.path:
                continue
            destination = (path.parent / unquote(target.path)).resolve()
            if ROOT not in destination.parents or not destination.exists():
                raise ValueError(f"Broken documentation link: {path.relative_to(ROOT)} -> {match[1]}")
            links += 1
    config = json.loads((ROOT / ".project-governance.json").read_text(encoding="utf-8"))
    for name in config["technology"]["source_directories"]:
        if not (ROOT / name).is_dir():
            raise ValueError(f"Missing registered source directory: {name}")
    if not config["commands"]["test"]:
        raise ValueError("No registered test command")
    if "@AGENTS.md" not in (ROOT / "CLAUDE.md").read_text():
        raise ValueError("Claude adapter must import the shared instructions")
    print(json.dumps({"status": "pass", "books": len(books), "python_sources": len(sources),
                      "documentation_links": links}, ensure_ascii=False))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Reading Notes 的环境、校验、构建与本地预览入口。"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from functools import partial
import http.server
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit

from catalog import ROOT, load_books
from release_support import extract_release


def doctor() -> int:
    required = {"python3": "Python 3.10+", "clang": "C11 / ASan / UBSan", "make": "C 图例构建",
                "pdftotext": "原书页码核对", "pdfinfo": "原书总页数核对", "node": "Node 24.21.0 LTS 静态构建", "pnpm": "pnpm 11.21.0 锁定依赖"}
    found = {name: shutil.which(name) is not None for name in required}
    optional = {name: shutil.which(name) is not None for name in ("nginx", "openssl")}
    versions = {n: subprocess.check_output([n, "--version"], text=True).strip() if found[n] else None for n in ("node", "pnpm")}
    version_ok = sys.version_info >= (3, 10) and versions == {"node": "v24.21.0", "pnpm": "11.21.0"}
    print(json.dumps({"python": sys.version.split()[0], "pinned_versions_ok": version_ok, "build_versions": versions,
                      "required": {name: {"purpose": required[name], "available": ok} for name, ok in found.items()},
                      "local_https_verification": optional}, ensure_ascii=False, indent=2))
    return 0 if all(found.values()) and version_ok else 1


def check(book_id: str, quick: bool, benchmarks: bool) -> int:
    books = load_books()
    selected = books if book_id == "all" else {book_id: books[book_id]}
    parent = ROOT / "tmp/project-check"
    parent.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix=datetime.now().strftime("%Y%m%dT%H%M%S-") , dir=parent))
    commands = [[sys.executable, ROOT / "tools/check_structure.py"],
                [sys.executable, ROOT / "tools/test_release_support.py"],
                [sys.executable, ROOT / "tools/test_reader_views.py"]]
    commands.extend([[sys.executable, ROOT / "tools/test_publish_durability.py"],
                     [sys.executable, ROOT / "tools/test_publish_policy.py"]])
    commands.append([sys.executable, ROOT / "tools/test_cache_delivery.py"])
    commands.append([sys.executable, ROOT / "tools/test_http_verification.py"])
    if "stochastic" in selected:
        base = selected["stochastic"]["root"]
        commands += [[sys.executable, base / "tools/check_review_records.py"],
                     [sys.executable, ROOT / "test/test_stochastic_derivations.py"],
                     [sys.executable, base / "tools/check_notes.py", "--extract-only", "--run-dir", run / "stochastic-structure"]]
        if not quick:
            commands.append([sys.executable, base / "tools/check_notes.py", "--run-dir", run / "stochastic"])
    if "weiss" in selected:
        base = selected["weiss"]["root"]
        commands.append([sys.executable, base / "notes/tools/check_notes.py"])
        if not quick:
            commands.append(["make", "-C", base / "c", "check"])
            command = [sys.executable, base / "notes/tools/check_notes.py", "--verify", run / "weiss"]
            if benchmarks:
                command.append("--benchmarks")
            commands.append(command)
    if "csapp" in selected:
        command = [sys.executable, selected["csapp"]["root"] / "tools/check_notes.py",
                   "--run-dir", run / "csapp"]
        if quick:
            command.append("--quick")
        commands.append(command)
    if "visual-group-theory" in selected:
        commands.append([sys.executable, ROOT / "test/test_vgt_source_diagram.py"])
        command = [sys.executable, selected["visual-group-theory"]["root"] / "tools/check_notes.py",
                   "--run-dir", run / "visual-group-theory"]
        if quick:
            command.append("--quick")
        commands.append(command)
    if "measure-probability" in selected:
        command = [sys.executable, selected["measure-probability"]["root"] / "tools/check_notes.py",
                   "--run-dir", run / "measure-probability"]
        if quick:
            command.append("--quick")
        commands.append(command)
    if "eopl" in selected:
        command = [sys.executable, selected["eopl"]["root"] / "tools/check_notes.py",
                   "--run-dir", run / "eopl"]
        if quick:
            command.append("--quick")
        commands.append(command)
    commands.append(["node", ROOT / "tools/reading-components/check.mjs"])
    commands.append(["node", ROOT / "tools/reader-contract/check.mjs"])
    commands.append(["node", ROOT / "tools/reading-typography/check.mjs"])
    commands.append(["node", ROOT / "tools/reading-presentation/check.mjs"])
    commands.append([sys.executable, ROOT / "tools/check_astro_records.py"])
    report = {"status": "running", "book": book_id, "quick": quick, "benchmarks": benchmarks,
              "started_at": datetime.now(timezone.utc).isoformat(), "checks": []}
    evidence = run / "report.json"
    for index, command in enumerate(commands):
        args = [str(arg) for arg in command]
        readable = [arg.replace(str(ROOT) + "/", "") for arg in args]
        print("执行：" + " ".join(readable), flush=True)
        result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
        log = run / f"check-{index + 1:02d}.log"
        log.write_text(result.stdout + result.stderr, encoding="utf-8")
        report["checks"].append({"command": readable, "exit_code": result.returncode,
                                 "log": log.relative_to(ROOT).as_posix()})
        if result.returncode:
            report["status"] = "failed"
            print((result.stdout + result.stderr)[-6000:], file=sys.stderr)
        evidence.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        if result.returncode:
            print("验证记录：" + evidence.relative_to(ROOT).as_posix(), flush=True)
            return result.returncode
        print("通过", flush=True)
    report.update(status="passed", finished_at=datetime.now(timezone.utc).isoformat())
    evidence.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("验证记录：" + evidence.relative_to(ROOT).as_posix(), flush=True)
    return 0


def release_directory(release_id: str) -> Path:
    if not re.fullmatch(r"\d{8}T\d{6}", release_id):
        raise ValueError("Release ID must be YYYYMMDDTHHMMSS")
    release = ROOT / "deploy/portal-releases" / release_id
    if not (release / "release.json").is_file():
        raise ValueError(f"Release does not exist: {release_id}")
    return release


def build(release_id: str | None) -> Path:
    command = [sys.executable, str(ROOT / "deploy/build_astro.py")]
    if release_id:
        command += ["--release-id", release_id]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        print(result.stdout + result.stderr, file=sys.stderr)
        raise RuntimeError("Release build failed")
    print(result.stdout, end="", flush=True)
    return Path(json.loads(result.stdout)["directory"])


def serve(release: Path, port: int) -> None:
    parent = ROOT / "tmp/preview"
    parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=release.name + "-", dir=parent) as temporary:
        site = Path(temporary) / "site"
        metadata = extract_release(release, site)
        scripts = " ".join(metadata["inline_script_csp_sources"])
        policy = (f"default-src 'self'; script-src 'self' {scripts}; style-src 'self' 'unsafe-inline'; "
                  "img-src 'self' data:; font-src 'self' data:; connect-src 'self'; object-src 'self'; "
                  "base-uri 'self'; frame-ancestors 'none'; form-action 'self'")

        class Preview(http.server.SimpleHTTPRequestHandler):
            extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                              ".c": "text/plain", ".py": "text/plain", ".md": "text/plain"}

            def end_headers(self):
                self.send_header("Cache-Control", "no-cache")
                self.send_header("X-Content-Type-Options", "nosniff")
                self.send_header("Content-Security-Policy", policy)
                super().end_headers()

            def send_head(self):
                parts = urlsplit(self.path)
                if any(part.startswith(".") for part in parts.path.split("/") if part):
                    self.send_error(404)
                    return None
                if parts.path in metadata["entry_redirects"]:
                    self.send_response(301)
                    self.send_header("Location", metadata["entry_redirects"][parts.path] +
                                     ("?" + parts.query if parts.query else ""))
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    return None
                return super().send_head()

            def list_directory(self, path):
                self.send_error(404)
                return None

        with http.server.ThreadingHTTPServer(("127.0.0.1", port), partial(Preview, directory=str(site))) as server:
            print(f"预览地址：http://127.0.0.1:{server.server_port}/ （Ctrl+C 停止）", flush=True)
            try:
                server.serve_forever()
            except KeyboardInterrupt:
                pass


def main() -> int:
    if sys.version_info < (3, 10):
        print("Reading Notes 需要 Python 3.10 或更高版本；请先选择正确的 python3。", file=sys.stderr)
        return 1
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="action", required=True)
    subs.add_parser("doctor", help="检查环境；不安装或升级软件")
    subs.add_parser("preview-components", help="生成 I039 内容组件样章，仅写入 tmp/reading-components-preview")
    p = subs.add_parser("check", help="运行登记的结构与程序检查")
    p.add_argument("--book", choices=("all", *load_books()), default="all")
    p.add_argument("--quick", action="store_true", help="仅结构、链接、代码同步和审阅记录检查")
    p.add_argument("--benchmarks", action="store_true", help="另核对 Weiss 已登记的实验计数与关闭断言模式")
    p = subs.add_parser("build", help="构建统一站点；已有版本不会覆盖")
    p.add_argument("--release-id")
    p = subs.add_parser("serve", help="从正式发布包预览；省略版本时先构建")
    p.add_argument("--release-id")
    p.add_argument("--port", type=int, default=8000)
    p = subs.add_parser("verify-release", help="在临时本地 Nginx 上检查 HTTPS、哈希、CSP 与旧入口")
    p.add_argument("--release-id", required=True)
    args = parser.parse_args()
    try:
        if args.action == "doctor":
            return doctor()
        if args.action == "preview-components":
            return subprocess.run(["node", ROOT / "tools/reading-components/preview.mjs"], cwd=ROOT).returncode
        if args.action == "check":
            if args.quick and args.benchmarks:
                parser.error("--benchmarks requires the full check")
            return check(args.book, args.quick, args.benchmarks)
        if args.action == "build":
            build(args.release_id)
        elif args.action == "serve":
            if not 0 <= args.port <= 65535:
                parser.error("port must be between 0 and 65535")
            serve(release_directory(args.release_id) if args.release_id else build(None), args.port)
        elif args.action == "verify-release":
            result = subprocess.run([sys.executable, ROOT / "tools/verify_local_release.py", "--release-dir",
                                     release_directory(args.release_id)], cwd=ROOT)
            return result.returncode
    except (ValueError, RuntimeError, OSError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

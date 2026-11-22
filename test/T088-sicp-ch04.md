# T088 · 第 4 章本地验收

印刷页 487–665 对应 PDF 515–693。独立从 PDF 提取 79 个题首，原文档引用边界与中文页题号、给定程序、共享锚点分别核对。第 4 章检查器的八个破坏性夹具覆盖题目、共享输入、程序、图、摘录、裸代码、深链接与教学示例。

候选、正式源与正式产物在 Chrome 离线模式下分别打开。视口为 1800、1440、1024、390 像素有脚本，以及 1440、390 像素无脚本。逐个视图核对题号索引、首末题、图 4.5、习题 4.20 公式、代码折叠、目录和页面宽度。

初次全站同步时书目仍登记五页，登记第六页后重新执行。首次启动三项 dist 检查时构建仍在打包，第 4 章尚未写入 dist；等待构建结束后重新执行。首次根检查发现本测试文件尚未写入，生成记录后重新执行。

## 验收结果

构建编号 `20261122T202756`，Node 24.22.3，pnpm 11.25.0，Racket 8.10。Git 祖先基线为 `beb2aad54b87a026282c4dd42dceca593fc06390`。本次构建的第 4 章 SHA-256 为 `e9ef84b31baeb522162143a8fa8fd34a9b991948d991ce7dc6f582a426ac5419`，gzip 文件为 87,371 字节。SICP 六个阅读页 parity 比较差异为零。

SICP 离线报告 `tmp/reading-notes-migration/browser/sicp/runs/2026-11-22T12-33-40-425Z-29c0d914/report.json` 的 SHA-256 为 `fabddc6c973b6cb298c56722e1174554c44e9760a87fe439a7e0c2d95d64b83f`。实际打开 8 个 HTML 入口，共 32 个有脚本视图、16 个无脚本视图，外部网络请求为零。目录门禁在源镜像与 dist 各检查 75 页，其中 18 页共 48 组。Racket 程序通过 25 组回归，另有 24 个教学示例读回。根检查报告为 `tmp/project-check/20261122T203417-mfn9r75u/report.json`。计时样本为本机观察值，无限流只比较有限前缀。

| 命令 | 退出码 |
| --- | ---: |
| `node scripts/sync-legacy.mjs --write` | 0 |
| `node tools/check-presentation-contract.mjs` | 0 |
| `node tools/reader-contract/check.mjs` | 0 |
| `node tools/reading-typography/check.mjs` | 0 |
| `node tools/reading-presentation/check.mjs` | 0 |
| `node tools/reading-prose/check.mjs` | 0 |
| `node --test scripts/*.test.mjs` | 0 |
| `python books/sicp/tools/check_notes.py` | 0 |
| `node scripts/toc-tree-smoke.mjs` | 0 |
| `python tools/project.py build` | 0 |
| `git diff --check` | 0 |
| `node scripts/sync-legacy.mjs` | 0 |
| `racket books/sicp/code/test-chapter04.rkt` | 0 |
| `racket books/sicp/tools/check_chapter04_examples.rkt` | 0 |
| `node books/sicp/tools/chapter04-candidate.mjs` | 0 |
| `node books/sicp/tools/check_chapter04_browser.mjs` | 0 |
| `node scripts/verify-parity.mjs --book sicp` | 0 |
| `node books/sicp/tools/check_chapter04_browser.mjs --dist` | 0 |
| `node scripts/toc-tree-smoke.mjs --dist` | 0 |
| `node scripts/check-offline.mjs --book sicp` | 0 |
| `python tools/project.py check-local` | 0 |
| `python tools/check_astro_records.py` | 0 |

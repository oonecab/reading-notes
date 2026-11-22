# T089 · SICP 第五章本地验收

原书题目清单与 PDF 694–861 中的题首逐项比对，52 个起页全部吻合。页面含 27 组注解、22 个叶小节的可复算示例、21 份共享输入、9 幅内联 SVG 与 9 份以原书图号标识的程序清单。页面与两个完整源码阅读副本按字节比较。

首次联调时，编译器将入口标签直接交给闭包构造操作，触发习题 5.9 的操作数限制。现先把入口写到寄存器再构造闭包，扩大后续编译路径的回归覆盖。候选排版检查还发现正文递推式缺 MathML、部分注解过短，两项均修复后重跑。负例保持在题面、输入、程序、图、摘录、裸代码、深链和小节示例八个维度。

C99 后端为每条指令生成 C 控制流，临时编译为共享库；值、环境和基本操作由 Racket 运行时提供。每次运行最多一百万步，C 栈最多 4096 个槽。显式堆的复制和标记清除另有独立测试。栈开销表将输入、递归或迭代程序、启动口径与统计量一并列出。

第一次正式构建赶在全书地图的 SVG 描述与修订散列同步前，源身份检查拒绝了地图。重新展开镜像并核对祖先与散列后，再次从源码构建。

补充习题的独立实验与编译清单期间，构建器发现测试程序在导出前后不一致并丢弃了该轮构建。最终复验要求发布包中的三个 Racket 文件和结果 JSON 与本地实测版本字节相同。

## 验收结果

构建编号 `20261122T212829`，Node 24.22.3，pnpm 11.25.0，Racket 8.10。Git 祖先基线为 `41e861b27dde14cd958e1439658a64975a41116c`。本次构建的第 5 章 SHA-256 为 `3bb79b29d95f3ebd41095d798c1ad0f17471ffebc368fa38dc9e1f8fbdd96a82`，gzip 文件为 227,301 字节。SICP 七个阅读页 parity 比较差异为零。

SICP 离线报告 `tmp/reading-notes-migration/browser/sicp/runs/2026-11-22T13-34-21-889Z-386e64b3/report.json` 的 SHA-256 为 `ef26a2fb47ea7f23fdd875b9e25284efca4590f1d8d8a47114ccc57ff38bc8c1`。实际打开 9 个 HTML 入口，共 36 个有脚本视图、18 个无脚本视图，外部网络请求为零。目录门禁在源镜像与 dist 各检查 76 页，其中 19 页共 53 组。Racket 程序通过 36 组回归，另有 22 个教学示例读回。根检查报告为 `tmp/project-check/20261122T213013-4rbj03uf/report.json`。三条末章执行路径均返回 120。源代码与运行时、程序输入、栈开销见书级执行记录。

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
| `racket books/sicp/code/test-chapter05.rkt` | 0 |
| `racket books/sicp/tools/check_chapter05_examples.rkt` | 0 |
| `node books/sicp/tools/chapter05-candidate.mjs` | 0 |
| `node books/sicp/tools/check_chapter05_browser.mjs` | 0 |
| `node scripts/verify-parity.mjs --book sicp` | 0 |
| `node books/sicp/tools/check_chapter05_browser.mjs --dist` | 0 |
| `node scripts/toc-tree-smoke.mjs --dist` | 0 |
| `node scripts/check-offline.mjs --book sicp` | 0 |
| `python tools/project.py check-local` | 0 |
| `python tools/check_astro_records.py` | 0 |
| `racket books/sicp/code/chapter05-c.rkt` | 0 |

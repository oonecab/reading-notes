# 第 3 章阶段验收

2026-11-22。对 PDF 322–514 执行 pdftotext -layout，以原书清单逐页匹配 82 个题首。按 Texinfo 的 quotation 边界归档原文。此检查仅证明起页与引用块边界。

Racket 8.10 运行 test-chapter03.rkt，8 组通过，退出 0。chapter03-candidate.mjs --partial 检查已编写的 11 题和全章 82 条归档，退出 0。完整模式因缺少 3.12–3.82 退出 1。check_chapter03_browser.mjs --partial 的 1800/1440/1024/390 有脚本及 1440/390 无脚本均退出 0；验证了索引数量、首末题开合、目录、横向宽度及外部请求。同步只读检查与 git diff --check 均退出 0。章级深度、视觉、输入和正式构建验收待完成。

## 正式验收

从 3.12 补至 3.82，共新增 71 题。第 3 章最终含 82 题、5 大节、19 个二级小节、24 组注解、38 幅内联 SVG 和 82 项题号索引。35 份共享输入有稳定锚点，51 道题登记显式输入依赖。82 题均绑定中文题面散列与 PDF 起页，3.80 同时归档图 3.37 后的续问。19 个二级小节有具体输入、步骤、验算、边界和 Racket 示例读回。第 1、2、3 章 Racket 分别通过 8、21、29 组。SICP 现为 5 页、225 题。

本地基线为 fcda9af，正式发布转换、页面一致性、离线浏览器分别执行。最终本地构建编号 20261122T134402，覆盖全站 74 个阅读页。第 3 章正式输出 SHA-256 为 6b27b93a0084eb44b90698fcab0434d36f2987d0fecad38e84a18153634aaac9。浏览器分别覆盖 1800、1440、1024、390 像素有脚本和 1440、390 像素无脚本，校验首末题、索引、目录、图 3.37、习题 3.80 公式和代码折叠。SICP 离线检查打开 7 个 HTML 入口，28 个有脚本、14 个无脚本视图，外部请求为 0。证据路径为 tmp/reading-notes-migration/browser/sicp/runs/2026-11-22T05-48-23-334Z-600aca33/report.json，报告 SHA-256 为 d208b9ae85ee4879a0824a9f21070b19e17485b6edb53be8f45e4ce070056140。全站 dist 目录树检查覆盖 74 页，其中 17 页形成 44 组。

| 命令 | 退出码 |
| --- | ---: |
| `node scripts/sync-legacy.mjs --write` | 0 |
| `node scripts/sync-legacy.mjs` | 0 |
| `node tools/check-presentation-contract.mjs` | 0 |
| `node tools/reader-contract/check.mjs` | 0 |
| `node tools/reading-typography/check.mjs` | 0 |
| `node tools/reading-presentation/check.mjs` | 0 |
| `node tools/reading-prose/check.mjs` | 0 |
| `node --test scripts/*.test.mjs` | 0 |
| `git diff --check` | 0 |
| `python tools/project.py check-local` | 0 |
| `python books/sicp/tools/check_notes.py` | 0 |
| `racket books/sicp/code/test-chapter03.rkt` | 0 |
| `racket books/sicp/tools/check_chapter03_examples.rkt` | 0 |
| `node books/sicp/tools/chapter03-candidate.mjs` | 0 |
| `node books/sicp/tools/check_chapter03_browser.mjs` | 0 |
| `python tools/project.py build` | 0 |
| `node scripts/verify-parity.mjs --book sicp` | 0 |
| `node scripts/check-offline.mjs --book sicp` | 0 |
| `node books/sicp/tools/check_chapter03_browser.mjs --dist` | 0 |
| `python tools/check_astro_records.py` | 0 |

初次执行保留了以下失败记录。Node 组件清单漏登新页时有两项失败，补登后 173/173 通过。构建中修订链绑定和专项检查的标准输出曾导致失败，修正后重建。根检查曾拒绝缺少第 3 章的历史基线记录；已用冻结镜像独立构建并绑定散列。窄屏离线测试曾把滚轮发给收起代码块的屏幕外坐标，已改为命中可见滚动区域后实测位移。原书代码行尾空格造成差异检查失败，改用等值 HTML 字符引用后，程序文本比对及差异检查通过。

执行环境为本机 Chrome、Racket 8.10、Poppler 和 Node 24.22.3。并发例验证规定的交错模型，流示例只强制有限前缀。第 4、5 章继续保留原书章意。

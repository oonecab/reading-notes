# EOPL：页面与来源说明

方法遵循 [RN-001](../../../docs/reading-notes-standard.md)，范围见[阅读计划](../reading-plan.md)，维护约定见 [agent.md](../agent.md)。

| 独立阅读页 | 原书范围 | 当前完整题解 |
|---|---|---|
| [全书地图](book_overview.html) | 九章、两个附录；目录 v–vii / PDF 6–8；依赖图 xviii / PDF 19 | 无 |
| [导读与作者序言](preface.html) | Foreword ix–xiii / PDF 10–14；Preface xv–xix / PDF 16–20 | 0.1，xix / PDF 20 |
| [第 1 章](chapter01_inductive_data.html) | pp.1–30 / PDF 24–53 | 1.1–1.36，36 题 |
| [第 2 章](chapter02_data_abstraction.html) | pp.31–55 / PDF 54–78 | 2.1–2.31，31 题 |

来源权威是 `source_manifest.json`、`source_inventory.json`、`source_excerpts.json`。地图与序言的图文审阅及全文阅读范围见 `../review/map-preface.md`；第 1、2 章见 `../review/ch01-02.json`。第 3–9 章摘要仅作全书导航。第 1、2 章完整原题与页序见 questions_ch01_02.json，解答与实际程序分开维护。

正文使用 `src/content/books/eopl/` 中的 JSON frontmatter + HTML；四份成品为展开镜像。使用 `../tools/sync_notes.py` 或根构建同步，均复用仓库现有 `readSource`/`syncMirrors`。I044 将 `7e9d2ea` 的原始源码登记为独立基线，frontmatter 的 `original_sha256` 可回查该提交；它是保留的源码快照，不表示以前已经上线。I048 的两章使用 `1e96df2` 的独立页面基线；最后的程序记号排版修订通过连续修订链另行登记。

版式参考 `src/content/books/measure-probability/preface.html`、`book_overview.html`。使用共享 `reading-base`、`reading-content-2`、`reading-navigation`、`reading-annotations`、`reading-components`、`reading-typography`；页内少量样式只处理本书依赖图、章意与术语表。页头/页尾只连向已完成页面，章意锚点保持 `chapter-1` 至 `chapter-9`。

目录、深链接与注解复用 `6a3f8b30744a694f9192.js`、`54f30fc1f5e1cbcd699a.js`，打印复用 `3497ba81d7e642909037.js`。证明/陈述/习题组件沿用 RN-001；序言 0.1 默认折叠，原题在前，答案在后。全书图与闭包图均有可访问名称、文字说明与窄屏局部横滚。

`../code/` 下的 Python/Racket 文件是程序维护源；序言 `scope-demo-code` 是同步的完整阅读副本。运行方式、输入语法、返回值和失败条件见[程序说明](../code/README.md)，页面上的手算过程独立于解释器输出。

从仓库根运行 `python3 books/eopl/tools/check_notes.py --quick` 检查结构和副本；不加 `--quick` 实际运行语义回归。`python3 books/eopl/tools/test_checker.py` 在隔离副本验证缺失锚点、页序错位、程序副本漂移均被拒绝。根入口 `python3 tools/project.py check --book eopl` 同样执行本书检查。I042 保留准备批历史证据；I044 对两页重新执行统一构建、浏览器矩阵、无脚本和下载验收，公开范围仅限地图与序言。

I048 新增第 1、2 章，沿用 RN-001 v1.7：原题与解答独立，习题默认折叠，代码使用原生独立控件，表格和图仅局部横滚。数学与程序标识符区分处理。新增内容的来源、运行与实际阅读记录见 `../review/ch01-02.json` 和根 T048；这属于本地内容扩展，生产发布事实仍以发布记录为准。

I051 将两章与主分支 RN-001 v1.9 合并。普通英文与数字使用 Times New Roman，Scheme 语句与源码使用共享等宽字体；原题容器使用正文标签，内部程序示例独立标记，数学条件使用原生 MathML。检查器将可见 MathML 的符号、上下标与保存的原题拼写互相核对，再逐字核对 67 道题，题干中的程序换行与缩进也参与比较。习题 2.24 的跨行过程名依据 PDF 73 恢复为 `bintree-to-list`。当前复核见 `../review/merge-review.json`，I048 的原始结论与散列继续保留。

本书的当前阅读契约以 RN-001 v1.10 为准：完整中文题干和来源、逐节注解、共同版心、代码等宽与原生折叠、命名明确的索引、直达登记 PDF 的原文入口。逐页义务在根目录 `docs/reader-contract.json`，原书发布身份在 `docs/reader-sources.json`；历史批次记录保留当时的范围，当前复查执行 `python3 tools/project.py check` 及完整浏览器矩阵。

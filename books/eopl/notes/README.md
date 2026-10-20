# EOPL：页面与来源说明

方法遵循 [RN-001](../../../docs/reading-notes-standard.md)，范围见[阅读计划](../reading-plan.md)，维护约定见 [agent.md](../agent.md)。

| 独立阅读页 | 原书范围 | 当前完整题解 |
|---|---|---|
| [全书地图](book_overview.html) | 九章、两个附录；目录 v–vii / PDF 6–8；依赖图 xviii / PDF 19 | 无 |
| [导读与作者序言](preface.html) | Foreword ix–xiii / PDF 10–14；Preface xv–xix / PDF 16–20 | 0.1，xix / PDF 20 |

来源权威是 `source_manifest.json`、`source_inventory.json`、`source_excerpts.json`。本批图文审阅和全文阅读范围见 `../review/map-preface.md`。章节摘要仅作全书导航，不代表对应章节的完整伴读或题解已经写成。

正文使用 `src/content/books/eopl/` 中的 JSON frontmatter + HTML；两份成品为展开镜像。准备阶段使用 `../tools/sync_notes.py`，复用仓库现有 `readSource`/`syncMirrors` 实现，避免另建共享资源展开规则。尚未建立正式 Astro 历史基线，frontmatter 不伪造 `original_sha256`。

版式参考 `src/content/books/measure-probability/preface.html`、`book_overview.html`。使用共享 `reading-base`、`reading-content-2`、`reading-navigation`、`reading-annotations`、`reading-components`；页内少量样式只处理本书依赖图、章意与术语表。页头/页尾只连向已完成页面，章意锚点保持 `chapter-1` 至 `chapter-9`。

目录、深链接与注解复用 `6a3f8b30744a694f9192.js`、`54f30fc1f5e1cbcd699a.js`，打印复用 `3497ba81d7e642909037.js`。证明/陈述/习题组件沿用 RN-001；序言 0.1 默认折叠，原题在前，答案在后。全书图与闭包图均有可访问名称、文字说明与窄屏局部横滚。

`../code/scope_demo.py` 是唯一程序源；序言 `scope-demo-code` 是同步的完整阅读副本。运行方式、输入语法、返回值和失败条件见[程序说明](../code/README.md)，页面上的手算过程独立于解释器输出。

从仓库根运行 `python3 books/eopl/tools/check_notes.py --quick` 检查结构和副本；不加 `--quick` 实际运行语义回归。`python3 books/eopl/tools/test_checker.py` 在隔离副本验证缺失锚点、页序错位、程序副本漂移均被拒绝。页面准备批的浏览器矩阵、无脚本和下载验证单独记录。公共五书构建不包含本书，不能引用它作为本书的发布验收。

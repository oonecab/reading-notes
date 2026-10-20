# EOPL · 程序设计语言要义

Daniel P. Friedman / Mitchell Wand，*Essentials of Programming Languages*，第三版，MIT Press，2008。

从[全书地图](notes/book_overview.html)开始，或直接阅读[导读与作者序言](notes/preface.html)。当前是新书准备批：完成两页伴读、原书习题 0.1 和一个原创闭包实验。原书九章、附录及全部编号项目已登记；后续章节的伴读和题解见[阅读计划](reading-plan.md)。

正文维护于 `src/content/books/eopl/`，`notes/` 中的两个 HTML 是共享样式展开后的独立成品。基础阅读无需服务器或网络。原 PDF 仅作本地对照，身份与页序见[来源清单](notes/source_manifest.json)。

本批依照新书接入的准备阶段运行书内工具，尚未加入正式站点 catalog、发布清单和 Astro 历史基线。完成代表章后沿[接入步骤](../../docs/adding-a-book.md)登记统一发布；本批页面可直接打开，不依赖该登记。

从主仓库根目录执行：

```sh
python3 books/eopl/tools/sync_notes.py --write
python3 books/eopl/tools/check_notes.py --quick
python3 books/eopl/tools/check_notes.py
python3 books/eopl/tools/test_checker.py
python3 books/eopl/code/scope_demo.py
```

[维护入口](agent.md) · [页面说明](notes/README.md) · [程序说明](code/README.md) · [本批审阅](review/map-preface.md) · [T042 验证记录](../../test/T042-eopl-map-preface.md)。

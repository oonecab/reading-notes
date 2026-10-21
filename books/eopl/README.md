# EOPL · 程序设计语言要义

Daniel P. Friedman / Mitchell Wand，*Essentials of Programming Languages*，第三版，MIT Press，2008。

从[全书地图](notes/book_overview.html)开始，或直接阅读[导读与作者序言](notes/preface.html)。I044 已发布地图与序言两页；当前本地内容继续加入第 1、2 章，累计四页伴读、68 道题解。原书九章、附录及全部编号项目已登记；后续章节的伴读和题解见[阅读计划](reading-plan.md)。

正文维护于 `src/content/books/eopl/`，`notes/` 中的四个 HTML 是共享样式展开后的独立成品。基础阅读无需服务器或网络。原 PDF 仅作本地对照，身份与页序见[来源清单](notes/source_manifest.json)。

I044 按用户整体发布要求，将现有两页、来源摘要与闭包实验接入 catalog、书架、根检查入口和发布清单；九章伴读仍按阅读计划推进。原始源码基线为 Git `7e9d2ea`，与旧生产版本明确区分。共同排版遵循 RN-001 v1.7；本批构建、实际阅读和上线证据见 [T044](../../test/T044-reading-typography.md)。

从主仓库根目录执行：

```sh
python3 books/eopl/tools/sync_notes.py --write
python3 books/eopl/tools/check_notes.py --quick
python3 books/eopl/tools/check_notes.py
python3 books/eopl/tools/test_checker.py
python3 books/eopl/code/scope_demo.py
racket books/eopl/code/test_chapters.rkt
```

[维护入口](agent.md) · [页面说明](notes/README.md) · [程序说明](code/README.md) · [地图与序言审阅](review/map-preface.md) · [T042 验证记录](../../test/T042-eopl-map-preface.md)。

第 1、2 章续写入口：[归纳数据与递归程序](notes/chapter01_inductive_data.html)、[数据抽象与抽象语法](notes/chapter02_data_abstraction.html)。包含全部 67 道原题、解答与 Racket 程序；来源和运行范围见 [T048](../../test/T048-eopl-ch01-02.md)。

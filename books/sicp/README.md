# SICP · 计算机程序的构造和解释

当前提供[全书地图](notes/book_overview.html)、[引言：前言与两版序言](notes/preface.html)和[第 1 章：用过程构造抽象](notes/chapter01_procedures.html)。第一章覆盖18个二级小节及习题1.1–1.46的完整中文题干、解答和可运行示例；[第 2 章](notes/chapter02_data_abstraction.html)覆盖 18 个二级小节和 97 题；[第 3 章](notes/chapter03_modularity.html)覆盖 19 个二级小节与 82 题；[第 4 章](notes/chapter04_metalinguistic.html)覆盖 79 题，[第 5 章](notes/chapter05_register_machines.html)覆盖 52 题。

原书为第二版 Unofficial Texinfo Format 2.andresraba5.6，用户提供的 [PDF](sicp.pdf) 共 883 页。所有原书索引使用该文件；网页版只辅助核对文字，不参与构建，也不提供页码。身份、分段页序、许可与本批范围由[来源清单](notes/source_manifest.json)维护。

维护先读 [agent.md](agent.md)、[阅读计划](reading-plan.md)和[页面说明](notes/README.md)。受控源在 `src/content/books/sicp/`；notes 下 HTML 为展开镜像。根目录执行 `python tools/project.py check-local --book sicp`、`python books/sicp/tools/check_notes.py`（完整程序回归）和 `python tools/project.py build`。程序接口见[code/README](code/README.md)，第一章证据与平台边界见[T075](../../test/T075-sicp-chapter01.md)；早期地图/引言记录T073保留。

### 第 3 章 · 模块化、对象和状态

I087 验收时为地图、引言及第 1–3 章，共 5 页、225 题。第 3 章对应 PDF 322–514，包含 82 题、19 个二级小节。可变序对使用 Racket 可变序对适配；并发示例采用明确交错模型，流测试读取有限前缀。

### 第 4 章 · 元语言抽象

I088 验收时为 6 页、304 题。第 4 章对应 PDF 515–693，4 大节、17 个二级小节；查询系统实现另分 8 个细目。程序验证使用 Racket 8.10。

### 第 5 章 · 寄存器机器里的计算

全书地图、引言及五章正文共 7 页、356 题。第 5 章对应 PDF 694–861，含 5 个大节、22 个二级小节与 52 道习题。程序以 Racket 8.10 执行；末两题用 GCC 编译 C99 控制器，数据操作通过本地运行时提供。

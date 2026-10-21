# EOPL：维护入口

先读[规则职责索引](../../docs/rules/README.md)、[RN-001](../../docs/reading-notes-standard.md)、本书[阅读计划](reading-plan.md)与[页面说明](notes/README.md)。命令从主仓库根目录执行。

- 书籍 ID 为 `eopl`，来源只按第三版 MIT Press 2008 核对；`notes/source_manifest.json` 维护身份与页序，`notes/source_inventory.json` 保存原书独立编号清单。正文阿拉伯页序偏移为 23，前置罗马页码另算。
- 当前内容范围为全书地图、Foreword、Preface、第 1、2 章，以及习题 0.1、1.1–1.36、2.1–2.31。第 3–9 章仍是规划，不能用地图摘要充当逐章完成。
- 正文唯一维护源为 `src/content/books/eopl/*.html`；`tools/sync_notes.py --write` 展开共享 CSS/JS、同步程序阅读副本与 `notes/*.html`。不要直接修改镜像。
- 程序采用 `standalone_sources`，维护于 `code/`；序言 Python 模型是原创六构造式 AST 解释器；第 1、2 章原创解答由 Racket 8.17 + eopl/rackunit 实际执行，范围见 code/README.md。完整原题（含小问、示例、提示、图示）由 notes/questions_ch01_02.json 单独登记，不能从已写答案倒推覆盖率。
- 环境、存储、续文、类型环境分别陈述；词法作用域与动态作用域、求值策略与对象共享、尾调用与总空间、类型安全与终止性不可混同。
- 原书陈述、短引文、译义、伴读例子分开标识；习题保留原编号、完整题干、提示、印刷页与 PDF 页序。
- 默认组件来自现有测度书与共享阅读样式，具体资源见 `notes/README.md`。本书已在 I044 以地图与序言范围登记，运行 `python3 tools/project.py check --book eopl` 或书内 checker；后续章节按阅读计划逐批验收。
- 来源读回、程序、静态结构和实际浏览器阅读分别记录于 `review/`；输出、截图和提取件只放忽略的 `tmp/`。

本书的当前阅读契约以 RN-001 v1.10 为准：完整中文题干和来源、逐节注解、共同版心、代码等宽与原生折叠、命名明确的索引、直达登记 PDF 的原文入口。逐页义务在根目录 `docs/reader-contract.json`，原书发布身份在 `docs/reader-sources.json`；历史批次记录保留当时的范围，当前复查执行 `python3 tools/project.py check` 及完整浏览器矩阵。

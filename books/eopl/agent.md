# EOPL：维护入口

先读[规则职责索引](../../docs/rules/README.md)、[RN-001](../../docs/reading-notes-standard.md)、本书[阅读计划](reading-plan.md)与[页面说明](notes/README.md)。命令从主仓库根目录执行。

- 书籍 ID 为 `eopl`，来源只按第三版 MIT Press 2008 核对；`notes/source_manifest.json` 维护身份与页序，`notes/source_inventory.json` 保存原书独立编号清单。正文阿拉伯页序偏移为 23，前置罗马页码另算。
- 当前任务范围是全书地图、Foreword、Preface 和习题 0.1。后续章节只能记为规划，不能用地图摘要充当逐章完成。
- 正文唯一维护源为 `src/content/books/eopl/*.html`；`tools/sync_notes.py --write` 展开共享 CSS/JS、同步程序阅读副本与 `notes/*.html`。不要直接修改镜像。
- 程序采用 `standalone_sources`，维护于 `code/`；本批 Python 模型是原创的六构造式 AST 解释器，不是原书 Scheme 全套代码的移植。Scheme/Racket 运行环境、原书代码执行范围必须另记。
- 环境、存储、续文、类型环境分别陈述；词法作用域与动态作用域、求值策略与对象共享、尾调用与总空间、类型安全与终止性不可混同。
- 原书陈述、短引文、译义、伴读例子分开标识；习题保留原编号、完整题干、提示、印刷页与 PDF 页序。
- 默认组件来自现有测度书与共享阅读样式，具体资源见 `notes/README.md`。本书已在 I044 以地图与序言范围登记，运行 `python3 tools/project.py check --book eopl` 或书内 checker；后续章节按阅读计划逐批验收。
- 来源读回、程序、静态结构和实际浏览器阅读分别记录于 `review/`；输出、截图和提取件只放忽略的 `tmp/`。

# EOPL：维护入口

先读[规则职责索引](../../docs/rules/README.md)、[RN-001](../../docs/reading-notes-standard.md)、[RN-002](../../docs/reading-presentation-standard.md)、本书[阅读计划](reading-plan.md)与[页面说明](notes/README.md)。命令从主仓库根目录执行。

- 书籍 ID 为 `eopl`，来源只按第三版 MIT Press 2008 核对；`notes/source_manifest.json` 维护身份与页序，`notes/source_inventory.json` 保存原书独立编号清单。正文阿拉伯页序偏移为 23，前置罗马页码另算。
- 当前内容范围为全书地图、Foreword、Preface、第 1–9 章与附录 A/B，以及序言1题、九章350题与附录B5题，共356题，不能用地图摘要充当逐章完成。
- 正文唯一维护源为 `src/content/books/eopl/*.html`；`tools/sync_notes.py --write` 展开共享 CSS/JS、同步程序阅读副本与 `notes/*.html`。不要直接修改镜像。
- 程序采用 `standalone_sources`，维护于 `code/`；序言 Python 模型是原创六构造式 AST 解释器；第 1–9 章及附录B原创解答由 Racket 8.17 + eopl/rackunit 实际执行，范围见 code/README.md。第 1、2 章题面与页序由 notes/questions_ch01_02.json 登记，第 3 章由 notes/questions_ch03.json 登记，第 4 章由 notes/questions_ch04.json 登记，第 5、6 章由 notes/questions_ch05.json、notes/questions_ch06.json 登记，第7章由notes/questions_ch07.json登记；完整英文原题按 RN-002 不进入阅读页，归档于 notes/original_questions.json（含题号、印刷页/PDF 页、英文 HTML 或文本与 sha256），只用于维护核对，不能从已写答案倒推覆盖率。
- 环境、存储、续文、类型环境分别陈述；词法作用域与动态作用域、求值策略与对象共享、尾调用与总空间、类型安全与终止性不可混同。
- 原书陈述、短引文、译义、伴读例子分开标识；习题保留原编号、完整中文题干、提示、印刷页与 PDF 页序。中文题干不得只有“见英文”“证明略”或纯公式；只有术语或译法确有歧义时，才附不超过 2 句/400 字并带 `data-excerpt-reason` 的短原文摘录，不逐题保留完整英文原题。
- 默认组件来自现有测度书与共享阅读样式，具体资源见 `notes/README.md`。本书已在 I044 以地图与序言范围登记，运行 `python3 tools/project.py check --book eopl` 或书内 checker；后续章节按阅读计划逐批验收。
- 来源读回、程序、静态结构和实际浏览器阅读分别记录于 `review/`；输出、截图和提取件只放忽略的 `tmp/`。

本书的当前阅读契约以 RN-001 v1.11 与 RN-002 v1.1 为准：完整中文题干和来源、逐节注解、共同版心、代码等宽与原生折叠、命名明确的索引、直达登记 PDF 的来源链接；阅读页不保留完整英文原题，只有术语或译法有歧义时才附不超过 2 句/400 字并带 `data-excerpt-reason` 的短原文摘录。逐页义务在根目录 `docs/reader-contract.json` 与 `docs/reader-presentation.json`，原书发布身份在 `docs/reader-sources.json`；历史批次记录保留当时的范围，当前复查执行 `python3 tools/project.py check` 及完整浏览器矩阵。

第 5、6 章续文/转换器使用现有 Racket/eopl；C11 比较三个 LETREC 驱动，Python 3 模拟同步和私有存储消息。核心源例、机器转移计数和宿主空间边界分别说明。CPS-IN、CPS-OUT 与调度状态不可交给宿主 eval。

第7章使用既有Racket与rackunit：CHECKED/INFERRED共用词法AST，类型环境与运行环境分离，发生检查只接受有限简单类型。W量化FV(type)减FV(environment)，引用/可变对象使用保守值限制；全局替换变体仅作单次非交错分析。规则和模式见code/README.md，有限测试不得替代语义类型的全称证明。

第8章题面独立登记于notes/questions_ch08.json。Racket模块解析器、检查器与求值器分别处理接口、类型身份与运行模块值；保留原书顺序匹配，习题8.8/8.17通过无序模式比较已按词法顺序展开的声明。参数化模块捕获定义环境，依赖结果代入实参的真实类型身份；导入只强制一次。命名接口按定义环境解释，静态类型不证明代数律或终止性。来源与分层本地证据见T063及review/ch08.json。

第9章题面独立登记于notes/questions_ch09.json。对象字段使用位置，继承方法保持宿主，send动态分派而super从宿主父类开始；类型检查先收集签名、再检查方法体及接口。源码、语法选项、初始化策略、名字改编、词法地址、多重继承/闭包对象/原型的适用边界见code/README.md；finite回归不代替一般安全或终止证明。原题9.37标注与9.34接口边界单独校注，来源及本地分层证据见T064/review/ch09.json。

I065完成附录A/B：A按六个主题组织原书无编号讨论，B保留B.1/B.2/B.3与四个无编号子标题；B.1–B.5独立原题输入为notes/questions_appendix_b.json。SLLGEN使用eopl生成器，算术数域为精确有理数；模式、词法覆盖、左结合及REPL终结符见code/README.md。当前来源和发布验收见review/completion.json与T065。

I066修复完整字符串输入与预算边界，将5.57三种同步机制接入同一THREADS解释器。第3–6章及附录B下载须同时取得code/sllgen_guard.rkt；同步语法、Mesa持锁前提和取消语义由code/README.md及5.57正文维护。当前修复证据见T066和review/implementation-repairs.json，历史发布仍由原记录描述。

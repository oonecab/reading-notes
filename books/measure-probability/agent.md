# 测度论与概率论基础：维护入口

先读 [RN-001](../../docs/reading-notes-standard.md)、[规则职责索引](../../docs/rules/README.md)、[阅读计划](reading-plan.md)和[章节说明](notes/README.md)。书籍 ID 为 `measure-probability`。

- 使用程士宏编著、北京大学出版社 2004 年第 1 版；来源身份与页序唯一维护在 `notes/source_manifest.json`。扫描版无文本层，OCR 数学符号不可靠。
- 正式中文内容维护于 `src/content/books/measure-probability/` 的八份受控 HTML，`notes/*.html` 为独立检查用兼容镜像；第一、二、四章各五节，第三、五章各四节，第六章五节。原题按“习题 c 第 n 题”定位，网站使用 `ex-c-n` 稳定锚点。
- 使用原书“域 / sigma 域 / 完全化”术语，同时解释代数 / sigma 代数 / 完备化同义关系。集合补集始终相对于已指定的空间。
- 广义实数运算保留 0 乘无穷等于 0 的约定；无穷减无穷、无穷除无穷不定义。商的可测性只在商有意义时适用。
- 区分半环上每个成员的 sigma 有限性与可数有限测度成员覆盖全空间。扩张唯一性、完全化和习题 2.20 明示后一条件。
- 原书疑点必须保留位置、原说法、修正与反例；`notes/source_issues.json` 登记，正式论证维护在 HTML。
- C11/Python 的唯一维护源在 `code/`，有限空间用最多 8 个点的位掩码；程序不证明一般测度定理。同步工具只更新 HTML 代码块。
- 版式、来源、覆盖与验证见 `notes/README.md` 和 `review/`。公共命令从仓库根 `tools/project.py` 进入。

第三、四章维护约定：低阶 M_p 与 N_p 分开使用；弱星与全对偶弱收敛明确区分；符号测度先固定一侧无穷的方向，所有相减检查存在条件。条件期望版本同时满足信息可测性和事件积分身份；零概率点的修改不能破坏前者。新证明与习题按独立原书清单逐项读回，不能只以编号数量作为完成依据。

Astro 维护、镜像同步与冻结基线规则见 [构建维护说明](../../docs/astro-authoring.md)。

第五、六章维护约定：乘积 sigma 域与完全化分开；转移核采用共同有限分块；Fubini 的有符号条件不以累次积分存在替代。三级数、强弱律和 CLT 分别写明独立、有限矩、截断尺度及收敛方式。分布归一化与原式校注以正文和 source_issues.json 为权威。有限核/二项卷积输入范围见 code/README.md，独立回归由 tools/check_products.py 负责。

本书的当前阅读契约以 RN-001 v1.11 为准：完整中文题干和来源、逐节注解、共同版心、代码等宽与原生折叠、命名明确的索引、直达登记 PDF 的原文入口。逐页义务在根目录 `docs/reader-contract.json`，原书发布身份在 `docs/reader-sources.json`；历史批次记录保留当时的范围，当前复查执行 `python3 tools/project.py check` 及完整浏览器矩阵。

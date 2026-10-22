# Visual Group Theory 维护入口

先读 [RN-001](../../docs/reading-notes-standard.md)、[规则职责索引](../../docs/rules/README.md)，再读[阅读计划](reading-plan.md)和[章节说明](notes/README.md)。本书 ID 为 `visual-group-theory`。

- 原书身份与完整目录由 `notes/source_manifest.json` 维护；`notes/source_inventory.json` 从原书正文独立枚举编号项。文本层会丢失负号及数学符号，题目与公式必须看原页。
- 正式中文内容在 `src/content/books/visual-group-theory/` 的十二份受控 HTML 维护，`notes/*.html` 是独立检查用兼容镜像：地图、序言、第 1—10 章。沿原节次，保留 302 题全部小问与 62 个编号陈述；本批第 9—10 章分别 28、30 题。新增章先扩来源清单。
- 区分状态、作用在全部状态上的动作、生成元、有限动作序列及其效果等价类。单个状态结果相同一般不足以判定两个动作相同；本批三幅不同画的完全标记状态例外，需解释原因。
- 字词 `ab` 按时间从左到右执行 a 再 b；对应函数为 b∘a。复合逆必须反序。标准群生成允许使用逆元，与仅正向拼接指令的操作清单另行说明。
- 第 1 章是非正式动作语言；关于可逆性与确定性的边界在习题 1.11 明示。有限穷举验证本章有限例子，一般命题由正文证明。
- C11/Python 代码的唯一维护源为 `code/`，`tools/sync_code.py` 同步 HTML。发布清单不含 `tmp/source.pdf`，正文来源以印刷页/PDF 页序文字与来源说明定位。
- 样式和导航来自随机过程 `notes/preface.html` 的现有组件，使用静态 MathML/SVG、原生 details、目录与阅读注解。保持 RN-001 四个断点及离线阅读。
- 按书检查由根 `tools/project.py` 分派到 `tools/check_notes.py`，执行与阅读证据在 `review/` 分层记录。结构、程序、内容与阅读验收必须分别记录。

- 第 2 章区分状态作用图与 Cayley 图；第 3 章明确刚体操作和理想分子/无限饰带模型；第 4 章采用行先列后，Q₄ 的 ji=k 依本 PDF 箭头，A₄ 下标/幂名对应及原题校注在正式页维护。不得从常用四元数约定替换本书的表。
- 3.11(f) 按实际原图具有双镜轴，与 (d) 重复；保留原图和证明，补充构造另标。4.29 的错误乘积与正确解分开核验。数据输入见 notes/algebra_inputs.json，独立回归见 tools/check_algebra.py。

- 第 5—8 章的规则以正式 HTML 为准：区别全部平方与 Aₙ、群的状态作用图与正则 Cayley 图、左/右陪集、半直积的作用方向以及幂映射的同态条件。按原页保留 5.33(e)、7.18(f)(g)、8.40 与 8.42 的实际符号，不能用预期答案改题。源输入为 notes/structures_inputs.json，独立核验为 tools/check_structures.py。

- 第 9—10 章须区分右作用的右陪集、群阶与作用集合大小、单根域与正规分裂域、消去多项式与最小多项式、可解群与有根。保留 9.22(d)、10.4、10.6、10.26、10.29 的原题并给成立条件或校正。独立输入 `notes/sylow_galois_inputs.json`，检查 `tools/check_sylow_galois.py`。

- 行内公式按语义维护静态 MathML；修改后核对上下标、逆元底数、整除与分式方向。英文短摘句明确写出节选范围，跨页步骤按引文实际所在页定位。阅读注解绑定含 h2 的主节，以兼容既有侧栏控制器；正文深链、题目与小问锚点保持稳定。阅读一致性检查在 `tools/check_reading.py`，不能用结构检查替代浏览器实际阅读。

- 每个行内和显示 MathML 都保留非空且相同的 aria-label 与 text/plain annotation；semantics 中先放呈现树、再放回退。纯文本对复合指数和整个分母加括号。完整公式复制覆盖两种 display，局部选区保持原生行为；显示公式既有 mtext 呈现不在仅补回退的修订中重写。

Astro 维护、镜像同步与冻结基线规则见 [构建维护说明](../../docs/astro-authoring.md)。

本书的当前阅读契约以 RN-001 v1.11 为准：完整中文题干和来源、逐节注解、共同版心、代码等宽与原生折叠、命名明确的索引、直达登记 PDF 的原文入口。逐页义务在根目录 `docs/reader-contract.json`，原书发布身份在 `docs/reader-sources.json`；历史批次记录保留当时的范围，当前复查执行 `python3 tools/project.py check` 及完整浏览器矩阵。

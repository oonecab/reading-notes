# 业务与计算规则

<!-- project-governance:managed:start -->
本目录保存公式、统计口径、精度、舍入、单位、币种、时间边界和异常处理等规则的唯一权威定义。

- 每项重要规则使用独立文件和稳定规则 ID。
- 修改规则时必须同时更新受影响代码、测试设计、可执行回归测试、API/报表/用户说明。
- 规则文件必须说明生效版本或日期，并保留只追加的变更记录。
- 示例应明确输入、输出、单位和边界，尽量与自动化测试共用夹具。
- 不得用代码注释代替权威规则文档，也不得在多份文档中分别维护同一公式。

新建规则时复制 `_template.md`。其中的 `project-governance:managed` 标记只表示 `_template.md` 本身由生成器维护；复制为实际规则文件后应删除两行标记，实际规则全文由项目自主管理。
<!-- project-governance:managed:end -->

## 规则索引

| 规则 ID | 名称 | 权威文档 | 生效版本/日期 | 责任人 |
|---|---|---|---|---|

## 本项目规则职责

教材陈述、例题、公式和推导由 src/content/books 中的受控 HTML 维护，原 books 章节路径是同步的检查/阅读镜像，具体流程见 [Astro 内容维护](../astro-authoring.md)；计算实现与数值接口由各书源码/正文及运行说明维护。跨书规则由本目录登记，教材模型保持在对应正文中。

跨书的来源核对、全书规划、伴读方法、题解、代码与阅读验收采用 [RN-001 读书笔记共同标准](../reading-notes-standard.md)（v1，2026-10-14）。[新书接入](../adding-a-book.md)与[模板](../templates/reading-notes/README.md)引用该标准；以下各书文件补充本书模型、范围和具体约定，既有更细要求继续生效。

- 随机过程：[维护约定](../../books/stochastic/agent.md)、[章节规范](../../books/stochastic/notes/README.md)、[程序接口](../../books/stochastic/code/README.md)。
- Weiss：[维护约定](../../books/weiss/agent.md)、[章节规范](../../books/weiss/notes/README.md)、[程序说明](../../books/weiss/notes/book_overview.html#program-guide)、[原图例接口](../../books/weiss/c/README.md)。
- CS:APP：[维护约定](../../books/csapp/agent.md)、[章节规范](../../books/csapp/notes/README.md)、[程序约定](../../books/csapp/code/README.md)、[原文来源清单](../../books/csapp/notes/source_excerpts.json)；定宽表示、C11 语义、ABI、流水线与缓存的模型由正式 HTML 定义。新增例子见 [T003](../../test/T003-csapp-companion.md)；流水寄存器开销、分配上限、缓存写策略、浮点精度前提及来源修订见 [I004](../../issues/I004-csapp-source-reading.md) 和 [T004](../../test/T004-csapp-source-reading.md)。

第二部分链接符号/重定位、信号状态与进程生命周期、页表与分配器契约分别由[第 7 章](../../books/csapp/notes/chapter07_linking.html)、[第 8 章](../../books/csapp/notes/chapter08_exceptional.html)、[第 9 章](../../books/csapp/notes/chapter09_virtual_memory.html)定义，执行范围与原书校注见 [I005](../../issues/I005-csapp-part-two.md) 和 [T005](../../test/T005-csapp-part-two.md)。

跨书共有的规则登记方式遵循本目录规范；发生公式、精度、单位或边界变更时，在此链接受影响的权威条目、问题单和测试，正文保留原结论与修正依据，不另抄一份算法或定理。

随机过程第一章的吸收计时约定由[习题 1.66](../../books/stochastic/notes/chapter01_markov_chains.html#ex-1-66)说明：按原书区分从第 1 步开始找吸收与允许时刻零已吸收的剩余等待，首步方程和最终边界答案分别使用对应定义。2026-10-16 的原书核对、解释修订与有理数回归见 [I016](../../issues/I016-stochastic-chapter1-explanations.md) / [T016](../../test/T016-stochastic-chapter1-explanations.md)。

后续章节的模型与计算边界仍以正式正文为准：[定理 3.7](../../books/stochastic/notes/chapter03_renewal_processes.html#theorem-3-7-proof)区分服务开始链的返回次数和真实时间空闲比例；[例 4.17](../../books/stochastic/notes/chapter04_continuous_time_markov_chains.html#example-4-17)按无限服务台逐个累加离开速率；[例 6.9](../../books/stochastic/notes/chapter06_mathematical_finance.html#example-6-9)保留历史报价，以完整精度计算折现后再舍入显示；[定理 6.9](../../books/stochastic/notes/chapter06_mathematical_finance.html#theorem-6-9-proof)说明极限与停止所需的一致可积条件；[定理 A.8](../../books/stochastic/notes/appendix_a_probability_review.html#theorem-a-8-proof)明确变量变换使用的局部绝对连续条件。原书说法、修正理由和各题输入在对应正文维护，逐项审阅及独立回归见 [I017](../../issues/I017-stochastic-remaining-explanations.md) / [T017](../../test/T017-stochastic-remaining-explanations.md)。

第二部分修订的信号临时等待掩码、作业清理与分配搜索游标契约见 [I006](../../issues/I006-csapp-part-two-review-fixes.md) / [T006](../../test/T006-csapp-part-two-review-fixes.md)，权威正文和维护程序仍在上述章节及程序约定中。

第三部分可靠 I/O 与文件共享、地址和协议边界、并发与同步的契约分别由[第 10 章](../../books/csapp/notes/chapter10_system_io.html)、[第 11 章](../../books/csapp/notes/chapter11_network.html)、[第 12 章](../../books/csapp/notes/chapter12_concurrency.html)定义，执行与校注范围见 [I007](../../issues/I007-csapp-part-three.md) / [T007](../../test/T007-csapp-part-three.md)。

第三部分修订的 HTTP 首部提前拒绝、接入窗口与活动连接处理、计时子进程取消规则见 [I008](../../issues/I008-csapp-part-three-review-fixes.md) / [T008](../../test/T008-csapp-part-three-review-fixes.md)，权威正文与程序约定仍在第 11/12 章及源码说明中。

第二轮严格评估中的 HTTP 字段空白/Host 先后规则、断言关闭后的必要自测、3.33 别名条件、CGI 子进程所有权与分配器空间统计口径见 [I010](../../issues/I010-csapp-review-v2-fixes.md) / [T010](../../test/T010-csapp-review-v2-fixes.md)。权威定义仍在相应正式正文与源码说明；12.39 的代理浏览器实验按逐题状态保留待验收。

CS:APP 全书解释复核见 [I018](../../issues/I018-csapp-explanations.md) / [T018](../../test/T018-csapp-explanations.md)。[第 5 章 §5.1](../../books/csapp/notes/chapter05_optimization.html#s5-1)逐句说明同址读写与 const 访问限制；其他补充位置由[逐项审阅记录](../../books/csapp/notes/explanation_review.json)链接回正式正文。本轮细化既有语义与计算条件，补充明确输入的推演；原题条件、维护程序的接口和计算口径沿用现有定义。

视觉群论的状态、动作、从左到右的字词、反序撤销及生成约定由[第 1 章 §1.4](../../books/visual-group-theory/notes/chapter01_what_is_a_group.html#s1-4)维护；非正式可逆性与整数平移生成元的语义分别见[习题 1.11](../../books/visual-group-theory/notes/chapter01_what_is_a_group.html#ex-1-11)和[习题 1.13](../../books/visual-group-theory/notes/chapter01_what_is_a_group.html#ex-1-13)。维护约定见[书级入口](../../books/visual-group-theory/agent.md)、[章节说明](../../books/visual-group-theory/notes/README.md)和[程序接口](../../books/visual-group-theory/code/README.md)，独立有限置换回归及阅读证据见 [T021](../../test/T021-visual-group-theory.md)。

视觉群论新增规则：Cayley 图、生成元和正 n 边形计数由[第 2 章](../../books/visual-group-theory/notes/chapter02_what_do_groups_look_like.html#s2-3)维护；刚体模型、舞步位置置换、饰带坐标及原图校注由[第 3 章](../../books/visual-group-theory/notes/chapter03_why_study_groups.html#s3-1)维护；行先列后、Q₄ 箭头乘法、A₄ 标签及群公理由[第 4 章](../../books/visual-group-theory/notes/chapter04_algebra_at_last.html#s4-4)维护。回归设计和执行见 [T022](../../test/T022-visual-group-theory-ch02-04.md)，反例表的来源输入为书级 notes/algebra_inputs.json。

测度与概率的集合系、广义实数运算和函数单调类条件由[第一章](../../books/measure-probability/notes/chapter01_measurable_spaces.html)维护；覆盖外测度、半环全空间覆盖、完全化及收敛的有限性条件由[第二章](../../books/measure-probability/notes/chapter02_measure_spaces.html)维护。原陈述与修正依据见[校注清单](../../books/measure-probability/notes/source_issues.json)，有限模型的位掩码、非负整数费用和有理数截断接口见[程序说明](../../books/measure-probability/code/README.md)，来源及独立回归见 [I023](../../issues/I023-measure-probability.md) / [T023](../../test/T023-measure-probability.md)。

测度与概率续写：积分存在条件、低阶 M_p/N_p 记号、矩比较和弱收敛由[第三章](../../books/measure-probability/notes/chapter03_integration.html)维护；符号测度的一侧有限约定、Hahn/Jordan 与 Lebesgue 分解、密度和条件期望版本由[第四章](../../books/measure-probability/notes/chapter04_signed_measures.html)维护。有限权重、零质量块、分数输出及整数上界见书级程序说明；条件与校注回归设计见 [T024](../../test/T024-measure-probability-ch03-04.md)。

视觉群论第 5—8 章规则入口：[置换次序、元素阶与 Cayley 定理](../../books/visual-group-theory/notes/chapter05_five_families.html#s5-4)，[左右陪集与有限群计数](../../books/visual-group-theory/notes/chapter06_subgroups.html#s6-4)，[商的良定义与半直积](../../books/visual-group-theory/notes/chapter07_products_and_quotients.html#s7-3)，[同态、核像、有限阿贝尔群分解](../../books/visual-group-theory/notes/chapter08_homomorphisms.html#s8-2)。原题条件及校注在这些正式页维护；设计与独立回归见 [T024](../../test/T024-visual-group-theory-ch05-08.md)，手读图/矩阵输入为书级 notes/structures_inputs.json。

视觉群论第 9—10 章规则入口：[作用约定、轨道稳定子与 Sylow 定理](../../books/visual-group-theory/notes/chapter09_sylow_theory.html#s9-1)，[最小多项式、分裂域、自同构与反向对应](../../books/visual-group-theory/notes/chapter10_galois_theory.html#s10-5)，[根式可解性及有限域题解](../../books/visual-group-theory/notes/chapter10_galois_theory.html#s10-7)。原题条件和校注以正式页为准；独立源输入 `notes/sylow_galois_inputs.json`，验证设计见 [T025](../../test/T025-visual-group-theory-ch09-10.md)。

2026-10-17 的 [I028](../../issues/I028-static-first-astro.md) 只改变构建及发布路径，教材计算规则、精度、题号和条件保持；逐字重建与 golden-master parity、原独立 Python 回归共同验证此边界。

2026-10-17 的 [I032](../../issues/I032-final-assessment-repairs.md) 补全[定理 1.5.5 修正条件的证明](../../books/measure-probability/notes/chapter01_measurable_spaces.html#theorem-1-5-5-proof)，并展开四个例子的已登记模型；原书编号与结论保留。命令入口的 ASCII 词法、负零与覆盖 mask 长度由[测度书程序说明](../../books/measure-probability/code/README.md)维护。C/Python 的数值算法与范围保持，空白、加号、Unicode 数字等非法输入统一拒绝，验证设计与故障变异见 [T032](../../test/T032-final-assessment-repairs.md)。

测度概率第五、六章：乘积 sigma 域、转移核、Fubini 有符号条件、相容概率与扩张由[第五章](../../books/measure-probability/notes/chapter05_product_spaces.html)维护；三级数、强弱大数律、特征函数及 CLT 的独立性、矩和尺度由[第六章](../../books/measure-probability/notes/chapter06_independent_sequences.html)维护。截断特征函数引理与习题归一化修正保留原说法、修正、依据；[校注清单](../../books/measure-probability/notes/source_issues.json)是定位入口。核矩阵与二项卷积的整数边界、浮点误差和零方差约定见[程序说明](../../books/measure-probability/code/README.md)，独立回归见 [T034](../../test/T034-measure-probability-ch05-06.md)。

2026-10-20 的 [I040](../../issues/I040-unified-reading-components.md) 恢复[测度概率习题 6.27](../../books/measure-probability/notes/chapter06_independent_sequences.html#ex-6-27)的原题四阶矩条件，将二阶矩推广放在解答说明；[Weiss 习题 12.1](../../books/weiss/notes/chapter12_advanced_data_structures.html#ex12-1)展开标准双层伸展的局部秩计账，区分简化版本所用论文引理与真实运行成本。有限枚举与显示条件回归见 `scripts/reading-components.test.mjs`，一般证明和外部引理依赖仍由正式正文表达。

EOPL 第三版准备批：词法/动态作用域、闭包创建环境、按值求值与错误条件由[序言闭包例子](../../books/eopl/notes/preface.html#scope-example)及[程序说明](../../books/eopl/code/README.md)维护；原书语义与 Python 教学子集分开标明。全书来源定位及准备阶段边界见[阅读计划](../../books/eopl/reading-plan.md)，执行和阅读证据见 [T042](../../test/T042-eopl-map-preface.md)。

EOPL 基础两章：递归终止度量、编号上下文、自然数表示、环境遮蔽、重复变量约定、zipper 重建和解析输入边界由[第 1 章](../../books/eopl/notes/chapter01_inductive_data.html)、[第 2 章](../../books/eopl/notes/chapter02_data_abstraction.html)及[程序接口](../../books/eopl/code/README.md)维护。原题及修正依据保留，实际 Racket 回归和计时口径见 [T048](../../test/T048-eopl-ch01-02.md)。

2026-10-21 的 [I052](../../issues/I052-reader-contract.md) 将 [RN-001 v1.10](../reading-notes-standard.md) 的完整中文题干、必需注解、统一索引和直接 PDF 定位固化为独立阅读契约。题干里的分布、独立性、任务动词、原程序与前置定理已按来源补齐，详情与验证边界见 [T052](../../test/T052-reader-contract.md)。视觉群论 [7.18(h)](../../books/visual-group-theory/notes/chapter07_products_and_quotients.html#ex-7-18) 以原书 PDF 第 166 页的 48 个动作终点为准，商图按同一作用诱导；可执行检查同时核对数据端点、箭头标记和实际 SVG 路径，避免用另一个 16 阶群代替原图。

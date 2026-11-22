# SICP：维护入口

先读[规则职责索引](../../docs/rules/README.md)、[RN-001](../../docs/reading-notes-standard.md)、[RN-002](../../docs/reading-presentation-standard.md)、[阅读计划](reading-plan.md)及[页面说明](notes/README.md)。命令从主仓库根目录执行。

- 只以本仓库 `sicp.pdf`（第二版 Texinfo 2.andresraba5.6，883 页）定位。正文页码加 28 得 PDF 页序，前置罗马页码单独映射。不能使用常见纸质版或网页版页码。
- 当前范围七页，包括全书地图、前言与两版序言、完整五章，各章分别为 46、97、82、79、52 题。不要将独立清单数量当完成数量。
- 正文唯一维护源是 `src/content/books/sicp/*.html`。执行 `node scripts/sync-legacy.mjs --write` 展开共同 CSS/JS 到 `notes/*.html`；不要直接编辑镜像。样式与控制器的选择见 notes/README。
- PDF `notes/source_manifest.json` 和 `notes/source_inventory.json` 独立保存原书身份、152 个书签条目、22 个主要节、356 道题定位。未编号陈述/正文例子在以后获授权扩章时细化，不虚构全书校勘已完成。
- 代换与环境、过程的语法递归与计算过程形态、数据闭包性质与过程闭包、非确定性与随机性、语义与资源成本分别解释。原书历史语言比较按其上下文陈述。
- 根检查器已登记 `tools/check_notes.py`，--quick检查来源/给定输入/程序镜像；不带--quick实际运行Racket回归。代码唯一源为code/下.rkt，页面片段和完整阅读副本须同步，不把结构通过当程序执行。第一章实测Racket8.10，历史EOPL8.17不是本次运行版本。
- 数值阈值、折叠方向、随机实验范围见notes/README与code/README；Miller–Rabin的1.28校注须保留最终余数不为1这一拒绝条件。
- 来源图像、日志与浏览器输出放忽略目录 tmp/；第一章证据见review/chapter01.json与根T075。历史review/map-introduction.md及T073不重写。生产发布须另有用户授权。

[逐节原文图、表与摘录清单](../../docs/visual-contract.json)登记第 1 章 18 个二级小节、Figure 1.1–1.5 的等价呈现和 1.14 的调用树。

### 第 3 章 · 模块化、对象和状态

I087 验收时为地图、引言及第 1–3 章，共 5 页、225 题。第 3 章对应 PDF 322–514，包含 82 题、19 个二级小节。可变序对使用 Racket 可变序对适配；并发示例采用明确交错模型，流测试读取有限前缀。

### 第 4 章 · 元语言抽象

I088 验收时为 6 页、304 题。第 4 章对应 PDF 515–693，4 大节、17 个二级小节；查询系统实现另分 8 个细目。程序验证使用 Racket 8.10。

### 第 5 章 · 寄存器机器里的计算

全书地图、引言及五章正文共 7 页、356 题。第 5 章对应 PDF 694–861，含 5 个大节、22 个二级小节与 52 道习题。程序以 Racket 8.10 执行；末两题用 GCC 编译 C99 控制器，数据操作通过本地运行时提供。

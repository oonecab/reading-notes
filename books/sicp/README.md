# SICP · 计算机程序的构造和解释

当前提供[全书地图](notes/book_overview.html)、[引言：前言与两版序言](notes/preface.html)和[第 1 章：用过程构造抽象](notes/chapter01_procedures.html)。第一章覆盖18个二级小节及习题1.1–1.46的完整中文题干、解答和可运行示例；第2—5章保留章意与原书入口。

原书为第二版 Unofficial Texinfo Format 2.andresraba5.6，用户提供的 [PDF](sicp.pdf) 共 883 页。所有原书索引使用该文件；网页版只辅助核对文字，不参与构建，也不提供页码。身份、分段页序、许可与本批范围由[来源清单](notes/source_manifest.json)维护。

维护先读 [agent.md](agent.md)、[阅读计划](reading-plan.md)和[页面说明](notes/README.md)。受控源在 `src/content/books/sicp/`；notes 下 HTML 为展开镜像。根目录执行 `python tools/project.py check-local --book sicp`、`python books/sicp/tools/check_notes.py`（完整程序回归）和 `python tools/project.py build`。程序接口见[code/README](code/README.md)，第一章证据与平台边界见[T075](../../test/T075-sicp-chapter01.md)；早期地图/引言记录T073保留。

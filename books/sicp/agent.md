# SICP：维护入口

先读[规则职责索引](../../docs/rules/README.md)、[RN-001](../../docs/reading-notes-standard.md)、[RN-002](../../docs/reading-presentation-standard.md)、[阅读计划](reading-plan.md)及[页面说明](notes/README.md)。命令从主仓库根目录执行。

- 只以本仓库 `sicp.pdf`（第二版 Texinfo 2.andresraba5.6，883 页）定位。正文页码加 28 得 PDF 页序，前置罗马页码单独映射。不能使用常见纸质版或网页版页码。
- 当前范围三页：全书地图、前言与两版序言、第一章。第一章18个二级节与46题全部覆盖；全书356题中仅46题完成，第二章以后仍为章意。不要将独立清单数量当完成数量。
- 正文唯一维护源是 `src/content/books/sicp/*.html`。执行 `node scripts/sync-legacy.mjs --write` 展开共同 CSS/JS 到 `notes/*.html`；不要直接编辑镜像。样式与控制器的选择见 notes/README。
- PDF `notes/source_manifest.json` 和 `notes/source_inventory.json` 独立保存原书身份、152 个书签条目、22 个主要节、356 道题定位。未编号陈述/正文例子在以后获授权扩章时细化，不虚构全书校勘已完成。
- 代换与环境、过程的语法递归与计算过程形态、数据闭包性质与过程闭包、非确定性与随机性、语义与资源成本分别解释。原书历史语言比较按其上下文陈述。
- 根检查器已登记 `tools/check_notes.py`，--quick检查来源/给定输入/程序镜像；不带--quick实际运行Racket回归。代码唯一源为code/下.rkt，页面片段和完整阅读副本须同步，不把结构通过当程序执行。第一章实测Racket8.10，历史EOPL8.17不是本次运行版本。
- 数值阈值、折叠方向、随机实验范围见notes/README与code/README；Miller–Rabin的1.28校注须保留最终余数不为1这一拒绝条件。
- 来源图像、日志与浏览器输出放忽略目录 tmp/；第一章证据见review/chapter01.json与根T075。历史review/map-introduction.md及T073不重写。生产发布须另有用户授权。

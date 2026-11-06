# SICP：维护入口

先读[规则职责索引](../../docs/rules/README.md)、[RN-001](../../docs/reading-notes-standard.md)、[RN-002](../../docs/reading-presentation-standard.md)、[阅读计划](reading-plan.md)及[页面说明](notes/README.md)。命令从主仓库根目录执行。

- 只以本仓库 `sicp.pdf`（第二版 Texinfo 2.andresraba5.6，883 页）定位。正文页码加 28 得 PDF 页序，前置罗马页码单独映射。不能使用常见纸质版或网页版页码。
- 当前范围仅两页：全书地图、前言与两版序言。五章只有章意摘要；356 道原书题是独立清单数量，不是完成数量。本批零题解、零可运行程序。
- 正文唯一维护源是 `src/content/books/sicp/*.html`。执行 `node scripts/sync-legacy.mjs --write` 展开共同 CSS/JS 到 `notes/*.html`；不要直接编辑镜像。样式与控制器的选择见 notes/README。
- PDF `notes/source_manifest.json` 和 `notes/source_inventory.json` 独立保存原书身份、152 个书签条目、22 个主要节、356 道题定位。未编号陈述/正文例子在以后获授权扩章时细化，不虚构全书校勘已完成。
- 代换与环境、过程的语法递归与计算过程形态、数据闭包性质与过程闭包、非确定性与随机性、语义与资源成本分别解释。原书历史语言比较按其上下文陈述。
- 根检查器已登记 `tools/check_notes.py`，支持 --quick；本批没有程序，完整书级检查检查来源与范围，不冒充 Scheme 执行。后续程序默认在 code/ 维护，同步阅读副本。
- 来源图像、日志与浏览器输出放忽略目录 tmp/；分层审阅见 review/map-introduction.md 和根 T073。生产发布须另有用户授权。

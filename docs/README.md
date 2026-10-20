# 文档职责索引

<!-- project-governance:managed:start -->
每类事实只能有一个权威来源：

- `../TECH.md`：技术栈、架构、路径、依赖、兼容边界与技术栈变更索引。
- `../AGENTS.md`：短小的 Agent 入口和不可协商红线。
- `../.project-governance.json`：结构化项目设置与已登记命令。
- `governance/`：工作流、测试、安全、变更控制、发布和风险规范。
- `environments.md`：不含秘密的环境变量名、服务和端口清单。
- `rules/`：公式、统计口径、舍入、单位、币种、时间边界等业务/计算规则的权威文档。
- `decisions/`：受控级别下难以回退的技术与架构决策。

禁止在多个文件中手工维护同一事实。其他文档必须链接到权威来源。代码变更完成前必须评估并同步受影响文档。
<!-- project-governance:managed:end -->

## 项目文档

- [人类入口](../README.md)与 [书籍登记](../books/catalog.json)。
- [统一部署与恢复](../deploy/README.md)：实际发布步骤的唯一操作说明。
- [治理更新流程](governance-updates.md)。
- [RN-001 读书笔记共同标准](reading-notes-standard.md)：跨书的来源、全书规划、伴读讲解、题解、程序、版式与分层验收方法；[新书模板](templates/reading-notes/README.md)记录书级事实。
- [新增子项目](adding-a-book.md)与 [本次迁移](migration-20261012.md)。
- [架构决策](decisions/ADR-001-book-subprojects.md)、[问题单](../issues/I001-project-merge.md)、[计划](../plan/P001-project-merge.md)、[测试设计](../test/T001-project-merge.md)与 [里程碑](../milestone/M001-project-merge.md)。
- [书籍内容与计算规则入口](rules/README.md)；专项正文规范随各书维护。
- [EOPL 地图与序言批](../books/eopl/README.md)：全书地图、两篇序文、习题 0.1；来源清单、当前范围与后续代表章见[阅读计划](../books/eopl/reading-plan.md)，准备批验收见 [T042](../test/T042-eopl-map-preface.md)，统一排版与有限范围发布见 [T044](../test/T044-reading-typography.md)。
- [CS:APP 第一批笔记](../books/csapp/README.md)：[I002](../issues/I002-csapp-part-one.md)、[P002](../plan/P002-csapp-part-one.md)、[T002](../test/T002-csapp-part-one.md)、[M002](../milestone/M002-csapp-part-one.md)。

- [CS:APP 全书地图与第一部分伴读](../books/csapp/notes/README.md)：[I003](../issues/I003-csapp-companion.md)、[P003](../plan/P003-csapp-companion.md)、[T003](../test/T003-csapp-companion.md)、[M003](../milestone/M003-csapp-companion.md)。

- [CS:APP 原文、公式与阅读修订](../books/csapp/notes/source_excerpts.json)：[I004](../issues/I004-csapp-source-reading.md)、[P004](../plan/P004-csapp-source-reading.md)、[T004](../test/T004-csapp-source-reading.md)、[M004](../milestone/M004-csapp-source-reading.md)。

- [CS:APP 第三部分伴读](../books/csapp/notes/book_overview.html#part-iii)：[I007](../issues/I007-csapp-part-three.md)、[P007](../plan/P007-csapp-part-three.md)、[T007](../test/T007-csapp-part-three.md)、[M007](../milestone/M007-csapp-part-three.md)。

- [跨书方法固化](reading-notes-standard.md)：[I009](../issues/I009-reading-notes-standard.md)、[P009](../plan/P009-reading-notes-standard.md)、[T009](../test/T009-reading-notes-standard.md)、[M009](../milestone/M009-reading-notes-standard.md)。

- [视觉群论伴读](../books/visual-group-theory/README.md)：全书地图、序言、第 1—10 章与 302 题；全书一致性修订 [I026](../issues/I026-visual-group-theory-polish.md) / [T026](../test/T026-visual-group-theory-polish.md)；第 9—10 章 [I025](../issues/I025-visual-group-theory-ch09-10.md) / [T025](../test/T025-visual-group-theory-ch09-10.md)，第 5—8 章 [I024](../issues/I024-visual-group-theory-ch05-08.md) / [T024](../test/T024-visual-group-theory-ch05-08.md)，第 2—4 章历史 [I022](../issues/I022-visual-group-theory-ch02-04.md) / [T022](../test/T022-visual-group-theory-ch02-04.md)，首批 [I021](../issues/I021-visual-group-theory.md)、[P021](../plan/P021-visual-group-theory.md)、[T021](../test/T021-visual-group-theory.md)、[M021](../milestone/M021-visual-group-theory.md)。

- [测度论与概率论基础伴读](../books/measure-probability/README.md)：全书总览、序言与前言、前四章和 115 题；本批 [I024](../issues/I024-measure-probability-ch03-04.md) / [T024](../test/T024-measure-probability-ch03-04.md)，首批 [I023](../issues/I023-measure-probability.md)、[P023](../plan/P023-measure-probability.md)、[T023](../test/T023-measure-probability.md)、[M023](../milestone/M023-measure-probability.md)。

- [Astro 静态构建决策](decisions/ADR-002-static-first-astro.md)：技术事实见 TECH.md，实施 [I028](../issues/I028-static-first-astro.md)，测试与停止条件 [T028](../test/T028-static-first-astro.md)。

- [Astro 内容维护](astro-authoring.md)：受控源、旧检查镜像、冻结基线及分阶段证据。
- [Ubuntu 静态发布](../deploy/UBUNTU.md)：安装、权限、不可变版本、原子切换与故障恢复。

- [Astro 迁移交付报告](astro-migration-report.md)：全量命令、parity、浏览器、可复现发布与保留范围。

- [Astro 生产发布记录](astro-production-report.md)：I029 的 Git、Ubuntu/systemd、公网验证与旧布局恢复点。

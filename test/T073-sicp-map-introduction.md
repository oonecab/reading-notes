# T073 · SICP 地图与引言验收

独立依据：用户指定本仓库 PDF；RN-001/RN-002；PDF 封面/版权/目录/序文和正文页码，不从新页面反推来源。

| 层次 | 预期 |
|---|---|
| 来源 | SHA-256、883 页，前置罗马页码独立登记，正文 p.1 对应 PDF29，各章/节的页序正确 |
| 范围 | 仅地图和引言两页、零原书习题解答；地图五节点都明确为章意，指向真实摘要标题 |
| 反例 | 错误 PDF 哈希、错页、缺失章、断链、伪造章节导航均应被现有/书级检查拒绝 |
| 内容 | Perlis 前言、第二版和第一版序言的主张与顺序可追溯；归纳、译义与引用分明 |
| 阅读 | 1800/1440/1024/390px、无脚本；逐节注解、地图五入口、目录/导航和本书 PDF 点击 |
| 集成 | 根本地结构检查、Node 测试、正式构建、两页 parity、离线矩阵和来源发布路径 |

以下为实际执行记录。完整 check / 本地 HTTPS 发布演练的 Windows 平台限制单列，不称全部门禁通过。

## 已执行的来源与静态检查

- PDF实际身份、页数、分段页码和22主要节定位通过；全书356题独立定位，本批零题解。书级完整来源检查通过，61个PDF链接均是本仓库原文件，并拒绝4种来源/范围变异。
- Node 24.22.1 / pnpm11.25.0 / Python3.12.14；测试进程PATH使用已有配套运行时，不改机器默认设置。初次使用系统Python3.14.3因缺tzdata失败，记录为环境失败，随后换用已有配套Python。
- pnpm test：135通过、0失败、0跳过，日志tmp/sicp/node-tests.log。共同组件/字体/阅读呈现静态检查覆盖71页；源码结构7书/142个Python源/1306文档链接通过。
- 根 check --book sicp --quick 在test_publish_durability.py出现2项Windows能力错误（缺rsync、POSIX目录fsync）；保留tmp/sicp/root-quick.log与tmp/project-check/20261106T221826-z0c07j7p/report.json。本书源码检查另行完整执行，不把根完整门禁记为通过。

## 失败与修复

- 首次受支持运行时构建在首页预算失败：21726B > 21000B。仅精简新SICP卡片并更新七书计数，最终首页20959B、gzip6776B；预算未提高。原始日志tmp/sicp/build-first-performance-failure.log。
- 第一轮SICP离线浏览发现390px地图继承共享SVG min-width620px，违反compact图初始可见要求。失败保留在tmp/reading-notes-migration/browser/sicp/runs/2026-11-06T14-24-05-389Z-26c6683e/；只修改SICP图的min-width/max-width，源镜像390px实际测得横坐标39–351、宽312。文字、节点、边和PDF链接保持。
- 接受前的两份本地Git来源快照和散列变化保存于books/sicp/review/baseline-history.json；旧快照作为新快照父提交保留，主分支与真实暂存区未被改写。

最终构建与浏览器结果见下节，初次失败保留原记录。

## 最终本地构建与阅读

最终构建 `python tools/project.py build` 成功，release `20261106T222526`，71受控阅读页、94公开HTML、594文件；本地包位于deploy/portal-releases/20261106T222526。71页parity、原性能预算与CSP实机检查通过；CSP9代表页、13脚本散列及篡改脚本被阻止。SICP另跑独立parity两页、零差异。

最终Chrome157.0.8103.39离线验收：3公开页（两阅读页和一个重定向）、12个有脚本视图、6个无脚本视图；正式阅读页分别为8/4视图。覆盖1800/1440/1024/390，17个必需注解小节，5个地图节点在1440/390及390无脚本的实际点击、键盘、同锚点重复与最终标题可见性；390表格局部横滚、目录点击、全部折叠展开后整页宽度均通过。报告tmp/reading-notes-migration/browser/sicp/runs/2026-11-06T14-28-58-312Z-5467d8ef/report.json。产生30张矩阵截图；实际打开其中8张，并额外打开书架1440/390及两页390无脚本文字位置4张，共12张；清单与散列在books/sicp/review/astro-migration.json，不把生成30张当成人工看过30张。

实际点击书架SICP标题→地图→引言→前言PDF13，URL为/sicp/sicp.pdf#page=13，HTTP200。Chrome页响应暴露601字节PDF查看器HTML壳，初次将它当PDF字节比较导致失败；探针确认后，分开核对查看器实际URL/状态与同地址原始HTTP响应，后者7645685字节SHA-256与仓库原书一致。失败/探针保留tmp/sicp/reader-path-first-failure.json、reader-path-viewer-probe.json；最终报告tmp/sicp/reader-path.json。没有删除PDF身份断言。

程序执行不适用：本批未提供运行程序；没有宣称运行原书求值器、模拟器或编译器。原书阅读为全书结构及主要节叙述通览、前言和两版序言精读；没有声称883页逐页精读或356题解答。未执行实体手机、其他浏览器、读屏器、Nginx本地HTTPS、完整POSIX门禁与生产部署；内容与本地阅读范围不依赖这些未做的发布操作。

文档同步：书级入口/计划/来源/审阅、catalog、共享阅读契约、书架与七书计数、规则职责、TECH、AGENTS、治理源码边界、I/P/T/M均同步。无技术栈、计算规则、服务、变量或端口变化，故无ADR及环境文件改动。

最终根入口 `python tools/project.py check-local --book sicp` 通过，报告tmp/project-check/20261106T223236-bxxmvi52/report.json；包括SICP来源/链接/范围、71页共用阅读/呈现/排版契约、旧源与当前输出审阅绑定。该命令的scope为local-structure，不替代前述受环境限制的完整发布门禁。`git diff --check` 通过；真实暂存区保持原样，用户提供PDF字节保持。

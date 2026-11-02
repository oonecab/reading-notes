# T071 构建收尾与 change-verification

## 版本与预期

日期：2026-11-02 至 2026-11-03（Asia/Shanghai）。基线 `6e25f11d805d49f27e04ab1791bc1627e5963b0a`，分支 `codex/windows-check-cli`，包含 I069/I070/I071 未提交修复。最终逐文件 SHA-256 及证据索引在忽略目录 `tmp/i071/verification.json`。

依据：既有性能预算、独立 legacy DOM parity、历史审阅 SHA-256、RN-001/RN-002 及 reader-contract / reader-sources / reader-presentation 登记。测试运行当前实现，期望不从压缩后的文件反推。此次没有修改教材题干、公式、来源、CSS 或页面脚本。

实测 Windows、Node 24.22.1、pnpm 11.25.0、Python 3.12.1、Astro 7.4.0、Playwright 1.62.1、Chrome 156.0.8078.79。测试进程 PATH 显式选择支持的 Node；机器默认 node 仍为 24.14.0，未改全局 PATH，直接使用该旧版本仍会被工具链门禁拒绝。

## 执行结果

| 检查 | 状态 | 实际证据 |
|---|---|---|
| pnpm install --offline --frozen-lockfile | pass | tmp/i071/install-frozen.log，锁文件与安装一致 |
| pnpm test | pass | tmp/i071/tests-final.log：135 项，失败/跳过均 0 |
| python tools/test_local_verification.py | pass | tmp/i071/doctor-tests.log：4 项；最终 check-local 再次包含此组 |
| python tools/test_reader_views.py | pass | tmp/i071/reader-views.log：13 项，含历史字节绑定正反例 |
| doctor --for build | pass（前置条件） | tmp/i071/doctor-build.json；prerequisites_met，runtime_verified=false |
| python tools/project.py check-local | pass | tmp/project-check/20261103T001009-1hr7imul/report.json：20 项命令，六书、公共契约及历史绑定；scope=local-structure |
| python tools/project.py build | pass | tmp/i071/build-final.log；tmp/reading-notes-migration/build.json；69 阅读页、91 公开 HTML、587 文件；release 20261103T000200 |
| 独立 DOM parity | pass | tmp/reading-notes-migration/parity/all.json，69 页，差异 0 |
| 全站原性能预算 | pass | tmp/reading-notes-migration/performance-budget.json，91 页；随机过程第 1 章 gzip 306585 <= 306632 字节 |
| 构建后呈现契约 | pass | tmp/reading-notes-migration/presentation-dist.json，errors=[] |
| 真实 CSP 与篡改负例 | pass | tmp/reading-notes-migration/csp/runs/2026-11-02T16-05-23-173Z-8e70f84e/report.json：9 代表页、13 脚本散列，篡改脚本被阻止 |
| 全站离线浏览器 | pass | 下方不可变运行记录：91 页，364 JS 视图、182 no-JS 视图，external_requests=[] |
| WSL Ubuntu 发布持久性/策略/缓存单元 | pass | python3 tools/test_publish_durability.py 5 项（终端执行）；test_publish_policy.py 7 项、test_cache_delivery.py 6 项，后两组日志 tmp/i071/linux-policy.log、linux-cache.log；共 18 项 |
| 正式包本地预览 | pass | tmp/i071/preview.json；从正式包启动，首页及随机过程/CSAPP/EOPL 代表页 HTTP 200，响应与 dist 逐字节一致 |

浏览器最终记录：`tmp/reading-notes-migration/browser/all/runs/2026-11-02T16-14-49-969Z-d04de3c9/report.json`。使用原恢复机制复用 426 个已完成视图，逐项核对 HTML 与截图散列及必需字段；重定向页面、未完成视图和失败的无脚本地图重新执行。完整命令及结果在 `tmp/i071/offline-resume.log`，前次 `2026-11-02T16-07-01-395Z-cff46fca` 记录不覆盖。最终 546 个视图由可追溯的已完成证据组成，不声称一次运行从头到尾通过。

## 失败、原因与回归

- 原 gzip 306796 超出 306632；保持预算/压缩级别，仅简化产物安全 id/class/data-* 引号，最终 306585。原始失败见 T070；自闭合斜杠错误变体在 tmp/i071/compact-negative.log，修复后的两个单元纳入 135 项。字节敏感 pre/code/math/svg/script/style/textarea 均保持。
- 第一轮 CSP 在 tmp/i071/build.log 失败：新建 CDP 会话未启用 Page domain，导致注入观察器不存在。驱动先启用 Page，重跑同一 CSP 与篡改断言通过；没有关闭 CSP。
- 第一轮离线 `2026-11-02T16-06-11-694Z-150c4080` 在手机横滚失败。滚轮返回不代表合成器完成滚动，现有限时等待真实 scrollLeft 增长，仍保留原位移断言。[Playwright wheel 契约](https://playwright.dev/docs/api/class-mouse#mouse-wheel)与实际失败一致。
- 原历史产物检查拒绝压缩后的属性语法。使用独立 Python HTMLParser 仅还原允许的引号，之后继续匹配原逐字节 SHA-256 和既有图标例外；历史摘要不重写。正文、属性值、脚本、保护岛变化均拒绝。新测试在隔离的 HEAD 检查器上实际 1 失败/12 通过（tmp/i071/reader-views-negative.log），当前 13/13。
- 无脚本地图发生真实导航时 evaluate 上下文被销毁。waitLanding 只对该错误做有界重试，重置稳定状态，仍要求正确 URL/标题/可见几何三次稳定读数；未知错误立即抛出，持续导航超时失败。新增两项先失败（map-negative.log），修复后该组 7/7（map-pass.log）。

## 图像观察与边界

实际打开查看 8 张成品截图：前次运行目录下 `csapp_notes_chapter02_information-390-reading.png`、`stochastic_notes_chapter01_markov_chains-1800-reading.png`、`eopl_notes_chapter03_expressions-390-reading.png`、`measure-probability_notes_chapter03_integration-1800-reading.png`、`visual-group-theory_notes_chapter06_subgroups-390-reading.png`、`weiss_notes_chapter02_algorithm_analysis-1800-reading.png`；最终目录下 `csapp_notes_book_overview-no-js-390.png` 与 `eopl_notes_chapter03_expressions-no-js-390.png`。正文、固定导航、公式、注解及代码在所看位置可读；长式/代码使用局部横滚。此为六书代表位置抽查，不冒充 91 页人工逐页复读或原书逐题复核。全量交互矩阵与抽查分开记录。

未执行：全套原生 C/Racket 程序矩阵、macOS/多 Node 版本实际构建矩阵、Nginx 本地 HTTPS 演练、生产部署及公网验收。这些不是本次工具配置修复完成的证据；Windows 完整 check/check --quick 仍保留 POSIX 门禁，不能以 check-local 替代。WSL 单元证明代码断言通过，不证明真实掉电恢复。生产发布实现未修改。

## 文档与交付

TECH、.project-governance.json、.env.example、环境说明、README、Astro 编写说明、测试规范及 I/P/M/T071 已同步。I068/I070 的失败与阻塞保留为历史，由本记录关联后续修复。代码、测试与文档的变更只涉及工具执行、产物语法和证据可移植性，教材计算规则无需改动。

结论：本次本地配置修复及适用验证通过；未提交、未推送、未部署。默认 Node 的切换仍由使用者的 shell/toolchain 选择决定。

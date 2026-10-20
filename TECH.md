# Reading Notes — 技术事实唯一来源

<!-- project-governance:managed:start -->
## 项目目的

统一管理 Durrett 随机过程、Weiss 数据结构、CS:APP 系统、Carter 视觉群论与程士宏测度概率笔记，保留正式 HTML、可运行示例、来源与验证记录，共用阅读入口和静态发布流程。

## 项目分类

- 项目类型：`generic`
- 治理级别：`controlled`

## 技术栈基线

### 语言

- HTML / CSS / JavaScript
- 静态 MathML / SVG
- C11
- Python 3

### 框架与核心库

- Python 标准库独立检查
- Astro 7.4.0 静态构建；受控 HTML 与局部交互（五书迁移已分批验收，见 ADR-002）

### 运行时与工具链

- Python 3.10+
- Clang（C11、AddressSanitizer、UndefinedBehaviorSanitizer）
- Make
- Poppler pdftotext / pdfinfo
- Node.js 24.21.0 LTS（仅构建）
- pnpm 11.21.0（锁定依赖）
- Nginx（服务器静态 HTTPS 服务）
- Ego Lite / ego-browser（构建 CSP 冒烟与离线浏览器验收）

## 源码边界

- books/stochastic
- books/weiss
- books/csapp
- books/visual-group-theory
- books/measure-probability
- portal
- deploy
- tools
- src
- scripts

## 架构事实

- books/catalog.json 登记书籍入口、目录和发布前缀；src/content/books/<book>/ 逐章维护受控 HTML，books/<book>/notes/*.html 保留为独立检查使用的兼容镜像。
- 随机过程、CS:APP、视觉群论和测度概率以 code/ 下 C/Python 为维护源并同步 HTML；Weiss 教学代码以正式 HTML 为维护源，c/ 为原书图例的独立 C 实现。
- 根目录工具统一调用各书既有校验器，输出写入被忽略的 tmp/ 或 deploy/portal-releases/。
- 统一构建保留 /stochastic/、/weiss/、/csapp/ 并接入 /visual-group-theory/、/measure-probability/ URL；部署使用独立版本目录和 current 原子切换，同时维护本版 CSP。
- 根 Git 历史与远端沿用；原 Weiss 工作目录保留，合并后的维护入口为本仓库。

## 项目类型约束

- 明确领域边界，并在 TECH.md 中记录项目专属架构事实。

## 项目专属规则

- 新增或修改书籍先读 docs/reading-notes-standard.md（RN-001），再读 books/<书籍>/agent.md 与 notes/README.md；共用方法与书级专项约定各有唯一来源。
- 保留原书条件、题号、版本、来源页码和校注依据；静态检查和执行样本不能替代原书内容核对。
- 保留单文件 HTML 的章节顺序、锚点、离线能力与桌面/窄屏阅读行为。
- 审阅文件的历史哈希保持历史事实；改变当前文件绑定时注明范围、原因和原值。
- 新增书籍按 docs/adding-a-book.md 与 docs/templates/reading-notes/ 执行，先核对原书、规划全书并验收样章；同步 catalog、首页、构建路由、验证与来源说明，只维护一份正式内容。
- 统一部署的操作说明以 deploy/README.md 为准；各书 deploy/ 为保留的单书工具与历史材料。
<!-- project-governance:managed:end -->

## 已确认的技术细节

当前维护路径以本文末尾 Astro 状态及 docs/astro-authoring.md 为准。以下 I001–I027 对应历史批次，其中“沿用原工具链”“正式 HTML 维护源”等措辞描述当时实现；其教材范围、模型与程序证据继续有效。

每本书的实际目录和预期范围以 [books/catalog.json](books/catalog.json) 为准。源布局与发布布局分开：`books/<id>/` 保存维护源，归档使用 `<publish_prefix>/` 保持站点地址。共同命令依赖各书原检查器，不重新实现数学校验；压缩包只包含显式清单中的发布文件。各书保留原单书构建器，公共构建复用随机过程的确定性归档函数。

内容与计算规则的权威入口见 [规则职责索引](docs/rules/README.md)，兼容取舍见 [ADR-001](docs/decisions/ADR-001-book-subprojects.md)。

随机过程详细过程的分批修订见 [I015](issues/I015-stochastic-derivations.md) / [T015](test/T015-stochastic-derivations.md)。标准库脚本 `books/stochastic/tools/derivation_coverage.py` 从原来源清单枚举 115 条结果、162 例和 236 题，验证证明目标、逐项过程与证明块入链。公共检查现对全书 513 项运行过程门禁、清单新鲜度检查和错链等反例回归；单独 `--check` 使用同一全书范围。正式 HTML 继续是正文唯一维护源，现有 CSS/JS、MathML 和发布结构保持；本轮没有技术栈或环境约定变更。

第一章按读者认可的例 1.4 深度完成逐项解释修订，范围和验收见 [I016](issues/I016-stochastic-chapter1-explanations.md) / [T016](test/T016-stochastic-chapter1-explanations.md)。逐项审阅记录绑定 164 项内容，涵盖模型、系数、证明条件及消元理由；习题 1.66 的原书计时边界另有精确回归。教学解释的人工读回与结构、计算、浏览器证据分别记录，运行时和发布机制沿用现有约定。

第 2—6 章及附录 A 的 349 项解释修订见 [I017](issues/I017-stochastic-remaining-explanations.md) / [T017](test/T017-stochastic-remaining-explanations.md)：106 例、84 条定理／引理、159 题及小问逐项对照原书并读回，补齐独立证明入口和每一步的理由。`notes/remaining_explanation_review.json` 绑定逐项内容、来源和浏览器证据。维护回归覆盖全书 48 组线性系统，以及服务开始链与真实时间分布、竞争时钟、无限服务台、倍增赌局、金融路径和节点复制、历史报价舍入、收敛条件等计算边界；这些有限回归与一般定理的数学审阅分别记录。

跨书伴读方法由 [RN-001](docs/reading-notes-standard.md)维护，新书按[接入步骤](docs/adding-a-book.md)和[工作模板](docs/templates/reading-notes/README.md)执行。该层只统一内容生产及验收方法，书级来源/计算规则和历史审阅保持原权威位置；现有按书检查与构建仍需显式接线。本次方法固化见 [I009](issues/I009-reading-notes-standard.md)，技术栈与服务环境保持不变。

CS:APP 子项目当前为第三版 Global Edition 的全书地图、序言、第 1 章、Part I 第 2—6 章、Part II 第 7—9 章与 Part III 第 10—12 章，共十四页。正文沿 117 个大节、261 个二级节展开，涵盖 419 道本版原书题、36 道补充自测。`code/` 是 C/Python 维护源，固定宽度运算、ABI、Y86、优化与缓存条件随正文说明；源码及额外汇编/性能基准由 `code/programs.json` 登记。`tools/check_notes.py` 核对来源、逐题页码、源码同步和独立计算基准。普通 C 使用 C11 编译并配合 ASan/UBSan；按字填充明确使用 GNU/Clang may_alias 扩展，x86-64 分类汇编经 Rosetta 执行，Linux 跨目标汇编生成另列，Y86 教学模型与官方 yas/yis/ssim/psim 执行分别记录，code/y86/ 提供七个 HCL 补丁、31 个输入与复现命令；官方旧工具以 GNU89、Clang、Lex 兼容选项构建，普通教学程序继续使用严格 C11。完整原 PDF 按来源清单的 publication.include_source_pdf 纳入构建包，当前已启用；发布页保留章节、来源和习题的 #page 页序链接，关闭收录时退回文字来源。接入与本地验收见 [I011](issues/I011-csapp-pdf-navigation.md) / [T011](test/T011-csapp-pdf-navigation.md)。宽屏目录和右侧阅读注解、窄屏折叠、题目/代码结构沿现有两书版式。详见 [I003](issues/I003-csapp-companion.md) 和 [T003](test/T003-csapp-companion.md)。

CS:APP 原文清单 `notes/source_excerpts.json` 保留第一批 78 处摘录并追加第二部分摘录、来源页和英文正文，其中第 2 章保留 25 条原书 `PRINCIPLE`。数学以静态 MathML 表达，共用块公式和行内公式容器。维护回归增加 Python 容器上界、四种缓存写策略的独立参考与脏位变异检查、`-DNDEBUG` 填充验证；浏览器阅读验收使用独立 Chrome DevTools MCP 实例，证据写入忽略目录。相关模型条件与阅读验证见 [I004](issues/I004-csapp-source-reading.md) 和 [T004](test/T004-csapp-source-reading.md)，运行时和发布架构保持既有设置。

CS:APP 第二部分新增 ELF/归档搜索与重定位模型、POSIX 进程/信号示例、地址翻译与堆分配模型。严格 C11 是编译语言基线，POSIX 接口通过特性宏显式请求并记录 macOS 宿主执行条件；Linux/x86-64 ELF 的跨目标对象生成与宿主程序运行分开验收。新增范围与对应计算契约见 [I005](issues/I005-csapp-part-two.md) 和 [T005](test/T005-csapp-part-two.md)，没有引入新运行时、前端框架或服务。后续信号等待、作业退出清理和 next-fit 独立回归修订见 [I006](issues/I006-csapp-part-two-review-fixes.md) / [T006](test/T006-csapp-part-two-review-fixes.md)。

CS:APP 第三部分增加可靠读写、描述符共享、回环网络和 HTTP、POSIX 线程及并发状态模型。程序继续沿用 C11/Python 与 POSIX 接口；线程程序显式使用 `-pthread`，Python 独立程序在索引中单独声明并核对预期输出。接口语义、宿主实验和状态模型分别记录。来源与计算契约见 [I007](issues/I007-csapp-part-three.md) / [T007](test/T007-csapp-part-three.md)，未改变核心依赖或服务环境。

第三部分全书评估后的 HTTP Expect 首部决策、select/echo 接入与既有连接处理、proc tfgets 计时器取消修订见 [I008](issues/I008-csapp-part-three-review-fixes.md) / [T008](test/T008-csapp-part-three-review-fixes.md)。修复继续使用既有 C11/POSIX 与静态发布流程。

CS:APP 第二轮严格评估修订见 [I010](issues/I010-csapp-review-v2-fixes.md) / [T010](test/T010-csapp-review-v2-fixes.md)，继续使用现有 C11/POSIX、Python 和静态页面流程。必要自测在关闭断言时仍执行；原题实验按逐项证据标记，12.39 的代理浏览器验收当前待完成。

CS:APP 全书解释补充见 [I018](issues/I018-csapp-explanations.md) / [T018](test/T018-csapp-explanations.md)。十四页正文与题解的审阅范围、具体补充位置和当前页面哈希保存在 `books/csapp/notes/explanation_review.json`。`tools/explanation_regressions.py` 由书级检查器调用，直接提取页面别名函数，在不同优化级别和 ASan/UBSan 下检验同址、异址及函数副作用，并拒绝错误合并与经 const 指针写入。继续使用既有标准库、C11 和页面组件。

CS:APP 图表与导航复核见 [I019](issues/I019-csapp-visual-navigation.md) / [T019](test/T019-csapp-visual-navigation.md)。`tools/reader_navigation_checks.py` 由书级检查器的快速及完整模式共同调用，按原书章节清单核对前后章、全书图及逐章推演入口，检查章节标签与目标、图注和 SVG 可访问名称，并以缺项、错链等内存变异验证检查能力。它不判断箭头含义或代替浏览器目视阅读；逐项内容与当前版本绑定另存 `notes/visual_navigation_review.json`。技术栈、运行方式和发布流程沿用原约定。

## 技术栈变更索引（只追加）

“技术栈变更”至少包括语言、运行时、框架、核心库、构建工具、数据库或中间件的新增、移除、替换、主版本升级，以及兼容基线变化。普通补丁升级仅在影响行为、兼容性或安全基线时记录。

| 日期 | 变更前 → 变更后 | 科学/工程理由 | 兼容、迁移与回滚影响 | 问题单 / ADR |
|---|---|---|---|---|
| 2026-10-12 | 分散笔记目录和外部 Weiss 构建来源 → 同仓库书籍子项目、统一标准库工具入口 | 一次克隆包含维护与验证所需源，保留原代码维护源 | 发布 URL 保持，原 Weiss 目录及迁移前快照保留；无新前端框架 | [I001](issues/I001-project-merge.md) / [ADR-001](docs/decisions/ADR-001-book-subprojects.md) |
| 2026-10-13 | 两书登记边界 → 增加 CS:APP 子项目和 /csapp/ 本地构建路由 | 复用静态 HTML、C11、Python 与既有 Poppler；显式区分机器模型和宿主执行 | 原两书 URL 与内容保持；新增目录和路由可独立回退；完整书籍 PDF 仅本地对照 | [I002](issues/I002-csapp-part-one.md) |

| 2026-10-17 | 直接维护单文件 HTML → Astro 7.4.0 静态构建、Node 24.21.0 LTS 与 pnpm 11.21.0 | 共享布局与确定性内联，原数学片段保持；Python 继续独立验证 | 五书分批门禁通过；保留旧 HTML、旧构建器与原 URL，生产仅 Nginx | [I028](issues/I028-static-first-astro.md) / [ADR-002](docs/decisions/ADR-002-static-first-astro.md) |
| 2026-10-17 | 构建后独立浏览验收 → 构建内必须通过真实浏览器 CSP 冒烟；发布用户持有版本 → root 安装器模板 | 防止脚本 hash 与验证对象漂移，明确版本写权限边界 | 构建需要 Ego Lite/ego-browser；正式 URL 与 Python 验证保持，服务器应用另交运维 | [I032](issues/I032-final-assessment-repairs.md) / [ADR-005](docs/decisions/ADR-005-root-release-installer.md) |

> 详细论证写入问题单或 ADR；本表保存可追踪索引，不得覆盖历史记录。

## 视觉群论伴读范围

Carter《Visual Group Theory》在 `books/visual-group-theory/` 维护，全书地图、序言与第 1—10 章十二页，覆盖原书 302 题与 62 条编号陈述。全书 302 题编号由原 PDF 独立枚举，各章按原节次维护推导和全部小问；`notes/source_manifest.json` 保存 312 页来源身份与分段页序。C11/Python 相邻交换、Dₙ BFS、无限饰带、运算表、置换、子群、半直积、同态、Sylow 与分裂域自同构十组示例的维护源在 `code/`，`tools/sync_code.py` 同步 HTML，书级检查器从根入口运行并使用独立顶点/四点置换、复矩阵、正则置换与反例基准。原 PDF 保留在本地忽略目录，仅笔记、程序和显式元数据进入统一包。新书路由、阅读资料及书架已接线；沿用既有工具链、静态页面与服务，无技术栈或环境变更。依据见 [I021](issues/I021-visual-group-theory.md) / [T021](test/T021-visual-group-theory.md)。

第 2—4 章扩写依据为 [I022](issues/I022-visual-group-theory-ch02-04.md) / [T022](test/T022-visual-group-theory-ch02-04.md)。保持现有技术栈、离线 HTML 组件和源 PDF 发布边界；官方 Group Explorer 仅作忽略目录中的实验依赖，不进入笔记运行时或发布包。

第 5—8 章扩写依据为 [I024](issues/I024-visual-group-theory-ch05-08.md) / [T024](test/T024-visual-group-theory-ch05-08.md)。独立有限核验新增四点置换、标记网格的忠实作用、全部函数穷举与原图邻接关系，源码在 `tools/check_structures.py`；图、源码和发布阅读副本分别验收。

## 测度与概率伴读范围

程士宏《测度论与概率论基础》当前八页为伴读总览、序言与前言和六章，覆盖 203 个编号陈述、33 个编号例子及 170 道习题。第五、六章新增 89 项编号内容、55 题与一组 C11/Python 核积分/二项卷积程序，总计四组维护源。原页 PDF 141—228 与附录 242—251 经目视，写前清单与当前读回分开。有限模型新增精确原子分布、层集期望、二项系数、路径穷举和单步特征函数乘积的独立基准，含普通与 ASan/UBSan 构建。内容与公式修正见 [I034](issues/I034-measure-probability-ch05-06.md) / [T034](test/T034-measure-probability-ch05-06.md)。来源仍为 256 页扫描，印刷页偏移 +12；本地原 PDF 不公开。受控 HTML、静态 MathML/SVG、Astro 构建与服务环境沿用现有约定。

第 9—10 章扩写依据为 [I025](issues/I025-visual-group-theory-ch09-10.md) / [T025](test/T025-visual-group-theory-ch09-10.md)。独立检查加入全部小阶对称群子群、六维有理矩阵、Sturm 根数、A₅ 共轭类与有限域；工具为 `tools/check_sylow_galois.py`，未新增运行依赖或环境变量。

视觉群论一致性修订 [I026](issues/I026-visual-group-theory-polish.md) / [T026](test/T026-visual-group-theory-polish.md) 为第 2—4 章补充阅读注解，并将关键行内公式改为静态 MathML；`tools/check_reading.py` 核对关键公式结构、节选范围与审阅元数据。全部行内与显示公式提供一致的静态名称和纯文本回退；复制控制器处理完整的两类公式，局部选区沿用浏览器行为。沿用现有 HTML/SVG/MathML 与浏览器组件，无技术栈、环境或服务变更。

## Astro 迁移状态

I039 提供隔离的内容组件样章命令 `python3 tools/project.py preview-components`，从 Git 基线 `41a77dd` 生成第一章副本、五书片段对照及完整性报告，仅写入 `tmp/reading-components-preview/`。该命令重现[历史提案](docs/reading-components-proposal.md)；正式实现与后续验收由 I040 承接，发布流程和技术栈保持原约定。

I032 修复后的仓库构建仍是 Node/Astro + Python helpers，全部公开 HTML 内联资源，正式页增加全 DOM/锚点 parity，页数从受控条目派生，兼容镜像由构建生成并暂时保留 Git 快照。Ego Lite/ego-browser 为构建中的真实 CSP 冒烟及完整离线验收依赖。新发布模板由 root 安装器持有版本树，fsync 屏障、原子 journal、损坏日志受控恢复、容量预检与保留策略见 [ADR-005](docs/decisions/ADR-005-root-release-installer.md)。I029–I031 保留历史实机记录；I033 已应用 root 安装器和权限/SSH/FTP/UFW/fail2ban 配置，实际结果及证书续期待办见 [I033 报告](docs/browser-stability-report.md)。

I033 加固浏览器驱动：深链读写绑定预期页面并等待节点，CSP/离线使用同一会话锁，失效缓存只在明确 not-found 时重建。`READING_NOTES_CSP_SPACE` 可显式选择现有空间；每次运行独立保存报告、日志、截图，成功入口原子更新，最新尝试另行记录。技术栈及正式内容未改变，恢复方法见 [Astro 编写说明](docs/astro-authoring.md)。

构建架构选择见 [ADR-002](docs/decisions/ADR-002-static-first-astro.md)，当前实施与证据见 [I028](issues/I028-static-first-astro.md) / [T028](test/T028-static-first-astro.md)。固定版本由 package.json、pnpm-lock.yaml 和 .node-version 约束。五书 54 页及书架已迁移，保留 1434 道原书习题与 36 道自测；原数学与历史审阅保持。根 build 现在调用 deploy/build_astro.py → Node/Astro → Python 发布策略与确定性打包。dist 仅包含 allowlist 中的 303 个公开文件；旧审阅 JSON 的 37 个 URL 输出固定摘要，完整证据留在仓库。新增 CS:APP 定位岛独立登记，其余原脚本保持。

新的 Ubuntu 模板采用 /srv/reading-notes/releases/<id>/site 与 current 原子切换，带 flock、SHA256、rsync、失败恢复、systemd 构建/发布单元和日志轮转。2026-10-17 的 I029 已在 Ubuntu 22.04 / Nginx 1.18.0 上部署 release 20261017T174039。root 维护的 Nginx 配置与发布用户权限分离，CSP 更新需管理员审查；reading-notes-deploy.service 为非 root oneshot，timer 保持停用，构建在本地完成。旧布局 release 20261017T151424 与站点配置保留为首次迁移恢复单元。详见 deploy/UBUNTU.md 和 docs/astro-production-report.md。

I032 新书接入验收使用 `tools/test_new_book_build.py` 运行完整隔离构建。发布文件由 allowlist 控制，新增书的入口、资料视图和 Nginx 前缀由目录登记派生；旧五书 Transformer 保留冻结字节，测度书范围标签由独立适配层处理。新增书/页可登记独立 Git 原始快照，后续修订仍走显式审阅链。

I033 于 2026-10-17 实机部署 `20261017T210828`，通过真实 systemd unit、旧版回滚及新版恢复、两版本 HTTPS 响应哈希和 root 只读权限验证。现有证书仍有效，自动续期未完成；Web 主机 tmpfiles 与可选构建主机模板已拆分。当前事实以 [I033 报告](docs/browser-stability-report.md)为准，I029/I032 保留各自验收时的边界。

I034 增页后当前书籍阅读页为 56 页、原书习题 1489 题；包括辅助页与旧入口共 76 个公开 HTML，allowlist 新增两章与两个源文件。新增页按 `page_baselines` 登记经过读回的本地 Git 内容快照，既有页继续保留 I028 原始 hash 并追加修订链；构建和真实阅读记录与生产发布记录分别维护。

I035 为受控静态发布加入确定性 gzip-6 sidecar；派生文件仅限 allowlist 中登记的文本，解压内容与原文件严格一致并进入归档 SHA 清单。Nginx 使用 gzip_static，保留 no-cache 和精确条件请求；发布器将内容到 mtime 的持久登记与 release 解包时间分离，同一内容复用 ETag，改变内容的同大小文件也使用不同验证器。历史清单只从 root 安装的摘要命名文件读取，以保持旧版可回滚。发布事务在 test/reload 后验证回环 HTTPS 的首页、五书入口及代表章节内容，失败恢复旧站并复核。新增健康检查 unit 模板与静态 HTML/gzip/DOM/JS 预算，CS:APP 横滚检测批量测量。实现和实际启用状态分别见 [I035](issues/I035-cache-performance-reliability.md) / [T035](test/T035-cache-performance-reliability.md)；运行时与数学内容不变。

I035 于 2026-10-20 从干净提交 e2ce917 构建并发布 `20261020T112509`：76 个 HTML、56 个正式页、495 个文件（含 188 个受控 gzip sidecar）。systemd 发布与源站内容检查成功，health timer 已启用。276 个与前版内容相同的文件保留 mtime；两个 PDF 和随机过程章正文以旧 ETag 实测返回 304。CS:APP 内容变化按新 ETag 提供，原基线及前版恢复单元保留。

I036 在发布适配层统一补齐书籍页和旧入口的 favicon，构建在所有公开 HTML 中验证唯一的内联站点 SVG。图标继续由 `portal/favicon.svg` 维护，支持网页跳转及独立 HTML 离线打开；正文源与完整 DOM parity、安全策略和生产运行时保持原约定。验证与发布证据见 [T036](test/T036-book-favicon.md)。

I036 于 2026-10-20 从干净提交 4471c54 发布 `20261020T120833`。继续使用现有 systemd/root 发布器与 Nginx 配置，旧版 20261020T112509 保留；378 个内容未变的文件延续原缓存验证器。发布后内容健康检查及五书公网浏览器图标检查通过。

I037 于 2026-10-20 从干净提交 `163478b` 发布 `20261020T142535`，当前版本含 56 个正式阅读页、76 个 HTML 和 495 个文件。公开文件与 `20261020T120833` 逐字相同，495 文件的 mtime 均保留；此次将最新提交绑定到正式发布记录，并重点验收测度概率第五、六章。systemd 发布、源站内容健康检查及新旧版本树校验通过，前版保留为恢复单元；验收范围与失败记录见 [T037](test/T037-measure-probability-production.md)。

I040 将 I039 样章组件落实到五书全部正式页，使用 `src/styles/reading-components.css` 统一陈述、例题、证明、习题的展示与展开约定；语义边界保存在受控 HTML，构建仍逐字展开镜像与内联。共同规范为 RN-001 v1.1，覆盖检查接入根 check 与 Node 测试；内容修改单独登记审阅链，保留原始迁移哈希。当前实施、验证与发布状态见 [I040](issues/I040-unified-reading-components.md) / [T040](test/T040-unified-reading-components.md)。

I041 将五书共同组件约定更新为 RN-001 v1.2：版心不依赖注解增强开关，陈述正文、题干/答案标签、代码折叠和题号导航使用明确的共同结构。书级 CSS 通过受控递归 include 组合共享连续段，Node 构建与 Python 检查独立展开并拒绝循环及路径越界，成品仍为完整内联静态 HTML。原 MathML、SVG、代码及题干文本保持字节一致；当前修订与原审阅分别绑定。评估取舍见 [复核说明](docs/review-followup-20261020.md)，实测与发布结果见 [T041](test/T041-review-followup.md)；技术栈、服务和端口不变。

I041 已从干净提交 `0a84a11` 发布 `20261020T212352`，完成服务器和正常域名验收，前版 `20261020T200604` 保留。当前包仍为 495 文件、76 HTML、56 正式阅读页；服务配置、端口、白名单和脚本 CSP 不变，证据见 [T041](test/T041-review-followup.md)。

I043 将组件语义约定更新为 RN-001 v1.3，补全按习题独立检查的标题父级、明确引用和表格名称、例子分类口径，并继续抽取相同样式。内容提交 `0ccf855` 已发布为 `20261020T225222`，恢复单元为 `20261020T212352`；本版仍为 495 文件、76 HTML、56 正式阅读页，技术栈、服务和端口不变。复核取舍及验收分别见 [复核说明](docs/recheck-followup-20261020.md) / [T043](test/T043-five-book-recheck.md)。

## EOPL 本地准备批（I042）

`books/eopl/` 保存第三版 EOPL 的来源清单、维护说明、Python 闭包实验和书内检查器；正文位于 `src/content/books/eopl/`，通过既有受控 HTML 展开器生成两份独立 HTML。当前范围为地图、Foreword、Preface 和习题 0.1；本批尚未加入正式 catalog、发布 allowlist、历史 Git 基线或根入口书级分派，依照新书接入的准备阶段使用 `python3 books/eopl/tools/check_notes.py`。根 README 提供本地阅读入口。

现有 Python/Node 与共享静态组件足够完成本批，没有引入 Scheme 运行时或新的技术栈。正式发布登记待代表章接入时完成；本批不以五书公共构建证明 EOPL 已发布。维护依据见 [I042](issues/I042-eopl-map-preface.md)，验证与治理生成器兼容性记录见 [T042](test/T042-eopl-map-preface.md)。

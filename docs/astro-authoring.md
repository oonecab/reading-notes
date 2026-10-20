# Astro 内容与独立检查

受控正文位于 `src/content/books/<book>/`，一章一份 HTML，文件头为 JSON frontmatter。共享 CSS/JS 在 `src/styles/`、`src/scripts/`，由 `RN:include` 标记按原字节展开。`ReaderLayout` 提供 head/body 骨架，组件保留语义片段边界，静态 MathML/SVG 不经重排。目录、注解与复制是独立的渐进增强脚本；基础阅读和原生 details 使用静态 HTML。

`books/<book>/notes/*.html` 是受控源展开后的兼容镜像，供原 Python 检查器独立读取。构建在验证受控源身份后自动生成镜像；`node scripts/sync-legacy.mjs` 单独检查一致性，`--write` 单独生成。兼容快照暂时随 Git 保留以支持独立检查与回滚，正文的唯一权威源是 `src/content/books/`。C/Python 程序仍遵循各书原代码维护入口，先把显示块同步进受控章节，再展开镜像并运行原检查。Weiss 的教学程序维护于受控章节内。

迁移期间 `scripts/migration-state.json` 固定起点，`original_sha256` 和 `git show` 双重守卫禁止正文变化。未来数学内容修订须另开受审阅的变更，连同原题/条件/代码、来源清单、Python 基线、当前审阅绑定与新 golden master 一起更新；不能以同步镜像命令自动认可内容变化。共享资源文件的哈希名称只为去重，不构成内容正确性的证明。

I032 开始，迁移后的明确内容修订在 `src/content-revisions.json` 逐页登记原始 hash、连续修订链、具体锚点、理由及独立内容审阅记录。原始 frontmatter hash、I028 Git 快照和旧审阅数据保持；当前内容必须同时匹配登记值和审阅记录，并保持原习题 ID 与原锚点顺序。构建 parity 比较当前已审阅源经同一发布转换后的全部 DOM，历史零差异迁移与后续内容修订分开陈述。登记脚本不能自动批准正文；每项实质修改先读回再填写原因和证据。

工具链为 **Node/Astro + Python build helpers**：Node 24.21.0、pnpm 11.21.0、Python 3.10+；Python 的 build_portal、prepare-pages、public_policy 参与构建，原独立验证器另行运行。准备本地来源资料，并安装 C/Make/Poppler（完整验证）、Nginx/OpenSSL（发布演练）和可运行的 Ego Lite / ego-browser CLI（浏览器验收），然后执行 `pnpm install --frozen-lockfile`、`pnpm build`。生产 HTTP 仍只由 Nginx 提供。

`pnpm build` 在临时目录准备来源并构建，对全部公开 HTML（当前 76 页，含辅助页和 5 个旧入口页）内联 CSS、favicon 和脚本；下载文件保留链接。正式页完整 DOM 的标签、命名空间、属性和子节点顺序、习题 ID 序列，以及正文/MathML/SVG/代码指纹和内部锚点一起核对。页面数量来自受控条目清单，新增书籍按 catalog、migration-state 与发布 allowlist 登记，不修改固定页数。

构建还启动环回临时 HTTP 服务，以生产 CSP 模板在真实浏览器覆盖每种内联脚本，确认哈希变异被浏览器阻止；打包再校验这些页面和脚本的指纹。所有门禁通过后才替换 `dist/`，保留上一份输出。`node scripts/verify-parity.mjs --book <book>` 比较冻结源和旧发布视图；`node scripts/check-offline.mjs --book <book>` 用 Ego Lite 实际断网打开该书全部公开页面，验证 1800/1440/1024/390 四档、1440/390 两档无 JS、深链、目录和局部横滚；旧入口验证其本地跳转目标。完整命令从仓库根执行，构建与浏览证据写入忽略目录 `tmp/reading-notes-migration/`。

逐书 `review/astro-migration.json`、`content-baseline-astro.json` 和 `release-astro.json` 是新增的迁移证据。旧数学审阅、来源材料、内容完整性基线和程序记录保留原有含义。仅因维护说明改动而更新的当前文档哈希，必须同时保存旧值及原因。

### 浏览器会话与复跑证据

CSP 和离线验收默认复用 `tmp/final-assessment/browser-session.json` 中的 Ego 空间。缓存空间已被关闭、明确返回 `task space not found: <ID>` 时，自动建立一个名为“Reading Notes 浏览器验收”的空间并原子更新缓存；用户控制、inactive、权限、超时及其他错误均停止并保留原错误。也可执行 `READING_NOTES_CSP_SPACE=<现有空间ID> pnpm build` 或同样设置运行 `pnpm check:offline`；值必须是正整数，显式指定的失效空间不会自动替换。CSP 检查始终是构建门禁。

两个命令共用会话旁的 `.lock`，已有验收运行时直接拒绝第二次启动。正常结束释放锁；命令被外部强制终止后先检查锁中的 PID、对应运行目录的日志及 Ego 当前页，确认驱动已停止，再移除该精确锁文件并重跑。不要对完整矩阵设置 300 秒总超时；它按每个页面/交互限制等待，完整 444 个视图需要数分钟。进程被强制杀死可能留下 `running` 尝试，不能当作通过。

离线证据在 `tmp/reading-notes-migration/browser/<all或书名>/runs/<UTC时间-随机ID>/`，CSP 证据在 `tmp/reading-notes-migration/csp/runs/<ID>/`。每轮独立保存 `report.json`、`driver.log` 和截图，报告使用临时文件、fsync 和原子替换。父目录的 `report.json` 只在完整成功且驱动正常退出后更新，`latest-attempt.json` 标明最近一次尝试及其状态；检查最近结果必须同时查看两者。失败保留其完整目录，不覆盖上一次成功截图。历史旧格式报告仍按原路径保留，I032 已归档证据不回写。

深链在执行与最终读取前等待目标存在，并在单次 DOM 读取中验证 URL、取得节点和读取状态；节点瞬时消失最多尝试三次，缺失或导航至别页明确失败。只有有习题的正式页检查首末习题深链；旧入口核对重定向与内容，辅助页保留渲染、目录和滚动检查。

### 新书与新页的构建空跑

新书在 `books/catalog.json` 登记目录、页数、入口和支持 `--quick` 的独立 Python checker，在 `scripts/migration-state.json` 加入 `migrated_books`；公开文件逐个加入 `deploy/publish-allowlist.json`。保留 `notes/book_overview.html` 入口约定。新书的源码先建立经过审阅的 Git 快照，在 `book_baselines` 为该书登记基准 commit；已有书增页使用 `page_baselines` 为新 route 单独登记，原页的历史来源哈希继续保留。原有五书的 I028 Transformer 和 CSS 快照不改变。

构建会从受控 HTML 生成缺失的兼容镜像，新增书的公开文件、静态资料视图和书架入口由目录登记与 allowlist 派生；Nginx 的书籍入口正则从已审核发布清单生成，不再枚举固定五书。`deploy/publication.py` 在冻结的旧 Transformer 外衔接目录扩展，并把测度书的地图导航标成伴读总览。I034 将该书程序入口的标题改从维护 README 取得，并更新引言；各组程序说明置于末尾维护用“校验”节之前。发布视图回归逐一核对登记程序的下载入口，避免后续章节被维护分隔截掉。

`python3 tools/test_new_book_build.py` 会在忽略目录复制当前源码到独立 Git 副本，加入两页 dummy 书及其原始快照，删去兼容镜像后运行真正的 `pnpm build --release-id ...`、全部 parity、CSP 浏览器冒烟、Python checker 和发布清单检查。测试只修改隔离副本；报告写入 `tmp/new-book-build/run-*/report.json`。它需要完整构建工具链及已启动的 Ego Lite，不加入每次 quick 检查。

### 缓存与性能门禁（I035）

公开文本在内联、摘要脱敏后生成 gzip-6 sidecar，header mtime 固定为 0。HTML 与压缩文件一同进入 release 清单。新 sidecar 不允许承载额外来源：发布器逐项有界解压并核对原文件，私有路径、遗漏、伪造压缩内容均拒绝。构建不压缩 PDF、zip 或已压缩下载。

`scripts/performance-budgets.json` 是经 I035 基线审查的上限；构建及 `pnpm check:performance` 检查每个公开 HTML 的原始/压缩体积、元素数和内联脚本量。首页和两个代表大章有单独预算，新增页面也受默认上限约束。预算不会随构建自动上涨。运行 `READING_NOTES_CSP_SPACE=<现有空间ID> node scripts/check-browser-performance.mjs https://notes.zzzping.top` 可取得 3 个代表页面、2 个视口/CPU 档、各 3 轮初访/复访的 36 次样本。它复用浏览器锁及独立运行目录，探针缺失或页面横溢出即失败，不清理用户全局缓存。静态预算不等于设备延迟；真实浏览器另记视口、CPU 倍率、初访/复访、长任务、布局和样本数。

CS:APP 共享横滚脚本的此次修订通过正常 source revision 链登记，当前绑定在 `books/csapp/review/reader-performance.json`；数学正文、原习题和历史基线保留。

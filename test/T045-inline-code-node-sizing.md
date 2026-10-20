# T045 行内程序与图中节点比例

状态：已完成并部署，线上验收通过；关联 I045、P045 与 M045。内容基线为 `09759945a0ad27e73f42c291e6b121a76fa6ce7a`，范围为六本书现有 58 个阅读页。EOPL 仍为全书地图、序言、习题 0.1 与闭包实验。

## 表达与图形

共享行内 `code` 使用 Times New Roman、浅灰蓝背景、细边框与少量留白。短表达式保持整体，长表达式在正文宽度内换行；完整 `pre` 不接受行内装饰。补齐 4,595 处程序标记，重点为 CS:APP、Weiss 与 EOPL 的函数、关键字、字段和调用。合并 165 处被拆开的程序表达式，其中 157 个 MathML 片段回归真实程序语法；例如 `waitpid(-1,&s,WNOHANG)`、`movq (%rdi),%rax` 与 `if(!initialized){init(); initialized=1;}` 均保持在同一个 code 中。

枚举全部 490 个 SVG，按标签及角色调整其中 50 图的 241 个节点。流程卡片按文字宽度与行数留白，元组圆节点扩大到容纳完整标签；数组格、字段宽度、坐标和生成元颜色保留。350 个原本连接到节点的端点读回同一节点，手工修正两条 load 转发箭头以及乱序执行图的折线落点。目视查看 13 张联系页中的全部 50 图，并回到六书正文代表页检查。7 处群论图中的 `N_G(H)`、`G_(N−1)`、`p^(N−1)` 采用定位 tspan，保留可核对的原始 notation。

以基线逐页比较：1,149 个完整程序块字节完全一致；全部锚点和链接有序一致；正文可读语义保留。除逐项记录的程序误分类片段外，50,829 个 MathML 保持原树。SVG 数学脚本同时验证原值与上/下标位置，不能用标注掩盖不同的显示值。检查工具具有漏标、混入数学片段、节点四边留白不足、错误脚本值和错位的负例。

## 验证与证据

完整根检查 22 项通过，最终程序文件名排版补修后，CS:APP 与公共检查再通过；Node 43 项通过。最终构建含 58 阅读页、80 HTML、511 文件，58 页 DOM parity 无差异，既定体积预算与实际浏览器 CSP 检查通过。58 页展开所有 details 后，1440/390px 共 116 个视图的行内样式、完整代码块样式和页面宽度均通过；241 个节点留白和 350 个连接端点通过。最终全站离线矩阵覆盖 320 个四档宽度视图和 160 个 no-JS 视图，外部请求为 0。

根报告：`tmp/project-check/20261021T022045-vqcnbojn/report.json`；补充检查：`tmp/project-check/20261021T023416-xsg_87ll/report.json`；最终离线：`tmp/reading-notes-migration/browser/all/runs/2026-10-20T18-35-08-839Z-0b1c585c/report.json`。独立构建与几何证据均在当前排版审阅文件中按 SHA-256 绑定。浏览器范围为 Chromium，不代替物理手机、Safari、Firefox 或屏幕阅读器验收。排版检查不作为全部数学证明再次核查的证据，也不重做历史 CS:APP 代理浏览器实验。

中途检查暴露两类绑定顺序问题：随机过程派生覆盖文件刷新后依赖摘要未同步，以及最终 SVG 标签更新期间镜像尚未同步。失败保存在 `tmp/project-check/20261021T020053-6ukt7oat/` 和 `tmp/project-check/20261021T021205-4t019y_1/`；完成同步后重新执行正式验收。截图辅助脚本曾将 Push 写成小写，并把页头导航图标计入图序号；已改为真实目标及 main 内 SVG，产品内容未为探针选择器修改。工作证据位于 `tmp/inline-code-20261021/`，当前源码和成品摘要绑定见 `docs/reading-presentation-review.json`。

## 发布

正式包从干净内容提交 `bc442bb42e679bc8ad448d7dd3cf4b426d506465` 构建，注释标签 `v2026.10.21-inline-code-layout` 指向该提交；内容已合入 `main`，主分支与标签原子推送后读取远端引用确认。发布号 `20261021T024246`，归档 SHA-256 为 `c8fcbaf3c0a55e5bb29de649ed0a2ea560f8aeda4b4c271a88827582d867857a`。后续验收记录提交只补充发布事实，标签与部署来源保持上述内容提交。

部署前核对 511 个包内文件与已验收成品完全一致，80 个 HTML 与最终离线矩阵的页面摘要一致，58 页当前审阅绑定通过。临时 HTTPS 验证覆盖 505 个直接文件、18 项跳转、194 个 gzip 表示及 2 项 PDF Range；发布器隔离集成检查 24 项通过。两处临时 Nginx 均已停止。源码改动与整个发布目录分别经 Gitleaks 扫描，结果均为 0 条发现。证据为 `tmp/inline-code-20261021/package-preflight.json`、`predeploy-acceptance.json`，以及 `tmp/release-check/20261021T024246-4e5eqhjm/https-verification.json`、`tmp/publish-check/20261021T024246-m92j7h3x/report.json`。

服务器 `current` 已指向 `releases/20261021T024246`。新版本和恢复单元 `20261021T012051` 各 511 个文件的内容摘要、root 所有权与只读权限均通过；395 个内容未变文件保留 mtime，116 个变更文件的 mtime 与旧版区分。Nginx 配置检查通过、服务 active；发布与健康检查 Result=success、ExecMainStatus=0，健康 timer active。没有待完成事务，队列为空，完成回执存在。管理员 Nginx 片段及发布策略的 SHA-256 分别保持 `8c8a40dd1dcc0a16541a2d47bb38037787e57ad0859bc27ad8ffe5c7f3704dd2`、`eac0d803f29f69a5399ee2f33fb9a5fb6254ed6e70eaec6662ae631f56dcef69`。旧版已核验并保留，本次未执行生产回滚。

正常域名 `https://notes.zzzping.top` 经常规 DNS 解析验证，未指定源站 IP：505 个直接文件内容、MIME、CSP 与缓存校验通过，18 项跳转、194 个 gzip 表示、2 项 PDF Range、条件请求和异常路由检查通过。实际浏览器覆盖六书代表页的 1440/390px 共 12 个视图，正文宽度、行内代码样式与数学显示正常；18 个实际字体探针均命中 Times New Roman。另验收 EOPL 390px 无脚本页面和首页到 EOPL 的真实点击路径。线上 EOPL 桌面/窄屏及 CS:APP 窄屏三张截图均已目视检查。证据 `server-after.json`、`public-verification.json`、`public-browser.json` 及截图位于 `tmp/inline-code-20261021/`，摘要同时绑定到当前排版审阅记录。

RN-001、TECH、环境当前版本、问题单、计划及里程碑已同步。本次没有改变技术栈、环境变量、服务配置、端口或计算规则，`.project-governance.json` 与 `.env.example` 无需修改。

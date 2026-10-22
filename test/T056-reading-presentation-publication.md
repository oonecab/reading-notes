# T056：阅读呈现发布验证

- 状态：`completed`
- 关联：[I056](../issues/I056-reading-presentation-publication.md)、[P056](../plan/P056-reading-presentation-publication.md)

验证分层：全站静态与程序回归、源/镜像和审阅绑定、Node 反例、秘密扫描、干净提交/远端身份、本地不可变包、真实 HTTPS/发布恢复、服务器状态、公网 HTTP 与实际阅读。程序和几何检查不能代替内容重新证明。

新增回归：允许登记的索引锚点后移；仍拒绝其他历史锚点换序、锚点删除与不存在的移动声明。先在原实现上证明失败，再执行修复。

发布前运行 `python3 tools/project.py check`、`pnpm test`、`pnpm check:parity`、`pnpm check:offline`、`python3 tools/project.py build`、`verify-release` 与 `tools/test_static_publish.py`；公网使用 `deploy/verify_portal.py`。浏览器复核 EOPL 四页、序言到第一章、中文题干、单题节与代码控件，以及随机过程/CS:APP 后置索引；桌面与 390px，相关无脚本视图另计。

保全依据：全站旧版内容与本批变化分别比较，I055 的 68 题保全证据可在源字节相同条件下复用。提交前检查全部候选文件，发布前后逐项读取清单及哈希；失败证据与结果待执行后追加。

首轮 `pnpm check:offline` 保留在 `tmp/reading-notes-migration/browser/all/runs/2026-10-22T17-13-21-037Z-c3b52f5e/`：完成 168 个有脚本视图，附录 390px 的 `#statement-index` 定位/目录高亮失败。复现与截图见 `tmp/reading-publish-20261023/index-position-*.png`；不是教材内容问题。整段复用脚本及较长的局部补丁先后触发随机过程和视觉群论的原体积上限，保留失败日志并收敛修改，未调整预算。

最终修改在原目录控制器展开后延后定位，净增 6 字节。`navigation-before.log` 在旧脚本隔离副本上拒绝桌面/手机案例；`navigation-after.log` 及新增 Node 测试验证展开后的位置、当前目录项以及空/缺失目标。`navigation-position-browser.json` 实际复验随机过程第 1 章和附录的 390/1440px 四个目录点击，均展开、选中索引且标题露出固定栏。46 页的源正文、题干、公式、图、程序、样式和链接保持；发布输出逐字还原比对见 `navigation-output-preservation.json`。新的当前源/输出绑定见 `docs/navigation-position-review.json`，旧记录按 Git 来源与原值保留。

后续矩阵从同一浏览器空间续跑；旧报告不改写，仅按页面及截图散列、完整必需字段复用未变视图，受共享脚本影响的页面重新执行。最终 107 项 Node 测试通过，源/镜像、审阅绑定、静态结构与完整 DOM parity 已复核。完整教材程序仍复用此前 25 项全站检查，源码及输入未变；新增软件行为由上述回归和浏览器验证承担。

最终验收于 2026-10-23 完成。源内容为 `0b987c309f1a3bc172ea15658c28873a423953d7`，工作树干净时构建版本 `20261023T020252`。以下路径均相对仓库根目录；长期摘要和证据散列保存在 [发布审阅](../docs/reading-presentation-publication-review.json)。

- 全站完整检查：`tmp/project-check/20261023T010747-9s_on10n/report.json`，25 项全部退出 0，包含实际 C/Python/Racket 程序。执行于最后目录脚本修正前；教材程序和输入字节保持，最终新增交互由 107 项 Node 测试及浏览器验证承担。
- 60 页原题/数学/SVG/代码保全：`tmp/reading-publish-20261023/content-delta-review.json`；69 个完整英文块归档后，受保护内容变化为 0。最终源/镜像、审阅链、静态结构与 60 页完整 parity 再核对通过。
- 离线最终报告：`tmp/reading-notes-migration/browser/all/runs/2026-10-22T18-07-06-485Z-addd37c5/report.json`，82 页、328 个有脚本视图（1800/1440/1024/390px）、164 个无脚本视图（1440/390px），外部请求 0。100 个未变视图按 HTML/截图散列与完整字段复用，其他视图实跑；旧失败报告保持。
- 本地真实 Nginx HTTPS：`tmp/release-check/20261023T020252-_y007j65/https-verification.json`；发布/故障恢复和缓存集成：`tmp/publish-check/20261023T020252-ny0tnm8c/report.json`，24 项通过。源码与提取后的公开包秘密扫描无发现，CSP 冒烟和既有体积预算通过。
- 服务器：`tmp/reading-publish-20261023/server-after.json`，新版本 524 文件、前版 523 文件逐项校验且 root 只读；399 个未变文件保留 mtime，124 个改变文件具有不同 mtime，新增 1 文件；政策归档及最终 Nginx 散列一致，发布/健康服务 Result=success，健康 timer active，队列为空，无待恢复事务。
- 正常域名：`tmp/reading-publish-20261023/public-verification.json`，518 文件、518 条件请求、196 预压缩资源、18 入口重定向和 6 份 PDF Range 通过，传输重试 0。
- 公网实际浏览器：`tmp/reading-publish-20261023/public-browser.json`、`public-nojs.json` 和 `public-pdf.json`。1440/390px 实际从地图到序言，再经页脚到第一章、第二章；检查 68 题范围、1.14 单题入口、1.26 中文题面、代码鼠标/键盘开合；随机过程第一章与 CS:APP 第七章直接进入正文，索引位于章末。390px 关闭脚本后原生展开题干及完整源码。实际点击 PDF 后，后续阅读器显示 51/433、印刷页 28 与习题 1.26；首个仅 iframe 的观察保留，不能单凭 URL 记为已读。
- 13 张公网截图已逐张打开阅读，文件散列与观察分别在上述三个报告中。浏览器空间 5 已在全部操作后一次性完成关闭。

维护文档收尾另运行已登记的 quick 检查及 source/dist 呈现契约，日志在 `tmp/reading-publish-20261023/maintenance-checks.log`；独立当前绑定复核见 `maintenance-astro-records.json`。最终 Git 实时远端与干净工作树证明保存在 `git-final-publication.json`。本次只更新发布证据和当前维护事实，不重建或替换已验收的生产内容包。

边界：自动矩阵不等同重新推导全部数学证明；本次实际打开阅读的是列出的 13 张公网截图及前述局部截图，不宣称逐张人工阅读全部矩阵。实际浏览器为 macOS Ego Lite Chromium，390px 是窄屏模拟，未测试真机 iOS/Android 或其他浏览器引擎。维护检查、程序运行和生产证据分别有效，不相互替代。

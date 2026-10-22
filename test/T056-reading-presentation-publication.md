# T056：阅读呈现发布验证

- 状态：`in_progress`
- 关联：[I056](../issues/I056-reading-presentation-publication.md)、[P056](../plan/P056-reading-presentation-publication.md)

验证分层：全站静态与程序回归、源/镜像和审阅绑定、Node 反例、秘密扫描、干净提交/远端身份、本地不可变包、真实 HTTPS/发布恢复、服务器状态、公网 HTTP 与实际阅读。程序和几何检查不能代替内容重新证明。

新增回归：允许登记的索引锚点后移；仍拒绝其他历史锚点换序、锚点删除与不存在的移动声明。先在原实现上证明失败，再执行修复。

发布前运行 `python3 tools/project.py check`、`pnpm test`、`pnpm check:parity`、`pnpm check:offline`、`python3 tools/project.py build`、`verify-release` 与 `tools/test_static_publish.py`；公网使用 `deploy/verify_portal.py`。浏览器复核 EOPL 四页、序言到第一章、中文题干、单题节与代码控件，以及随机过程/CS:APP 后置索引；桌面与 390px，相关无脚本视图另计。

保全依据：全站旧版内容与本批变化分别比较，I055 的 68 题保全证据可在源字节相同条件下复用。提交前检查全部候选文件，发布前后逐项读取清单及哈希；失败证据与结果待执行后追加。

首轮 `pnpm check:offline` 保留在 `tmp/reading-notes-migration/browser/all/runs/2026-10-22T17-13-21-037Z-c3b52f5e/`：完成 168 个有脚本视图，附录 390px 的 `#statement-index` 定位/目录高亮失败。复现与截图见 `tmp/reading-publish-20261023/index-position-*.png`；不是教材内容问题。整段复用脚本及较长的局部补丁先后触发随机过程和视觉群论的原体积上限，保留失败日志并收敛修改，未调整预算。

最终修改在原目录控制器展开后延后定位，净增 6 字节。`navigation-before.log` 在旧脚本隔离副本上拒绝桌面/手机案例；`navigation-after.log` 及新增 Node 测试验证展开后的位置、当前目录项以及空/缺失目标。`navigation-position-browser.json` 实际复验随机过程第 1 章和附录的 390/1440px 四个目录点击，均展开、选中索引且标题露出固定栏。46 页的源正文、题干、公式、图、程序、样式和链接保持；发布输出逐字还原比对见 `navigation-output-preservation.json`。新的当前源/输出绑定见 `docs/navigation-position-review.json`，旧记录按 Git 来源与原值保留。

后续矩阵从同一浏览器空间续跑；旧报告不改写，仅按页面及截图散列、完整必需字段复用未变视图，受共享脚本影响的页面重新执行。最终 107 项 Node 测试通过，源/镜像、审阅绑定、静态结构与完整 DOM parity 已复核。完整教材程序仍复用此前 25 项全站检查，源码及输入未变；新增软件行为由上述回归和浏览器验证承担。

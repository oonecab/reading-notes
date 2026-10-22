# T056：阅读呈现发布验证

- 状态：`in_progress`
- 关联：[I056](../issues/I056-reading-presentation-publication.md)、[P056](../plan/P056-reading-presentation-publication.md)

验证分层：全站静态与程序回归、源/镜像和审阅绑定、Node 反例、秘密扫描、干净提交/远端身份、本地不可变包、真实 HTTPS/发布恢复、服务器状态、公网 HTTP 与实际阅读。程序和几何检查不能代替内容重新证明。

新增回归：允许登记的索引锚点后移；仍拒绝其他历史锚点换序、锚点删除与不存在的移动声明。先在原实现上证明失败，再执行修复。

发布前运行 `python3 tools/project.py check`、`pnpm test`、`pnpm check:parity`、`pnpm check:offline`、`python3 tools/project.py build`、`verify-release` 与 `tools/test_static_publish.py`；公网使用 `deploy/verify_portal.py`。浏览器复核 EOPL 四页、序言到第一章、中文题干、单题节与代码控件，以及随机过程/CS:APP 后置索引；桌面与 390px，相关无脚本视图另计。

保全依据：全站旧版内容与本批变化分别比较，I055 的 68 题保全证据可在源字节相同条件下复用。提交前检查全部候选文件，发布前后逐项读取清单及哈希；失败证据与结果待执行后追加。

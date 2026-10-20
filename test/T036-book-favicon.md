# T036 书籍标签图标验收

范围：五书总览、章节、辅助阅读页与旧入口。验收标准为 head 中唯一的 SVG favicon 声明，内联数据与 `portal/favicon.svg` 完全相同；网络和 file 协议打开均可解码，页面正文完整 DOM parity 保持。

先运行新入口回归，确认旧实现因缺失声明失败。内联回归覆盖相对路径、已声明图标、重复、错误内容、放在 body 中的声明与缺失图标。构建对全部公开 HTML 执行门禁。发布前后实际浏览五书的总览与章节，并验证正常 TLS/CSP 下图标可解码；下载单页后直接离线打开复测。

2026-10-20 本地结果：

- 旧版 `20261020T112509` 的 76 个 HTML 中，56 个正式页及 5 个旧入口共 61 页缺失图标；`tmp/i036/before-icons.json` 保存逐页清单。
- 新五书回归在旧实现上出现 10 个缺失声明失败，见 `tmp/i036/red-tests.log`。首次完整构建还拦住历史入口生成路径的遗漏，见 `tmp/i036/build-missing-legacy-entry.log`，接线修正后通过。
- `python3 tools/project.py doctor` 通过锁定版本检查；`pnpm test` 21/21，初始 `tools/test_reader_views.py` 10/10。
- 完整检查 `tmp/project-check/20261020T115849-x7f2136l/report.json` 的前 17 项全部通过，包含五书完整 C/Python 回归；最后一项旧审阅整页 hash 检查因新图标失败。保留该失败报告，并增加“精确 head 插入后必须恢复旧 hash”的展示兼容检查，不修改原记录。新增反例覆盖正文、脚本、标题、重复、位置与类型修改。
- 修正后 `tools/test_reader_views.py` 11/11，独立 `tools/check_astro_records.py` 通过全部 56 页和 20 个既有源修订绑定；`python3 tools/project.py check --quick` 全部通过，报告为 `tmp/project-check/20261020T120707-oh5pbk6f/report.json`。程序内容未再改变，已通过的五书完整执行结果沿用本轮前 17 项证据。
- 候选包 `20261020T130000` 构建成功：495 文件、76 HTML、56 正式页；全部图标检查和 76 页性能预算通过，完整 DOM parity 56 页零差异。CSP 浏览器门禁覆盖 9 页、12 个脚本 hash，变异脚本被阻止。
- `tmp/i036/output-diff.json` 确认相比上一线上版本仅 61 个 HTML 的 favicon 声明及 56 个对应 gzip 文件变化，其余 378 文件逐字一致；去除新增图标标记后，所有改变的 HTML 与旧版逐字一致。
- 真实本地 Nginx HTTPS 验证通过：490 文件、188 gzip 表示、15 旧入口及两份 PDF Range；报告为 `tmp/release-check/20261020T130000-7_knh3fa/https-verification.json`。
- Ego 浏览器在 CSP 预览中从首页点击五书总览，再点击第一章并刷新，共 16 个图标检查通过。各取一章复制到独立目录，在断网和禁用脚本条件下以 file 协议打开，5/5 图标声明及图像解码通过。见 `tmp/i036/browser-local.json`。

本次变更只涉及 head 图标；采用上述定向离线验收，未重跑 I035 的 456 个全文阅读视图或发布器故障注入。正文、样式、脚本的逐字比较、全 DOM parity 和完整程序检查与这些历史实读证据分别记录。

生产和最终 Git 身份待上线后补充。

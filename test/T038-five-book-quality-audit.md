# T038：五书检阅的验证设计与证据

- 状态：`completed_with_findings`
- 关联：[I038](../issues/I038-five-book-quality-audit.md)、[P038](../plan/P038-five-book-quality-audit.md)
- 规则依据：RN-001 第 2—6 节、各书维护规范
- 入口源码：`41a77dd`
- 本次工作目录：`tmp/five-book-audit-20261020/`

自动验证使用根 `tools/project.py` 的 doctor、完整 check --benchmarks、build，及登记的 Node 测试、parity、offline 和 performance。完整运行的退出码、原始日志和报告路径分别记录。

内容审阅检查条件、符号、具体推演、原题小问、来源定位、代码与文字约定。清单和字符串检查只用于选择审阅对象；来源核读使用实际 PDF 页面。

浏览器以同一个 Ego TaskSpace 检阅最终构建页。正式页比较 1800、1440、1024、390px；无 JS 验证 1440/390px；核心样式比较正文、标题、导航、注解、习题、代码、表格和公式。人工目视与自动几何数据分开记录，真实手机及屏幕阅读器不在本机模拟的证据范围内。

本次没有计算规则变更，金额、时区等业务边界不适用。程序现有正常、异常、数值及内存边界由登记的完整检查执行；新增疑点另做独立复现。

实际结果：

- 根完整检查（含 benchmarks）18/18 通过，报告 `tmp/project-check/20261020T152832-chr6u4e6/report.json`。
- Node 测试 21/21 通过，`tmp/five-book-node-tests-20261020.log`。
- 构建 release `20261020T152942` 成功；56 页 DOM parity 为 0 差异；76 个发布 HTML 性能预算通过。
- 全站浏览器矩阵 304 个 JS 视图、152 个 no-JS 视图通过，0 外部请求；报告 `tmp/reading-notes-migration/browser/all/runs/2026-10-20T07-31-45-146Z-c3cefdb8/report.json`。
- 56 正式页 × 4 档计算样式一致性检查完成；56 页在 390px 全部展开后没有整页横向溢出或宽内容泄漏；`tmp/five-book-audit-20261020/style-matrix.json`。
- 实际打开 20 张五书四档页头截图、24 张重点阅读位置截图；另打开 6 张原 PDF 渲染页。目视范围没有用自动生成的 502 张截图数量替代。
- 公网主页及每书一页共六个响应为 200，正文哈希与本地成品相同。只读抽样未覆盖全部生产路由和服务器配置。

F01 的原页与网页实际条件不一致已复现；F02 的过时序言已确认。A01 保持待验收，未将协议测试视为真实浏览器代理验收。C01 为解释深度建议。详细定位、原始证据路径和限制见[检阅报告](../docs/five-book-quality-audit-20261020.md)及[证据索引](../docs/five-book-quality-audit-20261020.json)。

交付记录检查：`python3 tools/check_structure.py` 通过（5 书、120 个 Python 源、830 个文档链接）；新增文档的相对链接、行尾空白及证据索引中的所有文件 SHA-256 均已核对，`git diff --check` 通过。最终工作区仅新增本轮六个审阅记录文件，教材源、程序、样式和构建配置没有改动。

同日补充组件检查：全量遍历五书受控页面，1,525 个习题/自测全部默认收起且题干先于解答；内部标题、例题容器、定理折叠方式和证明区块存在跨书及书内差异。结果保存于 `component-structure.json` 和 `exercise-component-forms.json`，与原有成品截图及 CSS 定义交叉核对；本次未重跑浏览器或程序测试，未修改教材、程序和样式。

# T078 · 习题结构验收

验证对象为 d163cac 上的 I078 本地工作区。对 46 题按原编号核对，并还原新增属性、角色类和答案标签后与修改前整页源码逐字节比较。1.27 的两个来源链接和跨页题的页段均已保留。完整题干和被引用输入的前后散列见 [审阅记录](../docs/exercise-contract-review.json)。

全站 72 页、1927 个习题组件。SICP 46 题符合契约。其他六书共 57 页登记于 I079，逐页偏差见 [审计](../docs/exercise-contract-audit.json)。首次根检查在本文件创建前报告 I078 文档链接失效，退出 1，原始日志保留于 tmp/i078/local.log。

## 执行结果

| 命令 | 最终退出码 |
| --- | --- |
| `node scripts/sync-legacy.mjs --write` | 0 |
| `node scripts/sync-legacy.mjs` | 0 |
| `node tools/check-presentation-contract.mjs` | 0 |
| `node tools/reading-components/check.mjs` | 0 |
| `node tools/reader-contract/check.mjs` | 0 |
| `node tools/reading-typography/check.mjs` | 0 |
| `node tools/reading-presentation/check.mjs` | 0 |
| `node --test scripts/*.test.mjs` | 0 |
| `git diff --check` | 0 |
| `python books/sicp/tools/check_notes.py` | 0 |
| `python tools/project.py check-local` | 0 |
| `python tools/project.py build` | 0 |
| `node scripts/verify-parity.mjs --book sicp` | 0 |
| `node scripts/check-offline.mjs --book sicp` | 0 |
| `node tmp/i078/browser.mjs` | 0 |


Node 测试通过 136 项。SICP 完整检查使用 Racket 8.10，8 项程序回归通过。根检查使用 MiKTeX 提供的 Poppler，最终报告为 tmp/project-check/20261118T160537-oe7f6h2x/report.json。构建后 SICP 三页内容对照无差异。

离线浏览器检查覆盖 5 页、20 个有脚本视图、10 个无脚本视图，外部请求为 0。另用 Playwright 在 1440、390 像素各检查启用与禁用 JavaScript 两种模式。四组均确认 46 题初始收起、索引有 46 个链接，能定位、展开及关闭 1.1 和 1.46，代码可收放，页面没有横向溢出。逐组数据见审阅记录的 chapter_browser。此轮验证覆盖结构与交互，没有重新人工审译 46 道题。其他书的 57 页迁移由 I079 跟踪。

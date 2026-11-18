# T080 · 原文视觉覆盖

检查第 1 章图 1.1–1.5、换零钱调用关系与源码冻结例外。执行结果见 docs/visual-coverage-review.json。

| 命令 | 最终退出码 |
| --- | ---: |
| `node scripts/sync-legacy.mjs --write` | 0 |
| `node scripts/sync-legacy.mjs` | 0 |
| `node tools/check-presentation-contract.mjs` | 0 |
| `node tools/reader-contract/check.mjs` | 0 |
| `node tools/reading-typography/check.mjs` | 0 |
| `node tools/reading-presentation/check.mjs` | 0 |
| `node --test scripts/*.test.mjs` | 0 |
| `git diff --check` | 0 |
| `python tools/project.py check-local` | 0 |
| `python books/sicp/tools/check_notes.py` | 0 |
| `python tools/project.py build` | 0 |
| `node scripts/verify-parity.mjs --book sicp` | 0 |
| `node scripts/check-offline.mjs --book sicp` | 0 |
| `node tmp/i080/browser.mjs` | 0 |
| `racket books/sicp/code/test-chapter02.rkt` | 0 |

初轮构建因修订记录缺失而拒绝。首次窄屏浏览器测得页面宽 651 px，定向检查和离线地图检查退出 1。给 SVG 增加局部滚动区后复跑，1440 与 390 有脚本、390 无脚本均确认树有 15 个调用节点、14 条边、两个标星的 fib 3；从两个正文入口定位到根部图和 55 节点表，整页无横向溢出。最初的根检查还拒绝了过期的书级说明散列，更新绑定后复跑通过。

137 个 Node 测试通过。SICP 现有三页零差异；离线浏览器覆盖 20 个有脚本视图、10 个无脚本视图，外部请求 0。根检查报告位于 tmp/project-check/20261118T170456-bdx1jwkq/report.json。第 2 章正式页面未验收。

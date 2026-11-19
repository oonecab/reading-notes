# T084 正文程序标记验收

本地构建 `20261119T222519`。初扫 73 页发现 71 个程序 token（包含嵌套式），旧版检查器当时报告 73 页命中 0，但遗漏了 quote 与代码表单元格，该次结果保留为漏检证据。修复覆盖 4 页。SICP 第 2 章按上下文复核了调用、定义及其示例输出，38 道题的答案标记发生变化，新增 61 个行内代码片段和 5 个块级定义。CSAPP 第 4、7 章分别增加 4 和 1 个行内片段，EOPL 第 6 章同一段的两处 print(e) 均已标记。

对照变更前 Git 镜像，比对了 4 页的 DOM 文本、全部 id 与 href 的有序序列、全部 MathML 和原有 pre/code 元素的原始 HTML 字节。已有程序片段仍按原顺序逐字出现。原始题号及题中给定输入保留；重新计算了受标记变动影响的题面或引用目标题摘要。第 2 章逐答案新旧摘要见该章审阅记录的 prose_markup_review。

| 命令 | 退出码 | 实测结果 |
|---|---:|---|
| `node scripts/sync-legacy.mjs --write` | 0 | 源页生成镜像 |
| `node scripts/sync-legacy.mjs` | 0 | 镜像一致 |
| `node tools/check-presentation-contract.mjs` | 0 | 呈现契约通过 |
| `node tools/reader-contract/check.mjs` | 0 | 阅读契约通过 |
| `node tools/reading-typography/check.mjs` | 0 | 73 页 |
| `node tools/reading-presentation/check.mjs` | 0 | 73 页 |
| `node tools/reading-prose/check.mjs` | 0 | 73 页，0 命中 |
| `node --test scripts/*.test.mjs` | 0 | 156 项通过，0 跳过 |
| `git diff --check` | 0 | 差异格式通过 |
| `python tools/project.py check-local` | 0 | 使用 Poppler；报告 tmp/project-check/20261119T222554-1_jhs5r5/report.json |
| `python books/sicp/tools/check_notes.py` | 0 | 完整模式，4 页、143 题；两章 Racket 回归分别为 8、21 组 |
| `python tools/project.py build` | 0 | 73 个阅读页；第 2 章 gzip 305709 字节，预算通过 |
| `node scripts/verify-parity.mjs --book sicp` | 0 | 4 页，0 差异 |
| `node scripts/check-offline.mjs --book sicp` | 0 | 24 个有脚本视图、12 个无脚本视图，0 个外部请求 |
| `node books/sicp/tools/check_chapter02_browser.mjs --dist` | 0 | Chrome 1800、1440、1024、390；额外覆盖 1440、390 无脚本 |

构建后另用离线 Chrome 在 1440 与 390 像素展开并定位 SICP 2.27 的 deep-reverse 定义、CSAPP 的 push/ret 与 jmp、EOPL 的 print(e)。8 次测量均有可见代码元素、等宽字体栈，页面横向溢出为 0。读回数据在 tmp/i084/spot.log。第 2 章 6 个视图还检查了 97 项题号索引、首末题、代码折叠、公式、图和导航。

检查器采用有语法特征的调用、指令和命令。孤立的英文名字、数学元组或字面数据需要结合上下文判断。回归覆盖正文失败、code 内通过、跳过指定容器、普通词组和例外邻接指令。

## I084 补充 · 引用与代码表

补齐 quote 后重新扫描 0 命中，范围为 73 个正式页。初次“0 命中”漏掉了 §2.3.1 的两层引用。对补修前的页面独立重放得到 3 个裸 quote 运算符：同一嵌套表达式内有 2 个，下一行有 1 个。旧检查器也未识别引用简写、取首过程名和符号名。

“引用的两层”表新增 5 个 code 元素，PDF 220、三行两列及文字顺序均已逐格读回。扩展规则还发现 SICP 第 1 章参数表中的 (square 21)，以及 EOPL 第 7、9 章类型和对象表达式表中的标识符与调用。对补修前后的 4 份源文件剥去行内 code 标签后逐字节比对一致。同步更新了修订链、当前源及构建输出摘要。

独立复核使用 Python 标准库 HTMLParser 从正式源文件读取文本节点，与 Node 检查器分别实现。覆盖任务列出的 21 个扩展运算符，检查 73 页，剩余命中 0。独立核对引用表中全部 5 个标记的内容和顺序。英文括注的例外按短语匹配，回归验证同一段的后续 Scheme 调用仍能报错。

| 本次实测命令 | 退出码 | 结果 |
|---|---:|---|
| `node scripts/sync-legacy.mjs --write`、`node scripts/sync-legacy.mjs` | 各 0 | 镜像已生成并复核 |
| `node tools/check-presentation-contract.mjs`、`node tools/reader-contract/check.mjs` | 各 0 | 契约通过 |
| `node tools/reading-typography/check.mjs`、`node tools/reading-presentation/check.mjs` | 各 0 | 全站排版、呈现通过 |
| `node tools/reading-prose/check.mjs`、`python -X utf8 tmp/i084/quote/independent.py` | 各 0 | 两次独立扫描各覆盖 73 页 |
| `node --test scripts/*.test.mjs` | 0 | 160 项通过，0 跳过 |
| `git diff --check` | 0 | 差异格式通过 |
| `python tools/project.py check-local` | 0 | 使用 Poppler，报告 tmp/project-check/20261119T225158-pplrg1po/report.json |
| `python books/sicp/tools/check_notes.py` | 0 | 完整检查；4 页、143 题，两章 Racket 回归分别为 8、21 组 |
| `python tools/project.py build` | 0 | 本地构建 20261119T225158，73 个阅读页 |
| `node scripts/verify-parity.mjs --book sicp` | 0 | 4 页，0 差异 |
| `node scripts/check-offline.mjs --book sicp` | 0 | 有脚本 24 个视图、无脚本 12 个视图，外部请求 0 |
| `node books/sicp/tools/check_chapter02_browser.mjs --dist` | 0 | 6 个正式视图通过 |

在构建产物另用离线无脚本 Chrome 以 1440 和 390 像素检查引用表。5 个代码元素均可见、使用等宽字体，来源链接指向 PDF 220，两种宽度下整页横向溢出均为 0。复测前次的 CSAPP push/ret、jmp、EOPL print(e) 及 SICP deep-reverse，两个宽度均通过。本轮执行记录位于 tmp/i084/quote/。

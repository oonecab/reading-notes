# T082 内容深度正式验收

正式页 18 个教学小节均有输入、初态、步骤、结果、验算、不变量与边界。26 段读图说明与 16 段教材程序说明紧邻各自材料，题解理由绑定实际题号。逐节程序探针与浏览器读回见 books/sicp/review/chapter02.json 的 content_depth 和 browser。结构校验比较正文、契约与审阅绑定；教学推演仍需逐节复核。

`node --test scripts/content-depth.test.mjs` 退出 0，11 项通过，包括真实页面正例、缺问题/例子/步骤/边界、同义空话的重复、漏图解、漏代码解释、复制材料充当示例、未登记旧页等反例。旧页依照 I083 清单审计，来源为前置提交的既有阅读页。

## I077/I082 正式验收

第 2 章从候选进入本地正式目录。I074 基线为 5281ead11a79edbef72d11a962c8993e44bb2379，兼容镜像由同步脚本生成。早期候选、缺基线和缺正式产物的记录保留。正式范围为四页、143 题；第 2 章 97 题、18 个二级节、23 组注解和 97 个题号索引。五节摘录义务含三段可见摘录、两条省略记录。

书架初检发现仍显示 3 页；正式排版初检发现 13 处锚点内有长行内公式缺横滚容器。更新书架及包裹层后重测通过；原 MathML 与题号保留。最终构建为 73 个阅读页，SICP parity 四页零差异。第 2 章成品为 864,485 字节，gzip 305,553 / 310,000 字节。26 幅图由 23 个内联 SVG 与 3 个内嵌 WebP 构成。

正式 Chrome 六视图覆盖 1800/1440/1024/390 有脚本及 1440/390 无脚本，核对地图直达、首末题、97 索引、代码开合、图像加载、摘录义务、公式及图版深链。390 像素时图版局部横滚 158 像素、整页无横溢。离线入口 6 个，有脚本 24 视图、无脚本 12 视图，外部请求为零。Racket 8.10 执行两章分别 8、21 组程序回归，另有 18 个逐节复算。Node 共 149 项通过。根检查报告为 tmp/project-check/20261118T213752-k73pkc64/report.json。

| 命令 | 退出码 |
|---|---:|
| `node scripts/sync-legacy.mjs --write` | 0 |
| `node scripts/sync-legacy.mjs` | 0 |
| `node tools/check-presentation-contract.mjs` | 0 |
| `node tools/reader-contract/check.mjs` | 0 |
| `node tools/reading-typography/check.mjs` | 0 |
| `node tools/reading-presentation/check.mjs` | 0 |
| `node --test scripts/*.test.mjs` | 0 |
| `python tools/project.py check-local` | 0 |
| `python books/sicp/tools/check_notes.py` | 0 |
| `racket books/sicp/code/test-chapter02.rkt` | 0 |
| `racket books/sicp/tools/check_chapter02_examples.rkt` | 0 |
| `python tools/project.py build` | 0 |
| `node scripts/verify-parity.mjs --book sicp` | 0 |
| `node scripts/check-offline.mjs --book sicp` | 0 |
| `node books/sicp/tools/check_chapter02_browser.mjs` | 0 |
| `node books/sicp/tools/check_chapter02_browser.mjs --dist` | 0 |
| `python tools/test_project_contracts.py` | 0 |
| `git merge-base --is-ancestor 5281ead HEAD` | 0 |
| `git diff --check` | 0 |

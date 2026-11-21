# T085 阅读目录树

本地构建 `20261120T221010`。先在独立 SICP 第 2 章样章验证 1800、1440、1024、390 像素有脚本及 1440、390 无脚本，再将共享函数接入两份现有控制器。最终 dist 在相同六种视图通过。另用 Chrome 打开全站 73 个正式页，对照源 HTML 的目录链接顺序，16 页形成 39 组。73 页在 script/style 元素之外与修改前镜像逐字节相同。

| 检查命令 | 退出码 | 结果 |
|---|---:|---|
| `node scripts/sync-legacy.mjs --write`、`node scripts/sync-legacy.mjs` | 各 0 | 源页生成镜像，再次核对一致 |
| `node tools/check-presentation-contract.mjs`、`node tools/reader-contract/check.mjs` | 各 0 | 全站呈现、阅读契约通过 |
| `node tools/reading-typography/check.mjs`、`node tools/reading-presentation/check.mjs` | 各 0 | 排版、呈现检查通过 |
| `node --test scripts/*.test.mjs` | 0 | 167 项通过，含目录结构、状态与深链接负例 |
| `git diff --check` | 0 | 差异格式通过 |
| `python tools/project.py check-local` | 0 | 使用 Poppler，报告 tmp/project-check/20261120T221126-vrmxwi95/report.json |
| `python books/sicp/tools/check_notes.py` | 0 | 含 Racket 的 SICP 完整检查通过 |
| `python tools/project.py build` | 0 | 73 个阅读页，612 个公开文件，性能预算与 CSP 通过 |
| `node scripts/verify-parity.mjs --book sicp` | 0 | 四页，0 差异 |
| `node scripts/check-offline.mjs --book sicp` | 0 | 24 个有脚本视图、12 个无脚本视图，外部请求 0，随后目录树检查通过 |
| `node scripts/toc-tree-browser.mjs --dist` | 0 | 样章六个正式视图通过 |

浏览器从 #s2-4-3 深链进入，核对可见落点、当前链接、桌面和窄屏初始状态、链接顺序、按钮所控制的唯一列表及 aria-expanded。点击、Enter、Space、手动折叠后滚动、hashchange、组内链接、打印展开与恢复均经过操作；窄屏点按钮保留整栏，点链接关闭整栏。无脚本时通过原生目录访问全部链接，未出现整页横向溢出。

早期运行发现随机过程审阅摘要失配、旧导航测试夹具缺少共享控制器、压缩体积超过预算，以及正式页打印样式隐藏目录。修复后重新运行。随机过程第 1 章最终 gzip 为 305924 字节，原上限为 306632 字节。实际运行日志在 tmp/i085/，全站当前源与正式输出散列见 docs/toc-tree-review.json。

### 目录点击产生文字选区

修复前，Chrome 在原生目录标题上连续三击后读出选区“目录”。共享侧栏样式增加 user-select: none。构建 20261120T223537 和六组正式浏览器视图退出码均为 0；连续点击后选区为空，双击正文标题仍可选字。全站 73 页再次核对链接顺序通过。

### 可复用组件 API 验收

本地正式构建 20261120T231425。独立页面先用空参数、缺少 panel/nav 和空目录调用 API，再插入自定义 h3/h4、缺失目标、无子项父标题及跨级条目。验证 650 像素自定义断点、已有同名 id 的避让及重复调用后的节点稳定性。全站从源页独立推导父子项，源镜像和 dist 各检查 73 个有脚本页面及 73 个无脚本页面。两次均为 16 页、39 组；每页宿主自动调用一次，重复调用后的 DOM、节点顺序和 href 保持一致。七本书均覆盖，包含视觉群论已有嵌套列表的页面。无脚本时打开整栏后所有链接可见；无外部请求、整页无横向溢出。

SICP 第 2 章在源镜像与 dist 的四个有脚本及两个无脚本视图均通过。检查了深链、当前节、鼠标与键盘、打印展开与恢复、窄屏整栏及正文文字选择。此前全站 smoke 发现已有子列表没有生成折叠按钮；已纳入实现与预期分组对照。初次正式构建还发现 JavaScript 超出既有预算，随后共享链接解析并压缩发布用阅读控制器，保留原预算。

镜像写入/核对、presentation、reader、typography、reading-presentation、源页浏览器、Node 全套（171 项）、git diff --check、根 check-local、SICP 完整检查、build、SICP parity、offline、dist 浏览器的最终退出码均为 0。根报告 tmp/project-check/20261120T231530-8asdwu1k/report.json；SICP parity 四页零差异，离线检查 24 个有脚本与 12 个无脚本视图。源、产物、浏览器日志与检查脚本的 SHA-256 已登记在 docs/toc-tree-review.json。

持续验证见 [T086](T086-toc-smoke.md)。

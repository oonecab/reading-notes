
# T086 全站目录树门禁

运行 `pnpm check:toc` 检查源镜像，运行 `pnpm check:toc:dist` 检查构建产物。按正式页面登记枚举，1440 像素逐页检查有脚本和无脚本模式，390 像素检查从源目录推导出的分组页。报告位于 `tmp/toc-tree-smoke/report.json`。键盘、打印、连续点击和移动端交互由 `scripts/toc-tree-browser.mjs` 的 SICP 样章覆盖。

2026-11-21 本地执行。正式登记动态枚举 73 页，其中 16 页有分组，共 39 组。源镜像和本次构建的 dist 各完成 178 个视图，1440 有脚本/无脚本各 73 页，390 有脚本/无脚本各 16 页；静态预检和各视图失败数均为 0。源镜像输出在 tmp/smoke-src.log，dist 输出在 tmp/i086-release1.log。

同步写入与只读检查、presentation-contract、reader-contract、reading-typography、reading-presentation、样章浏览器、全站 smoke、Node 全套（173/173）、git diff --check、Poppler check-local 和 SICP 完整检查均返回 0。断言覆盖乱序、缺按钮、缺 ARIA、展开与可见性冲突、无脚本出现按钮或隐藏链接、深链组关闭、重复按钮或控制 ID。13 项目录契约测试通过。

默认 Node 24.14.0 低于构建要求，使用本机 Node 24.22.3 重新 build，退出码 0。SICP parity 四页差异 0；offline 为 24 个有脚本及 12 个无脚本视图，外部请求 0。两条命令均返回 0。offline 随后执行 dist 全站 smoke 和六视图深度样章，两项均通过。

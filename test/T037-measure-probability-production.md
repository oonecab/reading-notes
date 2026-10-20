# T037 测度概率第五、六章生产验收

状态：completed。日期：2026-10-20。关联：[I037](../issues/I037-measure-probability-production.md)、[P037](../plan/P037-measure-probability-production.md)。本轮机器报告、日志与截图位于忽略目录 `tmp/ch56-production-20261020/`；下列路径以该目录为基准，另注明根检查报告路径。

## 发布身份与本地验证

正式包 `20261020T142535` 来自干净提交 `163478b1ed2a008438cf33e79498a195c59dae00`，归档 SHA-256 为 `f015ff983d4d30bcd04385ada742cdbb53b31d2605658f773d97ee6459ddf282`。495 个文件包含 76 个 HTML、56 个正式阅读页和 188 个 gzip sidecar；公开文件与原线上版 `20261020T120833` 逐项相同。见 `build.json`、`package-preflight.json`。

`python3 tools/project.py doctor` 锁定版本检查、Node 21 项测试、统一构建、56 页 DOM parity、CSP 浏览器门禁、公开包 Gitleaks 扫描通过。本地真实 Nginx HTTPS 核对通过 490 文件、188 gzip 表示、15 个兼容入口及两份 PDF Range，报告为 `tmp/release-check/20261020T142535-rdcmkzr3/https-verification.json`。测度概率离线验收覆盖 10 个公开页面的 40 个常规视图和 20 个无脚本视图，见 `offline.log` 及其引用的独立运行报告；外部请求数为 0。

根完整检查的前 14 项通过，包含公共发布回归、随机过程和 Weiss 完整程序执行，见 `tmp/project-check/20261020T142641-g_n5ilcv/report.json`。视觉群论、测度概率分别从根入口完成完整检查，报告为 `tmp/project-check/20261020T144017-ac36zknx/report.json`、`tmp/project-check/20261020T144129-iwah3k21/report.json`。第五、六章 `product_limits` 覆盖 298 个有效案例、35 个非法案例、999 次 CLI 执行；6 类错误变体被拒绝，C 发布版、ASan/UBSan 版及 Python 与独立有限模型预期一致。

完整检查保留四次失败：两次整仓运行及一次 Python 3.14 单书运行在 CS:APP 信号回归的不同位置出现 1 秒超时；Python 3.12 单书复核在 readiness 等待超时。原报告分别为 `tmp/project-check/20261020T142047-uudh1x9w/report.json`、`tmp/project-check/20261020T142641-g_n5ilcv/report.json`、`tmp/project-check/20261020T143217-kjnj4luu/report.json`、`tmp/project-check/20261020T143642-76su3bxu/report.json`。24 次旧二进制原时限重放及 12 次新编译启动探针均得到预期结果，但不足以确定超时根因。随后原信号模块在原编译参数和原 1 秒 GUARD 下完整通过，包含 10 个进程清理场景、2 个 HTML 信号掩码场景、8 个错误变体；原入口在其后的六组回归也全部通过。见 `signal-isolated/report.json`、`csapp-remaining-round2/report.json`。前置检查、完整信号模块和后续检查共同构成分组验收证据；未改动程序、测试和时限，也未将单次整仓运行记为成功。发布前判定保存在 `predeploy-acceptance.json`。

## 生产与外部 HTTPS

现有 systemd 队列完成原子发布，`current -> releases/20261020T142535`；deploy 与 health 的 `Result=success`、`ExecMainStatus=0`，Nginx active，健康 timer active。发布器事务内源站内容检查成功，ready 队列为空、done 回执存在、无遗留事务。新旧版本各 495 文件的 SHA、root 所有权、文件 0444／目录 0555 权限均已核验；495 个内容相同文件的 mtime 保留，旧版 `20261020T120833` 继续作为完整恢复单元。Nginx 片段 hash 与发布前一致，现有 CSP 覆盖全部本版脚本。见 `deployment-actions.log`、`deployment-result.json`、`server-before.json`、`server-after.json`。

本机默认 DNS 路径将域名解析到代理地址，命令行全量核对在首个文件经三次尝试后因 TLS EOF／连接重置终止，保留 `public-verification.log`。随后使用验证器支持的 `--connect-ip` 连接已确认的源站公网 IP，同时保持 `https://notes.zzzping.top` 的 Host、SNI 和正常证书校验；`public-origin-verification.json` 通过 490 文件、188 gzip 表示及解压内容、490 次 ETag 条件请求、15 个兼容入口、2 份 PDF Range 与拒绝规则，transport retries 为 0。此结果是外部机器直连公网源站的证据，不能表述为默认 DNS 命令行路径恢复。

浏览器始终通过正常域名进入站点；第五、六章另用浏览器同源请求核对完整 HTML 的 SHA，与正式 manifest 一致，见 `public-interactions-round3/report.json` 的 `domain_content`。该路径与上述源站 IP 验证分别记录。

## 第五、六章阅读验收

正式页面为 `/measure-probability/notes/chapter05_product_spaces.html` 和 `/measure-probability/notes/chapter06_independent_sequences.html`，主报告为 `public-reading-round3/report.json`：

- 两章各检查 1800、1440、1024、390px，共 8 个常规布局视图。主文 MathML 数分别为 369 与 601，原题数分别为 28 与 27；展开内容后无整页横向溢出、`merror` 或替换字符。宽屏的阅读注解随当前章节进入侧栏，另有 8 次侧栏切换检查，确认相应公式逐字匹配且可见。
- 55 题分别在 1440px 与 390px 完成深链定位，共 110 次；题目和答案可见、顺序正确，标题进入视口，定位稳定。
- 18 次章内目录导航验证定位、高亮和窄屏目录收拢；14 次跨页导航覆盖第五章与第四／六章、伴读总览及书架。合计 32 次。
- 禁用 JavaScript 后，两章在桌面／窄屏共 4 个视图通过；原生 `details` 可展开，题目、答案和静态 MathML 保持。常规布局轮次捕获的 CSP／runtime 错误数为 0。

补查报告 `public-interactions-round3/report.json` 实走 1440px 与 390px 的“书架→伴读总览→第五章”，在两章各选择一条长公式发送水平滚轮输入，确认公式区 `scrollLeft` 改变而页面 `scrollX=0`、文档宽度保持；另完成禁用脚本的第五章→第六章→第五章导航。

共 28 张未修改的浏览器截图已逐张打开查看，清单和散列见 `visual-review.json`。检查样例覆盖转移核联合质量、Fubini 条件、Tulcea 扩张、多维矩形增量、三级数定理、特征函数反演、Lindeberg 条件以及习题 6.26 的归一化。积分、求和、上下标、根号、分式及希腊字母可辨认；窄屏长式的右端可通过局部横向滚动读到。无脚本截图保留了原题、答案与原书校注。

最初两轮页面脚本分别因把公式的 `data-accessibility-key` 当作 id、要求所有宽屏注解同时出现在当前侧栏而停止；两轮补查脚本因首页相对 href／文本定位假设停止。原失败报告保留在 `public-reading/`、`public-reading-round2/`、`public-interactions/`、`public-interactions-round2/`。按实际 DOM 和侧栏行为修正本轮临时验收脚本后，完整重跑通过；正式页面未改动。

本次是已维护内容的发布与显示验收，未重新开展逐条原书数学审阅；窄屏证据来自浏览器视口，未声明实体手机或屏幕阅读器验收。环境及当前发布文档已同步，历史数学审阅绑定保留，浏览器任务空间已关闭（`browser-finish.log`）。文档同步后根 `check --quick` 全部通过，报告为 `tmp/project-check/20261020T145724-kspmm7pj/report.json`；暂存变更 Gitleaks 扫描无发现。提交／远端及服务器最终读回另存 `final-delivery.json`；发布证据文档提交与生产包的源码提交分别记录。

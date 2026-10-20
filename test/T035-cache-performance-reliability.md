# T035 缓存与发布验证

日期：2026-10-20。关联 [I035](../issues/I035-cache-performance-reliability.md)、[P035](../plan/P035-cache-performance-reliability.md)、[T035](../test/T035-cache-performance-reliability.md)、[M035](../milestone/M035-cache-performance-reliability.md)。

旧实现反例：tmp/i035/red-tests.log 缺少预压缩入口而失败；tmp/i035/reader-red.log 捕获首个 DOM 写入后的布局读取而失败。新实现通过 6 项 Python 交付回归和 20 项 Node 测试。缓存用固定同一秒验证相同内容复用、同大小变化、返回旧内容、gzip/identity 等大小表示、历史文件内容校验和持久写失败；公开清单验证伪造/遗漏/额外 sidecar、旧策略未登记和摘要不匹配；HTTP 200 的错误正文不能通过健康检查。

完整 `python3 tools/project.py check` 通过，证据 tmp/project-check/20261020T110755-zzpdt4c0/report.json，包含五书程序、严格 C/运行回归和当前审阅绑定。`pnpm test` 20/20；`pnpm check:parity` 56 页零差异。构建生成 76 个公开 HTML，CSP 浏览器覆盖 9 页/12 种脚本哈希，变异脚本确实被阻止；HTML/压缩体积、DOM、JS 预算通过。

离线验收 tmp/reading-notes-migration/browser/all/runs/2026-10-20T03-08-10-291Z-7a7f0021/report.json：304 个 JS 视图（1800/1440/1024/390）与 152 个无 JS 视图通过，包含辅助页、深链、折叠、TOC、公式图形与局部滚动。实际打开查看 CS:APP 第 2 章 1440 顶部和 390 题解截图；正文、公式、左右栏、移动折叠与底部导航可读。

真实本地 Nginx：tmp/publish-check/20261020T120000-mmczgjfz/report.json，24 项演练通过；覆盖六阶段 SIGKILL、持久化、损坏 journal、锁、gzip/identity 条件请求、同大小内容变化、显式回滚、test/reload/health 失败和恢复检查再失败。全量 HTTPS 对 490 个非重定向文件验证 SHA/类型/CSP/304，对所有派生 gzip 校验原始压缩字节、解压等价、Vary、gzip;q=0 回退，并保留两个 PDF Range 与 15 个旧入口行为。测试包装有意添加等长首页标记，仅用于隔离演练。

后续记录：Ubuntu 隔离重跑、独立浏览器性能样本、最终 Git/生产内容验收。浏览器 CPU 降速是实验条件，不是实际手机或真实用户百分位；静态体积下降不直接等于同幅加载时间下降。

Ubuntu 22.04 / Nginx 1.18.0 隔离演练由非特权 reading-notes 用户运行，最终 24 项通过，报告 source/tmp/publish-check/test-package-qclp8ht2/report.json（私有隔离目录），未切换在线 current。新验证器的 6 项单元回归在服务器 Python 3.10 上也通过；其中 identity/gzip 等大小强 ETag 分离新增后重新跑了整个服务器演练。最后 quick 检查 tmp/project-check/20261020T111638-d2u4hssf/report.json 通过。

浏览器前后各 36 次独立采样：tmp/i035/performance-comparison.json。1440px/1x 与 390px/4x，环回 Nginx、网络不降速，每页面首访/复访各 3 次。前序与 quick 检查重叠的 36 次预热样本明确排除，不覆盖原记录。压缩字节：随机过程第 1 章 381416 → 289216（-24.2%）；CS:APP 第 2 章 131718 → 110387（-16.2%）；首页 6506 → 5898。降速窄屏首访 loadEventEnd 中位数分别 1258 → 1146ms、500 → 429ms；桌面随机过程首访 479 → 486ms，CS:APP 复访 145 → 165ms，表明延迟存在波动，不能宣称所有场景同幅加速。最长章仍有 74912 个元素。

另做单次 content-visibility 原型实验（仅浏览器注入，未进入源码）：首次 load 865 → 493ms，初始文档高度 214105 → 46845px，末题深链两者均能展开并定位。证据 tmp/i035/content-visibility-experiment.json。样本和高度估计均不足以支持全站推广，本次没有启用该原型。

正式发布 `20261020T112509` 来自干净提交 `e2ce9179c5c82f48963433cca730180f3dd2e14a`，归档 SHA-256 `efb70752427b484b9c305d6666537c8e599d929af38a41e9f4b8270468243de0`；与隔离演练包的全部站点文件和 archive SHA 完全一致。代码推送已核对本地、tracking 和远端 ref。上线前备份发布库、固定 helper 与 snippet 到 `/root/reading-notes-i035-20261020T112509`，安装后先验证旧站内容，再通过 reading-notes-deploy.service 发布；Result=success / ExecMainStatus=0，origin_health=passed。health timer enabled/active，首次 health.service 成功。

源站完整 HTTPS 校验通过 490 个非重定向文件、188 份预压缩表示、15 个旧入口和两份 PDF Range，报告 tmp/i035/origin-verification.json。root 只读权限、候选和前版 SHA、无遗留 journal 均再次验证。276 个相同内容文件的 mtime 全部保留；公网用前版 ETag 请求随机过程第 1 章 identity 和两份 PDF 返回 304，修改页返回 200，随后当前 identity/gzip 条件请求返回 304，证据 tmp/i035/cache-production.json。首次改用 gzip-6 的压缩字节变化，旧 gzip 验证器正确失效一次。

公网浏览器实际走通首页 → CS:APP 伴读总览 → 第 2 章 → 390px 宽表横滚 → 末题深链，105 个横滚候选中实际宽表 scrollLeft 0 → 148，文档未横溢出；末题展开且位于视口内、目录高亮正确。桌面和窄屏截图已打开检查，证据 tmp/i035/public-browser.json 与 public-csapp-*.png。

首次公网全量验证因一次读取超时退出，保留 tmp/i035/public-verification.log；没有记为成功。验证器补上只重试 GET/HEAD、最多三次、关闭失败连接、保留重试记录和每 50 文件进度。`tools/test_http_verification.py` 的恢复、重试耗尽、HTTP 错误不绕过、POST 不重放测试在本机及 Ubuntu 通过。最终公网复跑已成功，见下段。

最终公网全量复跑：tmp/i035/public-verification.json，2026-10-20T11:38:51.276913+08:00 至 2026-10-20T11:43:57.810325+08:00，490 个文件、188 个压缩表示、15 个旧入口、两个 PDF Range 全部通过，transport_retries=0。原有测度第 5/6 章随本次完整发布上线，其路径与内容 SHA 已纳入核对。代码及站点构建提交为 e2ce917；发布后的验证器维护与本交付记录作为后续提交，不改变站点 payload。Gitleaks 初次代码暂存区扫描无泄漏；最终提交前再次扫描。隔离临时 payload 已在保留完整证据后清理；正式前版、归档回执和 root 恢复备份仍保留。

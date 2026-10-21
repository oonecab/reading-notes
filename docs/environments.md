# 环境事实

<!-- project-governance:managed:start -->
## 环境变量名

- ASTRO_TELEMETRY_DISABLED
- READING_NOTES_CSP_SPACE
- READING_NOTES_TEST_CRASH

## 服务

- 本地预览：Python 静态 HTTP 服务，绑定 127.0.0.1
- 正式阅读站点：notes.zzzping.top，Nginx + TLS；部署步骤见 deploy/README.md
- Ubuntu reading-notes-deploy.service 以 reading-notes 执行，通过固定 sudo root 安装器发布；deploy timer 保持 disabled；本地构建，Web 主机无需构建用户。
- 宿主机历史 MySQL 服务及数据已于 2026-10-17 按 I030 卸载；mailutils 依赖的 mysql-common 与 libmysqlclient21 保留为共享客户端组件。
- I033 已应用 root 安装器、root-owned 只读 release、SSH 仅公钥、FTP masked、UFW 22/80/443 和 fail2ban sshd；I051 当前 release 为 20261021T135233，I050 的 20261021T125632 及对应配置保留为恢复单元。DNS 自动续期与用户自行轮换 root 密码仍待处理，见 docs/browser-stability-report.md。
- I035 已启用 reading-notes-health.service/.timer：15 分钟回环 HTTPS 内容核对；I051 发布与健康检查成功，timer 保持 active，现有端口和服务配置沿用，证据见 T035/T051。

## 端口与端点

- 本地预览默认 8000，仅 127.0.0.1；可用 --port 指定
- 生产 Nginx 80 / 443；HTTPS 已验收，源站 HTTP 返回 301，当前公网 HTTP 返回 403，见 I029。
- 原 MySQL 3306 / 33060 监听已随 I030 服务卸载关闭。
- Weiss 正式入口为 https://notes.zzzping.top/weiss/notes/book_overview.html；原独立域名已停用并删除 DNS，服务器旧站文件、Nginx vhost 和专属证书续期条目已于 2026-10-17 按 I031 清理。

本文件严禁写入凭据或生产数据。`.env.example` 必须与环境变量名清单同步。
<!-- project-governance:managed:end -->

## 项目专属环境说明

本地阅读使用离线 HTML 或环回 HTTP；临时 HTTPS 验收单独创建测试证书和 Nginx 配置，验证后停止测试进程。生产域名、目录、证书和切换步骤以 [部署说明](../deploy/README.md) 为准，执行发布前读取实际状态。当前项目不要求用户设置持久环境变量；本地 TLS 验证器只对自己的子进程设置 `SSL_CERT_FILE`，不修改系统信任。未单独登记预发布环境。

新模板目录为 `/srv/reading-notes`，构建工作目录为 `/opt/reading-notes-builder`；Node/pnpm 只存在于构建主机。Web 主机的 Python/rsync/flock 是一次性发布命令依赖，不是 HTTP 运行服务。现网已在 I029 切换到 /srv/reading-notes/current/site，旧 /var/www/notes.zzzping.top 目录与配置保留为首次迁移恢复点；实际版本见 [生产发布记录](astro-production-report.md)。

I032 的构建 CSP/离线验收需要 Ego Lite 与 ego-browser CLI，在私有任务空间运行；临时 HTTP 服务只绑定回环随机端口，用后关闭。I033 实机已关闭 SSH 密码认证并验证新密钥会话，FTP 已 stop/mask，无 21/3306 监听；UFW 仅保留 22/80/443，fail2ban sshd jail 已运行。root 密码未轮换，现有 Certbot 手工 DNS-01 续期仍需改为自动 DNS；HTTP dry-run 实测 403，后续步骤见 [DNS 续期交接](../deploy/DNS-RENEWAL.md)。

I035 新增 `reading-notes-health.service/.timer` 模板，每 15 分钟以回环 TLS 核对当前发布内容；独立 oneshot，无新增端口或凭据变量，安装状态见 I035。Nginx 新模板要求 gzip_static 模块；持久缓存验证器登记位于 `/srv/reading-notes/.cache-validators.json`，只由持锁 root 发布器更新。

2026-10-20 I035 实机：reading-notes-health.timer 已 enabled/active，health.service 首次执行 Result=success、ExecMainStatus=0；每 15 分钟并带最多 30 秒抖动执行回环内容检查。current 为 releases/20261020T112509，保留 20261017T210828 作为前版。发布工具/片段备份和证据保存在 root 的 I035 私有目录，见 T035；没有新增公开端口或应用服务器。

2026-10-20 I036 实机：current 更新为 releases/20261020T120833，来源为干净提交 4471c54；上一版 20261020T112509 已核验并保留。发布 unit、内容健康检查均成功，健康 timer 保持 active，Nginx 片段 hash 与发布前相同，版本树保持 root 拥有且只读。此次仅发布图标修复的静态文件包；环境变量名、服务配置和端口沿用既有约定，.env.example 无需调整。见 [T036](../test/T036-book-favicon.md)。

2026-10-20 I037 实机：current 为 releases/20261020T142535，来源为干净提交 163478b；恢复单元 20261020T120833 已逐项校验并保留。新旧版本各 495 文件的内容与只读权限通过校验，495 文件保留 mtime；Nginx 片段 hash 与发布前一致，发布及内容健康检查成功，health timer 保持 active。环境变量、服务配置和端口沿用原约定，.env.example 无需调整。测度概率第五、六章的页面、导航和公式实读结果见 [T037](../test/T037-measure-probability-production.md)。

2026-10-20 I041 实机：current 为 releases/20261020T212352，来源为干净提交 0a84a11，恢复单元 20261020T200604 已逐项校验并保留。新旧版本各 495 文件的内容、所有权和只读权限通过；Nginx 片段散列未变，发布与内容健康检查成功，health timer active。更新当前发布事实；环境变量、服务配置和端口未变，.env.example 无需调整。公网与浏览器证据见 [T041](../test/T041-review-followup.md)。

2026-10-20 I043 实机：current 为 releases/20261020T225222，来源为干净提交 0ccf855；恢复单元 20261020T212352 已核验并保留。495 文件、只读权限、缓存 mtime、Nginx 配置及发布/健康服务通过；正常域名和实际浏览器验收完成。环境变量、服务配置及端口不变，证据见 [T043](../test/T043-five-book-recheck.md)。

I044 新增静态 `/eopl/` 路由，范围为地图、序言、来源摘要和 Python 闭包示例；仍由既有 Nginx 80/443 提供，服务及非秘密环境变量名不变，无需修改 `.env.example`。前缀由 catalog 登记；本次在管理员维护的原 Nginx 片段中加入该前缀并保留已许可的 CSP 哈希集合，实际当前版本见 T044。

2026-10-21 I044 实机：current 为 releases/20261021T012051，来源为干净提交 24e7e69，标签 `v2026.10.21-typography`；恢复单元 `20261020T225222` 及其管理员配置已核验并保留。新旧发布树、缓存 mtime、Nginx、发布/健康服务、正常域名和浏览器验收通过。新增 `/eopl/` 前缀和显式发布清单，原 CSP 哈希集合保留，服务、端口及环境变量名保持。证据见 [T044](../test/T044-reading-typography.md)。

2026-10-21 I045 实机：current 为 releases/20261021T024246，来源为干净提交 bc442bb，标签 `v2026.10.21-inline-code-layout`；恢复单元 `20261021T012051` 已核验并保留。新旧版本各 511 文件的摘要和只读权限通过；395 个未变文件保留 mtime，116 个变更文件具有不同 mtime。Nginx 片段和发布策略摘要未变，发布及健康检查成功，health timer active；正常域名及六书桌面/窄屏浏览器验收通过。环境变量、服务、端口沿用原约定，`.project-governance.json` 与 `.env.example` 无需调整。证据见 [T045](../test/T045-inline-code-node-sizing.md)。

2026-10-21 I046 实机：current 为 releases/20261021T095146，来源为干净提交 c2784f9，标签 `v2026.10.21-reader-copy`；恢复单元 `20261021T024246` 已核验并保留。新旧版本各 511 文件及只读权限通过；477 个未变文件保留 mtime，34 个变更文件具有不同 mtime。Nginx 片段及发布策略摘要未变，发布和健康检查成功，health timer active。正常域名与受影响阅读页面的桌面/窄屏检查通过。环境变量名、服务配置和端口沿用原约定，`.env.example` 无需调整。证据见 [T046](../test/T046-reader-copy.md)。

2026-10-21 I047 实机：current 为 releases/20261021T103218，干净提交 33d3441，标签 `v2026.10.21-code-folding`；恢复单元 `20261021T095146` 已逐项核验并保留。新旧版本各 511 文件及 root 只读权限通过，475 个未变文件保留 mtime，36 个变更文件使用不同 mtime。发布与健康检查成功，timer active；Nginx 片段、发布策略、脚本 CSP、服务、端口和变量名保持，`.env.example` 无需调整。正常域名及代码交互证据见 [T047](../test/T047-code-folding.md)。

2026-10-21 I049 实机：current 为 releases/20261021T112119，干净提交 d41f129，标签 `v2026.10.21-code-font`；恢复单元 `20261021T103218` 已逐项核验并保留。新旧版本各 511 文件及 root 只读权限通过，363 个未变文件保留 mtime，148 个变更文件使用不同 mtime。发布与健康检查成功，timer active；Nginx 片段、发布策略、脚本 CSP、服务、端口和变量名保持，`.env.example` 无需调整。正常域名字体和折叠证据见 [T049](../test/T049-code-font.md)。

2026-10-21 I050 实机：current 为 releases/20261021T125632，干净提交 64d359b，标签 `v2026.10.21-math-notation`；恢复单元 `20261021T112119` 已逐项核验并保留。新旧版本各 511 文件及 root 只读权限通过，391 个未变文件保留 mtime，120 个变更文件使用不同 mtime。发布与健康检查成功，timer active；Nginx 片段、发布策略、脚本 CSP、服务、端口和变量名保持，`.env.example` 无需调整。正常域名字体和折叠证据见 [T050](../test/T050-math-notation.md)。

2026-10-21 I051 实机：current 为 releases/20261021T135233，干净提交 561e978，标签 `v2026.10.21-eopl-chapters-reviewed`。本版 519 文件及前版 `20261021T125632` 的 511 文件逐项校验，均为 root 只读版本树；499 个未变文件保留 mtime，12 个变更文件使用不同 mtime，新增 8 文件。部署和内容健康检查成功，队列为空、无待恢复事务，健康 timer active。发布策略更新为 `375100f1`，新旧政策由管理员归档；Nginx 片段、12 个脚本 CSP、服务、端口和变量名保持，`.env.example` 无需调整。完整公网验证通过，证据见 [T051](../test/T051-eopl-merge-review.md)。

## 构建与测试变量用法

`ASTRO_TELEMETRY_DISABLED` 在 Astro 子进程强制为 1。`READING_NOTES_CSP_SPACE` 是 CSP 与离线验收共用的 Ego 任务空间正整数 ID；显式指定的空间不可用即失败，互斥与恢复按 [Astro 编写说明](astro-authoring.md) 执行。`READING_NOTES_TEST_CRASH` 只用于隔离 dry-run 故障测试，生产路径不使用它作为故障开关。`.env.example` 是保留的人工安全示例，不包含凭据。

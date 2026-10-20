# 环境事实

<!-- project-governance:managed:start -->
## 环境变量名

- `ASTRO_TELEMETRY_DISABLED`：构建子进程强制为 `1`，禁用 Astro 遥测；`.env.example` 记录安全值。
- `READING_NOTES_CSP_SPACE`：可选的 Ego 任务空间正整数 ID，CSP 与离线验收共用。显式指定的空间不可用即失败；默认缓存仅在精确 not-found 时重建，恢复与互斥规则见 [Astro 编写说明](astro-authoring.md)。
- `READING_NOTES_TEST_CRASH`：仅隔离 dry-run 故障测试使用，选择强制终止阶段；生产路径不读取它作为故障开关。

## 服务

- 本地预览：Python 静态 HTTP 服务，绑定 127.0.0.1
- 正式阅读站点：notes.zzzping.top，Nginx + TLS；部署步骤见 deploy/README.md
- Ubuntu reading-notes-deploy.service 以 reading-notes 调用固定 sudo root 安装器，当前发布 20261020T112509（I035）；deploy timer 保持 disabled，构建服务及构建 tmpfiles 模板留给独立构建主机
- I033 已应用 root-owned 只读 release、固定 helper/sudoers，unit 已移除整目录 Nginx 日志写例外；实机证据见 [本轮报告](browser-stability-report.md)
- 宿主机历史 MySQL 服务及数据已于 2026-10-17 按 I030 卸载；mailutils 依赖的 mysql-common 与 libmysqlclient21 保留为共享客户端组件

## 端口与端点

- 本地预览默认 8000，仅 127.0.0.1；可用 --port 指定
- 生产 Nginx 80 / 443；HTTPS 已验收，源站 HTTP 返回 301，当前公网 HTTP 返回 403（见 I029）
- 原 MySQL 3306 / 33060 监听已随 I030 服务卸载关闭
- Weiss 正式入口：[Reading Notes · Weiss](https://notes.zzzping.top/weiss/notes/book_overview.html)；原 weiss.zzzping.top 独立域名已停用并删除 DNS，服务器旧站文件、Nginx vhost 和专属证书续期条目已于 2026-10-17 按 [I031](../issues/I031-retire-weiss-site.md) 清理

本文件严禁写入凭据或生产数据。`.env.example` 必须与环境变量名清单同步。
<!-- project-governance:managed:end -->

## 项目专属环境说明

本地阅读使用离线 HTML 或环回 HTTP；临时 HTTPS 验收单独创建测试证书和 Nginx 配置，验证后停止测试进程。生产域名、目录、证书和切换步骤以 [部署说明](../deploy/README.md) 为准，执行发布前读取实际状态。当前项目不要求用户设置持久环境变量；本地 TLS 验证器只对自己的子进程设置 `SSL_CERT_FILE`，不修改系统信任。未单独登记预发布环境。

新模板目录为 `/srv/reading-notes`，构建工作目录为 `/opt/reading-notes-builder`；Node/pnpm 只存在于构建主机。Web 主机的 Python/rsync/flock 是一次性发布命令依赖，不是 HTTP 运行服务。现网已在 I029 切换到 /srv/reading-notes/current/site，旧 /var/www/notes.zzzping.top 目录与配置保留为首次迁移恢复点；实际版本见 [生产发布记录](astro-production-report.md)。

I032 的构建 CSP/离线验收需要 Ego Lite 与 ego-browser CLI，在私有任务空间运行；临时 HTTP 服务只绑定回环随机端口，用后关闭。I033 实机已关闭 SSH 密码认证并验证新密钥会话，FTP 已 stop/mask，无 21/3306 监听；UFW 仅保留 22/80/443，fail2ban sshd jail 已运行。root 密码未轮换，现有 Certbot 手工 DNS-01 续期仍需改为自动 DNS；HTTP dry-run 实测 403，后续步骤见 [DNS 续期交接](../deploy/DNS-RENEWAL.md)。

I035 新增 `reading-notes-health.service/.timer` 模板，每 15 分钟以回环 TLS 核对当前发布内容；独立 oneshot，无新增端口或凭据变量，安装状态见 I035。Nginx 新模板要求 gzip_static 模块；持久缓存验证器登记位于 `/srv/reading-notes/.cache-validators.json`，只由持锁 root 发布器更新。

2026-10-20 I035 实机：reading-notes-health.timer 已 enabled/active，health.service 首次执行 Result=success、ExecMainStatus=0；每 15 分钟并带最多 30 秒抖动执行回环内容检查。current 为 releases/20261020T112509，保留 20261017T210828 作为前版。发布工具/片段备份和证据保存在 root 的 I035 私有目录，见 T035；没有新增公开端口或应用服务器。

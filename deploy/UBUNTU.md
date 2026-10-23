# Ubuntu 静态发布

I061 当前发布为 `20261023T211622`，来源为干净提交 `ee76a04`，上一版 `20261023T020252` 及配套政策与配置已核验并保留。新版本558文件、64阅读页和86公开HTML，实际部署、健康检查和正常域名读回见 [T061](../test/T061-eopl-publication.md)与[发布审阅](../docs/eopl-chapters-publication-review.json)。root 安装器、只读版本树、预压缩、缓存验证器与内容健康检查沿用既有操作约定。

I037 历史发布为 `20261020T142535`，来源为干净提交 `163478b`，上一版 `20261020T120833` 保留可回滚，测度概率第五、六章验收见 [T037](../test/T037-measure-probability-production.md)。I036 的书籍页面内联 favicon，以及 I035 启用的预压缩、缓存验证器与内容健康检查继续生效，见 [T036](../test/T036-book-favicon.md) 与 [T035](../test/T035-cache-performance-reliability.md)。I033 曾按 [I032 运维方案](OPERATIONS-I032.md)应用 root 安装器、只读版本树与新 unit，并发布 `20261017T210828`。`reading-notes-publish` 是受控生产写入口；I033 加固结果见 [I033 报告](../docs/browser-stability-report.md)，I029 保留为历史迁移记录。

构建主机使用 Node 24.21.0、pnpm 11.21.0、Python 3.10+、C/Make/Poppler；Web 主机只运行 Nginx。两台主机可以分开：Web 主机安装 Python、rsync 和 util-linux 仅用于一次性发布脚本，不启动 Node、Python HTTP 或数据库服务。下面的安装约定已在 I029 的 Ubuntu 22.04 上完成实机发布与验证；当前版本和证据见 [生产发布记录](../docs/astro-production-report.md)。独立构建主机仍为可选模板，本次构建在本地完成。

## 安装、目录与权限

Web 主机管理员安装 `nginx python3 rsync util-linux openssl certbot`，创建 `reading-notes` 系统组及同名无登录系统用户。独立构建主机另建 `reading-notes-build` 用户，加入 `reading-notes` 组；安装锁定 Node/pnpm 和 `clang make poppler-utils`，检出已审核提交至 `/opt/reading-notes-builder`。先执行 `python3 tools/project.py doctor`，不要用不匹配的 Node/pnpm 继续构建。

将 `deploy/scripts/`、`deploy/public_policy.py`、`deploy/http_checks.py`、`deploy/publish-allowlist.json`、`deploy/policies/`、`deploy/nginx/` 与 `tools/release_support.py` 按仓库相对结构安装到 `/usr/local/lib/reading-notes/`，由 root 拥有、目录 0755、普通文件 0644、脚本 0755。此安装目录不可由发布用户修改。将 `reading-notes-publish` 与 `reading-notes-nginx` 安装到 `/usr/local/sbin/`，root:root 0755。将 `reading-notes.sudoers` 用 `visudo -cf` 校验后安装到 `/etc/sudoers.d/reading-notes`，root:root 0440；它只允许调用校验固定动作及版本 ID 的 `reading-notes-publish`；安装器再调用 Nginx helper 的 test/reload/health。

Web 主机将 `reading-notes.tmpfiles.conf` 安装到 `/etc/tmpfiles.d/reading-notes.conf`，执行 `systemd-tmpfiles --create /etc/tmpfiles.d/reading-notes.conf`。独立构建主机在创建构建用户后额外安装 `reading-notes-build.tmpfiles.conf`；Web 模板不引用构建用户。运行目录为：

```text
/srv/reading-notes/releases/<release-id>/site/
/srv/reading-notes/releases/<release-id>/SHA256SUMS
/srv/reading-notes/releases/<release-id>/release.json
/srv/reading-notes/current -> releases/<release-id>
/var/spool/reading-notes/{ready,done}/
```

发布脚本把新目录改为目录 0555、文件 0444；拒绝重用版本号。`current` 与 release 位于同一文件系统。I032 新树由 root 持有；安装器预检字节与 inode 余量，持锁清理超过 24 小时的临时残留。正式版本 cleanup 默认只列计划，显式 apply 才删除超过七天且不在保护集合中的版本，至少保留最近三个版本、current 与最近成功发布的前版；首次迁移旧布局在该树外，保留不动。

## 构建、证书与首次上线

在构建主机执行：

```sh
pnpm install --frozen-lockfile
python3 tools/project.py check
python3 tools/project.py build
python3 tools/project.py verify-release --release-id YYYYMMDDTHHMMSS
```

`deploy/portal-releases/<id>/` 是传输单元，包含确定性的 `site.tar.gz`、逐文件 `SHA256SUMS`、`release.json` 和 Nginx 模板。SHA256SUMS 相对 `site/`，位于 web root 外。相同输入两次构建的清单和 tar.gz 均应相同；版本号与本地计时不进入网页。

在部署前完成域名及证书。HTTP vhost 先只安装 `notes.conf.template` 的 80 端口部分，创建与 vhost 相符的 `/var/www/letsencrypt`，在 HTTP 验证可达的环境使用 `certbot certonly --webroot -w /var/www/letsencrypt -d notes.zzzping.top` 取得证书，再安装完整 vhost。证书私钥留在 `/etc/letsencrypt`，不要复制进仓库或 release。当前 notes 域名的 HTTP 挑战实测返回 403，现有证书使用手工 DNS-01；自动续期按 [DNS 交接](DNS-RENEWAL.md)单独迁移。

管理员审查本版 `nginx-static.inc` 后将其安装到 `/etc/nginx/snippets/reading-notes-static.inc`，root:root 0644；完整 vhost 引用这份固定配置。发布用户不能写 Nginx 配置。脚本在切换前检查新版本所有脚本 CSP 哈希都已登记；未来新增脚本时必须先按变更控制审查并更新这份 snippet。发布目录中的同名文件仅用于审核和回退参考，不直接作为 root Nginx 的 include。

`disable_symlinks on from=$document_root` 允许管理员指定的 `current` 入口，但拒绝站点内部的符号链接。发布器本身同时拒绝归档内链接、路径穿越、白名单外文件和原始审阅数据。静态模板开启 UTF-8、gzip、ETag、CSP、HSTS、PDF Range、正确 MIME，关闭目录枚举，仅接受 GET/HEAD。HSTS 只在 HTTPS vhost 使用。

将审核后的包复制到 Web 主机私有队列，使用发布用户运行：

```sh
sudo -u reading-notes sudo -n /usr/local/sbin/reading-notes-publish publish YYYYMMDDTHHMMSS
```

脚本使用 `flock` 排他锁；在临时目录解包并检查 SHA256SUMS、元数据和精确 allowlist，用 rsync 写入新的 release，先创建临时 symlink，再用 POSIX rename 原子替换 `current`，随后执行受限的 `nginx -t` 和 `systemctl reload nginx`。任何正常异常或 TERM/INT 导致恢复原链接并重载旧配置；失败候选保留在 current 以外供检查。首次部署失败时移除新 current。

## 服务、回滚与验收

`reading-notes-build.service/.timer` 仅安装在构建主机；固定执行已检出的提交，不自动拉取远端。该主机需要 `/opt/node/bin` 中匹配版本的 node/pnpm，以及已经具备来源 PDF 的受控工作目录。构建任务完成完整 Python 检查后把包原子移入 ready 队列。Web 主机只安装 `reading-notes-deploy.service/.timer`；队列可以通过已有受控传输流程从构建主机送达。两个 timer 默认不因复制文件而启用；安装验证完成后管理员执行 `systemctl daemon-reload` 及相应 `enable --now`。日志见 `journalctl -u reading-notes-build -u reading-notes-deploy`。

Nginx 日志可沿用发行版 logrotate；若安装提供的 `reading-notes.logrotate`，先从发行版通配规则排除同名日志，避免重复轮转。tmpfiles 只创建目录，不清理版本。

发布 unit 的 `ProtectSystem=strict` 保持启用。Ubuntu Nginx 的 `nginx -t` 会以写方式打开已有 `/run/nginx.pid`，因此 `ReadWritePaths` 单独列出这个 root 拥有的文件；发布用户仍受文件权限限制，只有受限 sudo helper 能完成检查。未列出该例外时，实机预检返回 `Read-only file system`。如果发行版使用不同 PID 路径，先核对有效 Nginx 配置，再精确调整该文件路径并重新执行 unit 内预检。

回滚仍需持锁、验证旧版哈希，并实际 test/reload：

```sh
sudo -u reading-notes sudo -n /usr/local/sbin/reading-notes-publish rollback YYYYMMDDTHHMMSS
```

因断电或 SIGKILL 留下 `.publish-transaction.json` 时，新发布会拒绝继续；检查日志后执行 `sudo -u reading-notes sudo -n /usr/local/sbin/reading-notes-publish recover` 恢复日志记载的原版本。若旧版服务重载也失败，日志和事务记录保留，先排查配置再恢复。显式 rollback 只要求目标旧版本验证通过，因此当前版本的文件损坏不会阻断恢复。队列进程在成功发布后、移动回执前中断时，下次会校验已生效的同版身份后完成回执，不重复覆盖。构建被强杀时同理检查 `tmp/reading-notes-migration/build.lock/owner.json` 的进程是否已退出，然后只移除这个失效锁目录，不删除构建基线。

I032 加固后的安装顺序为：逐文件 fsync → 从叶到根 fsync 目录 → rename 候选 → fsync 候选与 releases 父目录 → 临时 journal 文件 fsync / 原子替换 / 父目录 fsync → 切 current / 父目录 fsync。清除 journal 和队列回执迁移也落盘。此契约依赖支持 POSIX fsync/同文件系统 rename 的本地文件系统及存储设备正确兑现写入屏障。损坏 journal 的 `--recover` 返回结构化诊断和退出码 2，保持文件及 current；管理员检查版本后使用 `reading-notes-publish recover YYYYMMDDTHHMMSS`，验证指定版本再恢复，并将损坏文件保留在 web root 外的 `.publish-transaction.corrupt-*.json`。恢复后可继续发布；不存在 journal 时 recover 幂等。

本地演练使用 `tools/test_static_publish.py --release-dir deploy/portal-releases/<id>`，真实执行 SHA、rsync、锁、原子 rename、临时 Nginx HTTPS/HTTP 和故障回滚。`publish.sh --dry-run --root <临时目录>` 也实际写入临时 release，但没有 service hook 时明确跳过服务动作，不代表生产验收。完整线上验收用 `deploy/verify_portal.py --release-dir <本地包> --origin https://notes.zzzping.top --output <私有报告>`，并实际检查桌面/手机页面、深链及公式。I029 已执行远端发布、真实 systemd/受限 helper 与生产证书 HTTPS 验证，并在 Ubuntu 隔离目录执行 13 项失败恢复测试。首次生产迁移保留旧站目录及配置，恢复命令见生产发布记录；没有为故障演练主动回退在线站点。

## I035 缓存与发布内容检查

安装新 helper 前保留旧 helper、snippet 和精确公开清单；旧清单以其 SHA-256 命名安装至 `deploy/policies/`（root:root，不可由队列用户修改）。新 release 按当前清单验证，旧版按其原清单验证。不要把上传包里的任意 policy 自动加入信任库。

Nginx 需要 `--with-http_gzip_static_module`，新 snippet 开启 `gzip_static on`、`gzip_vary on` 与 `if_modified_since exact`。仅命中真实 `.gz` 时静态协商 gzip，identity / gzip;q=0 正常回退；HTTP 响应继续 no-cache。预压缩在构建时完成，线上没有压缩任务服务。

发布锁内持久维护 `/srv/reading-notes/.cache-validators.json`；首次导入既有版本先逐文件验证哈希。相同 URL/内容复用秒级 mtime，identity 与 gzip 表示共享时间占用集合以避免等大小表示碰撞，改变内容在同秒发布也占用另一个未使用的过去秒，避免同大小 ETag 冲突和未来 Last-Modified。mtime 是缓存身份，不用于判断发布时间；版本身份看 release.json。即使保留策略删除旧 release，也保留该登记，禁止将它当临时缓存清理。登记写入及 fsync 在候选只读与 current 切换之前，失败终止发布。

`reading-notes-nginx health` 使用正常 TLS 主机名校验，连接 127.0.0.1:443，核对当前 manifest 的首页、每书入口和最大章节内容 SHA、类型、缓存及 CSP。健康检查处于事务内；任一步失败恢复旧 current，再执行 test/reload/health。恢复检查失败保留 journal。成功回执记录 release/archive/source 和源站健康状态；这不代替公网连通与浏览器验收。

可安装 `reading-notes-health.service/.timer` 并执行 `systemctl daemon-reload && systemctl enable --now reading-notes-health.timer`。每 15 分钟检查相同内容；持共享发布锁，发布进行时延后，遗留 journal 视为失败。unit 只有读取权限且不会修改 current；失败出现在 systemd 状态和 journal，不发送外部消息。使用 `systemctl status reading-notes-health.service`、`journalctl -u reading-notes-health.service` 查看；timer 不等于外部公网监测。实际安装状态以 I035 验收记录为准。

`tools/test_static_publish.py` 增加不变页面 identity/gzip 304、同大小首页变化 200、回滚 ETag、健康失败回滚；`deploy/verify_portal.py` 对所有文件验证内容及 304，对全部 sidecar 校验 gzip 原始字节、解压等价、Vary 和 gzip;q=0 回退，同时保留 PDF Range 和路由检查。

公网全量验证器对 GET/HEAD 的网络/读取异常最多尝试三次，每次都关闭连接并记录请求路径和异常类别；最终失败仍以非零退出。HTTP 错误状态、错误正文和 CSP/缓存断言不会被重试绕过，POST 拒绝测试也不会重放。每 50 个文件输出进度，报告保留 transport_retries。

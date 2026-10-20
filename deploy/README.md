# 统一笔记站点的构建与部署

六本书的 58 个正式阅读页及统一书架通过 Astro 7.4.0 构建。Node 24.21.0 LTS 与 pnpm 11.21.0 只用于构建，运行时为 Nginx 静态文件。数学、习题和程序由原 Python 检查器独立验证；读者下载的 C/Python 程序在自己的电脑运行。

## 构建与预览

从仓库根执行：

```sh
python3 tools/project.py doctor
pnpm install --frozen-lockfile
python3 tools/project.py check
pnpm build
pnpm check:parity
pnpm check:offline
python3 tools/project.py build
```

`pnpm build` 输出 `dist/`，同时写入 `tmp/reading-notes-migration/dist-SHA256SUMS`。58 页和书架均内联资源，可直接 file 协议打开；其他资料页和下载链接需要保留整个发布目录。Ego Lite 离线验收独立运行四种宽度和 no-JS；构建成功不能替代阅读验收。

`tools/project.py build` 调用同一个 Node 构建，在持有构建锁时打包，并拒绝覆盖已有版本号。可指定 `--release-id YYYYMMDDTHHMMSS`。完整包位于 `deploy/portal-releases/<id>/`：

| 文件 | 用途 |
|---|---|
| site.tar.gz | 确定性静态文件归档，只有它的成员进入 web root |
| SHA256SUMS / archive.sha256 | 相对 site/ 的逐文件清单 / 压缩包散列 |
| release.json | 本版路径、字节数、散列、路由、CSP 与白名单版本 |
| navigation.json | 本版链接与下载清单 |
| nginx-static.inc | 本版配置及脚本 CSP，供管理员审查安装 |
| nginx-notes.zzzping.top.conf | Ubuntu vhost 模板 |

相同内容输入的 SHA256SUMS 和归档相同；版本 ID、构建日志、计时及浏览证据位于 web root 外。临时候选经过 parity、内联与公开策略检查后才替换 dist，上一份保留在忽略目录。旧 `deploy/build_portal.py` 保留并提供兼容资料视图；它不再是根构建入口。冻结的 `reader_views.py` 保持原字节，旧发布协议见历史文档。

```sh
python3 tools/project.py serve --release-id YYYYMMDDTHHMMSS --port 8000
python3 tools/project.py verify-release --release-id YYYYMMDDTHHMMSS
python3 tools/test_static_publish.py --release-dir deploy/portal-releases/YYYYMMDDTHHMMSS
```

预览仅监听环回地址。`verify-release` 创建本次进程信任的临时证书，检查真实 Nginx HTTPS、哈希、MIME、CSP、PDF Range、旧入口及查询参数；结束后停止测试进程。发布集成测试另外检查 HTTP 跳转、gzip、ETag、HSTS、内部 symlink 拒绝、并发锁、不可覆盖、原子切换及故障回滚。日志与报告保存在 `tmp/`。

## 发布白名单与 Ubuntu

[精确白名单](publish-allowlist.json) 登记精确公开文件路径，构建和发布两次核对；新增文件必须明确登记。受控预压缩另生成 gzip sidecar，文件数量与内容散列以本版 release.json 为准。正文、源码下载及公开的来源/习题索引保留，37 个历史审阅/校验 JSON URL 返回固定公开摘要。原审阅记录、夹具、截图和内容基线继续由仓库保存，不作为站点文件。两份原已授权 PDF 按原路径及冻结散列保留：随机过程的 assets PDF 和 CS:APP 的 csapp.pdf。其余原 PDF 只用于本地对照。来源资料 URL 和正文页码链接保持；修改 PDF 收录属于新的兼容性变更，必须重新审阅，不能只翻转旧开关。

[Ubuntu 安装与操作](UBUNTU.md) 规定 `/srv/reading-notes/releases/<id>/{site,SHA256SUMS,release.json}` 和 `current`。`publish.sh` 持 flock、验证归档及 allowlist，用 rsync 写新版本，再创建临时链接并 atomic rename 到 current。受限 root 安装器校验队列并写入版本树，再由固定 Nginx helper 完成 test/reload，失败恢复旧链接。完整 Nginx 配置由 root 审核安装，发布用户不能修改；新增脚本须先安装相应 CSP。Web 主机无需 Node。

I028 完成本地迁移与演练后，用户在 I029 明确授权生产发布。2026-10-17 已在 Ubuntu 上部署 `20261017T174039`，静态根为 `/srv/reading-notes/current/site`。实际命令、实机验收与首次迁移回滚点见 [生产发布记录](../docs/astro-production-report.md)。旧布局 `20261017T151424`、站点配置、证书和续期约定保留；历史手工流程见 `docs/history/deployment-before-astro.md`，旧 builder 和单书工具保留。

Weiss 的正式阅读入口为 [主站 Weiss 笔记](https://notes.zzzping.top/weiss/notes/book_overview.html)。已退役的 `weiss.zzzping.top` 独立部署于 2026-10-17 按 [I031](../issues/I031-retire-weiss-site.md) 完成服务器清理：旧 web root、部署记录、Nginx vhost、日志和专属证书续期条目均已删除。主站当前版本及上述首次迁移回滚点保持。

当前维护入口见 [Astro 编写说明](../docs/astro-authoring.md)，迁移验证见 [T028](../test/T028-static-first-astro.md)。本地浏览、静态检查、程序执行、发布模拟与公网验收各自独立。

I033 已将生产更新到 `20261017T210828`，实测固定 root 安装器、systemd 发布、root-owned 只读版本和回滚恢复；SSH/FTP/UFW/fail2ban 已应用。当前证书的 DNS 自动续期仍待配置，见 [当前发布报告](../docs/browser-stability-report.md)与 [DNS 续期步骤](DNS-RENEWAL.md)。

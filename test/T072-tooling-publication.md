# T072 工具配置修复合并与部署：发布验收

2026-11-03，用户明确授权合并主分支、提交推送 GitHub 并部署指定服务器。关联 I069/I070/I071，本地修复验收见 [T071](../test/T071-final-build.md)。执行者 Codex；不改变教材内容与计算规则。

步骤：核对已验收源码摘要与远端；提交明确文件清单并合并 main；从干净提交构建，与 20261103T000200 的全部公开文件逐字节一致；运行隔离 Linux HTTPS/发布恢复测试；核对线上 current、文件摘要、CSP/配置与固定发布器；使用既有受限发布服务切换；核验新旧文件、健康状态、公网 HTTPS/缓存/PDF/浏览器；追加回执并推送文档。

回滚点预检为 20261025T233903，发布前保存当前配置及安装程序摘要；使用既有 reading-notes-publish rollback，保留旧版本，不删除历史版本。无密码、私钥或本机认证资料进入仓库。生产服务、端口、技术栈与变量名保持；本批不需新增 ADR。

状态：completed，最终结果见下文及发布回执。

## 发布前发现的跨平台缺陷

首次候选 20261103T002415 在服务器原生 sha256sum 校验时失败，current 仍为 20261025T233903、无遗留事务。原因是 Windows 默认文本写入把 SHA256SUMS 写为 CRLF；原发布演练在 Linux 重造夹具清单，未检验输入包原始清单。

修复：两种构建入口的发布元数据显式使用 UTF-8/LF；发布演练首先原样调用输入包的真实发布器，然后再运行变异/故障夹具。新增原始包回归在旧 Windows 包上实际失败（tmp/i072/manifest-negative.log），保留首次部署日志；不得现场放宽服务器校验或改写旧包掩盖来源。

## 2026-11-03 实际发布

修复内容提交 `1f98250884b008af8233c04b6ae156e23c45a327` 快进合并 main 并推送；随后补充清单换行修复提交 `9961ac655d8f1f2c3bba34813c502d50932cd690`。最终发布从后者的干净工作区构建，版本为 `20261103T003521`。

- 最终公开文件 587 个，69 个阅读页、91 HTML；所有公开文件与 T071 已验收包 `20261103T000200` 逐字节一致，归档 SHA-256 同为 `30178bc72ecc2aa1def64aed9c821374153a4883a964254b6e8343873563878e`。JSON、校验清单及生成配置现为 UTF-8/LF，CSP snippet 与现有服务器文件逐字节相同。
- Windows 正式构建、原预算、parity 和真实 CSP 正反例通过。最后新增修改只涉及发布元数据格式及原始包测试；T071 的 135 项 Node 测试与 546 个离线视图绑定的公开文件未变，按哈希复用，不声称本次全部重新执行。
- WSL Ubuntu 独立 ext4 目录执行最终包的 `tools/test_static_publish.py`：25 项通过，含未重写输入包的原生校验、SIGKILL 恢复、并发和 HTTP/HTTPS 回滚。`verify_local_release.py`：581 文件/条件请求、18 入口及 PDF Range 通过。日志 tmp/i072/linux-final.log，报告 static-final-report.json、https-final-report.json。临时 Nginx 已停止。旧版 24 项演练通过并未覆盖 CRLF 缺陷，失败过程保留。
- 服务器已将 current 切到 `releases/20261103T003521`。587 文件匹配最终清单并保持 root 持有/0444；旧版 `20261025T233903` 的587文件、权限和mtime逐项保持；292个同内容文件保留mtime，295个变化文件更新。固定发布程序及配置摘要未变，队列空、无未完成事务。
- 第二次切换和健康检查成功后，上传队列目录属主为root导致回执移动失败。修正该精确目录和三个上传文件的属主为reading-notes后，既有幂等恢复流程校验同版身份并完成回执（recovered_receipt=true），没有重复覆盖生产版本。部署服务及健康服务最终 Result=success/ExecMainStatus=0；Nginx及健康timer正常。
- 本机 Chrome 156 通过正常域名运行六书地图的1440/390/390无脚本18组，129次节点点击、15次键盘操作；六章1440/390共12视图及原生题目开合通过；30截图、运行错误为零。记录 tmp/i072/online-browser/report.json。人工打开8张：csapp-map-390-true、stochastic-map-1440-false，以及六书代表章节（随机过程/CSAPP/视觉群论390，EOPL/测度概率/Weiss1440），观察正文、题目/题解、公式/代码与导航可读。这不是全站逐题重审。

认证使用现有SSH密钥，未保存用户提供的密码。首次失败包及部署日志保留于服务器私有备份目录 `/var/backups/reading-notes/I072-20261103T002415/`，旧生产版本继续作为回滚单位。回滚命令仍为 `sudo -u reading-notes sudo -n /usr/local/sbin/reading-notes-publish rollback 20261025T233903`，配套配置本批未变。

网络证据边界：本机 Python/curl 直连域名出现 TLS reset（部署前已存在），真实本机 Chrome 可正常访问。全量生产 HTTPS 协议检查从服务器通过正常域名执行，另由本机 Chrome 提供外部阅读路径证据，不将服务器自检描述成独立外部全量协议测试。

生产 HTTPS 最终通过：581 文件及304、208组gzip、18入口、6份PDF Range，传输重试0次。完整回执见 [tooling-publication-review.json](../docs/tooling-publication-review.json)。最终文档维护提交不改变公开文件或构建实现，生产来源身份固定为9961ac6。

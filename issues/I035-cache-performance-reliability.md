# I035 缓存、加载性能与发布可靠性

日期：2026-10-20。关联 [I035](../issues/I035-cache-performance-reliability.md)、[P035](../plan/P035-cache-performance-reliability.md)、[T035](../test/T035-cache-performance-reliability.md)、[M035](../milestone/M035-cache-performance-reliability.md)。

用户在基于 web-engineering-playbook 的评估后要求开始修复，并已在本对话授权提交推送和服务器部署。基线为 d3464db，工作区干净；生产旧版 20261017T210828。证书配置按用户纠正移出本轮范围。

本轮修复四条实际路径：解包重写 mtime 导致相同内容失去缓存；响应仍动态 gzip-1；CS:APP 105 个溢出容器交错读写布局；发布仅 test/reload 成功而缺少内容核对。同时修复公开清单演进后旧版不能验证的回滚边界。

方案采用确定性 gzip-6 sidecar、持久的内容验证器登记、先读后写的局部脚本、事务内回环 TLS 内容 SHA 核对与只读健康检查 timer。HTML 继续 no-cache，原 URL、静态生产和数学内容不变。gzip/identity 在同一 URL 下共同保留不同内容的时间标识，含等大小表示的 ETag 边界。历史公开清单由管理员安装，不从上传队列采信。

文档影响已同步 TECH、Astro 维护、Ubuntu 运维、环境登记和 .env.example。没有公式、单位、题号或程序模型变更，不需要修改书级计算规则；14 页脚本变更依正常修订链登记，历史基线保留。方案可通过旧 release、旧 helper/snippet 和持久登记恢复，无新核心运行时。

状态：已完成。76 页本地阅读、两平台发布演练、正式 systemd 上线、源站与公网全量内容检查均已验证，Git 和生产身份分别记录于 T035/M035。离屏渲染原型仍属于实验，不在本次上线范围。

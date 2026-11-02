# P070 剩余修复与复核计划

1. 先保留两项环境诊断/入口失败、三项本地证据写入失败；P1沿用T069实际先失败再通过证据。
2. 明确local/full/build/release前置能力，增加独立check-local，保留完整门禁。
3. 延迟CS:APP程序执行依赖，修复pdfinfo本地化时区解码；对本地证据区分Windows原子替换与POSIX目录持久性。
4. 修复同类CLI及构建URL路径问题；嵌套CSP清单与逐页性能预算回归先失败再通过。
5. 执行能力/命令范围回归、Node全量、六书check-local、完整门禁和正式构建；按change-verification分开报告通过与阻塞。
6. 同步TECH、README、治理配置、环境与测试规范；记录最终文件摘要，不自动提交或部署。

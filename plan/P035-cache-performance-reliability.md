# P035 缓存与发布修复计划

日期：2026-10-20。关联 [I035](../issues/I035-cache-performance-reliability.md)、[P035](../plan/P035-cache-performance-reliability.md)、[T035](../test/T035-cache-performance-reliability.md)、[M035](../milestone/M035-cache-performance-reliability.md)。

1. 建立针对缓存同秒/等大小/回滚、压缩等价、旧清单与健康失败的独立反例，保留旧实现失败证据。
2. 发布内容先脱敏及精确 allowlist 检查，再生成 sidecar；归档、SHA 清单、CSP 和完整 DOM parity 一起验证。
3. 发布锁内导入已验证的历史 mtime、原子持久写入验证器登记，再设置候选时间；之后沿用 root 只读/fsync/原子切换。test/reload/health 均在事务中，恢复也执行内容核对。
4. CS:APP 横滚检测批量读取尺寸、只写实际变化；用不变的正文/MathML/SVG/代码/习题指纹和真实浏览器验证阅读行为。构建新增静态性能预算，浏览器独立报告 3 页 × 2 设备档 × 3 轮 × 初访/复访。
5. 执行登记检查、完整离线矩阵、本地及 Ubuntu 隔离 Nginx 故障演练。检查变更和秘密后提交推送，再按既有授权发布；保留旧 release 与 helper/snippet 恢复点，逐文件公网/源站验证分开记录。

经验应用范围：web-engineering-playbook E06（2026-09-22）的表示协商与缓存一致性，E39（2026-09-28）的实验条件和首访/复访分组，E43（2026-10-13）的压缩位置。这里是针对本项目的工程决策，效果以 T035 实测为依据。

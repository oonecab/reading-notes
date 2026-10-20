# M035 缓存与发布修复里程碑

日期：2026-10-20。关联 [I035](../issues/I035-cache-performance-reliability.md)、[P035](../plan/P035-cache-performance-reliability.md)、[T035](../test/T035-cache-performance-reliability.md)、[M035](../milestone/M035-cache-performance-reliability.md)。

已完成：失败反例、缓存/预压缩与恢复实现、14 页脚本修订及不变内容指纹、静态性能预算、完整程序检查、76 页离线矩阵和本地 24 项发布演练。恢复策略保留旧发布目录、可信旧清单及上线前 helper/snippet 备份。

Ubuntu 隔离 24 项演练和 72 次独立浏览器性能样本已完成，详见 T035。状态：completed_and_deployed。代码 e2ce917 已提交推送，从干净源构建的 20261020T112509 已经 systemd 发布成功。490 文件/188 压缩表示/15 入口/2 PDF Range 的源站与公网验证、线上实际阅读和健康 timer 首次运行全部通过；最终证据与后续验证器维护提交见 T035。

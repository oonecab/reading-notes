# P067 工具链兼容范围实施计划

1. 核对主分支与授权，建立codex/toolchain-range分支。
2. 放宽同主版本范围，保留锁文件与严格门禁；同步doctor、构建与发布实际版本。
3. 适配Windows命令入口，不改变Linux持久性语义。
4. 执行专项及登记检查，记录平台阻碍；同步技术事实。
5. 显式暂存任务文件，提交、快进合并main并推送。

范围与回滚见[I067](../issues/I067-toolchain-range.md)，证据见[T067](../test/T067-toolchain-range.md)。

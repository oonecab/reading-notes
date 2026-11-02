# P069 第一批修复计划

1. 保留已有审阅记录，在codex/windows-check-cli分支实现。
2. 先执行真实CLI回归：有效输入必须输出覆盖报告；隔离目录的损坏JSON必须非零退出。
3. 使用fileURLToPath规范化模块路径，再运行相同回归。
4. 执行pnpm test，区分新增回归与既有Windows fsync失败，更新证据。

本批之后再处理I068的P2；本批不提交、合并、推送或部署。

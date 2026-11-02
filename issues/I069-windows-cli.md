# I069 Windows 检查CLI静默空跑

承接[I068](I068-skill-config-review.md)的P1，用户授权逐步修复。第一批仅修复两个阅读契约CLI的入口路径比较，并增加真实子进程回归；不改检查规则和书籍内容。修复使用Node已有fileURLToPath，无新技术栈、服务或环境变量，回滚可撤销本批文件改动。

范围、验证与剩余问题见[T069](../test/T069-windows-cli.md)。P2环境能力诊断、检查分层及Windows目录同步仍待后续批次，不能标记完整项目已可运行。

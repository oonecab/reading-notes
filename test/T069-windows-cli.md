# T069 Windows CLI回归证据

日期：2026-11-02。基线6e25f11，工作分支codex/windows-check-cli；Node 24.22.1、pnpm 11.25.0、Python 3.12.1。使用change-verification方法。

## 独立预期与设计

RN-001/RN-002要求真实执行阅读检查；退出0本身不能替代覆盖报告。scripts/check-cli.test.mjs通过真实Node子进程执行两个正式入口；有效输入解析JSON并检查状态、错误清单与非空覆盖；错误输入仅写入tmp/cli-regressions下独立目录，损坏策略必须触发SyntaxError和非零退出。只清理自身创建目录，不修改正式内容或模拟检查函数。

## 先失败再通过

修改入口前运行同一测试：4项全部失败，分别因正常输入无输出、错误输入仍退出0。这是实际旧实现失败，不是缺少依赖或导入失败。日志tmp/i069-cli/before.log。

入口路径从URL pathname改用fileURLToPath后：4项全部通过、0跳过。阅读报告覆盖登记的69页，呈现报告包含书籍检查结果。日志tmp/i069-cli/after.log。

全量结果见下方追加记录。未重复完整构建及离线浏览器：该入口修复不解除T068已复现的termios/发布持久性环境阻碍。Linux/macOS本轮未实测，不把Windows证据推广到全部平台。

文档影响：更新TESTING中的真实CLI测试入口与TECH中的修复事实；没有数学/业务规则、技术栈、服务、端口或环境变量变化，不需修改相应配置。此前T068是历史审查快照，保留其发现，通过本记录关联修复状态。

## 全量复测

`pnpm test`：124项，121通过、3失败、0跳过。新增4项全部通过；剩余3项仍是scripts/browser-runtime.test.mjs中的Windows目录fsync EPERM，与T068的3项相同，未修改或跳过。日志tmp/i069-cli/full.log。git diff --check通过。本批P1修复完成；完整测试套件保持未通过状态。

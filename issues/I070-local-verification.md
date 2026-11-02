# I070 本地验证与平台能力修复

用户授权继续修复I068/I069剩余问题并按change-verification复核。当前分支codex/windows-check-cli，基线6e25f11及前批未提交修改；保留已有审阅记录。

实现包括按操作报告前置能力、独立check-local、CS:APP延迟导入POSIX程序回归、本地浏览器证据写入适配、另外三个CLI入口与构建路由规范化。完整check/quick及Linux生产持久性门禁保留。Windows本地证据不承诺目录掉电持久性；没有改变生产发布代码。

验证详见[T070](../test/T070-local-verification.md)。外部ego-browser与目标POSIX环境不属于已通过的运行事实。无提交、推送或生产授权操作。回滚为撤销本批文件修改；无数据迁移或不可逆选择，不需新增ADR。

2026-11-03 后续：本地配置修复与正式构建/浏览器验证已完成，最新结果见 [T071](../test/T071-final-build.md)；以上审阅时的失败与限制保留为历史事实。

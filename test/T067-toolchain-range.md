# T067 工具链范围：验证记录

用户授权：2026-11-02 同意调整版本范围、本地测试、合并 main 并推送；不含生产部署。

范围：Node >=24.21.0 <25、pnpm >=11.21.0 <12；保留 packageManager 基准和 frozen-lockfile。构建、doctor 与发布实际版本证据联动，Windows 使用解析后的 pnpm.cmd 与 python。不修改数学内容或 Linux 发布持久性测试。

验收：边界测试、依赖安装、登记检查和构建；缺失外部输入/平台依赖需如实记录，不能绕过门禁。回滚通过 revert 本次提交。

文档影响：TECH、治理配置、编写与部署说明同步；无服务、端口或新增环境变量变更。测试结果见下。

## 本地证据（2026-11-02）

- Node 24.22.1 / pnpm 11.25.0 / Python 3.12.1：doctor通过，锁文件安装成功且未改锁文件。
- 版本边界回归通过；Node全量最终120项：117通过、3失败，失败均为既有browser-runtime目录fsync在Windows返回EPERM。新增doctor/manifest一致性回归通过；工具链专项共2项通过。
- 阅读契约与呈现契约通过，直接导入checkAll验证（既有CLI的file URL比较在Windows不执行入口）；没有进行逐页浏览器验收。
- quick前三组通过，发布持久性测试因O_DIRECTORY/rsync失败。正式构建越过版本门禁并启动Python helpers，但CS:APP依赖termios/pty，Windows缺失，构建未完成。parity/offline/performance依赖完整构建，未达到执行前提。
- 临时日志仅存忽略目录tmp/i067-*；没有删除、跳过或弱化上述失败测试。Linux完整验证与正式包仍未完成，I067仅交付版本范围及命令入口调整，不宣称站点已在Windows完整运行。

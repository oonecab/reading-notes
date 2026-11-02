# T068 Skills 驱动的配置审阅与验证

日期：2026-11-02。被审阅提交：6e25f11d805d49f27e04ab1791bc1627e5963b0a。任务为安装技能并测试/审阅，不含修复、提交、推送或生产操作。

## 方法与安装

安装完整用户级包：web-engineering-playbook、risk-based-test-planning、testability-review、change-verification。来源提交分别为fd3b3d392a06948e869e2dc916b9111c4e45f8de、695d27917e057ab6f859f2f40ea51e7e568c7b8e。源文件与安装副本SHA-256逐项一致，许可证保留；Codex skills/list forceReload实查四项均scope=user、enabled=true、errors=[]。测试技能三包结构检查通过；经验库check通过74来源/74经验/6主题。仅在测试技能源码仓库的独立venv安装PyYAML 6.0.3用于校验。

应用testability-review的可控制/可观察/隔离检查及change-verification的证据状态规则。工程经验库采用E60（来源日期2026-10-20：兼容矩阵）和E05（2026-09-21：解释器可用不代表依赖兼容）的归纳建议；它们是审查方法，不是当前项目兼容性的证明。

## 风险与发现

### P1：Windows的两个正式CLI静默空跑

位置：tools/reader-contract/check.mjs:143、tools/check-presentation-contract.mjs:317。path.resolve得到Windows路径，而new URL(import.meta.url).pathname得到带前导斜杠的URL路径，两者不等，main分支没有执行。实测两个命令退出0且stdout为0字节；直接导入checkAll后才输出实际结果。影响：自动化可把未执行误当通过。最小修复建议：使用fileURLToPath统一路径；验收必须启动真实CLI、解析报告，并在隔离的错误夹具上验证非零退出，不能只测导出的函数。构建直接调用checkAll，因此不能将CLI空跑扩大解释为构建中的检查也被绕过。

### P2：环境诊断缺少按操作区分的能力报告

位置：tools/project.py:28-38。版本与可执行文件存在性检查通过后返回0，但没有检测检查/构建所需termios、目录同步语义、rsync和浏览器能力。实测doctor通过，同环境CS:APP检查因termios缺失失败，quick因O_DIRECTORY/rsync失败。建议按本地结构检查、完整程序验证、构建浏览器门禁、Linux发布分别报告ready/blocked及原因，不把同一工具清单当全流程准备完成。验收应在同一环境同时比较doctor报告和对应真实入口。

### P2：快速检查在进入书级检查前被发布平台依赖阻断

位置：tools/project.py:50，deploy/scripts/durability.py:9，scripts/browser-runtime.mjs:14，books/csapp/tools/part_two_regressions.py:8。quick按顺序执行Linux发布持久性测试且首错返回，Windows无法获得后续书级检查证据；Node全量的目录fsync也有3项失败。建议提供明确的本地结构检查入口和平台能力矩阵，完整发布门禁继续保留，不能跳过后仍标记完整check通过。CS:APP的Unix回归依赖可按真实使用边界延迟加载，使纯结构检查不必导入pty；实际POSIX程序仍需真实目标环境验证。

## 当前执行结果

Node 24.22.1、pnpm 11.25.0、Python 3.12.1；测试进程PATH显式选用同一Node，未改机器全局PATH。

| 检查 | 结果 | 解释 |
|---|---|---|
| doctor | pass（有限范围） | 仅现有诊断覆盖的版本/工具检查 |
| Node全量 | fail | 120项，117通过、3个目录fsync失败、0跳过；含2个工具链专项通过 |
| quick | fail | 前三组通过，发布持久性测试O_DIRECTORY/rsync失败 |
| CS:APP quick | blocked | import pty最终因termios缺失失败 |
| 阅读契约CLI | fail（未执行） | 退出0，但无报告，不计通过 |
| 呈现契约CLI | fail（未执行） | 退出0，但无报告，不计通过 |
| 直接调用阅读契约 | pass | 69页、errors=[] |
| 直接调用呈现契约 | pass | errors=[] |
| 完整构建/产物parity/性能/离线/逐页浏览器 | not-run | 本轮已独立复现构建必需CS:APP阻碍，未重复完整构建；既有失败记录见T067，不冒充本轮结果 |

原始日志与结构化结果位于忽略目录tmp/i068-skill-audit/。支持范围最低版本及其它平台未实测；不能把版本解析单元测试称为完整兼容矩阵。

## 交付边界

审查与技能安装完成，发现尚未修复。没有修改业务源码、数学规则、项目运行配置或部署状态。文档影响仅为本次审查证据，不需修改TECH或环境变量清单；不将审查建议写成已生效技术事实。

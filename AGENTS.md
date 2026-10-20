# AGENTS.md

<!-- project-governance:managed:start -->
本仓库是 **Reading Notes**：统一管理 Durrett 随机过程、Weiss 数据结构、CS:APP 系统、Carter 视觉群论与程士宏测度概率及 EOPL 地图与序言笔记，保留正式 HTML、可运行示例、来源与验证记录，共用阅读入口和静态发布流程。

这是 Codex、OpenCode 及兼容编码 Agent 的共享指令入口。详细规范只在下列权威文档中维护，不得在多个 Agent 文件中复制全文。

## 修改前必读

1. `TECH.md` — 当前技术事实、边界与技术栈变更索引
2. `docs/governance/WORKFLOW.md` — 变更生命周期、文档联动与完成门禁
3. `docs/governance/TESTING.md` — 测试和证据要求
4. `docs/governance/SECURITY.md` — 密钥、数据和外部系统红线
5. `docs/rules/README.md` — 业务与计算规则的权威文档规范
6. `docs/governance/CHANGE_CONTROL.md` — 审批、迁移和回滚门禁

## 不可绕过的红线

- 只处理任务范围内的内容，保留用户已有及无关改动。
- 严禁提交密钥、令牌、凭据、私钥、生产数据或其他敏感信息。
- 未经明确授权，不得执行破坏性操作、生产操作、数据库结构变更、部署或外部系统写入。
- 不得通过删除、跳过、弱化失败测试，或伪造测试结果来宣称任务完成。
- 不得只改代码而遗漏受影响的权威文档；完成前必须评估文档影响，即使无需更新也要在问题单或交付说明中写明理由。

## 强制联动规则

- 新增、移除、替换核心技术栈，或进行影响兼容性的主版本升级时，必须在同一变更中更新 `.project-governance.json` 与 `TECH.md`，并在 `TECH.md` 追加技术栈变更索引；难以回退时还必须新增 ADR。
- 修改公式、统计口径、舍入方式、精度、单位、币种、时间边界或其他业务/计算规则时，必须在同一变更中更新规则权威文档、受影响的 API/报表/用户说明、测试设计及可执行回归测试；代码、测试和文档必须表达同一规则。
- 环境变量、服务、端口或部署环境发生变化时，必须同步 `.project-governance.json`、`docs/environments.md` 及 `.env.example` 中的非秘密变量名。
- `.project-governance.json` 是命令、治理级别和 Agent 开关的机器可读事实来源；`TECH.md` 是当前技术事实来源。

## 完成条件

- 采用最小安全变更并完成相称的测试。
- 运行已登记的检查并如实记录证据；无法运行时必须说明原因和替代验证。
- 完成代码、测试、权威文档、问题单和变更记录的同步后，才可标记完成。

重要工作必须使用 `issues/`、`plan/`、`milestone/` 和 `test/`；难以回退的选择必须在 `docs/decisions/` 中新增决策记录。

已启用的 Agent 兼容范围：Codex, Claude Code, OpenCode。
<!-- project-governance:managed:end -->

## 项目专属补充

新增或修改书籍内容前读取 [规则职责索引](docs/rules/README.md)与 [RN-001 读书笔记共同标准](docs/reading-notes-standard.md)，再读取该书 `agent.md` 与 `notes/README.md`。新增书籍按[接入步骤](docs/adding-a-book.md)和[工作模板](docs/templates/reading-notes/README.md)执行，先完成原书清单、全书地图与样章验收，再按批次扩写。从根目录使用 `tools/project.py` 运行检查和构建，输出只放忽略目录。对话默认使用自然、连续的中文，先直接说明结果，再讲必要依据，避免重复总结。

各书原有说明中的“项目/仓库根目录”按子项目根目录解释；公共命令从 Reading Notes 主仓库根目录执行。

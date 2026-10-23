# 测试与验证规范

<!-- project-governance:managed:start -->
按风险覆盖正常、边界和失败行为。

## 已登记命令

### 环境准备

- `python3 tools/project.py doctor`
- `pnpm install --frozen-lockfile`

### 测试

- `python3 tools/project.py check`
- `pnpm test`
- `pnpm check:parity`
- `pnpm check:offline`
- `pnpm check:performance`
- `node tools/reader-contract/check.mjs`

### 静态检查

- `python3 tools/project.py check --quick`

### 格式检查

- 尚未登记。

### 构建

- `pnpm build`
- `python3 tools/project.py build`

## 业务与计算规则测试

规则变化必须以 `docs/rules/` 中的权威定义为依据，并按风险覆盖：

- 经确认的变更前与变更后示例；
- 零值、空值、负值、极值和非法输入；
- 精度、舍入方式、溢出和累计误差；
- 单位、币种及换算基准；
- 时区、自然日/工作日、月末/年末和生效时间边界；
- 重复执行、并发、幂等、异常恢复和历史数据兼容。

至少有一项回归测试能够在旧实现或错误实现上失败。文档示例应尽量复用测试夹具或可执行样例，防止示例与代码分叉。

## 证据红线

- 正常、边界和失败路径必须按风险覆盖。
- 行为变化必须有能够检测回归的测试。
- 未实际运行并检查结果时，不得声称检查通过。
- 已登记命令无法运行时，必须记录具体限制并采用最安全且有意义的替代验证。
- 严禁为了获得绿色结果而弱化、跳过或删除失败测试。
- 完成证据必须包含代码、测试与权威文档一致性的检查结果。

通用初始化器只能建立结构和门禁，无法理解任意业务语义；语义一致性最终必须由项目级契约测试、文档检查、CI 或人工评审证明。
<!-- project-governance:managed:end -->

## 项目专属质量门禁

具体命令、证据目录与验证边界见 [根 README](../../README.md)，本次迁移场景见 [T001](../../test/T001-project-merge.md)。构建检查与完整程序检查分别执行；发布前补充本地 HTTPS 和公网浏览器验收。

读书笔记的来源/内容、静态结构、程序/计算、真实阅读、本地集成和线上发布分层要求统一见 [RN-001](../reading-notes-standard.md)。逐章记录可使用[审阅模板](../templates/reading-notes/chapter-review.md.template)；未执行项保持待验收，变更绑定以实际读回和复测为依据。

I052 起，`node tools/reader-contract/check.mjs` 为逐页阅读契约门禁，`scripts/reader-contract.test.mjs` 验证错误输入能被拒绝。浏览器按登记的全部必需注解逐节检查，实际范围与人工观察记录按 [RN-001 §6.1](../reading-notes-standard.md) 保存。

逐页浏览器验收另在 390px 将每页正文中的全部原生折叠块展开，分别检查启用和关闭页面脚本时的整页宽度；该检查与首末题的实际点击、代码开合和人工截图阅读分别记录。复用既有证据须同时满足 HTML 与截图散列一致、该视图必需的检查字段齐全；旧记录缺少新增检查项时应重跑。

章节图节点与其他章节入口分别按 [RN-002 §2.3](../reading-presentation-standard.md) 验证预期目标和最终可见标题；静态清单、实际逐节点操作、无脚本及键盘结果单独记录。旧浏览器视图缺少新增节点检查字段时重跑，不能因 HTML 未变而沿用。

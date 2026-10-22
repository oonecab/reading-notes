# 里程碑：阅读呈现与检查契约落地

- 状态：`completed_locally`
- 关联问题单：[I053](../issues/I053-reading-presentation.md)
- 计划：[P053](../plan/P053-reading-presentation.md)
- 测试：[T053](../test/T053-reading-presentation.md)

## 完成定义

- RN-002 与 `docs/reader-presentation.json` 成为六书阅读呈现、导航、章首、索引位置和题干语言策略的权威来源。
- 新增 `tools/check-presentation-contract.mjs`，覆盖全部 60 页，并具备 7 个可失败反例；接入 `tools/project.py check` 与构建门禁。
- EOPL 序言直达第一章；随机过程/CS:APP 章首索引后置；EOPL 68 道题的完整英文原题移出阅读页并归档。
- 全站检查、Node 测试、构建 parity、浏览器阅读路径与无脚本抽检完成；结论按 RN-002 三层记录，不把结构通过扩大为内容或生产通过。

## 证据入口

- 契约报告：`tmp/presentation-migration/`、`docs/reader-presentation-review.json`
- 自动测试：`scripts/presentation-contract.test.mjs`、`scripts/reader-contract.test.mjs`
- 浏览器：本地 `dist/` 与 390/1440 截图（T053 记录）
- 最终结果：source/dist 契约 60/60、全站 check 0、build 0、Node tests 101/101、parity 0 差异、浏览器六书路径 4–14 步全部可走。

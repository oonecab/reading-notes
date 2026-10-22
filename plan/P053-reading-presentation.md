# 实施计划：阅读呈现与检查规范化

- 状态：`completed_locally`
- 关联问题单：[I053](../issues/I053-reading-presentation.md)
- 目标里程碑：[M053](../milestone/M053-reading-presentation.md)
- 负责人：Lead + eopl-english + index-placement

## 目标与非目标

目标：把六书阅读页的页面族、阅读路径、章首顺序、索引位置、题干语言策略与检查方法写成可执行的 RN-002 + `docs/reader-presentation.json` + `tools/check-presentation-contract.mjs`，并修掉 EOPL 导航、EOPL 逐题英文原题、随机过程/CS:APP 章首索引三类可见问题，使六书 60 页通过同一契约。

非目标：不改教材数学/答案/程序；不新增/删除章节；不改发布流程与服务器；不把内容正确性、屏幕阅读器或未执行的生产验收声称为已通过。

## 依赖与风险

依赖：六书 60 页现有受控 HTML、`books/catalog.json`、`docs/reader-contract.json`、RN-001 v1.10、Node 24.21.0/parse5、各书检查器。风险：批量导航改写、索引移动破坏锚点、删除英文影响 EOPL 检查器与题干审阅哈希。用逐页 diff、字节哈希、负向测试与全站检查控制。

## 实施步骤

1. `[done]` 建立 RN-002、`docs/reader-presentation.json`、契约检查器与 7 个负向测试。
2. `[done]` 统一六书 60 页 `chapter-nav` 与侧栏标签；序言/章末/末页直接入口。
3. `[done]` EOPL 移除 69 个完整英文原题块并归档，更新 EOPL 检查器与 13 个负例。
4. `[done]` 随机过程 7 页、CS:APP 14 页章首索引移到页脚前，侧栏索引后置。
5. `[done]` 更新 `docs/reader-contract.json`、`docs/reader-question-review.json`、RN-001 v1.11、RN-002 v1.0.1 与入口文档。
6. `[done]` 全站 check / Node tests / build / 浏览器阅读路径与无脚本验证。
7. `[done]` 记录 T053/M053、更新 TECH.md、保存证据。

## 文档同步计划

| 文档/记录 | 同步内容 | 负责人 | 完成时点 | 一致性验证 |
|---|---|---|---|---|
| `docs/reading-presentation-standard.md` | RN-002 全文 | Lead | 已完成 | 检查器与负向测试 |
| `docs/reader-presentation.json` | 60 页顺序/标签 | Lead | 已完成 | `check-presentation-contract` |
| `docs/reading-notes-standard.md` | v1.11，英文原题条款移除 | Lead | 已完成 | 与 RN-002 交叉引用 |
| `AGENTS.md`、`docs/README.md`、`.project-governance.json` | 新入口与命令 | Lead | 已完成 | 文档链接检查 |
| 各书 `agent.md`/`notes/README.md` | 书级索引/英文/导航说明 | 各修订员 | 本批 | 书级检查器 |
| `TECH.md`、T053/M053 | 实施与证据 | Lead | 验证后 | 命令与报告 |

## 测试与验证计划

- 变更前失败证明：旧页面上 `check-presentation-contract` 对 EOPL 序言、随机过程章首、EOPL 英文原题均失败。
- 自动化验证：`node tools/check-presentation-contract.mjs`、`node --test scripts/presentation-contract.test.mjs`、`python3 tools/project.py check`、`pnpm test`、`pnpm check:parity`、build。
- 文档一致性验证：RN-002 的每条规则对应检查器断言与负向测试；`docs/reader-presentation.json` 是页面顺序的唯一登记。
- 其他评审证据：浏览器逐书走 overview→preface→ch1→…→末页，桌面/390px/无脚本；实际打开截图读回。

## 迁移、发布与回滚

- 迁移顺序：契约/检查器 → 导航 → EOPL 英文/索引 → 登记与审阅哈希 → 全站验证。
- 回滚触发条件：页序/导航错、数学或代码字节变化、契约检查无法在合理范围内通过。
- 回滚步骤：Git 恢复六书页面、检查器、登记和文档；保留归档文件。
- 回滚验证：`git diff` 与 `python3 tools/project.py check` 恢复基线结果。

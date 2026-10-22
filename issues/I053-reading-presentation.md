# 问题单：阅读呈现、导航与检查规范（RN-002）

- 状态：`completed_locally`
- 创建时间：`2026-10-22 01:05 +08:00`
- 负责人：Lead + eopl-english + index-placement
- 变更类型：`user-visible`
- 关联计划：[P053](../plan/P053-reading-presentation.md)
- 关联测试设计：[T053](../test/T053-reading-presentation.md)
- 关联决策记录：`none`

## 已观察事实

- 用户指出六书阅读页仍存在阅读路径与展示规则不一致：EOPL 序言页脚“第 1 章在全书中的位置”指向全书地图段落而非第一章；随机过程章首放整章定义/定理长索引，其他书没有；EOPL 每题保留完整英文原题，中文题干与英文原题重复；此前“统一验收通过”的表述超出实际检查范围。
- 现有规则分散：RN-001 v1.10 要求每题英文原题；`docs/reader-contract.json` 只登记内容义务；`tools/reader-contract/check.mjs` 据此强制英文原题；`tools/reading-presentation/check.mjs` 只查字体/代码/图；各书检查器各自放行导航与索引位置，没有跨书契约。
- 六书 60 个阅读页的章节导航标签、顺序、页脚入口各不相同；随机过程 7 页、CS:APP 14 页有章首索引；EOPL 68 道题有完整英文原题。

## 影响与范围

影响全部六书 60 个正式阅读页的阅读路径、章首信息顺序、索引位置与题干呈现；不改变教材数学内容、原题号、答案、程序、来源页、发布路径或技术栈。首页/书架和 PDF 资源不在本次改动范围。生产发布需单独授权，本单只做本地修改与验证。

## 文档影响评估

- 文档同步结论：`required`
- 受影响的权威文档：[RN-002](../docs/reading-presentation-standard.md)（新增）、[RN-001](../docs/reading-notes-standard.md)（v1.11）、`docs/reader-presentation.json`（新增）、`docs/reader-contract.json`、`AGENTS.md`、`docs/README.md`、`.project-governance.json`、`TECH.md`、各书 `agent.md`/`notes/README.md`。
- 需要同步的内容：页面族、唯一阅读路径、章首/索引位置、题干语言策略、三层检查与结论写法；EOPL 与随机过程/CS:APP 的书级说明。
- 无需更新理由：`not-applicable`（规则变化必须同步）。

### 技术栈变更

`none`。新增 Node 检查器与 JSON 登记，沿用 Node 24.21.0/parse5，无运行时依赖。

### 业务/计算规则变更

`none`。不改变公式、题解、程序行为；只改变题面呈现与页面编排。

## 验收条件

- 六书 60 页全部通过 `node tools/check-presentation-contract.mjs`：导航直接、章首无索引、索引后置、无完整英文原题、侧栏统一、页面骨架一致。
- 反向测试覆盖地图锚点冒充下一章、序言缺下一页、章首索引、英文原题、侧栏标签/末页伪造下一章。
- EOPL 68 道题与 1 段共同题设的 69 个完整英文块归档到维护文件，阅读页无重复英文；中文题干、答案、数学/代码字节不变。
- 随机过程/CS:APP 的章首索引移到页脚前，锚点与侧栏可解析；正文、题干、数学/代码字节不变。
- `python3 tools/project.py check`、`pnpm test`、build、浏览器阅读路径验收与无脚本检查通过；结论按 RN-002 三层分别记录。

## 风险与回滚

- 风险：批量导航重写可能丢失原有“程序说明/序言”入口；索引移动可能破坏侧栏顺序；删除英文可能影响书级检查器/审阅哈希。
- 防护：导航只替换 `p.chapter-nav` 与侧栏标签；索引只移动块，不新增 section；英文归档并由 EOPL 检查器改查归档；对数学/代码/题干做字节哈希对比；逐页 diff 审阅。
- 回滚：Git 恢复六书页面、检查器、登记与文档；归档文件保留，不影响回滚。生产未发布，无需版本切换。

## 活动记录

- `2026-10-22 01:05 +08:00` — 建立 RN-002、呈现契约与检查器；完成六书 60 页导航统一（直接下一页、页脚入口、侧栏“目录”）；派发 EOPL 英文原题移除与随机过程/CS:APP 索引后置。
- `2026-10-22 01:45 +08:00` — 完成：EOPL 69 个完整英文原题块移除并归档；随机过程 7 页、CS:APP 14 页索引后置；六书侧栏统一“全书地图/序言”；构建注入的“笔记首页”登记为壳层规则并增加 dist 导航检查。`node tools/check-presentation-contract.mjs` 与 `--dist` 均 60/60 通过；`python3 tools/project.py check`、`pnpm build`、`pnpm test`、`pnpm check:parity`、`pnpm check:performance` 通过；浏览器六书路径与 390px/无脚本抽检通过。未执行提交、推送或生产发布。

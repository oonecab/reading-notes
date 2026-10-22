# 测试设计：六书阅读呈现、导航与题干语言契约

- 关联问题单：[I053](../issues/I053-reading-presentation.md)
- 关联计划：[P053](../plan/P053-reading-presentation.md)
- 目标里程碑：[M053](../milestone/M053-reading-presentation.md)
- 规则权威文档：[RN-002](../docs/reading-presentation-standard.md)、[RN-001](../docs/reading-notes-standard.md) v1.11
- 规则版本/生效时间：RN-002 v1.0 / 2026-10-22；RN-001 v1.11 / 2026-10-22

## 前置条件与夹具

- 受控源：`src/content/books/` 六书 60 个 HTML；机器登记 `docs/reader-presentation.json`；内容义务 `docs/reader-contract.json`。
- 反例夹具：`scripts/presentation-contract.test.mjs` 的合成页面，不读写真实书籍。
- 浏览器：本地构建 `dist/` 与 `python3 -m http.server`；只访问 127.0.0.1，不使用外部服务。
- 不涉及秘密、生产数据或个人数据。

## 规则与边界覆盖

| 维度 | 适用规则与预期 | 场景 ID/自动化测试 |
|---|---|---|
| 导航目标 | 章节链接必须指向章节文件，不得用 `book_overview.html#chapter-N` 冒充下一章 | `presentation-contract.test.mjs` “chapter navigation must not point at the map section” |
| 序言/末页 | 序言必须直达第一章；最后一页不得伪造下一章 | “preface must link directly to the first chapter”、“sidebar title and last-page navigation” |
| 章首顺序 | header 与第一个 section 之间最多一个导语段落，不得有索引/列表/折叠 | “chapter opening rejects indexes and lists” |
| 索引位置 | 定义/定理/摘录索引在最后 section 之后；习题索引在习题区、首题之前 | 同上、`check-presentation-contract` 全量 |
| 题干语言 | 完整英文原题禁止；短摘录 ≤2 句/400 字且带 `data-excerpt-reason` | “full English original is prohibited”、“short original excerpt needs a bounded reason” |
| 页面骨架 | `body.rn-components`、`main#top`、页头/页脚、侧栏标题“目录” | “sidebar title and last-page navigation”、全量检查 |
| 全站登记 | 60 页与 `docs/reader-presentation.json` 一一对应，缺失/多页失败 | `checkAll` 计数断言 |

## 场景

### TD-001 — 契约通过

- Given：六书受控页面与登记完整。
- When：`node tools/check-presentation-contract.mjs`。
- Then：status=`passed`，60 页，0 错误。
- 自动化测试：`tools/check-presentation-contract.mjs`。
- 旧实现回归证明：修改前 EOPL 序言、随机过程 7 页、CS:APP 14 页、EOPL 68 题英文原题均失败。

### TD-002 — 导航/章首/索引反例

- Given：合成页面。
- When：`node --test scripts/presentation-contract.test.mjs`。
- Then：7 个反例全部被拒绝。
- 旧实现回归证明：旧检查器没有跨书导航/索引位置规则，反例可通过。

### TD-003 — EOPL 英文原题去除与归档

- Given：EOPL 序言与第 1、2 章。
- When：页面移除 `details.original-question`，英文写入 `books/eopl/notes/original_questions.json`；运行 `python3 books/eopl/tools/check_notes.py`。
- Then：68 题中文题干、答案、来源保留；归档 69 条（含 1 段共同题设）；页面 0 个 `original-question`；检查器通过。
- 自动化测试：`books/eopl/tools/check_notes.py`、`books/eopl/tools/test_checker.py`。

### TD-004 — 随机过程/CS:APP 索引后置

- Given：随机过程 7 页、CS:APP 14 页章首索引。
- When：索引块移到页脚前，侧栏索引入口后置；运行书级检查器与契约检查。
- Then：索引 id/目标不变；章首不再有索引；丛书检查通过；数学/代码元素集合保持一致（移动导致顺序变化，数量与内容集合不变）。
- 自动化测试：`books/stochastic/tools/check_notes.py`、`books/csapp/tools/check_notes.py`、`check-presentation-contract`。

### TD-005 — 全站回归

- Given：修改后的受控页面。
- When：`python3 tools/project.py check`、`pnpm test`、`pnpm check:parity`、构建、浏览器逐书路径。
- Then：全部通过；数学/代码/题干字节保全；60 页导航实际可走；390px 无整页溢出。
- 旧实现回归证明：修改前契约检查失败（序言、章首索引、英文原题）。

## 文档一致性证据

- RN-002 每条规则对应 `tools/check-presentation-contract.mjs` 的断言与 7 个负例。
- `docs/reader-presentation.json` 的 60 页与 `books/catalog.json`、实际文件一致。
- RN-001 v1.11 与 EOPL `agent.md`/`notes/README.md` 已删除“每题英文原题”要求，改为 RN-002 §5。
- `docs/reader-contract.json` 的 EOPL `chinese_translation_required` 改为 false；`docs/reader-question-review.json` 仅更新 EOPL 页面散列，范围是移除完整英文与补充中文共同题设。

## 退出条件

- 契约检查 60/60、反例 7/7、Node 测试全过、书级检查全过、构建 parity 0。
- 浏览器逐书 overview→preface→ch1→…→末页可走，桌面/390px/无 JS 各抽检；结论按 RN-002 分层写明未覆盖项。

## 最终执行记录（2026-10-22）

| 检查 | 命令 | 结果 |
|---|---|---|
| 源契约 | `node tools/check-presentation-contract.mjs` | 60/60 页，0 错误 |
| 构建产物 | `node tools/check-presentation-contract.mjs --dist` | 60/60 页，0 错误；两组 `chapter-nav` 均含声明的“笔记首页”，侧栏“全书地图/序言”标签一致 |
| 反向测试 | `node --test scripts/presentation-contract.test.mjs` | 7/7 通过 |
| 阅读契约 | `node --test scripts/reader-contract.test.mjs` | 16/16 通过 |
| 全站检查 | `python3 tools/project.py check` | 退出 0；25 项检查含六书 checker、reader/presentation contract、astro records |
| Node 测试 | `pnpm test` | 101/101 通过 |
| 构建 | `pnpm build` | 60 阅读页、82 HTML、524 文件，CSP 通过 |
| parity | `pnpm check:parity` | 60 页 0 差异 |
| 性能预算 | `pnpm check:performance` | 82 页通过 |
| EOPL | `check_notes.py` / `test_checker.py` | 0 / 0；归档 69 条，Racket 6269 assertions |
| 随机过程 | `check_notes.py` / `check_review_records.py` | 0 / 0；235 current bindings |
| CS:APP | `check_notes.py --run-dir tmp/csapp-recheck` | 0 |
| VGT / Weiss / measure | 各自 `check_notes.py` | 0 / 0 / 0 |

浏览器（本地 `dist`，1440 与 390px，实际点击）：
- stochastic 9 步、weiss 13 步、csapp 14 步、visual-group-theory 12 步、measure-probability 8 步、eopl 4 步，均从 overview 走到末页；每步 URL 与目标文件一致。
- EOPL 序言页脚“第 1 章 · 归纳数据与递归程序 →”实际点击进入 `chapter01_inductive_data.html`，不再指向 `book_overview.html#chapter-1`。
- 随机过程第 1 章、CS:APP 第 7 章打开时 header 与第一个 section 之间无索引；随机过程索引在页脚前且侧栏最后一项为“定义与定理”。
- 390px `scrollWidth=375 <= 390`；无脚本 EOPL 序言 h1、53 个 MathML 与 footer 导航可见。
- 截图：`tmp/presentation-migration/shots/`（EOPL 序言页脚、EOPL 第 1 章开头、随机过程索引末尾、CS:APP 第 7 章开头、390px、无脚本）。

未覆盖：屏幕阅读器、Firefox/Safari、线上发布；内容抽查只覆盖 EOPL 序言/第 1 章、随机过程第 1 章、CS:APP 第 7 章，不能外推为全部题目重新审阅。CS:APP notes 级旧 `page_sha256` 字段未全部重绑，当前权威绑定是 `src/content-revisions.json`、`docs/reader-contract-review.json` 与各书 checker 实际读取的记录。

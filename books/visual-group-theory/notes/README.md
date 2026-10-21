# 页面与来源

正式入口为 [全书地图](book_overview.html)。本书原书页序的正文偏移为 +15，罗马前置页另列；具体身份和全书目录以 [source_manifest.json](source_manifest.json) 为准。

| 页面 | 原书位置 | 本批内容 |
|---|---|---|
| [全书地图](book_overview.html) | 目录 xi—xiii / PDF 12—14；Overview 1—2 / PDF 16—17；各章结构端点 | 十章路线、批次、概念索引、来源与程序入口 |
| [序言导读](preface.html) | ix / PDF 10；Overview 1—2 / PDF 16—17 | 作者目标、图像读法、有限群与阅读依赖 |
| [第 1 章](chapter01_what_is_a_group.html) | 3—9 / PDF 18—24；印刷 10 / PDF 25 为空白 | 1.1—1.5、14 题全部小问、9 个编号陈述 |
| [第 2 章](chapter02_what_do_groups_look_like.html) | 11—24 / PDF 26—39 | 2.1—2.6、19 题全部小问、正多边形 BFS |
| [第 3 章](chapter03_why_study_groups.html) | 25—40 / PDF 40—55 | 3.1—3.4、16 题全部小问、Definition 3.1、饰带坐标程序 |
| [第 4 章](chapter04_algebra_at_last.html) | 41—62 / PDF 56—77 | 4.1—4.5、33 题全部小问、Definitions 4.1—4.2、完整表与公理检查 |
| [第 5 章](chapter05_five_families.html) | 63—96 / PDF 78—111 | 44 题全部小问；五类群、置换与 Cayley 定理 |
| [第 6 章](chapter06_subgroups.html) | 97—116 / PDF 112—131 | 31 题全部小问；子群、陪集与 Lagrange 定理 |
| [第 7 章](chapter07_products_and_quotients.html) | 117—156 / PDF 132—171 | 37 题全部小问；直积、商群、正规化子与共轭 |
| [第 8 章](chapter08_homomorphisms.html) | 157—192 / PDF 172—207 | 50 题全部小问；同态、核像与有限阿贝尔分类 |
| [第 9 章](chapter09_sylow_theory.html) | 193—220 / PDF 208—235 | 28 题全部小问；作用、Sylow 三定理、阶 12 分类 |
| [第 10 章](chapter10_galois_theory.html) | 221—260 / PDF 236—275 | 30 题全部小问；域、自同构、Galois 对应、根式可解性 |

原 PDF 的正式副本为 `../assets/source.pdf`；来源标签保留印刷页与 PDF 页序，直接链接对应 PDF 页，身份由根 `docs/reader-sources.json` 固定。源码维护于 `../code/`；执行 `python3 books/visual-group-theory/tools/sync_code.py --write` 同步 HTML 阅读副本。图表、正文与数学陈述在 `src/content/books/visual-group-theory/` 的受控 HTML 维护，本目录是独立检查用兼容镜像。维护与同步见 [Astro 说明](../../../docs/astro-authoring.md)。

样式和导航复用 `books/stochastic/notes/preface.html` 的纸色、绿色、17px/1.9、860px 主栏、240px 左目录和 280px 阅读注解栏；保留 1100/1440 断点和窄屏局部横滚。编号项有独立锚点；习题使用 `details.exercise`、`div.exercise-question`、`div.answer`；来源摘录和中文解释分别标明。

十章的完整 Python / C11 阅读副本均使用 `details.code-details`，摘要标明语言与程序用途，默认收起；点击或键盘可开合，关闭脚本仍可使用。运行命令和程序解释保留在控件附近，代码 ID、下载和维护源同步不变。共同规范及长片段的处理见 [RN-001 v1.7](../../../docs/reading-notes-standard.md)。

完整编号提取保存在 [source_inventory.json](source_inventory.json)，读回范围覆盖全部十章。当前习题清单为 [exercise_manifest.json](exercise_manifest.json)，引文为 [source_excerpts.json](source_excerpts.json)，首批状态在 [review/chapter01.md](../review/chapter01.md) 及 T021；第 2—4 章证据在 [review/chapters02-04.md](../review/chapters02-04.md) 及 T022。结构、运行、内容和实际阅读分别记录。

前四章验收保留在历史记录；第 5—8 章验收见 [chapters05-08](../review/chapters05-08.md)。第 2—4 章原图与反例输入见 [algebra_inputs.json](algebra_inputs.json)；第 5—8 章题面小问、置换、矩阵和商图输入见 [structures_inputs.json](structures_inputs.json)。当前文件绑定为 [review/validation.json](../review/validation.json)，最终包证据为 [review/release.json](../review/release.json)，前三批历史绑定保留于 review/history/。

第 9—10 章原图、子问与精确多项式输入见 [sylow_galois_inputs.json](sylow_galois_inputs.json)，本批证据见 [chapters09-10](../review/chapters09-10.md)，附录校注及证明边界见正式章节。

全书一致性修订见 [I026](../../../issues/I026-visual-group-theory-polish.md) / [T026](../../../test/T026-visual-group-theory-polish.md)。十章地图列出章节主题、页码与习题数量；第 2—4 章增加 15 组阅读注解，宽屏随章节显示，窄屏与无 JS 阅读保留正文中的原生折叠块。6.5 的六张表、9.28 和 10.26 的证明步骤及 4.1、6.4 的小问均有稳定锚点。

关键行内公式使用静态语义 MathML：356 处、140 种表达式，与原有 31 个显示公式并存。全部 387 个 MathML 均有一致的 aria-label 与 text/plain annotation；31 个显示公式保留原呈现树，文本回退对复合指数及分母明确加括号。上下标、逆元、根式、分式及运算符各使用相应结构，保留原记号的 annotation 与可访问名称；公式不能只包进 mtext。关键语义回归在 `../tools/check_reading.py`，数学条件仍由正式正文说明。程序文本、英文引语与 SVG 的文字标签按各自语境保留。

19 处英文节选在引文前明确标出步骤、条件或句子范围；完整中文陈述紧随其后。Definition 7.5 的步骤 2 位于印刷 133 / PDF 148，起始定义位于前一页，两个定位分别记录。七条跨行交叉引用在 source_inventory.json 中记录 duplicate/reference、具体上下文与正式项所在页。`inventory_source.py` 只负责独立枚举，重新提取的 pending 不代表否定人工复核；更新正式清单时须保留或重新完成审阅元数据。

完整行内/显示公式或含公式段落的复制会将 `annotation` 原记号写入纯文本剪贴板，同时保留富文本的 MathML。选中部分公式时沿用浏览器行为，避免把局部选取替换成整式；关闭 JS 时仍保留静态数学结构，纯文本序列化取决于浏览器。复制增强仅处理用户触发的 copy 事件，不读取系统剪贴板。

本轮内容、来源与实际阅读结论见 [一致性修订审阅](../review/polish.md)，上一批验收绑定已保留于 review/history/batch04-*。

页面外提取公式时，可读取 `math.getAttribute("aria-label")` 或 `math.querySelector('annotation[encoding="text/plain"]').textContent`，两者给出同一连续记号，不依赖页面 JavaScript。原生 `Selection.toString()` 的逐节点换行取决于浏览器；复制增强不改写这一原生接口。显示公式回退与复制追加验收见 [审阅记录](../review/polish.md)。

2026-10-20 起，四类教学组件统一遵循 [RN-001 v1.1](../../../docs/reading-notes-standard.md)；共享维护源为 `src/styles/reading-components.css`。陈述保持可见，证明默认展开并可折叠，习题默认收起，题干、解答与来源共用排版。具体覆盖与本轮内容修正见 [I040](../../../issues/I040-unified-reading-components.md)，原数学审阅和历史执行证据保留。

本书的当前阅读契约以 RN-001 v1.10 为准：完整中文题干和来源、逐节注解、共同版心、代码等宽与原生折叠、命名明确的索引、直达登记 PDF 的原文入口。逐页义务在根目录 `docs/reader-contract.json`，原书发布身份在 `docs/reader-sources.json`；历史批次记录保留当时的范围，当前复查执行 `python3 tools/project.py check` 及完整浏览器矩阵。

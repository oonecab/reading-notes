# 随机过程读书笔记的维护约定

原始资料是 Richard Durrett, Essentials of Stochastic Processes, Third Edition (2016) 的本地 PDF。版本、SHA-256、章节范围和全部习题起始页见 notes/source_manifest.json。PDF 共 282 页，省略印刷空白页 146、268；引用同时列印刷页与真实 PDF 页序。

## 内容与入口

- notes/book_overview.html 为统一入口；序言、六章、概率论复习附录各一 HTML，共九页，文件名及章次以 notes/README.md 为准。
- 序言保留四段英文原文、逐段中文译文与阅读注解。各章及附录的“定义与定理”索引按 [RN-002](../../docs/reading-presentation-standard.md) §4 放在本章正文与习题之后、页脚之前，侧栏链接排在所有小节之后，不新增 section；索引按原书编号链接到相应小节的正式陈述，`#statement-index` 的 id、summary 与默认折叠状态保持不变，跨页锚点仍可解析。
- 原书全部115条编号定理及引理、两条编号定义须保持覆盖；中文陈述集中写全条件、结论及边界，附英文原文、推导要点、原书页码和详细推导入口。其余基础定义与未编号公式标明性质，概率三公理集中在附录A.1，各章引用。英文摘录与中文解释分开，原书笔误在校注中说明，编号按原书保留。
- 保持原书节次与题号，解释机制、条件、推导与例子。六章全部 236 道习题保留中文题干、全部小问和可核对解答。
- 每题用 details.exercise，题干在 div.exercise-question，解答在 div.answer；原题条件与题干校注分别写清。矛盾不能静默改成另一道题。
- 解答用 ol.solution-steps 展开实际推导，每题至少三步，并逐项回答所有小问。每一步给出本题的条件、方程、运算或论证；数值题写出代入与单位，矩阵题写完整系数、消元和代回，证明题说明可积性及极限交换依据，期权题列终点路径和各内部节点的继续价值、复制持仓与行权决定。
- 解答标题统一为“解答”。正文示例在相应原书小节给出模型、方程、计算及结果验算；公式和定理写明适用条件、关键推导及极限依据。正文示例的来源和推导位置见 notes/readability_review.json。
- 可读文字、公式、数表和代码数值字面量的小数统一保留前导零，例如 0.70、0.05、0.5；C/Python 的格式字符串和词法正则按程序语义保留。
- 原书算术、术语或边界差异回到 PDF 页面核实后说明；一般定理保留非周期、正再生、可积性、停时和模型假设。

## 排版与代码

- 统一纸色、绿色强调、17px 正文、1.9 行高、860px 正文最大宽度。宽屏左侧 240px 目录；窄屏原生折叠目录；保留跳到正文、当前节标记、上下章与全书地图。
- 每页完整 HTML 可离线打开，CSS、导航 JS、静态 MathML、SVG、代码阅读副本和图数据均内嵌。复杂公式、宽表和代码局部滚动，整页不溢出。
- 每个原有小节在 details.reading-notes 中保存两条阅读注解，包含模型理解、条件解释、额外推导或验算依据。1440px 及以上显示右侧 280px 注解栏，随正文当前小节更新；较窄页面将同一组注解放在对应小节末尾，可折叠阅读。关闭 JS 时使用原生小节注解，保留内容入口。正文中的完整证明、示例与习题解答继续留在原位置。
- 具体算法提供完整 C11/Python 3 代码对，相同输入、算法、边界及输出。纯证明无需附空程序。
- 程序输入说明与实现一致，明确整数格式、字段数、矩阵及边界条件、有限数值范围和非零错误退出；双精度求解的病态阈值应在使用说明中写清。
- code/ 下的六个章节目录是程序维护入口，共七组十四份 C/Python 源文件；登记及页面对应关系见 code/programs.json。修改源码后运行 python3 tools/sync_code.py --write，同步 HTML 内的阅读副本。各组网页附源文件下载链接；代码同步检查与完整验证都要求源码和页面逐字一致。图数据仍在 HTML 内维护；tmp/notes-check 中的提取件用于检查。
- 仿真写明种子、重复、参数与误差；图必须采用可复核记录，理论、解析、采样与数值递推各自注明。

## 验证

运行 python3 tools/check_notes.py，检查链接、锚点、九页结构、序言原文段落、编号定理覆盖、概率公理、题号顺序、详细解答、解答标题、小数前导零、HTML 层次、公式转换、代码对、源码同步、下载链接、PDF 页序与源文件哈希，严格 C11 编译、Python 执行、ASan/UBSan、独立数值基准、非法输入和语言一致性。数值程序检查与正文、题干、纯数学证明的原书核对分别记录在 notes/validation.json、notes/review_manifest.json、notes/readability_review.json 和 notes/statements_review.json。纯内容修改后，若全部程序与数值基准的哈希保持一致，可保留此前运行证据并注明检查点及本次结构、浏览器检查范围。

每次改动最终页面后检查受影响页面的宽屏左目录、小屏折叠、习题深链接及自动展开、公式/表格/代码局部滚动、章间链接与截图。静态/程序检查与浏览器验收分别记录。

tmp 中保留本次提取、视觉核对与编写中间件。正文与图数据编辑 `src/content/books/stochastic/` 的受控 HTML，`notes/*.html` 保留为独立检查用兼容镜像，程序编辑 code/ 源文件并同步；检查脚本和数值基准随实质计算变更更新。

## 静态发布

网页的原书链接统一指向 assets/essentials-of-stochastic-processes.pdf，其字节和原始 PDF 相同，保留原书文件用于来源核对。PDF 页码链接使用真实页序 #page=N，代码和 PDF 都使用相对路径。

运行 python3 deploy/build_release.py 生成独立版本包，包含 index.html、notes/、code/、assets/。Nginx 文档根目录指向这一层，按 deploy/README.md 进行版本校验、原子切换和回滚；服务器配置不执行 C/Python 示例。代码抽离与 HTTP 检查见 notes/code_deployment_review.json，版本包验收保存在 deploy/reports/。

## 本次复查后的验证约定

修改内容后先对照原书核实，再运行 `python3 tools/content_integrity.py --record` 记录审阅基线；不得用自动更新基线绕过变更审阅。`tools/content_integrity.py --source-pages` 检查编号及起始页，不能当作题干或证明正确性的替代。独立基准生成器在 tools/generate_cases.py；tools/check_content_regressions.py 保留内容错误的确切复现，tools/test_tooling.py 保留变异、错误退出与资源扫描的回归，tools/check_simulation_seeds.py 检查额外种子。

索引按 RN-002 后置后，页面只发生整块元素移动，但页面哈希会变化。重绑时只更新审阅记录中的当前文件绑定与 `current_representation_sha256`，`files` 之外的既有哈希、历史截图哈希、审阅结论和批次范围保持原样；逐项原值→当前值记录在 notes/index_rebinding_review.json，检查入口为 `python3 tools/check_review_records.py`。

完整程序检查采用 `-ffp-contract=off`，区分输入失败2、数值失败3、资源失败4和信号崩溃。当前环境的C／Python数值程序输出逐字一致，数值另与独立基准比较。原始执行时间与记录整理时间分开；更新复查JSON时保留历史检查点，当前SHA与当前浏览器／运行记录对应。发布元数据只能保存相对路径。

Astro 维护、镜像同步与冻结基线规则见 [构建维护说明](../../docs/astro-authoring.md)。

本书的当前阅读契约同时以 RN-001 v1.11 和 [RN-002 v1.1](../../docs/reading-presentation-standard.md) 为准：完整中文题干和来源、逐节注解、共同版心、代码等宽与原生折叠、命名明确的索引、索引后置于章末、直达登记 PDF 的原文入口。逐页义务在根目录 `docs/reader-contract.json` 与 `docs/reader-presentation.json`，原书发布身份在 `docs/reader-sources.json`；历史批次记录保留当时的范围，当前复查执行 `python3 tools/project.py check` 及完整浏览器矩阵。

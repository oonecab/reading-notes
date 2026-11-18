# T076 · 格式一致性验证

预期来自用户 A–G 与既有 RN-001/RN-002，独立于转换脚本。检查全部章节 h1 与登记 label 相同，title 以前者开头；重复页尾为零，overline 标签/内容统一，测度170题摘要与 data-exercise 对应；程序与数学标记按语义区分，无未说明的弯引号。

保护断言逐页比较有序 id、题号、PDF链接、程序源码片段与前态，检查原始来源散列、修订链连续性。对指定文字变化之外的正文与教学内容进行差异读回。临时断言保存在 tmp/i076，不新增无必要的永久测试。

执行范围：同步镜像、呈现契约、逐页阅读契约、排版检查、全部Node回归、根check-local与受影响书完整check。真实构建/parity后绑定输出，并在桌面和390px、无脚本检查阅读行为。检查失败保留原始日志；环境缺工具或PDF编码错误记 blocked，不等同完整通过。

执行结果（2026-11-14，基线679dc9d上的未提交工作区）：

环境：Node24.22.1、pnpm11.25.0、Python3.12.1、Chrome157.0.8103.52，Windows；Python使用PYTHONUTF8=1，任务PATH选用已安装的MiKTeX Poppler23.13.0。没有修改全局PATH或项目兼容基线。

| 命令 | 退出码与结论 | 日志/报告（仓库相对路径） |
| --- | --- | --- |
| node scripts/sync-legacy.mjs --write | 0，生成52个变化镜像 | 同步后check及前后保护断言 |
| node scripts/sync-legacy.mjs | 0，72页一致 | tmp/i076/assertions.json |
| node tools/check-presentation-contract.mjs | 0，RN-002 | tmp/i076/presentation-2.log |
| node tools/reader-contract/check.mjs | 0，72页 | tmp/i076/reader-2.log |
| node tools/reading-typography/check.mjs | 0，72页 | tmp/i076/typography-2.log |
| node --test scripts/*.test.mjs | 0，135通过，0失败/跳过 | tmp/i076/node-tests.log |
| python tools/project.py check-local | 0，22项通过 | tmp/project-check/20261114T214659-gi9e47hv/report.json；tmp/i076/check-local-final.log |
| python tools/project.py check --book BOOK | 六书各1，blocked | tmp/i076/full-BOOK.log（csapp、weiss、measure-probability、visual-group-theory、stochastic、eopl） |
| python tools/project.py build | 0，72阅读页/96公开HTML/606文件 | tmp/i076/build-4.log；tmp/reading-notes-migration/build.json |
| python tools/check_astro_records.py | 0，当前绑定及历史来源保持 | tmp/i076/astro-records.log |
| node tmp/i076/verify.mjs --before | 1，旧快照265个目标不满足，预期失败 | tmp/i076/before-assertions.json |
| node tmp/i076/verify.mjs | 0，72页/56章/170摘要；保护断言通过 | tmp/i076/assertions.json |
| node tmp/i076/browser.mjs | 最终0，312视图/129落点 | tmp/i076/browser-3.log；tmp/i076/browser/report.json |
| node tmp/i076/focus.mjs | 0，真实鼠标横滚0→97px | tmp/i076/focus.json |
| git diff --check | 0 | tmp/i076/diff-check.log |

完整入口均在发布耐久性检查失败：Windows无os.O_DIRECTORY，且缺少rsync；原错误与每次退出码保留，书级程序执行尚未到达。没有删除或放宽这两个测试。check-local实际覆盖七书的结构、来源、代码副本、题面清单及阅读契约，但不替代POSIX发布耐久性和完整C/Racket/ASan程序矩阵。本次PDF来源核对在Poppler下通过，没有把提示中的潜在Xpdf编码问题当作实际发生的失败。

构建包含72页完整DOM parity、96公开页预算和真实CSP：9个代表页面、13个脚本散列，篡改脚本被拒绝。本地产物为deploy/portal-releases/20261114T213511，未部署。浏览器检查副本逐页与成功构建的dist字节一致，再登记52个新输出SHA。

浏览器范围：52个修改页各1800/1440/1024/390启用脚本，以及1440/390关闭脚本，共312视图；检查收起/全部展开宽度、首末题原生开合、局部公式滚动及保留的返回入口。五幅已登记SVG章节图共43节点，在1440、390和390无脚本实际操作129次，其中15次键盘Enter；复用仓库waitLanding核对预期URL、文字标题、固定栏下方的稳定可见落点。测度书无此类登记SVG节点，未把它虚计为图点击覆盖。

生成18张矩阵截图和4张专项截图，实际打开13张验收图；另打开1张无脚本返回定位诊断图。截图逐项散列、实际读回范围见docs/format-consistency-review.json。长类型公式可在326px容器内从左端真实滚到右端97px，整页不溢出。没有声称逐页逐段重新数学审阅，或重跑完整发布矩阵的所有注解、图形、剪贴板、下载和HTTP路径。

失败与修正：初轮发现地图落点旧标题、题干/输入散列和长公式局部容器需要联动，均修复后复跑；EOPL6.29/6.30独立中文展示清单及其当前校验散列同步，原始英文输入保留。一次元数据编辑带入的末尾换行已恢复原字节。临时浏览器断言先误以scrollY<200代替标题可见，后又用innerText引入的换行比较中英双行标题；诊断截图确认实际落点正确，分别改为可见标题判据和仓库既有waitLanding。attempt-1/2完整保留，已完成视图只在HTML散列一致时复用，未跳过失败视图或落点。

文档一致性：52页逐项修订链、6条题干/依赖绑定、23个地图target_title及当前书级绑定均有前值/后值；全部导航label/href与历史修订链未改。规则依据及无需修改TECH/RN正文的理由见I076。完整文件清单见tmp/i076/changed-files.json，逐页语义差异见docs/format-consistency-review.json。

残余边界：完整POSIX/程序门禁blocked；没有第二浏览器、实体手机、读屏器或生产验证。21,000余处既有MathML可访问名称和全量language-*标记按用户要求留待后续，不在本批扩写。

### I076-spacing · 指定MathML间距回退（2026-11-14）

用户逐项限定4页8个公式：CS:APP第6章2式，EOPL第3章3式、第6章2式及总览1式。仅加入10个`<mspace width="0.25em"/>`；72页前后字节对比确认，除这些插入之外，受控源没有其他变化。原aria-label、annotation、题号、锚点、标题、PDF链接、程序、17个code例外和原审阅结论均保持；同页未列出的`60,000/12,000=5`也未改。

按相同节点修改EOPL6.30独立中文展示清单，并同步其题干与当前校验散列。新增修订链为`I076-spacing`，保留历史链及original_sha256；前后源/输出散列、单节点diff和当前验收证据追加在`docs/format-consistency-review.json`的`spacing_followup`，不将此前312视图的证据改写为新版本全站验收。

真实渲染使用Chrome157.0.8103.52/Playwright，实际读取MathML相邻元素的`getBoundingClientRect()`，不以innerText判断空格。修改前保存的正式产物散列与原输出绑定一致；修改后使用成功构建的dist。8个公式分别在1440/390px测量，共16组公式、20对边界：

| 边界 | 修改前 | 修改后 |
| --- | --- | --- |
| `60,000`末尾→`毫`、`5`→`毫` | 0px | 4.25px |
| `106`→`余`、`余`→`4` | 0px | 4.25px |
| `run`、`value-of-program`、`value-of`→冒号 | 0px | 4.25px |
| `cps-of-rest`、`cps-of-exp/ctx`→冒号 | 0px | 4.25px |
| 总览表格的`f`→冒号 | 0px | 3.625px（随表格较小字号） |

全部展示token与原label一致，没有新增重复文本。展开正文全部details后，390px页面scrollWidth仍为390px；长签名保持既有局部滚动，真实鼠标横滚到101px，未撑宽页面。实际打开4张修改后截图读回：手机单位、手机余数、桌面冒号和手机长类型签名；其余截图只记录为捕获，不宣称逐张目视检查。完整坐标、字号、散列、截图与测量结果见`tmp/i076-spacing/before-render.json`和`after-render.json`。

| 执行命令 | 退出码 | 本轮记录 |
| --- | --- | --- |
| `node scripts/sync-legacy.mjs --write` | 0 | 生成镜像；没有直接编辑镜像 |
| `node scripts/sync-legacy.mjs` | 0 | `tmp/i076-spacing/sync.log` |
| `node tools/check-presentation-contract.mjs` | 0 | `tmp/i076-spacing/presentation.log` |
| `node tools/reader-contract/check.mjs` | 0 | `tmp/i076-spacing/reader.log` |
| `node tools/reading-typography/check.mjs` | 0 | `tmp/i076-spacing/typography.log` |
| `node --test scripts/*.test.mjs` | 0 | `tmp/i076-spacing/node-tests.log`：135通过、0失败、0跳过 |
| `python tools/project.py build` | 0 | `tmp/i076-spacing/build.log`：本地包20261114T222201，72阅读页/96公开HTML，parity、预算、CSP通过 |
| `node tmp/i076-spacing/render.mjs --before` | 0 | 真实采样复现20对0px间距；这是采样成功，不代表旧版满足间距要求 |
| `node tmp/i076-spacing/render.mjs` | 0 | `tmp/i076-spacing/after-render.log`：20对间距满足0.25em几何断言 |
| `node tmp/i076-spacing/verify.mjs` | 0 | `tmp/i076-spacing/protection.json`：只有指定节点插入；历史与其他字节保留 |
| `python tools/check_astro_records.py` | 0 | `tmp/i076-spacing/astro-records.log`：72页当前绑定及历史来源检查通过 |
| `git diff --check` | 0 | `tmp/i076-spacing/diff-check.log` |

该8节点间距回退已修复。无需更改RN-001/RN-002或TECH：执行既有单位/记号排版要求，技术栈和计算规则不变。此前完整POSIX门禁的环境限制仍是历史边界，本轮未声称重跑全部教材程序或全站浏览器矩阵。未commit/push/deploy。

### I076-sicp-accessibility · SICP 第一章属性补齐（2026-11-14）

检查执行于2026-11-14；2026-11-17恢复中断任务时确认check-local退出0，重新执行源字节保护断言并核对dist散列未变，再补齐本记录。此前检查结果只绑定上述同一内容版本，不声称今天重新运行全部检查。

范围仅为受控源 src/content/books/sicp/chapter01_procedures.html 的 73 个新增属性。65 个代码块逐个分类：58 个 language-scheme；7 个 language-text，分别是习题1.6的调用/结果、1.9的箭头求值轨迹、1.12的Pascal三角形、1.34/1.42/1.43的调用/结果，以及 programs 下的运行命令说明。带注释输出的 Scheme 程序仍归为 Scheme，没有修改代码、注释、缩进或程序维护源。

8 个块级 MathML 均补可访问名称，对应习题1.2前缀分式、1.8立方根Newton改进、1.15正弦三倍角、1.29 Simpson积分、1.31 Wallis乘积、1.37无限/有限连分式、1.39 Lambert正切连分式。名称包含公式内容；全部原 MathML 子节点保持不变。

修改前快照运行同一属性断言：退出1，确认65个语言类及8个名称缺失；修改后退出0。删除新增的73个属性后与本轮源快照逐字节相同，另外71页源完全未改；镜像仅由 sync-legacy --write 生成。原始SHA、历史history、17个code例外文本及既有审阅结论全部保留。43条题干/引用输入的序列化HTML散列因属性改变而重新绑定，旧值与新值保留在 sicp_accessibility_followup；SICP书级 current_source_sha256 同步，独立题面/代码清单无需修改。

当前绑定：source_sha256=615d72ee21654a32a1a0453a4785dc7208053edc3adb149b04cc363dc2eb24c7；output_sha256=b6dbaf964487ae3e49a0c2faf94cd9bdc7f9e74196c7f16e0ae7f2d9240443f8；本地构建 20261114T224317。修订链新增 I076-sicp-accessibility，详细逐块分类、公式名称与锚点见 docs/format-consistency-review.json 的 sicp_accessibility_followup。

| 执行命令 | 退出码 | 结果/证据 |
| --- | --- | --- |
| node scripts/sync-legacy.mjs --write | 0 | tmp/i076-sicp/sync-write.log |
| node scripts/sync-legacy.mjs | 0 | tmp/i076-sicp/sync.log |
| node tools/check-presentation-contract.mjs | 0 | tmp/i076-sicp/presentation.log |
| node tools/reader-contract/check.mjs | 0 | tmp/i076-sicp/reader.log |
| node tools/reading-typography/check.mjs | 0 | tmp/i076-sicp/typography.log |
| node --test scripts/*.test.mjs | 0 | tmp/i076-sicp/node-tests.log |
| python tools/project.py build | 0 | tmp/i076-sicp/build.log |
| python tools/project.py check-local | 0 | tmp/i076-sicp/check-local.log |
| node tmp/i076-sicp/verify.mjs | 0 | tmp/i076-sicp/protection.log |
| node tmp/i076-sicp/browser.mjs | 0 | tmp/i076-sicp/browser.log |

Node测试135通过、0失败、0跳过。check-local使用 D:/Program Files/MiKTeX/miktex/bin/x64/pdftotext.exe（Poppler23.13.0），正式报告为 tmp/project-check/20261114T224720-9tyk4_58/report.json。构建通过72阅读页的parity、预算及CSP检查，产物只在忽略目录。

Chrome 157.0.8103.52 / Playwright 实际加载当前dist，在1440px和390px下展开正文全部details，65块文本与修改前一致，58/7语言分类一致，8个公式名称分别在浏览器可访问性树中唯一存在；页面scrollWidth分别为1440与390，无整页横向溢出。没有截图人工读回或读屏器测试，不将浏览器AX树检查表述为这些证据。

RN-001/RN-002和TECH无需改动：这是落实既有代码语言标识和公式可访问性要求，没有变更公式语义、计算规则、技术栈或环境配置。此前完整POSIX门禁限制仍保持历史边界，本轮不声称全站浏览器矩阵或教材程序重新验收。未commit/push/deploy。

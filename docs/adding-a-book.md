# 接入一本新书

从[共同标准 RN-001](reading-notes-standard.md)开始，使用[工作模板](templates/reading-notes/README.md)记录本书事实。用户提供原书资料、版本或可定位来源，以及本次要做的范围后，就按下面的顺序推进；缺少资料时先完成能核实的规划，待核实项保留明确状态。

## 1. 来源、全书规划与样章

1. 检查当前工作树和已有书籍约定，保留无关修改。建立 `issues/`、`plan/`、`test/`、`milestone/` 记录，说明任务依据、范围、风险和恢复点。
2. 选择稳定的小写 ID，在 `books/<id>/` 建目录。按模板创建 `reading-plan.md`、`agent.md`、`notes/README.md` 和 `review/` 中的逐章记录；补充子项目 `README.md`。已有子项目保留必要内部路径，按增量接入。
3. 核实原书身份、来源哈希和页序映射，从原书独立枚举目录、编号陈述、示例及习题。默认维护 `notes/source_manifest.json`；题目和摘录较多时另列 `exercise_manifest.json`、`source_excerpts.json`。字段适配本书，但必须覆盖 RN-001 的定位与范围要求，并由本书检查器核对。
4. 通览全书结构，先写 `notes/book_overview.html` 和序言，再完成一个代表章。按原书主线完成正文、关键机制推演、本批完整题解及有教学价值的程序；逐章记录覆盖关系。
5. 进行样章的来源读回、程序验证和桌面/窄屏真实阅读，修复内容与组件问题后按批次扩展。每批更新地图、来源覆盖及实际验收状态；全书完成范围以清单与证据为准。

新书默认目录：

```text
books/<id>/
  README.md                 # 本书入口与当前范围
  reading-plan.md            # 版次、学科适配、全书地图与批次
  agent.md                  # 书级维护入口
  notes/                    # 总览、序言、逐章 HTML、来源/覆盖清单
    README.md               # 页面映射、组件来源和专项约定
  code/                     # 默认的程序维护源及索引、运行说明
  assets/                   # 确有需要的本书资源
  tools/                    # 本书检查器与同步/提取工具
  review/                   # 逐章审阅及可提交的证据摘要
```

若以 HTML 维护代码，在 catalog 登记 `html_code_blocks`，从正式页面提取验证。采用其他目录时登记实际路径；如 Weiss 保留 `c/` 和 `notes/tools/`。临时文件、提取件、二进制、截图及原始日志放在忽略目录。

## 2. 接入仓库工具与书架

准备好本批页面、书级说明与有意义的检查器后，再登记到公共层。当前注册表负责路径事实，检查/构建仍有按书的显式接线；只增加 catalog 条目不能完成新书接入。样章阶段可直接运行书内工具，完成接线后公共验收统一用根入口。

| 接入位置 | 必须完成的内容 |
|---|---|
| [books/catalog.json](../books/catalog.json) | ID、标题、实际目录、入口、发布前缀、notes/code 目录、维护约定、代码权威源、检查器、本批真实页数与原书题数 |
| [tools/project.py](../tools/project.py) | `check()` 显式分派新书的快速与完整检查；确认报告含新书检查命令及执行结果 |
| [tools/check_structure.py](../tools/check_structure.py) | 复核新增文件、来源身份和文档约束是否被覆盖，需要书级来源检查时补入本书检查器 |
| [deploy/build_portal.py](../deploy/build_portal.py) | 显式发布来源清单、书级检查和构建资源；当前要求 ID 与 publish_prefix 相同 |
| [deploy/reader_views.py](../deploy/reader_views.py) | 新书名称、资料页面、来源链接转换及导航；缺少本地原书发布许可时保留可核对的文字来源 |
| [Nginx 入口模板](../deploy/nginx-portal-static.inc.template)、[deploy/verify_portal.py](../deploy/verify_portal.py) | 新书入口规则、相对资源、响应与链接验收 |
| [portal/index.html](../portal/index.html)、[README](../README.md)、[文档索引](README.md)、[规则职责索引](rules/README.md) | 书架、读者入口、维护与规则权威链接，以及真实完成范围 |
| [.project-governance.json](../.project-governance.json)、[TECH](../TECH.md) | 新增源码边界、实际维护方式及必要命令；按[治理更新流程](governance-updates.md)预览、应用、校验受管部分 |

catalog 的字段和合法值沿用现有条目，`expected_pages` 是实际 HTML 数（含地图/序言），`expected_exercises` 是本批覆盖的原书题数；原创自测另记。新书默认 `code_authority: standalone_sources`。`guidelines`、`checker`、`entry` 指向实际存在的文件；登记前确认 ID/前缀唯一。增量扩章时同步范围和数量，保留已有 URL、章序与锚点。

发布路径使用 `<publish_prefix>/`，源文件使用 `books/<id>/`。完整原书和配套包须明确可发布并列入来源清单后才进入站点包。构建应能从同仓库材料复现，依赖的本地对照资料及获取方式须说明，不能引用其他工作目录中的隐含文件。

## 3. 验收并记录本批结果

下列命令均在主仓库根目录执行，`<id>` 与 `<release-id>` 替换为实际值。构建输出中的 release ID 用于后续预览，避免预览不同版本。

```sh
python3 tools/project.py doctor
python3 tools/project.py check --book <id> --quick
python3 tools/project.py check --book <id>
python3 tools/project.py check --quick
python3 tools/project.py check
python3 tools/project.py build
python3 tools/project.py verify-release --release-id <release-id>
python3 tools/project.py serve --release-id <release-id>
```

`check --quick` 验证结构、链接、同步与来源绑定；完整检查须真正执行适用程序及独立基准。查看生成报告，确认新书被执行；程序成功后继续按 RN-001 做来源与内容读回、最终页面真实阅读和正式包的浏览器路径验收。`verify-release` 需要本机 Nginx/OpenSSL；不可用时记录具体缺口及实际替代证据，不能记为该层已通过。

逐章填写审阅记录，必要发现闭合后更新 I/P/T/M 和书架的本批状态。交付说明列明完成范围、来源/内容/程序/阅读/集成的实际结论、证据位置及剩余事项。后续批次沿同一流程继续；生产发布及恢复按[统一部署说明](../deploy/README.md)和用户实际授权执行。

下次可直接提出：“按项目的 RN-001 读书笔记标准接入这本书，资料在……，本次完成……。”如果用户要求从头开始，则先完成全书地图、序言和代表章，再按阅读计划推进。

I074补充：新书来源快照必须合入交付分支历史再推送，详见[Astro维护说明](astro-authoring.md)。合并前核对普通克隆可取得登记对象；根检查拒绝仅本地存在而不为HEAD祖先的快照。

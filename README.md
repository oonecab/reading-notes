# Reading Notes · 读书笔记

把一本书作为独立子项目，在同一个仓库中维护中文伴读笔记、习题解答、可运行程序、原书来源和验证记录。目前收录 Richard Durrett《Essentials of Stochastic Processes》第三版、Mark Allen Weiss《Data Structures and Algorithm Analysis in C》第二版（中国改编版）、Bryant / O’Hallaron《Computer Systems: A Programmer’s Perspective》第三版 Global Edition、Nathan C. Carter《Visual Group Theory》（MAA 2009 版权电子版），程士宏《测度论与概率论基础》（北京大学出版社 2004 年第 1 版），以及 Friedman / Wand《Essentials of Programming Languages》第三版的地图、序言与第 1–6 章。

统一阅读站点为 [notes.zzzping.top](https://notes.zzzping.top/)。GitHub 仓库为 [oonecab/reading-notes](https://github.com/oonecab/reading-notes)，沿用随机过程项目的 Git 历史；本地项目目录继续沿用原名。

| 子项目 | 阅读入口 | 内容与维护方式 |
|---|---|---|
| [Durrett 随机过程](books/stochastic/README.md) | [全书地图](books/stochastic/notes/book_overview.html) | 9 个 HTML 页面、236 道习题、7 组 C/Python 示例；独立源码同步到网页 |
| [Weiss 数据结构与算法](books/weiss/README.md) | [全书地图](books/weiss/notes/book_overview.html) | 13 个 HTML 页面、362 道习题、205 组双语实现；从正式 HTML 提取代码验证，另有 171 个 C 图例入口 |
| [CS:APP 计算机系统](books/csapp/README.md) | [全书地图](books/csapp/notes/book_overview.html) | 14 个 HTML 页面：序言及第 1—12 章，包含三个部分；117 个原书大节、419 道原书习题、36 道补充自测与 C/Python 实验；独立源码同步到网页 |
| [Carter 视觉群论](books/visual-group-theory/README.md) | [全书地图](books/visual-group-theory/notes/book_overview.html) | 12 个 HTML 页面：地图、序言、第 1—10 章及全部 302 题；10 组 C/Python 程序 |
| [程士宏 测度论与概率论·全六章伴读](books/measure-probability/README.md) | [伴读总览](books/measure-probability/notes/book_overview.html) | 8 个 HTML 页面：总览、序言与前言、六章及全部 170 题；4 组 C/Python 程序，包含全部星号小节 |
| [Friedman / Wand · EOPL](books/eopl/README.md) | [全书地图](books/eopl/notes/book_overview.html) | 8 个 HTML 页面：地图、导读与序言、第 1–6 章；252 道完整题解及 Python/Racket/C 示例 |

EOPL 当前有地图、序言与第 1–6 章八个阅读页，覆盖序言及六章全部 252 道习题。控制路线从[第 5 章](books/eopl/notes/chapter05_continuations.html)进入[第 6 章](books/eopl/notes/chapter06_cps.html)，把解释器续文、异常、线程、CPS转换和效果连接起来。第 7–9 章与附录保留原书导览；本地与生产验收见 [T061](test/T061-eopl-publication.md)，当前生产版本为 `20261023T211622`。

CS:APP 全书笔记已接入统一首页与构建：从首页点击“进入 CS:APP 笔记”，进入全书地图后选择序言或第 1—12 章；阅读页顶部可返回书架。统一包收录笔记、教学程序与原书 PDF，点击章节、来源和习题中的页码链接可打开对应 PDF 页序。线上生效另按发布授权和验收记录确认。

视觉群论已接入统一构建与书架，来源清单保留原书身份和印刷页/PDF 页序，完整原 PDF 仅本地对照；首批见 [T021](test/T021-visual-group-theory.md)，第 2—4 章见 [T022](test/T022-visual-group-theory-ch02-04.md)，第 5—8 章见 [T024](test/T024-visual-group-theory-ch05-08.md)，第 9—10 章见 [T025](test/T025-visual-group-theory-ch09-10.md)。视觉群论与测度概率当前范围的统一上线验收见 [T027](test/T027-five-book-publication.md)。

## 阅读与本地运行

直接用浏览器打开上述全书地图即可离线阅读。每章是一份完整 HTML，公式、图表、正文代码和导航保存在文件内；保留完整子项目目录，相关文件链接才能正常使用。

统一书架和资料网页来自发布构建。在仓库根目录执行以下命令，预览会先构建完整站点，再仅向本机提供服务：

```sh
python3 tools/project.py doctor
pnpm install --frozen-lockfile
python3 tools/project.py serve
```

访问 `http://127.0.0.1:8000/`，按 `Ctrl+C` 停止；端口可用 `--port 8080` 指定。已生成版本可使用 `serve --release-id YYYYMMDDTHHMMSS` 预览。受控 HTML 与检查镜像的同步见 [Astro 维护说明](docs/astro-authoring.md)，预览提供正式包中的页面。

Python 需要 3.10 或更高版本，项目脚本使用标准库。完整验证需要 Clang、Make 和 Poppler 的 `pdftotext` / `pdfinfo`；构建使用固定 Node 24.21.0 LTS、pnpm 11.21.0 和 Astro 7.4.0；先运行 `pnpm install --frozen-lockfile`。`doctor` 检查工具是否可用，不会安装软件。网页服务器只提供静态文件。

```sh
# 随机过程：编译或运行独立示例
make -C books/stochastic/code
python3 books/stochastic/code/chapter02_poisson_processes/poisson.py
./books/stochastic/code/build/poisson

# Weiss：运行全部 C 图例和 TestKit
make -C books/weiss/c check
```

## 项目结构与维护

```text
books/
  catalog.json                  # 书籍目录、入口、发布前缀与维护方式
  stochastic/                   # 随机过程：notes、code、assets、tools、review
  weiss/                        # Weiss：notes、c、原书 PDF、原图例源码包
  csapp/                        # CS:APP：notes、code、tools、原书 PDF
  visual-group-theory/           # 视觉群论：notes、code、tools、review；原 PDF 仅本地对照
  measure-probability/           # 测度与概率：notes、code、tools、review；原 PDF 仅本地对照
portal/                         # 统一书架与发布阅读样式
tools/project.py                # 环境、校验、构建、预览的统一入口
deploy/                         # 统一构建、HTTPS 验证及 Nginx 模板
docs/                           # 文档职责、架构决策、环境与治理
issues/、plan/、milestone/、test/ # 问题单、实施计划、里程碑与测试设计
AGENTS.md、CLAUDE.md、TECH.md     # Agent 入口与技术事实
.project-governance.json        # 可重复生成的治理配置
```

一书一个子项目、一章一个笔记文件；保持已有章序、文件名、锚点和相对资源路径。共同写作与验收方法由 [RN-001 读书笔记共同标准](docs/reading-notes-standard.md)维护，页面族、导航、章首与索引位置、题干语言和检查方法由 [RN-002 阅读呈现、导航与检查规范](docs/reading-presentation-standard.md)维护；各书的算法、模型及专项约定见[规则职责索引](docs/rules/README.md)。公共层负责登记、验证、阅读入口和发布。迁入的 PDF 和原代码包用于确定教材版次与来源，验证过程中不自动替换。

新增书籍按[接入步骤](docs/adding-a-book.md)，使用[阅读计划、书级约定和逐章审阅模板](docs/templates/reading-notes/README.md)：核实原书与覆盖清单，建立全书地图和序言，完成代表章并实际验收，然后分批写作、接入统一书架。可直接提出：“按项目 RN-001 标准接入这本书，资料在……，本次完成……。”共享 Agent 入口已把该标准列为必读。

修改程序与网页代码副本时，先按 [Astro 内容维护](docs/astro-authoring.md) 更新受控源和检查镜像，再运行原源码同步检查与完整验证。Weiss 的教学算法在受控章节 HTML 内维护，展开检查镜像后提取验证；`books/weiss/c/` 保留原图例的 C 转换，两者的职责见子项目说明。VS Code 从本仓库根目录打开，使用 `.vscode/` 中的“调试指定图例”或“调试 TestKit 指定用例”。

```sh
# 快速检查：结构、链接、代码同步、当前审阅绑定
python3 tools/project.py check --quick

# 完整检查：已登记书籍的数值/功能验证与全部已登记 C 程序
python3 tools/project.py check

# 可选按书检查，以及额外复核已登记的实验计数
python3 tools/project.py check --book stochastic
python3 tools/project.py check --book weiss --benchmarks
```

根 `Makefile` 提供 `make check`、`make check-fast`、`make build` 和 `make serve` 等快捷入口。运行日志和 JSON 证据写入 `tmp/project-check/`，提取件与二进制不纳入提交。结构、程序、原书内容复核及浏览器验收分别记录；程序执行通过不能代替全部数学论证正确性的证明。

采用 `controlled` 治理级别，以覆盖目录迁移、公共发布与恢复。详细职责入口是 [docs/README.md](docs/README.md)，当前技术事实见 [TECH.md](TECH.md)，治理更新见[操作说明](docs/governance-updates.md)，新增书籍方法见[子项目接入说明](docs/adding-a-book.md)，本次迁移及来源见[迁移记录](docs/migration-20261012.md)。

## 构建与部署

```sh
python3 tools/project.py build
# 可指定固定版本 ID；已有目录会拒绝覆盖
python3 tools/project.py build --release-id YYYYMMDDTHHMMSS
```

统一包位于 `deploy/portal-releases/<release-id>/`，Astro 从 `src/content/books/` 构建登记的六本书，原 Python 检查继续读取同步镜像。发布路径分别为 `/stochastic/`、`/weiss/`、`/csapp/`、`/visual-group-theory/`、`/measure-probability/` 和 `/eopl/`；原有书籍的章节地址保持兼容。

构建依赖 Node/Astro 与 Python 辅助脚本，完整工具准备见 [Astro 编写说明](docs/astro-authoring.md)。全部公开 HTML 内联阅读资源（数量以本次构建报告为准），正式页做全 DOM parity；代码/PDF 下载继续作为链接。`pnpm build` 包含使用生产 CSP 的真实浏览器冒烟和脚本哈希变异检查，`pnpm check:offline` 覆盖全部页面的四档视口及桌面/手机 no-JS。

包内包括站点归档、逐文件 SHA-256、版本清单和本版 CSP 对应的 Nginx 配置。服务器采用独立 `releases/<release-id>` 目录与 `current` 原子切换；回滚同时恢复站点链接与该版本的配置。完整步骤、证书维护、验收边界及回滚命令见[部署说明](deploy/README.md)。

可用 `python3 tools/project.py verify-release --release-id YYYYMMDDTHHMMSS` 在临时本地 Nginx 上验证 HTTPS 响应、文件哈希、MIME、CSP、旧入口和 PDF Range；需要本机 Nginx 与 OpenSSL。该检查不会修改系统 Nginx 配置。生产上传、生效与公网浏览器验收在明确的发布任务中执行并单独记录。

## 本地生成物与上传边界

正式维护源、原书来源和验证摘要随项目保留。`tmp/`、编译/字节码缓存和本地版本包由 `.gitignore` 排除；只有明确清单中的站点文件进入部署包。被忽略的目录也可能包含验证输入、历史证据、迁移基线和正在使用的预览，不能整目录盲删。

本地清理先核对用途、引用和运行进程，再对确认可重建的生成物记录精确清单，采用可恢复的移除并复查正式文件与构建。此次清理的范围、恢复和验收见 [I013](issues/I013-project-cleanup.md) 与 [T013](test/T013-project-cleanup.md)。

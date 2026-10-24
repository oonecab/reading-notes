# EOPL · 程序设计语言要义

Daniel P. Friedman / Mitchell Wand，*Essentials of Programming Languages*，第三版，MIT Press，2008。

从[全书地图](notes/book_overview.html)开始，或直接阅读[导读与作者序言](notes/preface.html)。I044 已发布地图与序言两页；当前本地内容包含第 1–9 章，累计十三页伴读、356 道题解。原书九章、附录及全部编号项目已登记；后续章节的伴读和题解见[阅读计划](reading-plan.md)。

正文维护于 `src/content/books/eopl/`，`notes/` 中的九个 HTML 是共享样式展开后的独立成品。基础阅读无需服务器或网络。原 PDF 作为已登记的阅读参考，章节来源链接直接定位 PDF 页序；身份与页序见[来源清单](notes/source_manifest.json)。

I044 按用户整体发布要求，将现有两页、来源摘要与闭包实验接入 catalog、书架、根检查入口和发布清单；九章伴读仍按阅读计划推进。原始源码基线为 Git `7e9d2ea`，与旧生产版本明确区分。共同排版遵循 RN-001 v1.7；本批构建、实际阅读和上线证据见 [T044](../../test/T044-reading-typography.md)。

从主仓库根目录执行：

```sh
python3 books/eopl/tools/sync_notes.py --write
python3 books/eopl/tools/check_notes.py --quick
python3 books/eopl/tools/check_notes.py
python3 books/eopl/tools/test_checker.py
python3 books/eopl/code/scope_demo.py
racket books/eopl/code/test_chapters.rkt
```

[维护入口](agent.md) · [页面说明](notes/README.md) · [程序说明](code/README.md) · [地图与序言审阅](review/map-preface.md) · [T042 验证记录](../../test/T042-eopl-map-preface.md)。

第 1、2 章续写入口：[归纳数据与递归程序](notes/chapter01_inductive_data.html)、[数据抽象与抽象语法](notes/chapter02_data_abstraction.html)。包含全部 67 道原题、解答与 Racket 程序；来源和运行范围见 [T048](../../test/T048-eopl-ch01-02.md)。

第 3 章续写入口：[表达式、闭包与词法地址](notes/chapter03_expressions.html)。包含 44 道完整中文原题、解答、逐节注解与实际运行的 Racket 解释器。核对记录见 [T058](../../test/T058-eopl-ch03.md)。

第 4 章续写入口：[状态、存储与参数传递](notes/chapter04_state.html)，包含 42 道完整中文题干与解答、五节注解，以及实际执行的纯存储传递、隐式引用、参数策略和语句解释器。核对记录见 [T059](../../test/T059-eopl-ch04.md)。

控制路线：[第5章：续文、异常与线程](notes/chapter05_continuations.html)与[第6章：CPS转换与计算效果](notes/chapter06_cps.html)。含98题完整中文题干和解答，提供过程/数据续文、CPS转换、目标解析运行、数据化/标签化，以及实际线程/同步例子。当前本地验收见 [T060](../../test/T060-eopl-ch05-06.md)。

第5、6章私有存储及转换绑定修订与本轮发布证据见 [T061](../../test/T061-eopl-publication.md)，原I060审阅保持其历史范围。

类型路线：[第7章：类型检查与类型推导](notes/chapter07_types.html)，按原节次讲解语义类型、类型环境、标注检查、替换/合一、两阶段推导及let多态。30题保留全部中文条件、输入与提示；Racket检查器、推导器和解释器实际运行，见[T062](../../test/T062-eopl-ch07.md)。

模块路线：[第8章：模块、接口与抽象类型](notes/chapter08_modules.html)，保留原书九个教学节/子节、16个编号例子、27题和18条注解。公开导出、类型身份、接口满足、依赖结果和参数逆变分别解释并执行，证据见[T063](../../test/T063-eopl-ch08.md)。

对象路线：[第9章：对象、类、继承与方法调用](notes/chapter09_objects.html)，十教学节/子节、定义9.5.1、42题及20条阅读注解。字段位置、词法宿主、动态分派、super和TYPED-OO分别解释并执行，见[T064](../../test/T064-eopl-ch09.md)。

全书完结（I065）：[附录A](notes/appendix_a_reading.html)与[附录B](notes/appendix_b_sllgen.html)补齐原书两份附录；当前地图、序言、九章与两附录共13页、356题。最近7–9章修复步数预算边界和继承关系预验证，完整来源/程序/阅读/发布记录见[T065](../../test/T065-eopl-completion-publication.md)。

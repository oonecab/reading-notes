# EOPL：可运行程序

程序是 `standalone_sources`：这里的源文件是权威，HTML 中的完整文件及局部函数由 `tools/sync_notes.py` 同步。所有程序在本地运行；阅读站点不执行读者输入。

| 文件 | 内容与输入契约 | 运行 |
|---|---|---|
| `scope_demo.py` | 序言六构造式 AST、词法/动态作用域；原创 Python 教学子集 | `python3 books/eopl/code/scope_demo.py` |
| `chapter01.rkt` | 第 1 章列表、S-list、LcExp、两种树形契约及递归例子；有限、无环合法数据 | `racket books/eopl/code/chapter01.rkt` |
| `chapter02.rkt` | 第 2 章自然数、diff-tree、7 种环境接口、栈、4 种 LcExp 接口、zipper、datatype、解析器 | `racket books/eopl/code/chapter02.rkt` |
| `test_chapters.rkt` | 原例、边界、错误路径、独立宿主操作比较、不同表示客户一致性、解析回写 | `racket books/eopl/code/test_chapters.rkt` |
| `benchmark_bigits.rkt` | 阶乘 6、8、10 × 基数 2、10、16、256；预热 1 次、每组测量 3 次、计时前 GC、单调时钟 | `racket books/eopl/code/benchmark_bigits.rkt` |

第 1、2 章实际验证环境为已有的 Racket 8.17；`eopl` 提供书中的 `define-datatype` 与 `cases`，`rackunit` 提供测试。使用完整 Racket 发行版且含这两个库即可运行。主程序先输出供手算比对的例子，测试退出码非零表示失败。检查器先从 PATH 寻找 racket；macOS 还会检查 Applications 内的已有 Racket 安装。没有运行时会明确失败，不以静态检查代替执行。

第 1 章例子使用 Racket 承载 Scheme 风格过程；`number-leaves` 用 `values/let*-values` 表达双返回值。为使全章在同一模块内比较，原题 `remove` 改名 `remove-all`，1.36 的版本叫 `number-elements/g`。第 2 章用 `env-api`、`lc-api` 收集同名接口；`seq-`、`zip-`、`dt-` 等前缀用于分开习题的不同表示，具体映射在题解代码和注释中说明。它们是原创解答实现，并非声称逐字执行原书所有代码。

边界由正文及源程序契约共同规定：bigits 基数至少为 2，输入自然数的最高位非零，零为 `()`，零的前驱报错；diff-tree 允许全部整数和非规范表示；环境值可以为 `#f`，未绑定与假值不同；批量环境扩展对冲突重复变量采用左边第一项胜出；ribcage 的常数时间构造假定输入是等长的既有列表，不在构造器内做线性长度检查。树的两种文法不能混用。空栈取顶/弹出、序列越过端点、根上移、空树取内容都报错。单参数 AST 解析拒绝多余字段、非法形参、点对与残缺输入；多参数版本允许文法星号产生的空形参/空操作数序列。2.28 的替代文法有歧义，字符串 unparser 不承诺唯一逆变换。

计时代码只通过自然数四操作计算，使用逐单位加法与重复加法的乘法。时间数值只绑定本次实现与运行环境；PDF 原例修正、测量结果及语义验证见 `../review/ch01-02.json`。程序测试不能替代一般归纳证明。

## 序言解释器的完整输入与错误契约


`scope_demo.py` 是伴读原创的有限 AST 解释器，用于核对闭包保存环境和变量遮蔽。实现语言为 Python 3.10+ 标准库；被解释语言是下面六种构造形成的教学子集。它不解析原书的文本语法，也没有 LETREC、布尔值、存储、类型检查或 Scheme 兼容层。

| AST | 含义 |
|---|---|
| `("const", n)` | 整数常量，拒绝 Python bool |
| `("var", name)` | 沿环境链查询最近绑定 |
| `("diff", e1, e2)` | 先左后右，两个值必须都是整数 |
| `("let", name, rhs, body)` | 在旧环境求 rhs，在新环境求 body |
| `("proc", param, body)` | 保存形参、体和创建环境，得到闭包 |
| `("call", operator, operand)` | 在调用环境求过程和实参，再执行过程体 |

`evaluate(expr)` 默认词法作用域：过程体在“闭包创建环境 + 形参绑定”中求值。`scope="dynamic"` 用“调用环境 + 形参绑定”，仅作有意识的比较变体。名称为 Python `str.isidentifier()` 接受的标识符。输入须是有限、无环的嵌套 tuple；整数使用 Python 精确整数。本教学程序递归运行，受宿主递归深度和内存限制，不声称尾调用优化或常量总空间。

根目录运行：

```sh
python3 books/eopl/code/scope_demo.py
python3 books/eopl/tools/test_scope.py
```

预期演示输出：

```text
lexical: 15
dynamic: 5
```

非法 AST、未知变量、非整数差与调用非过程抛出 `LanguageError`。词法版本返回的 `Closure` 可以由其他 AST 调用和传递；API 不接受注入外部环境。环境为不可变链，每次 `let` 新建节点，旧闭包保存的链不会因后来的遮蔽而被改写。

`tools/test_scope.py` 用独立手算结果核对嵌套遮蔽、实参求值环境、闭包逸出和失败分支，并对多个整数穷举验证 `b-a` / `b-c` 的作用域差异。页面副本由 `tools/sync_notes.py --write` 同步，检查器按完整源码比较。

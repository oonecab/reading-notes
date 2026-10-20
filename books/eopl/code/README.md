# EOPL 序言程序

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

# EOPL：可运行程序

程序是 `standalone_sources`：这里的源文件是权威，HTML 中的完整文件及局部函数由 `tools/sync_notes.py` 同步。所有程序在本地运行；阅读站点不执行读者输入。

| 文件 | 内容与输入契约 | 运行 |
|---|---|---|
| `scope_demo.py` | 序言六构造式 AST、词法/动态作用域；原创 Python 教学子集 | `python3 books/eopl/code/scope_demo.py` |
| `chapter01.rkt` | 第 1 章列表、S-list、LcExp、两种树形契约及递归例子；有限、无环合法数据 | `racket books/eopl/code/chapter01.rkt` |
| `chapter02.rkt` | 第 2 章自然数、diff-tree、7 种环境接口、栈、4 种 LcExp 接口、zipper、datatype、解析器 | `racket books/eopl/code/chapter02.rkt` |
| `test_chapters.rkt` | 原例、边界、错误路径、独立宿主操作比较、不同表示客户一致性、解析回写 | `racket books/eopl/code/test_chapters.rkt` |
| `benchmark_bigits.rkt` | 阶乘 6、8、10 × 基数 2、10、16、256；预热 1 次、每组测量 3 次、计时前 GC、单调时钟 | `racket books/eopl/code/benchmark_bigits.rkt` |

第 1–4 章实际验证环境为已有的 Racket 8.17；`eopl` 提供书中的 `define-datatype` 与 `cases`，`rackunit` 提供测试。使用完整 Racket 发行版且含这两个库即可运行。主程序先输出供手算比对的例子，测试退出码非零表示失败。检查器先从 PATH 寻找 racket；macOS 还会检查 Applications 内的已有 Racket 安装。没有运行时会明确失败，不以静态检查代替执行。

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

## 第 3 章：解释器与翻译器

`chapter03.rkt` 是有名解释器的维护源，使用 eopl/SLLGEN 实际解析源字符串，不调用宿主 eval。`run` 返回带标签的 ExpVal；`datum` 只转换显示形式，不参与源语言求值。基础值有 num-val、bool-val、list-val、proc-val；默认 if 只接收 bool-val，变量查询总返回 ExpVal。初始绑定为 i=1、v=5、x=10。

| 文件或入口 | 输入与语义 |
|---|---|
| `chapter03.rkt` / `run` | LET/PROC/LETREC 及 3.6–3.18、3.19–3.37 的联合扩充；整数、列表、闭包与相互递归；程序语法见文件 grammar |
| `chapter03_lexical.rkt` / `run/nameless` | 先翻译、再无名求值；支持 cond、pack/unpack、letrec、多绑定和多参数；不支持 traceproc |
| `chapter03_variants.rkt` / `run/bool` | 习题 3.14 的独立 Bool-exp 文法；普通表达式只产生整数；谓词只在布尔语法中出现 |
| 同文件 / `run/letproc` | 习题 3.19 的独立单参 PROC 前端；只允许 letproc 创建过程，不含匿名 proc；letproc 本身不是递归声明 |
| 同文件 / `run/uniform` | 习题 3.22 的全括号语法；所有运算采用 `(operator operand ...)`，内置过程名字也来自环境并可被遮蔽 |
| `test_chapter03.rkt` | 17 组语义回归，含独立计算期望值、参数网格、类型与元数错误、闭包逃逸、递归缓存及优化计数 |

`run` 的独立模式由关键字选择：`#:scope 'lexical` 或 `'dynamic`；`#:environment 'data` 或 `'host`；`#:procedures 'data` 或 `'host`；`#:recursion 'fresh` 或 `'cached`。默认词法作用域、数据环境、数据闭包与查询时重建递归闭包。cached 模式先分配全部单元、建立整组环境，再填好保存这个环境的所有闭包；初始化期间不执行用户主体。两种环境和两种过程表示遵守同一查询/应用接口。

所有严格操作数和实参从左至右求值，实参在调用环境中计算；词法过程体在保存环境加形参的环境中执行。if/cond 只求被选结果。并行 let 的右侧都在旧环境求值；let* 逐项扩展；unpack 要求列表长度与名字数完全一致。并行 let、参数组、unpack、递归组拒绝组内重名，let* 允许逐次遮蔽。列表是 proper list，元素保存完整 ExpVal；cons 的尾部必须为列表，空表 car/cdr 报错。整数 quotient 向零截断，除零报错。print 输出外部值并返回数值 1；traceproc 仅在正常返回时打印 exit。

习题 3.13 使用 `#:integers #t`：仅整数 LET 构造合法，谓词返回 0/1，0 为假。它与默认布尔值语言、3.14 的布尔子文法是独立设计。源题 3.39 提到 pack，但 3.18 只明确给出 unpack；伴读约定 pack 与 list 同义，并在题解明确记录这一补充。

`run/nameless` 的 `#:layout 'flat` 用单槽链，`'rib` 用 frame 链与向量槽位；翻译与求值同步增加空参数 frame。目标 letrec 引用与普通引用分开，前者从递归描述构造保存整组环境的闭包。两种布局在执行时都不按源名字查找。外层链按深度读取仍需线性遍历，词法地址不自动提供常数时间的任意深度访问。

有名入口与无名入口的 `#:trim #t` 仅捕获自由绑定；无名版还生成捕获计划并按紧缩布局重译主体。对静态绑定齐全的程序比较语义；紧缩可能提前发现未绑定自由名字，翻译则会检查死分支的所有名字。有名 letrec 的递归闭包仍保存完整递归环境，紧缩只处理普通过程；无名普通闭包可捕获递归描述。动态绑定不支持紧缩。

无名 `#:optimize 1` 追踪已知过程，直接翻译确定调用而省去操作符查找；`#:optimize 2` 进一步删除没有普通值用途的纯过程构造，并按删槽后的布局重新翻译主体。自由引用使用创建点的绑定身份，实参仍严格求值一次。元数不匹配和未知调用保留普通调用路径；第一类过程用途阻止删除。紧缩与已知过程是分别验证的实验，入口拒绝同时启用。原例三个模式的结果均为 10，闭包构造次数分别为 1、1、0，地址读取分别为 3、2、2。

```sh
racket books/eopl/code/chapter03.rkt
racket books/eopl/code/chapter03_lexical.rkt
racket books/eopl/code/chapter03_variants.rkt
racket books/eopl/code/test_chapter03.rkt
python3 books/eopl/tools/test_chapter03_mutations.py
```

主模块依次打印 3、18、−5、−100、12、120。各例的原书定位、推演和运行结果见[第 3 章正文](../notes/chapter03_expressions.html)。代码只是本章所列语言的实现，源语法、错误与模式边界以本说明及题解共同规定。

## 第 4 章：状态、参数策略与语句

`chapter04.rkt` 维护 SLLGEN 前端、带标签的值、环境/存储和各题联合扩充；`chapter04_explicit.rkt` 在同一 AST 上独立实现纯存储传递，拒绝 EXPLICIT-REFS 以外的构造；`chapter04_statements.rkt` 使用独立 Program/Statement/Expression 文法，语句不伪装成表达值。它们是原创伴读实现，题解逐项说明属于哪一种语言，联合前端不代表原书所有扩充都同时存在。

| 文件或入口 | 输入、返回与选项 |
|---|---|
| `chapter04_explicit.rkt` / `run`、`run/details` | 显式引用、过程/多参数/多 let/互递归、begin/list；run 返回 ExpVal，details 返回 `answer(value,store)`，初始环境 i=1/v=5/x=10 直接绑定值；`#:setref-result 'constant/'rhs/'old` 选择返回 23、右值或最终写入前的旧值 |
| `chapter04.rkt` / `run` | 隐式引用及各题扩充；返回 ExpVal。`#:mode 'value/'reference/'value-result/'name/'need` 指定普通 proc 的策略，默认 value；所有模式保持词法作用域 |
| 同模块 / `run/details` | 返回 `execution(value,store,metrics,events)`；另接 `#:backend 'list/'fixed/'vector`、`#:capacity`、`#:rec 'cached/'fresh`、`#:immutable-let?`、`#:optimize-thunks?`、`#:pairs 'two/'base`、`#:fuel`；默认可增长向量、稳定递归位置、可变 let、未优化 thunk、双位置序对、100000 求值步骤 |
| `chapter04_statements.rkt` / `run` | 语句程序，返回 `statement-result(output,store)`；`#:input` 是输入文本端口，`#:fuel` 限制执行步骤；四个 4.22 原例保持原语法 |
| `test_chapter04.rkt` | 21 组、641 项断言；独立预期、状态历史、操作计数、错误/恢复、有限整数矩阵 |

源语言整数使用宿主精确整数。引用的内部表示是已分配槽位下标，不能与 `num-val` 混用；没有释放位置或垃圾回收。每次 run 建立新 store；初始隐式环境分配 3 槽，显式环境不分配。链表后端保留原书线性操作；fixed 在预分配向量内常数时间分配/读写，耗尽报错；vector 按倍增扩容，读写常数时间，分配为摊还常数时间。初始化和扩容不算作常数时间。

严格子表达式、运算符及各实参均从左至右。多声明 let 的右侧在旧环境求值、状态依次传递，之后创建新槽；重复声明或形参报错。调用先确认参数个数再执行实参，是错误输入的明确约定。默认 letrec 一次分配全部槽、让闭包保存整组环境，再填入，查询不重复分配。fresh 保留原书查询时分配的演示实现，不用于给递归名字赋值的实验。

`set`、`setref`、`setleft`、`setright` 分别返回原书的 27、23、82、83；数组写入的返回值本题未指定，伴读选择 73。数组初始化式只求一次，长度为非负精确整数；数组值保存基址和长度，读取/写入前检查本对象范围，空数组合法但不可索引。复制序对或数组描述符不会深拷贝对象。

`procval`、`procref` 把策略记入闭包，以支持混合调用；`letref` 使用引用左值规则。引用实参可为变量或 `arrayref(a,i)`，嵌套下标在调用时计算一次。按值结果只接受变量实参，进入体前复制到新槽，正常返回时按参数从左至右写回；同一目的槽由后一个参数覆盖，体报错时不写回。`ref x` 扩充允许引用成为表达值，默认按值传参仍为形参创建新槽。

按名/按需对变量实参复用原槽，其他实参新建装 thunk 的槽。thunk 保存实参的调用者环境；强制时使用当前存储。按名重复强制，按需用首次结果替换 thunk。普通 let 仍急切；`lazylet` 的所有新绑定有各自新槽、右侧 thunk 保存旧环境，右侧即使是变量也不引入别名。`#:optimize-thunks? #t` 只提前包装常量和 proc，不提前执行其过程体。源语言没有 catch 或并发；步骤上限用于可复现的非终止实验，不能成为计算结果。

`#:immutable-let? #t` 使普通 let 存直接的 immutable 值，`letmutable` 仍分配可变位置，赋值不可变绑定报错；该题实验与引用参数实验分别运行。`setdynamic` 保存进入时的旧内容，临时改同一位置，退出时恢复，保留其他槽的效果；宿主 dynamic-wind 也保证体抛错后恢复。

语句扩充语法：`read x`；`do Statement while Expression`；`varinit x=e1 y=e2; Statement`；`block` 先列变量初始化、再列 `procedure f(args)=Expression`、再列 `subroutine p(args)=Statement`，最后 `in Statement end`；子程序调用为 `call p(args)`。普通 var 不初始化，读取未初始化槽报错；varinit 顺序初始化，前面名字可见于后面右侧，当前名字的右侧先看外层。block 的所有调用对象共享同一递归环境，变量初始化不在本组调用对象作用域内。过程与子程序是两个带标签值种类，交叉误用报错；两者参数按值。read 只接受非负精确整数 datum，拒绝 EOF、负数、分数和非数字。

```sh
racket books/eopl/code/chapter04_explicit.rkt
racket books/eopl/code/chapter04.rkt
racket books/eopl/code/chapter04_statements.rkt
racket books/eopl/code/test_chapter04.rkt
python3 books/eopl/tools/test_chapter04_mutations.py
```

三组演示输出分别为 `-1/0/11/11`、`3/4/88/-1/0` 和四个语句例的 `7`、`12`、`3/4/3`、`12`。逐步轨迹、全部 42 题、原书图 4.6 的接口校注与各实验条件见[第 4 章正文](../notes/chapter04_state.html)。

## 第 5、6 章：控制、目标语言和转换

[第五章](../notes/chapter05_continuations.html)与[第六章](../notes/chapter06_cps.html)使用已有 Racket 8.17/eopl/rackunit；宿主驱动比较为 C11，同步模型为 Python 3 标准库。运行时、站点技术栈和服务定义不变。

| 文件或入口 | 输入、返回与界限 |
|---|---|
| `chapter05_syntax.rkt` / `parse` | SLLGEN 前端，输出可读的标签列表 AST；联合语法供题解使用，源名字不允许 `%`；LETREC/列表/状态/异常/线程按实际语言模式解释 |
| `chapter05_cps.rkt` / `run-cps` | 独立过程 CPS 核心，含列表、多参数、异常、letcc；返回两个 values：值与指标；`#:representation 'inline/'pair`；不支持存储和线程扩充 |
| `chapter05.rkt` / `run` | 数据帧/寄存器状态、隐式或显式位置、异常、捕获、线程与消息；返回 `result(value,output,metrics,trace,threads)` |
| 同模块 / `translate-callcc` | 保持先值式后目标式的次序，把 letcc/throw 降为 call-with-current-continuation 与普通过程应用 |
| `chapter05_statements.rkt` / `run` | 第4章原语句前端的4.22核心，表达式续文接一个值、命令续文零参数；`#:commands 'data/'procedural`，返回输出值列表；未初始化读取报错 |
| `chapter05_machine.c` | 输入由源码构造的 LETREC AST；模式0零参宿主调用、1真实goto、2数据蹦床；固定容量环境/帧arena，支持输入递减规模0…20000 |
| `chapter05_sync.py` | 显式调度快照模型，演示计数信号量、Mesa条件变量、可复用屏障和JSON消息；私有存储的THREADS解释器在chapter05.rkt维护 |
| `chapter06.rkt` / `cps-program` | 联合源AST/字符串转成CPS-OUT AST；先对词法绑定α改名，再生成带`%`的名字；目标值不通过宿主eval求值 |
| `chapter06_target.rkt` / `parse-target`、`run-target` | 独立目标文法只允许SimpleExp/TfExp；程序先输出目标文本再重解析；返回两个values：值与输出/步数/分配指标 |
| `chapter06_algorithms.rkt` / `algorithm` | 6.4四过程的`data/procedural/inline/register`表示，沿用符号S-list/λ表达式；返回值与唯一结束计数 |
| `chapter06_examples.rkt` | 6.13全部八个原/转换例、6.6六种调用次序；题给扩展使用列表原语与0/1真值，未找到的fnlrgtn约定空表 |
| `chapter06_transforms.rkt` | `defunctionalize`将续文或所有过程改为整数标签列表；`atomicize`保留输入全部名字，为原语操作数选择未占用的新名字；`anf`、`canonical-target`用于ANF和α等价比较；过程数据化范围为§6.3纯CPS-IN及列表 |
| `chapter06_outputs.json` | 八个源输入与实际生成的完整CPS-OUT文本；独立解析和执行结果由examples模块重新核对，HTML副本逐段同步 |
| `chapter06_register.rkt` | `compile-register`生成标签指令表；`run-register`用PC/env/val循环执行，运行时闭包是代码标签和定义环境记录 |
| `test_chapter05_06.rkt` | 11组语义回归：独立数值基准、不同表示、正常/错误/恢复、时间片矩阵、效果顺序、源码/目标重解析、90个生成程序及ANF结构 |
| `test_chapter06_scheme.rkt` | 给6.3未知函数具体CPS定义，实际执行全部七式并比较独立答案 |

`chapter05.rkt` 默认词法作用域与纯绑定，`#:implicit? #t` 使所有新绑定分配位置。支持 `#:scope 'lexical/'dynamic`、`#:driver 'loop/'thunk`、`#:handler-lookup 'search/'cached`、`#:exception-mode 'abort/'resume`、`#:trace?`、`#:fuel`。默认fuel为2,000,000个状态转移；超限是明确错误，不是结果。操作数与实参严格先运算符、再从左至右；多let的RHS用旧环境。初始i/v/x为1/5/10，另绑定call-with-current-continuation。除法对整数向零取整；错参数个数与除零分别沿语言异常通道传1001/1002；其他类型错误明确失败。print返回38、set返回27、setref返回23。

`#:private-store? #t` 为习题5.56在线程记录中保存私有位置集合，仍使用同一THREADS字符串前端。spawn与send以memo复制可达的引用、列表、闭包环境；别名在接收者内部保持，自引用位置和递归闭包先登记占位再填充。变量及显式引用的读取/写入均验证当前存储所有权；消息不会保留指向发送者位置的引用。`run-private-counter` 使用三条增量消息返回3，`private-counter-program` 是正文同步的完整输入。复制复杂度随可达数据图增大，当前朴素环境列表的路径与字段也参与复制成本。该模式使用词法作用域；跨存储传递mutex或捕获续文报错。动态作用域组合明确拒绝。Python快照模型作为同步机制的另一个可运行说明保留。

线程参数 `#:quantum` 为正整数，计时只在apply入口；缺省1,000,000。`#:preserve-ticks? #t` 让yield保存剩余额度，耗尽才补新片。`#:thread-ids? #t` 时主ID0、父ID−1，spawn父子都取得子ID；未开启时沿原书父73/子28。`self()`/`parent()`、`yield()`、`kill(id)`、`send(id,value)`、`receive()`是明确的习题语法选择。每个线程有独立帧栈；默认模式共享存储，私有存储模式分别持有自己的位置集合。消息FIFO。wait/signal按书中binary semaphore语义，不追踪owner；signal直接移交许可且保持锁关闭。主结果与blocked数同时返回；若仅剩阻塞线程且主结果尚无，则报死锁。kill仅删除排队线程，既不杀正在运行的自身，也不自动释放此前已持有的锁。

`cps-program` 支持 `#:order 'left/'right/'operands-first`、`#:share-if?`、`#:send 'call/'let/'substitute`、`#:fuse-let?`、`#:exceptions?`、`#:implicit?`、`#:immutable?`。默认左至右、共享if续文、已知续文应用化为let、融合非简单let。右至左改变效果次序，实参位置保持。替换优化针对纯SimpleExp，名字已按绑定身份改名。隐式位置先降为显式位置再CPS化，可变递归组先全部分配再安装闭包；不可变分析也按绑定身份。隐式引用模式也为letcc/catch引入的源绑定建立所需位置，或按不可变分析直接保存值；对应原始续文/异常参数使用独立鲜名。异常模式给每个用户过程同时传K/H，重抛用外层H；它不额外把所有宿主类型错误自动改成源异常。捕获控制不会回滚store。

6.31/6.32的纯过程数据化保留整数标签、自由变量顺序与递归组重建；不能把后续newrefk/derefk的过程参数在没有同步改目标接口时直接当作数据记录传入。6.33标签化运行器本身支持显式效果。ANF固定求值次序但保留直接调用，不承诺迭代控制行为；CPS闭包、环境、任意精度整数及C arena的总占用也不由“控制栈有界”自动限定。

```sh
racket books/eopl/code/test_chapter05_06.rkt
racket books/eopl/code/chapter06_examples.rkt
racket books/eopl/code/test_chapter06_scheme.rkt
racket books/eopl/code/chapter05_statements.rkt
python3 books/eopl/code/chapter05_sync.py
cc -std=c11 -O0 -fno-optimize-sibling-calls -Wall -Wextra -Werror books/eopl/code/chapter05_machine.c -o /tmp/eopl-machine
/tmp/eopl-machine 0 1000
/tmp/eopl-machine 1 20000
/tmp/eopl-machine 2 20000
```

C数值运算采用long，正式驱动例只做有界递减；自行更换AST时必须另核对溢出边界。arena不做垃圾回收，只保证容量内的运行；所有标签/环境/帧读写另用ASan/UBSan运行检查。程序输出与原书图6.1/6.2的校注在正文中相邻说明；来源、运行、浏览器与本地包证据单独维护。

## 第7章：类型检查、推导与求值

维护源为chapter07.rkt、chapter07_types.rkt、chapter07_syntax.rkt和chapter07_examples.rkt。现有Racket8.17运行，直接用字符串输入；不把对象程序交给宿主eval。`check`强制具体参数/递归结果标注，采用结构相等；`infer`缺省单态，问号或省略标注各分配一个鲜变量。初始类型环境i/v/x均为int，运行值依次1/5/10。

```racket
(require "chapter07.rkt")
(check "proc(x:int) -(x,1)") ; (int -> int)
(infer "proc(f) proc(x) -((f 3),(f x))") ; ((int -> int) -> (int -> int))
(infer "proc(x)x") ; (a0 -> a0)
```

`infer-details`返回类型、带AST上下文的约束、替换快照和计数；`external`只对真实类型变量结点规范重命名，保留重复位置关系。`#:engine`可选eager/lazy/memo/walk/global/vector，默认eager；`#:two-phase? #t`先收集单态约束再统一求解。eager扩展时回填旧右侧；lazy追完整无环链，memo在一次应用内缓存；walk只解引用根再递归；vector直接索引并路径压缩。global入口清空全局关联表，不能交错或并发使用多个分析器。关联表、追链、整树遍历和发生检查的成本分别计算，向量直接查找的常数时间不代表整次推导常数时间。

并行let的所有右侧在旧环境分析，再同时扩展正文；多元过程核对完整参数数量。递归组先预绑定全部签名，逐个统一正文与返回类型，在组内保持单态。类型语法为int/bool/void、`(T1 * ... * Tn -> T)`、`pairof T * T`、`listof T`、`refto T`；零参数过程也可用`(-> T)`。CHECKED空表写作`emptylist_T`，INFERRED可省略；list要求至少一个元素，空表用emptylist。`pair`是newpair的别名。赋值返回27/int；可变序对模式`#:mutable-pairs? #t`下setleft/setright返回82/83及int；setref返回不透明unit/void。错误类别分别表示解析、标注、未绑定、参数数量、类型冲突、发生检查和不支持的模式。

`#:polymorphism 'copy`在定义时环境中重新分析let右侧，避免使用点捕获；右侧即便未使用也先检查一次。`'w`分析一次，仅泛化FV(当前类型)减FV(当前环境)，各使用点实例化量化变量；过程参数和递归组保持单态。两种多态模式默认启用保守值限制：数字/变量/过程/空表及非扩张分量构成的不可变数据可泛化，newref、赋值、未知调用以及可变pair分配不可泛化；已泛化let绑定禁止赋值。纯语言可显式设`#:value-restriction? #f`观察不受该限制的W；含存储时关闭会接受7.30反例，运行确实出现类型错误。

`evaluate`忽略标注，采用词法闭包、按值及从左到右求子式；引用/序对用显式对象包装宿主box。整数为Racket精确整数。fuel必须为正的精确整数，默认100000，耗尽单独报告，不视为类型错误或非终止证明。空表访问也单列错误；本章类型安全并不排除它。`run`先推导后求值，语义契约的见证可单独调用evaluate。

```text
racket books/eopl/code/chapter07.rkt
racket books/eopl/code/chapter07_examples.rkt
racket books/eopl/code/test_chapter07.rkt
python3 books/eopl/tools/test_chapter07_mutations.py
```

测试覆盖原题13式、标注检查/错误顺序、词法捕获、并行let、互递归、多参数、复合数据与别名、间接循环、替换组合/缓存、α重命名、多态map及值限制。20种浅层类型结构的合一成功解逐一回代；拒绝例另以六种有限基型赋值枚举核对，这个有限域不冒充任意类型的一般完备证明。故障注入先通过未修改见证，再确认错误版本能正常加载并被独立断言拒绝。规则、完整题解与程序阅读副本见[第七章正文](../notes/chapter07_types.html)。


## 第8章：模块、接口与抽象类型

阅读入口为[第八章](../notes/chapter08_modules.html)。chapter08.rkt提供check、run、run/trace、compare-interfaces；chapter08_syntax.rkt维护模块/接口和表达式文法，chapter08_examples.rkt维护原书例子与完整习题实现，test_chapter08.rkt维护独立期望。运行需要同目录的chapter07_types.rkt与chapter07_syntax.rkt；均可从章节下载区取得。

默认使用CHECKED与原书有序子序列匹配。无序模式传入#:unordered? #t，只改变已展开声明的匹配顺序；推导模式传入#:inferred? #t，同一次程序检查共享约束状态。点号、多参数let/proc/letrec、模块体let/letrec、局部/嵌套模块、多参数模块过程、一般模块体应用和命名接口已实现。接口标签及同一声明组中的名字要求唯一；模块、普通值、类型与接口名字分别查找。

限定类型展开后引用不可由源程序制造的身份；实现比较知道表示，客户端公开视图重新封装opaque声明。模块过程参数逆变、结果协变，绑定先alpha对齐；应用依赖结果替换为实参真实导出的类型。命名接口保存定义环境，类型环境插入入口集中规范化，底层环境构造留在实现模块内部。

#:dependencies 'depends-on要求模块体和程序体显式声明可见模块；空子句表示不依赖其他模块。#:dependencies 'imports采用按声明顺序可见的惰性模块、new/busy/done状态与单次缓存。import与imports同义，按原题允许叶模块省略空子句；省略表示空导入。未导入模块仍静态检查但不执行。run/trace返回execution，分别保存type、value、output及模块求值次数。print只接受整数，记录输出并返回整数1。

普通求值为按值、从左到右，整数任意精度；步数预算必须为正的精确整数，默认100000步，耗尽报告fuel，不证明不终止。错误种类区分parse、annotation、duplicate、hidden、interface、mismatch、arity、dependencies及运行期错误。原书to-int采用取pred到零的算法，保证终止需输入代表非负整数；from-int、加法、乘法与相等性另处理正负整数。代数正确性仍以前提“输入算术实现满足整数表示定律、各原语调用终止”为准。表的空查找缺省值从内容模块false取得，以直接支持题面的mybool。

执行：racket chapter08.rkt；racket test_chapter08.rkt。书级完整检查另执行test_chapter08_inputs.py，直接从最终页面取16编号例子及原题代码，并分别记录完整程序和未完成骨架的解析结果；test_chapter08_mutations.py用独立见证拒绝可正常加载的语义错误版本。



## 第9章：对象、类、继承与方法调用

阅读入口为[第九章](../notes/chapter09_objects.html)。同一目录保存chapter09.rkt、chapter09_syntax.rkt、chapter09_runtime.rkt、chapter09_types.rkt、chapter09_compile.rkt、chapter09_examples.rkt和test_chapter09.rkt，使用既有Racket8.17标准库/json/rackunit，无本书其他章节源码依赖。

```sh
racket chapter09.rkt
racket chapter09_examples.rkt
racket test_chapter09.rkt
```

主程序返回5；原书图9.1为`((3 -3) (5 -5))`，9.2为12，9.4为`(101 102 101 999)`，9.6为33；图9.12的检查类型为`(listof int)`，运行值为`(12 100)`。图9.8原有省略体保留来源；figure9-8-complete是明确补全的伴读程序，返回`(11 22 7 8)`。

公开入口为`run source #:typed? #f #:check? #t #:options (hash)`、`run/trace`、`check source #:options (hash)`和`check/compiled`。run返回原始表达值，对象/过程为专门的宿主记录；trace另记录输出、调用事件、逻辑计数和类环境。check只做TYPED-OO类型检查，check/compiled返回类型、已改写程序与静态类环境。原书全部Scheme解释器未原样移植执行，实际对象为伴读语法/解释器/检查器及最终页面输入。

本章无类型版本的变量、字段和形参使用可变位置，let右侧并行可见、按文本从左到右求值；普通过程先操作符再实参。send先按文本次序求实参，再求接收者；new先实参、再分配/初始化对象。该顺序为伴读明确约定。无类型set返回27，有类型set为void；print要求整数，记录输出并返回1。精确整数运算，默认100000步预算，耗尽报告fuel，不作为不终止证明。

类继承默认单父类且父类先声明；全局方法体在全部类描述符建立后才翻译/执行，可以引用后声明的类。普通方法不捕获主程序的普通局部变量；字段帧使用宿主的声明视图，继承方法保持原宿主。self为真实接收者，super从词法宿主的父类查找；同名字段各有身份和位置。访问级别依据调用处宿主判断；final在类构造时拒绝覆盖。字段未初始化读取报告uninitialized。

源语法包括new/send/super/self、fieldref/fieldset、superfieldref/superfieldset、named-send/named-fieldref/named-fieldset、private/protected/public、final method、static变量、staticmethod、`letclass C = extends Parent ... in exp`，以及原书多参数过程/递归、列表和begin。局部类的对象保存类身份及定义环境；静态初始化一次，按顺序只看已初始化静态绑定和局部声明外层环境，不提供实例字段或self。`emptylist _ Type`为有类型空表；有类型list要求非空且元素类型相同。普通if接受相同或一方为另一方子类型的两个分支，结果取较宽类型；不实现一般联合类型。

选项名及值：

| 选项 | 值与含义 |
|---|---|
| object-class | name默认；record直接保存类描述符；两者保持局部类身份 |
| overload? | 默认#f；#t按方法名与参数个数重载，构造器同样适用 |
| mangle? | 默认#f；#t生成m:@n名字及零参数构造桥接，目标仍是原CLASSES表达式；原题假设:@不出现在用户方法名中 |
| stable? / method-lookup | #t原槽替换新名追加；查询默认linear，也可hash。计数是显式键比较或哈希查询次数，不是CPU时间 |
| lexical? | #t对原CLASSES/TYPED-OO计算深度/下标，运行帧不保留名字；帧内向量O(1)，帧链仍按深度遍历。静态变量/字段初始化扩展使用独立有名模式 |
| direct-super? / named-slots? | #t分别生成实际方法引用、指定类向量槽节点；方法选择常数取项，其他调用成本另计 |
| host-fields-only? / static-self? | 分别启用9.7仅宿主字段、9.14直接self发送按宿主分派的替代语义 |
| multiple? | #t为无类型CLASSES开放多父类：相同声明字段按身份共享；不同父同名字段须限定，方法冲突须子类覆盖；super取第一父类 |
| initialization | textbook默认保留构造器签名豁免；new-only拒绝send/named-send/super对initialize的显式调用，允许new隐式调用 |
| casts | runtime默认；related对两个具体类要求祖先关系，接口操作数保留可能成功的运行检查。目标总要求实际类，接口不能作目标 |
| field-initializers? | #t要求每个实例字段有表达式，类型符合声明；表达式只见宿主前序字段及静态成员，不见self/super与后序字段 |
| fuel | 正整数，默认100000；非法选项值与未知选项名报告option |

TYPED-OO先收集所有类型名，验证完整继承关系的声明顺序与父节点种类，再比较全部签名，最后查方法体、覆盖和接口履约。这样，非法自继承不会在前向类型比较中造成无限循环。过程参数逆变/结果协变；listof在子类型关系中保持不变。覆盖须保持static/dynamic种类、参数/结果兼容和不收窄访问级别，initialize仅豁免覆盖签名比较，其自身方法体仍须符合声明。类须有initialize；接口要求public动态方法，接口继承合并全部要求并拒绝不兼容冲突。类型名字可以引用后声明的类，extends仍有声明顺序。

静态方法调用在类型检查阶段固定到接收表达式的静态类；动态调用保留按实际对象选择。字段访问同样固定静态字段视图，避免子字段遮蔽类型不同导致错位。类型检查不保证基本版字段已初始化，不保证行为不变量和终止；显式initialize在textbook模式保留原书限制，new-only提供额外拒绝。原题9.37的`method void m1()12`被字面拒绝，示例仅修正为int后得到`(12 21)`；9.34的类祖先论证不直接适用于接口操作数。

无类扩展：`newobject m=proc(...)... endnewobject`建立共享环境的闭包对象，`getmethod(obj,m)`取得绑定方法；`newobject extends parent ...`共享父闭包状态，并把继承调用的self重新绑定到子对象。原型采用`emptyobject`、`extend proto field x=exp method m(...)exp endextend`和`clone proto`；字段位置浅复制，方法模板保留词法环境与宿主字段身份。局部参数/变量遮蔽字段，方法声明时可见字段遮蔽外层词法变量；外层位置与字段内对象仍可共享。闭包/原型使用无类型入口，TYPED-OO不提供它们的类型系统。

9.30明确增加string字面量、concat与number-to-string。多重继承采用共享祖先，不声称同时实现重复祖先布局；名字改编和无名翻译的适用语言及选项边界如上。错误按parse、annotation、duplicate、unbound、object、class、field、method、arity、access、final、ambiguity、type、override、dispatch、initialize、initialization、interface、cast、compile、fuel、option等kind报告。有限结构/整数回归、操作计数和一般语义论证分别记录，详见T064与review/ch09.json。

## 附录 B：实际 SLLGEN 与算术解释器

将[appendix_b.rkt](appendix_b.rkt)、[test_appendix_b.rkt](test_appendix_b.rkt)及[sllgen_guard.rkt](sllgen_guard.rkt)置于同一目录，以Racket8.17及其eopl/rackunit执行：

```sh
racket appendix_b.rkt
racket test_appendix_b.rkt
```

扫描器、解析器与数据类型由eopl的SLLGEN生成。parse-base对应B.1，parse-variables对应B.4，parse-unary对应B.5；calculate默认unary模式，也可用#:mode 'base/'variables/'unary。数字token仅含无符号数字，负号在因子语法中递归处理；加减层、乘除层分别左折叠，除法使用精确有理数。可选环境是符号到精确有理数的关联表，同名时第一项生效。未绑定、除零和语法/字符错误均明确失败。公开算术字符串入口先检查全部字符，防止本机SLLGEN把1@2只识别为合法前缀1；百分号注释内部不受算术字符限制。

scan-statement/parse-statement重现原书两语句块；parse-terminated/parse-separated分别表示逐项分号终结与项间分隔。parse-bindings和parse-parallel展示重复字段与嵌套平行列表；原文法接受长度不等的并行赋值，示例仅解析，执行还需独立语义检查。arithmetic-repl采用实际SLLGEN流解析与make-rep-loop，额外以分号终结每个表达式；以包装端口逐字符校验流输入，拒绝把未知字符当作EOF；再只把精确的干净EOF开始符号错误转为正常结束，残缺输入仍报错。原书p.386流解析器输出的token/AST用词校注见source_issues.json。

附录页面输入直接提取运行，独立回归核对优先级、结合性、变量、负号、无效输入和生成器列表结构。有限测试和原书解答的语义论证分别保留，见T065。

## 输入完整性与习题5.57同步扩展（I066，2026-10-25）

第3–6章和附录B的SLLGEN字符串前端依赖同目录的[sllgen_guard.rkt](sllgen_guard.rkt)。它使用对应词法规格及文法字面量逐token验证整个输入，再交给实际SLLGEN；未知字符、孤立标识符后缀或未匹配的多字符记号均拒绝，不能把合法前缀当成完整程序。源语言百分号注释、CPS-OUT标识符中的百分号分别按各自规格处理。附录B流REPL仍使用自己的流端口保护。第4章run/details和第5章run的fuel都必须是正的精确整数，预算耗尽单独报错。

习题5.57在chapter05_syntax.rkt与chapter05.rkt内实现三种同步机制，使用现有THREADS的run、线程记录、续文与就绪队列：

- semaphore(n)要求非负精确整数；down(s)无许可时FIFO阻塞，up(s)优先直接移交许可，不额外增加计数。返回值分别52、53。
- condition(m)绑定一个mutex。condition-wait(c)在一条转移中入队并释放该锁，恢复时先重新取锁，再返回52；condition-signal(c)令队首就绪并返回53，空通知不累计。调用者按Mesa方式持锁检查谓词并循环等待；mutex沿用原二元信号量模型、不跟踪owner，运行器只拒绝等待时锁明显未关闭的情况。
- barrier(n)要求正精确整数；barrier-wait(b)凑齐固定人数才清空本代队列并放行全部线程，返回从1开始的代号。

kill同时清理新增队列及条件等待者重新取锁的mutex队列；已取消的屏障到达者不计数，参与人数不缩减，需有替补到达才能完成该轮。主线程尚无值且仅剩阻塞线程时报告死锁；已有主结果时返回blocked计数。跨私有存储复制同步对象拒绝。三个完整输入常量为semaphore-program、condition-program、barrier-program，使用#:implicit? #t与#:thread-ids? #t；q=1–30时分别返回(2 0)、45、(1 2)，结束时blocked均0。条件例的45来自通知后仍持锁的生产者最终写入，区别于Python简化例的44。

chapter05_sync.py保留为生成器比较模型；必要执行与检查均在Python普通及-O模式运行，观测结果一致。正文3.43–3.44、5.57、6.31–6.33的四段完整复现实例由tools/test_review_inputs.py从阅读镜像提取后执行；输入/预算/调度回归由tools/test_review_repairs.rkt执行，均接入书级完整检查。

6.31的续文数据化使用生成名字的独立格式：用户标识符α改名为`k%编号`等，编译器续文形参为`k%%编号`（双续文模式的错误参数为`h%%编号`），分支连接点为`join%%编号`。源字符串标识符不能含百分号，因此用户名k/h/join不会被误认；AST输入遵守同一源标识符契约。defunctionalize接收本转换器的纯CPS-IN及列表输出。回归覆盖普通/递归过程、高阶形参、非简单let结果及捕获值，并比较目标文本重读与寄存器执行。

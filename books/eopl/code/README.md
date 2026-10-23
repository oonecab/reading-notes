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

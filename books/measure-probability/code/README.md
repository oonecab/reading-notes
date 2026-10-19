# 测度、乘积空间与独立求和程序

程序对应[第一章有限可测空间](../notes/chapter01_measurable_spaces.html#finite-model)、[简单函数逼近](../notes/chapter01_measurable_spaces.html#simple-model)和[第二章外测度例子](../notes/chapter02_measure_spaces.html#outer-model)，以及[第三、四章的积分与条件期望](../notes/chapter03_integration.html#integration-model)、[第五、六章的转移核与独立求和](../notes/chapter05_product_spaces.html#product-model)。Python 仅用标准库；C 使用严格 C11。下载源文件后可独立运行。

```sh
python3 finite_spaces.py sigma 4 3
python3 finite_spaces.py outer 3 3:1 6:1 7:2
python3 simple_approx.py 13 10 2
clang -std=c11 -Wall -Wextra -Werror -pedantic finite_spaces.c -o finite_spaces
./finite_spaces outer 3 3:1 6:1 7:2
clang -std=c11 -Wall -Wextra -Werror -pedantic simple_approx.c -o simple_approx
./simple_approx 13 10 2
```

点编号从 0 开始，整数的第 i 位表示是否包含第 i 个点。四点空间的 3 是 {0,1}，12 是 {2,3}；生成元 3 产生原子 [3,12] 和集合 [0,3,12,15]。空生成元产生最粗的 sigma 域。`outer` 的 `mask:cost` 表示可用覆盖及其非负整数费用；输出中 `null` 表示无法覆盖所致的正无穷。三点反例得到外测度 [0,1,1,1,1,2,1,2]，Caratheodory 可测集只有空集和全空间。

`simple_approx` 的输入为 p、q、n，计算非负有理数 p/q 在二进网格上的向下取整并截断到 n。输出 `grid/scale` 为精确值；例如 13/10、n=2 输出 5/4。无限值由正文单独解释，程序仅处理有限有理数。

有限模型限制 1≤点数≤8、0≤费用≤1000000；C 版最多 256 个覆盖选项，Python 版沿用这一输入边界。截断模型限制 0≤p≤1000000、1≤q≤1000000、1≤n≤20，使 C 无符号整数中间结果安全。两个入口只接受 ASCII 十进制整数，拒绝前后空白、加号、下划线和 Unicode 数字。`finite_spaces` 的词法允许负号，数值仍须非负（因此 `-0` 等同 0）；`simple_approx` 使用无符号十进制词法，连 `-0` 也拒绝，与 C 入口一致。覆盖选项的 mask 字段最多 31 字符。非法输入退出码为 2、无标准输出，错误写入 stderr。有限原子枚举和结果排序按常规 O(m log m) 排序计算，上界为 O(k·n+n·2^n)，外测度 DP 与判别为 O(k·2^n+4^n)，n 是点数、k 是选项数；空间 O(2^n)。计算检验具体模型，正文证明负责一般结论。

源文件下载：[finite_spaces.py](finite_spaces.py)、[finite_spaces.c](finite_spaces.c)、[simple_approx.py](simple_approx.py)、[simple_approx.c](simple_approx.c)。

## 积分、分解与条件期望

第三组源文件为 [finite_integrals.py](finite_integrals.py) / [finite_integrals.c](finite_integrals.c)，正文从[第三章积分计算](../notes/chapter03_integration.html#integration-model)连接到[第四章分解与条件均值](../notes/chapter04_signed_measures.html#finite-conditional)。

```sh
python3 finite_integrals.py 1,2,0,1 -2,1,9,4 0,0,1,1 2,-1,3,0
clang -std=c11 -Wall -Wextra -Werror -pedantic finite_integrals.c -o finite_integrals
./finite_integrals 1,2,0,1 -2,1,9,4 0,0,1,1 2,-1,3,0
```

四个参数依次为权重、函数值、信息块标签、符号质量。每个参数由逗号连接 ASCII 整数，允许负号，不接受加号、空白或小数；单参数最多 127 字符，四向量等长且有 1—8 点。权重 0—1000，函数值与符号质量 −1000—1000，标签 0—n−1，权重总和须正。非法输入无标准输出，错误写到 stderr，退出码 2。函数 `calculate` 供已验证输入使用，独立命令入口负责参数校验。

所有概率量以权重总和归一化；积分本身仍按未归一化权重。分数输出 `[分子,分母]` 已约分且分母正。本例积分 4、正负积分 6 和 2、二阶积分 22、期望 `[1,1]`。条件均值依次为 `[0,1],[0,1],[4,1],[4,1]`，同一信息块内逐点相同；整块为零质量时选常数零。零质量点若处在正质量块中仍须取该块的均值。

Jordan 正负质量是逐点的正负部分。Lebesgue 分解相对于输入权重：正权重点构成绝对连续部分，零权重点上的符号质量构成奇异部分。`density` 只表示绝对连续部分的密度；本例为 `[2,1],[-1,2],[0,1],[0,1]`，奇异质量向量 `[0,0,3,0]`，故 `absolute_continuous=false`，全变差总量 6。

逐点累加后，每点扫描其信息块，时间 O(n²)、空间 O(n)。二阶积分上界 8×1000³=8×10⁹，使用 C 的 `long long`；解析每次累加后立即检查 1000 上界，下一次乘十前已有界。测试中的子集穷举属于独立基准，不影响示例算法复杂度。测试还枚举所有信息事件，检查条件积分、可测性、L2 投影，以及 Jordan 上下确界和密度恢复，普通构建与 ASan/UBSan 构建分别运行。

## 核积分与独立和

第四组源文件为 [product_limits.py](product_limits.py) / [product_limits.c](product_limits.c)。[第五章](../notes/chapter05_product_spaces.html#product-model)完整显示源码，[第六章](../notes/chapter06_independent_sequences.html#limit-model)接续二项卷积与标准化特征函数。

```sh
python3 product_limits.py joint 1 1 3 4
python3 product_limits.py binomial 4 1 2
clang -std=c11 -Wall -Wextra -Werror -pedantic product_limits.c -lm -o product_limits
./product_limits joint 1 1 3 4
./product_limits binomial 4 1 2
```

`joint p a b m` 表示 P(X=1)=p/m，P(Y=1|X=0)=a/m，P(Y=1|X=1)=b/m。1≤m≤1000，0≤p,a,b≤m。联合质量分子按 (0,0)、(0,1)、(1,0)、(1,1) 排列，共同分母 m²；行列边缘仍使用该分母。`expectation_numerator` 和 `iterated_numerator` 都是 Z=X+2Y 期望的分子，分别直接逐点和先核后初始质量计算。`independent` 精确检查四格交叉乘积。示例输出质量 [9,3,1,3]/16，边缘 [12,4]/16 与 [10,6]/16，两个期望分子均为 16，独立性为 false。零概率行的核可任意指定，它不影响联合律。

`binomial n p m` 令 0≤n≤16，1≤m≤8，0≤p≤m。每一步将已有计数 k 的整数质量分别乘 m−p、p，送到 k 和 k+1，分母乘 m。输出二项质量分子与共同分母 mⁿ、均值分子（同分母）、方差分子 np(m−p) 和分母 m²。n=4,p=1,m=2 时质量为 [1,4,6,4,1]/16、均值 2、方差 1。n=0 是空和，质量 [1]、均值方差为零。p=0 或 p=m 也退化；这些情况 `normalizable=false`、`standardized_cf_t1=null`，不会做零标准差的除法。非退化时另输出 t=1 的标准化特征函数实虚部，使用 double，独立特征函数乘积基准的绝对误差阈值为 2e−12。

质量与矩的分子为精确非负整数，不自动约分。最大 mⁿ 为 8¹⁶=2⁴⁸，均值分子不超过 16·2⁴⁸=2⁵²；C 使用 unsigned long long，联合四格交叉积不超过 10¹²。数字解析先限制 10 字符，每次累加立即检查上界，下一次乘十前已有界。只接受无符号 ASCII 十进制串，包括零及前导零；拒绝负号（含 −0）、加号、空白、下划线、小数及 Unicode 数字。非法输入退出码 2，无标准输出，错误写 stderr。

核模型是固定四点，时间和空间均 O(1)；二项卷积时间 O(n²)、空间 O(n)。独立回归不只比较 C 与 Python：联合分布用精确分数与全部原子检验，期望另用层集尾和；二项质量用组合数公式与 n≤6 时的全部二进路径枚举；浮点特征函数用独立单步乘积公式。另保留错误输出变异、边界输入、原书截断引理及经验分布尺度的反例。有限程序的验证范围与无穷序列定理证明分别记录。

## 校验

从仓库根使用 `python3 tools/project.py check --book measure-probability`。维护源在本目录，受控 HTML 及兼容镜像由 `tools/sync_code.py --write` 按 `programs.json` 和 HTML 解析边界同步；不带 `--write` 时只校验；独立基准、编译与执行日志写入忽略目录。

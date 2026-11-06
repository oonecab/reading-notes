# SICP 程序说明

第一章教学维护源是[chapter01.rkt](chapter01.rkt)，本次实际执行宿主为Racket8.10，依赖仅内置racket、rackunit和json。过程体用Scheme风格，模块、参数保护、迭代上限和测试驱动是Racket适配。页面代码片段及完整副本由书级检查逐字比对；改源码后运行`python books/sicp/tools/sync_chapter01.py --write`更新受控阅读副本，再运行`node scripts/sync-legacy.mjs --write`。同步器不改题面或实验数据。

在仓库根目录执行：

```text
racket books/sicp/code/test-chapter01.rkt
racket books/sicp/code/benchmark-chapter01.rkt
racket books/sicp/code/experiments-chapter01.rkt
python books/sicp/tools/check_notes.py
```

[test-chapter01.rkt](test-chapter01.rkt)包含8组实际测试，内部遍历多组输入：枚举比较/带符号乘法、标准库幂/根对照、独立线性Fibonacci、全底数素性反例、精确多项式积分、非结合折叠、函数组合及数值失败保护。1.5/1.6的无界发散由规则推导，不启动无限程序；1.6另实际检查普通过程的两参数均求值。1.13和增长阶属于数学证明，不冒充运行可证。

[benchmark-chapter01.rkt](benchmark-chapter01.rkt)固定12个试除确认的素数，预热后取5个1000次批次的中位数，使用单调毫秒钟换算微秒/次；Fermat20轮、种子20261106。计时包含循环/调用/随机选底，速度比不是测试阈值；重复运行应保存新记录并人工重读解释，不能只更新哈希。

[experiments-chapter01.rkt](experiments-chapter01.rkt)输出1.36完整轨迹、Wallis截断值和1.45有限阻尼实验；[chapter01-results.json](chapter01-results.json)保存本次真实输出和源哈希。数值停止、差分步长、四位精度和折叠方向见[第一章对应题解](../notes/chapter01_procedures.html#exercises)；维护口径另记于书级页面说明，源文件表达相同常数。

输入约定：快速幂指数为非负整数；递归乘法的乘数非负，迭代乘法另归一化负乘数；Fibonacci下标非负；Pascal行/列从0起。区间累积要求next严格增大且最终越过上界。sqrt拒绝负数，cube-root允许负数，nth-root只允许负数的奇次根。newtons-method、fixed-point及反复阻尼均可能失败，失败不会返回伪成功末值。Fermat演示随机接口只用于本章已测的小整数范围，避免跨出宿主random上界。固定底数的Miller–Rabin通过不意味着任意大小输入确定为素数。

`miller-rabin?`接收明示底数，`miller-rabin/random?`接收正整数轮数及可注入随机源；默认随机源与Fermat具有相同的宿主边界。见证回归用指定底数稳定检查2047的底数2通过、底数3失败，以及9的最终余数失败；均匀独立抽样的概率解释与这些确定性测试分别说明。区间素数搜索允许指定上界，`timed-prime-test`提供单次显示接口，正式计时仍采用批量中位数。

正文的14组“教材输入”是用于读题的原始片段与基本约定，保存于独立清单；它们不是第二份执行维护源。题目通过精确锚点引用，完整可运行版本与改进的数值/边界语义仍以本目录源码为准。

原书解释器、寄存器机器模拟器和编译器尚未展开；第一章执行结果不代表这些后续系统已验证。

# SICP：页面、来源与组件

遵循 [RN-001](../../../docs/reading-notes-standard.md) 与 [RN-002](../../../docs/reading-presentation-standard.md)。I073完成地图/引言，I075按用户续写要求展开第一章，第二章以后延后。

| 页面 | 原书范围 | 本批题解 |
|---|---|---|
| [全书地图](book_overview.html) | 五章及22主要节；目录 iii–viii / PDF3–8 | 无 |
| [引言：前言与两版序言](preface.html) | Perlis xiii–xviii/PDF13–18；第二版 xix–xx/PDF19–20；第一版 xxi–xxiv/PDF21–24 | 无 |
| [第1章：用过程构造抽象](chapter01_procedures.html) | pp.1–106/PDF29–134，§1.1–1.3全部18二级节 | 1.1–1.46，共46题 |

唯一正文在 `src/content/books/sicp/`；notes HTML 是共享资源展开后的兼容镜像。复用EOPL地图/序言的reading-base、reading-content-2、reading-navigation、reading-annotations、reading-components和reading-typography。第一章采用reading-annotations-nested控制器；根契约登记全部子节及父节，防止只检测章级注解。地图第一节点直达第一章，其余四个保留章意。程序阅读副本由独立Python检查与code/源逐字比对。

`source_manifest.json` 保存身份、分段页序和许可；`source_inventory.json` 从 PDF 书签与正文题号独立提取。PDF82 的1.13被公式打断，单独核对；PDF194 第二个2.38是2.39题干里的引用，去重而不新增题。所有原文入口为 `../sicp.pdf#page=N`。

`questions_ch01.json`保留维护用完整原题HTML/文字、原编号和本仓库PDF页序；原题给定程序与公式完整进入中文题面，英文整题不发布。1.13从PDF图像核对Binet式；1.28的反例校注与原题分开。计时与数值结果来自code/中的实际程序，结果文件绑定其源哈希。

`chapter01-inputs.json`独立保存14组基本约定/教材引用片段和34题的精确依赖入口，核对PDF中的定义位置；original_code保留转写原文，code仅去掉每行末尾的空格/制表符，保留缩进、换行与全部记号。给定程序采用同一行尾规范后逐字比对，测试同时拒绝记号与缩进变化。教材片段在对应正文原位提供，保持原始域假设和局限；不要把它们与code/中带保护的执行适配混同。Fibonacci两种同名定义是替代版本，源码模块只加载独立实现；原书prime?在这里按n≥2使用，执行源另明确拒绝1。所有被引用的题面输入还由根问题散列绑定。

第一章计算约定：原始sqrt用平方残差0.001；改进sqrt/立方根/高次根以相邻猜测相对差≤10⁻¹²（或浮点相等）停止，默认最多2000步，零单独处理，非有限值拒绝。原书fixed-point比较绝对步差<10⁻⁵，初值与完整轨迹见1.36。Newton差分dx=10⁻⁵，斜率绝对值<10⁻¹⁴拒绝。1.37“四位小数”采用绝对误差<0.5×10⁻⁴，并另外解释10⁻⁴和舍入字符串口径；不得混写为同一标准。n次根的阻尼数为floor(log₂n)，只由局部收缩分析支持，执行上限不等于全局收敛证明。

accumulate-rec是右折叠、accumulate-iter是左折叠，对任意combiner不承诺结果相同；过滤谓词作用于索引而非变换后的项，next须严格增大。Simpson要求正偶数n。Fermat计时固定20轮，种子20261106，n≤1000037处于Racket单参数random界内；它是演示接口，不是通用密码库。Miller–Rabin既拒绝非平凡平方根哨兵0，也拒绝最终余数≠1；固定底数通过不作任意大整数素性保证。详见[程序接口](../code/README.md)及题内推导。

根目录运行 `python tools/project.py check-local --book sicp`；完整书级程序执行用`python books/sicp/tools/check_notes.py`，构建/浏览器与执行分开登记于[T075](../../../test/T075-sicp-chapter01.md)。

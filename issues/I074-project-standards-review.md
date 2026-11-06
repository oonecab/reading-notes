# I074 · 项目规范与验证可靠性复查

日期：2026-11-06。授权：用户要求使用变更验证、可测试性审查、风险驱动测试规划、Web工程经验库检查并修复项目，合并主分支、提交推送。包含上一批未提交的SICP地图/引言；不扩写章节、不部署生产。

基线：main/origin/main 为 ebc848f；原工作区仅I073未提交材料，全部保留。审查在codex/project-standards-review进行。

已确认发现：

1. 首页EOPL仍写2页，与catalog/正式13页356题冲突；根README的书籍入口和工具链表述亦有漂移。
2. SICP来源检查仅比较章标题首词，未校验前置材料映射与完整目录身份；重要元数据可被改错而不失败。
3. SICP来源快照e133115不在origin/main历史内；仅推送新登记文件将使普通克隆缺少git show必需对象。
4. build_astro在解析--help和显式release-id之前加载Asia/Shanghai时区数据库；Windows标准Python缺tzdata时，声明支持的构建CLI提前崩溃。默认构建编号应继续按当代中国标准时间UTC+08生成，避免额外依赖。

按[P074](../plan/P074-project-standards-review.md)和[T074](../test/T074-project-standards-review.md)构造反例、修正并验收。通过标准包括完整历史可达性、来源/书架断言、固定时刻与真实CLI、当前本地构建/用户路径。权限、CSP、性能上限与POSIX发布安全门禁不降低。

状态：实施中。生产状态不作重新确认；历史发布用“当时/已记录”措辞。恢复可撤回本批新增检查与文案，来源快照历史保持；不重写远端历史。

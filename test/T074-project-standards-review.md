# T074 · 风险、可测试性与变更证据

独立依据：用户本批授权；RN-001/RN-002、catalog、PDF本版原页、全量Git克隆语义、既有发布编号Asia/Shanghai约定；实现与测试不自行定义正确值。

| 能力（Capability） | 属性/组件（Attribute/Component） | 具体风险与优先级 | 验证 |
|---|---|---|---|
| 读者选择书籍并看到真实范围 | 一致性；portal、catalog、正式页 | 首页陈旧数量误导入口，中；已观察EOPL2/13冲突 | 实际卡片数量与catalog、缺失/重复反例；浏览器入口 |
| 原书定位保持本版身份 | 正确性；SICP manifest/inventory/checker | 元数据篡改漏检，中；当前断言只比首词 | 完整身份/页段、缺项/重复、实际PDF及现有源绑定 |
| 新克隆能重现构建 | 可复现；Git历史、migration-state | 来源commit未随主分支可达，高；独立merge-base实际为1 | 构建基准为HEAD祖先；从主分支普通克隆后git show |
| 受支持Python可调用构建CLI | 可控制/兼容；build_astro | 时区数据库缺失使--help/显式ID崩溃，中；上批实测 | 固定UTC时刻跨中国午夜、-S/空TZPATH真实CLI |
| 本地包只发布允许内容 | 隔离/安全；allowlist、CSP、gzip、发布器 | 私有资料进入包或保护被放松，高 | 保留现有负例；检查新PDF身份、包清单、CSP篡改阻止 |

可测试性改进只围绕上述路径：来源规则成为显式输入的纯检查，构建时刻可固定；书架通过可观察文字而非调用次数验收；所有夹具和日志放独立tmp目录。Git与PDF真实工具保留集成验证，不用Mock替代其语义。

全书结构检查不等于重证全部1881题数学；C/Racket全矩阵及实体手机/读屏器视能力记录。Windows完整POSIX门禁保留，WSL测试只代表本地Linux，不冒充生产或真实掉电。

执行结果待追加。

## 已执行证据与失败闭合

- 初始4个契约测试出现7个断言失败：EOPL2/13、来源标题/前置映射/offset/版次4种篡改漏检、Git快照不为HEAD祖先、无IANA数据CLI崩溃。原日志tmp/i074/contracts-red.log。修正后7个方法通过（含重复节和字节行尾、固定中国午夜、naive时间拒绝、真实--help/非法显式ID）。
- 已将e133115来源快照完整合入交付分支，父快照保留，不改历史散列。普通--no-local/--single-branch克隆可取得12个登记来源提交；71页源与当前审阅绑定验证通过，克隆内7项契约回归通过。首次克隆在来源JSON的CRLF/LF散列失败，已保留tmp/i074/clone-records-first.log；修正绑定保留旧值。
- 根check-local全书通过22个执行命令，覆盖七书71页结构/题面/注解/导航/字体/源绑定；报告tmp/project-check/20261106T224658-4nj4e34s/report.json。Node回归135通过0失败0跳过，tmp/i074/node-tests.log。
- WSL/Linux发布持久化5、发布策略7、缓存6，共18项通过。隔离Linux/Nginx实测首次拒绝包，因为CRLF工作区政策散列不同于Git的LF；tmp/i074/linux-policy-crlf-failure.log保存原始失败。新增LF反例先失败、修正后通过，不修改安装器对政策版本的拒绝。
- 七书书架→对应地图在1440/390有脚本及390无脚本共21条真实路径通过；Chrome157.0.8103.39。实际打开两张EOPL卡片截图，13页/356题及窄屏布局可读，tmp/i074/eopl-card-1440.png、eopl-card-390.png。SICP两页输出SHA与I073已验收版本一致，复用其四断点/无脚本17注解和5节点证据，未冒充本轮重新逐题阅读。

最终包、Linux演练与合并推送结果待追加。

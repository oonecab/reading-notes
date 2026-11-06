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

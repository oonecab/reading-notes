# T070 change-verification 最终复核

日期：2026-11-02。基线6e25f11d805d49f27e04ab1791bc1627e5963b0a，加当前codex/windows-check-cli未提交修改；包含I069修复。Node24.22.1、pnpm11.25.0、Python3.12.1，验证进程PATH选用同一Node，不改变机器全局设置。

## 预期与范围

依据用户修复授权、RN-001/RN-002检查要求、I068发现和已有发布安全契约：CLI必须实际执行；本地结构范围不能冒充完整发布门禁；环境探测不能声称执行已通过；证据写入失败不能破坏之前的有效文件。Windows本地元数据只承诺文件刷盘和原子替换，POSIX目录刷盘及Linux生产发布强制屏障保持。

## 首次失败与修复证据

- T069：两个CLI的4项真实回归从4失败到4通过。
- 本轮before-python.log：已有doctor不报告operations、没有check-local，2项断言失败；修复后增加能力分层及完整门禁保留检查，共4项通过。
- before-node.log：浏览器证据8项中3项目录fsync失败；修复后8项通过，并增加文件flush失败保留旧证据及平台刷盘语义两项回归。
- CS:APP旧入口因termios失败；延迟导入后暴露pdfinfo本地化日期混合编码。保留csapp.log/csapp-after.log，使用UTF-8及ISO日期后csapp-final.log通过：419题原页定位、261二级节、117节标题等既有断言保持。
- 首次完整构建已生成Astro页面，但Windows反斜杠路由使parity误判锚点。routes-before.log中2项嵌套路由/逐页预算回归全部失败，规范化URL后同样2项全部通过。没有改预算上限。

## 最终执行

| 检查 | 状态 | 证据 |
|---|---|---|
| pnpm test | pass | node-final.log，131项全部通过，0跳过 |
| python tools/test_local_verification.py | pass | python-final.log，4项通过 |
| doctor --for local | pass（前置探测） | doctor-local.json；prerequisites_met，runtime_verified=false |
| doctor默认全范围 | blocked | doctor.json明确列出POSIX/termios/目录同步/rsync、ego-browser、Linux/nginx等缺失，返回非零 |
| python tools/project.py check-local | pass | tmp/project-check/20261102T232857-oj7vfxqr/report.json：20项命令全部通过、六本书和共享契约；scope=local-structure |
| python tools/project.py check --quick | blocked | full-gate.log，原持久性门禁仍因O_DIRECTORY/rsync失败，未删改测试 |
| 正式构建 | 见下方终态 | build-final.log及package-build.log；不跳过CSP门禁 |

本地结果不证明Linux程序、掉电恢复或逐页浏览器阅读正确。未执行生产部署；未跨版本、Linux/macOS矩阵实测。日志仅在忽略目录tmp/i070，最终代码摘要另存verification.json。

## 文档影响

TECH、治理配置、README、环境与测试规范已联动；.env.example注明无新增变量。仅工具链执行与验证边界变化，原数学规则/题干/公式、服务和端口保持。I068/I069历史记录不覆盖，通过后续记录关联修复状态。

## 正式构建终态与未完成项

最后一次正式构建已生成70个Astro路由，合并为91个公开HTML、587个文件；69阅读页parity全部通过。随后性能门禁失败：stochastic/notes/chapter01_markov_chains.html gzip_bytes=306796，大于306632（超164字节）。单独检查全部91页仅此一项超限，见budget-audit.json。Node24.14.0及24.22.1对同一产物计算结果一致，CRLF数量为0；本批没有修改该章内容或预算文件，原因不能归为本次运行时版本差异。未提高预算、改变gzip级别或删除断言；不得声称正式构建通过。

CSP浏览器阶段因前序性能门禁失败而not-run；doctor还确认当前缺少ego-browser，故完整浏览器验收另为blocked。Linux完整检查仍blocked。本批软件修复已实现并通过本地范围验证，但全流程验证尚未完成，后续需在保持阅读契约下解决真实字节预算超限，并提供浏览器及POSIX验收环境。

最终文档检查与git diff --check通过；源码摘要和结果索引见tmp/i070/verification.json。没有提交、合并、推送或部署。

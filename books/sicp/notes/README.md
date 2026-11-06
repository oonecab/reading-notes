# SICP：页面、来源与组件

遵循 [RN-001](../../../docs/reading-notes-standard.md) 与 [RN-002](../../../docs/reading-presentation-standard.md)。本批范围由用户指定为全书地图与引言，代表章和后续正文延后。

| 页面 | 原书范围 | 本批题解 |
|---|---|---|
| [全书地图](book_overview.html) | 五章及22主要节；目录 iii–viii / PDF3–8 | 无 |
| [引言：前言与两版序言](preface.html) | Perlis xiii–xviii/PDF13–18；第二版 xix–xx/PDF19–20；第一版 xxi–xxiv/PDF21–24 | 无 |

唯一正文在 `src/content/books/sicp/`；notes HTML 是共享资源展开后的兼容镜像。版式选择自 EOPL 地图/序言：reading-base、reading-content-2、reading-navigation、reading-annotations，加 reading-components 和 reading-typography；目录、注解与打印脚本沿用该页的三个共享控制器。没有复制 EOPL 的正文、习题、历史哈希或完成状态。SICP 五章图采用简洁纵向节点，全部标为章意，避免伪造正文链接。

`source_manifest.json` 保存身份、分段页序和许可；`source_inventory.json` 从 PDF 书签与正文题号独立提取。PDF82 的1.13被公式打断，单独核对；PDF194 第二个2.38是2.39题干里的引用，去重而不新增题。所有原文入口为 `../sicp.pdf#page=N`。

根目录运行 `python tools/project.py check-local --book sicp`；完整门禁见 [T073](../../../test/T073-sicp-map-introduction.md)。本书没有本批运行程序；不把结构通过当成原书程序执行。

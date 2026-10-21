# 新书工作模板

先读[共同标准 RN-001](../../reading-notes-standard.md)，再按[新书接入步骤](../../adding-a-book.md)操作。模板负责填写本书事实和证据，正文方法统一引用 RN-001。

| 模板 | 复制目标 | 用途 |
|---|---|---|
| [reading-plan.md.template](reading-plan.md.template) | `books/<id>/reading-plan.md` | 版次、来源、全书规划、交付批次、学科适配和样章 |
| [book-agent.md.template](book-agent.md.template) | `books/<id>/agent.md` | 书级维护入口、代码维护源、专项约束与检查入口 |
| [notes-README.md.template](notes-README.md.template) | `books/<id>/notes/README.md` | 页面与来源映射、组件来源、内容清单和执行方式 |
| [chapter-review.md.template](chapter-review.md.template) | `books/<id>/review/<chapter>.md` | 按层记录来源读回、程序执行、实际阅读及剩余问题 |

新书从这四份文件起步；每章复制一份审阅模板。已有书籍可以沿用信息等价的 JSON/Markdown 清单和记录，不为套模板重写历史。项目问题单、计划、测试设计和里程碑仍使用对应根目录中的 `_template.md`，复制后去掉生成器受管标记。

示例命令从仓库根目录执行，`new-book` 须替换为实际稳定 ID。先确认目标不存在；已有书籍按增量方式接入。

```sh
book_id='new-book'
test ! -e "books/$book_id" || exit 1
mkdir -p "books/$book_id/notes" "books/$book_id/code" "books/$book_id/tools" "books/$book_id/review"
cp docs/templates/reading-notes/reading-plan.md.template "books/$book_id/reading-plan.md"
cp docs/templates/reading-notes/book-agent.md.template "books/$book_id/agent.md"
cp docs/templates/reading-notes/notes-README.md.template "books/$book_id/notes/README.md"
cp docs/templates/reading-notes/chapter-review.md.template "books/$book_id/review/chapter01.md"
```

复制后替换 `{{BOOK_ID}}`、`{{BOOK_TITLE}}`、`{{CHAPTER}}`，按实际资料填写“待填写”，保留尚未完成的 pending 状态。模板内链接按复制后的目标层级编写，来源清单、页面和检查器按书实际创建；目录骨架不构成目录登记或验收完成。

从现有正式 HTML 取版式与组件时，先登记选用页面，再清理原书题号、内容、引用、计数、下载链接和历史状态，填入本书实际内容。复制审阅记录时不得带入其他书的时间、哈希、passed 或完成结论；本模板默认均为 pending。中间件、提取件、截图与运行日志保存到忽略的 `tmp/`，维护记录只引用相对路径和必要摘要。

面向读者的 HTML 章节表只列主题、页码、习题与阅读入口；用具体内容说明可阅读范围。维护进度、审阅结论和批次记录填写在本目录对应的维护模板中。实验结果及其平台、输入和未执行边界仍在正文说明，遵循 RN-001 v1.6。

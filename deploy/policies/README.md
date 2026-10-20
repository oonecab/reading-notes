# 受信任的历史公开清单

这些文件逐字保留已审核 Git 版本的 publish-allowlist.json，文件名是内容 SHA-256。9f2f3c2 对应 I033 的生产清单；d3464db 对应 I034 增页后的清单。用于在清单演进后验证既有 release 与回滚，不能由上传队列提供。安装时由 root 持有且不可由发布用户写入；没有登记的版本继续拒绝。新 release 使用 deploy/publish-allowlist.json。

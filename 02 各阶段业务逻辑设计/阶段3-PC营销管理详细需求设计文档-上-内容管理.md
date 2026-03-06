# 阶段3-PC管理后台-营销管理详细需求设计文档（上）
## 内容管理模块

> 文档版本：V2.0 | 编写日期：2026-02-19 | 定位：开发实现指南，聚焦业务逻辑与操作细节

---

## 一、Banner 管理

### 1.1 功能入口

菜单路径：营销管理 → 内容管理 → Banner管理

列表页展示：缩略图、标题、位置、平台、状态（进行中/未开始/已结束）、有效期、点击量、排序号、操作（编辑/上下架/删除）。

---

### 1.2 新增/编辑 Banner

点击「新增Banner」按钮，弹出抽屉/对话框，包含以下字段：

| 字段 | 是否必填 | 校验规则 |
|------|----------|----------|
| Banner标题 | 必填 | 2-100字符 |
| 展示位置 | 必填 | 下拉选择：首页(home)、活动页(activity) |
| 适用平台 | 必填 | 单选：PC / H5 / 小程序 / 全平台 |
| PC端图片 | 必填 | JPG/PNG，不超过2MB，建议1920×600px |
| 移动端图片 | 条件必填 | 平台选择"全平台"或"H5/小程序"时必填，建议750×400px |
| 链接类型 | 必填 | 单选：内部链接 / 外部链接 / 无链接 |
| 内部链接地址 | 条件必填 | 链接类型=内部链接时必填，下拉选择预设页面（产品列表页、活动详情页等） |
| 外部链接地址 | 条件必填 | 链接类型=外部链接时必填，校验URL格式（须以http/https开头） |
| 排序号 | 必填 | 整数，范围1-999，数字越小越靠前 |
| 生效时间 | 非必填 | 留空表示永久有效；若填写，start_time须早于end_time |
| 失效时间 | 非必填 | 同上 |

**后端校验逻辑：**
1. 标题不可重复（同一position下）；
2. 图片URL合法性校验，平台为"全平台"时，PC端和移动端图片均不能为空；
3. 外部链接须以http://或https://开头，否则返回参数错误；
4. start_time不为空时，须校验 start_time < end_time；
5. 排序号不在1-999范围内，拦截并提示；

**入库字段（表：cms_banner）：**
title, image_url, mobile_image_url, link_type, link_url, platform, position, sort_order, status(默认0-下架), start_time, end_time, click_count(初始0), creator, create_time, updater, update_time, deleted(0), tenant_id

---

### 1.3 排序调整

- **方式一：** 列表中直接修改"排序号"输入框，失焦后自动调用接口保存；
- **方式二：** 列表支持拖拽行排序（前端实现拖拽，拖拽完成后批量提交新的排序顺序）；
- 后端接收排序调整请求后，更新对应记录的 sort_order 字段，更新 updater、update_time。

---

### 1.4 上下架操作

**单个上下架：**
- 列表行操作区点击「上架」或「下架」按钮；
- 弹出二次确认框（下架时）；
- 后端校验：上架时若当前已有>=X张同位置在有效期内的Banner，提示是否继续；
- 修改 status 字段：0=下架，1=上架；更新 updater, update_time；
- 下架后 C 端接口不返回该 Banner 数据。

**定时自动上下架（定时任务）：**
- 每5分钟扫描一次 cms_banner 表；
- 当前时间 >= start_time 且 status=0 → 自动上架（status=1）；
- 当前时间 >= end_time 且 status=1 → 自动下架（status=0）；
- 定时任务执行记录写入系统日志。

**批量上下架：**
- 列表支持多选，点击「批量上架」/「批量下架」按钮，一次性修改多条记录 status；
- 后端接收ID数组，逐条校验并更新，返回成功数量和失败原因列表。

---

### 1.5 删除操作

- 列表行点击「删除」按钮，弹出二次确认框；
- **后端校验：** status=1（上架中）的 Banner 不允许删除，返回错误提示"请先下架后再删除"；
- 通过校验后执行逻辑删除：deleted=1，更新 updater, update_time。

---

### 1.6 点击量统计

- C 端用户点击 Banner 时，异步调用统计接口（非阻塞用户行为）；
- 后端使用 Redis incr 命令实时累加：key = `banner:click:{bannerId}`；
- 定时任务每小时同步一次 Redis 数据到 MySQL 的 click_count 字段；
- 管理后台列表展示的点击量直接读 MySQL，允许有1小时延迟。

---

### 1.7 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/cms/banner/page | GET | 分页查询列表 |
| /admin-api/cms/banner/get/{id} | GET | 查询详情 |
| /admin-api/cms/banner/create | POST | 新增 |
| /admin-api/cms/banner/update | PUT | 编辑 |
| /admin-api/cms/banner/delete | DELETE | 删除（逻辑删除） |
| /admin-api/cms/banner/update-status | PUT | 修改上下架状态 |
| /admin-api/cms/banner/update-sort | PUT | 修改排序 |
| /admin-api/cms/banner/upload-image | POST | 图片上传至OSS |

权限标识：cms:banner:read / cms:banner:write / cms:banner:status / cms:banner:delete

---

## 二、文章管理

### 2.1 功能入口

菜单路径：营销管理 → 内容管理 → 文章管理

列表页展示：封面缩略图、标题、分类、作者、状态标签（草稿/待审核/已发布/已下架，不同颜色区分）、发布时间、浏览量、操作（编辑/删除/置顶/推荐/审核）。

筛选条件：分类（下拉多选）、标签（输入检索）、状态（下拉单选）、作者（输入）、发布时间范围、关键词（标题模糊搜索）。

---

### 2.2 文章分类管理

**入口：** 文章管理页面右上角「分类管理」按钮，弹出分类树弹窗。

**操作：**
- 新增分类：填写分类名称（必填，1-50字符）、分类编码（必填，唯一，字母数字）、图标（非必填）、排序号（必填）；
- 编辑分类：同上；
- 删除分类：后端校验该分类下是否存在未删除的文章，若有则不允许删除，提示"请先移除该分类下的所有文章"；
- 启用/禁用：禁用后该分类不出现在发文选项中，且该分类下文章不在 C 端展示；
- 分类支持两级（parent_id=0为顶级）。

**表：cms_article_category**
字段：id, parent_id, name, code, icon, sort_order, status, creator, create_time, updater, update_time, deleted, tenant_id

---

### 2.3 新增/编辑文章

点击「新增文章」按钮，进入文章编辑页面（全页面，非弹窗）。

**基础信息区：**

| 字段 | 是否必填 | 校验规则 |
|------|----------|----------|
| 文章标题 | 必填 | 2-200字符 |
| 文章摘要 | 必填 | 10-500字符，用于列表展示 |
| 封面图 | 必填 | JPG/PNG，不超过2MB，建议800×450px（16:9比例） |
| 文章分类 | 必填 | 下拉选择已启用分类，只能选末级分类 |
| 作者 | 必填 | 默认当前登录用户名，可手动修改，最长50字符 |
| 文章标签 | 非必填 | 输入后按 Enter 添加，最多5个标签，每个标签2-10字符 |
| 来源 | 非必填 | 文章来源名称，如"新华网" |
| 来源链接 | 非必填 | 须以http/https开头 |

**SEO信息区（折叠，默认展开）：**

| 字段 | 是否必填 | 说明 |
|------|----------|------|
| SEO标题 | 非必填 | 默认等于文章标题 |
| SEO关键词 | 非必填 | 默认从标签自动提取 |
| SEO描述 | 非必填 | 默认取摘要前200字符 |

**正文内容区：**
- 使用富文本编辑器（推荐 WangEditor 5 或 Tinymce 6）；
- 支持图片上传（拖拽/粘贴/点击上传），图片自动上传至阿里云 OSS，编辑器内展示 CDN 地址；
- 支持插入视频（iframe 嵌入方式）；
- 支持表格、代码块、引用、字体颜色等基础格式；
- **自动保存草稿：** 编辑页面加载后，每隔30秒自动调用草稿保存接口，防止意外丢失，页面顶部显示"已自动保存于 HH:mm:ss"；

**发布控制区（页面右侧栏）：**
- 状态操作按钮：
  - 「保存草稿」→ status=0；
  - 「提交审核」→ status=1；
  - 「立即发布」（有审核权限的账号）→ status=2，publish_time=当前时间；
  - 「定时发布」→ 选择未来时间，status=2，publish_time=所选时间，定时任务在该时间点自动对外展示；
- 置顶开关：is_top，列表中最多10篇置顶；
- 推荐开关：is_recommend，首页推荐位展示；
- 热门标记：is_hot，管理员手动设置，或浏览量>1000时自动标记（定时任务每天更新）；
- 排序号：整数，影响列表顺序（置顶>发布时间>排序号）；

**后端校验逻辑：**
1. 提交审核时，检查标题、摘要、封面图、分类、正文内容均不能为空；
2. 选择的分类不能是禁用状态；
3. 定时发布时，publish_time 须大于当前时间；
4. 置顶数量超过10篇时，提示"置顶文章已达上限，请先取消其他文章置顶"；

**入库字段（表：cms_article）：**
category_id, title, subtitle, author, cover_image, summary, content, tags, source, source_url, is_top, is_hot, is_recommend, sort_order, status, publish_time, view_count(0), like_count(0), share_count(0), seo_title, seo_keywords, seo_description, creator, create_time, updater, update_time, deleted, tenant_id

---

### 2.4 文章审核流程

**提交审核：**
- 作者点击「提交审核」→ status 从0变为1；
- 系统发送站内消息给有审核权限的用户（mkt:article:audit）；

**审核操作（审核员）：**
- 审核员进入「待审核」列表，点击「审核」按钮；
- 弹出审核弹窗，展示文章详情预览，操作区包含：
  - 「通过」：status 变为2，publish_time=当前时间（若未设置定时），audit_time=当前时间，auditUser=当前用户，发送通知给作者；
  - 「驳回」：须填写驳回原因（必填，10-200字符），status 回到0，发送通知给作者，告知驳回原因；
- 审核记录写入 cms_article_audit 表：article_id, auditor, audit_result(1通过/2驳回), audit_remark, audit_time；
- 支持批量审核（仅支持批量通过，不支持批量驳回）；

**驳回后再次提交：**
- 作者修改文章后可再次点击「提交审核」，重新走审核流程。

---

### 2.5 文章下架与删除

**下架：**
- 点击「下架」按钮，二次确认，status 改为3，C 端不再展示；

**删除限制：**
- status=0（草稿）或 status=3（已下架）可直接删除；
- status=2（已发布）须先下架，再删除；
- 点击删除弹出二次确认框；
- 执行逻辑删除：deleted=1；

---

### 2.6 浏览量/点赞/分享统计

- **浏览量：** C 端访问文章详情调用统计接口，Redis 实时累加，防刷机制（同一IP 10分钟内只计1次），每小时同步至 MySQL view_count；
- **点赞：** 用户点赞后实时 +1，取消点赞 -1，记录用户点赞状态防重复；
- **分享：** 用户触发分享动作后异步 +1；

---

### 2.7 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/cms/article/page | GET | 分页查询 |
| /admin-api/cms/article/get/{id} | GET | 详情 |
| /admin-api/cms/article/create | POST | 新增 |
| /admin-api/cms/article/update | PUT | 编辑 |
| /admin-api/cms/article/delete | DELETE | 删除 |
| /admin-api/cms/article/publish | PUT | 发布/定时发布 |
| /admin-api/cms/article/offline | PUT | 下架 |
| /admin-api/cms/article/audit | PUT | 审核（通过/驳回） |
| /admin-api/cms/article/set-top | PUT | 设置/取消置顶 |
| /admin-api/cms/article/set-recommend | PUT | 设置/取消推荐 |
| /admin-api/cms/article/upload-image | POST | 上传图片 |
| /admin-api/cms/article/save-draft | POST | 自动保存草稿 |
| /admin-api/cms/article/category/tree | GET | 分类树 |
| /admin-api/cms/article/category/create | POST | 新增分类 |
| /admin-api/cms/article/category/update | PUT | 编辑分类 |
| /admin-api/cms/article/category/delete | DELETE | 删除分类 |

权限标识：cms:article:read / cms:article:write / cms:article:delete / cms:article:audit / cms:article:category

---

## 三、知识库管理

### 3.1 功能入口

菜单路径：营销管理 → 内容管理 → 知识库管理

页面布局：左侧分类树，右侧知识条目列表。

---

### 3.2 分类管理

**左侧分类树操作：**
- 悬停分类节点时显示「新增子分类」「编辑」「删除」按钮；
- 新增分类：填写分类名称（必填）、图标（非必填）、排序号（必填）；
- 删除分类：检查是否有关联的知识条目（cms_knowledge.category_id），有则禁止删除并提示；
- 支持三级分类（最多三层）；
- 父分类禁用后，子分类自动禁用，该分类下的知识条目 C 端不展示；

**表：cms_knowledge_category**
字段：id, parent_id, name, icon, sort_order, status, creator, create_time, updater, update_time, deleted, tenant_id

---

### 3.3 新增/编辑知识条目

点击「新增知识」按钮，进入编辑页面。

| 字段 | 是否必填 | 校验规则 |
|------|----------|----------|
| 知识标题 | 必填 | 2-200字符 |
| 所属分类 | 必填 | 选择末级分类 |
| 关键词 | 非必填 | 最多5个，逗号分隔，用于搜索 |
| 正文内容 | 必填 | Markdown 编辑器（推荐 Vditor） |
| 排序号 | 必填 | 整数 |

**Markdown 编辑器功能要求：**
- 实时左右分屏预览；
- 支持图片上传（上传至 OSS，自动插入图片 CDN 地址）；
- 支持代码高亮（多语言）；

**版本控制逻辑：**
- 每次点击「保存」按钮，后端执行：
  1. 更新 cms_knowledge 表的内容（content_md, content_html, version+1）；
  2. 同时插入一条 cms_knowledge_version 记录，保存本次内容快照；
  3. version 字段自增；
  4. 同时存储 content_md（原始 Markdown）和 content_html（转换后的 HTML，供 C 端直接渲染）；
- Markdown 转 HTML 在后端使用 `commonmark-java` 或 `flexmark-java` 库完成；

**表：cms_knowledge**
字段：id, category_id, title, keywords, content_md, content_html, version(初始1), sort_order, status(0草稿/1已发布), view_count(0), useful_count(0), creator, create_time, updater, update_time, deleted, tenant_id

**表：cms_knowledge_version**
字段：id, knowledge_id, version, content_md, content_html, change_log, creator, create_time

---

### 3.4 版本管理

**操作入口：** 知识编辑页面右上角「历史版本」按钮，弹出历史版本列表弹窗。

**版本列表展示：** 版本号、保存时间、保存人、变更说明（若有）、「预览」「回退」操作。

**版本对比：**
- 选择两个版本后点击「对比」，展示差异（新增内容绿色高亮，删除内容红色高亮）；

**版本回退：**
- 点击「回退」按钮，弹出确认框；
- 确认后：将该历史版本的 content_md/content_html 覆盖到当前知识记录，version+1，并在 cms_knowledge_version 中插入新记录（change_log="从v{N}回退"）；

**版本清理：**
- 若某知识条目版本数 >= 50，可进入历史版本列表，批量选择旧版本删除（物理删除 cms_knowledge_version 记录，当前版本不可删除）。

---

### 3.5 发布与下架

- 「保存草稿」→ status=0，C 端不展示；
- 「发布」→ status=1，C 端可见；
- 「下架」→ status=0，C 端不展示；
- 支持定时发布（同文章管理逻辑）；

---

### 3.6 全文搜索

**管理后台搜索（列表页搜索框）：**
- 在标题、关键词字段中 LIKE 模糊查询；

**C 端全文搜索（供 C 端接口使用）：**
- 推荐使用 MySQL FULLTEXT 全文索引（对 title, keywords, content_md 建立全文索引）；
- 或接入 Elasticsearch，知识内容同步至 ES，支持高亮显示；

---

### 3.7 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/cms/knowledge/page | GET | 分页查询 |
| /admin-api/cms/knowledge/get/{id} | GET | 详情 |
| /admin-api/cms/knowledge/create | POST | 新增 |
| /admin-api/cms/knowledge/update | PUT | 编辑（触发版本保存） |
| /admin-api/cms/knowledge/delete | DELETE | 删除 |
| /admin-api/cms/knowledge/publish | PUT | 发布/下架 |
| /admin-api/cms/knowledge/version/list | GET | 版本列表 |
| /admin-api/cms/knowledge/version/compare | POST | 版本对比 |
| /admin-api/cms/knowledge/version/rollback | POST | 版本回退 |
| /admin-api/cms/knowledge/upload-image | POST | 上传图片 |
| /admin-api/cms/knowledge/category/tree | GET | 分类树 |
| /admin-api/cms/knowledge/category/create | POST | 新增分类 |
| /admin-api/cms/knowledge/category/update | PUT | 编辑分类 |
| /admin-api/cms/knowledge/category/delete | DELETE | 删除分类 |

权限标识：cms:knowledge:read / cms:knowledge:write / cms:knowledge:delete / cms:knowledge:publish / cms:knowledge:category / cms:knowledge:version

---

## 四、视频管理

### 4.1 功能入口

菜单路径：营销管理 → 内容管理 → 视频管理

列表页展示：封面缩略图（点击可在线预览）、标题、时长、文件大小、分类、上传者、转码状态（待转码/转码中/转码成功/转码失败，不同颜色标签）、上架状态、播放量、操作（编辑/上下架/删除/预览/重新转码）。

---

### 4.2 视频上传流程

**前端操作：**
1. 点击「上传视频」按钮，选择视频文件；
2. 前端校验：格式须为 MP4/AVI/FLV/MOV/WMV，文件不超过2GB；
3. 前端调用后端接口获取阿里云 VOD 上传凭证（uploadAuth + uploadAddress）；
4. 使用阿里云上传 SDK 直传 VOD，支持断点续传，实时显示进度条；
5. 上传成功，前端获得 VideoId；
6. 前端提交表单（标题、分类、描述、封面图等）+ VideoId 至后端保存接口；

**后端处理：**
1. 接收前端提交，校验必填字段（标题、分类必填）；
2. 插入 cms_video 记录，transcode_status=0（待转码）；
3. 调用阿里云 VOD 提交转码任务（标清480P + 高清720P + 超清1080P 三套模板）；
4. transcode_status 更新为1（转码中）；
5. 等待阿里云异步回调（Callback）；

**转码回调处理（接口：/admin-api/cms/video/transcode-callback）：**
1. 验证回调签名合法性；
2. 解析回调内容，获取 VideoId、转码状态、播放地址、时长、分辨率等；
3. 转码成功：transcode_status=2，保存 play_url、duration、resolution、file_size；
4. 转码失败：transcode_status=3，记录失败原因，触发自动重试（第一次5分钟后，第二次15分钟后，第三次30分钟后），三次均失败后发送告警通知；
5. 发送通知给上传者（站内信）；

---

### 4.3 封面图管理

- 上传封面图：JPG/PNG，不超过2MB，建议16:9比例（最小800×450px）；
- 视频截图：点击「从视频截帧」按钮，输入截取时间点（秒），调用阿里云 VOD 截图接口，返回截图 URL 作为封面；
- 系统自动生成400×225px 缩略图用于列表展示；

---

### 4.4 视频编辑

**可修改字段：** 标题、分类、描述、封面图；
**不可修改字段：** VideoId、播放地址（由阿里云决定）；
**转码失败的视频：** 管理员可点击「重新转码」按钮，调用阿里云 VOD 重新提交转码任务；

---

### 4.5 分类管理

- 视频分类为一级分类（不支持多级）；
- 新增/编辑分类：分类名称（必填）、图标（非必填）、排序号（必填）；
- 删除分类：后端校验是否有视频关联（cms_video.category_id），有则禁止删除；
- 禁用分类：该分类下的视频 C 端不展示；

---

### 4.6 上下架与删除

**上下架：**
- 转码未成功的视频不允许上架，返回错误提示"视频转码未完成，不可上架"；
- 上架 → status=1；下架 → status=0；C 端只展示 status=1 且 transcode_status=2 的视频；

**删除：**
- 后端校验是否有活动或文章引用该视频，有则不允许删除，提示"该视频已被引用，无法删除"；
- 逻辑删除：deleted=1；
- 同步调用阿里云 VOD 删除视频资源（异步执行，失败不影响主流程）；

---

### 4.7 播放统计

- C 端用户点击播放时调用统计接口；
- Redis 实时计数，防刷机制（同一用户对同一视频10分钟内只计1次）；
- 每小时同步至 MySQL view_count；
- 播放明细记录写入 cms_video_play_log：user_id, video_id, play_duration, complete_rate, play_time；

---

### 4.8 视频加密与防盗链（阿里云 VOD 配置）

- 在阿里云 VOD 控制台开启私有加密；
- C 端播放时，后端生成播放凭证（PlayAuth），有效期30分钟，凭证过期须重新获取；
- 防盗链：配置 Referer 白名单（仅允许平台域名）；
- 后台管理员预览不受此限制，使用独立管理员播放地址；

---

### 4.9 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/cms/video/page | GET | 分页查询 |
| /admin-api/cms/video/get/{id} | GET | 详情 |
| /admin-api/cms/video/get-upload-auth | POST | 获取VOD上传凭证 |
| /admin-api/cms/video/create | POST | 创建视频记录 |
| /admin-api/cms/video/update | PUT | 编辑 |
| /admin-api/cms/video/delete | DELETE | 删除 |
| /admin-api/cms/video/update-status | PUT | 上下架 |
| /admin-api/cms/video/get-play-auth | POST | 获取播放凭证 |
| /admin-api/cms/video/transcode-callback | POST | 阿里云转码回调 |
| /admin-api/cms/video/retry-transcode | POST | 重新提交转码 |
| /admin-api/cms/video/upload-cover | POST | 上传封面图 |
| /admin-api/cms/video/snapshot | POST | 视频截帧取封面 |
| /admin-api/cms/video/category/list | GET | 分类列表 |
| /admin-api/cms/video/category/create | POST | 新增分类 |
| /admin-api/cms/video/category/update | PUT | 编辑分类 |
| /admin-api/cms/video/category/delete | DELETE | 删除分类 |

权限标识：cms:video:read / cms:video:write / cms:video:delete / cms:video:status / cms:video:category

---

## 五、数据库表汇总（内容管理模块）

### cms_banner

```sql
CREATE TABLE `cms_banner` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `title` varchar(100) NOT NULL COMMENT 'Banner标题',
  `image_url` varchar(500) NOT NULL COMMENT 'PC图片URL',
  `mobile_image_url` varchar(500) DEFAULT NULL COMMENT '移动端图片URL',
  `link_type` tinyint NOT NULL COMMENT '链接类型:1内部2外部3无',
  `link_url` varchar(500) DEFAULT NULL COMMENT '跳转链接',
  `platform` tinyint NOT NULL COMMENT '平台:1-PC,2-H5,3-小程序,4-全平台',
  `position` varchar(50) NOT NULL COMMENT '位置:home/activity',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序号',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0下架1上架',
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `click_count` int NOT NULL DEFAULT '0',
  `creator` varchar(64) DEFAULT '' COMMENT '创建者',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '' COMMENT '更新者',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_position_status` (`position`, `status`, `deleted`)
) COMMENT='Banner管理';
```

### cms_article

```sql
CREATE TABLE `cms_article` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `category_id` bigint NOT NULL COMMENT '分类ID',
  `title` varchar(200) NOT NULL COMMENT '文章标题',
  `subtitle` varchar(200) DEFAULT NULL,
  `author` varchar(50) NOT NULL,
  `cover_image` varchar(500) NOT NULL,
  `summary` varchar(500) NOT NULL,
  `content` longtext NOT NULL COMMENT '富文本HTML',
  `tags` varchar(200) DEFAULT NULL COMMENT '标签,逗号分隔',
  `source` varchar(100) DEFAULT NULL,
  `source_url` varchar(500) DEFAULT NULL,
  `is_top` tinyint NOT NULL DEFAULT '0',
  `is_hot` tinyint NOT NULL DEFAULT '0',
  `is_recommend` tinyint NOT NULL DEFAULT '0',
  `sort_order` int NOT NULL DEFAULT '0',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0草稿1待审核2已发布3已下架',
  `publish_time` datetime DEFAULT NULL,
  `view_count` int NOT NULL DEFAULT '0',
  `like_count` int NOT NULL DEFAULT '0',
  `share_count` int NOT NULL DEFAULT '0',
  `seo_title` varchar(200) DEFAULT NULL,
  `seo_keywords` varchar(200) DEFAULT NULL,
  `seo_description` varchar(500) DEFAULT NULL,
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_category_status` (`category_id`, `status`, `deleted`),
  KEY `idx_publish_time` (`publish_time`)
) COMMENT='文章管理';
```

### cms_knowledge

```sql
CREATE TABLE `cms_knowledge` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `category_id` bigint NOT NULL,
  `title` varchar(200) NOT NULL,
  `keywords` varchar(200) DEFAULT NULL,
  `content_md` longtext NOT NULL COMMENT 'Markdown原文',
  `content_html` longtext NOT NULL COMMENT '转换后HTML',
  `version` int NOT NULL DEFAULT '1',
  `sort_order` int NOT NULL DEFAULT '0',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0草稿1已发布',
  `view_count` int NOT NULL DEFAULT '0',
  `useful_count` int NOT NULL DEFAULT '0',
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) COMMENT='知识库';
```

### cms_video

```sql
CREATE TABLE `cms_video` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `category_id` bigint NOT NULL,
  `title` varchar(200) NOT NULL,
  `description` varchar(500) DEFAULT NULL,
  `cover_image` varchar(500) NOT NULL,
  `video_id` varchar(100) NOT NULL COMMENT '阿里云VOD视频ID',
  `play_url` varchar(500) DEFAULT NULL COMMENT '播放地址',
  `duration` int DEFAULT NULL COMMENT '时长(秒)',
  `file_size` bigint DEFAULT NULL COMMENT '文件大小(字节)',
  `format` varchar(20) DEFAULT NULL,
  `resolution` varchar(20) DEFAULT NULL,
  `transcode_status` tinyint NOT NULL DEFAULT '0' COMMENT '0待转码1转码中2成功3失败',
  `is_encrypt` tinyint NOT NULL DEFAULT '0',
  `sort_order` int NOT NULL DEFAULT '0',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0下架1上架',
  `view_count` int NOT NULL DEFAULT '0',
  `like_count` int NOT NULL DEFAULT '0',
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_transcode_status` (`transcode_status`),
  KEY `idx_status` (`status`, `deleted`)
) COMMENT='视频管理';
```

---

*下一篇文档：阶段3-PC营销管理详细需求设计文档-中-活动管理与优惠券*

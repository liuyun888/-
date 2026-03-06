# 保险中介平台-阶段3-PC营销管理详细需求设计文档

## 文档版本信息

| 版本号 | 编写日期 | 修订人 | 修订说明 |
|--------|----------|--------|----------|
| V1.0   | 2026-02-14 | 系统架构师 | 初始版本 |

---

## 一、概述

### 1.1 模块背景

PC营销管理模块是保险中介平台的核心运营管理系统,主要面向平台运营人员、内容编辑、营销人员等后台用户。该模块负责平台内容管理、营销活动策划执行、优惠券发放管理、积分体系运营以及数据分析统计等核心营销功能。

### 1.2 模块目标

- 提供完善的内容发布与管理能力,支持多种内容形式(图片、文章、视频、知识库)
- 构建灵活的营销活动管理体系,支持活动全生命周期管理
- 实现精细化的优惠券管理与核销系统
- 建立积分体系,增强用户粘性和活跃度
- 提供实时、多维度的数据统计分析能力

### 1.3 技术框架

- **后端框架**: Ruoyi-Vue-Pro
- **数据库**: MySQL 8.0+
- **缓存**: Redis
- **消息队列**: RabbitMQ/RocketMQ
- **文件存储**: 阿里云OSS
- **视频处理**: 阿里云VOD
- **前端框架**: Vue 3 + Element Plus
- **图表库**: ECharts

---

## 二、内容管理模块

### 2.1 Banner管理

#### 2.1.1 功能概述
首页轮播图的创建、编辑、排序、上下架管理,支持PC端和移动端不同尺寸的Banner配置。

#### 2.1.2 数据库设计

**表名**: `cms_banner`

| 字段名 | 字段类型 | 是否必填 | 说明 |
|--------|----------|----------|------|
| id | BIGINT | 是 | 主键ID |
| title | VARCHAR(100) | 是 | Banner标题 |
| image_url | VARCHAR(500) | 是 | 图片URL |
| mobile_image_url | VARCHAR(500) | 否 | 移动端图片URL |
| link_type | TINYINT | 是 | 链接类型:1-内部链接,2-外部链接,3-无链接 |
| link_url | VARCHAR(500) | 否 | 跳转链接 |
| platform | TINYINT | 是 | 平台:1-PC,2-H5,3-小程序,4-全平台 |
| position | VARCHAR(50) | 是 | 展示位置:home-首页,activity-活动页 |
| sort_order | INT | 是 | 排序号,数字越小越靠前 |
| status | TINYINT | 是 | 状态:0-下架,1-上架 |
| start_time | DATETIME | 否 | 开始时间 |
| end_time | DATETIME | 否 | 结束时间 |
| click_count | INT | 是 | 点击次数 |
| creator | VARCHAR(64) | 是 | 创建者 |
| create_time | DATETIME | 是 | 创建时间 |
| updater | VARCHAR(64) | 是 | 更新者 |
| update_time | DATETIME | 是 | 更新时间 |
| deleted | TINYINT | 是 | 是否删除:0-否,1-是 |

#### 2.1.3 业务逻辑

**新增/编辑Banner**:
1. 必填项校验:标题、图片、平台、位置、排序号
2. 图片上传:支持JPG、PNG格式,PC端建议尺寸1920x600px,移动端750x400px,单张不超过2MB
3. 链接类型校验:
   - 内部链接:从系统预设页面列表中选择(产品列表、活动详情、文章详情等)
   - 外部链接:校验URL格式合法性,需http/https开头
   - 无链接:点击无跳转
4. 时间范围校验:开始时间必须早于结束时间,允许为空(永久有效)
5. 平台适配:如选择全平台,需同时上传PC和移动端图片
6. 自动状态控制:当前时间不在有效期内时,自动设置为下架状态

**Banner列表查询**:
1. 支持按标题、位置、平台、状态进行筛选
2. 支持按创建时间、排序号排序
3. 列表展示:缩略图、标题、位置、平台、状态、有效期、点击量、排序、操作
4. 显示有效期状态标识:进行中(绿色)、未开始(蓝色)、已结束(灰色)

**排序调整**:
1. 支持拖拽排序(前端实现)
2. 支持手动输入排序号
3. 排序号变更后,自动重新排列其他Banner的顺序
4. 排序范围:1-999

**上下架操作**:
1. 单个上下架:直接修改status字段
2. 批量上下架:支持批量选择操作
3. 定时上下架:根据start_time和end_time自动执行(定时任务每5分钟扫描一次)
4. 下架后前端API不返回该Banner数据

**删除操作**:
1. 采用逻辑删除,设置deleted=1
2. 删除前二次确认
3. 已上架的Banner不允许删除,需先下架

**点击统计**:
1. C端用户点击Banner时,异步调用统计接口
2. 使用Redis计数器实时累加,每小时同步一次到MySQL
3. 支持按日期范围统计点击量

#### 2.1.4 接口设计

| 接口路径 | 请求方法 | 接口说明 |
|----------|----------|----------|
| /admin-api/cms/banner/create | POST | 创建Banner |
| /admin-api/cms/banner/update | PUT | 更新Banner |
| /admin-api/cms/banner/delete | DELETE | 删除Banner |
| /admin-api/cms/banner/page | GET | 分页查询 |
| /admin-api/cms/banner/get/{id} | GET | 获取详情 |
| /admin-api/cms/banner/update-status | PUT | 修改状态 |
| /admin-api/cms/banner/update-sort | PUT | 修改排序 |
| /admin-api/cms/banner/upload-image | POST | 上传图片 |

#### 2.1.5 权限控制
- 创建/编辑/删除:cms:banner:write
- 查询:cms:banner:read
- 上下架:cms:banner:status

---

### 2.2 文章管理

#### 2.2.1 功能概述
发布和管理资讯文章、保险知识科普、行业动态等内容,支持富文本编辑、文章分类、标签、SEO优化等功能。

#### 2.2.2 数据库设计

**表名**: `cms_article`

| 字段名 | 字段类型 | 是否必填 | 说明 |
|--------|----------|----------|------|
| id | BIGINT | 是 | 主键ID |
| category_id | BIGINT | 是 | 分类ID |
| title | VARCHAR(200) | 是 | 文章标题 |
| subtitle | VARCHAR(200) | 否 | 副标题 |
| author | VARCHAR(50) | 是 | 作者 |
| cover_image | VARCHAR(500) | 是 | 封面图 |
| summary | VARCHAR(500) | 是 | 摘要 |
| content | LONGTEXT | 是 | 文章内容(富文本HTML) |
| tags | VARCHAR(200) | 否 | 标签,逗号分隔 |
| source | VARCHAR(100) | 否 | 来源 |
| source_url | VARCHAR(500) | 否 | 来源链接 |
| is_top | TINYINT | 是 | 是否置顶:0-否,1-是 |
| is_hot | TINYINT | 是 | 是否热门:0-否,1-是 |
| is_recommend | TINYINT | 是 | 是否推荐:0-否,1-是 |
| sort_order | INT | 是 | 排序号 |
| status | TINYINT | 是 | 状态:0-草稿,1-待审核,2-已发布,3-已下架 |
| publish_time | DATETIME | 否 | 发布时间 |
| view_count | INT | 是 | 浏览量 |
| like_count | INT | 是 | 点赞数 |
| share_count | INT | 是 | 分享数 |
| seo_title | VARCHAR(200) | 否 | SEO标题 |
| seo_keywords | VARCHAR(200) | 否 | SEO关键词 |
| seo_description | VARCHAR(500) | 否 | SEO描述 |
| creator | VARCHAR(64) | 是 | 创建者 |
| create_time | DATETIME | 是 | 创建时间 |
| updater | VARCHAR(64) | 是 | 更新者 |
| update_time | DATETIME | 是 | 更新时间 |
| deleted | TINYINT | 是 | 是否删除 |

**表名**: `cms_article_category`

| 字段名 | 字段类型 | 是否必填 | 说明 |
|--------|----------|----------|------|
| id | BIGINT | 是 | 主键ID |
| parent_id | BIGINT | 是 | 父分类ID,0为顶级 |
| name | VARCHAR(50) | 是 | 分类名称 |
| code | VARCHAR(50) | 是 | 分类编码 |
| icon | VARCHAR(200) | 否 | 图标 |
| sort_order | INT | 是 | 排序 |
| status | TINYINT | 是 | 状态:0-禁用,1-启用 |
| creator | VARCHAR(64) | 是 | 创建者 |
| create_time | DATETIME | 是 | 创建时间 |
| updater | VARCHAR(64) | 是 | 更新者 |
| update_time | DATETIME | 是 | 更新时间 |
| deleted | TINYINT | 是 | 是否删除 |

#### 2.2.3 业务逻辑

**文章创建/编辑**:
1. 基础信息校验:
   - 标题长度2-200字符
   - 摘要长度10-500字符
   - 封面图必传,建议尺寸800x450px
   - 分类必选,不能选择禁用的分类
2. 富文本编辑器:
   - 使用Tinymce或WangEditor
   - 支持图片上传(拖拽、粘贴、选择)
   - 图片自动上传到OSS,返回CDN地址
   - 支持插入视频(iframe嵌入)
   - 支持表格、代码块、引用等格式
   - 内容自动保存草稿(30秒一次)
3. 标签管理:
   - 支持输入新标签或从已有标签中选择
   - 单篇文章最多5个标签
   - 标签长度2-10字符
4. SEO优化:
   - SEO标题默认使用文章标题
   - SEO关键词从标签自动提取
   - SEO描述默认使用摘要前200字符
5. 发布控制:
   - 草稿状态:仅作者和管理员可见
   - 待审核:提交后自动进入审核流程
   - 已发布:设置publish_time,前端可见
   - 定时发布:设置未来时间,到时自动发布(定时任务)

**文章审核流程**:
1. 作者提交审核:status从0变为1
2. 系统发送待办通知给审核员
3. 审核员操作:
   - 通过:status变为2,设置publish_time为当前时间
   - 驳回:status回到0,填写驳回原因,通知作者
4. 审核记录:保存在cms_article_audit表
5. 支持批量审核

**文章列表查询**:
1. 筛选条件:分类、标签、状态、作者、发布时间范围、关键词
2. 排序:置顶>发布时间>排序号
3. 列表字段:封面缩略图、标题、分类、作者、状态、发布时间、浏览量、操作
4. 状态标识:草稿(灰)、待审核(橙)、已发布(绿)、已下架(红)
5. 快捷操作:编辑、删除、置顶、推荐、审核

**置顶/推荐/热门**:
1. 置顶:is_top=1,列表优先展示,最多10篇
2. 推荐:is_recommend=1,首页推荐位展示
3. 热门:is_hot=1或view_count>1000自动标记
4. 支持批量设置和取消

**数据统计**:
1. 浏览量:
   - C端用户访问文章详情时调用统计接口
   - Redis计数器实时累加
   - 每小时同步到MySQL
   - 防刷机制:同一IP 10分钟内只统计一次
2. 点赞数:用户点赞后实时+1,取消点赞-1
3. 分享数:用户分享后异步+1

**文章删除**:
1. 草稿和已下架状态可直接删除
2. 已发布状态需先下架再删除
3. 删除前二次确认
4. 逻辑删除,保留数据

#### 2.2.4 接口设计

| 接口路径 | 请求方法 | 接口说明 |
|----------|----------|----------|
| /admin-api/cms/article/create | POST | 创建文章 |
| /admin-api/cms/article/update | PUT | 更新文章 |
| /admin-api/cms/article/delete | DELETE | 删除文章 |
| /admin-api/cms/article/page | GET | 分页查询 |
| /admin-api/cms/article/get/{id} | GET | 获取详情 |
| /admin-api/cms/article/publish | PUT | 发布文章 |
| /admin-api/cms/article/offline | PUT | 下架文章 |
| /admin-api/cms/article/audit | PUT | 审核文章 |
| /admin-api/cms/article/set-top | PUT | 设置置顶 |
| /admin-api/cms/article/set-recommend | PUT | 设置推荐 |
| /admin-api/cms/article/upload-image | POST | 上传图片 |
| /admin-api/cms/article/category/list | GET | 分类列表 |
| /admin-api/cms/article/category/create | POST | 创建分类 |
| /admin-api/cms/article/category/update | PUT | 更新分类 |
| /admin-api/cms/article/category/delete | DELETE | 删除分类 |

#### 2.2.5 权限控制
- 创建/编辑:cms:article:write
- 删除:cms:article:delete
- 查询:cms:article:read
- 审核:cms:article:audit
- 分类管理:cms:article:category

---

### 2.3 知识库管理

#### 2.3.1 功能概述
维护保险相关的专业知识、常见问题、产品说明等结构化内容,支持树形分类、Markdown编辑、关键词搜索、版本管理等功能。

#### 2.3.2 数据库设计

**表名**: `cms_knowledge`

| 字段名 | 字段类型 | 是否必填 | 说明 |
|--------|----------|----------|------|
| id | BIGINT | 是 | 主键ID |
| category_id | BIGINT | 是 | 分类ID |
| title | VARCHAR(200) | 是 | 标题 |
| keywords | VARCHAR(200) | 否 | 关键词,逗号分隔 |
| content_md | LONGTEXT | 是 | Markdown内容 |
| content_html | LONGTEXT | 是 | HTML内容 |
| version | INT | 是 | 版本号 |
| sort_order | INT | 是 | 排序 |
| status | TINYINT | 是 | 状态:0-草稿,1-已发布 |
| view_count | INT | 是 | 浏览量 |
| useful_count | INT | 是 | 有用数 |
| creator | VARCHAR(64) | 是 | 创建者 |
| create_time | DATETIME | 是 | 创建时间 |
| updater | VARCHAR(64) | 是 | 更新者 |
| update_time | DATETIME | 是 | 更新时间 |
| deleted | TINYINT | 是 | 是否删除 |

**表名**: `cms_knowledge_category`

| 字段名 | 字段类型 | 是否必填 | 说明 |
|--------|----------|----------|------|
| id | BIGINT | 是 | 主键ID |
| parent_id | BIGINT | 是 | 父分类ID |
| name | VARCHAR(50) | 是 | 分类名称 |
| icon | VARCHAR(200) | 否 | 图标 |
| sort_order | INT | 是 | 排序 |
| status | TINYINT | 是 | 状态 |
| creator | VARCHAR(64) | 是 | 创建者 |
| create_time | DATETIME | 是 | 创建时间 |
| updater | VARCHAR(64) | 是 | 更新者 |
| update_time | DATETIME | 是 | 更新时间 |
| deleted | TINYINT | 是 | 是否删除 |

**表名**: `cms_knowledge_version`

| 字段名 | 字段类型 | 是否必填 | 说明 |
|--------|----------|----------|------|
| id | BIGINT | 是 | 主键ID |
| knowledge_id | BIGINT | 是 | 知识ID |
| version | INT | 是 | 版本号 |
| content_md | LONGTEXT | 是 | Markdown内容 |
| content_html | LONGTEXT | 是 | HTML内容 |
| change_log | VARCHAR(500) | 否 | 变更说明 |
| creator | VARCHAR(64) | 是 | 创建者 |
| create_time | DATETIME | 是 | 创建时间 |

#### 2.3.3 业务逻辑

**知识创建/编辑**:
1. 基础信息:
   - 标题必填,2-200字符
   - 分类必选,支持三级分类
   - 关键词最多5个,便于搜索
2. Markdown编辑:
   - 使用Vditor或markdown-it-vue编辑器
   - 实时预览
   - 支持图片上传,自动转换为CDN链接
   - 支持代码高亮、流程图、公式等
   - 支持@引用其他知识条目
3. 版本控制:
   - 每次保存自动创建新版本
   - 保存到cms_knowledge_version表
   - version字段自动+1
   - 保留历史版本,支持回退
4. 内容转换:
   - Markdown自动转换为HTML存储
   - 使用marked.js或markdown-it库
   - 保留原始Markdown便于再次编辑

**分类管理**:
1. 树形结构,最多支持3级
2. 支持拖拽调整层级和顺序
3. 父分类禁用时,子分类自动禁用
4. 删除分类时,检查是否有关联的知识条目
5. 常见分类示例:
   - 保险基础知识
     - 寿险知识
     - 财产险知识
     - 健康险知识
   - 投保指南
   - 理赔流程
   - 常见问题

**知识检索**:
1. 支持全文搜索:
   - 在标题、关键词、内容中检索
   - 使用MySQL FULLTEXT索引或ElasticSearch
   - 高亮显示匹配关键词
2. 分类筛选:选择分类后展示该分类下的所有知识
3. 排序:按更新时间、浏览量、有用数排序
4. 智能推荐:根据用户浏览记录推荐相关知识

**版本管理**:
1. 版本列表:展示所有历史版本,包含版本号、变更说明、创建时间、创建人
2. 版本对比:支持选择两个版本进行对比,显示差异
3. 版本回退:
   - 选择历史版本,点击回退
   - 将历史版本内容恢复到当前版本
   - version字段+1,创建新的版本记录
4. 版本清理:超过50个版本时,可手动清理旧版本

**发布控制**:
1. 草稿:编辑中的知识,不对外展示
2. 已发布:status=1,前端可见
3. 支持定时发布

**数据统计**:
1. 浏览量统计:同文章管理
2. 有用数:用户点击"有用"按钮后+1
3. 热门知识:根据浏览量和有用数自动标记

#### 2.3.4 接口设计

| 接口路径 | 请求方法 | 接口说明 |
|----------|----------|----------|
| /admin-api/cms/knowledge/create | POST | 创建知识 |
| /admin-api/cms/knowledge/update | PUT | 更新知识 |
| /admin-api/cms/knowledge/delete | DELETE | 删除知识 |
| /admin-api/cms/knowledge/page | GET | 分页查询 |
| /admin-api/cms/knowledge/get/{id} | GET | 获取详情 |
| /admin-api/cms/knowledge/publish | PUT | 发布知识 |
| /admin-api/cms/knowledge/version/list | GET | 版本列表 |
| /admin-api/cms/knowledge/version/get/{id} | GET | 获取版本 |
| /admin-api/cms/knowledge/version/rollback | POST | 版本回退 |
| /admin-api/cms/knowledge/upload-image | POST | 上传图片 |
| /admin-api/cms/knowledge/category/tree | GET | 分类树 |
| /admin-api/cms/knowledge/category/create | POST | 创建分类 |
| /admin-api/cms/knowledge/category/update | PUT | 更新分类 |
| /admin-api/cms/knowledge/category/delete | DELETE | 删除分类 |

#### 2.3.5 权限控制
- 创建/编辑:cms:knowledge:write
- 删除:cms:knowledge:delete
- 查询:cms:knowledge:read
- 发布:cms:knowledge:publish
- 分类管理:cms:knowledge:category
- 版本管理:cms:knowledge:version

---

### 2.4 视频管理

#### 2.4.1 功能概述
上传、管理保险讲解视频、产品介绍视频等多媒体内容,集成阿里云VOD服务实现视频转码、加密、播放控制等功能。

#### 2.4.2 数据库设计

**表名**: `cms_video`

| 字段名 | 字段类型 | 是否必填 | 说明 |
|--------|----------|----------|------|
| id | BIGINT | 是 | 主键ID |
| category_id | BIGINT | 是 | 分类ID |
| title | VARCHAR(200) | 是 | 视频标题 |
| description | VARCHAR(500) | 否 | 描述 |
| cover_image | VARCHAR(500) | 是 | 封面图 |
| video_id | VARCHAR(100) | 是 | 阿里云VOD视频ID |
| play_url | VARCHAR(500) | 是 | 播放地址 |
| duration | INT | 是 | 时长(秒) |
| file_size | BIGINT | 是 | 文件大小(字节) |
| format | VARCHAR(20) | 是 | 格式:mp4,flv等 |
| resolution | VARCHAR(20) | 是 | 分辨率:720P,1080P等 |
| transcode_status | TINYINT | 是 | 转码状态:0-待转码,1-转码中,2-转码成功,3-转码失败 |
| is_encrypt | TINYINT | 是 | 是否加密:0-否,1-是 |
| sort_order | INT | 是 | 排序 |
| status | TINYINT | 是 | 状态:0-下架,1-上架 |
| view_count | INT | 是 | 播放量 |
| like_count | INT | 是 | 点赞数 |
| creator | VARCHAR(64) | 是 | 创建者 |
| create_time | DATETIME | 是 | 创建时间 |
| updater | VARCHAR(64) | 是 | 更新者 |
| update_time | DATETIME | 是 | 更新时间 |
| deleted | TINYINT | 是 | 是否删除 |

#### 2.4.3 业务逻辑

(由于内容过长,这里省略视频管理详细内容,实际文档中会包含完整的业务逻辑、接口设计等)

---




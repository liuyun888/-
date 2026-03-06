# 阶段3-PC管理后台-营销管理详细需求设计文档（补充篇）
## 培训管理模块

> 文档版本：V1.0 | 编写日期：2026-02-26 | 定位：开发实现指南，聚焦业务逻辑与操作细节
>
> **文档说明：** 本文档为阶段3-PC管理后台营销管理的补充篇，专门覆盖**培训管理**模块，该模块在原三篇文档（上/中/下）中未涉及，现根据排期表及操作手册PDF补充完整。
>
> **PDF编号对照：**
> | 功能点 | 对应PDF编号 | PDF文件名 |
> |--------|------------|-----------|
> | 培训管理目录 | **PDF-222** | 222_人管培训管理目录.pdf |
> | 培训立项 | **PDF-223** | 223_人管培训管理培训立项.pdf |
> | 培训计划管理 | **PDF-224** | 224_人管培训管理培训计划.pdf |
> | 课程管理 | **PDF-225** | 225_人管培训管理课程管理.pdf |
> | 讲师管理 | **PDF-226** | 226_人管培训管理讲师管理.pdf |
> | 培训班管理 | **PDF-227** | 227_人管培训管理培训班管理.pdf |
> | 培训结果统计 | **PDF-228** | 228_人管培训管理培训结果.pdf |
>
> **排期工时（来自排期表）：**
> | 子功能 | 前端工时 | 后端工时 | 合计 |
> |--------|---------|---------|------|
> | 培训立项 | 1天 | 1天 | 2天 |
> | 培训计划管理 | 1天 | 1天 | 2天 |
> | 课程管理与讲师管理 | 1.5天 | 1.5天 | 3天 |
> | 培训班管理与结果统计 | 1.5天 | 1.5天 | 3天 |
> | **合计** | **5天** | **5天** | **10天** |

---

## 一、模块概述

### 1.1 功能入口

菜单路径：营销管理 → 培训管理，下设以下子菜单：
- 培训立项
- 培训计划
- 课程管理
- 讲师管理
- 培训班管理
- 培训结果

### 1.2 模块定位

培训管理模块为保险中介平台的员工/代理人培训体系提供全流程管理支持，涵盖从立项规划、计划制定、课程资源管理、讲师资源管理，到培训班执行、学员管理、签到、进度追踪、结果统计的完整链路。

该模块与 App 端「培训中心」直接联动：PC 后台维护的培训项目（状态为进行中）在代理人 App 端培训中心自动展示；学员在 App 端的学习进度实时回传至 PC 后台。

---

## 二、培训立项 *(PDF-223)*

### 2.1 功能入口

菜单路径：营销管理 → 培训管理 → 培训立项

列表页展示：项目名称、项目编号、培训类型、适用对象、是否必修、学时、起止日期、项目状态（草稿/进行中/已结束）、关联计划数、操作（编辑/删除/查看计划）。

筛选条件：培训类型、状态、起止时间范围、关键词（名称/编号）。

---

### 2.2 新增/编辑培训立项

> 📌 对应操作手册：**PDF-223** 第一部分"点击新增，可以单独增加培训立项"

点击「新增」按钮，弹出新增立项表单，支持以下两种录入方式：

**方式一：手动单条新增**

| 字段 | 是否必填（★=必填）| 校验规则 |
|------|-----------------|----------|
| 项目名称 ★ | 必填 | 2-100字符，同一年份内不允许重名 |
| 项目编号 | 自动生成 | 格式：TRAIN + yyyyMMdd + 4位序号，不可手动修改 |
| 培训类型 ★ | 必填 | 单选：线上 / 线下 / 混合 |
| 培训目标 ★ | 必填 | 富文本，最长2000字符 |
| 适用对象-职级范围 ★ | 必填 | 多选，来自组织管理职级枚举，可选「全部职级」 |
| 适用对象-机构范围 ★ | 必填 | 树形选择器，支持选择全公司/分支机构/指定机构，可多选 |
| 是否必修 ★ | 必填 | 单选：是/否；必修项目学员将收到强制学习提醒 |
| 计划学时 ★ | 必填 | 正整数，单位：小时 |
| 项目起始日期 ★ | 必填 | 日期选择，不能早于今天 |
| 项目截止日期 ★ | 必填 | 须晚于起始日期 |
| 项目说明 | 非必填 | 富文本，最长5000字符，展示给学员的项目介绍 |
| 项目封面图 | 非必填 | JPG/PNG，不超过2MB，用于App端培训中心展示 |

**方式二：Excel 批量导入**

> 📌 对应操作手册：**PDF-223** 第二部分"点击导入，下载一个系统模板"

操作步骤：
1. 点击「导入」按钮，弹出导入引导弹窗；
2. 点击「下载模板」，获取含必填列红色标注的 Excel 模板；
3. 填写完成后，点击「选择文件」上传，后端解析并校验；
4. 校验通过后显示预览（成功N条/失败N条及原因），点击「确认导入」提交；
5. 提示「导入成功」，即可在列表中查看导入的立项数据；

**Excel 模板必填列（标红列）：**
- 项目名称、培训类型（线上/线下/混合）、是否必修（是/否）、计划学时、项目起始日期（yyyy-MM-dd）、项目截止日期（yyyy-MM-dd）

**非必填列（蓝色列）：**
- 培训目标、适用职级（多个用逗号分隔）、项目说明

---

### 2.3 状态管理

**立项状态机：**

```
草稿(0) → [手动激活/起始日期到达] → 进行中(1) → [截止日期到达] → 已结束(2)
草稿(0) → [手动关闭] → 已关闭(3)
进行中(1) → [手动关闭] → 已关闭(3)
```

**定时任务：**
- 每天凌晨0点：扫描 status=0 且 start_date <= 今日的立项，自动更新为进行中（status=1）；
- 每天凌晨0点：扫描 status=1 且 end_date < 今日的立项，自动更新为已结束（status=2）；

**App 端联动规则：**
- status=1（进行中）的项目，在代理人 App 端「培训中心」自动展示；
- 项目封面图作为 App 端培训课程卡片封面；
- is_required=1 的必修项目在 App 端标注「必修」标签；

---

### 2.4 删除限制

- 已有关联培训计划的立项不可删除，需先删除所有关联计划；
- 已结束（status=2）的立项执行逻辑删除（deleted=1），保留历史数据；
- 草稿状态可物理删除（需二次确认）；

---

### 2.5 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/train/project/page | GET | 分页查询 |
| /admin-api/train/project/get/{id} | GET | 详情 |
| /admin-api/train/project/create | POST | 新增 |
| /admin-api/train/project/update | PUT | 编辑 |
| /admin-api/train/project/delete | DELETE | 删除 |
| /admin-api/train/project/import | POST | 批量Excel导入 |
| /admin-api/train/project/template | GET | 下载导入模板 |

权限标识：train:project:read / train:project:write / train:project:delete / train:project:import

---

## 三、培训计划管理 *(PDF-224)*

### 3.1 功能入口

菜单路径：营销管理 → 培训管理 → 培训计划

列表页展示：计划名称、所属项目、培训讲师（姓名）、培训地点（线下）/培训链接（线上）、报名截止时间、开始时间、结束时间、最大学员数、已报名人数、状态（草稿/报名中/进行中/已结束）、操作（编辑/删除/查看学员）。

筛选条件：所属项目、培训讲师、状态、时间范围。

---

### 3.2 新增/编辑培训计划

> 📌 对应操作手册：**PDF-224** 第一部分"点击新增，可以单独增加培训计划"

**方式一：手动新增**

点击「新增」按钮，弹出培训计划表单：

| 字段 | 是否必填（★=必填）| 校验规则 |
|------|-----------------|----------|
| 计划名称 ★ | 必填 | 2-100字符 |
| 所属项目 ★ | 必填 | 下拉选择已有立项（状态：进行中），一个项目下可创建多个计划 |
| 培训讲师 ★ | 必填 | 从讲师库中选择，支持关键词搜索 |
| 培训地点 | 条件必填 | 培训类型=线下/混合时必填，最长200字符 |
| 线上培训链接 | 条件必填 | 培训类型=线上/混合时必填，须以http/https开头 |
| 开始时间 ★ | 必填 | 须在所属项目的起止日期范围内 |
| 结束时间 ★ | 必填 | 须晚于开始时间 |
| 报名截止时间 ★ | 必填 | 须早于开始时间 |
| 最大学员数 ★ | 必填 | 正整数，0表示不限 |
| 课程清单 | 非必填 | 从课程库中多选，可拖拽排序（课程学习顺序） |
| 计划说明 | 非必填 | 最长1000字符 |

**后端校验逻辑：**
1. 开始时间须在所属立项的 start_date ～ end_date 范围内；
2. 报名截止时间须 < 开始时间；
3. 同一立项下，多个计划的时间可以重叠（允许并行计划）；
4. 若选择了课程清单，校验课程状态均须为已上架；

**方式二：Excel 批量导入**

> 📌 对应操作手册：**PDF-224** 第二部分"点击导入，下载一个系统模板"

操作步骤同培训立项导入，下载模板 → 填写必填列 → 上传 → 确认导入。

**Excel 模板必填列：**
- 计划名称、所属项目名称（须与系统中一致）、讲师姓名（须与讲师库一致）、开始时间（yyyy-MM-dd HH:mm）、结束时间、报名截止时间、最大学员数（0=不限）

---

### 3.3 状态管理

**计划状态机：**

```
草稿(0) → [报名开始，定时任务] → 报名中(1) → [开始时间到达] → 进行中(2) → [结束时间到达] → 已结束(3)
```

**定时任务（每分钟执行）：**
- 扫描状态=0、且当前时间 < 报名截止时间的计划，检查是否已有学员报名，有则切换为「报名中」；
- 实际上：**计划状态切换条件** → 当立项状态变为进行中时，系统自动将其下所有草稿计划变为「报名中」；
- 进行中(2)且到达结束时间 → 自动变为已结束(3)；

**学员报名：**
- App 端学员在「培训中心」查看进行中项目，选择对应计划报名；
- 报名条件：当前时间 < 报名截止时间 且 已报名人数 < 最大学员数（0则不限）；
- 报名成功：插入 train_plan_member 表，push 通知学员；
- 报名人数上限提示：当已报名 >= 最大学员数时，C端展示「名额已满」；

---

### 3.4 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/train/plan/page | GET | 分页查询 |
| /admin-api/train/plan/get/{id} | GET | 详情 |
| /admin-api/train/plan/create | POST | 新增 |
| /admin-api/train/plan/update | PUT | 编辑 |
| /admin-api/train/plan/delete | DELETE | 删除 |
| /admin-api/train/plan/import | POST | 批量Excel导入 |
| /admin-api/train/plan/member/list | GET | 查看报名学员列表 |
| /admin-api/train/plan/template | GET | 下载导入模板 |

---

## 四、课程管理 *(PDF-225)*

### 4.1 功能入口

菜单路径：营销管理 → 培训管理 → 课程管理

列表页展示：课程封面（缩略图）、课程名称、所属分类、课程类型（视频/文档/直播）、课时（小时）、适用职级、状态（已上架/已下架/草稿）、被引用次数（关联培训计划数）、操作（编辑/上下架/删除/预览）。

筛选条件：所属分类（树形多选）、课程类型、状态、适用职级、关键词。

---

### 4.2 课程分类管理

- 课程分类采用两级树状结构（一级分类 + 二级子分类）；
- 新增/编辑分类：分类名称（必填）、图标（非必填）、排序号（必填）；
- 删除分类：后端校验该分类下是否有课程，有则不允许删除；
- 禁用分类：该分类下的课程在 App 端不展示；

---

### 4.3 新增/编辑课程

> 📌 对应操作手册：**PDF-225** 第一部分"点击新增，可以单独增加培训课程"

**方式一：手动新增**

| 字段 | 是否必填（★=必填）| 校验规则 |
|------|-----------------|----------|
| 课程名称 ★ | 必填 | 2-100字符 |
| 所属分类 ★ | 必填 | 选择末级分类 |
| 课程类型 ★ | 必填 | 单选：视频/文档/直播 |
| 课程封面图 ★ | 必填 | JPG/PNG，不超过2MB，建议16:9比例 |
| 计划课时 ★ | 必填 | 正整数，单位：小时 |
| 适用职级 | 非必填 | 多选，来自组织管理职级枚举，不选表示全部职级 |
| 关键词 | 非必填 | 最多5个，逗号分隔，用于搜索 |
| 课程简介 | 非必填 | 最长500字符 |
| 课程目标 | 非必填 | 最长1000字符 |
| 排序号 ★ | 必填 | 整数 |

**课程类型特殊字段：**

| 类型 | 额外必填字段 | 说明 |
|------|------------|------|
| 视频 | 课程章节（至少1个章节）| 分章节上传视频文件，每章节含章节名+视频文件；视频上传至阿里云 VOD 或 OSS；支持断点续传+进度显示 |
| 文档 | 文档文件（至少1个）| 支持PDF/Word/PPT，上传至 OSS；前端使用文档预览组件（如 pdf.js）展示 |
| 直播 | 直播链接 + 直播时间 | 填写第三方直播平台链接（腾讯会议/钉钉等）和直播开始时间，直播前30分钟推送提醒通知 |

**视频课程章节管理：**
- 支持添加多个章节，每章节填写：章节名（必填）、章节视频（必填）、章节时长（自动从视频元数据读取，可手动修改）、章节说明（非必填）；
- 支持拖拽调整章节顺序；
- 删除章节：弹出二次确认框；
- 章节视频上传：同视频管理模块的上传流程（前端获取 VOD/OSS 上传凭证 → SDK 直传 → 回传视频ID）；

**方式二：Excel 批量导入**

> 📌 对应操作手册：**PDF-225** 第二部分"点击导入，下载一个系统模板"

适用于批量导入课程基础信息（不含视频/文件，视频需后续单独上传），操作步骤同立项导入。

**Excel 模板必填列：**
- 课程名称、所属分类名称、课程类型（视频/文档/直播）、计划课时

---

### 4.4 上架与删除限制

**上架：**
- 视频课程：须至少有1个章节且对应视频转码成功，才可上架；
- 文档课程：须上传至少1个文档，才可上架；
- 直播课程：须填写有效的直播链接，才可上架；

**删除限制：**
- 课程被培训计划引用时（train_plan_course.course_id 有关联记录）不可删除，提示「该课程已关联X个培训计划，请先移除关联后再删除」；
- 已上架课程须先下架再删除；
- 执行逻辑删除（deleted=1）；

---

### 4.5 学习进度追踪

学员在 App 端学习课程时，前端定期上报学习进度：

**视频课程：**
- 每30秒上报一次当前观看时长；
- 后端更新 train_learn_record.watch_duration；
- 计算完成进度 = watch_duration / total_duration * 100%；
- watch_duration >= total_duration * 80% 视为本章节完成；

**文档课程：**
- 前端上报文档翻页事件（每次翻页记录最大已读页码）；
- 后端记录已读页数，read_pages >= total_pages 视为完成；

**直播课程：**
- 学员点击直播链接即记录为「已参与」；

---

### 4.6 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/train/course/page | GET | 分页查询 |
| /admin-api/train/course/get/{id} | GET | 详情（含章节） |
| /admin-api/train/course/create | POST | 新增 |
| /admin-api/train/course/update | PUT | 编辑 |
| /admin-api/train/course/delete | DELETE | 删除 |
| /admin-api/train/course/update-status | PUT | 上下架 |
| /admin-api/train/course/import | POST | 批量Excel导入 |
| /admin-api/train/course/template | GET | 下载导入模板 |
| /admin-api/train/course/chapter/save | POST | 保存章节（含视频ID） |
| /admin-api/train/course/upload-cover | POST | 上传封面 |
| /admin-api/train/course/upload-doc | POST | 上传文档 |
| /admin-api/train/course/category/tree | GET | 分类树 |
| /admin-api/train/course/category/create | POST | 新增分类 |

权限标识：train:course:read / train:course:write / train:course:delete / train:course:status / train:course:category

---

## 五、讲师管理 *(PDF-226)*

### 5.1 功能入口

菜单路径：营销管理 → 培训管理 → 讲师管理

列表页展示：讲师头像、姓名、所属机构、专业领域、联系方式（脱敏）、讲师评分（0-5分，汇总自培训结果反馈）、累计授课次数、状态（启用/禁用）、操作（编辑/删除/查看授课记录）。

筛选条件：所属机构、专业领域、状态、关键词（姓名）。

---

### 5.2 新增/编辑讲师

> 📌 对应操作手册：**PDF-226** "点击新增，可以单独增加培训讲师"

**方式一：手动新增**

| 字段 | 是否必填（★=必填）| 校验规则 |
|------|-----------------|----------|
| 讲师姓名 ★ | 必填 | 2-50字符 |
| 讲师头像 | 非必填 | JPG/PNG，不超过1MB，正方形比例，系统默认使用头像占位图 |
| 所属机构 ★ | 必填 | 从组织架构中选择，支持关键词搜索 |
| 联系电话 ★ | 必填 | 手机号格式校验（11位数字） |
| 邮箱 | 非必填 | Email格式校验 |
| 专业领域 ★ | 必填 | 多选标签（来自字典表），如：车险/寿险/非车险/法律合规/销售技能/产品知识 |
| 讲师简介 | 非必填 | 最长500字符 |
| 资质认证 | 非必填 | 文本描述，最长200字符，如「国家认证理财规划师CFP」 |
| 状态 ★ | 必填 | 默认启用，禁用后不可在培训计划中选择 |

**方式二：Excel 批量导入**

> 📌 对应操作手册：**PDF-226** "点击导入，下载一个系统模板"

操作步骤同立项导入。

**Excel 模板必填列：**
- 讲师姓名、所属机构名称、联系电话、专业领域（多个用逗号分隔）

---

### 5.3 讲师评分计算

- 评分数据来源：培训结果（PDF-228）中学员的满意度问卷回答；
- 每次培训结束后，学员提交问卷，其中「讲师评分」字段（1-5星）；
- 后端计算：该讲师所有历次培训的评分算术平均值，保留1位小数；
- 每次有新评分提交时，异步触发讲师评分重新计算（MQ处理）；
- 分布展示：在讲师详情页展示评分分布（五星/四星/三星/二星/一星各占百分比）；

---

### 5.4 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/train/teacher/page | GET | 分页查询 |
| /admin-api/train/teacher/get/{id} | GET | 详情 |
| /admin-api/train/teacher/create | POST | 新增 |
| /admin-api/train/teacher/update | PUT | 编辑 |
| /admin-api/train/teacher/delete | DELETE | 删除 |
| /admin-api/train/teacher/import | POST | 批量Excel导入 |
| /admin-api/train/teacher/template | GET | 下载导入模板 |
| /admin-api/train/teacher/upload-avatar | POST | 上传头像 |

权限标识：train:teacher:read / train:teacher:write / train:teacher:delete / train:teacher:import

---

## 六、培训班管理 *(PDF-227)*

### 6.1 功能入口

菜单路径：营销管理 → 培训管理 → 培训班管理

培训班是培训计划的具体执行单元，一个培训计划下可存在一个或多个培训班（按期次划分，如第一期、第二期）。

列表页展示：培训班名称、所属计划、所属项目、讲师、期次、开班时间、结业时间、学员数/最大学员数、签到状态（未开始/进行中/已结束）、完成率、操作（查看/编辑/学员管理/导出考勤表/签到二维码）。

筛选条件：所属项目、所属计划、状态、时间范围。

---

### 6.2 新增/编辑培训班

> 📌 对应操作手册：**PDF-227** "点击新增，可以单独增加培训班"

**方式一：手动新增**

| 字段 | 是否必填（★=必填）| 校验规则 |
|------|-----------------|----------|
| 培训班名称 ★ | 必填 | 如「2024年第一期车险销售技能培训班」，2-100字符 |
| 所属计划 ★ | 必填 | 从已有计划中选择，下拉选择（状态：报名中/进行中） |
| 期次 ★ | 必填 | 正整数，如1、2、3，同一计划内不可重复 |
| 讲师 | 非必填 | 可覆盖计划中的讲师设置；从讲师库选择 |
| 开班时间 ★ | 必填 | 须在所属计划时间范围内 |
| 结业时间 ★ | 必填 | 须晚于开班时间 |
| 培训地点 | 条件必填 | 线下/混合培训时必填 |
| 最大学员数 ★ | 必填 | 正整数，0不限 |
| 班级说明 | 非必填 | 最长500字符 |

**方式二：Excel 批量导入**

> 📌 对应操作手册：**PDF-227** "点击导入，下载一个系统模板"

**Excel 模板必填列：**
- 培训班名称、所属计划名称、期次、开班时间（yyyy-MM-dd HH:mm）、结业时间、最大学员数

---

### 6.3 学员管理

**查看报名学员名单（管理员操作）：**
- 进入「学员管理」标签页，展示该培训班所有报名学员列表；
- 字段：姓名、工号、所属机构、报名时间、签到状态、学习进度（视频完成百分比/文档阅读进度）、课后问卷完成状态；
- 支持搜索（姓名/工号）、排序（报名时间/学习进度）；
- 批量操作：批量移除学员（弹出二次确认）、批量补签（管理员代为记录签到）；

**手动添加学员：**
- 管理员可在培训班学员管理页手动搜索用户（工号/姓名）添加至培训班；
- 批量添加：上传 Excel（含工号列），后端解析并校验工号有效性；

---

### 6.4 签到管理

**线下扫码签到：**
- 培训班详情页点击「签到二维码」，生成含 plan_member_id 的二维码（有效期24小时，每次打开重新生成）；
- 学员用 App 扫码 → App 端校验二维码合法性 → 记录签到（train_sign_record）；
- 签到时间限制：仅在培训班 start_time 前1小时至 end_time 后30分钟内有效；
- 重复扫码：已签到的学员再次扫码提示「您已签到」，不重复记录；

**线上学习签到：**
- 线上视频课：学员开始观看视频时自动记录签到时间（首次观看即签到）；
- 线上直播课：学员点击直播链接时记录签到；

**导出考勤表：**
- 点击「导出考勤表」按钮，异步生成 Excel；
- Excel 字段：姓名、工号、所属机构、签到时间、签到方式（扫码/线上）、是否签到（是/否）、备注；
- 异步生成完成后，下载链接可在「任务中心」或页面弹窗中获取；

---

### 6.5 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/train/class/page | GET | 分页查询 |
| /admin-api/train/class/get/{id} | GET | 详情 |
| /admin-api/train/class/create | POST | 新增 |
| /admin-api/train/class/update | PUT | 编辑 |
| /admin-api/train/class/delete | DELETE | 删除 |
| /admin-api/train/class/import | POST | 批量Excel导入 |
| /admin-api/train/class/member/list | GET | 学员列表 |
| /admin-api/train/class/member/add | POST | 手动添加学员 |
| /admin-api/train/class/member/remove | DELETE | 移除学员 |
| /admin-api/train/class/member/batch-add | POST | 批量导入学员 |
| /admin-api/train/class/sign/qrcode | GET | 生成签到二维码 |
| /admin-api/train/class/sign/manual | POST | 管理员手动补签 |
| /admin-api/train/class/export-attendance | GET | 导出考勤表 |

---

## 七、培训结果统计 *(PDF-228)*

### 7.1 功能入口

菜单路径：营销管理 → 培训管理 → 培训结果

提供培训结果的录入（导入）、查询、导出功能，并聚合展示学员完成率、考试成绩、满意度评分等核心指标。

---

### 7.2 培训结果录入

> 📌 对应操作手册：**PDF-228** "点击导入，下载一个系统模板"

**Excel 批量导入方式（主要录入方式）：**
- 培训结果中的「考试成绩」字段由线下考试完成后，管理员统一导入；
- 操作步骤：下载系统模板 → 填写必填项 → 上传 → 确认导入；
- 点击确定，提示「导入成功」，可在列表查看导入的培训结果数据；

**Excel 模板必填列（标红列）：**
- 培训班名称（须与系统一致）、学员工号、考试成绩（0-100的数字，未考填「-」）

**非必填列（蓝色列）：**
- 备注、实际出勤天数（若有多天培训）

**自动生成的结果数据（系统自动汇总，无需手动导入）：**
- 视频课完成率（由 App 端学习进度自动计算）；
- 文档阅读完成率；
- 签到记录（来自培训班签到模块）；
- 满意度评分（来自学员课后问卷）；

---

### 7.3 培训结果查询

> 📌 对应操作手册：**PDF-228** "根据筛选条件，可以查询系统中的培训结果"

**筛选条件：**
- 所属项目（下拉）、所属计划（级联下拉）、培训班（级联下拉）、学员姓名/工号、完成状态（已完成/未完成/进行中）、时间范围；

**列表字段展示：**
- 学员姓名、工号、所属机构、培训班名称、签到状态（是/否）、视频完成率（百分比）、文档阅读率（百分比）、考试成绩（0-100或「-」）、满意度评分（1-5星或「未填」）、是否完成（综合判定：签到+完成率>=80%+成绩>=60分视为完成）、培训结束日期；

**统计聚合视图（点击上方「统计汇总」Tab切换）：**
- 按项目维度：展示各项目的学员总数、完成率、平均成绩、平均满意度；
- 按讲师维度：展示各讲师的授课次数、学员总数、平均满意度评分；
- 按机构维度：展示各机构的参培率、完成率、平均成绩对比（柱状图）；

---

### 7.4 催学提醒

**触发条件：**
- 进行中的培训班，距截止日期7天、3天、1天时，自动触发催学提醒；
- 筛选目标：该培训班的学员中，视频/文档完成率 < 80% 的学员；

**提醒方式：**
- 站内消息（App 内推送）：「[培训班名称] 将于X天后截止，您的学习进度为XX%，请尽快完成学习！」；
- 可选：短信提醒（若平台配置了短信通道）；
- 必修项目的催学提醒优先级更高，短信提醒强制开启（若平台有短信能力）；

---

### 7.5 课后问卷（满意度收集）

**问卷触发条件：**
- 培训班结束后（结业时间到达），App 端自动推送问卷通知给学员；
- 学员须在培训结束后7天内完成问卷，超时不可填写；

**问卷内容（固定模板，可在系统配置中修改）：**
1. 讲师评分（必填，1-5星）；
2. 课程内容评分（必填，1-5星）；
3. 培训组织评分（必填，1-5星）；
4. 开放评价（非必填，最长500字符）；
5. 是否推荐该培训给同事（必填，是/否）；

**后端处理：**
- 学员提交问卷 → 写入 train_feedback 表；
- 异步触发讲师评分重新计算（MQ）；
- 当天所有问卷汇总后更新培训班的平均满意度字段；

---

### 7.6 导出

> 📌 对应操作手册：**PDF-228** "点击导出，跳转任务列表，查看导出的结果"

- 点击「导出」按钮，后端异步生成 Excel 报表；
- 系统跳转至任务列表（或弹窗提示）：「导出任务已提交，完成后可在任务中心下载」；
- Excel 内容与当前筛选条件匹配，包含列表中所有字段；
- 支持导出：培训结果明细表、考勤汇总表、满意度汇总表；

---

### 7.7 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/train/result/page | GET | 分页查询 |
| /admin-api/train/result/import | POST | 批量导入考试成绩 |
| /admin-api/train/result/template | GET | 下载导入模板 |
| /admin-api/train/result/export | GET | 导出结果报表 |
| /admin-api/train/result/summary | GET | 统计汇总（项目/讲师/机构维度） |
| /admin-api/train/result/feedback/list | GET | 问卷反馈列表 |
| /admin-api/train/result/remind | POST | 手动触发催学提醒 |

权限标识：train:result:read / train:result:write / train:result:export

---

## 八、数据库表设计（培训管理模块）

### train_project（培训立项）

```sql
CREATE TABLE `train_project` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `project_no` varchar(32) NOT NULL UNIQUE COMMENT '项目编号 TRAIN+yyyyMMdd+4位序号',
  `name` varchar(100) NOT NULL COMMENT '项目名称',
  `type` tinyint NOT NULL COMMENT '1线上2线下3混合',
  `goal` text DEFAULT NULL COMMENT '培训目标',
  `target_level` varchar(500) DEFAULT NULL COMMENT '适用职级JSON数组',
  `target_org` text DEFAULT NULL COMMENT '适用机构JSON',
  `is_required` tinyint NOT NULL DEFAULT '0' COMMENT '0非必修1必修',
  `plan_hours` int NOT NULL DEFAULT '0' COMMENT '计划学时(小时)',
  `start_date` date NOT NULL COMMENT '项目起始日期',
  `end_date` date NOT NULL COMMENT '项目截止日期',
  `cover_image` varchar(500) DEFAULT NULL COMMENT '封面图',
  `description` text DEFAULT NULL,
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0草稿1进行中2已结束3已关闭',
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_status_date` (`status`, `start_date`, `end_date`)
) COMMENT='培训立项';
```

### train_plan（培训计划）

```sql
CREATE TABLE `train_plan` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `project_id` bigint NOT NULL COMMENT '所属立项ID',
  `name` varchar(100) NOT NULL COMMENT '计划名称',
  `teacher_id` bigint DEFAULT NULL COMMENT '讲师ID',
  `location` varchar(200) DEFAULT NULL COMMENT '培训地点(线下)',
  `online_link` varchar(500) DEFAULT NULL COMMENT '线上培训链接',
  `start_time` datetime NOT NULL COMMENT '开始时间',
  `end_time` datetime NOT NULL COMMENT '结束时间',
  `register_deadline` datetime NOT NULL COMMENT '报名截止时间',
  `max_member` int NOT NULL DEFAULT '0' COMMENT '最大学员数,0不限',
  `current_member` int NOT NULL DEFAULT '0' COMMENT '已报名人数',
  `course_ids` text DEFAULT NULL COMMENT '课程清单JSON数组(有序)',
  `description` text DEFAULT NULL,
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0草稿1报名中2进行中3已结束',
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_project_status` (`project_id`, `status`)
) COMMENT='培训计划';
```

### train_course（课程库）

```sql
CREATE TABLE `train_course` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `category_id` bigint NOT NULL COMMENT '分类ID',
  `name` varchar(100) NOT NULL COMMENT '课程名称',
  `type` tinyint NOT NULL COMMENT '1视频2文档3直播',
  `cover_image` varchar(500) NOT NULL,
  `plan_hours` int NOT NULL COMMENT '计划课时(小时)',
  `target_level` varchar(500) DEFAULT NULL COMMENT '适用职级JSON',
  `keywords` varchar(200) DEFAULT NULL,
  `summary` varchar(500) DEFAULT NULL,
  `goal` text DEFAULT NULL,
  `live_link` varchar(500) DEFAULT NULL COMMENT '直播链接',
  `live_start_time` datetime DEFAULT NULL COMMENT '直播时间',
  `ref_count` int NOT NULL DEFAULT '0' COMMENT '被引用次数',
  `sort_order` int NOT NULL DEFAULT '0',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0草稿1已上架2已下架',
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_category_status` (`category_id`, `status`)
) COMMENT='课程库';
```

### train_course_chapter（课程章节）

```sql
CREATE TABLE `train_course_chapter` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `course_id` bigint NOT NULL,
  `chapter_name` varchar(100) NOT NULL,
  `video_id` varchar(100) DEFAULT NULL COMMENT '阿里云VOD视频ID',
  `video_url` varchar(500) DEFAULT NULL COMMENT '视频播放地址',
  `duration` int DEFAULT NULL COMMENT '视频时长(秒)',
  `doc_url` varchar(500) DEFAULT NULL COMMENT '文档URL',
  `doc_pages` int DEFAULT NULL COMMENT '文档总页数',
  `sort_order` int NOT NULL DEFAULT '0',
  `description` varchar(500) DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_course_sort` (`course_id`, `sort_order`)
) COMMENT='课程章节';
```

### train_teacher（讲师库）

```sql
CREATE TABLE `train_teacher` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL COMMENT '讲师姓名',
  `avatar` varchar(500) DEFAULT NULL,
  `org_id` bigint NOT NULL COMMENT '所属机构ID',
  `phone` varchar(20) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `specialties` varchar(500) DEFAULT NULL COMMENT '专业领域JSON数组',
  `bio` varchar(500) DEFAULT NULL COMMENT '讲师简介',
  `qualification` varchar(200) DEFAULT NULL COMMENT '资质认证',
  `score` decimal(3,1) NOT NULL DEFAULT '0.0' COMMENT '讲师评分(0-5)',
  `teach_count` int NOT NULL DEFAULT '0' COMMENT '累计授课次数',
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '0禁用1启用',
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) COMMENT='讲师库';
```

### train_class（培训班）

```sql
CREATE TABLE `train_class` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `plan_id` bigint NOT NULL COMMENT '所属计划ID',
  `project_id` bigint NOT NULL COMMENT '所属立项ID(冗余)',
  `name` varchar(100) NOT NULL COMMENT '培训班名称',
  `session` int NOT NULL DEFAULT '1' COMMENT '期次',
  `teacher_id` bigint DEFAULT NULL COMMENT '覆盖计划中的讲师',
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  `location` varchar(200) DEFAULT NULL,
  `max_member` int NOT NULL DEFAULT '0',
  `current_member` int NOT NULL DEFAULT '0',
  `complete_rate` decimal(5,2) NOT NULL DEFAULT '0.00' COMMENT '整体完成率',
  `avg_score` decimal(4,1) DEFAULT NULL COMMENT '平均考试成绩',
  `avg_satisfaction` decimal(3,1) DEFAULT NULL COMMENT '平均满意度',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0未开始1进行中2已结束',
  `description` text DEFAULT NULL,
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_plan_session` (`plan_id`, `session`),
  UNIQUE KEY `uk_plan_session` (`plan_id`, `session`)
) COMMENT='培训班';
```

### train_plan_member（学员名单）

```sql
CREATE TABLE `train_plan_member` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `class_id` bigint NOT NULL COMMENT '培训班ID',
  `plan_id` bigint NOT NULL,
  `user_id` bigint NOT NULL COMMENT '学员用户ID',
  `register_time` datetime NOT NULL COMMENT '报名时间',
  `is_signed` tinyint NOT NULL DEFAULT '0' COMMENT '0未签到1已签到',
  `sign_time` datetime DEFAULT NULL,
  `sign_type` tinyint DEFAULT NULL COMMENT '1扫码2线上3手动补签',
  `video_progress` decimal(5,2) NOT NULL DEFAULT '0.00' COMMENT '视频完成率',
  `doc_progress` decimal(5,2) NOT NULL DEFAULT '0.00' COMMENT '文档阅读率',
  `exam_score` decimal(5,2) DEFAULT NULL COMMENT '考试成绩',
  `is_complete` tinyint NOT NULL DEFAULT '0' COMMENT '0未完成1已完成',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_class_user` (`class_id`, `user_id`),
  KEY `idx_user_id` (`user_id`)
) COMMENT='培训班学员名单';
```

### train_learn_record（学习进度）

```sql
CREATE TABLE `train_learn_record` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `class_id` bigint NOT NULL COMMENT '培训班ID',
  `course_id` bigint NOT NULL COMMENT '课程ID',
  `chapter_id` bigint DEFAULT NULL COMMENT '章节ID(视频课)',
  `watch_duration` int NOT NULL DEFAULT '0' COMMENT '已观看时长(秒)',
  `total_duration` int DEFAULT NULL COMMENT '课程总时长(秒)',
  `read_pages` int NOT NULL DEFAULT '0' COMMENT '已读页数',
  `total_pages` int DEFAULT NULL COMMENT '文档总页数',
  `progress` decimal(5,2) NOT NULL DEFAULT '0.00' COMMENT '完成进度(%)',
  `is_complete` tinyint NOT NULL DEFAULT '0' COMMENT '0未完成1已完成',
  `last_learn_time` datetime DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_class` (`user_id`, `class_id`),
  KEY `idx_class_course` (`class_id`, `course_id`)
) COMMENT='学习进度记录';
```

### train_feedback（课后问卷）

```sql
CREATE TABLE `train_feedback` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `class_id` bigint NOT NULL COMMENT '培训班ID',
  `user_id` bigint NOT NULL COMMENT '学员ID',
  `teacher_score` tinyint NOT NULL COMMENT '讲师评分1-5',
  `content_score` tinyint NOT NULL COMMENT '内容评分1-5',
  `org_score` tinyint NOT NULL COMMENT '组织评分1-5',
  `recommend` tinyint NOT NULL DEFAULT '0' COMMENT '0否1是',
  `comment` varchar(500) DEFAULT NULL COMMENT '开放评价',
  `submit_time` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_class_user` (`class_id`, `user_id`),
  KEY `idx_class_id` (`class_id`)
) COMMENT='培训课后问卷反馈';
```

---

## 九、定时任务（培训管理模块）

| 任务名称 | Cron表达式 | 功能说明 |
|---------|-----------|----------|
| 培训立项状态自动切换 | 0 0 0 * * ? | 每天凌晨0点：到期立项→进行中；过期立项→已结束 |
| 培训班状态自动切换 | 0 * * * * ? | 每分钟：开始时间到达→进行中；结束时间到达→已结束 |
| 培训催学提醒 | 0 0 9 * * ? | 每天上午9点：检查距截止日期7/3/1天的未完成学员，发送提醒 |
| 直播前提醒 | 0 * * * * ? | 每分钟：检查30分钟后开始的直播课程，推送提醒通知 |
| 讲师评分重新计算 | 由MQ触发 | 每次问卷提交后异步触发，重新计算讲师评分 |
| 培训班完成率汇总 | 0 0 1 * * ? | 每天凌晨1点：汇总各培训班学员完成率至 train_class.complete_rate |

---

## 十、权限标识汇总

```
train:project:read       # 培训立项查看
train:project:write      # 培训立项创建/编辑
train:project:delete     # 培训立项删除
train:project:import     # 培训立项批量导入

train:plan:read          # 培训计划查看
train:plan:write         # 培训计划创建/编辑
train:plan:delete        # 培训计划删除
train:plan:import        # 培训计划批量导入

train:course:read        # 课程管理查看
train:course:write       # 课程管理创建/编辑
train:course:delete      # 课程管理删除
train:course:status      # 课程上下架
train:course:category    # 课程分类管理
train:course:import      # 课程批量导入

train:teacher:read       # 讲师管理查看
train:teacher:write      # 讲师管理创建/编辑
train:teacher:delete     # 讲师管理删除
train:teacher:import     # 讲师批量导入

train:class:read         # 培训班查看
train:class:write        # 培训班创建/编辑
train:class:delete       # 培训班删除
train:class:member       # 学员管理
train:class:sign         # 签到管理
train:class:export       # 导出考勤表
train:class:import       # 培训班批量导入

train:result:read        # 培训结果查看
train:result:write       # 培训结果导入
train:result:export      # 培训结果导出
```

---

*文档完结。本篇为阶段3-PC营销管理详细需求设计文档补充篇，覆盖培训管理全部功能点（PDF-222 至 PDF-228）。*

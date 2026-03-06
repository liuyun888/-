# 阶段3 B端业务员App-营销工具 业务逻辑设计文档（下篇）
## 覆盖模块：培训中心（课程列表、课程详情、在线考试、学习记录、证书管理）

> 本文档面向前后端开发人员，聚焦业务流程、字段规则、接口行为、数据库入库。

---

## 七、培训中心模块

### 7.1 课程列表页

#### 7.1.1 页面说明

业务员App进入「营销工具→培训中心」，展示培训课程列表。

**页面交互**：
- 顶部搜索框：支持按课程名搜索
- 分类Tab：全部 / 新人培训 / 产品培训 / 销售技巧 / 法规培训 / 进阶课程（分类由PC管理后台配置，前端动态获取）
- 筛选条件（可下拉选择）：
  - 课程类型：全部 / 视频 / 图文 / 音频（`course_type`：1-视频 2-图文 3-音频 4-直播）
  - 难度：全部 / 入门 / 进阶 / 高级（`difficulty`：1-入门 2-进阶 3-高级）
- 课程卡片展示：
  - 封面图（`cover_url`）
  - 课程名称（`course_name`）
  - 讲师姓名（`teacher_name`）
  - 总时长（`duration`秒，转换为"X分钟"或"X小时X分"格式）
  - 已学人数（`study_count`）
  - 「必修」红色标签（`is_required=true`时展示）
  - 我的进度（若已学习过，显示进度条和百分比）
- 排序：`sort ASC`，必修课程优先置顶（`is_required=true AND status=1`先展示）

**后端接口**：`GET /app-api/marketing/course/page`

**请求参数**：
| 字段 | 必填 | 说明 |
|---|---|---|
| keyword | 否 | 搜索关键词 |
| categoryId | 否 | 分类ID |
| courseType | 否 | 课程类型 |
| difficulty | 否 | 难度 |
| pageNo | 是 | 页码 |
| pageSize | 是 | 每页数量 |

**后端逻辑**：
1. 查询`marketing_course`，WHERE `status=1 AND deleted=0 AND tenant_id=当前租户`
2. 如有keyword，加`course_name LIKE '%keyword%'`条件
3. 联查`marketing_user_study_record`，获取当前用户对每门课的学习进度（`study_progress`）
4. 排序：`is_required DESC, sort ASC`
5. 返回列表，含`studyProgress`（0-100，0表示未学）、`isCompleted`字段

---

### 7.2 课程详情页

#### 7.2.1 页面交互

业务员点击某课程卡片进入课程详情页。

**页面内容**：
- 顶部：封面图（视频课展示视频播放区域，可点击播放第一章预览或付费章节的免费试看）
- 课程基本信息：课程名、讲师姓名、讲师介绍、课程简介（`introduction`）
- 数据统计：X章节 / X分钟 / X人已学
- 我的进度（已学时展示）：进度条、百分比、当前学到第X章
- 章节列表（`marketing_course_chapter`）：
  - 章节序号、章节名称（`chapter_name`）
  - 时长（若有）
  - 「免费试看」标签（`is_free=true`）
  - 已完成章节显示「✓」勾选图标
  - 当前正在学的章节高亮
- 底部固定按钮：
  - 未开始学：「开始学习」（进入第一章）
  - 学习中：「继续学习」（进入上次学习的章节，定位到上次播放位置）
  - 已完成：「已完成 查看证书」（有考试则跳考试，无考试直接看证书）
- 若课程绑定了考试（`marketing_exam.course_id = 当前课程ID`），展示「参加考试」按钮（课程进度≥95%时才可点击）

**后端接口**：`GET /app-api/marketing/course/{id}`

**后端逻辑**：
1. 查询`marketing_course`
2. 查询`marketing_course_chapter`列表，按`sort ASC`
3. 查询`marketing_user_study_record`获取当前用户学习进度（chapter_id、last_position、study_progress、is_completed）
4. 查询该课程绑定的考试（`marketing_exam.course_id = courseId AND status=1`，取最新一条）
5. 组装返回

**返回结构示例**：
```json
{
  "id": 1,
  "courseName": "车险产品知识培训",
  "categoryId": 2,
  "coverUrl": "https://...",
  "introduction": "本课程介绍...",
  "teacherName": "张老师",
  "teacherIntro": "10年保险从业经验...",
  "courseType": 1,
  "difficulty": 1,
  "duration": 3600,
  "chapterCount": 5,
  "studyCount": 200,
  "isRequired": true,
  "chapters": [
    {"id":1,"chapterName":"第一章：车险概述","sort":1,"duration":600,"isFree":true,"contentUrl":"https://..."},
    {"id":2,"chapterName":"第二章：交强险详解","sort":2,"duration":900,"isFree":false,"contentUrl":"https://..."}
  ],
  "myProgress": {
    "studyProgress": 40,
    "currentChapterId": 1,
    "lastPosition": 300,
    "isCompleted": false
  },
  "examId": 5
}
```

---

### 7.3 课程学习页（章节播放）

#### 7.3.1 视频课学习页

**页面交互**：
- 顶部视频播放器，支持倍速播放（0.75x / 1x / 1.25x / 1.5x / 2x）
- 进入时自动定位到上次学习位置（`last_position`秒）
- 播放器下方：章节名称、章节列表（可切换章节）
- 底部：上一章 / 下一章 按钮
- 每隔5秒上报一次播放进度（节流处理，避免频繁请求）

**进度上报接口**：`POST /app-api/marketing/course/study-progress`

**请求体**：
```json
{
  "courseId": 1,
  "chapterId": 2,
  "position": 450,
  "totalDuration": 900
}
```

**后端逻辑（进度上报）**：
1. 查询`marketing_user_study_record`，WHERE `user_id=当前用户 AND course_id=请求courseId`
   - 不存在则创建（insert，`study_progress=0, study_duration=0`）
2. 更新`chapter_id`、`last_position`（=请求position）、`last_study_time`=当前时间
3. 计算累加学习时长：`本次新增时长 = position - 上次上报的position`（限制：若差值>120秒则按120秒计算，防止切后台暂停仍计时；若差值<0则不累加）
4. `study_duration = study_duration + 本次新增时长`
5. 重新计算学习进度：`study_progress = MIN(study_duration / course.duration * 100, 100)`（取整）
6. 若`study_progress >= 95`且`is_completed = false`：
   - 设置`is_completed = true`，`complete_time = 当前时间`
   - 异步执行：`marketing_course.study_count + 1`
   - 异步执行：检查是否可以颁发证书（若课程无考试，直接生成证书；若有考试，需等考试通过后颁发）
7. UPDATE `marketing_user_study_record`

**防刷机制**：
- 服务端做接口频率限制（同一用户同一课程，5秒内最多1次上报）
- `position`只能向前增长，不接受倒退（若position < last_position则不更新last_position，但允许用户拖拽回看）

---

### 7.4 在线考试

#### 7.4.1 考试入口

**触发**：业务员在课程详情页点击「参加考试」按钮。

**前提条件**（前端+后端均校验）：
- 该课程的学习进度 `study_progress >= 95`（即课程基本学完）
- 该考试`status=1`（启用）
- 重考次数未超限（若`allow_retake=false`且已有记录，禁止进入）

**进入考试前弹窗**：
- 展示考试说明：考试名称、题目数量、总分、及格分、考试时长（分钟）、剩余重考次数
- 按钮：「开始考试」「取消」

**后端接口（开始考试）**：`POST /app-api/marketing/exam/{examId}/start`

**后端校验**：
1. 考试必须存在且`status=1`，否则报错"考试不存在"
2. 查询`marketing_user_exam_record`，WHERE `user_id=当前用户 AND exam_id=考试ID`：
   - 若`allow_retake=false`且已有记录，报错"不允许重考"
   - 若`max_retake_times`有限制且`history.size() >= max_retake_times`，报错"重考次数已达上限"
3. 查询`marketing_exam_question`列表，若为空报错"考试没有题目"
4. 若`random_order=true`，打乱题目顺序（Collections.shuffle）
5. 创建考试记录：向`marketing_user_exam_record`插入：
   - `user_id`、`exam_id`、`start_time=当前时间`、`retake_times=历史考试次数`
6. 返回：`recordId`（本次考试记录ID）、考试基本信息、题目列表（**不返回正确答案`correct_answer`和`analysis`**）

**返回题目格式**：
```json
{
  "recordId": 100,
  "examName": "车险知识考试",
  "duration": 30,
  "totalScore": 100,
  "passScore": 60,
  "deadlineTime": "2025-01-01T10:30:00",
  "questions": [
    {
      "id": 1,
      "questionType": 1,
      "questionContent": "以下哪项不属于交强险保障范围？",
      "options": [
        {"key":"A","value":"死亡伤残赔偿"},
        {"key":"B","value":"医疗费用赔偿"},
        {"key":"C","value":"财产损失赔偿"},
        {"key":"D","value":"精神损失赔偿"}
      ],
      "score": 10
    }
  ]
}
```

> `deadlineTime = start_time + duration（分钟）`，前端据此做倒计时。

---

#### 7.4.2 答题页面

**页面交互**：
- 顶部：考试名称、倒计时（`deadlineTime - 当前时间`，红色显示剩余不足5分钟时）
- 答题区域：当前题目内容 + 选项（单选/多选/判断/填空）
- 底部：题目进度（第X题/共X题）、「上一题」「下一题」按钮
- 题目列表浮层：点击右上角"题目列表"可跳转到指定题目，已答题目显示绿色，未答显示灰色
- 最后一题时底部显示「提交答卷」按钮
- 倒计时归零后自动触发提交

**重要交互细节**：
- 答案实时保存在前端内存（不需要实时上报后端，防止网络问题丢失答案）
- 提交前检查是否有未答题目，若有弹窗提示"您有X道题未作答，确认提交？"

---

#### 7.4.3 提交试卷

**触发**：用户点击「提交答卷」或倒计时归零。

**后端接口**：`POST /app-api/marketing/exam/record/{recordId}/submit`

**请求体**：
```json
{
  "answers": [
    {"questionId": 1, "userAnswer": "D"},
    {"questionId": 2, "userAnswer": "A,C"},
    {"questionId": 3, "userAnswer": "true"}
  ]
}
```

**后端校验**：
1. 查询`marketing_user_exam_record`，校验`record_id`存在且`user_id=当前用户`
2. 若`submit_time`不为NULL，说明已提交，报错"考试已提交"
3. 检查考试是否超时：`当前时间 > start_time + duration(分钟)`，超时则按已作答部分评分（不报错，继续处理）

**后端批改逻辑**：
1. 查询该考试所有题目（`marketing_exam_question.exam_id = exam.id`）
2. 遍历请求中的answers，逐题判断是否正确：
   - 单选题（type=1）：`userAnswer.equalsIgnoreCase(correctAnswer)`
   - 多选题（type=2）：将`userAnswer`和`correctAnswer`都按","拆分，排序后比较是否完全一致
   - 判断题（type=3）：`userAnswer.equalsIgnoreCase(correctAnswer)`（"true"/"false"或"对"/"错"）
   - 填空/简答（type=4,5）：字符串去首尾空格后忽略大小写比较（简单实现，实际可引入人工复核）
3. 累加各题得分，计算`totalScore`
4. 判断是否通过：`totalScore >= exam.pass_score`
5. 计算答题时长：`duration = 当前时间 - record.start_time（秒）`
6. 更新`marketing_user_exam_record`：`submit_time`、`duration`、`score`、`pass_status`（0-未通过 1-通过）、`answers`（保存JSON格式的答题记录）

**通过考试后触发（异步）**：
- 生成证书：调用`CertificateService.generateCertificate(userId, courseId, examId)`
- 发站内消息：「恭喜您通过[考试名称]，证书已发放！」

**返回结果**：
```json
{
  "recordId": 100,
  "score": 70,
  "totalScore": 100,
  "passScore": 60,
  "isPassed": true,
  "duration": 1200,
  "answerResults": [
    {
      "questionId": 1,
      "questionContent": "...",
      "userAnswer": "D",
      "correctAnswer": "D",
      "isCorrect": true,
      "score": 10,
      "analysis": "精神损失赔偿不属于交强险保障范围..."
    }
  ]
}
```

---

#### 7.4.4 考试结果页

**页面交互**：
- 顶部：大图标（通过=绿色勾 / 未通过=红色X）
- 本次得分、满分、及格线
- 答题耗时
- 通过时：展示「查看证书」按钮
- 未通过时：展示「查看解析」「重新考试」按钮（重新考试受`allow_retake`和`max_retake_times`限制）
- 「查看解析」：展示每道题的用户答案、正确答案和解析

---

### 7.5 学习记录页

**页面说明**：业务员进入「营销工具→培训中心→学习记录」。

**页面交互**：
- Tab：学习中 / 已完成
- 课程卡片展示：
  - 封面图、课程名
  - 学习进度百分比（已完成时显示100%和「已完成」标签）
  - 最后学习时间（`last_study_time`）
  - 「继续学习」/「再次学习」按钮
  - 若已完成且有证书，展示「查看证书」链接
- 按`last_study_time DESC`排序

**后端接口**：`GET /app-api/marketing/course/my-records`

**请求参数**：isCompleted（0-学习中 1-已完成）、pageNo、pageSize

**后端逻辑**：
1. 查询`marketing_user_study_record`，WHERE `user_id=当前用户 AND deleted=0`，按`last_study_time DESC`
2. 如有`isCompleted`筛选，加`is_completed=?`条件
3. 批量查询`marketing_course`获取课程基本信息
4. 批量查询`marketing_user_certificate`获取证书信息（若有）
5. 返回列表

---

### 7.6 证书管理

#### 7.6.1 我的证书列表页

**页面说明**：业务员进入「营销工具→培训中心→证书管理」。

**页面交互**：
- 列表展示所有已获得的证书：
  - 证书名称（通常为"[课程名]结业证书"）
  - 颁发机构名称
  - 颁发日期
  - 证书图片缩略图
  - 「下载证书」「分享证书」按钮
- 按`issue_time DESC`排序

**后端接口**：`GET /app-api/marketing/certificate/my-list`

**后端逻辑**：查询`marketing_user_certificate`，WHERE `user_id=当前用户 AND deleted=0`，按`issue_time DESC`，联查`marketing_course`获取课程名。

---

#### 7.6.2 证书生成逻辑

**触发时机**：
1. 课程无关联考试：课程学习进度 >= 95% 时自动生成
2. 课程有关联考试：考试通过（`pass_status=1`）后自动生成

**证书生成接口**（内部调用，不对外暴露）：`CertificateService.generateCertificate(Long userId, Long courseId)`

**生成步骤**：
1. 校验：该用户该课程的证书是否已存在（`marketing_user_certificate`中`user_id + course_id`唯一），存在则跳过
2. 查询课程信息、用户姓名、当前租户机构名称
3. 生成证书图片：
   - 使用证书模板图（后台配置的证书背景图）
   - Java AWT将用户姓名、课程名、颁发日期、证书编号绘制到模板上
   - 上传OSS，获取URL
4. 生成唯一证书编号：`CERT + yyyyMMdd + 6位序列号`（如`CERT202501010001`）
5. 向`marketing_user_certificate`插入记录：
   - `user_id`
   - `course_id`
   - `exam_id`（若有）
   - `certificate_no`（唯一证书编号）
   - `certificate_url`（OSS图片URL）
   - `issue_org`（颁发机构，取当前租户名称）
   - `issue_time`（当前时间）

**`marketing_user_certificate`（用户证书表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| user_id | BIGINT | 用户ID |
| course_id | BIGINT | 关联课程ID |
| exam_id | BIGINT | 关联考试ID（可空，无考试时为空） |
| certificate_no | VARCHAR(50) | 证书编号，唯一 |
| certificate_url | VARCHAR(500) | 证书图片OSS URL |
| issue_org | VARCHAR(100) | 颁发机构名称 |
| issue_time | DATETIME | 颁发时间 |
| deleted | BIT | 是否删除 |
| 唯一索引 | - | `uk_user_course(user_id, course_id)` |

---

#### 7.6.3 证书下载/分享

**下载**：前端调用系统API将OSS图片保存到本地相册，无需后端接口。

**分享**：前端调用微信分享API，或将证书图片URL传给用户自行分享。分享时展示个人姓名、证书名称。

---

### 7.7 相关数据表汇总

**`marketing_course`（课程表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| course_name | VARCHAR(200) | 课程名称 |
| category_id | BIGINT | 分类ID |
| cover_url | VARCHAR(500) | 封面图 |
| introduction | TEXT | 课程简介 |
| teacher_name | VARCHAR(50) | 讲师姓名 |
| teacher_intro | VARCHAR(500) | 讲师介绍 |
| course_type | TINYINT | 1-视频 2-图文 3-音频 4-直播 |
| difficulty | TINYINT | 1-入门 2-进阶 3-高级 |
| duration | INT | 总时长（秒） |
| chapter_count | INT | 章节数（冗余，更新时同步） |
| study_count | INT | 学习人数（完成课程的人数） |
| is_required | BIT | 是否必修（1=是） |
| pass_score | INT | 关联考试的及格分（冗余字段，方便展示） |
| sort | INT | 排序 |
| status | TINYINT | 0-禁用 1-启用 |
| creator/.../tenant_id | - | 框架标准字段 |

**`marketing_course_chapter`（章节表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| course_id | BIGINT | 关联课程ID |
| chapter_name | VARCHAR(200) | 章节名称 |
| chapter_type | TINYINT | 1-视频 2-图文 3-音频 |
| content_url | VARCHAR(500) | 内容地址（视频/音频URL） |
| content_text | TEXT | 图文内容（Markdown或富文本） |
| duration | INT | 章节时长（秒） |
| sort | INT | 排序 |
| is_free | BIT | 是否免费试看 |

**`marketing_user_study_record`（学习记录表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| user_id | BIGINT | 用户ID |
| course_id | BIGINT | 课程ID |
| chapter_id | BIGINT | 当前学习的章节ID |
| study_duration | INT | 累计学习时长（秒） |
| study_progress | INT | 学习进度（0-100） |
| is_completed | BIT | 是否完成（study_progress>=95时设为true） |
| complete_time | DATETIME | 完成时间 |
| last_study_time | DATETIME | 最后学习时间 |
| last_position | INT | 最后播放位置（秒），用于断点续播 |
| 唯一索引 | - | `uk_user_course(user_id, course_id)` |

**`marketing_exam`（考试表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| exam_name | VARCHAR(200) | 考试名称 |
| course_id | BIGINT | 关联课程ID（可空，独立考试时为空） |
| description | TEXT | 考试说明 |
| duration | INT | 考试时长（分钟） |
| total_score | INT | 总分 |
| pass_score | INT | 及格分 |
| question_count | INT | 题目数量（冗余，与题目表一致） |
| allow_retake | BIT | 是否允许重考（默认true） |
| max_retake_times | INT | 最大重考次数（NULL表示不限） |
| random_order | BIT | 是否随机打乱题目顺序 |
| status | TINYINT | 0-禁用 1-启用 |
| creator/.../tenant_id | - | 框架标准字段 |

**`marketing_exam_question`（考试题目表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| exam_id | BIGINT | 关联考试ID |
| question_type | TINYINT | 1-单选 2-多选 3-判断 4-填空 5-简答 |
| question_content | TEXT | 题目内容 |
| options | JSON | 选项列表（数组，含key和value），判断题和填空题为空 |
| correct_answer | VARCHAR(500) | 正确答案（单选/判断存A/B/C/D/true/false，多选存"A,C"，填空存参考答案） |
| score | INT | 该题分值 |
| analysis | TEXT | 解析说明（提交后展示，答题中不返回） |
| difficulty | TINYINT | 1-简单 2-中等 3-困难 |
| sort | INT | 排序 |

**`marketing_user_exam_record`（考试记录表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| user_id | BIGINT | 用户ID |
| exam_id | BIGINT | 考试ID |
| start_time | DATETIME | 开始考试时间 |
| submit_time | DATETIME | 提交时间（NULL表示未提交） |
| duration | INT | 答题时长（秒） |
| score | INT | 最终得分 |
| pass_status | TINYINT | 0-未通过 1-通过（NULL=未提交） |
| answers | JSON | 用户答题记录（提交后保存） |
| retake_times | INT | 当前为第几次考试（从0开始） |

---

## 八、错误码定义（下篇相关）

| 错误码 | 说明 |
|---|---|
| 1_008_006_000 | 课程不存在 |
| 1_008_006_001 | 章节不存在 |
| 1_008_006_002 | 课程已禁用 |
| 1_008_006_003 | 课程未完成，不能参加考试（study_progress < 95） |
| 1_008_007_000 | 考试不存在 |
| 1_008_007_001 | 考试已禁用 |
| 1_008_007_002 | 不允许重考 |
| 1_008_007_003 | 重考次数已达上限 |
| 1_008_007_004 | 考试没有题目 |
| 1_008_007_005 | 考试记录不存在 |
| 1_008_007_006 | 考试已提交 |
| 1_008_008_000 | 证书不存在 |

---

## 九、接口权限说明

所有App端接口需在Header中携带登录Token（`Authorization: Bearer {token}`），后端从Token中解析`userId`，接口内部不接受传入`userId`参数。

接口路径规范：
- App端（业务员）：`/app-api/marketing/...`
- 管理端（PC后台）：`/admin-api/marketing/...`

---

*上篇内容：营销素材 + 客户邀请 → 见《阶段3-B端营销工具业务逻辑设计文档-上篇》*
*中篇内容：活动推广 + 团队管理 → 见《阶段3-B端营销工具业务逻辑设计文档-中篇》*

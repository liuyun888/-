# 阶段5-合规双录详细需求设计文档【中篇：AI质检 + 合规管理】

> 版本：V2.0 | 日期：2026-02-19 | 配置：1前端 + 1后端

---

## 一、数据库设计

### 1.1 双录质检记录表 `ins_double_record_check`

```sql
CREATE TABLE `ins_double_record_check` (
  `id`                        BIGINT       NOT NULL AUTO_INCREMENT COMMENT '质检记录ID',
  `record_id`                 BIGINT       NOT NULL COMMENT '双录记录ID，关联ins_double_record.id',
  `record_code`               VARCHAR(50)  NOT NULL COMMENT '双录编号',
  `check_type`                TINYINT      NOT NULL COMMENT '质检类型：1-AI自动质检 2-人工抽检',
  `check_status`              TINYINT      NOT NULL DEFAULT 0 COMMENT '状态：0-待检测 1-检测中 2-已完成',
  `check_result`              TINYINT      DEFAULT NULL COMMENT '质检结论：1-通过 2-不通过',
  `asr_text`                  MEDIUMTEXT   DEFAULT NULL COMMENT 'ASR全文转写结果',
  `asr_confidence`            DECIMAL(5,2) DEFAULT NULL COMMENT 'ASR平均置信度（0-100）',
  `asr_task_id`               VARCHAR(100) DEFAULT NULL COMMENT '第三方ASR任务ID，用于轮询结果',
  `violation_items`           JSON         DEFAULT NULL COMMENT '违规项明细，见下方结构说明',
  `violation_score`           INT          DEFAULT 0 COMMENT '违规扣分总分',
  `final_score`               INT          DEFAULT 100 COMMENT '最终得分（100 - violation_score）',
  `face_check_result`         TINYINT      DEFAULT NULL COMMENT '人脸识别结果：1-通过 2-不通过',
  `face_similarity_score`     DECIMAL(5,2) DEFAULT NULL COMMENT '人脸与身份证相似度（0-100）',
  `id_card_check_result`      TINYINT      DEFAULT NULL COMMENT '证件识别结果：1-通过 2-不通过',
  `id_card_is_original`       BIT(1)       DEFAULT NULL COMMENT '证件是否原件（翻拍检测）',
  `keyword_hit_count`         INT          DEFAULT 0 COMMENT '关键词命中数量',
  `keyword_total_count`       INT          DEFAULT 0 COMMENT '关键词总数量',
  `forbidden_word_hit_count`  INT          DEFAULT 0 COMMENT '禁用词命中次数',
  `check_user_id`             BIGINT       DEFAULT NULL COMMENT '人工质检员ID',
  `check_time`                DATETIME     DEFAULT NULL COMMENT '质检完成时间',
  `check_remark`              VARCHAR(500) DEFAULT NULL COMMENT '质检备注',
  `creator`                   VARCHAR(64)  DEFAULT '',
  `create_time`               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`                   VARCHAR(64)  DEFAULT '',
  `update_time`               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`                   BIT(1)       NOT NULL DEFAULT b'0',
  `tenant_id`                 BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_record_id` (`record_id`),
  KEY `idx_check_type_status` (`check_type`, `check_status`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='双录质检记录表';
```

**`violation_items` JSON 字段结构**：
```json
[
  {
    "violationType": "FORBIDDEN_WORD",
    "nodeIndex": 2,
    "hitWord": "保本",
    "timeOffset": "00:02:30",
    "context": "这款产品是保本的，您放心购买",
    "deductScore": 20
  },
  {
    "violationType": "MISSING_KEYWORD",
    "nodeIndex": 3,
    "hitWord": "犹豫期",
    "timeOffset": null,
    "context": "该节点未提及关键词【犹豫期】",
    "deductScore": 10
  }
]
```

violationType 枚举：`FORBIDDEN_WORD`=禁用词 / `MISSING_KEYWORD`=关键词遗漏 / `SKIP_NODE`=跳过必读节点 / `FACE_FAIL`=人脸识别失败 / `ID_CARD_FAKE`=证件翻拍

### 1.2 行为轨迹存证表 `ins_behavior_trace`

```sql
CREATE TABLE `ins_behavior_trace` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT,
  `trace_batch_id` VARCHAR(50)  NOT NULL COMMENT '批次ID，同一次上报用相同ID',
  `order_id`       BIGINT       DEFAULT NULL COMMENT '关联订单ID',
  `customer_id`    BIGINT       NOT NULL COMMENT '客户ID',
  `product_id`     BIGINT       NOT NULL COMMENT '产品ID',
  `event_type`     VARCHAR(50)  NOT NULL COMMENT '事件类型：PAGE_VIEW/PAGE_SCROLL/ELEMENT_CLICK/FORM_INPUT/BUTTON_SUBMIT',
  `page_url`       VARCHAR(500) NOT NULL COMMENT '页面URL',
  `page_title`     VARCHAR(200) NOT NULL COMMENT '页面标题',
  `page_type`      TINYINT      DEFAULT NULL COMMENT '页面类型：1-产品详情 2-健康告知 3-投保须知 4-条款展示 5-支付确认',
  `enter_time`     DATETIME     DEFAULT NULL COMMENT '进入时间',
  `leave_time`     DATETIME     DEFAULT NULL COMMENT '离开时间',
  `stay_duration`  INT          DEFAULT NULL COMMENT '停留时长（秒）',
  `scroll_depth`   INT          DEFAULT NULL COMMENT '最大滚动深度（0-100，百分比）',
  `element_id`     VARCHAR(200) DEFAULT NULL COMMENT '点击元素ID',
  `element_text`   VARCHAR(200) DEFAULT NULL COMMENT '点击元素文本',
  `click_x`        INT          DEFAULT NULL COMMENT '点击X坐标',
  `click_y`        INT          DEFAULT NULL COMMENT '点击Y坐标',
  `event_time`     DATETIME     NOT NULL COMMENT '事件发生时间',
  `device_info`    VARCHAR(500) DEFAULT NULL COMMENT '设备信息（JSON）',
  `ip_address`     VARCHAR(50)  DEFAULT NULL COMMENT '客户端IP',
  `screenshot_url` VARCHAR(500) DEFAULT NULL COMMENT '页面截图OSS路径（关键页面）',
  `creator`        VARCHAR(64)  DEFAULT '',
  `create_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted`        BIT(1)       NOT NULL DEFAULT b'0',
  `tenant_id`      BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_page_type` (`page_type`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='C端投保行为轨迹存证表';
```

### 1.3 存证区块链记录表 `ins_blockchain_evidence`

```sql
CREATE TABLE `ins_blockchain_evidence` (
  `id`                    BIGINT       NOT NULL AUTO_INCREMENT,
  `evidence_code`         VARCHAR(50)  NOT NULL COMMENT '存证编号，EV+yyyyMMdd+6位序号',
  `evidence_type`         TINYINT      NOT NULL COMMENT '存证类型：1-双录视频 2-行为轨迹 3-质检报告',
  `related_id`            BIGINT       NOT NULL COMMENT '关联业务ID（double_record.id 或 order_id）',
  `related_code`          VARCHAR(50)  NOT NULL COMMENT '关联业务编号',
  `file_hash`             VARCHAR(256) NOT NULL COMMENT '文件SHA256哈希值',
  `file_url`              VARCHAR(500) NOT NULL COMMENT '文件OSS存储路径',
  `file_size`             BIGINT       NOT NULL COMMENT '文件大小（字节）',
  `blockchain_type`       TINYINT      NOT NULL COMMENT '区块链平台：1-蚂蚁链 2-腾讯至信链',
  `blockchain_tx_id`      VARCHAR(256) NOT NULL COMMENT '区块链交易ID',
  `blockchain_block_height` BIGINT     DEFAULT NULL COMMENT '区块高度',
  `blockchain_timestamp`  BIGINT       NOT NULL COMMENT '区块链时间戳（毫秒）',
  `verify_url`            VARCHAR(500) DEFAULT NULL COMMENT '在线验证链接',
  `is_verified`           BIT(1)       DEFAULT b'0' COMMENT '是否已完成验证校验',
  `verify_time`           DATETIME     DEFAULT NULL COMMENT '最后验证时间',
  `remark`                VARCHAR(500) DEFAULT NULL,
  `creator`               VARCHAR(64)  DEFAULT '',
  `create_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`               VARCHAR(64)  DEFAULT '',
  `update_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`               BIT(1)       NOT NULL DEFAULT b'0',
  `tenant_id`             BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_evidence_code` (`evidence_code`),
  UNIQUE KEY `uk_blockchain_tx_id` (`blockchain_tx_id`),
  KEY `idx_related_id` (`related_id`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='区块链存证记录表';
```

---

## 二、功能模块：AI 质检（异步）

### 2.1 整体流程

双录完成 → MQ消息触发 → 后端消费者启动AI质检任务 → 调用各AI服务 → 汇总结果写库 → 更新双录主记录状态

```
MQ Topic: double_record_ai_check
消费者类: DoubleRecordAiCheckConsumer
处理逻辑:
1. 查询 ins_double_record，验证 status=2（已完成）
2. 创建 ins_double_record_check 记录，check_type=1，check_status=1（检测中）
3. 并发调用以下子任务（可用 CompletableFuture 并行执行）：
   - ASR语音转文字
   - 关键词/禁用词检测（依赖ASR结果，需串行）
   - 人脸识别检测
   - 证件识别检测
4. 汇总所有违规项，计算扣分
5. 更新 ins_double_record_check，check_status=2，写入所有结果
6. 更新 ins_double_record：ai_check_status=2，violation_count=N
7. 若 final_score >= 60：ins_double_record.record_status=4（质检通过）
   若 final_score < 60：ins_double_record.record_status=5（质检不通过）
8. 发送消息通知业务员（站内信+Push）
```

### 2.2 ASR 语音转文字

**服务商**：阿里云智能语音（推荐，中文识别准确率高）

**调用方式**：
1. 将 `audio_url` 传给阿里云 ASR 录音文件识别接口（异步任务）
2. 轮询或等待回调获取识别结果（通常 1-3 分钟内返回）
3. 将 `asr_text` 和 `asr_confidence` 写入 `ins_double_record_check`

**后端实现要点**：
- 使用阿里云 SDK：`com.aliyun.oss`，接口：`POST https://filetrans.cn-shanghai.aliyuncs.com`
- `asr_task_id` 暂存后，通过定时任务（每30秒扫一次）轮询结果
- 识别完成后触发关键词检测

**接口**（外部调用内部触发，无需前端直接调用）：
```
后端内部方法：AsrService.submitAsrTask(recordId, audioUrl) → 返回 taskId
后端内部方法：AsrService.pollAsrResult(taskId) → 返回 AsrResultVO { text, confidence }
```

### 2.3 关键词 & 禁用词检测

**检测逻辑**（在 ASR 结果返回后触发）：

```
输入：asrText（全文），template的keyWords数组，forbiddenWords数组

关键词检测：
1. 遍历 template.key_words 数组，逐个在 asrText 中用正则全文匹配（忽略大小写）
2. 未命中的关键词 → 生成 violation_item（MISSING_KEYWORD）
3. keyword_hit_count = 命中数；keyword_total_count = 总数
4. 同时检测各节点的 keyWords（需要按节点分段ASR文本，按时间戳切分）

禁用词检测：
1. 遍历 template.forbidden_words 数组，逐个在 asrText 中全文匹配
2. 命中的禁用词 → 生成 violation_item（FORBIDDEN_WORD），记录时间偏移 timeOffset
3. forbidden_word_hit_count = 命中次数
4. 每命中一个禁用词扣 20 分（violation_score += 20）
5. 每遗漏一个关键词扣 5 分（violation_score += 5）
```

**禁用词列表（系统内置，可在模板中覆盖）**：
保本、无风险、固定收益、保证赚钱、稳赚不赔、银行存款、储蓄险、高回报、零风险

### 2.4 人脸识别检测

**目的**：验证双录视频中的客户人脸与身份证照片一致，且为活体（防照片/视频攻击）

**调用时机**：双录视频上传后，从视频中截取人脸帧（调用阿里云人脸识别或腾讯云 FaceID）

**后端处理逻辑**：
1. 从 `video_url` 中抽取关键帧（调用 FFmpeg 或云服务提取帧图片）
2. 将帧图片和身份证图片（`customer_id_card_image_url`）发送给人脸识别 SDK
3. 获取比对相似度 `face_similarity_score`
4. 阈值判断：`face_similarity_score >= 80` → 通过；否则 → 不通过（FACE_FAIL，扣30分）
5. 更新 `ins_double_record_check.face_check_result` 和 `face_similarity_score`

**接口**（内部调用）：
```
FaceCheckService.checkFace(recordId, videoUrl, idCardImageUrl)
  → FaceCheckResult { passed: boolean, similarityScore: decimal }
```

### 2.5 证件识别（OCR + 翻拍检测）

**目的**：检测双录中展示的身份证是否为原件（非翻拍），并 OCR 识别信息与投保人信息比对

**处理逻辑**：
1. 业务员双录时需拍摄/展示身份证（前端在指定节点引导业务员上传证件照片）
2. 调用 OCR 服务（阿里云 OCR 或百度智能云）识别身份证
3. 将识别结果与 `ins_double_record.customer_id_card`（解密后）比对：姓名+身份证号
4. 翻拍检测：OCR 服务返回 `isOriginal` 字段（通过摩尔纹/屏幕边缘检测）
5. 若 `isOriginal=false` → 证件翻拍（ID_CARD_FAKE，扣30分）
6. 若姓名/证件号比对不一致 → 严重违规（额外扣50分）

**接口**（内部调用）：
```
IdCardCheckService.checkIdCard(recordId, idCardImageUrl)
  → IdCardCheckResult { isOriginal: boolean, ocrName, ocrIdCard, matchResult: boolean }
```

### 2.6 质检评分规则

| 违规类型 | 扣分 | 备注 |
|----------|------|------|
| 使用禁用词（每次） | -20分 | 如"保本"、"无风险" |
| 遗漏必读关键词（每个） | -5分 | 如未提及"犹豫期" |
| 跳过必读节点（每个） | -15分 | node_completed未包含must节点 |
| 人脸识别不通过 | -30分 | 相似度<80 |
| 证件翻拍 | -30分 | 非原件身份证 |
| 证件信息不符 | -50分 | OCR结果与投保人不一致 |

**评分等级**：

| 分数段 | 等级 | 处理 |
|--------|------|------|
| 90-100 | 优秀 | 自动通过 |
| 80-89 | 良好 | 自动通过 |
| 60-79 | 合格 | 通过，触发人工抽检（按配置比例） |
| <60 | 不合格 | 不通过，要求重录 |

---

## 三、功能模块：可回溯行为轨迹（C端埋点）

### 3.1 埋点采集（前端 SDK）

在 C 端商城投保流程的以下关键页面中集成行为轨迹上报：

**关键页面及最低停留时长**：

| 页面类型 | page_type | 最低停留时长 | 是否截图 |
|----------|-----------|-------------|---------|
| 产品详情页 | 1 | 30秒 | 否 |
| 健康告知页 | 2 | 60秒 | 是（每题点击时） |
| 投保须知页 | 3 | 45秒 | 否 |
| 条款展示页 | 4 | 90秒 | 是（翻页时） |
| 支付确认页 | 5 | 10秒 | 是（点击支付时） |

**前端采集逻辑（Vue3 composable）**：

1. 进入关键页面时，记录 `enterTime`，启动计时器
2. 每秒 `stayDuration++`，未达最低停留时长时「下一步」按钮 `disabled`
3. 达到最低停留时长时，按钮变为可用；同时记录一条 `PAGE_VIEW` 事件
4. 滚动时记录当前最大滚动深度（每隔3秒更新一次）
5. 点击元素时记录 `ELEMENT_CLICK` 事件（含坐标）
6. 离开页面时（beforeUnmount）记录 `leaveTime`，计算 `stayDuration`，批量上报

**批量上报接口**（C端调用）：
```
POST /api/insurance/behavior/track

Request:
{
  "orderId": 123456,
  "customerId": 789,
  "productId": 100,
  "events": [
    {
      "eventType": "PAGE_VIEW",
      "pageUrl": "/product/detail/100",
      "pageTitle": "XX重疾险",
      "pageType": 1,
      "enterTime": "2026-02-19 10:00:00",
      "leaveTime": "2026-02-19 10:01:30",
      "stayDuration": 90,
      "scrollDepth": 85
    },
    {
      "eventType": "ELEMENT_CLICK",
      "pageUrl": "/order/health-notify",
      "pageType": 2,
      "elementId": "health_q_1",
      "elementText": "是否患有高血压？→ 否",
      "clickX": 320,
      "clickY": 450,
      "eventTime": "2026-02-19 10:02:10"
    }
  ]
}

后端处理：
1. 验证 orderId 与当前登录用户关联
2. 批量插入 ins_behavior_trace（每条事件插一行）
3. 检查关键页面是否满足最低停留时长要求：
   - PAGE_VIEW 事件中 stayDuration < minDuration → 在 ins_behavior_trace 中标记异常（extra字段写入 abnormal=true）
   - 该异常情况后续在AI质检时会作为风险点提示质检员
4. 返回成功

Response: { "code": 0 }
```

### 3.2 页面截图存证

关键操作（健康告知每题点击、条款翻页、点击支付）时，前端调用 `html2canvas` 截图后上传：

```
POST /api/insurance/behavior/screenshot

Request (multipart/form-data 或 JSON with base64):
{
  "orderId": 123456,
  "pageType": 2,
  "eventType": "ELEMENT_CLICK",
  "screenshotBase64": "data:image/png;base64,iVBORw0KG..."
}

后端处理：
1. 将 base64 解码为图片文件
2. 在图片上添加水印（时间戳 + 客户ID + 订单号），使用 Graphics2D 或 ImageIO
3. 上传至 OSS：路径格式 {tenant_id}/screenshot/{orderId}/{yyyyMMddHHmmss}.png
4. 更新对应的 ins_behavior_trace 记录的 screenshot_url

Response: { "code": 0, "data": { "screenshotUrl": "oss://..." } }
```

### 3.3 审计查看行为轨迹（PC 管理后台）

**入口**：质检审核详情页 → 行为轨迹标签页

**页面展示**：
- 时间轴形式展示客户在各页面的操作轨迹
- 展示每个关键页面的停留时长，不达标的用红色标注
- 展示健康告知的点击情况（每题是否点击了是/否）
- 展示截图预览（缩略图，点击可查看大图）

**接口**：
```
GET /admin-api/insurance/behavior/trace/{orderId}

Response:
{
  "code": 0,
  "data": {
    "orderId": 123456,
    "totalPages": 5,
    "traces": [
      {
        "pageType": 1,
        "pageTitle": "XX重疾险",
        "stayDuration": 90,
        "minRequired": 30,
        "qualified": true,
        "scrollDepth": 85,
        "events": [...]
      }
    ]
  }
}
```

---

## 四、功能模块：质检审核（PC 管理后台）

### 4.1 质检任务列表

**页面路径**：合规管理 → 质检审核管理

**列表筛选条件**：
- 双录编号（精确）
- 业务员姓名（模糊）
- 客户姓名（模糊）
- 双录状态（下拉：质检通过/质检不通过/质检中/已完成待质检）
- AI质检结果（下拉：通过/不通过）
- 是否已人工质检（下拉）
- 创建时间范围

**列表展示字段**（PC 表格）：

| 字段 | 说明 |
|------|------|
| 双录编号 | record_code |
| 业务员 | agent_name |
| 客户姓名 | customer_name（脱敏：李*） |
| 产品名称 | product_name |
| 保费金额 | premium（万元） |
| 双录类型 | 现场/远程 |
| 双录时长 | duration（分:秒格式） |
| AI质检 | 通过/不通过/检测中（带颜色标签） |
| 违规次数 | violation_count |
| AI得分 | final_score（带颜色：≥80绿/60-79黄/<60红） |
| 人工质检 | 待质检/已通过/已不通过 |
| 创建时间 | create_time |
| 操作 | 查看详情、人工质检（状态为质检通过且抽检队列中显示） |

**接口**：
```
GET /admin-api/insurance/double-record/check/page
Query: pageNo&pageSize&recordCode&agentName&customerName&recordStatus&aiCheckResult&beginTime&endTime
```

### 4.2 人工质检操作

**入口**：点击列表的「人工质检」按钮 → 打开全屏质检页面

**质检页面布局（左右分栏）**：

**左侧**：视频播放器区域
- 嵌入视频播放器（Aliplayer，使用从 `/video-url/{recordId}` 获取的临时 URL）
- 支持倍速：0.5x / 1x / 1.5x / 2x
- 支持字幕显示（ASR 转写文本同步字幕）
- 进度条上用**红色圆点**标记违规时间点，鼠标 hover 显示违规内容，点击跳转
- 视频下方显示 ASR 转写全文，关键词高亮绿色、禁用词高亮红色

**右侧**：质检信息区域
- 上部：双录基本信息（编号/业务员/客户/产品/时长）
- 中部：话术节点完成情况（打勾/打叉列表）
- 中部：AI 质检汇总（得分、违规项列表，含时间点和扣分）
- 中部：人脸/证件识别结果
- 下部：质检结论填写区（必填）：
  - 质检结论：单选「通过」/「不通过」（**必选**）
  - 质检意见：文本域（不通过时**必填**，最少20字）
  - 「提交质检结果」按钮（蓝色主按钮）

**提交质检结果接口**：
```
POST /admin-api/insurance/double-record/manual-check

Request:
{
  "recordId": 789,
  "checkResult": 2,         // 1-通过 2-不通过（必填）
  "checkRemark": "00:02:30处业务员使用禁用词'保本'，且犹豫期条款未明确告知，质检不通过"
}

后端校验：
1. recordId 有效，check_type 为人工
2. checkResult 必填，值只能为 1 或 2
3. checkResult=2 时 checkRemark 不能为空且长度≥20
4. 当前用户有质检员角色
5. 该记录未被其他人质检中（并发锁：用 Redis SET NX，key=double_check_{recordId}，30分钟超时）

后端处理：
1. 更新 ins_double_record_check：check_result, check_user_id, check_time, check_remark, check_status=2
2. 更新 ins_double_record：
   - 若 checkResult=1：record_status=4（质检通过）
   - 若 checkResult=2：record_status=5（质检不通过）
   - manual_check_user_id, manual_check_time, manual_check_result, manual_check_remark
3. 若不通过：发送站内信给业务员，告知需重录，附上质检意见

Response: { "code": 0, "msg": "质检结果已提交" }
```

### 4.3 质检报告生成与导出

**触发方式**：人工质检完成后自动生成；也可在质检详情页手动点击「导出质检报告」

**报告内容**（PDF 格式）：

1. **封面**：双录编号、产品名称、业务员信息、报告生成时间
2. **基本信息**：双录时间、时长、类型、触发场景
3. **话术完成情况**：各节点完成状态表格，打勾/打叉，实际时长 vs 要求时长
4. **AI质检结果**：得分（大字居中）、违规项明细表格（时间点/类型/扣分）
5. **人脸/证件检测**：检测结果图片（缩略图）+ 判定结论
6. **人工质检意见**：质检员姓名、时间、结论、意见
7. **结论**：通过/不通过（大字红绿标注）

**技术方案**：使用 `iText 7` 或 `Flying Saucer (XHTML to PDF)` 生成 PDF

**接口**：
```
GET /admin-api/insurance/double-record/check/report/{recordId}

后端处理：
1. 校验 recordId 存在且质检已完成
2. 拼装报告数据VO
3. 渲染 HTML 模板（Thymeleaf）→ 转换为 PDF
4. 上传 PDF 到 OSS 并缓存（同一 recordId 已生成的直接返回 URL）
5. 返回 PDF 下载链接

Response: { "code": 0, "data": { "reportUrl": "临时签名URL，2小时有效" } }
```

### 4.4 合规报表

**页面路径**：合规管理 → 合规数据报表

**报表内容**（卡片 + 图表）：

- **汇总卡片**：本月双录总数、通过数、通过率、平均得分
- **趋势折线图**：近30天每日质检通过率
- **违规分布饼图**：各违规类型占比（禁用词/关键词遗漏/节点跳过等）
- **业务员排行**：按质检通过率排序（前10/后10）
- **产品风险分布**：不同产品平均得分对比柱状图

**筛选条件**：时间范围（默认近30天）、业务员（可选）、产品类型（可选）

**接口**：
```
GET /admin-api/insurance/double-record/statistics/overview
Query: beginTime&endTime&agentId&productType

Response:
{
  "totalCount": 500,
  "passCount": 420,
  "passRate": 84.0,
  "avgScore": 82.5,
  "dailyTrend": [{ "date": "2026-02-01", "passRate": 85.2 }, ...],
  "violationDistribution": [{ "type": "FORBIDDEN_WORD", "count": 45, "ratio": 0.35 }, ...],
  "agentRanking": [{ "agentName": "张三", "passRate": 95.0, "count": 20 }, ...]
}
```

---

## 五、功能模块：审计日志

### 5.1 AOP 自动记录

基于 yudao-cloud 框架的 `@OperateLog` 注解，在以下接口自动记录操作日志：

- 双录记录查询（含查询条件、结果条数）
- 视频 URL 生成（记录谁在何时获取了哪条双录的视频链接）
- 人工质检提交（记录质检员、质检结论）
- 质检报告导出
- 话术模板增删改
- 区块链存证创建

**敏感操作额外记录**（写入 `sys_operate_log`）：
```
requestUrl、requestMethod、operateUserId、operateName、operateTime、
resultCode、diffContent（修改前后对比）、userIp
```

### 5.2 可回溯记录（C端行为全程埋点）

除 `ins_behavior_trace` 外，投保全流程需满足以下可回溯要求：

| 环节 | 记录内容 | 存储位置 |
|------|----------|----------|
| 产品详情浏览 | 停留时长、滚动深度 | ins_behavior_trace |
| 健康告知填写 | 每题点击时间、选择值 | ins_behavior_trace |
| 投保须知阅读 | 停留时长、截图 | ins_behavior_trace |
| 条款阅读 | 停留时长、翻页记录、截图 | ins_behavior_trace |
| 确认投保 | 勾选「已阅读并同意」的时间戳、截图 | ins_behavior_trace |
| 支付成功 | 支付时间、截图 | ins_behavior_trace |

---

## 六、接口清单（AI质检 + 合规管理模块）

| 接口路径 | 方法 | 说明 | 调用方 |
|----------|------|------|--------|
| `/api/insurance/behavior/track` | POST | 上报行为轨迹（C端） | C端用户 |
| `/api/insurance/behavior/screenshot` | POST | 上传截图（C端） | C端用户 |
| `/admin-api/insurance/behavior/trace/{orderId}` | GET | 查看行为轨迹 | 质检员 |
| `/admin-api/insurance/double-record/check/page` | GET | 质检任务列表 | 质检员 |
| `/admin-api/insurance/double-record/check/{id}` | GET | 质检详情 | 质检员 |
| `/admin-api/insurance/double-record/manual-check` | POST | 提交人工质检结果 | 质检员 |
| `/admin-api/insurance/double-record/check/report/{recordId}` | GET | 导出质检报告PDF | 质检员/管理员 |
| `/admin-api/insurance/double-record/statistics/overview` | GET | 合规报表汇总 | 管理员 |

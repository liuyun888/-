# 业务员App · 车险报价开发文档（下）
# 功能：报价单生成与分享 & 续保管理

> **框架**：yudao-cloud（微服务版）  
> **模块**：`yudao-module-carins`  
> **文档范围**：报价流程第6步～第8步，以及续保管理全流程

---

## 一、报价单生成（Step 6）

### 1.1 触发生成

**触发时机**：业务员在报价结果页，点击某家保司方案卡片上的「生成报价单」按钮。

**页面跳转**：点击后进入「报价单预览页」，同步触发后端 PDF 生成（异步）。

---

### 1.2 生成 PDF 报价单接口

- **接口**：`POST /app-api/carins/quote/generate-pdf`
- **请求体**：
  ```json
  {
    "quoteResultId": 20001,
    "includeCustomerName": true,
    "templateCode": "STANDARD"
  }
  ```
  - `templateCode`：报价单模板代码，`STANDARD`（正式商务）/ `WARM`（亲和温馨）/ `PROMO`（促销活动），默认 `STANDARD`；
  - `includeCustomerName`：是否在报价单上显示客户姓名（客户隐私保护，业务员选择）。

- **后端处理**：
  1. 校验 `quoteResultId` 属于当前用户，且状态为 `SUCCESS`；
  2. 组装报价单数据（见 1.3）；
  3. **异步**生成 PDF（通过 RocketMQ 发送消息，由 PDF Worker 消费）；
  4. 立即返回 `{ "taskId": "xxx", "status": "GENERATING" }`；
  5. 前端每 2 秒轮询 `GET /app-api/carins/quote/pdf-status?taskId=xxx`；
  6. PDF 生成完成后，上传 OSS（路径：`/{tenantId}/quotes/{quoteNo}.pdf`），更新 `carins_quote_doc.pdf_url`；
  7. 轮询接口返回 `{ "status": "DONE", "pdfUrl": "https://..." }`，前端展示预览和下载按钮。

- **超时处理**：PDF 生成超过 30 秒，标记为失败，前端提示「报价单生成失败，请重试」。

---

### 1.3 PDF 报价单数据组装规则

报价单数据来源于以下表的联合查询：

| 数据项 | 来源 |
|--------|------|
| 公司 Logo、名称、许可证号 | `sys_tenant`（租户配置表）|
| 业务员姓名、工号、手机号 | `system_users`（系统用户表）|
| 业务员二维码 | 由业务员 ID 生成专属二维码（二维码指向业务员名片 H5 页）|
| 报价单编号 | `carins_quote_request.quote_no` |
| 报价日期/有效期 | `carins_quote_result.create_time` + `valid_until` |
| 车辆信息（车牌、VIN、车主等）| `carins_vehicle` |
| 险种方案 + 各险种保费 | `carins_quote_result.rate_details`（JSON 解析）|
| 费率系数（NCD等）| `carins_quote_result` 字段 |
| 增值服务 | `carins_quote_request.value_added`（JSON）|
| 车主证件号 | 读取后**脱敏处理**（身份证：前3位 + *** + 后4位）|

**PDF 内容结构（iText7 渲染顺序）**：

1. **头部**：公司 Logo（左）+ 报价单标题（中）+ 报价单号、日期（右）
2. **业务员区**：姓名、工号、手机、专属二维码（右下角）
3. **车辆信息表格**：车牌、VIN、发动机号、初登日期、车型、使用性质、座位数
4. **车主信息**：姓名（可选）、证件号（脱敏）
5. **险种明细表格**：险种名 | 保险金额 | 保费（元）| 备注
6. **费用合计行**：交强险合计 + 商业险合计 + 车船税 = **总保费**（加粗）
7. **费率系数说明**：NCD 系数 × 自主核保系数 × 自主渠道系数 = 最终折扣
8. **增值服务区**：赠送/可选服务列表（✅ 标注）
9. **底部免责声明**：固定文字（「本报价单仅供参考，最终保费以保险公司出单为准」等）
10. **客户确认区**（可选，空白签名线）

---

### 1.4 生成 H5 分享页

H5 分享页与 PDF 同步生成（无需异步，直接返回 URL）：

- **接口**：`POST /app-api/carins/quote/generate-h5`
- **请求体**：`{ "quoteRequestId": 10001 }`（包含所有保司的报价结果）
- **后端处理**：
  1. 生成唯一 `shareCode`（8位随机字符串，存入 Redis，TTL=7 天）；
  2. H5 URL 格式：`https://h5.xxx.com/quote/share/{shareCode}`；
  3. 生成微信分享专用短链（调用短链服务或微信接口）；
  4. 在 `carins_quote_share` 表记录分享记录；
  5. 返回 `{ "h5Url": "...", "shortUrl": "..." }`。

**H5 页面数据接口**（供 H5 前端调用，无需登录）：
- `GET /open-api/carins/quote/share-data?code={shareCode}`
- 后端从 Redis 读取 `shareCode` 对应的 `quoteRequestId`，再查询数据；
- 若 `shareCode` 不存在（过期），返回 `{ "expired": true }`，H5 展示「报价已失效，请联系业务员」。

**行为埋点数据接收接口**（H5 前端上报）：
- `POST /open-api/carins/quote/track`
- 请求体：`{ "shareCode": "xxx", "event": "VIEW_OPEN", "data": { "duration": 120 } }`
- 事件类型：`VIEW_OPEN`（打开页面）/ `VIEW_CLOSE`（离开）/ `CLICK_INSURER`（点击保司）/ `CLICK_CONTACT`（点击联系业务员）
- 后端入库 `carins_share_track`，同时检查触发通知规则（见 1.5）

---

### 1.5 客户行为实时通知规则

| 触发条件 | 通知业务员内容 | 通知方式 |
|---------|-------------|---------|
| 客户首次打开 H5 链接 | 「{客户名/车牌号} 正在查看您的报价单」 | App 推送 + 站内信 |
| 客户停留时长 > 3 分钟 | 「客户对报价单感兴趣，建议及时跟进」 | App 推送 |
| 客户点击「联系业务员」 | 「客户希望与您联系，请尽快回复」 | App 推送 + 短信 |

通知由 `RenewalMessageConsumer` 消费 MQ 消息发送，MQ 消息在 `track` 接口处理后异步发布。

**防重发规则**：同一 `shareCode` + 同一业务员，`VIEW_OPEN` 事件只触发一次通知（Redis 记录已通知标志位，TTL=24 小时）。

---

### 1.6 报价文档表结构

```sql
CREATE TABLE carins_quote_doc (
  id               BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id        BIGINT       NOT NULL,
  quote_request_id BIGINT       NOT NULL,
  quote_result_id  BIGINT                              COMMENT '关联的具体保司结果（PDF用）',
  doc_type         VARCHAR(10)  NOT NULL               COMMENT 'PDF / H5',
  template_code    VARCHAR(20)                         COMMENT '模板代码',
  pdf_url          VARCHAR(500)                        COMMENT 'OSS PDF URL',
  h5_url           VARCHAR(200)                        COMMENT 'H5 页面 URL',
  share_code       VARCHAR(20)                         COMMENT 'H5 分享码',
  short_url        VARCHAR(200)                        COMMENT '微信短链',
  status           VARCHAR(20)  NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/GENERATING/DONE/FAILED',
  view_count       INT          NOT NULL DEFAULT 0     COMMENT 'H5 查看次数',
  expire_time      DATETIME                            COMMENT 'H5 过期时间',
  create_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_quote_request (quote_request_id)
) COMMENT '报价文档表';

CREATE TABLE carins_share_track (
  id               BIGINT       NOT NULL AUTO_INCREMENT,
  share_code       VARCHAR(20)  NOT NULL,
  event            VARCHAR(30)  NOT NULL               COMMENT '事件类型',
  client_ip        VARCHAR(50),
  user_agent       VARCHAR(500),
  duration_seconds INT                                 COMMENT '停留时长（VIEW_CLOSE时携带）',
  create_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_share_code (share_code, create_time)
) COMMENT '分享行为追踪表';
```

---

## 二、续保管理

### 2.1 续保任务自动生成（定时任务）

**Job 名称**：`RenewalReminderJob`  
**执行时间**：每日凌晨 02:00（Cron：`0 0 2 * * ?`）  
**执行逻辑**：

1. 查询满足以下条件的车辆档案：
   - `carins_vehicle.status = 5`（已投保）
   - 关联保单 `carins_policy.expire_date BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 60 DAY)`
   - 该车辆本次保险周期尚未生成续保任务（`carins_renewal_task` 中无有效记录）
2. 对每辆车生成一条 `carins_renewal_task`：
   - `priority` 自动计算：
     - 到期 ≤ 7 天 → `URGENT`（红色）
     - 到期 8~30 天 → `HIGH`（橙色）
     - 到期 31~60 天 → `NORMAL`（黄色）
   - `agent_id` 分配逻辑：
     - 查 `carins_vehicle.agent_id`（原归属业务员）；
     - 若该业务员状态为离职（`system_users.status = DISABLE`），向上查找其直属上级（`system_dept` 关系表）；
     - 若仍无法分配，`agent_id = NULL`，进入公共续保池；
   - `status = PENDING`；
3. 发送 APP 推送通知给相关业务员（批量，通过 MQ 异步）；
4. Job 执行记录入库 `sys_job_log`，记录生成任务数、失败数。

**负载均衡**：若某业务员当前有效续保任务数 > 50，超出部分（普通优先级）随机分配给同团队其他业务员。

---

### 2.2 续保任务列表页（App）

**接口**：`GET /app-api/carins/renewal/task-list`

**请求参数**：
```
priority = URGENT/HIGH/NORMAL/ALL（筛选优先级）
status = PENDING/FOLLOWING/ALL
page = 1
pageSize = 20
```

**权限控制**：业务员只能看自己的任务；团队长可看团队全部；管理员可看租户全部。

**返回字段（每条任务卡片）**：
- 车牌号、车主名、车型名（`carins_vehicle` 关联）
- 保险到期日（`carins_policy.expire_date`）
- 距到期天数（`expire_date - today()`，前端标红/橙/黄）
- 任务状态 + 最近跟进时间
- 本轮报价记录摘要（如已发起续保报价，展示「已报价：3 家保司，最低 ¥3,500」）

---

### 2.3 续保任务详情页

**接口**：`GET /app-api/carins/renewal/task-detail?taskId=xxx`

页面包含三个区：

**① 车辆与保险信息区**（只读）：
- 车牌、车型、车主
- 上年保单：保司、险种、保额、到期日、上年保费
- 上年出险次数 + 预计 NCD 系数（从 `carins_policy.claim_count` 计算）

**② 跟进记录区**：
- 时间线展示所有历史跟进记录（倒序）
- 每条记录：时间 + 跟进方式（图标）+ 客户态度 + 记录内容

**③ 操作按钮区**：
- [发起续保报价]：跳转到报价流程（车辆信息预填，直接到 Step 3）
- [记录跟进]：弹出跟进记录填写弹窗
- [标记成交/流失]：变更任务状态

---

### 2.4 记录跟进

**弹窗字段**（必填字段标 *）：

| 字段 | 类型 | 必填 | 选项/规则 |
|------|------|------|----------|
| 跟进方式 * | 单选 | 是 | 电话 / 微信 / 面访 / 短信 |
| 客户态度 * | 单选 | 是 | 积极（明确续保）/ 犹豫（待定）/ 拒绝（明确不续）/ 未接通 |
| 跟进备注 * | 文本域 | 是 | 最少 10 字，最多 500 字 |
| 客户关注点 | 多选 | 否 | 价格 / 服务 / 保司品牌 / 理赔速度 |
| 下次跟进时间 | 日期时间 | 条件必填 | 若客户态度=犹豫，必须填写；到期时间自动设为下次提醒时间 |
| 发送报价单 | 开关 | 否 | 开启后可选择要发送的报价单（已生成的）|

**提交接口**：`POST /app-api/carins/renewal/follow-record`

**后端处理**：
1. 校验必填字段；
2. 若 `customer_attitude = REJECT`（拒绝），前端需进一步确认：弹窗「客户已明确拒绝，是否标记为流失？」；
3. INSERT `carins_renewal_follow`；
4. 更新 `carins_renewal_task.last_follow_time` + `status = FOLLOWING`（如之前为 PENDING）；
5. 若 `next_follow_time` 非空，写入提醒定时任务队列（Redis Sorted Set，`score = 时间戳`）；
6. 若 `send_quote = true`，发送报价单短链给客户（调用短信接口）。

---

### 2.5 多渠道续保提醒推送

**推送任务执行**：由 `RenewalSmsJob` 每天 10:00 执行（Cron：`0 0 10 * * ?`）

**推送规则**（避免过度骚扰）：

| 距到期天数 | 推送渠道 | 是否强制 | 备注 |
|-----------|---------|---------|------|
| 60 天 | 短信 + App 推送 | 否（可配置关闭） | 首次提醒 |
| 30 天 | 短信 + App 推送 + 微信服务号 | 否 | 中期提醒 |
| 15 天 | 短信 + App 推送 | 是 | 重要提醒 |
| 7 天 | 短信 + App 推送 + 微信服务号 | 是 | 紧急提醒 |
| 3 天 | 短信 | 是 | 最终提醒 |

**短信模板内容**（需在阿里云短信平台预审批）：
```
【{公司名称}】尊敬的{车主姓名}，您的爱车{车牌号}车险将于{到期日}到期，
请及时续保，点击查看方案：{续保链接}。回复T退订。
```

**频率限制（同一客户手机号）**：
- 同一渠道（短信）：每 7 天最多 2 次；
- 所有渠道合计：每 7 天总共不超过 3 次；
- 查 `carins_renewal_notice_log` 表判断是否满足频率要求，满足才发送。

**免打扰时间**：
- 短信推送：避开 21:00 ~ 次日 08:00（超出时段的任务顺延到次日 10:00）；
- App 推送：无限制（系统通知，用户可自行关闭）。

---

### 2.6 标记成交与流失

#### 标记成交

**接口**：`PUT /app-api/carins/renewal/close-won`

**请求体**：
```json
{
  "taskId": 30001,
  "actualPremium": 3800.00,
  "insurerCode": "PICC",
  "policyNo": "P202602150001",
  "note": "客户选择人保，总保费3800元"
}
```

**后端处理**：
1. 更新 `carins_renewal_task.status = CLOSED_WON`；
2. 若 `policyNo` 非空，在 `carins_policy` 更新/新建保单记录；
3. 更新 `carins_vehicle.status = 5`（已投保），`expire_date = 新保单到期日`；
4. 触发客户满意度问卷推送（通过 MQ 异步，发送短信邀请评分）；
5. 下一年度的续保任务由次年定时任务自动生成（无需手动创建）。

#### 标记流失

**接口**：`PUT /app-api/carins/renewal/close-lost`

**请求体**：
```json
{
  "taskId": 30001,
  "lostReason": "PRICE",
  "note": "客户说价格比直销贵200元，已在直销购买"
}
```

**流失原因枚举（必选）**：
- `PRICE`：价格因素
- `SERVICE`：服务因素
- `BRAND`：保司品牌偏好
- `COMPETITOR`：竞品成交
- `NO_NEED`：不再需要保险（车辆报废/过户）
- `OTHER`：其他

**后端处理**：
1. 更新 `carins_renewal_task.status = CLOSED_LOST`；
2. 若 `lostReason = NO_NEED`，更新 `carins_vehicle.status = 7`（已失效）；
3. 其他流失原因：`carins_vehicle.status` 保持不变（明年仍可重试）；
4. 系统标记：下一年度到期时，仍会生成续保任务（流失客户挽回）。

---

### 2.7 任务状态机

```
PENDING（待处理）
    ↓ 业务员首次记录跟进
FOLLOWING（跟进中）
    ↓                    ↓                  ↓
CLOSED_WON（成交）   CLOSED_LOST（流失）   POSTPONED（延期）
                                              ↓ 到达下次跟进时间
                                          自动恢复 FOLLOWING
```

**状态说明**：

| 状态 | 触发条件 | App 展示 |
|------|---------|---------|
| PENDING | 系统自动生成任务 | 红点提示，「待处理」标签 |
| FOLLOWING | 业务员记录 ≥ 1 次跟进 | 显示最近跟进时间 |
| POSTPONED | 业务员点击「延期」，填写下次跟进时间 | 灰色，显示「下次跟进：{日期}」|
| CLOSED_WON | 业务员标记成交 | 绿色「已成交」，从待办列表移除 |
| CLOSED_LOST | 业务员标记流失 | 灰色「已流失」，从待办列表移除 |

---

### 2.8 续保管理相关表结构

```sql
-- 续保任务表
CREATE TABLE carins_renewal_task (
  id               BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id        BIGINT       NOT NULL,
  agent_id         BIGINT                              COMMENT '负责业务员（NULL=公共池）',
  vehicle_id       BIGINT       NOT NULL,
  policy_id        BIGINT       NOT NULL               COMMENT '关联上一年保单',
  expire_date      DATE         NOT NULL               COMMENT '保险到期日',
  priority         VARCHAR(10)  NOT NULL               COMMENT 'URGENT/HIGH/NORMAL',
  status           VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
  last_follow_time DATETIME                            COMMENT '最近跟进时间',
  follow_count     INT          NOT NULL DEFAULT 0     COMMENT '跟进次数',
  lost_reason      VARCHAR(20)                         COMMENT '流失原因',
  actual_premium   DECIMAL(10,2)                       COMMENT '实际成交保费',
  create_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_agent_priority (agent_id, priority, status),
  INDEX idx_expire_date (expire_date, status),
  INDEX idx_vehicle_id (vehicle_id)
) COMMENT '续保任务表';

-- 跟进记录表
CREATE TABLE carins_renewal_follow (
  id               BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id        BIGINT       NOT NULL,
  task_id          BIGINT       NOT NULL,
  agent_id         BIGINT       NOT NULL,
  follow_type      VARCHAR(20)  NOT NULL               COMMENT 'PHONE/WECHAT/VISIT/SMS',
  customer_attitude VARCHAR(20) NOT NULL               COMMENT 'POSITIVE/HESITANT/REJECT/NO_ANSWER',
  content          VARCHAR(500) NOT NULL               COMMENT '跟进内容',
  key_concerns     VARCHAR(200)                        COMMENT '客户关注点（逗号分隔）',
  next_follow_time DATETIME                            COMMENT '下次跟进时间',
  quote_doc_id     BIGINT                              COMMENT '关联发送的报价单ID',
  create_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_task_id (task_id, create_time)
) COMMENT '续保跟进记录表';

-- 续保提醒推送日志表
CREATE TABLE carins_renewal_notice_log (
  id               BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id        BIGINT       NOT NULL,
  task_id          BIGINT       NOT NULL,
  vehicle_id       BIGINT       NOT NULL,
  owner_mobile     VARCHAR(11)  NOT NULL,
  notice_type      VARCHAR(20)  NOT NULL               COMMENT 'SMS/APP/WECHAT',
  notice_time      DATETIME     NOT NULL               COMMENT '发送时间',
  days_before_expire INT        NOT NULL               COMMENT '距到期天数',
  send_status      VARCHAR(10)  NOT NULL               COMMENT 'SUCCESS/FAIL',
  fail_reason      VARCHAR(200),
  PRIMARY KEY (id),
  INDEX idx_mobile_time (owner_mobile, notice_time),
  INDEX idx_task_id (task_id)
) COMMENT '续保提醒发送日志（用于频率控制）';

-- 保单表（投保成功后记录）
CREATE TABLE carins_policy (
  id               BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id        BIGINT       NOT NULL,
  vehicle_id       BIGINT       NOT NULL,
  agent_id         BIGINT       NOT NULL,
  quote_request_id BIGINT                              COMMENT '关联报价请求（平台出单时有值）',
  insurer_code     VARCHAR(20)  NOT NULL,
  policy_no        VARCHAR(50)  NOT NULL               COMMENT '保单号',
  start_date       DATE         NOT NULL               COMMENT '保险起期',
  expire_date      DATE         NOT NULL               COMMENT '保险止期',
  total_premium    DECIMAL(10,2) NOT NULL              COMMENT '实收保费',
  ci_premium       DECIMAL(10,2)                       COMMENT '交强险保费',
  bi_premium       DECIMAL(10,2)                       COMMENT '商业险保费',
  claim_count      TINYINT      NOT NULL DEFAULT 0     COMMENT '本年度出险次数',
  policy_detail    JSON                                COMMENT '险种明细JSON',
  source           VARCHAR(20)  NOT NULL DEFAULT 'MANUAL' COMMENT 'MANUAL（手录）/PLATFORM（平台出单）',
  create_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE INDEX uk_policy_no (insurer_code, policy_no),
  INDEX idx_vehicle_expire (vehicle_id, expire_date),
  INDEX idx_agent_id (agent_id)
) COMMENT '保单表';
```

---

## 三、错误码标准定义（汇总）

| 错误码 | 含义 | 是否可重试 | 前端展示文案 |
|--------|------|-----------|------------|
| E001 | 网络超时 | 是（自动重试1次）| 「网络超时，请稍后重试」 |
| E002 | 接口异常（5xx）| 是（自动重试1次）| 「接口异常，可稍后重试」 |
| E003 | 参数错误 | 否 | 「报价参数有误，请检查车辆信息」 |
| E004 | 车辆拒保 | 否 | 「该保司拒保，点击查看原因」 |
| E005 | 需人工核保 | 等待（异步轮询）| 「需人工审核，预计1个工作日」 |
| E006 | 车型匹配失败 | 是 | 「车型未能匹配，建议手动选择」 |
| E007 | 费率数据缺失 | 否 | 「保司费率数据缺失，无法报价」 |
| E008 | 保司系统维护 | 是 | 「保司系统维护中，请稍后重试」 |
| E009 | 超出承保范围 | 否 | 「该车辆超出承保范围」 |
| E010 | 证件信息异常 | 否 | 「车主证件信息与保司记录不符」 |
| E011 | 认证失败 | 否 | 「保司接口认证失败，请联系管理员」 |

---

## 四、定时任务清单

| Job 名称 | 执行时间（Cron）| 功能 |
|---------|----------------|------|
| `RenewalReminderJob` | `0 0 2 * * ?`（凌晨2点）| 扫描即将到期保单，生成续保任务 |
| `RenewalSmsJob` | `0 0 10 * * ?`（上午10点）| 按规则推送续保提醒短信/App 通知 |
| `QuoteExpireJob` | `0 30 0 * * ?`（凌晨0:30）| 清理过期报价（`valid_until < NOW()`，更新状态）|
| `RenewalFollowReminderJob` | `0 * * * * ?`（每分钟）| 读取 Redis Sorted Set，触发到期的个人跟进提醒 |

---

## 五、API 接口汇总

| 接口 | Method | URL | 说明 |
|------|--------|-----|------|
| 上传图片 | POST | `/app-api/carins/ocr/upload-image` | OCR 图片上传 |
| OCR 识别 | POST | `/app-api/carins/ocr/recognize-driving-license` | 行驶证识别 |
| 车型搜索 | GET | `/app-api/carins/vehicle/model/search` | 品牌/车系/车款联动 |
| VIN 解析 | POST | `/app-api/carins/vehicle/parse-vin` | VIN 码智能解析 |
| 车牌查档案 | GET | `/app-api/carins/vehicle/query-by-plate` | 查历史档案 |
| 保存车辆 | POST | `/app-api/carins/vehicle/save-or-update` | 新建/更新档案 |
| 初始化报价 | POST | `/app-api/carins/quote/init-request` | 保存险种方案 |
| 发起询价 | POST | `/app-api/carins/quote/start` | 触发多保司询价 |
| 查询询价状态 | GET | `/app-api/carins/quote/status` | 轮询报价进度 |
| 单保司重试 | POST | `/app-api/carins/quote/retry-single` | 重试单个保司 |
| 生成 PDF | POST | `/app-api/carins/quote/generate-pdf` | 异步生成 PDF |
| PDF 状态查询 | GET | `/app-api/carins/quote/pdf-status` | 轮询 PDF 生成状态 |
| 生成 H5 分享 | POST | `/app-api/carins/quote/generate-h5` | 生成分享链接 |
| H5 数据接口 | GET | `/open-api/carins/quote/share-data` | H5 页面数据（免登录）|
| H5 行为追踪 | POST | `/open-api/carins/quote/track` | 客户行为埋点 |
| 续保任务列表 | GET | `/app-api/carins/renewal/task-list` | 分页查询续保任务 |
| 续保任务详情 | GET | `/app-api/carins/renewal/task-detail` | 任务详情 |
| 记录跟进 | POST | `/app-api/carins/renewal/follow-record` | 新增跟进记录 |
| 标记成交 | PUT | `/app-api/carins/renewal/close-won` | 标记成交 |
| 标记流失 | PUT | `/app-api/carins/renewal/close-lost` | 标记流失 |

---

*文档版本：V3.0 | 范围：报价流程 Step6-Step8 + 续保管理全流程*

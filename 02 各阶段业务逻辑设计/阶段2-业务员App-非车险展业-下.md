# 阶段2-B端业务员App-非车险展业 详细功能设计文档（下）

> **项目：** 保险中介全域数字化平台  
> **模块：** 业务员App - 非车险展业  
> **技术栈：** yudao-cloud（Spring Cloud Alibaba + Vue3）  
> **文档版本：** v3.0（业务逻辑重写版）  
> **涵盖模块：** M5-订单管理 · M6-业绩统计 · M7-佣金管理

---

## M5 订单管理

### 业务背景

业务员通过本模块跟踪客户下单后的订单全生命周期：从待支付 → 核保中 → 已承保，以及催单、取消等操作。

**说明：** 非车险订单的创建通常由客户在 C 端商城下单（或业务员辅助录单），本模块仅负责订单的**查询和跟进**，不负责创建订单。

---

### M5-F1 订单列表

#### 业务流程

**页面布局：**
- 顶部状态 Tab（横向滑动）：全部 / 待支付 / 核保中 / 已承保 / 已取消
- 搜索框（按订单号/客户姓名）
- 订单卡片列表

**订单卡片展示字段：**
- 产品名称（如"XX重大疾病保险"）
- 被保人姓名
- 保额（如 ￥50万）
- 保费（如 年缴 ￥6,580）
- 订单状态（标签，不同状态不同颜色）
- 下单时间
- 操作按钮（根据状态显示）：待支付→【催单】；核保中→无；已承保→【查看保单】；已取消→无

**状态说明：**
| 状态值 | 状态名 | 颜色 | 说明 |
|---|---|---|---|
| 1 | 待支付 | 橙色 | 客户下单但未完成支付 |
| 2 | 核保中 | 蓝色 | 客户已支付，保险公司核保中 |
| 3 | 已承保 | 绿色 | 核保通过，保单已生效 |
| 4 | 已取消 | 灰色 | 订单已取消（超时或主动取消） |
| 5 | 核保拒绝 | 红色 | 保险公司拒绝承保 |

**数据权限：** 仅展示 `agent_id = 当前登录业务员ID` 的订单。

**后端接口：** `GET /insurance/order/page`

**请求参数：**
```
orderStatus   Integer   订单状态（选填，不传则查全部）
keyword       String    订单号或客户姓名（选填）
startTime     String    开始时间（选填，格式yyyy-MM-dd）
endTime       String    结束时间（选填）
pageNo        Integer
pageSize      Integer   默认20
```

**后端处理逻辑：**
1. 固定条件：`agent_id = 当前用户ID AND deleted = 0`；
2. 按 orderStatus 过滤（不传则不过滤）；
3. keyword 处理：若像订单号（纯数字或以字母开头的编码）则精确匹配 `order_no`，否则模糊匹配关联客户的 `name`（join `ins_customer`）；
4. 按 `create_time` 倒序排列；
5. 返回分页列表。

---

### M5-F2 订单详情

#### 业务流程

点击订单卡片，进入订单详情页。

**页面信息（从上到下）：**

**区域一：状态流转条**
- 以进度条形式展示：下单 → 支付 → 核保 → 承保
- 当前所处状态高亮显示
- 每个节点显示操作时间（从 `ins_order_log` 表读取）

**区域二：订单基本信息**
- 订单号、下单时间、产品名称、保险公司
- 保单号（已承保后显示）、保单生效日期、保单到期日

**区域三：投保信息**
- 投保人姓名、被保人姓名、被保人性别/年龄
- 保额、保费（年缴/月缴）、缴费期限、保障期限

**区域四：佣金信息（仅业务员可见）**
- 预计佣金金额、佣金状态（待结算/已结算）
- 若已结算，显示结算时间和结算金额

**区域五：操作按钮（根据状态）**
- 待支付：【发送催单通知】（发送短信提醒客户支付）/ 【取消订单】
- 已承保：【下载电子保单】（OSS 文件 URL）
- 核保拒绝：【查看拒绝原因】

**后端接口：** `GET /insurance/order/detail/{id}`

**后端处理逻辑：**
1. 校验订单 ID 存在且 `agent_id = 当前用户`；
2. 查询 `ins_order` 基础信息；
3. 查询 `ins_order_log` 获取状态流转历史；
4. 查询 `ins_commission` 获取佣金信息；
5. 返回聚合数据。

---

### M5-F3 订单搜索

#### 业务流程

- 订单列表顶部搜索框，输入内容后防抖500ms触发搜索；
- 支持精确搜索：输入完整订单号（如 `ORD202502180001`）→ 精确匹配；
- 支持模糊搜索：输入客户姓名关键词 → 模糊匹配。

---

### M5-F4 订单催单

#### 业务流程

在订单列表或详情页，对**状态为"待支付"**的订单点击【催单】按钮。

**操作流程：**
1. 点击【催单】按钮，弹出 Dialog 确认："是否发送催款提醒给客户 {姓名}？"；
2. 点击确认，调用后端接口；
3. 后端向客户手机号发送短信（通过短信网关）：
   "您有一笔待支付订单，产品：{产品名}，保费：{金额}元，请尽快完成支付，如有疑问请联系您的顾问{业务员姓名}。"；
4. 同时记录本次催单操作（`ins_order_log` 表插入一条类型为"催单"的记录）；
5. 催单次数限制：同一订单同一天最多催单 2 次，超过则前端按钮置灰并提示"今日已催单 2 次，明日可再次催单"。

**后端接口：** `POST /insurance/order/urge/{id}`

**后端处理逻辑：**
1. 校验订单存在且属于当前业务员；
2. 校验订单状态为 1（待支付），其他状态返回错误"仅待支付订单可催单"；
3. 查询今日已催单次数：`SELECT count FROM ins_order_log WHERE order_id=? AND type=5（催单）AND DATE(create_time)=CURDATE()`；
4. 若 >= 2，返回错误"今日催单次数已达上限"；
5. 查询客户手机号（解密）；
6. 调用短信服务发送模板短信；
7. 插入 `ins_order_log`：type=5（催单），操作人=当前业务员，操作时间=当前时间；
8. 返回成功。

---

### M5-F5 取消订单

#### 业务流程

对**状态为"待支付"**的订单，业务员可发起取消。

**操作流程：**
1. 点击【取消订单】按钮；
2. 弹出 Dialog 确认，并显示输入框"取消原因（选填）"；
3. 点击确认，调用取消接口；
4. 订单状态更新为 4（已取消）；
5. 记录操作日志；
6. 若客户已支付（状态已是 2 核保中），则不允许取消，需要走退保流程（本期不实现）。

**后端接口：** `POST /insurance/order/cancel/{id}`

**请求参数：** `{"cancelReason": "客户临时不想买了"}`

**后端处理逻辑：**
1. 校验订单存在且属于当前业务员；
2. 校验 `order_status = 1`（待支付），其他状态返回"不可取消"；
3. 更新 `ins_order` 的 `order_status = 4`，`cancel_reason = ?`，`cancel_time = 当前时间`；
4. 插入 `ins_order_log`：type=4（取消），取消原因；
5. 若该订单已计算了预计佣金，将对应 `ins_commission` 记录设置为无效（invalid=1）；
6. 返回成功。

---

### ins_order（订单表）

```sql
CREATE TABLE ins_order (
  id              BIGINT NOT NULL AUTO_INCREMENT,
  order_no        VARCHAR(32) NOT NULL COMMENT '订单编号，如ORD202502180001',
  product_id      BIGINT NOT NULL,
  product_name    VARCHAR(100) NOT NULL COMMENT '产品名称（冗余存储）',
  agent_id        BIGINT NOT NULL,
  customer_id     BIGINT NOT NULL,
  applicant_name  VARCHAR(50) NOT NULL COMMENT '投保人姓名',
  insured_name    VARCHAR(50) NOT NULL COMMENT '被保人姓名',
  insured_age     INT,
  insured_gender  TINYINT,
  premium         DECIMAL(15,2) NOT NULL COMMENT '年缴保费',
  amount          DECIMAL(15,2) NOT NULL COMMENT '保额',
  payment_period  VARCHAR(50),
  coverage_period VARCHAR(50),
  policy_no       VARCHAR(50) COMMENT '保单号，核保通过后赋值',
  policy_start_date DATE COMMENT '保单生效日期',
  policy_end_date   DATE COMMENT '保单到期日',
  policy_file_url   VARCHAR(500) COMMENT '电子保单文件URL',
  order_status    TINYINT NOT NULL COMMENT '1-待支付 2-核保中 3-已承保 4-已取消 5-核保拒绝',
  payment_status  TINYINT DEFAULT 0 COMMENT '0-未支付 1-已支付',
  payment_time    DATETIME,
  issue_time      DATETIME COMMENT '承保时间',
  cancel_time     DATETIME,
  cancel_reason   VARCHAR(200),
  reject_reason   VARCHAR(500) COMMENT '核保拒绝原因',
  commission_amount DECIMAL(15,2) COMMENT '预计佣金（承保后计算）',
  commission_status TINYINT DEFAULT 0 COMMENT '0-未结算 1-已结算',
  creator         VARCHAR(64) DEFAULT '',
  create_time     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updater         VARCHAR(64) DEFAULT '',
  update_time     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_order_no (order_no),
  KEY idx_agent_status_time (agent_id, order_status, create_time),
  KEY idx_customer_id (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';

CREATE TABLE ins_order_log (
  id          BIGINT NOT NULL AUTO_INCREMENT,
  order_id    BIGINT NOT NULL,
  type        TINYINT NOT NULL COMMENT '1-创建 2-支付 3-核保通过 4-取消 5-催单 6-核保拒绝',
  remark      VARCHAR(500),
  operator_id BIGINT COMMENT '操作人ID（系统操作时为null）',
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_order_id (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单操作日志';
```

---

## M6 业绩统计

### 业务背景

业务员通过业绩看板了解自己的保费、佣金、订单数据，包括今日/本月/累计维度，以及趋势图、险种分布等可视化展示。

---

### M6-F1 业绩看板

#### 业务流程

**入口：** 底部导航"业绩"Tab，默认进入看板页。

**页面布局（从上到下）：**

**时间维度切换器：** 今日 / 本月 / 今年 / 累计（Tab切换，切换后所有数据刷新）

**核心指标卡片区（2×2宫格）：**
| 指标 | 说明 |
|---|---|
| 保费规模 | 已承保订单的保费合计（元） |
| 佣金收入 | 已结算佣金合计（元） |
| 成交件数 | 已承保订单数量（件） |
| 新增客户 | 新增客户数量（人） |

每个卡片显示：当前值 + 同比变化（如"↑15.3%"，与上一个相同周期对比）

**目标完成进度（本月维度）：**
- 若管理员设置了月度目标（从 `ins_agent_target` 表读取），展示进度条；
- 进度 = 本月已完成 / 目标值 × 100%；
- 超额完成时展示"🎉 已超额完成本月目标"。

**后端接口：** `GET /insurance/performance/dashboard`

**请求参数：** `period=today|month|year|all`

**后端处理逻辑：**
1. 根据 period 计算时间范围（today: 当天0点到23:59；month: 当月1日到今天；year: 当年1月1日到今天；all: 全部）；
2. 查询 `ins_order` 表统计（`agent_id=当前用户 AND order_status=3 AND issue_time 在范围内`）：
   - `SUM(premium)` → 保费规模
   - `COUNT(id)` → 成交件数
3. 查询 `ins_commission` 表统计已结算佣金；
4. 查询 `ins_customer` 统计新增客户数；
5. 计算同比：用相同逻辑查上一周期数据，计算增长率；
6. 查询目标数据（若有）；
7. 组装返回。

---

### M6-F2 业绩明细

#### 业务流程

点击看板中的指标卡片，或Tab切换到"明细"，进入业绩明细列表。

**页面布局：**
- 顶部：时间筛选（年月选择器）+ 险种分类筛选（全部/重疾/医疗/意外/年金）
- 明细列表：每条为一笔订单

**明细列表字段：**
- 产品名称 + 险种标签
- 客户姓名
- 保额（如 50万）
- 保费（如 ￥6,580/年）
- 承保日期
- 预计佣金金额（灰色小字）

**排序：** 默认按承保日期倒序。

**合计行：** 列表底部展示"合计：保费 XXXX 元，佣金 XXXX 元，共 N 件"。

**后端接口：** `GET /insurance/performance/detail`

**请求参数：**
```
year        Integer   年份（必填）
month       Integer   月份（选填，不传则查整年）
categoryId  Long      险种分类ID（选填）
pageNo      Integer
pageSize    Integer
```

---

### M6-F3 业绩趋势图

#### 业务流程

**展示内容：**
- 横轴：日期（当月按天/当年按月）
- 纵轴：保费金额（柱状图） + 佣金金额（折线图，双Y轴）
- 图表上方显示统计范围切换：近7天/近30天/近12月

**交互：** 点击图表上某个数据点，底部显示该时间段的详细数据（件数/保费/佣金）。

**后端接口：** `GET /insurance/performance/trend`

**请求参数：** `dateRange=7d|30d|12m`

**后端处理逻辑：**
1. 7天：按天聚合，`GROUP BY DATE(issue_time)`；
2. 30天：按天聚合；
3. 12月：按月聚合，`GROUP BY DATE_FORMAT(issue_time, '%Y-%m')`；
4. 返回时间序列数组：`[{date, premium, commission, orderCount}]`；
5. 若某天/月无数据，补0值（保证折线图连续）。

---

### M6-F4 险种分布

#### 业务流程

在业绩看板底部展示饼图，显示各险种保费占比。

**展示内容：**
- 饼图：各险种（重疾/医疗/意外/年金/寿险）保费金额占比；
- 图例：险种名称 + 金额 + 占比百分比；
- 时间范围与看板顶部维度切换联动（默认本月）。

**后端接口：** `GET /insurance/performance/category-distribution`

**返回格式：**
```json
[
  {"categoryName": "重疾险", "premium": 120000, "percentage": 45.2},
  {"categoryName": "医疗险", "premium": 80000, "percentage": 30.1}
]
```

---

## M7 佣金管理

### 业务背景

佣金管理让业务员可以清晰看到每笔订单产生的佣金、结算状态，并可发起提现申请。佣金的计算和结算由 PC 端佣金系统负责，本模块仅提供**查看**和**提现申请**功能。

### 佣金状态说明

| 状态值 | 状态名 | 说明 |
|---|---|---|
| 0 | 待结算 | 订单已承保，佣金尚未到账 |
| 1 | 已结算 | 佣金已计算到账，可提现 |
| 2 | 提现中 | 已提交提现申请，处理中 |
| 3 | 已提现 | 佣金已转入银行卡 |
| -1 | 已无效 | 订单取消或退保，佣金作废 |

---

### M7-F1 佣金总览

#### 业务流程

**入口：** 底部导航"佣金"Tab。

**页面布局：**

**顶部汇总卡片（大卡片）：**
- 可提现金额（元，绿色大字体）：状态为"已结算"的佣金合计
- 本月预计佣金：状态为"待结算"的佣金合计（灰色）
- 累计已提现金额
- 操作按钮：【立即提现】（蓝色大按钮）

**状态 Tab：**
- 待结算 / 已结算 / 提现中 / 已提现 / 已无效

**后端接口：** `GET /insurance/commission/overview`

**返回字段：**
```
availableAmount     BigDecimal  可提现金额（已结算合计）
pendingAmount       BigDecimal  待结算金额
withdrawingAmount   BigDecimal  提现中金额
totalWithdrawn      BigDecimal  累计已提现
```

---

### M7-F2 佣金明细

#### 业务流程

**页面布局：**
- 顶部筛选：时间范围（年月选择）+ 状态筛选
- 佣金明细列表（按结算时间倒序）

**明细列表字段：**
- 产品名称
- 客户姓名
- 订单号（可点击跳转订单详情）
- 佣金金额（元）
- 佣金类型（首年/续年）
- 佣金状态（带颜色标签）
- 结算时间（待结算的显示"预计结算：承保后30天"）

**后端接口：** `GET /insurance/commission/page`

**请求参数：**
```
year            Integer   年份（选填）
month           Integer   月份（选填）
status          Integer   佣金状态（选填）
pageNo          Integer
pageSize        Integer
```

---

### M7-F3 佣金提现

#### 业务流程

点击【立即提现】按钮，弹出提现申请弹窗（半屏）。

**提现弹窗字段：**

| 字段 | 必填 | 校验规则 |
|---|---|---|
| 提现金额 | 是 | 数字，最小提现金额 100 元；不得超过可提现余额；最高单次提现 50,000 元（可配置） |
| 收款方式 | 是 | 单选：银行卡 / 支付宝（本期只支持银行卡） |
| 银行名称 | 是 | 下拉选择（列举主流银行：工行/农行/建行/招行等） |
| 银行卡号 | 是 | 16-19位纯数字；Luhn 算法校验；前端展示时脱敏（保留后4位） |
| 开户姓名 | 是 | 2-20字中文，必须与实名认证一致（与 `sys_user.real_name` 对比） |

**提现限制：**
- 同一业务员每月最多提现 5 次；
- 提现后资金 T+2 到账（工作日）；
- 当日已提现金额超过 200,000 元时，自动触发风控审核。

**提交提现后流程（用户视角）：**
1. 点击【确认提现】；
2. 弹出短信验证码确认（向绑定手机号发送6位验证码，有效期5分钟）；
3. 输入验证码后，提现申请提交成功；
4. 页面显示："提现申请已提交，预计 T+2 工作日到账，可在提现记录中查看进度"；
5. 对应佣金记录状态变更为"提现中"；
6. PC 管理后台审核通过后，状态变更为"已提现"。

**后端接口：** `POST /insurance/commission/withdraw`

**请求参数：**
```json
{
  "amount": 5000.00,
  "bankName": "招商银行",
  "bankAccount": "6225880199888888",
  "accountName": "张三",
  "smsCode": "123456"
}
```

**后端处理逻辑：**
1. 校验短信验证码（Redis Key: `sms:withdraw:{userId}`）；
2. 加锁（Redis 分布式锁 Key: `lock:withdraw:{userId}`，超时30秒），防并发重复提现；
3. 查询可提现余额（`SELECT SUM(commission_amount) FROM ins_commission WHERE agent_id=? AND settlement_status=1`），校验余额充足；
4. 校验 `accountName` 与 `sys_user.real_name` 一致；
5. 校验今日提现次数不超过限制；
6. 创建提现记录（`ins_withdrawal`），status=1（审核中）；
7. 将对应佣金记录（金额合计等于提现金额的已结算记录）标记为 status=2（提现中），关联 `withdrawal_id`；
8. 选取佣金记录的策略：按结算时间从早到晚选取（FIFO），累加直到达到提现金额；
9. 解锁，返回成功。

**入库字段（ins_withdrawal）：**
```
id                BIGINT
agent_id          BIGINT
withdrawal_no     VARCHAR(32) 提现编号（WD+年月日+6位序列）
amount            DECIMAL(15,2) 提现金额
bank_name         VARCHAR(50)
bank_account      VARCHAR(300)  银行卡号（AES加密，只存密文）
bank_account_last4 VARCHAR(4)   卡号后4位明文（展示用）
account_name      VARCHAR(50)
status            TINYINT     1-审核中 2-已通过 3-已打款 4-已拒绝
reject_reason     VARCHAR(200) 拒绝原因
payment_voucher   VARCHAR(500) 打款凭证URL（财务上传）
apply_time        DATETIME    申请时间
audit_time        DATETIME    审核时间
payment_time      DATETIME    打款时间
create_time       DATETIME
```

---

### M7-F4 提现记录

#### 业务流程

**页面布局：**
- 提现记录列表（按申请时间倒序）

**列表字段：**
- 提现金额（元）
- 收款银行及卡号（尾号XXXX）
- 申请时间
- 状态（审核中/已通过/已打款/已拒绝）
- 到账时间（已打款时展示）
- 拒绝原因（已拒绝时展示）

**若提现被拒绝：**
- 状态展示"已拒绝"（红色）
- 点击后弹窗显示拒绝原因；
- 对应佣金记录自动恢复为"已结算"状态（status=1），可重新申请提现。

**后端接口：** `GET /insurance/commission/withdrawal/list`

---

## 数据库核心表设计（M5、M6、M7）

### ins_commission（佣金记录表）

```sql
CREATE TABLE ins_commission (
  id                BIGINT NOT NULL AUTO_INCREMENT,
  agent_id          BIGINT NOT NULL,
  order_id          BIGINT NOT NULL COMMENT '关联订单ID',
  order_no          VARCHAR(32) NOT NULL COMMENT '订单号（冗余）',
  product_name      VARCHAR(100) COMMENT '产品名称（冗余）',
  customer_name     VARCHAR(50) COMMENT '客户姓名（冗余）',
  commission_type   TINYINT COMMENT '1-首年佣金(FYC) 2-续年佣金(RYC)',
  commission_year   INT COMMENT '佣金年度（第几年）',
  gross_premium     DECIMAL(15,2) COMMENT '基准保费',
  commission_rate   DECIMAL(6,4)  COMMENT '佣金比例',
  commission_amount DECIMAL(15,2) NOT NULL COMMENT '佣金金额',
  settlement_status TINYINT DEFAULT 0 COMMENT '0-待结算 1-已结算 2-提现中 3-已提现 -1-已无效',
  settlement_time   DATETIME COMMENT '结算时间',
  withdrawal_id     BIGINT COMMENT '关联提现记录ID',
  invalid           TINYINT DEFAULT 0 COMMENT '是否无效（订单取消/退保）',
  creator           VARCHAR(64) DEFAULT '',
  create_time       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updater           VARCHAR(64) DEFAULT '',
  update_time       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted           TINYINT DEFAULT 0,
  tenant_id         BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_agent_status (agent_id, settlement_status),
  KEY idx_order_id (order_id),
  KEY idx_agent_settlement_time (agent_id, settlement_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金记录表';
```

### ins_withdrawal（提现记录表）

```sql
CREATE TABLE ins_withdrawal (
  id                  BIGINT NOT NULL AUTO_INCREMENT,
  agent_id            BIGINT NOT NULL,
  withdrawal_no       VARCHAR(32) NOT NULL,
  amount              DECIMAL(15,2) NOT NULL,
  bank_name           VARCHAR(50) NOT NULL,
  bank_account        VARCHAR(300) NOT NULL COMMENT '银行卡号AES密文',
  bank_account_last4  VARCHAR(4) NOT NULL COMMENT '卡号后4位明文',
  account_name        VARCHAR(50) NOT NULL,
  status              TINYINT DEFAULT 1 COMMENT '1-审核中 2-已通过 3-已打款 4-已拒绝',
  reject_reason       VARCHAR(200),
  payment_voucher     VARCHAR(500),
  apply_time          DATETIME NOT NULL,
  audit_time          DATETIME,
  payment_time        DATETIME,
  auditor_id          BIGINT COMMENT '审核人ID',
  create_time         DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time         DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  tenant_id           BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_withdrawal_no (withdrawal_no),
  KEY idx_agent_status (agent_id, status, apply_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='提现记录表';
```

---

## 全局公共逻辑说明

### 数据权限控制

所有 B 端接口均须在后端校验数据归属权：
- 业务员角色：只能操作/查看自己（`agent_id = 当前登录用户ID`）的数据；
- 团队长角色（若有）：可查看直属团队成员的数据（`agent_id IN (团队成员ID列表)`）；
- 超出权限范围的操作返回 403 并记录安全日志。

### 敏感字段加密规范

| 字段 | 存储方式 | 查询方式 |
|---|---|---|
| 手机号 | AES-256-CBC 全密文 | 同时存 SHA256 hash 字段用于精确查询 |
| 身份证 | AES-256-CBC，前14位密文+"|"+后4位明文 | 后4位明文字段支持模糊查询 |
| 银行卡号 | AES-256-CBC 全密文 | 同时存后4位明文字段 |
| 展示脱敏 | 前端展示时：手机138****1234，身份证 330***...***1234 | 后端脱敏后返回，不传原文 |

### 消息通知统一入口

系统通知（跟进提醒、计划书查看通知、催单回执等）统一写入 `ins_message` 表：

```sql
CREATE TABLE ins_message (
  id          BIGINT NOT NULL AUTO_INCREMENT,
  agent_id    BIGINT NOT NULL COMMENT '接收人业务员ID',
  type        TINYINT NOT NULL COMMENT '1-跟进提醒 2-计划书被查看 3-催单回执 4-佣金到账 5-提现结果',
  title       VARCHAR(100) NOT NULL,
  content     VARCHAR(500) NOT NULL,
  is_read     TINYINT DEFAULT 0,
  related_id  BIGINT COMMENT '关联业务ID（客户ID/计划书ID/订单ID）',
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_agent_read (agent_id, is_read, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='消息通知表';
```

App 端通过 `GET /insurance/message/unread-count` 定时轮询（30秒间隔）获取未读消息数，显示红点角标。

---

## 工时估算（M5+M6+M7）

| 模块 | 功能点 | 前端工时 | 后端工时 | 合计 |
|---|---|---|---|---|
| M5 订单管理 | 订单列表（状态Tab+搜索） | 1天 | 0.5天 | 1.5天 |
| M5 订单管理 | 订单详情（流转日志） | 1天 | 0.5天 | 1.5天 |
| M5 订单管理 | 订单搜索 | 0.5天 | 0.5天 | 1天 |
| M5 订单管理 | 催单（次数限制+短信） | 0.5天 | 1天 | 1.5天 |
| M5 订单管理 | 取消订单 | 0.5天 | 0.5天 | 1天 |
| M6 业绩统计 | 业绩看板（4指标+同比） | 1.5天 | 1天 | 2.5天 |
| M6 业绩统计 | 业绩明细列表 | 1天 | 0.5天 | 1.5天 |
| M6 业绩统计 | 趋势图（双Y轴ECharts） | 1天 | 0.5天 | 1.5天 |
| M6 业绩统计 | 险种分布饼图 | 0.5天 | 0.5天 | 1天 |
| M7 佣金管理 | 佣金总览（可提现余额） | 1天 | 0.5天 | 1.5天 |
| M7 佣金管理 | 佣金明细列表 | 1天 | 0.5天 | 1.5天 |
| M7 佣金管理 | 提现申请（验证码+加锁） | 1.5天 | 2天 | 3.5天 |
| M7 佣金管理 | 提现记录 | 0.5天 | 0.5天 | 1天 |
| **合计** | | **11.5天** | **9天** | **20.5天** |

---

## 全模块工时汇总

| 文档 | 模块 | 前端工时 | 后端工时 | 合计 |
|---|---|---|---|---|
| 上册 | M1产品库 + M2保费试算 | 11天 | 8.5天 | 19.5天 |
| 中册 | M3计划书 + M4客户CRM | 16天 | 13天 | 29天 |
| 下册 | M5订单 + M6业绩 + M7佣金 | 11.5天 | 9天 | 20.5天 |
| **总计** | | **38.5天** | **30.5天** | **69天** |

> **配置说明：** 以上工时按 1前端 + 1后端 配置估算。前后端可并行开发，前端依赖后端接口联调时间约10天（含接口调试），因此实际上线时间约 **45-50个工作日**（约10周）。

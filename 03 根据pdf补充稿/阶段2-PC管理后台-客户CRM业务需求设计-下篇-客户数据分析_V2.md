# PC管理后台 · 客户CRM 业务需求设计文档【下篇】
## 模块：客户数据分析

> **文档版本**：V2.0（已根据操作手册补充细节）
> **对应排期**：阶段2-PC管理后台-客户CRM
> **技术栈**：yudao-cloud（Spring Cloud Alibaba）、MySQL 8.x、Redis、ECharts、Xxl-Job
> **工时估算**：前端 7.5天 + 后端 5天
>
> **PDF操作手册对应关系**：
> - `36号` → 客户-数据-目录
> - `37号` → 客户-数据-企业概览
> - `38号` → 客户-数据-员工报表
> - `39号` → 客户-数据-业务报表
> - `40号` → 客户-数据-监控数据

---

## 一、企业概览（数据大屏）
> 📄 **对应操作手册：37号（客户-数据-企业概览）**

### 1.1 页面入口与说明

菜单路径：`客户 → 数据 → 企业概览`

**性能设计核心原则**：大屏页面所有数据**读自统计汇总表**（`ins_stat_daily`），不直接查业务表。统计数据由每日凌晨3点定时任务（Xxl-Job）从各业务表计算写入统计表。页面加载时直接读统计表，响应 < 500ms。

### 1.2 企业概览核心内容（操作手册37号）

> 📄 **操作手册37号明确说明的核心功能**：
> 1. **客户实时数据池**：可根据时间段查看客户的分配情况、跟进状态
> 2. **客户跟进分析**：实时了解客户的报价情况、成单量、保费等数据
> 3. **跟进记录分析**：实时记录云短信、电话呼出的跟进状态
> 4. **员工呼出分析**：实时记录坐席的外部情况

### 1.3 页面内容布局

大屏采用全屏无菜单模式，分为以下区块：

#### 1.3.1 核心指标卡片（顶部一行，7个指标）

| 指标名 | 数据来源字段 | 说明 |
|---|---|---|
| 注册用户总数 | `ins_stat_summary.total_user_count` | 累计注册业务员+消费者 |
| 本月活跃用户 | `ins_stat_monthly.active_user_count` | 当月有登录行为的用户数 |
| 本月新增用户 | `ins_stat_monthly.new_user_count` | |
| 本月保费 | `ins_stat_monthly.total_premium` | 当月出单保费合计（元） |
| 累计保费 | `ins_stat_summary.total_premium_all` | 系统上线至今 |
| 在售保单数 | `ins_stat_summary.active_policy_count` | 当前有效保单数 |
| 历史报价数 | `ins_stat_summary.total_quote_count` | 系统上线至今报价记录数 |

#### 1.3.2 客户实时数据池（操作手册37号）

支持根据时间段查看客户的分配情况和跟进状态：

| 实时指标 | 说明 | 数据来源 |
|---|---|---|
| 今日新增客户数 | 当日新增客户 | Redis 实时INCR |
| 今日分配客户数 | 当日分配操作次数 | Redis 实时INCR |
| 跟进中客户数 | 当前处于跟进状态的客户数 | Redis 实时计算 |
| 未跟进客户数 | 当前未被跟进的客户总数 | 实时查询 |
| 今日跟进客户数 | 当日有跟进记录的客户数 | Redis 实时INCR |

前端每30秒轮询接口 `GET /admin-api/stat/realtime/customer-pool` 刷新数据。

#### 1.3.3 客户跟进分析（操作手册37号）

实时了解客户的报价情况、成单量、保费等数据：

| 分析指标 | 图表类型 | 说明 |
|---|---|---|
| 今日报价次数 | 数字卡片 | 实时 |
| 今日出单量 | 数字卡片 | 实时 |
| 今日保费金额 | 数字卡片 | 实时 |
| 报价→出单转化率 | 仪表盘 | 今日 |

#### 1.3.4 跟进记录分析（操作手册37号）

实时记录云短信、电话呼出的跟进状态：

| 分析指标 | 图表类型 | 说明 |
|---|---|---|
| 今日云短信发送数 | 数字卡片 | 实时 |
| 今日电话呼出次数 | 数字卡片 | 实时 |
| 短信发送成功率 | 进度条 | 今日 |
| 电话接通率 | 进度条 | 今日 |

#### 1.3.5 员工呼出分析（操作手册37号）

实时记录坐席的外部情况（需接入云呼叫功能）：
- 各坐席今日呼出次数
- 各坐席通话时长
- 坐席状态（在线/忙碌/离线）

#### 1.3.6 近12个月保费走势折线图

- ECharts 折线图，X轴12个月标签，Y轴保费金额（单位：万元）
- 数据来源：查 `ins_stat_monthly` 表近12条记录，字段 `stat_month`（YYYYMM）和 `total_premium`
- 鼠标悬停显示：该月保费XX万元，环比±XX%

#### 1.3.7 险种分布饼图

- ECharts 饼图，展示各险种（车险/意外险/健康险/财产险等）占总保费比例
- 数据来源：`ins_stat_summary` 或 `ins_stat_product_type` 表，字段：`product_type`、`premium`、`count`
- 图例可点击隐藏某险种

#### 1.3.8 保司贡献度柱状图

- ECharts 水平柱状图，X轴为保费金额，Y轴为各保险公司名称
- 取本月贡献保费 TOP10 保司，数据来源：`ins_stat_company_monthly`

#### 1.3.9 地域分布中国地图热力图

- ECharts Map（中国省份），颜色深浅表示各省客户数量
- 数据来源：`ins_stat_region`，字段：`province`、`customer_count`
- 鼠标悬停显示省份名称和客户数

#### 1.3.10 今日实时数据池

- 展示今日实时数据（不走统计表，直接实时查询，更新频率30秒）：今日新增客户、今日报价次数、今日出单量、今日分配客户数、今日跟进客户数、今日呼出次数
- 实现：前端轮询接口 `GET /admin-api/stat/realtime/today`，后端查Redis（由各业务模块在操作成功时实时INCR相应Key）

### 1.4 统计定时任务设计

```
每日凌晨3:00 Xxl-Job 触发 StatDailyJob：

1. 统计前一天(T-1)各维度数据：
   - 新增客户数（ins_customer.create_time = T-1）
   - 新增保单数/保费（ins_policy.sign_date = T-1）
   - 报价次数（ins_quote_record.create_time = T-1）
   - 按机构/业务员/险种/保司分组统计
   
2. UPSERT 到以下统计表（INSERT ... ON DUPLICATE KEY UPDATE）：
   - ins_stat_daily（每日统计）
   - ins_stat_monthly（月累计，每天追加）
   - ins_stat_summary（全量累计，每天更新总数）
   
3. 任务执行完毕记录日志到 ins_stat_job_log
```

### 1.5 数据库表设计

```sql
-- 每日统计表
CREATE TABLE ins_stat_daily (
    id              BIGINT  NOT NULL AUTO_INCREMENT,
    tenant_id       BIGINT  NOT NULL,
    stat_date       DATE    NOT NULL COMMENT '统计日期',
    new_customer    INT     DEFAULT 0 COMMENT '新增客户数',
    new_policy      INT     DEFAULT 0 COMMENT '新增保单数',
    total_premium   DECIMAL(18,2) DEFAULT 0 COMMENT '当日保费（元）',
    quote_count     INT     DEFAULT 0 COMMENT '报价次数',
    deal_rate       DECIMAL(5,2) COMMENT '出单转化率（%）',
    sms_count       INT     DEFAULT 0 COMMENT '当日发送短信条数',
    call_count      INT     DEFAULT 0 COMMENT '当日呼出次数',
    follow_count    INT     DEFAULT 0 COMMENT '当日跟进客户数',
    assign_count    INT     DEFAULT 0 COMMENT '当日分配客户数',
    PRIMARY KEY (id),
    UNIQUE KEY uk_tenant_date (tenant_id, stat_date)
) COMMENT = '每日统计表';

-- 月度统计表
CREATE TABLE ins_stat_monthly (
    id              BIGINT  NOT NULL AUTO_INCREMENT,
    tenant_id       BIGINT  NOT NULL,
    stat_month      VARCHAR(6) NOT NULL COMMENT '统计月份 YYYYMM',
    new_user_count  INT     DEFAULT 0 COMMENT '新增用户数',
    active_user_count INT   DEFAULT 0 COMMENT '活跃用户数',
    new_policy_count INT    DEFAULT 0 COMMENT '新增保单数',
    total_premium   DECIMAL(18,2) DEFAULT 0 COMMENT '月保费（元）',
    quote_count     INT     DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uk_tenant_month (tenant_id, stat_month)
) COMMENT = '月度统计表';

-- 汇总统计表（全量累计）
CREATE TABLE ins_stat_summary (
    id                  BIGINT  NOT NULL AUTO_INCREMENT,
    tenant_id           BIGINT  NOT NULL,
    total_user_count    BIGINT  DEFAULT 0,
    total_customer_count BIGINT DEFAULT 0,
    total_premium_all   DECIMAL(20,2) DEFAULT 0,
    active_policy_count INT    DEFAULT 0 COMMENT '当前有效保单数',
    total_quote_count   BIGINT  DEFAULT 0,
    update_time         DATETIME,
    PRIMARY KEY (id),
    UNIQUE KEY uk_tenant (tenant_id)
) COMMENT = '全量汇总统计';

-- Redis Key 规范（实时数据）
-- stat:today:{tenant_id}:new_customer   - 今日新增客户（INCR）
-- stat:today:{tenant_id}:new_policy     - 今日出单数
-- stat:today:{tenant_id}:quote_count    - 今日报价数
-- stat:today:{tenant_id}:follow_count   - 今日跟进客户数
-- stat:today:{tenant_id}:assign_count   - 今日分配客户数
-- stat:today:{tenant_id}:sms_count      - 今日发送短信数
-- stat:today:{tenant_id}:call_count     - 今日呼出次数
-- TTL: 每天0点由定时任务统一清零或设置48小时TTL
```

---

## 二、员工报表与业务报表
> 📄 **对应操作手册：38号（员工报表）、39号（业务报表）**

### 2.1 员工报表
> 📄 **操作手册38号：** "可以根据天或者月的维度来统计坐席的客户跟进情况，支持导出；战败或未结数据也会以报表的形式展示出来并支持导出"

菜单路径：`客户 → 数据 → 员工报表`

#### 2.1.1 查询维度切换

页面顶部提供三个维度Tab：**业务员维度** / **机构维度** / **部门维度**

#### 2.1.2 时间维度切换

支持按**天**或**月**的维度统计（操作手册38号），完整支持：本月 / 上月 / 本季 / 上季 / 本年 / 自定义区间（日期范围选择）

#### 2.1.3 业务员维度表格字段

| 字段 | 说明 |
|---|---|
| 排名 | 按保费自动排序 |
| 业务员姓名 | |
| 所属机构 | |
| 保费（元） | SUM(policy.total_premium) |
| 件数 | COUNT(policy) |
| 新增客户数 | COUNT(customer.create_time in 选择期间) |
| 跟进客户数 | 选择周期内有跟进记录的客户数（操作手册38号） |
| 完成率 | 实际保费 / 目标保费 × 100%，用进度条展示 |
| 目标保费 | 来自 `ins_performance_target` 表 |

进度条展示：目标值从 `ins_performance_target` 表读取（按业务员+时间周期匹配），若未设置目标值则不显示进度条。

**导出**：点击【导出Excel】，EasyExcel 导出当前筛选结果，包含所有可见列。

#### 2.1.4 战败/未结数据报表（操作手册38号）

> 📄 **操作手册38号：** "战败或未结数据也会以报表的形式展示出来并支持导出"

在员工报表页面增加独立Tab：**战败报表** 和 **未结报表**

**战败报表**：
- 展示已标记为"已流失/战败"状态的跟进记录，按业务员/机构分组统计
- 字段：业务员、战败客户数、战败原因分布（表格+柱状图）、时间周期

**未结报表**：
- 展示当前仍处于"跟进中"但超过设定天数未更新的记录
- 字段：业务员、未结客户数、平均跟进周期、最长未跟进天数

两者均支持**导出Excel**功能。

#### 2.1.5 目标值设置入口

点击右上角【设置目标】按钮（需权限），弹窗中可为每个业务员设置本月/本季/本年保费目标，数据存入 `ins_performance_target`。

#### 2.1.6 图表展示

在表格下方展示 ECharts 柱状图：X轴为业务员姓名，Y轴为保费金额，若有目标值则用折线叠加显示（折柱混合图）。

### 2.2 业务报表
> 📄 **操作手册39号：** "可根据报价查询、出单查询2个维度进行筛选数据，筛选出来的数据支持查看报价详情、分享报价单、进行重新报价等操作；点击这里可以把报价单指派给其他出单员"

菜单路径：`客户 → 数据 → 业务报表`

#### 2.2.1 报价查询与出单查询两大维度（操作手册39号）

**维度一：报价查询**
- 筛选条件：日期范围、业务员、险种、保司、报价状态
- 列表展示所有报价记录，支持查看报价详情、分享报价单、重新报价
- **指派出单员**（操作手册39号）：可将报价单指派给其他出单员处理

**维度二：出单查询**
- 筛选条件：日期范围、业务员、险种、保司、出单状态
- 列表展示所有出单记录，支持查看保单详情

#### 2.2.2 险种占比

- ECharts 饼图 + 数据表格并排展示
- 时间范围筛选（日期区间）
- 表格字段：险种名称、保单数量、保费金额、占比%
- 后端：GROUP BY policy_type 聚合

#### 2.2.3 保司占比

- 同险种占比，GROUP BY company_id

#### 2.2.4 客群年龄分布

- ECharts 柱状图，X轴年龄段（20以下/20-30/30-40/40-50/50-60/60以上），Y轴客户数
- 后端：根据 `ins_customer.birthday` 计算年龄，GROUP BY 年龄段

#### 2.2.5 新续保比例

- ECharts 环形图，展示"新保"和"续保"比例（按件数和保费两个维度可切换）
- 数据来源：`ins_policy.business_type`（NEW/RENEW）

### 2.3 数据库表（目标值）

```sql
CREATE TABLE ins_performance_target (
    id          BIGINT  NOT NULL AUTO_INCREMENT,
    tenant_id   BIGINT  NOT NULL,
    agent_id    BIGINT  NOT NULL COMMENT '业务员ID',
    period_type VARCHAR(20) COMMENT '周期类型：MONTH/QUARTER/YEAR',
    period_val  VARCHAR(10) COMMENT '周期值：YYYYMM或YYYY-Q1或YYYY',
    target_premium DECIMAL(18,2) COMMENT '保费目标（元）',
    target_count INT             COMMENT '件数目标',
    create_by   BIGINT,
    create_time DATETIME,
    PRIMARY KEY (id),
    UNIQUE KEY uk_agent_period (agent_id, period_type, period_val)
) COMMENT = '业绩目标';
```

---

## 三、监控数据看板
> 📄 **对应操作手册：40号（客户-数据-监控数据）**

### 3.1 功能概览

菜单路径：`客户 → 数据 → 监控数据`

此页面展示系统运营实时监控指标，用于管理员及运营人员实时掌握系统健康状态。

### 3.2 监控数据页面内容（操作手册40号）

> 📄 **操作手册40号核心内容**：
> - **语音记录**：当语音转文字权限打开，质监窗口就会有转文字按钮，可以把语音转换成文字，转换记录放在转文字记录Tab页
> - **语音批量下载**：查询出来的数据点击下载录音文件按钮会生成录音压缩包：第一层文件夹是坐席名字，第二层文件夹是客户名称_客户手机号
> - **短信记录**：可查看短信的发送情况、发送详情等信息并支持导出
> - **转文字记录**：转文字是需要额外收费

监控数据看板包含以下内容区域：

#### 3.2.1 语音记录 Tab（操作手册40号）

**功能**：
- 列表展示通话录音记录，含坐席名称、客户姓名、客户手机号、通话时长、通话时间、录音文件
- **语音转文字**：当语音转文字权限打开后，质监窗口显示【转文字】按钮，可将录音转换为文字记录（需额外付费）
- **转文字记录查看**：独立的转文字记录Tab，展示已转换的录音文字内容

**语音批量下载**（操作手册40号）：
- 查询出来的数据点击【下载录音文件】按钮会生成录音压缩包
- 压缩包结构：第一层文件夹为坐席名字，第二层文件夹为`客户名称_客户手机号`
- 异步生成，完成后通知下载链接

#### 3.2.2 短信记录 Tab（操作手册40号）

**功能**：
- 可查看短信的发送情况、发送详情等信息
- 筛选条件：发送时间范围、接收手机号、发送状态（成功/失败/退订）
- 支持**导出**短信记录Excel
- 字段：发送时间、接收号码（脱敏）、发送内容、发送状态、运营商回执码、所属任务

#### 3.2.3 转文字记录 Tab（操作手册40号）

> ⚠️ **注意**：转文字是需要额外收费的功能，需开通后才能使用

- 展示已进行语音转文字的记录列表
- 字段：转换时间、坐席名称、客户信息、原始录音时长、转换文字内容（摘要）、操作（查看全文）

### 3.3 运营实时监控指标

页面分两大区：**核心运营指标** 和 **异常告警区**

#### 3.3.1 核心运营指标

使用 ECharts 仪表盘（Gauge）展示，每个指标一个仪表盘组件：

| 指标名 | 计算方式 | 刷新频率 |
|---|---|---|
| 报价成功率 | 成功报价次数 / 总报价次数 × 100%（当日） | 30秒轮询 |
| 出单转化率 | 出单数 / 有效报价次数 × 100%（当日） | 30秒轮询 |
| 核保通过率 | 核保通过数 / 核保总数 × 100%（当日） | 30秒轮询 |
| 理赔处理及时率 | 24h内处理理赔数 / 总理赔数 × 100% | 5分钟轮询 |

**数据来源**：Redis 实时计数（各业务模块在操作节点 INCR 对应 Key），后端接口读 Redis，5分钟批量同步到 `ins_stat_monitor` 表持久化。

**Redis Key 设计**：
```
ins:monitor:{tenant_id}:quote_total      - 今日报价总数
ins:monitor:{tenant_id}:quote_success    - 今日成功报价数
ins:monitor:{tenant_id}:policy_deal      - 今日出单数
ins:monitor:{tenant_id}:underwrite_total - 今日核保总数
ins:monitor:{tenant_id}:underwrite_pass  - 今日核保通过数
TTL: 48小时
```

#### 3.3.2 异常告警区

展示当前触发的告警列表，告警卡片颜色：红色（严重）/ 橙色（警告）

**告警规则**（可配置，存入 `ins_alert_rule` 表）：

| 告警类型 | 默认阈值 | 触发条件 |
|---|---|---|
| 核保通过率骤降 | < 60% | 核保通过率低于阈值 |
| 报价接口超时率高 | > 10% | 报价超时次数/报价总数 > 阈值 |
| 出单转化率异常 | < 20% | 当日转化率低于阈值 |

触发告警时：
1. 在告警区展示告警卡片（告警类型、当前值、阈值、触发时间）
2. 同时发送站内信通知给系统管理员（`ins_notice` 表）
3. 告警消除条件：对应指标恢复到阈值以上后，告警卡片变灰并显示"已恢复"

#### 3.3.3 历史趋势图

页面下部展示近24小时各指标趋势折线图（每5分钟一个数据点），数据来源：`ins_stat_monitor` 表查询。

### 3.4 告警阈值配置

右上角【配置】按钮（需管理员权限）：弹出配置弹窗，可修改各告警规则的阈值（数值输入框），保存后更新 `ins_alert_rule` 表，系统配置热加载（Redis 缓存，TTL 5分钟）。

### 3.5 数据库表设计

```sql
-- 监控指标记录表（5分钟批量写入）
CREATE TABLE ins_stat_monitor (
    id              BIGINT  NOT NULL AUTO_INCREMENT,
    tenant_id       BIGINT  NOT NULL,
    record_time     DATETIME NOT NULL COMMENT '记录时间（每5分钟一条）',
    quote_success_rate DECIMAL(5,2) COMMENT '报价成功率(%)',
    deal_convert_rate  DECIMAL(5,2) COMMENT '出单转化率(%)',
    underwrite_pass_rate DECIMAL(5,2) COMMENT '核保通过率(%)',
    claim_timely_rate  DECIMAL(5,2) COMMENT '理赔及时率(%)',
    PRIMARY KEY (id),
    INDEX idx_tenant_time (tenant_id, record_time)
) COMMENT = '系统监控指标记录';

-- 告警规则表
CREATE TABLE ins_alert_rule (
    id          BIGINT  NOT NULL AUTO_INCREMENT,
    tenant_id   BIGINT  NOT NULL,
    rule_code   VARCHAR(50) NOT NULL COMMENT '规则编码',
    rule_name   VARCHAR(100) NOT NULL COMMENT '规则名称',
    threshold   DECIMAL(10,2) NOT NULL COMMENT '告警阈值',
    direction   VARCHAR(10) COMMENT '方向：LT-小于阈值告警 GT-大于阈值告警',
    notify_user_ids VARCHAR(500) COMMENT '通知用户ID列表（逗号分隔）',
    enabled     TINYINT DEFAULT 1 COMMENT '是否启用',
    update_time DATETIME,
    PRIMARY KEY (id),
    UNIQUE KEY uk_tenant_code (tenant_id, rule_code)
) COMMENT = '告警规则配置';

-- 告警记录表
CREATE TABLE ins_alert_log (
    id          BIGINT  NOT NULL AUTO_INCREMENT,
    tenant_id   BIGINT  NOT NULL,
    rule_id     BIGINT  NOT NULL COMMENT '告警规则ID',
    trigger_value DECIMAL(10,2) COMMENT '触发时的指标值',
    threshold   DECIMAL(10,2) COMMENT '阈值（快照）',
    trigger_time DATETIME NOT NULL COMMENT '触发时间',
    recover_time DATETIME COMMENT '恢复时间（NULL=未恢复）',
    status      VARCHAR(20) DEFAULT 'ACTIVE' COMMENT 'ACTIVE/RECOVERED',
    PRIMARY KEY (id),
    INDEX idx_tenant_status (tenant_id, status)
) COMMENT = '告警记录';

-- 语音记录表（云呼叫录音）
CREATE TABLE ins_voice_record (
    id              BIGINT      NOT NULL AUTO_INCREMENT,
    tenant_id       BIGINT      NOT NULL,
    agent_id        BIGINT      NOT NULL COMMENT '坐席ID',
    agent_name      VARCHAR(50) COMMENT '坐席名称',
    customer_id     BIGINT      COMMENT '客户ID',
    customer_name   VARCHAR(50) COMMENT '客户姓名',
    phone_suffix    VARCHAR(4)  COMMENT '客户手机后4位',
    duration        INT         DEFAULT 0 COMMENT '通话时长（秒）',
    file_url        VARCHAR(500) COMMENT '录音文件OSS URL',
    call_time       DATETIME    COMMENT '通话时间',
    transcribe_status VARCHAR(20) DEFAULT 'NONE' COMMENT '转文字状态：NONE/PENDING/DONE/FAILED',
    transcribe_text TEXT        COMMENT '转文字内容',
    transcribe_time DATETIME    COMMENT '转文字完成时间',
    create_time     DATETIME,
    PRIMARY KEY (id),
    INDEX idx_agent_id (agent_id),
    INDEX idx_call_time (tenant_id, call_time)
) COMMENT = '语音通话记录';
```

---

## 四、API接口清单（数据分析模块）

| 接口 | 方法 | 路径 | 说明 | 对应PDF |
|---|---|---|---|---|
| 企业概览-核心指标 | GET | `/admin-api/stat/overview/summary` | 读统计表 | 37号 |
| 企业概览-保费趋势 | GET | `/admin-api/stat/overview/premium-trend` | 近12个月 | 37号 |
| 企业概览-险种分布 | GET | `/admin-api/stat/overview/product-type-pie` | | 37号 |
| 企业概览-保司贡献 | GET | `/admin-api/stat/overview/company-bar` | TOP10 | 37号 |
| 企业概览-地域分布 | GET | `/admin-api/stat/overview/region-map` | 省份数据 | 37号 |
| 客户实时数据池 | GET | `/admin-api/stat/realtime/customer-pool` | 读Redis | 37号 |
| 跟进分析实时数据 | GET | `/admin-api/stat/realtime/follow-analysis` | 读Redis | 37号 |
| 今日实时数据 | GET | `/admin-api/stat/realtime/today` | 读Redis | 37号 |
| 员工报表列表 | GET | `/admin-api/stat/agent/report/page` | 分页+排序 | 38号 |
| 员工报表导出 | GET | `/admin-api/stat/agent/report/export` | | 38号 |
| 战败报表 | GET | `/admin-api/stat/agent/defeat/page` | 战败数据 | 38号 |
| 未结报表 | GET | `/admin-api/stat/agent/pending/page` | 未结数据 | 38号 |
| 战败/未结导出 | GET | `/admin-api/stat/agent/defeat-pending/export` | EasyExcel | 38号 |
| 设置业绩目标 | POST | `/admin-api/stat/agent/target/save` | UPSERT | 38号 |
| 业务报表-报价查询 | GET | `/admin-api/stat/business/quote/page` | 分页 | 39号 |
| 业务报表-出单查询 | GET | `/admin-api/stat/business/policy/page` | 分页 | 39号 |
| 报价指派出单员 | POST | `/admin-api/stat/business/quote/assign` | | 39号 |
| 业务报表-险种占比 | GET | `/admin-api/stat/business/product-type` | | 39号 |
| 业务报表-保司占比 | GET | `/admin-api/stat/business/company` | | 39号 |
| 业务报表-年龄分布 | GET | `/admin-api/stat/business/age-group` | | 39号 |
| 业务报表-新续保比 | GET | `/admin-api/stat/business/new-renew-ratio` | | 39号 |
| 监控-实时指标 | GET | `/admin-api/stat/monitor/realtime` | 30秒轮询 | 40号 |
| 监控-历史趋势 | GET | `/admin-api/stat/monitor/trend` | 近24小时 | 40号 |
| 告警规则列表 | GET | `/admin-api/stat/alert/rule/list` | | 40号 |
| 修改告警阈值 | PUT | `/admin-api/stat/alert/rule/update` | | 40号 |
| 当前告警列表 | GET | `/admin-api/stat/alert/active/list` | | 40号 |
| 语音记录列表 | GET | `/admin-api/stat/voice/page` | | 40号 |
| 语音批量下载 | POST | `/admin-api/stat/voice/batch-download` | 异步生成压缩包 | 40号 |
| 发起语音转文字 | POST | `/admin-api/stat/voice/transcribe` | 需开通权限 | 40号 |
| 短信记录列表 | GET | `/admin-api/stat/sms-record/page` | | 40号 |
| 短信记录导出 | GET | `/admin-api/stat/sms-record/export` | EasyExcel | 40号 |
| 转文字记录列表 | GET | `/admin-api/stat/voice/transcribe/page` | | 40号 |

---

## 五、权限控制汇总

本模块涉及的权限点（对应 yudao-cloud `system_menu` 表 `permission` 字段）：

| 权限标识 | 说明 | 适用角色 | 对应PDF |
|---|---|---|---|
| `crm:customer:query` | 查询客户列表 | 所有员工 | 25/26号 |
| `crm:customer:create` | 新增客户 | 业务员及以上 | 25号 |
| `crm:customer:update` | 修改客户 | 业务员及以上 | 25号 |
| `crm:customer:delete` | 删除客户 | 主管及以上 | 25号 |
| `crm:customer:transfer` | 移交客户 | 主管及以上 | 26号 |
| `crm:customer:export` | 导出客户 | 主管及以上 | 25号 |
| `crm:customer:assign` | 分配客户 | 内勤及以上 | 25号 |
| `crm:customer:recycle` | 回收客户 | 主管及以上 | 25号 |
| `crm:customer:batch-quote` | 批量报价 | 业务员及以上 | 25/26号 |
| `crm:follow:proxy` | 代录跟进记录 | 主管及以上 | 29号 |
| `crm:renewal:assign` | 分配续期任务 | 内勤及以上 | 30号 |
| `crm:sms:send` | 发送云短信 | 客服专员及以上 | 33号 |
| `crm:sms:template:create` | 新增短信模板 | 客服专员及以上 | 33号 |
| `stat:overview:view` | 查看企业概览 | 管理员 | 37号 |
| `stat:report:view` | 查看员工/业务报表 | 主管及以上 | 38/39号 |
| `stat:target:edit` | 设置业绩目标 | 主管及以上 | 38号 |
| `stat:alert:config` | 配置告警阈值 | 系统管理员 | 40号 |
| `stat:monitor:view` | 查看监控看板 | 管理员 | 40号 |
| `stat:voice:transcribe` | 语音转文字 | 管理员（需开通付费） | 40号 |
| `stat:voice:download` | 批量下载录音 | 主管及以上 | 40号 |

**数据权限（行级权限）**：
- 管理员：不限制，查全租户数据
- 机构主管：只能查本机构及下级机构的数据（`org_id IN (当前机构及子机构ID列表)`）
- 普通业务员：只能查 `agent_id = 自己` 的数据

数据权限通过 yudao-cloud 框架的 `@DataPermission` 注解 + 自定义 `InsDataPermissionRuleCustomizer` 实现，避免在每个 SQL 中手动拼接 WHERE 条件。

---

## 六、公共技术说明

### 6.1 加密规则

手机号、证件号在数据库中均加密存储（AES-256），同时维护明文后4位用于搜索（`phone_suffix`、`id_card_suffix`），避免全表解密。

加密工具类：`CrmEncryptUtils`（封装 yudao-cloud 的加密工具）

### 6.2 EasyExcel 使用规范

- 导入：使用 `EasyExcel.read()` + 自定义 Listener，每100行校验一次，每500行批量 INSERT
- 导出：数据量 > 5000 行时采用异步方式（先返回"导出任务已提交"，完成后站内信通知）
- 导出手机号/证件号：统一脱敏，不允许明文导出

### 6.3 分页统一规范

- 请求参数：`pageNo`（从1开始）、`pageSize`（默认20，最大100）
- 响应结构：`{ total, list, pageNo, pageSize }`
- 使用 MyBatis Plus `IPage` 分页，结合 `@DataPermission` 自动注入数据权限 SQL

### 6.4 统计数据时效性说明

| 数据类型 | 时效性 | 实现方式 |
|---|---|---|
| 今日实时数据池 | 实时（30秒刷新） | Redis 计数 + 轮询 |
| 运营监控指标 | 准实时（30秒/5分钟） | Redis + 定时持久化 |
| 历史统计数据 | T+1（每日凌晨3点更新） | Xxl-Job + 统计表 |
| 大屏展示数据 | T+1 | 统计表直读 |

---

> **文档完结**
> 共拆分为【上篇-客户管理】【中篇-续期管理与云短信】【下篇-客户数据分析】三个文档
> 合计工时：前端 20.5天 + 后端 15天 = **35.5天**
>
> **新增内容说明（V2.0 vs V1.0）**：
> - 上篇：补充了批量报价/变更组织/回收客户功能；补充了任务列表功能；新增导入批次管理；补充客户设置章节
> - 中篇：补充续期看板的商户看板/机构看板/续保提醒/续保跟踪四大区域；补充导出续回保单专项功能；补充短信按操作手册的精确权限描述和计费规则；新增短信系统设置表
> - 下篇：补充企业概览的客户实时数据池/跟进分析/跟进记录分析/员工呼出分析四大内容区；补充员工报表的战败/未结数据报表；补充业务报表的报价查询/出单查询维度；监控数据补充语音记录/短信记录/转文字记录三个Tab

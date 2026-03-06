# PC管理后台 · 客户CRM 业务需求设计文档【下篇】
## 模块：客户数据分析

> **文档版本**：V1.0  
> **对应排期**：阶段2-PC管理后台-客户CRM  
> **技术栈**：yudao-cloud（Spring Cloud Alibaba）、MySQL 8.x、Redis、ECharts、Xxl-Job  
> **工时估算**：前端 7.5天 + 后端 5天  

---

## 一、企业概览（数据大屏）

### 1.1 页面入口与说明

菜单路径：`客户 → 数据 → 企业概览`

**性能设计核心原则**：大屏页面所有数据**读自统计汇总表**（`ins_stat_daily`），不直接查业务表。统计数据由每日凌晨3点定时任务（Xxl-Job）从各业务表计算写入统计表。页面加载时直接读统计表，响应 < 500ms。

### 1.2 页面内容布局

大屏采用全屏无菜单模式，分为以下区块：

#### 1.2.1 核心指标卡片（顶部一行，7个指标）

| 指标名 | 数据来源字段 | 说明 |
|---|---|---|
| 注册用户总数 | `ins_stat_summary.total_user_count` | 累计注册业务员+消费者 |
| 本月活跃用户 | `ins_stat_monthly.active_user_count` | 当月有登录行为的用户数 |
| 本月新增用户 | `ins_stat_monthly.new_user_count` | |
| 本月保费 | `ins_stat_monthly.total_premium` | 当月出单保费合计（元） |
| 累计保费 | `ins_stat_summary.total_premium_all` | 系统上线至今 |
| 在售保单数 | `ins_stat_summary.active_policy_count` | 当前有效保单数 |
| 历史报价数 | `ins_stat_summary.total_quote_count` | 系统上线至今报价记录数 |

#### 1.2.2 近12个月保费走势折线图

- ECharts 折线图，X轴12个月标签，Y轴保费金额（单位：万元）
- 数据来源：查 `ins_stat_monthly` 表近12条记录，字段 `stat_month`（YYYYMM）和 `total_premium`
- 鼠标悬停显示：该月保费XX万元，环比±XX%

#### 1.2.3 险种分布饼图

- ECharts 饼图，展示各险种（车险/意外险/健康险/财产险等）占总保费比例
- 数据来源：`ins_stat_summary` 或 `ins_stat_product_type` 表，字段：`product_type`、`premium`、`count`
- 图例可点击隐藏某险种

#### 1.2.4 保司贡献度柱状图

- ECharts 水平柱状图，X轴为保费金额，Y轴为各保险公司名称
- 取本月贡献保费 TOP10 保司，数据来源：`ins_stat_company_monthly`

#### 1.2.5 地域分布中国地图热力图

- ECharts Map（中国省份），颜色深浅表示各省客户数量
- 数据来源：`ins_stat_region`，字段：`province`、`customer_count`
- 鼠标悬停显示省份名称和客户数

#### 1.2.6 今日实时数据池

- 展示今日实时数据（不走统计表，直接实时查询，更新频率30秒）：今日新增客户、今日报价次数、今日出单量、今日分配客户数、今日跟进客户数、今日呼出次数
- 实现：前端轮询接口 `GET /admin-api/stat/realtime/today`，后端查Redis（由各业务模块在操作成功时实时INCR相应Key）

### 1.3 统计定时任务设计

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

### 1.4 数据库表设计

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
-- sms:stat:today:{tenant_id}:new_customer   - 今日新增客户（INCR）
-- sms:stat:today:{tenant_id}:new_policy     - 今日出单数
-- sms:stat:today:{tenant_id}:quote_count    - 今日报价数
-- TTL: 每天0点由定时任务统一清零或设置48小时TTL
```

---

## 二、员工报表与业务报表

### 2.1 员工报表

菜单路径：`客户 → 数据 → 员工报表`

#### 2.1.1 查询维度切换

页面顶部提供三个维度Tab：**业务员维度** / **机构维度** / **部门维度**

#### 2.1.2 时间维度切换

支持：本月 / 上月 / 本季 / 上季 / 本年 / 自定义区间（日期范围选择）

#### 2.1.3 业务员维度表格字段

| 字段 | 说明 |
|---|---|
| 排名 | 按保费自动排序 |
| 业务员姓名 | |
| 所属机构 | |
| 保费（元） | SUM(policy.total_premium) |
| 件数 | COUNT(policy) |
| 新增客户数 | COUNT(customer.create_time in 选择期间) |
| 完成率 | 实际保费 / 目标保费 × 100%，用进度条展示 |
| 目标保费 | 来自 `ins_performance_target` 表 |

进度条展示：目标值从 `ins_performance_target` 表读取（按业务员+时间周期匹配），若未设置目标值则不显示进度条。

**导出**：点击【导出Excel】，EasyExcel 导出当前筛选结果，包含所有可见列。

#### 2.1.4 目标值设置入口

点击右上角【设置目标】按钮（需权限），弹窗中可为每个业务员设置本月/本季/本年保费目标，数据存入 `ins_performance_target`。

#### 2.1.5 图表展示

在表格下方展示 ECharts 柱状图：X轴为业务员姓名，Y轴为保费金额，若有目标值则用折线叠加显示（折柱混合图）。

### 2.2 业务报表

#### 2.2.1 险种占比

- ECharts 饼图 + 数据表格并排展示
- 时间范围筛选（日期区间）
- 表格字段：险种名称、保单数量、保费金额、占比%
- 后端：GROUP BY policy_type 聚合

#### 2.2.2 保司占比

- 同险种占比，GROUP BY company_id

#### 2.2.3 客群年龄分布

- ECharts 柱状图，X轴年龄段（20以下/20-30/30-40/40-50/50-60/60以上），Y轴客户数
- 后端：根据 `ins_customer.birthday` 计算年龄，GROUP BY 年龄段

#### 2.2.4 新续保比例

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

### 3.1 功能概览

菜单路径：`客户 → 数据 → 监控数据`

此页面展示系统运营实时监控指标，用于管理员及运营人员实时掌握系统健康状态。

### 3.2 实时指标展示

页面分两大区：**核心运营指标** 和 **异常告警区**

#### 3.2.1 核心运营指标

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

#### 3.2.2 异常告警区

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

#### 3.2.3 历史趋势图

页面下部展示近24小时各指标趋势折线图（每5分钟一个数据点），数据来源：`ins_stat_monitor` 表查询。

### 3.3 告警阈值配置

右上角【配置】按钮（需管理员权限）：弹出配置弹窗，可修改各告警规则的阈值（数值输入框），保存后更新 `ins_alert_rule` 表，系统配置热加载（Redis 缓存，TTL 5分钟）。

### 3.4 数据库表设计

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
```

---

## 四、API接口清单（数据分析模块）

| 接口 | 方法 | 路径 | 说明 |
|---|---|---|---|
| 企业概览-核心指标 | GET | `/admin-api/stat/overview/summary` | 读统计表 |
| 企业概览-保费趋势 | GET | `/admin-api/stat/overview/premium-trend` | 近12个月 |
| 企业概览-险种分布 | GET | `/admin-api/stat/overview/product-type-pie` | |
| 企业概览-保司贡献 | GET | `/admin-api/stat/overview/company-bar` | TOP10 |
| 企业概览-地域分布 | GET | `/admin-api/stat/overview/region-map` | 省份数据 |
| 今日实时数据 | GET | `/admin-api/stat/realtime/today` | 读Redis |
| 员工报表列表 | GET | `/admin-api/stat/agent/report/page` | 分页+排序 |
| 员工报表导出 | GET | `/admin-api/stat/agent/report/export` | |
| 设置业绩目标 | POST | `/admin-api/stat/agent/target/save` | UPSERT |
| 业务报表-险种占比 | GET | `/admin-api/stat/business/product-type` | |
| 业务报表-保司占比 | GET | `/admin-api/stat/business/company` | |
| 业务报表-年龄分布 | GET | `/admin-api/stat/business/age-group` | |
| 业务报表-新续保比 | GET | `/admin-api/stat/business/new-renew-ratio` | |
| 监控-实时指标 | GET | `/admin-api/stat/monitor/realtime` | 30秒轮询 |
| 监控-历史趋势 | GET | `/admin-api/stat/monitor/trend` | 近24小时 |
| 告警规则列表 | GET | `/admin-api/stat/alert/rule/list` | |
| 修改告警阈值 | PUT | `/admin-api/stat/alert/rule/update` | |
| 当前告警列表 | GET | `/admin-api/stat/alert/active/list` | |

---

## 五、权限控制汇总

本模块涉及的权限点（对应 yudao-cloud `system_menu` 表 `permission` 字段）：

| 权限标识 | 说明 | 适用角色 |
|---|---|---|
| `crm:customer:query` | 查询客户列表 | 所有员工 |
| `crm:customer:create` | 新增客户 | 业务员及以上 |
| `crm:customer:update` | 修改客户 | 业务员及以上 |
| `crm:customer:delete` | 删除客户 | 主管及以上 |
| `crm:customer:transfer` | 移交客户 | 主管及以上 |
| `crm:customer:export` | 导出客户 | 主管及以上 |
| `crm:follow:proxy` | 代录跟进记录 | 主管及以上 |
| `crm:renewal:assign` | 分配续期任务 | 内勤及以上 |
| `crm:sms:send` | 发送云短信 | 客服专员及以上 |
| `crm:sms:template:create` | 新增短信模板 | 客服专员及以上 |
| `stat:overview:view` | 查看企业概览 | 管理员 |
| `stat:report:view` | 查看员工/业务报表 | 主管及以上 |
| `stat:target:edit` | 设置业绩目标 | 主管及以上 |
| `stat:alert:config` | 配置告警阈值 | 系统管理员 |
| `stat:monitor:view` | 查看监控看板 | 管理员 |

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

---

> **文档完结**  
> 共拆分为【上篇-客户管理】【中篇-续期管理与云短信】【下篇-客户数据分析】三个文档  
> 合计工时：前端 19.5天 + 后端 15天 = **34.5天**

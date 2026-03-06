# 阶段2-PC佣金系统详细需求文档【下篇】
## 订单管理 + 保单管理 + 财务报表 + 通用开发规范

> 版本：V3.0 | 日期：2026-02-18 | 技术栈：yudao-cloud（微服务版）+ MySQL 8.0 + Redis  
> 配置：1前端 + 1后端

---

## 一、模块总览

| 模块 | 功能点 | 工时（前+后） |
|------|--------|---------------|
| 订单管理 | 订单中心（列表+高级搜索） | 1.5+1 = 2.5天 |
| 订单管理 | 订单详情 | 1+0.5 = 1.5天 |
| 订单管理 | 订单审核（风控） | 1.5+1.5 = 3天 |
| 订单管理 | 订单改批 | 1+1 = 2天 |
| 订单管理 | 订单退保 | 1+1 = 2天 |
| 保单管理 | 保单列表（查询筛选） | 1+0.5 = 1.5天 |
| 保单管理 | 保单录入（手动） | 1.5+1 = 2.5天 |
| 保单管理 | 保单验真 | 0.5+1 = 1.5天 |
| 保单管理 | 保单变更（批改/加保） | 1+1 = 2天 |
| 保单管理 | 保单导出 | 0.5+0.5 = 1天 |
| 财务报表 | 收入报表 | 1.5+1 = 2.5天 |
| 财务报表 | 支出报表（佣金） | 1.5+1 = 2.5天 |
| 财务报表 | 利润分析 | 1.5+1 = 2.5天 |
| 财务报表 | 佣金发放汇总 | 1+0.5 = 1.5天 |

---

## 二、订单管理模块

### 2.1 订单中心

#### 2.1.1 功能说明

订单是保单的前置流程，代表客户已下单但保单尚未签发的状态。本模块提供全量订单的查询、搜索和管理能力。

#### 2.1.2 订单列表页

**入口**：佣金管理 → 订单管理 → 订单中心

**展示字段**：订单号、保险公司、险种、被保人姓名、保费（元）、保单状态、业务员、下单时间、操作（查看/审核/改批/退保）

**基础搜索条件**：
- 订单号（精确）
- 被保人姓名（模糊）
- 险种（下拉多选）
- 保单状态（下拉：待审核/已承保/改批中/退保中/已退保/已拒保）
- 时间范围（下单时间，日期区间选择）

**高级搜索（展开区域）**：
- 保险公司（下拉多选）
- 业务员（员工选择器，支持姓名/工号搜索）
- 保费范围（最低-最高）
- 支付状态（已支付/未支付）

> **技术说明**：高级搜索推荐使用 Elasticsearch 实现，支持多字段复合查询。若未部署ES，可使用MySQL动态SQL + 索引覆盖实现。

#### 2.1.3 数据库表（订单主表）

```sql
CREATE TABLE `insurance_order` (
  `id`                 bigint(20)    NOT NULL AUTO_INCREMENT,
  `order_no`           varchar(64)   NOT NULL COMMENT '订单号（ORD+YYYYMMDD+6位序）',
  `policy_no`          varchar(128)  DEFAULT NULL COMMENT '关联保单号（承保后填入）',
  `insurance_company`  varchar(128)  NOT NULL COMMENT '保险公司',
  `product_id`         bigint(20)    NOT NULL COMMENT '产品ID',
  `product_name`       varchar(128)  NOT NULL,
  `product_category`   varchar(32)   NOT NULL COMMENT 'CAR/LIFE/HEALTH',
  `insured_name`       varchar(64)   NOT NULL COMMENT '被保人姓名',
  `insured_id_no`      varchar(32)   DEFAULT NULL COMMENT '被保人身份证号（加密存储）',
  `insured_mobile`     varchar(20)   DEFAULT NULL COMMENT '被保人手机（加密存储）',
  `policyholder_name`  varchar(64)   DEFAULT NULL COMMENT '投保人姓名',
  `premium`            decimal(12,2) NOT NULL COMMENT '保费（元）',
  `payment_period`     int(11)       DEFAULT NULL COMMENT '缴费年期',
  `sum_insured`        decimal(15,2) DEFAULT NULL COMMENT '保额（元）',
  `agent_id`           bigint(20)    NOT NULL COMMENT '业务员ID',
  `agent_name`         varchar(64)   NOT NULL,
  `channel`            varchar(32)   DEFAULT NULL COMMENT '来源渠道（APP/PC/SCAN_CODE）',
  `order_status`       varchar(32)   NOT NULL DEFAULT 'PENDING'
                       COMMENT 'PENDING/PAID/UNDERWRITING/INSURED/REJECTED/CANCEL_PENDING/CANCELLED',
  `audit_status`       varchar(32)   DEFAULT NULL COMMENT '风控审核状态（PASS/REJECT/MANUAL）',
  `audit_remark`       varchar(500)  DEFAULT NULL,
  `pay_status`         varchar(32)   DEFAULT 'UNPAID' COMMENT 'UNPAID/PAID/REFUNDED',
  `pay_time`           datetime      DEFAULT NULL,
  `pay_amount`         decimal(12,2) DEFAULT NULL,
  `pay_channel`        varchar(32)   DEFAULT NULL,
  `start_date`         date          DEFAULT NULL COMMENT '保险起期',
  `end_date`           date          DEFAULT NULL COMMENT '保险止期',
  `remark`             varchar(500)  DEFAULT NULL,
  `creator`            varchar(64)   DEFAULT NULL,
  `create_time`        datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`            varchar(64)   DEFAULT NULL,
  `update_time`        datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`            tinyint(1)    DEFAULT 0,
  `tenant_id`          bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_order_status` (`order_status`),
  KEY `idx_create_time` (`create_time`),
  KEY `idx_insured_mobile` (`insured_mobile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保险订单表';
```

---

### 2.2 订单详情

#### 2.2.1 详情页内容

**页面布局（Tab切换）**：
- Tab1：订单基本信息（险种、产品、保费、保期等）
- Tab2：投被保人信息（姓名、证件号、手机号等，证件号脱敏显示）
- Tab3：支付信息（支付渠道、金额、时间、流水号）
- Tab4：审核记录（风控审核结果、人工审核记录）
- Tab5：操作日志（所有状态变更记录）

---

### 2.3 订单审核（风控审核）

#### 2.3.1 功能说明

对高风险订单进行人工风控审核。系统自动规则引擎初判后，标记需人工处理的订单进入审核队列。

#### 2.3.2 待审核订单列表

**入口**：佣金管理 → 订单管理 → 待审核订单

**展示字段**：订单号、险种、被保人、保费、风险等级（高/中/低）、风险原因、等待时长、操作（审核）

**风险自动标记规则**（后端规则引擎，在订单创建时同步执行）：

| 风险规则 | 风险等级 | 处理方式 |
|---------|---------|---------|
| 单笔保费 > 50万元 | 高 | 必须人工审核 |
| 短时间内（1小时）同一被保人重复投保 | 高 | 必须人工审核 |
| 被保人在黑名单中 | 高 | 自动拒保 |
| 业务员近30天内连续10笔被退保 | 中 | 标记人工审核 |
| 新业务员（入职<30天）保费>10万 | 中 | 标记人工审核 |
| 其他 | 低 | 自动通过 |

#### 2.3.3 审核操作弹窗

点击【审核】，弹出审核弹窗包含：
- 订单关键信息展示（只读）
- 风险原因说明
- 审核操作：【通过】/ 【拒保】/ 【需补充材料】

**审核通过（后端）**：
1. 更新 `insurance_order.audit_status='PASS'`
2. 若订单状态为PAID（已付款），触发保单出单流程（调用保司接口）
3. 记录操作日志

**拒保（后端）**：
1. 更新 `insurance_order.order_status='REJECTED'`，`audit_status='REJECT'`
2. 若已付款，触发退款流程
3. 发送拒保通知给业务员和客户

---

### 2.4 订单改批

#### 2.4.1 功能说明

对已承保的订单，客户或业务员提出修改申请（如修改被保人信息、保额、险种等），需走改批流程。

#### 2.4.2 改批申请表单

**触发**：在订单列表点击【改批】→ 弹出改批申请弹窗

**表单字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 改批类型 | 下拉 | 是 | 被保人信息变更/保额调整/保期变更/其他 |
| 变更说明 | 文本域 | 是 | 描述具体变更内容 |
| 附件材料 | 文件上传 | 否 | 支持jpg/png/pdf，最大5个文件 |
| 联系方式 | 文本 | 是 | 客户联系电话 |

**后端处理**：
1. 创建 `insurance_order_change` 记录（status=PENDING）
2. 更新 `insurance_order.order_status='CHANGE_PENDING'`
3. 若涉及保费变更，需重新核算佣金：旧佣金标记REJECTED，新佣金重新进入待审核
4. 改批审批通过后，调用保司接口提交变更，保司确认后更新保单信息

#### 2.4.3 改批版本管理

每次改批审批通过后，将旧版本数据归档（`insurance_order_change_history`），保留完整变更链路。

---

### 2.5 订单退保

#### 2.5.1 退保申请流程

**触发**：在订单列表点击【退保】→ 弹出退保申请弹窗

**退保表单字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 退保原因 | 下拉 | 是 | 客户主动退保/理赔纠纷/产品不符/其他 |
| 退保说明 | 文本域 | 是 | 详细说明 |
| 退保生效日 | 日期 | 是 | 不能早于今天 |
| 附件 | 文件上传 | 否 | |

**后端处理**：
1. 创建 `insurance_order_cancel` 记录（status=PENDING）
2. 查询该订单对应的已审核/已发放佣金记录
3. 计算退保佣金回收金额（基于退保规则：如退保时间在承保后30天内全额回收，30-90天回收50%，90天后不回收）
4. 生成佣金回收记录（commission_record，commission_type=REFUND，金额为负数）
5. 若原佣金已发放（PAID），需从下月结算扣除；若尚未发放（APPROVED/PENDING），直接作废

**退保佣金回收规则配置**（可在基本法配置中设置）：
```json
{
  "cancel_rules": [
    {"days_within": 30,  "refund_rate": 1.0,  "description": "30天内退保全额回收"},
    {"days_within": 90,  "refund_rate": 0.5,  "description": "31-90天退保回收50%"},
    {"days_within": 365, "refund_rate": 0.25, "description": "91天-1年退保回收25%"},
    {"days_within": 9999, "refund_rate": 0,   "description": "1年以上不回收"}
  ]
}
```

---

## 三、保单管理模块

### 3.1 保单列表

#### 3.1.1 列表页

**入口**：佣金管理 → 保单管理 → 保单列表

**展示字段**：保单号、保险公司、险种、产品名称、被保人、保费、保单状态（有效/到期/退保/失效）、承保日期、到期日期、业务员、操作（详情/验真/变更/导出）

**搜索条件**：保单号（精确）、被保人姓名（模糊）、保险公司（下拉）、险种（下拉）、状态（下拉）、承保日期范围

---

### 3.2 保单录入（手动）

#### 3.2.1 功能说明

业务员在系统外与保司签订的保单，可通过此功能手动录入系统，以确保佣金计算完整。

#### 3.2.2 录入表单字段

**基本信息（第一步）**：

| 字段 | 类型 | 必填 | 校验 | 说明 |
|------|------|------|------|------|
| 险种 | 下拉 | 是 | | CAR/LIFE/HEALTH |
| 保险公司 | 下拉 | 是 | | 从已配置保司列表选 |
| 产品 | 联动下拉 | 是 | 根据险种+保司联动 | |
| 保单号 | 文本 | 是 | 同一保司下唯一，不允许重复录入 | |
| 承保日期 | 日期 | 是 | 不能晚于今天 | |
| 保险起期 | 日期 | 是 | | |
| 保险止期 | 日期 | 是 | 必须晚于起期 | |
| 保费（元） | 金额 | 是 | >0 | |
| 保额（元） | 金额 | 否 | >0 | |
| 缴费年期 | 数字 | 寿险必填 | 1-30 | |
| 业务员 | 员工选择器 | 是 | | |

**被保人信息（第二步）**：

| 字段 | 必填 | 校验 |
|------|------|------|
| 被保人姓名 | 是 | 不超过64字 |
| 证件类型 | 是 | 居民身份证/护照/其他 |
| 证件号码 | 是 | 身份证格式校验 |
| 手机号 | 否 | 11位手机号格式 |
| 出生日期 | 否 | |

**附件上传（第三步）**：
- 保单文件（PDF/图片，必传）
- 回执（可选）

**后端处理**：
1. 校验保单号在同一保司下唯一（联合唯一索引 `insurance_company + policy_no`）
2. 证件号码格式校验（18位身份证加权校验）
3. OCR辅助：若上传了保单PDF，可调用OCR服务自动识别字段（辅助填充，不强制）
4. 保存 `insurance_policy` 记录
5. 自动触发佣金计算（同批量计算流程）

---

### 3.3 保单验真

#### 3.3.1 功能说明

调用保司接口或第三方接口，验证保单真实性。

#### 3.3.2 验真操作

**触发**：在保单列表点击【验真】

**后端逻辑**：
1. 根据保单所属保险公司，查询对应的API配置（接口地址、认证方式）
2. 调用保司查询接口，传入保单号
3. 接口返回结果：
   - 匹配：更新 `insurance_policy.verify_status='VERIFIED'`，保存验证时间
   - 不匹配：更新 `verify_status='FAILED'`，记录保司返回的信息
   - 保司接口不可用：标记 `verify_status='TIMEOUT'`，提示"保司接口暂时不可用，请稍后重试"
4. 验证结果展示在保单详情页

---

### 3.4 保单变更（批改/加保）

#### 3.4.1 变更表单

**变更类型**：
- 批改：修改被保人信息、联系方式、地址等（不影响保费）
- 加保：增加保额或增加附加险（可能影响保费，需重新核保）

**表单字段**：

| 字段 | 必填 | 说明 |
|------|------|------|
| 变更类型 | 是 | 批改/加保 |
| 变更内容 | 是 | 具体变更字段（根据类型动态展示） |
| 变更原因 | 是 | |
| 附件 | 否 | |
| 生效日期 | 是 | |

**后端处理**：
1. 创建 `insurance_policy_change` 版本记录
2. 若加保导致保费增加：
   - 计算增额保费
   - 生成增额佣金记录（进入待审核）
3. 若批改无保费变化：仅更新保单信息，不影响佣金
4. 变更审批通过后，更新 `insurance_policy` 主记录并归档旧版本

---

### 3.5 保单导出

**功能**：选中一批保单（勾选），或按当前筛选条件导出全部，生成Excel。

**导出字段**（可由管理员配置导出哪些列）：保单号、保险公司、险种、被保人、保费、承保日期、到期日期、业务员、保单状态

**后端**：
1. 数据量 ≤ 2000条：同步生成，直接返回文件流下载
2. 数据量 > 2000条：异步生成，完成后推送站内消息通知下载

---

## 四、财务报表模块

### 4.1 收入报表

#### 4.1.1 功能说明

统计保费收入，按险种、保司、业务员、时间等维度分析。

#### 4.1.2 报表页面

**入口**：佣金管理 → 财务报表 → 收入报表

**筛选维度**：时间范围（月/季度/年）、险种（多选）、保险公司（多选）、业务员/部门

**图表展示**：
- 折线图：按月保费收入趋势
- 柱状图：各险种保费占比
- 饼图：各保司保费分布

**数据表格**：支持按险种/保司/业务员下钻，底部有汇总行

**接口**：`GET /commission/report/income`，参数：startPeriod、endPeriod、productCategory、insuranceCompany

**后端SQL示意**：
```sql
SELECT
  DATE_FORMAT(p.start_date, '%Y-%m') AS period,
  p.product_category,
  p.insurance_company,
  COUNT(p.id) AS policy_count,
  SUM(p.premium) AS total_premium
FROM insurance_policy p
WHERE p.deleted = 0
  AND p.policy_status = 'ACTIVE'
  AND p.start_date BETWEEN #{startDate} AND #{endDate}
  AND p.product_category IN (#{productCategories})
GROUP BY DATE_FORMAT(p.start_date, '%Y-%m'), p.product_category, p.insurance_company
ORDER BY period ASC
```

---

### 4.2 支出报表（佣金支出）

#### 4.2.1 功能说明

统计各周期佣金支出总额，按险种、职级、佣金类型分析成本构成。

#### 4.2.2 报表内容

**图表**：
- 柱状图：各月佣金支出（FYC/RYC/OVERRIDE/BONUS 堆叠柱）
- 折线图：佣金率（佣金/保费）趋势，监控是否有异常升高

**数据表格**：按结算周期展示，列包含：FYC金额、RYC金额、管理津贴金额、奖金金额、合计、总保费、综合佣金率

---

### 4.3 利润分析

#### 4.3.1 功能说明

= 保费收入 - 佣金支出 - 运营成本（手工录入），计算利润率。

#### 4.3.2 页面内容

**可手工录入的成本项**（按月维护）：
- 员工薪资
- 办公租金
- 系统服务费
- 市场推广费
- 其他成本

**图表**：
- 利润趋势折线图（按月）
- 成本结构饼图（各类成本占比）

---

### 4.4 佣金发放汇总

#### 4.4.1 功能说明

查看历史所有发放批次的汇总数据，支持多维度统计。

#### 4.4.2 报表内容

**展示维度**：按结算周期、按险种、按业务员、按发放渠道

**关键指标**：本月已发放总额、待发放总额、已驳回金额、各险种发放占比

**支持导出**Excel，包含每笔发放明细（业务员、发放金额、发放时间、对应保单）

---

## 五、通用开发规范

### 5.1 金额计算规范

- **强制使用 BigDecimal**，禁止 float/double
- 计算过程中间精度保留4位，最终入库保留2位
- 统一使用 `RoundingMode.HALF_UP`（四舍五入）
- 分摊计算时，尾差统一加到最后一项（避免总额不匹配）

```java
BigDecimal commission = premium.multiply(rate)
    .setScale(2, RoundingMode.HALF_UP);
```

### 5.2 并发控制规范

**佣金审核防重复（乐观锁）**：
```sql
UPDATE commission_record
SET status = 'APPROVED', auditor = #{auditor}, audit_time = NOW()
WHERE id = #{id} AND status = 'PENDING' AND deleted = 0
```
若 `updateCount = 0`，说明已被他人审核，返回错误："该记录已被审核，请刷新后重试"

**发放批次防重复执行（分布式锁）**：
```java
String lockKey = "commission:pay:batch:" + batchId;
boolean locked = redisTemplate.opsForValue()
    .setIfAbsent(lockKey, "1", 10, TimeUnit.MINUTES);
if (!locked) throw new ServiceException("该批次正在发放中，请勿重复操作");
try {
    executePayment(batchId);
} finally {
    redisTemplate.delete(lockKey);
}
```

### 5.3 异常码规范

```java
public interface CommissionErrorCodeConstants {
    // 基本法 (1-01-001 ~ 1-01-099)
    ErrorCode RANK_NOT_FOUND         = new ErrorCode(101001, "职级不存在");
    ErrorCode RANK_CODE_DUPLICATE    = new ErrorCode(101002, "职级代码已存在");
    ErrorCode RANK_HAS_AGENTS        = new ErrorCode(101003, "该职级下存在在职员工，无法删除");
    ErrorCode RULE_NOT_FOUND         = new ErrorCode(101010, "佣金规则不存在");
    ErrorCode RULE_CODE_DUPLICATE    = new ErrorCode(101011, "规则代码已存在");
    ErrorCode RATE_EXCEED_MAX        = new ErrorCode(101012, "佣金率超出监管上限");

    // 计算 (1-02-001 ~ 1-02-099)
    ErrorCode AGENT_NOT_FOUND        = new ErrorCode(102001, "业务员不存在");
    ErrorCode NO_APPLICABLE_RULE     = new ErrorCode(102002, "未找到适用的佣金规则");
    ErrorCode COMMISSION_CALC_ERROR  = new ErrorCode(102003, "佣金公式计算失败：{}");
    ErrorCode COMMISSION_DUPLICATE   = new ErrorCode(102004, "该保单已存在佣金记录");

    // 审核 (1-03-001 ~ 1-03-099)
    ErrorCode COMMISSION_NOT_PENDING = new ErrorCode(103001, "只有待审核状态的记录才能审核");
    ErrorCode COMMISSION_ALREADY_AUDITED = new ErrorCode(103002, "该记录已被审核");

    // 发放 (1-04-001 ~ 1-04-099)
    ErrorCode PAY_BATCH_STATUS_INVALID   = new ErrorCode(104001, "结算单状态不正确，无法执行该操作");
    ErrorCode PAY_BATCH_ALREADY_EXECUTING = new ErrorCode(104002, "发放正在执行中，请勿重复操作");
    ErrorCode PAY_ACCOUNT_NOT_BIND       = new ErrorCode(104003, "业务员未绑定收款账号");

    // 对账 (1-05-001 ~ 1-05-099)
    ErrorCode SETTLEMENT_FILE_PARSE_ERROR = new ErrorCode(105001, "结算单文件解析失败：{}");
    ErrorCode SETTLEMENT_PERIOD_DUPLICATE = new ErrorCode(105002, "该保司该周期的结算单已存在");
    ErrorCode SETTLEMENT_NOT_FOUND        = new ErrorCode(105003, "结算单不存在");
}
```

### 5.4 数据权限控制

| 角色 | 数据范围 |
|------|---------|
| 超级管理员 | 全部数据 |
| 财务管理员 | 全部佣金数据，可执行审核和发放 |
| 分公司管理员 | 本分公司下所有数据（按 tenant_id 或 org_id 过滤） |
| 团队负责人 | 本团队及下级团队的数据（递归查组织树） |
| 业务员 | 仅自己的佣金记录（B端APP查询，非PC端） |

**实现方式**：在Mapper查询中根据当前用户角色动态拼接 WHERE 条件（利用yudao框架的数据权限注解 `@DataPermission`）

### 5.5 接口权限注解规范

所有Controller接口必须添加权限注解：

```java
@PreAuthorize("@ss.hasPermission('commission:audit:approve')")
@PostMapping("/approve")
public CommonResult<Boolean> approve(...) { ... }
```

权限标识命名规则：`模块:功能:操作`

| 权限标识 | 说明 |
|---------|------|
| `commission:rank:create` | 创建职级 |
| `commission:rule:update` | 修改规则 |
| `commission:audit:approve` | 审核通过 |
| `commission:audit:reject` | 审核驳回 |
| `commission:pay:execute` | 执行发放 |
| `commission:settlement:import` | 导入结算单 |
| `commission:order:audit` | 订单风控审核 |

### 5.6 定时任务汇总

| 任务名称 | Cron表达式 | 说明 | 模块 |
|---------|-----------|------|------|
| 职级晋升评估 | `0 0 1 1 * ?` | 每月1日01:00评估晋升资格 | 基本法 |
| 晋升生效执行 | `0 0 2 1 * ?` | 每月1日02:00将审批通过晋升生效 | 基本法 |
| 保单佣金批量计算 | `0 0 3 * * ?` | 每日03:00处理前一日未计算保单 | 计算引擎 |
| RYC续期佣金计算 | `0 0 4 * * ?` | 每日04:00计算当月到期续期佣金 | 计算引擎 |
| 季度奖/年度奖计算 | `0 0 5 1 1,4,7,10 ?` | 每季度首月01:00计算奖金 | 计算引擎 |
| 生成月度发放批次 | `0 0 2 5 * ?` | 每月5日02:00自动生成发放批次 | 佣金结算 |
| 保司结算数据同步 | `0 0 3 6 * ?` | 每月6日03:00同步保司API数据 | 对账管理 |
| 发放失败重试 | `0 */5 * * * ?` | 每5分钟重试一次失败的发放 | 佣金结算 |

### 5.7 操作日志规范

以下操作必须写入系统操作日志（`sys_operate_log`）：

| 操作类型 | 操作模块 |
|---------|---------|
| 创建/修改/删除职级 | 基本法配置 |
| 创建/修改/停用佣金规则 | 基本法配置 |
| 佣金审核通过/驳回 | 佣金审核 |
| 批量审核 | 佣金审核 |
| 创建/提交/审批/执行发放批次 | 佣金发放 |
| 导入结算单 | 对账管理 |
| 处理对账差异 | 对账管理 |
| 订单风控审核 | 订单管理 |
| 保单手动录入 | 保单管理 |

使用yudao框架的 `@OperateLog` 注解实现自动记录。

---

## 六、工时估算汇总（全模块）

| 模块 | 功能点 | 前端工时（天） | 后端工时（天） | 合计（天） |
|------|--------|-------------|-------------|---------|
| **基本法配置** | 职级体系管理 | 1 | 1 | 2 |
| | 晋升规则配置 | 1.5 | 1.5 | 3 |
| | 佣金比例配置（FYC/RYC） | 1 | 1 | 2 |
| | 津贴配置（管理津贴/育成奖/伯乐奖） | 1.5 | 1.5 | 3 |
| | 奖励规则（季度奖/年度奖） | 1 | 1 | 2 |
| **佣金计算引擎** | 佣金规则库（Groovy公式+版本管理） | 0 | 2 | 2 |
| | 佣金试算页面 | 1 | 1.5 | 2.5 |
| | 批量佣金计算（含异步+进度） | 0 | 2 | 2 |
| | 分红险分期分摊 | 0 | 1.5 | 1.5 |
| **佣金结算** | 结算单生成 | 1 | 1 | 2 |
| | 结算审核 | 1 | 1 | 2 |
| | 佣金发放（含银行/支付宝/微信） | 1 | 1.5 | 2.5 |
| | 发放记录查询 | 0.5 | 0.5 | 1 |
| **对账管理** | 保司对账（Excel导入+自动匹配） | 1.5 | 2 | 3.5 |
| | 差异处理 | 1 | 1 | 2 |
| | 对账报表 | 1 | 1 | 2 |
| **订单管理** | 订单中心（列表+高级搜索） | 1.5 | 1 | 2.5 |
| | 订单详情 | 1 | 0.5 | 1.5 |
| | 订单风控审核 | 1.5 | 1.5 | 3 |
| | 订单改批 | 1 | 1 | 2 |
| | 订单退保 | 1 | 1 | 2 |
| **保单管理** | 保单列表 | 1 | 0.5 | 1.5 |
| | 保单手动录入 | 1.5 | 1 | 2.5 |
| | 保单验真 | 0.5 | 1 | 1.5 |
| | 保单变更 | 1 | 1 | 2 |
| | 保单导出 | 0.5 | 0.5 | 1 |
| **财务报表** | 收入报表 | 1.5 | 1 | 2.5 |
| | 支出报表 | 1.5 | 1 | 2.5 |
| | 利润分析 | 1.5 | 1 | 2.5 |
| | 佣金发放汇总 | 1 | 0.5 | 1.5 |
| **合计** | | **33** | **34.5** | **67.5天** |

---

> **【下篇完】**
> 
> 三篇文档合计覆盖「阶段2-PC管理后台-佣金系统」sheet中全部功能点，请结合上、中、下三篇阅读开发。
> 如有疑问请联系产品负责人。

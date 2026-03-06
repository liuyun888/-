# 阶段2-PC佣金系统详细需求文档【补充篇B】
## 薪酬管理模块 + 非车系统设置模块

> 版本：V4.0 | 日期：2026-02-26 | 技术栈：yudao-cloud（微服务版）+ MySQL 8.0 + Redis  
> 配置：1前端 + 1后端  
> 说明：本文档为原三篇文档（上/中/下篇）的补充，覆盖排期表中遗漏的功能点  
> 对应排期表：阶段2-PC管理后台-佣金系统 Sheet

---

## 一、模块总览

| 模块 | 功能点 | 对应PDF编号 | 工时（前+后） |
|------|--------|------------|---------------|
| 薪酬管理 | 佣金查询（业务员维度） | **PDF-220**（佣金查询） | 2+1.5 = 3.5天 |
| 薪酬管理 | 工资查询（月度汇总） | **PDF-221**（工资查询） | 1+1 = 2天 |
| 薪酬管理 | 加扣款导入 | **PDF-219**（加扣款导入） | 1+1 = 2天 |
| 非车系统设置 | 非车导入模板设置 | **PDF-105**（模板设置） | 1+1 = 2天 |
| 非车系统设置 | 非车保单字段自定义设置 | **PDF-106**（保单设置） | 1+1 = 2天 |

---

## 二、薪酬管理模块

> **菜单路径**：佣金管理 → 薪酬管理

### 2.1 佣金查询（业务员维度）
> 对应PDF：**PDF-220（佣金查询）**

#### 2.1.1 功能说明

以业务员为核心维度，查询其名下所有已生成的佣金明细记录。支持多条件筛选、明细下钻、汇总统计，以及大数据量Excel导出（最大50000条）。

本功能服务于：
- **财务人员**：核查某业务员某时段佣金是否正确计算
- **团队负责人**：查看下属业务员的业绩与佣金概况
- **业务员本人**（通过B端App查询，非本页面）：仅供参考，App端另有专属入口

#### 2.1.2 查询列表页

**入口**：佣金管理 → 薪酬管理 → 佣金查询

**搜索条件（基础搜索）**：

| 字段 | 类型 | 说明 |
|------|------|------|
| 业务员姓名/工号 | 文本模糊搜索 | |
| 结算周期 | 年月选择（范围） | 开始月 ~ 结束月 |
| 险种 | 下拉多选 | 全部/车险/非车/寿险 |
| 结算状态 | 下拉多选 | PENDING/APPROVED/PAID/REJECTED |

**高级搜索（展开区域）**：

| 字段 | 类型 | 说明 |
|------|------|------|
| 佣金类型 | 多选 | FYC/RYC/OVERRIDE/BONUS/REFUND |
| 保险公司 | 下拉多选 | |
| 保单号 | 文本精确 | |
| 所属部门 | 组织树选择 | 支持下钻到子部门 |
| 佣金金额范围 | 数值输入（最低-最高） | 单位：元 |
| 发放时间范围 | 日期范围 | |

**列表展示字段**：

| 列名 | 字段 | 说明 |
|------|------|------|
| 佣金单号 | commission_no | |
| 业务员工号 | agent_code | |
| 业务员姓名 | agent_name | |
| 所属部门 | dept_name | |
| 职级 | agent_rank | 计算时职级快照 |
| 保单号 | policy_no | |
| 险种 | product_category | |
| 保险公司 | insurance_company | |
| 保费（元） | premium | 数值，千分位格式 |
| 佣金类型 | commission_type | FYC/RYC/OVERRIDE/BONUS/REFUND |
| 佣金率（%） | commission_rate | 百分比 |
| 佣金金额（元） | commission_amount | |
| 结算周期 | settle_period | YYYY-MM格式展示 |
| 结算状态 | status | 状态标签（颜色区分） |
| 发放时间 | pay_time | |
| 发放渠道 | pay_channel | BANK/ALIPAY/WECHAT |
| 操作 | - | 查看详情 |

**底部汇总行（本页合计 + 全量合计）**：

| 汇总项 | 说明 |
|--------|------|
| 本页总佣金金额 | SUM(当前页所有记录的commission_amount) |
| 全量总佣金金额 | SUM(所有筛选结果的commission_amount，不分页) |
| 本页记录数 | |
| 全量记录数 | |

> **技术说明**：全量合计通过单独的聚合接口 `GET /commission/salary/query/summary` 返回，避免全量加载数据到前端。

#### 2.1.3 佣金详情页（点击查看）

点击【查看详情】，展示该佣金记录的完整信息：
- 基本信息：佣金单号、类型、金额、状态、结算周期
- 计算信息：适用规则代码、计算公式展示（`calc_formula` 字段）、是否合规截断
- 保单信息：保单号、险种、保费、保险公司、承保日期
- 审核记录：审核人、审核时间、审核意见（若已审核）
- 发放记录：发放批次号、发放时间、发放渠道（若已发放）
- 分润关系：若为OVERRIDE类型，展示关联的源佣金信息（哪位下级的佣金触发的分润）

#### 2.1.4 Excel导出

**触发**：点击【导出】按钮

**导出逻辑**：
- ≤5000条：同步生成，直接返回文件流
- 5000~50000条：异步生成，提交后显示任务进度，完成后推送站内消息通知下载
- >50000条：弹出提示「当前筛选结果超出50000条，请缩小查询范围后重试」，拒绝导出

**导出字段**：与列表字段一致，增加「计算公式」和「审核人」两列

**实现要点**：
- 使用 **EasyExcel** 流式写入，避免大数据量OOM
- 异步导出任务存入Redis（`commission:export:task:{taskId}`），前端轮询进度
- 导出文件上传到OSS，生成有效期2小时的临时下载链接

#### 2.1.5 后端接口规范

```
GET /commission/salary/query/list
  参数：agentName, agentCode, startPeriod, endPeriod, productCategory[], 
        commissionType[], status[], policyNo, deptId, amountMin, amountMax,
        pageNo, pageSize, sortField, sortOrder
  响应：分页列表

GET /commission/salary/query/summary
  参数：（同list，无分页参数）
  响应：{ totalAmount, totalCount }

POST /commission/salary/query/export
  参数：（同list，无分页参数）
  响应：{ taskId } 或文件流
```

---

### 2.2 工资查询（月度汇总）
> 对应PDF：**PDF-221（工资查询）**

#### 2.2.1 功能说明

按月、按人展示业务员的完整薪资构成明细，数据来源于 `commission_record`（佣金类型：FYC/RYC/OVERRIDE/BONUS）与 `comm_salary_adjustment`（加扣款）的聚合汇总。

#### 2.2.2 工资查询页面

**入口**：佣金管理 → 薪酬管理 → 工资查询

**搜索条件**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 查询月份 | 年月选择 | 是 | 默认上月 |
| 业务员姓名/工号 | 文本模糊 | 否 | 空=查全部 |
| 所属部门 | 组织树选择 | 否 | |

**列表展示字段（每人一行）**：

| 列名 | 说明 |
|------|------|
| 工号 | |
| 姓名 | |
| 所属部门 | |
| 职级 | |
| FYC（首年佣金） | 本月所有FYC类型commission_record合计 |
| RYC（续期佣金） | 本月所有RYC合计 |
| 管理津贴（OVERRIDE） | 本月所有OVERRIDE合计 |
| 奖励（BONUS） | 本月所有BONUS合计 |
| 佣金回收（REFUND） | 本月退保回收金额（负数，红色显示） |
| 加款小计 | comm_salary_adjustment中type=ADD的合计 |
| 扣款小计 | comm_salary_adjustment中type=DEDUCT的合计（红色显示） |
| 税前合计 | FYC + RYC + OVERRIDE + BONUS + REFUND + 加款 - 扣款 |
| 代扣个税 | 按个税公式预估（见2.2.3） |
| 税后实发 | 税前合计 - 代扣个税 |
| 操作 | 查看明细 / 下载工资条 |

**点击【查看明细】**：展开或跳转到明细弹窗，列出该员工该月的所有佣金记录（按commission_type分组展示）和加扣款记录。

#### 2.2.3 个税预扣计算逻辑（后端）

> **说明**：个税预扣采用按月累加预扣法（参照个人所得税预扣预缴办法），实际以专职财务最终申报为准。系统仅作**预估显示**，不作为正式纳税依据。

```java
/**
 * 简化版个税预扣计算（月度）
 * 基础减除费用：5000元/月（2024年标准）
 * 月应纳税所得额 = 税前合计 - 5000（基础减除）- 专项扣除（社保/公积金，按实际配置）
 * 查累进税率表取税率和速扣数
 */
BigDecimal taxableIncome = grossAmount.subtract(BASIC_DEDUCTION).subtract(specialDeduction);
if (taxableIncome.compareTo(BigDecimal.ZERO) <= 0) return BigDecimal.ZERO;
// 查税率区间
TaxBracket bracket = getTaxBracket(taxableIncome);
BigDecimal tax = taxableIncome.multiply(bracket.getRate())
    .subtract(bracket.getQuickDeduction())
    .setScale(2, RoundingMode.HALF_UP);
return tax.max(BigDecimal.ZERO);
```

**月度税率表**（2024年）：

| 月应纳税所得额（元） | 税率 | 速算扣除数（元） |
|-------------------|------|----------------|
| 0 ~ 3,000 | 3% | 0 |
| 3,000 ~ 12,000 | 10% | 210 |
| 12,000 ~ 25,000 | 20% | 1,410 |
| 25,000 ~ 35,000 | 25% | 2,660 |
| 35,000 ~ 55,000 | 30% | 4,410 |
| 55,000 ~ 80,000 | 35% | 7,160 |
| 80,000以上 | 45% | 15,160 |

#### 2.2.4 批量下载工资条

**触发**：列表页点击【批量下载工资条】→ 选择下载格式（单文件多Sheet / 多个独立文件zip包）

**工资条Excel格式**（单员工一页）：
```
公司名称：XXX保险经纪有限公司
工资条 - 2026年02月

姓名：张三       工号：A001       部门：北京分公司-直销一组

┌─────────────────────────────────────────────┐
│ 收入项目                    金额（元）        │
├─────────────────┬───────────────────────────┤
│ FYC首年佣金     │                  5,200.00 │
│ RYC续期佣金     │                    350.00 │
│ 管理津贴        │                    780.00 │
│ 奖励            │                  1,000.00 │
│ 绩效加款        │                    500.00 │
├─────────────────┼───────────────────────────┤
│ 扣款项目                                      │
├─────────────────┬───────────────────────────┤
│ 佣金回收（退保）│                   -200.00 │
│ 考勤扣款        │                   -100.00 │
├─────────────────┼───────────────────────────┤
│ 税前合计        │                  7,530.00 │
│ 代扣个税（预估）│                   -303.00 │
│ 税后实发        │                  7,227.00 │
└─────────────────┴───────────────────────────┘

注：个税为系统预估值，仅供参考，实际以税务申报为准。
```

#### 2.2.5 数据库设计（聚合来源）

工资查询不引入新表，通过SQL聚合以下已有表：

```sql
-- 工资查询聚合SQL（示意）
SELECT
  u.id AS agent_id,
  u.name AS agent_name,
  u.user_code AS agent_code,
  d.name AS dept_name,
  COALESCE(SUM(CASE WHEN cr.commission_type='FYC' THEN cr.commission_amount ELSE 0 END), 0) AS fyc_total,
  COALESCE(SUM(CASE WHEN cr.commission_type='RYC' THEN cr.commission_amount ELSE 0 END), 0) AS ryc_total,
  COALESCE(SUM(CASE WHEN cr.commission_type='OVERRIDE' THEN cr.commission_amount ELSE 0 END), 0) AS override_total,
  COALESCE(SUM(CASE WHEN cr.commission_type='BONUS' THEN cr.commission_amount ELSE 0 END), 0) AS bonus_total,
  COALESCE(SUM(CASE WHEN cr.commission_type='REFUND' THEN cr.commission_amount ELSE 0 END), 0) AS refund_total,
  COALESCE(sa_add.add_total, 0) AS add_total,
  COALESCE(sa_deduct.deduct_total, 0) AS deduct_total
FROM sys_user u
LEFT JOIN sys_dept d ON u.dept_id = d.id
LEFT JOIN commission_record cr ON cr.agent_id = u.id
  AND cr.settle_period = #{settlePeriod}
  AND cr.deleted = 0
  AND cr.status IN ('APPROVED', 'PAID')   -- 已审核和已发放才纳入工资
LEFT JOIN (
  SELECT agent_id, SUM(amount) AS add_total
  FROM comm_salary_adjustment
  WHERE salary_month = #{settlePeriod} AND adjust_type = 'ADD' AND deleted = 0
  GROUP BY agent_id
) sa_add ON sa_add.agent_id = u.id
LEFT JOIN (
  SELECT agent_id, SUM(amount) AS deduct_total
  FROM comm_salary_adjustment
  WHERE salary_month = #{settlePeriod} AND adjust_type = 'DEDUCT' AND deleted = 0
  GROUP BY agent_id
) sa_deduct ON sa_deduct.agent_id = u.id
WHERE u.deleted = 0
  AND u.status = 1
  AND (#{deptId} IS NULL OR u.dept_id IN (SELECT id FROM sys_dept WHERE path LIKE CONCAT((SELECT path FROM sys_dept WHERE id=#{deptId}), '%')))
GROUP BY u.id, u.name, u.user_code, d.name
HAVING (fyc_total + ryc_total + override_total + bonus_total + refund_total + add_total + deduct_total) != 0
```

---

### 2.3 加扣款导入
> 对应PDF：**PDF-219（加扣款导入）**

#### 2.3.1 功能说明

运营/财务人员通过Excel批量导入业务员的加扣款数据，包括考勤扣款、绩效奖励、垫付回收等项目，这些数据将影响当月工资结算中的「加款」和「扣款」汇总。

#### 2.3.2 加扣款导入页面

**入口**：佣金管理 → 薪酬管理 → 加扣款管理

**页面布局**：
- 顶部：操作区（下载模板、上传文件按钮）
- 中间：历史导入批次列表
- 底部：导入后的加扣款明细列表（按月份筛选）

**操作步骤**：
1. 点击【下载模板】，获取标准Excel模板
2. 按模板填写数据后，点击【上传导入文件】
3. 系统预解析（前5行预览 + 总行数展示）
4. 确认后点击【确认导入】

#### 2.3.3 Excel导入模板字段

| 列序 | 列名 | 必填 | 格式要求 | 说明 |
|------|------|------|----------|------|
| A | 员工工号 | 是 | 文本，系统内有效工号 | 工号不存在则该行报错 |
| B | 员工姓名 | 是 | 文本 | 用于核对，不作为匹配依据 |
| C | 工资月份 | 是 | YYYY-MM格式 | 如：2026-02 |
| D | 类型 | 是 | 枚举值：加款/扣款 | 不在此枚举内报错 |
| E | 金额（元） | 是 | 正数，保留2位小数 | 必须>0，类型决定正负 |
| F | 项目类型 | 是 | 文本（见下方字典） | 考勤扣款/绩效奖励/垫付回收/其他 |
| G | 原因/备注 | 是 | 文本，不超过200字 | 说明加扣款原因 |

**项目类型字典**（可在系统中扩展配置）：
- 考勤扣款（ATTENDANCE）
- 绩效奖励（PERFORMANCE）
- 垫付回收（ADVANCE_RECOVERY）
- 行政罚款（ADMIN_PENALTY）
- 其他加款（OTHER_ADD）
- 其他扣款（OTHER_DEDUCT）

#### 2.3.4 后端导入逻辑

```
1. EasyExcel 流式读取文件（支持.xlsx/.xls，最大5000行/次）
2. 逐行校验：
   a. 工号是否存在（sys_user表，status=1）
   b. 工资月份格式是否正确（YYYY-MM，且不能是未来月份）
   c. 类型是否在枚举内（加款/扣款）
   d. 金额是否>0
   e. 原因是否填写
3. 格式错误的行：记录行号和原因，不中止整体导入，继续处理后续行
4. 通过校验的行：批量 INSERT comm_salary_adjustment
   - adjust_type = （加款→ADD，扣款→DEDUCT）
   - amount 始终存正数，类型字段区分加减
5. 创建导入批次记录（comm_salary_adjustment_batch），记录导入人、时间、成功数、失败数
6. 返回导入结果摘要，失败行可下载明细Excel
```

**幂等控制**：同一工号+月份+类型+金额+项目类型组合重复导入时，提示「检测到重复数据，是否覆盖？」，需用户确认。

#### 2.3.5 加扣款历史查询

**入口**：页面底部的「加扣款明细」区域

**筛选条件**：员工姓名/工号、工资月份、类型（加款/扣款）、项目类型、导入批次

**展示字段**：工号、姓名、工资月份、类型、金额、项目类型、原因、导入批次号、导入时间、操作（撤销）

**撤销操作**：  
点击【撤销】→ 弹出确认框「确认撤销该加扣款记录？撤销后将影响当月工资重新计算。」  
后端：逻辑删除该记录（`deleted=1`），写入操作日志

#### 2.3.6 数据库表

```sql
-- 加扣款批次表
CREATE TABLE `comm_salary_adjustment_batch` (
  `id`          bigint(20)    NOT NULL AUTO_INCREMENT,
  `batch_no`    varchar(64)   NOT NULL COMMENT '导入批次号',
  `file_url`    varchar(255)  NOT NULL COMMENT '原始文件OSS地址',
  `total_count` int(11)       NOT NULL DEFAULT 0,
  `success_count` int(11)     NOT NULL DEFAULT 0,
  `fail_count`  int(11)       NOT NULL DEFAULT 0,
  `salary_month` varchar(16)  NOT NULL COMMENT '影响的工资月份（YYYY-MM）',
  `operator`    varchar(64)   NOT NULL COMMENT '操作人',
  `remark`      varchar(500)  DEFAULT NULL,
  `creator`     varchar(64)   DEFAULT NULL,
  `create_time` datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted`     tinyint(1)    DEFAULT 0,
  `tenant_id`   bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='加扣款导入批次表';

-- 加扣款明细表
CREATE TABLE `comm_salary_adjustment` (
  `id`            bigint(20)    NOT NULL AUTO_INCREMENT,
  `batch_id`      bigint(20)    NOT NULL COMMENT '关联批次ID',
  `agent_id`      bigint(20)    NOT NULL COMMENT '员工ID',
  `agent_code`    varchar(64)   NOT NULL COMMENT '工号',
  `agent_name`    varchar(64)   NOT NULL COMMENT '姓名（导入时快照）',
  `salary_month`  varchar(16)   NOT NULL COMMENT '工资月份（YYYY-MM）',
  `adjust_type`   varchar(16)   NOT NULL COMMENT 'ADD（加款）/DEDUCT（扣款）',
  `item_type`     varchar(32)   NOT NULL COMMENT '项目类型',
  `amount`        decimal(12,2) NOT NULL COMMENT '金额（正数，类型决定加减）',
  `reason`        varchar(200)  NOT NULL COMMENT '原因说明',
  `revoke_remark` varchar(200)  DEFAULT NULL COMMENT '撤销原因',
  `creator`       varchar(64)   DEFAULT NULL,
  `create_time`   datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`       varchar(64)   DEFAULT NULL,
  `update_time`   datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`       tinyint(1)    DEFAULT 0 COMMENT '逻辑删除=撤销',
  `tenant_id`     bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_agent_month` (`agent_id`, `salary_month`),
  KEY `idx_batch_id` (`batch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='加扣款明细表';
```

---

## 三、非车系统设置模块

> **菜单路径**：佣金管理 → 非车管理 → 系统设置  
> 或：系统管理 → 非车系统设置

### 3.1 非车导入模板设置
> 对应PDF：**PDF-105（非车系统设置-模板设置）**

#### 3.1.1 功能说明

不同保司、不同险种的非车险保单Excel导出格式各异，字段名称和列位置不统一。本功能允许管理员为每种保单来源配置「列名→系统字段」的映射关系，使导入功能能正确解析各保司Excel数据，无需修改代码。

#### 3.1.2 模板列表页

**入口**：系统设置 → 非车系统设置 → 模板设置

**展示字段**：

| 列名 | 说明 |
|------|------|
| 模板名称 | 如：平安非车险导入模板_2026 |
| 适用险种 | 非车险/健康险/意外险/全部 |
| 适用保司 | 关联保险公司（NULL=通用） |
| 字段映射数量 | 配置了多少个列映射 |
| 版本号 | 如：V1.0、V2.0 |
| 状态 | 启用/停用 |
| 创建时间 | |
| 操作 | 编辑 / 复制 / 停用 / 下载空表 |

**操作按钮**：
- 【新增模板】→ 弹出配置弹窗
- 【下载空模板Excel】→ 下载该模板的空白Excel文件（含表头行，方便保司按格式填写）

#### 3.1.3 新增/编辑模板弹窗

**基础信息区（上半部分）**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 模板名称 | 文本 | 是 | 不超过64字 |
| 适用险种 | 下拉（多选） | 是 | |
| 适用保司 | 下拉（可选） | 否 | 空=通用模板 |
| 版本号 | 文本 | 是 | 格式建议V1.0 |
| Excel起始数据行号 | 数字 | 是 | 默认2（第1行为表头，第2行起为数据） |
| 备注 | 文本域 | 否 | |

**字段映射配置区（下半部分，可增删行）**：

| 列名 | 类型 | 必填 | 说明 |
|------|------|------|------|
| Excel列标题名 | 文本 | 是 | 如：「保单号码」、「被保险人」 |
| 对应系统字段 | 下拉（从字段字典选） | 是 | 如：policy_no、insured_name |
| 是否必填 | 单选 | 是 | 该列数据在导入时是否必须有值 |
| 数据格式 | 下拉 | 是 | 文本/数值/日期（YYYY-MM-DD）/金额（保留2位） |
| 默认值 | 文本 | 否 | 若该列在Excel中为空时的默认填充值 |
| 说明 | 文本 | 否 | 对该字段的补充说明 |

**系统字段字典**（预置的可映射字段，覆盖保单录入的所有标准字段）：

| 字段代码 | 字段名 | 类型 |
|---------|--------|------|
| policy_no | 保单号 | 文本 |
| insurance_company | 保险公司 | 文本 |
| insured_name | 被保人姓名 | 文本 |
| insured_id_no | 被保人证件号 | 文本 |
| insured_mobile | 被保人手机 | 文本 |
| premium | 保费（元） | 金额 |
| sum_insured | 保额（元） | 金额 |
| start_date | 保险起期 | 日期 |
| end_date | 保险止期 | 日期 |
| policy_date | 承保日期 | 日期 |
| product_name | 产品名称 | 文本 |
| agent_code | 业务员工号 | 文本 |
| channel | 销售渠道 | 文本 |
| ... | （可自定义扩展） | |

**后端处理**：
1. 校验：同一保司+险种不允许存在两个状态为启用的同名模板
2. 字段映射列表序列化为JSON存入 `non_motor_import_template.column_mapping`：
   ```json
   {
     "start_row": 2,
     "columns": [
       {"excel_header": "保单号码", "field_code": "policy_no", "required": true, "data_type": "TEXT", "default_value": null},
       {"excel_header": "保费", "field_code": "premium", "required": true, "data_type": "AMOUNT", "default_value": null},
       {"excel_header": "起保日期", "field_code": "start_date", "required": true, "data_type": "DATE", "default_value": null}
     ]
   }
   ```
3. 新增时生成版本号（若不填，系统自动按 V1.0、V2.0 递增）
4. 版本记录不可物理删除，只能停用

#### 3.1.4 模板与保单导入联动

在非车险保单导入功能（PDF-088）中，操作步骤如下：
1. 选择导入模板（从已启用的模板中选，下拉显示：模板名称 + 适用险种 + 版本）
2. 上传Excel文件
3. 系统按模板 `column_mapping` 解析Excel列
4. 若Excel表头与模板配置的 `excel_header` 不匹配，则提示「列名不匹配，请检查是否选择了正确的模板」

#### 3.1.5 数据库表

```sql
-- 非车险导入模板表
CREATE TABLE `non_motor_import_template` (
  `id`               bigint(20)    NOT NULL AUTO_INCREMENT,
  `template_name`    varchar(64)   NOT NULL COMMENT '模板名称',
  `product_category` varchar(64)   NOT NULL COMMENT '适用险种（JSON数组或ALL）',
  `insurance_company` varchar(128) DEFAULT NULL COMMENT '适用保司（NULL=通用）',
  `version`          varchar(16)   NOT NULL DEFAULT 'V1.0' COMMENT '版本号',
  `start_row`        int(11)       NOT NULL DEFAULT 2 COMMENT 'Excel数据起始行',
  `column_mapping`   json          NOT NULL COMMENT '列映射配置JSON',
  `status`           tinyint(1)    DEFAULT 1 COMMENT '1启用 0停用',
  `remark`           varchar(500)  DEFAULT NULL,
  `creator`          varchar(64)   DEFAULT NULL,
  `create_time`      datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          varchar(64)   DEFAULT NULL,
  `update_time`      datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          tinyint(1)    DEFAULT 0,
  `tenant_id`        bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_product_company` (`product_category`(32), `insurance_company`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='非车险保单导入模板表';
```

---

### 3.2 非车保单字段自定义设置
> 对应PDF：**PDF-106（非车系统设置-保单设置）**

#### 3.2.1 功能说明

非车险产品种类繁多（健康险、责任险、企财险、农险等），各险种需要记录的保单信息字段各不相同。本功能允许管理员为各险种自定义保单的录入表单字段和列表展示字段，无需开发人员介入即可灵活扩展字段。

**核心约束**：
- 系统预置的**标准字段**（保单号、保险公司、保费等）不可删除，可调整显示顺序和是否必填
- 自定义字段可随时新增/停用
- 字段配置变更对**存量保单数据无影响**（新字段在旧保单中显示为空）

#### 3.2.2 险种字段配置列表页

**入口**：系统设置 → 非车系统设置 → 保单设置

**页面布局**：左侧险种选择树，右侧展示当前险种的字段配置列表

**左侧险种树**：健康险 / 责任险 / 企财险 / 工程险 / 农险 / 货运险 / 意外险 / 通用（其他非车）

**右侧字段列表展示**：

| 列名 | 说明 |
|------|------|
| 字段名称 | 如：被保险财产地址 |
| 字段代码 | 如：insured_property_address（系统内部标识） |
| 字段类型 | 文本/数字/金额/日期/下拉选择/多行文本 |
| 是否必填 | 是/否 |
| 列表显示 | 是否在保单列表的列中展示 |
| 排序 | 在录入表单和列表中的显示顺序 |
| 字段来源 | 系统预置 / 自定义 |
| 状态 | 启用/停用 |
| 操作 | 编辑 / 停用（自定义字段专有） |

**操作按钮**：
- 【新增自定义字段】→ 弹出新增弹窗
- 【调整排序】→ 进入拖拽排序模式
- 【同步到其他险种】→ 将当前配置应用到选定的其他险种（跨险种复用）

#### 3.2.3 新增/编辑自定义字段弹窗

| 字段 | 类型 | 必填 | 校验 | 说明 |
|------|------|------|------|------|
| 字段名称（中文） | 文本 | 是 | 不超过64字 | 展示给用户的字段标签 |
| 字段代码（英文） | 文本 | 是 | 仅小写字母、数字、下划线；同险种下唯一；不可与标准字段代码重复 | 系统内部标识，创建后不可修改 |
| 字段类型 | 下拉 | 是 | | 文本/数字/金额/日期/下拉选择/多行文本 |
| 下拉选项值 | 动态展示（类型=下拉时） | 是 | 至少1个选项 | 格式：选项1 , 选项2 , 选项3（逗号分隔） |
| 占位提示文字 | 文本 | 否 | | 录入框的placeholder提示 |
| 是否必填 | 单选 | 是 | 默认否 | |
| 是否在列表展示 | 单选 | 是 | 默认否 | 影响保单列表列是否展示该字段 |
| 排序号 | 数字 | 否 | 正整数 | 在表单中的显示位置 |
| 字段说明/帮助文字 | 文本域 | 否 | | 在录入页悬浮提示 |

**字段类型对应的展示控件**：

| 字段类型 | 录入控件 | 列表展示 |
|---------|---------|---------|
| 文本（TEXT） | 单行输入框 | 文字，超长省略号 |
| 多行文本（TEXTAREA） | 多行文本域 | 文字截断+展开 |
| 数字（NUMBER） | 数字输入框 | 数字 |
| 金额（AMOUNT） | 金额输入框（千分位格式） | ¥1,234.56 |
| 日期（DATE） | 日期选择器 | YYYY-MM-DD |
| 下拉选择（SELECT） | 下拉框（单选） | 选项文字 |

**后端处理**：
1. 校验字段代码唯一性（同一险种下）
2. 写入 `non_motor_field_config` 表
3. 不修改已有保单数据（存量数据安全）

#### 3.2.4 自定义字段数据存储方案

自定义字段的数据采用 **JSON扩展字段** 方式存储，不为每个自定义字段单独建列：

```sql
-- 非车险保单表中扩展字段
-- insurance_non_motor_policy 表中增加：
-- `extra_fields` json DEFAULT NULL COMMENT '自定义字段数据（key=字段代码, value=字段值）'
```

存储示例：
```json
{
  "insured_property_address": "北京市朝阳区XXX大厦",
  "construction_period": "2026-01-01至2026-12-31",
  "project_value": 5000000
}
```

前端渲染逻辑：
1. 进入录入页时，先调接口获取当前险种的字段配置列表（按排序号排列）
2. 根据字段类型动态渲染控件
3. 提交时，将所有自定义字段值打包为 `extra_fields` JSON随保单一起提交

#### 3.2.5 数据库表

```sql
-- 非车险保单字段配置表
CREATE TABLE `non_motor_field_config` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT,
  `product_category` varchar(64)  NOT NULL COMMENT '险种分类（健康险/责任险/企财险等）',
  `field_code`      varchar(64)   NOT NULL COMMENT '字段代码（小写+下划线，唯一）',
  `field_name`      varchar(64)   NOT NULL COMMENT '字段中文名',
  `field_type`      varchar(32)   NOT NULL COMMENT 'TEXT/NUMBER/AMOUNT/DATE/SELECT/TEXTAREA',
  `select_options`  varchar(1000) DEFAULT NULL COMMENT '下拉选项（逗号分隔，SELECT类型才有）',
  `placeholder`     varchar(255)  DEFAULT NULL COMMENT '占位提示文字',
  `help_text`       varchar(500)  DEFAULT NULL COMMENT '帮助说明',
  `is_required`     tinyint(1)    DEFAULT 0 COMMENT '是否必填（0否 1是）',
  `is_list_column`  tinyint(1)    DEFAULT 0 COMMENT '是否列表展示（0否 1是）',
  `sort`            int(11)       DEFAULT 0 COMMENT '排序号',
  `field_source`    varchar(16)   DEFAULT 'CUSTOM' COMMENT 'PRESET（系统预置）/CUSTOM（自定义）',
  `status`          tinyint(1)    DEFAULT 1 COMMENT '1启用 0停用',
  `creator`         varchar(64)   DEFAULT NULL,
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         varchar(64)   DEFAULT NULL,
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         tinyint(1)    DEFAULT 0,
  `tenant_id`       bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_category_code` (`product_category`, `field_code`),
  KEY `idx_product_category` (`product_category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='非车险保单字段自定义配置表';
```

---

## 四、接口权限标识（新增）

| 权限标识 | 说明 |
|---------|------|
| `commission:salary:query` | 佣金查询（业务员维度） |
| `commission:salary:export` | 佣金查询导出 |
| `commission:salary:wage:query` | 工资查询 |
| `commission:salary:wage:export` | 工资条下载 |
| `commission:salary:adjustment:import` | 加扣款导入 |
| `commission:salary:adjustment:revoke` | 撤销加扣款 |
| `non-motor:template:create` | 新增导入模板 |
| `non-motor:template:update` | 修改导入模板 |
| `non-motor:field:create` | 新增自定义字段 |
| `non-motor:field:update` | 修改自定义字段 |

---

## 五、操作日志补充

以下操作需写入 `sys_operate_log`：

| 操作类型 | 操作模块 |
|---------|---------|
| 加扣款批量导入 | 薪酬管理 |
| 单条加扣款撤销 | 薪酬管理 |
| 工资条批量导出 | 薪酬管理 |
| 新增/修改非车导入模板 | 非车系统设置 |
| 停用非车导入模板 | 非车系统设置 |
| 新增/修改自定义字段 | 非车系统设置 |
| 停用自定义字段 | 非车系统设置 |

---

> **【补充篇B完】**  
>  
> **文档结构说明**（完整需求文档由以下5个文件组成）：
>
> | 文件 | 内容 |
> |------|------|
> | 上篇 | 基本法配置 + 佣金计算引擎 |
> | 中篇 | 佣金结算 + 对账管理 |
> | 下篇 | 订单管理 + 保单管理 + 财务报表 + 通用规范 |
> | **补充篇A（本配套文档）** | 车险政策管理（留点/加投点/赋值/禁保名单）+ 多级结算 |
> | **补充篇B（本文档）** | 薪酬管理（佣金查询/工资查询/加扣款导入）+ 非车系统设置 |
>
> 五篇合计覆盖排期表「阶段2-PC管理后台-佣金系统」Sheet中所有53行功能点（前端40天 + 后端45.5天 = 合计85.5天）。

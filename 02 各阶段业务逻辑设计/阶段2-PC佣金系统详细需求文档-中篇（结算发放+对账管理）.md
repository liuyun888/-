# 阶段2-PC佣金系统详细需求文档【中篇】
## 佣金结算模块 + 对账管理模块

> 版本：V3.0 | 日期：2026-02-18 | 技术栈：yudao-cloud（微服务版）+ MySQL 8.0 + Redis  
> 配置：1前端 + 1后端

---

## 一、模块总览

| 模块 | 功能点 | 工时（前+后） |
|------|--------|---------------|
| 佣金结算 | 结算单生成 | 1+1 = 2天 |
| 佣金结算 | 结算审核 | 1+1 = 2天 |
| 佣金结算 | 佣金发放 | 1+1.5 = 2.5天 |
| 佣金结算 | 发放记录查询 | 0.5+0.5 = 1天 |
| 对账管理 | 保司对账（Excel导入+自动匹配） | 1.5+2 = 3.5天 |
| 对账管理 | 差异处理 | 1+1 = 2天 |
| 对账管理 | 对账报表 | 1+1 = 2天 |

---

## 二、佣金结算模块

### 2.1 结算单生成

#### 2.1.1 功能说明

每月月底或指定时间，财务人员可对某结算周期（年月）的所有已审核佣金进行汇总，生成一份正式的"结算单"，作为批量发放的依据。

#### 2.1.2 结算单列表页

**入口**：佣金管理 → 佣金结算 → 结算单管理

**展示字段**：结算单号、结算周期、总人数、总金额、状态（草稿/待审核/已审核/已发放）、创建时间、操作（查看/审核/发放/下载）

**搜索条件**：结算周期（年月选择）、状态（下拉）

**操作按钮**：
- 【生成结算单】按钮 → 弹出生成配置弹窗

#### 2.1.3 生成结算单弹窗

| 字段 | 类型 | 必填 | 校验 |
|------|------|------|------|
| 结算周期 | 年月选择 | 是 | 不能选未来月份；同一周期只允许生成一张草稿结算单 |
| 包含佣金类型 | 多选（FYC/RYC/OVERRIDE/BONUS） | 是 | 默认全选 |
| 包含险种 | 多选 | 否 | 空=全部险种 |
| 发放方式 | 下拉（银行转账/支付宝/微信） | 是 | |
| 备注 | 文本域 | 否 | |

**点击【生成】后端逻辑**：
1. 校验该周期是否已有非DRAFT状态的结算单，若有则返回错误："该周期已有审核中或已发放的结算单"
2. 查询条件：`commission_record WHERE settle_period=xxx AND status='APPROVED' AND pay_batch_no IS NULL AND deleted=0`（已审核、未发放、符合筛选条件）
3. 若查询结果为0，返回提示："当前周期暂无符合条件的已审核佣金"
4. 创建 `commission_pay_batch`（status=DRAFT）
5. 按业务员维度汇总：
   - 查询每个业务员的银行卡/支付宝/微信账号（从员工信息中取，若未绑定则跳过并记录警告）
   - 创建 `commission_pay_detail`（每人一条，合并该周期内所有佣金记录的金额）
6. 将所有被汇总的 `commission_record.pay_batch_no` 更新为新批次号
7. 返回生成结果：共汇总X人，总金额Y元，有Z人因未绑定账号被跳过

#### 2.1.4 结算单详情页

点击结算单列表的【查看】，进入结算单详情页：
- 顶部：结算单基本信息（周期、状态、总金额、发放方式）
- 中间：发放明细表格（业务员姓名、工号、职级、佣金类型明细、合计金额、收款账号、状态）
- 底部：操作按钮区（根据状态显示：提交审核/撤回/下载Excel/驳回/发放）

---

### 2.2 结算审核

#### 2.2.1 审核流程说明

结算单提交后，须经财务负责人审核，审核通过后才能执行发放。

**状态流转**：
```
DRAFT（草稿） 
  → 点击【提交审核】 → PENDING（待审核）
  → 财务主管【审核通过】 → APPROVED（已审核）
  → 【驳回】 → REJECTED（已驳回，返回DRAFT可重新修改）
  → 已审核后【执行发放】 → PAYING（发放中）
  → 发放完成 → COMPLETED（已完成）
```

#### 2.2.2 待审核列表页

**入口**：佣金管理 → 佣金结算 → 待审核结算单

**筛选条件**：结算周期、提交人、金额范围

**审核操作**：
1. 点击【审核】按钮 → 进入审核详情页（展示发放明细）
2. 审核详情页底部有【通过】和【驳回】按钮
3. 点击【通过】：弹出确认框"确认审核通过？通过后将允许执行发放。" → 确认后更新 `commission_pay_batch.status=APPROVED`，记录审批人和时间
4. 点击【驳回】：弹出驳回原因输入框（必填）→ 确认后更新 `commission_pay_batch.status=REJECTED`，同时将该批次关联的所有 `commission_record.pay_batch_no` 清空（恢复为未分配状态）

**后端审核逻辑**：
1. 校验 `commission_pay_batch.status=PENDING`，非法状态则返回错误
2. 使用乐观锁更新（WHERE status='PENDING'），防止并发重复审核
3. 审核通过/驳回均写入操作日志

---

### 2.3 佣金发放

#### 2.3.1 触发入口

状态为 APPROVED 的结算单，可执行发放。点击结算单详情页的【执行发放】按钮。

#### 2.3.2 发放前二次确认

弹出确认框：
```
即将执行发放：
  结算周期：2026年2月
  发放人数：128人
  发放总金额：¥256,800.00
  发放渠道：银行转账

确认后将立即提交银行批量转账，请确认收款信息无误。

[取消]  [确认发放]
```

#### 2.3.3 银行转账发放流程

**点击【确认发放】后端流程**：
1. 获取分布式锁 `commission:pay:batch:{batchId}`（有效期10分钟），防止重复执行
2. 更新 `commission_pay_batch.status=PAYING`
3. 生成银行转账文件（Excel格式，字段：序号、收款户名、收款账号、收款银行、金额、备注）
4. 上传文件到OSS，更新 `commission_pay_batch.bank_file_url`
5. 更新 `commission_pay_batch.status=BANK_FILE_READY`（等待财务人员下载文件到企业网银操作）

> **说明**：银行批量转账通常采用"生成文件→财务网银上传"模式，不直接对接银行接口。若后续对接银行接口，则调用银行企业付款API，根据回调更新状态。

**支付宝批量打款（若选择支付宝）**：
1. 调用支付宝批量打款API（`alipay.fund.trans.uni.transfer`）
2. 遍历发放明细，逐笔提交（out_biz_no=`PAY_${detailId}`，确保幂等）
3. 支付宝同步返回SUCCESS则更新明细状态为已发放
4. FAIL则记录失败原因，加入重试队列
5. 最多重试3次，退避策略（1分钟、5分钟、15分钟后重试）
6. 3次失败后标记为需人工处理

**发放完成**：
- 所有明细均成功后，更新 `commission_pay_batch.status=COMPLETED`，记录 `actual_pay_time`
- 更新对应 `commission_record.status=PAID`，记录 `pay_time` 和 `pay_channel`
- 推送发放成功通知给每位业务员（站内信/短信）

#### 2.3.4 发放明细表（数据库）

```sql
CREATE TABLE `commission_pay_batch` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT,
  `batch_no`        varchar(64)   NOT NULL COMMENT '批次号（PAY+YYYYMMDD+4位序）',
  `settle_period`   varchar(32)   NOT NULL COMMENT '结算周期（YYYYMM）',
  `total_agents`    int(11)       NOT NULL DEFAULT 0 COMMENT '发放人数',
  `total_amount`    decimal(14,2) NOT NULL DEFAULT 0 COMMENT '发放总金额',
  `pay_channel`     varchar(32)   NOT NULL COMMENT 'BANK/ALIPAY/WECHAT',
  `bank_file_url`   varchar(255)  DEFAULT NULL COMMENT '银行转账文件URL',
  `plan_pay_time`   datetime      DEFAULT NULL COMMENT '计划发放时间',
  `actual_pay_time` datetime      DEFAULT NULL COMMENT '实际发放时间',
  `status`          varchar(32)   NOT NULL DEFAULT 'DRAFT'
                    COMMENT 'DRAFT/PENDING/APPROVED/REJECTED/PAYING/BANK_FILE_READY/COMPLETED/FAILED',
  `submitter`       varchar(64)   DEFAULT NULL COMMENT '提交人',
  `submit_time`     datetime      DEFAULT NULL,
  `approver`        varchar(64)   DEFAULT NULL COMMENT '审批人',
  `approve_time`    datetime      DEFAULT NULL,
  `approve_remark`  varchar(500)  DEFAULT NULL,
  `remark`          varchar(500)  DEFAULT NULL,
  `creator`         varchar(64)   DEFAULT NULL,
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         varchar(64)   DEFAULT NULL,
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         tinyint(1)    DEFAULT 0,
  `tenant_id`       bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`),
  KEY `idx_settle_period` (`settle_period`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金发放批次表';

CREATE TABLE `commission_pay_detail` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT,
  `batch_id`        bigint(20)    NOT NULL COMMENT '关联批次ID',
  `batch_no`        varchar(64)   NOT NULL,
  `agent_id`        bigint(20)    NOT NULL COMMENT '业务员ID',
  `agent_name`      varchar(64)   NOT NULL,
  `agent_code`      varchar(64)   DEFAULT NULL COMMENT '工号',
  `pay_account`     varchar(128)  DEFAULT NULL COMMENT '收款账号',
  `pay_account_name` varchar(64)  DEFAULT NULL COMMENT '收款户名',
  `pay_bank_name`   varchar(128)  DEFAULT NULL COMMENT '收款银行',
  `pay_amount`      decimal(12,2) NOT NULL COMMENT '发放金额',
  `commission_ids`  json          DEFAULT NULL COMMENT '包含的佣金记录ID列表',
  `status`          varchar(32)   NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/PAID/FAILED',
  `fail_reason`     varchar(255)  DEFAULT NULL,
  `retry_count`     int(11)       DEFAULT 0,
  `pay_time`        datetime      DEFAULT NULL,
  `pay_voucher`     varchar(255)  DEFAULT NULL COMMENT '支付凭证URL',
  `creator`         varchar(64)   DEFAULT NULL,
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_batch_id`  (`batch_id`),
  KEY `idx_agent_id`  (`agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金发放明细表';
```

---

### 2.4 发放记录查询

#### 2.4.1 页面入口

佣金管理 → 佣金结算 → 发放记录

#### 2.4.2 列表页

**展示字段**：发放批次号、结算周期、业务员、发放金额、发放渠道、发放时间、状态、操作（查看凭证）

**搜索条件**：业务员姓名/工号（模糊）、结算周期、状态、发放时间范围

**导出**：选中或全部记录可导出Excel（含所有展示字段）

---

## 三、对账管理模块

### 3.1 保司对账（Excel导入 + 自动匹配）

#### 3.1.1 功能说明

每月从保司获取结算数据（Excel或API），导入系统后与本地佣金记录进行自动比对，找出差异（佣金金额不一致、本地多出、保司多出等）。

#### 3.1.2 结算单导入页面

**入口**：佣金管理 → 对账管理 → 导入结算单

**操作步骤**：
1. 选择保险公司（下拉，从系统配置的保司列表中选）
2. 选择结算周期（年月选择）
3. 点击【下载模板】获取标准导入Excel模板
4. 填写数据后，点击【上传文件】选择Excel（支持.xls/.xlsx，限制50MB，最大10000行）
5. 点击【预解析】→ 后端返回解析预览（前5行数据预览，以及总行数、识别到的列映射）
6. 确认无误后点击【确认导入】

#### 3.1.3 Excel模板标准格式

| 列序 | 列名 | 必填 | 格式 | 说明 |
|------|------|------|------|------|
| A | 保单号 | 是 | 文本 | |
| B | 被保人姓名 | 否 | 文本 | |
| C | 保费（元） | 是 | 数值，保留2位 | |
| D | 佣金率（%） | 是 | 数值，如25.00 | |
| E | 佣金金额（元） | 是 | 数值，保留2位 | |
| F | 业务员工号 | 否 | 文本 | |
| G | 承保日期 | 否 | YYYY-MM-DD | |

**后端导入逻辑**：
1. 读取Excel，逐行解析
2. 行级校验：保单号不为空、保费>0、佣金金额>0；格式错误的行记录行号和原因，不中止整体导入
3. 通过校验的行批量插入 `insurance_settlement_detail`（match_status='UNMATCHED'）
4. 汇总到 `insurance_settlement`（主表）：记录总保单数、总佣金、导入文件URL（上传到OSS）
5. 返回导入结果：成功X条、失败Y条（可下载失败明细Excel）

#### 3.1.4 自动对账执行

**触发方式**：
- 导入成功后，页面显示【立即对账】按钮，点击后触发
- 或定时任务每月6号凌晨03:00自动执行

**点击【立即对账】后端逻辑**：

```
1. 取出本次导入的所有结算明细（match_status='UNMATCHED'）
2. 对每条明细：
   a. 根据 policy_no + insurance_company 查询本地 commission_record
   b. 若本地不存在：
      → match_status = 'EXCEPTION'
      → diff_type = 'LOCAL_MISSING'（本地无此保单佣金记录）
      → exception_reason = '本地系统未找到该保单的佣金记录'
   c. 若本地存在：
      → 比对佣金金额差异：|settlement.commission_amount - local.commission_amount| ≤ 0.01 元视为匹配
      → 匹配：match_status = 'MATCHED'
      → 不匹配：match_status = 'EXCEPTION'
              diff_type = 'AMOUNT_DIFF'
              diff_amount = settlement.commission_amount - local.commission_amount（正=保司多，负=保司少）
              exception_reason = 保司金额{X}，本地金额{Y}，差异{Z}元
3. 更新 insurance_settlement 主表的统计（matched_count, exception_count）
4. 返回对账结果统计：总N条，匹配X条，异常Y条
```

#### 3.1.5 对账结果列表页

**入口**：佣金管理 → 对账管理 → 对账记录

**展示字段**：结算单号、保险公司、结算周期、总保单数、已匹配数、异常数、对账状态（待对账/已对账/有异常）、导入时间、操作（查看明细/重新对账）

点击【查看明细】进入明细列表，可按匹配状态筛选（全部/已匹配/未匹配/异常）

---

### 3.2 差异处理

#### 3.2.1 差异列表页

**入口**：佣金管理 → 对账管理 → 差异处理

**筛选条件**：保险公司、结算周期、差异类型、处理状态

**展示字段**：

| 列名 | 说明 |
|------|------|
| 保单号 | |
| 保险公司 | |
| 差异类型 | LOCAL_MISSING（本地缺失）/ AMOUNT_DIFF（金额差异）/ RATE_DIFF（费率差异）|
| 保司金额（元） | |
| 本地金额（元） | |
| 差异金额（元） | 正=保司多付，负=保司少付 |
| 处理状态 | 待处理/已处理/处理中 |
| 操作 | 处理 |

#### 3.2.2 差异处理弹窗

点击【处理】按钮，弹出处理弹窗，包含差异详情和处理方案选择：

**处理方案选择**：

| 方案代码 | 方案说明 | 适用场景 |
|---------|---------|---------|
| ACCEPT_INSURANCE | 以保司数据为准，调整本地佣金金额 | 保司数据正确，本地计算有误 |
| KEEP_LOCAL | 保持本地数据，标记为已核实 | 本地数据正确，保司有误，生成异议函 |
| MANUAL_ADJUST | 手动输入调整金额 | 双方均有部分误差，人工协商结果 |

**ACCEPT_INSURANCE 处理逻辑**（后端）：
1. 根据保单号找到本地 `commission_record`
2. 更新 `commission_amount` 为保司数据的金额
3. 若该佣金已审核（APPROVED），需重新进入审核流程
4. 若该佣金已发放（PAID），生成一条差额调整记录（正/负调整）
5. 更新 `insurance_settlement_detail.match_status='MATCHED'`，记录处理人和时间

**KEEP_LOCAL 处理逻辑**：
1. 更新 `insurance_settlement_detail.handle_type='KEEP_LOCAL'`，match_status='HANDLED'
2. 生成异议函（纯文本或Word模板），记录差异详情，发送至保司联系邮箱（可选）
3. 记录处理人、时间、处理备注

**MANUAL_ADJUST 处理逻辑**：
1. 操作人输入最终确认金额和原因
2. 更新本地佣金为调整后金额
3. 生成调整凭证，走审批流

**处理弹窗额外字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 处理方案 | 单选 | 是 | |
| 调整金额（元） | 数字 | 仅MANUAL_ADJUST必填 | |
| 处理备注 | 文本域 | 是 | 不超过500字 |

**审批分级**：
- 差异金额 < 100元：财务专员直接处理（无需审批）
- 100元 ≤ 差异 < 1000元：财务主管审批
- 差异 ≥ 1000元：总经理审批

---

### 3.3 对账报表

#### 3.3.1 功能说明

生成月度对账汇总报表，展示本期对账整体情况、异常汇总、差异分析。

#### 3.3.2 报表页面

**入口**：佣金管理 → 对账管理 → 对账报表

**筛选维度**：结算周期、保险公司（多选）

**报表内容**：
1. **汇总卡片区**：总保单数、已匹配率（%）、异常条数、总差异金额（正/负）
2. **对账明细折线图**：按保司分组展示各月匹配率趋势
3. **差异类型分布饼图**：LOCAL_MISSING / AMOUNT_DIFF / RATE_DIFF 占比
4. **明细表格**：可下载Excel

**后端接口**：`GET /commission/settlement/report`，参数：`settlePeriod`、`insuranceCompanyCodes`

---

## 四、数据库表汇总（本篇涉及）

```sql
-- 保司结算单主表
CREATE TABLE `insurance_settlement` (
  `id`                 bigint(20)    NOT NULL AUTO_INCREMENT,
  `settlement_no`      varchar(64)   NOT NULL COMMENT '结算单号',
  `insurance_company`  varchar(128)  NOT NULL COMMENT '保险公司',
  `settle_period`      varchar(32)   NOT NULL COMMENT '结算周期（YYYYMM）',
  `import_time`        datetime      NOT NULL,
  `file_url`           varchar(255)  NOT NULL COMMENT '原始文件OSS地址',
  `total_count`        int(11)       NOT NULL DEFAULT 0 COMMENT '总保单数',
  `total_premium`      decimal(15,2) NOT NULL DEFAULT 0 COMMENT '总保费',
  `total_commission`   decimal(15,2) NOT NULL DEFAULT 0 COMMENT '总佣金',
  `matched_count`      int(11)       DEFAULT 0 COMMENT '已匹配数',
  `exception_count`    int(11)       DEFAULT 0 COMMENT '异常数',
  `match_status`       varchar(32)   DEFAULT 'PENDING'
                       COMMENT 'PENDING/MATCHING/MATCHED/HAS_EXCEPTION',
  `operator`           varchar(64)   NOT NULL COMMENT '导入操作人',
  `remark`             varchar(500)  DEFAULT NULL,
  `creator`            varchar(64)   DEFAULT NULL,
  `create_time`        datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`            varchar(64)   DEFAULT NULL,
  `update_time`        datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`            tinyint(1)    DEFAULT 0,
  `tenant_id`          bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_settlement_no` (`settlement_no`),
  KEY `idx_settle_period` (`settle_period`),
  KEY `idx_insurance_company` (`insurance_company`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保司结算单主表';

-- 保司结算单明细表
CREATE TABLE `insurance_settlement_detail` (
  `id`                    bigint(20)    NOT NULL AUTO_INCREMENT,
  `settlement_id`         bigint(20)    NOT NULL COMMENT '关联结算单ID',
  `settlement_no`         varchar(64)   NOT NULL,
  `insurance_company`     varchar(128)  NOT NULL,
  `policy_no`             varchar(128)  NOT NULL COMMENT '保单号',
  `insured_name`          varchar(64)   DEFAULT NULL COMMENT '被保人',
  `premium`               decimal(12,2) NOT NULL COMMENT '保费',
  `commission_rate`       decimal(6,4)  NOT NULL COMMENT '佣金率',
  `commission_amount`     decimal(12,2) NOT NULL COMMENT '佣金金额',
  `agent_code`            varchar(64)   DEFAULT NULL COMMENT '业务员工号（保司）',
  `policy_date`           date          DEFAULT NULL COMMENT '承保日期',
  `match_status`          varchar(32)   DEFAULT 'UNMATCHED'
                          COMMENT 'UNMATCHED/MATCHED/EXCEPTION/HANDLED',
  `local_commission_id`   bigint(20)    DEFAULT NULL COMMENT '本地匹配的佣金ID',
  `diff_type`             varchar(64)   DEFAULT NULL COMMENT 'LOCAL_MISSING/AMOUNT_DIFF/RATE_DIFF',
  `diff_amount`           decimal(12,2) DEFAULT NULL COMMENT '差异金额（正=保司多）',
  `exception_reason`      varchar(255)  DEFAULT NULL,
  `handle_type`           varchar(64)   DEFAULT NULL COMMENT 'ACCEPT_INSURANCE/KEEP_LOCAL/MANUAL_ADJUST',
  `handle_remark`         varchar(500)  DEFAULT NULL,
  `handler`               varchar(64)   DEFAULT NULL COMMENT '处理人',
  `handle_time`           datetime      DEFAULT NULL,
  `creator`               varchar(64)   DEFAULT NULL,
  `create_time`           datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_settlement_id` (`settlement_id`),
  KEY `idx_policy_no`     (`policy_no`),
  KEY `idx_match_status`  (`settlement_id`, `match_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保司结算单明细表';
```

---

> **【中篇完】** 下篇内容请见《阶段2-PC佣金系统详细需求文档-下篇（订单管理+保单管理+财务报表+通用规范）》

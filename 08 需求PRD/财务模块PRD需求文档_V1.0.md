# 保险中介平台 · 财务模块需求PRD文档

| 文档信息 | 内容 |
|---------|------|
| 项目名称 | 保险中介全域数字化平台（intermediary-cloud） |
| 模块名称 | 财务中台（ins-finance） |
| 文档版本 | V1.0（基于排期表V13） |
| 技术栈 | yudao-cloud + Spring Cloud Alibaba + EasyExcel + Activiti + ECharts |
| 数据库Schema | `db_ins_finance`，表前缀 `ins_fin_` |
| 微服务模块 | `intermediary-module-ins-finance` |
| 编写日期 | 2026年3月 |
| 文档状态 | 正式版 |

---

## 文档说明

本文档为保险中介平台财务模块完整PRD，覆盖 **阶段6-财务中台** 及 **阶段6-财务中台-合格结算补充（V13新增）** 全部功能点。

文档面向**后端开发、前端开发、测试工程师**，每个功能模块包含：功能概述 → 业务流程 → 页面交互 → 后端处理逻辑 → 数据库设计 → 接口定义。

---

## 目录

1. [模块概述](#一模块概述)
2. [自动对账模块](#二自动对账模块)
   - 2.1 保单导入
   - 2.2 智能匹配引擎
   - 2.3 差异标记与人工处理
   - 2.4 对账报表
3. [上游结算模块（V13）](#三上游结算模块v13)
   - 3.1 上游对账（批量导入修改）
   - 3.2 批量导入结算
   - 3.3 未填手续费跟单队列
4. [合格结算模块（V13）](#四合格结算模块v13)
   - 4.1 合格认定规则配置
   - 4.2 合格汇总与对账单管理
   - 4.3 确认到账
5. [导出模板配置（V13）](#五导出模板配置v13)
   - 5.1 车险导出模板
   - 5.2 非车险导出模板
6. [结算管理模块](#六结算管理模块)
   - 6.1 结算单生成
   - 6.2 结算审核
   - 6.3 发票管理
   - 6.4 打款管理
7. [税务管理模块](#七税务管理模块)
   - 7.1 个税计算
   - 7.2 税务申报
   - 7.3 完税证明
8. [BI经营报表模块](#八bi经营报表模块)
   - 8.1 经营看板
   - 8.2 保费统计
   - 8.3 佣金分析
   - 8.4 人力分析
   - 8.5 渠道分析
   - 8.6 自定义报表
9. [监管报表模块](#九监管报表模块)
   - 9.1 业务台账
   - 9.2 数据上报
   - 9.3 报表归档
10. [权限控制说明](#十权限控制说明)
11. [接口总览](#十一接口总览)
12. [数据库表设计总览](#十二数据库表设计总览)
13. [开发工时估算](#十三开发工时估算)

---

## 一、模块概述

### 1.1 业务背景

保险中介业务涉及复杂的财务结算体系，包括保费对账、佣金结算、税务处理、监管报送等环节。财务中台模块旨在构建一个统一的财务中台系统，实现财务数据的自动化处理、智能化对账、合规化管理。

### 1.2 核心功能模块总览

| 子模块 | 核心功能 | 用户角色 |
|-------|---------|---------|
| 自动对账 | 保单导入、智能匹配、差异标记、人工处理、对账报表 | 财务专员/财务主管 |
| 上游结算（V13） | 批量对账导入、批量结算导入、跟单队列管理 | 财务专员/内勤 |
| 合格结算（V13） | 合格认定规则、对账单生成、到账确认 | 财务经理/财务专员 |
| 导出模板（V13） | 车险/非车险自定义导出字段模板 | 财务专员/管理员 |
| 结算管理 | 结算单生成、审核流程、发票管理、打款管理 | 财务专员/财务主管 |
| 税务管理 | 个税计算、税务申报、完税证明 | 财务专员/财务主管 |
| BI报表 | 经营看板、保费统计、佣金分析、人力分析、渠道分析、自定义报表 | 所有财务角色 |
| 监管报表 | 业务台账、数据上报、报表归档 | 财务专员/管理员 |

### 1.3 系统特点

- **全流程自动化**：从对账到结算到税务的全自动处理，减少人工干预
- **智能匹配引擎**：基于保单号、身份证、手机号、金额等多维度规则的智能对账
- **合规性保障**：符合保险监管要求的报表体系，报表归档保存7年
- **实时数据分析**：基于ECharts的BI实时经营决策支持
- **V13合格结算**：新增上游手续费批量对账、跟单队列、合格认定完整流程

### 1.4 微服务模块结构

```
intermediary-module-ins-finance/
├── intermediary-module-ins-finance-api/
│   └── cn.qmsk.intermediary.module.ins.finance/
│       ├── api/InsFinanceApi.java
│       └── dto/InsSettlementDTO.java
└── intermediary-module-ins-finance-server/
    └── cn.qmsk.intermediary.module.ins.finance/
        ├── controller/admin/
        │   ├── AdminInsReconcileController.java       # 自动对账
        │   ├── AdminInsUpstreamSettleController.java  # 上游结算（V13）
        │   ├── AdminInsQualifiedSettleController.java # 合格结算（V13）
        │   ├── AdminInsExportTemplateController.java  # 导出模板（V13）
        │   ├── AdminInsSettlementController.java      # 结算管理
        │   ├── AdminInsTaxController.java             # 税务管理
        │   ├── AdminInsFinanceBiController.java       # BI报表
        │   └── AdminInsRegulatoryController.java      # 监管报表
        ├── service/（略，同名ServiceImpl）
        ├── dal/dataobject/
        │   ├── InsReconcileTaskDO.java
        │   ├── InsReconcileDiffDO.java
        │   ├── InsSettlementDO.java
        │   ├── InsTaxRecordDO.java
        │   ├── InsUpstreamSettleDO.java
        │   ├── InsQualifiedOrderDO.java   # V13
        │   └── InsExportTemplateDO.java   # V13
        └── job/
            ├── InsAutoReconcileJob.java
            ├── InsTaxCalculateJob.java
            ├── InsQualifiedExpireJob.java # V13
            └── InsRegulatoryReportJob.java
```

---

## 二、自动对账模块

### 2.1 保单导入

#### 2.1.1 功能概述

自动对账模块负责将保险公司下发的保单数据（通过Excel导入）与系统内已有的业务员投保订单进行自动匹配比对，识别差异并推送人工处理，最终生成对账报表。

**核心流程：** 导入 → 匹配 → 差异标记 → 人工处理 → 出报表

#### 2.1.2 功能入口

PC管理后台 → 财务中台 → 自动对账 → 保单导入

#### 2.1.3 导入列表页

**页面顶部筛选栏：**

| 筛选项 | 类型 | 说明 |
|-------|------|------|
| 保险公司 | 下拉选择 | 来源于系统已配置的保险公司列表 |
| 导入日期范围 | 日期选择器 | 开始日期～结束日期 |
| 对账状态 | 下拉 | 待匹配/匹配中/已完成/异常 |

**列表展示字段：**

| 字段 | 说明 |
|------|------|
| 导入批次号 | 系统自动生成，格式：IMP+年月日+4位序号，如IMP202501150001 |
| 保险公司 | 导入数据对应的保险公司名称 |
| 导入文件名 | 上传的Excel文件名 |
| 保单总数 | 本批次导入保单数量 |
| 匹配成功数 | 智能匹配后成功匹配的保单数 |
| 差异数量 | 存在差异的保单数 |
| 导入状态 | 待处理/处理中/处理完成/处理失败 |
| 操作人 | 执行导入操作的用户名 |
| 导入时间 | 操作时间 |
| 操作 | 查看详情 / 下载原文件 / 重新匹配 |

列表顶部右侧提供 **"导入保单"** 按钮。

#### 2.1.4 导入保单弹窗

| 字段 | 类型 | 是否必填 | 说明 |
|------|------|---------|------|
| 保险公司 | 下拉选择 | 必填 | 选择本次导入数据对应的保险公司 |
| 对账月份 | 月份选择器 | 必填 | 本次对账对应的自然月，格式YYYY-MM |
| 导入模板 | 下载链接 | — | 点击可下载对应保险公司的Excel模板 |
| 上传文件 | 文件上传 | 必填 | 支持.xlsx/.xls，单次最大20MB |
| 备注 | 文本框 | 非必填 | 最多200字 |

**点击"确认导入"后：**
1. 前端校验必填项，未填则在字段下方提示红字"请填写XX"
2. 校验文件格式，非.xlsx/.xls弹出提示"请上传Excel格式文件"
3. 校验通过后上传文件并提交，弹出"导入任务已提交，系统将在后台处理"提示

#### 2.1.5 后端导入处理逻辑

**同步部分（立即返回）：**
1. 校验文件大小（≤20MB）、格式（xlsx/xls）
2. 生成导入批次号（IMP + yyyyMMdd + 4位序号，Redis INCR保证唯一性）
3. 将文件存储至OSS（路径：`finance/reconciliation/import/年/月/批次号.xlsx`）
4. 插入导入记录，状态为"待处理"，立即返回批次号

**异步处理部分（MQ消费者）：**
1. 更新状态为"处理中"
2. 使用EasyExcel读取文件，逐行解析，每1000行提交一次事务写库（`ins_fin_import_detail`表）
3. **解析规则：**
   - 必须列：保单号、投保人姓名、投保人身份证/手机号、险种类型、保费金额、起保日期、保险公司保单流水号
   - 空行自动跳过，表头行自动识别（第一行为表头）
   - 金额列强制转为BigDecimal，非数字格式记录行错误信息
   - 日期列解析失败记录行错误信息，不中断整体导入
4. 解析完成后，更新导入记录：总数、成功数、失败数，状态改为"处理完成"（有失败行则"部分失败"）
5. 发送MQ消息触发智能匹配任务

#### 2.1.6 数据库表设计

```sql
-- 导入批次表
CREATE TABLE ins_fin_import_batch (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  batch_no        VARCHAR(20) NOT NULL COMMENT '批次号 IMP+yyyyMMdd+4位序号',
  insurer_code    VARCHAR(50) NOT NULL COMMENT '保险公司编码',
  insurer_name    VARCHAR(100) COMMENT '保险公司名称',
  reconcile_month VARCHAR(7) NOT NULL COMMENT '对账月份 YYYY-MM',
  file_name       VARCHAR(200) COMMENT '原始文件名',
  file_url        VARCHAR(500) COMMENT 'OSS文件路径',
  total_count     INT DEFAULT 0 COMMENT '保单总数',
  matched_count   INT DEFAULT 0 COMMENT '匹配成功数',
  diff_count      INT DEFAULT 0 COMMENT '差异数量',
  error_count     INT DEFAULT 0 COMMENT '解析错误数',
  status          TINYINT DEFAULT 0 COMMENT '0待处理 1处理中 2处理完成 3部分失败 4处理失败',
  remark          VARCHAR(200),
  creator         BIGINT,
  create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
  updater         BIGINT,
  update_time     DATETIME,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT
) ENGINE=InnoDB COMMENT='保司保单导入批次表';

-- 导入明细表
CREATE TABLE ins_fin_import_detail (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  batch_id        BIGINT NOT NULL COMMENT '批次ID',
  batch_no        VARCHAR(20),
  policy_no       VARCHAR(64) COMMENT '保单号',
  insurer_policy_no VARCHAR(64) COMMENT '保司保单流水号',
  holder_name     VARCHAR(50) COMMENT '投保人姓名',
  holder_id_card  VARCHAR(64) COMMENT '投保人身份证（AES加密）',
  holder_phone    VARCHAR(64) COMMENT '投保人手机号（AES加密）',
  insurance_type  VARCHAR(32) COMMENT '险种类型',
  premium         DECIMAL(12,2) COMMENT '保费金额',
  commission_rate DECIMAL(6,4) COMMENT '手续费率',
  commission_amt  DECIMAL(12,2) COMMENT '手续费金额',
  start_date      DATE COMMENT '起保日期',
  end_date        DATE COMMENT '止保日期',
  match_status    TINYINT DEFAULT 0 COMMENT '0未匹配 1精确匹配 2模糊匹配 3无法匹配',
  sys_policy_id   BIGINT COMMENT '匹配到的系统保单ID',
  parse_error     VARCHAR(500) COMMENT '解析错误信息',
  creator         BIGINT,
  create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT,
  INDEX idx_batch_id(batch_id),
  INDEX idx_policy_no(policy_no)
) ENGINE=InnoDB COMMENT='保司保单导入明细表';
```

---

### 2.2 智能匹配引擎

#### 2.2.1 匹配规则（优先级从高到低）

| 优先级 | 匹配规则 | 条件 | 匹配结果 |
|-------|---------|------|---------|
| 1 | **精确匹配** | 保单号完全相同 | 精确匹配（match_status=1） |
| 2 | **证件+金额匹配** | 投保人身份证 + 保费金额（误差≤1元）+ 险种类型 | 精确匹配 |
| 3 | **手机+金额匹配** | 投保人手机号 + 保费金额（误差≤1元）+ 起保日期（误差≤3天） | 模糊匹配（match_status=2，需人工确认） |
| 4 | **姓名+金额匹配** | 投保人姓名 + 保费金额（误差≤0.1元）+ 起保日期（同月）+ 险种 | 模糊匹配，差异标记 |

所有规则都无法匹配时，标记为"无法匹配"（match_status=3），进入差异列表人工处理。

#### 2.2.2 匹配执行方式

**自动触发：** 导入完成后异步触发。

**手动触发：** 点击列表操作栏"重新匹配"按钮，重新对该批次执行匹配。

**并发优化：** 使用`CompletableFuture`并行处理多条保单的匹配，每批1000条，线程池大小`Runtime.getRuntime().availableProcessors() * 2`。

#### 2.2.3 差异识别类型

匹配成功后，即使匹配到了系统保单，也需要比对以下字段是否存在差异：

| 差异类型 | 判断条件 | 差异级别 |
|---------|---------|---------|
| 保费差异 | 导入保费 vs 系统保费，差额超过1元 | 高 |
| 手续费差异 | 导入手续费 vs 系统手续费，差额超过1元 | 高 |
| 起保日期差异 | 日期差距超过1天 | 中 |
| 险种不符 | 险种大类不一致 | 高 |
| 多单少单 | 导入有，系统无（多单）；系统有，导入无（少单） | 高 |

---

### 2.3 差异标记与人工处理

#### 2.3.1 差异列表页

**入口：** PC管理后台 → 财务中台 → 自动对账 → 差异处理

**筛选条件：** 批次号、保险公司、差异类型（下拉多选）、处理状态（待处理/已处理/已忽略）

**列表字段：**

| 字段 | 说明 |
|------|------|
| 差异编号 | DIFF+年月日+序号 |
| 批次号 | 所属导入批次 |
| 保单号 | 导入的保单号 |
| 保险公司 | |
| 差异类型 | 保费差异/手续费差异/日期差异/险种不符/多单/少单 |
| 导入值 | 导入文件中的字段值 |
| 系统值 | 系统中的字段值 |
| 差额 | 导入值 - 系统值（金额类差异显示） |
| 处理状态 | 待处理/已处理/已忽略 |
| 处理人 | |
| 处理时间 | |
| 操作 | 处理 / 忽略 |

顶部提供"批量忽略"按钮（可多选后批量忽略）。

#### 2.3.2 人工处理操作

点击"处理"按钮，弹出右侧抽屉面板，展示：

**左侧：** 差异详情（导入值 vs 系统值，差异字段红色高亮）

**右侧：** 处理选项

| 处理方式 | 说明 | 后端动作 |
|---------|------|---------|
| 以导入值为准 | 更新系统中的对应字段为导入值 | 更新保单相关字段，记录变更日志 |
| 以系统值为准 | 保持系统数据不变，标记导入差异为已处理 | 仅更新差异记录状态 |
| 手动输入确认值 | 既不以导入值也不以系统值，手动填写最终值 | 以填写值更新系统 |
| 忽略 | 本次不处理，差异持续存在 | 状态改为"已忽略" |

处理备注（必填）：说明处理原因。

**后端处理逻辑（以导入值为准时）：**
1. 校验操作权限
2. 在事务中更新系统保单对应字段
3. 写入字段变更日志（旧值/新值/操作人/时间）
4. 更新差异记录状态为"已处理"
5. 重新计算该保单的对账结果

#### 2.3.3 数据库表设计

```sql
CREATE TABLE ins_fin_reconcile_diff (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  batch_id        BIGINT NOT NULL COMMENT '导入批次ID',
  batch_no        VARCHAR(20),
  import_detail_id BIGINT COMMENT '导入明细ID',
  sys_policy_id   BIGINT COMMENT '系统保单ID',
  policy_no       VARCHAR(64),
  insurer_code    VARCHAR(50),
  diff_type       VARCHAR(30) COMMENT '差异类型：PREMIUM/COMMISSION/DATE/TYPE/EXTRA/MISSING',
  diff_level      TINYINT COMMENT '1高 2中 3低',
  import_value    VARCHAR(200) COMMENT '导入值',
  sys_value       VARCHAR(200) COMMENT '系统值',
  diff_amount     DECIMAL(12,2) COMMENT '差额（金额类）',
  process_status  TINYINT DEFAULT 0 COMMENT '0待处理 1已处理 2已忽略',
  process_type    TINYINT COMMENT '1以导入值为准 2以系统值为准 3手动输入',
  process_value   VARCHAR(200) COMMENT '处理后确认值',
  process_remark  VARCHAR(500) COMMENT '处理备注',
  processor       BIGINT,
  process_time    DATETIME,
  creator         BIGINT,
  create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
  updater         BIGINT,
  update_time     DATETIME,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT,
  INDEX idx_batch_id(batch_id),
  INDEX idx_policy_no(policy_no),
  INDEX idx_process_status(process_status)
) ENGINE=InnoDB COMMENT='对账差异记录表';
```

---

### 2.4 对账报表

#### 2.4.1 功能入口

PC管理后台 → 财务中台 → 自动对账 → 对账报表

#### 2.4.2 报表页面

**筛选条件：** 对账月份（月份选择器）、保险公司（多选）

**统计汇总区（顶部数字卡片）：**

| 指标 | 说明 |
|------|------|
| 导入保单数 | 当月导入的全部保单条数 |
| 精确匹配数 | 匹配率 = 精确匹配数 / 导入保单数 |
| 差异处理完成率 | 已处理差异 / 总差异数 |
| 保费差异金额 | 导入保费合计 - 系统保费合计 |
| 手续费差异金额 | 导入手续费合计 - 系统手续费合计 |

**图表区：**
- 柱状图：各保险公司匹配率对比
- 饼图：差异类型分布（保费差异/手续费差异/日期差异/其他）

**明细表格（按保险公司维度）：**

| 保险公司 | 导入总数 | 精确匹配 | 模糊匹配 | 无法匹配 | 差异数 | 差异金额 | 处理进度 |
|---------|---------|---------|---------|---------|-------|---------|---------|

**操作按钮：** 导出Excel（EasyExcel生成，含完整明细）

---

## 三、上游结算模块（V13）

> 本模块为V13新增功能，对应操作手册PDF-171至PDF-191。

### 3.1 上游对账（批量导入修改手续费）

#### 3.1.1 功能概述

财务人员从保险公司获取实际手续费数据后，通过Excel批量导入方式，将系统内保单的上游手续费修改为保司实际应付金额，完成对账。

#### 3.1.2 功能入口

PC管理后台 → 财务 → 上游结算 → 对账 → 点击【批量导入对账】按钮

#### 3.1.3 操作流程

```
Step1: 在"上游结算-对账"页面 → 点击【批量导入对账】→ 弹出对话框
Step2: 对话框内点击【下载对账模板】→ 下载标准Excel模板
Step3: 用户填写Excel模板 → 点击【选择文件】上传 → 选择处理方式 → 点击【确定】
Step4: 系统解析Excel → 更新系统内手续费金额（对账完成）
```

#### 3.1.4 弹窗页面字段

| 元素 | 类型 | 说明 |
|------|------|------|
| 【下载对账表格】按钮 | Button | 下载含当前筛选条件保单的Excel模板 |
| 文件上传区 | Upload | 仅支持.xlsx/.xls，文件大小≤10MB |
| 处理方式 | Radio 单选 | 选项1：以导入金额为准完成对账；选项2：以导入应结金额为准修改系统数据并结算 |
| 【确定】按钮 | Button | 提交执行 |

#### 3.1.5 Excel模板结构

文件名：`上游对账导入模板_${yyyyMMdd}.xlsx`

| 列名 | 字段 | 是否必填 | 说明 |
|------|------|---------|------|
| 保单号 | policy_no | ✅ 必填 | 用于匹配系统保单 |
| 保险公司 | insurer_name | ✅ 必填 | 与系统保单保险公司一致 |
| 应结手续费金额（元） | should_settle_amount | ✅ 必填 | 保司应付手续费金额 |
| 实结手续费金额（元） | actual_settle_amount | ✅ 必填 | 本次实际收到金额；仅修改手续费场景填0 |
| 上游手续费比例（%） | upstream_rate | 选填 | 若填写则同步更新费率 |
| 备注 | remark | 选填 | — |

#### 3.1.6 上传校验规则

后端收到文件后执行以下校验，任一校验失败则**整批拒绝导入**，返回错误明细：

1. **格式校验**：文件是否为xlsx/xls，行数 ≤ 500条，否则提示"单次最多500条"
2. **保单存在性校验**：`policy_no` 在系统中存在且状态不为已撤保/已作废
3. **保险公司匹配校验**：导入的insurer_name与系统保单的保险公司名称一致（允许模糊匹配）
4. **金额格式校验**：must为数字，≥0，精度≤2位小数
5. **重复性校验**：同一保单号在本次导入中不允许重复

#### 3.1.7 二次确认弹窗

弹窗显示汇总信息：
```
本次导入保单共 N 条
涉及保险公司：XX保险、XX财险
修改前系统手续费合计：¥ XXX.XX
修改后（导入值）手续费合计：¥ XXX.XX
差异金额：¥ XXX.XX（红色显示）
```

用户点击【以导入金额为准，完成对账】后执行写库。

#### 3.1.8 后端处理逻辑（对账写库）

在同一数据库事务内，遍历每条导入记录：

```sql
-- 1. 若 upstream_rate 有值，更新保单表手续费比例
UPDATE insurance_policy
SET upstream_rate = #{upstream_rate},
    upstream_amount = #{should_settle_amount},
    update_time = NOW(), updater = #{operatorId}
WHERE policy_no = #{policy_no};

-- 2. 更新或插入上游结算明细
INSERT INTO ins_fin_upstream_settle_detail (
  policy_no, insurer_code, should_settle_amount, actual_settle_amount,
  reconcile_status, ...
) VALUES (...) ON DUPLICATE KEY UPDATE ...;

-- 3. 写操作日志
INSERT INTO sys_operate_log (...) VALUES (...);
```

**互斥保护：** 对账写库前检查该保单是否已关联已确认的对账单（`reconcile_bill`），若已关联则拒绝修改，提示：
> "以下 X 条保单已关联已确认的对账单（单号：RBxxxxxxxxx），无法修改手续费，请先联系财务主管解锁对账单。"

---

### 3.2 批量导入结算

#### 3.2.1 功能入口

PC管理后台 → 财务 → 上游结算 → 结算 → 点击【批量导入结算】

#### 3.2.2 操作流程

```
Step5: 菜单切换至 财务 → 上游结算 → 结算 → 点击【批量导入结算】
Step6: 下载结算模板 → 填写结算信息 → 上传 → 选择"以导入应结金额为准，修改系统数据并结算"
Step7: 系统生成结算单 → 在"结算记录"中找到该结算单 → 点击【审批】→ 完成上游结算
```

#### 3.2.3 结算模板结构

| 列名 | 字段 | 是否必填 |
|------|------|---------|
| 保单号 | policy_no | ✅ |
| 保险公司 | insurer_name | ✅ |
| 应结手续费金额（元） | should_settle_amount | ✅ |
| 实结手续费金额（元） | actual_settle_amount | ✅ |
| 结算说明 | remark | 选填 |

#### 3.2.4 后端结算逻辑

选择"以导入应结金额为准，修改系统数据并结算"后：
1. 按照3.1.8逻辑更新手续费
2. 生成上游结算单（`ins_fin_upstream_settle`表），状态=待审批
3. 生成结算明细（`ins_fin_upstream_settle_detail`表）
4. 发起Activiti审批流程，通知财务主管
5. 审批通过后，更新保单 `upstream_settle_status = 'SETTLED'`

---

### 3.3 未填手续费跟单队列（FN-02）

#### 3.3.1 功能概述

在批量导入结算时，若某些保单的上游手续费尚未填写（`upstream_rate` 为空），系统将这些保单加入"跟单队列"，等待财务人员后续填入手续费后再结算，并支持超期告警。

#### 3.3.2 功能入口

PC管理后台 → 财务 → 上游结算 → 跟单队列

#### 3.3.3 跟单队列列表页

**筛选条件：** 保险公司（下拉）、保单号（文本）、导入时间范围、跟单状态（待处理/已填入/已跳过）、是否超期

**列表字段：**

| 字段 | 说明 |
|------|------|
| 保单号 | |
| 保险公司 | |
| 险种大类 | 车险/非车/寿险 |
| 保费 | |
| 导入时间 | 进入队列时间 |
| 是否超期 | 超过系统配置天数（默认45天）标红显示 |
| 跟单状态 | PENDING_RATE待处理 / SKIP_CURRENT_PERIOD跳过 / SETTLED已结算 |
| 操作 | 填入手续费 / 标记跳过 |

顶部提供【批量导入手续费】按钮。

#### 3.3.4 操作A：填入手续费（单条）

点击"填入手续费"，弹出填写框：

| 字段 | 类型 | 必填 |
|------|------|------|
| 上游手续费比例（%） | 数字输入 | 选填 |
| 上游手续费金额（元） | 数字输入 | ✅ 必填 |
| 备注 | 文本 | 选填 |

确认后：
1. 更新 `insurance_policy.upstream_rate/upstream_amount`
2. 更新 `ins_pending_rate_queue.pending_status = 'SETTLED'`
3. 记录填入时间、填入人
4. 写操作日志（类型：`PENDING_RATE_FILLED`）

#### 3.3.5 操作B：批量填入手续费（Excel导入）

模板列：保单号、上游手续费金额、上游手续费比例（选填）、备注

- 最多500条/次
- 批量操作加分布式锁（Redis Redisson），防止并发操作同一批保单

#### 3.3.6 操作C：标记跳过

点击【标记跳过】，弹出确认框：
> "确认将该保单标记为'跳过本期'？标记后本期不再结算此保单手续费，待下期补录费率后一并结算。"

确认后：
1. 更新 `ins_pending_rate_queue.pending_status = 'SKIP_CURRENT_PERIOD'`
2. 记录跳过时间、跳过人、跳过原因
3. 下期结算扫描时状态自动恢复为 `PENDING_RATE` 重新进入队列

#### 3.3.7 超期告警机制

**XXL-Job 定时任务：** 每日凌晨1:00执行

```
扫描 ins_pending_rate_queue where pending_status = 'PENDING_RATE'
计算 DATEDIFF(NOW(), import_time) > expire_days_config（默认45天）
超期保单：
  1. 更新 is_expired = 1
  2. 推送站内信给财务主管（FINANCE_MANAGER角色）
     标题："跟单队列超期提醒"
     内容："共有 X 条保单上游手续费超 N 天未处理，请及时处理。[查看详情]"
  3. 写告警日志（防重复：同一批次同一天只发一次）
```

**系统配置项：** `pending_rate_expire_days`，默认45，可在财务配置页面修改。

#### 3.3.8 数据库表设计

```sql
CREATE TABLE ins_pending_rate_queue (
  id                  BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
  policy_no           VARCHAR(64) NOT NULL COMMENT '保单号',
  insurer_code        VARCHAR(32) NOT NULL COMMENT '保险公司编码',
  insurer_name        VARCHAR(64) NOT NULL COMMENT '保险公司名称',
  insurance_type      VARCHAR(32) NOT NULL COMMENT '险种大类（CAR/NON_CAR/LIFE）',
  premium_amount      DECIMAL(12,2) DEFAULT NULL COMMENT '保费',
  upstream_rate       DECIMAL(8,4) DEFAULT NULL COMMENT '上游手续费比例',
  upstream_amount     DECIMAL(12,2) DEFAULT NULL COMMENT '上游手续费金额',
  pending_status      VARCHAR(32) NOT NULL DEFAULT 'PENDING_RATE'
                      COMMENT '跟单状态（PENDING_RATE/SKIP_CURRENT_PERIOD/SETTLED）',
  is_expired          TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否超期',
  expire_days_config  INT NOT NULL DEFAULT 45 COMMENT '超期天数配置快照',
  import_time         DATETIME NOT NULL COMMENT '导入时间',
  filled_time         DATETIME DEFAULT NULL COMMENT '手续费填入时间',
  filled_by           BIGINT DEFAULT NULL COMMENT '填入人ID',
  skip_time           DATETIME DEFAULT NULL COMMENT '跳过时间',
  skip_by             BIGINT DEFAULT NULL COMMENT '跳过人ID',
  skip_reason         VARCHAR(200) DEFAULT NULL,
  settle_time         DATETIME DEFAULT NULL COMMENT '结算完成时间',
  remark              VARCHAR(500) DEFAULT NULL,
  creator             BIGINT NOT NULL,
  create_time         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updater             BIGINT DEFAULT NULL,
  update_time         DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  deleted             TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_policy_no (policy_no),
  KEY idx_insurer_status (insurer_code, pending_status),
  KEY idx_import_time (import_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='上游手续费跟单队列';
```

---

## 四、合格结算模块（V13）

### 4.1 合格认定规则配置

#### 4.1.1 功能概述

系统支持配置"保单自动合格"规则，满足规则的保单自动标记为合格状态，用于下游结算统计。也支持手动批量导入合格名单。

#### 4.1.2 功能入口

PC管理后台 → 财务 → 合格结算 → 合格认定规则

#### 4.1.3 规则配置页面

**规则列表字段：**

| 字段 | 说明 |
|------|------|
| 规则名称 | |
| 适用险种 | 车险/非车险/全部 |
| 适用保险公司 | 多选，默认全部 |
| 触发条件 | 上游结算状态=已结算 / 到账金额≥应结金额×X% / 自定义条件 |
| 合格有效期 | 认定合格后的有效天数（0=永久） |
| 状态 | 启用/禁用 |
| 操作 | 编辑/删除 |

#### 4.1.4 合格状态字段扩展

在 `insurance_policy` 表中新增以下字段：

| 字段名 | 类型 | 说明 |
|-------|------|------|
| qualify_status | VARCHAR(32) | 合格状态（NULL/QUALIFIED/SETTLED） |
| qualify_time | DATETIME | 合格认定时间 |
| qualify_source | VARCHAR(32) | 合格来源（AUTO/MANUAL） |
| upstream_settle_status | VARCHAR(32) | 上游结算状态 |
| has_tracking_settled | TINYINT(1) | 是否含跟单结算手续费 |

---

### 4.2 合格汇总与对账单管理

#### 4.2.1 合格汇总页面

**入口：** PC管理后台 → 财务 → 合格结算 → 合格汇总

**筛选条件：** 对账月份、保险公司、合格状态

**汇总数据展示（按保险公司分组）：**

| 保险公司 | 合格保单数 | 合格保费合计 | 合格手续费合计 | 对账单状态 | 操作 |
|---------|---------|------------|------------|----------|------|
| XX保险 | 128 | ¥1,280,000 | ¥64,000 | 已生成 | 查看/解锁 |

**生成对账单按钮：** 选择保险公司和月份后，点击"生成对账单"

#### 4.2.2 对账单生成逻辑

1. 汇总当月该保司所有 `qualify_status = 'QUALIFIED'` 且 `upstream_settle_status = 'SETTLED'` 的保单
2. 创建 `ins_fin_reconcile_bill` 主记录（状态=GENERATED）
3. 创建 `ins_fin_reconcile_bill_detail` 明细记录（每条保单一行，含手续费金额）
4. 自动计算对账单总手续费

#### 4.2.3 对账单状态流转

```
GENERATED（已生成）
  → 财务经理确认收款后 → CONFIRMED（已确认）
  → 财务主管解锁后 → GENERATED（已生成，可重新修改手续费）
```

#### 4.2.4 数据库表设计

```sql
-- 合格对账单主表
CREATE TABLE ins_fin_reconcile_bill (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  bill_no         VARCHAR(30) NOT NULL COMMENT 'RB+年月日+序号',
  insurer_code    VARCHAR(50) NOT NULL,
  insurer_name    VARCHAR(100),
  reconcile_month VARCHAR(7) NOT NULL COMMENT '对账月份',
  policy_count    INT DEFAULT 0,
  total_premium   DECIMAL(14,2) COMMENT '总保费',
  total_commission DECIMAL(12,2) COMMENT '总手续费',
  received_amount DECIMAL(12,2) COMMENT '实际到账金额',
  status          VARCHAR(20) DEFAULT 'GENERATED' COMMENT 'GENERATED/CONFIRMED',
  confirm_time    DATETIME COMMENT '确认时间',
  confirm_by      BIGINT,
  creator         BIGINT,
  create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
  updater         BIGINT,
  update_time     DATETIME,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT
) ENGINE=InnoDB COMMENT='合格对账单主表';

-- 合格对账单明细
CREATE TABLE ins_fin_reconcile_bill_detail (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  bill_id         BIGINT NOT NULL COMMENT '对账单ID',
  bill_no         VARCHAR(30),
  policy_no       VARCHAR(64) NOT NULL,
  insurer_code    VARCHAR(50),
  premium         DECIMAL(12,2),
  upstream_rate   DECIMAL(6,4),
  commission_amount DECIMAL(12,2),
  qualify_time    DATETIME,
  qualify_source  VARCHAR(20),
  creator         BIGINT,
  create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT,
  INDEX idx_bill_id(bill_id),
  INDEX idx_policy_no(policy_no)
) ENGINE=InnoDB COMMENT='合格对账单明细';
```

---

### 4.3 确认到账

#### 4.3.1 功能说明

财务经理在收到保险公司实际打款后，在对账单上确认到账金额，系统记录差额并更新状态。

#### 4.3.2 操作步骤

1. 在对账单列表点击"确认到账"按钮
2. 弹出对话框，填写：
   - 实际到账金额（必填）
   - 到账日期（必填）
   - 银行流水号（选填）
   - 备注（选填）
3. 系统自动计算差额 = 实际到账 - 对账单总手续费
4. 差额记录至 `ins_fin_reconcile_diff_amount`
5. 对账单状态更新为 `CONFIRMED`

#### 4.3.3 权限控制

- **确认到账**：仅 `FINANCE_MANAGER`（财务经理）和 `ADMIN` 角色可操作
- **解锁对账单**：仅 `FINANCE_MANAGER` 和 `ADMIN` 角色可操作

---

## 五、导出模板配置（V13）

### 5.1 车险导出模板（FN-03）

#### 5.1.1 功能入口

- 入口1：车险 → 保单管理 → 保单查询 → 【导出】→ 【自定义表头】
- 入口2（仅管理员）：财务 → 财务配置 → 导出模板管理 → 车险模板

#### 5.1.2 模板列表页

**筛选：** 模板名称（模糊搜索）、保险公司（下拉）、状态（启用/禁用）

**列表列：** 模板ID、模板名称、适用保险公司、创建人、创建时间、最后修改时间、状态

**操作：** 编辑 / 复制 / 删除 / 预览 / 下载样本

**右上角：** 【新增模板】按钮

**权限：**
- 配置权限（新增/编辑/删除）：角色 `ADMIN` 或 `FINANCE_MANAGER`
- 使用权限（选择模板导出）：角色 `FINANCE`、`INNER_STAFF`、`ADMIN`

#### 5.1.3 新增/编辑模板弹窗

| 字段 | 类型 | 是否必填 | 校验规则 |
|------|------|---------|---------|
| 模板名称 | 文本输入 | ✅ | 最长50字，同类型下不允许重名 |
| 授权组织 | 树形选择器 | 选填 | 勾选组织后仅该组织成员可见；不勾选则全员可见 |
| 适用保险公司 | 下拉多选 | 选填 | 不选则适用所有保司 |
| 模板备注 | 文本域 | 选填 | 最长200字 |
| 字段配置区 | 双栏穿梭框 | ✅（至少选1个字段） | 见下方字段分组 |

#### 5.1.4 车险可选字段分组

| 分组 | 字段列表 |
|------|---------|
| 基本信息组 | 保险公司、保险类型、业务类型、保（批）单号、涉农业务、互联网业务、业务员名称、渠道名称、签单日期、起保日期、结束日期 |
| 车辆信息组 | 发动机号、车牌号、车架号 |
| 被保人信息组 | 被保人姓名 |
| 投保人信息组 | 投保人姓名 |
| 保单费用组 | 车船税、总保费、总净保费 |
| 上游手续费组 | 上游保单手续费（%）、上游保单手续费（元） |
| 下游手续费组 | 下游保单手续费（%）、下游保单手续费（元） |
| 结算状态组 | 上游对账状态、上游结算状态、对账状态（下游）、下游结算状态 |
| 险种组 | 交强险、商业险（含子险种：车损险、三者险、座位险、盗抢险、玻璃险、自燃险等），支持全选 |

> 字段分组数据由后端接口 `/finance/export-template/car/fields` 返回，字段定义存储在 `ins_fin_export_field_config` 表中，便于扩展。

右侧已选字段支持**拖拽排序**（Sortable.js），排序即为Excel导出时的列顺序。

#### 5.1.5 使用模板导出保单

在保单查询页点击【导出】→【自定义表头】，弹出导出对话框：

| 字段 | 类型 | 说明 |
|------|------|------|
| 选择模板 | 下拉单选 | 拉取当前用户有权限的模板；默认显示上次使用的模板 |
| 导出范围 | Radio | 当前查询结果（全部）/ 仅勾选记录 |
| 文件名 | 文本输入 | 默认：`车险保单_批次号_yyyyMMdd`，可修改 |

**后端导出逻辑：**
1. 获取模板配置（字段列表及顺序）
2. 按查询条件或勾选保单号列表查询数据
3. 使用 **EasyExcel 动态表头** 生成Excel
4. 记录导出历史至 `ins_fin_export_history` 表
5. 文件存OSS，生成临时下载链接（有效期24小时）

---

### 5.2 非车险导出模板（FN-04）

与车险导出模板功能相同，差异在于字段分组内容。

**非车险特有字段分组：**

| 分组 | 字段列表 |
|------|---------|
| 被保人信息组 | 被保人姓名、被保人证件类型、被保人证件号、被保人手机号 |
| 保单基本组 | 险种名称、险种大类、投保日期、起保日期、终保日期、保险期间 |
| 保额信息组 | 主险保额、附加险保额、年缴保费 |
| 合格状态组 | 合格状态、合格认定时间、合格来源 |
| 跟单状态组 | 跟单状态、手续费填入时间 |

#### 5.2.1 数据库表设计

```sql
-- 导出模板主表
CREATE TABLE ins_fin_export_template (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  template_code   VARCHAR(36) NOT NULL COMMENT 'UUID主键码',
  template_name   VARCHAR(50) NOT NULL,
  template_type   VARCHAR(20) NOT NULL COMMENT 'CAR_INSURANCE/NON_CAR_INSURANCE',
  insurer_codes   VARCHAR(500) COMMENT '适用保司编码，JSON数组',
  org_ids         VARCHAR(500) COMMENT '授权组织ID，JSON数组',
  remark          VARCHAR(200),
  status          TINYINT DEFAULT 1 COMMENT '0禁用 1启用',
  creator         BIGINT,
  create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
  updater         BIGINT,
  update_time     DATETIME,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT,
  UNIQUE KEY uk_code(template_code)
) ENGINE=InnoDB COMMENT='导出模板主表';

-- 模板字段明细
CREATE TABLE ins_fin_export_template_field (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  template_id     BIGINT NOT NULL,
  field_code      VARCHAR(50) NOT NULL COMMENT '字段编码',
  field_name      VARCHAR(100) NOT NULL COMMENT '字段显示名称',
  field_order     INT NOT NULL COMMENT '列顺序（从1开始）',
  is_required     TINYINT DEFAULT 0,
  creator         BIGINT,
  create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT,
  INDEX idx_template_id(template_id)
) ENGINE=InnoDB COMMENT='导出模板字段明细';

-- 导出历史记录
CREATE TABLE ins_fin_export_history (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  template_id     BIGINT COMMENT '使用的模板ID',
  template_name   VARCHAR(50),
  export_type     VARCHAR(20) COMMENT 'CAR_INSURANCE/NON_CAR_INSURANCE',
  file_name       VARCHAR(200),
  file_url        VARCHAR(500),
  record_count    INT COMMENT '导出记录数',
  expire_time     DATETIME COMMENT '文件链接过期时间（24小时后）',
  creator         BIGINT,
  create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT
) ENGINE=InnoDB COMMENT='导出历史记录';
```

---

## 六、结算管理模块

### 6.1 结算单生成

#### 6.1.1 功能概述

每月月底，财务人员对某结算周期内所有已完成对账的业务员佣金进行汇总，生成正式的结算单作为批量打款的依据。

#### 6.1.2 功能入口

PC管理后台 → 财务中台 → 结算管理 → 结算单管理

#### 6.1.3 结算单列表页

**搜索条件：** 结算周期（年月选择）、状态（下拉）

**展示字段：** 结算单号、结算周期、总人数、总金额、状态（草稿/待审核/已审核/已打款）、创建时间、操作

**结算单号规则：** SL + yyyyMM + 4位序号，如 SL20250100001

**操作按钮：** 【生成结算单】

#### 6.1.4 生成结算单弹窗

| 字段 | 类型 | 必填 | 校验 |
|------|------|------|------|
| 结算周期 | 年月选择 | ✅ | 不能选未来月份；同一周期只允许生成一张草稿结算单 |
| 包含佣金类型 | 多选（FYC/RYC/OVERRIDE/BONUS） | ✅ | 默认全选 |
| 包含险种 | 多选 | 否 | 空=全部险种 |
| 备注 | 文本域 | 否 | |

#### 6.1.5 后端生成逻辑

1. 校验该周期是否已有非DRAFT状态的结算单，若有则返回错误
2. 查询已审核、未发放、符合筛选条件的佣金记录
3. 若查询结果为0，返回提示"当前周期暂无符合条件的已审核佣金"
4. 按业务员维度汇总，创建结算单主记录（status=DRAFT）
5. 查询每个业务员的银行卡/支付宝/微信账号（未绑定则跳过并记录警告）
6. 创建结算单明细（每人一条）
7. 计算个税（自动调用税务模块计算，详见税务管理章节）
8. 返回生成结果：共汇总X人，总金额Y元，有Z人因未绑定账号被跳过

#### 6.1.6 数据库表设计

```sql
-- 结算单主表
CREATE TABLE ins_fin_settlement (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  settlement_no   VARCHAR(20) NOT NULL COMMENT '结算单号 SL+yyyyMM+序号',
  settle_month    VARCHAR(7) NOT NULL COMMENT '结算月份',
  total_person    INT DEFAULT 0 COMMENT '总人数',
  total_gross     DECIMAL(14,2) COMMENT '税前总金额',
  total_tax       DECIMAL(12,2) COMMENT '总个税',
  total_net       DECIMAL(14,2) COMMENT '税后总金额',
  status          VARCHAR(20) DEFAULT 'DRAFT'
                  COMMENT 'DRAFT/PENDING/APPROVED/REJECTED/PAYING/COMPLETED',
  invoice_status  TINYINT DEFAULT 0 COMMENT '0未开票 1部分开票 2已开票',
  payment_status  TINYINT DEFAULT 0 COMMENT '0未打款 1打款中 2已打款',
  submit_time     DATETIME,
  approve_time    DATETIME,
  approver        BIGINT,
  reject_reason   VARCHAR(500),
  remark          VARCHAR(500),
  creator         BIGINT,
  create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
  updater         BIGINT,
  update_time     DATETIME,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT
) ENGINE=InnoDB COMMENT='结算单主表';

-- 结算单明细
CREATE TABLE ins_fin_settlement_detail (
  id              BIGINT PRIMARY KEY AUTO_INCREMENT,
  settlement_id   BIGINT NOT NULL,
  settlement_no   VARCHAR(20),
  agent_id        BIGINT NOT NULL COMMENT '业务员ID',
  agent_name      VARCHAR(50),
  agent_no        VARCHAR(30) COMMENT '工号',
  gross_amount    DECIMAL(12,2) COMMENT '税前应结金额',
  tax_amount      DECIMAL(12,2) COMMENT '代扣个税',
  net_amount      DECIMAL(12,2) COMMENT '实发金额',
  bank_name       VARCHAR(50) COMMENT '收款银行',
  bank_account    VARCHAR(64) COMMENT '收款账号（AES加密）',
  bank_holder     VARCHAR(50) COMMENT '开户名',
  pay_status      TINYINT DEFAULT 0 COMMENT '0待打款 1打款中 2已打款 3失败',
  creator         BIGINT,
  create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
  deleted         TINYINT DEFAULT 0,
  tenant_id       BIGINT,
  INDEX idx_settlement_id(settlement_id),
  INDEX idx_agent_id(agent_id)
) ENGINE=InnoDB COMMENT='结算单明细';
```

---

### 6.2 结算审核

#### 6.2.1 审核流程说明

结算单提交后，须经财务负责人审核，审核通过后才能执行发放。

**状态流转：**
```
DRAFT（草稿）
  → 点击【提交审核】 → PENDING（待审核）
  → 财务主管【审核通过】 → APPROVED（已审核）
  → 【驳回】 → REJECTED（已驳回，可修改后重新提交）
  → 已审核后【执行发放】 → PAYING（发放中）
  → 发放完成 → COMPLETED（已完成）
```

#### 6.2.2 审核页面

**入口：** 财务中台 → 结算管理 → 待审核结算单

**筛选条件：** 结算周期、提交人、金额范围

**审核操作：**
1. 点击【审核】进入审核详情页
2. 底部【通过】：弹出确认框，确认后更新 `status=APPROVED`，记录审批人和时间
3. 底部【驳回】：弹出驳回原因输入框（必填），确认后更新 `status=REJECTED`

**后端审核逻辑：**
- 使用乐观锁更新（`WHERE status='PENDING'`），防止并发重复审核
- 审核通过/驳回均写入操作日志（`@OperateLog` 注解）
- 基于 Activiti 工作流实现审批流程

---

### 6.3 发票管理

#### 6.3.1 功能概述

支持业务员或财务人员申请开票，系统自动或手动处理发票，并管理发票文件和状态。

#### 6.3.2 功能入口

PC管理后台 → 财务中台 → 结算管理 → 发票管理

#### 6.3.3 发票列表页

**筛选：** 结算月份、业务员、发票状态（待开具/已开具/已作废）、申请日期范围

**列表字段：**

| 字段 | 说明 |
|------|------|
| 发票申请号 | INV+年月日+序号 |
| 结算单号 | 关联结算单 |
| 业务员 | 申请人 |
| 开票金额 | 含税金额 |
| 开票类型 | 增值税专票/增值税普票/收据 |
| 开票抬头 | |
| 发票状态 | 待开具/开具中/已开具/已作废 |
| 申请时间 | |
| 操作 | 查看 / 上传发票 / 作废 |

#### 6.3.4 申请开票流程

点击"申请开票"按钮：

| 字段 | 类型 | 必填 |
|------|------|------|
| 关联结算单 | 下拉选择（状态=已审核） | ✅ |
| 开票类型 | 单选 | ✅ |
| 开票抬头 | 文本 | ✅ |
| 税号 | 文本 | 条件必填（专票必填） |
| 开票金额 | 数字（含税） | ✅ |
| 税率 | 下拉（3%/6%/9%/13%/免税） | ✅ |
| 开票内容 | 文本 | ✅ |
| 收票邮箱 | 邮箱格式 | ✅ |

**后端处理：**
1. 校验开票金额不得超过对应结算单实发金额
2. 生成发票申请记录，状态"待开具"
3. 若接入了发票API（百旺、航信），则调用API自动开票，异步获取发票文件URL
4. 若未接入API，则推送工单给财务人员手动处理

**上传发票：** 支持PDF，最大5MB，上传后存OSS，状态改为"已开具"

#### 6.3.5 发票作废

点击"作废"，输入作废原因（必填）后：
1. 发票状态改为"已作废"，记录作废时间和原因
2. 对应结算单发票状态重置为"未开票"，允许重新申请
3. 若已通过API开票，同步调用发票API的冲红接口

#### 6.3.6 数据库表设计

```sql
CREATE TABLE ins_fin_invoice (
  id                BIGINT PRIMARY KEY AUTO_INCREMENT,
  invoice_apply_no  VARCHAR(30) NOT NULL COMMENT '发票申请号 INV+年月日+序号',
  settlement_id     BIGINT NOT NULL COMMENT '结算单ID',
  settlement_no     VARCHAR(20),
  agent_id          BIGINT,
  invoice_type      TINYINT COMMENT '1增值税专票 2增值税普票 3收据',
  invoice_title     VARCHAR(100) COMMENT '开票抬头',
  tax_no            VARCHAR(30) COMMENT '税号',
  total_amount      DECIMAL(12,2) COMMENT '含税金额',
  tax_rate          DECIMAL(5,4) COMMENT '税率',
  tax_amount        DECIMAL(12,2) COMMENT '税额',
  amount_without_tax DECIMAL(12,2) COMMENT '不含税金额',
  invoice_content   VARCHAR(100) COMMENT '开票内容',
  receive_email     VARCHAR(100) COMMENT '收票邮箱',
  status            TINYINT DEFAULT 0 COMMENT '0待开具 1开具中 2已开具 3已作废',
  invoice_no        VARCHAR(50) COMMENT '发票号码',
  invoice_code      VARCHAR(50) COMMENT '发票代码',
  invoice_file_url  VARCHAR(500) COMMENT '电子发票PDF地址（OSS）',
  void_reason       VARCHAR(200),
  creator           BIGINT,
  create_time       DATETIME DEFAULT CURRENT_TIMESTAMP,
  updater           BIGINT,
  update_time       DATETIME,
  deleted           TINYINT DEFAULT 0,
  tenant_id         BIGINT,
  INDEX idx_settlement_id(settlement_id)
) ENGINE=InnoDB COMMENT='发票管理表';
```

---

### 6.4 打款管理

#### 6.4.1 功能概述

审核通过的结算单，由财务人员发起打款操作，支持批量打款，系统生成银行批量付款文件或调用银行API完成实际佣金划拨。

#### 6.4.2 功能入口

PC管理后台 → 财务中台 → 结算管理 → 打款管理

#### 6.4.3 打款列表页

**筛选：** 结算月份、业务员、打款状态（待打款/打款中/已打款/失败）、打款批次号

**列表字段：**

| 字段 | 说明 |
|------|------|
| 打款批次号 | PAY+年月日+序号 |
| 结算单号 | |
| 业务员姓名/工号 | |
| 结算月份 | |
| 实发金额 | 本次打款金额 |
| 收款银行 | |
| 收款卡号 | 脱敏展示，如 622202****1234 |
| 打款状态 | |
| 打款时间 | |
| 操作 | 查看回单 / 重试（失败时显示） |

#### 6.4.4 发起打款流程

**步骤一：** 在结算单列表勾选状态=审核通过的结算单（可多选），点击"发起打款"

**步骤二：** 弹出打款确认对话框

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 打款方式 | 单选 | ✅ | 批量文件导出（手动上传银行系统）/ API自动打款 |
| 付款账户 | 下拉 | ✅ | 公司付款银行账户，来源于系统配置 |
| 备注 | 文本 | 否 | |

**步骤三：若选择"批量文件导出"**
1. 生成打款批次记录（status=打款中）
2. 生成银行批量付款Excel文件（格式遵循平安银行/招商银行等标准格式），存OSS
3. 提示"文件已生成，请下载后上传至银行系统"，提供下载链接
4. 显示"确认已完成上传"按钮，点击后将打款状态改为"已打款"（人工确认模式）

**步骤三：若选择"API自动打款"**
1. 生成打款批次记录（status=打款中）
2. 获取分布式锁 `finance:pay:batch:{batchId}`（有效期10分钟），防止重复执行
3. 调用银行API批量转账接口
4. 异步回调或轮询更新每笔打款状态（成功/失败）
5. 所有明细处理完毕后更新批次状态

---

## 七、税务管理模块

### 7.1 个税计算

#### 7.1.1 业务背景

保险中介平台向业务员支付佣金时，需依法代扣代缴个人所得税。佣金所得属于"劳务报酬所得"，适用预扣率表。

#### 7.1.2 个税计算规则

**每次收入额计算：**
- 每次收入 ≤ 4,000元：收入额 = 收入 - 800元（定额扣除）
- 每次收入 > 4,000元：收入额 = 收入 × (1 - 20%)（按比例扣除）

**劳务报酬所得预扣率表（2024年适用）：**

| 每次收入额 | 预扣率 | 速算扣除数 |
|-----------|-------|----------|
| 不超过20,000元 | 20% | 0 |
| 超过20,000元不超过50,000元 | 30% | 2,000元 |
| 超过50,000元 | 40% | 7,000元 |

**应扣税额 = 收入额 × 预扣率 - 速算扣除数**

**计算示例：**
- 本月应结佣金 = 30,000元
- 收入额 = 30,000 × (1 - 20%) = 24,000元
- 预扣率 = 30%，速算扣除数 = 2,000
- 应扣税额 = 24,000 × 30% - 2,000 = **5,200元**
- 实发金额 = 30,000 - 5,200 = **24,800元**

#### 7.1.3 功能入口

PC管理后台 → 财务中台 → 税务管理 → 个税计算

#### 7.1.4 个税计算页面

**筛选+查询：** 结算月份（必填）、业务员（可选），点击"查询/计算"

**列表展示（每个业务员一行）：**

| 字段 | 说明 |
|------|------|
| 业务员姓名 / 工号 | |
| 结算单号 | |
| 应结佣金（税前） | |
| 定额/比例扣除额 | |
| 应纳税收入额 | |
| 预扣率 | |
| 速算扣除数 | |
| 应扣税额 | |
| 实发金额 | |
| 计算状态 | 自动计算 / 已人工调整 |
| 操作 | 人工调整 |

#### 7.1.5 人工调整

点击"人工调整"，弹出编辑框：
- 允许手动修改"应扣税额"（需填写调整原因）
- 重新计算实发金额
- 更新结算单的 `tax_amount` 和 `actual_amount`
- 状态标记为"已人工调整"，记录操作日志

#### 7.1.6 数据库表设计

```sql
CREATE TABLE ins_fin_tax_record (
  id                BIGINT PRIMARY KEY AUTO_INCREMENT,
  settlement_id     BIGINT NOT NULL,
  settlement_no     VARCHAR(20),
  agent_id          BIGINT NOT NULL,
  agent_name        VARCHAR(50),
  settle_month      VARCHAR(7),
  gross_income      DECIMAL(12,2) COMMENT '税前收入',
  deduction         DECIMAL(12,2) COMMENT '扣除额（800定额或20%）',
  taxable_income    DECIMAL(12,2) COMMENT '应纳税收入额',
  tax_rate          DECIMAL(5,4) COMMENT '预扣率',
  quick_deduction   DECIMAL(10,2) COMMENT '速算扣除数',
  tax_amount        DECIMAL(12,2) COMMENT '应扣税额',
  net_income        DECIMAL(12,2) COMMENT '税后实发金额',
  calc_type         TINYINT DEFAULT 0 COMMENT '0自动计算 1人工调整',
  adjust_reason     VARCHAR(200),
  creator           BIGINT,
  create_time       DATETIME DEFAULT CURRENT_TIMESTAMP,
  updater           BIGINT,
  update_time       DATETIME,
  deleted           TINYINT DEFAULT 0,
  tenant_id         BIGINT
) ENGINE=InnoDB COMMENT='个税计算记录';
```

---

### 7.2 税务申报

#### 7.2.1 功能概述

每月完成代扣税款后，系统生成符合税务局要求的申报数据文件，供财务人员下载后上传至自然人电子税务局（扣缴端）完成申报。

#### 7.2.2 申报列表页

**筛选：** 申报月份、申报状态（待申报/申报中/已申报）

**列表字段：**

| 字段 | 说明 |
|------|------|
| 申报批次号 | TAX+年月+序号 |
| 申报月份 | YYYY-MM |
| 申报人数 | 代扣人数 |
| 代扣税额合计 | |
| 申报状态 | |
| 申报文件 | 下载链接 |
| 操作 | 生成申报文件 / 标记已申报 / 查看明细 |

#### 7.2.3 生成申报文件

点击"生成申报文件"，确认本月参与申报的人数和代扣税额合计后：

1. 查询该月所有 `calc_type` 已完成的税务记录
2. 按自然人电子税务局扣缴端要求的格式生成CSV/Excel申报文件：

| 字段 | 税务局字段名 |
|------|-----------|
| 身份证号 | 证件号码 |
| 姓名 | 姓名 |
| 收入额 | 所得项目金额 |
| 收入类型 | 所得项目（编码：04劳务报酬） |
| 税前扣除 | 费用 |
| 应纳税所得额 | 应纳税所得额 |
| 税率 | 税率 |
| 速算扣除数 | 速算扣除数 |
| 应纳税额 | 应纳税额 |
| 已扣缴税额 | 已扣缴税额 |

3. 文件存OSS，更新申报批次状态

#### 7.2.4 标记已申报

填写：申报日期（必填）、申报方式（必填：自然人税务局在线申报/纸质报送）、申报凭证（选填）、备注

---

### 7.3 完税证明

#### 7.3.1 功能概述

为业务员生成个人所得税完税证明，支持按月或按年生成PDF，支持邮件发送。

#### 7.3.2 功能入口

PC管理后台 → 财务中台 → 税务管理 → 完税证明

#### 7.3.3 完税证明列表页

**筛选：** 结算月份/年份（支持按年汇总）、业务员

**列表字段：**

| 字段 | 说明 |
|------|------|
| 业务员姓名/工号 | |
| 统计周期 | 月度/年度 |
| 代扣税额 | |
| 税后实发 | |
| 证明状态 | 未生成/已生成 |
| 操作 | 生成PDF / 下载 / 发送邮件 |

#### 7.3.4 生成完税证明PDF

点击"生成PDF"，系统根据预置PDF模板（含公司抬头、印章）生成：
- **证明内容**：纳税人姓名、身份证号、所属周期、累计收入、累计已扣税额、公章（水印）
- 文件存OSS，更新状态为"已生成"，提供下载链接

**发送邮件：** 点击"发送邮件"，将PDF附件发送至业务员绑定的邮箱，记录发送时间

---

## 八、BI经营报表模块

### 8.1 经营看板

#### 8.1.1 功能概述

首页实时大屏，展示公司核心经营指标，支持实时刷新（30秒自动刷新）。

#### 8.1.2 功能入口

PC管理后台 → 财务中台 → BI报表 → 经营看板

#### 8.1.3 看板指标卡片区

**核心KPI卡片（今日/本月/本年三个维度切换）：**

| 指标 | 说明 | 计算口径 |
|------|------|---------|
| 新单保费（FYP） | 新保保费合计 | 当期出单保单总保费 |
| 活动人力 | 当期有出单的业务员数 | distinct agent_id |
| 佣金收入 | 公司获得佣金合计 | 上游结算已到账手续费 |
| 有效继续率 | 续保率 | 应续保/已续保 |
| 件均保费 | FYP / 保单数 | |
| 新增客户 | 当期新建客户数 | |

#### 8.1.4 图表区

**图表一：保费趋势折线图**
- X轴：月份（近12个月），Y轴：保费金额（万元）
- 双折线：新单FYP（蓝）/ 续期RYP（绿）

**图表二：险种占比环形图**
- 车险 / 非车险 / 寿险占比（按保费金额）

**图表三：团队产能排行榜（横向柱状图）**
- 按团队保费降序排列，展示前10团队

**图表四：异常告警区**
- 列出当日触发的告警项：如跟单超期、对账差异未处理、结算审核超期等
- 点击可跳转对应模块

#### 8.1.5 后端数据接口

所有大屏指标由独立的聚合查询服务提供，结果缓存至Redis（TTL=5分钟），避免频繁查询数据库。

---

### 8.2 保费统计

#### 8.2.1 功能入口

PC管理后台 → 财务中台 → BI报表 → 保费统计

#### 8.2.2 页面功能

**筛选栏：** 时间范围（月份区间）、险种大类（多选）、保险公司（多选）、团队（多选）

**图表一：保费趋势折线图**
- X轴：月份，Y轴：保费金额
- 可按险种大类分组展示多折线

**图表二：险种结构饼图**
- 各险种保费占比

**汇总表格（按月度+险种维度）：**

| 月份 | 险种 | 保单数 | 总保费 | 净保费 | 同比增长 | 环比增长 |
|------|------|-------|-------|-------|---------|---------|

---

### 8.3 佣金分析

#### 8.3.1 功能入口

PC管理后台 → 财务中台 → BI报表 → 佣金分析

#### 8.3.2 页面功能

**图表一：佣金趋势折线图**
- 双折线：应收佣金（蓝）/ 实收佣金（橙）/ 已发放佣金（绿）
- X轴：月份，Y轴：金额（万元）

**图表二：佣金率变化折线图**
- 按险种展示平均佣金率变化趋势

**汇总数据卡片区：**

| 指标 | 说明 |
|------|------|
| 本月应收佣金 | 当月已出单保单应收取的手续费合计 |
| 本月实收佣金 | 已到账手续费合计 |
| 已发放佣金 | 已打款给业务员的佣金合计 |
| 未发放佣金 | 实收 - 已发放 |
| 综合佣金率 | 实收佣金 / 总保费 |

**明细表格（按业务员维度）：**

| 业务员 | 保单数 | 保费 | 应收佣金 | 实收佣金 | 已发放 | 实际佣金率 |
|-------|-------|------|---------|---------|-------|----------|

---

### 8.4 人力分析

#### 8.4.1 功能入口

PC管理后台 → 财务中台 → BI报表 → 人力分析

#### 8.4.2 页面功能

**筛选栏：** 时间范围（月份区间）、团队（多选）

**图表一：人力发展折线图**
- 三条折线：在职人数（蓝）/ 新增人数（绿）/ 离职人数（红）

**图表二：人均产能趋势（折线图）**
- X轴：月份，Y轴：人均保费（万元/人）

**图表三：活跃率分析**
- 活跃率 = 当月有出单业务员 / 当月在职业务员总数
- 按团队展示柱状图对比

**汇总表格（按团队/月份）：**

| 团队 | 月份 | 期初人数 | 新增 | 离职 | 期末人数 | 出单人数 | 活跃率 | 人均保费 | 人均佣金 |
|------|------|---------|-----|------|---------|---------|-------|---------|---------|

---

### 8.5 渠道分析

#### 8.5.1 功能入口

PC管理后台 → 财务中台 → BI报表 → 渠道分析

#### 8.5.2 页面功能

**筛选栏：** 时间范围（月份区间）、渠道/保险公司（多选，默认全部）

**图表一：渠道保费占比（饼图）**
- 各保险公司保费占比，支持点击下钻查看险种分布

**图表二：渠道保费趋势对比（折线图，多线）**
- 每条线代表一个保险公司

**图表三：渠道佣金率对比（横向柱状图）**
- 各渠道平均佣金率从高到低排序

**汇总表格：**

| 保险公司 | 险种数量 | 保单数 | 保费合计 | 保费占比 | 佣金合计 | 佣金率 | 月均增长率 |
|---------|---------|-------|---------|---------|---------|-------|----------|

---

### 8.6 自定义报表

#### 8.6.1 功能概述

允许财务/运营人员自行选择维度和指标，动态生成数据报表，无需开发介入。支持保存常用报表配置。

#### 8.6.2 功能入口

PC管理后台 → 财务中台 → BI报表 → 自定义报表

#### 8.6.3 页面布局

**页面分为左中右三区：**

**左侧：维度/指标选择区**

可选维度（多选拖拽）：

| 维度分类 | 维度字段 |
|---------|---------|
| 时间维度 | 年 / 月 / 日 / 周 |
| 业务维度 | 保险公司、险种大类、险种小类、团队、业务员 |
| 地区维度 | 省份、城市 |

可选指标（多选）：保单数、保费金额、佣金金额、佣金率、个税金额、实发金额、活跃人数

**中间：报表配置区**
- 行维度：拖入1-2个维度字段
- 列维度：拖入0-1个维度字段（构成交叉表）
- 指标：勾选展示哪些指标列
- 时间范围：必填
- 筛选条件：可选

**右侧：报表展示区**
- 动态生成数据表格，支持列排序、合计行、分页（每页50条）
- 【导出Excel】：EasyExcel动态表头导出
- 【保存配置】：填写报表名称，保存当前配置
- 【我的报表】：查看已保存的报表配置，点击快速加载

#### 8.6.4 后端动态SQL实现

1. 前端提交 `ReportQueryDTO`（维度列表、指标列表、时间范围、筛选条件）
2. 后端通过 `ReportSqlBuilder` 服务动态构建SQL
3. **白名单安全机制**：所有可选维度、指标均有对应枚举映射，前端传入枚举Key，后端映射为SQL字段，拒绝不在枚举中的字段（防SQL注入）

#### 8.6.5 数据库表设计

```sql
CREATE TABLE ins_fin_bi_report_config (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  report_name VARCHAR(100) NOT NULL COMMENT '报表名称',
  config_json TEXT NOT NULL COMMENT '配置JSON（维度、指标、筛选等）',
  creator     BIGINT,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  updater     BIGINT,
  update_time DATETIME,
  deleted     TINYINT DEFAULT 0,
  tenant_id   BIGINT
) ENGINE=InnoDB COMMENT='BI自定义报表配置';
```

---

## 九、监管报表模块

### 9.1 业务台账

#### 9.1.1 功能概述

按监管要求生成标准格式的业务台账表，记录保险中介机构的保费收入、佣金收入等，用于向金融监管总局报送。

#### 9.1.2 功能入口

PC管理后台 → 财务中台 → 监管报表 → 业务台账

#### 9.1.3 台账列表页

**筛选：** 报表年月（月份选择器）、报表状态（待生成/已生成/已上报/已归档）

**列表字段：**

| 字段 | 说明 |
|------|------|
| 台账编号 | REG+年月+序号 |
| 报表名称 | 如"2025年01月保险中介业务统计台账" |
| 报表类型 | 月报/季报/年报 |
| 报表月份 | |
| 生成状态 | 待生成/已生成 |
| 上报状态 | 待上报/已上报 |
| 归档状态 | 待归档/已归档 |
| 操作 | 生成 / 预览 / 下载 / 标记已上报 / 归档 |

#### 9.1.4 生成台账

**触发方式：** 手动点击"生成"按钮，或XXL-Job每月1日凌晨自动生成上月台账。

**后端生成逻辑：**
1. 查询上月已完成对账和结算的所有数据
2. 按监管报表固定格式填充数据：
   - **表一：保险代理业务基本情况表**（业务类型/保单数量/保费收入/手续费收入/手续费率）
   - **表二：人员情况表**（从业人员类别/期初人数/本期新增/本期减少/期末人数）
   - **表三：客户投诉情况**（如有）
3. 使用EasyExcel模板填充（预置好格式的xlsx模板），文件存OSS
4. 更新台账记录状态为"已生成"

#### 9.1.5 标记已上报

弹出对话框：

| 字段 | 类型 | 是否必填 |
|------|------|---------|
| 上报日期 | 日期选择器 | ✅ |
| 上报方式 | 单选 | ✅ | 监管系统在线上报 / 纸质报送 |
| 上报凭证 | 文件上传 | 否 |
| 备注 | 文本 | 否 |

---

### 9.2 数据上报

#### 9.2.1 功能概述

对接监管数据上报接口（部分地区银保局要求API上报），自动推送数据，支持失败重试。

#### 9.2.2 上报配置

首次使用需在"系统配置"中配置监管接口参数：监管机构名称、接口地址（URL）、认证方式（API Key / OAuth2 / 数字证书）、认证参数（AES加密存储）、数据格式（JSON/XML/固定格式报文）

#### 9.2.3 上报记录列表

**筛选：** 上报月份、上报机构、上报状态（成功/失败/待上报）

**列表字段：**

| 字段 | 说明 |
|------|------|
| 上报批次号 | RPT+年月日+序号 |
| 上报机构 | 监管机构名称 |
| 上报月份 | |
| 数据条数 | 本次上报数据量 |
| 上报状态 | 成功/失败/部分成功 |
| 上报时间 | |
| 响应信息 | 监管系统返回的响应码和描述 |
| 操作 | 查看请求/响应详情 / 重试 |

#### 9.2.4 上报逻辑

**定时自动上报：** XXL-Job 每月5日凌晨3点触发

**手动触发：** 点击"立即上报"，选择上报月份和机构

**后端处理：**
1. 查询目标月份需上报的业务数据
2. 按监管接口规范组装报文
3. 调用HTTP接口发送，记录请求报文和响应报文（加密存储）
4. 解析响应：成功则更新上报状态；失败则记录错误，推送告警通知
5. 失败记录支持手动"重试"

---

### 9.3 报表归档

#### 9.3.1 功能概述

统一管理各类报表文件的归档，支持按月、按类型检索，确保报表可追溯、可审计，符合金融监管保存期限要求。

#### 9.3.2 归档列表页

**筛选：** 报表类型（对账报表/结算报表/税务申报/监管台账）、时间范围、归档状态

**列表字段：**

| 字段 | 说明 |
|------|------|
| 报表名称 | |
| 报表类型 | |
| 所属月份 | YYYY-MM |
| 文件大小 | KB/MB |
| 归档时间 | |
| 归档人 | |
| 操作 | 下载 / 删除（需系统管理员权限） |

#### 9.3.3 归档规则

**手动归档：** 在各报表生成页点击"归档"，文件在OSS中移动到归档目录（路径：`finance/archive/年/月/报表类型/文件名`），记录归档人和时间。

**自动归档：** 定时任务每月1日将上月所有已上报的监管台账自动归档。

**合规要求：** 归档后的文件在OSS中启用"不可删除"（Object Lock），保存期限**7年**（符合金融监管要求）。

#### 9.3.4 数据库表设计

```sql
CREATE TABLE ins_fin_report_archive (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  report_name VARCHAR(200) NOT NULL,
  report_type VARCHAR(50) COMMENT '类型：reconcile/settlement/tax/regulatory',
  report_month VARCHAR(7),
  file_name   VARCHAR(200),
  file_url    VARCHAR(500) COMMENT 'OSS归档路径',
  file_size   BIGINT COMMENT '字节',
  archive_type TINYINT DEFAULT 0 COMMENT '0手动 1自动',
  source_id   BIGINT COMMENT '来源记录ID',
  source_type VARCHAR(50) COMMENT '来源类型',
  creator     BIGINT,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  updater     BIGINT,
  update_time DATETIME,
  deleted     TINYINT DEFAULT 0,
  tenant_id   BIGINT
) ENGINE=InnoDB COMMENT='报表归档管理';
```

---

## 十、权限控制说明

财务中台各功能的角色权限矩阵：

| 功能模块 | 财务专员 | 内勤 | 财务主管 | 财务经理 | 系统管理员 |
|---------|---------|------|---------|---------|----------|
| 保单导入（查看/操作） | ✅ | ✅ | ✅ | ✅ | ✅ |
| 差异人工处理 | ✅ | ❌ | ✅ | ✅ | ✅ |
| 批量导入对账 | ✅ | ❌ | ✅ | ✅ | ✅ |
| 跟单队列操作 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 合格认定规则配置 | ❌ | ❌ | ✅ | ✅ | ✅ |
| 生成合格对账单 | ✅ | ❌ | ✅ | ✅ | ✅ |
| 确认到账 | ❌ | ❌ | ❌ | ✅ | ✅ |
| 解锁对账单 | ❌ | ❌ | ❌ | ✅ | ✅ |
| 导出模板配置 | ❌ | ❌ | ✅ | ✅ | ✅ |
| 导出模板使用 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 结算单生成 | ✅ | ❌ | ✅ | ✅ | ✅ |
| 结算单审核 | ❌ | ❌ | ✅ | ✅ | ✅ |
| 发票管理（查看/申请） | ✅ | ❌ | ✅ | ✅ | ✅ |
| 打款操作 | ❌ | ❌ | ✅ | ✅ | ✅ |
| 个税计算（查看） | ✅ | ❌ | ✅ | ✅ | ✅ |
| 个税人工调整 | ❌ | ❌ | ✅ | ✅ | ✅ |
| 税务申报 | ✅ | ❌ | ✅ | ✅ | ✅ |
| BI报表（查看） | ✅ | ✅ | ✅ | ✅ | ✅ |
| 监管台账（生成/上报） | ✅ | ❌ | ✅ | ✅ | ✅ |
| 报表归档（删除） | ❌ | ❌ | ❌ | ❌ | ✅ |
| 超期告警配置 | ❌ | ❌ | ❌ | ✅ | ✅ |

> 权限在 yudao-cloud 的 `system_role_menu` 中配置，菜单按钮级别控制。

---

## 十一、接口总览

### 自动对账接口

| Method | Path | 说明 |
|--------|------|------|
| GET | `/finance/reconcile/import/page` | 导入批次分页列表 |
| POST | `/finance/reconcile/import/upload` | 上传并创建导入批次 |
| POST | `/finance/reconcile/import/{batchId}/match` | 手动触发匹配 |
| GET | `/finance/reconcile/diff/page` | 差异记录分页列表 |
| POST | `/finance/reconcile/diff/{id}/process` | 处理单条差异 |
| POST | `/finance/reconcile/diff/batch-ignore` | 批量忽略差异 |
| GET | `/finance/reconcile/report` | 对账报表数据 |
| GET | `/finance/reconcile/report/export` | 对账报表导出 |

### 上游结算接口（V13）

| Method | Path | 说明 |
|--------|------|------|
| GET | `/finance/upstream/reconcile/template` | 下载对账模板 |
| POST | `/finance/upstream/reconcile/batch-import` | 批量导入对账（预览） |
| POST | `/finance/upstream/reconcile/batch-confirm` | 确认批量对账写库 |
| GET | `/finance/upstream/settle/template` | 下载结算模板 |
| POST | `/finance/upstream/settle/batch-import` | 批量导入结算 |
| GET | `/finance/pending-rate/list` | 跟单队列分页查询 |
| PUT | `/finance/pending-rate/{id}/fill-rate` | 填入手续费（单条） |
| POST | `/finance/pending-rate/batch-fill` | 批量导入手续费 |
| PUT | `/finance/pending-rate/{id}/skip` | 标记跳过 |
| GET/PUT | `/finance/pending-rate/config` | 超期配置读取/修改 |

### 合格结算接口（V13）

| Method | Path | 说明 |
|--------|------|------|
| GET | `/finance/qualify/rule/list` | 合格认定规则列表 |
| POST | `/finance/qualify/rule/save` | 保存认定规则 |
| GET | `/finance/qualify/summary` | 合格汇总数据 |
| POST | `/finance/reconcile-bill/generate` | 生成合格对账单 |
| GET | `/finance/reconcile-bill/page` | 对账单列表 |
| POST | `/finance/reconcile-bill/{id}/confirm` | 确认到账 |
| POST | `/finance/reconcile-bill/{id}/unlock` | 解锁对账单 |

### 导出模板接口（V13）

| Method | Path | 说明 |
|--------|------|------|
| GET | `/finance/export-template/page` | 模板列表 |
| POST | `/finance/export-template/save` | 新增/编辑模板 |
| DELETE | `/finance/export-template/{id}` | 删除模板 |
| GET | `/finance/export-template/car/fields` | 车险可选字段列表 |
| GET | `/finance/export-template/non-car/fields` | 非车险可选字段列表 |
| GET | `/finance/export-template/{id}/preview` | 模板预览 |
| POST | `/car/policy/export` | 车险保单导出（使用模板） |
| POST | `/non-car/policy/export` | 非车险保单导出 |

### 结算管理接口

| Method | Path | 说明 |
|--------|------|------|
| GET | `/finance/settlement/page` | 结算单分页列表 |
| POST | `/finance/settlement/generate` | 手动生成结算单 |
| POST | `/finance/settlement/{id}/submit` | 提交审核 |
| GET | `/finance/settlement/{id}/detail` | 结算单详情（含明细） |
| POST | `/finance/settlement/approve` | 审核操作（Activiti） |
| GET | `/finance/invoice/page` | 发票分页列表 |
| POST | `/finance/invoice/apply` | 申请开票 |
| POST | `/finance/invoice/{id}/upload` | 上传发票文件 |
| POST | `/finance/invoice/{id}/void` | 发票作废 |
| GET | `/finance/payment/page` | 打款批次列表 |
| POST | `/finance/payment/initiate` | 发起打款 |
| GET | `/finance/payment/{batchId}/file` | 下载批量付款文件 |
| POST | `/finance/payment/{batchId}/confirm` | 确认打款完成 |

### 税务管理接口

| Method | Path | 说明 |
|--------|------|------|
| GET | `/finance/tax/calc/page` | 个税计算列表 |
| POST | `/finance/tax/calc/{id}/adjust` | 人工调整个税 |
| GET | `/finance/tax/declare/page` | 税务申报列表 |
| POST | `/finance/tax/declare/generate` | 生成申报文件 |
| POST | `/finance/tax/declare/{id}/mark-declared` | 标记已申报 |
| GET | `/finance/tax/certificate/page` | 完税证明列表 |
| POST | `/finance/tax/certificate/{id}/generate` | 生成完税证明PDF |
| POST | `/finance/tax/certificate/{id}/send-email` | 发送完税证明邮件 |

### BI报表接口

| Method | Path | 说明 |
|--------|------|------|
| GET | `/finance/bi/dashboard` | 经营看板数据 |
| GET | `/finance/bi/premium/stat` | 保费统计 |
| GET | `/finance/bi/commission/stat` | 佣金分析 |
| GET | `/finance/bi/agent/stat` | 人力分析 |
| GET | `/finance/bi/channel/stat` | 渠道分析 |
| POST | `/finance/bi/custom/query` | 自定义报表查询 |
| GET | `/finance/bi/custom/export` | 自定义报表导出 |
| GET | `/finance/bi/custom/config/list` | 我的报表配置列表 |
| POST | `/finance/bi/custom/config/save` | 保存报表配置 |

### 监管报表接口

| Method | Path | 说明 |
|--------|------|------|
| GET | `/finance/regulatory/ledger/page` | 业务台账列表 |
| POST | `/finance/regulatory/ledger/generate` | 生成台账 |
| POST | `/finance/regulatory/ledger/{id}/mark-reported` | 标记已上报 |
| GET | `/finance/regulatory/report/page` | 数据上报记录列表 |
| POST | `/finance/regulatory/report/upload` | 发起数据上报 |
| POST | `/finance/regulatory/report/{id}/retry` | 重试上报 |
| GET | `/finance/regulatory/archive/page` | 归档列表 |
| POST | `/finance/regulatory/archive/{id}/archive` | 归档操作 |

---

## 十二、数据库表设计总览

**数据库Schema：`db_ins_finance`，表前缀：`ins_fin_`**

### Part 1 — 自动对账模块（11张表）

| 序号 | 表名 | 业务说明 |
|------|------|---------|
| 1 | `ins_fin_import_batch` | 保司Excel导入批次（含匹配进度） |
| 2 | `ins_fin_import_detail` | 导入明细（逐条保单数据，记录匹配状态） |
| 3 | `ins_fin_reconcile_diff` | 差异记录（保费/佣金/日期差异，人工处理） |
| 4 | `ins_fin_upstream_settle` | 上游结算主表（按保司聚合，需审批） |
| 5 | `ins_fin_upstream_settle_detail` | 上游结算明细（每条保单的结算数据） |
| 6 | `ins_fin_qualify_rule_config` | 合格认定规则配置 |
| 7 | `ins_fin_qualify_record` | 合格认定审计记录（合格/撤销操作轨迹） |
| 8 | `ins_fin_reconcile_bill` | 合格对账单主表（按保司+周期汇总） |
| 9 | `ins_fin_reconcile_bill_detail` | 合格对账单明细（每条保单手续费） |
| 10 | `ins_fin_reconcile_diff_amount` | 对账差额记录（实际到账差额标注） |
| 11 | `ins_fin_qualified_order` | 上游手续费跟单队列（无费率保单暂挂） |

### Part 2 — 结算管理 + 税务管理 + 监管报表（11张表）

| 序号 | 表名 | 业务说明 |
|------|------|---------|
| 12 | `ins_fin_settlement` | 结算单主表（业务员月度佣金结算，含审核流） |
| 13 | `ins_fin_settlement_detail` | 结算单明细（每张保单的佣金明细） |
| 14 | `ins_fin_payment_batch` | 打款批次表（批量发起打款） |
| 15 | `ins_fin_payment_detail` | 打款明细（每张结算单的打款结果） |
| 16 | `ins_fin_invoice` | 发票管理（开票申请，支持电子发票API） |
| 17 | `ins_fin_tax_record` | 个税计算记录（劳务报酬预扣率法） |
| 18 | `ins_fin_tax_declare_batch` | 税务申报批次（月度代扣个税申报文件） |
| 19 | `ins_fin_tax_certificate` | 完税证明（月度/年度PDF，可邮件发送） |
| 20 | `ins_fin_regulatory_ledger` | 监管业务台账（按月生成，标记上报） |
| 21 | `ins_fin_regulatory_report` | 监管API上报记录（含请求响应报文） |
| 22 | `ins_fin_report_archive` | 报表归档管理（OSS加锁，保存7年） |

### Part 3 — 导出模板 + BI配置（5张表）

| 序号 | 表名 | 业务说明 |
|------|------|---------|
| 23 | `ins_fin_export_template` | 导出模板主表（车险/非车险字段模板） |
| 24 | `ins_fin_export_template_field` | 模板字段配置（列名/顺序/格式） |
| 25 | `ins_fin_export_field_config` | 字段元数据字典（后端预置全量可选字段） |
| 26 | `ins_fin_export_history` | 导出历史记录（含文件路径和过期时间） |
| 27 | `ins_fin_bi_report_config` | BI自定义报表配置（用户保存的查询参数） |

**合计：27张表**

---

## 十三、开发工时估算

> 工时按 1前端 + 1后端 配置，单位：人天

### 阶段6-财务中台（原有功能）

| 模块 | 功能点 | 前端（天） | 后端（天） | 合计（天） |
|------|--------|----------|----------|----------|
| 自动对账 | 保单导入 | 2.5 | 3.0 | 5.5 |
| 自动对账 | 智能匹配引擎 | 0.5 | 4.0 | 4.5 |
| 自动对账 | 差异标记 | 2.0 | 2.0 | 4.0 |
| 自动对账 | 人工处理 | 2.5 | 2.0 | 4.5 |
| 自动对账 | 对账报表 | 2.0 | 2.0 | 4.0 |
| 结算管理 | 结算单生成 | 1.0 | 3.0 | 4.0 |
| 结算管理 | 结算审核（Activiti） | 2.5 | 3.0 | 5.5 |
| 结算管理 | 发票管理 | 2.5 | 3.0 | 5.5 |
| 结算管理 | 打款管理 | 2.0 | 3.0 | 5.0 |
| 税务管理 | 个税计算 | 1.0 | 2.5 | 3.5 |
| 税务管理 | 税务申报 | 1.5 | 2.0 | 3.5 |
| 税务管理 | 完税证明 | 1.0 | 1.5 | 2.5 |
| BI报表 | 经营看板 | 3.0 | 2.5 | 5.5 |
| BI报表 | 保费统计 | 2.5 | 2.0 | 4.5 |
| BI报表 | 佣金分析 | 2.5 | 2.0 | 4.5 |
| BI报表 | 人力分析 | 2.5 | 2.0 | 4.5 |
| BI报表 | 渠道分析 | 2.5 | 2.0 | 4.5 |
| BI报表 | 自定义报表 | 3.0 | 3.5 | 6.5 |
| 监管报表 | 业务台账 | 2.5 | 3.0 | 5.5 |
| 监管报表 | 数据上报 | 0.5 | 3.0 | 3.5 |
| 监管报表 | 报表归档 | 1.0 | 1.0 | 2.0 |
| **阶段6小计** | | **42.0** | **50.0** | **92.0** |

### 阶段6-合格结算补充（V13新增）

| 模块 | 功能点 | 前端（天） | 后端（天） | 合计（天） |
|------|--------|----------|----------|----------|
| 上游结算 | 批量修改上游手续费并结算（FN-01） | 2.0 | 2.5 | 4.5 |
| 上游结算 | 未填手续费跟单队列（FN-02） | 2.5 | 2.5 | 5.0 |
| 导出模板 | 合格-车险导出模板配置（FN-03） | 1.5 | 1.5 | 3.0 |
| 导出模板 | 合格-非车险导出模板配置（FN-04） | 1.0 | 1.0 | 2.0 |
| 合格结算 | 合格上游结算完整流程（FN-05） | 0.5 | 0.5 | 1.0 |
| **V13小计** | | **7.5** | **8.0** | **15.5** |

### 总计

| 分类 | 前端（天） | 后端（天） | 合计（天） |
|------|----------|----------|----------|
| 阶段6-财务中台 | 42.0 | 50.0 | 92.0 |
| 阶段6-合格结算补充（V13） | 7.5 | 8.0 | 15.5 |
| **总计（含20%缓冲）** | **59.4** | **69.6** | **129.0** |

---

## 附录：关联操作手册 PDF 索引

| PDF编号 | 功能说明 |
|--------|---------|
| PDF-171 | 财务-目录 |
| PDF-172 | 财务-财务明细管理 |
| PDF-173 | 财务-财务明细管理-批量匹配政策 |
| PDF-174 | 财务-财务明细管理-设置筛选条件及列表字段 |
| PDF-175 | 财务-财务明细管理-设置导出模板 |
| PDF-176 | 财务-上游结算-目录 |
| PDF-177 | 财务-上游结算-上游对账 |
| PDF-178 | 财务-上游结算-上游导入结算 |
| PDF-179 | 财务-上游结算-撤销上游结算 |
| PDF-180 | 财务-上游结算-批量修改上游手续费 |
| PDF-181 | 财务-上游结算-上游对账提示系统异常的排查步骤 |
| PDF-182 | 财务-下游对账 |
| PDF-183 | 财务-奖励结算 |
| PDF-184 | 财务-结算查询 |
| PDF-185 | 财务-财务配置-目录 |
| PDF-186 | 财务-财务配置-结算设置 |
| PDF-187 | 财务-财务配置-公司卡管理 |
| PDF-188 | 财务-财务配置-添加发票抬头 |
| PDF-189 | 财务-财务配置-设置财务表格模板 |
| PDF-190 | 财务-业财转换（1） |
| PDF-191 | 财务-业财转换（2） |

---

*文档结束 · 本PRD文档覆盖财务模块全部功能点，如有疑问请联系技术负责人*

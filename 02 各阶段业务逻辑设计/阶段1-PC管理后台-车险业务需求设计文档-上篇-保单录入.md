# 阶段1 · PC管理后台 · 车险业务需求设计文档【上篇：保单录入】

> 版本：V1.0 | 对应排期表 Sheet：`阶段1-PC管理后台-车险业务` | 前端工时：32天 | 后端工时：32天

---

## 文档说明

本文档面向开发人员，直接描述每个功能的业务逻辑、字段规则、校验逻辑、后端处理步骤和数据库写入情况，不做技术选型解释。整体分为**上篇（保单录入）**、**中篇（保单查询与设置）**、**下篇（报表与统计分析）**三个文档。

技术栈约定：框架 `yudao-cloud`（Spring Cloud Alibaba），数据库 MySQL 8.x + MyBatis Plus，缓存 Redis，MQ RocketMQ，Excel 处理 EasyExcel，文件存储 OSS/MinIO。

---

## 一、保单录入模块

> 菜单路径：车险 → 保单管理 → 保单录入

### 1.1 保单录入（手工单笔录入）

#### 页面入口

进入菜单后，默认展示**单笔录入**选项卡。页面顶部有两个 Tab：「单笔录入」「批量录入」，默认激活单笔录入。

#### 录入表单字段

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| 保险公司 | 下拉 | ✅ | 从已配置保司列表获取 |
| 出单工号 | 下拉 | ✅ | 根据所选保险公司联动过滤，只展示该保司下已配置且有效的工号 |
| 业务员 | 人员选择器 | ✅ | 从组织架构人员中选择 |
| 出单员 | 人员选择器 | 否 | 可为空，表示与业务员相同 |
| 险种类型 | 单选 | ✅ | 交强险 / 商业险 / 交商合并 |
| 保单号 | 文本 | ✅ | 根据保单设置中配置的格式规则做前端正则校验 |
| 车牌号 | 文本 | 否 | 允许新能源车牌格式 |
| VIN 码 | 文本 | 否 | 17 位字母数字 |
| 车型 | 文本 | 否 | 车辆品牌+型号描述 |
| 保费（交强） | 金额 | 条件必填 | 险种含交强险时必填，单位元，保留两位小数 |
| 保费（商业） | 金额 | 条件必填 | 险种含商业险时必填 |
| 车船税 | 金额 | 否 | 允许为 0 |
| 签单日期 | 日期 | ✅ | 不能晚于今天 |
| 支付日期 | 日期 | 否 | 允许为空；不早于签单日期 |
| 起保日期 | 日期 | ✅ | |
| 保险止期 | 日期 | ✅ | 必须晚于起保日期 |
| 录入方式 | 单选 | ✅ | 直连 / 手工；默认手工 |
| 业务来源 | 下拉 | 否 | 直销 / 转介绍 / 网销 / 电销 等（字典表 `ins_dict_business_source`） |
| 产品备注 | 文本 | 否 | 自定义备注 |

#### 前端交互

1. 选择保险公司后，出单工号下拉列表自动刷新，只展示该保司下状态为「启用」的工号。
2. 险种类型选择影响保费字段必填状态：选「交强险」则交强险保费必填、商业险保费隐藏；选「商业险」则商业险保费必填、交强险保费隐藏；选「交商合并」则两个保费字段均必填。
3. 提交时前端做基础格式校验（保单号正则、日期合法性、金额非负）。
4. 提交成功后弹出提示框：「保存成功，是否继续录入下一张？」
   - 点击「继续录入」：清空表单（保留保险公司、工号、业务员、出单员的上次填写值），进入快速录入模式。
   - 点击「返回列表」：跳转到保单查询列表页。

#### 后端校验（`AdminInsCarPolicyController.create`）

1. **重复保单拦截**：查询 `insurance_car_policy` 表，条件 `policy_no = #{policyNo} AND insurance_company_id = #{insuranceCompanyId} AND is_deleted = 0`，若存在则返回错误 `保单号[xxx]在该保司下已存在，请勿重复录入`。联合唯一索引：`uk_policy_no_company`。
2. **工号与保司匹配**：验证所选出单工号 `ins_company_no_id` 的 `company_id` 与所选保险公司一致，否则返回 `所选工号不属于该保险公司`。
3. **签单日期在政策有效期内**：查询匹配的佣金政策（`ins_car_policy_rule`），若签单日期不在任何有效政策区间内，返回 `当前签单日期无匹配佣金政策，请先配置政策后录入`（警告级别，允许强制保存）。
4. **日期逻辑校验**：支付日期 ≥ 签单日期，保险止期 > 起保日期。

#### 数据库写入

保存成功后写入 `insurance_car_policy` 表，核心字段如下：

```sql
INSERT INTO insurance_car_policy (
  id, tenant_id, merchant_id,
  insurance_company_id, company_no_id,
  salesman_id, issuer_id,
  policy_type,          -- 险种类型：1交强 2商业 3交商
  policy_no,            -- 保单号
  plate_no, vin_code, car_model,
  premium_compulsory,   -- 交强险保费
  premium_commercial,   -- 商业险保费
  vehicle_tax,          -- 车船税
  sign_date, pay_date, start_date, end_date,
  entry_type,           -- 录入方式：1直连 2手工
  business_source,
  policy_remark,
  status,               -- 1正常
  is_deleted,           -- 0
  creator, create_time, updater, update_time
)
```

写入后，**异步触发佣金匹配计算**：发送 RocketMQ 消息 `ins_car_policy_created`，消费者 `InsCarCommissionCalculateConsumer` 执行：
- 根据 `company_no_id + sign_date` 匹配 `ins_car_commission_rule` 表的政策规则，计算应收佣金。
- 写入 `ins_car_commission_record` 表（状态：待结算）。

---

### 1.2 录单问题排查步骤（辅助功能）

#### 触发场景

在保单录入时，若调用保司 API 获取保单信息失败，或手工录入保存失败，右侧或弹窗展示**录单问题排查引导**面板。

#### 排查步骤展示逻辑（分步引导 UI）

系统展示 3 步排查流程，用户按步骤操作：

**Step 1：工号状态检查**
- 系统自动调用工号健康检测接口，检查当前所选工号在保司系统的登录状态。
- 若工号异常（未配置 / 已过期 / 被锁定），显示具体原因：`工号[xxx]状态异常：[原因]，请联系管理员重新配置`。

**Step 2：保单号格式检查**
- 验证保单号是否符合该保司的格式规则（从 `ins_company_policy_rule` 获取正则）。
- 若不符合，显示该保司正确的保单号格式示例。

**Step 3：签单日期政策检查**
- 检查签单日期是否在任意有效政策区间内。
- 若无匹配政策，显示：`当前日期[xxx]无匹配政策，请到 车险-政策管理 配置政策后重试`。

#### 异常日志记录

录单失败时，后端记录 `ins_car_entry_error_log` 表：
```sql
(merchant_id, company_no_id, policy_no, sign_date, error_type, error_msg, create_time)
```
`error_type`：1=工号异常，2=保单号格式错误，3=政策缺失，4=API调用失败，5=其他。

#### 操作按钮

- 【复制异常信息】：将当前错误描述文本复制到剪贴板，供内勤发送给业务员。

---

### 1.3 保单号/车牌号批量录入

#### 页面入口

点击单笔录入页面顶部 Tab「批量录入」，进入批量录入页面。

#### 操作流程

**第一步：填写公共信息**
- 出单工号（必填，下拉）
- 业务员（必填，人员选择器）
- 出单员（选填）

**第二步：输入保单号/车牌号**
- 文本域输入框，提示语：`每行一个保单号或车牌号，也可用英文逗号分隔`。
- 支持换行和英文逗号两种分隔方式，前端解析后去重、去空格。
- 单次最多输入 20 个（前端校验，超出提示 `单次最多批量录入 20 条，当前输入 [n] 条`）。

**第三步：获取保单信息**
- 点击【获取保单信息】按钮，前端 loading 状态。
- 后端并发调用保司 API（限流：max 20 并发，超时 10s/条），返回预览表格。
- 预览表格展示字段：序号、保单号/车牌号（输入值）、保险公司、保单号（API返回）、车牌号、被保险人、险种、保费、获取状态。
- 获取失败的条目，状态列显示红色原因：`工号不匹配 / 保单不存在 / 网络超时`，该行可点击【单条重试】。

**第四步：确认保存**
- 预览表格下方展示统计：成功 n 条 / 失败 m 条。
- 点击【确认保存】，只保存状态为「成功」的条目。
- 失败条目不影响成功条目保存，用户可在保存后对失败条目单条重试后再次保存。

#### 后端处理

1. 接口 `POST /ins/car/policy/batch-fetch`：接收工号ID + 保单号/车牌号数组，并发调用保司 API，返回每条的解析结果。限流通过 Redis + Semaphore 控制，单次并发不超过 20。
2. 接口 `POST /ins/car/policy/batch-save`：接收预览结果中用户确认的条目数组。逐条执行与单笔录入相同的唯一性校验和佣金触发逻辑。失败条目单独返回失败原因，成功条目正常写库。
3. **防重录**：批量保存前先通过 `policy_no + company_id` 联合查询已有记录，过滤已录入保单并在返回结果中标注 `已录入`。

---

### 1.4 批单录入

#### 页面入口

菜单：车险 → 保单管理 → 批单录入（独立菜单项，也可从保单详情页跳入）。

#### 操作流程

**方式一：手工单条录入**

表单字段：

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| 原保单号 | 文本+搜索 | ✅ | 输入后触发模糊搜索，从 `insurance_car_policy` 中查找，选中后自动带出原保单信息 |
| 批改类型 | 下拉 | ✅ | 增保 / 减保 / 地址变更 / 信息变更 / 批量退保 |
| 批改原因 | 文本 | ✅ | 最大 200 字 |
| 批改日期 | 日期 | ✅ | 不能早于原保单签单日期 |
| 批单号 | 文本 | ✅ | 批改保单的新单号 |
| 批改保费变动 | 金额 | 条件必填 | 增保/减保类型时必填；正数=增保，负数=减保 |
| 批改后保费 | 金额（展示） | — | 系统自动计算：原保费 + 批改保费变动 |

前端交互：
- 选中原保单号后，自动回填：保险公司、工号、业务员、原始保费。
- 批改类型选「地址变更」或「信息变更」时，批改保费变动字段置灰不可输入（默认为 0）。
- 提交前展示批改摘要确认弹窗：原保费 → 批改后保费。

后端处理：
1. 验证原保单 `policy_no` 在本商户下存在且状态正常（`is_deleted=0 AND status=1`）。
2. 验证批单号唯一性（同保司下不重复）。
3. 批改保费变动不为 0 时，联动重算佣金：发送 MQ 消息 `ins_car_endorsement_created`，消费者重新计算该保单的佣金差额，写入 `ins_car_commission_record`（类型：批改调整）。
4. 写入 `insurance_car_endorsement` 表：
```sql
(id, policy_id, endorsement_no, endorsement_type, endorsement_reason,
 endorsement_date, premium_change, premium_after, status, creator, create_time)
```

**方式二：批量导入批单**

1. 点击【下载批单导入模板】，返回 Excel 模板（EasyExcel 动态生成，含示例行）。
2. 模板字段：原保单号、批单号、批改类型、批改原因、批改日期、批改保费变动。
3. 上传 Excel 文件 → 后端 EasyExcel 解析 → 返回预览结果（正常行数/错误行数/错误原因列表）。
4. 用户确认后异步写库，写库结果通过站内信通知（成功 n 条，失败 m 条，可下载失败明细）。

---

## 二、数据库主要表结构参考

### `insurance_car_policy`（车险保单主表）

```sql
CREATE TABLE `insurance_car_policy` (
  `id`                    BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`             BIGINT       NOT NULL COMMENT '租户ID',
  `merchant_id`           BIGINT       NOT NULL COMMENT '商户ID',
  `insurance_company_id`  BIGINT       NOT NULL COMMENT '保险公司ID',
  `company_no_id`         BIGINT       NOT NULL COMMENT '出单工号ID',
  `salesman_id`           BIGINT       NOT NULL COMMENT '业务员ID',
  `issuer_id`             BIGINT                COMMENT '出单员ID',
  `policy_type`           TINYINT      NOT NULL COMMENT '险种类型 1交强 2商业 3交商',
  `policy_no`             VARCHAR(64)  NOT NULL COMMENT '保单号',
  `plate_no`              VARCHAR(20)           COMMENT '车牌号',
  `vin_code`              VARCHAR(17)           COMMENT '车架号',
  `car_model`             VARCHAR(100)          COMMENT '车型',
  `premium_compulsory`    DECIMAL(12,2) DEFAULT 0 COMMENT '交强险保费',
  `premium_commercial`    DECIMAL(12,2) DEFAULT 0 COMMENT '商业险保费',
  `vehicle_tax`           DECIMAL(10,2) DEFAULT 0 COMMENT '车船税',
  `sign_date`             DATE         NOT NULL COMMENT '签单日期',
  `pay_date`              DATE                  COMMENT '支付日期',
  `start_date`            DATE         NOT NULL COMMENT '起保日期',
  `end_date`              DATE         NOT NULL COMMENT '保险止期',
  `entry_type`            TINYINT      NOT NULL DEFAULT 2 COMMENT '录入方式 1直连 2手工',
  `business_source`       VARCHAR(20)           COMMENT '业务来源',
  `policy_remark`         VARCHAR(500)          COMMENT '产品备注',
  `import_batch_id`       BIGINT                COMMENT '批量导入批次ID',
  `region_province`       VARCHAR(50)           COMMENT '省份（区域分析用）',
  `region_city`           VARCHAR(50)           COMMENT '城市',
  `is_new_car`            TINYINT      DEFAULT 0 COMMENT '是否新车 0旧车 1新车',
  `status`                TINYINT      DEFAULT 1 COMMENT '状态 1正常 2已批改 3已退保',
  `is_deleted`            TINYINT      DEFAULT 0,
  `creator`               BIGINT,
  `create_time`           DATETIME,
  `updater`               BIGINT,
  `update_time`           DATETIME,
  UNIQUE KEY `uk_policy_no_company` (`policy_no`, `insurance_company_id`, `merchant_id`),
  KEY `idx_merchant_sign_date` (`merchant_id`, `sign_date`),
  KEY `idx_salesman` (`salesman_id`),
  KEY `idx_import_batch` (`import_batch_id`)
) ENGINE=InnoDB COMMENT='车险保单主表';
```

### `insurance_car_endorsement`（批单表）

```sql
CREATE TABLE `insurance_car_endorsement` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT,
  `policy_id`        BIGINT       NOT NULL COMMENT '关联主保单ID',
  `policy_no`        VARCHAR(64)  NOT NULL COMMENT '原保单号',
  `endorsement_no`   VARCHAR(64)  NOT NULL COMMENT '批单号',
  `endorsement_type` TINYINT      NOT NULL COMMENT '1增保 2减保 3地址变更 4信息变更 5批量退保',
  `endorsement_reason` VARCHAR(200),
  `endorsement_date` DATE         NOT NULL,
  `premium_change`   DECIMAL(12,2) DEFAULT 0 COMMENT '保费变动金额',
  `premium_after`    DECIMAL(12,2)            COMMENT '批改后保费',
  `status`           TINYINT      DEFAULT 1,
  `is_deleted`       TINYINT      DEFAULT 0,
  `creator`          BIGINT,
  `create_time`      DATETIME,
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  UNIQUE KEY `uk_endorsement_no` (`endorsement_no`, `merchant_id`)
) ENGINE=InnoDB COMMENT='车险批单表';
```

### `ins_car_entry_error_log`（录单异常日志）

```sql
CREATE TABLE `ins_car_entry_error_log` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT,
  `merchant_id`    BIGINT       NOT NULL,
  `company_no_id`  BIGINT                COMMENT '工号ID',
  `policy_no`      VARCHAR(64)           COMMENT '尝试录入的保单号',
  `sign_date`      DATE,
  `error_type`     TINYINT               COMMENT '1工号异常 2格式错误 3政策缺失 4API失败 5其他',
  `error_msg`      VARCHAR(500),
  `create_time`    DATETIME,
  PRIMARY KEY (`id`),
  KEY `idx_merchant_time` (`merchant_id`, `create_time`)
) ENGINE=InnoDB COMMENT='录单异常日志';
```

---

## 三、API 接口清单（保单录入模块）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/admin-api/ins/car/policy/create` | 手工单笔录入保存 |
| POST | `/admin-api/ins/car/policy/batch-fetch` | 批量获取保单信息（调保司API） |
| POST | `/admin-api/ins/car/policy/batch-save` | 批量保存确认 |
| POST | `/admin-api/ins/car/endorsement/create` | 手工单条批单录入 |
| POST | `/admin-api/ins/car/endorsement/import` | 批单 Excel 导入 |
| GET  | `/admin-api/ins/car/entry-log/page` | 录单异常日志分页查询 |

---

*下一篇：【中篇】保单查询 · 保单设置*

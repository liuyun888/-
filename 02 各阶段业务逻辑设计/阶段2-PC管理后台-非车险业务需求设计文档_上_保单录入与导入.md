# 非车险业务需求设计文档（上）
## 阶段2 - PC管理后台 - 非车险业务
### 模块：保单管理（录入/导入）

---

## 一、非车保单录入（手工单笔）

### 1.1 入口

导航：【非车】→【保单管理】→【保单录入】，点击【新增保单】按钮，弹出保单录入表单页（全屏或大弹窗）。

---

### 1.2 表单字段说明

#### 基本信息（必填项标 `*`）

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| 保险公司 * | 下拉选择 | 是 | 从系统保司字典加载，联动工号/政策匹配 |
| 标的标识 * | 单选：车辆 / 人 / 物品 | 是 | 控制后续表单展示结构（见下方分支逻辑） |
| 标的名称 | 文本 | 否 | 被保标的物名称 |
| 保(批)单号 * | 文本 | 是 | 与保险公司组成联合唯一索引，防止重录 |
| 险种编码 | 文本/下拉 | 否 | 与险种联动 |
| 险种 * | 下拉选择 | 是 | 加载非车险种字典 |
| 产品名称 * | 下拉选择 | 是 | **分支逻辑**：标的标识=车辆时，只能选择系统产品；标的标识=人或物品时，产品名称为自定义文本输入，不限于系统产品 |
| 互联网业务 | 单选：是/否 | 否 | - |
| 涉农业务 | 单选：是/否 | 否 | - |
| 保单状态 * | 下拉：正常/退保/批改/终止 | 是 | - |
| 签单日期 * | 日期选择 | 是 | - |
| 起保日期 * | 日期选择 | 是 | - |
| 保险止期 * | 日期选择 | 是 | 必须 >= 起保日期 |
| 支付日期 | 日期选择 | 否 | 用于政策匹配（日期类型=支付日期时使用） |
| 渠道名称 | 文本/下拉 | 否 | 业务来源渠道 |
| 业务员 * | 下拉/搜索选择 | 是 | 从人员管理加载，影响佣金归属 |
| 工号名称 | 下拉 | 否 | 需先在非车工号范围内配置，与政策匹配关联 |
| 出单员 | 文本/下拉 | 否 | - |
| 录入方式 | 下拉：手工录单/自动录单等 | 否 | - |
| 共保标识 * | 单选：是/否 | 是 | 选"是"时出现共保保司填写区域 |

#### 共保保司信息（共保标识=是时显示，标的标识=人或物品时支持）

- 可添加多家共保保险公司
- 每行：保险公司（必填）、保费比例（%）、共保保单号

#### 被保人信息（根据标的标识显示不同）

| 标的标识 | 显示内容 |
|----------|----------|
| 车辆 | 车主姓名、证件类型、证件号、车牌号、车架号、发动机号；车主/被保人可勾选"同投保人"自动填充 |
| 人 | 被保人姓名（支持添加多个被保人），每人：姓名、证件号、出生日期 |
| 物品 | 被保人姓名、证件号 |

> 注：**选车辆时，车主和被保人为必填关系人信息**。选人/物品时，被保人可为空或多人。

#### 投保人信息

- 投保人名称 *（必填）
- 证件类型
- 证件号
- 联系电话

#### 保单费用

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| 全保费 * | 金额数字 | 是 | 含税保费 |
| 净保费 * | 金额数字 | 是 | 不含税保费 |

#### 上游手续费

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| 上游保单手续费比例(%) | 数字 | 否 | 与政策匹配后自动回填，可手动覆盖 |
| 上游手续费金额 | 数字 | 否 | = 净保费 × 上游比例，系统自动计算 |
| 结算方式 | 下拉 | 否 | 上游结算方式 |

#### 下游手续费

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| 下游比例(%) | 数字 | 否 | 可跳过，后续补录 |
| 下游金额 | 数字 | 否 | = 净保费 × 下游比例，系统自动计算 |

---

### 1.3 保存逻辑

1. **前端校验**：所有 `*` 必填字段不为空；保险止期 >= 起保日期；手续费比例 >= 0。
2. **后端校验**：
   - 联合唯一索引校验：`保险公司 + 保(批)单号` 不可重复（特例：在【保单设置】中，若某险种开启了"相同保单号不同产品录入"，则同一保单号允许录入不同产品名称的保单）。
   - 业务员必须属于当前租户/机构下的有效人员。
3. **保存后触发政策匹配**：系统根据 `保险公司 + 险种 + 工号 + 日期（按政策日期类型取签单日期或支付日期）` 匹配最新有效的非车政策批次，自动回填上游手续费比例和金额。若无匹配政策，手续费字段保持手填值。
4. **数据入库**：写入 `ins_non_vehicle_policy` 主表 + 关系人信息子表（`ins_non_vehicle_insured`）+ 共保子表（`ins_non_vehicle_co_insurer`，如有）。

---

### 1.4 数据库设计

#### 主表：`ins_non_vehicle_policy`

```sql
CREATE TABLE `ins_non_vehicle_policy` (
  `id`                    BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `tenant_id`             BIGINT       NOT NULL COMMENT '租户ID',
  `insurance_company_id`  BIGINT       NOT NULL COMMENT '保险公司ID',
  `insurance_company_name` VARCHAR(100) NOT NULL COMMENT '保险公司名称',
  `policy_no`             VARCHAR(100) NOT NULL COMMENT '保(批)单号',
  `subject_type`          TINYINT      NOT NULL COMMENT '标的标识：1-车辆 2-人 3-物品',
  `subject_name`          VARCHAR(200) COMMENT '标的名称',
  `insurance_type_code`   VARCHAR(50)  COMMENT '险种编码',
  `insurance_type`        VARCHAR(100) NOT NULL COMMENT '险种',
  `product_id`            BIGINT       COMMENT '产品ID（标的=车辆时关联系统产品）',
  `product_name`          VARCHAR(200) NOT NULL COMMENT '产品名称（标的=人/物品时为自定义文本）',
  `is_internet`           TINYINT(1)   DEFAULT 0 COMMENT '互联网业务：0-否 1-是',
  `is_agriculture`        TINYINT(1)   DEFAULT 0 COMMENT '涉农业务：0-否 1-是',
  `policy_status`         TINYINT      NOT NULL COMMENT '保单状态：1-正常 2-退保 3-批改 4-终止',
  `sign_date`             DATE         NOT NULL COMMENT '签单日期',
  `start_date`            DATE         NOT NULL COMMENT '起保日期',
  `end_date`              DATE         NOT NULL COMMENT '保险止期',
  `payment_date`          DATE         COMMENT '支付日期',
  `channel_name`          VARCHAR(100) COMMENT '渠道名称',
  `salesperson_id`        BIGINT       NOT NULL COMMENT '业务员ID',
  `salesperson_name`      VARCHAR(100) NOT NULL COMMENT '业务员姓名',
  `work_no`               VARCHAR(100) COMMENT '工号名称',
  `issuer_id`             BIGINT       COMMENT '出单员ID',
  `issuer_name`           VARCHAR(100) COMMENT '出单员姓名',
  `input_type`            VARCHAR(50)  COMMENT '录入方式',
  `is_co_insured`         TINYINT(1)   DEFAULT 0 COMMENT '共保标识：0-否 1-是',
  `holder_name`           VARCHAR(200) NOT NULL COMMENT '投保人名称',
  `holder_cert_type`      VARCHAR(50)  COMMENT '投保人证件类型',
  `holder_cert_no`        VARCHAR(100) COMMENT '投保人证件号',
  `holder_phone`          VARCHAR(50)  COMMENT '投保人联系电话',
  `total_premium`         DECIMAL(18,4) NOT NULL COMMENT '全保费',
  `net_premium`           DECIMAL(18,4) NOT NULL COMMENT '净保费',
  `upstream_rate`         DECIMAL(8,4)  COMMENT '上游手续费比例(%)',
  `upstream_fee`          DECIMAL(18,4) COMMENT '上游手续费金额',
  `upstream_settle_type`  VARCHAR(50)  COMMENT '上游结算方式',
  `downstream_rate`       DECIMAL(8,4)  COMMENT '下游手续费比例(%)',
  `downstream_fee`        DECIMAL(18,4) COMMENT '下游手续费金额',
  `policy_batch_id`       BIGINT       COMMENT '匹配的政策批次ID',
  `org_id`                BIGINT       COMMENT '归属机构ID',
  `region`                VARCHAR(100) COMMENT '投保区域/省市',
  `business_source`       VARCHAR(100) COMMENT '业务来源',
  `import_batch_no`       VARCHAR(100) COMMENT '批量导入批次号（手工录入时为空）',
  `remark`                VARCHAR(500) COMMENT '备注',
  `creator`               BIGINT       COMMENT '创建人',
  `create_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`               BIGINT       COMMENT '更新人',
  `update_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`               TINYINT(1)   DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_company_policy_no` (`tenant_id`, `insurance_company_id`, `policy_no`, `product_id`) COMMENT '联合唯一索引'
) ENGINE=InnoDB COMMENT='非车险保单主表';
```

#### 被保人子表：`ins_non_vehicle_insured`

```sql
CREATE TABLE `ins_non_vehicle_insured` (
  `id`           BIGINT       NOT NULL AUTO_INCREMENT,
  `policy_id`    BIGINT       NOT NULL COMMENT '关联非车保单ID',
  `insured_type` TINYINT      COMMENT '1-车主 2-被保人 3-投保人',
  `name`         VARCHAR(200) NOT NULL COMMENT '姓名',
  `cert_type`    VARCHAR(50)  COMMENT '证件类型',
  `cert_no`      VARCHAR(100) COMMENT '证件号',
  `birthday`     DATE         COMMENT '出生日期（人身险）',
  `plate_no`     VARCHAR(50)  COMMENT '车牌号（车辆时）',
  `vin`          VARCHAR(100) COMMENT '车架号',
  `engine_no`    VARCHAR(100) COMMENT '发动机号',
  `create_time`  DATETIME     DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB COMMENT='非车险被保人/关系人子表';
```

#### 共保子表：`ins_non_vehicle_co_insurer`

```sql
CREATE TABLE `ins_non_vehicle_co_insurer` (
  `id`                    BIGINT       NOT NULL AUTO_INCREMENT,
  `policy_id`             BIGINT       NOT NULL COMMENT '关联非车保单ID',
  `co_company_id`         BIGINT       NOT NULL COMMENT '共保保险公司ID',
  `co_company_name`       VARCHAR(100) NOT NULL,
  `co_policy_no`          VARCHAR(100) COMMENT '共保保单号',
  `co_premium_ratio`      DECIMAL(8,4) COMMENT '共保保费比例(%)',
  `create_time`           DATETIME     DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB COMMENT='非车险共保信息子表';
```

---

## 二、非车批单录入

### 2.1 入口

导航：【非车】→【保单管理】→【保单录入】，切换到【批单录入】Tab，或在保单查询列表中对指定保单点击【录入批单】。

---

### 2.2 操作流程

1. **输入原保单号**：在「原保单号」输入框粘贴/输入原非车保单的保(批)单号，点击【查询】或失焦时自动触发：后端根据 `tenant_id + 原保单号` 查询 `ins_non_vehicle_policy`，回填以下信息（只读展示）：
   - 保险公司名称
   - 险种
   - 关联产品名称
   - 原保单净保费
   - 原保单上游手续费比例
2. **填写批改信息**：

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| 批改类型 * | 下拉：增保/减保/变更被保标的/其他 | 是 | - |
| 批改保单号 * | 文本 | 是 | 如：原保单号-001 |
| 批改日期 * | 日期 | 是 | 批改生效日期，同时更新支付日期 |
| 支付日期 * | 日期 | 是 | 需改为批改日期，用于对账 |
| 批改保费差额 * | 金额（可负数） | 是 | 增保填正数（如200），退保填负数（如-500），单位：元 |
| 批改后净保费差额 | 金额（可负数） | 否 | 自动 = 批改保费差额（若不做价税分离处理） |

3. **手续费重算**：当批改保费差额 ≠ 0 时，系统自动重算：
   - 上游手续费差额 = 批改后净保费差额 × 原保单上游手续费比例
   - 下游手续费差额 = 批改后净保费差额 × 原保单下游手续费比例
   - 以上计算结果展示给用户确认，用户可手动修改。
4. **保存**：批单与原保单关联存储，写入 `ins_non_vehicle_policy` 表（`policy_status=3`，`original_policy_no` 关联原保单），同时原保单净保费和手续费按差额累加更新（或通过批改记录汇总计算）。

---

### 2.3 批改历史

在保单查询列表中，点击某张保单的【批改历史】，弹窗展示该保单的所有批改记录，按批改日期降序排列，字段：批改保单号、批改类型、批改日期、保费差额、操作人、操作时间。

> 数据库：`ins_non_vehicle_policy` 中通过 `original_policy_no` 字段关联，查询 `WHERE original_policy_no = ? AND policy_status = 3` 获取批改历史。

---

## 三、非车保单批量导入（Excel）

### 3.1 入口

导航：【非车】→【保单管理】→【保单查询】→点击【保单批量导入】按钮（或【导入】）。

---

### 3.2 完整操作流程

#### Step 1：下载导入模板
- 点击【下载导入模板】，弹出模板选择弹窗，展示当前租户在【非车-系统设置-模板设置】中已配置的导入模板列表。
- 选中对应险种模板后下载 Excel 文件。
- Excel 文件包含两个 Sheet：
  - **sheet1**：数据录入区，第一行为字段表头（红色标注为必填字段），从第二行开始录入数据。
  - **sheet2**：导入字段说明/示例，每个字段的填写规范和枚举值参考。

#### Step 2：填写数据
- 用户按照 sheet1 表头填写非车保单数据。
- **关键注意**：「险种类别」和「产品名称」字段的值必须与系统中【非车-系统设置-产品管理】内的数据**完全一致**（包括全角/半角、空格）。

#### Step 3：上传文件
- 回到系统，点击【请选择要导入的数据文件】或拖拽上传 Excel 文件。
- 文件格式：`.xlsx` 或 `.xls`，大小限制 10MB。

#### Step 4：预解析与预览
- 上传后系统异步触发预解析（使用 EasyExcel）：
  1. **格式验证**：必填字段是否为空、日期格式是否为 `yyyy-MM-dd`、金额是否为数字。
  2. **险种/产品名称精确匹配校验**：读取 sheet1 中的「险种类别」和「产品名称」，与系统产品库（`ins_non_vehicle_product`）做精确匹配。不一致则标记该行错误。
  3. **重复保单检查**：`保险公司 + 保(批)单号` 是否已存在于 `ins_non_vehicle_policy`（已存在则标记重复，跳过或报错）。
- 预解析完成后：若有错误，弹出预览窗，展示错误明细（行号+字段+错误原因）；若无错误，直接进入确认步骤。

#### Step 5：确认导入
- 用户确认无误后，点击【确认导入】，系统执行**异步批量写库**（MQ 或线程池处理）。
- 写库逻辑与手工录入一致，包括触发政策匹配、写入主表和子表。

#### Step 6：查看导入任务状态
- 导入提交后，用户可点击【任务列表】查看当前及历史导入任务：

| 列名 | 说明 |
|------|------|
| 任务ID | 批次号 |
| 导入时间 | 提交时间 |
| 总条数 | 文件总行数 |
| 成功条数 | 成功写库数 |
| 失败条数 | 校验/写库失败数 |
| 状态 | 处理中/成功/部分成功/失败 |
| 操作 | 【下载失败明细】 |

- 失败明细 Excel 包含：原始数据行 + 最后一列追加「错误原因」说明。

---

### 3.3 后端技术实现要点

- 使用 EasyExcel `ReadListener` 分批（每批 500 行）写库，避免大文件内存溢出。
- 创建导入任务记录表 `ins_import_task`，状态异步更新。
- 险种/产品名称校验：提前加载产品库到 Redis 缓存（`ins_non_vehicle_product` 全量 Hash），O(1) 查找。
- 失败行写入失败明细表 `ins_import_task_error`，支持下载。

---

## 四、非车导入失败排查辅助

> 此为页面引导功能，无独立路由，在导入失败时在错误弹窗底部展示「常见原因排查」折叠面板。

### 4.1 系统自动提示的错误类型与排查步骤

| 错误代码 | 错误提示 | 排查步骤 |
|----------|----------|----------|
| `ERR_PRODUCT_NOT_FOUND` | 产品与系统内的产品匹配不上 | ①确认表格中「产品名称」值；②到【非车】→【系统设置】→【产品管理】，分别在「系统产品」和「自定义产品」Tab搜索；③若找不到，点击【新增产品】添加后重新导入 |
| `ERR_TYPE_MISMATCH` | 险种和产品归属不匹配 | ①查看表格中「险种类别」与「产品名称」；②到产品管理查找产品，确认系统中该产品对应的险种类别；③以系统中的险种类别为准，更新表格后重新导入 |
| `ERR_DATE_FORMAT` | 日期格式错误 | 确认日期格式为 `yyyy-MM-dd`（如 `2024-01-15`），不能用 `/` 分隔 |
| `ERR_DUPLICATE` | 保单号重复 | 该保单已录入系统，如需修改请使用【批量更新信息】功能 |
| `ERR_TEMPLATE_OLD` | 模板版本不匹配 | 重新下载最新版本模板后填写 |
| `ERR_REQUIRED_EMPTY` | 必填字段为空 | 检查 sheet1 红色表头对应列是否有漏填 |

### 4.2 失败明细下载

任务列表中，点击失败任务的【下载失败明细】，下载含错误说明列的 Excel 文件，用户可在原文件基础上修正后重新上传。

---

## 五、相关接口清单（保单录入模块）

| 接口 | 方法 | 说明 |
|------|------|------|
| `/non-vehicle/policy/create` | POST | 手工新增非车保单 |
| `/non-vehicle/policy/update/{id}` | PUT | 编辑非车保单 |
| `/non-vehicle/policy/endorsement/create` | POST | 新增批单 |
| `/non-vehicle/policy/{id}/endorsement-history` | GET | 查询批改历史 |
| `/non-vehicle/policy/import/template/download` | GET | 下载导入模板 |
| `/non-vehicle/policy/import/upload` | POST | 上传导入文件 |
| `/non-vehicle/policy/import/task/list` | GET | 导入任务列表 |
| `/non-vehicle/policy/import/task/{taskId}/error/download` | GET | 下载失败明细 |
| `/non-vehicle/policy/match-policy` | POST | 触发/重新触发政策匹配（返回匹配到的上下游比例） |

---

*文档版本：V1.0 | 对应排期表：阶段2-PC管理后台-非车险业务 | 参考操作手册：86、87、88、93号*

# 阶段1 · PC管理后台 · 车险业务需求设计文档【补充篇：政策管理】

> 版本：V2.0（补充版）| 对应排期表 Sheet：`阶段1-PC管理后台-车险业务`  
> 对应操作手册：62 / 63 / 64 / 65 / 66 / 67 / 68 / 69 / 70 号  
> 技术栈：yudao-cloud（Spring Cloud Alibaba），MySQL 8.x，Redis，RocketMQ

---

## 文档说明

本文档为车险业务需求设计文档的补充篇，专项描述**车险政策管理**模块的完整业务逻辑，包括：基础政策管理、多级结算政策设置、加投/扣点政策、留点设置、预核保/报价提示、报价赋值政策。

---

## 六、政策管理模块

> 菜单路径：车险 → 政策管理

### 6.1 模块概述

政策管理是佣金计算的核心配置入口。保单录入后，系统根据政策规则（保司、工号、日期类型、承保条件）自动匹配佣金政策，计算上游收入和下游支出。

政策体系分为：
- **基础政策**：按承保条件匹配标准手续费/佣金点位。
- **附加政策（加投/奖励）**：在基础政策之上叠加的额外奖励点位。
- **扣点政策**：在基础政策之上扣减的点位。
- **留点政策**：多级结算中各层级负责人的留点配置。
- **禁止/提示类政策**：控制报价或核保阶段的限制提示。
- **报价赋值政策**：报价阶段自动填充特定字段的值。

---

### 6.2 政策管理主页面

#### 页面结构

- 左侧：保险公司选择器（下拉，选中后右侧展示该保司的政策批次列表）。
- 右侧：政策批次列表，列含：批次名称、政策类型、有效期、适用工号、状态（草稿/审核中/生效中/已过期/已停用）、操作（编辑/复制/停用/审批）。
- 右上角：**[新增政策批次]** 按钮。

#### 政策状态流转

```
草稿 → 审核中 → 生效中
                ↓
              已停用
```

- 新增后默认为「草稿」状态。
- 点击「保存并提交审批」，状态变为「审核中」。
- 审批通过后，状态变为「生效中」；当前日期超出有效期后自动变为「已过期」。
- 管理员可手动将「生效中」政策停用。

---

### 6.3 新增政策批次

#### 基础配置（弹窗第一步）

| 字段 | 必填 | 说明 |
|------|------|------|
| 保险公司 | ✅ | 选择对应保司 |
| 批次名称 | ✅ | 可自定义描述，如「2024年人保Q1基础政策」 |
| 政策类型 | ✅ | 下拉：基础政策 / 禁止报价 / 报价提示 / 禁止核保 / 核保提示 / 报价赋值 |
| 适用工号 | 否 | 多选；若不填则该保司下全部工号均可匹配 |
| 匹配日期类型 | ✅ | 支付日期 / 核保日期 / 签单日期 / 录入系统日期 / 单证打印日期 / 录入保司系统日期 |
| 有效期起 | ✅ | 政策生效起始日期 |
| 有效期止 | 否 | 若不填则永久有效（直到手动停用） |

**后端处理**：
1. 保存批次基础配置到 `ins_car_policy_rule_batch` 表（status=1草稿）。
2. 返回批次ID，前端进入政策条件配置页面。

#### 政策条件配置（类电子表格界面）

政策条件页面采用**类 Excel 电子表格**交互，行为政策行，列为承保条件维度 + 点位字段。

**操作说明**：
- **增加条件列**：点击表头上方的「+」图标，弹出「承保条件选择器」，从可用条件列表中勾选所需条件（如车龄、使用性质、座位数、NCD档位等），确认后追加到表头。
- **单元格名称设置**：点击条件列的列头单元格，可手动输入名称，或点击「填入名称」让系统根据已设置的承保条件内容自动生成名称。
- **设置承保条件**：右键单击数据行的条件单元格，弹出承保条件配置弹窗，勾选该格对应的条件值（如车龄：1年以内、1-3年、3-5年、5年以上）。
- **设置点位**：双击点位单元格，输入数值（支持小数点后两位），并可切换单位（%百分比 / 元 / 千分比）。
- **批量设置点位**：选中多行或多列，点击「批量设置」，可对选中区域统一增减点位（+0.5% 或 -0.3% 等）。
- **删除列**：点击列头右侧「垃圾桶」图标删除该条件列。

**可配置的承保条件维度**（前端从 `ins_car_condition_dict` 表获取可选项）：

| 条件类别 | 具体条件 |
|----------|----------|
| 车辆信息 | 车龄、座位数、排量、车辆用途/使用性质、新旧车、新能源类型 |
| 险种信息 | 险种类型（交强/商业）、险别组合 |
| 地区信息 | 投保省份、城市 |
| 客户信息 | 客户类型（个人/企业）、客户等级 |
| 保单信息 | 保费区间、保险期限、续保年数 |
| 特殊标识 | 是否含特约服务、是否商业车队 |

**点位类型配置**：每一行可在行首小扳手图标中设置当前行的点位类型：
- `基础点位`（默认）：标准佣金点位。
- `附加政策（加投/奖励）`：在基础点位之上叠加；附加政策支持匹配多条（多条均满足时累计叠加）。
- `扣点政策`：在基础点位之上扣减；扣点政策只能匹配一条（多条满足时只取一条）。
- 点位行右上角展示小标记区分类型（基础=无标记，附加=绿色「+」，扣点=红色「-」）。

**上下游分离配置**：
- 每一行同时配置**上游点位**（保司支付给机构）和**下游点位**（机构支付给业务员）。
- 两者需在表格的不同列中分别填写，不可混用。
- 注意：下游点位应为总下游点位（含负责人留点 + 业务员点位之和）。

---

### 6.4 政策审批

#### 审批流程

1. 政策配置完成后，点击【保存并提交审批】，政策状态变为「审核中」。
2. 审批人（管理员/具有审批权限的角色）在「政策管理 → 政策审批」列表中看到待审批记录。
3. 审批人点击【审批通过】，政策状态变为「生效中」，系统开始按该政策匹配保单。
4. 审批人点击【审批拒绝】，填写拒绝原因，政策状态回退为「草稿」，发站内信通知创建人。

#### 相关表

```sql
CREATE TABLE `ins_car_policy_rule_batch` (
  `id`                BIGINT      NOT NULL AUTO_INCREMENT COMMENT '批次ID',
  `merchant_id`       BIGINT      NOT NULL,
  `insurance_company_id` BIGINT   NOT NULL COMMENT '保险公司ID',
  `batch_name`        VARCHAR(100) NOT NULL COMMENT '批次名称',
  `policy_type`       TINYINT     NOT NULL COMMENT '1基础 2禁止报价 3报价提示 4禁止核保 5核保提示 6报价赋值',
  `match_date_type`   TINYINT     NOT NULL COMMENT '1支付日期 2核保日期 3签单日期 4录入日期 5打印日期 6录入保司',
  `valid_start`       DATE        NOT NULL COMMENT '有效期起',
  `valid_end`         DATE                 COMMENT '有效期止（NULL=永久）',
  `apply_no_ids`      JSON                 COMMENT '适用工号ID列表（NULL=全部工号）',
  `status`            TINYINT     DEFAULT 1 COMMENT '1草稿 2审核中 3生效中 4已过期 5已停用',
  `approve_id`        BIGINT               COMMENT '审批人ID',
  `approve_time`      DATETIME,
  `approve_remark`    VARCHAR(500),
  `creator`           BIGINT,
  `create_time`       DATETIME,
  `updater`           BIGINT,
  `update_time`       DATETIME,
  `deleted`           TINYINT     DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_merchant_company` (`merchant_id`, `insurance_company_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB COMMENT='车险政策批次表';
```

```sql
CREATE TABLE `ins_car_policy_rule_row` (
  `id`              BIGINT      NOT NULL AUTO_INCREMENT,
  `batch_id`        BIGINT      NOT NULL COMMENT '所属批次ID',
  `row_index`       INT         NOT NULL COMMENT '行序号（排序用）',
  `row_name`        VARCHAR(200)         COMMENT '行名称（自动生成或手动输入）',
  `row_type`        TINYINT     DEFAULT 1 COMMENT '1基础点位 2附加/奖励 3扣点',
  `conditions`      JSON        NOT NULL  COMMENT '承保条件JSON（key=条件编码, value=条件值数组）',
  `upstream_rate`   DECIMAL(8,4)          COMMENT '上游点位（%）',
  `upstream_amount` DECIMAL(12,2)         COMMENT '上游固定金额（元，与upstream_rate二选一）',
  `downstream_rate` DECIMAL(8,4)          COMMENT '下游点位（%）',
  `downstream_amount` DECIMAL(12,2)       COMMENT '下游固定金额（元）',
  `is_deleted`      TINYINT     DEFAULT 0,
  `create_time`     DATETIME,
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`)
) ENGINE=InnoDB COMMENT='车险政策规则行';
```

---

### 6.5 多级结算政策设置

#### 功能说明

多级结算用于机构/组织层级中，将下游点位按层级拆分给各级负责人和最终业务员。例如：总公司 → 分公司 → 营业部 → 业务员，各层级负责人均可获得留点收益。

#### 配置流程

**第一步：设置组织的政策级别**

在人员管理 → 组织维护管理中，为组织配置「政策级别」（一级政策、二级政策...）：
1. 进入组织详情，点击「机构编辑」。
2. 字段「是否实体机构」选「是」。
3. 字段「政策级别」选择对应级别（如一级、二级）。

**第二步：在政策的下游配置中添加组织维度**

在基础政策编辑页面：
1. 点击「下游政策」，点击页面上的「+」按钮。
2. 选择「下游维度」：`组织部门`（可按组织树选择具体机构/部门/团队）。
3. 选中需要设置下游点位的组织，点击确定。
4. 在该组织所在行配置下游点位（此时填写的是该组织负责人 + 业务员的总下游点位）。
5. 保存并提交审批。

**第三步：配置留点政策**

留点政策控制多级链路中各层负责人的分成。详见 6.6 节。

#### 注意事项

- 多级结算下，下游点位 = 各层负责人留点之和 + 业务员点位。
- 每个保单最终只会匹配一条下游政策行（按组织层级最精确匹配优先）。
- 佣金计算顺序：保单录入 → 匹配上游政策行 → 计算上游收入 → 匹配下游政策行 → 计算总下游 → 按留点政策层层拆分 → 写入各层级的 `ins_car_commission_record`。

---

### 6.6 留点设置

#### 留点模式

留点是从下游总点位中，单独划拨给机构/部门负责人的部分点位。支持两种配置模式：

| 模式 | 说明 |
|------|------|
| 总部统一设置 | 留点由总部管理员配置；负责人本人只能查看，无权编辑或审批 |
| 机构负责人自主设置 | 留点可由总部管理员或对应负责人本人编辑和审批 |

#### 菜单路径

车险 → 政策管理 → 留点设置

#### 操作流程（两种入口）

**入口一：「留点设置」独立页面（留点设置 = 旧版方式）**

1. 点击【设置留点】。
2. 在「选择机构」下拉中选择目标机构。
3. 选择「点位设置方式」（总部统一 / 机构自主）。
4. 在类 Excel 表格中右键单元格，勾选留点条件，设置留点点位。
5. 设置完毕后保存并提交审核。审批通过后生效。

> 注意：留点设置和下游留点（6.7节的留点政策）只能二选其一，不可同时使用。

**入口二：基础政策内的「下游留点」（留点政策 = 新版方式）**

详见 6.7 节。

---

### 6.7 留点政策设置（新版多级留点）

#### 说明

留点政策是基础政策中的「下游留点」配置区域，用于定义各层级负责人的留点规则。适用于需要精细化控制多层分佣的场景。

#### 配置流程

1. 进入基础政策编辑页面，找到「下游留点」开关（默认关闭）。
2. 打开「下游留点」后，默认勾选「业务员留点」。
3. 在下游留点表格区域，双击各层级负责人所在的点位单元格，输入留点点位。
4. 批量设置留点点位：点击「批量设置点位」：
   - 上游点位区间：「含（包含上限、不含下限）」，例如设置5-10的点位留点，需填写「5-11」。
   - 可选「点位取整」：开启后，如原始点位含小数，批量设置后小数部分被抹去（默认关闭）。
   - 选择需要批量设置的点位类型（基础/附加/扣点/非车，可多选，默认仅选基础）。
5. 设置完毕后保存并提交审批。

#### 相关表

```sql
CREATE TABLE `ins_car_policy_retain_point` (
  `id`              BIGINT      NOT NULL AUTO_INCREMENT,
  `batch_id`        BIGINT      NOT NULL COMMENT '关联政策批次ID',
  `org_id`          BIGINT      NOT NULL COMMENT '适用机构ID',
  `leader_id`       BIGINT               COMMENT '留点归属负责人ID',
  `set_mode`        TINYINT     DEFAULT 1 COMMENT '1总部统一 2负责人自主',
  `conditions`      JSON                 COMMENT '留点条件JSON（上游点位区间等）',
  `retain_rate`     DECIMAL(8,4)          COMMENT '留点比例（%）',
  `status`          TINYINT     DEFAULT 2 COMMENT '1草稿 2审核中 3生效 4已停用',
  `approve_id`      BIGINT,
  `approve_time`    DATETIME,
  `creator`         BIGINT,
  `create_time`     DATETIME,
  `deleted`         TINYINT     DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_batch_org` (`batch_id`, `org_id`)
) ENGINE=InnoDB COMMENT='车险政策留点表';
```

---

### 6.8 禁止报价 / 报价提示 / 禁止核保 / 核保提示

#### 功能说明

通过特殊政策类型，在报价或核保阶段对满足特定条件的保单进行拦截或弹出提示。

#### 政策类型说明

| 政策类型 | 触发时机 | 用户体验 |
|----------|----------|----------|
| 禁止报价 | 报价时匹配到该政策 | 直接阻止报价，显示禁止原因；无法继续报价 |
| 报价提示 | 报价时匹配到该政策 | 弹出提示弹窗，显示提示信息；用户可点击「继续报价」忽略提示 |
| 禁止核保 | 核保时匹配到该政策 | 直接阻止核保，显示禁止原因；无法核保出单 |
| 核保提示 | 核保时匹配到该政策 | 弹出提示弹窗；用户可选择继续 |

#### 配置方式

在新增政策批次时，「政策类型」下拉选择对应类型（禁止报价/报价提示/禁止核保/核保提示）。

政策条件配置方式同基础政策（类 Excel 表格，右键设置承保条件）。

**差异**：禁止/提示类政策无需填写点位字段；需额外填写一个「提示/禁止原因文本」字段（在批次基础配置弹窗中），该文本将在拦截时展示给用户。

#### 后端逻辑（报价/核保阶段）

报价或核保接口调用前，执行政策检查：
```java
// 伪代码
List<PolicyRuleBatch> activeBatches = policyRuleService.findActiveBatches(
    companyId, noId, quoteDateType, quoteDate
);
for (PolicyRuleBatch batch : activeBatches) {
    if (batch.policyType == FORBID_QUOTE) {
        PolicyMatchResult result = matchConditions(batch, policyInfo);
        if (result.matched) {
            throw new ForbidQuoteException(batch.remark);
        }
    } else if (batch.policyType == QUOTE_TIPS) {
        PolicyMatchResult result = matchConditions(batch, policyInfo);
        if (result.matched) {
            return QuoteCheckResult.warn(batch.remark);
        }
    }
}
```

---

### 6.9 报价赋值政策

#### 功能说明

报价赋值政策作用于报价环节。当报价时匹配到该政策，系统根据政策配置自动填充（或强制覆盖）报价表单中的特定字段值。

支持赋值的字段类型：
1. **关系人地址**：自动填充投保人/被保险人地址。
2. **车队协议号**：自动填充车队协议编号（用于车队批量投保）。
3. **自主定价系数**：自动设置商业险的自主定价系数（NCD）。

#### 赋值类型

| 赋值类型 | 行为 |
|----------|------|
| 默认值 | 报价时展示「赋值提示」弹窗，给出建议值；用户可选择采用或手动修改 |
| 固定值 | 报价时不弹提示；该字段直接使用政策配置的值，用户填入任何值也会被强制替换 |

#### 配置流程

1. 新增政策批次时，「政策类型」选「报价赋值」。
2. 配置承保条件（匹配哪些车辆执行赋值，如使用性质=家用）。
3. 在「核保类型」/「赋值条件」单元格中（右键点击进入）：选择要赋值的字段、设置赋值内容、选择赋值类型（默认值/固定值）。
4. 保存并提交审批。

#### 后端处理

报价接口中，在正常政策匹配之外，额外执行报价赋值检查：
- 若匹配到固定值赋值政策，在返回报价结果时覆盖对应字段，并在前端标注「由政策赋值（不可修改）」。
- 若匹配到默认值赋值政策，在报价结果中附加 `assignmentTips` 字段，前端弹窗展示建议值。

---

### 6.10 政策匹配引擎（后端实现要点）

政策匹配是车险佣金计算的核心算法，以下是关键实现规范：

#### 匹配流程

```
保单录入/更新
    ↓
1. 查找候选政策批次
   SELECT * FROM ins_car_policy_rule_batch
   WHERE merchant_id=? AND insurance_company_id=?
     AND status=3 (生效中)
     AND valid_start <= 匹配日期 AND (valid_end IS NULL OR valid_end >= 匹配日期)
     AND (apply_no_ids IS NULL OR JSON_CONTAINS(apply_no_ids, 工号ID))
   
    ↓
2. 按政策类型过滤（仅取基础政策，附加/扣点政策在同批次内处理）
    ↓
3. 遍历政策批次的各行，执行条件匹配
   - 对每行的 conditions JSON 进行逐条件比对
   - 条件中无值的视为通配（匹配所有）
   - 多个条件之间为 AND 关系
   - 优先级：条件越具体（非空条件越多）的行优先匹配
    ↓
4. 取匹配到的第一行（基础点位），计算上游和下游佣金
    ↓
5. 在同批次中，查找所有附加行，逐行判断是否匹配，匹配则累加
    ↓
6. 在同批次中，查找所有扣点行，取第一条匹配的扣点行进行扣减
    ↓
7. 写入 ins_car_commission_record
```

#### `ins_car_commission_record` 表结构

```sql
CREATE TABLE `ins_car_commission_record` (
  `id`                  BIGINT      NOT NULL AUTO_INCREMENT,
  `merchant_id`         BIGINT      NOT NULL,
  `policy_id`           BIGINT      NOT NULL COMMENT '关联车险保单ID',
  `policy_batch_id`     BIGINT               COMMENT '匹配到的政策批次ID',
  `policy_row_id`       BIGINT               COMMENT '匹配到的政策行ID',
  `commission_type`     TINYINT     NOT NULL COMMENT '1上游手续费 2下游佣金 3附加奖励 4扣点 5留点',
  `beneficiary_id`      BIGINT               COMMENT '受益人ID（下游/留点时为业务员/负责人）',
  `beneficiary_type`    TINYINT              COMMENT '1业务员 2部门负责人 3机构负责人',
  `upstream_rate`       DECIMAL(8,4)          COMMENT '上游点位（%）',
  `upstream_amount`     DECIMAL(12,2)         COMMENT '上游金额（元）',
  `downstream_rate`     DECIMAL(8,4)          COMMENT '下游点位（%）',
  `downstream_amount`   DECIMAL(12,2)         COMMENT '下游金额（元）',
  `base_premium`        DECIMAL(12,2)         COMMENT '计算基准保费',
  `status`              TINYINT     DEFAULT 0 COMMENT '0待结算 1已匹配 2已结算 3已付款 4已冻结',
  `settlement_year`     INT                   COMMENT '结算年',
  `settlement_month`    TINYINT               COMMENT '结算月',
  `settlement_quarter`  TINYINT               COMMENT '结算季度',
  `creator`             BIGINT,
  `create_time`         DATETIME,
  `update_time`         DATETIME,
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_beneficiary` (`beneficiary_id`, `status`),
  KEY `idx_merchant_status` (`merchant_id`, `status`)
) ENGINE=InnoDB COMMENT='车险佣金计算记录';
```

#### 性能优化

- 政策批次和行数据在 Redis 缓存（Key：`ins:car:policy:rules:{merchantId}:{companyId}`，TTL 30分钟）。
- 政策审批通过或停用时，主动清除相关缓存。
- 单次匹配耗时目标：< 50ms（包含 Redis 读取 + 内存匹配）。
- 大批量导入保单时（>100条），佣金计算走 MQ 异步处理，通过 `RocketMQ` 消息队列串行消费，避免并发写入冲突。

---

## 七、政策管理 API 接口清单

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/admin-api/ins/car/policy-rule/page` | 政策批次分页列表 |
| POST | `/admin-api/ins/car/policy-rule/batch` | 新增政策批次（基础配置） |
| PUT | `/admin-api/ins/car/policy-rule/batch/{id}` | 编辑政策批次基础配置 |
| POST | `/admin-api/ins/car/policy-rule/row` | 新增/更新政策行（含条件和点位） |
| DELETE | `/admin-api/ins/car/policy-rule/row/{id}` | 删除政策行 |
| PUT | `/admin-api/ins/car/policy-rule/batch/{id}/submit` | 提交审批 |
| PUT | `/admin-api/ins/car/policy-rule/batch/{id}/approve` | 审批通过 |
| PUT | `/admin-api/ins/car/policy-rule/batch/{id}/reject` | 审批拒绝 |
| PUT | `/admin-api/ins/car/policy-rule/batch/{id}/disable` | 停用政策 |
| POST | `/admin-api/ins/car/policy-rule/batch/{id}/copy` | 复制政策批次 |
| GET | `/admin-api/ins/car/policy-rule/condition-dict` | 获取可选承保条件字典 |
| GET | `/admin-api/ins/car/policy-rule/retain-point/list` | 留点政策列表（按机构） |
| POST | `/admin-api/ins/car/policy-rule/retain-point` | 新增/更新留点设置 |
| POST | `/admin-api/ins/car/policy-rule/match-test` | 政策匹配测试（Debug用，传入模拟保单参数返回匹配结果） |

---

## 八、微服务归属

政策管理模块归属于 `intermediary-module-ins-order` 微服务下：

```
controller/admin/
└── AdminInsCarPolicyRuleController.java    # 政策管理主控制器
└── AdminInsCarRetainPointController.java   # 留点设置控制器
└── AdminInsCarApprovalController.java      # 政策审批控制器

service/
├── InsCarPolicyRuleService / InsCarPolicyRuleServiceImpl
├── InsCarPolicyMatchService / InsCarPolicyMatchServiceImpl    # 核心匹配引擎
└── InsCarRetainPointService / InsCarRetainPointServiceImpl
```

---

## 九、本模块工时估算

| 功能点 | 前端(天) | 后端(天) | 合计 |
|--------|---------|---------|------|
| 政策批次CRUD + 审批流 | 1.5 | 1.5 | 3 |
| 类Excel政策条件配置界面 | 3 | 1 | 4 |
| 附加/扣点政策行配置 | 1 | 0.5 | 1.5 |
| 多级结算/下游配置 | 1 | 1 | 2 |
| 留点设置（两种模式） | 1 | 1 | 2 |
| 禁止/提示类政策 | 0.5 | 0.5 | 1 |
| 报价赋值政策 | 0.5 | 0.5 | 1 |
| 政策匹配引擎 + 佣金计算 | 0 | 3 | 3 |
| 政策匹配缓存优化 | 0 | 1 | 1 |
| **合计** | **8.5** | **10** | **18.5** |

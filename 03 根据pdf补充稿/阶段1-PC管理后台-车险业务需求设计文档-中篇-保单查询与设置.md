# 阶段1 · PC管理后台 · 车险业务需求设计文档【中篇：保单查询与设置】

> 版本：V1.0 | 对应排期表 Sheet：`阶段1-PC管理后台-车险业务`

---

## 四、保单查询模块

> 菜单路径：车险 → 保单管理 → 保单查询

### 4.1 保单查询主列表（场景化查询）

#### 页面结构

页面分为三个区域：

1. **顶部场景 Tab 栏**：展示用户已配置的查询场景，默认展示「全部」场景。每个 Tab 右侧有「+」按钮新增场景，已有场景右键或点击「...」可编辑/删除。
2. **筛选条件区域**：根据当前激活场景展示对应的筛选字段（字段来源于场景配置）。固定筛选条件（所有场景必有）：日期类型（下拉：签单日期/支付日期/核保日期）、日期区间（日期范围选择器）。
3. **数据列表区域**：展示保单列表，底部有汇总行。

#### 默认展示字段

保险公司、保（批）单号、业务员、起保日期、保险止期、产品备注、工号名称、险种类型、产品、工号、保险分公司、操作（查看详情 / 编辑 / 删除）。

列字段可通过场景配置增减和排序。

#### 底部汇总行（固定，不受分页影响）

对当前筛选结果全量聚合，展示：
- 总保费 = SUM(premium_compulsory + premium_commercial)
- 净保费（交强） = SUM(premium_compulsory)
- 净保费（商业） = SUM(premium_commercial)
- 车船税 = SUM(vehicle_tax)
- 总件数 = COUNT(*)

后端通过独立聚合 SQL 查询，不做分页截断：
```sql
SELECT COUNT(*) as total_count,
       SUM(premium_compulsory + premium_commercial) as total_premium,
       SUM(premium_compulsory) as compulsory_premium,
       SUM(premium_commercial) as commercial_premium,
       SUM(vehicle_tax) as vehicle_tax_total
FROM insurance_car_policy
WHERE [筛选条件] AND is_deleted = 0
```

#### 列表操作

- **查看详情**：跳转到保单详情页（只读）。
- **编辑**：弹出编辑弹窗，字段同录入表单，保存触发佣金重算。
- **删除**：执行逻辑删除（详见 4.6 节）。

#### 数据权限

- 超级管理员/内勤：可查看本商户全量保单。
- 业务员：默认只查看自己名下保单（`salesman_id = 当前用户ID`）；若有「查看团队保单」权限则可见所在组织的保单。
- 通过 yudao-cloud 数据权限注解 `@DataPermission` 实现。

---

### 4.2 新增/修改场景管理

#### 触发入口

- 点击场景 Tab 栏右侧【场景+】新增场景。
- 右键已有 Tab 或点击「...」→【编辑场景】修改。

#### 新增场景弹窗

弹窗分两部分：

**Part 1：筛选条件配置**

- 左侧：可选筛选字段列表（全量字段）。
- 右侧：已选字段列表，支持拖拽排序。
- 灰色标注（不可移除）的系统固定条件：日期类型、日期区间。
- 其他可选条件包括：保险公司、业务员、出单工号、险种类型、车牌号、VIN码、保单号、录入方式、业务来源、保险止期区间等。

**Part 2：列表展示字段配置**

- 同样是左侧可选、右侧已选+拖拽排序的双列布局。
- 至少保留「保单号」和「操作」两列（不可移除）。

**场景名称**：顶部文本框，必填，最大 20 字。

#### 保存逻辑

- 场景配置以 JSON 形式存储到 `ins_car_policy_scene` 表，按用户 ID 隔离。
- 场景 JSON 结构：
```json
{
  "sceneName": "本月签单",
  "filterFields": ["insurance_company_id", "salesman_id", ...],
  "listColumns": ["policy_no", "plate_no", "premium_total", ...],
  "defaultDateType": "sign_date",
  "defaultDateRange": "current_month"
}
```
- 用户刷新页面后，系统重新加载该用户的场景列表，Tab 顺序保持用户上次操作的顺序（保存 `sort` 字段）。

---

### 4.3 表格批量导入保单

#### 操作流程

**Step 1：下载模板**
- 点击【下载导入模板】，后端 EasyExcel 动态生成模板文件返回。
- 模板包含两个 Sheet：「导入数据」（含标题行+示例行）、「字段说明」（各字段格式说明）。

**Step 2：填写并上传**
- 用户填写模板后，点击【上传文件】，支持 .xlsx / .xls 格式，文件大小限制 10MB。

**Step 3：预解析预览**
- 后端同步解析文件（EasyExcel ReadListener），返回预览结果：
  - 总行数 / 格式错误行数（含错误原因） / 重复保单行数
  - 预览表格：前 10 行数据展示（绿色=正常，红色=错误，黄色=重复）。
- 用户确认后点击【确认导入】。

**Step 4：异步写库**
- 后端生成唯一批次号：Redis `INCR ins:car:import:batch:id` 自增后拼接商户ID前缀。
- 写入 `ins_car_import_batch` 批次记录表（状态：处理中）。
- 发送 RocketMQ 消息，消费者异步写库：逐条校验、写保单、触发佣金计算。
- 全部处理完成后更新批次状态（成功/部分失败），发送站内信通知用户。

**Step 5：查看结果**
- 可在【保单查询 → 任务列表 → 保单导入列表】查看批次状态和失败明细。
- 失败明细可下载 Excel（含原数据+错误原因列）。

#### 相关表

```sql
CREATE TABLE `ins_car_import_batch` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '批次ID',
  `merchant_id`   BIGINT       NOT NULL,
  `batch_no`      VARCHAR(32)  NOT NULL COMMENT '批次号',
  `file_name`     VARCHAR(200)          COMMENT '原文件名',
  `file_url`      VARCHAR(500)          COMMENT 'OSS文件地址',
  `total_count`   INT          DEFAULT 0,
  `success_count` INT          DEFAULT 0,
  `fail_count`    INT          DEFAULT 0,
  `status`        TINYINT      DEFAULT 1 COMMENT '1处理中 2成功 3部分失败 4全部失败',
  `fail_file_url` VARCHAR(500)          COMMENT '失败明细文件URL',
  `creator`       BIGINT,
  `create_time`   DATETIME,
  `finish_time`   DATETIME,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`)
) ENGINE=InnoDB COMMENT='车险保单批量导入批次表';
```

---

### 4.4 车险保单导出

#### 触发方式

- **勾选导出**：在列表勾选多条保单，点击工具栏【导出】。
- **条件导出**：不勾选时点击【导出】，按当前筛选条件导出全量结果。

#### 导出逻辑

- ≤ 2000 条：同步生成，直接返回文件流（浏览器弹出下载）。
- > 2000 条：异步生成。提示「数据量较大，系统将在后台生成，完成后通过站内信通知您下载」。后台 EasyExcel 写文件到 OSS，完成后站内信附下载链接（链接有效期 24h）。

#### 导出格式

用户可在导出前选择：
- **完整版**：包含所有保单字段（含佣金数据）。
- **简版**：仅基础信息字段（保单号、保险公司、车牌号、保费、业务员、日期）。

导出字段也受当前激活场景的列配置影响（若选「按场景字段导出」）。

---

### 4.5 批量更新保单数据

#### 操作入口

在保单查询列表勾选多条保单（或全选当前筛选结果），点击工具栏【批量更新】。

#### 弹窗交互

弹窗展示可批量修改的字段列表（勾选要修改的字段）：

| 可批量修改字段 | 说明 |
|----------------|------|
| 业务员归属 | 人员选择器，更换业务员 |
| 出单员 | 人员选择器 |
| 录入方式 | 下拉：直连/手工 |
| 业务来源 | 下拉 |
| 产品备注 | 文本框 |

- 用户勾选要修改的字段后，填写新值。
- 底部展示：已选中 n 条保单，确认后将更新选中字段。
- 点击【确认更新】。

#### 后端处理

1. 获取分布式锁（Redis Key：`ins:car:policy:batch_update:{merchant_id}`），防并发操作。
2. 逐条更新（或批量 `UPDATE ... WHERE id IN (...)` 分批执行，每批 200 条）。
3. 若批改了业务员，需检查该业务员是否在本商户有效，否则返回错误。
4. 更新完成后，将操作写入审计日志 `sys_operate_log`：操作类型=批量更新保单，变更内容（JSON diff）。
5. 释放分布式锁。

#### Excel 模板批量更新（另一入口）

1. 点击【下载批量更新模板】，模板包含：保单号（必填，作为主键定位）+ 各可修改字段列。
2. 用户填写后上传，EasyExcel 解析，以保单号定位记录批量 UPDATE。
3. 解析预览后确认执行，结果同步返回（数据量少）或异步处理。

---

### 4.6 保单批量删除

#### 操作入口

勾选保单后，点击工具栏【批量删除】。

#### 二次确认弹窗

弹窗内容：`确定删除已选中的 [n] 条保单吗？删除后不可恢复。`
- 若部分保单已参与佣金结算，弹窗额外提示：`注意：以下 [m] 条保单已参与佣金结算，无法删除，请先撤销对应结算后再操作：[保单号列表]`，并将这部分保单从本次删除范围中排除。
- **同步删除非车保单开关**：弹窗中展示一个勾选项「同时删除随车险一起录入的非车保单」，默认勾选。开启后，与选中车险保单关联的非车保单（`ins_noncar_policy.car_policy_id = 车险保单ID`）也会被一并逻辑删除。

#### 后端处理

1. 查询所选保单 ID 列表中，是否存在 `is_deleted=0` 且关联 `ins_car_commission_record.status IN (2,3)`（2=已结算，3=已付款）的记录。
2. 已结算保单返回错误列表，仅对未结算保单执行逻辑删除：`UPDATE insurance_car_policy SET is_deleted=1, updater=?, update_time=NOW() WHERE id IN (...)`。
3. 若勾选了「同时删除非车保单」，执行：`UPDATE ins_noncar_policy SET is_deleted=1 WHERE car_policy_id IN (...) AND is_deleted=0`。
4. 所有删除操作在同一事务内执行（`@Transactional`）。
5. 写操作审计日志（包含删除条数、是否同步删除非车、操作人、时间）。
6. 删除完成后，将结果写入任务记录（`ins_car_batch_task`），用户可在「任务列表」中查看本次批量删除的明细（成功条数/失败条数）。

---

### 4.7 表格导入保单查询删除

#### 功能说明

适用于保司下发一批保单号，需要批量清理的场景。

#### 操作流程

1. 点击【导入文件筛选】（保单查询列表工具栏）。
2. 上传含保单号列的 Excel（第一列为保单号，无需表头或表头为「保单号」）。
3. 系统解析文件，提取保单号列表，执行 IN 查询定位到系统中存在的保单，展示到列表中。
4. 用户复核列表后，点击【全选当前结果】→【批量删除】，执行 4.6 节的逻辑删除流程。

---

### 4.8 通过导入 ID 筛选保单

#### 功能说明

每次批量导入保单会生成唯一的批次 ID（`ins_car_import_batch.id`），可利用该 ID 精确筛选该批次导入的所有保单。

#### 使用路径

1. 菜单：保单查询 → 任务列表 → 保单导入列表，查看历史批次的「批次ID」。
2. 回到保单查询页，在筛选条件中找到「导入任务ID」字段（场景可选条件之一）。
3. 输入批次ID，查询出该批次对应的全部保单。
4. 可用于数据核对或批量删除（常见场景：导入有误后整批删除）。

#### 实现要点

- `insurance_car_policy` 表中有 `import_batch_id` 字段关联批次。
- 保单查询的筛选条件需支持 `import_batch_id = ?` 过滤。
- 在场景管理的「可选条件」列表中增加「导入任务ID」选项。

---

### 4.9 多个保单号逗号隔开搜索

#### 功能开关

在【保单设置】中配置（见第五章），开关字段：`multi_policy_search_enable`。

#### 开启后的行为

- 保单查询筛选区的「保单号」输入框，提示语变更为：`可输入多个保单号，用英文逗号分隔`。
- 用户输入如 `PDAA202300001,PDAA202300002,PDAA202300003`，前端解析为数组传入后端。
- 后端生成 `policy_no IN ('PDAA202300001', ...)` 查询，最多支持 500 个保单号（超出提示 `最多支持同时搜索 500 个保单号`）。

#### 关闭时的行为

- 保单号输入框为普通模糊搜索（`LIKE '%xxx%'`），提示语：`请输入保单号`。

#### 批量保单号辅助小工具

页面右下角提供「NO—保单号批量处理小工具」快捷入口（悬浮按钮）：
1. 将 Excel 表格中需要转换的保单号列数据复制（Tab/换行分隔）。
2. 粘贴到小工具输入框中，点击「格式转换」。
3. 工具自动将换行/Tab分隔的多个保单号转换为英文逗号分隔格式。
4. 点击「复制结果」，将转换后的字符串粘贴到保单查询的保单号输入框中查询。

**后端实现**：此小工具为纯前端功能，无需后端接口，前端 JavaScript 实现字符串转换逻辑。

---

### 4.10 车险保单添加非车保单

#### 功能入口

进入车险保单详情页（只读详情）→ 展开「非车信息」Tab → 点击【新增非车产品】。

#### 新增非车产品弹窗字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 险种名称 | 下拉 | ✅ | 从非车产品库（`ins_noncar_product`）搜索选择，只允许选择已上架产品 |
| 保险公司 | 自动带出 | — | 由所选产品带出，不可手改 |
| 保单号（非车） | 文本 | ✅ | |
| 保费 | 金额 | ✅ | 单位元 |
| 起保日期 | 日期 | ✅ | 格式必须为 `yyyy-MM-dd` |
| 保险止期 | 日期 | ✅ | 格式必须为 `yyyy-MM-dd` |
| 业务员 | 人员选择器 | ✅ | 默认带入车险保单的业务员 |

#### 后端处理

1. 验证所选产品存在于 `ins_noncar_product` 且状态为上架（`status=1`）。
2. 日期格式强制校验（后端正则：`^\d{4}-\d{2}-\d{2}$`），格式不符则返回错误（日期格式问题会导致非车模块无法同步）。
3. 在 `ins_noncar_policy` 表中插入一条非车保单记录，并将 `car_policy_id` 字段关联到当前车险保单 ID。
4. 同步触发非车佣金计算（发 MQ）。

---

## 五、保单设置模块

> 菜单路径：车险 → 保单管理 → 保单设置

### 5.1 保单设置（字段与功能配置）

#### 页面结构

表单页，分为以下配置区块：

**区块1：查询默认行为**
- 默认日期类型：单选，签单日期 / 支付日期 / 核保日期（默认：签单日期）。
- 默认日期范围：单选，当月 / 当季 / 上月 / 自定义（默认：当月）。

**区块2：保单号搜索模式**
- 是否开启多保单号逗号搜索：开关（默认关闭）。

**区块3：保单号格式规则**
- 最小长度：数字输入，默认 8。
- 最大长度：数字输入，默认 20。
- 允许特殊字符：勾选框（允许哪些：`-`、`/`、空格）。

**区块4：录入规则**
- 是否强制关联出单工号：开关（开启后，录入表单中出单工号必填且必须选择，不可手工输入）。
- 重复保单提示模式：单选：
  - `显示录单人及录入日期`（默认）：提示信息中展示录入人员姓名及录入日期。
  - `隐藏录单人及录入日期`：只提示存在重复保单，不暴露具体人员信息（适用于隐私保护场景）。
- 工号必须与委托协议关联：开关（开启后，工号管理新增/编辑时委托代理协议字段变为必填；协议到期后，该工号自动禁用）。

**区块5：业务归属设置**
- 保单业务归属依据：单选，从「业务员 / 出单员 / 录单员 / 工号」中选择。
  - 选择「业务员」：保单归属在对应业务员及其所在组织下，政策匹配和佣金计算以业务员归属组织的政策为准。
  - 选择「工号」：以工号绑定的机构为归属，适用于工号归属机构与业务员归属机构不同的场景。
  - 选择完毕点击保存生效。
- 保单修改下游手续费限制：
  - 开关开启：保单修改时，下游手续费的金额和点位不允许超过当前已匹配政策的金额和点位（管理员账号例外，不受此限制）。
  - 子配置「是否不限制财务经理」：
    - 总开关开启 + 此选项开启：财务经理角色也不受限制。
    - 总开关开启 + 此选项关闭：财务经理同样不允许超过政策金额。
  - 开关关闭：不限制任何角色。
- 保单代理人与收款人一致：开关。开启后，当保单的业务员与收款人不一致时，系统给出提示（不阻止保存）。
- 车险系统录单带出的非车保单信息同步非车系统：开关。开启后，车险保单录入时若带出非车险产品信息，自动同步到非车模块（`ins_noncar_policy` 表）。
- 录单时试算手续费限制：
  - 配置不支持试算手续费的组织机构（多选组织树）。
  - 勾选的组织下的录单操作：保单录入页面不显示「试算」按钮；如填写的上下游金额超过政策匹配金额，系统弹出警告提示。
  - 取消勾选并保存：恢复该组织的试算功能。

#### 保存逻辑

- 配置项写入 `sys_config` 表，key 格式：`ins.car.policy.{配置项名称}`，值为 JSON 或字符串。
- 修改即时生效（系统读取时每次查库，或设置 Redis 缓存 TTL 5 分钟）。
- 影响范围：本商户下所有用户的查询和录入行为。

---

### 5.2 同步设置（商户间保单同步）

#### 功能说明

将 A 商户的车险保单录入后，自动同步一份至 B 商户（适用于总公司与分公司数据共享）。

#### 前置条件（由客户经理在后台开通）

1. A 商户必须在系统级别开启「录单同步功能」（`sys_merchant.enable_policy_sync = 1`）。
2. A、B 两个商户必须配置了相同的保司工号（同一工号分别在两个商户下绑定）。

#### 操作流程

**A 商户操作：**
1. 进入【车险 → 保单管理 → 保单设置 → 同步设置】选项卡。
2. 点击【新增同步配置】，弹窗填写：
   - 目标商户：输入框搜索（按商户名称/编号搜索），选中目标商户 B 后，填写 B 商户的系统登录账号和密码（作为同步凭证）。
   - 同步工号：选择作为同步凭证的保司工号（该工号须在 A、B 两个商户下均已配置相同工号信息）。
   - 禁用的录单模式（多选）：指定哪些录入方式的保单**不**同步到 B 商户（如：勾选「手工」则手工录入的保单不同步，只同步直连录入的保单）。
   - 是否启用：开关。
3. 保存配置，写入 `ins_car_policy_sync_config` 表。

> 注意：A 商户中配置的目标商户 B 的账号密码，经 AES 加密后存储。

**同步触发机制：**
- A 商户新录入保单后，检查是否存在该工号的同步配置（`company_no_id` 匹配且启用），同时判断录入方式是否在「禁用录单模式」列表中。
- 若满足同步条件，发送 MQ 消息 `ins_car_policy_sync`，消费者在 B 商户下创建同样的保单记录（`merchant_id` 替换为 B 商户，`creator` 标注为「同步」）。
- 同步失败（网络/校验异常）写入 `ins_car_policy_sync_fail_log`，并每 10 分钟定时重试（最多 3 次）。
- 点击【禁用】按钮可临时禁用该工号的同步，不影响其他工号。
- 点击【编辑】可修改已配置的同步工号信息。

**测试同步：**
- 配置完成后，A 商户操作一条录单，B 商户查询保单列表中该保单状态显示为「代理间同步保单」，表示同步成功。

**A 商户录单权限要求**：
- 录单人员需在系统角色权限中开通「录单同步」相关权限，否则录入的保单不会触发同步逻辑。

#### 相关表

```sql
CREATE TABLE `ins_car_policy_sync_config` (
  `id`              BIGINT  NOT NULL AUTO_INCREMENT,
  `source_merchant_id`  BIGINT NOT NULL COMMENT '源商户ID(A)',
  `target_merchant_id`  BIGINT NOT NULL COMMENT '目标商户ID(B)',
  `company_no_id`   BIGINT  NOT NULL COMMENT '同步凭证工号ID',
  `enabled`         TINYINT DEFAULT 1 COMMENT '0禁用 1启用',
  `creator`         BIGINT,
  `create_time`     DATETIME,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_source_target_no` (`source_merchant_id`,`target_merchant_id`,`company_no_id`)
) ENGINE=InnoDB COMMENT='商户间保单同步配置';
```

---

## 六、相关表场景配置表结构

### `ins_car_policy_scene`（查询场景配置）

```sql
CREATE TABLE `ins_car_policy_scene` (
  `id`          BIGINT       NOT NULL AUTO_INCREMENT,
  `merchant_id` BIGINT       NOT NULL,
  `user_id`     BIGINT       NOT NULL COMMENT '所属用户ID',
  `scene_name`  VARCHAR(20)  NOT NULL COMMENT '场景名称',
  `scene_config` JSON         NOT NULL COMMENT '场景配置JSON',
  `sort`        INT          DEFAULT 0 COMMENT '排序',
  `is_default`  TINYINT      DEFAULT 0 COMMENT '是否默认场景',
  `is_deleted`  TINYINT      DEFAULT 0,
  `create_time` DATETIME,
  `update_time` DATETIME,
  PRIMARY KEY (`id`),
  KEY `idx_user_merchant` (`user_id`, `merchant_id`)
) ENGINE=InnoDB COMMENT='车险保单查询场景配置';
```

---

## 七、API 接口清单（保单查询与设置模块）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/admin-api/ins/car/policy/page` | 保单查询分页列表 |
| GET | `/admin-api/ins/car/policy/summary` | 底部汇总数据 |
| GET | `/admin-api/ins/car/policy/{id}` | 保单详情 |
| PUT | `/admin-api/ins/car/policy/{id}` | 编辑保单 |
| DELETE | `/admin-api/ins/car/policy/batch-delete` | 批量逻辑删除 |
| PUT | `/admin-api/ins/car/policy/batch-update` | 批量更新字段 |
| POST | `/admin-api/ins/car/policy/import` | 上传文件批量导入 |
| GET | `/admin-api/ins/car/policy/export` | 导出保单 Excel |
| POST | `/admin-api/ins/car/policy/import-query-delete` | 导入文件筛选保单 |
| POST | `/admin-api/ins/car/policy/add-noncar` | 车险保单添加非车保单 |
| GET | `/admin-api/ins/car/import-batch/page` | 导入批次列表 |
| GET | `/admin-api/ins/car/policy/scene/list` | 获取当前用户场景列表 |
| POST | `/admin-api/ins/car/policy/scene` | 新增场景 |
| PUT | `/admin-api/ins/car/policy/scene/{id}` | 修改场景 |
| DELETE | `/admin-api/ins/car/policy/scene/{id}` | 删除场景 |
| GET | `/admin-api/ins/car/policy/settings` | 获取保单设置 |
| PUT | `/admin-api/ins/car/policy/settings` | 保存保单设置 |
| GET | `/admin-api/ins/car/policy/sync-config/list` | 同步配置列表 |
| POST | `/admin-api/ins/car/policy/sync-config` | 新增同步配置 |
| PUT | `/admin-api/ins/car/policy/sync-config/{id}` | 修改同步配置 |

---

*下一篇：【下篇】报表管理 · 统计分析*

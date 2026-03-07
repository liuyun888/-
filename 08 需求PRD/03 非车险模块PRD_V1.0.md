# 非车险模块 产品需求文档（PRD）

> **文档版本**：V1.0  
> **项目名称**：保险中介平台（intermediary-cloud）  
> **模块名称**：非车险业务（Non-Vehicle Insurance）  
> **技术栈**：yudao-cloud（Spring Cloud Alibaba）+ MySQL 8.0 + Redis + RocketMQ  
> **微服务归属**：`intermediary-module-ins-order`  
> **数据库 Schema**：`db_ins_order`，表前缀 `ins_non_vehicle_`  
> **包路径**：`cn.qmsk.intermediary`  
> **参考操作手册**：PDF 84～106 号

---

## 目录

1. [模块概述](#一模块概述)
2. [菜单结构与权限](#二菜单结构与权限)
3. [保单管理 - 保单录入（手工单笔）](#三保单管理---保单录入手工单笔)
4. [保单管理 - 批单录入](#四保单管理---批单录入)
5. [保单管理 - 保单批量导入](#五保单管理---保单批量导入)
6. [保单管理 - 保单查询](#六保单管理---保单查询)
7. [保单管理 - 批量更新信息](#七保单管理---批量更新信息)
8. [保单管理 - 导入失败排查](#八保单管理---导入失败排查)
9. [政策管理 - 新增政策批次](#九政策管理---新增政策批次)
10. [政策管理 - 政策其他操作](#十政策管理---政策其他操作)
11. [统计分析 - 险别占比分析](#十一统计分析---险别占比分析)
12. [统计分析 - 分支机构分析](#十二统计分析---分支机构分析)
13. [统计分析 - 保险公司分析](#十三统计分析---保险公司分析)
14. [统计分析 - 区域占比分析](#十四统计分析---区域占比分析)
15. [统计分析 - 业务来源分析](#十五统计分析---业务来源分析)
16. [系统设置 - 产品管理](#十六系统设置---产品管理)
17. [系统设置 - 模板设置](#十七系统设置---模板设置)
18. [系统设置 - 保单设置](#十八系统设置---保单设置)
19. [数据库设计汇总](#十九数据库设计汇总)
20. [接口清单汇总](#二十接口清单汇总)
21. [微服务代码组织结构](#二十一微服务代码组织结构)

---

## 一、模块概述

### 1.1 业务背景

非车险（Non-Vehicle Insurance）模块是保险中介平台的核心业务模块之一，覆盖财产险、工程险、责任险、农险、健康险等多类非汽车保险业务的全生命周期管理，包括保单录入、批改管理、政策配置、手续费计算、统计分析等核心功能。

### 1.2 用户角色与权限

| 角色 | 权限范围 |
|------|----------|
| 超级管理员 | 全部非车险数据，含所有机构 |
| 机构管理员 | 本机构及下级机构的非车险数据 |
| 团队主管 | 本团队成员的非车险数据 |
| 业务员 | 本人名下的非车险保单 |
| 出单员 | 本人负责出单的保单（按出单员字段过滤） |
| 财务人员 | 非车险手续费结算相关数据 |

### 1.3 模块功能地图

```
非车险
├── 保单管理
│   ├── 保单录入（手工单笔 / 批单录入）
│   ├── 保单查询（列表查询 / 字段自定义 / 条件自定义）
│   ├── 保单批量导入（Excel上传 / 任务状态查询）
│   └── 批量更新信息
├── 政策管理
│   ├── 非车政策（新增 / 编辑 / 复制 / 停用 / 删除）
│   └── 政策匹配引擎（触发上下游手续费自动回填）
├── 统计分析
│   ├── 险别占比分析
│   ├── 分支机构分析
│   ├── 保险公司分析
│   ├── 区域占比分析
│   └── 业务来源分析
└── 系统设置
    ├── 产品管理（系统产品 / 自定义产品 / 险种类别）
    ├── 模板设置（Excel导入/导出模板）
    └── 保单设置（录单设置 / 手续费校验 / 字段自定义）
```

### 1.4 工时估算（排期表参考）

| 功能模块 | 前端（天） | 后端（天） | 合计 |
|----------|-----------|-----------|------|
| 非车保单录入（手工） | 2 | 2 | 4 |
| 非车批单录入 | 1 | 1.5 | 2.5 |
| 非车保单导入 | 1.5 | 2 | 3.5 |
| 非车保单查询（含字段/条件设置） | 2 | 2 | 4 |
| 批量更新信息 | 1 | 1 | 2 |
| 非车政策-新增政策批次 | 2 | 2 | 4 |
| 非车政策-其他操作 | 1 | 1 | 2 |
| 险别占比分析 | 1 | 1 | 2 |
| 分支机构分析 | 1.5 | 1.5 | 3 |
| 保险公司分析 | 1 | 1 | 2 |
| 区域占比分析 | 1 | 1 | 2 |
| 业务来源分析 | 1 | 1 | 2 |
| 产品管理 | 1 | 1 | 2 |
| 模板设置 | 1 | 1 | 2 |
| 保单设置 | 1 | 1 | 2 |
| **合计** | **19** | **20** | **39** |

---

## 二、菜单结构与权限

### 2.1 菜单层级

```
非车（/non-vehicle）
├── 保单管理（/non-vehicle/policy）
│   ├── 保单录入（/non-vehicle/policy/entry）            PDF-86/87
│   ├── 保单查询（/non-vehicle/policy/query）            PDF-89/90/91
│   └── 任务列表（/non-vehicle/policy/task）             PDF-88
├── 政策管理（/non-vehicle/policy-rule）
│   └── 非车政策（/non-vehicle/policy-rule/list）        PDF-94/95/96
├── 统计分析（/non-vehicle/statistics）
│   ├── 险别占比分析（/non-vehicle/statistics/type-ratio）   PDF-98
│   ├── 分支机构分析（/non-vehicle/statistics/org）          PDF-99
│   ├── 保险公司分析（/non-vehicle/statistics/company）      PDF-100
│   ├── 区域占比分析（/non-vehicle/statistics/region）       PDF-101
│   └── 业务来源分析（/non-vehicle/statistics/source）       PDF-102
└── 系统设置（/non-vehicle/settings）
    ├── 产品管理（/non-vehicle/settings/product）            PDF-103/104
    ├── 模板设置（/non-vehicle/settings/template）           PDF-105
    └── 保单设置（/non-vehicle/settings/policy-config）      PDF-106
```

### 2.2 权限码设计

| 权限码 | 说明 |
|--------|------|
| `non_vehicle:policy:create` | 新增非车保单 |
| `non_vehicle:policy:update` | 编辑非车保单 |
| `non_vehicle:policy:delete` | 删除非车保单 |
| `non_vehicle:policy:export` | 导出非车保单 |
| `non_vehicle:policy:import` | 批量导入非车保单 |
| `non_vehicle:rule:create` | 新增非车政策 |
| `non_vehicle:rule:update` | 编辑非车政策 |
| `non_vehicle:statistics:view` | 查看统计分析 |
| `non_vehicle:settings:manage` | 系统设置管理 |

---

## 三、保单管理 - 保单录入（手工单笔）

> **对应PDF**：`86_非车-保单管理-非车保单录入`  
> **菜单路径**：【非车】→【保单管理】→【保单录入】  
> **工时**：前端2天 + 后端2天

### 3.1 入口说明

点击【保单录入】→【新增保单】按钮，弹出保单录入全屏表单页。

### 3.2 表单字段详细说明

#### 3.2.1 基本信息区域

| 字段名 | 控件类型 | 必填 | 校验规则 | 说明 |
|--------|----------|------|----------|------|
| 保险公司 | 下拉选择 | ✅ | 不能为空 | 从系统保司字典加载，联动工号/政策匹配 |
| 标的标识 | 单选：车辆/人/物品 | ✅ | 不能为空 | **核心分支字段**，控制后续表单结构 |
| 标的名称 | 文本输入 | ❌ | — | 被保标的物名称 |
| 保(批)单号 | 文本输入 | ✅ | 唯一性校验 | 与保险公司组成联合唯一索引，防止重录 |
| 险种编码 | 文本/下拉 | ❌ | — | 与险种联动 |
| 险种 | 下拉选择 | ✅ | 不能为空 | 加载非车险种字典 |
| 产品名称 | 分支逻辑控件 | ✅ | 不能为空 | 见3.3节分支逻辑说明 |
| 互联网业务 | 单选：是/否 | ❌ | — | — |
| 涉农业务 | 单选：是/否 | ❌ | — | — |
| 保单状态 | 下拉 | ✅ | 不能为空 | 正常/退保/批改/终止 |
| 签单日期 | 日期选择 | ✅ | 不能为空 | — |
| 起保日期 | 日期选择 | ✅ | 不能为空 | — |
| 保险止期 | 日期选择 | ✅ | >= 起保日期 | — |
| 支付日期 | 日期选择 | ❌ | — | 政策匹配日期类型=支付日期时使用 |
| 渠道名称 | 文本/下拉 | ❌ | — | 业务来源渠道 |
| 业务员 | 下拉搜索选择 | ✅ | 必须为租户内有效人员 | 影响佣金归属 |
| 工号名称 | 下拉 | ❌ | — | 须在非车工号范围内配置，与政策匹配关联 |
| 出单员 | 文本/下拉 | ❌ | — | — |
| 录入方式 | 下拉 | ❌ | — | 手工录单/自动录单等 |
| 共保标识 | 单选：是/否 | ✅ | — | 选"是"时显示共保保司区域（仅标的=人或物品时支持） |

#### 3.2.2 产品名称分支逻辑

| 标的标识 | 产品名称控件 |
|----------|------------|
| 车辆 | 下拉选择，仅能选择**系统产品**（`product_type=1`）|
| 人 / 物品 | 自定义文本输入，不限于系统产品；也可选择**自定义产品** |

#### 3.2.3 共保保司信息区域

**显示条件**：共保标识 = 是 且 标的标识 = 人或物品

- 可添加多家共保保险公司（点击【新增共保】按钮追加一行）
- 每行字段：保险公司（必填下拉）、保费比例（%，数字输入）、共保保单号（文本输入）

#### 3.2.4 被保人信息区域（按标的标识动态显示）

| 标的标识 | 显示字段 | 必填说明 |
|----------|----------|----------|
| 车辆 | 车主姓名、证件类型、证件号、车牌号、车架号、发动机号；支持勾选"同投保人"自动填充 | **必填** |
| 人 | 被保人姓名（支持添加多人），每人：姓名、证件号、出生日期 | 可为空，支持多人 |
| 物品 | 被保人姓名、证件号 | 可为空 |

#### 3.2.5 投保人信息区域

| 字段 | 必填 |
|------|------|
| 投保人名称 | ✅ |
| 证件类型 | ❌ |
| 证件号 | ❌ |
| 联系电话 | ❌ |

#### 3.2.6 保单费用区域

| 字段名 | 必填 | 说明 |
|--------|------|------|
| 全保费 | ✅ | 含税保费 |
| 净保费 | ✅ | 不含税保费 |

#### 3.2.7 上游手续费区域

| 字段名 | 必填 | 说明 |
|--------|------|------|
| 上游保单手续费比例(%) | ❌ | 政策匹配后自动回填，可手动覆盖 |
| 上游手续费金额 | ❌ | = 净保费 × 上游比例（系统自动计算） |
| 结算方式 | ❌ | 上游结算方式下拉 |

#### 3.2.8 下游手续费区域

| 字段名 | 必填 | 说明 |
|--------|------|------|
| 下游比例(%) | ❌ | 可跳过，后续补录 |
| 下游金额 | ❌ | = 净保费 × 下游比例（系统自动计算） |

### 3.3 保存流程与后端逻辑

#### Step 1：前端校验
- 所有标注 `*` 必填字段不为空
- 保险止期 >= 起保日期
- 手续费比例 >= 0
- 金额字段为有效数字

#### Step 2：后端校验
1. **联合唯一索引校验**：`tenant_id + insurance_company_id + policy_no` 不可重复  
   _特例_：若在【保单设置】中，当前险种开启了"相同保单号不同产品录入"，则唯一索引为 `tenant_id + insurance_company_id + policy_no + product_id`
2. **业务员有效性校验**：业务员必须属于当前租户/机构下的有效人员
3. **标的标识与产品的一致性校验**：标的=车辆时，产品必须在系统产品库中存在

#### Step 3：数据写库
- 主表写入 `ins_non_vehicle_policy`
- 被保人信息写入 `ins_non_vehicle_insured`
- 共保信息写入 `ins_non_vehicle_co_insurer`

#### Step 4：触发政策匹配
保存成功后，系统异步/同步执行政策匹配：

```
匹配条件：
1. tenant_id = 当前租户
2. 保险公司ID = 保单.保险公司ID
3. 产品名称 = 保单.产品名称
4. 状态 = 正常（status = 1）
5. 日期匹配（按政策日期类型）：
   - 政策日期类型=签单日期：生效日期起 <= 保单.签单日期 <= 生效日期止
   - 政策日期类型=支付日期：生效日期起 <= 保单.支付日期 <= 生效日期止
6. 工号匹配：政策.适用工号 包含 保单.工号名称，或政策无工号限制
7. 机构匹配：政策.适用机构 包含 保单.归属机构，或政策无机构限制
```

匹配成功后自动回填：`upstream_rate`、`upstream_fee`、`downstream_rate`、`downstream_fee`  
若无匹配政策，保持手填值不变。

### 3.4 编辑保单

- 在保单查询列表点击【编辑】，进入与新增相同的表单页（预填已有数据）
- **限制**：若保单上游手续费已完成结算（`upstream_settle_status = 已结算`），则上游手续费比例和金额字段不可修改（置灰），并提示"已结算保单手续费不可修改"

---

## 四、保单管理 - 批单录入

> **对应PDF**：`87_非车-保单管理-非车批单录入`  
> **菜单路径**：【非车】→【保单管理】→【保单录入】→ 切换至【批单录入】Tab，或从保单查询列表点击【录入批单】  
> **工时**：前端1天 + 后端1.5天

### 4.1 操作流程

#### Step 1：输入原保单号
- 在「原保单号」输入框输入或粘贴原非车保单的保(批)单号
- 点击【查询】或失焦时自动触发：后端根据 `tenant_id + 保单号` 查询 `ins_non_vehicle_policy`
- 查询成功后只读回填：保险公司名称、险种、关联产品名称、原保单净保费、原保单上游手续费比例

#### Step 2：填写批改信息

| 字段名 | 必填 | 说明 |
|--------|------|------|
| 批改类型 | ✅ | 下拉：增保 / 减保 / 变更被保标的 / 其他 |
| 批改保单号 | ✅ | 新批改保单号，如原保单号-001 |
| 批改日期 | ✅ | 批改生效日期 |
| 支付日期 | ✅ | **无论加保退保，支付日期必须改为最新批单日期**（用于对账） |
| 批改保费差额 | ✅ | 加保填正数（如+200），退保填负数（如-500），单位：元 |
| 批改后净保费差额 | ❌ | 默认 = 批改保费差额，可手动修改 |

#### Step 3：手续费自动重算
当批改保费差额 ≠ 0 时，系统自动计算：
- 上游手续费差额 = 批改后净保费差额 × 原保单上游手续费比例
- 下游手续费差额 = 批改后净保费差额 × 原保单下游手续费比例
- 计算结果展示供用户确认，用户可手动覆盖

#### Step 4：保存
- 批单写入 `ins_non_vehicle_policy` 表，`policy_status = 3`（批改），`original_policy_no` 关联原保单
- 同时更新原保单净保费和手续费（按差额累加，或通过批改记录汇总计算）

### 4.2 批改历史

- 在保单查询列表点击某张保单的【批改历史】，弹窗展示该保单所有批改记录
- 按批改日期降序排列
- 字段：批改保单号、批改类型、批改日期、保费差额、操作人、操作时间

> 查询SQL：`SELECT * FROM ins_non_vehicle_policy WHERE original_policy_no = ? AND policy_status = 3`

---

## 五、保单管理 - 保单批量导入

> **对应PDF**：`88_非车-保单管理-非车保单导入`，`93_非车-保单管理-非车不能导入的排查步骤`  
> **菜单路径**：【非车】→【保单管理】→【保单查询】→ 点击【保单批量导入】按钮  
> **工时**：前端1.5天 + 后端2天

### 5.1 完整操作流程

#### Step 1：下载导入模板
- 点击【下载导入模板】，弹出模板选择弹窗
- 展示当前租户在【非车-系统设置-模板设置】中已配置并启用的导入模板列表
- 选中模板后下载 Excel，文件包含两个 Sheet：
  - **sheet1**：数据录入区，第一行为字段表头（**红色标注为必填字段**），第二行起录入数据
  - **sheet2**：导入字段说明/示例（各字段填写规范和枚举值参考）

#### Step 2：填写数据注意事项
- 险种类别和产品名称的值必须与系统【产品管理】中的数据**完全一致**（含全角/半角、空格）
- 日期格式：`yyyy-MM-dd`（如 `2024-01-15`），不支持斜杠 `/` 分隔

#### Step 3：上传文件
- 支持 `.xlsx` 或 `.xls` 格式，大小限制 10MB
- 支持点击选择或拖拽上传

#### Step 4：预解析与预览
上传后系统异步触发 EasyExcel 预解析：

1. **格式验证**：必填字段是否为空、日期格式是否合规、金额是否为数字
2. **险种/产品名称精确匹配**：与系统产品库 `ins_non_vehicle_product` 做精确匹配（Redis 缓存加速，O(1) 查找）
3. **重复保单检查**：`保险公司 + 保(批)单号` 是否已存在

预解析完成后：
- 有错误 → 弹出预览窗展示错误明细（行号 + 字段 + 错误原因）
- 无错误 → 直接进入确认步骤

#### Step 5：确认导入
- 用户点击【确认导入】，系统异步批量写库（MQ 或线程池，每批500行）
- 写库逻辑与手工录入一致，包括触发政策匹配

#### Step 6：查看任务状态

导入提交后跳转至【任务列表】查看进度：

| 列名 | 说明 |
|------|------|
| 任务ID | 批次号（UUID） |
| 导入时间 | 提交时间 |
| 总条数 | 文件总行数 |
| 成功条数 | 成功写库数 |
| 失败条数 | 失败数量 |
| 状态 | 处理中/成功/部分成功/失败 |
| 操作 | 【下载失败明细】 |

### 5.2 导入失败常见原因与排查

| 错误代码 | 错误提示 | 排查步骤 |
|----------|----------|----------|
| `ERR_PRODUCT_NOT_FOUND` | 产品与系统内的产品匹配不上 | ①查看表格中产品名称；②到【非车→产品管理】分别在「系统产品」和「自定义产品」Tab搜索；③查不到则新增后重新导入 |
| `ERR_TYPE_MISMATCH` | 险种和产品归属不匹配 | ①到产品管理找到该产品，确认险种类别；②**以系统中险种类别为准**更新表格后重新导入 |
| `ERR_DATE_FORMAT` | 日期格式错误 | 确认格式为 `yyyy-MM-dd`，不能用 `/` |
| `ERR_DUPLICATE` | 保单号重复 | 该保单已录入，如需修改请用【批量更新信息】 |
| `ERR_TEMPLATE_OLD` | 模板版本不匹配 | 重新下载最新版本模板 |
| `ERR_REQUIRED_EMPTY` | 必填字段为空 | 检查 sheet1 红色表头对应列是否漏填 |

失败明细下载后，Excel 最后一列追加"错误原因"说明，用户可在原文件基础上修正后重新上传。

### 5.3 后端技术实现要点

- **EasyExcel ReadListener**：分批（每批500行）写库，防止大文件内存溢出
- **Redis 缓存**：提前加载 `ins_non_vehicle_product` 全量到 Hash，O(1) 精确匹配
- **任务表**：导入任务状态存 `ins_import_task`，异步更新
- **失败明细**：失败行写入 `ins_import_task_error`，支持下载

---

## 六、保单管理 - 保单查询

> **对应PDF**：`89_目录`，`90_查询条件设置`，`91_查询列表字段设置`，`92_批量更新信息`  
> **菜单路径**：【非车】→【保单管理】→【保单查询】  
> **工时**：前端2天 + 后端2天

### 6.1 查询条件

#### 固定条件（不可移除，灰色显示）
- 日期类型（签单日期/支付日期/起保日期）+ 日期区间（起止日期选择器）
- 保险公司（下拉多选）
- 保单状态（下拉多选）

#### 可选条件（用户可选择展示，通过【筛选设置】配置）

| 条件字段 | 控件类型 |
|----------|----------|
| 保(批)单号 | 文本（支持逗号分隔多个，由保单设置开关控制） |
| 业务员 | 下拉搜索 |
| 险种 | 下拉树形（多级联动） |
| 产品名称 | 文本模糊匹配 |
| 工号名称 | 下拉搜索 |
| 业务员登录名 | 文本 |
| 渠道名称 | 文本/下拉 |
| 保单来源 | 下拉 |
| 出单来源 | 下拉 |
| 出单员 | 下拉搜索 |
| 出单机构 | 树形选择 |
| 被保险人姓名 | 文本模糊 |
| 投保人姓名 | 文本模糊 |
| 投保人证件号 | 文本精确 |
| 上游结算状态 | 下拉：已结算/未结算 |
| 共保标识 | 下拉：是/否 |
| 经办人 | 下拉搜索 |

### 6.2 查询条件自定义设置（个人级）

**入口**：保单查询页顶部，点击【筛选设置】按钮

**弹窗交互**：
- 右侧「可添加条件」：全量可选条件，每项有勾选框
- 左侧「已启用条件」：已勾选的条件，支持上下拖拽排序；固定条件灰色不可移除
- 在右侧勾选某条件 → 出现在左侧末尾
- 在左侧点击已启用的蓝色条件 → 移除（同时右侧取消勾选）
- 在左侧拖拽卡片 → 调整展示顺序
- 点击【确定】保存；点击【取消】不保存

**后端存储**：
- 按 `用户ID + 模块标识（non_vehicle_query）` 存入 `sys_user_config` 表
- JSON 格式：`[{"fieldCode":"policy_no","sort":1},{"fieldCode":"salesperson","sort":2}]`
- 用户未配置时使用系统默认配置

### 6.3 查询列表字段

**固定列（不可移除）**：保险公司、保(批)单号、操作列

**可选列（部分常用）**：

| 字段 | 说明 |
|------|------|
| 业务员 | — |
| 起保日期 | — |
| 保险止期 | — |
| 险种类型 | — |
| 产品名称 | — |
| 全保费 | — |
| 净保费 | — |
| 上游手续费比例(%) | — |
| 上游手续费金额 | — |
| 下游手续费比例(%) | — |
| 下游手续费金额 | — |
| 保单状态 | — |
| 签单日期 | — |
| 支付日期 | — |
| 投保人名称 | — |
| 被保人姓名 | — |
| 工号名称 | — |
| 渠道名称 | — |
| 业务来源 | — |
| 录入方式 | — |
| 上游结算状态 | — |
| 机构名称 | — |

### 6.4 列表字段自定义设置（个人级）

**入口**：列表右上角字段设置图标（齿轮/列图标）

**弹窗交互**：同查询条件设置弹窗的交互模式（右侧可选，左侧已选可拖拽排序）

**后端存储**：按 `用户ID + 模块标识（non_vehicle_column）` 存储

**字段元数据接口**：`GET /non-vehicle/policy/column-config/meta` 返回全量字段定义，前端动态渲染列，不硬编码

### 6.5 列表底部汇总行

固定展示当前查询条件下的全量合计（不只是当前分页）：
- 总保费合计 = SUM(全保费)
- 净保费合计 = SUM(净保费)
- 上游手续费合计 = SUM(上游手续费金额)
- 下游手续费合计 = SUM(下游手续费金额)

后端在列表查询时额外执行一条 SUM 聚合 SQL。

### 6.6 列表操作项

| 操作 | 说明 |
|------|------|
| 编辑 | 进入保单编辑表单 |
| 删除 | 逻辑删除（需未结算）；二次确认 |
| 录入批单 | 跳转批单录入页，预填原保单号 |
| 批改历史 | 弹窗展示批改记录 |
| 导出 | EasyExcel 异步导出，按当前查询条件全量导出 |

---

## 七、保单管理 - 批量更新信息

> **对应PDF**：`92_非车-保单管理-非车批量更新信息`  
> **菜单路径**：【非车】→【保单管理】→【保单查询】→ 点击【批量更新信息】  
> **工时**：前端1天 + 后端1天

### 7.1 操作流程

#### Step 1：下载导入模板
- 弹出弹窗，点击【下载导入模板】
- Excel 含两个 Sheet：
  - **sheet1**：A列为保单号（必填，作为主键定位），B列起为可修改的字段列
  - **sheet2**：字段参考说明（枚举值及填写规范）

#### Step 2：填写数据
- A列保单号必填
- 只填需要修改的字段列，不修改的列留空（后端只更新有值的字段）
- 若同一保单号存在多条记录（相同保单号不同产品场景），**C列产品名称必填**以精确定位

#### Step 3：上传文件
- 确认弹窗中「允许覆盖」开关为**开启状态**（默认关闭，开启后才会覆盖现有数据）

#### Step 4：执行更新
- 提交后跳转【任务列表】查看状态
- 状态失败时可下载失败明细 Excel，查看最后一列「校验结果」后修改重新上传

### 7.2 后端校验规则

1. A列保单号必须在系统中存在，否则报错「保单不存在」
2. **已结算保单手续费保护**：若 `upstream_settle_status = 已结算`，则更新中的「上游手续费比例」「上游手续费金额」字段**忽略不更新**，结果中提示「已结算保单费率不予更新」
3. 每次更新写入操作审计日志：操作人、时间、类型（批量更新）、涉及保单ID列表、更新前后字段快照（JSON diff）

---

## 八、保单管理 - 导入失败排查

> **对应PDF**：`93_非车-保单管理-非车不能导入的排查步骤`  
> **工时**：前端0.5天 + 后端0.5天

### 8.1 功能说明

无独立路由，在导入失败时，错误弹窗底部展示「常见原因排查」折叠面板，引导用户自助排查。

### 8.2 前端交互

在导入错误弹窗底部展示折叠面板，列出常见错误类型及操作指引，引导用户：
1. 到产品管理界面核查产品名称/险种一致性
2. 按提示修改 Excel 文件后重新上传
3. 下载失败明细 Excel，根据错误列说明逐条修复

---

## 九、政策管理 - 新增政策批次

> **对应PDF**：`94_非车-政策设置-目录`，`95_非车-政策设置-新增政策批次`  
> **菜单路径**：【非车】→【政策管理】→【非车政策】→ 点击【新增政策批次】  
> **工时**：前端2天 + 后端2天

### 9.1 政策基本配置

| 字段名 | 必填 | 说明 |
|--------|------|------|
| 政策批次名称 | ✅ | 自定义，如「2024年财产险Q1政策」 |
| 保险公司 | ✅ | 选择后联动产品方案和承保条件 |
| 日期类型 | ✅ | 签单日期 / 支付日期；决定政策匹配使用哪个日期字段 |
| 状态 | ✅ | **正常**：保存后立即生效；**待确认**：草稿，不匹配保单 |
| 生效日期起 | ✅ | 政策有效期开始 |
| 生效日期止 | ✅ | 必须 > 生效日期起 |
| 投保区域 | ❌ | 省市多选，不选则适用全部区域；**未知区域适用于未上牌车辆** |
| 适用工号 | ❌ | 多选。**前提**：须在【车险-报价出单-出单工号-编辑-工号范围】中选择了「非车」或「车险及非车」，该工号才会出现在此列表 |
| 适用机构 | ❌ | 多选树形，仅归属所选机构的保单可匹配此政策 |
| 备注 | ❌ | 自定义说明 |

### 9.2 产品点位配置（表格形式）

每行代表一个产品维度的点位配置：

| 列名 | 必填 | 说明 |
|------|------|------|
| 产品名称 | ✅ | 点击编辑图标弹出产品选择器；若产品不存在，先到产品管理新增 |
| 产品方案 | ❌ | 依赖保险公司加载，若无则在产品管理中新增 |
| 承保条件 | ❌ | **须先选好保司**才能选承保条件；按原始政策文件勾选 |
| 价税分离 | ❌ | 开启：按净保费计算手续费；关闭：按全保费（总保费）计算手续费 |
| 上游手续费比例(%) | ✅ | 保险公司给付的手续费比例 |
| 下游手续费比例(%) | ❌ | 给到业务员/机构的通用点位 |
| 操作 | — | 【+】新增一行；【垃圾桶】删除本行 |

**下游独立设置（可选）**：
- 点击每行的【设置下游】，为特定组织部门或业务员单独配置不同的下游比例（覆盖通用点位）
- 格式：选择目标（组织/业务员）+ 填写独立下游比例

### 9.3 保存校验逻辑

**前端校验**：
- 政策批次名称、保险公司、日期类型、生效日期不为空
- 生效日期止 > 生效日期起
- 至少配置一行产品点位
- 上游比例为有效数字

**后端校验**：
1. 检查是否存在**生效日期区间重叠**且**保险公司相同**的「正常」状态政策（允许用户选择是否强制保存）
2. 状态=「正常」时，保存后立即生效

**数据写库**：
- 政策批次 → `ins_non_vehicle_policy_batch`
- 产品点位 → `ins_non_vehicle_policy_item`
- 下游独立点位 → `ins_non_vehicle_policy_downstream`

### 9.4 政策匹配引擎（后端核心逻辑）

```
1. 查找候选政策批次：
   WHERE tenant_id=? AND insurance_company_id=? AND status=1（正常）
     AND 日期条件满足 AND 工号条件满足 AND 机构条件满足

2. 在候选批次的产品点位中：
   匹配 product_name = 保单.产品名称 的行

3. 取匹配行，应用价税分离：
   - is_tax_separate=1：手续费基数 = 净保费
   - is_tax_separate=0：手续费基数 = 全保费

4. 上游手续费 = 手续费基数 × upstream_rate
5. 下游手续费：查找 ins_non_vehicle_policy_downstream 中是否有针对
   当前业务员或机构的独立下游比例，有则取独立值，无则取通用 downstream_rate
   下游手续费 = 手续费基数 × downstream_rate

6. 回填到保单：upstream_rate, upstream_fee, downstream_rate, downstream_fee
   同时记录匹配到的 policy_batch_id
```

---

## 十、政策管理 - 政策其他操作

> **对应PDF**：`96_非车-政策设置-其他操作`  
> **工时**：前端1天 + 后端1天

### 10.1 政策列表

**展示字段**：政策批次名称、保险公司、生效日期、状态、创建时间、操作列

**可用操作**：

| 操作 | 说明 |
|------|------|
| 详情 | 查看政策信息，只读不可编辑 |
| 编辑 | 进入编辑表单。**如需编辑已生效政策，须先停用再编辑** |
| 复制 | 创建一份相同内容的新政策批次，状态默认为「待确认」，名称追加「-副本」，生效日期保留原日期（用户需手动修改） |
| 停用 | 弹出确认框，确认后 `status` 更新为 3（停用）。停用后不参与新保单政策匹配；历史已匹配保单不受影响 |
| 删除 | 逻辑删除该政策 |

### 10.2 状态流转

```
待确认（草稿）
    ↓ 修改状态为正常
正常（生效中）
    ↓ 手动停用
停用（失效）
```

---

## 十一、统计分析 - 险别占比分析

> **对应PDF**：`98_非车-统计分析-非车险别占比分析`  
> **菜单路径**：【非车】→【统计分析】→【险别占比分析】  
> **工时**：前端1天 + 后端1天

### 11.1 公共筛选条件（所有统计分析页共用）

| 字段 | 说明 |
|------|------|
| 日期类型 + 日期区间 | 签单日期/支付日期/起保日期，配合起止日期选择器 |
| 保险公司 | 下拉多选，不选则统计全部保司 |
| 险种 | 下拉多选，不选则统计全部险种 |
| 机构 | 树形选择，含下级汇总 |

### 11.2 公共统计指标说明

| 指标（列头缩写） | 计算公式 |
|----------------|----------|
| 单量 | COUNT(policy_id) |
| 总（总保费） | SUM(total_premium) |
| 净（净保费） | SUM(net_premium) |
| 收（上游手续费） | SUM(upstream_fee) |
| 支（下游手续费） | SUM(downstream_fee) |
| 利（利润） | 上游手续费 - 下游手续费 |
| 率（利润率） | 利润 / 净保费 × 100% |

### 11.3 页面结构

**顶部**：公共筛选条件区，点击【查询】刷新，点击【导出】导出 Excel

**中部图表区（双图）**：
- 左图：各险种单量占比饼图（ECharts Pie），图例含险种名称+单量+占比百分比
- 右图：各险种保费占比饼图（ECharts Pie），图例含险种名称+净保费+占比百分比
- 右上角可切换图表类型（饼图/柱状图）

**底部数据明细表**：

| 险种名称 | 单量 | 总 | 净 | 收 | 支 | 利 |
|---------|------|----|----|----|----|-----|
| 财产险 | | | | | | |
| 工程险 | | | | | | |
| 责任险 | | | | | | |
| 农险 | | | | | | |
| 健康险 | | | | | | |
| 其他 | | | | | | |
| **合计** | | | | | | |

### 11.4 后端接口

```
GET /non-vehicle/statistics/insurance-type-ratio
请求参数：dateType, startDate, endDate, companyIds, orgId
返回：{ chartData:[...], tableData:[...], total:{...} }
```

---

## 十二、统计分析 - 分支机构分析

> **对应PDF**：`99_非车-统计分析-非车分支机构分析`  
> **菜单路径**：【非车】→【统计分析】→【分支机构分析】  
> **工时**：前端1.5天 + 后端1.5天

### 12.1 页面结构

**顶部**：筛选条件区（含保险公司多选筛选）

**中部图表区**：
- 按所选保险公司分列展示各机构业绩柱状图（ECharts Bar）
- X轴：机构名称；Y轴：净保费
- 图表右侧下拉切换显示维度：总保费/净保费/单量

**左侧机构树**：
- 展示所有分支机构的树形结构
- 点击某节点，右侧表格只显示该机构（含下级）的数据

**右侧数据表**：
- 行：机构列表（含层级缩进）
- 列：合计列（单量/总保费/净保费/利润）+ 各保险公司分列（每保司一列，展示该机构在此保司的净保费）
- 若筛选了特定保司，只显示该保司的分列，其余列隐藏

### 12.2 后端接口

```
GET /non-vehicle/statistics/org-analysis
请求参数：dateType, startDate, endDate, companyIds, orgId
返回：机构树状结构 + 每个机构节点的各保司数据对象
```

SQL核心：按 `org_id + insurance_company_id` 两层 GROUP BY，应用层组装树形结构；动态列在应用层 Pivot 后前端动态渲染

---

## 十三、统计分析 - 保险公司分析

> **对应PDF**：`100_非车-统计分析-非车保险公司分析`  
> **菜单路径**：【非车】→【统计分析】→【保险公司分析】  
> **工时**：前端1天 + 后端1天

### 13.1 页面结构

**顶部**：公共筛选条件区

**中部图表区（双图）**：
- 左图：各保司单量排名柱状图（ECharts Bar，降序排列）
- 右图：各保司保费占比饼图（ECharts Pie）

**底部数据明细表**：

| 保险公司 | 单量 | 总 | 净 | 收 | 支 | 利 | 率 |
|---------|------|----|----|----|----|----|----|
| 平安财险 | | | | | | | |
| 人保财险 | | | | | | | |
| **合计** | | | | | | | |

> 列头说明（来自 PDF 100）：收=上游手续费，支=下游手续费，利=收-支，率=利/净

### 13.2 后端接口

```
GET /non-vehicle/statistics/company-analysis
请求参数：dateType, startDate, endDate, insuranceTypeIds, orgId
返回：{ chartData:[...], tableData:[...], total:{...} }
```

---

## 十四、统计分析 - 区域占比分析

> **对应PDF**：`101_非车-统计分析-非车区域占比分析`  
> **菜单路径**：【非车】→【统计分析】→【区域占比分析】  
> **工时**：前端1天 + 后端1天

### 14.1 页面结构

**顶部**：公共筛选条件区

**中部图表区（可切换）**：
- 饼图模式：各省市保单量占比饼图 + 各省市保费占比饼图
- 地图模式：ECharts Map 中国地图热力图，颜色深浅表示保费量大小，鼠标悬浮展示省份+保费总额

**底部数据明细表**：
- 按省市+机构+保险公司三维度交叉展示
- 字段：区域（省市）、机构名称、保险公司、单量、总保费、净保费、上游手续费、下游手续费、利润

### 14.2 区域数据来源

区域字段从保单录入时的 `region`（投保区域/省市）字段获取，统计时按 `region` GROUP BY；若为空则归入「未知地区」

### 14.3 后端接口

```
GET /non-vehicle/statistics/region-analysis
请求参数：dateType, startDate, endDate, companyIds, insuranceTypeIds, orgId
返回：{ mapData:[{name:'广东',value:1200000},...], tableData:[...] }
```

---

## 十五、统计分析 - 业务来源分析

> **对应PDF**：`102_非车-统计分析-非车业务来源分析`  
> **菜单路径**：【非车】→【统计分析】→【业务来源分析】  
> **工时**：前端1天 + 后端1天

### 15.1 页面结构

**顶部**：公共筛选条件区

**中部图表区**：
- 左：各渠道（直销/转介绍/经纪/代理/其他）业务量占比饼图
- 右：各渠道保费占比柱状图

**底部数据交叉统计表**：
- 行：业务来源渠道
- 列：保险公司分列（每个保司一列，展示该渠道在此保司的单量/保费）+ 合计行
- 字段：业务来源、单量、总保费、净保费、上游手续费、下游手续费、利润、[各保司列...]

### 15.2 后端接口

```
GET /non-vehicle/statistics/business-source-analysis
请求参数：dateType, startDate, endDate, companyIds, insuranceTypeIds, orgId
返回：{ chartData:[...], tableData:[...], companies:[保司列表，用于前端动态列渲染] }
```

---

## 十六、系统设置 - 产品管理

> **对应PDF**：`103_104_非车-系统设置-产品管理`  
> **菜单路径**：【非车】→【系统设置】→【产品管理】  
> **工时**：前端1天 + 后端1天

### 16.1 页面 Tab 结构

**险种类别 Tab**（只读）：
- 展示平台预置的非车险种类别列表（险种编码、险种名称、状态）
- 作为保单录入时险种下拉的数据源

**系统产品 Tab**（只读，不可增删改）：
- 展示平台预置的标准产品库
- **注意**：系统产品仅适用于标的标识为「车辆」的非车保单
- 查询条件：险种类别（下拉）、产品名称（模糊）
- 列表字段：保险公司、险种类别、产品名称、产品方案数量、状态

**自定义产品 Tab**（可增删改）：
- 用户自行维护的非标准产品
- **注意**：自定义产品在保单录入时，无论标的标识是人/物品/车辆，均可使用

### 16.2 自定义产品 - 新增

点击【新增产品】，弹出表单：

| 字段 | 必填 | 说明 |
|------|------|------|
| 保险公司 | ✅ | — |
| 险种类别 | ✅ | 从险种类别加载 |
| 产品名称 | ✅ | 全局唯一（同一租户内产品名称不可重复） |

**后端校验**：
1. `tenant_id + product_name` 唯一性校验
2. 保险公司和险种类别不为空
3. 保存成功后，产品立即在保单录入的产品下拉中可选，并参与导入时的产品名称匹配校验

### 16.3 自定义产品 - 编辑

- 可修改险种类别和产品名称（**保险公司不可修改**）
- 前端提示：若已有保单使用此产品，修改产品名称会影响已有保单的显示

### 16.4 自定义产品 - 删除

后端校验：是否有保单正在使用此产品（`ins_non_vehicle_policy.product_id = ?`）  
若有则拒绝删除，提示「该产品已被 XX 张保单使用，无法删除」

---

## 十七、系统设置 - 模板设置

> **对应PDF**：`105_非车-系统设置-模板设置`  
> **菜单路径**：【非车】→【系统设置】→【模板设置】  
> **工时**：前端1天 + 后端1天

### 17.1 模板列表

字段：模板名称、授权组织、创建时间、状态（启用/禁用）、操作（查看/编辑/禁用）

### 17.2 新增模板（Step 1：基本信息）

| 字段 | 必填 | 说明 |
|------|------|------|
| 模板名称 | ✅ | 如「非车业务数据导出」「财责险导入模板」 |
| 授权组织 | ❌ | 树形多选，限制可用机构；不选则全部可用 |

### 17.3 新增模板（Step 2：字段配置）

- **左侧「未选字段区」**：按大类分组（不可调整大类顺序），可单个勾选：
  - **基本信息**：保险公司、标的类型、险种编码、险种、互联网业务、涉农业务、保单状态、签单日期、起保日期、保险止期、支付日期、渠道名称、业务员、出单员、录入方式等
  - **组织结构**：归属机构、部门、团队等
  - **被保人信息**：被保人姓名、证件类型、证件号等
  - **投保人信息**：投保人名称、证件号等
  - **保单费用**：全保费、净保费
  - **上游手续费**：上游比例、上游金额、上游结算状态等
  - **下游手续费**：下游比例、下游金额、下游结算状态等
  - **批单信息**：原保单号、批改类型等

- **右侧「已选字段区」**：已勾选字段列表，支持拖拽调整顺序（**同一大类内可拖拽，大类顺序不变**）

### 17.4 禁用/删除模板

- 点击【禁用】：`status=0`，模板在保单导入/导出时不再出现在可选列表中

---

## 十八、系统设置 - 保单设置

> **对应PDF**：`106_非车-系统设置-保单设置`  
> **菜单路径**：【非车】→【系统设置】→【保单设置】  
> **工时**：前端1天 + 后端1天

> **注意**：修改保单设置后，需**点击保存并重新登录**才能生效（某些配置项影响前端缓存）。

### 18.1 录单设置（一）：保单业务归属

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 非车保单业务归属 | 单选：业务员/出单员/录单员 | 业务员 | 影响统计分析时保单按哪个人员字段汇总归属 |

存储：`sys_config` 表，`config_key = non_vehicle_policy_belong_type`

### 18.2 录单设置（二）：下游手续费校验

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 组织维度的下游手续费上限校验 | 勾选框（多选组织） | 不勾选 | 勾选某组织后，该组织人员修改保单时，下游手续费不得超过已匹配政策的比例 |

**后端逻辑**：保存非车保单时，若当前用户所属机构在校验列表中，读取匹配政策的 `downstream_rate`，若用户填写的 `downstream_rate` > 政策 `downstream_rate`，返回错误「下游手续费不能超过政策配置的 XX%」

存储：`sys_config` 表，`config_key = non_vehicle_downstream_check_orgs`，值为组织ID的 JSON 数组

### 18.3 录单设置（三）：相同保单号不同产品

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 允许同一险种下相同保单号录入不同产品 | 险种维度多选勾选框 | 全不勾选 | 开启后允许保单号相同但产品不同的保单同时存在 |

**默认情况**：`保险公司 + 保单号` 联合唯一，重复录入提示「保单号已存在」  
**开启后**：唯一约束变为 `保险公司 + 保单号 + 产品名称`（通过应用层逻辑处理）

存储：`sys_config` 表，`config_key = non_vehicle_same_policy_no_insurance_types`，值为险种ID列表

### 18.4 保单查询默认设置

| 配置项 | 类型 | 默认值 |
|--------|------|--------|
| 默认日期类型 | 单选 | 签单日期 |
| 默认查询时间范围 | 下拉：近1个月/近3个月/当月 | 近1个月 |
| 多保单号逗号分隔搜索 | 开关 | 关闭 |
| 未录入保单统计角标 | 开关 | 关闭 |

### 18.5 保字段自定义设置（非车保单 extra_fields）

- 支持租户自定义字段（如特殊险种需要录入的扩展信息）
- 自定义字段值存储在 `ins_non_vehicle_policy.extra_fields`（JSON 类型字段）
- 字段配置存入 `non_motor_field_config` 表
- 前端保单录入表单根据该配置动态渲染自定义字段区域

### 18.6 提醒设置 & 汇率设置

> **当前版本暂不实现**，为后期非车理赔模块预留功能。页面展示「敬请期待」占位说明。

---

## 十九、数据库设计汇总

### 19.1 非车险保单主表：`ins_non_vehicle_policy`

```sql
CREATE TABLE `ins_non_vehicle_policy` (
  `id`                    BIGINT        NOT NULL AUTO_INCREMENT,
  `tenant_id`             BIGINT        NOT NULL                 COMMENT '租户ID',
  `policy_no`             VARCHAR(100)  NOT NULL                 COMMENT '保(批)单号',
  `policy_status`         TINYINT       NOT NULL DEFAULT 1        COMMENT '1-正常 2-退保 3-批改 4-终止',
  `original_policy_no`    VARCHAR(100)            COMMENT '原保单号（批改时关联）',
  `insurance_company_id`  BIGINT        NOT NULL                 COMMENT '保险公司ID',
  `insurance_company_name` VARCHAR(100) NOT NULL                 COMMENT '保险公司名称',
  `subject_type`          TINYINT       NOT NULL                 COMMENT '标的标识 1-车辆 2-人 3-物品',
  `subject_name`          VARCHAR(200)            COMMENT '标的名称',
  `insurance_type_id`     BIGINT        NOT NULL                 COMMENT '险种ID',
  `insurance_type_name`   VARCHAR(100)  NOT NULL                 COMMENT '险种名称',
  `insurance_type_code`   VARCHAR(50)             COMMENT '险种编码',
  `product_id`            BIGINT                  COMMENT '产品ID',
  `product_name`          VARCHAR(200)  NOT NULL                 COMMENT '产品名称',
  `is_internet`           TINYINT(1)    DEFAULT 0 COMMENT '互联网业务 0-否 1-是',
  `is_agriculture`        TINYINT(1)    DEFAULT 0 COMMENT '涉农业务 0-否 1-是',
  `sign_date`             DATE          NOT NULL                 COMMENT '签单日期',
  `start_date`            DATE          NOT NULL                 COMMENT '起保日期',
  `end_date`              DATE          NOT NULL                 COMMENT '保险止期',
  `pay_date`              DATE                    COMMENT '支付日期',
  `channel_name`          VARCHAR(100)            COMMENT '渠道名称',
  `business_source`       VARCHAR(50)             COMMENT '业务来源',
  `salesman_id`           BIGINT        NOT NULL                 COMMENT '业务员ID',
  `salesman_name`         VARCHAR(100)  NOT NULL                 COMMENT '业务员姓名',
  `company_no_id`         BIGINT                  COMMENT '工号ID',
  `company_no_name`       VARCHAR(100)            COMMENT '工号名称',
  `issuer_id`             BIGINT                  COMMENT '出单员ID',
  `issuer_name`           VARCHAR(100)            COMMENT '出单员姓名',
  `entry_type`            VARCHAR(50)             COMMENT '录入方式',
  `is_co_insured`         TINYINT(1)    DEFAULT 0 COMMENT '共保标识 0-否 1-是',
  `org_id`                BIGINT                  COMMENT '归属机构ID',
  `org_name`              VARCHAR(200)            COMMENT '归属机构名称',
  `dept_id`               BIGINT                  COMMENT '部门ID',
  `region`                VARCHAR(100)            COMMENT '投保区域（省市）',
  `total_premium`         DECIMAL(14,2) NOT NULL DEFAULT 0 COMMENT '全保费（含税）',
  `net_premium`           DECIMAL(14,2) NOT NULL DEFAULT 0 COMMENT '净保费（不含税）',
  `upstream_rate`         DECIMAL(8,4)  DEFAULT 0 COMMENT '上游手续费比例(%)',
  `upstream_fee`          DECIMAL(14,2) DEFAULT 0 COMMENT '上游手续费金额',
  `upstream_settle_type`  VARCHAR(50)             COMMENT '上游结算方式',
  `upstream_settle_status` TINYINT      DEFAULT 0 COMMENT '0-未结算 1-已结算',
  `downstream_rate`       DECIMAL(8,4)  DEFAULT 0 COMMENT '下游手续费比例(%)',
  `downstream_fee`        DECIMAL(14,2) DEFAULT 0 COMMENT '下游手续费金额',
  `downstream_settle_status` TINYINT   DEFAULT 0 COMMENT '0-未结算 1-已结算',
  `policy_batch_id`       BIGINT                  COMMENT '匹配到的政策批次ID',
  `extra_fields`          JSON                    COMMENT '自定义扩展字段值（JSON）',
  `remark`                VARCHAR(500)            COMMENT '备注',
  `creator`               BIGINT,
  `create_time`           DATETIME      DEFAULT CURRENT_TIMESTAMP,
  `updater`               BIGINT,
  `update_time`           DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`               TINYINT(1)    DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_company_policy_no` (`tenant_id`, `insurance_company_id`, `policy_no`, `product_id`) COMMENT '联合唯一索引',
  KEY `idx_salesman_id` (`salesman_id`),
  KEY `idx_sign_date` (`sign_date`),
  KEY `idx_pay_date` (`pay_date`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB COMMENT='非车险保单主表';
```

### 19.2 被保人/关系人子表：`ins_non_vehicle_insured`

```sql
CREATE TABLE `ins_non_vehicle_insured` (
  `id`           BIGINT       NOT NULL AUTO_INCREMENT,
  `policy_id`    BIGINT       NOT NULL COMMENT '关联非车保单ID',
  `insured_type` TINYINT                COMMENT '1-车主 2-被保人 3-投保人',
  `name`         VARCHAR(200) NOT NULL  COMMENT '姓名',
  `cert_type`    VARCHAR(50)            COMMENT '证件类型',
  `cert_no`      VARCHAR(100)           COMMENT '证件号（AES-256加密存储）',
  `cert_no_mask` VARCHAR(50)            COMMENT '证件号脱敏显示版本',
  `birthday`     DATE                   COMMENT '出生日期（人身险）',
  `plate_no`     VARCHAR(50)            COMMENT '车牌号（标的=车辆时）',
  `vin`          VARCHAR(100)           COMMENT '车架号',
  `engine_no`    VARCHAR(100)           COMMENT '发动机号',
  `create_time`  DATETIME     DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB COMMENT='非车险被保人/关系人子表';
```

### 19.3 共保子表：`ins_non_vehicle_co_insurer`

```sql
CREATE TABLE `ins_non_vehicle_co_insurer` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT,
  `policy_id`        BIGINT       NOT NULL COMMENT '关联非车保单ID',
  `co_company_id`    BIGINT       NOT NULL COMMENT '共保保险公司ID',
  `co_company_name`  VARCHAR(100) NOT NULL,
  `co_policy_no`     VARCHAR(100)           COMMENT '共保保单号',
  `co_premium_ratio` DECIMAL(8,4)           COMMENT '共保保费比例(%)',
  `create_time`      DATETIME     DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB COMMENT='非车险共保信息子表（仅适用于标的=人或物品的保单）';
```

### 19.4 政策批次表：`ins_non_vehicle_policy_batch`

```sql
CREATE TABLE `ins_non_vehicle_policy_batch` (
  `id`                    BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`             BIGINT       NOT NULL,
  `batch_name`            VARCHAR(200) NOT NULL COMMENT '政策批次名称',
  `insurance_company_id`  BIGINT       NOT NULL COMMENT '保险公司ID',
  `date_type`             TINYINT      NOT NULL COMMENT '1-签单日期 2-支付日期',
  `status`                TINYINT      NOT NULL DEFAULT 2 COMMENT '1-正常 2-待确认 3-停用',
  `valid_start`           DATE         NOT NULL COMMENT '生效日期起',
  `valid_end`             DATE         NOT NULL COMMENT '生效日期止',
  `region_ids`            JSON                   COMMENT '投保区域省市ID列表',
  `apply_no_ids`          JSON                   COMMENT '适用工号ID列表',
  `apply_org_ids`         JSON                   COMMENT '适用机构ID列表',
  `remark`                VARCHAR(500),
  `creator`               BIGINT,
  `create_time`           DATETIME     DEFAULT CURRENT_TIMESTAMP,
  `updater`               BIGINT,
  `update_time`           DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`               TINYINT(1)   DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_company_status` (`insurance_company_id`, `status`)
) ENGINE=InnoDB COMMENT='非车险政策批次表';
```

### 19.5 政策产品点位表：`ins_non_vehicle_policy_item`

```sql
CREATE TABLE `ins_non_vehicle_policy_item` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT,
  `batch_id`        BIGINT       NOT NULL COMMENT '政策批次ID',
  `product_id`      BIGINT                COMMENT '产品ID',
  `product_name`    VARCHAR(200) NOT NULL COMMENT '产品名称',
  `product_plan`    VARCHAR(200)           COMMENT '产品方案',
  `underwrite_cond` JSON                   COMMENT '承保条件（选中项）',
  `is_tax_separate` TINYINT(1)   DEFAULT 0 COMMENT '价税分离 0-否(按全保费) 1-是(按净保费)',
  `upstream_rate`   DECIMAL(8,4) NOT NULL  COMMENT '上游手续费比例(%)',
  `downstream_rate` DECIMAL(8,4)           COMMENT '通用下游手续费比例(%)',
  `sort`            INT          DEFAULT 0 COMMENT '排序',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`)
) ENGINE=InnoDB COMMENT='非车险政策产品点位配置表';
```

### 19.6 政策下游独立点位表：`ins_non_vehicle_policy_downstream`

```sql
CREATE TABLE `ins_non_vehicle_policy_downstream` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT,
  `item_id`         BIGINT       NOT NULL COMMENT '政策产品点位ID',
  `target_type`     TINYINT               COMMENT '1-组织 2-业务员',
  `target_id`       BIGINT       NOT NULL COMMENT '组织ID或业务员ID',
  `target_name`     VARCHAR(200),
  `downstream_rate` DECIMAL(8,4) NOT NULL COMMENT '独立下游比例(%)',
  PRIMARY KEY (`id`),
  KEY `idx_item_id` (`item_id`)
) ENGINE=InnoDB COMMENT='非车险政策下游独立点位表';
```

### 19.7 产品库表：`ins_non_vehicle_product`

```sql
CREATE TABLE `ins_non_vehicle_product` (
  `id`                    BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`             BIGINT       NOT NULL,
  `insurance_company_id`  BIGINT                COMMENT '保险公司ID（自定义产品可选）',
  `insurance_type_id`     BIGINT       NOT NULL COMMENT '险种类别ID',
  `insurance_type_name`   VARCHAR(100) NOT NULL COMMENT '险种类别名称',
  `product_name`          VARCHAR(200) NOT NULL COMMENT '产品名称',
  `product_type`          TINYINT      NOT NULL COMMENT '1-系统产品 2-自定义产品',
  `status`                TINYINT      DEFAULT 1 COMMENT '1-启用 0-禁用',
  `creator`               BIGINT,
  `create_time`           DATETIME     DEFAULT CURRENT_TIMESTAMP,
  `updater`               BIGINT,
  `update_time`           DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`               TINYINT(1)   DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_product_name` (`tenant_id`, `product_name`, `deleted`)
) ENGINE=InnoDB COMMENT='非车险产品库';
```

### 19.8 导入模板表：`ins_non_vehicle_template`

```sql
CREATE TABLE `ins_non_vehicle_template` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`     BIGINT       NOT NULL,
  `template_name` VARCHAR(200) NOT NULL COMMENT '模板名称',
  `org_ids`       JSON                   COMMENT '授权组织ID列表',
  `status`        TINYINT      DEFAULT 1 COMMENT '1-启用 0-禁用',
  `creator`       BIGINT,
  `create_time`   DATETIME     DEFAULT CURRENT_TIMESTAMP,
  `updater`       BIGINT,
  `update_time`   DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`       TINYINT(1)   DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB COMMENT='非车险Excel模板配置表';
```

### 19.9 导入模板字段配置表：`ins_non_vehicle_template_field`

```sql
CREATE TABLE `ins_non_vehicle_template_field` (
  `id`          BIGINT       NOT NULL AUTO_INCREMENT,
  `template_id` BIGINT       NOT NULL COMMENT '模板ID',
  `field_group` VARCHAR(100)           COMMENT '字段大类名称',
  `field_code`  VARCHAR(100) NOT NULL  COMMENT '字段代码（对应policy表字段名）',
  `field_label` VARCHAR(200) NOT NULL  COMMENT '字段显示名称（Excel列头）',
  `is_required` TINYINT(1)   DEFAULT 0 COMMENT '是否必填（导入时）',
  `sort`        INT          DEFAULT 0 COMMENT '排序',
  PRIMARY KEY (`id`),
  KEY `idx_template_id` (`template_id`)
) ENGINE=InnoDB COMMENT='非车险模板字段配置明细表';
```

### 19.10 导入任务表：`ins_import_task`

```sql
CREATE TABLE `ins_import_task` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`     BIGINT       NOT NULL,
  `task_type`     VARCHAR(50)  NOT NULL COMMENT '任务类型：non_vehicle_import / non_vehicle_update',
  `batch_no`      VARCHAR(100) NOT NULL COMMENT '批次号（UUID）',
  `total_count`   INT          DEFAULT 0,
  `success_count` INT          DEFAULT 0,
  `fail_count`    INT          DEFAULT 0,
  `status`        TINYINT      DEFAULT 0 COMMENT '0-处理中 1-成功 2-部分成功 3-失败',
  `file_url`      VARCHAR(500)           COMMENT '原始上传文件URL',
  `fail_file_url` VARCHAR(500)           COMMENT '失败明细文件URL',
  `creator`       BIGINT,
  `create_time`   DATETIME     DEFAULT CURRENT_TIMESTAMP,
  `update_time`   DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB COMMENT='保单导入/批量更新任务表';
```

### 19.11 保单字段自定义配置表：`non_motor_field_config`

```sql
CREATE TABLE `non_motor_field_config` (
  `id`           BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`    BIGINT       NOT NULL,
  `field_code`   VARCHAR(100) NOT NULL COMMENT '自定义字段代码',
  `field_label`  VARCHAR(200) NOT NULL COMMENT '字段显示名称',
  `field_type`   VARCHAR(50)  NOT NULL COMMENT '字段类型：text/number/date/select',
  `is_required`  TINYINT(1)   DEFAULT 0,
  `options`      JSON                   COMMENT '下拉选项（field_type=select时）',
  `sort`         INT          DEFAULT 0,
  `status`       TINYINT      DEFAULT 1,
  `creator`      BIGINT,
  `create_time`  DATETIME     DEFAULT CURRENT_TIMESTAMP,
  `updater`      BIGINT,
  `update_time`  DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`      TINYINT(1)   DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB COMMENT='非车险保单自定义字段配置表';
```

---

## 二十、接口清单汇总

### 20.1 保单管理接口

| 接口 URL | 方法 | 说明 |
|----------|------|------|
| `/non-vehicle/policy/create` | POST | 手工新增非车保单 |
| `/non-vehicle/policy/update/{id}` | PUT | 编辑非车保单 |
| `/non-vehicle/policy/delete/{id}` | DELETE | 逻辑删除非车保单 |
| `/non-vehicle/policy/page` | GET | 分页查询保单列表 |
| `/non-vehicle/policy/{id}` | GET | 查询保单详情 |
| `/non-vehicle/policy/summary` | GET | 查询列表汇总行（SUM合计） |
| `/non-vehicle/policy/endorsement/create` | POST | 新增批单 |
| `/non-vehicle/policy/{id}/endorsement-history` | GET | 查询批改历史 |
| `/non-vehicle/policy/match-policy` | POST | 触发/重新触发政策匹配 |
| `/non-vehicle/policy/column-config/meta` | GET | 获取全量字段元数据 |
| `/non-vehicle/policy/column-config` | GET/POST | 读写用户字段个性化配置 |
| `/non-vehicle/policy/filter-config` | GET/POST | 读写用户筛选条件个性化配置 |

### 20.2 导入导出接口

| 接口 URL | 方法 | 说明 |
|----------|------|------|
| `/non-vehicle/policy/import/template/download` | GET | 下载导入模板（需传模板ID） |
| `/non-vehicle/policy/import/upload` | POST | 上传导入文件（multipart/form-data） |
| `/non-vehicle/policy/import/confirm/{taskId}` | POST | 预解析完成后确认导入 |
| `/non-vehicle/policy/import/task/list` | GET | 导入任务列表 |
| `/non-vehicle/policy/import/task/{taskId}/error/download` | GET | 下载失败明细 |
| `/non-vehicle/policy/bulk-update/upload` | POST | 批量更新信息文件上传 |
| `/non-vehicle/policy/export` | GET | 保单导出（EasyExcel异步） |

### 20.3 政策管理接口

| 接口 URL | 方法 | 说明 |
|----------|------|------|
| `/non-vehicle/policy-rule/page` | GET | 政策批次列表 |
| `/non-vehicle/policy-rule/create` | POST | 新增政策批次 |
| `/non-vehicle/policy-rule/update/{id}` | PUT | 编辑政策批次 |
| `/non-vehicle/policy-rule/copy/{id}` | POST | 复制政策批次 |
| `/non-vehicle/policy-rule/disable/{id}` | PUT | 停用政策批次 |
| `/non-vehicle/policy-rule/delete/{id}` | DELETE | 删除政策批次 |
| `/non-vehicle/policy-rule/{id}/detail` | GET | 政策批次详情 |

### 20.4 统计分析接口

| 接口 URL | 方法 | 说明 |
|----------|------|------|
| `/non-vehicle/statistics/insurance-type-ratio` | GET | 险别占比分析 |
| `/non-vehicle/statistics/org-analysis` | GET | 分支机构分析 |
| `/non-vehicle/statistics/company-analysis` | GET | 保险公司分析 |
| `/non-vehicle/statistics/region-analysis` | GET | 区域占比分析 |
| `/non-vehicle/statistics/business-source-analysis` | GET | 业务来源分析 |
| `/non-vehicle/statistics/{type}/export` | GET | 统计分析导出 |

### 20.5 系统设置接口

| 接口 URL | 方法 | 说明 |
|----------|------|------|
| `/non-vehicle/product/page` | GET | 产品列表（含系统/自定义） |
| `/non-vehicle/product/create` | POST | 新增自定义产品 |
| `/non-vehicle/product/update/{id}` | PUT | 编辑自定义产品 |
| `/non-vehicle/product/delete/{id}` | DELETE | 删除自定义产品 |
| `/non-vehicle/template/list` | GET | 模板列表 |
| `/non-vehicle/template/create` | POST | 新增模板 |
| `/non-vehicle/template/update/{id}` | PUT | 编辑模板 |
| `/non-vehicle/template/disable/{id}` | PUT | 禁用模板 |
| `/non-vehicle/settings/policy-config` | GET/POST | 读写保单设置 |
| `/non-vehicle/settings/field-config` | GET/POST | 读写字段自定义设置 |

---

## 二十一、微服务代码组织结构

```
intermediary-module-ins-order
├── controller/
│   └── admin/
│       ├── AdminNonVehiclePolicyController.java       # 保单录入/查询/导入/导出/批量操作
│       ├── AdminNonVehicleEndorsementController.java  # 批单管理
│       ├── AdminNonVehiclePolicyRuleController.java   # 政策管理
│       ├── AdminNonVehicleStatisticsController.java   # 统计分析
│       ├── AdminNonVehicleProductController.java      # 产品管理
│       ├── AdminNonVehicleTemplateController.java     # 模板设置
│       └── AdminNonVehicleSettingsController.java     # 保单设置
│
├── service/
│   ├── NonVehiclePolicyService.java / Impl
│   ├── NonVehicleEndorsementService.java / Impl
│   ├── NonVehiclePolicyMatchService.java / Impl      # 政策匹配引擎
│   ├── NonVehicleImportService.java / Impl           # 导入服务（EasyExcel）
│   ├── NonVehicleStatisticsService.java / Impl
│   └── NonVehicleSettingsService.java / Impl
│
├── dal/
│   └── mysql/
│       ├── InsNonVehiclePolicyMapper.java
│       ├── InsNonVehicleInsuredMapper.java
│       ├── InsNonVehicleCoInsurerMapper.java
│       ├── InsNonVehiclePolicyBatchMapper.java
│       ├── InsNonVehiclePolicyItemMapper.java
│       ├── InsNonVehiclePolicyDownstreamMapper.java
│       ├── InsNonVehicleProductMapper.java
│       ├── InsNonVehicleTemplateMapper.java
│       └── InsImportTaskMapper.java
│
└── enums/
    ├── NonVehicleSubjectTypeEnum.java    # 标的标识：1车辆/2人/3物品
    ├── NonVehiclePolicyStatusEnum.java   # 保单状态：1正常/2退保/3批改/4终止
    └── NonVehiclePolicyRuleStatusEnum.java # 政策状态：1正常/2待确认/3停用
```

### 21.1 关键技术约束

| 约束项 | 规范 |
|--------|------|
| 多租户隔离 | 所有表含 `tenant_id`，所有查询必须带 `tenant_id` 条件 |
| 数据权限 | 基于 `@DataPermission` 注解，按角色控制数据可见范围 |
| 无物理外键 | 不使用数据库外键约束，通过应用层保证引用完整性 |
| 敏感数据加密 | 证件号（`cert_no`）AES-256 加密存储；`cert_no_mask` 存储脱敏版本 |
| 软删除 | 所有主要数据表含 `deleted` 字段，逻辑删除 |
| 导出大数据量 | 超过2000条时异步导出，通过站内信通知下载链接 |
| 统计查询缓存 | 统计分析接口结果缓存 Redis，TTL 15分钟，Key格式：`ins:nonvehicle:stat:{tenantId}:{type}:{hash}` |
| 导入分批写库 | EasyExcel ReadListener 每批 500 行，防止大文件内存溢出 |
| 政策匹配触发 | 保单保存成功后，异步发送 RocketMQ 消息触发政策匹配，避免阻塞主流程 |

---

*文档结束 | 版本 V1.0 | 对应操作手册 PDF 84-106 | 对应排期表：阶段2-PC管理后台-非车险业务*

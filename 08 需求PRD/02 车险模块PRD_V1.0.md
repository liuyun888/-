# 保险中介平台 · 车险模块产品需求文档（PRD）

**文档信息**

| 项目 | 内容 |
|------|------|
| 项目名称 | 保险中介全域数字化平台（intermediary-cloud） |
| 模块 | 车险（Car Insurance） |
| 微服务模块 | intermediary-module-ins-order / yudao-module-carins |
| 数据库 Schema | db_ins_order |
| 表前缀 | ins_order_policy_car_ / carins_ |
| 版本 | V1.0 |
| 编写日期 | 2026-03 |
| 技术框架 | yudao-cloud（Spring Cloud Alibaba） |
| 文档范围 | 业务员App + PC管理后台 + C端小程序 车险全链路 |

---

## 目录

1. 模块概述
2. 业务流程总览
3. PC管理后台 · 保单录入
4. PC管理后台 · 保单查询
5. PC管理后台 · 保单设置
6. PC管理后台 · 报表与统计分析
7. 业务员App · 车险报价（上）— 车辆信息录入
8. 业务员App · 车险报价（中）— 投保方案配置与多保司报价引擎
9. 业务员App · 车险报价（下）— 报价单生成与分享
10. 业务员App · 续保管理
11. C端小程序 · 车险投保
12. 数据库核心表设计
13. 接口清单
14. 权限矩阵

---

## 一、模块概述

### 1.1 模块定位

车险模块是保险中介平台的核心业务模块之一，覆盖**交强险**与**商业险**两大险种，提供从客户获取、报价询价、投保出单、保单管理到续保跟进的完整业务闭环。

**服务对象**：
- B端业务员（移动App）：车辆信息录入、报价询价、报价单生成与分享、续保跟进
- PC内勤/管理人员（管理后台）：保单录入、查询、统计分析、政策配置
- C端客户（微信小程序/H5）：在线报价、自助投保、保单查看

### 1.2 核心功能范围

| 功能域 | 子功能 | 端 |
|-------|--------|-----|
| 保单管理 | 手工录入、批量导入、批改、退保、查询、导出 | PC |
| 报价引擎 | 车辆信息录入（OCR/VIN/手工）、险种配置、多保司并发询价 | App |
| 报价单 | PDF生成、H5分享、客户行为追踪 | App |
| 续保管理 | 自动任务生成、跟进记录、成交/流失 | App + PC |
| 统计报表 | 出单统计、业务来源分析、保司分析、业务员绩效 | PC |
| 保单设置 | 格式规则、同步设置、场景配置 | PC |
| C端投保 | 车险在线报价、投保、支付 | C端 |

### 1.3 技术约定

- 框架：yudao-cloud 微服务版，包命名空间 `cn.qmsk.intermediary`
- 无物理外键，应用层维护引用完整性
- 证件号、银行卡号、手机号 AES-256 加密存储，黑名单查询使用 SHA-256 哈希
- 标准审计字段：`creator / create_time / updater / update_time / deleted / tenant_id`
- 数据权限通过 yudao-cloud `@DataPermission` 注解实现

---

## 二、业务流程总览

### 2.1 车险出单主流程

```
客户意向
   ↓
[App] 录入车辆信息（OCR行驶证 / VIN解析 / 手工录入）
   ↓
[App] 配置投保方案（险种组合 + 保额选择）
   ↓
[App] 触发多保司并发询价（人保/平安/太保等）
   ↓
[App] 展示报价结果 → 生成PDF报价单 → H5分享给客户
   ↓
客户确认方案
   ↓
[PC/App] 录入保单 / C端自助投保
   ↓
保单写库 → 触发佣金计算（MQ异步）→ 更新续保队列
```

### 2.2 续保管理流程

```
[定时任务 凌晨2:00] 扫描到期保单（到期日 ≤ 今天+60天）
   ↓
生成续保任务（carins_renewal_task，PENDING状态）
   ↓
[App] 业务员查看续保待办 → 记录跟进（电话/微信/上门）
   ↓
发送续保提醒（短信/App Push/微信服务号，提前30/15/7/3天）
   ↓
业务员发起新一年报价 → 客户确认 → 出单
   ↓
标记续保任务 CLOSED_WON（成交）
或
标记续保任务 CLOSED_LOST（流失，记录原因）
```

---

## 三、PC管理后台 · 保单录入

**菜单路径**：车险 → 保单管理 → 保单录入

**前端工时**：32天 | **后端工时**：32天

### 3.1 手工单笔录入

#### 3.1.1 页面入口

进入菜单后，默认展示**单笔录入**选项卡。页面顶部两个 Tab：「单笔录入」「批量录入」，默认激活单笔录入。

#### 3.1.2 录入表单字段

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| 保险公司 | 下拉 | ✅ | 从已配置保司列表获取 |
| 出单工号 | 下拉 | ✅ | 根据所选保险公司联动过滤，只展示该保司下已配置且有效的工号 |
| 业务员 | 人员选择器 | ✅ | 从组织架构人员中选择 |
| 出单员 | 人员选择器 | 否 | 可为空，表示与业务员相同 |
| 险种类型 | 单选 | ✅ | 交强险 / 商业险 / 交商合并 |
| 保单号 | 文本 | ✅ | 按保单设置中格式规则做前端正则校验 |
| 车牌号 | 文本 | 否 | 允许新能源车牌格式 |
| VIN 码 | 文本 | 否 | 17 位字母数字 |
| 车型 | 文本 | 否 | 车辆品牌+型号描述 |
| 保费（交强） | 金额 | 条件必填 | 险种含交强险时必填，单位元，两位小数 |
| 保费（商业） | 金额 | 条件必填 | 险种含商业险时必填 |
| 车船税 | 金额 | 否 | 允许为0 |
| 签单日期 | 日期 | ✅ | 不能晚于今天 |
| 支付日期 | 日期 | 否 | 不早于签单日期 |
| 起保日期 | 日期 | ✅ | |
| 保险止期 | 日期 | ✅ | 必须晚于起保日期 |
| 录入方式 | 单选 | ✅ | 直连 / 手工，默认手工 |
| 业务来源 | 下拉 | 否 | 直销/转介绍/网销/电销等（字典 `ins_dict_business_source`） |
| 产品备注 | 文本 | 否 | 自定义备注 |

#### 3.1.3 前端交互规则

1. 选择保险公司后，出单工号下拉自动刷新，只展示该保司下启用工号。
2. 险种类型影响保费字段显隐与必填：
   - 交强险：交强险保费必填，商业险保费隐藏
   - 商业险：商业险保费必填，交强险保费隐藏
   - 交商合并：两个保费字段均必填
3. 提交成功后弹出提示：「保存成功，是否继续录入下一张？」
   - 「继续录入」：清空表单，保留保险公司、工号、业务员的上次填写值
   - 「返回列表」：跳转到保单查询列表页

#### 3.1.4 后端校验逻辑

1. **重复保单拦截**：查询 `ins_order_policy_car`，条件 `policy_no = #{policyNo} AND insurance_company_id = #{insuranceCompanyId} AND deleted = 0`，存在则返回错误"保单号在该保司下已存在，请勿重复录入"。
2. **工号与保司匹配**：验证所选工号的 `company_id` 与所选保司一致，否则返回错误。
3. **签单日期在政策有效期内**：查询匹配佣金政策，签单日期不在区间内则警告（允许强制保存）。
4. **保存后触发佣金计算**：发送 MQ 消息（topic: `ins.car.policy.created`），佣金服务异步消费计算。

### 3.2 批量导入保单

#### 3.2.1 操作流程（5步）

**Step 1 下载模板**：点击【下载导入模板】，EasyExcel 动态生成，包含两个 Sheet：「导入数据」（含标题行+示例行）、「字段说明」（格式说明）。

**Step 2 填写并上传**：支持 `.xlsx / .xls`，文件大小限制 10MB。

**Step 3 预解析预览**：后端同步解析返回预览结果（总行数/错误行数/重复保单行数），前10行数据展示（绿色=正常，红色=错误，黄色=重复）。

**Step 4 异步写库**：确认导入后，生成唯一批次号，写入 `ins_car_import_batch` 批次记录表（状态：处理中），发送 RocketMQ 消息，消费者异步逐条写库并触发佣金计算。

**Step 5 查看结果**：在【保单查询 → 任务列表 → 保单导入列表】查看批次状态，失败明细可下载 Excel（含原数据+错误原因列）。

#### 3.2.2 批量导入相关表

```sql
CREATE TABLE `ins_car_import_batch` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '批次ID',
  `merchant_id`   BIGINT       NOT NULL,
  `batch_no`      VARCHAR(32)  NOT NULL COMMENT '批次号',
  `file_name`     VARCHAR(200) COMMENT '原文件名',
  `file_url`      VARCHAR(500) COMMENT 'OSS文件地址',
  `total_count`   INT          DEFAULT 0,
  `success_count` INT          DEFAULT 0,
  `fail_count`    INT          DEFAULT 0,
  `status`        TINYINT      DEFAULT 1 COMMENT '1-处理中 2-成功 3-部分失败 4-全部失败',
  `fail_file_url` VARCHAR(500) COMMENT '失败明细文件URL',
  `creator`       BIGINT,
  `create_time`   DATETIME,
  `finish_time`   DATETIME,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`)
) ENGINE=InnoDB COMMENT='车险保单批量导入批次表';
```

### 3.3 批改单录入

**入口**：车险 → 保单管理 → 保单录入 → 切换至「批单录入」Tab，或在查询列表对保单点击【录入批单】。

**操作流程**：
1. 输入原保单号，系统自动回填：保险公司、险种、车辆信息、原保费
2. 填写批改信息：批改类型（增保/减保/变更标的/其他）、批改保单号、批改日期、支付日期、保费差额（加保填正数，退保填负数）
3. 系统自动重算手续费差额 = 保费差额 × 原上游比例
4. 保存后更新原保单净保费和手续费（差额累加），批单独立存档

**批改历史**：在查询列表点击【批改历史】，弹窗展示该保单所有批改记录（按批改日期降序）。

---

## 四、PC管理后台 · 保单查询

**菜单路径**：车险 → 保单管理 → 保单查询

### 4.1 查询主列表（场景化查询）

#### 4.1.1 页面结构

1. **顶部场景 Tab 栏**：展示用户已配置的查询场景，默认「全部」场景，支持新增/编辑/删除场景
2. **筛选条件区域**：固定条件（日期类型+日期区间）+ 场景自定义条件
3. **数据列表区域**：底部有汇总合计行

#### 4.1.2 默认展示字段

保险公司、保（批）单号、业务员、起保日期、保险止期、产品备注、工号名称、险种类型、产品、工号、保险分公司、操作（查看/编辑/删除）。

#### 4.1.3 底部汇总行

对当前筛选结果全量聚合，展示：总保费、净保费（交强）、净保费（商业）、车船税、总件数。后端通过独立聚合 SQL 查询，不受分页影响。

#### 4.1.4 数据权限

- 超级管理员/内勤：查看本商户全量保单
- 业务员：默认只查看自己名下保单；有「查看团队保单」权限则可见所在组织保单
- 通过 `@DataPermission` 注解实现

### 4.2 场景管理

**新增场景弹窗**分两部分：
- Part 1：筛选条件配置（左侧全量可选字段，右侧已选字段，支持拖拽排序）
- Part 2：列表展示字段配置（同双列布局）

场景配置以 JSON 存储到 `ins_car_policy_scene` 表，按用户 ID 隔离：

```json
{
  "sceneName": "本月签单",
  "filterFields": ["insurance_company_id", "salesman_id"],
  "listColumns": ["policy_no", "plate_no", "premium_total"],
  "defaultDateType": "sign_date",
  "defaultDateRange": "current_month"
}
```

### 4.3 保单导出

- ≤ 2000 条：同步生成，直接返回文件流
- > 2000 条：异步生成，完成后站内信通知下载（链接有效期24小时）
- 导出格式：完整版（含佣金数据）/ 简版（基础信息）

### 4.4 批量操作

**批量更新**：勾选多条保单，可批量修改业务员归属、出单员、录入方式、业务来源、产品备注。支持 Excel 模板批量更新（以保单号为主键定位）。

**批量删除**：
- 已参与佣金结算的保单无法删除，系统提示并排除
- 可选「同时删除随车险录入的非车保单」（默认勾选）
- 删除操作在同一事务内执行，写操作审计日志

**导入 ID 筛选**：通过批量导入批次 ID 精确筛选该批次的全部保单。

### 4.5 保单详情

**基本信息**：保险公司、险种、保费、保期、保单号、录入信息

**险种明细**：商业险各险别的保额、保费、免赔率

**车辆信息**：车牌、VIN、发动机号、车型、使用性质、座位数

**操作记录**：状态变更历史、操作人、操作时间

---

## 五、PC管理后台 · 保单设置

**菜单路径**：车险 → 保单管理 → 保单设置

### 5.1 查询条件设置（个人自定义）

**入口**：保单查询页顶部点击【筛选设置】。

**弹窗交互**：左右双列布局，右侧可选条件，左侧已启用条件，支持拖拽排序。灰色固定条件不可移除（日期类型、日期区间）。

**后端存储**：按 `用户ID + 模块标识(car_query)` 存入用户偏好表，JSON 格式记录字段名及排序。

### 5.2 列表字段设置（个人自定义）

**入口**：查询列表右上角字段设置图标。同查询条件设置弹窗类似的双列布局，固定字段「保单号」和「操作」不可移除。

### 5.3 保单格式规则设置

管理员可配置保单号格式正则表达式，系统在录入时前端做格式校验。

### 5.4 同步设置

配置保单数据同步策略，如与保司系统对接时的自动同步频率、同步范围等。

---

## 六、PC管理后台 · 报表与统计分析

**菜单路径**：车险 → 统计分析

### 6.1 出单统计报表

**维度**：按日/周/月/季/年汇总

**指标**：
- 件数、保费总额、净保费
- 交强险/商业险件数及保费占比
- 新车/续保件数及占比

**展示方式**：折线图（趋势）+ 柱状图（对比）+ 数据表格

### 6.2 业务来源分析

- 各来源渠道（直销/转介绍/网销/电销）的件数、保费、占比
- 环比/同比增长率
- 支持按保险公司、业务员、组织机构下钻

### 6.3 保险公司分析

- 各保司件数、保费、手续费汇总
- 工号使用频率分析
- 月度趋势下钻（点击保司名称可查看该保司月度数据）

### 6.4 组织/业务员绩效

**组织维度**：各部门/团队的出单量、保费额、续保率

**业务员维度**：
- 个人保费排行榜
- 续保率排名
- 件均保费

### 6.5 统计分析接口

| 接口 | 说明 |
|------|------|
| GET /admin-api/ins/car/analysis/report | 出单统计报表 |
| GET /admin-api/ins/car/analysis/business-source | 业务来源分析 |
| GET /admin-api/ins/car/analysis/company | 保险公司分析 |
| GET /admin-api/ins/car/analysis/dept | 组织部门业绩 |
| GET /admin-api/ins/car/analysis/salesman | 业务员业绩分析 |
| GET /admin-api/ins/car/analysis/{type}/export | 统计分析导出 |

---

## 七、业务员App · 车险报价（上）— 车辆信息录入

**对应模块**：`yudao-module-carins`，App端控制器 `app/QuoteController`

### 7.1 报价流程总步骤

| 步骤 | 功能 | 说明 |
|------|------|------|
| Step 1 | 车辆信息录入 | 行驶证OCR / VIN解析 / 手工输入 |
| Step 2 | 投保人/被保人 | 基本信息填写 |
| Step 3 | 投保方案配置 | 险种+保额选择 |
| Step 4 | 触发多保司询价 | 并发调用各保司接口 |
| Step 5 | 查看报价结果 | 对比展示各保司保费 |
| Step 6 | 生成报价单 | PDF生成+H5分享 |

### 7.2 行驶证 OCR 识别

**接口**：`POST /app-api/carins/ocr/upload-image` 上传图片 → `POST /app-api/carins/ocr/recognize-driving-license` OCR识别

**识别字段**：车牌号、VIN、发动机号、车型名称、品牌、初次登记日期、新车购置价、座位数、使用性质、车主姓名

**结果处理**：
- 置信度 < 0.85 的字段标黄提示「请核对」
- 模糊/遮挡图片提示「图片不清晰，请重拍」
- 识别结果可手动修正，修正后重新校验

**OCR服务**：对接腾讯云或阿里云 OCR，后端 `OcrService` 抽象接口 + `TencentOcrServiceImpl` 实现

### 7.3 VIN 码智能解析

**接口**：`POST /app-api/carins/vehicle/parse-vin`

**解析内容**：
- 前3位 WMI：识别制造商/品牌（L开头=国产，J开头=日系）
- 第4-8位 VDS：车型、车身类型、发动机类型
- 第9位：校验码验证VIN有效性
- 第10位：年份代码，推算出厂年份
- 自动填充初登日期范围、新车购置价、座位数

### 7.4 车型库智能匹配

**对接第三方车型库**（精友/纳鼎等）：

- **品牌联想**：支持拼音首字母，如输入"bs"显示"奔驰、宝马、保时捷"
- **车系筛选**：选品牌后按年份、热度排序展示车系，标注停产车系
- **车款精确匹配**：按"排量+变速箱类型"快速筛选，如"2.0T 自动豪华型"
- **参数自动回填**：匹配成功后自动回填座位数、新车购置价、整备质量；与行驶证数据冲突时优先行驶证，标记差异

### 7.5 车辆档案管理

**接口**：`GET /app-api/carins/vehicle/query-by-plate`（按车牌查历史档案）、`POST /app-api/carins/vehicle/save-or-update`（新建/更新档案）

**档案查重**：同一商户+车牌号唯一档案，相同车辆重复报价自动关联历史档案。

**历史保单回填**：通过保司续保查询接口获取上年保单，对比VIN/发动机号，差异则提示"可能过户"，智能推荐续保方案（未出险推荐延续原方案，多次出险推荐降低保额）。

---

## 八、业务员App · 车险报价（中）— 投保方案配置与多保司报价引擎

### 8.1 方案模板快选

| 模板名称 | 三者险保额 | 车损险 | 司乘险 | 附加险 | 适用场景 |
|---------|-----------|--------|--------|--------|---------|
| 经济型 | 50万 | ❌ | ❌ | 无 | 老旧车/价格敏感 |
| 标准型 | 100万 | ✅ | 1万/座 | 玻璃险、划痕险（新车）| 大多数家用车 |
| 全面型 | 200万 | ✅（含不计免赔）| 5万/座 | 涉水、自燃、划痕、玻璃（进口）、轮胎 | 新车/豪车 |

**地域适配**（后端控制）：
- 南方省份（粤/闽/浙/沪/琼等）：标准型/全面型默认勾选涉水险
- 北方省份（黑/吉/辽/内蒙/甘/新等）：标准型默认勾选自燃险

**车龄适配**（前端计算）：
- 车龄0-2年：推荐划痕险、玻璃险（进口）
- 车龄3-6年：推荐自燃险、玻璃险（国产）
- 车龄7年以上：不推荐划痕险，提示车损险保额建议

### 8.2 各险种配置规则

**交强险**：强制勾选，复选框置灰不可取消，显示文字"交强险为法律要求强制投保，已默认选中"。

**三者险**：
- 默认勾选，保额下拉单选：5/10/20/30/50/100（默认）/150/200/300/500/1000万
- 购置价 > 50万的豪车默认200万，前端提示"建议高保额保障"

**车损险**：
- 默认勾选，保额=实际车辆价值（后端计算只读展示）
- 实际价值 = 新车购置价 × (1 - 9%)^车龄，最大折旧80%
- 车损险是以下附加险的前置条件：车损险不计免赔、发动机涉水损失险、指定专修厂险

**司乘险**：
- 默认勾选，保额档位：1/2/5/10/20万每座
- 座位数从车辆档案自动取，灰色不可编辑

**附加险配置规则**：

| 附加险 | 前置险种 | 互斥规则 | 特殊说明 |
|--------|---------|---------|---------|
| 车损险不计免赔 | 车损险 | — | |
| 三者险不计免赔 | 三者险 | — | |
| 发动机涉水损失险 | 车损险 | — | 南方推荐 |
| 指定专修厂险 | 车损险 | — | 保费增加10-15% |
| 玻璃险（国产） | — | 与进口互斥 | 二选一 |
| 玻璃险（进口） | — | 与国产互斥 | 二选一 |
| 车身划痕险 | — | 车龄>6年不可选 | |
| 自然损失险 | — | — | |
| 新增设备损失险 | — | — | 需填写设备总价值 |

**互斥规则前端处理**：勾选「进口玻璃」时自动取消「国产玻璃」，反之亦然。

**营运车辆强制规则**：若 `use_type=3`（营运），「承运人责任险」强制勾选且置灰。

### 8.3 多保司并发询价引擎

**接口**：`POST /app-api/carins/quote/start`

**引擎设计**：
- 并发调用3-5家保司报价接口（人保/平安/太保/国寿/太平洋等）
- 单家保司超时5秒则跳过，失败自动重试1次
- 全局超时20秒，即使仅1家成功也判定为"完成"
- 采用熔断器模式（Sentinel），自动隔离故障保司

**前端轮询**：`GET /app-api/carins/quote/status?quoteRequestId=xxx`，每2秒一次，保司返回结果实时更新报价卡片。

**保费计算逻辑**（本地估算，最终以保司接口为准）：

交强险：基础保费（6座以下950元，6座以上1100元）× NCD系数 × 违章系数

| 连续未出险年数 | NCD系数 |
|-------------|---------|
| 首次/上年出险 | 1.0 |
| 上年未出险 | 0.9 |
| 连续2年未出险 | 0.8 |
| 连续3年及以上未出险 | 0.7 |

商业险：基准保费 × NCD系数 × 车型系数（0.8~1.5）× 车龄系数（新车1.0，5年车0.85）× 渠道系数

### 8.4 报价结果展示

**结果页**：按总保费从低到高排序，每个保司卡片展示：Logo+名称、总保费（大字突出）、保费明细（可展开）、优惠标签、「生成报价单」按钮。最优报价标记"推荐"或"最低价"角标。

**数据缓存**：报价结果缓存至 Redis（key: `carins:quote:result:{quoteRequestId}`），TTL 24小时，过期后结果状态更新为"已失效"。

---

## 九、业务员App · 车险报价（下）— 报价单生成与分享

### 9.1 PDF 报价单生成

**触发**：在报价结果页，点击某家保司方案的「生成报价单」按钮。

**接口**：`POST /app-api/carins/quote/generate-pdf`

**请求参数**：
- `quoteResultId`：报价结果ID
- `includeCustomerName`：是否显示客户姓名（隐私保护）
- `templateCode`：模板代码（STANDARD/WARM/PROMO）

**生成流程**：
1. 后端异步生成（RocketMQ 发消息，PDF Worker 消费）
2. 立即返回 `{taskId, status: "GENERATING"}`
3. 前端每2秒轮询 `GET /app-api/carins/quote/pdf-status?taskId=xxx`
4. 生成完成后上传 OSS（路径：`/{tenantId}/quotes/{quoteNo}.pdf`）
5. 超过30秒标记失败，提示"生成失败，请重试"

**PDF 内容结构**：
1. 头部：公司Logo + 报价单标题 + 编号/日期
2. 业务员区：姓名、工号、手机、专属二维码
3. 车辆信息表格：车牌、VIN、发动机号、初登日期、车型、座位数
4. 险种明细表格：险种名 | 保险金额 | 保费 | 备注
5. 费用合计行：交强险 + 商业险 + 车船税 = 总保费（加粗）
6. 费率系数：NCD系数 × 自主核保系数 = 最终折扣
7. 增值服务区
8. 底部免责声明："本报价单仅供参考，最终保费以保险公司出单为准"
9. 客户确认区（空白签名线，可选）

**证件号脱敏规则**：身份证前3位 + *** + 后4位，如"430***1234"。

### 9.2 H5 分享页

**接口**：`POST /app-api/carins/quote/generate-h5`

**生成流程**：
1. 生成8位随机 `shareCode`，存入 Redis（TTL=7天）
2. H5 URL：`https://h5.xxx.com/quote/share/{shareCode}`
3. 生成微信分享短链
4. 记录 `carins_quote_share` 表

**H5数据接口**（免登录）：`GET /open-api/carins/quote/share-data?code={shareCode}`，`shareCode`不存在（过期）则返回 `{expired: true}`，展示"报价已失效，请联系业务员"。

### 9.3 客户行为实时通知

**行为埋点接口**：`POST /open-api/carins/quote/track`，事件类型：VIEW_OPEN/VIEW_CLOSE/CLICK_INSURER/CLICK_CONTACT

**通知规则**：

| 触发条件 | 通知内容 | 通知方式 |
|---------|---------|---------|
| 客户首次打开H5 | "{客户/车牌}正在查看您的报价单" | App推送 + 站内信 |
| 停留 > 3分钟 | "客户对报价单感兴趣，建议及时跟进" | App推送 |
| 点击联系业务员 | "客户希望联系您，请尽快回复" | App推送 + 短信 |

**防重发**：同一 `shareCode` + 同一业务员，`VIEW_OPEN` 只触发一次通知（Redis 标志位，TTL=24小时）。

---

## 十、业务员App · 续保管理

### 10.1 续保任务自动生成

**Job名称**：`RenewalReminderJob`，每日凌晨 02:00（Cron: `0 0 2 * * ?`）

**触发逻辑**：
1. 查询 `ins_order_policy_car` 表中 `end_date BETWEEN today AND today+60`，`deleted=0`
2. 对每条匹配保单，查询 `carins_renewal_task` 是否已存在对应任务
3. 不存在则新建任务（status=PENDING）
4. 按剩余天数设置优先级：≤7天=URGENT，8~30天=HIGH，>30天=NORMAL
5. 推送站内信给归属业务员

### 10.2 续保任务列表

**接口**：`GET /app-api/carins/renewal/task-list`

**筛选条件**：优先级、状态（待处理/跟进中/已成交/已流失）、到期日期范围

**展示字段**：车牌号、车主姓名、到期日期、剩余天数（颜色编码：红色≤7天，橙色8-30天，绿色>30天）、优先级、状态、最近跟进时间

### 10.3 跟进记录录入

**接口**：`POST /app-api/carins/renewal/follow-record`

| 字段 | 必填 | 说明 |
|------|------|------|
| 跟进方式 | ✅ | 电话联系/短信/微信/上门拜访/其他 |
| 客户态度 | ✅ | 积极/中性/消极 |
| 跟进内容 | ✅ | 最多500字 |
| 下次跟进日期 | 否 | 日期选择器 |

**后端处理**：
1. 插入跟进记录
2. 若当前状态为PENDING，自动更新为FOLLOWING
3. 若跟进内容标记成交，更新为CLOSED_WON

### 10.4 续保结案操作

**标记成交** `PUT /app-api/carins/renewal/close-won`：
- 更新任务 status=CLOSED_WON
- 更新 `carins_vehicle.status=5`（已投保），`expire_date=新保单到期日`
- 触发客户满意度问卷推送（MQ异步）

**标记流失** `PUT /app-api/carins/renewal/close-lost`：
- 更新任务 status=CLOSED_LOST，记录流失原因（价格/服务/品牌/竞品/其他）
- 若原因=NO_NEED（车辆报废/过户），更新 `carins_vehicle.status=7`（已失效）
- 其他原因：下一年度仍生成续保任务（流失客户挽回）

### 10.5 续保提醒规则

**提醒时机**：到期前 30天、15天、7天、3天各发一次

**提醒渠道**：
1. 短信：`【XX保险】您的爱车(京A12345)保险将于X月X日到期，点击链接查看续保优惠 {专属链接}`
2. 微信服务号模板消息（需客户关注）
3. App站内信

**频率限制**：同一渠道每周最多2次，多渠道叠加每周总计不超过3次。免打扰时段：短信避免21:00-次日8:00。

**任务状态机**：

```
PENDING（待处理）
    ↓ 首次跟进
FOLLOWING（跟进中）
    ↓            ↓             ↓
CLOSED_WON   CLOSED_LOST   POSTPONED（延期）
（成交）      （流失）         ↓ 到达下次跟进时间
                          恢复 FOLLOWING
```

---

## 十一、C端小程序 · 车险投保

**入口**：C端商城首页 → 车险 → 查询报价/投保

### 11.1 车辆信息录入（C端）

**功能**：客户自助输入车牌号/VIN码，系统识别车辆基本信息，或手动填写。

**车险投保步骤**：
1. 车辆信息录入（车牌号、VIN、品牌车型、车主信息）
2. 险种方案选择（与App端配置逻辑一致）
3. 在线报价（并发调用保司接口）
4. 选择方案
5. 填写投保人/被保人信息
6. 确认保单信息
7. 支付（微信支付/支付宝/银行转账）
8. 保单出单/导入

### 11.2 C端报价展示

**并发询价逻辑**与App端一致，展示样式针对移动端优化：
- 轻量卡片展示各保司报价
- 支持横向对比两家保司的险种明细
- 推荐标签（最低价/热选）

### 11.3 C端保单支付

**支付方式**：微信支付（JSAPI/小程序支付）、支付宝 H5支付、银行转账

**支付流程**：
1. 确认保单信息 → 生成订单（`ins_order_main`）
2. 调用支付渠道下单接口
3. 回调更新订单状态
4. 触发出单流程（调用保司接口出单/提醒内勤录单）
5. 出单成功 → 写入 `ins_order_policy_car` → 发送保单到客户邮箱/短信

### 11.4 C端增值服务（扩展需求）

| 功能 | 说明 | 工时（前/后） |
|------|------|------------|
| 违章查询 | 对接聚合数据API，缓存24小时 | 1天 / 0.5天 |
| 道路救援一键呼叫 | 对接安锐/博时救援平台，GPS坐标WGS84→GCJ02 | 1天 / 0.5天 |
| OBD/驾驶行为评分 | 手机陀螺仪模拟，加权评分模型 | 1.5天 / 1天 |

---

## 十二、数据库核心表设计

### 12.1 车险保单主表

```sql
CREATE TABLE `ins_order_policy_car` (
  `id`                      BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenant_id`               BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `merchant_id`             BIGINT        NOT NULL COMMENT '商户ID（机构ID）',
  -- 保险公司信息
  `insurance_company_id`    BIGINT        NOT NULL COMMENT '保险公司ID',
  `insurance_company_name`  VARCHAR(100)  NOT NULL COMMENT '保险公司名称',
  -- 保单基本信息
  `policy_no`               VARCHAR(100)  NOT NULL COMMENT '保单号',
  `policy_type`             TINYINT       NOT NULL COMMENT '1-交强险 2-商业险 3-交+商',
  `policy_status`           TINYINT       NOT NULL DEFAULT 1 COMMENT '1-正常 2-批改 3-退保 4-失效',
  `entry_type`              TINYINT       NOT NULL DEFAULT 2 COMMENT '1-直连出单 2-手工录入',
  -- 车辆信息
  `plate_no`                VARCHAR(20)   COMMENT '车牌号',
  `vin_code`                VARCHAR(17)   COMMENT '车架号（VIN）',
  `engine_no`               VARCHAR(30)   COMMENT '发动机号',
  `car_model`               VARCHAR(200)  COMMENT '车型名称',
  `car_brand`               VARCHAR(100)  COMMENT '品牌',
  `car_seat_count`          INT           COMMENT '座位数',
  `car_register_date`       DATE          COMMENT '初次登记日期',
  `car_use_type`            VARCHAR(50)   COMMENT '使用性质',
  `car_owner_name`          VARCHAR(100)  COMMENT '车主姓名',
  `car_owner_cert_no`       VARCHAR(100)  COMMENT '车主证件号（AES-256加密）',
  -- 交强险信息
  `compulsory_policy_no`    VARCHAR(100)  COMMENT '交强险保单号',
  `premium_compulsory`      DECIMAL(12,2) DEFAULT 0 COMMENT '交强险保费（元）',
  `compulsory_start_date`   DATE          COMMENT '交强险起保日期',
  `compulsory_end_date`     DATE          COMMENT '交强险止期',
  -- 商业险信息
  `commercial_policy_no`    VARCHAR(100)  COMMENT '商业险保单号',
  `premium_commercial`      DECIMAL(12,2) DEFAULT 0 COMMENT '商业险保费（元）',
  `commercial_start_date`   DATE          COMMENT '商业险起保日期',
  `commercial_end_date`     DATE          COMMENT '商业险止期',
  -- 通用保单信息
  `vehicle_tax`             DECIMAL(10,2) DEFAULT 0 COMMENT '车船税（元）',
  `sign_date`               DATE          COMMENT '签单日期',
  `pay_date`                DATE          COMMENT '支付日期',
  `start_date`              DATE          COMMENT '起保日期（取交强/商业的早者）',
  `end_date`                DATE          COMMENT '保险止期（取交强/商业的晚者）',
  -- 人员信息
  `salesman_id`             BIGINT        COMMENT '业务员ID',
  `salesman_name`           VARCHAR(100)  COMMENT '业务员姓名',
  `org_id`                  BIGINT        COMMENT '所属机构ID',
  `company_no_id`           BIGINT        COMMENT '出单工号ID',
  -- 费用信息
  `upstream_fee_rate`       DECIMAL(8,4)  COMMENT '上游手续费比例(%)',
  `upstream_fee_amount`     DECIMAL(12,2) COMMENT '上游手续费金额（元）',
  `downstream_fee_rate`     DECIMAL(8,4)  COMMENT '下游手续费比例(%)',
  `downstream_fee_amount`   DECIMAL(12,2) COMMENT '下游手续费金额（元）',
  `profit_amount`           DECIMAL(12,2) DEFAULT 0 COMMENT '利润（元）',
  -- 来源标识
  `channel_name`            VARCHAR(100)  COMMENT '渠道名称',
  `source_type`             TINYINT       DEFAULT 1 COMMENT '1-PC录单 2-App录单 3-批量导入 4-直连',
  `import_batch_no`         VARCHAR(64)   COMMENT '批次导入编号',
  -- 续保关联
  `is_renewal`              TINYINT(1)    DEFAULT 0 COMMENT '是否续保',
  `pre_policy_no`           VARCHAR(100)  COMMENT '上一年度保单号',
  -- C端关联
  `order_id`                BIGINT        COMMENT '关联C端订单ID',
  `user_id`                 BIGINT        COMMENT '关联C端用户ID',
  `remark`                  VARCHAR(500)  COMMENT '备注',
  -- 框架标准字段
  `creator`                 VARCHAR(64)   DEFAULT '',
  `create_time`             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`                 VARCHAR(64)   DEFAULT '',
  `update_time`             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`                 TINYINT(1)    NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_company_policy` (`tenant_id`, `insurance_company_id`, `policy_no`, `deleted`),
  KEY `idx_salesman_id` (`salesman_id`),
  KEY `idx_plate_no` (`plate_no`),
  KEY `idx_vin_code` (`vin_code`),
  KEY `idx_end_date` (`end_date`),
  KEY `idx_sign_date` (`sign_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='车险保单主表';
```

### 12.2 车险险别明细表

```sql
CREATE TABLE `ins_order_policy_car_coverage` (
  `id`                BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`         BIGINT        NOT NULL COMMENT '关联车险保单ID',
  `tenant_id`         BIGINT        NOT NULL DEFAULT 0,
  `coverage_code`     VARCHAR(50)   NOT NULL COMMENT '险别代码（CZZE=车损险）',
  `coverage_name`     VARCHAR(100)  NOT NULL COMMENT '险别名称',
  `sum_insured`       DECIMAL(15,2) DEFAULT 0 COMMENT '保额（元）',
  `premium`           DECIMAL(10,2) DEFAULT 0 COMMENT '该险别保费（元）',
  `deductible_rate`   DECIMAL(5,2)  DEFAULT 0 COMMENT '绝对免赔率(%)',
  `is_selected`       TINYINT(1)    DEFAULT 1 COMMENT '是否投保',
  `remark`            VARCHAR(200),
  `creator`           VARCHAR(64)   DEFAULT '',
  `create_time`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted`           TINYINT(1)    NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB COMMENT='车险保单险别明细表';
```

### 12.3 车险续保追踪表

```sql
CREATE TABLE `ins_order_car_renewal` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`        BIGINT       NOT NULL,
  `agent_id`         BIGINT       COMMENT '负责业务员（NULL=公共池）',
  `vehicle_id`       BIGINT       NOT NULL,
  `policy_id`        BIGINT       NOT NULL COMMENT '关联上一年保单',
  `expire_date`      DATE         NOT NULL COMMENT '保险到期日',
  `priority`         VARCHAR(10)  NOT NULL COMMENT 'URGENT/HIGH/NORMAL',
  `status`           VARCHAR(20)  NOT NULL DEFAULT 'PENDING' COMMENT '任务状态',
  `last_follow_time` DATETIME     COMMENT '最近跟进时间',
  `follow_count`     INT          NOT NULL DEFAULT 0,
  `lost_reason`      VARCHAR(20)  COMMENT '流失原因',
  `actual_premium`   DECIMAL(10,2) COMMENT '实际成交保费',
  `create_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_agent_priority` (`agent_id`, `priority`, `status`),
  INDEX `idx_expire_date` (`expire_date`, `status`)
) COMMENT='车险续保记录追踪表';
```

---

## 十三、接口清单

### 13.1 App 端接口

| 接口 | Method | URL | 说明 |
|------|--------|-----|------|
| 上传图片 | POST | `/app-api/carins/ocr/upload-image` | OCR图片上传 |
| 行驶证识别 | POST | `/app-api/carins/ocr/recognize-driving-license` | OCR识别 |
| 车型搜索 | GET | `/app-api/carins/vehicle/model/search` | 品牌/车系/车款联动 |
| VIN解析 | POST | `/app-api/carins/vehicle/parse-vin` | VIN码智能解析 |
| 车牌查档案 | GET | `/app-api/carins/vehicle/query-by-plate` | 查历史档案 |
| 保存车辆 | POST | `/app-api/carins/vehicle/save-or-update` | 新建/更新档案 |
| 初始化报价 | POST | `/app-api/carins/quote/init-request` | 保存险种方案 |
| 发起询价 | POST | `/app-api/carins/quote/start` | 触发多保司询价 |
| 查询询价状态 | GET | `/app-api/carins/quote/status` | 轮询报价进度 |
| 单保司重试 | POST | `/app-api/carins/quote/retry-single` | 重试单个保司 |
| 生成PDF | POST | `/app-api/carins/quote/generate-pdf` | 异步生成PDF |
| PDF状态查询 | GET | `/app-api/carins/quote/pdf-status` | 轮询PDF状态 |
| 生成H5分享 | POST | `/app-api/carins/quote/generate-h5` | 生成分享链接 |
| H5数据接口 | GET | `/open-api/carins/quote/share-data` | H5页面数据（免登录）|
| H5行为埋点 | POST | `/open-api/carins/quote/track` | 客户行为上报 |
| 续保任务列表 | GET | `/app-api/carins/renewal/task-list` | 分页查询续保任务 |
| 续保任务详情 | GET | `/app-api/carins/renewal/task-detail` | 任务详情 |
| 记录跟进 | POST | `/app-api/carins/renewal/follow-record` | 新增跟进记录 |
| 标记成交 | PUT | `/app-api/carins/renewal/close-won` | 标记成交 |
| 标记流失 | PUT | `/app-api/carins/renewal/close-lost` | 标记流失 |

### 13.2 PC 端接口

| 接口 | Method | URL | 说明 |
|------|--------|-----|------|
| 新增保单 | POST | `/admin-api/ins/car/policy/create` | 手工录入 |
| 编辑保单 | PUT | `/admin-api/ins/car/policy/update` | 编辑保单 |
| 保单查询 | GET | `/admin-api/ins/car/policy/page` | 分页查询 |
| 保单详情 | GET | `/admin-api/ins/car/policy/{id}` | 查看详情 |
| 批量删除 | DELETE | `/admin-api/ins/car/policy/batch-delete` | 批量删除 |
| 批量更新 | PUT | `/admin-api/ins/car/policy/batch-update` | 批量更新字段 |
| 下载导入模板 | GET | `/admin-api/ins/car/policy/import/template` | 下载模板 |
| 上传导入文件 | POST | `/admin-api/ins/car/policy/import/upload` | 上传文件 |
| 确认导入 | POST | `/admin-api/ins/car/policy/import/confirm/{taskId}` | 确认执行 |
| 导入任务列表 | GET | `/admin-api/ins/car/policy/import/task/list` | 任务列表 |
| 录入批单 | POST | `/admin-api/ins/car/endorsement/create` | 新增批改单 |
| 批改历史 | GET | `/admin-api/ins/car/endorsement/history/{policyId}` | 查询批改历史 |
| 保单导出 | GET | `/admin-api/ins/car/policy/export` | 条件导出 |
| 场景列表 | GET | `/admin-api/ins/car/policy/scene/list` | 查询场景 |
| 保存场景 | POST | `/admin-api/ins/car/policy/scene/save` | 保存场景配置 |

---

## 十四、权限矩阵

| 功能 | 超管/内勤 | 团队长 | 业务员 |
|------|---------|--------|--------|
| 查看全量保单 | ✅ | 本团队 | 本人 |
| 录入保单 | ✅ | ✅ | ✅ |
| 编辑保单 | ✅ | 本团队 | 本人 |
| 删除保单 | ✅ | 本团队（审批） | ❌ |
| 批量导入 | ✅ | ✅ | ❌ |
| 查看统计分析 | ✅ | 本团队 | 本人 |
| 查看报价 | ✅ | ✅ | ✅ |
| 发起询价 | ✅ | ✅ | ✅ |
| 查看续保任务 | ✅ | 本团队 | 本人 |
| 标记续保结案 | ✅ | 本团队 | 本人 |
| 保单设置 | ✅ | ❌ | ❌ |
| 查询条件/字段配置 | ✅ | ✅ | ✅（个人） |

---

*文档版本：V1.0 | 编写日期：2026-03 | 适用框架：yudao-cloud（intermediary-cloud）*
*下一批次文档：非车险模块 PRD*

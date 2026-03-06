# 阶段4 · AI智能中台需求文档（上）— AI保障规划

> 框架：yudao-cloud（ruoyi-vue-pro 微服务版）  
> 模块前缀：`ai_`  
> 接口前缀：`/admin-api/ai/`  
> 适用人员：前端开发、后端开发  
> 文档版本：v2.0

---

## 目录

1. [风险测评问卷](#1-风险测评问卷)
2. [保障缺口计算](#2-保障缺口计算)
3. [规划报告生成](#3-规划报告生成)
4. [产品推荐引擎](#4-产品推荐引擎)
5. [方案对比](#5-方案对比)
6. [规划方案分享](#6-规划方案分享)

---

## 1. 风险测评问卷

### 1.1 业务说明

代理人在 B 端 App 或 PC 后台为客户发起家庭风险评估，收集家庭收入、支出、资产、负债、已有保障等信息，为后续保障缺口计算提供原始数据。问卷支持动态跳题逻辑。

---

### 1.2 PC 管理后台 — 问卷模板管理

#### 1.2.1 问卷模板列表页

路径：**AI智能工具 → 保障规划 → 问卷模板管理**

列表展示字段：模板编码、模板名称、版本号、题目数量、状态（启用/停用）、创建时间、操作（编辑/停用/复制）。

支持按模板名称、状态筛选。

#### 1.2.2 新建/编辑问卷模板

点击【新建模板】或【编辑】按钮，弹出侧边抽屉（Drawer），包含两个 Tab：

**Tab1 基本信息**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 模板名称 | 文本 | ✅ | 最长100字 |
| 模板编码 | 文本 | ✅ | 唯一，英文+数字，自动生成可手动改 |
| 版本号 | 文本 | ✅ | 默认1.0 |
| 描述 | 文本域 | ❌ | 最长500字 |
| 状态 | 单选 | ✅ | 启用/停用，默认启用 |

**Tab2 题目管理**

以列表形式展示当前模板所有题目，支持拖拽排序。操作列：编辑、删除。

点击【添加题目】弹出对话框：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 题目文本 | 文本域 | ✅ | 最长500字 |
| 题目类型 | 下拉 | ✅ | 单选/多选/文本输入/数字输入/日期 |
| 题目分组 | 文本 | ❌ | 用于前端分组展示，如"家庭收入"、"现有保障" |
| 是否必填 | 开关 | ✅ | 默认必填 |
| 排序号 | 数字 | ✅ | 越小越靠前 |
| 选项配置 | 动态表格 | 条件必填 | 题目类型为单选/多选时必填，每行一个选项（value+label） |
| 校验规则 | JSON | ❌ | 数字题目可配置 min/max 范围 |
| 跳题逻辑 | JSON | ❌ | 见下方跳题逻辑说明 |

**跳题逻辑 JSON 格式**：

```json
{
  "rules": [
    {
      "condition": "value == '4'",
      "actions": [
        { "type": "showQuestion", "targetCode": "Q010" },
        { "type": "hideQuestion", "targetCode": "Q008" }
      ]
    }
  ]
}
```

后端保存前校验：跳题目标题目编码必须存在于同一模板内，否则返回错误提示"跳题目标题目不存在"。

**后端保存逻辑**：
- 检查 template_code 在同租户下唯一（deleted=0）
- 题目按 sort_order 排序保存
- 跳题逻辑中引用的 targetCode 检查存在性
- 返回 templateId

---

### 1.3 发起问卷（B 端 App / PC 后台）

#### 1.3.1 入口

- PC 后台：客户详情页 → 【发起保障规划】按钮
- B 端 App：客户列表 → 客户详情 → 底部【发起保障规划】

#### 1.3.2 选择问卷模板

弹出模板列表（仅展示已启用的模板），选择后点击【确认发起】。

后端逻辑：
1. 校验该客户是否存在进行中的问卷（status=1），若存在，弹提示"该客户已有进行中的问卷，是否继续填写？"，选是则跳转到已有问卷，选否则放弃当前操作。
2. 创建 `ai_questionnaire_record`，status=0，记录 customer_id、agent_id、template_id。
3. 返回 recordId，前端跳转到问卷填写页。

#### 1.3.3 问卷填写页

页面布局：
- 顶部：客户姓名 + 进度条（已答题数/总题数）
- 中部：题目区域（当前可见题目）
- 底部：【暂存】【上一步】【下一步/提交】

**填写交互逻辑**：

1. 进入页面时，调接口获取问卷模板所有题目及已保存的答案（断点续做）。
2. 前端根据 skipLogic 实时计算当前应展示的题目列表（隐藏的题目不渲染，不必填）。
3. 点击【下一步】前端先做必填校验，通过后逐题调保存接口（或批量保存）。
4. 点击【暂存】直接保存当前已填答案，不做必填校验，status 保持1（进行中）。
5. 最后一题点击【提交】，前端调完成接口。

**后端每题保存接口**：
- 接收 recordId、questionId、answerValue、answerText
- 先查 record 是否存在且 status≠2（已完成）
- 若该题已有答案则 update，否则 insert
- 解析当前题的 skipLogic，根据 answerValue 计算需要显示/隐藏的题目列表，返回给前端
- 同时更新 record 的 update_time

**后端完成接口**：
- 校验该模板所有必填题目（未被跳过的）都已有答案
- 若有未填项，返回缺失题目列表，前端跳转到对应题目
- 全部通过：更新 status=2、complete_time、duration（完成时间-开始时间）
- 异步触发缺口计算任务（发 MQ 消息）

---

### 1.4 数据库设计

```sql
-- 问卷模板表
CREATE TABLE `ai_questionnaire_template` (
  `id`            BIGINT NOT NULL AUTO_INCREMENT,
  `template_code` VARCHAR(32) NOT NULL COMMENT '模板编码，同租户唯一',
  `template_name` VARCHAR(100) NOT NULL,
  `description`   VARCHAR(500),
  `version`       VARCHAR(20) NOT NULL DEFAULT '1.0',
  `status`        TINYINT(1) NOT NULL DEFAULT 1 COMMENT '0停用 1启用',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_template_code` (`template_code`, `tenant_id`, `deleted`)
) COMMENT='AI问卷模板表';

-- 问卷题目表
CREATE TABLE `ai_questionnaire_question` (
  `id`              BIGINT NOT NULL AUTO_INCREMENT,
  `template_id`     BIGINT NOT NULL,
  `question_code`   VARCHAR(32) NOT NULL COMMENT '题目编码，同模板内唯一',
  `question_text`   VARCHAR(500) NOT NULL,
  `question_type`   VARCHAR(20) NOT NULL COMMENT 'single/multiple/input/number/date',
  `question_group`  VARCHAR(50) COMMENT '分组标签',
  `sort_order`      INT NOT NULL DEFAULT 0,
  `is_required`     BIT(1) NOT NULL DEFAULT b'1',
  `options`         JSON COMMENT '[{"value":"1","label":"10万以下"},...]',
  `validation_rule` JSON COMMENT '{"min":0,"max":9999}',
  `skip_logic`      JSON COMMENT '跳题逻辑，见文档说明',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_template_id` (`template_id`),
  KEY `idx_sort` (`sort_order`)
) COMMENT='AI问卷题目表';

-- 问卷填写记录表
CREATE TABLE `ai_questionnaire_record` (
  `id`          BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id` BIGINT NOT NULL,
  `agent_id`    BIGINT COMMENT '代理人ID',
  `template_id` BIGINT NOT NULL,
  `status`      TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0未开始 1进行中 2已完成',
  `start_time`  DATETIME,
  `complete_time` DATETIME,
  `duration`    INT COMMENT '耗时秒',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_status` (`status`)
) COMMENT='AI问卷填写记录表';

-- 问卷答案表
CREATE TABLE `ai_questionnaire_answer` (
  `id`          BIGINT NOT NULL AUTO_INCREMENT,
  `record_id`   BIGINT NOT NULL,
  `question_id` BIGINT NOT NULL,
  `answer_value` VARCHAR(1000) COMMENT '答案值（单选存value，多选存逗号分隔）',
  `answer_text`  TEXT COMMENT '答案展示文本',
  `answer_time`  DATETIME,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_record_question` (`record_id`, `question_id`, `deleted`),
  KEY `idx_record_id` (`record_id`)
) COMMENT='AI问卷答案表';
```

---

### 1.5 接口清单

| 接口 | Method | URL | 说明 |
|------|--------|-----|------|
| 模板列表 | GET | `/admin-api/ai/questionnaire/template/page` | 分页，支持筛选 |
| 创建模板 | POST | `/admin-api/ai/questionnaire/template` | |
| 编辑模板 | PUT | `/admin-api/ai/questionnaire/template/{id}` | |
| 获取模板（含题目） | GET | `/admin-api/ai/questionnaire/template/{id}` | |
| 发起问卷 | POST | `/admin-api/ai/questionnaire/record/start` | 入参：customerId,templateId |
| 保存答案 | POST | `/admin-api/ai/questionnaire/answer/save` | 单题保存，返回跳题结果 |
| 批量保存答案 | POST | `/admin-api/ai/questionnaire/answer/batch-save` | |
| 完成问卷 | POST | `/admin-api/ai/questionnaire/record/complete` | 入参：recordId，触发缺口计算 |
| 查看问卷详情 | GET | `/admin-api/ai/questionnaire/record/{recordId}` | 含所有答案 |

---

## 2. 保障缺口计算

### 2.1 业务说明

问卷完成后，系统自动（或手动触发）基于标准普尔家庭资产象限模型计算客户的保障缺口。计算结果是产品推荐和报告生成的输入数据源。

### 2.2 标准普尔象限计算规则

**象限目标比例（可配置）**：

| 象限 | 名称 | 建议比例 | 对应问卷字段 |
|------|------|----------|------|
| 要花的钱 | 应急备用金 | 年收入×10% | 家庭月支出×6个月 |
| 保命的钱 | 风险保障金 | 年收入×20% | 现有保险保额之和 |
| 生钱的钱 | 投资增值 | 年收入×30% | 现有投资资产 |
| 保本升值 | 养老/教育储备 | 年收入×40% | 养老金+教育金储备 |

**各险种保障缺口计算公式**：

```
寿险保额需求   = 年收入 × 年龄系数 × 家庭责任系数
寿险缺口       = 寿险保额需求 - 现有寿险保额（取0若为负）

重疾险保额需求 = 年收入 × 3 ~ 5倍（默认3倍，可配置）
重疾险缺口     = 重疾险保额需求 - 现有重疾险保额

意外险保额需求 = 年收入 × 5 ~ 10倍（默认5倍，可配置）
意外险缺口     = 意外险保额需求 - 现有意外险保额

医疗险缺口     = 无社保→建议百万医疗，有社保→建议中端医疗（配置项）

应急金缺口     = 月支出 × 6 - 现金及活期存款
```

**年龄系数表（存入 `ai_gap_calculation_params`，可后台调整）**：

| 年龄段 | 系数 |
|--------|------|
| 18~30岁 | 10 |
| 31~40岁 | 8 |
| 41~50岁 | 6 |
| 51~60岁 | 4 |
| 60岁以上 | 2 |

**家庭责任系数**：有子女且子女未独立=1.2，无子女=1.0，有赡养老人=额外+0.1。

### 2.3 计算参数管理（PC 后台）

路径：**AI智能工具 → 参数配置 → 缺口计算参数**

列表字段：参数类型、参数键、参数值、描述、状态、操作（编辑）。

点击编辑弹出表单：参数值（数字）、描述（文本）、状态。

**后端保存校验**：参数值必须为正数；同 param_type + param_key 在同租户下唯一。

### 2.4 计算触发机制

1. **自动触发**：问卷完成后通过 RocketMQ 发送消息，消费者异步执行计算。
2. **手动触发**：客户详情页点击【重新计算缺口】按钮，直接调计算接口。

**计算接口后端逻辑**：
1. 查询问卷记录，确认 status=2（已完成），否则返回错误"问卷未完成"。
2. 读取所有答案，按 question_code 映射到计算字段（question_code 与字段的映射关系在配置文件中维护）。
3. 读取当前有效的计算参数（status=1 的 `ai_gap_calculation_params`）。
4. 使用 BigDecimal 执行计算，所有缺口值若为负数则置为0。
5. 将结果 insert/update 到 `ai_gap_analysis_result`，记录 calculate_time。
6. 返回 resultId。

### 2.5 数据库设计

```sql
-- 缺口分析结果表
CREATE TABLE `ai_gap_analysis_result` (
  `id`                       BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`              BIGINT NOT NULL,
  `questionnaire_record_id`  BIGINT NOT NULL,
  -- 家庭财务数据（从问卷提取）
  `family_annual_income`     DECIMAL(15,2) COMMENT '家庭年收入',
  `family_monthly_expense`   DECIMAL(15,2) COMMENT '家庭月支出',
  `total_assets`             DECIMAL(15,2) COMMENT '总资产',
  `total_liabilities`        DECIMAL(15,2) COMMENT '总负债',
  -- 象限目标vs实际vs缺口
  `emergency_fund_target`    DECIMAL(15,2),
  `emergency_fund_current`   DECIMAL(15,2),
  `emergency_fund_gap`       DECIMAL(15,2),
  `protection_target`        DECIMAL(15,2),
  `protection_current`       DECIMAL(15,2),
  `protection_gap`           DECIMAL(15,2),
  `investment_target`        DECIMAL(15,2),
  `investment_current`       DECIMAL(15,2),
  `investment_gap`           DECIMAL(15,2),
  `preservation_target`      DECIMAL(15,2),
  `preservation_current`     DECIMAL(15,2),
  `preservation_gap`         DECIMAL(15,2),
  -- 各险种缺口
  `life_insurance_gap`       DECIMAL(15,2) COMMENT '寿险缺口',
  `critical_illness_gap`     DECIMAL(15,2) COMMENT '重疾险缺口',
  `accident_insurance_gap`   DECIMAL(15,2) COMMENT '意外险缺口',
  `medical_insurance_gap`    DECIMAL(15,2) COMMENT '医疗险缺口',
  `calculate_time`           DATETIME,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_record_id` (`questionnaire_record_id`)
) COMMENT='AI缺口分析结果表';

-- 计算参数配置表
CREATE TABLE `ai_gap_calculation_params` (
  `id`          BIGINT NOT NULL AUTO_INCREMENT,
  `param_type`  VARCHAR(50) NOT NULL COMMENT '参数类型：age_factor/coverage_ratio/emergency_ratio',
  `param_key`   VARCHAR(100) NOT NULL COMMENT '参数键：如 18_30（年龄段）',
  `param_value` DECIMAL(10,4) NOT NULL,
  `description` VARCHAR(500),
  `status`      TINYINT(1) NOT NULL DEFAULT 1,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_type_key` (`param_type`, `param_key`, `tenant_id`, `deleted`)
) COMMENT='AI缺口计算参数表';
```

### 2.6 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 触发缺口计算 | POST | `/admin-api/ai/gap/calculate` |
| 获取缺口结果 | GET | `/admin-api/ai/gap/result/{resultId}` |
| 获取客户最新缺口结果 | GET | `/admin-api/ai/gap/customer/{customerId}/latest` |
| 参数列表 | GET | `/admin-api/ai/gap/params/list` |
| 编辑参数 | PUT | `/admin-api/ai/gap/params/{id}` |

---

## 3. 规划报告生成

### 3.1 业务说明

基于缺口分析结果，异步生成 PDF 格式的保障规划报告，支持在线预览、下载和分享。报告通过 iText 7 + Thymeleaf 模板生成，图表由服务端渲染（ECharts Server-Side Rendering 或 JFreeChart）后插入 PDF。

### 3.2 报告生成操作流程

1. 缺口计算完成后，客户详情页/保障规划详情页出现【生成报告】按钮。
2. 点击【生成报告】弹出确认框，可选择报告模板（若有多个）。
3. 点击确认后，前端立即展示"报告生成中"状态，后端异步处理。
4. 前端轮询状态接口（每3秒一次，最多轮询60次），生成成功后展示【下载】【分享】按钮。
5. 若生成失败，展示失败提示，提供【重试】按钮。

### 3.3 后端生成流程

1. 接收请求，校验 gapResultId 存在且属于当前租户。
2. 在 `ai_planning_report` 中创建记录，status=0（生成中）。
3. 发送 MQ 消息到报告生成队列。
4. 消费者处理：
   a. 查询缺口结果、客户信息、推荐产品等数据。
   b. 用 Thymeleaf 渲染 HTML 模板（注入数据变量）。
   c. 使用 JFreeChart 生成标准普尔象限饼图等图表，转为 Base64 图片嵌入 HTML。
   d. iText 7 pdfHTML 插件将 HTML 转 PDF，添加页眉（机构名称+Logo）、页脚（页码+免责声明）。
   e. 将 PDF 上传至阿里云 OSS，获取访问 URL。
   f. 更新 `ai_planning_report`，status=1，填入 pdf_url、pdf_size、page_count、generate_time。
5. 若任意步骤失败，更新 status=2，记录失败原因，删除本地临时文件。

### 3.4 数据库设计

```sql
CREATE TABLE `ai_planning_report` (
  `id`            BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`   BIGINT NOT NULL,
  `gap_result_id` BIGINT NOT NULL,
  `report_code`   VARCHAR(50) NOT NULL COMMENT '报告编号，系统自动生成，格式 RPT+年月日+6位序号',
  `report_title`  VARCHAR(200) COMMENT '报告标题，默认"XXX的家庭保障规划报告"',
  `template_id`   BIGINT COMMENT '报告模板ID',
  `pdf_url`       VARCHAR(500) COMMENT 'OSS存储URL',
  `pdf_size`      BIGINT COMMENT '文件大小（字节）',
  `page_count`    INT,
  `status`        TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0生成中 1成功 2失败',
  `fail_reason`   VARCHAR(500) COMMENT '失败原因',
  `view_count`    INT NOT NULL DEFAULT 0,
  `share_count`   INT NOT NULL DEFAULT 0,
  `generate_time` DATETIME,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_report_code` (`report_code`, `deleted`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_gap_result_id` (`gap_result_id`)
) COMMENT='AI规划报告表';
```

### 3.5 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 发起报告生成 | POST | `/admin-api/ai/report/generate` |
| 查询生成状态 | GET | `/admin-api/ai/report/status/{reportId}` |
| 报告列表（客户） | GET | `/admin-api/ai/report/list?customerId=xxx` |
| 下载报告 | GET | `/admin-api/ai/report/download/{reportId}` |

---

## 4. 产品推荐引擎

### 4.1 业务说明

基于缺口分析结果，为客户推荐最匹配的保险产品。采用"规则引擎 + 协同过滤"混合推荐策略。推荐结果可展示在规划报告中，也可在 B 端 App 独立展示。

### 4.2 推荐流程

1. 缺口计算完成后自动触发推荐，也可手动点击【刷新推荐】。
2. 后端读取缺口数据，确定各险种需求优先级。
3. 对产品库执行规则过滤（硬条件）→ 协同过滤打分（软条件）→ 综合排序。
4. 取 Top N（默认10条）写入 `ai_recommendation_detail`。
5. 前端展示推荐产品列表，每个产品显示推荐原因（模板化文案）。

### 4.3 综合评分模型

```
综合得分（0-100） = 规则匹配度 × 40% + 协同过滤得分 × 30% + 性价比得分 × 20% + 公司权重 × 10%
```

**规则匹配度（0-100分）**：
- 投保年龄在产品投保范围内：+20分，否则直接过滤（硬排除）
- 保额能覆盖缺口的80%以上：+30分，覆盖50%-80%：+15分
- 年保费在客户预算内：+30分，超预算20%以内：+10分
- 健康告知无问题（调接口查核保结论）：+20分

**协同过滤得分**：基于 `相似客户（年龄±5岁、收入±20%、同地区）` 的购买记录计算，由定时任务（每天凌晨）预计算产品相似度矩阵存入 Redis。

**性价比得分**：保额 / 年保费 归一化后打分。

**公司权重**：在机构后台配置各保险公司的权重系数（0.8~1.2），用于运营干预。

**推荐理由文案模板**：

| 场景 | 文案模板 |
|------|---------|
| 寿险缺口 | 根据您{age}岁、年收入{income}万的情况，建议配置{coverage}万保额的寿险，该产品每年仅需{premium}元 |
| 重疾缺口 | 您目前重疾保障缺口约{gap}万，该产品保额{coverage}万，覆盖{diseaseCount}种重疾 |

### 4.4 数据库设计

```sql
-- 推荐记录表（一次推荐）
CREATE TABLE `ai_product_recommendation` (
  `id`              BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`     BIGINT NOT NULL,
  `gap_result_id`   BIGINT NOT NULL,
  `recommend_time`  DATETIME NOT NULL,
  `recommend_count` INT NOT NULL DEFAULT 0,
  `budget`          DECIMAL(12,2) COMMENT '客户预算年保费上限',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`)
) COMMENT='AI产品推荐记录表';

-- 推荐产品明细表
CREATE TABLE `ai_recommendation_detail` (
  `id`                BIGINT NOT NULL AUTO_INCREMENT,
  `recommendation_id` BIGINT NOT NULL,
  `product_id`        BIGINT NOT NULL,
  `rank`              INT NOT NULL COMMENT '推荐排名',
  `total_score`       DECIMAL(5,2) NOT NULL,
  `rule_score`        DECIMAL(5,2),
  `cf_score`          DECIMAL(5,2),
  `price_score`       DECIMAL(5,2),
  `company_score`     DECIMAL(5,2),
  `recommend_reason`  VARCHAR(1000) COMMENT '推荐理由（模板文案填充后存储）',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_recommendation_id` (`recommendation_id`),
  KEY `idx_product_id` (`product_id`)
) COMMENT='AI推荐产品明细表';
```

### 4.5 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 获取推荐产品 | POST | `/admin-api/ai/recommend/products` |
| 查看推荐详情 | GET | `/admin-api/ai/recommend/{recommendationId}` |
| 记录产品交互 | POST | `/admin-api/ai/recommend/interaction` |

---

## 5. 方案对比

### 5.1 业务说明

在推荐结果页，代理人可选择1个目标产品（主推）+ 最多3个对比产品，生成多维度对比表格，突出差异项，辅助客户决策。

### 5.2 操作流程

1. 推荐产品列表页，每个产品卡片有【加入对比】按钮，底部固定浮层显示已加入对比的产品数量（1~4个）。
2. 选好后点击浮层中的【开始对比】按钮，跳转到对比详情页。
3. 对比详情页以表格形式展示，第一列为对比维度名称，后续列为各产品数据。
4. 两列数据不同时，差异项用黄色背景高亮。
5. 顶部有【保存对比记录】按钮，点击后保存当前对比到客户记录中。

**后端对比接口逻辑**：
1. 接收 targetProductId、compareProductIds（数组，最多3个）。
2. 校验产品数量（2~4个），否则返回"对比产品数量需在2到4个之间"。
3. 批量查询各产品详情（产品基础信息 + 保障条款结构化数据）。
4. 按预定义的对比维度列表（存配置文件）逐维度组装数据。
5. 比较各产品在同一维度的值，不相同时将 `highlight=true`。
6. 将对比记录写入 `ai_plan_comparison` 和 `ai_comparison_product`。
7. 返回对比矩阵数据。

**对比维度（共15个，可配置）**：产品名称、保险公司、险种类型、保障期限、缴费期限、保额（主险）、年缴保费、等待期、理赔方式（直赔/报销）、重疾保障数量、轻症保障数量、附加险支持、是否含保费豁免、分红/增值权益、公司偿付能力。

### 5.3 数据库设计

```sql
CREATE TABLE `ai_plan_comparison` (
  `id`                BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`       BIGINT NOT NULL,
  `recommendation_id` BIGINT,
  `target_product_id` BIGINT NOT NULL,
  `compare_time`      DATETIME NOT NULL,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`)
) COMMENT='AI方案对比记录表';

CREATE TABLE `ai_comparison_product` (
  `id`            BIGINT NOT NULL AUTO_INCREMENT,
  `comparison_id` BIGINT NOT NULL,
  `product_id`    BIGINT NOT NULL,
  `rank`          INT NOT NULL COMMENT '展示顺序',
  `total_score`   DECIMAL(5,2),
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_comparison_id` (`comparison_id`)
) COMMENT='AI对比产品明细表';
```

---

## 6. 规划方案分享

### 6.1 业务说明

代理人可将规划报告生成带有权限控制的 H5 分享链接，发送给客户或第三方查看。支持公开/密码保护/白名单三种模式。

### 6.2 操作流程

1. 规划报告详情页点击【分享】按钮，弹出分享配置弹框。

**弹框字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 分享方式 | 单选 | ✅ | 公开链接 / 密码保护 / 仅限指定手机号 |
| 访问密码 | 文本 | 条件必填 | 选密码保护时必填，4~8位数字 |
| 允许访问手机号 | 标签输入 | 条件必填 | 选仅限指定手机号时必填，最多10个 |
| 有效天数 | 数字 | ✅ | 1~90天，默认7天 |
| 最大查看次数 | 数字 | ❌ | 不填则不限制 |

2. 点击【生成分享链接】，后端生成分享码和链接，弹框内展示链接和二维码，提供【复制链接】【下载二维码】按钮。

3. 分享管理列表（客户详情页）：展示该客户所有分享记录，可撤销分享（status=0）。

**后端生成逻辑**：
1. 校验报告 status=1（已生成成功）。
2. 生成 share_code（UUID 取前8位+时间戳后4位，确保唯一）。
3. 生成 share_url = `https://{域名}/share/{share_code}`。
4. 调用二维码生成库（ZXing）生成 share_url 的二维码图片，上传 OSS，得到 qrcode_url。
5. 插入 `ai_plan_share` 记录，计算 expire_time = now + expireDays。
6. 返回 shareUrl、qrcodeUrl、accessPassword。

**H5 分享页访问逻辑**（面向客户端，单独 C 端接口）：
1. 根据 share_code 查询分享记录，校验 status=1 且未过期。
2. 若 share_type=password，要求用户输入密码，校验后继续。
3. 若 share_type=restricted，要求用户输入手机号+验证码，校验手机号在白名单内。
4. 更新 current_view_count+1，若超过 max_view_count 则返回"访问次数已达上限"。
5. 记录访问日志（ai_share_access_log）：访问时间、IP、设备信息。
6. 返回报告数据（部分字段脱敏，脱敏规则按 data_mask 配置）。

### 6.3 数据库设计

```sql
CREATE TABLE `ai_plan_share` (
  `id`                  BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`         BIGINT NOT NULL,
  `report_id`           BIGINT NOT NULL,
  `recommendation_id`   BIGINT,
  `share_code`          VARCHAR(32) NOT NULL COMMENT '唯一分享码',
  `share_url`           VARCHAR(500),
  `qrcode_url`          VARCHAR(500),
  `share_type`          VARCHAR(20) NOT NULL COMMENT 'public/password/restricted',
  `access_password`     VARCHAR(100),
  `allowed_phones`      JSON COMMENT '["138xxxx1234","139xxxx5678"]',
  `expire_time`         DATETIME,
  `max_view_count`      INT,
  `current_view_count`  INT NOT NULL DEFAULT 0,
  `data_mask`           JSON COMMENT '脱敏配置，如{"idCard":true,"phone":true}',
  `status`              TINYINT(1) NOT NULL DEFAULT 1 COMMENT '0撤销 1生效 2已过期',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_share_code` (`share_code`, `deleted`),
  KEY `idx_customer_id` (`customer_id`)
) COMMENT='AI方案分享表';

CREATE TABLE `ai_share_access_log` (
  `id`           BIGINT NOT NULL AUTO_INCREMENT,
  `share_id`     BIGINT NOT NULL,
  `access_time`  DATETIME NOT NULL,
  `access_phone` VARCHAR(11),
  `access_ip`    VARCHAR(50),
  `access_device` VARCHAR(200),
  `duration`     INT COMMENT '停留时长（秒）',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_share_id` (`share_id`)
) COMMENT='AI分享访问日志表';
```

### 6.4 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 创建分享 | POST | `/admin-api/ai/share/create` |
| 分享列表 | GET | `/admin-api/ai/share/list?customerId=xxx` |
| 撤销分享 | PUT | `/admin-api/ai/share/{id}/revoke` |
| H5访问验证 | POST | `/app-api/ai/share/access/{shareCode}` |
| H5访问记录 | POST | `/app-api/ai/share/log` |

---

*文档结束 · 下篇见《阶段4-AI智能中台需求文档-中（智能核保）》*

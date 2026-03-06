# 阶段4 · AI智能中台需求文档（中）— 智能核保 & 智能客服

> 框架：yudao-cloud（ruoyi-vue-pro 微服务版）  
> 模块前缀：`ai_`  
> 接口前缀：`/admin-api/ai/`  
> 适用人员：前端开发、后端开发  
> 文档版本：v2.0

---

## 目录

1. [智能核保](#1-智能核保)
   - 1.1 疾病库维护
   - 1.2 核保规则配置
   - 1.3 智能问答（核保流程）
   - 1.4 核保结论
   - 1.5 人工核保
2. [智能客服](#2-智能客服)
   - 2.1 知识库配置
   - 2.2 意图识别
   - 2.3 对话管理
   - 2.4 转人工客服

---

## 1. 智能核保

### 1.1 疾病库维护

#### 1.1.1 业务说明

疾病库是智能核保的基础数据，包含疾病名称、ICD-10 编码、别名（俗称/医学名称）、默认核保等级等信息。支持全文检索（基于 Elasticsearch），用于用户填写健康告知时的疾病搜索。

#### 1.1.2 PC 后台 — 疾病库管理

路径：**AI智能工具 → 智能核保 → 疾病库管理**

**列表页字段**：疾病编码、疾病名称（中文）、疾病分类、ICD-10编码、严重程度（1-5星展示）、默认核保等级（标准体/加费/延期/拒保）、状态、操作（编辑/禁用/查看别名）。

支持按疾病名称（模糊）、分类、核保等级筛选；支持导入（Excel模板导入），导入时字段同新建表单。

**新建/编辑疾病表单字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 疾病编码 | 文本 | ✅ | 系统自动生成，可手动改，唯一 |
| 疾病名称（中文） | 文本 | ✅ | 最长200字 |
| 疾病名称（英文） | 文本 | ❌ | |
| 疾病分类 | 下拉/树选择 | ✅ | 如：心血管系统、肿瘤、内分泌等 |
| ICD-10编码 | 标签输入 | ❌ | 可添加多个，如 I21.0、I21.1 |
| 疾病描述 | 富文本 | ❌ | |
| 常见症状 | 标签输入 | ❌ | 多个症状标签 |
| 严重程度 | 星级选择 | ✅ | 1~5 |
| 默认核保等级 | 下拉 | ✅ | 标准体/加费体/延期/拒保/转人工 |
| 默认加费比例 | 数字 | 条件必填 | 选择"加费体"时必填，如 20（即20%） |
| 状态 | 开关 | ✅ | 默认启用 |

点击【查看别名】弹出别名管理弹框，展示该疾病的所有别名，支持添加（别名文本+别名类型：俗称/医学名/地方名）和删除。

**后端保存逻辑**：
1. 校验 disease_code 同租户唯一（deleted=0）。
2. 保存到 `ai_disease_info` 和 `ai_disease_alias`。
3. **同步更新 Elasticsearch 索引**：将疾病名称（中英文）、所有别名、ICD-10编码、症状等字段同步到 ES 的 `disease_index` 索引（使用 ik_max_word 分词器）。
4. 删除/禁用疾病时，同步从 ES 删除或标记该文档。

**ES 全量同步接口**（管理员操作）：`POST /admin-api/ai/disease/sync-es`，将全量疾病数据重新写入 ES。

#### 1.1.3 数据库设计

```sql
CREATE TABLE `ai_disease_info` (
  `id`                   BIGINT NOT NULL AUTO_INCREMENT,
  `disease_code`         VARCHAR(32) NOT NULL COMMENT '疾病编码，同租户唯一',
  `disease_name_cn`      VARCHAR(200) NOT NULL COMMENT '中文名称',
  `disease_name_en`      VARCHAR(200),
  `disease_category`     VARCHAR(50) COMMENT '疾病分类',
  `icd10_codes`          JSON COMMENT '["I21.0","I21.1"]',
  `description`          TEXT,
  `symptoms`             JSON COMMENT '["胸痛","气短"]',
  `severity_level`       TINYINT(1) COMMENT '严重程度 1-5',
  `underwriting_grade`   VARCHAR(20) COMMENT 'standard/extra/postpone/decline/manual',
  `default_premium_rate` DECIMAL(5,2) COMMENT '默认加费比例%',
  `status`               TINYINT(1) NOT NULL DEFAULT 1,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_disease_code` (`disease_code`, `tenant_id`, `deleted`),
  KEY `idx_category` (`disease_category`)
) COMMENT='AI疾病信息表';

CREATE TABLE `ai_disease_alias` (
  `id`          BIGINT NOT NULL AUTO_INCREMENT,
  `disease_id`  BIGINT NOT NULL,
  `alias_name`  VARCHAR(200) NOT NULL,
  `alias_type`  VARCHAR(20) COMMENT 'common（俗称）/medical（医学名）/local（地方名）',
  `pinyin`      VARCHAR(500) COMMENT '拼音（用于前端拼音搜索）',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_disease_id` (`disease_id`)
) COMMENT='AI疾病别名表';
```

#### 1.1.4 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 疾病列表 | GET | `/admin-api/ai/disease/page` |
| 新建疾病 | POST | `/admin-api/ai/disease` |
| 编辑疾病 | PUT | `/admin-api/ai/disease/{id}` |
| 疾病详情 | GET | `/admin-api/ai/disease/{id}` |
| 别名列表 | GET | `/admin-api/ai/disease/{id}/alias` |
| 添加别名 | POST | `/admin-api/ai/disease/{id}/alias` |
| 删除别名 | DELETE | `/admin-api/ai/disease/alias/{aliasId}` |
| **ES搜索疾病**（健康告知时调用） | GET | `/admin-api/ai/disease/search?keyword=心梗` |
| 全量同步ES | POST | `/admin-api/ai/disease/sync-es` |

---

### 1.2 核保规则配置

#### 1.2.1 业务说明

核保规则以决策树方式存储，一个产品（或险种）对应一棵规则树。规则树由若干判断节点（条件分支）和结论节点（核保结论）构成。规则通过可视化界面配置后，后端转换为 Drools DRL 格式存储并热加载执行。

#### 1.2.2 PC 后台 — 核保规则管理

路径：**AI智能工具 → 智能核保 → 核保规则配置**

**规则树列表页字段**：规则树ID、关联产品名称、险种类型、规则树名称、版本号、状态（草稿/测试中/已发布）、发布时间、操作（编辑/发布/复制/查看测试记录）。

按产品、险种类型、状态筛选。

**新建/编辑规则树**：

进入规则树编辑页（全屏页面，不是弹框），左侧为可视化决策树画布（基于 AntV G6 或 X6 实现），右侧为当前选中节点的属性面板。

- 顶部操作栏：【保存（草稿）】【测试】【发布】【返回列表】
- 画布支持：添加判断节点（拖拽到画布）、添加结论节点、连接节点（拖拽连线）、删除节点/连线

**判断节点属性面板字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 节点名称 | 文本 | ✅ | 如"血糖值判断" |
| 节点编码 | 文本 | ✅ | 系统自动生成，如 NODE_001 |
| 判断条件 | 构建器 | ✅ | 字段+运算符+值（支持多条件AND/OR组合） |
| 提问文本 | 文本 | ✅ | 向用户展示的问题，如"您的血糖空腹值是多少？" |
| 问题类型 | 下拉 | ✅ | 单选/数字/日期 |
| 选项 | 动态列表 | 条件必填 | 单选类型时必填 |

**结论节点属性面板字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 节点名称 | 文本 | ✅ | |
| 核保结论 | 下拉 | ✅ | 标准体/加费体/除外/延期/拒保/转人工 |
| 加费比例 | 数字 | 条件必填 | 结论为加费体时必填，如20（即20%）|
| 除外责任 | 文本 | 条件必填 | 结论为除外时必填，说明除外的部位/疾病 |
| 延期时长 | 数字 | 条件必填 | 结论为延期时必填，如12（个月） |
| 结论说明 | 文本 | ❌ | 展示给用户的说明文字 |

**发布流程**：
1. 点击【测试】，弹出测试面板，可手动输入测试用例（模拟用户回答），验证规则树走向是否符合预期，记录测试结果到 `ai_rule_tree_test_log`。
2. 测试通过后点击【发布】，将 status 从0或1改为2，记录 publish_time。
3. 同一产品同时只允许一棵已发布的规则树，发布新版本时旧版本自动归档（status=-1）。

**后端保存逻辑**：
1. 保存规则树基本信息到 `ai_underwriting_rule_tree`。
2. 将可视化的决策树 JSON（包含所有节点、连线、属性）存入 `tree_json` 字段。
3. 后端将 tree_json 转换为 Drools DRL 规则文件内容，存入 `drl_content` 字段。
4. 发布时，使用 KieContainer 热加载新规则，覆盖旧规则，无需重启服务。

#### 1.2.3 数据库设计

```sql
CREATE TABLE `ai_underwriting_rule_tree` (
  `id`             BIGINT NOT NULL AUTO_INCREMENT,
  `product_id`     BIGINT NOT NULL COMMENT '关联产品ID',
  `insurance_type` VARCHAR(50) COMMENT '险种类型，如life/critical_illness/accident',
  `tree_name`      VARCHAR(100) NOT NULL,
  `version`        VARCHAR(20) NOT NULL DEFAULT '1.0',
  `drl_content`    LONGTEXT COMMENT 'Drools DRL规则内容（由tree_json自动生成）',
  `tree_json`      JSON COMMENT '可视化决策树完整JSON',
  `status`         TINYINT(1) NOT NULL DEFAULT 0 COMMENT '-1归档 0草稿 1测试中 2已发布',
  `publish_time`   DATETIME,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_product_id` (`product_id`),
  KEY `idx_status` (`status`)
) COMMENT='AI核保规则树表';

CREATE TABLE `ai_rule_tree_test_log` (
  `id`           BIGINT NOT NULL AUTO_INCREMENT,
  `tree_id`      BIGINT NOT NULL,
  `test_input`   JSON COMMENT '测试输入（模拟问答数据）',
  `test_result`  JSON COMMENT '规则执行结果',
  `is_pass`      BIT(1) COMMENT '是否通过',
  `tester_id`    BIGINT,
  `test_time`    DATETIME NOT NULL,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_tree_id` (`tree_id`)
) COMMENT='AI规则树测试日志';
```

#### 1.2.4 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 规则树列表 | GET | `/admin-api/ai/underwriting/rule-tree/page` |
| 创建规则树 | POST | `/admin-api/ai/underwriting/rule-tree` |
| 保存规则树（含节点） | PUT | `/admin-api/ai/underwriting/rule-tree/{id}` |
| 获取规则树详情 | GET | `/admin-api/ai/underwriting/rule-tree/{id}` |
| 测试规则树 | POST | `/admin-api/ai/underwriting/rule-tree/{id}/test` |
| 发布规则树 | PUT | `/admin-api/ai/underwriting/rule-tree/{id}/publish` |
| 热加载规则 | POST | `/admin-api/ai/underwriting/rule-tree/{id}/reload` |

---

### 1.3 智能问答（核保流程）

#### 1.3.1 业务说明

在投保流程的健康告知环节，用户（客户/代理人）输入疾病名称，系统匹配疾病库后加载对应产品的核保规则树，逐步向用户提问（遍历决策树节点），根据用户回答实时推进，最终给出核保结论。

#### 1.3.2 核保问答流程

```
用户搜索疾病（ES检索）
    ↓
选择疾病确认（可多选多种疾病）
    ↓
系统查询该产品 × 该疾病的已发布规则树
    ↓
创建核保会话（ai_underwriting_qa_session）
    ↓
从根节点开始，返回第一个问题
    ↓
用户回答 → 后端根据答案匹配规则树分支 → 返回下一个问题
    ↓
到达结论节点（叶子节点）
    ↓
若结论=转人工 → 进入人工核保流程
其他结论 → 记录核保结论，继续投保流程
```

#### 1.3.3 前端交互说明

- 问答界面类似聊天界面，问题出现在左侧（机器人气泡），用户回答后显示在右侧。
- 单选题：以按钮组展示选项，点击即选中。
- 数字/日期题：弹出输入框，输入完成点击确认。
- 支持【返回上一题】（最多返回3步）。
- 顶部显示当前疾病名称和估计问题总数（若无法估计则不显示）。
- 进度条显示已完成题数 / 已知总题数（决策树展开后更新）。

#### 1.3.4 后端核保问答逻辑

**创建会话接口（`POST /admin-api/ai/underwriting/qa/start`）**：
1. 入参：applyId（投保申请ID）、diseaseIds（疾病ID数组）、productId。
2. 查询 product 对应的已发布规则树（status=2），若无规则树则直接返回"标准体"。
3. 逐个疾病创建 `ai_underwriting_qa_session` 记录（一个疾病一个会话）。
4. 返回 sessionId，以及规则树根节点对应的第一个问题。

**提交答案接口（`POST /admin-api/ai/underwriting/qa/answer`）**：
1. 入参：sessionId、nodeCode（当前节点编码）、answerValue。
2. 校验 session 存在且 session_status=0（进行中）。
3. 将答案保存到 `ai_underwriting_qa_record`。
4. 加载该会话关联规则树的 DRL，执行 Drools 推理：
   - 将当前所有已回答问题数据构建成 Fact 对象。
   - 触发规则引擎，得到下一个需要问的节点或结论节点。
5. 若得到判断节点：返回下一个问题（question_text、question_type、options）。
6. 若得到结论节点：
   - 记录核保结论，更新 session_status=1（已完成）。
   - 返回 `{type: "conclusion", conclusion: {...}}`。
7. 更新 session 的 current_node_code、answered_count。

**返回上一题接口（`PUT /admin-api/ai/underwriting/qa/back`）**：
1. 查询该 session 最后一条 `ai_underwriting_qa_record`，软删除该条记录（deleted=1）。
2. 更新 session 的 current_node_code 为前一节点编码，answered_count-1。
3. 返回上一题的问题数据和已保存的答案（便于前端回显）。

#### 1.3.5 数据库设计

```sql
CREATE TABLE `ai_underwriting_qa_session` (
  `id`                BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`       BIGINT NOT NULL,
  `apply_id`          BIGINT COMMENT '投保申请ID',
  `disease_id`        BIGINT NOT NULL,
  `product_id`        BIGINT NOT NULL,
  `tree_id`           BIGINT NOT NULL COMMENT '规则树ID',
  `session_status`    TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0进行中 1已完成 2已放弃',
  `current_node_code` VARCHAR(50),
  `total_questions`   INT NOT NULL DEFAULT 0,
  `answered_count`    INT NOT NULL DEFAULT 0,
  `start_time`        DATETIME,
  `complete_time`     DATETIME,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_apply_id` (`apply_id`)
) COMMENT='AI核保问答会话表';

CREATE TABLE `ai_underwriting_qa_record` (
  `id`            BIGINT NOT NULL AUTO_INCREMENT,
  `session_id`    BIGINT NOT NULL,
  `question_seq`  INT NOT NULL COMMENT '问题序号，从1开始',
  `node_code`     VARCHAR(50) NOT NULL,
  `question_text` VARCHAR(1000) NOT NULL,
  `question_type` VARCHAR(20) NOT NULL,
  `options`       JSON,
  `answer_value`  VARCHAR(500),
  `answer_text`   VARCHAR(1000) COMMENT '答案展示文本',
  `answer_time`   DATETIME,
  `is_modified`   BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否因返回上一题而修改',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_session_id` (`session_id`)
) COMMENT='AI核保问答记录表';
```

---

### 1.4 核保结论

#### 1.4.1 业务说明

问答完成后，系统生成正式核保结论，写入 `ai_underwriting_conclusion`，并关联到投保申请。若同一申请有多种疾病，则每种疾病对应一条结论，综合结论取最严苛的。

#### 1.4.2 核保结论生成逻辑

1. 问答会话 status 变为1时，根据最终到达的结论节点数据创建 `ai_underwriting_conclusion`。
2. 若同一 apply_id 有多条结论，执行综合：
   - 存在任一"拒保" → 综合结论为"拒保"
   - 存在任一"转人工" → 综合结论为"转人工"
   - 存在任一"延期" → 综合结论为"延期"（取最长延期时长）
   - 存在"加费"或"除外" → 综合结论为"加费/除外"，保费 = 标准保费 × (1 + 各加费比例之和)
   - 全部为"标准体" → 综合结论为"标准体"
3. 更新投保申请状态，通知前端展示结论。

#### 1.4.3 PC 后台 — 核保结论查询

路径：**AI智能工具 → 智能核保 → 核保记录查询**

列表字段：申请单号、客户姓名、产品名称、疾病名称、核保结论、加费比例/除外责任/延期时长、核保时间、核保方式（智能/人工）、操作（查看详情）。

详情页展示完整问答记录（时间线形式）和最终结论。

#### 1.4.4 数据库设计

```sql
CREATE TABLE `ai_underwriting_conclusion` (
  `id`                  BIGINT NOT NULL AUTO_INCREMENT,
  `apply_id`            BIGINT NOT NULL,
  `customer_id`         BIGINT NOT NULL,
  `product_id`          BIGINT NOT NULL,
  `disease_id`          BIGINT COMMENT '对应的疾病ID',
  `session_id`          BIGINT COMMENT '问答会话ID',
  `underwriting_type`   VARCHAR(20) NOT NULL DEFAULT 'auto' COMMENT 'auto自动/manual人工',
  `conclusion`          VARCHAR(20) NOT NULL COMMENT 'standard/extra/exclusion/postpone/decline/manual',
  `extra_rate`          DECIMAL(5,2) COMMENT '加费比例%',
  `exclusion_items`     VARCHAR(500) COMMENT '除外责任描述',
  `postpone_months`     INT COMMENT '延期月数',
  `conclusion_reason`   VARCHAR(1000) COMMENT '结论原因说明',
  `is_comprehensive`    BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否为综合结论',
  `underwriting_time`   DATETIME NOT NULL,
  `underwriter_id`      BIGINT COMMENT '人工核保人员ID（人工核保时填写）',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_apply_id` (`apply_id`),
  KEY `idx_customer_id` (`customer_id`)
) COMMENT='AI核保结论表';
```

---

### 1.5 人工核保

#### 1.5.1 业务说明

当智能核保结论为"转人工"时，系统自动创建人工核保工单，分配给核保专员处理，支持补充资料上传，完成后录入核保结论。

#### 1.5.2 操作流程

**代理人侧（B 端 App/PC）**：
- 投保申请进入"待人工核保"状态，展示提示："您的申请已转入人工核保，预计1-3个工作日内完成，请耐心等待。"
- 可上传补充材料（体检报告、就诊记录等），调上传接口。
- 可查看工单进度。

**核保专员侧（PC 后台）**：
- 路径：**AI智能工具 → 智能核保 → 人工核保工单**
- 列表字段：工单号、申请单号、客户姓名、产品名称、疾病名称、优先级、工单状态（待处理/处理中/已完成/已关闭）、创建时间、SLA剩余时间（超SLA的标红）、操作（领取/处理/查看）。
- 工单状态筛选；按优先级排序；支持批量分配给指定核保人员。

**工单处理页**：
- 上方：客户基本信息、投保产品、疾病信息。
- 中间：智能核保问答记录（只读展示）、客户上传的补充材料（可下载预览）。
- 下方：核保结论表单（同1.4.3中的结论字段）+ 【提交结论】按钮。
- 提交后，工单 case_status 变为 completed，自动更新 `ai_underwriting_conclusion`，通知代理人和客户。

**SLA 规则（可配置）**：
- 普通工单：3个工作日
- 高优先级：1个工作日
- 紧急工单：4小时
- 超SLA时，系统发站内消息给工单负责人和其上级。

#### 1.5.3 数据库设计

```sql
CREATE TABLE `ai_manual_underwriting_case` (
  `id`               BIGINT NOT NULL AUTO_INCREMENT,
  `case_no`          VARCHAR(50) NOT NULL COMMENT '工单号，格式 UW+年月日+6位序号',
  `apply_id`         BIGINT NOT NULL,
  `customer_id`      BIGINT NOT NULL,
  `disease_id`       BIGINT,
  `product_id`       BIGINT NOT NULL,
  `transfer_reason`  VARCHAR(500) COMMENT '转人工原因',
  `priority`         VARCHAR(20) NOT NULL DEFAULT 'medium' COMMENT 'low/medium/high/urgent',
  `case_status`      VARCHAR(20) NOT NULL DEFAULT 'waiting' COMMENT 'waiting/processing/completed/closed',
  `assignee_id`      BIGINT COMMENT '分配的核保专员ID',
  `assign_time`      DATETIME,
  `sla_deadline`     DATETIME COMMENT 'SLA截止时间',
  `accept_time`      DATETIME COMMENT '核保专员接单时间',
  `complete_time`    DATETIME,
  `close_reason`     VARCHAR(500) COMMENT '关闭原因',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_case_no` (`case_no`, `deleted`),
  KEY `idx_apply_id` (`apply_id`),
  KEY `idx_assignee_id` (`assignee_id`),
  KEY `idx_case_status` (`case_status`)
) COMMENT='AI人工核保工单表';

CREATE TABLE `ai_manual_underwriting_attachment` (
  `id`        BIGINT NOT NULL AUTO_INCREMENT,
  `case_id`   BIGINT NOT NULL,
  `file_name` VARCHAR(200) NOT NULL,
  `file_url`  VARCHAR(500) NOT NULL COMMENT 'OSS URL',
  `file_type` VARCHAR(50) COMMENT '文件类型：pdf/jpg/png/doc',
  `file_size` BIGINT,
  `uploader_id` BIGINT,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_case_id` (`case_id`)
) COMMENT='AI人工核保附件表';
```

#### 1.5.4 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 工单列表 | GET | `/admin-api/ai/underwriting/manual/page` |
| 工单详情 | GET | `/admin-api/ai/underwriting/manual/{id}` |
| 领取工单 | PUT | `/admin-api/ai/underwriting/manual/{id}/accept` |
| 批量分配工单 | PUT | `/admin-api/ai/underwriting/manual/batch-assign` |
| 提交核保结论 | POST | `/admin-api/ai/underwriting/manual/{id}/submit-conclusion` |
| 上传附件 | POST | `/admin-api/ai/underwriting/manual/{id}/attachment` |
| 核保问答记录 | GET | `/admin-api/ai/underwriting/qa/{sessionId}/records` |
| 核保结论查询 | GET | `/admin-api/ai/underwriting/conclusion/page` |

---

## 2. 智能客服

### 2.1 知识库配置

#### 2.1.1 业务说明

PC 后台维护保险业务 FAQ 知识库，知识条目经发布后用于智能客服机器人回答用户问题。支持树形分类管理、相似问题维护、全文检索（ES）。

#### 2.1.2 知识分类管理

路径：**AI智能工具 → 智能客服 → 知识分类管理**

树形列表展示分类层级（最多3层）。操作：添加子分类、编辑、删除（无知识的分类才能删除）。

**新建/编辑分类字段**：分类名称（必填，最长100字）、父分类（选树节点）、排序号（必填）、图标（OSS URL，可选）、描述（可选）。

#### 2.1.3 知识条目管理

路径：**AI智能工具 → 智能客服 → 知识库管理**

**列表字段**：知识编码、所属分类、标准问题（截取前30字）、状态（草稿/审核中/已发布/已下线）、点赞数、点踩数、创建人、发布时间、操作（编辑/审核/发布/下线）。

支持按分类、状态、关键词筛选。

**新建/编辑知识条目字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 标准问题 | 文本 | ✅ | 最长500字 |
| 所属分类 | 树选择 | ✅ | |
| 标准答案 | 富文本 | ✅ | 支持图片、链接 |
| 关键词 | 标签输入 | ❌ | 用于ES检索权重 |
| 适用范围 | 下拉 | ✅ | 全部/指定产品/指定场景 |
| 关联产品 | 多选 | 条件必填 | 适用范围=指定产品时必填 |
| 有效期 | 日期范围 | ❌ | 不填则永久有效 |

**知识审核流程**：
1. 编辑保存后 status=0（草稿），点击【提交审核】改为 status=1（审核中）。
2. 审核人员在审核列表看到待审核条目，点击【通过】改为 status=2（已发布），并同步到 ES；点击【驳回】返回草稿状态，填写驳回原因。
3. 已发布的条目可点击【下线】改为 status=3，同时从 ES 删除。

**相似问题管理**：
- 在知识详情页底部，可手动添加相似问题（最多20条），也会有学习来源（用户未匹配的问题被自动归类到相似问题待人工确认）。
- 相似问题用于提高 ES 的召回率。

#### 2.1.4 数据库设计

```sql
CREATE TABLE `ai_knowledge_category` (
  `id`            BIGINT NOT NULL AUTO_INCREMENT,
  `parent_id`     BIGINT NOT NULL DEFAULT 0,
  `category_name` VARCHAR(100) NOT NULL,
  `category_path` VARCHAR(500) COMMENT '路径，如 /1/5/12',
  `sort_order`    INT NOT NULL DEFAULT 0,
  `icon`          VARCHAR(500),
  `description`   VARCHAR(500),
  `status`        TINYINT(1) NOT NULL DEFAULT 1,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_parent_id` (`parent_id`)
) COMMENT='AI知识分类表';

CREATE TABLE `ai_knowledge_base` (
  `id`                BIGINT NOT NULL AUTO_INCREMENT,
  `knowledge_code`    VARCHAR(50) NOT NULL,
  `category_id`       BIGINT NOT NULL,
  `standard_question` VARCHAR(500) NOT NULL,
  `answer`            TEXT NOT NULL COMMENT '纯文本答案（客服机器人使用）',
  `answer_html`       LONGTEXT COMMENT '富文本答案（前端展示用）',
  `keywords`          JSON COMMENT '["关键词1","关键词2"]',
  `apply_scope`       VARCHAR(20) NOT NULL DEFAULT 'all' COMMENT 'all/product/scene',
  `product_ids`       JSON,
  `status`            TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0草稿 1审核中 2已发布 3已下线',
  `reviewer_id`       BIGINT,
  `reject_reason`     VARCHAR(500),
  `publish_time`      DATETIME,
  `expire_time`       DATETIME,
  `click_count`       INT NOT NULL DEFAULT 0,
  `like_count`        INT NOT NULL DEFAULT 0,
  `dislike_count`     INT NOT NULL DEFAULT 0,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_knowledge_code` (`knowledge_code`, `tenant_id`, `deleted`),
  KEY `idx_category_id` (`category_id`),
  KEY `idx_status` (`status`)
) COMMENT='AI知识库表';

CREATE TABLE `ai_knowledge_similar_question` (
  `id`               BIGINT NOT NULL AUTO_INCREMENT,
  `knowledge_id`     BIGINT NOT NULL,
  `similar_question` VARCHAR(500) NOT NULL,
  `similarity_score` DECIMAL(3,2),
  `source`           VARCHAR(20) NOT NULL DEFAULT 'manual' COMMENT 'manual手动/learned系统学习/user用户未匹配',
  `is_confirmed`     BIT(1) NOT NULL DEFAULT b'0' COMMENT '学习来源需人工确认',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_knowledge_id` (`knowledge_id`)
) COMMENT='AI知识相似问题表';
```

---

### 2.2 意图识别

#### 2.2.1 业务说明

用户在客服窗口输入消息后，后端调用阿里云 NLP 服务识别用户意图，并提取关键实体（如产品名、保单号等）。意图识别结果决定对话管理的处理策略。

#### 2.2.2 意图分类定义

| 意图编码 | 意图名称 | 处理策略 |
|----------|----------|----------|
| PRODUCT_CONSULT | 产品咨询 | 检索知识库匹配回答 |
| POLICY_QUERY | 保单查询 | 引导用户提供保单号，调保单查询接口 |
| CLAIM_CONSULT | 理赔咨询 | 检索知识库或转人工 |
| COMPLAINT | 投诉建议 | 直接转人工（高优先级） |
| RENEWAL_QUERY | 续保咨询 | 检索知识库，可关联续保入口 |
| SMALLTALK | 寒暄闲聊 | 返回预设闲聊回复 |
| UNKNOWN | 无法识别 | 连续3次后转人工 |

#### 2.2.3 技术实现

1. 调用阿里云 NLP 自然语言理解（NLU）服务 API。
2. 对返回的 intent 取 top-1，若 confidence < 0.3 则归为 UNKNOWN。
3. 同时进行实体识别（NER），提取 `product_name`、`policy_no`、`date` 等实体。
4. 识别结果缓存到 Redis（key=sessionId+messageId，TTL=1小时），同一消息不重复调用。
5. 若阿里云 NLP 调用失败，降级为关键词匹配（从知识库 keywords 字段匹配），并记录告警日志。
6. 每次识别结果记录到 `ai_chatbot_message`，包含 intent 和 entities 字段（JSON），用于后续优化。

---

### 2.3 对话管理

#### 2.3.1 业务说明

智能客服入口供客户（C端）和代理人（B端）使用。系统管理对话状态，维护多轮上下文，根据意图触发不同的处理流程。

#### 2.3.2 对话入口与会话创建

**C 端商城**：页面右下角悬浮"客服"按钮，点击弹出对话框。
**B 端 App**：底部导航"客服"Tab。

点击进入后，若当前无活跃会话（active状态），系统自动创建会话：
- 生成 session_id（UUID）
- 记录 customer_id、channel（web/app）、start_time
- 发送欢迎语（固定文案，如"您好！我是智能客服小保，请问有什么可以帮您？"）

若有活跃会话（且最后一条消息在1小时内），则恢复该会话（加载历史消息）。

#### 2.3.3 消息处理流程（每条用户消息）

1. 前端发送消息到 `/app-api/ai/chatbot/message/send`。
2. 保存用户消息到 `ai_chatbot_message`（message_type=user）。
3. 调用意图识别服务（见2.2.3）。
4. 根据意图执行对应处理：

   **PRODUCT_CONSULT / CLAIM_CONSULT / RENEWAL_QUERY**：
   - 用消息文本调用 ES 检索知识库（全文搜索 standard_question + similar_question + keywords）。
   - 取相似度最高的1条（score > 0.5 才使用），返回 answer 文本。
   - 若 score ≤ 0.5，返回"抱歉，我没有找到相关答案，需要为您转接人工客服吗？"，并提供【转人工】按钮。
   - 保存机器人回复到 `ai_chatbot_message`（message_type=bot），记录 knowledge_id、confidence。

   **POLICY_QUERY**：
   - 若上下文（context_data）中没有 policy_no，返回"请提供您的保单号"。
   - 若有 policy_no，调保单查询接口返回保单信息摘要。

   **COMPLAINT**：
   - 直接触发转人工流程（见2.4），优先级=high。

   **UNKNOWN（连续3次）**：
   - 返回"为了更好地帮助您，为您转接人工客服"，自动触发转人工。

5. 实时通过 WebSocket 推送机器人回复给前端（不轮询）。
6. 更新会话的 context_data（存最近5条对话 + 提取的实体信息）到 Redis，TTL=1小时。

**上下文存储结构（Redis）**：
```json
{
  "sessionId": "xxx",
  "recentMessages": [
    {"role":"user","content":"重疾险怎么理赔"},
    {"role":"bot","content":"重疾险理赔流程如下..."}
  ],
  "entities": {
    "product_name": "XX重疾险",
    "policy_no": null
  },
  "unknownCount": 0,
  "lastActiveTime": "2025-02-14T10:30:00"
}
```

#### 2.3.4 数据库设计

```sql
CREATE TABLE `ai_chatbot_session` (
  `id`              BIGINT NOT NULL AUTO_INCREMENT,
  `session_id`      VARCHAR(64) NOT NULL COMMENT 'UUID，全局唯一',
  `customer_id`     BIGINT NOT NULL,
  `channel`         VARCHAR(20) NOT NULL COMMENT 'web/app/wechat',
  `session_status`  VARCHAR(20) NOT NULL DEFAULT 'active' COMMENT 'active/ended/transferred',
  `current_intent`  VARCHAR(100),
  `start_time`      DATETIME NOT NULL,
  `end_time`        DATETIME,
  `message_count`   INT NOT NULL DEFAULT 0,
  `is_transferred`  BIT(1) NOT NULL DEFAULT b'0',
  `transfer_time`   DATETIME,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_session_id` (`session_id`, `deleted`),
  KEY `idx_customer_id` (`customer_id`)
) COMMENT='AI对话会话表';

CREATE TABLE `ai_chatbot_message` (
  `id`              BIGINT NOT NULL AUTO_INCREMENT,
  `session_id`      VARCHAR(64) NOT NULL,
  `message_type`    VARCHAR(20) NOT NULL COMMENT 'user/bot/system',
  `message_content` TEXT NOT NULL,
  `message_time`    DATETIME NOT NULL,
  `intent`          VARCHAR(100) COMMENT '识别的意图',
  `entities`        JSON COMMENT '识别的实体',
  `knowledge_id`    BIGINT COMMENT '匹配的知识库条目ID',
  `confidence`      DECIMAL(3,2) COMMENT '置信度',
  `is_satisfied`    BIT(1) COMMENT '用户是否满意此回答（用户点赞/踩后更新）',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_session_id` (`session_id`),
  KEY `idx_message_time` (`message_time`)
) COMMENT='AI对话消息表';
```

---

### 2.4 转人工客服

#### 2.4.1 业务说明

转人工时系统创建人工客服工单，通过腾讯云 IM SDK 实现客服与客户的实时聊天，同时将之前的机器人对话上下文同步给接待客服。

#### 2.4.2 转人工触发与排队

**触发条件**：
1. 意图识别连续3次为 UNKNOWN。
2. 用户点击对话界面中的【转人工】按钮。
3. 意图为 COMPLAINT。
4. 机器人回复了"抱歉没有找到答案"且用户点击了【转人工】按钮。

**转人工流程**：
1. 创建 `ai_manual_service_case` 工单，状态=waiting，case_no 自动生成（格式：CS+年月日+6位序号）。
2. 按负载均衡算法（当前接待数最少的在线客服）自动分配客服，或放入公共等待队列。
3. 向客服发送系统消息（站内消息/IM消息）："有新会话需要处理，客户：xxx，问题类型：xxx"。
4. 通过 WebSocket 通知用户："您前面还有 N 位用户等待，预计等待时间约 M 分钟。"
5. 客服点击【接入】按钮后，case_status 变为 serving，accept_time 记录，WebSocket 通知用户已连接人工客服。

**聊天界面**：
- 技术方案：腾讯云 IM SDK（TRTC/腾讯云 IM）。
- 客服端（PC 后台）：集成 IM SDK，左侧会话列表，右侧聊天窗口，顶部展示客户基本信息和历史机器人对话（只读）。
- 客户端（C 端/B 端 App）：对话界面无缝切换为与真人客服的聊天。
- 消息历史存储在腾讯云 IM，同时同步写入 `ai_chatbot_message`（message_type=manual_agent）。

**结束会话**：
- 客服点击【结束会话】，弹确认框，确认后 case_status=completed，complete_time 记录。
- 向客户推送满意度调查弹框（1-5星+文字评价），评价保存到 `ai_service_evaluation`。
- 更新 `ai_chatbot_session` session_status=ended。

#### 2.4.3 PC 后台 — 客服工作台

路径：**AI智能工具 → 智能客服 → 客服工作台**

- 左侧：当前排队列表（按等待时长排序）+ 我的会话列表。
- 中间：聊天窗口（集成 IM SDK）。
- 右侧：客户信息面板（姓名、保单数量、历史工单等）。
- 顶部状态栏：在线/忙碌/离线切换，当前接待数/上限。

#### 2.4.4 数据库设计

```sql
CREATE TABLE `ai_manual_service_case` (
  `id`                  BIGINT NOT NULL AUTO_INCREMENT,
  `case_no`             VARCHAR(50) NOT NULL,
  `chatbot_session_id`  VARCHAR(64) NOT NULL COMMENT '智能客服会话ID',
  `customer_id`         BIGINT NOT NULL,
  `transfer_reason`     VARCHAR(500),
  `case_type`           VARCHAR(20) NOT NULL COMMENT 'consult/claim/complaint',
  `priority`            VARCHAR(20) NOT NULL DEFAULT 'medium',
  `case_status`         VARCHAR(20) NOT NULL DEFAULT 'waiting' COMMENT 'waiting/serving/completed/closed',
  `assign_agent_id`     BIGINT,
  `queue_position`      INT,
  `wait_time`           INT COMMENT '等待时长（秒）',
  `serve_time`          INT COMMENT '服务时长（秒）',
  `transfer_time`       DATETIME NOT NULL,
  `accept_time`         DATETIME,
  `complete_time`       DATETIME,
  `im_group_id`         VARCHAR(100) COMMENT '腾讯云IM群组ID',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_case_no` (`case_no`, `deleted`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_assign_agent_id` (`assign_agent_id`),
  KEY `idx_case_status` (`case_status`)
) COMMENT='AI人工客服工单表';

CREATE TABLE `ai_service_evaluation` (
  `id`           BIGINT NOT NULL AUTO_INCREMENT,
  `case_id`      BIGINT NOT NULL,
  `customer_id`  BIGINT NOT NULL,
  `agent_id`     BIGINT NOT NULL,
  `star_rating`  TINYINT NOT NULL COMMENT '1-5星',
  `comment`      VARCHAR(500),
  `eval_time`    DATETIME NOT NULL,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_case_id` (`case_id`, `deleted`),
  KEY `idx_agent_id` (`agent_id`)
) COMMENT='AI服务满意度评价表';
```

#### 2.4.5 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 发送消息 | POST | `/app-api/ai/chatbot/message/send` |
| 获取历史消息 | GET | `/app-api/ai/chatbot/session/{sessionId}/messages` |
| 触发转人工 | POST | `/app-api/ai/chatbot/transfer` |
| 知识库评价（赞/踩） | POST | `/app-api/ai/chatbot/message/{msgId}/rate` |
| 工单列表（客服） | GET | `/admin-api/ai/cs/case/page` |
| 接入会话（客服） | PUT | `/admin-api/ai/cs/case/{id}/accept` |
| 结束会话（客服） | PUT | `/admin-api/ai/cs/case/{id}/complete` |
| 客服在线状态切换 | PUT | `/admin-api/ai/cs/agent/status` |
| 提交满意度评价 | POST | `/app-api/ai/cs/evaluation` |
| 未匹配问题汇总（管理） | GET | `/admin-api/ai/cs/unmatched-questions` |

---

*文档结束 · 下篇见《阶段4-AI智能中台需求文档-下（数据分析）》*

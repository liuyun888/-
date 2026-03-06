# 保险中介平台 - 阶段4 AI智能工具详细需求设计文档

> **项目基础框架**:ruoyi-vue-pro  
> **文档版本**:v1.0  
> **编写日期**:2025-02-14  
> **目标读者**:前端开发、后端开发、测试工程师、AI算法工程师

---

## 文档说明

本文档基于ruoyi-vue-pro框架进行设计,详细描述阶段4-AI智能工具的所有功能模块。每个功能模块包含:

- **功能概述**:业务目标和使用场景
- **业务流程**:完整的业务处理流程
- **功能需求**:详细的功能点说明
- **数据库设计**:表结构、索引、关联关系
- **接口设计**:RESTful API定义
- **业务逻辑**:核心算法和处理流程
- **技术实现要点**:技术方案和难点解决

**注意**:本文档不包含代码示例,仅提供业务逻辑和技术方案说明。

---

## 目录

1. [AI保障规划](#1-ai保障规划)
2. [智能核保](#2-智能核保)
3. [智能客服](#3-智能客服)
4. [数据分析](#4-数据分析)
5. [数据库设计规范](#5-数据库设计规范)
6. [接口设计规范](#6-接口设计规范)
7. [技术实现要点](#7-技术实现要点)

---

## 1. AI保障规划

### 1.1 风险测评问卷

#### 1.1.1 功能概述

**业务目标**:
- 通过动态问卷收集客户家庭财务信息
- 评估客户风险承受能力
- 为保障缺口计算提供数据基础

**使用场景**:
- 代理人为客户进行家庭保障规划前的信息收集
- 客户自助填写风险评估问卷
- 定期更新客户家庭财务状况

**核心特性**:
- 支持跳题逻辑,根据答案动态展示问题
- 支持暂存和继续填写
- 自动保存填写进度

#### 1.1.2 业务流程

```
代理人发起测评
    ↓
选择问卷模板
    ↓
客户填写问卷 ← → 跳题逻辑判断
    ↓
自动保存答案
    ↓
完成问卷提交
    ↓
触发缺口计算
```

#### 1.1.3 页面设计

**问卷填写页面**:
```
┌─────────────── 家庭风险评估问卷 ───────────────┐
│  客户: 张先生                进度: [████░░] 60%  │
├──────────────────────────────────────────────────┤
│                                                  │
│  第3页 / 共5页                                   │
│                                                  │
│  问题3: 您的家庭年收入是多少?                    │
│  ○ 10万以下                                      │
│  ○ 10-30万                                       │
│  ● 30-50万                                       │
│  ○ 50万以上                                      │
│                                                  │
│  问题4: 您的家庭年支出大约是多少?                │
│  [___________] 万元                              │
│                                                  │
│                                                  │
│  [暂存] [上一步]                     [下一步]    │
└──────────────────────────────────────────────────┘
```

#### 1.1.4 字段定义与数据库设计

**问卷模板表**:
```sql
CREATE TABLE `ai_questionnaire_template` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `template_code` VARCHAR(32) NOT NULL COMMENT '模板编码',
  `template_name` VARCHAR(100) NOT NULL COMMENT '模板名称',
  `description` VARCHAR(500) COMMENT '描述',
  `version` VARCHAR(20) NOT NULL DEFAULT '1.0' COMMENT '版本号',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态:0-停用 1-启用',
  
  -- ruoyi框架标准字段
  `creator` VARCHAR(64) DEFAULT '' COMMENT '创建者',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` VARCHAR(64) DEFAULT '' COMMENT '更新者',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenant_id` BIGINT NOT NULL DEFAULT 0 COMMENT '租户ID',
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_template_code` (`template_code`, `deleted`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI问卷模板表';
```

**问卷问题表**:
```sql
CREATE TABLE `ai_questionnaire_question` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `template_id` BIGINT NOT NULL COMMENT '模板ID',
  `question_code` VARCHAR(32) NOT NULL COMMENT '问题编码',
  `question_text` VARCHAR(500) NOT NULL COMMENT '问题文本',
  `question_type` VARCHAR(20) NOT NULL COMMENT '问题类型:single-单选 multiple-多选 input-文本 number-数字 date-日期',
  `question_group` VARCHAR(50) COMMENT '问题分组',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `is_required` BIT(1) NOT NULL DEFAULT b'1' COMMENT '是否必填',
  `options` JSON COMMENT '选项配置',
  `validation_rule` JSON COMMENT '校验规则',
  `skip_logic` JSON COMMENT '跳题逻辑',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_template_id` (`template_id`),
  KEY `idx_sort` (`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI问卷问题表';
```

**问卷记录表**:
```sql
CREATE TABLE `ai_questionnaire_record` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `agent_id` BIGINT COMMENT '代理人ID',
  `template_id` BIGINT NOT NULL COMMENT '模板ID',
  `status` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '状态:0-未开始 1-进行中 2-已完成',
  `start_time` DATETIME COMMENT '开始时间',
  `complete_time` DATETIME COMMENT '完成时间',
  `duration` INT COMMENT '耗时(秒)',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI问卷记录表';
```

**问卷答案表**:
```sql
CREATE TABLE `ai_questionnaire_answer` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `record_id` BIGINT NOT NULL COMMENT '问卷记录ID',
  `question_id` BIGINT NOT NULL COMMENT '问题ID',
  `answer_value` VARCHAR(1000) COMMENT '答案值',
  `answer_text` TEXT COMMENT '答案文本',
  `answer_time` DATETIME COMMENT '答题时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_record_id` (`record_id`),
  KEY `idx_question_id` (`question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI问卷答案表';
```

#### 1.1.5 接口设计

```http
GET /admin-api/ai/questionnaire/template/{templateId}
功能: 获取问卷模板及所有问题
响应:
{
  "code": 0,
  "data": {
    "id": 1,
    "templateCode": "RISK_ASSESSMENT_V1",
    "templateName": "家庭风险评估问卷",
    "questions": [
      {
        "id": 101,
        "questionCode": "Q001",
        "questionText": "您的家庭年收入是多少?",
        "questionType": "single",
        "isRequired": true,
        "options": [
          {"value": "1", "label": "10万以下"},
          {"value": "2", "label": "10-30万"},
          {"value": "3", "label": "30-50万"},
          {"value": "4", "label": "50万以上"}
        ],
        "skipLogic": {
          "condition": "value == '4'",
          "action": "showQuestion",
          "targetQuestionCode": "Q003"
        }
      }
    ]
  }
}
```

```http
POST /admin-api/ai/questionnaire/answer
功能: 提交答案(支持单题提交和批量提交)
请求:
{
  "recordId": 12345,
  "questionId": 101,
  "answerValue": "3",
  "answerText": "30-50万"
}
响应:
{
  "code": 0,
  "data": {
    "nextQuestions": [
      {
        "questionCode": "Q002",
        "questionText": "您的家庭年支出大约是多少?"
      }
    ]
  }
}
```

```http
POST /admin-api/ai/questionnaire/complete
功能: 完成问卷
请求:
{
  "recordId": 12345
}
响应:
{
  "code": 0,
  "data": {
    "recordId": 12345,
    "completedAt": "2025-02-14 10:30:00"
  }
}
```

#### 1.1.6 业务逻辑 - 跳题逻辑引擎

**跳题规则配置示例**:
```json
{
  "condition": "value == '4'",
  "operator": "AND",
  "actions": [
    {
      "type": "showQuestion",
      "targetQuestionCode": "Q005"
    },
    {
      "type": "hideQuestion",
      "targetQuestionCode": "Q003"
    }
  ]
}
```

**跳题逻辑处理流程**:
1. 接收用户答案
2. 解析当前问题的skipLogic配置
3. 评估条件表达式
4. 执行对应的action
5. 返回下一个应该展示的问题列表

**技术实现要点**:
- 使用表达式引擎(如Aviator)解析条件
- 支持复杂的逻辑组合(AND/OR/NOT)
- 前后端都需要实现跳题逻辑(前端用于实时交互,后端用于数据校验)

---

### 1.2 缺口计算算法

#### 1.2.1 功能概述

**业务目标**:
- 基于标准普尔家庭资产象限模型计算保障缺口
- 分析客户在保障、投资、消费等方面的资金分配
- 为产品推荐提供数据依据

**计算模型 - 标准普尔家庭资产象限**:
```
┌─────────────────┬─────────────────┐
│  要花的钱(10%)  │  保命的钱(20%)  │
│  日常开销      │  意外/重疾保障  │
│  短期消费      │  寿险保障      │
└─────────────────┼─────────────────┘
│  生钱的钱(30%)  │  保本升值(40%)  │
│  投资理财      │  养老储备      │
│  创造收益      │  子女教育      │
└─────────────────┴─────────────────┘
```

#### 1.2.2 业务流程

```
获取问卷数据
    ↓
提取家庭财务指标
    ↓
计算各象限应有金额
    ↓
对比实际配置
    ↓
计算缺口
    ↓
生成分析报告
```

#### 1.2.3 数据库设计

```sql
CREATE TABLE `ai_gap_analysis_result` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `questionnaire_record_id` BIGINT NOT NULL COMMENT '问卷记录ID',
  
  -- 基础财务数据
  `family_annual_income` DECIMAL(15,2) COMMENT '家庭年收入',
  `family_monthly_expense` DECIMAL(15,2) COMMENT '家庭月支出',
  `total_assets` DECIMAL(15,2) COMMENT '总资产',
  `total_liabilities` DECIMAL(15,2) COMMENT '总负债',
  `investable_assets` DECIMAL(15,2) COMMENT '可投资资产',
  
  -- 标准普尔象限 - 目标vs当前vs缺口
  `emergency_fund_target` DECIMAL(15,2) COMMENT '应急金目标',
  `emergency_fund_current` DECIMAL(15,2) COMMENT '应急金当前',
  `emergency_fund_gap` DECIMAL(15,2) COMMENT '应急金缺口',
  
  `protection_target` DECIMAL(15,2) COMMENT '保障目标金额',
  `protection_current` DECIMAL(15,2) COMMENT '保障当前金额',
  `protection_gap` DECIMAL(15,2) COMMENT '保障缺口',
  
  `investment_target` DECIMAL(15,2) COMMENT '投资目标金额',
  `investment_current` DECIMAL(15,2) COMMENT '投资当前金额',
  `investment_gap` DECIMAL(15,2) COMMENT '投资缺口',
  
  `preservation_target` DECIMAL(15,2) COMMENT '保本目标金额',
  `preservation_current` DECIMAL(15,2) COMMENT '保本当前金额',
  `preservation_gap` DECIMAL(15,2) COMMENT '保本缺口',
  
  -- 保险保障缺口明细
  `life_insurance_gap` DECIMAL(15,2) COMMENT '寿险缺口',
  `critical_illness_gap` DECIMAL(15,2) COMMENT '重疾险缺口',
  `accident_insurance_gap` DECIMAL(15,2) COMMENT '意外险缺口',
  `medical_insurance_gap` DECIMAL(15,2) COMMENT '医疗险缺口',
  
  `calculate_time` DATETIME COMMENT '计算时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_questionnaire_record_id` (`questionnaire_record_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI缺口分析结果表';
```

```sql
CREATE TABLE `ai_gap_calculation_params` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `param_type` VARCHAR(50) NOT NULL COMMENT '参数类型:age-年龄 risk-风险偏好 responsibility-家庭责任',
  `param_key` VARCHAR(100) NOT NULL COMMENT '参数键',
  `param_value` DECIMAL(10,4) NOT NULL COMMENT '参数值',
  `description` VARCHAR(500) COMMENT '描述',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态:0-停用 1-启用',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_type_key` (`param_type`, `param_key`, `deleted`),
  KEY `idx_param_type` (`param_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI缺口计算参数表';
```

#### 1.2.4 接口设计

```http
POST /admin-api/ai/gap/calculate
功能: 执行缺口计算
请求:
{
  "questionnaireRecordId": 12345
}
响应:
{
  "code": 0,
  "data": {
    "resultId": 67890
  }
}
```

```http
GET /admin-api/ai/gap/result/{resultId}
功能: 获取缺口分析结果
响应:
{
  "code": 0,
  "data": {
    "customerId": 123,
    "customerName": "张先生",
    "familyAnnualIncome": 500000,
    "quadrants": {
      "emergency": {
        "target": 60000,
        "current": 30000,
        "gap": 30000,
        "percentage": "10%"
      },
      "protection": {
        "target": 120000,
        "current": 50000,
        "gap": 70000,
        "percentage": "20%"
      }
    },
    "insuranceGaps": {
      "lifeInsurance": 3000000,
      "criticalIllness": 500000,
      "accidentInsurance": 1000000,
      "medicalInsurance": 0
    }
  }
}
```

#### 1.2.5 业务逻辑 - 保障缺口计算公式

**年龄系数配置**:
```
18-30岁: 10倍
31-40岁: 8倍
41-50岁: 6倍
51-60岁: 4倍
60岁以上: 2倍
```

**寿险保障计算**:
```
寿险保额 = 年收入 × 年龄系数 × 家庭责任系数 × 风险偏好系数
寿险缺口 = 寿险保额 - 现有寿险保额
```

**重疾险保障计算**:
```
重疾保额 = 年收入 × 3-5倍
重疾缺口 = 重疾保额 - 现有重疾保额
```

**意外险保障计算**:
```
意外保额 = 年收入 × 5-10倍
意外缺口 = 意外保额 - 现有意外保额
```

**应急金计算**:
```
应急金 = 月支出 × 6个月
应急金缺口 = 应急金 - 现金及活期存款
```

**技术实现要点**:
- 使用BigDecimal进行精确计算,避免浮点数精度问题
- 计算参数支持配置化管理,便于调整策略
- 计算结果需要记录计算时间和所用参数版本,确保可追溯

---

### 1.3 规划报告生成

#### 1.3.1 功能概述

**业务目标**:
- 将缺口分析结果生成专业的PDF报告
- 包含图表、数据分析和产品推荐
- 支持在线预览和下载
- 支持微信/邮件分享

**报告结构**:
```
1. 封面页
2. 家庭基本情况
3. 标准普尔象限分析
4. 保障缺口分析
5. 资产配置建议
6. 产品推荐方案
7. 附录和免责声明
```

#### 1.3.2 数据库设计

```sql
CREATE TABLE `ai_planning_report` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `gap_result_id` BIGINT NOT NULL COMMENT '缺口分析结果ID',
  `report_code` VARCHAR(50) NOT NULL COMMENT '报告编号',
  `report_title` VARCHAR(200) COMMENT '报告标题',
  `template_id` BIGINT COMMENT '模板ID',
  `pdf_url` VARCHAR(500) COMMENT 'PDF文件URL',
  `pdf_size` BIGINT COMMENT '文件大小(字节)',
  `page_count` INT COMMENT '页数',
  `status` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '状态:0-生成中 1-成功 2-失败',
  `view_count` INT NOT NULL DEFAULT 0 COMMENT '查看次数',
  `share_count` INT NOT NULL DEFAULT 0 COMMENT '分享次数',
  `generate_time` DATETIME COMMENT '生成时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_report_code` (`report_code`, `deleted`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_gap_result_id` (`gap_result_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI规划报告表';
```

#### 1.3.3 接口设计

```http
POST /admin-api/ai/report/generate
功能: 生成规划报告(异步)
请求:
{
  "gapResultId": 67890,
  "templateId": 1
}
响应:
{
  "code": 0,
  "data": {
    "reportId": 100001,
    "status": "generating"
  }
}
```

```http
GET /admin-api/ai/report/status/{reportId}
功能: 查询报告生成状态
响应:
{
  "code": 0,
  "data": {
    "reportId": 100001,
    "status": "success",
    "progress": 100,
    "pdfUrl": "https://oss.example.com/reports/100001.pdf"
  }
}
```

```http
GET /admin-api/ai/report/download/{reportId}
功能: 下载报告PDF
响应: PDF文件流
```

#### 1.3.4 业务逻辑 - PDF生成流程

**技术方案: iText 7**

**生成步骤**:
1. 加载HTML模板
2. 填充数据(使用Thymeleaf模板引擎)
3. 生成图表(使用ECharts或JFreeChart)
4. HTML转PDF(iText 7的pdfHTML插件)
5. 添加页眉页脚、水印
6. 上传到OSS存储
7. 更新数据库记录

**图表生成示例 - 标准普尔象限饼图**:
- 使用ECharts生成图表
- 通过PhantomJS或Puppeteer渲染为图片
- 插入到PDF文档中

**技术实现要点**:
- 使用异步任务处理,避免阻塞
- 使用消息队列(RabbitMQ)解耦生成任务
- 支持PDF生成失败重试机制
- 生成的PDF文件上传OSS后删除本地文件
- 添加PDF文件访问权限控制

---

### 1.4 产品推荐引擎

#### 1.4.1 功能概述

**业务目标**:
- 基于缺口分析结果推荐合适的保险产品
- 使用协同过滤和规则引擎结合
- 提供推荐理由和个性化说明

**推荐算法**:
1. 基于规则的推荐(年龄/健康状况/预算匹配)
2. 协同过滤推荐(相似用户购买的产品)
3. 内容推荐(产品特征匹配)
4. 混合推荐(综合评分)

#### 1.4.2 数据库设计

```sql
CREATE TABLE `ai_product_recommendation` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `gap_result_id` BIGINT NOT NULL COMMENT '缺口分析结果ID',
  `recommend_time` DATETIME NOT NULL COMMENT '推荐时间',
  `recommend_count` INT NOT NULL DEFAULT 0 COMMENT '推荐产品数',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_gap_result_id` (`gap_result_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI产品推荐记录表';
```

```sql
CREATE TABLE `ai_recommendation_detail` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `recommendation_id` BIGINT NOT NULL COMMENT '推荐记录ID',
  `product_id` BIGINT NOT NULL COMMENT '产品ID',
  `rank` INT NOT NULL COMMENT '推荐排名',
  `total_score` DECIMAL(5,2) NOT NULL COMMENT '综合得分',
  `rule_score` DECIMAL(5,2) COMMENT '规则匹配得分',
  `cf_score` DECIMAL(5,2) COMMENT '协同过滤得分',
  `price_score` DECIMAL(5,2) COMMENT '性价比得分',
  `company_score` DECIMAL(5,2) COMMENT '公司权重得分',
  `recommend_reason` VARCHAR(1000) COMMENT '推荐理由',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_recommendation_id` (`recommendation_id`),
  KEY `idx_product_id` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI推荐产品明细表';
```

#### 1.4.3 接口设计

```http
POST /admin-api/ai/recommend/products
功能: 获取产品推荐
请求:
{
  "gapResultId": 67890,
  "budget": 10000,
  "limit": 10
}
响应:
{
  "code": 0,
  "data": {
    "recommendationId": 50001,
    "products": [
      {
        "productId": 1001,
        "productName": "XX终身寿险",
        "insuranceCompany": "XX人寿",
        "totalScore": 95.5,
        "recommendReason": "根据您的年收入和家庭责任,建议配置500万保额的终身寿险",
        "estimatedPremium": 8500
      }
    ]
  }
}
```

#### 1.4.4 业务逻辑 - 综合评分模型

```
综合得分 = 规则匹配度(40%) + 协同过滤得分(30%) + 性价比得分(20%) + 公司权重(10%)
```

**规则匹配度(0-100分)**:
- 年龄匹配(投保年龄范围): 20分
- 保额覆盖缺口: 30分
- 保费在预算内: 30分
- 健康告知匹配: 20分

**协同过滤得分(0-100分)**:
- 基于用户的协同过滤: 50分
- 基于物品的协同过滤: 50分

**技术实现要点**:
- 协同过滤使用Apache Mahout库
- 定时任务计算产品相似度矩阵
- 推荐结果缓存到Redis,有效期24小时
- 记录用户对推荐产品的交互(浏览/收藏/购买)用于优化算法

---

### 1.5 方案对比

#### 1.5.1 功能概述

**业务目标**:
- 支持1个目标产品与最多3个产品对比
- 多维度对比(保障/价格/服务/理赔)
- 高亮差异点,辅助决策

**对比维度**:
- 基础信息(产品名称/公司/类型)
- 保障内容(保额/保障范围/特色保障)
- 费用(年缴保费/总保费/性价比)
- 理赔服务(等待期/理赔时效/理赔率)
- 增值服务

#### 1.5.2 数据库设计

```sql
CREATE TABLE `ai_plan_comparison` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `recommendation_id` BIGINT COMMENT '推荐记录ID',
  `target_product_id` BIGINT NOT NULL COMMENT '目标产品ID',
  `compare_time` DATETIME NOT NULL COMMENT '对比时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI方案对比记录表';
```

```sql
CREATE TABLE `ai_comparison_product` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `comparison_id` BIGINT NOT NULL COMMENT '对比记录ID',
  `product_id` BIGINT NOT NULL COMMENT '产品ID',
  `rank` INT NOT NULL COMMENT '排序',
  `total_score` DECIMAL(5,2) COMMENT '总评分',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_comparison_id` (`comparison_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI对比产品表';
```

#### 1.5.3 接口设计

```http
POST /admin-api/ai/comparison/create
功能: 创建产品对比
请求:
{
  "targetProductId": 1001,
  "compareProductIds": [1002, 1003, 1004]
}
响应:
{
  "code": 0,
  "data": {
    "comparisonId": 3001
  }
}
```

```http
GET /admin-api/ai/comparison/result/{comparisonId}
功能: 获取对比结果
响应:
{
  "code": 0,
  "data": {
    "comparisonId": 3001,
    "comparisonMatrix": {
      "headers": ["产品名称", "年缴保费", "保额", "保障期限", "..."],
      "rows": [
        {
          "productId": 1001,
          "productName": "XX终身寿险",
          "annualPremium": {"value": 8500, "highlight": false},
          "coverage": {"value": "500万", "highlight": true},
          "...": "..."
        }
      ]
    }
  }
}
```

---

### 1.6 规划方案分享

#### 1.6.1 功能概述

**业务目标**:
- 将保障规划生成H5分享页面
- 支持链接/二维码分享
- 设置访问权限和有效期
- 记录访问行为

#### 1.6.2 数据库设计

```sql
CREATE TABLE `ai_plan_share` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `report_id` BIGINT NOT NULL COMMENT '报告ID',
  `recommendation_id` BIGINT COMMENT '推荐记录ID',
  `share_code` VARCHAR(32) NOT NULL COMMENT '分享码',
  `share_url` VARCHAR(500) COMMENT '分享链接',
  `qrcode_url` VARCHAR(500) COMMENT '二维码URL',
  `share_type` VARCHAR(20) NOT NULL COMMENT '分享类型:public-公开 password-密码 restricted-限制',
  `access_password` VARCHAR(100) COMMENT '访问密码',
  `allowed_phones` JSON COMMENT '允许访问的手机号列表',
  `expire_time` DATETIME COMMENT '过期时间',
  `max_view_count` INT COMMENT '最大查看次数',
  `current_view_count` INT NOT NULL DEFAULT 0 COMMENT '当前查看次数',
  `data_mask` JSON COMMENT '数据脱敏配置',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态:0-已撤销 1-生效中 2-已过期',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_share_code` (`share_code`, `deleted`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_report_id` (`report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI方案分享表';
```

```sql
CREATE TABLE `ai_share_access_log` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `share_id` BIGINT NOT NULL COMMENT '分享ID',
  `access_time` DATETIME NOT NULL COMMENT '访问时间',
  `access_phone` VARCHAR(11) COMMENT '访问手机号',
  `access_ip` VARCHAR(50) COMMENT '访问IP',
  `access_device` VARCHAR(200) COMMENT '访问设备',
  `page_views` INT NOT NULL DEFAULT 1 COMMENT '页面浏览数',
  `duration` INT COMMENT '停留时长(秒)',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_share_id` (`share_id`),
  KEY `idx_access_time` (`access_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI分享访问日志表';
```

#### 1.6.3 接口设计

```http
POST /admin-api/ai/share/create
功能: 创建分享
请求:
{
  "reportId": 100001,
  "shareType": "password",
  "expireDays": 7,
  "maxViewCount": 50
}
响应:
{
  "code": 0,
  "data": {
    "shareId": 20001,
    "shareUrl": "https://m.example.com/share/ABC123XYZ",
    "qrcodeUrl": "https://oss.example.com/qrcodes/ABC123XYZ.png",
    "shareCode": "ABC123XYZ",
    "accessPassword": "8888"
  }
}
```

---

## 2. 智能核保

### 2.1 疾病库维护

#### 2.1.1 功能概述

**业务目标**:
- 维护核保所需的疾病知识库
- 支持ICD-10国际疾病分类标准
- 提供全文检索和模糊匹配

**核心功能**:
- 疾病信息管理(增删改查)
- 疾病别名管理
- ICD-10编码管理
- 疾病关联关系管理
- Elasticsearch全文检索

#### 2.1.2 数据库设计

```sql
CREATE TABLE `ai_disease_info` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `disease_code` VARCHAR(32) NOT NULL COMMENT '疾病编码(内部)',
  `disease_name_cn` VARCHAR(200) NOT NULL COMMENT '疾病名称(中文)',
  `disease_name_en` VARCHAR(200) COMMENT '疾病名称(英文)',
  `disease_category` VARCHAR(50) COMMENT '疾病分类',
  `icd10_codes` JSON COMMENT 'ICD-10编码数组',
  `description` TEXT COMMENT '疾病描述',
  `symptoms` JSON COMMENT '常见症状数组',
  `severity_level` TINYINT(1) COMMENT '严重程度:1-5',
  `underwriting_grade` VARCHAR(20) COMMENT '核保等级:standard-标准体 extra-加费 postpone-延期 decline-拒保',
  `default_premium_rate` DECIMAL(5,2) COMMENT '默认加费比例(%)',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_disease_code` (`disease_code`, `deleted`),
  KEY `idx_category` (`disease_category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI疾病信息表';
```

```sql
CREATE TABLE `ai_disease_alias` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `disease_id` BIGINT NOT NULL COMMENT '疾病ID',
  `alias_name` VARCHAR(200) NOT NULL COMMENT '别名',
  `alias_type` VARCHAR(20) COMMENT '别名类型:common-俗称 medical-医学 local-地方',
  `pinyin` VARCHAR(500) COMMENT '拼音',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_disease_id` (`disease_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI疾病别名表';
```

#### 2.1.3 Elasticsearch索引设计

**索引名称**: disease_index

**Mapping定义重点**:
- 使用ik_max_word分词器支持中文全文检索
- 使用pinyin分析器支持拼音搜索
- 疾病名称、别名、症状都需要建立索引
- 支持模糊匹配和高亮显示

**技术实现要点**:
- 使用Spring Data Elasticsearch集成
- 数据库数据变更时同步更新ES索引
- 提供全量和增量同步接口
- 监控ES集群健康状态

---

### 2.2 核保规则配置

#### 2.2.1 功能概述

**业务目标**:
- 配置基于决策树的核保规则
- 支持复杂的条件判断和组合
- 使用Drools规则引擎执行

**决策树结构**:
```
根节点(产品)
  ├─ 判断节点(疾病类型)
  │   ├─ 判断节点(病情严重程度)
  │   │   ├─ 结论节点(标准承保)
  │   │   └─ 结论节点(加费20%)
  │   └─ 结论节点(拒保)
  └─ 判断节点(年龄)
      ├─ 结论节点(标准承保)
      └─ 结论节点(延期)
```

#### 2.2.2 数据库设计

```sql
CREATE TABLE `ai_underwriting_rule_tree` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `product_id` BIGINT NOT NULL COMMENT '产品ID',
  `insurance_type` VARCHAR(50) COMMENT '险种类型',
  `tree_name` VARCHAR(100) NOT NULL COMMENT '规则树名称',
  `version` VARCHAR(20) NOT NULL DEFAULT '1.0' COMMENT '版本号',
  `drl_content` LONGTEXT COMMENT 'Drools规则内容',
  `tree_json` JSON COMMENT '决策树JSON',
  `status` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '状态:0-草稿 1-测试中 2-已发布',
  `publish_time` DATETIME COMMENT '发布时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_product_id` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI核保规则树表';
```

#### 2.2.3 业务逻辑 - Drools规则引擎

**技术方案**:
- 使用Drools规则引擎
- 规则文件采用DRL格式
- 支持规则热加载
- 规则测试框架

**技术实现要点**:
- 规则文件存储在数据库或文件系统
- 使用KieContainer加载规则
- 规则变更后需要重新加载
- 记录规则执行日志用于审计

---

### 2.3 智能问答

#### 2.3.1 功能概述

**业务目标**:
- 根据疾病信息智能提出问题
- 逐步收集健康告知信息
- 遍历决策树得出核保结论

**问答流程**:
```
客户输入疾病
    ↓
系统匹配疾病库
    ↓
加载核保规则树
    ↓
生成问题列表
    ↓
客户回答问题 ← → 根据答案调整问题
    ↓
收集完整信息
    ↓
得出核保结论
```

#### 2.3.2 数据库设计

```sql
CREATE TABLE `ai_underwriting_qa_session` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `apply_id` BIGINT COMMENT '投保申请ID',
  `disease_id` BIGINT NOT NULL COMMENT '疾病ID',
  `tree_id` BIGINT NOT NULL COMMENT '规则树ID',
  `session_status` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '状态:0-进行中 1-已完成 2-已放弃',
  `current_node_code` VARCHAR(50) COMMENT '当前节点编码',
  `total_questions` INT NOT NULL DEFAULT 0 COMMENT '总问题数',
  `answered_count` INT NOT NULL DEFAULT 0 COMMENT '已回答数',
  `start_time` DATETIME COMMENT '开始时间',
  `complete_time` DATETIME COMMENT '完成时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_disease_id` (`disease_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI智能问答会话表';
```

```sql
CREATE TABLE `ai_underwriting_qa_record` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `session_id` BIGINT NOT NULL COMMENT '会话ID',
  `question_seq` INT NOT NULL COMMENT '问题序号',
  `node_code` VARCHAR(50) NOT NULL COMMENT '节点编码',
  `question_text` VARCHAR(1000) NOT NULL COMMENT '问题文本',
  `question_type` VARCHAR(20) NOT NULL COMMENT '问题类型',
  `options` JSON COMMENT '选项',
  `answer_value` VARCHAR(500) COMMENT '答案值',
  `answer_text` VARCHAR(1000) COMMENT '答案文本',
  `answer_time` DATETIME COMMENT '回答时间',
  `is_modified` BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否修改过',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_session_id` (`session_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI问答记录表';
```

---

### 2.4 核保结论

#### 2.4.1 功能概述

**业务目标**:
- 根据问答信息得出核保结论
- 计算加费金额或比例
- 确定除外责任
- 生成核保报告

**核保等级**:
- 标准体: 无加费,正常承保
- 加费体: 需要额外支付保费
- 除外承保: 特定疾病/部位不保
- 延期承保: 延迟一段时间后再核保
- 拒绝承保: 无法承保
- 人工核保: 转人工审核

#### 2.4.2 数据库设计

```sql
CREATE TABLE `ai_underwriting_conclusion` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `apply_id` BIGINT NOT NULL COMMENT '投保申请ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `product_id` BIGINT NOT NULL COMMENT '产品ID',
  `qa_session_id` BIGINT COMMENT '问答会话ID',
  `conclusion_code` VARCHAR(50) NOT NULL COMMENT '结论编码',
  `underwriting_grade` VARCHAR(20) NOT NULL COMMENT '核保等级:STANDARD/EXTRA/EXCLUSION/POSTPONE/DECLINE/MANUAL',
  `is_approved` BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否承保',
  `approval_amount` DECIMAL(15,2) COMMENT '承保保额',
  `standard_premium` DECIMAL(15,2) COMMENT '标准保费',
  `extra_premium` DECIMAL(15,2) COMMENT '加费金额',
  `extra_rate` DECIMAL(5,2) COMMENT '加费比例(%)',
  `final_premium` DECIMAL(15,2) COMMENT '最终保费',
  `exclusion_list` JSON COMMENT '除外责任列表',
  `postpone_days` INT COMMENT '延期天数',
  `postpone_reason` VARCHAR(500) COMMENT '延期原因',
  `decline_reason` VARCHAR(500) COMMENT '拒保原因',
  `conclusion_summary` VARCHAR(1000) COMMENT '结论摘要',
  `conclusion_detail` TEXT COMMENT '结论详情',
  `underwriter` VARCHAR(100) COMMENT '核保员',
  `conclusion_time` DATETIME NOT NULL COMMENT '结论时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_apply_id` (`apply_id`, `deleted`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_underwriting_grade` (`underwriting_grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI核保结论表';
```

---

### 2.5 人工核保

#### 2.5.1 功能概述

**业务目标**:
- 智能核保无法处理的案件转人工
- 支持完整的工作流程
- 核保员在线审核材料
- 做出最终核保结论

**工作流节点**:
1. 创建工单
2. 分配核保员
3. 初审
4. 要求补充资料(可选)
5. 复审
6. 做出结论
7. 审批(重大案件)
8. 归档

#### 2.5.2 数据库设计

```sql
CREATE TABLE `ai_manual_underwriting_case` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `case_no` VARCHAR(50) NOT NULL COMMENT '工单编号',
  `apply_id` BIGINT NOT NULL COMMENT '投保申请ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `product_id` BIGINT NOT NULL COMMENT '产品ID',
  `insured_amount` DECIMAL(15,2) NOT NULL COMMENT '投保金额',
  `qa_session_id` BIGINT COMMENT '智能问答会话ID',
  `auto_conclusion_id` BIGINT COMMENT '智能核保结论ID',
  `refer_reason` VARCHAR(500) NOT NULL COMMENT '转人工原因',
  `urgency_level` VARCHAR(20) NOT NULL DEFAULT 'normal' COMMENT '紧急程度:normal/urgent/critical',
  `case_status` VARCHAR(20) NOT NULL DEFAULT 'waiting' COMMENT '工单状态:waiting/serving/completed/closed',
  `assignee_id` BIGINT COMMENT '当前处理人ID',
  `approver_id` BIGINT COMMENT '审批人ID',
  `assign_time` DATETIME COMMENT '分配时间',
  `deadline_time` DATETIME COMMENT '处理期限',
  `complete_time` DATETIME COMMENT '完成时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_case_no` (`case_no`, `deleted`),
  KEY `idx_apply_id` (`apply_id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_assignee_id` (`assignee_id`),
  KEY `idx_case_status` (`case_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI人工核保工单表';
```

**技术实现要点**:
- 工作流引擎可使用Activiti或Flowable
- 支持工单超时预警和升级
- 记录完整的流转日志
- 支持补充资料上传和OCR识别

---

## 3. 智能客服

### 3.1 知识库配置

#### 3.1.1 功能概述

**业务目标**:
- 维护FAQ知识库
- 支持问题分类和相似问题
- 提供全文检索

**知识分类体系**:
```
保险知识
├── 产品咨询
│   ├── 寿险
│   ├── 重疾险
│   └── 医疗险
├── 投保流程
├── 保单服务
└── 常见问题
```

#### 3.1.2 数据库设计

```sql
CREATE TABLE `ai_knowledge_category` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `parent_id` BIGINT NOT NULL DEFAULT 0 COMMENT '父分类ID',
  `category_name` VARCHAR(100) NOT NULL COMMENT '分类名称',
  `category_path` VARCHAR(500) COMMENT '分类路径',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `icon` VARCHAR(500) COMMENT '图标',
  `description` VARCHAR(500) COMMENT '描述',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI知识分类表';
```

```sql
CREATE TABLE `ai_knowledge_base` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `knowledge_code` VARCHAR(50) NOT NULL COMMENT '知识编码',
  `category_id` BIGINT NOT NULL COMMENT '分类ID',
  `standard_question` VARCHAR(500) NOT NULL COMMENT '标准问题',
  `answer` TEXT NOT NULL COMMENT '标准答案',
  `answer_html` LONGTEXT COMMENT '答案HTML',
  `keywords` JSON COMMENT '关键词数组',
  `apply_scope` VARCHAR(20) NOT NULL DEFAULT 'all' COMMENT '适用范围:all/product/scene',
  `product_ids` JSON COMMENT '产品ID列表',
  `scene_codes` JSON COMMENT '场景编码列表',
  `status` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '状态:0-草稿 1-审核中 2-已发布 3-已下线',
  `creator_id` BIGINT COMMENT '创建人ID',
  `reviewer_id` BIGINT COMMENT '审核人ID',
  `publish_time` DATETIME COMMENT '发布时间',
  `expire_time` DATETIME COMMENT '失效时间',
  `click_count` INT NOT NULL DEFAULT 0 COMMENT '点击次数',
  `like_count` INT NOT NULL DEFAULT 0 COMMENT '点赞次数',
  `dislike_count` INT NOT NULL DEFAULT 0 COMMENT '踩次数',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_knowledge_code` (`knowledge_code`, `deleted`),
  KEY `idx_category_id` (`category_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI知识库表';
```

```sql
CREATE TABLE `ai_knowledge_similar_question` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `knowledge_id` BIGINT NOT NULL COMMENT '知识ID',
  `similar_question` VARCHAR(500) NOT NULL COMMENT '相似问题',
  `similarity_score` DECIMAL(3,2) COMMENT '相似度得分',
  `source` VARCHAR(20) NOT NULL DEFAULT 'manual' COMMENT '来源:manual-手动 learned-学习',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_knowledge_id` (`knowledge_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI知识相似问题表';
```

**技术实现要点**:
- 使用Elasticsearch实现全文检索
- 支持拼音搜索和模糊匹配
- 未匹配问题自动收集用于优化知识库
- 知识点击和评价数据用于优化排序

---

### 3.2 意图识别

#### 3.2.1 功能概述

**业务目标**:
- 使用NLP技术识别用户意图
- 分类到预定义的意图类别
- 提取关键实体信息

**意图分类**:
- 产品咨询
- 投保相关
- 保单服务
- 理赔相关
- 寒暄闲聊
- 投诉建议

#### 3.2.2 技术方案

**选择: 阿里云NLP服务**
- 预训练模型,准确率高
- 支持自定义意图
- 支持实体识别
- API调用简单

**集成方式**:
- 开通阿里云NLP服务
- 配置API密钥
- 封装调用接口
- 缓存识别结果
- 异常降级处理

**技术实现要点**:
- 文本预处理(去除无意义字符)
- 意图置信度阈值设置
- 多意图处理策略
- 记录识别日志用于优化

---

### 3.3 对话管理

#### 3.3.1 功能概述

**业务目标**:
- 管理多轮对话
- 维护对话上下文
- 实现槽位填充

**对话状态机**:
```
INIT (初始)
  ↓
INTENT_RECOGNIZED (意图已识别)
  ↓
SLOT_FILLING (槽位填充中)
  ↓
CONFIRM (等待确认)
  ↓
EXECUTING (执行中)
  ↓
COMPLETED (已完成)
```

#### 3.3.2 数据库设计

```sql
CREATE TABLE `ai_chatbot_session` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `session_id` VARCHAR(64) NOT NULL COMMENT '会话ID(UUID)',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `channel` VARCHAR(20) NOT NULL COMMENT '渠道:web/app/wechat',
  `session_status` VARCHAR(20) NOT NULL DEFAULT 'active' COMMENT '会话状态:active/ended/transferred',
  `current_intent` VARCHAR(100) COMMENT '当前意图',
  `context_data` JSON COMMENT '上下文数据',
  `start_time` DATETIME NOT NULL COMMENT '开始时间',
  `end_time` DATETIME COMMENT '结束时间',
  `message_count` INT NOT NULL DEFAULT 0 COMMENT '消息数量',
  `is_transferred` BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否转人工',
  `transfer_time` DATETIME COMMENT '转人工时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_session_id` (`session_id`, `deleted`),
  KEY `idx_customer_id` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI对话会话表';
```

```sql
CREATE TABLE `ai_chatbot_message` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `session_id` VARCHAR(64) NOT NULL COMMENT '会话ID',
  `message_type` VARCHAR(20) NOT NULL COMMENT '消息类型:user/bot/system',
  `message_content` TEXT NOT NULL COMMENT '消息内容',
  `message_time` DATETIME NOT NULL COMMENT '消息时间',
  `intent` VARCHAR(100) COMMENT '意图',
  `entities` JSON COMMENT '实体',
  `knowledge_id` BIGINT COMMENT '匹配知识ID',
  `confidence` DECIMAL(3,2) COMMENT '置信度',
  `is_satisfied` BIT(1) COMMENT '是否满意',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_session_id` (`session_id`),
  KEY `idx_message_time` (`message_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI对话消息表';
```

**技术实现要点**:
- 使用Redis存储会话上下文
- 上下文设置合理的过期时间
- 支持指代消解("它"、"这个")
- 实现省略补全

---

### 3.4 转人工

#### 3.4.1 功能概述

**业务目标**:
- 智能客服无法解决时转人工
- 无缝衔接对话上下文
- 支持排队机制
- 服务质量评价

**触发条件**:
- 意图识别置信度过低(连续3次<0.3)
- 用户明确要求人工
- 复杂问题无法解答
- 投诉类问题

#### 3.4.2 数据库设计

```sql
CREATE TABLE `ai_manual_service_case` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `case_no` VARCHAR(50) NOT NULL COMMENT '工单编号',
  `chatbot_session_id` VARCHAR(64) NOT NULL COMMENT '智能客服会话ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `transfer_reason` VARCHAR(500) COMMENT '转人工原因',
  `case_type` VARCHAR(20) NOT NULL COMMENT '工单类型:consult-咨询 claim-理赔 complaint-投诉',
  `priority` VARCHAR(20) NOT NULL DEFAULT 'medium' COMMENT '优先级:low/medium/high/urgent',
  `case_status` VARCHAR(20) NOT NULL DEFAULT 'waiting' COMMENT '工单状态:waiting/serving/completed/closed',
  `assign_agent_id` BIGINT COMMENT '分配客服ID',
  `queue_position` INT COMMENT '排队位置',
  `wait_time` INT COMMENT '等待时长(秒)',
  `serve_time` INT COMMENT '服务时长(秒)',
  `transfer_time` DATETIME NOT NULL COMMENT '转人工时间',
  `accept_time` DATETIME COMMENT '接入时间',
  `complete_time` DATETIME COMMENT '完成时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_case_no` (`case_no`, `deleted`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_assign_agent_id` (`assign_agent_id`),
  KEY `idx_case_status` (`case_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI人工客服工单表';
```

**技术方案: 腾讯云IM SDK**
- 实时消息推送
- 消息已读未读
- 历史消息查询
- 在线状态管理

---

## 4. 数据分析

### 4.1 用户画像

#### 4.1.1 功能概述

**业务目标**:
- 构建多维度用户标签
- 支持用户分群
- 为精准营销提供依据

**标签体系**:
- 基础属性(年龄/性别/收入)
- 行为特征(活跃度/兴趣偏好)
- 购买行为(投保产品/金额)
- 风险特征(健康状况/信用)
- 价值特征(客户价值/流失风险)

#### 4.1.2 数据库设计

```sql
CREATE TABLE `ai_user_portrait` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `portrait_data` JSON NOT NULL COMMENT '画像数据',
  `last_update_time` DATETIME NOT NULL COMMENT '最后更新时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_customer_id` (`customer_id`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI用户画像表';
```

```sql
CREATE TABLE `ai_user_tag` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `tag_category` VARCHAR(50) NOT NULL COMMENT '标签分类',
  `tag_name` VARCHAR(100) NOT NULL COMMENT '标签名称',
  `tag_value` VARCHAR(500) COMMENT '标签值',
  `tag_score` DECIMAL(5,2) COMMENT '标签得分',
  `valid_from` DATETIME NOT NULL COMMENT '生效时间',
  `valid_to` DATETIME COMMENT '失效时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_tag_category` (`tag_category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI用户标签表';
```

**技术实现要点**:
- 使用Spark或Flink进行批量计算
- 实时更新关键标签
- 标签数据可存储MongoDB或HBase
- 提供标签查询API

---

### 4.2 流失预警

#### 4.2.1 功能概述

**业务目标**:
- 预测用户流失概率
- 识别高流失风险用户
- 提前干预挽留

**流失定义**:
- 连续90天未登录
- 保单到期未续保
- 明确表示不再续保

#### 4.2.2 数据库设计

```sql
CREATE TABLE `ai_churn_prediction` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `prediction_date` DATE NOT NULL COMMENT '预测日期',
  `churn_probability` DECIMAL(5,4) NOT NULL COMMENT '流失概率',
  `risk_level` VARCHAR(20) NOT NULL COMMENT '风险等级:normal/low/medium/high',
  `feature_values` JSON COMMENT '特征值',
  `model_version` VARCHAR(50) COMMENT '模型版本',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_prediction_date` (`prediction_date`),
  KEY `idx_risk_level` (`risk_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI流失预测记录表';
```

**技术方案**:
- 使用XGBoost模型
- Python训练,Java调用
- 定期重训练模型
- 模型版本管理

---

### 4.3 精准营销

#### 4.3.1 功能概述

**业务目标**:
- 个性化产品推荐
- 营销内容个性化
- 多渠道触达(短信/推送/邮件)
- 效果跟踪

#### 4.3.2 数据库设计

```sql
CREATE TABLE `ai_marketing_campaign` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `campaign_code` VARCHAR(50) NOT NULL COMMENT '活动编码',
  `campaign_name` VARCHAR(200) NOT NULL COMMENT '活动名称',
  `campaign_type` VARCHAR(50) NOT NULL COMMENT '活动类型:product_recommend/promotion/renewal',
  `target_segment_id` BIGINT COMMENT '目标人群ID',
  `recommend_algorithm` VARCHAR(50) COMMENT '推荐算法',
  `touch_channels` JSON COMMENT '触达渠道数组',
  `start_time` DATETIME NOT NULL COMMENT '开始时间',
  `end_time` DATETIME NOT NULL COMMENT '结束时间',
  `status` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '状态:0-未开始 1-进行中 2-已结束',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_campaign_code` (`campaign_code`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI营销活动表';
```

---

### 4.4 RFM模型

#### 4.4.1 功能概述

**业务目标**:
- 分析客户价值
- 识别不同类型客户
- 制定差异化策略

**RFM指标**:
- R(Recency): 最近一次投保时间
- F(Frequency): 投保频次
- M(Monetary): 消费金额

**客户分层**:
- 重要价值客户(RFM: 555)
- 重要发展客户(RFM: 545)
- 重要保持客户(RFM: 355)
- 一般客户(RFM: 444)
- 低价值客户(RFM: 111)

#### 4.4.2 数据库设计

```sql
CREATE TABLE `ai_rfm_analysis_result` (
  `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `customer_id` BIGINT NOT NULL COMMENT '客户ID',
  `analysis_period_start` DATE NOT NULL COMMENT '分析周期开始',
  `analysis_period_end` DATE NOT NULL COMMENT '分析周期结束',
  `recency_value` INT NOT NULL COMMENT 'R值(天数)',
  `recency_score` TINYINT NOT NULL COMMENT 'R得分:1-5',
  `frequency_value` INT NOT NULL COMMENT 'F值(次数)',
  `frequency_score` TINYINT NOT NULL COMMENT 'F得分:1-5',
  `monetary_value` DECIMAL(15,2) NOT NULL COMMENT 'M值(金额)',
  `monetary_score` TINYINT NOT NULL COMMENT 'M得分:1-5',
  `rfm_score` DECIMAL(3,1) NOT NULL COMMENT 'RFM综合得分',
  `customer_type` VARCHAR(50) NOT NULL COMMENT '客户类型',
  `customer_level` VARCHAR(10) NOT NULL COMMENT '客户等级:S/A/B/C/D',
  `analysis_time` DATETIME NOT NULL COMMENT '分析时间',
  
  `creator` VARCHAR(64) DEFAULT '',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0',
  `tenant_id` BIGINT NOT NULL DEFAULT 0,
  
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_customer_type` (`customer_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI-RFM分析结果表';
```

---

## 5. 数据库设计规范

### 5.1 命名规范

**表命名**:
- 全部小写,单词间用下划线
- 统一前缀: ai_
- 表名体现业务含义

**字段命名**:
- 全部小写,单词间用下划线
- 布尔字段以is_开头
- 时间字段以_time结尾

**索引命名**:
- 主键索引: pk_{表名}
- 唯一索引: uk_{表名}_{字段}
- 普通索引: idx_{表名}_{字段}

### 5.2 公共字段

所有表必须包含ruoyi框架标准字段:
- creator: 创建者
- create_time: 创建时间
- updater: 更新者
- update_time: 更新时间
- deleted: 删除标识
- tenant_id: 租户ID

### 5.3 索引设计原则

- WHERE条件字段建索引
- JOIN关联字段建索引
- 区分度高的字段建索引
- 联合索引遵循最左前缀原则
- 避免在数据量小的表建过多索引

---

## 6. 接口设计规范

### 6.1 RESTful API规范

**URL设计**:
- 使用名词复数形式
- 使用小写字母
- 版本号放在路径中: /api/v1/

**HTTP方法**:
- GET: 查询
- POST: 创建
- PUT: 完整更新
- PATCH: 部分更新
- DELETE: 删除

### 6.2 统一响应格式

```json
{
  "code": 0,
  "msg": "success",
  "data": {},
  "timestamp": 1640000000000
}
```

**状态码**:
- 200: 成功
- 400: 参数错误
- 401: 未认证
- 403: 无权限
- 404: 资源不存在
- 500: 服务器错误

---

## 7. 技术实现要点

### 7.1 AI保障规划

- 跳题逻辑使用规则引擎或状态机
- 缺口计算使用BigDecimal精确计算
- PDF生成使用iText 7,异步处理
- 推荐引擎使用协同过滤+规则引擎

### 7.2 智能核保

- Elasticsearch实现疾病库检索
- Drools规则引擎执行核保规则
- 决策树遍历使用递归算法
- 人工核保使用工作流引擎

### 7.3 智能客服

- NLP使用阿里云服务
- 对话管理使用状态机
- 上下文存储Redis
- IM使用腾讯云SDK

### 7.4 数据分析

- 用户画像使用Spark批量计算
- 流失预测使用XGBoost模型
- 精准营销使用推荐算法
- RFM分析使用SQL计算

### 7.5 性能优化

- 数据库读写分离
- Redis缓存热点数据
- 异步任务使用消息队列
- 接口限流熔断

---

## 8. 开发工时评估

| 模块 | 前端(天) | 后端(天) | 总计(天) |
|------|----------|----------|----------|
| AI保障规划 | 7.0 | 9.0 | 16.0 |
| 智能核保 | 7.0 | 9.0 | 16.0 |
| 智能客服 | 5.5 | 7.5 | 13.0 |
| 数据分析 | 2.5 | 7.5 | 10.0 |
| **总计** | **22.0** | **33.0** | **55.0** |

---

## 附录

### A. 技术栈

**后端**:
- Spring Boot
- MyBatis Plus
- Drools
- Elasticsearch
- Redis
- RabbitMQ

**第三方服务**:
- 阿里云NLP
- 腾讯云IM
- OSS存储

**AI/算法**:
- XGBoost
- Mahout

### B. 术语表

- AI: 人工智能
- NLP: 自然语言处理
- RFM: Recency Frequency Monetary
- DRL: Drools规则语言
- ES: Elasticsearch
- IM: 即时通讯

---

**文档结束**

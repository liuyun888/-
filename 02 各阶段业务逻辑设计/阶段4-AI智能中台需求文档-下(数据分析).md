# 阶段4 · AI智能中台需求文档（下）— 数据分析

> 框架：yudao-cloud（ruoyi-vue-pro 微服务版）  
> 模块前缀：`ai_`  
> 接口前缀：`/admin-api/ai/`  
> 适用人员：前端开发、后端开发  
> 文档版本：v2.0

---

## 目录

1. [用户画像](#1-用户画像)
2. [流失预警](#2-流失预警)
3. [精准营销](#3-精准营销)
4. [RFM 客户价值分析](#4-rfm-客户价值分析)

---

## 1. 用户画像

### 1.1 业务说明

通过汇聚客户的基础属性、行为数据、投保记录等多维度信息，构建客户画像标签体系，供代理人查阅、精准营销和 RFM 分析使用。

标签计算采用定时任务（每日凌晨批量刷新），标签数据存入 `ai_user_tag`，概览快照存入 `ai_user_portrait`。

### 1.2 标签体系

| 标签分类 | 标签名称示例 | 计算规则 |
|----------|------------|---------|
| 基础属性 | 年龄段（25-30岁）、性别、所在城市 | 直接从客户基础信息表读取 |
| 财富等级 | 高净值/中等/普通 | 年收入：>100万=高净值，20-100万=中等，<20万=普通 |
| 保障状态 | 保障完善/保障不足/无保障 | 持有有效保单数量判断 |
| 保单续保 | 即将续保（30天内）/已到期 | 遍历到期时间 |
| 活跃度 | 高活跃/中活跃/低活跃/沉默 | 近30天登录天数：>15=高，5-15=中，1-5=低，0=沉默 |
| 产品偏好 | 偏好重疾险/偏好医疗险/偏好年金险 | 历史投保产品类型统计TOP1 |
| 流失风险 | 高流失风险/中等/低 | 来自流失预警模型（见第2节） |
| 客户价值 | S/A/B/C/D级 | 来自 RFM 分析（见第4节） |

### 1.3 PC 后台 — 客户画像查看

**入口一**：客户管理 → 客户详情页 → 画像 Tab

该 Tab 展示：
- 标签云：所有有效标签以彩色标签形式展示，点击可查看标签说明。
- 投保偏好分析：近2年各险种投保金额占比饼图。
- 活跃度趋势：近90天登录天数折线图。
- 保障完整性雷达图：意外/重疾/医疗/寿险/养老 5个维度的保障覆盖程度。

**入口二**：AI智能工具 → 数据分析 → 客户画像列表

列表字段：客户姓名、手机号、财富等级标签、保障状态标签、活跃度标签、流失风险标签、客户价值等级、最近活跃时间、操作（查看画像详情）。

支持按各维度标签筛选（多选），支持导出筛选结果（Excel）。

### 1.4 标签计算定时任务

定时任务说明（通过 yudao-cloud quartz 调度）：

| 任务 | 执行时间 | 逻辑 |
|------|----------|------|
| 基础标签刷新 | 每天 01:00 | 读取全量客户基础信息，写入/更新 `ai_user_tag` |
| 活跃度标签 | 每天 01:30 | 统计近30天登录日志，计算活跃天数，写标签 |
| 保单标签 | 每天 02:00 | 扫描保单表，生成续保预警、保障状态标签 |
| 画像快照刷新 | 每天 03:00 | 聚合各维度标签，更新 `ai_user_portrait` 的 portrait_data |

**portrait_data JSON 结构**：
```json
{
  "age": 32,
  "gender": "male",
  "city": "上海",
  "wealthLevel": "high",
  "protectionStatus": "partial",
  "activityLevel": "high",
  "churnRisk": "low",
  "customerLevel": "A",
  "productPreferences": ["重疾险", "年金险"],
  "policyCount": 3,
  "totalPremium": 35000,
  "lastActiveDate": "2025-02-14"
}
```

### 1.5 数据库设计

```sql
CREATE TABLE `ai_user_portrait` (
  `id`               BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`      BIGINT NOT NULL,
  `portrait_data`    JSON NOT NULL COMMENT '画像快照JSON',
  `last_update_time` DATETIME NOT NULL,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_customer_id` (`customer_id`, `tenant_id`, `deleted`)
) COMMENT='AI用户画像快照表';

CREATE TABLE `ai_user_tag` (
  `id`           BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`  BIGINT NOT NULL,
  `tag_category` VARCHAR(50) NOT NULL COMMENT '标签分类：base/wealth/protection/activity/preference/churn/value',
  `tag_name`     VARCHAR(100) NOT NULL COMMENT '标签名称',
  `tag_value`    VARCHAR(500) COMMENT '标签值（量化指标）',
  `tag_score`    DECIMAL(5,2) COMMENT '标签得分（部分标签有量化分值）',
  `valid_from`   DATETIME NOT NULL,
  `valid_to`     DATETIME COMMENT 'NULL表示永久有效，或以下次刷新覆盖',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_tag_category` (`tag_category`)
) COMMENT='AI用户标签表';
```

### 1.6 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 客户画像详情 | GET | `/admin-api/ai/portrait/customer/{customerId}` |
| 客户画像列表（带标签筛选） | GET | `/admin-api/ai/portrait/page` |
| 客户标签列表 | GET | `/admin-api/ai/portrait/tags/{customerId}` |
| 手动刷新单客户画像 | POST | `/admin-api/ai/portrait/refresh/{customerId}` |
| 画像数据导出 | GET | `/admin-api/ai/portrait/export` |

---

## 2. 流失预警

### 2.1 业务说明

每日通过机器学习模型（XGBoost）对客户进行流失概率预测，识别高流失风险客户，支持代理人查看风险名单并采取干预措施（触达记录）。

### 2.2 流失定义与特征

**流失定义**（满足任一）：
- 连续90天无登录记录
- 持有保单到期后30天内未续保
- 明确告知不续保/退保

**模型特征变量（共14个）**：

| 特征 | 说明 |
|------|------|
| days_since_login | 距最后登录天数 |
| login_count_30d | 近30天登录次数 |
| days_since_last_purchase | 距最后投保天数 |
| policy_count | 持有有效保单数 |
| renewal_rate | 历史续保率 |
| total_premium | 累计保费 |
| age | 年龄 |
| policy_expiring_30d | 30天内到期保单数 |
| complaint_count | 历史投诉次数 |
| agent_interaction_count_90d | 近90天与代理人互动次数 |
| app_open_count_30d | 近30天App打开次数 |
| claim_count | 历史理赔次数 |
| city_tier | 城市等级（1/2/3线） |
| wealth_level | 财富等级（数值化） |

**风险等级划分**：

| 流失概率 | 风险等级 | 建议行动 |
|---------|---------|---------|
| ≥ 0.7 | 高风险 | 立即触达，代理人主动致电/发优惠 |
| 0.4 - 0.7 | 中风险 | 7日内触达，发送关怀消息 |
| 0.2 - 0.4 | 低风险 | 30日内关注 |
| < 0.2 | 正常 | 常规维护 |

### 2.3 PC 后台 — 流失预警管理

路径：**AI智能工具 → 数据分析 → 流失预警**

**看板区（顶部）**：
- 今日高风险客户数（红色卡片）
- 今日中风险客户数（橙色卡片）
- 近7日预警客户总数
- 干预成功率（触达后30天内有互动/续保的比例）

**预警名单列表**：

列表字段：客户姓名、负责代理人、流失概率（%显示）、风险等级（色标）、主要流失因素（取top3特征）、最近登录时间、距到期最近保单（天数）、干预状态（未触达/已触达/已转化）、操作（查看客户 / 记录干预）。

支持按风险等级、代理人、干预状态筛选；按流失概率倒序排列。

**记录干预弹框字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 触达方式 | 下拉 | ✅ | 电话/短信/微信/面访 |
| 触达时间 | 日期时间 | ✅ | 默认当前时间 |
| 触达内容 | 文本 | ✅ | 简要说明沟通情况 |
| 客户意向 | 单选 | ✅ | 有意向续保/暂时观望/明确拒绝 |

点击【保存】后：插入 `ai_churn_intervention` 记录，更新该预警记录的干预状态为"已触达"。

### 2.4 模型更新机制

- 模型由算法团队用 Python+XGBoost 训练，导出为 PMML 格式，上传到系统。
- 后端 Java 使用 jpmml-evaluator 加载 PMML 模型文件执行预测。
- 每天凌晨定时任务（02:30）：从数据库提取所有活跃客户的特征数据 → 调用 PMML 模型 → 写入 `ai_churn_prediction` → 更新用户流失风险标签。
- PC 后台提供模型版本管理页面，可上传新版 PMML 文件，点击【激活】后下次定时任务使用新版本。

### 2.5 数据库设计

```sql
CREATE TABLE `ai_churn_prediction` (
  `id`                BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`       BIGINT NOT NULL,
  `prediction_date`   DATE NOT NULL COMMENT '预测日期',
  `churn_probability` DECIMAL(5,4) NOT NULL COMMENT '流失概率 0.0000-1.0000',
  `risk_level`        VARCHAR(20) NOT NULL COMMENT 'normal/low/medium/high',
  `feature_values`    JSON COMMENT '特征值快照，用于模型解释',
  `top_factors`       JSON COMMENT '主要风险因素，如["days_since_login","policy_expiring_30d"]',
  `model_version`     VARCHAR(50) COMMENT '使用的模型版本',
  `intervention_status` VARCHAR(20) NOT NULL DEFAULT 'none' COMMENT 'none/contacted/converted',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_prediction_date_risk` (`prediction_date`, `risk_level`)
) COMMENT='AI流失预测记录表';

CREATE TABLE `ai_churn_intervention` (
  `id`               BIGINT NOT NULL AUTO_INCREMENT,
  `prediction_id`    BIGINT NOT NULL,
  `customer_id`      BIGINT NOT NULL,
  `agent_id`         BIGINT NOT NULL COMMENT '记录干预的代理人',
  `contact_method`   VARCHAR(20) NOT NULL COMMENT 'call/sms/wechat/visit',
  `contact_time`     DATETIME NOT NULL,
  `contact_content`  VARCHAR(1000),
  `customer_intention` VARCHAR(20) COMMENT 'interested/watching/rejected',
  `is_converted`     BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否最终转化（续保/新购）',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_prediction_id` (`prediction_id`),
  KEY `idx_customer_id` (`customer_id`)
) COMMENT='AI流失干预记录表';

CREATE TABLE `ai_churn_model_version` (
  `id`           BIGINT NOT NULL AUTO_INCREMENT,
  `version_code` VARCHAR(50) NOT NULL,
  `model_file_url` VARCHAR(500) NOT NULL COMMENT 'PMML文件OSS地址',
  `file_size`    BIGINT,
  `description`  VARCHAR(500),
  `status`       TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0待激活 1已激活 2已归档',
  `activate_time` DATETIME,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_version_code` (`version_code`, `tenant_id`, `deleted`)
) COMMENT='AI流失预测模型版本表';
```

### 2.6 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 流失预警列表 | GET | `/admin-api/ai/churn/page` |
| 流失看板统计 | GET | `/admin-api/ai/churn/dashboard` |
| 记录干预 | POST | `/admin-api/ai/churn/intervention` |
| 模型版本列表 | GET | `/admin-api/ai/churn/model/list` |
| 上传新模型 | POST | `/admin-api/ai/churn/model/upload` |
| 激活模型版本 | PUT | `/admin-api/ai/churn/model/{id}/activate` |

---

## 3. 精准营销

### 3.1 业务说明

基于用户画像和 RFM 分析结果，运营人员创建营销活动，圈定目标客群，通过短信/推送/站内消息等渠道进行个性化触达，并跟踪营销效果。

### 3.2 PC 后台 — 营销活动管理

路径：**AI智能工具 → 数据分析 → 精准营销**

#### 3.2.1 营销活动列表

列表字段：活动编码、活动名称、活动类型、目标人数、已触达人数、触达率、转化率（成单/触达）、开始时间、结束时间、状态（未开始/进行中/已结束）、操作（查看/暂停/复制）。

#### 3.2.2 新建营销活动（分步表单，共3步）

**Step 1：基本信息**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 活动名称 | 文本 | ✅ | 最长200字 |
| 活动类型 | 下拉 | ✅ | 产品推荐/促销活动/续保提醒/新客欢迎 |
| 开始时间 | 日期时间 | ✅ | 不能早于当前时间 |
| 结束时间 | 日期时间 | ✅ | 必须晚于开始时间 |
| 触达渠道 | 多选 | ✅ | 短信/APP推送/站内消息（至少选1个） |
| 消息模板 | 文本域 | ✅ | 支持变量占位符，如 `{客户姓名}` `{产品名称}` `{到期日}` |

**Step 2：目标人群圈定**

选择方式：
- **标签筛选**：从用户画像标签中选择组合条件（AND逻辑），实时预估人数（调后端接口）。
- **上传名单**：上传包含客户ID的 Excel 文件（提供下载模板）。
- **已有人群包**：选择之前保存的人群包。

**标签筛选条件示例**：
- 流失风险 = 高风险 AND 客户价值等级 IN [A, B] AND 年龄 BETWEEN 30 AND 45

点击【预估人数】按钮，后端执行 SQL 查询预估结果，返回 `目标人数: 1,234 人`，同时生成 `ai_marketing_segment` 记录。

**Step 3：推荐产品（可选）**

若活动类型为"产品推荐"，则需配置推荐产品列表（从产品库多选，最多5个）和推荐算法（规则引擎/协同过滤/混合）。

点击【保存并激活】，活动 status=1（进行中），系统在活动开始时间到达后自动执行触达任务。

#### 3.2.3 触达任务执行逻辑

活动开始时间到达时，定时任务触发：
1. 查询活动对应的目标人群列表（`ai_marketing_audience`）。
2. 对每个目标客户，按配置的渠道逐一触达：
   - **短信**：调阿里云短信服务 API，使用活动配置的消息模板（替换变量），记录到 `ai_marketing_send_log`。
   - **APP 推送**：调极光推送/个推 API，发送个性化推送通知。
   - **站内消息**：写入系统消息表。
3. 触达结果实时更新 `ai_marketing_send_log`（发送状态/失败原因）。
4. 触达完成后，汇总更新活动的 `sent_count`。

#### 3.2.4 营销效果跟踪

- **点击率**：用户点击推送/短信跳转链接时，在链接中带活动编码参数，后端记录到 `ai_marketing_click_log`。
- **转化率**：投保成功后，检查投保申请的来源字段中是否有营销活动标记，统计转化数写入活动记录。
- 活动详情页展示效果数据看板：触达人数、到达率（短信送达数/发送数）、点击率、转化数、产生保费总额。

### 3.3 数据库设计

```sql
CREATE TABLE `ai_marketing_campaign` (
  `id`                 BIGINT NOT NULL AUTO_INCREMENT,
  `campaign_code`      VARCHAR(50) NOT NULL,
  `campaign_name`      VARCHAR(200) NOT NULL,
  `campaign_type`      VARCHAR(50) NOT NULL COMMENT 'product_recommend/promotion/renewal/welcome',
  `touch_channels`     JSON COMMENT '["sms","push","in_app"]',
  `message_template`   TEXT COMMENT '消息模板，含变量占位符',
  `start_time`         DATETIME NOT NULL,
  `end_time`           DATETIME NOT NULL,
  `status`             TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0未开始 1进行中 2已暂停 3已结束',
  `target_count`       INT NOT NULL DEFAULT 0 COMMENT '目标人数',
  `sent_count`         INT NOT NULL DEFAULT 0 COMMENT '已触达人数',
  `click_count`        INT NOT NULL DEFAULT 0,
  `convert_count`      INT NOT NULL DEFAULT 0 COMMENT '转化成单人数',
  `convert_premium`    DECIMAL(15,2) COMMENT '转化保费总额',
  `recommend_products` JSON COMMENT '推荐产品ID列表',
  `recommend_algorithm` VARCHAR(50) COMMENT 'rule/cf/hybrid',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_campaign_code` (`campaign_code`, `tenant_id`, `deleted`)
) COMMENT='AI营销活动表';

CREATE TABLE `ai_marketing_segment` (
  `id`              BIGINT NOT NULL AUTO_INCREMENT,
  `segment_name`    VARCHAR(200) NOT NULL COMMENT '人群包名称',
  `segment_type`    VARCHAR(20) NOT NULL COMMENT 'tag_filter/upload/manual',
  `filter_condition` JSON COMMENT '标签筛选条件',
  `customer_count`  INT NOT NULL DEFAULT 0,
  `status`          TINYINT(1) NOT NULL DEFAULT 1,
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) COMMENT='AI营销人群包表';

CREATE TABLE `ai_marketing_audience` (
  `id`           BIGINT NOT NULL AUTO_INCREMENT,
  `campaign_id`  BIGINT NOT NULL,
  `customer_id`  BIGINT NOT NULL,
  `segment_id`   BIGINT,
  `is_sent`      BIT(1) NOT NULL DEFAULT b'0',
  `is_clicked`   BIT(1) NOT NULL DEFAULT b'0',
  `is_converted` BIT(1) NOT NULL DEFAULT b'0',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_campaign_id` (`campaign_id`),
  KEY `idx_customer_id` (`customer_id`)
) COMMENT='AI营销目标受众表';

CREATE TABLE `ai_marketing_send_log` (
  `id`           BIGINT NOT NULL AUTO_INCREMENT,
  `campaign_id`  BIGINT NOT NULL,
  `customer_id`  BIGINT NOT NULL,
  `channel`      VARCHAR(20) NOT NULL COMMENT 'sms/push/in_app',
  `content`      TEXT COMMENT '发送内容（变量已替换）',
  `send_time`    DATETIME NOT NULL,
  `send_status`  VARCHAR(20) NOT NULL COMMENT 'success/failed/pending',
  `fail_reason`  VARCHAR(500),
  `msg_id`       VARCHAR(100) COMMENT '第三方消息平台返回的消息ID',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_campaign_id` (`campaign_id`),
  KEY `idx_customer_id` (`customer_id`)
) COMMENT='AI营销发送日志表';
```

### 3.4 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| 活动列表 | GET | `/admin-api/ai/marketing/campaign/page` |
| 创建活动 | POST | `/admin-api/ai/marketing/campaign` |
| 活动详情 | GET | `/admin-api/ai/marketing/campaign/{id}` |
| 暂停/恢复活动 | PUT | `/admin-api/ai/marketing/campaign/{id}/pause` |
| 预估人群数量 | POST | `/admin-api/ai/marketing/segment/estimate` |
| 保存人群包 | POST | `/admin-api/ai/marketing/segment` |
| 人群包列表 | GET | `/admin-api/ai/marketing/segment/list` |
| 活动效果看板 | GET | `/admin-api/ai/marketing/campaign/{id}/stats` |
| 上传名单 | POST | `/admin-api/ai/marketing/segment/upload` |

---

## 4. RFM 客户价值分析

### 4.1 业务说明

RFM 模型基于三个维度分析客户价值：R（Recency，最近一次投保时间）、F（Frequency，投保频次）、M（Monetary，累计保费）。每个维度打分1-5分，综合分决定客户价值等级，供代理人制定差异化策略。

### 4.2 RFM 计算逻辑

**计算周期**：默认分析近2年（可配置）的投保数据，每月1日凌晨全量重算。

**各维度计算规则**：

**R 值（距上次投保天数，天数越小越好）**：

| 天数范围 | R分 |
|---------|-----|
| ≤ 30天 | 5 |
| 31~90天 | 4 |
| 91~180天 | 3 |
| 181~365天 | 2 |
| > 365天 | 1 |

**F 值（分析期内投保次数，次数越多越好）**：

| 投保次数 | F分 |
|---------|-----|
| ≥ 5次 | 5 |
| 3~4次 | 4 |
| 2次 | 3 |
| 1次 | 2 |
| 0次 | 1 |

**M 值（分析期内累计保费，金额越大越好）**：

M值按全租户客户的保费分布做五等分（五分位数），不同租户使用各自分布，避免绝对金额偏差。即：最高的20%客户得5分，依次类推。

**综合得分**：`RFM综合 = R × 0.4 + F × 0.3 + M × 0.3`（权重可配置）

**客户等级划分**：

| 等级 | 综合分 | 客户类型 | 策略建议 |
|------|-------|---------|---------|
| S级 | ≥ 4.5 | 重要价值客户 | 专属服务、VIP专属产品 |
| A级 | 3.5~4.4 | 重要发展客户 | 增购推荐、高端产品升级 |
| B级 | 2.5~3.4 | 重要保持客户 | 续保提醒、关怀活动 |
| C级 | 1.5~2.4 | 一般价值客户 | 常规营销 |
| D级 | < 1.5 | 低价值/流失客户 | 召回活动或放弃策略 |

### 4.3 PC 后台 — RFM 分析看板

路径：**AI智能工具 → 数据分析 → RFM 客户价值分析**

**看板区（顶部图表）**：
- 客户等级分布饼图（S/A/B/C/D各等级人数占比）
- 近6个月各等级客户数量变化折线图（展示等级流动趋势）

**客户明细列表**：

列表字段：客户姓名、负责代理人、R值（天数）、R分、F值（次数）、F分、M值（保费金额）、M分、综合得分、客户等级、分析周期、操作（查看客户详情）。

支持按等级筛选；支持按综合得分、M值、F值排序；支持导出。

**等级变化提醒（右上角消息提醒）**：
- 每月1日RFM重算后，生成等级变化报告，S级降级的客户发站内消息给负责代理人，提醒"客户XXX本月等级从S降为A，请及时跟进"。

### 4.4 RFM 计算定时任务

任务名：`rfm_monthly_calc_job`，执行时间：每月1日 03:30。

执行步骤：
1. 从配置读取分析时间窗口（默认近2年）。
2. 读取分析期内所有有成交记录的客户列表。
3. 计算每位客户的R、F、M原始值。
4. 计算M分（全租户五分位数分布），R分和F分按固定区间。
5. 计算综合得分，确定等级。
6. 与上月结果对比，生成等级变化记录（`ai_rfm_level_change`）。
7. 写入 `ai_rfm_analysis_result`（insert新记录，保留历史）。
8. 同步更新 `ai_user_tag` 中的客户价值等级标签。
9. 推送等级变化消息给相关代理人。

### 4.5 数据库设计

```sql
CREATE TABLE `ai_rfm_analysis_result` (
  `id`                    BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`           BIGINT NOT NULL,
  `analysis_period_start` DATE NOT NULL COMMENT '分析期开始',
  `analysis_period_end`   DATE NOT NULL COMMENT '分析期结束',
  `recency_value`         INT NOT NULL COMMENT 'R值（天数）',
  `recency_score`         TINYINT NOT NULL COMMENT 'R分 1-5',
  `frequency_value`       INT NOT NULL COMMENT 'F值（次数）',
  `frequency_score`       TINYINT NOT NULL COMMENT 'F分 1-5',
  `monetary_value`        DECIMAL(15,2) NOT NULL COMMENT 'M值（保费金额）',
  `monetary_score`        TINYINT NOT NULL COMMENT 'M分 1-5',
  `rfm_score`             DECIMAL(4,2) NOT NULL COMMENT '综合得分',
  `customer_level`        VARCHAR(10) NOT NULL COMMENT 'S/A/B/C/D',
  `analysis_time`         DATETIME NOT NULL COMMENT '计算时间',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_analysis_time` (`analysis_time`),
  KEY `idx_customer_level` (`customer_level`)
) COMMENT='AI RFM分析结果表';

CREATE TABLE `ai_rfm_level_change` (
  `id`             BIGINT NOT NULL AUTO_INCREMENT,
  `customer_id`    BIGINT NOT NULL,
  `agent_id`       BIGINT COMMENT '负责代理人',
  `analysis_month` VARCHAR(7) NOT NULL COMMENT '分析月份，格式 2025-02',
  `old_level`      VARCHAR(10) COMMENT '上月等级',
  `new_level`      VARCHAR(10) NOT NULL COMMENT '本月等级',
  `is_upgraded`    BIT(1) COMMENT 'true升级/false降级',
  `notify_status`  TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0未通知 1已通知',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_analysis_month` (`analysis_month`)
) COMMENT='AI RFM等级变化记录表';

CREATE TABLE `ai_rfm_weight_config` (
  `id`              BIGINT NOT NULL AUTO_INCREMENT,
  `r_weight`        DECIMAL(3,2) NOT NULL DEFAULT 0.40 COMMENT 'R权重',
  `f_weight`        DECIMAL(3,2) NOT NULL DEFAULT 0.30 COMMENT 'F权重',
  `m_weight`        DECIMAL(3,2) NOT NULL DEFAULT 0.30 COMMENT 'M权重',
  `analysis_months` INT NOT NULL DEFAULT 24 COMMENT '分析时间窗口（月）',
  `is_active`       BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否当前生效',
  `creator` VARCHAR(64) DEFAULT '', `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` VARCHAR(64) DEFAULT '', `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` BIT(1) NOT NULL DEFAULT b'0', `tenant_id` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) COMMENT='AI RFM权重配置表';
```

### 4.6 接口清单

| 接口 | Method | URL |
|------|--------|-----|
| RFM看板数据 | GET | `/admin-api/ai/rfm/dashboard` |
| RFM结果列表 | GET | `/admin-api/ai/rfm/page` |
| 客户RFM历史 | GET | `/admin-api/ai/rfm/customer/{customerId}/history` |
| 等级变化列表 | GET | `/admin-api/ai/rfm/level-change/page` |
| 权重配置查看 | GET | `/admin-api/ai/rfm/weight-config` |
| 更新权重配置 | POST | `/admin-api/ai/rfm/weight-config` |
| 手动触发计算 | POST | `/admin-api/ai/rfm/calc-now` |
| 导出结果 | GET | `/admin-api/ai/rfm/export` |

---

## 附录：数据分析模块定时任务汇总

| 任务名称 | 执行时间 | 说明 |
|---------|---------|------|
| `user_tag_refresh_job` | 每天 01:00 | 基础属性+活跃度+保单标签刷新 |
| `portrait_snapshot_job` | 每天 03:00 | 聚合标签更新画像快照 |
| `churn_prediction_job` | 每天 02:30 | 流失概率预测 |
| `rfm_monthly_calc_job` | 每月1日 03:30 | RFM全量重算+等级变化通知 |
| `campaign_execute_job` | 每5分钟 | 检查到达开始时间的营销活动，执行触达 |
| `product_cf_matrix_job` | 每天 00:00 | 计算协同过滤产品相似度矩阵，写入Redis |

---

*文档结束 · 共三篇：*  
*上篇：AI保障规划 | 中篇：智能核保 + 智能客服 | 下篇：数据分析（本篇）*

# 合规双录模块 · 数据库表结构设计文档

> **模块**：`intermediary-module-ins-compliance`  
> **Schema**：`db_ins_compliance`  
> **表前缀**：`ins_comp_`  
> **对应阶段**：阶段5 - 合规双录（双录引擎 + AI质检 + 存证管理 + 行为轨迹）  
> **文档版本**：V1.0  
> **编写日期**：2026-03-01  
> **SQL文件**：`db_ins_compliance.sql`

---

## 一、模块职责说明

合规双录模块是寿险业务的强监管要求，覆盖以下核心能力：

| 子模块 | 核心功能 | 技术依赖 |
|--------|----------|----------|
| 双录引擎 | RTC房间管理/话术节点推进/断点重录 | 声网Agora Cloud Recording |
| 话术模板 | 节点JSON编排/关键词/禁用词配置 | 可视化节点编辑器 |
| AI质检 | ASR语音转文字/关键词检测/人脸识别/证件OCR | 阿里云ASR/人脸识别SDK |
| 区块链存证 | 文件哈希上链/验证接口 | 蚂蚁链/腾讯至信链 |
| 行为轨迹 | C端投保全流程埋点/截图存证 | html2canvas + OSS |
| 合规报表 | 通过率趋势/违规分布/业务员排行 | 复用官方report模块 |

---

## 二、表清单总览

| 表名 | 中文名 | 说明 | 对应DO类 |
|------|--------|------|----------|
| `ins_comp_recording_session` | 双录会话主表 | 一条双录的完整生命周期记录 | `InsRecordingSessionDO` |
| `ins_comp_retry_log` | 重录日志表 | 每次重录申请和审批记录 | `InsRetryLogDO` |
| `ins_comp_script_template` | 话术模板表 | 节点JSON/关键词/禁用词 | `InsScriptTemplateDO` |
| `ins_comp_quality_check` | AI质检结果表 | ASR/关键词/人脸/证件检测 | `InsQualityCheckResultDO` |
| `ins_comp_evidence_record` | 区块链存证记录表 | 链上哈希/验证状态 | `InsEvidenceRecordDO` |
| `ins_comp_behavior_trace` | C端行为轨迹表 | 停留时长/截图/交互事件 | `InsBehaviorTraceDO` |
| `ins_comp_trigger_rule` | 双录触发规则配置 | 可动态配置触发条件 | `InsTriggerRuleDO` |
| `ins_comp_system_config` | 合规系统配置 | 抽检比例/超时等参数 | `InsCompSystemConfigDO` |

---

## 三、核心表设计详解

### 3.1 `ins_comp_recording_session`（双录会话主表）

这是合规模块最核心的表，一条记录代表一次完整的双录会话。

**关键字段说明**：

| 字段组 | 字段 | 说明 |
|--------|------|------|
| 编号 | `record_code` | DR+yyyyMMdd+Redis自增6位，全局唯一 |
| 参与者 | `agent_id` / `customer_id` | 关联ins_agent模块 |
| 安全 | `customer_id_card` | AES-256-CBC加密，密钥由Nacos KMS管理 |
| RTC | `rtc_room_id` / `rtc_token` / `invite_token` | 声网房间和Token管理 |
| 节点 | `node_completed` / `current_node` | JSON数组记录已完成节点，实时更新 |
| 音视频 | `video_url` / `audio_url` | OSS私有存储路径，访问需生成临时签名URL |
| AI质检 | `ai_check_status` / `ai_final_score` | 异步质检状态和汇总得分 |
| 人工 | `manual_check_result` / `manual_check_remark` | 人工质检结论 |

**状态机**：

```
0-待开始 ──start──> 1-进行中 ──finish──> 2-已完成 ──MQ──> 3-质检中
                                                          ├──pass──> 4-质检通过
                                                          └──fail──> 5-质检不通过
任意状态 ──cancel──> 6-已作废
```

**索引设计**：

```sql
UNIQUE KEY uk_record_code         -- 编号全局唯一
KEY idx_agent_id (agent_id, create_time)   -- 业务员维度查询（数据隔离）
KEY idx_ai_check_status           -- 定时任务扫描待质检记录
KEY idx_stat_report               -- 合规报表统计复合索引
```

---

### 3.2 `ins_comp_script_template`（话术模板表）

**`script_nodes` JSON 字段结构**（完整示例）：

```json
[
  {
    "nodeIndex": 1,
    "nodeName": "身份确认",
    "nodeType": "MUST",
    "scriptContent": "您好，我是XX保险公司代理人，工号XXXX。请问您是XXX先生/女士本人吗？",
    "expectedResponse": "客户口头确认本人身份",
    "keyWords": ["本人", "代理人"],
    "forbiddenWords": [],
    "minDuration": 10
  },
  {
    "nodeIndex": 2,
    "nodeName": "产品风险告知",
    "nodeType": "MUST",
    "scriptContent": "您购买的XX分红险，分红收益具有不确定性，非固定利率...",
    "keyWords": ["分红", "不确定性", "犹豫期"],
    "forbiddenWords": ["保本", "无风险", "固定收益"],
    "minDuration": 30
  },
  {
    "nodeIndex": 3,
    "nodeName": "健康告知确认",
    "nodeType": "OPTIONAL",
    "scriptContent": "请问您过去5年内是否有住院记录？",
    "keyWords": [],
    "forbiddenWords": [],
    "minDuration": 0
  }
]
```

**模板匹配优先级规则**（业务逻辑，后端实现）：

1. `product_type` 精确匹配 > `product_type=0`（通用模板）
2. 同类型内取 `version` 最大且 `is_active=true` 的
3. 同时考虑 `age_min` / `age_max` 客户年龄区间

---

### 3.3 `ins_comp_quality_check`（AI质检结果表）

**质检评分规则**：

| 违规类型 | 字段 | 扣分 | 备注 |
|----------|------|------|------|
| 禁用词（每次） | `forbidden_score_deduct` | -20分 | 如"保本"、"无风险" |
| 遗漏必读关键词（每个） | `keyword_score_deduct` | -5分 | 如未提及"犹豫期" |
| 跳过必读节点（每个） | `node_score_deduct` | -15分 | MUST类型节点未完成 |
| 人脸识别不通过 | `face_score_deduct` | -30分 | 相似度 < 80 |
| 证件翻拍 | `idcard_score_deduct` | -30分 | 非原件身份证 |
| 证件信息不符 | `idcard_score_deduct` | -50分 | OCR与投保人不一致 |

**评分等级**：

| 分数段 | `score_level` | 处理逻辑 |
|--------|---------------|----------|
| 90-100 | `EXCELLENT` | 自动通过，触发存证 |
| 80-89 | `GOOD` | 自动通过，触发存证 |
| 60-79 | `PASS` | 通过，按配置比例触发人工抽检（默认20%） |
| < 60 | `FAIL` | 不通过，通知业务员重录 |

**异步处理流程**（MQ消费者）：

```
MQ Topic: double_record_ai_check
消费者: DoubleRecordAiCheckConsumer

处理步骤:
1. 创建 ins_comp_quality_check 记录（check_status=1）
2. CompletableFuture 并行执行：
   ├── ASR语音转文字（需等待回调，约1-3分钟）
   ├── 人脸识别（视频截帧+比对）
   └── 证件OCR识别
3. ASR完成后串行执行关键词/禁用词检测
4. 汇总所有扣分 → 计算 final_score
5. 更新 ins_comp_quality_check（check_status=2）
6. 更新 ins_comp_recording_session（ai_check_status=2，record_status=4或5）
7. 发送站内信+Push通知业务员
```

---

### 3.4 `ins_comp_evidence_record`（区块链存证记录表）

**存证触发时机**：

- 自动触发：双录完成后24小时内，由定时任务扫描未存证记录
- 手动触发：合规管理员在存证管理页面手动触发

**存证文件类型**（`evidence_type`）：

| 值 | 说明 | 对应文件 |
|----|------|----------|
| 1 | 双录视频 | `record_code_video.mp4` |
| 2 | 行为轨迹 | 轨迹数据JSON文件 |
| 3 | 质检报告 | `record_code_report.pdf` |
| 4 | 签字确认 | 电子签字图片 |

**幂等设计**：同一 `session_id + evidence_type` 组合已存在则跳过，不重复上链。

---

### 3.5 `ins_comp_behavior_trace`（C端行为轨迹表）

**各页面最低停留要求**（来自 `ins_comp_system_config`）：

| `page_type` | 页面名称 | 最低停留 | 是否截图 |
|-------------|----------|----------|----------|
| 1 | 产品详情页 | 30秒 | 否 |
| 2 | 健康告知页 | 60秒 | 是（每题点击） |
| 3 | 投保须知页 | 45秒 | 否 |
| 4 | 条款展示页 | 90秒 | 是（翻页时） |
| 5 | 支付确认页 | 10秒 | 是（点击支付） |

**`event_detail` JSON 示例**（健康告知页）：

```json
{
  "questions": [
    {"questionId": 1, "question": "过去5年内是否住院？", "answer": "否", "clickTime": "2026-02-14T10:05:30"},
    {"questionId": 2, "question": "是否患有糖尿病？", "answer": "否", "clickTime": "2026-02-14T10:05:45"}
  ]
}
```

---

## 四、定时任务设计

| 任务类 | 执行频率 | 功能 |
|--------|----------|------|
| `InsAsrPollJob` | 每30秒 | 扫描 `asr_status=1` 的记录，轮询阿里云ASR结果 |
| `InsEvidenceRetryJob` | 每小时 | 扫描存证失败记录，重新触发区块链存证 |
| `InsEvidenceAlertJob` | 每小时 | 扫描超24h未存证的已完成双录，推送告警 |
| `InsManualCheckUrgeJob` | 每天9:00 | 扫描超7工作日未完成人工质检的记录，发催办通知 |
| `InsAiCheckTimeoutJob` | 每小时 | 扫描超72h未完成AI质检的记录，重新提交MQ |
| `InsRtcRecordCheckJob` | 每30分钟 | 查询声网录制状态，处理录制回调超时 |

---

## 五、安全与合规设计

### 5.1 数据加密

```
customer_id_card  → AES-256-CBC 加密存储
customer_mobile   → AES-256-CBC 加密存储
密钥管理          → Nacos Config + KMS，不硬编码在代码中
接口返回脱敏      → 身份证前6后4，姓名只保留姓
```

### 5.2 数据权限

| 角色 | 数据范围 | 实现方式 |
|------|----------|----------|
| 业务员 | 只能查看自己的双录 | `WHERE agent_id = currentUserId` |
| 团队长 | 本团队所有成员 | `WHERE agent_org_id = currentOrgId` |
| 质检员 | 全部待质检记录 | 无额外过滤，但只读 |
| 合规主管 | 全部记录 + 管理能力 | 无额外过滤 |

### 5.3 OSS 存储规范

```
文件路径格式：{tenant_id}/double-record/{yyyy}/{MM}/{record_code}_{type}.{ext}
Bucket权限：私有（禁止公开访问）
访问方式：后端生成临时签名URL（有效期2小时）
视频分层存储：
  0~3月   → 标准存储
  3~12月  → 低频存储
  12月+   → 归档存储
  5年后   → 锁定，需合规审批才可删除
```

---

## 六、模块间依赖关系

```
ins-compliance 依赖：
  ├── ins-order    (order_id 关联保单订单)
  ├── ins-agent    (agent_id/customer_id 关联业务员和客户)
  ├── ins-product  (product_id 获取产品类型，判断双录触发条件)
  ├── system       (user_id 获取质检员信息，权限校验)
  ├── member       (user_id C端用户，行为轨迹关联)
  └── pay          (order_id 支付确认页行为轨迹)

ins-compliance 被依赖：
  └── ins-order   (查询双录状态，投保审核前校验双录是否通过)
```

---

## 七、SQL文件说明

提供 1 个 SQL 文件，包含完整建表语句：

| 文件 | 内容 |
|------|------|
| `db_ins_compliance.sql` | 创建库、8张表的完整DDL、初始化配置数据、索引 |

**执行顺序**：

```bash
# 1. 创建数据库并执行DDL
mysql -h host -u root -p < db_ins_compliance.sql

# 2. 验证表结构
USE db_ins_compliance;
SHOW TABLES;
```

---

## 八、后续扩展建议

1. **质检规则引擎**：当前关键词/禁用词逻辑硬编码在Service中，后续可抽象为规则引擎（如Drools），支持更复杂的质检逻辑配置
2. **多链支持**：`blockchain_type` 字段已预留多区块链平台枚举，可平滑扩展
3. **ASR分段对齐**：`asr_detail` JSON 保存了时间戳分段，后续可实现视频字幕同步、违规时间点精准定位
4. **合规数据大屏**：基于 `ins_comp_recording_session` + `ins_comp_quality_check` 的统计字段，接入 `intermediary-module-report` 实现BI大屏展示

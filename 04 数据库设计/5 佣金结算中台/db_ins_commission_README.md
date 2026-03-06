# 佣金结算中台 · 数据库表结构设计文档

> **模块**：`intermediary-module-ins-commission`  
> **Schema**：`db_ins_commission`  
> **表前缀**：`ins_comm_`（通用） / `ins_car_`（车险政策专属）  
> **文档版本**：V1.0  
> **编写日期**：2026-03-01  
> **对应阶段**：阶段2-PC管理后台-佣金系统（上篇 + 中篇 + 下篇 + 补充篇A/B）  
> **技术栈**：MySQL 8.0 + Spring Boot + MyBatis Plus + yudao-cloud

---

## 一、模块职责概述

佣金结算中台（`ins-commission`）负责保险中介平台全险种（车险/非车险/寿险）的佣金计算、结算、发放和对账体系，是整个平台的核心财务引擎。

核心能力：
- **基本法配置**：职级体系/晋升规则/FYC/RYC/津贴/奖励
- **佣金计算引擎**：基于 Groovy 脚本的规则引擎，支持批量异步计算
- **结算发放**：月度结算单生成、审核工作流、银行/支付宝/微信多渠道发放
- **保司对账**：Excel 导入保司账单、自动匹配、差异处理、开票收款
- **薪酬管理**：佣金查询（业务员维度）、工资月度汇总、加扣款导入
- **车险政策管理**：留点政策/加投点/报价赋值/禁保名单
- **多级结算**：分润链路配置与分润计算

---

## 二、SQL 文件清单

| 文件名 | 内容说明 | 包含表数量 |
|--------|---------|-----------|
| `db_ins_commission_part1_basic_law.sql` | 基本法配置 + 佣金规则引擎 | 7 张 |
| `db_ins_commission_part2_record_statement.sql` | 佣金记录 + 结算单 + 对账管理 | 9 张 |
| `db_ins_commission_part3_car_policy.sql` | 车险政策管理 + 多级结算政策 | 5 张 |

---

## 三、完整表清单（共 21 张）

### 3.1 Part 1：基本法配置 + 佣金规则引擎

| 序号 | 表名 | 说明 | 对应需求 |
|------|------|------|---------|
| 1 | `ins_comm_basic_law` | 基本法主表（版本管理） | 上篇 §2.1 |
| 2 | `ins_comm_rank` | 职级体系配置（FYC率/RYC率/分润率） | 上篇 §2.1 |
| 3 | `ins_comm_rank_promotion_rule` | 晋升规则配置（FYP/团队人数等条件） | 上篇 §2.2 |
| 4 | `ins_comm_allowance_config` | 津贴配置（管理津贴/育成奖/伯乐奖/季度年度奖） | 上篇 §2.4/2.5 |
| 5 | `ins_comm_rule` | 佣金规则表（Groovy脚本/版本管理） | 上篇 §3.1 |
| 6 | `ins_comm_rate_history` | 佣金比例变更历史（合规审计） | 上篇 §2.3 + 补充篇A |
| 7 | `ins_comm_agent_rank_snapshot` | 业务员职级月度快照 | 上篇 §2.1（历史回溯） |

### 3.2 Part 2：佣金记录 + 结算单 + 对账管理

| 序号 | 表名 | 说明 | 对应需求 |
|------|------|------|---------|
| 8 | `ins_comm_record` | **佣金明细记录表（核心主表）** | 上篇 §3.3 + 补充篇B §2.1 |
| 9 | `ins_comm_calc_batch` | 批量计算批次（异步任务管理） | 上篇 §3.3 |
| 10 | `ins_comm_statement` | 结算单（月度/季度汇总） | 中篇 §2.1~2.4 |
| 11 | `ins_comm_pay_batch` | 佣金发放批次 | 中篇 §2.3 |
| 12 | `ins_comm_reconcile` | 与保司对账记录（开票/收款一体化） | 中篇 §3.1~3.3 |
| 13 | `ins_comm_reconcile_import_batch` | 保司账单导入批次 | 中篇 §3.1 |
| 14 | `ins_comm_salary_adjustment` | 业务员加扣款记录 | 补充篇B §2.3 (PDF-219) |
| 15 | `ins_comm_adj_import_batch` | 加扣款导入批次 | 补充篇B §2.3 |
| 16 | `ins_comm_commission_split` | 佣金分润链路归档（多级结算审计） | 补充篇A §3.1 |

### 3.3 Part 3：车险政策管理 + 多级结算

| 序号 | 表名 | 说明 | 对应需求 |
|------|------|------|---------|
| 17 | `ins_car_point_config` | 车险留点政策（保司/险种/职级差异化） | PDF-66/67 |
| 18 | `ins_car_extra_point_batch` | 车险加投点批次（FYP阶梯档位） | PDF-65 |
| 19 | `ins_car_quote_adjust_policy` | 报价赋值政策（展示层加减价） | PDF-69/70 |
| 20 | `ins_car_underwrite_blacklist` | 预核保禁止投保名单 | PDF-68 |
| 21 | `ins_comm_multilevel_policy` | 多级结算政策（分润链路JSON） | PDF-244/245 |

---

## 四、核心表关系说明

```
ins_comm_basic_law (基本法)
    └── ins_comm_rank (职级) 1:N
            └── ins_comm_rank_promotion_rule (晋升规则) 1:N
    └── ins_comm_allowance_config (津贴) 1:N

ins_comm_rule (佣金规则，独立)

保单下单(ins_order模块) ──触发──► ins_comm_calc_batch (批量计算)
    └── 计算结果 ──写入──► ins_comm_record (佣金明细，核心)
                                ├── commission_type=FYC/RYC  基础佣金
                                ├── commission_type=OVERRIDE ← ins_comm_commission_split (分润链路)
                                └── commission_type=BONUS    津贴奖励

ins_comm_record ──归集──► ins_comm_statement (结算单)
    └── APPROVED ──► ins_comm_pay_batch (发放批次) ──► 银行/支付宝/微信

ins_comm_reconcile_import_batch (导入) ──► ins_comm_reconcile (对账)
    └── 差异处理/开票/收款 在 ins_comm_reconcile 表内管理

ins_comm_salary_adjustment (加扣款) ──JOIN──► 工资聚合查询(不独立建汇总表)

ins_comm_multilevel_policy (多级结算政策)
    └── sys_dept.multi_settle_policy_id 绑定 (ALTER扩展字段)
```

---

## 五、关键设计说明

### 5.1 ins_comm_record 佣金明细表设计要点

这是整个模块最核心的表，所有类型的佣金（FYC/RYC/OVERRIDE/BONUS/REFUND）都在此表中用 `commission_type` 字段区分，而非拆分多张表。

主要优点：
- 统一查询入口，工资聚合 SQL 简单
- 支持跨险种、跨类型的汇总统计
- 分润关系通过 `source_commission_id` 自关联

**状态机**：
```
PENDING → APPROVED → PAID
       ↘ REJECTED
PAID → REFUNDED（退保回收）
```

### 5.2 分润计算逻辑

当业务员出单生成 FYC 佣金后，系统递归查询其上级主任链路：
1. 读取 `sys_dept.multi_settle_policy_id` 匹配多级结算政策
2. 按 `ins_comm_multilevel_policy.override_hierarchy` JSON 中的各层比例计算分润
3. 为每个上级主任生成一条 `commission_type=OVERRIDE` 的 `ins_comm_record` 记录
4. 同时在 `ins_comm_commission_split` 归档完整分润链路（审计用）

若未配置多级结算政策，则回退到 `ins_comm_rank.override_rate` 计算基本法标准管理津贴。

### 5.3 工资查询不引入汇总表

工资查询（`补充篇B §2.2`）通过以下方式实现，不引入新的聚合表：
- 实时 SQL 聚合 `ins_comm_record` 按 `agent_id + settle_period` 分组
- LEFT JOIN `ins_comm_salary_adjustment` 获取加扣款
- 前端展示层计算个税（使用 `ins_comm_statement` 的 `tax_amount` 字段）

高并发场景下，可将月度工资结果缓存到 Redis（Key: `commission:salary:{period}:{agentId}`）。

### 5.4 合规截断机制

佣金计算引擎在写入 `ins_comm_record` 前，需检查：
1. 实际佣金率 ≤ 监管合规上限（来自 `ins_car_point_config.compliance_max_rate` 或保司配置）
2. 若超限，自动截断至上限，并设置 `is_compliance_truncated=1`，记录 `original_rate`（原始比例）
3. 所有变更写入 `ins_comm_rate_history` 供合规审计

### 5.5 Groovy 规则引擎安全

`ins_comm_rule.rule_script` 存储的 Groovy 脚本在执行时需：
- 使用沙箱（Groovy Sandbox，禁止 `System.exit`、文件IO等危险操作）
- 设置超时（默认 5s），超时报错不抛出异常，降级到基础比例计算
- 脚本变更需走审批流（`bpm` 模块），审批通过后才更新 `is_latest=1`

---

## 六、索引设计说明

### 高频查询场景对应索引

| 查询场景 | 核心索引 |
|---------|---------|
| 佣金查询（业务员+周期） | `idx_agent_period_type` (agent_id, settle_period, commission_type) |
| 保单号查佣金 | `idx_policy_no` (policy_no) |
| 对账单匹配保单 | `idx_policy_no` on ins_comm_reconcile |
| 批量计算进度查询 | `idx_status` + `idx_calc_period` on ins_comm_calc_batch |
| 禁保名单快速判断 | `idx_blacklist_value_hash` (SHA256哈希查询) |
| 留点政策匹配（报价时） | `idx_company_type_org_rank` |

---

## 七、Redis 缓存设计（补充说明）

| Key 格式 | 说明 | TTL |
|----------|------|-----|
| `commission:rule:{ruleCode}` | 最新佣金规则脚本（热点缓存） | 1小时 |
| `commission:rank:snapshot:{agentId}:{month}` | 业务员月度职级快照 | 7天 |
| `commission:blacklist:{hash}` | 禁保名单布隆过滤器 | 永久（定时刷新） |
| `commission:export:task:{taskId}` | 大数据量导出任务进度 | 2小时 |
| `commission:calc:batch:{batchId}:progress` | 批量计算进度 | 24小时 |

---

## 八、定时任务清单

| 任务名称（Job Handler） | Cron | 说明 |
|----------------------|------|------|
| `insCommAutoCalcJob` | `0 0 1 1 * ?` | 每月1日01:00自动触发上月佣金批量计算 |
| `insCommStatementGenJob` | `0 0 2 5 * ?` | 每月5日02:00生成上月结算单草稿 |
| `insCarBlacklistExpireJob` | `0 30 0 * * ?` | 每日00:30清理过期禁保名单（status=0）并刷新Redis |
| `insCarExtraPointCalcJob` | `0 0 3 1 * ?` | 每月1日03:00统计上月业务员FYP，追加加投点佣金 |
| `insCommRankSnapshotJob` | `0 0 4 1 * ?` | 每月1日04:00生成上月全员职级快照 |

---

## 九、权限标识清单

| 权限标识 | 说明 |
|---------|------|
| `commission:basic-law:create` | 新增基本法 |
| `commission:basic-law:update` | 修改基本法 |
| `commission:rank:create` | 新增职级 |
| `commission:rule:create` | 新增佣金规则 |
| `commission:rule:publish` | 发布佣金规则（需审批） |
| `commission:calc:trigger` | 手动触发佣金计算 |
| `commission:statement:approve` | 审核结算单 |
| `commission:pay:operate` | 执行佣金发放 |
| `commission:reconcile:import` | 导入保司对账账单 |
| `commission:reconcile:handle-diff` | 处理对账差异 |
| `commission:car-policy:point:create` | 新增留点政策 |
| `commission:car-policy:point:update` | 修改留点政策 |
| `commission:car-policy:extra-point:create` | 新增加投点批次 |
| `commission:car-policy:quote-adjust:create` | 新增报价赋值政策 |
| `commission:car-policy:blacklist:add` | 新增禁保名单 |
| `commission:car-policy:blacklist:import` | 批量导入禁保名单 |
| `commission:multilevel:policy:create` | 新增多级结算政策 |
| `commission:multilevel:bind` | 组织绑定多级结算负责人 |
| `commission:salary:query` | 佣金查询（薪酬管理） |
| `commission:salary:adjust:import` | 加扣款导入 |

---

*对应工程：intermediary-cloud / intermediary-module-ins-commission*

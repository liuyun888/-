# intermediary-module-ins-life 数据库设计说明

> **数据库名**：`db_ins_life`  
> **表前缀**：`ins_life_`（寿险专属）、`ins_insurer_life_`（保司扩展）、`ins_questionnaire_`（统一问卷引擎）  
> **文档版本**：V1.0 | **生成日期**：2026-03-01  
> **对应需求**：阶段7-PC管理后台-寿险体系 + 阶段8-C端商城-寿险投保  
> **工程模块**：`intermediary-module-ins-life`（寿险专属中台，V13新增）

---

## 一、文件说明

| SQL文件 | 包含模块 | 表数量 |
|--------|---------|------|
| `ins_life_01_product.sql` | 产品管理、H5配置、系统配置 | 15张 |
| `ins_life_02_policy.sql` | 保单管理（个险/团险/C端投保） | 16张 |
| `ins_life_03_renewal_claim_finance.sql` | 续期/理赔/数据回传/财务/报表 | 15张 |

**合计：46张核心业务表**

---

## 二、表清单总览（46张）

### Part 1 — 产品模块（15张）

| 表名 | 对应需求 |
|-----|---------|
| `ins_insurer_life_ext` | 寿险合作保司扩展信息（PDF-169） |
| `ins_life_product` | 寿险产品主表（PDF-170，C端列表） |
| `ins_life_product_commission` | 产品佣金配置（首年/续年，PDF-170 Tab2） |
| `ins_life_product_rate` | 产品费率表（EasyExcel导入，PDF-170 Tab4） |
| `ins_life_product_auth` | 产品机构授权（PDF-170） |
| `ins_questionnaire_template` | 健康告知/保障规划问卷模板（V15统一引擎） |
| `ins_life_product_questionnaire` | 产品与问卷关联 |
| `ins_life_insurer_account` | 业务员保司工号（PDF-167） |
| `ins_life_h5_product_category` | H5产品分类（PDF-165） |
| `ins_life_h5_online_policy` | H5在线投保配置（PDF-165） |
| `ins_life_h5_product_intro` | H5产品介绍配置（PDF-165） |
| `ins_life_h5_plan_book` | H5计划书配置（PDF-165） |
| `ins_life_h5_content_category` | H5内容分类（PDF-165） |
| `ins_life_h5_content` | H5内容管理（PDF-165） |
| `ins_life_sys_config` | 寿险系统参数配置（PDF-166，Redis热更新） |

### Part 2 — 保单模块（16张）

| 表名 | 对应需求 |
|-----|---------|
| `ins_policy_life` | 寿险保单主表（PDF-110，PC/App/C端统一） |
| `ins_life_policy_coverage` | 保单险种子表（主险+附加险） |
| `ins_life_policy_insured` | 被保人/受益人表 |
| `ins_policy_attachment` | 保单附件/影像件（PDF-122） |
| `ins_policy_life_status_log` | 保单状态变更日志 |
| `ins_policy_life_change_log` | 保单字段修改日志 |
| `ins_life_policy_receipt` | 回执记录表（PDF-116） |
| `ins_life_policy_visit` | 回访记录表（PDF-117~119） |
| `ins_life_conservation` | 保全申请表（PDF-125~127） |
| `ins_life_orphan` | 孤儿单表（PDF-132~133） |
| `ins_life_orphan_log` | 孤儿单分配轨迹（PDF-134） |
| `ins_life_policy_reconcile` | 保单核对记录（PDF-114） |
| `ins_life_import_log` | 批量导入日志（PDF-112） |
| `ins_life_group_policy_member` | 团险被保人名册（PDF-115） |
| `ins_life_order_draft` | C端投保草稿（阶段8，24小时过期） |
| `ins_life_export_task` | 异步导出任务（共用） |

### Part 3 — 续期/理赔/财务/报表（15张）

| 表名 | 对应需求 |
|-----|---------|
| `ins_life_renewal_track` | 续期跟踪记录（PDF-128~131） |
| `ins_life_payment_record` | 保费缴费记录 |
| `ins_life_renewal_policy` | 续期政策配置 |
| `ins_life_claim_record` | 理赔案件主表（PDF-138） |
| `ins_life_claim_follow` | 理赔跟进记录 |
| `ins_life_data_return_config` | 数据回传保司配置（PDF-135~137） |
| `ins_life_data_return_log` | 数据回传执行日志 |
| `ins_life_upstream_settlement` | 上游结算统计（PDF-151） |
| `ins_life_policy_settlement` | 保单结算明细（PDF-152/162） |
| `ins_life_org_calculation` | 机构计算（PDF-153） |
| `ins_life_org_reconcile` | 机构对账（PDF-154） |
| `ins_life_agent_tax` | 代理人个税查询（PDF-155） |
| `ins_life_salary_calculation` | 薪资计算（PDF-156） |
| `ins_life_adjustment` | 上游加扣管理（PDF-157） |
| `ins_life_regulatory_report` | 监管报表记录（PDF-159） |

---

## 三、设计原则与关键决策

### 3.1 服务边界

本模块（`db_ins_life`）仅存储寿险业务数据，与其他微服务的数据关联均通过业务代码（无物理外键）实现：

| 字段 | 关联服务 | 说明 |
|-----|---------|------|
| `insurer_id` | ins-agent | 保险公司主表 |
| `customer_id` | ins-agent/CRM | 客户主表 |
| `agent_id` / `org_id` | ins-agent / system | 业务员/机构 |
| `member_id` | ins-member | C端会员 |
| `process_inst_id` | bpm | Flowable流程实例 |

### 3.2 敏感字段加密

以下字段所有值均在 Service 层使用 **AES-256** 加密存储、解密读取，展示时脱敏：

- 证件号：前4后4显示，中间 `***`
- 手机号：131`****`1111
- 银行账号：末位4位显示，其余 `*`

### 3.3 V15架构合并

- **问卷引擎**：`ins_questionnaire_template` 全平台统一，`template_type` 区分 `HEALTH`/`AI_PLAN`
- **保司表**：不重复建寿险保司主表，用 `ins_insurer_life_ext` 扩展
- **保单主表**：PC/App/C端统一写 `ins_policy_life`，`source` 字段区分来源

### 3.4 继续率计算逻辑（R13/R25/R37/R49）

```sql
-- R13 示例
-- 分母：12个月前起保的有效保单
SELECT COUNT(*) AS denominator FROM ins_policy_life
WHERE DATE_FORMAT(start_date, '%Y-%m') = DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 12 MONTH), '%Y-%m')
AND policy_status IN ('ACTIVE', 'LAPSED');

-- 分子：分母中第13期已缴费的保单
SELECT COUNT(*) AS numerator FROM ins_life_renewal_track rt
INNER JOIN ins_policy_life p ON rt.policy_id = p.id
WHERE rt.period_year = 2 AND rt.follow_status = 'PAID'
AND DATE_FORMAT(p.start_date, '%Y-%m') = DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 12 MONTH), '%Y-%m');
```

### 3.5 定时任务清单（XXL-Job）

| Job类名 | 执行频率 | 功能 |
|--------|---------|------|
| `InsLifeOrphanRecognizeJob` | 每天00:30 | 识别离职业务员保单入孤儿单池 |
| `InsLifeDraftCleanJob` | 每小时 | 清理过期投保草稿 |
| `InsLifeRenewalAlertJob` | 每天08:00 | 续期缴费提醒推送 |
| `InsLifeAutoLapseJob` | 每天01:00 | 超宽限期保单自动失效 |
| `InsLifeNextPaymentDateJob` | 每月1日 | 批量计算next_payment_date |

---

## 四、Redis缓存策略

| 缓存Key格式 | 数据 | TTL |
|-----------|------|-----|
| `ins:life:product:list:{md5(参数)}` | C端产品列表 | 5分钟 |
| `ins:life:product:detail:{id}` | 产品详情 | 10分钟 |
| `ins:life:sys:config:{tenant_id}` | 系统参数 | 30分钟 |
| `ins:life:questionnaire:{product_id}` | 健康告知问卷 | 10分钟 |

---

*SQL执行顺序：Part1 → Part2 → Part3（无跨文件物理外键，顺序不强制）*

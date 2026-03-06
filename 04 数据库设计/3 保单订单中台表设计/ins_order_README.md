# intermediary-module-ins-order 数据库设计文档

> **模块**：保单订单中台  
> **Schema**：`db_ins_order`  
> **表前缀**：`ins_order_`  
> **版本**：V1.0  
> **覆盖阶段**：阶段1（车险保单录入）、阶段2（非车险保单管理）、阶段3（C端投保）、阶段7（寿险保单管理 ★V13）、阶段8（C端寿险投保 ★V13）

---

## 一、文件说明

本模块数据库设计拆分为 **4个SQL文件**，请按顺序执行：

| 文件名 | 内容 | 表数量 |
|--------|------|--------|
| `ins_order_01_car_policy.sql` | 车险保单相关表 | 4张 |
| `ins_order_02_non_car_policy.sql` | 非车险保单相关表 | 4张 |
| `ins_order_03_life_policy.sql` | 寿险保单相关表（★V13） | 13张 |
| `ins_order_04_order_claim_common.sql` | 订单主表、理赔、附件、导入/导出等通用表 | 12张 |

**执行顺序**：先创建数据库，再依次执行以上4个SQL文件。

---

## 二、数据库总览（33张表）

### 📋 车险保单（4张表）

| 表名 | 说明 |
|------|------|
| `ins_order_policy_car` | 车险保单主表（交强险/商业险/交+商，含手工录入和直连出单） |
| `ins_order_policy_car_coverage` | 车险商业险险别明细表（车损险/三者险/座人险等） |
| `ins_order_policy_car_endorsement` | 车险批改单表（增保/减保/变更标的） |
| `ins_order_car_renewal` | 车险续保记录追踪表 |

### 📋 非车险保单（4张表）

| 表名 | 说明 |
|------|------|
| `ins_order_policy_non_car` | 非车险保单主表（含险种/标的/互联网/涉农/共保标识，支持extra_fields自定义字段） |
| `ins_order_policy_non_car_insured` | 非车险被保人/关系人子表 |
| `ins_order_policy_non_car_co_insurer` | 非车险共保信息子表 |
| `ins_order_non_car_field_config` | 非车险保单字段自定义配置表 |

### 📋 寿险保单（13张表，★V13）

| 表名 | 说明 |
|------|------|
| `ins_order_policy_life` | 寿险保单主表（个险/团险，含完整状态机：PAYING→ACTIVE→LAPSED等） |
| `ins_order_policy_life_coverage` | 寿险保单险种明细（主险+附加险） |
| `ins_order_policy_life_insured` | 寿险被保人/受益人表（AES-256加密存储证件号） |
| `ins_order_policy_life_group_member` | 寿险团险被保人名册表 |
| `ins_order_life_receipt` | 寿险保单回执记录表（对应PDF-116） |
| `ins_order_life_visit_record` | 寿险回访记录表（对应PDF-117~119） |
| `ins_order_life_conservation` | 寿险保全申请表（变更受益人/减保/复效等，含Flowable审批流） |
| `ins_order_life_orphan` | 寿险孤儿单表（业务员离职后保单池） |
| `ins_order_life_orphan_log` | 寿险孤儿单分配轨迹表（含收益继承比例） |
| `ins_order_life_status_log` | 寿险保单状态变更日志 |
| `ins_order_life_change_log` | 寿险保单字段修改日志（含审批） |
| `ins_order_life_reconcile` | 寿险保单核对记录表（与保司数据比对，对应PDF-114） |
| `ins_order_life_renewal_remind` | 寿险续期缴费提醒记录表（防重复发送） |

### 📋 订单/理赔/通用（12张表）

| 表名 | 说明 |
|------|------|
| `ins_order_main` | 订单主表（C端投保产生，覆盖三大险种，含优惠券/积分抵扣） |
| `ins_order_insurance_apply` | 投保申请单表（C端投保中间状态，支持断点续填） |
| `ins_order_life_draft` | 寿险投保草稿表（C端分步填写，断点续填，24小时过期） |
| `ins_order_claim_record` | 理赔案件主表（寿险/非车险/C端通用） |
| `ins_order_claim_follow_record` | 理赔跟进记录表 |
| `ins_order_claim_material_template` | 理赔材料模板配置表 |
| `ins_order_claim_material` | 理赔材料上传记录表 |
| `ins_order_policy_attachment` | 保单附件表（影像件，通用三大险种） |
| `ins_order_import_log` | 批量导入日志表（EasyExcel，各险种保单批量导入） |
| `ins_order_export_task` | 异步导出任务表（大数据量导出，通用） |
| `ins_order_policy_verify_log` | 保单验真日志表（C端保单验真） |
| `ins_order_payment_record` | 支付记录表（订单支付流水） |

---

## 三、设计关键决策说明

### 3.1 表前缀统一使用 `ins_order_`
区别于其他模块（如 `ins_product_`、`ins_crm_`），便于跨库查询时识别来源模块。

### 3.2 寿险保单状态机（完整）
`ins_order_policy_life.policy_status` 字段使用字符串枚举值，而非数字，提高可读性：

```
PAYING → UNDERWRITING → ACTIVE
ACTIVE → OVERDUE → LAPSED（超宽限期）
ACTIVE → WAITING_CONDITION_CONFIRM → ACTIVE / CANCELLED
ACTIVE → SUSPENDED → ACTIVE（复效）
ACTIVE → TERMINATED / REJECTED / CANCELLED / MATURED
```

### 3.3 敏感信息加密存储
证件号（id_no）、手机号（phone）字段均在应用层加密后存库（AES-256），查询时服务端解密后脱敏返回，DB层不存明文。

### 3.4 非车险自定义字段 extra_fields
`ins_order_policy_non_car.extra_fields`（JSON列）存储各险种配置的自定义字段值，配合 `ins_order_non_car_field_config` 动态渲染表单，避免频繁DDL。

### 3.5 批改单设计
- 车险：独立批改单表 `ins_order_policy_car_endorsement`，通过 `policy_id` 关联原保单。
- 非车险：批改保单复用 `ins_order_policy_non_car` 主表，通过 `original_policy_no` + `policy_status=3` 区分批改记录。

### 3.6 孤儿单收益继承比例
`ins_order_life_orphan.inherit_ratio` 和 `ins_order_life_orphan_log.inherit_ratio` 均存储分配时设置的收益继承比例（%），该值会传递给佣金模块影响后续佣金计算。

### 3.7 导出任务异步化
所有超过5000条数据的导出均走 `ins_order_export_task` 异步任务表：前端提交导出 → 后端异步处理 → 完成后OSS存文件 → 站内信/任务列表通知用户下载。

---

## 四、关联模块说明

| 关联模块 | 关联方式 |
|----------|----------|
| `intermediary-module-ins-product`（产品中台） | 通过 `product_id` 关联产品信息 |
| `intermediary-module-ins-commission`（佣金中台） | 保单写入后发MQ触发佣金计算（`InsOrderProducer`） |
| `intermediary-module-ins-crm`（客户CRM） | 通过 `customer_id` 关联客户档案 |
| `intermediary-module-system`（系统模块） | 通过 `agent_id/user_id` 关联业务员/用户，`org_id` 关联机构 |
| `intermediary-module-pay`（支付模块） | 通过 `order_id` 关联订单支付流水 |

---

## 五、索引设计原则

1. **主键**：统一使用BIGINT自增主键
2. **唯一索引**：保单号+租户+保司的联合唯一约束，防止重复录单
3. **业务查询索引**：业务员ID、机构ID、状态、日期范围等高频查询字段
4. **加密字段**：cert_no（证件号）索引对加密后的密文建索引（支持精确查询）
5. **软删除**：统一使用 `deleted` 字段，deleted=1为已删除

---

## 六、XXL-Job 定时任务清单

| 任务名称 | 执行时间 | 说明 |
|---------|---------|------|
| `CarRenewalReminderJob` | 每天 09:00 | 车险到期续保提醒 |
| `LifeOrphanDetectJob` | 每天 01:00 | 扫描当天离职业务员，将其保单入孤儿单池 |
| `LifePolicyRenewalReminderJob` | 每天 09:00 | 寿险续期缴费提醒（30/15/7/1天及逾期节点） |
| `LifePolicyLapsedJob` | 每天 02:00 | 扫描超宽限期未缴费保单，状态变更为LAPSED |
| `InsLifeOrderDraftCleanJob` | 每天 02:00 | 清理24小时过期未完成的投保草稿 |
| `InsOrderExpireJob` | 每5分钟 | 扫描过期未支付订单，状态变更为EXPIRED |

---

## 七、MQ 消息清单

| 消息Topic | 触发时机 | 消费方 |
|-----------|---------|--------|
| `ins_order_policy_created` | 保单成功录入/C端投保支付完成 | 佣金模块（触发佣金计算） |
| `ins_order_car_endorsement_created` | 车险批改单创建 | 佣金模块（触发佣金调整） |
| `ins_order_life_orphan_assigned` | 孤儿单分配完成 | 佣金模块（更新收益继承） |
| `ins_order_life_renewal_paid` | 寿险续期缴费成功 | 保单模块（更新next_payment_date） |
| `ins_order_claim_settled` | 寿险死亡理赔结案 | 保单模块（联动保单状态变LAPSED） |

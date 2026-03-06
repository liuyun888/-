# intermediary-module-ins-finance 财务中台模块
## 数据库表结构设计说明文档

> **数据库**：`db_ins_finance`
> **表前缀**：`ins_fin_`
> **框架**：yudao-cloud (Spring Cloud Alibaba + MyBatis-Plus)
> **版本**：V1.0 | 2026-03-01

---

## 一、文件清单

| 文件 | 内容 | 表数量 |
|------|------|--------|
| `db_ins_finance_part1_reconcile.sql` | 自动对账模块（导入批次、明细、差异、上游结算、合格结算系列） | 11张 |
| `db_ins_finance_part2_settlement_tax.sql` | 结算管理 + 税务管理 + 监管报表 + 报表归档 | 11张 |
| `db_ins_finance_part3_template_bi.sql` | 导出模板配置 + BI报表配置 + 初始化数据 | 5张 |

**合计：27张表**（含初始化数据脚本）

---

## 二、表清单总览

### Part 1 — 自动对账模块

| 序号 | 表名 | 对应DO | 业务说明 |
|------|------|--------|---------|
| 1 | `ins_fin_import_batch` | `InsReconcileTaskDO` | 保司Excel导入批次（含匹配进度） |
| 2 | `ins_fin_import_detail` | - | 导入明细（逐条保单数据，记录匹配状态） |
| 3 | `ins_fin_reconcile_diff` | `InsReconcileDiffDO` | 差异记录（保费/佣金/日期差异，人工处理） |
| 4 | `ins_fin_upstream_settle` | `InsUpstreamSettleDO` | 上游结算主表（按保司聚合，需审批） |
| 5 | `ins_fin_upstream_settle_detail` | - | 上游结算明细（每条保单的结算数据） |
| 6 | `ins_fin_qualify_rule_config` | - | 合格认定规则配置（触发保单自动合格的条件） |
| 7 | `ins_fin_qualify_record` | - | 合格认定审计记录（合格/撤销操作轨迹） |
| 8 | `ins_fin_reconcile_bill` | - | 合格对账单主表（按保司+周期汇总） |
| 9 | `ins_fin_reconcile_bill_detail` | - | 合格对账单明细（每条保单手续费） |
| 10 | `ins_fin_reconcile_diff_amount` | - | 对账差额记录（实际到账差额标注） |
| 11 | `ins_fin_qualified_order` | `InsQualifiedOrderDO` | 上游手续费跟单队列（无费率保单暂挂） |

### Part 2 — 结算管理 + 税务管理 + 监管报表

| 序号 | 表名 | 对应DO | 业务说明 |
|------|------|--------|---------|
| 12 | `ins_fin_settlement` | `InsSettlementDO` | 结算单主表（业务员月度佣金结算，含审核流） |
| 13 | `ins_fin_settlement_detail` | - | 结算单明细（每张保单的佣金明细） |
| 14 | `ins_fin_payment_batch` | - | 打款批次表（批量发起打款） |
| 15 | `ins_fin_payment_detail` | - | 打款明细（每张结算单的打款结果） |
| 16 | `ins_fin_invoice` | - | 发票管理（开票申请，支持电子发票API） |
| 17 | `ins_fin_tax_record` | `InsTaxRecordDO` | 个税计算记录（劳务报酬预扣率法） |
| 18 | `ins_fin_tax_declare_batch` | - | 税务申报批次（月度代扣个税申报文件） |
| 19 | `ins_fin_tax_certificate` | - | 完税证明（月度/年度PDF，可邮件发送） |
| 20 | `ins_fin_regulatory_ledger` | - | 监管业务台账（按月生成，标记上报） |
| 21 | `ins_fin_regulatory_report` | - | 监管API上报记录（含请求响应报文） |
| 22 | `ins_fin_report_archive` | - | 报表归档管理（OSS加锁，保存7年） |

### Part 3 — 导出模板 + BI配置

| 序号 | 表名 | 对应DO | 业务说明 |
|------|------|--------|---------|
| 23 | `ins_fin_export_template` | `InsExportTemplateDO` | 导出模板主表（车险/非车险字段模板） |
| 24 | `ins_fin_export_template_field` | - | 模板字段配置（列名/顺序/格式） |
| 25 | `ins_fin_export_field_config` | - | 字段元数据字典（后端预置全量可选字段） |
| 26 | `ins_fin_export_history` | - | 导出历史记录（含文件路径和过期时间） |
| 27 | `ins_fin_bi_report_config` | - | BI自定义报表配置（用户保存的查询参数） |

---

## 三、核心业务流程与表关联

### 3.1 自动对账流程

```
[导入Excel]
    → ins_fin_import_batch（批次）
    → ins_fin_import_detail（明细，match_status=0未匹配）
    → [智能匹配Job]
    → match_status=1精确/2模糊(差异)/3无法匹配
    → 差异写 ins_fin_reconcile_diff（process_status=0待处理）
    → [人工处理差异] → process_status=1已处理/2已忽略
    → batch全部处理完 → status=2完成（可生成结算单）
```

### 3.2 结算审核流程（Activiti）

```
ins_fin_settlement（status=0待审核）
    → 提交审核 → status=1审核中（创建Activiti流程，记录 process_inst_id）
    → 审核通过 → status=2审核通过
    → 申请开票 → ins_fin_invoice（status=0待开具）
    → 发起打款 → ins_fin_payment_batch + ins_fin_payment_detail
    → 打款成功 → settlement.status=4已打款，paid_time 回填
```

### 3.3 合格结算流程（FN-05）

```
保单录入
    → [自动认定规则扫描] ins_fin_qualify_rule_config
    → 写 ins_fin_qualify_record（qualify_status=QUALIFIED）
    → 生成 ins_fin_reconcile_bill（对账单）
    → ins_fin_reconcile_bill_detail（明细）
    → 确认到账 → bill_status=CONFIRMED/SETTLED
```

### 3.4 跟单队列流程（FN-02）

```
保单导入时 upstream_rate IS NULL
    → 插入 ins_fin_qualified_order（pending_status=PENDING_RATE）
    → [每日超期告警Job] 扫描 is_expired=0 且超期 → 更新 is_expired=1 → 推送告警
    → 财务填入手续费 → pending_status=SETTLED
    → 进入正常结算流程
    
    也可 → 标记跳过 → pending_status=SKIP_CURRENT_PERIOD
```

---

## 四、与工程结构文档的对应关系

| 工程结构文档中的DO | 实际数据库表 |
|-------------------|-------------|
| `InsReconcileTaskDO` | `ins_fin_import_batch`（对账任务即导入批次） |
| `InsReconcileDiffDO` | `ins_fin_reconcile_diff` |
| `InsSettlementDO` | `ins_fin_settlement` |
| `InsTaxRecordDO` | `ins_fin_tax_record` |
| `InsUpstreamSettleDO` | `ins_fin_upstream_settle` |
| `InsQualifiedOrderDO` | `ins_fin_qualified_order` |
| `InsExportTemplateDO` | `ins_fin_export_template` |

---

## 五、注意事项

1. **敏感数据加密**：`ins_fin_regulatory_report` 的 `request_body`/`response_body` 字段需在应用层AES加密后入库（监管报文含企业敏感数据）。

2. **身份证号脱敏**：`ins_fin_tax_record.id_card_no` 建议入库前脱敏处理（保留前3后4位），在税务申报文件生成时使用原始值（从业务员用户表加解密获取）。

3. **银行卡号脱敏**：`ins_fin_payment_detail.bank_card_no` 展示时脱敏（保留后4位），数据库存原始加密值。

4. **OSS文件锁定**：`ins_fin_report_archive` 中 `is_locked=1` 的文件，需在OSS控制台启用 Object Lock，防止误删，保存期限7年。

5. **Activiti流程**：结算单审核集成 yudao-cloud 内置的 `bpm` 模块，`process_inst_id` 关联流程实例，请确保 BPM 模块已部署。

6. **分布式序号**：批次号（IMP/SET/PAY/TAX/RPT等）使用 Redis INCR 保证唯一，key格式：`ins:finance:seq:{类型}:{yyyyMMdd}`，每日重置。

7. **定时任务（XXL-Job）**：
   - `InsAutoReconcileJob`：触发智能匹配（MQ异步）
   - `InsTaxCalculateJob`：每月5日凌晨2点自动生成上月结算单+个税
   - `InsQualifiedOrderAlertJob`：每日凌晨1点扫描跟单超期（默认45天）

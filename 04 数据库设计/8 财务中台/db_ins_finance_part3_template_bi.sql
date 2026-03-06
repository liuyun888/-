-- ==========================================================
-- 保险中介平台 · 财务中台模块（intermediary-module-ins-finance）
-- 数据库：db_ins_finance
-- 表前缀：ins_fin_
-- Part 3：导出模板配置 + BI经营报表配置 + 数据字典 + 说明
-- 涉及文档：阶段6-财务中台-合格结算补充_业务需求设计_中篇
-- 作者：架构设计 by AI | 框架：yudao-cloud（Spring Cloud Alibaba）
-- 生成时间：2026-03-01
-- ==========================================================

USE `db_ins_finance`;

-- ================================================================
-- ================ 导出模板配置模块（FN-03/FN-04）================
-- ================================================================

-- ----------------------------------------------------------
-- 1. 导出模板主表（ins_fin_export_template）
--    对应：InsExportTemplateDO（工程结构文档）
--    业务：车险/非车险保单导出模板配置，支持自定义列字段和顺序
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_export_template` (
  `id`                    BIGINT       NOT NULL AUTO_INCREMENT                    COMMENT '主键ID',
  `template_code`         VARCHAR(64)  NOT NULL                                   COMMENT '模板编码（UUID，系统自动生成）',
  `template_name`         VARCHAR(100) NOT NULL                                   COMMENT '模板名称（如"平安车险标准导出模板"）',
  `template_type`         VARCHAR(32)  NOT NULL                                   COMMENT '模板类型：CAR_INSURANCE/NON_CAR_INSURANCE',
  `insurer_codes`         VARCHAR(500) DEFAULT NULL                               COMMENT '适用保司编码，逗号分隔；NULL=全部保司',
  `org_ids`               VARCHAR(500) DEFAULT NULL                               COMMENT '授权组织ID，逗号分隔；NULL=全部组织',
  `insurance_categories`  VARCHAR(200) DEFAULT NULL                               COMMENT '适用险种大类（非车专用），逗号分隔',
  `remark`                VARCHAR(500) DEFAULT NULL                               COMMENT '模板说明',
  `status`                TINYINT(1)   NOT NULL DEFAULT 1                         COMMENT '状态：1启用 0禁用',
  `version`               INT          NOT NULL DEFAULT 1                         COMMENT '版本号（每次编辑自增）',
  `creator`               BIGINT       NOT NULL                                   COMMENT '创建人ID',
  `create_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP         COMMENT '创建时间',
  `updater`               BIGINT       DEFAULT NULL                               COMMENT '更新人ID',
  `update_time`           DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP   COMMENT '更新时间',
  `deleted`               TINYINT(1)   NOT NULL DEFAULT 0                         COMMENT '逻辑删除',
  `tenant_id`             BIGINT       NOT NULL DEFAULT 0                         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_type_name` (`template_type`, `template_name`, `deleted`),
  KEY `idx_template_type` (`template_type`, `status`),
  KEY `idx_creator` (`creator`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='导出模板主表（车险/非车险保单导出字段模板，支持自定义列顺序和内容）';


-- ----------------------------------------------------------
-- 2. 导出模板字段配置表（ins_fin_export_template_field）
--    业务：模板下每个输出字段的配置（列名/排序/格式化规则）
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_export_template_field` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT                            COMMENT '主键ID',
  `template_id`   BIGINT       NOT NULL                                           COMMENT '模板ID（关联 ins_fin_export_template.id）',
  `field_code`    VARCHAR(64)  NOT NULL                                           COMMENT '字段编码（与导出数据映射用，如 policy_no/premium）',
  `field_name`    VARCHAR(100) NOT NULL                                           COMMENT '列头显示名称（Excel中展示的列名）',
  `field_order`   INT          NOT NULL DEFAULT 0                                 COMMENT '列顺序（从1开始，决定Excel列位置）',
  `is_required`   TINYINT(1)   NOT NULL DEFAULT 0                                 COMMENT '是否必含字段（1=不可从模板移除的系统必要字段）',
  `format_rule`   VARCHAR(200) DEFAULT NULL                                       COMMENT '格式化规则（如日期格式 yyyy-MM-dd、数字精度 2位小数等）',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP                 COMMENT '创建时间',
  `deleted`       TINYINT(1)   NOT NULL DEFAULT 0                                 COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  KEY `idx_template_id` (`template_id`),
  UNIQUE KEY `uk_template_field` (`template_id`, `field_code`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='导出模板字段配置表（模板下每列字段的名称、顺序和格式化规则）';


-- ----------------------------------------------------------
-- 3. 导出字段元数据配置表（ins_fin_export_field_config）
--    业务：系统维护的全量可映射字段字典（后端维护，前端选择字段时展示）
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_export_field_config` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `template_type`   VARCHAR(32)  NOT NULL                                         COMMENT '适用模板类型：CAR_INSURANCE/NON_CAR_INSURANCE',
  `field_group`     VARCHAR(64)  NOT NULL                                         COMMENT '字段分组（基本信息/车辆信息/被保人信息/佣金信息等）',
  `field_code`      VARCHAR(64)  NOT NULL                                         COMMENT '字段编码（唯一，用于映射数据库字段）',
  `field_name`      VARCHAR(100) NOT NULL                                         COMMENT '字段显示名称（前端展示）',
  `db_mapping`      VARCHAR(200) NOT NULL                                         COMMENT '数据库字段映射（格式：表名.字段名 或 SQL表达式）',
  `default_format`  VARCHAR(100) DEFAULT NULL                                     COMMENT '默认格式化规则（如 yyyy-MM-dd）',
  `sort_order`      INT          NOT NULL DEFAULT 0                               COMMENT '同组内默认排序',
  `is_system`       TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '是否系统内置字段（1=系统必含字段，不可删除）',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_type_code` (`template_type`, `field_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='导出字段元数据配置表（系统维护的全量可选字段字典，由后端预置，前端拖拽选择）';


-- ----------------------------------------------------------
-- 4. 保单导出历史记录表（ins_fin_export_history）
--    业务：记录每次用模板导出的操作历史，含文件路径和有效期
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_export_history` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT                            COMMENT '主键ID',
  `template_id`   BIGINT       NOT NULL                                           COMMENT '使用的模板ID',
  `template_name` VARCHAR(100) NOT NULL                                           COMMENT '模板名称（快照，防止模板更改后历史无法显示）',
  `template_type` VARCHAR(32)  NOT NULL                                           COMMENT '模板类型（CAR_INSURANCE/NON_CAR_INSURANCE）',
  `file_name`     VARCHAR(200) NOT NULL                                           COMMENT '导出文件名（含扩展名）',
  `file_path`     VARCHAR(500) DEFAULT NULL                                       COMMENT '文件存储路径（OSS路径）',
  `export_count`  INT          NOT NULL DEFAULT 0                                 COMMENT '导出保单条数',
  `query_params`  TEXT         DEFAULT NULL                                       COMMENT '导出时的查询条件快照（JSON格式）',
  `status`        VARCHAR(20)  NOT NULL DEFAULT 'PROCESSING'                      COMMENT '状态：PROCESSING/SUCCESS/FAILED',
  `error_msg`     VARCHAR(500) DEFAULT NULL                                       COMMENT '失败原因',
  `expire_time`   DATETIME     DEFAULT NULL                                       COMMENT '文件下载链接过期时间（默认生成后24小时）',
  `operator`      BIGINT       NOT NULL                                           COMMENT '操作人ID',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP                 COMMENT '创建时间',
  `update_time`   DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP           COMMENT '更新时间',
  `deleted`       TINYINT(1)   NOT NULL DEFAULT 0                                 COMMENT '逻辑删除',
  `tenant_id`     BIGINT       NOT NULL DEFAULT 0                                 COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_operator_time` (`operator`, `create_time`),
  KEY `idx_template_id` (`template_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='保单导出历史记录表（每次用模板导出保单的操作记录，支持重新下载）';


-- ================================================================
-- =================== BI经营报表配置模块 =========================
-- ================================================================

-- ----------------------------------------------------------
-- 5. 自定义报表配置表（ins_fin_bi_report_config）
--    业务：BI经营报表 → 自定义报表，业务员/管理员保存的报表查询配置
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_bi_report_config` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `report_name`     VARCHAR(100) NOT NULL                                         COMMENT '报表名称（用户自定义）',
  `report_type`     VARCHAR(50)  NOT NULL                                         COMMENT '报表类型（PREMIUM/COMMISSION/AGENT/CHANNEL等）',
  `query_params`    TEXT         NOT NULL                                         COMMENT '查询条件配置（JSON：维度/指标/筛选条件/时间范围）',
  `chart_type`      VARCHAR(30)  DEFAULT NULL                                     COMMENT '图表类型（BAR/LINE/PIE/TABLE）',
  `is_shared`       TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '是否共享给全员（0仅自己 1全员可见）',
  `creator`         BIGINT       NOT NULL                                         COMMENT '创建人ID（报表归属人）',
  `creator_name`    VARCHAR(50)  DEFAULT NULL                                     COMMENT '创建人姓名（快照）',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `updater`         BIGINT       DEFAULT NULL                                     COMMENT '更新人',
  `update_time`     DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP         COMMENT '更新时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '逻辑删除',
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_creator` (`creator`),
  KEY `idx_report_type` (`report_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='自定义报表配置表（用户保存的BI报表查询条件和图表配置，可分享）';


-- ================================================================
-- =================== 数据字典说明（ENUM枚举参考）================
-- ================================================================

-- ----------------------------------------------------------
-- 备注：以下为本模块所有状态字段的枚举说明，
-- 建议在 yudao-cloud 的 sys_dict_type/sys_dict_data 中维护
-- ----------------------------------------------------------

/*
── 对账批次状态（import_batch_status）─────────────────
0=待处理, 1=处理中, 2=完成, 3=失败, 4=部分失败

── 匹配状态（match_status）─────────────────────────────
0=未匹配, 1=精确匹配, 2=模糊匹配(含差异), 3=无法匹配

── 差异处理状态（diff_process_status）──────────────────
0=待处理, 1=已处理, 2=已忽略

── 差异处理方式（diff_process_action）──────────────────
USE_SYSTEM=以系统数据为准, USE_IMPORT=以保险公司数据为准,
MANUAL_INPUT=手动输入修正值, IGNORE=忽略此差异

── 上游结算状态（upstream_settle_status）───────────────
PENDING_APPROVE=待审批, APPROVED=审批通过,
SETTLED=已结算, REJECTED=审批驳回

── 合格认定状态（qualify_status）───────────────────────
QUALIFIED=已合格, CANCELLED=已撤销

── 合格对账单状态（bill_status）────────────────────────
GENERATED=已生成, CONFIRMED=已确认到账,
SETTLED=已结算(终态), UPDATED=已更新(需重新确认)

── 跟单队列状态（pending_status）───────────────────────
PENDING_RATE=待确认费率, SKIP_CURRENT_PERIOD=跳过本期, SETTLED=已结算

── 结算单状态（settlement_status）──────────────────────
0=待审核, 1=审核中, 2=审核通过, 3=审核驳回, 4=已打款, 5=已作废

── 发票类型（invoice_type）─────────────────────────────
1=增值税专票, 2=增值税普票, 3=收据

── 发票状态（invoice_status）───────────────────────────
0=待开具, 1=开具中, 2=已开具, 3=已作废

── 打款方式（pay_type）─────────────────────────────────
0=批量文件导出(人工上传银行), 1=API自动打款

── 打款状态（payment_status）───────────────────────────
0=待打款, 1=打款中, 2=已打款, 3=打款失败

── 个税计算类型（calc_type）────────────────────────────
0=系统自动计算, 1=财务人工调整

── 税务申报状态（declare_status）───────────────────────
0=待申报, 1=申报中, 2=已申报

── 完税证明类型（cert_type）────────────────────────────
0=月度证明, 1=年度汇总证明

── 导出任务状态（export_status）────────────────────────
PROCESSING=处理中, SUCCESS=成功, FAILED=失败

── 归档方式（archive_type）─────────────────────────────
0=手动归档, 1=自动归档

── 监管台账状态（ledger_status）────────────────────────
0=待生成, 1=已生成, 2=已上报

── 上报状态（report_status）────────────────────────────
0=待上报, 1=上报中, 2=成功, 3=失败, 4=部分成功

── 个税预扣率表（劳务报酬所得，2024年）────────────────
每次收入额 ≤ 4000元：收入额 = 收入 - 800（定额扣除）
每次收入额 > 4000元：收入额 = 收入 × (1-20%)（比例扣除）
收入额 ≤ 20000：税率20%，速算扣除数0
收入额 20001~50000：税率30%，速算扣除数2000
收入额 > 50000：税率40%，速算扣除数7000
*/


-- ================================================================
-- =================== 索引设计说明 ================================
-- ================================================================

/*
性能优化说明（关键查询场景）：

1. ins_fin_import_batch
   - 高频：财务按月份+保司查询对账批次 → idx_insurer_month
   - 高频：按状态筛选批次 → idx_status

2. ins_fin_import_detail
   - 高频：按批次查明细（分页，可达万级数据）→ idx_batch_id + match_status 联合
   - 分析：按系统订单反查 → idx_system_order

3. ins_fin_reconcile_diff
   - 高频：查待处理差异（财务每日处理）→ idx_process_status
   - 高频：按批次汇总差异 → idx_batch_id

4. ins_fin_qualified_order（跟单队列）
   - 每日告警任务扫描超期 → idx_is_expired (is_expired, pending_status)
   - 高频：按保司+状态筛选 → idx_insurer_status

5. ins_fin_settlement
   - 高频：按月份+状态生成报表 → idx_settle_month + idx_status
   - 高频：业务员查自己的结算单 → idx_agent_month

6. ins_fin_tax_record
   - 税务申报查询：按月份查所有业务员个税 → idx_settle_month
   - 业务员查个人：→ idx_agent_month

7. 分库分表建议：
   - ins_fin_import_detail 当数据量超500万行时，建议按 reconcile_month（YYYY-MM）进行分表
   - ins_fin_settlement_detail 按 settle_month 分表

8. 数据归档策略：
   - ins_fin_import_detail、ins_fin_settlement_detail 超过2年的历史数据
     定期归档到历史库（finance_history），保持主库性能
*/


-- ================================================================
-- =================== 初始化基础数据 ==============================
-- ================================================================

-- 合格认定规则-初始化默认规则（系统预置）
INSERT INTO `ins_fin_qualify_rule_config`
  (`rule_code`, `rule_name`, `rule_desc`, `is_enabled`, `rule_params`, `sort_order`)
VALUES
  ('PREMIUM_PAID',      '保费实收',       '保单对应保费已全额到账（payment_status=PAID）',              1, NULL,                1),
  ('WAITING_PERIOD',    '等待期满',       '保单已过等待期（从承保日起，等待期天数可配置）',               1, '{"days": 15}',      2),
  ('NO_SURRENDER',      '未退保',         '保单未发生退保（policy_status != SURRENDER）',               1, NULL,                3),
  ('POLICY_VALID',      '保单有效',       '保单当前状态为有效（policy_status = VALID）',                 1, NULL,                4),
  ('MANUAL_IMPORT',     '手动导入合格',   '财务手动批量导入合格名单触发（不受以上规则约束）',            1, NULL,                99);

-- 车险导出字段元数据-初始化基础字段
INSERT INTO `ins_fin_export_field_config`
  (`template_type`, `field_group`, `field_code`, `field_name`, `db_mapping`, `sort_order`, `is_system`)
VALUES
  ('CAR_INSURANCE', '基本信息', 'policy_no',        '保单号',       'ins_car_policy.policy_no',           1,  1),
  ('CAR_INSURANCE', '基本信息', 'insurer_name',     '保险公司',     'ins_insurer.insurer_name',           2,  1),
  ('CAR_INSURANCE', '基本信息', 'agent_name',       '业务员姓名',   'sys_user.nickname',                  3,  1),
  ('CAR_INSURANCE', '基本信息', 'sign_date',        '签单日期',     'ins_car_policy.sign_date',           4,  0),
  ('CAR_INSURANCE', '车辆信息', 'plate_no',         '车牌号',       'ins_car_policy.plate_no',            5,  0),
  ('CAR_INSURANCE', '车辆信息', 'vin',              '车架号(VIN)',  'ins_car_policy.vin',                 6,  0),
  ('CAR_INSURANCE', '车辆信息', 'car_model',        '车型',         'ins_car_policy.car_model',           7,  0),
  ('CAR_INSURANCE', '被保人',   'insured_name',     '被保人姓名',   'ins_car_policy.insured_name',        8,  0),
  ('CAR_INSURANCE', '保费佣金', 'premium',          '保费(元)',     'ins_car_policy.premium',             9,  1),
  ('CAR_INSURANCE', '保费佣金', 'commission_rate',  '佣金率(%)',    'ins_car_policy.commission_rate',    10,  0),
  ('CAR_INSURANCE', '保费佣金', 'commission_amount','佣金金额(元)','ins_car_policy.commission_amount',  11,  0),
  ('CAR_INSURANCE', '保费佣金', 'upstream_rate',    '上游手续费率', 'ins_car_policy.upstream_rate',      12,  0),
  ('NON_CAR_INSURANCE', '基本信息', 'policy_no',    '保单号',       'ins_non_car_policy.policy_no',       1,  1),
  ('NON_CAR_INSURANCE', '基本信息', 'insurer_name', '保险公司',     'ins_insurer.insurer_name',           2,  1),
  ('NON_CAR_INSURANCE', '基本信息', 'product_name', '产品名称',     'ins_non_car_policy.product_name',    3,  0),
  ('NON_CAR_INSURANCE', '基本信息', 'insurance_type','险种类别',    'ins_non_car_policy.insurance_type',  4,  0),
  ('NON_CAR_INSURANCE', '被保人',   'insured_name', '被保人姓名',   'ins_non_car_policy.insured_name',    5,  0),
  ('NON_CAR_INSURANCE', '保费佣金', 'premium',      '保费(元)',     'ins_non_car_policy.premium',         6,  1),
  ('NON_CAR_INSURANCE', '保费佣金', 'commission_amount','佣金(元)', 'ins_non_car_policy.commission_amount',7,0);

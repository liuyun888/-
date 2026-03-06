-- ==========================================================
-- 保险中介平台 · 财务中台模块（intermediary-module-ins-finance）
-- 数据库：db_ins_finance
-- 表前缀：ins_fin_
-- Part 1：自动对账模块（Auto Reconcile）
-- 涉及文档：阶段6-财务中台详细需求设计文档_上_、
--           阶段6-财务中台-合格结算补充_业务需求设计_上/中/下篇
-- 作者：架构设计 by AI | 框架：yudao-cloud（Spring Cloud Alibaba）
-- 生成时间：2026-03-01
-- ==========================================================

CREATE DATABASE IF NOT EXISTS `db_ins_finance`
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE `db_ins_finance`;

-- ----------------------------------------------------------
-- 1. 导入批次表（ins_fin_import_batch）
--    对应：InsReconcileTaskDO（工程结构文档中 InsReconcileTaskDO）
--    业务：财务 → 自动对账 → 保单导入，记录每次Excel导入批次
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_import_batch` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `batch_no`        VARCHAR(30)  NOT NULL                                         COMMENT '批次号（IMP+yyyyMMdd+4位序号，如IMP202501150001）',
  `insurer_id`      BIGINT       NOT NULL                                         COMMENT '保险公司ID（关联 sys_insurer.id）',
  `insurer_name`    VARCHAR(100) NOT NULL                                         COMMENT '保险公司名称（冗余快照）',
  `reconcile_month` VARCHAR(7)   NOT NULL                                         COMMENT '对账月份（YYYY-MM）',
  `file_name`       VARCHAR(200) DEFAULT NULL                                     COMMENT '原始上传文件名',
  `file_url`        VARCHAR(500) DEFAULT NULL                                     COMMENT 'OSS文件路径（finance/reconciliation/import/年/月/批次号.xlsx）',
  `total_count`     INT          NOT NULL DEFAULT 0                               COMMENT '导入总条数',
  `success_count`   INT          NOT NULL DEFAULT 0                               COMMENT '解析成功条数',
  `fail_count`      INT          NOT NULL DEFAULT 0                               COMMENT '解析失败条数',
  `match_count`     INT          NOT NULL DEFAULT 0                               COMMENT '智能匹配成功数（含精确+模糊）',
  `diff_count`      INT          NOT NULL DEFAULT 0                               COMMENT '差异记录数',
  `unmatch_count`   INT          NOT NULL DEFAULT 0                               COMMENT '无法匹配数',
  `status`          TINYINT      NOT NULL DEFAULT 0                               COMMENT '状态：0待处理 1处理中 2完成 3失败 4部分失败',
  `error_msg`       VARCHAR(500) DEFAULT NULL                                     COMMENT '失败原因',
  `remark`          VARCHAR(200) DEFAULT NULL                                     COMMENT '备注（最多200字）',
  `creator`         BIGINT       DEFAULT NULL                                     COMMENT '创建人（操作员ID）',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `updater`         BIGINT       DEFAULT NULL                                     COMMENT '最后更新人',
  `update_time`     DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP         COMMENT '最后更新时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '逻辑删除（0正常 1删除）',
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`),
  KEY `idx_insurer_month` (`insurer_id`, `reconcile_month`),
  KEY `idx_status` (`status`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='财务对账-导入批次表（每次Excel上传为一个批次）';


-- ----------------------------------------------------------
-- 2. 导入明细表（ins_fin_import_detail）
--    业务：保险公司下发的逐条保单明细，智能匹配后记录匹配状态
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_import_detail` (
  `id`                  BIGINT       NOT NULL AUTO_INCREMENT                      COMMENT '主键ID',
  `batch_id`            BIGINT       NOT NULL                                     COMMENT '批次ID（关联 ins_fin_import_batch.id）',
  `batch_no`            VARCHAR(30)  NOT NULL                                     COMMENT '批次号（冗余，便于查询）',
  `insurer_id`          BIGINT       NOT NULL                                     COMMENT '保险公司ID',
  `insurer_policy_no`   VARCHAR(50)  DEFAULT NULL                                 COMMENT '保险公司保单号',
  `insurer_batch_no`    VARCHAR(50)  DEFAULT NULL                                 COMMENT '保险公司内部批次号',
  `policy_holder_name`  VARCHAR(50)  DEFAULT NULL                                 COMMENT '投保人姓名',
  `id_card_no`          VARCHAR(20)  DEFAULT NULL                                 COMMENT '投保人身份证号（脱敏存储）',
  `mobile`              VARCHAR(20)  DEFAULT NULL                                 COMMENT '投保人手机号（脱敏存储）',
  `product_type`        VARCHAR(50)  DEFAULT NULL                                 COMMENT '险种类型',
  `premium`             DECIMAL(12,2) DEFAULT NULL                                COMMENT '保费金额（元）',
  `commission_rate`     DECIMAL(6,4) DEFAULT NULL                                 COMMENT '佣金率（如0.1200=12%）',
  `commission_amount`   DECIMAL(12,2) DEFAULT NULL                                COMMENT '佣金金额（元）',
  `start_date`          DATE         DEFAULT NULL                                 COMMENT '起保日期',
  `end_date`            DATE         DEFAULT NULL                                 COMMENT '终保日期',
  `match_status`        TINYINT      NOT NULL DEFAULT 0                           COMMENT '匹配状态：0未匹配 1精确匹配 2模糊匹配（含差异） 3无法匹配',
  `system_order_id`     BIGINT       DEFAULT NULL                                 COMMENT '匹配到的系统订单ID',
  `system_policy_no`    VARCHAR(50)  DEFAULT NULL                                 COMMENT '系统保单号（匹配成功时填充）',
  `row_no`              INT          DEFAULT NULL                                 COMMENT 'Excel原始行号（用于错误定位）',
  `row_error`           VARCHAR(500) DEFAULT NULL                                 COMMENT '行数据错误信息（解析失败原因）',
  `creator`             BIGINT       DEFAULT NULL                                 COMMENT '创建人',
  `create_time`         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP           COMMENT '创建时间',
  `updater`             BIGINT       DEFAULT NULL                                 COMMENT '更新人',
  `update_time`         DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP     COMMENT '更新时间',
  `deleted`             TINYINT(1)   NOT NULL DEFAULT 0                           COMMENT '逻辑删除',
  `tenant_id`           BIGINT       NOT NULL DEFAULT 0                           COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_match_status` (`batch_id`, `match_status`),
  KEY `idx_system_order` (`system_order_id`),
  KEY `idx_insurer_policy_no` (`insurer_policy_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='财务对账-导入明细表（保险公司下发保单逐条数据）';


-- ----------------------------------------------------------
-- 3. 对账差异记录表（ins_fin_reconcile_diff）
--    对应：InsReconcileDiffDO
--    业务：智能匹配后发现差异（保费/佣金/日期差异）的记录，人工处理
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_reconcile_diff` (
  `id`                  BIGINT       NOT NULL AUTO_INCREMENT                      COMMENT '主键ID',
  `batch_id`            BIGINT       NOT NULL                                     COMMENT '批次ID（关联 ins_fin_import_batch.id）',
  `batch_no`            VARCHAR(30)  NOT NULL                                     COMMENT '批次号（冗余）',
  `import_detail_id`    BIGINT       NOT NULL                                     COMMENT '导入明细ID（关联 ins_fin_import_detail.id）',
  `system_order_id`     BIGINT       DEFAULT NULL                                 COMMENT '系统订单ID（无法匹配时为NULL）',
  `system_policy_no`    VARCHAR(50)  DEFAULT NULL                                 COMMENT '系统保单号',
  `insurer_policy_no`   VARCHAR(50)  DEFAULT NULL                                 COMMENT '保险公司保单号',
  `diff_type`           VARCHAR(200) DEFAULT NULL                                 COMMENT '差异类型，逗号分隔（PREMIUM/COMMISSION/DATE/UNMATCH/DUPLICATE）',
  `import_premium`      DECIMAL(12,2) DEFAULT NULL                                COMMENT '导入保费（元）',
  `system_premium`      DECIMAL(12,2) DEFAULT NULL                                COMMENT '系统保费（元）',
  `premium_diff`        DECIMAL(12,2) DEFAULT NULL                                COMMENT '保费差额（导入-系统）',
  `import_commission`   DECIMAL(12,2) DEFAULT NULL                                COMMENT '导入佣金（元）',
  `system_commission`   DECIMAL(12,2) DEFAULT NULL                                COMMENT '系统佣金（元）',
  `commission_diff`     DECIMAL(12,2) DEFAULT NULL                                COMMENT '佣金差额（导入-系统）',
  `import_start_date`   DATE         DEFAULT NULL                                 COMMENT '导入起保日期',
  `system_start_date`   DATE         DEFAULT NULL                                 COMMENT '系统起保日期',
  `process_status`      TINYINT      NOT NULL DEFAULT 0                           COMMENT '处理状态：0待处理 1已处理 2已忽略',
  `process_action`      VARCHAR(50)  DEFAULT NULL                                 COMMENT '处理方式：USE_SYSTEM/USE_IMPORT/MANUAL_INPUT/IGNORE',
  `corrected_premium`   DECIMAL(12,2) DEFAULT NULL                                COMMENT '修正保费（手动输入时）',
  `corrected_commission` DECIMAL(12,2) DEFAULT NULL                               COMMENT '修正佣金（手动输入时）',
  `process_user_id`     BIGINT       DEFAULT NULL                                 COMMENT '处理人ID',
  `process_time`        DATETIME     DEFAULT NULL                                 COMMENT '处理时间',
  `process_remark`      VARCHAR(500) DEFAULT NULL                                 COMMENT '处理备注（最多500字）',
  `creator`             BIGINT       DEFAULT NULL                                 COMMENT '创建人',
  `create_time`         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP           COMMENT '创建时间',
  `updater`             BIGINT       DEFAULT NULL                                 COMMENT '更新人',
  `update_time`         DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP     COMMENT '更新时间',
  `deleted`             TINYINT(1)   NOT NULL DEFAULT 0                           COMMENT '逻辑删除',
  `tenant_id`           BIGINT       NOT NULL DEFAULT 0                           COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_import_detail_id` (`import_detail_id`),
  KEY `idx_process_status` (`process_status`),
  KEY `idx_system_order_id` (`system_order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='财务对账-差异记录表（智能匹配后识别的保费/佣金/日期差异）';


-- ----------------------------------------------------------
-- 4. 上游结算主表（ins_fin_upstream_settle）
--    对应：InsUpstreamSettleDO
--    业务：财务 → 上游结算，按保司聚合生成的结算单（需财务主管审批）
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_upstream_settle` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `settle_no`       VARCHAR(32)  NOT NULL                                         COMMENT '结算单号（US${yyyyMMdd}${6位序号}）',
  `insurer_id`      BIGINT       NOT NULL                                         COMMENT '保险公司ID',
  `insurer_code`    VARCHAR(32)  NOT NULL                                         COMMENT '保险公司编码',
  `insurer_name`    VARCHAR(64)  NOT NULL                                         COMMENT '保险公司名称（快照）',
  `period_start`    DATE         NOT NULL                                         COMMENT '结算周期开始日期',
  `period_end`      DATE         NOT NULL                                         COMMENT '结算周期结束日期',
  `policy_count`    INT          NOT NULL DEFAULT 0                               COMMENT '涉及保单数',
  `total_amount`    DECIMAL(14,2) NOT NULL DEFAULT 0                              COMMENT '应结手续费合计（元）',
  `actual_amount`   DECIMAL(14,2) NOT NULL DEFAULT 0                              COMMENT '实结手续费合计（元）',
  `diff_amount`     DECIMAL(14,2) NOT NULL DEFAULT 0                              COMMENT '差异金额（应结-实结，元）',
  `settle_status`   VARCHAR(32)  NOT NULL DEFAULT 'PENDING_APPROVE'               COMMENT '结算状态：PENDING_APPROVE/APPROVED/SETTLED/REJECTED',
  `approve_user_id` BIGINT       DEFAULT NULL                                     COMMENT '审批人ID',
  `approve_time`    DATETIME     DEFAULT NULL                                     COMMENT '审批时间',
  `approve_comment` VARCHAR(200) DEFAULT NULL                                     COMMENT '审批意见',
  `operate_type`    VARCHAR(64)  DEFAULT NULL                                     COMMENT '操作类型（BATCH_SETTLE/BATCH_SETTLE_WITH_RATE_MODIFY）',
  `remark`          VARCHAR(500) DEFAULT NULL                                     COMMENT '备注',
  `creator`         BIGINT       NOT NULL                                         COMMENT '创建人',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `updater`         BIGINT       DEFAULT NULL                                     COMMENT '更新人',
  `update_time`     DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP         COMMENT '更新时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '逻辑删除',
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_settle_no` (`settle_no`),
  KEY `idx_insurer_period` (`insurer_id`, `period_start`),
  KEY `idx_settle_status` (`settle_status`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='财务上游结算主表（按保司聚合，需审批后生效）';


-- ----------------------------------------------------------
-- 5. 上游结算明细表（ins_fin_upstream_settle_detail）
--    业务：上游结算单下每张保单的结算明细
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_upstream_settle_detail` (
  `id`                    BIGINT       NOT NULL AUTO_INCREMENT                    COMMENT '主键ID',
  `settle_id`             BIGINT       NOT NULL                                   COMMENT '上游结算单ID（关联 ins_fin_upstream_settle.id）',
  `settle_no`             VARCHAR(32)  NOT NULL                                   COMMENT '结算单号（冗余）',
  `policy_no`             VARCHAR(64)  NOT NULL                                   COMMENT '保单号',
  `insurer_id`            BIGINT       NOT NULL                                   COMMENT '保险公司ID',
  `insurer_code`          VARCHAR(32)  NOT NULL                                   COMMENT '保险公司编码',
  `insurance_type`        VARCHAR(32)  DEFAULT NULL                               COMMENT '险种大类（CAR/NON_CAR/LIFE）',
  `premium_amount`        DECIMAL(12,2) DEFAULT NULL                              COMMENT '保费（元）',
  `upstream_rate`         DECIMAL(8,4) DEFAULT NULL                               COMMENT '手续费比例（%）',
  `should_settle_amount`  DECIMAL(12,2) NOT NULL DEFAULT 0                        COMMENT '应结手续费（元）',
  `actual_settle_amount`  DECIMAL(12,2) NOT NULL DEFAULT 0                        COMMENT '实结手续费（元）',
  `settle_status`         VARCHAR(32)  NOT NULL DEFAULT 'PENDING_APPROVE'         COMMENT '明细结算状态',
  `sign_date`             DATE         DEFAULT NULL                               COMMENT '签单日期',
  `period_start`          DATE         DEFAULT NULL                               COMMENT '结算周期开始',
  `period_end`            DATE         DEFAULT NULL                               COMMENT '结算周期结束',
  `create_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP         COMMENT '创建时间',
  `deleted`               TINYINT(1)   NOT NULL DEFAULT 0                         COMMENT '逻辑删除',
  `tenant_id`             BIGINT       NOT NULL DEFAULT 0                         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_settle_id` (`settle_id`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_insurer_code` (`insurer_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='财务上游结算明细表（每条保单的结算数据）';


-- ----------------------------------------------------------
-- 6. 合格认定规则配置表（ins_fin_qualify_rule_config）
--    业务：合格结算 → 合格认定 → 规则配置（保单自动合格触发条件）
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_qualify_rule_config` (
  `id`           BIGINT       NOT NULL AUTO_INCREMENT                             COMMENT '主键ID',
  `rule_code`    VARCHAR(64)  NOT NULL                                            COMMENT '规则编码（唯一）',
  `rule_name`    VARCHAR(100) NOT NULL                                            COMMENT '规则名称',
  `rule_desc`    VARCHAR(500) DEFAULT NULL                                        COMMENT '规则描述说明',
  `is_enabled`   TINYINT(1)   NOT NULL DEFAULT 1                                  COMMENT '是否启用（1启用 0禁用）',
  `rule_params`  VARCHAR(500) DEFAULT NULL                                        COMMENT '规则参数（JSON格式，如天数/金额阈值等）',
  `sort_order`   INT          NOT NULL DEFAULT 0                                  COMMENT '排序值（越小越先匹配）',
  `creator`      BIGINT       DEFAULT NULL                                        COMMENT '创建人',
  `create_time`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP                  COMMENT '创建时间',
  `updater`      BIGINT       DEFAULT NULL                                        COMMENT '更新人',
  `update_time`  DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP            COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rule_code` (`rule_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='合格认定规则配置表（保单自动合格触发规则，如付清保费+过了等待期）';


-- ----------------------------------------------------------
-- 7. 合格认定记录表（ins_fin_qualify_record）
--    业务：保单合格/撤销合格的操作审计记录
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_qualify_record` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `policy_no`       VARCHAR(64)  NOT NULL                                         COMMENT '保单号',
  `insurer_code`    VARCHAR(32)  NOT NULL                                         COMMENT '保险公司编码',
  `insurer_name`    VARCHAR(64)  DEFAULT NULL                                     COMMENT '保险公司名称（快照）',
  `qualify_status`  VARCHAR(32)  NOT NULL                                         COMMENT '合格状态（QUALIFIED=认定合格 CANCELLED=撤销合格）',
  `qualify_source`  VARCHAR(32)  NOT NULL                                         COMMENT '来源（AUTO=自动认定 MANUAL_IMPORT=手动导入）',
  `qualify_time`    DATETIME     NOT NULL                                         COMMENT '认定/撤销时间',
  `operator`        BIGINT       NOT NULL                                         COMMENT '操作人ID',
  `remark`          VARCHAR(500) DEFAULT NULL                                     COMMENT '备注/撤销原因',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '逻辑删除',
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_insurer_time` (`insurer_code`, `qualify_time`),
  KEY `idx_qualify_status` (`qualify_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='合格认定操作记录表（保单合格/撤销合格的完整审计轨迹）';


-- ----------------------------------------------------------
-- 8. 合格对账单主表（ins_fin_reconcile_bill）
--    业务：合格结算 → 对账单管理（按保司+周期汇总合格保单应收手续费）
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_reconcile_bill` (
  `id`                BIGINT       NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `bill_no`           VARCHAR(32)  NOT NULL                                       COMMENT '对账单号（RB+年月日+序号）',
  `insurer_code`      VARCHAR(32)  NOT NULL                                       COMMENT '保险公司编码',
  `insurer_name`      VARCHAR(64)  NOT NULL                                       COMMENT '保险公司名称（快照）',
  `bill_period_start` DATE         NOT NULL                                       COMMENT '对账周期开始',
  `bill_period_end`   DATE         NOT NULL                                       COMMENT '对账周期结束',
  `total_policy_count` INT         NOT NULL DEFAULT 0                             COMMENT '涉及保单数',
  `should_amount`     DECIMAL(14,2) NOT NULL DEFAULT 0                            COMMENT '应收手续费合计（元）',
  `actual_amount`     DECIMAL(14,2) NOT NULL DEFAULT 0                            COMMENT '已收手续费合计（元）',
  `diff_amount`       DECIMAL(14,2) NOT NULL DEFAULT 0                            COMMENT '差异金额（应收-已收，元）',
  `bill_status`       VARCHAR(32)  NOT NULL DEFAULT 'GENERATED'                   COMMENT '状态：GENERATED/CONFIRMED/SETTLED/UPDATED',
  `generate_time`     DATETIME     NOT NULL                                       COMMENT '生成时间',
  `generator`         BIGINT       NOT NULL                                       COMMENT '生成操作人ID',
  `confirm_time`      DATETIME     DEFAULT NULL                                   COMMENT '确认到账时间',
  `confirmer`         BIGINT       DEFAULT NULL                                   COMMENT '确认操作人ID',
  `remark`            VARCHAR(500) DEFAULT NULL                                   COMMENT '备注',
  `creator`           BIGINT       NOT NULL                                       COMMENT '创建人',
  `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `updater`           BIGINT       DEFAULT NULL                                   COMMENT '更新人',
  `update_time`       DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP       COMMENT '更新时间',
  `deleted`           TINYINT(1)   NOT NULL DEFAULT 0                             COMMENT '逻辑删除',
  `tenant_id`         BIGINT       NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_bill_no` (`bill_no`),
  KEY `idx_insurer_period` (`insurer_code`, `bill_period_start`),
  KEY `idx_bill_status` (`bill_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='合格对账单主表（按保司+周期汇总合格保单应收手续费，含到账确认）';


-- ----------------------------------------------------------
-- 9. 合格对账单明细表（ins_fin_reconcile_bill_detail）
--    业务：对账单下每张合格保单的明细数据
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_reconcile_bill_detail` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `bill_no`         VARCHAR(32)  NOT NULL                                         COMMENT '对账单号（关联 ins_fin_reconcile_bill.bill_no）',
  `policy_no`       VARCHAR(64)  NOT NULL                                         COMMENT '保单号',
  `insurer_code`    VARCHAR(32)  NOT NULL                                         COMMENT '保险公司编码',
  `insurance_type`  VARCHAR(32)  NOT NULL                                         COMMENT '险种大类',
  `sign_date`       DATE         NOT NULL                                         COMMENT '签单日期',
  `premium_amount`  DECIMAL(12,2) NOT NULL DEFAULT 0                              COMMENT '保费（元）',
  `upstream_rate`   DECIMAL(8,4) DEFAULT NULL                                     COMMENT '手续费比例（%）',
  `should_amount`   DECIMAL(12,2) NOT NULL DEFAULT 0                              COMMENT '应收手续费（元）',
  `actual_amount`   DECIMAL(12,2) NOT NULL DEFAULT 0                              COMMENT '已收手续费（元）',
  `settle_status`   VARCHAR(32)  NOT NULL                                         COMMENT '结算状态（同 insurance_policy.qualify_status）',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '逻辑删除',
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_bill_no` (`bill_no`),
  KEY `idx_policy_no` (`policy_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='合格对账单明细表（对账单下每条保单的手续费明细）';


-- ----------------------------------------------------------
-- 10. 合格对账差额记录表（ins_fin_reconcile_diff_amount）
--     业务：保司实际到账与对账单金额有差异时的差额记录（如税款扣减/汇差）
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_reconcile_diff_amount` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT                            COMMENT '主键ID',
  `bill_no`       VARCHAR(32)  NOT NULL                                           COMMENT '对账单号（关联 ins_fin_reconcile_bill.bill_no）',
  `insurer_code`  VARCHAR(32)  NOT NULL                                           COMMENT '保险公司编码',
  `diff_amount`   DECIMAL(12,2) NOT NULL                                          COMMENT '差额（正=多收 负=少收，元）',
  `diff_reason`   VARCHAR(64)  NOT NULL                                           COMMENT '差异原因（TAX_DEDUCTION/EXCHANGE_DIFF/REDUCTION/POLICY_CHANGE/OTHER）',
  `diff_detail`   VARCHAR(500) DEFAULT NULL                                       COMMENT '差异说明（详细描述）',
  `arrive_time`   DATETIME     NOT NULL                                           COMMENT '到账时间',
  `operator`      BIGINT       NOT NULL                                           COMMENT '操作人ID',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP                 COMMENT '创建时间',
  `tenant_id`     BIGINT       NOT NULL DEFAULT 0                                 COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_bill_no` (`bill_no`),
  KEY `idx_insurer_arrive` (`insurer_code`, `arrive_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='合格对账差额记录表（对账单实际到账差额明细，用于差异标注）';


-- ----------------------------------------------------------
-- 11. 上游手续费跟单队列（ins_fin_qualified_order）
--     对应：InsQualifiedOrderDO（工程结构文档）
--     业务：保单导入时 upstream_rate 为空 → 进入跟单队列等待填入手续费
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_qualified_order` (
  `id`                  BIGINT       NOT NULL AUTO_INCREMENT                      COMMENT '主键ID',
  `policy_no`           VARCHAR(64)  NOT NULL                                     COMMENT '保单号（全局唯一）',
  `insurer_code`        VARCHAR(32)  NOT NULL                                     COMMENT '保险公司编码',
  `insurer_name`        VARCHAR(64)  NOT NULL                                     COMMENT '保险公司名称（快照）',
  `insurance_type`      VARCHAR(32)  NOT NULL                                     COMMENT '险种大类（CAR/NON_CAR/LIFE）',
  `insured_name`        VARCHAR(50)  DEFAULT NULL                                 COMMENT '投保人姓名',
  `sign_date`           DATE         DEFAULT NULL                                 COMMENT '签单日期',
  `premium_amount`      DECIMAL(12,2) DEFAULT NULL                                COMMENT '保费（元）',
  `upstream_rate`       DECIMAL(8,4) DEFAULT NULL                                 COMMENT '上游手续费比例（%，填入后更新）',
  `upstream_amount`     DECIMAL(12,2) DEFAULT NULL                                COMMENT '上游手续费金额（元，填入后更新）',
  `pending_status`      VARCHAR(32)  NOT NULL DEFAULT 'PENDING_RATE'              COMMENT '跟单状态：PENDING_RATE/SKIP_CURRENT_PERIOD/SETTLED',
  `is_expired`          TINYINT(1)   NOT NULL DEFAULT 0                           COMMENT '是否超期（0否 1是）',
  `expire_days_config`  INT          NOT NULL DEFAULT 45                          COMMENT '超期天数配置值快照（默认45天）',
  `import_time`         DATETIME     NOT NULL                                     COMMENT '保单导入时间',
  `filled_time`         DATETIME     DEFAULT NULL                                 COMMENT '手续费填入时间',
  `filled_by`           BIGINT       DEFAULT NULL                                 COMMENT '填入操作人ID',
  `skip_time`           DATETIME     DEFAULT NULL                                 COMMENT '标记跳过时间',
  `skip_by`             BIGINT       DEFAULT NULL                                 COMMENT '跳过操作人ID',
  `skip_reason`         VARCHAR(200) DEFAULT NULL                                 COMMENT '跳过原因',
  `settle_time`         DATETIME     DEFAULT NULL                                 COMMENT '结算完成时间',
  `remark`              VARCHAR(500) DEFAULT NULL                                 COMMENT '备注',
  `creator`             BIGINT       NOT NULL                                     COMMENT '创建人',
  `create_time`         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP           COMMENT '创建时间',
  `updater`             BIGINT       DEFAULT NULL                                 COMMENT '更新人',
  `update_time`         DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP     COMMENT '更新时间',
  `deleted`             TINYINT(1)   NOT NULL DEFAULT 0                           COMMENT '逻辑删除',
  `tenant_id`           BIGINT       NOT NULL DEFAULT 0                           COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_policy_no` (`policy_no`),
  KEY `idx_insurer_status` (`insurer_code`, `pending_status`),
  KEY `idx_import_time` (`import_time`),
  KEY `idx_is_expired` (`is_expired`, `pending_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='上游手续费跟单队列（导入时无费率的保单暂挂，等待填入手续费后结算）';

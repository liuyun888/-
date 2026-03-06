-- ==========================================================
-- 保险中介平台 · 财务中台模块（intermediary-module-ins-finance）
-- 数据库：db_ins_finance
-- 表前缀：ins_fin_
-- Part 2：结算管理 + 税务管理 + 监管报表 + 报表归档
-- 涉及文档：阶段6-财务中台详细需求设计文档_中_、_下_
-- 作者：架构设计 by AI | 框架：yudao-cloud（Spring Cloud Alibaba）
-- 生成时间：2026-03-01
-- ==========================================================

USE `db_ins_finance`;

-- ================================================================
-- ====================== 结算管理模块 ============================
-- ================================================================

-- ----------------------------------------------------------
-- 1. 结算单主表（ins_fin_settlement）
--    对应：InsSettlementDO
--    业务：按业务员维度汇总月度佣金生成结算单，需走审核+打款流程
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_settlement` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `settlement_no`   VARCHAR(30)  NOT NULL                                         COMMENT '结算单号（SET+年月+4位序号，如SET2025010001）',
  `agent_id`        BIGINT       NOT NULL                                         COMMENT '业务员ID',
  `agent_name`      VARCHAR(50)  NOT NULL                                         COMMENT '业务员姓名（快照）',
  `agent_no`        VARCHAR(30)  NOT NULL                                         COMMENT '业务员工号（快照）',
  `team_id`         BIGINT       DEFAULT NULL                                     COMMENT '所属团队ID',
  `team_name`       VARCHAR(100) DEFAULT NULL                                     COMMENT '所属团队名称（快照）',
  `settle_month`    VARCHAR(7)   NOT NULL                                         COMMENT '结算月份（YYYY-MM）',
  `policy_count`    INT          NOT NULL DEFAULT 0                               COMMENT '结算保单数量',
  `gross_commission` DECIMAL(12,2) NOT NULL DEFAULT 0                             COMMENT '应结佣金（税前，元）',
  `tax_amount`      DECIMAL(12,2) NOT NULL DEFAULT 0                              COMMENT '代扣个税（元）',
  `actual_amount`   DECIMAL(12,2) NOT NULL DEFAULT 0                              COMMENT '实发金额（=应结-个税，元）',
  `generate_type`   TINYINT      NOT NULL DEFAULT 0                               COMMENT '生成方式：0自动生成 1手动生成',
  `status`          TINYINT      NOT NULL DEFAULT 0                               COMMENT '状态：0待审核 1审核中 2审核通过 3审核驳回 4已打款 5已作废',
  `reject_reason`   VARCHAR(200) DEFAULT NULL                                     COMMENT '审核驳回原因',
  `void_reason`     VARCHAR(200) DEFAULT NULL                                     COMMENT '作废原因',
  `invoice_status`  TINYINT      NOT NULL DEFAULT 0                               COMMENT '开票状态：0未开票 1开票中 2已开票',
  `pay_batch_id`    BIGINT       DEFAULT NULL                                     COMMENT '打款批次ID（关联 ins_fin_payment_batch.id）',
  `paid_time`       DATETIME     DEFAULT NULL                                     COMMENT '实际打款时间',
  `process_inst_id` VARCHAR(64)  DEFAULT NULL                                     COMMENT 'Activiti流程实例ID',
  `creator`         BIGINT       DEFAULT NULL                                     COMMENT '创建人',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `updater`         BIGINT       DEFAULT NULL                                     COMMENT '更新人',
  `update_time`     DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP         COMMENT '更新时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '逻辑删除',
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_settlement_no` (`settlement_no`),
  KEY `idx_agent_month` (`agent_id`, `settle_month`),
  KEY `idx_status` (`status`),
  KEY `idx_settle_month` (`settle_month`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='结算单主表（每月每位业务员一张，含税前佣金、个税、实发金额、审核状态）';


-- ----------------------------------------------------------
-- 2. 结算单明细表（ins_fin_settlement_detail）
--    业务：结算单下每张保单的佣金明细，一保单一行
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_settlement_detail` (
  `id`                BIGINT       NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `settlement_id`     BIGINT       NOT NULL                                       COMMENT '结算单ID（关联 ins_fin_settlement.id）',
  `settlement_no`     VARCHAR(30)  NOT NULL                                       COMMENT '结算单号（冗余）',
  `agent_id`          BIGINT       NOT NULL                                       COMMENT '业务员ID',
  `policy_no`         VARCHAR(50)  NOT NULL                                       COMMENT '保单号',
  `system_order_id`   BIGINT       DEFAULT NULL                                   COMMENT '系统订单ID',
  `insurer_id`        BIGINT       DEFAULT NULL                                   COMMENT '保险公司ID',
  `insurer_name`      VARCHAR(64)  DEFAULT NULL                                   COMMENT '保险公司名称（快照）',
  `product_type`      VARCHAR(50)  DEFAULT NULL                                   COMMENT '险种类型',
  `premium`           DECIMAL(12,2) DEFAULT NULL                                  COMMENT '保费（元）',
  `commission_rate`   DECIMAL(6,4) DEFAULT NULL                                   COMMENT '佣金率（快照）',
  `commission_amount` DECIMAL(12,2) NOT NULL DEFAULT 0                            COMMENT '佣金金额（元）',
  `settle_month`      VARCHAR(7)   NOT NULL                                       COMMENT '结算月份（YYYY-MM）',
  `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `deleted`           TINYINT(1)   NOT NULL DEFAULT 0                             COMMENT '逻辑删除',
  `tenant_id`         BIGINT       NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_settlement_id` (`settlement_id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_policy_no` (`policy_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='结算单明细表（结算单下每张保单的佣金明细，一条对应一张保单）';


-- ----------------------------------------------------------
-- 3. 打款批次表（ins_fin_payment_batch）
--    业务：审核通过的结算单发起打款，支持批量付款文件导出或API打款
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_payment_batch` (
  `id`                BIGINT       NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `pay_batch_no`      VARCHAR(30)  NOT NULL                                       COMMENT '打款批次号（PAY+年月日+序号）',
  `pay_month`         VARCHAR(7)   DEFAULT NULL                                   COMMENT '结算月份',
  `settlement_count`  INT          NOT NULL DEFAULT 0                             COMMENT '打款结算单总笔数',
  `total_amount`      DECIMAL(14,2) NOT NULL DEFAULT 0                            COMMENT '打款总金额（元）',
  `pay_type`          TINYINT      NOT NULL DEFAULT 0                             COMMENT '打款方式：0批量文件导出 1API自动打款',
  `pay_account_id`    BIGINT       DEFAULT NULL                                   COMMENT '付款账户ID（来源于系统配置）',
  `pay_account_name`  VARCHAR(100) DEFAULT NULL                                   COMMENT '付款账户名称（快照）',
  `bank_file_url`     VARCHAR(500) DEFAULT NULL                                   COMMENT '批量付款文件OSS路径',
  `status`            TINYINT      NOT NULL DEFAULT 0                             COMMENT '状态：0待打款 1打款中 2已打款 3打款失败',
  `confirm_user_id`   BIGINT       DEFAULT NULL                                   COMMENT '确认完成操作人ID（文件导出模式下人工确认）',
  `confirm_time`      DATETIME     DEFAULT NULL                                   COMMENT '确认打款完成时间',
  `remark`            VARCHAR(200) DEFAULT NULL                                   COMMENT '备注',
  `creator`           BIGINT       NOT NULL                                       COMMENT '创建人',
  `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `updater`           BIGINT       DEFAULT NULL                                   COMMENT '更新人',
  `update_time`       DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP       COMMENT '更新时间',
  `deleted`           TINYINT(1)   NOT NULL DEFAULT 0                             COMMENT '逻辑删除',
  `tenant_id`         BIGINT       NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pay_batch_no` (`pay_batch_no`),
  KEY `idx_status` (`status`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='打款批次表（勾选多张结算单批量发起打款的批次记录）';


-- ----------------------------------------------------------
-- 4. 打款明细表（ins_fin_payment_detail）
--    业务：打款批次下每张结算单的打款记录（含银行卡/打款结果）
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_payment_detail` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `pay_batch_id`    BIGINT       NOT NULL                                         COMMENT '打款批次ID（关联 ins_fin_payment_batch.id）',
  `pay_batch_no`    VARCHAR(30)  NOT NULL                                         COMMENT '打款批次号（冗余）',
  `settlement_id`   BIGINT       NOT NULL                                         COMMENT '结算单ID',
  `settlement_no`   VARCHAR(30)  NOT NULL                                         COMMENT '结算单号（冗余）',
  `agent_id`        BIGINT       NOT NULL                                         COMMENT '业务员ID',
  `agent_name`      VARCHAR(50)  NOT NULL                                         COMMENT '业务员姓名（快照）',
  `settle_month`    VARCHAR(7)   NOT NULL                                         COMMENT '结算月份',
  `pay_amount`      DECIMAL(12,2) NOT NULL                                        COMMENT '打款金额（实发金额，元）',
  `bank_name`       VARCHAR(50)  DEFAULT NULL                                     COMMENT '收款银行名称',
  `bank_card_no`    VARCHAR(30)  DEFAULT NULL                                     COMMENT '收款银行卡号（脱敏，如622202****1234）',
  `bank_account_name` VARCHAR(50) DEFAULT NULL                                    COMMENT '银行账户名',
  `status`          TINYINT      NOT NULL DEFAULT 0                               COMMENT '状态：0待打款 1打款中 2已打款 3打款失败',
  `fail_reason`     VARCHAR(200) DEFAULT NULL                                     COMMENT '打款失败原因',
  `bank_serial_no`  VARCHAR(50)  DEFAULT NULL                                     COMMENT '银行流水号（API返回）',
  `paid_time`       DATETIME     DEFAULT NULL                                     COMMENT '实际到账时间',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `updater`         BIGINT       DEFAULT NULL                                     COMMENT '更新人',
  `update_time`     DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP         COMMENT '更新时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '逻辑删除',
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_pay_batch_id` (`pay_batch_id`),
  KEY `idx_settlement_id` (`settlement_id`),
  KEY `idx_agent_id` (`agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='打款明细表（批次下每张结算单的打款结果，含银行卡信息和到账状态）';


-- ----------------------------------------------------------
-- 5. 发票管理表（ins_fin_invoice）
--    业务：审核通过的结算单申请开具发票，支持电子发票API或手工上传
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_invoice` (
  `id`                  BIGINT       NOT NULL AUTO_INCREMENT                      COMMENT '主键ID',
  `invoice_apply_no`    VARCHAR(30)  NOT NULL                                     COMMENT '发票申请号（INV+年月日+序号）',
  `settlement_id`       BIGINT       NOT NULL                                     COMMENT '结算单ID（关联 ins_fin_settlement.id）',
  `settlement_no`       VARCHAR(30)  DEFAULT NULL                                 COMMENT '结算单号（冗余）',
  `agent_id`            BIGINT       NOT NULL                                     COMMENT '业务员ID',
  `agent_name`          VARCHAR(50)  DEFAULT NULL                                 COMMENT '业务员姓名（快照）',
  `invoice_type`        TINYINT      DEFAULT NULL                                 COMMENT '发票类型：1增值税专票 2增值税普票 3收据',
  `invoice_title`       VARCHAR(100) DEFAULT NULL                                 COMMENT '开票抬头',
  `tax_no`              VARCHAR(30)  DEFAULT NULL                                 COMMENT '纳税人识别号（税号）',
  `total_amount`        DECIMAL(12,2) DEFAULT NULL                                COMMENT '含税总金额（元）',
  `tax_rate`            DECIMAL(5,4) DEFAULT NULL                                 COMMENT '税率（如0.03=3%）',
  `tax_amount`          DECIMAL(12,2) DEFAULT NULL                                COMMENT '税额（元）',
  `amount_without_tax`  DECIMAL(12,2) DEFAULT NULL                                COMMENT '不含税金额（元）',
  `invoice_content`     VARCHAR(100) DEFAULT NULL                                 COMMENT '开票内容（如"代理手续费"）',
  `receive_email`       VARCHAR(100) DEFAULT NULL                                 COMMENT '收票邮箱',
  `status`              TINYINT      NOT NULL DEFAULT 0                           COMMENT '状态：0待开具 1开具中 2已开具 3已作废',
  `invoice_no`          VARCHAR(50)  DEFAULT NULL                                 COMMENT '发票号码（API返回）',
  `invoice_code`        VARCHAR(50)  DEFAULT NULL                                 COMMENT '发票代码（API返回）',
  `invoice_file_url`    VARCHAR(500) DEFAULT NULL                                 COMMENT '电子发票PDF的OSS路径',
  `void_reason`         VARCHAR(200) DEFAULT NULL                                 COMMENT '作废原因',
  `void_time`           DATETIME     DEFAULT NULL                                 COMMENT '作废时间',
  `creator`             BIGINT       DEFAULT NULL                                 COMMENT '创建人',
  `create_time`         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP           COMMENT '创建时间',
  `updater`             BIGINT       DEFAULT NULL                                 COMMENT '更新人',
  `update_time`         DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP     COMMENT '更新时间',
  `deleted`             TINYINT(1)   NOT NULL DEFAULT 0                           COMMENT '逻辑删除',
  `tenant_id`           BIGINT       NOT NULL DEFAULT 0                           COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_invoice_apply_no` (`invoice_apply_no`),
  KEY `idx_settlement_id` (`settlement_id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='发票管理表（结算单开票申请记录，支持电子发票API和手工上传）';


-- ================================================================
-- ====================== 税务管理模块 ============================
-- ================================================================

-- ----------------------------------------------------------
-- 6. 个税计算记录表（ins_fin_tax_record）
--    对应：InsTaxRecordDO
--    业务：结算单生成时自动计算代扣个税，支持财务人工调整
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_tax_record` (
  `id`                BIGINT       NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `settlement_id`     BIGINT       NOT NULL                                       COMMENT '结算单ID（关联 ins_fin_settlement.id）',
  `settlement_no`     VARCHAR(30)  DEFAULT NULL                                   COMMENT '结算单号（冗余）',
  `agent_id`          BIGINT       NOT NULL                                       COMMENT '业务员ID',
  `agent_name`        VARCHAR(50)  DEFAULT NULL                                   COMMENT '业务员姓名（快照）',
  `agent_no`          VARCHAR(30)  DEFAULT NULL                                   COMMENT '业务员工号（快照）',
  `id_card_no`        VARCHAR(20)  DEFAULT NULL                                   COMMENT '身份证号（加密存储，用于申报）',
  `settle_month`      VARCHAR(7)   NOT NULL                                       COMMENT '结算月份（YYYY-MM）',
  `gross_income`      DECIMAL(12,2) NOT NULL                                      COMMENT '税前收入（应结佣金，元）',
  `deduction`         DECIMAL(12,2) NOT NULL DEFAULT 0                            COMMENT '扣除额（<4000元扣800；>=4000元扣20%，元）',
  `taxable_income`    DECIMAL(12,2) NOT NULL DEFAULT 0                            COMMENT '应纳税收入额（=税前收入-扣除额，元）',
  `tax_rate`          DECIMAL(5,4) NOT NULL DEFAULT 0                             COMMENT '适用预扣率（如0.20=20%）',
  `quick_deduction`   DECIMAL(10,2) NOT NULL DEFAULT 0                            COMMENT '速算扣除数（元）',
  `tax_amount`        DECIMAL(12,2) NOT NULL DEFAULT 0                            COMMENT '应扣税额（=应纳税额×税率-速算扣除数，元）',
  `net_income`        DECIMAL(12,2) NOT NULL DEFAULT 0                            COMMENT '税后实发金额（=税前收入-应扣税额，元）',
  `calc_type`         TINYINT      NOT NULL DEFAULT 0                             COMMENT '计算类型：0系统自动计算 1财务人工调整',
  `adjust_reason`     VARCHAR(200) DEFAULT NULL                                   COMMENT '人工调整原因（calc_type=1时必填）',
  `original_tax`      DECIMAL(12,2) DEFAULT NULL                                  COMMENT '调整前原税额（人工调整时记录原值，元）',
  `creator`           BIGINT       DEFAULT NULL                                   COMMENT '创建人',
  `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `updater`           BIGINT       DEFAULT NULL                                   COMMENT '更新人',
  `update_time`       DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP       COMMENT '更新时间',
  `deleted`           TINYINT(1)   NOT NULL DEFAULT 0                             COMMENT '逻辑删除',
  `tenant_id`         BIGINT       NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_settlement_agent` (`settlement_id`, `agent_id`),
  KEY `idx_agent_month` (`agent_id`, `settle_month`),
  KEY `idx_settle_month` (`settle_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='个税计算记录表（劳务报酬预扣率法，记录每张结算单的代扣个税明细）';


-- ----------------------------------------------------------
-- 7. 税务申报批次表（ins_fin_tax_declare_batch）
--    业务：每月生成符合税务局要求的申报数据文件，记录申报状态
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_tax_declare_batch` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `declare_batch_no` VARCHAR(20) NOT NULL                                         COMMENT '申报批次号（TAX+年月+4位序号）',
  `declare_month`   VARCHAR(7)   NOT NULL                                         COMMENT '申报月份（YYYY-MM）',
  `declare_count`   INT          NOT NULL DEFAULT 0                               COMMENT '申报人数',
  `total_tax`       DECIMAL(12,2) NOT NULL DEFAULT 0                              COMMENT '代扣税额合计（元）',
  `status`          TINYINT      NOT NULL DEFAULT 0                               COMMENT '状态：0待申报 1申报中 2已申报',
  `summary_file_url` VARCHAR(500) DEFAULT NULL                                    COMMENT '申报汇总表OSS路径（Excel）',
  `detail_file_url` VARCHAR(500) DEFAULT NULL                                     COMMENT '申报明细表OSS路径（Excel）',
  `file_expire_time` DATETIME    DEFAULT NULL                                     COMMENT '文件下载链接过期时间（默认7天）',
  `declare_date`    DATE         DEFAULT NULL                                     COMMENT '实际申报日期（财务人员手工上传后回填）',
  `declare_voucher_no` VARCHAR(50) DEFAULT NULL                                   COMMENT '申报凭证号（选填）',
  `declare_screenshot_url` VARCHAR(500) DEFAULT NULL                              COMMENT '申报截图OSS路径（选填）',
  `creator`         BIGINT       DEFAULT NULL                                     COMMENT '创建人',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `updater`         BIGINT       DEFAULT NULL                                     COMMENT '更新人',
  `update_time`     DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP         COMMENT '更新时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '逻辑删除',
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_declare_batch_no` (`declare_batch_no`),
  KEY `idx_declare_month` (`declare_month`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='税务申报批次表（月度代扣个税申报，生成汇总/明细申报文件）';


-- ----------------------------------------------------------
-- 8. 完税证明表（ins_fin_tax_certificate）
--    业务：为业务员生成月度/年度PDF完税证明，可下载/发邮件
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_tax_certificate` (
  `id`                BIGINT       NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `agent_id`          BIGINT       NOT NULL                                       COMMENT '业务员ID',
  `agent_name`        VARCHAR(50)  NOT NULL                                       COMMENT '业务员姓名（快照）',
  `agent_no`          VARCHAR(30)  DEFAULT NULL                                   COMMENT '业务员工号（快照）',
  `cert_type`         TINYINT      NOT NULL DEFAULT 0                             COMMENT '证明类型：0月度证明 1年度汇总证明',
  `cert_period`       VARCHAR(7)   NOT NULL                                       COMMENT '所属月份（月度：YYYY-MM；年度：YYYY）',
  `gross_income`      DECIMAL(12,2) NOT NULL DEFAULT 0                            COMMENT '税前收入合计（元）',
  `tax_amount`        DECIMAL(12,2) NOT NULL DEFAULT 0                            COMMENT '代扣税额合计（元）',
  `net_income`        DECIMAL(12,2) NOT NULL DEFAULT 0                            COMMENT '实发金额合计（元）',
  `status`            TINYINT      NOT NULL DEFAULT 0                             COMMENT '状态：0待生成 1已生成',
  `cert_file_url`     VARCHAR(500) DEFAULT NULL                                   COMMENT '完税证明PDF的OSS路径',
  `generate_time`     DATETIME     DEFAULT NULL                                   COMMENT 'PDF生成时间',
  `last_send_email`   VARCHAR(100) DEFAULT NULL                                   COMMENT '最后一次发送邮件地址',
  `last_send_time`    DATETIME     DEFAULT NULL                                   COMMENT '最后一次发送邮件时间',
  `creator`           BIGINT       DEFAULT NULL                                   COMMENT '创建人',
  `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `updater`           BIGINT       DEFAULT NULL                                   COMMENT '更新人',
  `update_time`       DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP       COMMENT '更新时间',
  `deleted`           TINYINT(1)   NOT NULL DEFAULT 0                             COMMENT '逻辑删除',
  `tenant_id`         BIGINT       NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_agent_period` (`agent_id`, `cert_period`, `cert_type`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='完税证明表（业务员月度/年度完税证明PDF，支持下载和邮件发送）';


-- ================================================================
-- ====================== 监管报表模块 ============================
-- ================================================================

-- ----------------------------------------------------------
-- 9. 监管业务台账表（ins_fin_regulatory_ledger）
--    业务：按月生成符合监管要求的业务台账（保险代理业务基本情况表等）
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_regulatory_ledger` (
  `id`                BIGINT       NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `ledger_no`         VARCHAR(30)  NOT NULL                                       COMMENT '台账编号（LDG+年月+序号）',
  `ledger_month`      VARCHAR(7)   NOT NULL                                       COMMENT '台账月份（YYYY-MM）',
  `ledger_type`       VARCHAR(50)  DEFAULT NULL                                   COMMENT '台账类型（BASIC/PERSONNEL/COMPLAINT等）',
  `file_name`         VARCHAR(200) DEFAULT NULL                                   COMMENT '台账文件名',
  `file_url`          VARCHAR(500) DEFAULT NULL                                   COMMENT 'OSS文件路径（EasyExcel模板生成）',
  `status`            TINYINT      NOT NULL DEFAULT 0                             COMMENT '状态：0待生成 1已生成 2已上报',
  `report_method`     TINYINT      DEFAULT NULL                                   COMMENT '上报方式：0监管系统在线上报 1纸质报送',
  `report_date`       DATE         DEFAULT NULL                                   COMMENT '上报日期',
  `report_voucher_url` VARCHAR(500) DEFAULT NULL                                  COMMENT '上报凭证截图OSS路径',
  `remark`            VARCHAR(200) DEFAULT NULL                                   COMMENT '备注',
  `creator`           BIGINT       DEFAULT NULL                                   COMMENT '创建人',
  `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `updater`           BIGINT       DEFAULT NULL                                   COMMENT '更新人',
  `update_time`       DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP       COMMENT '更新时间',
  `deleted`           TINYINT(1)   NOT NULL DEFAULT 0                             COMMENT '逻辑删除',
  `tenant_id`         BIGINT       NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ledger_no` (`ledger_no`),
  KEY `idx_ledger_month` (`ledger_month`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='监管业务台账表（按月生成/标记上报，格式遵循保险代理业务基本情况表）';


-- ----------------------------------------------------------
-- 10. 监管数据上报记录表（ins_fin_regulatory_report）
--     业务：对接监管API接口自动上报数据，记录请求/响应及状态
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_regulatory_report` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `report_batch_no` VARCHAR(30)  NOT NULL                                         COMMENT '上报批次号（RPT+年月日+序号）',
  `regulator_name`  VARCHAR(100) NOT NULL                                         COMMENT '监管机构名称',
  `regulator_code`  VARCHAR(50)  NOT NULL                                         COMMENT '监管机构编码',
  `report_month`    VARCHAR(7)   NOT NULL                                         COMMENT '上报月份（YYYY-MM）',
  `data_count`      INT          NOT NULL DEFAULT 0                               COMMENT '本次上报数据条数',
  `status`          TINYINT      NOT NULL DEFAULT 0                               COMMENT '状态：0待上报 1上报中 2成功 3失败 4部分成功',
  `request_body`    TEXT         DEFAULT NULL                                     COMMENT '请求报文（加密存储，防止数据泄露）',
  `response_body`   TEXT         DEFAULT NULL                                     COMMENT '响应报文（加密存储）',
  `response_code`   VARCHAR(50)  DEFAULT NULL                                     COMMENT '监管系统响应码',
  `response_msg`    VARCHAR(500) DEFAULT NULL                                     COMMENT '监管系统响应描述',
  `fail_reason`     VARCHAR(500) DEFAULT NULL                                     COMMENT '失败原因（上报失败时记录）',
  `retry_count`     INT          NOT NULL DEFAULT 0                               COMMENT '重试次数',
  `last_retry_time` DATETIME     DEFAULT NULL                                     COMMENT '最后重试时间',
  `report_time`     DATETIME     DEFAULT NULL                                     COMMENT '实际上报时间',
  `creator`         BIGINT       DEFAULT NULL                                     COMMENT '创建人',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `updater`         BIGINT       DEFAULT NULL                                     COMMENT '更新人',
  `update_time`     DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP         COMMENT '更新时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0                               COMMENT '逻辑删除',
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_report_batch_no` (`report_batch_no`),
  KEY `idx_report_month_status` (`report_month`, `status`),
  KEY `idx_regulator_code` (`regulator_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='监管数据上报记录表（对接监管API，记录上报报文、响应结果及重试情况）';


-- ----------------------------------------------------------
-- 11. 报表归档管理表（ins_fin_report_archive）
--     业务：统一管理对账/结算/税务/监管等报表文件的归档，7年保存
-- ----------------------------------------------------------
CREATE TABLE `ins_fin_report_archive` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT                            COMMENT '主键ID',
  `report_name`   VARCHAR(200) NOT NULL                                           COMMENT '报表名称',
  `report_type`   VARCHAR(50)  NOT NULL                                           COMMENT '报表类型：reconcile/settlement/tax/regulatory',
  `report_month`  VARCHAR(7)   DEFAULT NULL                                       COMMENT '所属月份（YYYY-MM）',
  `file_name`     VARCHAR(200) DEFAULT NULL                                       COMMENT '文件名',
  `file_url`      VARCHAR(500) DEFAULT NULL                                       COMMENT 'OSS归档路径（finance/archive/年/月/类型/文件名）',
  `file_size`     BIGINT       DEFAULT NULL                                       COMMENT '文件大小（字节）',
  `archive_type`  TINYINT      NOT NULL DEFAULT 0                                 COMMENT '归档方式：0手动归档 1自动归档',
  `source_id`     BIGINT       DEFAULT NULL                                       COMMENT '来源记录ID（对应各报表主表的id）',
  `source_type`   VARCHAR(50)  DEFAULT NULL                                       COMMENT '来源类型（ledger/batch/tax_declare等）',
  `is_locked`     TINYINT(1)   NOT NULL DEFAULT 0                                 COMMENT 'OSS是否加锁（1=不可删除，用于合规保存）',
  `expire_years`  INT          NOT NULL DEFAULT 7                                 COMMENT '保存年限（默认7年，符合金融监管要求）',
  `creator`       BIGINT       DEFAULT NULL                                       COMMENT '归档人',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP                 COMMENT '归档时间',
  `updater`       BIGINT       DEFAULT NULL                                       COMMENT '更新人',
  `update_time`   DATETIME     DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP           COMMENT '更新时间',
  `deleted`       TINYINT(1)   NOT NULL DEFAULT 0                                 COMMENT '逻辑删除（不影响OSS文件）',
  `tenant_id`     BIGINT       NOT NULL DEFAULT 0                                 COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_report_type_month` (`report_type`, `report_month`),
  KEY `idx_source` (`source_type`, `source_id`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='报表归档管理表（统一管理财务各类报表，归档后OSS加锁保存7年）';

-- =====================================================
-- 保险中介平台 · 佣金结算中台数据库设计
-- 模块: intermediary-module-ins-commission
-- Schema: db_ins_commission
-- 表前缀: ins_comm_
-- 文档版本: V1.0 | 日期: 2026-03-01
-- Part 2: 佣金明细记录 + 结算单 + 对账管理
-- =====================================================

USE `db_ins_commission`;

-- =====================================================
-- 8. ins_comm_record  佣金明细记录表（核心主表）
-- 每笔保单对应一条或多条佣金记录（如同一保单产生FYC+OVERRIDE）
-- 对应需求: 上篇 §3.3 批量佣金计算 + 补充篇B §2.1 佣金查询
-- =====================================================
CREATE TABLE `ins_comm_record` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `commission_no`   varchar(64)   NOT NULL                               COMMENT '佣金单号（唯一，格式: CM+yyyyMMdd+6位流水）',
  -- 关联保单信息
  `order_id`        bigint(20)    DEFAULT NULL                           COMMENT '订单ID（关联ins_order模块）',
  `policy_id`       bigint(20)    DEFAULT NULL                           COMMENT '保单ID（关联ins_order模块）',
  `policy_no`       varchar(64)   NOT NULL                               COMMENT '保单号',
  `product_category` varchar(32)  NOT NULL                               COMMENT '险种: CAR/NON_CAR/LIFE/HEALTH/ACCIDENT',
  `insurance_company_code` varchar(64) NOT NULL                         COMMENT '保险公司编码',
  `insurance_company_name` varchar(128) NOT NULL                        COMMENT '保险公司名称（冗余）',
  `premium`         decimal(14,2) NOT NULL                               COMMENT '保费（元）',
  `insure_date`     date          NOT NULL                               COMMENT '承保日期',
  -- 业务员信息（计算时快照）
  `agent_id`        bigint(20)    NOT NULL                               COMMENT '业务员ID',
  `agent_code`      varchar(64)   NOT NULL                               COMMENT '业务员工号',
  `agent_name`      varchar(64)   NOT NULL                               COMMENT '业务员姓名',
  `dept_id`         bigint(20)    NOT NULL                               COMMENT '所属部门ID',
  `dept_name`       varchar(128)  NOT NULL                               COMMENT '所属部门名称（快照）',
  `rank_id`         bigint(20)    NOT NULL                               COMMENT '计算时职级ID',
  `rank_code`       varchar(32)   NOT NULL                               COMMENT '计算时职级编码（快照）',
  `rank_name`       varchar(64)   NOT NULL                               COMMENT '计算时职级名称（快照）',
  -- 佣金信息
  `commission_type` varchar(32)   NOT NULL                               COMMENT '佣金类型: FYC首年佣金/RYC续期佣金/OVERRIDE管理津贴/BONUS奖励/REFUND退保回收',
  `commission_rate` decimal(8,4)  NOT NULL DEFAULT 0                    COMMENT '佣金率（百分比小数，如0.30=30%）',
  `commission_base` decimal(14,2) NOT NULL                               COMMENT '佣金计算基数（保费或标保）',
  `commission_amount` decimal(14,2) NOT NULL                             COMMENT '佣金金额（元）',
  `is_compliance_truncated` tinyint(1) NOT NULL DEFAULT 0               COMMENT '是否经合规截断（超监管上限被截断）: 1是 0否',
  `original_rate`   decimal(8,4)  DEFAULT NULL                           COMMENT '截断前原始比例（合规截断时记录）',
  -- 计算信息
  `rule_id`         bigint(20)    DEFAULT NULL                           COMMENT '适用的佣金规则ID',
  `rule_code`       varchar(64)   DEFAULT NULL                           COMMENT '适用的佣金规则编码（快照）',
  `calc_formula`    text          DEFAULT NULL                           COMMENT '计算公式说明（供展示审计）',
  `calc_batch_id`   bigint(20)    DEFAULT NULL                           COMMENT '批量计算批次ID（批量触发时记录）',
  -- 分润关系（仅OVERRIDE类型使用）
  `source_commission_id` bigint(20) DEFAULT NULL                        COMMENT '源佣金记录ID（OVERRIDE类型：由哪笔FYC触发）',
  `source_agent_id` bigint(20)    DEFAULT NULL                           COMMENT '源业务员ID（OVERRIDE分润来源）',
  `override_level`  int           DEFAULT NULL                           COMMENT '分润层级（多级结算中的层级数1/2/3）',
  -- 结算信息
  `settle_period`   varchar(7)    DEFAULT NULL                           COMMENT '结算周期 YYYY-MM',
  `statement_id`    bigint(20)    DEFAULT NULL                           COMMENT '结算单ID（关联ins_comm_statement）',
  `status`          varchar(16)   NOT NULL DEFAULT 'PENDING'             COMMENT '状态: PENDING待审核 APPROVED已审核 PAID已发放 REJECTED已拒绝 REFUNDED已回收',
  `pay_time`        datetime      DEFAULT NULL                           COMMENT '发放时间',
  `pay_channel`     varchar(16)   DEFAULT NULL                           COMMENT '发放渠道: BANK银行 ALIPAY支付宝 WECHAT微信',
  `pay_batch_no`    varchar(64)   DEFAULT NULL                           COMMENT '发放批次号',
  `reject_reason`   varchar(500)  DEFAULT NULL                           COMMENT '拒绝原因',
  -- 标准字段
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_commission_no` (`commission_no`, `tenant_id`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_settle_period` (`settle_period`),
  KEY `idx_status` (`status`),
  KEY `idx_commission_type` (`commission_type`),
  KEY `idx_product_category` (`product_category`),
  KEY `idx_statement_id` (`statement_id`),
  KEY `idx_calc_batch_id` (`calc_batch_id`),
  KEY `idx_create_time` (`create_time`),
  KEY `idx_source_commission_id` (`source_commission_id`),
  -- 组合索引（工资查询高频查询）
  KEY `idx_agent_period_type` (`agent_id`, `settle_period`, `commission_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金明细记录表（核心，每笔保单对应一或多条）';


-- =====================================================
-- 9. ins_comm_calc_batch  佣金批量计算批次表
-- 管理批量计算任务的状态和进度
-- 对应需求: 上篇 §3.3 批量佣金计算（异步+进度）
-- =====================================================
CREATE TABLE `ins_comm_calc_batch` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `batch_no`        varchar(64)   NOT NULL                               COMMENT '批次号',
  `calc_period`     varchar(7)    NOT NULL                               COMMENT '计算结算周期 YYYY-MM',
  `product_category` varchar(32)  DEFAULT NULL                           COMMENT '险种范围（NULL=全部险种）',
  `dept_id`         bigint(20)    DEFAULT NULL                           COMMENT '计算部门范围（NULL=全公司）',
  `calc_type`       varchar(16)   NOT NULL DEFAULT 'AUTO'               COMMENT '触发方式: AUTO自动 MANUAL手动',
  `status`          varchar(16)   NOT NULL DEFAULT 'PENDING'             COMMENT '批次状态: PENDING待执行 RUNNING计算中 SUCCESS成功 FAILED失败',
  `total_count`     int           NOT NULL DEFAULT 0                     COMMENT '总保单数',
  `success_count`   int           NOT NULL DEFAULT 0                     COMMENT '成功计算数',
  `fail_count`      int           NOT NULL DEFAULT 0                     COMMENT '失败数',
  `total_amount`    decimal(16,2) NOT NULL DEFAULT 0                    COMMENT '生成佣金总金额',
  `start_time`      datetime      DEFAULT NULL                           COMMENT '计算开始时间',
  `end_time`        datetime      DEFAULT NULL                           COMMENT '计算结束时间',
  `error_message`   text          DEFAULT NULL                           COMMENT '批次失败原因',
  `fail_detail_url` varchar(512)  DEFAULT NULL                           COMMENT '失败明细导出文件URL（OSS）',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`, `tenant_id`),
  KEY `idx_calc_period` (`calc_period`),
  KEY `idx_status` (`status`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金批量计算批次表';


-- =====================================================
-- 10. ins_comm_statement  结算单表（月度/季度汇总）
-- 对应需求: 中篇 §2.1 结算单生成
-- =====================================================
CREATE TABLE `ins_comm_statement` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `statement_no`    varchar(64)   NOT NULL                               COMMENT '结算单号（唯一，格式: ST+yyyyMM+5位流水）',
  `statement_type`  varchar(16)   NOT NULL DEFAULT 'MONTHLY'             COMMENT '结算类型: MONTHLY月度 QUARTERLY季度 CUSTOM自定义',
  `settle_period`   varchar(7)    NOT NULL                               COMMENT '结算周期 YYYY-MM',
  `agent_id`        bigint(20)    NOT NULL                               COMMENT '业务员ID',
  `agent_code`      varchar(64)   NOT NULL                               COMMENT '业务员工号',
  `agent_name`      varchar(64)   NOT NULL                               COMMENT '业务员姓名',
  `dept_id`         bigint(20)    NOT NULL                               COMMENT '所属部门ID',
  `dept_name`       varchar(128)  NOT NULL                               COMMENT '所属部门名称（快照）',
  `rank_code`       varchar(32)   NOT NULL                               COMMENT '结算时职级（快照）',
  -- 汇总金额
  `fyc_amount`      decimal(14,2) NOT NULL DEFAULT 0                    COMMENT 'FYC首年佣金合计',
  `ryc_amount`      decimal(14,2) NOT NULL DEFAULT 0                    COMMENT 'RYC续期佣金合计',
  `override_amount` decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '管理津贴合计',
  `bonus_amount`    decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '奖励合计',
  `refund_amount`   decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '退保回收合计（负数或0）',
  `add_amount`      decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '加款合计（加扣款导入）',
  `deduct_amount`   decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '扣款合计（负数或0）',
  `gross_amount`    decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '税前合计 = FYC+RYC+OVERRIDE+BONUS+REFUND+ADD+DEDUCT',
  `tax_amount`      decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '代扣个税（预估）',
  `net_amount`      decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '税后实发金额',
  `commission_count` int          NOT NULL DEFAULT 0                     COMMENT '关联佣金记录数',
  -- 审核信息
  `status`          varchar(16)   NOT NULL DEFAULT 'DRAFT'               COMMENT '状态: DRAFT草稿 SUBMITTED提交审核 APPROVED审核通过 REJECTED已拒绝 PAID已发放',
  `submit_time`     datetime      DEFAULT NULL                           COMMENT '提交审核时间',
  `approve_time`    datetime      DEFAULT NULL                           COMMENT '审核通过时间',
  `approver_id`     bigint(20)    DEFAULT NULL                           COMMENT '审核人ID',
  `approver_name`   varchar(64)   DEFAULT NULL                           COMMENT '审核人姓名',
  `approve_comment` varchar(500)  DEFAULT NULL                           COMMENT '审核意见',
  `reject_reason`   varchar(500)  DEFAULT NULL                           COMMENT '拒绝原因',
  -- 发放信息
  `pay_time`        datetime      DEFAULT NULL                           COMMENT '发放时间',
  `pay_channel`     varchar(16)   DEFAULT NULL                           COMMENT '发放渠道: BANK/ALIPAY/WECHAT',
  `pay_account`     varchar(128)  DEFAULT NULL                           COMMENT '发放账户（加密存储）',
  `pay_batch_no`    varchar(64)   DEFAULT NULL                           COMMENT '发放批次号',
  -- 标准字段
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_statement_no` (`statement_no`, `tenant_id`),
  UNIQUE KEY `uk_agent_period` (`agent_id`, `settle_period`, `statement_type`, `tenant_id`),
  KEY `idx_settle_period` (`settle_period`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_status` (`status`),
  KEY `idx_approver_id` (`approver_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='结算单表（月度/季度汇总）';


-- =====================================================
-- 11. ins_comm_pay_batch  佣金发放批次表
-- 管理批量发放任务
-- 对应需求: 中篇 §2.3 佣金发放
-- =====================================================
CREATE TABLE `ins_comm_pay_batch` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `batch_no`        varchar(64)   NOT NULL                               COMMENT '发放批次号',
  `settle_period`   varchar(7)    NOT NULL                               COMMENT '结算周期 YYYY-MM',
  `pay_channel`     varchar(16)   NOT NULL                               COMMENT '发放渠道: BANK/ALIPAY/WECHAT',
  `total_count`     int           NOT NULL DEFAULT 0                     COMMENT '发放人数',
  `total_amount`    decimal(16,2) NOT NULL DEFAULT 0                    COMMENT '发放总金额',
  `status`          varchar(16)   NOT NULL DEFAULT 'PENDING'             COMMENT '状态: PENDING待发放 PROCESSING发放中 SUCCESS成功 PARTIAL部分成功 FAILED失败',
  `success_count`   int           NOT NULL DEFAULT 0                     COMMENT '成功数',
  `fail_count`      int           NOT NULL DEFAULT 0                     COMMENT '失败数',
  `pay_time`        datetime      DEFAULT NULL                           COMMENT '发放时间',
  `third_party_batch_no` varchar(128) DEFAULT NULL                       COMMENT '第三方支付批次号（银行/支付宝）',
  `fail_detail_url` varchar(512)  DEFAULT NULL                           COMMENT '失败明细文件URL',
  `remark`          varchar(500)  DEFAULT NULL                           COMMENT '备注',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`, `tenant_id`),
  KEY `idx_settle_period` (`settle_period`),
  KEY `idx_status` (`status`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金发放批次表';


-- =====================================================
-- 12. ins_comm_reconcile  对账记录表（与保司账单比对）
-- 对应需求: 中篇 §3.1 保司对账（Excel导入+自动匹配）
-- =====================================================
CREATE TABLE `ins_comm_reconcile` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `reconcile_no`    varchar(64)   NOT NULL                               COMMENT '对账单号（唯一）',
  `reconcile_period` varchar(7)   NOT NULL                               COMMENT '对账期间 YYYY-MM',
  `insurance_company_code` varchar(64) NOT NULL                         COMMENT '保险公司编码',
  `insurance_company_name` varchar(128) NOT NULL                        COMMENT '保险公司名称',
  `import_batch_id` bigint(20)    DEFAULT NULL                           COMMENT '导入批次ID',
  -- 保单信息
  `policy_no`       varchar(64)   NOT NULL                               COMMENT '保单号',
  `policy_id`       bigint(20)    DEFAULT NULL                           COMMENT '系统保单ID（匹配成功后填充）',
  `product_category` varchar(32)  DEFAULT NULL                           COMMENT '险种',
  `insure_date`     date          DEFAULT NULL                           COMMENT '承保日期',
  -- 金额核对
  `insurer_premium` decimal(14,2) DEFAULT NULL                           COMMENT '保司账单保费',
  `system_premium`  decimal(14,2) DEFAULT NULL                           COMMENT '系统保费',
  `insurer_commission_rate` decimal(8,4) DEFAULT NULL                   COMMENT '保司账单佣金率',
  `insurer_commission_amount` decimal(14,2) DEFAULT NULL                COMMENT '保司账单佣金金额（应付）',
  `system_commission_amount` decimal(14,2) DEFAULT NULL                 COMMENT '系统计算应收佣金金额',
  `diff_amount`     decimal(14,2) DEFAULT NULL                           COMMENT '差异金额 = 保司应付 - 系统应收',
  -- 对账状态
  `match_status`    varchar(16)   NOT NULL DEFAULT 'UNMATCHED'          COMMENT '匹配状态: UNMATCHED未匹配 MATCHED已匹配 MISMATCH保单匹配但金额差异',
  `reconcile_status` varchar(16)  NOT NULL DEFAULT 'PENDING'             COMMENT '对账状态: PENDING待对账 CONFIRMED已确认 DIFF_PROCESSING差异处理中 CLOSED已关闭',
  `diff_reason`     varchar(32)   DEFAULT NULL                           COMMENT '差异原因: PREMIUM_DIFF保费不一致 RATE_DIFF比例不一致 POLICY_CHANGE批改 REFUND退保 PERIOD_DIFF跨期',
  `diff_note`       varchar(500)  DEFAULT NULL                           COMMENT '差异说明',
  `handler_id`      bigint(20)    DEFAULT NULL                           COMMENT '差异处理人ID',
  `handle_time`     datetime      DEFAULT NULL                           COMMENT '差异处理时间',
  -- 开票收款
  `invoice_status`  varchar(16)   NOT NULL DEFAULT 'NONE'               COMMENT '开票状态: NONE未开票 INVOICED已开票',
  `invoice_no`      varchar(64)   DEFAULT NULL                           COMMENT '发票号',
  `invoice_amount`  decimal(14,2) DEFAULT NULL                           COMMENT '开票金额',
  `invoice_date`    date          DEFAULT NULL                           COMMENT '开票日期',
  `invoice_title`   varchar(128)  DEFAULT NULL                           COMMENT '开票抬头',
  `invoice_tax_no`  varchar(32)   DEFAULT NULL                           COMMENT '纳税人识别号',
  `collect_status`  varchar(16)   NOT NULL DEFAULT 'UNPAID'              COMMENT '收款状态: UNPAID未收款 PAID已收款',
  `collect_date`    date          DEFAULT NULL                           COMMENT '收款日期',
  `actual_amount`   decimal(14,2) DEFAULT NULL                           COMMENT '实际收款金额',
  -- 原始导入数据
  `raw_data`        json          DEFAULT NULL                           COMMENT '保司导入的原始数据JSON（用于人工核对）',
  -- 标准字段
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_reconcile_no` (`reconcile_no`, `tenant_id`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_reconcile_period` (`reconcile_period`),
  KEY `idx_insurance_company` (`insurance_company_code`),
  KEY `idx_match_status` (`match_status`),
  KEY `idx_reconcile_status` (`reconcile_status`),
  KEY `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='与保司对账记录表';


-- =====================================================
-- 13. ins_comm_reconcile_import_batch  对账导入批次表
-- 管理保司账单的Excel导入任务
-- 对应需求: 中篇 §3.1 保司对账导入
-- =====================================================
CREATE TABLE `ins_comm_reconcile_import_batch` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `batch_no`        varchar(64)   NOT NULL                               COMMENT '导入批次号',
  `insurance_company_code` varchar(64) NOT NULL                         COMMENT '保险公司编码',
  `insurance_company_name` varchar(128) NOT NULL                        COMMENT '保险公司名称',
  `reconcile_period` varchar(7)   NOT NULL                               COMMENT '对账期间',
  `file_name`       varchar(256)  NOT NULL                               COMMENT '上传文件名',
  `file_url`        varchar(512)  NOT NULL                               COMMENT '文件存储URL（OSS）',
  `total_rows`      int           NOT NULL DEFAULT 0                     COMMENT '总行数',
  `success_rows`    int           NOT NULL DEFAULT 0                     COMMENT '成功导入行数',
  `fail_rows`       int           NOT NULL DEFAULT 0                     COMMENT '失败行数',
  `matched_rows`    int           NOT NULL DEFAULT 0                     COMMENT '自动匹配成功数',
  `status`          varchar(16)   NOT NULL DEFAULT 'PENDING'             COMMENT '导入状态: PENDING待处理 PROCESSING处理中 SUCCESS成功 FAILED失败',
  `error_message`   text          DEFAULT NULL                           COMMENT '批次错误信息',
  `fail_detail_url` varchar(512)  DEFAULT NULL                           COMMENT '失败明细文件URL',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`, `tenant_id`),
  KEY `idx_insurance_company` (`insurance_company_code`),
  KEY `idx_reconcile_period` (`reconcile_period`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保司对账账单导入批次表';


-- =====================================================
-- 14. ins_comm_salary_adjustment  加扣款记录表
-- 业务员的手工加扣款（考勤扣款/绩效奖励/垫付回收等）
-- 对应需求: 补充篇B §2.3 加扣款导入 (PDF-219)
-- =====================================================
CREATE TABLE `ins_comm_salary_adjustment` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `import_batch_id` bigint(20)    DEFAULT NULL                           COMMENT '导入批次ID（关联ins_comm_adj_import_batch）',
  `agent_id`        bigint(20)    NOT NULL                               COMMENT '业务员ID',
  `agent_code`      varchar(64)   NOT NULL                               COMMENT '业务员工号',
  `agent_name`      varchar(64)   NOT NULL                               COMMENT '业务员姓名（快照）',
  `salary_month`    varchar(7)    NOT NULL                               COMMENT '工资所属月份 YYYY-MM',
  `adjust_type`     varchar(16)   NOT NULL                               COMMENT '调整类型: ADD加款 DEDUCT扣款',
  `item_type`       varchar(32)   NOT NULL                               COMMENT '项目类型: ATTENDANCE考勤扣款 PERFORMANCE绩效奖励 ADVANCE_RECOVERY垫付回收 ADMIN_PENALTY行政罚款 OTHER_ADD其他加款 OTHER_DEDUCT其他扣款',
  `amount`          decimal(14,2) NOT NULL                               COMMENT '金额（元，正数，类型决定正负）',
  `reason`          varchar(500)  NOT NULL                               COMMENT '原因/备注',
  `status`          varchar(16)   NOT NULL DEFAULT 'ACTIVE'              COMMENT '状态: ACTIVE有效 DELETED已删除',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_salary_month` (`salary_month`),
  KEY `idx_adjust_type` (`adjust_type`),
  KEY `idx_import_batch_id` (`import_batch_id`),
  KEY `idx_agent_month` (`agent_id`, `salary_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员加扣款记录表';


-- =====================================================
-- 15. ins_comm_adj_import_batch  加扣款导入批次表
-- 对应需求: 补充篇B §2.3 加扣款导入批次管理
-- =====================================================
CREATE TABLE `ins_comm_adj_import_batch` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `batch_no`        varchar(64)   NOT NULL                               COMMENT '导入批次号',
  `salary_month`    varchar(7)    NOT NULL                               COMMENT '工资月份',
  `file_name`       varchar(256)  NOT NULL                               COMMENT '上传文件名',
  `file_url`        varchar(512)  NOT NULL                               COMMENT '文件存储URL',
  `total_rows`      int           NOT NULL DEFAULT 0                     COMMENT '总行数',
  `success_rows`    int           NOT NULL DEFAULT 0                     COMMENT '成功导入行数',
  `fail_rows`       int           NOT NULL DEFAULT 0                     COMMENT '失败行数',
  `status`          varchar(16)   NOT NULL DEFAULT 'PENDING'             COMMENT '导入状态',
  `fail_detail_url` varchar(512)  DEFAULT NULL                           COMMENT '失败明细文件URL',
  `remark`          varchar(500)  DEFAULT NULL                           COMMENT '备注',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`, `tenant_id`),
  KEY `idx_salary_month` (`salary_month`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='加扣款导入批次表';


-- =====================================================
-- 16. ins_comm_commission_split  佣金分润链路表（多级结算归档）
-- 记录OVERRIDE类型佣金的完整分润链路，用于审计追溯
-- 对应需求: 补充篇A §3.1 多级结算分润明细
-- =====================================================
CREATE TABLE `ins_comm_commission_split` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `source_commission_id` bigint(20) NOT NULL                            COMMENT '源佣金记录ID（触发分润的原始FYC）',
  `source_agent_id` bigint(20)    NOT NULL                               COMMENT '源业务员ID',
  `source_agent_code` varchar(64) NOT NULL                               COMMENT '源业务员工号',
  `policy_no`       varchar(64)   NOT NULL                               COMMENT '保单号',
  `settle_period`   varchar(7)    NOT NULL                               COMMENT '结算周期 YYYY-MM',
  `split_level`     int           NOT NULL                               COMMENT '分润层级（1=直接上级，2=隔代，依此类推）',
  `recipient_agent_id` bigint(20) NOT NULL                               COMMENT '分润接收人ID（上级主任）',
  `recipient_agent_code` varchar(64) NOT NULL                            COMMENT '分润接收人工号',
  `recipient_agent_name` varchar(64) NOT NULL                            COMMENT '分润接收人姓名',
  `split_rate`      decimal(8,4)  NOT NULL                               COMMENT '分润比例',
  `source_commission_amount` decimal(14,2) NOT NULL                      COMMENT '源佣金金额',
  `split_amount`    decimal(14,2) NOT NULL                               COMMENT '分润金额',
  `multilevel_policy_id` bigint(20) DEFAULT NULL                        COMMENT '适用的多级结算政策ID',
  `commission_record_id` bigint(20) DEFAULT NULL                        COMMENT '生成的OVERRIDE佣金记录ID（关联ins_comm_record）',
  `status`          varchar(16)   NOT NULL DEFAULT 'PENDING'             COMMENT '状态: PENDING/APPROVED/PAID',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_source_commission_id` (`source_commission_id`),
  KEY `idx_recipient_agent_id` (`recipient_agent_id`),
  KEY `idx_settle_period` (`settle_period`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金分润链路归档表（多级结算审计）';

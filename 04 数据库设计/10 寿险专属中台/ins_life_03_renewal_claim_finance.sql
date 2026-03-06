-- =============================================================================
-- 保险中介平台 · intermediary-module-ins-life
-- 数据库：db_ins_life
-- Part 3：续期管理 + 理赔管理 + 财务管理 + 数据回传 + 报表模块
-- 对应需求：
--   阶段7-中篇A § 续期跟踪（PDF-128~131）
--   阶段7-中篇A § 理赔管理（PDF-138）
--   阶段7-中篇A § 数据回传（PDF-135~137）
--   阶段7-中篇B § 续期政策配置
--   阶段7-下篇Part1 § 财务管理（PDF-151~157）
--   阶段7-下篇Part2 § 报表管理（PDF-159~163）
-- 工程模块：intermediary-module-ins-life-server
-- 生成日期：2026-03-01
-- =============================================================================

USE `db_ins_life`;

-- =============================================================================
-- 一、续期管理模块
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. 续期跟踪记录表  ins_life_renewal_track
--    对应需求：PDF-128~131 续期跟踪-续期查询/批量导入/续期缴费
--    PC端业务员跟进记录 + C端用户续期缴费均写入此表
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_renewal_track` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `policy_id`        BIGINT        NOT NULL                                      COMMENT '保单ID，关联ins_policy_life.id',
  `policy_no`        VARCHAR(50)   NOT NULL                                      COMMENT '保单号（冗余）',
  `period_year`      INT           NOT NULL                                      COMMENT '续期年度（第几年），从2开始',
  `due_date`         DATE          NOT NULL                                      COMMENT '本期缴费到期日',
  `grace_end_date`   DATE          NOT NULL                                      COMMENT '宽限期截止日（due_date + 宽限期天数）',
  -- 跟进记录
  `contact_time`     DATETIME      DEFAULT NULL                                  COMMENT '联系时间',
  `contact_type`     VARCHAR(20)   DEFAULT NULL                                  COMMENT '联系方式：PHONE/WECHAT/SMS/VISIT',
  `contact_result`   VARCHAR(30)   DEFAULT NULL                                  COMMENT '联系结果：NO_ANSWER/PREPARE_PAY/HESITATE/REFUSE/PAID',
  `note`             VARCHAR(500)  DEFAULT NULL                                  COMMENT '备注',
  `next_plan_time`   DATETIME      DEFAULT NULL                                  COMMENT '下次跟进计划时间',
  -- 跟进状态：NOT_FOLLOWED未跟进/FOLLOWING跟进中/PAID已缴费/REFUSED已拒缴/ABANDONED放弃
  `follow_status`    VARCHAR(20)   NOT NULL DEFAULT 'NOT_FOLLOWED'               COMMENT '跟进状态',
  `last_follow_time` DATETIME      DEFAULT NULL                                  COMMENT '最后跟进时间',
  -- 缴费结果
  `paid_time`        DATETIME      DEFAULT NULL                                  COMMENT '实际缴费时间',
  `paid_amount`      DECIMAL(12,2) DEFAULT NULL                                  COMMENT '实际缴费金额',
  `paid_method`      VARCHAR(20)   DEFAULT NULL                                  COMMENT '缴费方式：WECHAT/ALIPAY/AUTO_DEDUCT/BANK',
  `payment_order_no` VARCHAR(50)   DEFAULT NULL                                  COMMENT '支付订单号',
  `operator_id`      BIGINT        DEFAULT NULL                                  COMMENT '跟进业务员ID',
  `operator_name`    VARCHAR(64)   DEFAULT NULL                                  COMMENT '跟进业务员姓名（冗余）',
  `import_batch_no`  VARCHAR(64)   DEFAULT NULL                                  COMMENT '批量导入批次号（PDF-131）',
  `creator`          VARCHAR(64)   DEFAULT ''                                    COMMENT '创建者',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP                                 COMMENT '更新时间',
  `deleted`          TINYINT       NOT NULL DEFAULT 0                            COMMENT '软删除',
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_policy_period` (`policy_id`, `period_year`),
  INDEX `idx_due_date` (`due_date`),
  INDEX `idx_follow_status` (`follow_status`),
  INDEX `idx_operator_id` (`operator_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险续期跟踪记录表（PDF-128~131，PC端跟进+C端缴费共用）';


-- -----------------------------------------------------------------------------
-- 2. 保费缴费记录表  ins_life_payment_record
--    对应需求：阶段8-中 C端缴费历史 + PC端续期缴费记录
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_payment_record` (
  `id`              BIGINT         NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `policy_id`       BIGINT         NOT NULL                                      COMMENT '保单ID',
  `policy_no`       VARCHAR(50)    NOT NULL                                      COMMENT '保单号（冗余）',
  `renewal_track_id` BIGINT        DEFAULT NULL                                  COMMENT '续期跟踪记录ID（续期缴费时关联）',
  `order_no`        VARCHAR(50)    NOT NULL                                      COMMENT '支付订单号',
  `payment_date`    DATE           NOT NULL                                      COMMENT '缴费日期（实收日期）',
  `amount`          DECIMAL(12,2)  NOT NULL                                      COMMENT '缴费金额（元）',
  `payment_method`  VARCHAR(20)    NOT NULL                                      COMMENT '缴费方式：WECHAT/ALIPAY/AUTO_DEDUCT/BANK',
  -- 状态：SUCCESS/FAILED/REFUNDED
  `status`          VARCHAR(20)    NOT NULL DEFAULT 'SUCCESS'                   COMMENT '缴费状态',
  -- 类型：FIRST_PAYMENT首期/RENEWAL续期/SUPPLEMENT补缴
  `payment_type`    VARCHAR(20)    NOT NULL                                      COMMENT '缴费类型',
  `period_year`     INT            DEFAULT NULL                                  COMMENT '对应保单年度（第几年）',
  `pay_channel`     VARCHAR(50)    DEFAULT NULL                                  COMMENT '支付渠道（微信/支付宝商户号等）',
  `channel_order_no` VARCHAR(100)  DEFAULT NULL                                  COMMENT '第三方支付渠道流水号',
  `creator`         VARCHAR(64)    DEFAULT ''                                    COMMENT '创建者',
  `create_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `tenant_id`       BIGINT         NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_order_no` (`order_no`),
  UNIQUE KEY `uk_order_no` (`order_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保费缴费记录表（首期+续期+补缴）';


-- -----------------------------------------------------------------------------
-- 3. 续期政策配置表  ins_life_renewal_policy
--    对应需求：阶段7-中篇B 续期政策配置
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_renewal_policy` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `policy_name`     VARCHAR(100)  NOT NULL                                       COMMENT '续期政策名称',
  `insurer_id`      BIGINT        DEFAULT NULL                                   COMMENT '适用保险公司（NULL=全部）',
  `category_code`   VARCHAR(20)   DEFAULT NULL                                   COMMENT '适用险种（NULL=全部）',
  `grace_period_days` INT         NOT NULL DEFAULT 60                            COMMENT '宽限期天数',
  `advance_notify_days` INT       NOT NULL DEFAULT 30                            COMMENT '提前提醒天数（多个值用逗号分隔存入下面字段）',
  `notify_days_config` VARCHAR(100) DEFAULT '30,15,7'                            COMMENT '提醒节点配置（逗号分隔天数，如30,15,7）',
  `auto_lapse_enabled` TINYINT    NOT NULL DEFAULT 1                             COMMENT '是否开启自动失效：0否 1是',
  `auto_lapse_days` INT           NOT NULL DEFAULT 0                             COMMENT '超宽限期后自动失效延迟天数',
  `status`          TINYINT       NOT NULL DEFAULT 1                             COMMENT '状态：0停用 1启用',
  `remark`          VARCHAR(300)  DEFAULT NULL                                   COMMENT '备注',
  `creator`         VARCHAR(64)   DEFAULT ''                                     COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `updater`         VARCHAR(64)   DEFAULT ''                                     COMMENT '更新者',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`         TINYINT       NOT NULL DEFAULT 0                             COMMENT '软删除',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险续期政策配置表（宽限期/提醒节点/自动失效规则）';


-- =============================================================================
-- 二、理赔管理模块
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 4. 理赔案件主表  ins_life_claim_record
--    对应需求：PDF-138 理赔管理（新增/查询/修改/明细）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_claim_record` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `policy_id`       BIGINT        NOT NULL                                       COMMENT '保单ID',
  `policy_no`       VARCHAR(50)   NOT NULL                                       COMMENT '保单号（冗余）',
  `insurer_id`      BIGINT        NOT NULL                                       COMMENT '保险公司ID（冗余）',
  `insurer_name`    VARCHAR(100)  DEFAULT NULL                                   COMMENT '保险公司名称（冗余）',
  `insured_name`    VARCHAR(50)   NOT NULL                                       COMMENT '被保人姓名（冗余）',
  `insured_id_no`   VARCHAR(512)  DEFAULT NULL                                   COMMENT '被保人证件号（AES加密）',
  `accident_time`   DATETIME      NOT NULL                                       COMMENT '出险时间',
  -- 出险类型：DEATH身故/TOTAL_DISABILITY全残/CRITICAL重大疾病/MINOR_ILLNESS轻症/HOSPITAL住院/ACCIDENT意外
  `accident_type`   VARCHAR(30)   NOT NULL                                       COMMENT '出险类型',
  `accident_desc`   TEXT          NOT NULL                                       COMMENT '出险经过（最多2000字）',
  `case_no`         VARCHAR(50)   DEFAULT NULL                                   COMMENT '赔案号（保司分配，可后补）',
  `submitted_docs`  JSON          DEFAULT NULL                                   COMMENT '已提交材料列表（死亡证明/医疗报告/身份证等）',
  `agent_id`        BIGINT        NOT NULL                                       COMMENT '负责业务员ID（默认保单归属业务员）',
  `agent_name`      VARCHAR(64)   DEFAULT NULL                                   COMMENT '业务员姓名（冗余）',
  `org_id`          BIGINT        DEFAULT NULL                                   COMMENT '机构ID（冗余）',
  -- 状态：PROCESSING处理中/SETTLED已结案/REJECTED已拒赔
  `status`          VARCHAR(20)   NOT NULL DEFAULT 'PROCESSING'                  COMMENT '案件状态',
  -- 赔付结果
  `claim_amount`    DECIMAL(15,2) DEFAULT NULL                                   COMMENT '赔付金额（元）',
  `claim_date`      DATE          DEFAULT NULL                                   COMMENT '赔付日期',
  `claim_account`   VARCHAR(200)  DEFAULT NULL                                   COMMENT '赔付账号信息',
  `claim_result_desc` VARCHAR(500) DEFAULT NULL                                  COMMENT '赔付结果说明',
  -- 若出险类型=身故，结案时联动保单状态变更为LAPSED
  `policy_status_updated` TINYINT NOT NULL DEFAULT 0                             COMMENT '是否已联动更新保单状态：0否 1是',
  `creator`         VARCHAR(64)   DEFAULT ''                                     COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `updater`         VARCHAR(64)   DEFAULT ''                                     COMMENT '更新者',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`         TINYINT       NOT NULL DEFAULT 0                             COMMENT '软删除',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_agent_id` (`agent_id`),
  INDEX `idx_org_id` (`org_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_accident_type` (`accident_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险理赔案件主表（PDF-138）';


-- -----------------------------------------------------------------------------
-- 5. 理赔跟进记录表  ins_life_claim_follow
--    对应需求：PDF-138 案件跟进（添加跟进进展/材料要求）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_claim_follow` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `claim_id`        BIGINT        NOT NULL                                       COMMENT '理赔案件ID',
  `follow_time`     DATETIME      NOT NULL                                       COMMENT '跟进时间',
  `progress`        TEXT          NOT NULL                                       COMMENT '处理进展描述',
  `doc_require`     TEXT          DEFAULT NULL                                   COMMENT '保司补充材料要求清单',
  `attachment_urls` JSON          DEFAULT NULL                                   COMMENT '附件URL列表（OSS路径数组）',
  `operator_id`     BIGINT        NOT NULL                                       COMMENT '操作人ID',
  `operator_name`   VARCHAR(64)   DEFAULT NULL                                   COMMENT '操作人姓名（冗余）',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_claim_id` (`claim_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险理赔案件跟进记录表（PDF-138）';


-- =============================================================================
-- 三、数据回传模块
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 6. 数据回传保司配置表  ins_life_data_return_config
--    对应需求：PDF-135~137 数据回传（交互平台/定时回传）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_data_return_config` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `insurer_id`      BIGINT        NOT NULL                                       COMMENT '保险公司ID',
  `insurer_name`    VARCHAR(100)  DEFAULT NULL                                   COMMENT '保险公司名称（冗余）',
  `return_type`     VARCHAR(20)   NOT NULL                                       COMMENT '回传类型：POLICY保单/PREMIUM保费/COMMISSION佣金/RENEWAL续期',
  `api_url`         VARCHAR(500)  NOT NULL                                       COMMENT '回传API地址',
  `api_method`      VARCHAR(10)   DEFAULT 'POST'                                 COMMENT '请求方式：GET/POST',
  `auth_type`       VARCHAR(20)   DEFAULT 'SIGN'                                 COMMENT '认证方式：SIGN签名/TOKEN令牌/BASIC',
  `auth_config`     VARCHAR(1000) DEFAULT NULL                                   COMMENT '认证配置JSON（加密存储）',
  `data_format`     VARCHAR(20)   DEFAULT 'JSON'                                 COMMENT '数据格式：JSON/XML',
  `cron_expression` VARCHAR(50)   DEFAULT NULL                                   COMMENT 'XXL-Job Cron表达式（定时回传时有值）',
  `enabled`         TINYINT       NOT NULL DEFAULT 1                             COMMENT '是否启用：0否 1是',
  `remark`          VARCHAR(300)  DEFAULT NULL                                   COMMENT '备注',
  `creator`         VARCHAR(64)   DEFAULT ''                                     COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `updater`         VARCHAR(64)   DEFAULT ''                                     COMMENT '更新者',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`         TINYINT       NOT NULL DEFAULT 0                             COMMENT '软删除',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_insurer_id` (`insurer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险数据回传保司配置表（PDF-135~137）';


-- -----------------------------------------------------------------------------
-- 7. 数据回传执行日志  ins_life_data_return_log
--    对应需求：PDF-136~137 回传执行结果记录/查看
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_data_return_log` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `config_id`       BIGINT        NOT NULL                                       COMMENT '回传配置ID',
  `insurer_id`      BIGINT        NOT NULL                                       COMMENT '保险公司ID（冗余）',
  `return_type`     VARCHAR(20)   NOT NULL                                       COMMENT '回传类型',
  `batch_no`        VARCHAR(64)   NOT NULL                                       COMMENT '回传批次号',
  `trigger_type`    VARCHAR(20)   NOT NULL                                       COMMENT '触发方式：MANUAL手动/SCHEDULE定时',
  `data_period`     VARCHAR(20)   DEFAULT NULL                                   COMMENT '数据期间（如2025-12）',
  `total_count`     INT           DEFAULT 0                                      COMMENT '回传总条数',
  `success_count`   INT           DEFAULT 0                                      COMMENT '成功条数',
  `fail_count`      INT           DEFAULT 0                                      COMMENT '失败条数',
  `request_body`    TEXT          DEFAULT NULL                                   COMMENT '请求报文（摘要，超长截断）',
  `response_body`   TEXT          DEFAULT NULL                                   COMMENT '响应报文（摘要）',
  -- 状态：SUCCESS/FAILED/PARTIAL_FAIL部分失败
  `status`          VARCHAR(20)   NOT NULL                                       COMMENT '回传状态',
  `error_msg`       VARCHAR(500)  DEFAULT NULL                                   COMMENT '错误信息',
  `execute_time`    DATETIME      DEFAULT NULL                                   COMMENT '执行时间（耗时用end_time-execute_time）',
  `end_time`        DATETIME      DEFAULT NULL                                   COMMENT '结束时间',
  `operator_id`     BIGINT        DEFAULT NULL                                   COMMENT '手动触发操作人ID',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`),
  INDEX `idx_config_id` (`config_id`),
  INDEX `idx_insurer_type` (`insurer_id`, `return_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险数据回传执行日志（PDF-136~137）';


-- =============================================================================
-- 四、财务管理模块
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 8. 上游结算统计表  ins_life_upstream_settlement
--    对应需求：PDF-151 上游结算统计
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_upstream_settlement` (
  `id`              BIGINT         NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `insurer_id`      BIGINT         NOT NULL                                      COMMENT '保险公司ID',
  `insurer_name`    VARCHAR(100)   DEFAULT NULL                                  COMMENT '保险公司名称（冗余）',
  `settle_month`    VARCHAR(7)     NOT NULL                                      COMMENT '结算月份（格式YYYY-MM）',
  `settle_type`     VARCHAR(20)    NOT NULL DEFAULT 'FYC'                       COMMENT '结算类型：FYC首年佣金/RYC续年佣金',
  `policy_count`    INT            NOT NULL DEFAULT 0                            COMMENT '保单件数',
  `total_premium`   DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT '总保费（元）',
  `fyc_amount`      DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT 'FYC佣金金额（元）',
  `ryc_amount`      DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT 'RYC续年佣金金额（元）',
  `std_premium`     DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT '折标保费（元）',
  `category_code`   VARCHAR(20)    DEFAULT NULL                                  COMMENT '险种分类（NULL=全部）',
  `org_id`          BIGINT         DEFAULT NULL                                  COMMENT '机构ID（NULL=全机构汇总）',
  -- 状态：PENDING待核对/CONFIRMED已确认/SETTLED已结算
  `status`          VARCHAR(20)    NOT NULL DEFAULT 'PENDING'                   COMMENT '结算状态',
  `confirm_time`    DATETIME       DEFAULT NULL                                  COMMENT '确认时间',
  `settle_time`     DATETIME       DEFAULT NULL                                  COMMENT '实际结算时间',
  `remark`          VARCHAR(300)   DEFAULT NULL                                  COMMENT '备注',
  `creator`         VARCHAR(64)    DEFAULT ''                                    COMMENT '创建者',
  `create_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `updater`         VARCHAR(64)    DEFAULT ''                                    COMMENT '更新者',
  `update_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`         TINYINT        NOT NULL DEFAULT 0                            COMMENT '软删除',
  `tenant_id`       BIGINT         NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_insurer_month` (`insurer_id`, `settle_month`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险上游结算统计表（PDF-151）';


-- -----------------------------------------------------------------------------
-- 9. 保单结算明细表  ins_life_policy_settlement
--    对应需求：PDF-152 保单结算（明细，含FYC/RYC金额）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_policy_settlement` (
  `id`              BIGINT         NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `settlement_id`   BIGINT         NOT NULL                                      COMMENT '上游结算ID，关联ins_life_upstream_settlement.id',
  `policy_id`       BIGINT         NOT NULL                                      COMMENT '保单ID',
  `policy_no`       VARCHAR(50)    NOT NULL                                      COMMENT '保单号（冗余）',
  `insurer_id`      BIGINT         NOT NULL                                      COMMENT '保险公司ID（冗余）',
  `insurer_name`    VARCHAR(100)   DEFAULT NULL                                  COMMENT '保险公司名称（冗余）',
  `category_code`   VARCHAR(20)    DEFAULT NULL                                  COMMENT '险种分类',
  `agent_id`        BIGINT         NOT NULL                                      COMMENT '业务员ID',
  `annual_premium`  DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT '年度保费（元）',
  `std_premium`     DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT '折标保费（元）',
  `fyc_rate`        DECIMAL(8,4)   DEFAULT NULL                                  COMMENT 'FYC佣金率（%）',
  `fyc_amount`      DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT 'FYC金额（元）',
  `ryc_rate`        DECIMAL(8,4)   DEFAULT NULL                                  COMMENT 'RYC佣金率（%）',
  `ryc_amount`      DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT 'RYC金额（元）',
  `settle_month`    VARCHAR(7)     NOT NULL                                      COMMENT '结算月份',
  `status`          VARCHAR(20)    NOT NULL DEFAULT 'PENDING'                   COMMENT '结算状态',
  `basic_law_id`    BIGINT         DEFAULT NULL                                  COMMENT '所属基本法ID（PDF-162 特有字段）',
  `basic_law_name`  VARCHAR(100)   DEFAULT NULL                                  COMMENT '基本法名称（冗余）',
  `creator`         VARCHAR(64)    DEFAULT ''                                    COMMENT '创建者',
  `create_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `deleted`         TINYINT        NOT NULL DEFAULT 0                            COMMENT '软删除',
  `tenant_id`       BIGINT         NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_settlement_id` (`settlement_id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_agent_id` (`agent_id`),
  INDEX `idx_settle_month` (`settle_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保单结算明细表（PDF-152/162，含FYC/RYC/所属基本法）';


-- -----------------------------------------------------------------------------
-- 10. 机构计算表  ins_life_org_calculation
--     对应需求：PDF-153 机构计算
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_org_calculation` (
  `id`              BIGINT         NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `org_id`          BIGINT         NOT NULL                                      COMMENT '机构ID',
  `org_name`        VARCHAR(100)   DEFAULT NULL                                  COMMENT '机构名称（冗余）',
  `calc_month`      VARCHAR(7)     NOT NULL                                      COMMENT '计算月份（YYYY-MM）',
  `fyp_amount`      DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT 'FYP首年保费合计（元）',
  `policy_count`    INT            NOT NULL DEFAULT 0                            COMMENT '保单件数',
  `agent_count`     INT            NOT NULL DEFAULT 0                            COMMENT '出单人力',
  `fyc_amount`      DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT 'FYC佣金合计',
  `ryc_amount`      DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT 'RYC续年佣金合计',
  `performance_bonus` DECIMAL(15,2) DEFAULT NULL                                 COMMENT '绩效奖金（元）',
  `status`          VARCHAR(20)    NOT NULL DEFAULT 'DRAFT'                     COMMENT '状态：DRAFT草稿/CONFIRMED确认/SETTLED已结算',
  `remark`          VARCHAR(300)   DEFAULT NULL                                  COMMENT '备注',
  `creator`         VARCHAR(64)    DEFAULT ''                                    COMMENT '创建者',
  `create_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `updater`         VARCHAR(64)    DEFAULT ''                                    COMMENT '更新者',
  `update_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`         TINYINT        NOT NULL DEFAULT 0                            COMMENT '软删除',
  `tenant_id`       BIGINT         NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_org_month` (`org_id`, `calc_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险机构计算表（PDF-153）';


-- -----------------------------------------------------------------------------
-- 11. 机构对账表  ins_life_org_reconcile
--     对应需求：PDF-154 机构对账
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_org_reconcile` (
  `id`               BIGINT         NOT NULL AUTO_INCREMENT                      COMMENT '主键ID',
  `org_id`           BIGINT         NOT NULL                                     COMMENT '机构ID',
  `insurer_id`       BIGINT         NOT NULL                                     COMMENT '保险公司ID',
  `reconcile_month`  VARCHAR(7)     NOT NULL                                     COMMENT '对账月份',
  `system_amount`    DECIMAL(15,2)  NOT NULL DEFAULT 0.00                        COMMENT '系统计算金额（元）',
  `insurer_amount`   DECIMAL(15,2)  DEFAULT NULL                                 COMMENT '保司确认金额（元）',
  `diff_amount`      DECIMAL(15,2)  DEFAULT NULL                                 COMMENT '差异金额（系统-保司）',
  `diff_reason`      VARCHAR(500)   DEFAULT NULL                                 COMMENT '差异原因',
  `status`           VARCHAR(20)    NOT NULL DEFAULT 'PENDING'                  COMMENT '状态：PENDING待核/CONFIRMED已核/DISPUTED争议/SETTLED已结算',
  `reconcile_time`   DATETIME       DEFAULT NULL                                 COMMENT '对账完成时间',
  `remark`           VARCHAR(300)   DEFAULT NULL                                 COMMENT '备注',
  `creator`          VARCHAR(64)    DEFAULT ''                                   COMMENT '创建者',
  `create_time`      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP           COMMENT '创建时间',
  `updater`          VARCHAR(64)    DEFAULT ''                                   COMMENT '更新者',
  `update_time`      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP                                 COMMENT '更新时间',
  `deleted`          TINYINT        NOT NULL DEFAULT 0                           COMMENT '软删除',
  `tenant_id`        BIGINT         NOT NULL DEFAULT 0                           COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_org_insurer_month` (`org_id`, `insurer_id`, `reconcile_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险机构对账表（PDF-154）';


-- -----------------------------------------------------------------------------
-- 12. 代理人个税查询表  ins_life_agent_tax
--     对应需求：PDF-155 代理个税查询
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_agent_tax` (
  `id`              BIGINT         NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `agent_id`        BIGINT         NOT NULL                                      COMMENT '代理人ID',
  `agent_name`      VARCHAR(64)    DEFAULT NULL                                  COMMENT '代理人姓名（冗余）',
  `tax_year`        INT            NOT NULL                                      COMMENT '税务年度',
  `tax_month`       INT            DEFAULT NULL                                  COMMENT '税务月份（NULL=年汇算）',
  `total_income`    DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT '总收入（元）',
  `taxable_income`  DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT '应税收入（元）',
  `tax_amount`      DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT '应纳税额（元）',
  `deduct_amount`   DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT '扣除税额（元）',
  `net_income`      DECIMAL(15,2)  NOT NULL DEFAULT 0.00                         COMMENT '税后净收入（元）',
  `tax_rate`        DECIMAL(5,2)   DEFAULT NULL                                  COMMENT '适用税率（%）',
  `status`          VARCHAR(20)    NOT NULL DEFAULT 'CALCULATED'                COMMENT '状态：CALCULATED已计算/CONFIRMED已确认/SUBMITTED已申报',
  `calc_time`       DATETIME       DEFAULT NULL                                  COMMENT '计算时间',
  `creator`         VARCHAR(64)    DEFAULT ''                                    COMMENT '创建者',
  `create_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `deleted`         TINYINT        NOT NULL DEFAULT 0                            COMMENT '软删除',
  `tenant_id`       BIGINT         NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_agent_year_month` (`agent_id`, `tax_year`, `tax_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险代理人个税查询表（PDF-155）';


-- -----------------------------------------------------------------------------
-- 13. 薪资计算表  ins_life_salary_calculation
--     对应需求：PDF-156 薪资计算
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_salary_calculation` (
  `id`              BIGINT         NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `agent_id`        BIGINT         NOT NULL                                      COMMENT '代理人ID',
  `agent_name`      VARCHAR(64)    DEFAULT NULL                                  COMMENT '代理人姓名（冗余）',
  `org_id`          BIGINT         DEFAULT NULL                                  COMMENT '机构ID',
  `calc_month`      VARCHAR(7)     NOT NULL                                      COMMENT '计算月份（YYYY-MM）',
  `base_salary`     DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT '基本薪资（元）',
  `fyc_income`      DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT 'FYC佣金收入（元）',
  `ryc_income`      DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT 'RYC续年佣金收入（元）',
  `bonus_income`    DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT '奖金收入（元）',
  `deduction`       DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT '扣款合计（元）',
  `tax_deduction`   DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT '代扣税款（元）',
  `net_salary`      DECIMAL(12,2)  NOT NULL DEFAULT 0.00                         COMMENT '税后实发金额（元）',
  `status`          VARCHAR(20)    NOT NULL DEFAULT 'DRAFT'                     COMMENT '状态：DRAFT草稿/CONFIRMED确认/PAID已发放',
  `pay_time`        DATETIME       DEFAULT NULL                                  COMMENT '实际发放时间',
  `remark`          VARCHAR(300)   DEFAULT NULL                                  COMMENT '备注',
  `creator`         VARCHAR(64)    DEFAULT ''                                    COMMENT '创建者',
  `create_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `updater`         VARCHAR(64)    DEFAULT ''                                    COMMENT '更新者',
  `update_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`         TINYINT        NOT NULL DEFAULT 0                            COMMENT '软删除',
  `tenant_id`       BIGINT         NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_agent_month` (`agent_id`, `calc_month`),
  INDEX `idx_org_month` (`org_id`, `calc_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险代理人薪资计算表（PDF-156）';


-- -----------------------------------------------------------------------------
-- 14. 上游加扣管理表  ins_life_adjustment
--     对应需求：PDF-157 上游加扣管理（退单/加收等调整）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_adjustment` (
  `id`              BIGINT         NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `insurer_id`      BIGINT         NOT NULL                                      COMMENT '保险公司ID',
  `settlement_id`   BIGINT         DEFAULT NULL                                  COMMENT '关联结算ID',
  `adjust_month`    VARCHAR(7)     NOT NULL                                      COMMENT '调整月份（YYYY-MM）',
  -- 调整类型：RETURN_CHARGE退单/ADDITIONAL_CHARGE加收/PENALTY罚款/BONUS奖励
  `adjust_type`     VARCHAR(20)    NOT NULL                                      COMMENT '调整类型',
  `adjust_amount`   DECIMAL(12,2)  NOT NULL                                      COMMENT '调整金额（元，正=加收 负=退回）',
  `adjust_reason`   VARCHAR(500)   NOT NULL                                      COMMENT '调整原因',
  `policy_no`       VARCHAR(50)    DEFAULT NULL                                  COMMENT '关联保单号（单笔调整时有值）',
  `status`          VARCHAR(20)    NOT NULL DEFAULT 'PENDING'                   COMMENT '状态：PENDING待处理/CONFIRMED已确认/EXECUTED已执行',
  `executor_id`     BIGINT         DEFAULT NULL                                  COMMENT '执行人ID',
  `execute_time`    DATETIME       DEFAULT NULL                                  COMMENT '执行时间',
  `remark`          VARCHAR(300)   DEFAULT NULL                                  COMMENT '备注',
  `creator`         VARCHAR(64)    DEFAULT ''                                    COMMENT '创建者',
  `create_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `updater`         VARCHAR(64)    DEFAULT ''                                    COMMENT '更新者',
  `update_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`         TINYINT        NOT NULL DEFAULT 0                            COMMENT '软删除',
  `tenant_id`       BIGINT         NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_insurer_month` (`insurer_id`, `adjust_month`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险上游加扣管理表（PDF-157，退单/加收/奖励等调整）';


-- =============================================================================
-- 五、报表管理模块
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 15. 监管报表记录表  ins_life_regulatory_report
--     对应需求：PDF-159 监管报表（按月/季/年生成，支持标记已提交）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_regulatory_report` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `report_type`     VARCHAR(20)   NOT NULL                                       COMMENT '报表类型：MONTHLY月报/QUARTERLY季报/YEARLY年报',
  `period`          VARCHAR(20)   NOT NULL                                       COMMENT '报表期间（如2025-Q4/2025-12/2025）',
  `insurer_id`      BIGINT        DEFAULT NULL                                   COMMENT '保险公司ID（NULL=全部）',
  `org_id`          BIGINT        DEFAULT NULL                                   COMMENT '机构ID（NULL=全部）',
  `file_url`        VARCHAR(500)  DEFAULT NULL                                   COMMENT '报表文件URL（OSS）',
  `total_policies`  INT           DEFAULT 0                                      COMMENT '保单总件数',
  `new_premium`     DECIMAL(15,2) DEFAULT NULL                                   COMMENT '新单保费金额累计（元，已开票）',
  -- 生成状态：GENERATING生成中/COMPLETED完成/FAILED失败
  `gen_status`      VARCHAR(20)   NOT NULL DEFAULT 'GENERATING'                  COMMENT '生成状态',
  -- 提交状态：NOT_SUBMITTED未提交/SUBMITTED已提交
  `submit_status`   VARCHAR(20)   NOT NULL DEFAULT 'NOT_SUBMITTED'               COMMENT '提交状态',
  `submit_time`     DATETIME      DEFAULT NULL                                   COMMENT '提交时间（手动标记）',
  `submit_operator` BIGINT        DEFAULT NULL                                   COMMENT '提交操作人ID',
  `gen_time`        DATETIME      DEFAULT NULL                                   COMMENT '生成完成时间',
  `operator_id`     BIGINT        DEFAULT NULL                                   COMMENT '生成操作人ID',
  `creator`         VARCHAR(64)   DEFAULT ''                                     COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `updater`         VARCHAR(64)   DEFAULT ''                                     COMMENT '更新者',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_report_type_period` (`report_type`, `period`),
  INDEX `idx_submit_status` (`submit_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险监管报表记录表（PDF-159，含标记已提交功能）';


-- =============================================================================
-- Part 3 表清单（共15张表）
-- ┌──────────────────────────────────────────┬───────────────────────────────┐
-- │ 表名                                     │ 说明                           │
-- ├──────────────────────────────────────────┼───────────────────────────────┤
-- │ ins_life_renewal_track                   │ 续期跟踪记录                   │
-- │ ins_life_payment_record                  │ 保费缴费记录                   │
-- │ ins_life_renewal_policy                  │ 续期政策配置                   │
-- │ ins_life_claim_record                    │ 理赔案件主表                   │
-- │ ins_life_claim_follow                    │ 理赔跟进记录                   │
-- │ ins_life_data_return_config              │ 数据回传保司配置               │
-- │ ins_life_data_return_log                 │ 数据回传执行日志               │
-- │ ins_life_upstream_settlement             │ 上游结算统计                   │
-- │ ins_life_policy_settlement               │ 保单结算明细                   │
-- │ ins_life_org_calculation                 │ 机构计算                       │
-- │ ins_life_org_reconcile                   │ 机构对账                       │
-- │ ins_life_agent_tax                       │ 代理人个税查询                 │
-- │ ins_life_salary_calculation              │ 薪资计算                       │
-- │ ins_life_adjustment                      │ 上游加扣管理                   │
-- │ ins_life_regulatory_report               │ 监管报表记录                   │
-- └──────────────────────────────────────────┴───────────────────────────────┘
-- =============================================================================

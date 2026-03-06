-- =============================================================================
-- 保险中介平台 · intermediary-module-ins-life
-- 数据库：db_ins_life
-- Part 2：寿险保单模块（Policy）
-- 对应需求：
--   阶段7-上篇 § 个险保单管理（PDF-110~124）
--   阶段7-上篇 § 团险保单管理（PDF-115）
--   阶段7-上篇 § 回执/回访/保全/孤儿单（PDF-116~127、132~134）
--   阶段8-中   § C端投保流程与C端保单管理
-- 工程模块：intermediary-module-ins-order-server（保单订单中台，主表归属）
-- 生成日期：2026-03-01
-- =============================================================================

USE `db_ins_life`;

-- -----------------------------------------------------------------------------
-- 1. 寿险保单主表  ins_policy_life
--    PC端、App端、C端保单统一录入此表（通过 source 字段区分来源）
--    对应需求：PDF-110 个险保单录入、阶段8 C端投保提交
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_policy_life` (
  `id`                     BIGINT         NOT NULL AUTO_INCREMENT                COMMENT '保单ID',
  `policy_no`              VARCHAR(50)    NOT NULL                               COMMENT '保单号/投保单号',
  `order_no`               VARCHAR(50)    DEFAULT NULL                           COMMENT 'C端投保订单号（C端入口时有值）',
  `insurer_id`             BIGINT         NOT NULL                               COMMENT '保险公司ID',
  `insurer_name`           VARCHAR(100)   DEFAULT NULL                           COMMENT '保险公司名称（冗余）',
  `product_id`             BIGINT         DEFAULT NULL                           COMMENT '寿险产品ID，关联ins_life_product.id',
  `product_name`           VARCHAR(100)   DEFAULT NULL                           COMMENT '产品名称（冗余）',
  `category_code`          VARCHAR(20)    NOT NULL                               COMMENT '险种分类：LIFE/CRITICAL/MEDICAL/ACCIDENT/SAVING/WHOLE_LIFE',
  -- 投保人信息（快照 + 关联客户）
  `customer_id`            BIGINT         DEFAULT NULL                           COMMENT '投保人客户ID，关联ins_customer.id',
  `holder_name`            VARCHAR(50)    NOT NULL                               COMMENT '投保人姓名',
  `holder_id_type`         VARCHAR(20)    NOT NULL                               COMMENT '投保人证件类型：ID_CARD/PASSPORT/HKMO',
  `holder_id_no`           VARCHAR(512)   NOT NULL                               COMMENT '投保人证件号（AES-256加密存储）',
  `holder_birth_date`      DATE           DEFAULT NULL                           COMMENT '投保人出生日期',
  `holder_gender`          CHAR(1)        DEFAULT NULL                           COMMENT '投保人性别：M/F',
  `holder_phone`           VARCHAR(50)    DEFAULT NULL                           COMMENT '投保人手机号（AES加密）',
  -- 业务员
  `agent_id`               BIGINT         DEFAULT NULL                           COMMENT '保单服务人（归属业务员）ID',
  `agent_name`             VARCHAR(64)    DEFAULT NULL                           COMMENT '服务人姓名（冗余）',
  `sales_agent_id`         BIGINT         DEFAULT NULL                           COMMENT '保单销售人ID（可与服务人不同）',
  `sales_agent_name`       VARCHAR(64)    DEFAULT NULL                           COMMENT '销售人姓名（冗余）',
  -- 机构
  `org_id`                 BIGINT         DEFAULT NULL                           COMMENT '所属机构ID，关联sys_dept.id',
  `org_name`               VARCHAR(100)   DEFAULT NULL                           COMMENT '机构名称（冗余）',
  -- 保单日期
  `sign_date`              DATE           DEFAULT NULL                           COMMENT '签单/投保日期',
  `underwrite_date`        DATE           DEFAULT NULL                           COMMENT '承保日期（保司实际承保）',
  `start_date`             DATE           NOT NULL                               COMMENT '起保日期（保险起期）',
  `end_date`               DATE           NOT NULL                               COMMENT '到期日期（保险止期）',
  `effective_date`         DATE           DEFAULT NULL                           COMMENT '保单生效日',
  -- 缴费信息
  `payment_method`         VARCHAR(20)    NOT NULL                               COMMENT '缴费方式：SINGLE/ANNUAL/HALF_YEAR/QUARTER/MONTHLY',
  `payment_period`         INT            NOT NULL DEFAULT 1                     COMMENT '缴费期间（年），趸缴=1',
  `annual_premium`         DECIMAL(12,2)  NOT NULL                               COMMENT '年度保费/首期保费（元）',
  `renewal_premium`        DECIMAL(12,2)  DEFAULT NULL                           COMMENT '续期保费（元）',
  `next_payment_date`      DATE           DEFAULT NULL                           COMMENT '下次缴费日（由定时任务计算维护）',
  `grace_period_days`      INT            NOT NULL DEFAULT 60                    COMMENT '宽限期天数（继承产品配置）',
  `lapsed_date`            DATE           DEFAULT NULL                           COMMENT '失效日期',
  -- 结算保费（用于佣金计算）
  `upstream_std_premium`   DECIMAL(12,2)  DEFAULT NULL                           COMMENT '上游标准保费',
  `downstream_first_std_premium`  DECIMAL(12,2) DEFAULT NULL                    COMMENT '下游首年标准保费',
  `downstream_renewal_std_premium` DECIMAL(12,2) DEFAULT NULL                   COMMENT '下游续期标准保费',
  `upstream_std_coef`      DECIMAL(8,4)   DEFAULT 1.0000                         COMMENT '上游折标系数（默认100%）',
  `downstream_first_coef`  DECIMAL(8,4)   DEFAULT 1.0000                         COMMENT '下游首年折标系数',
  `value_premium`          DECIMAL(12,2)  DEFAULT NULL                           COMMENT '价值保费',
  -- 业务标志
  `business_type`          VARCHAR(20)    DEFAULT 'NEW'                          COMMENT '业务类型：NEW新单/RENEW续保/TRANSFER转保',
  `is_reinstatement`       TINYINT        NOT NULL DEFAULT 0                     COMMENT '是否复效保单：0否 1是',
  `policy_type`            VARCHAR(10)    NOT NULL DEFAULT 'INDIVIDUAL'          COMMENT '保单类型：INDIVIDUAL个险/GROUP团险',
  -- 来源
  `source`                 VARCHAR(20)    NOT NULL DEFAULT 'PC'                  COMMENT '录入来源：PC管理后台/APP业务员/C_END_C端/IMPORT批量导入',
  -- 状态：ACTIVE有效/PENDING待核保/OVERDUE逾期/LAPSED失效/CANCELLED退保/MATURED满期/REJECTED拒保
  `policy_status`          VARCHAR(30)    NOT NULL DEFAULT 'ACTIVE'              COMMENT '保单状态',
  `underwriting_conditions` JSON          DEFAULT NULL                           COMMENT '核保附加条件（C端核保有条件时写入）',
  -- C端专属
  `member_id`              BIGINT         DEFAULT NULL                           COMMENT 'C端会员ID，关联member_user.id（C端投保时有值）',
  `auto_deduct_status`     VARCHAR(20)    DEFAULT 'NONE'                         COMMENT '代扣状态：NONE/SIGNING/ACTIVE/EXPIRED/CANCELLED/FAILED',
  `e_policy_url`           VARCHAR(500)   DEFAULT NULL                           COMMENT '电子保单PDF地址（OSS）',
  -- 回执/回访状态（冗余，避免关联查询）
  `receipt_status`         TINYINT        NOT NULL DEFAULT 0                     COMMENT '回执状态：0待回执 1已回执',
  `visit_status`           TINYINT        NOT NULL DEFAULT 0                     COMMENT '回访状态：0待回访 1已回访',
  `remark`                 VARCHAR(500)   DEFAULT NULL                           COMMENT '备注',
  `creator`                VARCHAR(64)    DEFAULT ''                             COMMENT '创建者',
  `create_time`            DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`                VARCHAR(64)    DEFAULT ''                             COMMENT '更新者',
  `update_time`            DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                           ON UPDATE CURRENT_TIMESTAMP                           COMMENT '更新时间',
  `deleted`                TINYINT        NOT NULL DEFAULT 0                     COMMENT '软删除：0未删除 1已删除',
  `tenant_id`              BIGINT         NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_insurer_policy_no` (`insurer_id`, `policy_no`, `deleted`),
  INDEX `idx_agent_id` (`agent_id`),
  INDEX `idx_org_id` (`org_id`),
  INDEX `idx_customer_id` (`customer_id`),
  INDEX `idx_member_id` (`member_id`),
  INDEX `idx_start_date` (`start_date`),
  INDEX `idx_next_payment_date` (`next_payment_date`),
  INDEX `idx_policy_status` (`policy_status`),
  INDEX `idx_category_code` (`category_code`),
  INDEX `idx_deleted` (`deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保单主表（PDF-110，PC/App/C端统一，source字段区分）';


-- -----------------------------------------------------------------------------
-- 2. 保单险种信息子表  ins_life_policy_coverage
--    对应需求：PDF-110 第三步-险种信息（主险+附加险，可多条）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_policy_coverage` (
  `id`             BIGINT         NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `policy_id`      BIGINT         NOT NULL                                       COMMENT '保单ID，关联ins_policy_life.id',
  `policy_no`      VARCHAR(50)    NOT NULL                                       COMMENT '保单号（冗余）',
  `coverage_type`  VARCHAR(20)    NOT NULL DEFAULT 'MAIN'                        COMMENT '险种类型：MAIN主险/RIDER附加险',
  `product_id`     BIGINT         DEFAULT NULL                                   COMMENT '险种产品ID',
  `product_code`   VARCHAR(50)    DEFAULT NULL                                   COMMENT '险种产品代码',
  `product_name`   VARCHAR(100)   NOT NULL                                       COMMENT '险种名称',
  `coverage_amount` DECIMAL(15,2) NOT NULL                                       COMMENT '保额（元）',
  `coverage_premium` DECIMAL(12,2) NOT NULL                                      COMMENT '险种保费（元）',
  `coverage_period` VARCHAR(50)   DEFAULT NULL                                   COMMENT '保险期间，如"终身"/"20年"',
  `payment_period` VARCHAR(20)    DEFAULT NULL                                   COMMENT '缴费期',
  `sort_order`     INT            NOT NULL DEFAULT 0                             COMMENT '排序（主险在前）',
  `creator`        VARCHAR(64)    DEFAULT ''                                     COMMENT '创建者',
  `create_time`    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `deleted`        TINYINT        NOT NULL DEFAULT 0                             COMMENT '软删除',
  `tenant_id`      BIGINT         NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保单险种信息子表（PDF-110 第三步，主险+附加险）';


-- -----------------------------------------------------------------------------
-- 3. 保单被保人/受益人表  ins_life_policy_insured
--    对应需求：PDF-110 第二步-关系人信息（被保人必须点击添加才生效）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_policy_insured` (
  `id`            BIGINT        NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `policy_id`     BIGINT        NOT NULL                                         COMMENT '保单ID',
  `policy_no`     VARCHAR(50)   NOT NULL                                         COMMENT '保单号（冗余）',
  -- record_type: 1=被保人 2=受益人
  `record_type`   TINYINT       NOT NULL                                         COMMENT '记录类型：1被保人 2受益人',
  `name`          VARCHAR(50)   NOT NULL                                         COMMENT '姓名',
  `gender`        CHAR(1)       DEFAULT NULL                                     COMMENT '性别：M/F',
  `birth_date`    DATE          DEFAULT NULL                                     COMMENT '出生日期',
  `id_type`       VARCHAR(20)   DEFAULT NULL                                     COMMENT '证件类型：ID_CARD/PASSPORT/HKMO',
  `id_no`         VARCHAR(512)  DEFAULT NULL                                     COMMENT '证件号（AES-256加密存储，展示时脱敏）',
  `phone`         VARCHAR(100)  DEFAULT NULL                                     COMMENT '手机号（AES加密，展示脱敏）',
  `address`       VARCHAR(300)  DEFAULT NULL                                     COMMENT '住址',
  `id_long_term`  TINYINT       DEFAULT 0                                        COMMENT '证件是否长期有效：0否 1是',
  `id_expiry_date` DATE         DEFAULT NULL                                     COMMENT '证件有效期（非长期时填写）',
  -- 与投保人关系（被保人时）
  `relationship`  VARCHAR(20)   DEFAULT NULL                                     COMMENT '与投保人关系：SELF本人/SPOUSE配偶/CHILD子女/PARENT父母/OTHER其他',
  -- 受益人专用字段
  `benefit_type`  VARCHAR(20)   DEFAULT NULL                                     COMMENT '受益人类型：LEGAL法定/APPOINTED指定（受益人时填写）',
  `benefit_ratio` DECIMAL(5,2)  DEFAULT NULL                                     COMMENT '受益比例（%），受益人专用',
  `benefit_order` INT           DEFAULT NULL                                     COMMENT '受益顺序（1/2/3）',
  -- 未成年被保人监护人信息
  `guardian_info` JSON          DEFAULT NULL                                     COMMENT '监护人信息JSON（未成年被保人专用）',
  `sort_order`    INT           NOT NULL DEFAULT 0                               COMMENT '排序',
  `creator`       VARCHAR(64)   DEFAULT ''                                       COMMENT '创建者',
  `create_time`   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `deleted`       TINYINT       NOT NULL DEFAULT 0                               COMMENT '软删除',
  `tenant_id`     BIGINT        NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_policy_type` (`policy_id`, `record_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保单被保人/受益人表（PDF-110 第二步，被保人必须点添加才生效）';


-- -----------------------------------------------------------------------------
-- 4. 保单附件表  ins_policy_attachment
--    对应需求：PDF-120~124 保单修改-批量影像件上传
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_policy_attachment` (
  `id`             BIGINT        NOT NULL AUTO_INCREMENT                         COMMENT '主键ID',
  `policy_id`      BIGINT        NOT NULL                                        COMMENT '保单ID',
  `policy_no`      VARCHAR(50)   NOT NULL                                        COMMENT '保单号（冗余）',
  `category`       VARCHAR(30)   NOT NULL                                        COMMENT '影像件分类：POLICY_COVER保单首页/CLAUSE_PAGE条款页/HEALTH_NOTICE健告书/OTHER其他',
  `file_name`      VARCHAR(200)  NOT NULL                                        COMMENT '文件原始名',
  `file_url`       VARCHAR(500)  NOT NULL                                        COMMENT '文件OSS路径',
  `file_size`      BIGINT        DEFAULT NULL                                    COMMENT '文件大小（字节）',
  `file_type`      VARCHAR(20)   DEFAULT NULL                                    COMMENT '文件类型：pdf/jpg/png',
  `upload_source`  VARCHAR(20)   DEFAULT 'MANUAL'                               COMMENT '上传来源：MANUAL手动/IMPORT导入/SYSTEM系统',
  `operator_id`    BIGINT        DEFAULT NULL                                    COMMENT '上传人ID',
  `operator_name`  VARCHAR(64)   DEFAULT NULL                                    COMMENT '上传人姓名（冗余）',
  `creator`        VARCHAR(64)   DEFAULT ''                                      COMMENT '创建者',
  `create_time`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP              COMMENT '创建时间',
  `deleted`        TINYINT       NOT NULL DEFAULT 0                              COMMENT '软删除',
  `tenant_id`      BIGINT        NOT NULL DEFAULT 0                              COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_policy_category` (`policy_id`, `category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保单附件/影像件表（PDF-122 批量影像件，路径规则：/life-policy/{insurer_code}/{policy_no}/{category}/）';


-- -----------------------------------------------------------------------------
-- 5. 保单状态变更日志  ins_policy_life_status_log
--    对应需求：PDF-111 保单日志入口（保单状态流转记录）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_policy_life_status_log` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `policy_id`       BIGINT        NOT NULL                                       COMMENT '保单ID',
  `policy_no`       VARCHAR(50)   NOT NULL                                       COMMENT '保单号（冗余）',
  `from_status`     VARCHAR(30)   DEFAULT NULL                                   COMMENT '变更前状态',
  `to_status`       VARCHAR(30)   NOT NULL                                       COMMENT '变更后状态',
  `change_reason`   VARCHAR(200)  DEFAULT NULL                                   COMMENT '变更原因',
  `change_source`   VARCHAR(30)   DEFAULT NULL                                   COMMENT '变更来源：MANUAL手动/SYSTEM系统/PAYMENT缴费/BPM审批',
  `operator_id`     BIGINT        DEFAULT NULL                                   COMMENT '操作人ID',
  `operator_name`   VARCHAR(64)   DEFAULT NULL                                   COMMENT '操作人姓名（冗余）',
  `remark`          VARCHAR(500)  DEFAULT NULL                                   COMMENT '备注',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '操作时间',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保单状态变更日志（PDF-111 保单日志）';


-- -----------------------------------------------------------------------------
-- 6. 保单字段修改日志  ins_policy_life_change_log
--    对应需求：PDF-120~122 保单修改记录（含审批流）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_policy_life_change_log` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `policy_id`       BIGINT        NOT NULL                                       COMMENT '保单ID',
  `policy_no`       VARCHAR(50)   NOT NULL                                       COMMENT '保单号（冗余）',
  `change_fields`   JSON          NOT NULL                                       COMMENT '修改字段快照JSON，格式：[{field,oldValue,newValue}]',
  `change_reason`   VARCHAR(500)  DEFAULT NULL                                   COMMENT '修改原因',
  `change_status`   VARCHAR(20)   NOT NULL DEFAULT 'APPROVED'                   COMMENT '审批状态：PENDING_APPROVE待审/APPROVED已批准/REJECTED已拒绝',
  `process_inst_id` VARCHAR(64)   DEFAULT NULL                                   COMMENT 'Flowable流程实例ID（需审批时有值）',
  `operator_id`     BIGINT        DEFAULT NULL                                   COMMENT '操作人ID',
  `operator_name`   VARCHAR(64)   DEFAULT NULL                                   COMMENT '操作人姓名（冗余）',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '操作时间',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保单字段修改日志（PDF-120~122，含审批状态）';


-- -----------------------------------------------------------------------------
-- 7. 回执记录表  ins_life_policy_receipt
--    对应需求：PDF-116 回执管理（纸质/电子回执记录）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_policy_receipt` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `policy_id`       BIGINT        NOT NULL                                       COMMENT '保单ID',
  `policy_no`       VARCHAR(50)   NOT NULL                                       COMMENT '保单号（冗余）',
  `insurer_id`      BIGINT        NOT NULL                                       COMMENT '保险公司ID（冗余，支持多保司批量导入）',
  `receipt_type`    TINYINT       DEFAULT NULL                                   COMMENT '回执类型：1纸质 2电子',
  `receipt_date`    DATE          DEFAULT NULL                                   COMMENT '回执日期',
  `receipt_remark`  VARCHAR(200)  DEFAULT NULL                                   COMMENT '回执说明',
  `status`          TINYINT       NOT NULL DEFAULT 0                             COMMENT '状态：0待回执 1已回执',
  `operator_id`     BIGINT        DEFAULT NULL                                   COMMENT '操作人ID',
  `operator_name`   VARCHAR(64)   DEFAULT NULL                                   COMMENT '操作人姓名（冗余）',
  `creator`         VARCHAR(64)   DEFAULT ''                                     COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`         TINYINT       NOT NULL DEFAULT 0                             COMMENT '软删除',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保单回执记录表（PDF-116）';


-- -----------------------------------------------------------------------------
-- 8. 回访记录表  ins_life_policy_visit
--    对应需求：PDF-117~119 回访管理（新增/查询/导出）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_policy_visit` (
  `id`             BIGINT        NOT NULL AUTO_INCREMENT                         COMMENT '主键ID',
  `policy_id`      BIGINT        NOT NULL                                        COMMENT '保单ID',
  `policy_no`      VARCHAR(50)   NOT NULL                                        COMMENT '保单号（冗余）',
  -- 回访类型：1电话 2上门 3微信 4视频
  `visit_type`     TINYINT       DEFAULT NULL                                    COMMENT '回访方式：1电话 2上门 3微信 4视频',
  `visit_date`     DATETIME      DEFAULT NULL                                    COMMENT '回访日期时间',
  `visit_content`  TEXT          DEFAULT NULL                                    COMMENT '回访内容记录',
  -- 回访结果：1满意 2一般 3不满意
  `visit_result`   TINYINT       DEFAULT NULL                                    COMMENT '回访结果：1满意 2一般 3不满意',
  `status`         TINYINT       NOT NULL DEFAULT 0                              COMMENT '状态：0待回访 1已完成',
  `agent_id`       BIGINT        DEFAULT NULL                                    COMMENT '回访业务员ID',
  `agent_name`     VARCHAR(64)   DEFAULT NULL                                    COMMENT '回访业务员姓名（冗余）',
  `recording_url`  VARCHAR(500)  DEFAULT NULL                                    COMMENT '录音/录像文件URL（OSS）',
  `remark`         VARCHAR(500)  DEFAULT NULL                                    COMMENT '备注',
  `creator`        VARCHAR(64)   DEFAULT ''                                      COMMENT '创建者',
  `create_time`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP              COMMENT '创建时间',
  `update_time`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                   ON UPDATE CURRENT_TIMESTAMP                                   COMMENT '更新时间',
  `deleted`        TINYINT       NOT NULL DEFAULT 0                              COMMENT '软删除',
  `tenant_id`      BIGINT        NOT NULL DEFAULT 0                              COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_agent_id` (`agent_id`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保单回访记录表（PDF-117~119）';


-- -----------------------------------------------------------------------------
-- 9. 保全申请表  ins_life_conservation
--    对应需求：PDF-125~127 保全维护（变更受益人/投保人/减保/停缴/复效/转换）
--    审批流：Flowable LIFE_CONSERVATION_APPROVE
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_conservation` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `policy_id`        BIGINT        NOT NULL                                       COMMENT '保单ID',
  `policy_no`        VARCHAR(50)   NOT NULL                                       COMMENT '保单号（冗余）',
  `member_id`        BIGINT        DEFAULT NULL                                   COMMENT 'C端会员ID（C端申请时有值）',
  -- 保全类型：BENEFICIARY_CHANGE变更受益人/POLICY_HOLDER_CHANGE变更投保人/
  --          SUM_REDUCE减保/PREMIUM_STOP停缴/REINSTATEMENT复效/CONVERT转换
  `conservation_type` VARCHAR(40)  NOT NULL                                       COMMENT '保全类型',
  `apply_date`       DATE          NOT NULL                                       COMMENT '申请日期',
  `apply_content`    TEXT          NOT NULL                                       COMMENT '申请内容描述',
  `extra_info`       JSON          DEFAULT NULL                                   COMMENT '扩展信息JSON（变更受益人/减保等类型的专属字段）',
  `attachment_urls`  JSON          DEFAULT NULL                                   COMMENT '附件材料URL列表（OSS路径数组，至少1个）',
  -- 状态：PENDING待审/APPROVED已批准/REJECTED已拒绝/EXECUTED已执行/CANCELLED已撤销
  `status`           VARCHAR(20)   NOT NULL DEFAULT 'PENDING'                    COMMENT '保全状态',
  `reject_reason`    VARCHAR(200)  DEFAULT NULL                                   COMMENT '拒绝原因',
  `process_inst_id`  VARCHAR(64)   DEFAULT NULL                                   COMMENT 'Flowable流程实例ID',
  `operator_id`      BIGINT        DEFAULT NULL                                   COMMENT '审核人ID',
  `execute_time`     DATETIME      DEFAULT NULL                                   COMMENT '保司执行完成时间',
  `apply_agent_id`   BIGINT        DEFAULT NULL                                   COMMENT '申请人业务员ID',
  `creator`          VARCHAR(64)   DEFAULT ''                                     COMMENT '创建者',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`          TINYINT       NOT NULL DEFAULT 0                             COMMENT '软删除',
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_member_id` (`member_id`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保全申请表（PDF-125~127，Flowable审批流LIFE_CONSERVATION_APPROVE）';


-- -----------------------------------------------------------------------------
-- 10. 孤儿单表  ins_life_orphan
--     对应需求：PDF-132~133 孤儿单管理-保单分配
--     业务员离职后其名下保单入池，由管理员重新分配
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_orphan` (
  `id`                 BIGINT        NOT NULL AUTO_INCREMENT                     COMMENT '主键ID',
  `policy_id`          BIGINT        NOT NULL                                    COMMENT '保单ID，关联ins_policy_life.id',
  `policy_no`          VARCHAR(50)   NOT NULL                                    COMMENT '保单号（冗余）',
  `original_agent_id`  BIGINT        NOT NULL                                    COMMENT '原业务员ID（已离职）',
  `original_agent_name` VARCHAR(64)  DEFAULT NULL                               COMMENT '原业务员姓名（冗余）',
  `org_id`             BIGINT        DEFAULT NULL                                COMMENT '机构ID',
  -- 状态：UNASSIGNED未分配/ASSIGNED已分配
  `status`             VARCHAR(20)   NOT NULL DEFAULT 'UNASSIGNED'               COMMENT '分配状态：UNASSIGNED/ASSIGNED',
  `pool_enter_time`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP          COMMENT '入池时间',
  `assigned_agent_id`  BIGINT        DEFAULT NULL                                COMMENT '接手业务员ID',
  `assigned_agent_name` VARCHAR(64)  DEFAULT NULL                               COMMENT '接手业务员姓名（冗余）',
  `inherit_ratio`      DECIMAL(5,2)  DEFAULT NULL                                COMMENT '收益继承比例（%），影响佣金计算（PDF-133关键字段）',
  `assigned_time`      DATETIME      DEFAULT NULL                                COMMENT '分配时间',
  `creator`            VARCHAR(64)   DEFAULT ''                                  COMMENT '创建者',
  `create_time`        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP          COMMENT '创建时间',
  `update_time`        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                       ON UPDATE CURRENT_TIMESTAMP                               COMMENT '更新时间',
  `deleted`            TINYINT       NOT NULL DEFAULT 0                          COMMENT '软删除',
  `tenant_id`          BIGINT        NOT NULL DEFAULT 0                          COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_policy_id` (`policy_id`, `deleted`),
  INDEX `idx_status` (`status`),
  INDEX `idx_org_id` (`org_id`),
  INDEX `idx_original_agent_id` (`original_agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险孤儿单表（PDF-132~133，业务员离职后保单入池）';


-- -----------------------------------------------------------------------------
-- 11. 孤儿单分配轨迹表  ins_life_orphan_log
--     对应需求：PDF-134 分配轨迹查询（支持导出至任务列表）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_orphan_log` (
  `id`              BIGINT         NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `orphan_id`       BIGINT         NOT NULL                                      COMMENT '孤儿单记录ID',
  `policy_id`       BIGINT         NOT NULL                                      COMMENT '保单ID（冗余）',
  `policy_no`       VARCHAR(50)    NOT NULL                                      COMMENT '保单号（冗余）',
  `from_agent_id`   BIGINT         DEFAULT NULL                                  COMMENT '原业务员ID',
  `from_agent_name` VARCHAR(64)    DEFAULT NULL                                  COMMENT '原业务员姓名（冗余）',
  `to_agent_id`     BIGINT         NOT NULL                                      COMMENT '接手业务员ID',
  `to_agent_name`   VARCHAR(64)    DEFAULT NULL                                  COMMENT '接手业务员姓名（冗余）',
  `inherit_ratio`   DECIMAL(5,2)   DEFAULT NULL                                  COMMENT '收益继承比例（%）',
  `assign_remark`   VARCHAR(200)   DEFAULT NULL                                  COMMENT '分配备注',
  `operator_id`     BIGINT         NOT NULL                                      COMMENT '操作人ID（管理员）',
  `operator_name`   VARCHAR(64)    DEFAULT NULL                                  COMMENT '操作人姓名（冗余）',
  `assign_time`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '分配时间',
  `tenant_id`       BIGINT         NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_orphan_id` (`orphan_id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_to_agent_id` (`to_agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险孤儿单分配轨迹表（PDF-134，支持导出下载）';


-- -----------------------------------------------------------------------------
-- 12. 保单核对记录表  ins_life_policy_reconcile
--     对应需求：PDF-114 保单核对（与保司数据比对）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_policy_reconcile` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `insurer_id`       BIGINT        NOT NULL                                      COMMENT '保险公司ID',
  `batch_no`         VARCHAR(64)   NOT NULL                                      COMMENT '核对批次号',
  `reconcile_date`   DATE          NOT NULL                                      COMMENT '核对日期',
  `total_count`      INT           DEFAULT 0                                     COMMENT '核对总件数',
  `match_count`      INT           DEFAULT 0                                     COMMENT '匹配件数',
  `diff_count`       INT           DEFAULT 0                                     COMMENT '差异件数',
  `miss_count`       INT           DEFAULT 0                                     COMMENT '缺失件数（保司有、系统无）',
  `extra_count`      INT           DEFAULT 0                                     COMMENT '多余件数（系统有、保司无）',
  `diff_detail_url`  VARCHAR(500)  DEFAULT NULL                                  COMMENT '差异明细文件URL（OSS）',
  `status`           VARCHAR(20)   NOT NULL DEFAULT 'PROCESSING'                 COMMENT '状态：PROCESSING处理中/COMPLETED完成/FAILED失败',
  `operator_id`      BIGINT        DEFAULT NULL                                  COMMENT '操作人ID',
  `creator`          VARCHAR(64)   DEFAULT ''                                    COMMENT '创建者',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP                                 COMMENT '更新时间',
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`),
  INDEX `idx_insurer_date` (`insurer_id`, `reconcile_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险保单核对记录表（PDF-114 保单核对）';


-- -----------------------------------------------------------------------------
-- 13. 批量导入日志表  ins_life_import_log
--     对应需求：PDF-112 批量导入保单（注意：模板前9行不能删除，*列为必填）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_import_log` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `import_type`     VARCHAR(30)   NOT NULL                                       COMMENT '导入类型：POLICY保单/RENEWAL续期/GROUP_MEMBER团险名册',
  `batch_no`        VARCHAR(64)   NOT NULL                                       COMMENT '导入批次号',
  `file_name`       VARCHAR(200)  NOT NULL                                       COMMENT '上传文件名',
  `file_url`        VARCHAR(500)  NOT NULL                                       COMMENT '上传文件OSS路径',
  `total_count`     INT           DEFAULT 0                                      COMMENT '总行数',
  `success_count`   INT           DEFAULT 0                                      COMMENT '成功行数',
  `fail_count`      INT           DEFAULT 0                                      COMMENT '失败行数',
  `result_file_url` VARCHAR(500)  DEFAULT NULL                                   COMMENT '导入结果文件URL（含失败原因）',
  `status`          VARCHAR(20)   NOT NULL DEFAULT 'PROCESSING'                  COMMENT '状态：PROCESSING处理中/COMPLETED完成/FAILED失败',
  `error_msg`       VARCHAR(500)  DEFAULT NULL                                   COMMENT '异常信息',
  `operator_id`     BIGINT        DEFAULT NULL                                   COMMENT '操作人ID',
  `operator_name`   VARCHAR(64)   DEFAULT NULL                                   COMMENT '操作人姓名（冗余）',
  `creator`         VARCHAR(64)   DEFAULT ''                                     COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`),
  INDEX `idx_import_type` (`import_type`),
  INDEX `idx_operator_id` (`operator_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险批量导入日志表（PDF-112，包含保单/续期/团险名册导入）';


-- -----------------------------------------------------------------------------
-- 14. 团险被保人名册表  ins_life_group_policy_member
--     对应需求：PDF-115 团险保单管理（Excel批量上传被保人名册）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_group_policy_member` (
  `id`            BIGINT        NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `policy_id`     BIGINT        NOT NULL                                         COMMENT '团险保单ID',
  `policy_no`     VARCHAR(50)   NOT NULL                                         COMMENT '保单号（冗余）',
  `member_name`   VARCHAR(50)   NOT NULL                                         COMMENT '被保人姓名',
  `id_type`       VARCHAR(20)   DEFAULT 'ID_CARD'                               COMMENT '证件类型',
  `id_no`         VARCHAR(512)  NOT NULL                                         COMMENT '证件号（AES-256加密）',
  `gender`        CHAR(1)       DEFAULT NULL                                     COMMENT '性别：M/F',
  `birth_date`    DATE          DEFAULT NULL                                     COMMENT '出生日期',
  `coverage_amount` DECIMAL(15,2) DEFAULT NULL                                   COMMENT '保额（元）',
  `premium`       DECIMAL(12,2) DEFAULT NULL                                     COMMENT '保费（元）',
  `job_title`     VARCHAR(100)  DEFAULT NULL                                     COMMENT '职务/岗位',
  `department`    VARCHAR(100)  DEFAULT NULL                                     COMMENT '部门',
  `import_batch_no` VARCHAR(64) DEFAULT NULL                                     COMMENT '导入批次号',
  `status`        TINYINT       NOT NULL DEFAULT 1                               COMMENT '状态：0退出 1在保',
  `exit_date`     DATE          DEFAULT NULL                                     COMMENT '退出日期',
  `creator`       VARCHAR(64)   DEFAULT ''                                       COMMENT '创建者',
  `create_time`   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `deleted`       TINYINT       NOT NULL DEFAULT 0                               COMMENT '软删除',
  `tenant_id`     BIGINT        NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_policy_id` (`policy_id`),
  INDEX `idx_id_no_hash` (`id_no`(50))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='团险保单被保人名册表（PDF-115，Excel批量导入）';


-- -----------------------------------------------------------------------------
-- 15. C端投保草稿表  ins_life_order_draft
--     对应需求：阶段8-中 投保草稿机制（24小时自动过期，XXL-Job清理）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_order_draft` (
  `id`            BIGINT        NOT NULL AUTO_INCREMENT                          COMMENT '草稿ID',
  `draft_id`      VARCHAR(64)   NOT NULL                                         COMMENT '草稿UUID（前端携带此参数）',
  `product_id`    BIGINT        NOT NULL                                         COMMENT '产品ID',
  `member_id`     BIGINT        NOT NULL                                         COMMENT 'C端会员ID',
  `agent_id`      BIGINT        DEFAULT NULL                                     COMMENT '归因业务员ID（从分享链接中解析）',
  `current_step`  VARCHAR(30)   NOT NULL DEFAULT 'HEALTH_NOTICE'                COMMENT '当前步骤：HEALTH_NOTICE/FILL_INFO/PAYMENT_CONFIRM/PAYING',
  `health_answers` JSON         DEFAULT NULL                                     COMMENT '健康告知问卷答案JSON',
  `underwriting_result` VARCHAR(20) DEFAULT NULL                                 COMMENT '智能核保结果：PASS通过/REJECT拒绝/CONDITIONAL有条件',
  `holder_info`   JSON          DEFAULT NULL                                     COMMENT '投保人信息JSON快照',
  `insured_list`  JSON          DEFAULT NULL                                     COMMENT '被保人列表JSON快照',
  `beneficiary_list` JSON       DEFAULT NULL                                     COMMENT '受益人列表JSON快照',
  `payment_period` VARCHAR(20)  DEFAULT NULL                                     COMMENT '选择的缴费期',
  `payment_method` VARCHAR(20)  DEFAULT NULL                                     COMMENT '选择的缴费方式',
  `coverage_amount` DECIMAL(15,2) DEFAULT NULL                                   COMMENT '选择的保障额度',
  `calculated_premium` DECIMAL(12,2) DEFAULT NULL                                COMMENT '保费计算结果',
  `expired_at`    DATETIME      NOT NULL                                         COMMENT '草稿过期时间（创建后24小时）',
  `creator`       VARCHAR(64)   DEFAULT ''                                       COMMENT '创建者',
  `create_time`   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `update_time`   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                  ON UPDATE CURRENT_TIMESTAMP                                    COMMENT '更新时间',
  `deleted`       TINYINT       NOT NULL DEFAULT 0                               COMMENT '软删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_draft_id` (`draft_id`),
  INDEX `idx_member_id` (`member_id`),
  INDEX `idx_expired_at` (`expired_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='C端寿险投保草稿表（阶段8，24小时过期，POST /app-api/ins/life/order/start创建）';


-- -----------------------------------------------------------------------------
-- 16. 异步导出任务表  ins_life_export_task
--     对应需求：多处保单/续期/孤儿单导出，PDF-113/130/134 均提到"导出后跳转任务列表下载"
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_export_task` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '主键ID',
  `task_no`         VARCHAR(64)   NOT NULL                                       COMMENT '任务编号',
  `task_type`       VARCHAR(50)   NOT NULL                                       COMMENT '任务类型：POLICY保单/RENEWAL续期/ORPHAN孤儿单/RECONCILE核对/REPORT报表',
  `task_name`       VARCHAR(200)  NOT NULL                                       COMMENT '任务名称（含查询条件摘要）',
  `query_params`    JSON          DEFAULT NULL                                   COMMENT '查询参数快照JSON',
  `file_name`       VARCHAR(200)  DEFAULT NULL                                   COMMENT '导出文件名',
  `file_url`        VARCHAR(500)  DEFAULT NULL                                   COMMENT '导出文件URL（OSS）',
  `total_count`     INT           DEFAULT 0                                      COMMENT '导出总行数',
  -- 状态：PENDING排队/PROCESSING处理中/COMPLETED完成/FAILED失败
  `status`          VARCHAR(20)   NOT NULL DEFAULT 'PENDING'                    COMMENT '任务状态',
  `error_msg`       VARCHAR(500)  DEFAULT NULL                                   COMMENT '错误信息',
  `operator_id`     BIGINT        NOT NULL                                       COMMENT '操作人ID',
  `operator_name`   VARCHAR(64)   DEFAULT NULL                                   COMMENT '操作人姓名（冗余）',
  `start_time`      DATETIME      DEFAULT NULL                                   COMMENT '开始处理时间',
  `end_time`        DATETIME      DEFAULT NULL                                   COMMENT '完成时间',
  `creator`         VARCHAR(64)   DEFAULT ''                                     COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`         TINYINT       NOT NULL DEFAULT 0                             COMMENT '软删除（删除导出记录）',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_no` (`task_no`),
  INDEX `idx_operator_id` (`operator_id`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险异步导出任务表（PDF-113/130/134等导出功能共用）';


-- =============================================================================
-- Part 2 表清单（共16张表）
-- ┌──────────────────────────────────────┬──────────────────────────────────┐
-- │ 表名                                 │ 说明                              │
-- ├──────────────────────────────────────┼──────────────────────────────────┤
-- │ ins_policy_life                      │ 寿险保单主表                      │
-- │ ins_life_policy_coverage             │ 保单险种子表（主险+附加险）        │
-- │ ins_life_policy_insured              │ 被保人/受益人表                   │
-- │ ins_policy_attachment                │ 保单附件/影像件                   │
-- │ ins_policy_life_status_log           │ 保单状态变更日志                  │
-- │ ins_policy_life_change_log           │ 保单字段修改日志                  │
-- │ ins_life_policy_receipt              │ 回执记录表                        │
-- │ ins_life_policy_visit                │ 回访记录表                        │
-- │ ins_life_conservation                │ 保全申请表（Flowable审批）        │
-- │ ins_life_orphan                      │ 孤儿单表                          │
-- │ ins_life_orphan_log                  │ 孤儿单分配轨迹                    │
-- │ ins_life_policy_reconcile            │ 保单核对记录                      │
-- │ ins_life_import_log                  │ 批量导入日志                      │
-- │ ins_life_group_policy_member         │ 团险被保人名册                    │
-- │ ins_life_order_draft                 │ C端投保草稿                       │
-- │ ins_life_export_task                 │ 异步导出任务                      │
-- └──────────────────────────────────────┴──────────────────────────────────┘
-- =============================================================================

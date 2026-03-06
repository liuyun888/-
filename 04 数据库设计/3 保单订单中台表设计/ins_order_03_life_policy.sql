-- ============================================================
-- 保险中介平台 - intermediary-module-ins-order（保单订单中台）
-- 数据库Schema: db_ins_order
-- 表前缀: ins_order_
-- 文件: 03 - 寿险保单相关表（★V13）
-- 版本: V1.0
-- ============================================================

USE `db_ins_order`;

-- ----------------------------
-- 9. 寿险保单主表（★V13 新增）
-- ----------------------------
CREATE TABLE `ins_order_policy_life` (
  `id`                      BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenant_id`               BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `merchant_id`             BIGINT        NOT NULL COMMENT '商户ID（机构ID）',

  -- 关联信息
  `order_no`                VARCHAR(64)   COMMENT '关联订单号（C端投保时）',
  `order_id`                BIGINT        COMMENT '关联订单ID',
  `user_id`                 BIGINT        COMMENT '关联C端用户ID（投保人）',

  -- 保险公司信息
  `insurance_company_id`    BIGINT        NOT NULL COMMENT '保险公司ID',
  `insurance_company_name`  VARCHAR(100)  NOT NULL COMMENT '保险公司名称',
  `insurance_company_code`  VARCHAR(50)   COMMENT '保险公司代码（用于OSS路径归档）',

  -- 产品信息
  `product_id`              BIGINT        COMMENT '产品ID',
  `product_name`            VARCHAR(200)  NOT NULL COMMENT '产品名称',
  `product_code`            VARCHAR(50)   COMMENT '产品代码',
  `insurance_type`          VARCHAR(50)   NOT NULL COMMENT '险种：寿险/重疾/医疗/意外/年金/万能险',

  -- 保单号
  `policy_no`               VARCHAR(100)  NOT NULL COMMENT '保单号/投保单号',
  `apply_no`                VARCHAR(100)  COMMENT '投保单号（与保单号可不同）',

  -- 保单类型
  `policy_category`         TINYINT       NOT NULL DEFAULT 1 COMMENT '保单类别：1-个险 2-团险',
  `business_type`           VARCHAR(20)   COMMENT '件数状态/业务类型：新单/续保/转保',
  `is_renewal`              TINYINT(1)    DEFAULT 0 COMMENT '是否复效保单：0-否 1-是',
  `is_self_insurance`       TINYINT(1)    DEFAULT 0 COMMENT '是否自保件（业务员投保）：0-否 1-是',

  -- 客户ID（关联CRM客户）
  `customer_id`             BIGINT        COMMENT '投保人客户ID（关联ins_crm_customer）',

  -- 保费缴费信息
  `payment_method`          VARCHAR(20)   NOT NULL COMMENT '缴费方式：趸缴/年缴/半年缴/季缴/月缴',
  `payment_period`          INT           NOT NULL COMMENT '缴费期间（年）',
  `payment_frequency`       TINYINT       COMMENT '缴费频率（次/年）：1年缴 2半年缴 4季缴 12月缴',
  `annual_premium`          DECIMAL(12,2) NOT NULL COMMENT '年度保费/首期保费（元）',
  `renewal_premium`         DECIMAL(12,2) COMMENT '续期保费（元）',
  `total_premium_paid`      DECIMAL(15,2) DEFAULT 0 COMMENT '已缴保费合计（元）',

  -- 标准保费（用于结算计算）
  `upstream_standard_premium`     DECIMAL(12,2) COMMENT '上游标准保费（元）',
  `downstream_first_premium`      DECIMAL(12,2) COMMENT '下游首年标准保费（元）',
  `downstream_renewal_premium`    DECIMAL(12,2) COMMENT '下游续期标准保费（元）',
  `upstream_discount_rate`        DECIMAL(5,4)  DEFAULT 1.0000 COMMENT '上游折标系数（默认1=100%）',
  `downstream_first_discount_rate`  DECIMAL(5,4)  DEFAULT 1.0000 COMMENT '下游首年折标系数',
  `value_premium`                 DECIMAL(12,2) COMMENT '价值保费（元）',

  -- 保额信息
  `sum_insured`             DECIMAL(15,2) COMMENT '保障额度/保额（元）',

  -- 保障期间
  `coverage_period`         VARCHAR(50)   COMMENT '保障期限（如：终身/20年/至70岁）',
  `start_date`              DATE          NOT NULL COMMENT '保险起期（起保日期）',
  `end_date`                DATE          COMMENT '保险止期（到期日期）',
  `sign_date`               DATE          COMMENT '签单日期/投保日期（默认=起保日期）',
  `underwriting_date`       DATE          COMMENT '承保日期（保司实际承保日期）',
  `effective_date`          DATE          COMMENT '保单生效日',

  -- 缴费跟踪
  `next_payment_date`       DATE          COMMENT '下次缴费日',
  `grace_period_days`       INT           NOT NULL DEFAULT 60 COMMENT '宽限期天数',
  `lapsed_date`             DATE          COMMENT '失效日期',

  -- 保单状态（完整状态机）
  `policy_status`           VARCHAR(30)   NOT NULL DEFAULT 'ACTIVE' COMMENT '保单状态：PAYING/UNDERWRITING/ACTIVE/WAITING_CONDITION_CONFIRM/OVERDUE/LAPSED/REJECTED/CANCELLED/MATURED/SUSPENDED/TERMINATED',

  -- 核保信息
  `underwriting_conditions` JSON          COMMENT '核保附加条件（JSON，包含条件描述）',

  -- 代扣签约
  `auto_deduct_status`      VARCHAR(20)   COMMENT '代扣状态：NONE/SIGNING/ACTIVE/EXPIRED/CANCELLED/FAILED',
  `auto_deduct_contract_no` VARCHAR(100)  COMMENT '代扣合同号',

  -- 组织信息
  `org_id`                  BIGINT        COMMENT '所属机构ID',
  `org_name`                VARCHAR(200)  COMMENT '所属机构名称',
  `org_code`                VARCHAR(50)   COMMENT '组织代码',

  -- 人员信息
  `agent_id`                BIGINT        COMMENT '保单服务人（归因业务员）ID',
  `agent_name`              VARCHAR(100)  COMMENT '保单服务人姓名',
  `agent_no`                VARCHAR(100)  COMMENT '保单服务人工号',
  `sales_agent_id`          BIGINT        COMMENT '销售人ID（可与服务人不同）',
  `sales_agent_name`        VARCHAR(100)  COMMENT '销售人姓名',

  -- 回执/回访状态
  `receipt_status`          TINYINT       DEFAULT 0 COMMENT '回执状态：0-待回执 1-已回执',
  `visit_status`            TINYINT       DEFAULT 0 COMMENT '回访状态：0-待回访 1-已回访',

  -- 电子保单
  `e_policy_url`            VARCHAR(500)  COMMENT '电子保单PDF地址（OSS）',

  -- 来源标识
  `source_type`             TINYINT       DEFAULT 1 COMMENT '来源：1-PC录单 2-App录单 3-批量导入 4-C端自助投保',
  `import_batch_no`         VARCHAR(64)   COMMENT '批量导入批次编号',

  `remark`                  VARCHAR(500)  COMMENT '备注',

  -- 框架标准字段
  `creator`                 VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`                 VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`                 TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除：0-否 1-是',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_company_policy` (`tenant_id`, `insurance_company_id`, `policy_no`, `deleted`),
  KEY `idx_tenant_id` (`tenant_id`),
  KEY `idx_order_no` (`order_no`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_policy_status` (`policy_status`),
  KEY `idx_next_payment_date` (`next_payment_date`),
  KEY `idx_start_date` (`start_date`),
  KEY `idx_org_id` (`org_id`),
  KEY `idx_insurance_type` (`insurance_type`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险保单主表（★V13）';


-- ----------------------------
-- 10. 寿险保单险种信息表（主险+附加险）
-- ----------------------------
CREATE TABLE `ins_order_policy_life_coverage` (
  `id`                BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`         BIGINT        NOT NULL COMMENT '关联寿险保单ID',
  `tenant_id`         BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `coverage_type`     TINYINT       NOT NULL COMMENT '险种类别：1-主险 2-附加险',
  `coverage_name`     VARCHAR(200)  NOT NULL COMMENT '险种名称',
  `product_code`      VARCHAR(50)   COMMENT '产品代码',
  `sum_insured`       DECIMAL(15,2) DEFAULT 0 COMMENT '保额（元）',
  `premium`           DECIMAL(12,2) DEFAULT 0 COMMENT '该险种保费（元）',
  `coverage_period`   VARCHAR(50)   COMMENT '保险期间（如终身/20年）',
  `payment_period`    VARCHAR(50)   COMMENT '缴费期（如20年缴/趸缴）',
  `sort`              INT           DEFAULT 0 COMMENT '排序（主险排前）',
  `creator`           VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `deleted`           TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险保单险种明细表（主险+附加险）';


-- ----------------------------
-- 11. 寿险被保人/受益人表（★V13）
-- ----------------------------
CREATE TABLE `ins_order_policy_life_insured` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`       BIGINT       NOT NULL COMMENT '关联寿险保单ID',
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
  `record_type`     TINYINT      NOT NULL COMMENT '记录类型：1-投保人 2-被保人 3-受益人',
  `name`            VARCHAR(50)  NOT NULL COMMENT '姓名',
  `gender`          CHAR(1)      COMMENT '性别：M-男 F-女',
  `birth_date`      DATE         COMMENT '出生日期',
  `age`             INT          COMMENT '年龄（录入时计算）',
  `id_type`         VARCHAR(20)  COMMENT '证件类型：身份证/护照/港澳通行证',
  `id_no`           VARCHAR(200) COMMENT '证件号（AES-256加密存储）',
  `phone`           VARCHAR(100) COMMENT '手机号（加密存储）',
  `address`         VARCHAR(500) COMMENT '住址',
  `relationship`    VARCHAR(20)  COMMENT '与投保人关系：本人/配偶/子女/父母/其他',
  `is_long_valid`   TINYINT(1)   DEFAULT 0 COMMENT '证件是否长期有效：0-否 1-是',
  `cert_expire_date` DATE        COMMENT '证件有效期',
  `occupation`      VARCHAR(100) COMMENT '职业',
  `health_info`     JSON         COMMENT '健康告知信息（JSON快照）',

  -- 受益人专用字段
  `benefit_type`    VARCHAR(20)  COMMENT '受益人类型：LAW-法定 DESIGNATED-指定',
  `benefit_ratio`   DECIMAL(5,2) COMMENT '受益比例（%），受益人专用',
  `benefit_order`   INT          COMMENT '受益顺序（1/2/3），受益人专用',
  `guardian_info`   JSON         COMMENT '监护人信息（未成年被保人专用）',

  `sort`            INT          DEFAULT 0 COMMENT '排序',
  `customer_id`     BIGINT       COMMENT '关联CRM客户ID',

  `creator`         VARCHAR(64)  DEFAULT '' COMMENT '创建者',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `deleted`         TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '是否删除',

  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_record_type` (`record_type`),
  KEY `idx_customer_id` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险保单被保人/受益人表（★V13）';


-- ----------------------------
-- 12. 寿险团险被保人名册表
-- ----------------------------
CREATE TABLE `ins_order_policy_life_group_member` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`       BIGINT        NOT NULL COMMENT '关联寿险团险保单ID',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `member_name`     VARCHAR(100)  NOT NULL COMMENT '被保人姓名',
  `id_type`         VARCHAR(20)   COMMENT '证件类型',
  `id_no`           VARCHAR(200)  COMMENT '证件号（加密存储）',
  `birth_date`      DATE          COMMENT '出生日期',
  `gender`          CHAR(1)       COMMENT '性别：M/F',
  `sum_insured`     DECIMAL(15,2) COMMENT '该成员保额（元）',
  `premium`         DECIMAL(10,2) COMMENT '该成员保费（元）',
  `department`      VARCHAR(100)  COMMENT '所在部门',
  `position`        VARCHAR(100)  COMMENT '职位',
  `entry_date`      DATE          COMMENT '入职日期',
  `status`          TINYINT       DEFAULT 1 COMMENT '状态：1-在职 0-离职（影响保单续期）',
  `creator`         VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `deleted`         TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_id_no` (`id_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险团险被保人名册表';


-- ----------------------------
-- 13. 寿险保单回执记录表（★V13，对应PDF-116）
-- ----------------------------
CREATE TABLE `ins_order_life_receipt` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`       BIGINT        NOT NULL COMMENT '关联寿险保单ID',
  `policy_no`       VARCHAR(100)  NOT NULL COMMENT '保单号',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `insurance_company_id` BIGINT   NOT NULL COMMENT '保险公司ID',
  `receipt_type`    TINYINT       COMMENT '回执类型：1-纸质 2-电子',
  `receipt_date`    DATE          COMMENT '回执日期',
  `receipt_remark`  VARCHAR(200)  COMMENT '回执说明',
  `attachment_url`  VARCHAR(500)  COMMENT '回执附件（OSS地址）',
  `status`          TINYINT       NOT NULL DEFAULT 0 COMMENT '状态：0-待回执 1-已回执',
  `operator_id`     BIGINT        COMMENT '操作人ID',
  `operator_name`   VARCHAR(100)  COMMENT '操作人名称',
  `creator`         VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险保单回执记录表（★V13）';


-- ----------------------------
-- 14. 寿险回访记录表（★V13，对应PDF-117~119）
-- ----------------------------
CREATE TABLE `ins_order_life_visit_record` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`       BIGINT        NOT NULL COMMENT '关联寿险保单ID',
  `policy_no`       VARCHAR(100)  NOT NULL COMMENT '保单号',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `visit_type`      TINYINT       COMMENT '回访类型：1-电话 2-上门 3-微信 4-视频',
  `visit_date`      DATETIME      COMMENT '回访日期时间',
  `visit_content`   TEXT          COMMENT '回访内容记录',
  `visit_result`    TINYINT       COMMENT '回访结果：1-满意 2-一般 3-不满意',
  `visit_remarks`   VARCHAR(500)  COMMENT '回访备注',
  `attachment_urls` JSON          COMMENT '回访附件URL列表',
  `status`          TINYINT       NOT NULL DEFAULT 0 COMMENT '状态：0-待回访 1-已完成',
  `agent_id`        BIGINT        COMMENT '回访业务员ID',
  `agent_name`      VARCHAR(100)  COMMENT '回访业务员姓名',
  `creator`         VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_status` (`status`),
  KEY `idx_visit_date` (`visit_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险回访记录表（★V13）';


-- ----------------------------
-- 15. 寿险保全申请表（★V13，对应PDF-125~127）
-- ----------------------------
CREATE TABLE `ins_order_life_conservation` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`           BIGINT        NOT NULL COMMENT '关联寿险保单ID',
  `policy_no`           VARCHAR(100)  NOT NULL COMMENT '保单号',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `conservation_type`   VARCHAR(50)   NOT NULL COMMENT '保全类型：BENEFICIARY_CHANGE/POLICY_HOLDER_CHANGE/SUM_REDUCE/PREMIUM_STOP/REINSTATEMENT/CONVERT',
  `apply_content`       TEXT          NOT NULL COMMENT '申请内容',
  `apply_date`          DATE          NOT NULL COMMENT '申请日期',
  -- 变更受益人扩展字段
  `new_beneficiary_name`    VARCHAR(100)  COMMENT '新受益人姓名（变更受益人时）',
  `new_beneficiary_id_no`   VARCHAR(200)  COMMENT '新受益人证件号（加密存储）',
  `new_beneficiary_relation` VARCHAR(50)  COMMENT '新受益人与被保人关系',
  -- 减保扩展字段
  `new_sum_insured`     DECIMAL(15,2) COMMENT '减保后新保额（元）',
  -- 复效扩展字段
  `overdue_premium`     DECIMAL(12,2) COMMENT '欠缴保费金额（元，复效时）',

  -- 审批状态
  `status`              VARCHAR(20)   NOT NULL DEFAULT 'PENDING' COMMENT '状态：PENDING-待审核 APPROVED-通过 REJECTED-拒绝 EXECUTED-已执行 CANCELLED-已撤销',
  `approve_time`        DATETIME      COMMENT '审批时间',
  `approver_id`         BIGINT        COMMENT '审批人ID',
  `approver_name`       VARCHAR(100)  COMMENT '审批人名称',
  `reject_reason`       VARCHAR(500)  COMMENT '拒绝原因',
  `execute_time`        DATETIME      COMMENT '执行时间（调用保司API完成变更的时间）',

  -- Flowable审批
  `process_instance_id` VARCHAR(64)   COMMENT 'Flowable流程实例ID',

  `attachment_urls`     JSON          COMMENT '保全附件URL列表',
  `source_type`         TINYINT       DEFAULT 1 COMMENT '来源：1-PC后台 2-C端申请',
  `applicant_id`        BIGINT        COMMENT '申请人ID',
  `applicant_name`      VARCHAR(100)  COMMENT '申请人名称',

  `creator`             VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`             VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`             TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',

  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_status` (`status`),
  KEY `idx_conservation_type` (`conservation_type`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险保全申请表（★V13）';


-- ----------------------------
-- 16. 寿险孤儿单表（★V13，对应PDF-132~134）
-- ----------------------------
CREATE TABLE `ins_order_life_orphan` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`           BIGINT        NOT NULL COMMENT '关联寿险保单ID',
  `policy_no`           VARCHAR(100)  NOT NULL COMMENT '保单号',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `original_agent_id`   BIGINT        NOT NULL COMMENT '原业务员ID（已离职）',
  `original_agent_name` VARCHAR(100)  NOT NULL COMMENT '原业务员姓名',
  `assigned_agent_id`   BIGINT        COMMENT '已分配业务员ID',
  `assigned_agent_name` VARCHAR(100)  COMMENT '已分配业务员姓名',
  `inherit_ratio`       DECIMAL(5,2)  COMMENT '收益继承比例（%，影响佣金计算）',
  `status`              VARCHAR(20)   NOT NULL DEFAULT 'UNASSIGNED' COMMENT '状态：UNASSIGNED-未分配 ASSIGNED-已分配',
  `pool_date`           DATE          NOT NULL COMMENT '入孤儿单池日期（业务员离职当天）',
  `assigned_time`       DATETIME      COMMENT '分配完成时间',
  `assign_remark`       VARCHAR(500)  COMMENT '分配备注',
  `org_id`              BIGINT        COMMENT '所属机构ID',
  `creator`             VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`             VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`             TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_policy_id` (`policy_id`, `deleted`),
  KEY `idx_original_agent_id` (`original_agent_id`),
  KEY `idx_assigned_agent_id` (`assigned_agent_id`),
  KEY `idx_status` (`status`),
  KEY `idx_pool_date` (`pool_date`),
  KEY `idx_org_id` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险孤儿单表（★V13）';


-- ----------------------------
-- 17. 寿险孤儿单分配轨迹表（★V13，对应PDF-134）
-- ----------------------------
CREATE TABLE `ins_order_life_orphan_log` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `orphan_id`           BIGINT        NOT NULL COMMENT '关联孤儿单记录ID',
  `policy_id`           BIGINT        NOT NULL COMMENT '关联寿险保单ID',
  `policy_no`           VARCHAR(100)  NOT NULL COMMENT '保单号',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `from_agent_id`       BIGINT        NOT NULL COMMENT '分配前业务员ID',
  `from_agent_name`     VARCHAR(100)  NOT NULL COMMENT '分配前业务员姓名',
  `to_agent_id`         BIGINT        NOT NULL COMMENT '分配后业务员ID',
  `to_agent_name`       VARCHAR(100)  NOT NULL COMMENT '分配后业务员姓名',
  `inherit_ratio`       DECIMAL(5,2)  COMMENT '收益继承比例（%）',
  `assign_time`         DATETIME      NOT NULL COMMENT '分配时间',
  `operator_id`         BIGINT        COMMENT '操作人ID',
  `operator_name`       VARCHAR(100)  COMMENT '操作人名称',
  `remark`              VARCHAR(500)  COMMENT '分配备注',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_orphan_id` (`orphan_id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_from_agent_id` (`from_agent_id`),
  KEY `idx_to_agent_id` (`to_agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险孤儿单分配轨迹表（★V13）';


-- ----------------------------
-- 18. 寿险保单状态变更日志表
-- ----------------------------
CREATE TABLE `ins_order_life_status_log` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`       BIGINT        NOT NULL COMMENT '关联寿险保单ID',
  `policy_no`       VARCHAR(100)  NOT NULL COMMENT '保单号',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `from_status`     VARCHAR(30)   COMMENT '变更前状态',
  `to_status`       VARCHAR(30)   NOT NULL COMMENT '变更后状态',
  `change_reason`   VARCHAR(200)  COMMENT '变更原因',
  `change_source`   VARCHAR(50)   COMMENT '变更来源：PC_MANUAL/C_END/SCHEDULE_JOB/MQ_EVENT',
  `operator_id`     BIGINT        COMMENT '操作人ID',
  `operator_name`   VARCHAR(100)  COMMENT '操作人名称',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '变更时间',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险保单状态变更日志表';


-- ----------------------------
-- 19. 寿险保单字段修改日志（含审批，对应PDF-120~124）
-- ----------------------------
CREATE TABLE `ins_order_life_change_log` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`           BIGINT        NOT NULL COMMENT '关联寿险保单ID',
  `policy_no`           VARCHAR(100)  NOT NULL COMMENT '保单号',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `change_type`         VARCHAR(50)   NOT NULL COMMENT '修改类型（字段名或分类）',
  `field_name`          VARCHAR(100)  COMMENT '修改字段名称（中文）',
  `old_value`           TEXT          COMMENT '修改前值',
  `new_value`           TEXT          COMMENT '修改后值',
  `status`              TINYINT       NOT NULL DEFAULT 0 COMMENT '状态：0-待审批 1-已通过 2-已拒绝',
  `apply_time`          DATETIME      COMMENT '申请时间',
  `approve_time`        DATETIME      COMMENT '审批时间',
  `approver_id`         BIGINT        COMMENT '审批人ID',
  `reject_reason`       VARCHAR(500)  COMMENT '拒绝原因',
  `operator_id`         BIGINT        NOT NULL COMMENT '修改人ID',
  `operator_name`       VARCHAR(100)  NOT NULL COMMENT '修改人名称',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险保单字段修改日志表';


-- ----------------------------
-- 20. 寿险保单核对记录表（对应PDF-114，与保司数据比对）
-- ----------------------------
CREATE TABLE `ins_order_life_reconcile` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`           BIGINT        COMMENT '关联寿险保单ID（若匹配到）',
  `policy_no`           VARCHAR(100)  NOT NULL COMMENT '保单号',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `insurance_company_id` BIGINT       NOT NULL COMMENT '保险公司ID',
  `reconcile_batch_no`  VARCHAR(64)   NOT NULL COMMENT '核对批次编号',
  `reconcile_date`      DATE          NOT NULL COMMENT '核对日期',
  `reconcile_status`    TINYINT       NOT NULL DEFAULT 0 COMMENT '核对状态：0-待核对 1-一致 2-差异',
  `diff_fields`         JSON          COMMENT '差异字段信息（字段名:系统值:保司值）',
  `handle_status`       TINYINT       DEFAULT 0 COMMENT '处理状态：0-未处理 1-已处理 2-忽略',
  `handle_remark`       VARCHAR(500)  COMMENT '处理说明',
  `handler_id`          BIGINT        COMMENT '处理人ID',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_reconcile_batch_no` (`reconcile_batch_no`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_reconcile_status` (`reconcile_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险保单核对记录表';


-- ----------------------------
-- 21. 寿险续期缴费提醒记录表（★V13）
-- ----------------------------
CREATE TABLE `ins_order_life_renewal_remind` (
  `id`            BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`     BIGINT        NOT NULL COMMENT '关联寿险保单ID',
  `tenant_id`     BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `remind_type`   TINYINT       NOT NULL COMMENT '提醒类型：1-提前30天 2-提前15天 3-提前7天 4-提前1天 5-逾期当天 6-逾期1天 7-逾期3天 8-逾期7天',
  `remind_date`   DATE          NOT NULL COMMENT '应提醒日期',
  `send_status`   TINYINT       NOT NULL DEFAULT 0 COMMENT '发送状态：0-未发送 1-已发送 2-发送失败',
  `send_time`     DATETIME      COMMENT '实际发送时间',
  `fail_reason`   VARCHAR(200)  COMMENT '发送失败原因',
  `create_time`   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_policy_remind_type` (`policy_id`, `remind_type`),
  KEY `idx_remind_date_status` (`remind_date`, `send_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险续期缴费提醒记录表（★V13）';

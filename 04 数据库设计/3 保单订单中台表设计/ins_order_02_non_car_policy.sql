-- ============================================================
-- 保险中介平台 - intermediary-module-ins-order（保单订单中台）
-- 数据库Schema: db_ins_order
-- 表前缀: ins_order_
-- 文件: 02 - 非车险保单相关表
-- 版本: V1.0
-- ============================================================

USE `db_ins_order`;

-- ----------------------------
-- 5. 非车险保单主表
-- ----------------------------
CREATE TABLE `ins_order_policy_non_car` (
  `id`                      BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenant_id`               BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `merchant_id`             BIGINT        NOT NULL COMMENT '商户ID（机构ID）',

  -- 保险公司信息
  `insurance_company_id`    BIGINT        NOT NULL COMMENT '保险公司ID',
  `insurance_company_name`  VARCHAR(100)  NOT NULL COMMENT '保险公司名称',

  -- 保单基本信息
  `policy_no`               VARCHAR(100)  NOT NULL COMMENT '保(批)单号',
  `original_policy_no`      VARCHAR(100)  COMMENT '原保单号（批单时填写，关联原保单）',
  `policy_status`           TINYINT       NOT NULL DEFAULT 1 COMMENT '保单状态：1-正常 2-退保 3-批改 4-终止',

  -- 标的信息
  `subject_type`            TINYINT       NOT NULL COMMENT '标的标识：1-车辆 2-人 3-物品',
  `subject_name`            VARCHAR(200)  COMMENT '标的名称',

  -- 险种信息
  `insurance_type_code`     VARCHAR(50)   COMMENT '险种编码',
  `insurance_type`          VARCHAR(100)  NOT NULL COMMENT '险种名称',
  `product_id`              BIGINT        COMMENT '产品ID（关联系统产品，标的=车辆时使用）',
  `product_name`            VARCHAR(200)  NOT NULL COMMENT '产品名称',

  -- 业务标识
  `is_internet`             TINYINT(1)    DEFAULT 0 COMMENT '是否互联网业务：0-否 1-是',
  `is_agriculture`          TINYINT(1)    DEFAULT 0 COMMENT '是否涉农业务：0-否 1-是',
  `is_co_insurance`         TINYINT(1)    DEFAULT 0 COMMENT '是否共保：0-否 1-是',

  -- 日期信息
  `sign_date`               DATE          NOT NULL COMMENT '签单日期',
  `start_date`              DATE          NOT NULL COMMENT '起保日期',
  `end_date`                DATE          NOT NULL COMMENT '保险止期',
  `payment_date`            DATE          COMMENT '支付日期',

  -- 保费信息
  `total_premium`           DECIMAL(12,2) DEFAULT 0 COMMENT '总保费（元）',
  `net_premium`             DECIMAL(12,2) DEFAULT 0 COMMENT '净保费（元）',
  `sum_insured`             DECIMAL(15,2) DEFAULT 0 COMMENT '保额（元）',

  -- 手续费信息
  `upstream_fee_rate`       DECIMAL(8,4)  DEFAULT 0 COMMENT '上游手续费比例（%）',
  `upstream_fee_amount`     DECIMAL(12,2) DEFAULT 0 COMMENT '上游手续费金额（元）',
  `downstream_fee_rate`     DECIMAL(8,4)  DEFAULT 0 COMMENT '下游手续费比例（%）',
  `downstream_fee_amount`   DECIMAL(12,2) DEFAULT 0 COMMENT '下游手续费金额（元）',
  `profit_amount`           DECIMAL(12,2) DEFAULT 0 COMMENT '利润（元）',

  -- 区域信息
  `region`                  VARCHAR(100)  COMMENT '投保区域（省市）',
  `region_code`             VARCHAR(20)   COMMENT '区域代码',

  -- 人员信息
  `company_no_id`           BIGINT        COMMENT '出单工号ID',
  `company_no`              VARCHAR(100)  COMMENT '出单工号',
  `salesman_id`             BIGINT        NOT NULL COMMENT '业务员ID',
  `salesman_name`           VARCHAR(100)  NOT NULL COMMENT '业务员姓名',
  `issuer_id`               BIGINT        COMMENT '出单员ID',
  `issuer_name`             VARCHAR(100)  COMMENT '出单员姓名',
  `org_id`                  BIGINT        COMMENT '所属机构ID',
  `org_name`                VARCHAR(200)  COMMENT '所属机构名称',

  -- 渠道信息
  `channel_name`            VARCHAR(100)  COMMENT '渠道名称',
  `source_type`             TINYINT       DEFAULT 1 COMMENT '来源：1-PC录单 2-App录单 3-批量导入 4-C端投保',

  -- 批改关联（批单录入时使用）
  `endorsement_type`        VARCHAR(50)   COMMENT '批改类型（增保/减保/变更被保标的/其他）',
  `endorsement_date`        DATE          COMMENT '批改生效日期',
  `premium_change`          DECIMAL(12,2) COMMENT '批改保费差额（元，可负数）',

  -- C端关联
  `order_id`                BIGINT        COMMENT '关联订单ID（C端投保时关联）',
  `user_id`                 BIGINT        COMMENT '关联C端用户ID',

  -- 自定义扩展字段（非车险自定义字段JSON存储）
  `extra_fields`            JSON          COMMENT '自定义字段数据（key=字段代码, value=字段值）',

  -- 导入批次
  `import_batch_no`         VARCHAR(64)   COMMENT '批量导入批次编号',

  `remark`                  VARCHAR(500)  COMMENT '备注',

  -- 框架标准字段
  `creator`                 VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`                 VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`                 TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除：0-否 1-是',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_company_policy` (`tenant_id`, `insurance_company_id`, `policy_no`, `product_id`, `deleted`),
  KEY `idx_tenant_id` (`tenant_id`),
  KEY `idx_salesman_id` (`salesman_id`),
  KEY `idx_insurance_type` (`insurance_type_code`),
  KEY `idx_sign_date` (`sign_date`),
  KEY `idx_start_date` (`start_date`),
  KEY `idx_original_policy_no` (`original_policy_no`),
  KEY `idx_org_id` (`org_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='非车险保单主表';


-- ----------------------------
-- 6. 非车险被保人/关系人子表
-- ----------------------------
CREATE TABLE `ins_order_policy_non_car_insured` (
  `id`            BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`     BIGINT        NOT NULL COMMENT '关联非车险保单ID',
  `tenant_id`     BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `insured_type`  TINYINT       COMMENT '关系人类型：1-投保人 2-被保人 3-车主',
  `name`          VARCHAR(200)  NOT NULL COMMENT '姓名',
  `cert_type`     VARCHAR(50)   COMMENT '证件类型（身份证/护照等）',
  `cert_no`       VARCHAR(200)  COMMENT '证件号（加密存储）',
  `birthday`      DATE          COMMENT '出生日期（人身险）',
  `gender`        CHAR(1)       COMMENT '性别：M-男 F-女',
  `phone`         VARCHAR(50)   COMMENT '联系电话（加密存储）',
  `plate_no`      VARCHAR(50)   COMMENT '车牌号（标的=车辆时）',
  `vin`           VARCHAR(100)  COMMENT '车架号',
  `engine_no`     VARCHAR(100)  COMMENT '发动机号',
  `address`       VARCHAR(500)  COMMENT '地址',
  `sort`          INT           DEFAULT 0 COMMENT '排序',
  `creator`       VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `deleted`       TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_cert_no` (`cert_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='非车险被保人/关系人子表';


-- ----------------------------
-- 7. 非车险共保信息子表
-- ----------------------------
CREATE TABLE `ins_order_policy_non_car_co_insurer` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`           BIGINT        NOT NULL COMMENT '关联非车险保单ID',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `co_company_id`       BIGINT        NOT NULL COMMENT '共保保险公司ID',
  `co_company_name`     VARCHAR(100)  NOT NULL COMMENT '共保保险公司名称',
  `co_policy_no`        VARCHAR(100)  COMMENT '共保保单号',
  `co_premium_ratio`    DECIMAL(8,4)  COMMENT '共保保费比例（%）',
  `co_premium_amount`   DECIMAL(12,2) COMMENT '共保保费金额（元）',
  `creator`             VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `deleted`             TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='非车险共保信息子表';


-- ----------------------------
-- 8. 非车险保单字段自定义配置表
-- ----------------------------
CREATE TABLE `ins_order_non_car_field_config` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `product_category` VARCHAR(64)   NOT NULL COMMENT '险种分类（健康险/责任险/企财险等）',
  `field_code`       VARCHAR(64)   NOT NULL COMMENT '字段代码（小写+下划线，唯一）',
  `field_name`       VARCHAR(64)   NOT NULL COMMENT '字段中文名',
  `field_type`       VARCHAR(32)   NOT NULL COMMENT '字段类型：TEXT/NUMBER/AMOUNT/DATE/SELECT/TEXTAREA',
  `select_options`   VARCHAR(1000) COMMENT '下拉选项（逗号分隔，SELECT类型）',
  `placeholder`      VARCHAR(255)  COMMENT '占位提示文字',
  `help_text`        VARCHAR(500)  COMMENT '帮助说明',
  `is_required`      TINYINT(1)    DEFAULT 0 COMMENT '是否必填：0-否 1-是',
  `is_list_column`   TINYINT(1)    DEFAULT 0 COMMENT '是否列表展示：0-否 1-是',
  `sort`             INT           DEFAULT 0 COMMENT '排序号',
  `field_source`     VARCHAR(16)   DEFAULT 'CUSTOM' COMMENT '字段来源：PRESET-系统预置 CUSTOM-自定义',
  `status`           TINYINT(1)    DEFAULT 1 COMMENT '状态：1-启用 0-停用',
  `creator`          VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`          VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`          TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_category_code` (`tenant_id`, `product_category`, `field_code`),
  KEY `idx_product_category` (`tenant_id`, `product_category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='非车险保单字段自定义配置表';

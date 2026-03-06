-- ============================================================
-- 保险中介平台 - intermediary-module-ins-order（保单订单中台）
-- 数据库Schema: db_ins_order
-- 表前缀: ins_order_
-- 文件: 01 - 车险保单相关表
-- 版本: V1.0
-- ============================================================

CREATE DATABASE IF NOT EXISTS `db_ins_order` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `db_ins_order`;

-- ----------------------------
-- 1. 车险保单主表
-- ----------------------------
CREATE TABLE `ins_order_policy_car` (
  `id`                      BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenant_id`               BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `merchant_id`             BIGINT        NOT NULL COMMENT '商户ID（机构ID）',

  -- 保险公司信息
  `insurance_company_id`    BIGINT        NOT NULL COMMENT '保险公司ID',
  `insurance_company_name`  VARCHAR(100)  NOT NULL COMMENT '保险公司名称',

  -- 保单基本信息
  `policy_no`               VARCHAR(100)  NOT NULL COMMENT '保单号（交强险或商业险）',
  `policy_type`             TINYINT       NOT NULL COMMENT '险种类型：1-交强险 2-商业险 3-交+商',
  `policy_status`           TINYINT       NOT NULL DEFAULT 1 COMMENT '保单状态：1-正常 2-批改 3-退保 4-失效',
  `entry_type`              TINYINT       NOT NULL DEFAULT 2 COMMENT '录入方式：1-直连出单 2-手工录入',

  -- 车辆信息
  `plate_no`                VARCHAR(20)   COMMENT '车牌号',
  `vin_code`                VARCHAR(17)   COMMENT '车架号（VIN）',
  `engine_no`               VARCHAR(30)   COMMENT '发动机号',
  `car_model`               VARCHAR(200)  COMMENT '车型名称',
  `car_brand`               VARCHAR(100)  COMMENT '品牌',
  `car_seat_count`          INT           COMMENT '座位数',
  `car_register_date`       DATE          COMMENT '初次登记日期',
  `car_use_type`            VARCHAR(50)   COMMENT '使用性质（家庭自用/企业非营业等）',
  `car_owner_name`          VARCHAR(100)  COMMENT '车主姓名',
  `car_owner_cert_type`     VARCHAR(20)   COMMENT '车主证件类型',
  `car_owner_cert_no`       VARCHAR(100)  COMMENT '车主证件号（加密存储）',

  -- 交强险信息
  `compulsory_policy_no`    VARCHAR(100)  COMMENT '交强险保单号',
  `premium_compulsory`      DECIMAL(12,2) DEFAULT 0 COMMENT '交强险保费（元）',
  `compulsory_start_date`   DATE          COMMENT '交强险起期',
  `compulsory_end_date`     DATE          COMMENT '交强险止期',

  -- 商业险信息
  `commercial_policy_no`    VARCHAR(100)  COMMENT '商业险保单号',
  `premium_commercial`      DECIMAL(12,2) DEFAULT 0 COMMENT '商业险保费（元）',
  `commercial_start_date`   DATE          COMMENT '商业险起期',
  `commercial_end_date`     DATE          COMMENT '商业险止期',

  -- 车船税
  `vehicle_tax`             DECIMAL(10,2) DEFAULT 0 COMMENT '车船税（元）',

  -- 保费汇总
  `total_premium`           DECIMAL(12,2) DEFAULT 0 COMMENT '总保费（元）',
  `net_premium`             DECIMAL(12,2) DEFAULT 0 COMMENT '净保费（元，不含税）',

  -- 日期信息
  `sign_date`               DATE          NOT NULL COMMENT '签单日期',
  `pay_date`                DATE          COMMENT '支付日期',
  `start_date`              DATE          NOT NULL COMMENT '起保日期',
  `end_date`                DATE          NOT NULL COMMENT '保险止期',

  -- 人员信息
  `company_no_id`           BIGINT        COMMENT '出单工号ID',
  `company_no`              VARCHAR(100)  COMMENT '出单工号',
  `salesman_id`             BIGINT        NOT NULL COMMENT '业务员ID',
  `salesman_name`           VARCHAR(100)  NOT NULL COMMENT '业务员姓名',
  `issuer_id`               BIGINT        COMMENT '出单员ID',
  `issuer_name`             VARCHAR(100)  COMMENT '出单员姓名',
  `org_id`                  BIGINT        COMMENT '所属机构ID',
  `org_name`                VARCHAR(200)  COMMENT '所属机构名称',

  -- 手续费信息（政策匹配后回填）
  `upstream_fee_rate`       DECIMAL(8,4)  DEFAULT 0 COMMENT '上游手续费比例（%）',
  `upstream_fee_amount`     DECIMAL(12,2) DEFAULT 0 COMMENT '上游手续费金额（元）',
  `downstream_fee_rate`     DECIMAL(8,4)  DEFAULT 0 COMMENT '下游手续费比例（%）',
  `downstream_fee_amount`   DECIMAL(12,2) DEFAULT 0 COMMENT '下游手续费金额（元）',
  `profit_amount`           DECIMAL(12,2) DEFAULT 0 COMMENT '利润（元）',

  -- 来源标识
  `channel_name`            VARCHAR(100)  COMMENT '渠道名称',
  `source_type`             TINYINT       DEFAULT 1 COMMENT '来源：1-PC录单 2-App录单 3-批量导入 4-直连',
  `import_batch_no`         VARCHAR(64)   COMMENT '批次导入编号（来自导入时）',

  -- 续保关联
  `is_renewal`              TINYINT(1)    DEFAULT 0 COMMENT '是否续保：0-否 1-是',
  `pre_policy_no`           VARCHAR(100)  COMMENT '上一年度保单号（续保时填写）',

  -- C端关联
  `order_id`                BIGINT        COMMENT '关联订单ID（C端投保时关联）',
  `user_id`                 BIGINT        COMMENT '关联C端用户ID',

  -- 备注
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
  KEY `idx_salesman_id` (`salesman_id`),
  KEY `idx_plate_no` (`plate_no`),
  KEY `idx_vin_code` (`vin_code`),
  KEY `idx_sign_date` (`sign_date`),
  KEY `idx_start_date` (`start_date`),
  KEY `idx_org_id` (`org_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='车险保单主表';


-- ----------------------------
-- 2. 车险保单险别明细表（商业险险别明细）
-- ----------------------------
CREATE TABLE `ins_order_policy_car_coverage` (
  `id`                BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`         BIGINT        NOT NULL COMMENT '关联车险保单ID',
  `tenant_id`         BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `coverage_code`     VARCHAR(50)   NOT NULL COMMENT '险别代码（如CZZE=车损险）',
  `coverage_name`     VARCHAR(100)  NOT NULL COMMENT '险别名称',
  `sum_insured`       DECIMAL(15,2) DEFAULT 0 COMMENT '保额（元）',
  `premium`           DECIMAL(10,2) DEFAULT 0 COMMENT '该险别保费（元）',
  `deductible_rate`   DECIMAL(5,2)  DEFAULT 0 COMMENT '绝对免赔率（%）',
  `is_selected`       TINYINT(1)    DEFAULT 1 COMMENT '是否投保：1-是 0-否',
  `remark`            VARCHAR(200)  COMMENT '备注',
  `creator`           VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `deleted`           TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='车险保单险别明细表';


-- ----------------------------
-- 3. 车险批改单表（endorsement）
-- ----------------------------
CREATE TABLE `ins_order_policy_car_endorsement` (
  `id`                    BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenant_id`             BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `policy_id`             BIGINT        NOT NULL COMMENT '关联原车险保单ID',
  `original_policy_no`    VARCHAR(100)  NOT NULL COMMENT '原保单号',
  `endorsement_no`        VARCHAR(100)  NOT NULL COMMENT '批改单号',
  `endorsement_type`      VARCHAR(50)   COMMENT '批改类型（增保/减保/变更标的/其他）',
  `endorsement_reason`    VARCHAR(500)  COMMENT '批改原因',
  `endorsement_date`      DATE          NOT NULL COMMENT '批改生效日期',
  `pay_date`              DATE          COMMENT '支付日期（批改后更新为最新批单日期）',
  `premium_change`        DECIMAL(12,2) DEFAULT 0 COMMENT '批改保费差额（元，可负数）',
  `premium_after`         DECIMAL(12,2) DEFAULT 0 COMMENT '批改后净保费（元）',
  `upstream_fee_change`   DECIMAL(10,2) DEFAULT 0 COMMENT '上游手续费变动（元）',
  `downstream_fee_change` DECIMAL(10,2) DEFAULT 0 COMMENT '下游手续费变动（元）',
  `status`                TINYINT       NOT NULL DEFAULT 1 COMMENT '状态：1-正常 0-已撤销',
  `operator_id`           BIGINT        COMMENT '操作人ID',
  `operator_name`         VARCHAR(100)  COMMENT '操作人名称',
  `remark`                VARCHAR(500)  COMMENT '备注',
  `creator`               VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`               VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`               TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_endorsement_no` (`tenant_id`, `endorsement_no`, `deleted`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_original_policy_no` (`original_policy_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='车险批改单表';


-- ----------------------------
-- 4. 车险续保记录表
-- ----------------------------
CREATE TABLE `ins_order_car_renewal` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `policy_id`           BIGINT        NOT NULL COMMENT '当前保单ID',
  `policy_no`           VARCHAR(100)  NOT NULL COMMENT '当前保单号',
  `pre_policy_id`       BIGINT        COMMENT '上年度保单ID',
  `pre_policy_no`       VARCHAR(100)  COMMENT '上年度保单号',
  `plate_no`            VARCHAR(20)   NOT NULL COMMENT '车牌号',
  `vin_code`            VARCHAR(17)   COMMENT '车架号',
  `renewal_status`      TINYINT       NOT NULL DEFAULT 0 COMMENT '续保状态：0-待跟进 1-已续保 2-未续保 3-转保他司',
  `salesman_id`         BIGINT        NOT NULL COMMENT '业务员ID',
  `salesman_name`       VARCHAR(100)  NOT NULL COMMENT '业务员姓名',
  `remind_count`        INT           DEFAULT 0 COMMENT '提醒次数',
  `last_remind_time`    DATETIME      COMMENT '最后一次提醒时间',
  `renewal_note`        VARCHAR(500)  COMMENT '续保备注',
  `expiry_date`         DATE          NOT NULL COMMENT '保单到期日（提醒依据）',
  `creator`             VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`             VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`             TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_plate_no` (`plate_no`),
  KEY `idx_salesman_id` (`salesman_id`),
  KEY `idx_expiry_date` (`expiry_date`),
  KEY `idx_renewal_status` (`renewal_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='车险续保记录表';

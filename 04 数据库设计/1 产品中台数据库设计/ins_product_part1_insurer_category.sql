-- =============================================================================
-- 保险产品中台 - intermediary-module-ins-product
-- Schema: db_ins_product
-- 表前缀: ins_product_
-- Part 1: 保险公司档案 + 险种分类
-- yudao-cloud 框架兼容，字段遵循框架规范（creator/updater/deleted/tenant_id）
-- =============================================================================

CREATE DATABASE IF NOT EXISTS `db_ins_product` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `db_ins_product`;

-- -----------------------------------------------------------------------------
-- 1. 保险公司档案表 ins_product_insurer
-- 车险/非车险/寿险共用，寿险扩展字段存 ins_product_insurer_life_ext
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_insurer`;
CREATE TABLE `ins_product_insurer` (
    `id`                    BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `company_code`          VARCHAR(50)  NOT NULL COMMENT '保司编码（全局唯一，保司内部使用的简码，如 PICC/CPIC）',
    `company_name`          VARCHAR(200) NOT NULL COMMENT '保司全称（营业执照名称）',
    `company_short_name`    VARCHAR(100) DEFAULT NULL COMMENT '保司简称（界面展示用）',
    `license_no`            VARCHAR(100) DEFAULT NULL COMMENT '经营许可证编号',
    `logo_url`              VARCHAR(500) DEFAULT NULL COMMENT '公司Logo（OSS URL）',
    `insurance_type`        TINYINT      NOT NULL DEFAULT 3 COMMENT '险种归属类型：1-车险 2-非车险 3-通用（含寿险）',
    `status`                TINYINT      NOT NULL DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    `contact_person`        VARCHAR(50)  DEFAULT NULL COMMENT '对接联系人',
    `contact_phone`         VARCHAR(20)  DEFAULT NULL COMMENT '联系电话',
    `api_enabled`           TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '是否开启API对接：0-否 1-是',
    `api_base_url`          VARCHAR(500) DEFAULT NULL COMMENT 'API基础地址',
    `api_app_id`            VARCHAR(200) DEFAULT NULL COMMENT 'API AppID',
    `api_app_key`           VARCHAR(500) DEFAULT NULL COMMENT 'API AppKey（AES-256加密存储）',
    `api_last_test_time`    DATETIME     DEFAULT NULL COMMENT '最后API测试时间',
    `api_test_result`       TINYINT      DEFAULT NULL COMMENT 'API测试结果：0-失败 1-成功',
    `commission_rate`       DECIMAL(6,4) DEFAULT NULL COMMENT '默认手续费协议比例（0.0000~1.0000）',
    `remark`                VARCHAR(500) DEFAULT NULL COMMENT '备注',
    `sort`                  INT          NOT NULL DEFAULT 0 COMMENT '排序值',
    `creator`               VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_company_code` (`company_code`, `deleted`),
    KEY `idx_tenant_status` (`tenant_id`, `status`, `deleted`),
    KEY `idx_insurance_type` (`insurance_type`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='保险公司档案表';


-- -----------------------------------------------------------------------------
-- 2. 寿险保司扩展表 ins_product_insurer_life_ext
-- 与 ins_product_insurer 1:1 关联，存储寿险专属字段
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_insurer_life_ext`;
CREATE TABLE `ins_product_insurer_life_ext` (
    `id`                    BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `insurer_id`            BIGINT       NOT NULL COMMENT '关联保司ID（ins_product_insurer.id）',
    `agreement_no`          VARCHAR(200) DEFAULT NULL COMMENT '执行协议编号（代理销售协议）',
    `agreement_start_date`  DATE         DEFAULT NULL COMMENT '协议起始日期',
    `agreement_end_date`    DATE         DEFAULT NULL COMMENT '协议截止日期',
    `settlement_mode`       TINYINT      NOT NULL DEFAULT 1 COMMENT '结算方式：1-银行转账 2-支付宝 3-其他',
    `bank_name`             VARCHAR(200) DEFAULT NULL COMMENT '开户银行名称（结算方式=1时必填）',
    `bank_account_no`       VARCHAR(500) DEFAULT NULL COMMENT '银行账号（AES-256加密存储）',
    `bank_account_name`     VARCHAR(200) DEFAULT NULL COMMENT '开户行名称',
    `creator`               VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_insurer_id` (`insurer_id`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险保司扩展信息表';


-- -----------------------------------------------------------------------------
-- 3. 险种分类表 ins_product_category
-- 树形结构，支持车险/非车险/寿险三大险种分类管理
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_category`;
CREATE TABLE `ins_product_category` (
    `id`                    BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `parent_id`             BIGINT       NOT NULL DEFAULT 0 COMMENT '父分类ID，顶级为0',
    `category_code`         VARCHAR(50)  NOT NULL COMMENT '险种编码（全局唯一，如 AUTO/FIRE/LIFE/HEALTH/ACCIDENT/ANNUITY）',
    `category_name`         VARCHAR(100) NOT NULL COMMENT '险种名称（如 车险/财产险/寿险/重疾险/意外险/年金险）',
    `insurance_type`        TINYINT      NOT NULL COMMENT '所属大险种：1-车险 2-非车险 3-寿险/健康险/意外险',
    `icon_url`              VARCHAR(500) DEFAULT NULL COMMENT '分类图标（OSS URL）',
    `category_type`         TINYINT      NOT NULL DEFAULT 1 COMMENT '分类类型：1-系统预置 2-自定义',
    `status`                TINYINT      NOT NULL DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    `sort`                  INT          NOT NULL DEFAULT 0 COMMENT '同级排序',
    `remark`                VARCHAR(500) DEFAULT NULL COMMENT '备注说明',
    `creator`               VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID（系统预置分类tenant_id=0，全租户共享）',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_category_code` (`category_code`, `deleted`),
    KEY `idx_parent_id` (`parent_id`, `status`, `deleted`),
    KEY `idx_insurance_type` (`insurance_type`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='险种分类表（树形结构）';


-- -----------------------------------------------------------------------------
-- 4. 保司工号表 ins_product_insurer_account
-- 存储与各保司API对接时使用的工号信息（车险/非车险/寿险均适用）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_insurer_account`;
CREATE TABLE `ins_product_insurer_account` (
    `id`                    BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `insurer_id`            BIGINT       NOT NULL COMMENT '关联保司ID',
    `insurance_type`        TINYINT      NOT NULL DEFAULT 3 COMMENT '险种类型：1-车险 2-非车险 3-寿险',
    `account_no`            VARCHAR(200) NOT NULL COMMENT '工号/账号',
    `app_id`                VARCHAR(200) DEFAULT NULL COMMENT 'API AppID（保司分配）',
    `app_key`               VARCHAR(500) DEFAULT NULL COMMENT 'API AppKey（AES-256加密存储，展示时仅显示后4位）',
    `api_base_url`          VARCHAR(500) DEFAULT NULL COMMENT 'API基础地址',
    `org_id`                BIGINT       DEFAULT NULL COMMENT '关联机构ID（NULL则全机构可用）',
    `agent_id`              BIGINT       DEFAULT NULL COMMENT '关联业务员ID（NULL则不限业务员）',
    `status`                TINYINT      NOT NULL DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    `last_test_time`        DATETIME     DEFAULT NULL COMMENT '最后连接测试时间',
    `test_result`           TINYINT      DEFAULT NULL COMMENT '测试结果：0-失败 1-成功',
    `remark`                VARCHAR(500) DEFAULT NULL COMMENT '备注',
    `creator`               VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    KEY `idx_insurer_type` (`insurer_id`, `insurance_type`, `status`),
    KEY `idx_tenant_status` (`tenant_id`, `status`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='保司工号/API账号表';


-- =============================================================================
-- 初始化数据：险种分类（系统预置，tenant_id=0）
-- =============================================================================

INSERT INTO `ins_product_category` (`parent_id`, `category_code`, `category_name`, `insurance_type`, `category_type`, `status`, `sort`, `creator`, `updater`, `tenant_id`) VALUES
-- 一级分类
(0, 'AUTO',        '车险',     1, 1, 1, 10, 'system', 'system', 0),
(0, 'NON_VEHICLE', '非车险',   2, 1, 1, 20, 'system', 'system', 0),
(0, 'LIFE',        '寿险',     3, 1, 1, 30, 'system', 'system', 0),
(0, 'HEALTH',      '健康险',   3, 1, 1, 40, 'system', 'system', 0),
(0, 'ACCIDENT',    '意外险',   3, 1, 1, 50, 'system', 'system', 0),
(0, 'ANNUITY',     '年金险',   3, 1, 1, 60, 'system', 'system', 0);

-- 非车险二级分类（parent_id待程序赋值，此处用占位符说明结构）
-- 财产险、责任险、工程险、农业险、信用保证险等可在系统初始化时按需补充

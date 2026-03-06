-- =============================================================================
-- 保险产品中台 - intermediary-module-ins-product
-- Schema: db_ins_product
-- Part 2: 产品主表（通用）+ 车险专属产品配置
-- =============================================================================

USE `db_ins_product`;

-- -----------------------------------------------------------------------------
-- 5. 产品主表 ins_product_info
-- 车险/非车险/寿险产品共用，险种差异字段通过扩展表管理
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_info`;
CREATE TABLE `ins_product_info` (
    `id`                        BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_code`              VARCHAR(100)    NOT NULL COMMENT '产品代码（同保司内唯一，创建后不可改，建议：公司代码-险种-序号）',
    `product_name`              VARCHAR(200)    NOT NULL COMMENT '产品名称',
    `insurer_id`                BIGINT          NOT NULL COMMENT '关联保司ID（ins_product_insurer.id）',
    `insurer_name`              VARCHAR(200)    NOT NULL COMMENT '保司名称（冗余）',
    `category_id`               BIGINT          NOT NULL COMMENT '险种分类ID（ins_product_category.id）',
    `category_name`             VARCHAR(100)    NOT NULL COMMENT '险种分类名称（冗余）',
    `insurance_type`            TINYINT         NOT NULL COMMENT '险种大类：1-车险 2-非车险 3-寿险 4-健康险 5-意外险 6-年金险',
    `product_type`              TINYINT         NOT NULL DEFAULT 1 COMMENT '产品类型：1-系统产品 2-自定义产品',
    `product_image`             VARCHAR(500)    DEFAULT NULL COMMENT '产品图片（OSS URL，上架前必填）',
    `product_summary`           VARCHAR(500)    DEFAULT NULL COMMENT '产品简介（最多200字）',
    `product_detail`            MEDIUMTEXT      DEFAULT NULL COMMENT '产品详情（富文本HTML）',
    `highlight_list`            JSON            DEFAULT NULL COMMENT '产品亮点列表（JSON数组，最多5条，每条<=20字）',
    `coverage_detail`           JSON            DEFAULT NULL COMMENT '保障责任明细（JSON结构）',
    `faq`                       JSON            DEFAULT NULL COMMENT '常见问答（JSON数组：[{q:"",a:""}]）',
    `exclusions`                TEXT            DEFAULT NULL COMMENT '免责条款说明',
    `case_study`                TEXT            DEFAULT NULL COMMENT '投保案例（富文本或Markdown）',
    `coverage_period`           INT             DEFAULT NULL COMMENT '保障期限（月数，-1=终身）',
    `coverage_period_type`      TINYINT         DEFAULT NULL COMMENT '保障期限类型：1-定期 2-终身',
    `min_premium`               BIGINT          DEFAULT NULL COMMENT '最低保费（分）',
    `max_premium`               BIGINT          DEFAULT NULL COMMENT '最高保费（分）',
    `min_coverage`              BIGINT          DEFAULT NULL COMMENT '最低保额（分）',
    `max_coverage`              BIGINT          DEFAULT NULL COMMENT '最高保额（分）',
    `min_age`                   INT             DEFAULT NULL COMMENT '最小投保年龄（岁）',
    `max_age`                   INT             DEFAULT NULL COMMENT '最大投保年龄（岁）',
    `status`                    TINYINT         NOT NULL DEFAULT 0 COMMENT '产品状态：0-下架 1-上架 2-草稿 3-待审核 4-停售',
    `stock`                     INT             NOT NULL DEFAULT -1 COMMENT '库存：-1=无限库存，>=0=有限库存',
    `stock_alert_threshold`     INT             NOT NULL DEFAULT 10 COMMENT '库存预警值',
    `sales_count`               INT             NOT NULL DEFAULT 0 COMMENT '累计销量（出单量）',
    `is_hot`                    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否热销标签：0-否 1-是（sales_count>=100自动打标）',
    `commission_rate`           DECIMAL(6,4)    DEFAULT NULL COMMENT '默认佣金比例（0.0000~1.0000）',
    `commission_rate_renewal`   DECIMAL(6,4)    DEFAULT NULL COMMENT '续年佣金比例（寿险适用）',
    `reference_premium_desc`    VARCHAR(200)    DEFAULT NULL COMMENT '参考保费文案描述（如"30岁男性，20年期，月缴¥328起"）',
    `auto_on_shelf_time`        DATETIME        DEFAULT NULL COMMENT '定时上架时间',
    `auto_off_shelf_time`       DATETIME        DEFAULT NULL COMMENT '定时下架时间',
    `on_shelf_time`             DATETIME        DEFAULT NULL COMMENT '实际上架时间',
    `off_shelf_time`            DATETIME        DEFAULT NULL COMMENT '实际下架时间',
    `product_manual_url`        VARCHAR(500)    DEFAULT NULL COMMENT '产品说明书（PDF，OSS URL）',
    `sort`                      INT             NOT NULL DEFAULT 0 COMMENT '排序值',
    `remark`                    VARCHAR(500)    DEFAULT NULL COMMENT '备注',
    `creator`                   VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`                   VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`                   TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`                 BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID（系统产品=0，自定义产品=所属租户）',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_product_code` (`product_code`, `insurer_id`, `deleted`),
    KEY `idx_tenant_category` (`tenant_id`, `category_id`, `status`, `deleted`),
    KEY `idx_insurer_status` (`insurer_id`, `status`, `deleted`),
    KEY `idx_insurance_type` (`insurance_type`, `status`, `deleted`),
    KEY `idx_auto_on_shelf` (`auto_on_shelf_time`, `status`, `deleted`),
    KEY `idx_auto_off_shelf` (`auto_off_shelf_time`, `status`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='保险产品主表（车险/非车险/寿险通用）';


-- -----------------------------------------------------------------------------
-- 6. 产品分级佣金配置表 ins_product_commission_level
-- 按业务员等级配置不同佣金比例（最多4级）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_commission_level`;
CREATE TABLE `ins_product_commission_level` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '关联产品ID（ins_product_info.id）',
    `agent_level`           TINYINT         NOT NULL COMMENT '业务员等级：1-初级 2-中级 3-高级 4-资深',
    `commission_rate`       DECIMAL(6,4)    NOT NULL COMMENT '该等级佣金比例（0.0000~1.0000）',
    `commission_rate_renewal` DECIMAL(6,4)  DEFAULT NULL COMMENT '续年佣金比例（寿险适用）',
    `payment_mode`          VARCHAR(50)     DEFAULT NULL COMMENT '缴费方式（寿险：趸缴/年缴/半年缴/季缴/月缴，NULL=全部适用）',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    KEY `idx_product_level` (`product_id`, `agent_level`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品分级佣金配置表';


-- -----------------------------------------------------------------------------
-- 7. 佣金比例变更日志表 ins_product_commission_change_log
-- 记录佣金变更历史，只影响后续新订单
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_commission_change_log`;
CREATE TABLE `ins_product_commission_change_log` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '产品ID',
    `old_commission_rate`   DECIMAL(6,4)    DEFAULT NULL COMMENT '变更前佣金比例',
    `new_commission_rate`   DECIMAL(6,4)    DEFAULT NULL COMMENT '变更后佣金比例',
    `change_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '变更时间',
    `operator_id`           BIGINT          NOT NULL COMMENT '操作人ID',
    `operator_name`         VARCHAR(100)    DEFAULT NULL COMMENT '操作人姓名（冗余）',
    `remark`                VARCHAR(500)    DEFAULT NULL COMMENT '变更原因说明',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    KEY `idx_product_time` (`product_id`, `change_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品佣金比例变更日志';


-- -----------------------------------------------------------------------------
-- 8. 产品机构授权表 ins_product_org_auth
-- 控制哪些机构可以销售特定产品（产品上架前须至少授权一个机构）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_org_auth`;
CREATE TABLE `ins_product_org_auth` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '产品ID',
    `org_id`                BIGINT          NOT NULL COMMENT '授权机构ID（对应系统组织架构）',
    `org_name`              VARCHAR(200)    DEFAULT NULL COMMENT '机构名称（冗余）',
    `auth_time`             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '授权时间',
    `operator_id`           BIGINT          NOT NULL COMMENT '操作人ID',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-有效 1-已取消授权',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_product_org` (`product_id`, `org_id`, `deleted`),
    KEY `idx_org_product` (`org_id`, `product_id`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品机构授权表';


-- -----------------------------------------------------------------------------
-- 9. 产品收藏表 ins_product_favorite
-- 业务员收藏产品，支持产品列表展示 isFavorite 字段
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_favorite`;
CREATE TABLE `ins_product_favorite` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '产品ID',
    `agent_id`              BIGINT          NOT NULL COMMENT '业务员ID',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '收藏时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-已收藏 1-已取消',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_agent_product` (`agent_id`, `product_id`, `deleted`),
    KEY `idx_product_id` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品收藏表（业务员端）';


-- -----------------------------------------------------------------------------
-- 10. 产品浏览记录表 ins_product_view_log
-- 异步写入，用于热度统计（sales_count/is_hot字段依赖此表）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_view_log`;
CREATE TABLE `ins_product_view_log` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '产品ID',
    `agent_id`              BIGINT          DEFAULT NULL COMMENT '业务员ID（NULL表示C端匿名访问）',
    `member_id`             BIGINT          DEFAULT NULL COMMENT 'C端会员ID',
    `view_source`           TINYINT         NOT NULL DEFAULT 1 COMMENT '访问来源：1-业务员App 2-C端小程序',
    `view_time`             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '浏览时间',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    KEY `idx_product_time` (`product_id`, `view_time`),
    KEY `idx_agent_time` (`agent_id`, `view_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品浏览记录表';


-- -----------------------------------------------------------------------------
-- 11. 车险费率表 ins_product_car_rate
-- EasyExcel导入，rate_key为组合键（省份+车龄+NCD系数等）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_car_rate`;
CREATE TABLE `ins_product_car_rate` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '关联产品ID',
    `province_code`         VARCHAR(20)     DEFAULT NULL COMMENT '省份编码（行政区划代码，如310000=上海）',
    `car_age`               INT             DEFAULT NULL COMMENT '车龄（年）',
    `ncd_factor`            DECIMAL(5,4)    DEFAULT NULL COMMENT 'NCD系数（无赔款优待系数，如0.85）',
    `rate_key`              VARCHAR(200)    NOT NULL COMMENT '费率键（组合唯一标识，如province_310000_age_3_ncd_0.85）',
    `rate_value`            DECIMAL(10,6)   NOT NULL COMMENT '费率值（如0.125000=12.5%）',
    `rate_type`             TINYINT         NOT NULL DEFAULT 1 COMMENT '费率类型：1-交强险基准 2-商业险基准 3-系数',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_product_rate_key` (`product_id`, `rate_key`, `deleted`),
    KEY `idx_product_province` (`product_id`, `province_code`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='车险费率表';


-- -----------------------------------------------------------------------------
-- 12. 非车险系统产品方案表 ins_product_non_vehicle_plan
-- 系统预置的非车险产品方案（只读，不可增删改），用于政策配置中产品方案字段的数据源
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_non_vehicle_plan`;
CREATE TABLE `ins_product_non_vehicle_plan` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '关联系统产品ID（ins_product_info.id）',
    `plan_name`             VARCHAR(200)    NOT NULL COMMENT '产品方案名称',
    `plan_code`             VARCHAR(100)    DEFAULT NULL COMMENT '方案编码',
    `plan_desc`             VARCHAR(500)    DEFAULT NULL COMMENT '方案说明',
    `status`                TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    `sort`                  INT             NOT NULL DEFAULT 0 COMMENT '排序',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID（系统预置=0）',
    PRIMARY KEY (`id`),
    KEY `idx_product_status` (`product_id`, `status`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='非车险系统产品方案表';

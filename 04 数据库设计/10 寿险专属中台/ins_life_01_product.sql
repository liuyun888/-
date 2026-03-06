-- =============================================================================
-- 保险中介平台 · intermediary-module-ins-life
-- 数据库：db_ins_life
-- 表前缀：ins_life_（寿险专属）/ ins_insurer_（保司扩展）/ ins_questionnaire_（问卷引擎）
-- Part 1：寿险产品模块（Product）
-- 对应需求：阶段7 § 产品管理（PDF-169/170）、阶段8 C端商城-寿险投保
-- 工程模块：intermediary-module-ins-product-server（产品主表）
--           intermediary-module-ins-life-server（寿险专属扩展）
-- 生成日期：2026-03-01
-- =============================================================================

CREATE DATABASE IF NOT EXISTS `db_ins_life` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `db_ins_life`;

-- -----------------------------------------------------------------------------
-- 1. 寿险保司扩展信息表  ins_insurer_life_ext
--    对应需求：合作保司管理（PDF-169）
--    与车险/非车险共用基础表 ins_insurer，通过本表扩展寿险专属字段
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_insurer_life_ext` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT                    COMMENT '主键ID',
  `insurer_id`       BIGINT        NOT NULL                                   COMMENT '保险公司ID，关联ins_insurer.id',
  `agreement_no`     VARCHAR(64)   DEFAULT NULL                               COMMENT '执行协议编号',
  `agreement_start`  DATE          DEFAULT NULL                               COMMENT '协议起始日期',
  `agreement_end`    DATE          DEFAULT NULL                               COMMENT '协议终止日期',
  `settle_method`    VARCHAR(20)   NOT NULL DEFAULT 'BANK_TRANSFER'           COMMENT '结算方式：BANK_TRANSFER/ALIPAY/OTHER',
  `bank_name`        VARCHAR(100)  DEFAULT NULL                               COMMENT '开户银行名称（结算=BANK_TRANSFER时必填）',
  `bank_branch`      VARCHAR(200)  DEFAULT NULL                               COMMENT '开户行支行名称',
  `bank_account`     VARCHAR(512)  DEFAULT NULL                               COMMENT '开户账号（AES-256加密存储）',
  `api_enabled`      TINYINT       NOT NULL DEFAULT 0                         COMMENT 'API对接开关：0关 1开',
  `api_endpoint`     VARCHAR(500)  DEFAULT NULL                               COMMENT 'API接入地址',
  `api_key`          VARCHAR(512)  DEFAULT NULL                               COMMENT 'API密钥（AES加密）',
  `remark`           VARCHAR(500)  DEFAULT NULL                               COMMENT '备注',
  `creator`          VARCHAR(64)   DEFAULT ''                                 COMMENT '创建者',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP         COMMENT '创建时间',
  `updater`          VARCHAR(64)   DEFAULT ''                                 COMMENT '更新者',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP                              COMMENT '更新时间',
  `deleted`          TINYINT       NOT NULL DEFAULT 0                         COMMENT '软删除：0未删除 1已删除',
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0                         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_insurer_id` (`insurer_id`),
  INDEX `idx_deleted` (`deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险合作保司扩展信息表（PDF-169）';


-- -----------------------------------------------------------------------------
-- 2. 寿险产品主表  ins_life_product
--    对应需求：寿险产品管理（PDF-170）、C端产品列表（阶段8）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_product` (
  `id`                      BIGINT         NOT NULL AUTO_INCREMENT              COMMENT '产品ID',
  `product_code`            VARCHAR(50)    NOT NULL                             COMMENT '保司侧产品编码（同一保司内唯一）',
  `product_name`            VARCHAR(100)   NOT NULL                             COMMENT '产品名称',
  `insurer_id`              BIGINT         NOT NULL                             COMMENT '保险公司ID',
  `insurer_name`            VARCHAR(100)   DEFAULT NULL                         COMMENT '保险公司名称（冗余）',
  `insurer_logo_url`        VARCHAR(500)   DEFAULT NULL                         COMMENT '保司LOGO（OSS，C端展示）',
  -- 险种分类：LIFE寿险/CRITICAL重疾/MEDICAL医疗/ACCIDENT意外/SAVING年金/WHOLE_LIFE万能险
  `category_code`           VARCHAR(20)    NOT NULL                             COMMENT '险种分类编码',
  `category_icon`           VARCHAR(500)   DEFAULT NULL                         COMMENT '险种图标URL（C端筛选显示）',
  -- 保障期限
  `coverage_period_type`    VARCHAR(20)    NOT NULL                             COMMENT '保障期限类型：FIXED定期/WHOLE_LIFE终身',
  `coverage_period_years`   INT            DEFAULT NULL                         COMMENT '保障期限（年），type=FIXED时必填',
  `coverage_period`         VARCHAR(50)    DEFAULT NULL                         COMMENT '保障期限展示文案，如"保至终身"/"保至70岁"',
  -- 缴费
  `payment_methods`         VARCHAR(100)   NOT NULL                             COMMENT '缴费方式逗号分隔：SINGLE/ANNUAL/HALF_YEAR/QUARTER/MONTHLY',
  `payment_period_list`     JSON           DEFAULT NULL                         COMMENT '支持缴费期JSON数组，如["趸缴","10年","20年"]',
  -- 保额范围
  `min_coverage_amount`     DECIMAL(15,2)  DEFAULT NULL                         COMMENT '最低保障额度（元）',
  `max_coverage_amount`     DECIMAL(15,2)  DEFAULT NULL                         COMMENT '最高保障额度（元）',
  -- 投保年龄
  `min_insure_age`          INT            NOT NULL DEFAULT 0                   COMMENT '最小投保年龄（周岁）',
  `max_insure_age`          INT            NOT NULL DEFAULT 70                  COMMENT '最大投保年龄（周岁）',
  `support_monthly`         TINYINT        NOT NULL DEFAULT 0                   COMMENT '是否支持月缴：0否 1是',
  `effective_delay_days`    INT            NOT NULL DEFAULT 0                   COMMENT '保障起始延迟天数（0=当日 1=次日0点）',
  `grace_period_days`       INT            NOT NULL DEFAULT 60                  COMMENT '宽限期天数，默认60天',
  -- 健康告知（冗余存储JSON，完整绑定见ins_life_product_questionnaire）
  `health_notice_json`      JSON           DEFAULT NULL                         COMMENT '健康告知问卷问题列表JSON（含跳题逻辑）',
  -- C端展示
  `highlight_list`          JSON           DEFAULT NULL                         COMMENT '产品亮点文案JSON数组，最多3条',
  `reference_premium_desc`  VARCHAR(200)   DEFAULT NULL                         COMMENT '参考保费文案，如"30岁男，月缴¥328起"',
  `intro`                   LONGTEXT       DEFAULT NULL                         COMMENT '产品简介（富文本HTML）',
  `manual_url`              VARCHAR(500)   DEFAULT NULL                         COMMENT '产品说明书PDF（OSS路径）',
  `is_hot`                  TINYINT        NOT NULL DEFAULT 0                   COMMENT '热销标签：0否 1是',
  `sort_weight`             INT            NOT NULL DEFAULT 0                   COMMENT '排序权重（值越大越靠前）',
  -- 状态：DRAFT草稿/PENDING_REVIEW待审/ON_SALE上架/OFF_SALE下架/STOP_SALE停售
  `status`                  VARCHAR(20)    NOT NULL DEFAULT 'OFF_SALE'          COMMENT '产品状态',
  -- 上架前置校验标志
  `is_rate_configured`      TINYINT        NOT NULL DEFAULT 0                   COMMENT '已配置费率表：0否 1是',
  `is_auth_configured`      TINYINT        NOT NULL DEFAULT 0                   COMMENT '已授权机构：0否 1是',
  `creator`                 VARCHAR(64)    DEFAULT ''                           COMMENT '创建者',
  `create_time`             DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP   COMMENT '创建时间',
  `updater`                 VARCHAR(64)    DEFAULT ''                           COMMENT '更新者',
  `update_time`             DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                            ON UPDATE CURRENT_TIMESTAMP                         COMMENT '更新时间',
  `deleted`                 TINYINT        NOT NULL DEFAULT 0                   COMMENT '软删除：0未删除 1已删除',
  `tenant_id`               BIGINT         NOT NULL DEFAULT 0                   COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_insurer_product_code` (`insurer_id`, `product_code`, `deleted`),
  INDEX `idx_category_code` (`category_code`),
  INDEX `idx_status` (`status`),
  INDEX `idx_is_hot_sort` (`is_hot`, `sort_weight`),
  INDEX `idx_insure_age` (`min_insure_age`, `max_insure_age`),
  INDEX `idx_deleted_status` (`deleted`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险产品主表（PDF-170，C端列表接口: GET /app-api/ins/life/product/page）';


-- -----------------------------------------------------------------------------
-- 3. 寿险产品佣金配置表  ins_life_product_commission
--    对应需求：PDF-170 Tab2-佣金配置（按缴费方式分行配置首年/续年佣金率）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_product_commission` (
  `id`                BIGINT         NOT NULL AUTO_INCREMENT                    COMMENT '主键ID',
  `product_id`        BIGINT         NOT NULL                                   COMMENT '产品ID',
  `payment_method`    VARCHAR(20)    NOT NULL                                   COMMENT '缴费方式：SINGLE/ANNUAL/HALF_YEAR/QUARTER/MONTHLY',
  `first_year_rate`   DECIMAL(8,4)   NOT NULL DEFAULT 0.0000                    COMMENT '首年佣金率（%），精度4位',
  `renewal_year_rate` DECIMAL(8,4)   NOT NULL DEFAULT 0.0000                    COMMENT '续年佣金率（%），精度4位',
  `fyc_base`          VARCHAR(20)    DEFAULT 'ANNUAL_PREMIUM'                   COMMENT 'FYC基础：ANNUAL_PREMIUM年保费/STANDARD_PREMIUM标准保费',
  `remark`            VARCHAR(200)   DEFAULT NULL                               COMMENT '备注',
  `creator`           VARCHAR(64)    DEFAULT ''                                 COMMENT '创建者',
  `create_time`       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP         COMMENT '创建时间',
  `updater`           VARCHAR(64)    DEFAULT ''                                 COMMENT '更新者',
  `update_time`       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                      ON UPDATE CURRENT_TIMESTAMP                               COMMENT '更新时间',
  `deleted`           TINYINT        NOT NULL DEFAULT 0                         COMMENT '软删除',
  `tenant_id`         BIGINT         NOT NULL DEFAULT 0                         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_product_payment` (`product_id`, `payment_method`, `deleted`),
  INDEX `idx_product_id` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险产品佣金配置表（PDF-170 Tab2）';


-- -----------------------------------------------------------------------------
-- 4. 寿险产品费率表  ins_life_product_rate
--    对应需求：PDF-170 Tab4-费率表（支持EasyExcel批量导入）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_product_rate` (
  `id`                BIGINT         NOT NULL AUTO_INCREMENT                    COMMENT '主键ID',
  `product_id`        BIGINT         NOT NULL                                   COMMENT '产品ID',
  `age_min`           INT            NOT NULL                                   COMMENT '年龄段最小值（周岁，含）',
  `age_max`           INT            NOT NULL                                   COMMENT '年龄段最大值（周岁，含）',
  `gender`            CHAR(1)        DEFAULT NULL                               COMMENT '性别：M男/F女/NULL不区分',
  `coverage_term`     VARCHAR(50)    DEFAULT NULL                               COMMENT '保障期限，如"20年"/"终身"',
  `payment_period`    VARCHAR(20)    DEFAULT NULL                               COMMENT '缴费期，如"10年"/"20年"',
  `premium_per_unit`  DECIMAL(12,4)  NOT NULL                                   COMMENT '保费/万元保额（元）',
  `effective_date`    DATE           DEFAULT NULL                               COMMENT '费率生效日期',
  `expiry_date`       DATE           DEFAULT NULL                               COMMENT '费率失效日期（NULL=长期有效）',
  `import_batch_no`   VARCHAR(64)    DEFAULT NULL                               COMMENT '导入批次号',
  `creator`           VARCHAR(64)    DEFAULT ''                                 COMMENT '创建者',
  `create_time`       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP         COMMENT '创建时间',
  `updater`           VARCHAR(64)    DEFAULT ''                                 COMMENT '更新者',
  `update_time`       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                      ON UPDATE CURRENT_TIMESTAMP                               COMMENT '更新时间',
  `deleted`           TINYINT        NOT NULL DEFAULT 0                         COMMENT '软删除',
  `tenant_id`         BIGINT         NOT NULL DEFAULT 0                         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_product_id` (`product_id`),
  INDEX `idx_product_age_gender` (`product_id`, `age_min`, `age_max`, `gender`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险产品费率表（PDF-170 Tab4，EasyExcel导入）';


-- -----------------------------------------------------------------------------
-- 5. 寿险产品机构授权表  ins_life_product_auth
--    对应需求：PDF-170 产品授权到机构
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_product_auth` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `product_id`    BIGINT       NOT NULL                                         COMMENT '产品ID',
  `org_id`        BIGINT       NOT NULL                                         COMMENT '机构ID，关联sys_dept.id',
  `org_name`      VARCHAR(100) DEFAULT NULL                                     COMMENT '机构名称（冗余）',
  `auth_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '授权时间',
  `operator_id`   BIGINT       DEFAULT NULL                                     COMMENT '操作人ID',
  `operator_name` VARCHAR(64)  DEFAULT NULL                                     COMMENT '操作人姓名（冗余）',
  `creator`       VARCHAR(64)  DEFAULT ''                                       COMMENT '创建者',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `deleted`       TINYINT      NOT NULL DEFAULT 0                               COMMENT '软删除',
  `tenant_id`     BIGINT       NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_product_org` (`product_id`, `org_id`, `deleted`),
  INDEX `idx_product_id` (`product_id`),
  INDEX `idx_org_id` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险产品机构授权表（PDF-170 产品授权）';


-- -----------------------------------------------------------------------------
-- 6. 健康告知问卷模板表  ins_questionnaire_template
--    对应需求：PDF-170 Tab3 / 架构V15-问卷引擎统一
--    注意：此表为全平台统一问卷引擎表，AI保障规划与健康核保共用
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_questionnaire_template` (
  `id`             BIGINT        NOT NULL AUTO_INCREMENT                        COMMENT '问卷模板ID',
  `template_code`  VARCHAR(50)   NOT NULL                                       COMMENT '问卷编码（全局唯一）',
  `template_name`  VARCHAR(200)  NOT NULL                                       COMMENT '问卷名称',
  -- HEALTH=健康告知问卷  AI_PLAN=AI保障规划问卷
  `template_type`  VARCHAR(20)   NOT NULL DEFAULT 'HEALTH'                      COMMENT '问卷类型：HEALTH/AI_PLAN',
  `questions_json` JSON          NOT NULL                                       COMMENT '题目列表JSON（含跳题逻辑、条件展示）',
  `version`        INT           NOT NULL DEFAULT 1                             COMMENT '版本号（修改后自增）',
  `status`         TINYINT       NOT NULL DEFAULT 1                             COMMENT '状态：0停用 1启用',
  `remark`         VARCHAR(500)  DEFAULT NULL                                   COMMENT '备注',
  `creator`        VARCHAR(64)   DEFAULT ''                                     COMMENT '创建者',
  `create_time`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP             COMMENT '创建时间',
  `updater`        VARCHAR(64)   DEFAULT ''                                     COMMENT '更新者',
  `update_time`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                   ON UPDATE CURRENT_TIMESTAMP                                  COMMENT '更新时间',
  `deleted`        TINYINT       NOT NULL DEFAULT 0                             COMMENT '软删除',
  `tenant_id`      BIGINT        NOT NULL DEFAULT 0                             COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_template_code` (`template_code`, `deleted`),
  INDEX `idx_template_type` (`template_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='健康告知/保障规划问卷模板表（全平台统一问卷引擎，V15架构合并）';


-- -----------------------------------------------------------------------------
-- 7. 产品与问卷关联表  ins_life_product_questionnaire
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_product_questionnaire` (
  `id`                 BIGINT   NOT NULL AUTO_INCREMENT                         COMMENT '主键ID',
  `product_id`         BIGINT   NOT NULL                                        COMMENT '产品ID',
  `questionnaire_id`   BIGINT   NOT NULL                                        COMMENT '问卷模板ID',
  `questionnaire_role` VARCHAR(20) NOT NULL DEFAULT 'MAIN'                      COMMENT '角色：MAIN主问卷/SPECIAL特殊问卷',
  `sort_order`         INT      NOT NULL DEFAULT 0                              COMMENT '排序',
  `creator`            VARCHAR(64) DEFAULT ''                                   COMMENT '创建者',
  `create_time`        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP              COMMENT '创建时间',
  `deleted`            TINYINT  NOT NULL DEFAULT 0                              COMMENT '软删除',
  PRIMARY KEY (`id`),
  INDEX `idx_product_id` (`product_id`),
  INDEX `idx_questionnaire_id` (`questionnaire_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险产品与健康告知问卷关联表';


-- -----------------------------------------------------------------------------
-- 8. 保司工号表  ins_life_insurer_account
--    对应需求：系统管理-保司工号管理（PDF-167）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_insurer_account` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT                      COMMENT '主键ID',
  `agent_id`         BIGINT        NOT NULL                                     COMMENT '业务员ID，关联sys_user.id',
  `agent_name`       VARCHAR(64)   DEFAULT NULL                                 COMMENT '业务员姓名（冗余）',
  `insurer_id`       BIGINT        NOT NULL                                     COMMENT '保险公司ID',
  `insurer_name`     VARCHAR(100)  DEFAULT NULL                                 COMMENT '保险公司名称（冗余）',
  `insurer_account`  VARCHAR(100)  NOT NULL                                     COMMENT '保司工号',
  `account_type`     VARCHAR(20)   DEFAULT 'AGENT'                              COMMENT '工号类型：AGENT代理人/BROKER经纪人',
  `is_default`       TINYINT       NOT NULL DEFAULT 0                           COMMENT '是否默认工号：0否 1是',
  `status`           TINYINT       NOT NULL DEFAULT 1                           COMMENT '状态：0停用 1启用',
  `last_test_time`   DATETIME      DEFAULT NULL                                 COMMENT '最后测试连接时间',
  `last_test_result` VARCHAR(20)   DEFAULT NULL                                 COMMENT '最后测试结果：SUCCESS/FAILED',
  `remark`           VARCHAR(200)  DEFAULT NULL                                 COMMENT '备注',
  `creator`          VARCHAR(64)   DEFAULT ''                                   COMMENT '创建者',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP           COMMENT '创建时间',
  `updater`          VARCHAR(64)   DEFAULT ''                                   COMMENT '更新者',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP                                COMMENT '更新时间',
  `deleted`          TINYINT       NOT NULL DEFAULT 0                           COMMENT '软删除',
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0                           COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_insurer` (`agent_id`, `insurer_id`, `deleted`),
  INDEX `idx_agent_id` (`agent_id`),
  INDEX `idx_insurer_id` (`insurer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险业务员保司工号表（PDF-167）';


-- -----------------------------------------------------------------------------
-- 9. H5后台配置系列表（PDF-165）
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_h5_product_category` (
  `id`            BIGINT        NOT NULL AUTO_INCREMENT                         COMMENT '主键ID',
  `category_name` VARCHAR(100)  NOT NULL                                        COMMENT '分类名称',
  `sort_order`    INT           NOT NULL DEFAULT 99                             COMMENT '显示顺序（越小越靠前，默认99）',
  `status`        TINYINT       NOT NULL DEFAULT 1                              COMMENT '状态：0停用 1启用',
  `creator`       VARCHAR(64)   DEFAULT ''                                      COMMENT '创建者',
  `create_time`   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP              COMMENT '创建时间',
  `updater`       VARCHAR(64)   DEFAULT ''                                      COMMENT '更新者',
  `update_time`   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                  ON UPDATE CURRENT_TIMESTAMP                                   COMMENT '更新时间',
  `deleted`       TINYINT       NOT NULL DEFAULT 0                              COMMENT '软删除',
  `tenant_id`     BIGINT        NOT NULL DEFAULT 0                              COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_sort` (`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险H5产品分类配置表（PDF-165）';

CREATE TABLE `ins_life_h5_online_policy` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `org_id`          BIGINT        NOT NULL                                      COMMENT '适用机构ID',
  `insurer_id`      BIGINT        NOT NULL                                      COMMENT '保险公司ID',
  `category_id`     BIGINT        NOT NULL                                      COMMENT '产品分类ID',
  `product_name`    VARCHAR(100)  NOT NULL                                      COMMENT '产品名称',
  `jump_url`        VARCHAR(1000) NOT NULL                                      COMMENT '跳转链接（保司在线投保URL）',
  `cover_image_url` VARCHAR(500)  DEFAULT NULL                                  COMMENT '封面图片URL（OSS）',
  `sort_order`      INT           NOT NULL DEFAULT 99                           COMMENT '排序',
  `status`          TINYINT       NOT NULL DEFAULT 1                            COMMENT '发布状态：0下架 1已发布',
  `creator`         VARCHAR(64)   DEFAULT ''                                    COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `updater`         VARCHAR(64)   DEFAULT ''                                    COMMENT '更新者',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                 COMMENT '更新时间',
  `deleted`         TINYINT       NOT NULL DEFAULT 0                            COMMENT '软删除',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_org_insurer` (`org_id`, `insurer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险H5在线投保配置表（PDF-165）';

CREATE TABLE `ins_life_h5_product_intro` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT                      COMMENT '主键ID',
  `org_id`           BIGINT        NOT NULL                                     COMMENT '适用机构ID',
  `insurer_id`       BIGINT        NOT NULL                                     COMMENT '保险公司ID',
  `category_id`      BIGINT        NOT NULL                                     COMMENT '产品分类ID',
  `product_name`     VARCHAR(100)  NOT NULL                                     COMMENT '产品名称',
  `selling_points`   VARCHAR(500)  DEFAULT NULL                                 COMMENT '产品卖点描述',
  `main_image_url`   VARCHAR(500)  DEFAULT NULL                                 COMMENT '主图URL（OSS）',
  `detail_image_url` VARCHAR(500)  DEFAULT NULL                                 COMMENT '详情图URL（OSS）',
  `sort_weight`      INT           NOT NULL DEFAULT 0                           COMMENT '排序权重',
  `status`           TINYINT       NOT NULL DEFAULT 1                           COMMENT '发布状态：0下架 1已发布',
  `creator`          VARCHAR(64)   DEFAULT ''                                   COMMENT '创建者',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP           COMMENT '创建时间',
  `updater`          VARCHAR(64)   DEFAULT ''                                   COMMENT '更新者',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP                                COMMENT '更新时间',
  `deleted`          TINYINT       NOT NULL DEFAULT 0                           COMMENT '软删除',
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0                           COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_org_id` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险H5产品介绍配置表（PDF-165）';

CREATE TABLE `ins_life_h5_plan_book` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT                       COMMENT '主键ID',
  `insurer_id`      BIGINT        NOT NULL                                      COMMENT '保险公司ID',
  `insurer_name`    VARCHAR(100)  DEFAULT NULL                                  COMMENT '保险公司名称（冗余）',
  `plan_book_name`  VARCHAR(200)  NOT NULL                                      COMMENT '计划书名称',
  `jump_url`        VARCHAR(1000) DEFAULT NULL                                  COMMENT '跳转链接（与file_url二选一）',
  `file_url`        VARCHAR(500)  DEFAULT NULL                                  COMMENT 'PDF文件URL（OSS，与jump_url二选一）',
  `cover_image_url` VARCHAR(500)  DEFAULT NULL                                  COMMENT '封面图URL',
  `status`          TINYINT       NOT NULL DEFAULT 1                            COMMENT '发布状态：0下架 1已发布',
  `sort_order`      INT           NOT NULL DEFAULT 0                            COMMENT '排序',
  `creator`         VARCHAR(64)   DEFAULT ''                                    COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP            COMMENT '创建时间',
  `updater`         VARCHAR(64)   DEFAULT ''                                    COMMENT '更新者',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP                                 COMMENT '更新时间',
  `deleted`         TINYINT       NOT NULL DEFAULT 0                            COMMENT '软删除',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0                            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_insurer_id` (`insurer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险H5计划书配置表（PDF-165）';

CREATE TABLE `ins_life_h5_content_category` (
  `id`            BIGINT        NOT NULL AUTO_INCREMENT                         COMMENT '主键ID',
  `category_name` VARCHAR(100)  NOT NULL                                        COMMENT '内容分类名称',
  `sort_order`    INT           NOT NULL DEFAULT 99                             COMMENT '显示顺序',
  `status`        TINYINT       NOT NULL DEFAULT 1                              COMMENT '状态：0停用 1启用',
  `creator`       VARCHAR(64)   DEFAULT ''                                      COMMENT '创建者',
  `create_time`   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP              COMMENT '创建时间',
  `deleted`       TINYINT       NOT NULL DEFAULT 0                              COMMENT '软删除',
  `tenant_id`     BIGINT        NOT NULL DEFAULT 0                              COMMENT '租户ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险H5内容分类表（PDF-165）';

CREATE TABLE `ins_life_h5_content` (
  `id`           BIGINT        NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `category_id`  BIGINT        NOT NULL                                         COMMENT '内容分类ID',
  `description`  VARCHAR(500)  NOT NULL                                         COMMENT '内容描述/标题',
  `image_url`    VARCHAR(500)  DEFAULT NULL                                     COMMENT '图片URL',
  -- 内容与跳转链接二选一（PDF-165明确：两者只能填一项）
  `content_type` VARCHAR(20)   NOT NULL DEFAULT 'RICH_TEXT'                    COMMENT '展示类型：RICH_TEXT富文本/JUMP_URL跳转链接',
  `content_body` LONGTEXT      DEFAULT NULL                                     COMMENT '富文本内容（content_type=RICH_TEXT时填写）',
  `jump_url`     VARCHAR(1000) DEFAULT NULL                                     COMMENT '跳转链接（content_type=JUMP_URL时填写）',
  `status`       TINYINT       NOT NULL DEFAULT 1                               COMMENT '发布状态：0下架 1已发布',
  `sort_order`   INT           NOT NULL DEFAULT 0                               COMMENT '排序',
  `creator`      VARCHAR(64)   DEFAULT ''                                       COMMENT '创建者',
  `create_time`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `updater`      VARCHAR(64)   DEFAULT ''                                       COMMENT '更新者',
  `update_time`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                 ON UPDATE CURRENT_TIMESTAMP                                    COMMENT '更新时间',
  `deleted`      TINYINT       NOT NULL DEFAULT 0                               COMMENT '软删除',
  `tenant_id`    BIGINT        NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  INDEX `idx_category_id` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险H5内容管理表（content_body与jump_url二选一，PDF-165）';


-- -----------------------------------------------------------------------------
-- 10. 寿险系统参数配置表  ins_life_sys_config
--     对应需求：系统管理-寿险系统配置（PDF-166）
--     key-value结构，配置值写入后同步清除Redis缓存，支持热更新
-- -----------------------------------------------------------------------------
CREATE TABLE `ins_life_sys_config` (
  `id`           BIGINT        NOT NULL AUTO_INCREMENT                          COMMENT '主键ID',
  `config_key`   VARCHAR(100)  NOT NULL                                         COMMENT '配置键，如renewal.grace_period_days',
  `config_value` VARCHAR(2000) NOT NULL                                         COMMENT '配置值',
  `config_name`  VARCHAR(200)  NOT NULL                                         COMMENT '配置名称（中文说明）',
  `config_group` VARCHAR(50)   DEFAULT NULL                                     COMMENT '分组：RENEWAL续期/CLAIM理赔/POLICY保单/NOTIFY通知',
  `value_type`   VARCHAR(20)   DEFAULT 'STRING'                                 COMMENT '值类型：STRING/INTEGER/DECIMAL/BOOLEAN/JSON',
  `remark`       VARCHAR(500)  DEFAULT NULL                                     COMMENT '备注说明',
  `creator`      VARCHAR(64)   DEFAULT ''                                       COMMENT '创建者',
  `create_time`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP               COMMENT '创建时间',
  `updater`      VARCHAR(64)   DEFAULT ''                                       COMMENT '更新者',
  `update_time`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                 ON UPDATE CURRENT_TIMESTAMP                                    COMMENT '更新时间',
  `deleted`      TINYINT       NOT NULL DEFAULT 0                               COMMENT '软删除',
  `tenant_id`    BIGINT        NOT NULL DEFAULT 0                               COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_config_key` (`config_key`, `tenant_id`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='寿险系统参数配置表（key-value，Redis热更新，PDF-166）';


-- =============================================================================
-- Part 1 表清单（共16张表）
-- ┌─────────────────────────────────────────────┬──────────────────────────┐
-- │ 表名                                        │ 说明                      │
-- ├─────────────────────────────────────────────┼──────────────────────────┤
-- │ ins_insurer_life_ext                        │ 寿险合作保司扩展信息       │
-- │ ins_life_product                            │ 寿险产品主表               │
-- │ ins_life_product_commission                 │ 产品佣金配置               │
-- │ ins_life_product_rate                       │ 产品费率表                 │
-- │ ins_life_product_auth                       │ 产品机构授权               │
-- │ ins_questionnaire_template                  │ 健康告知/规划问卷模板       │
-- │ ins_life_product_questionnaire              │ 产品问卷关联               │
-- │ ins_life_insurer_account                    │ 业务员保司工号             │
-- │ ins_life_h5_product_category               │ H5产品分类                 │
-- │ ins_life_h5_online_policy                  │ H5在线投保配置             │
-- │ ins_life_h5_product_intro                  │ H5产品介绍配置             │
-- │ ins_life_h5_plan_book                      │ H5计划书配置               │
-- │ ins_life_h5_content_category              │ H5内容分类                 │
-- │ ins_life_h5_content                       │ H5内容管理                 │
-- │ ins_life_sys_config                       │ 寿险系统参数配置            │
-- └─────────────────────────────────────────────┴──────────────────────────┘
-- =============================================================================

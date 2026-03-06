-- =============================================================================
-- 保险产品中台 - intermediary-module-ins-product
-- Schema: db_ins_product
-- Part 3: 寿险产品专属配置（与 ins_product_info 1:1 或 1:N 关联）
-- =============================================================================

USE `db_ins_product`;

-- -----------------------------------------------------------------------------
-- 13. 寿险产品扩展信息表 ins_product_life_ext
-- 与 ins_product_info 1:1 关联，存储寿险专属字段
-- 对应 PDF-170 寿险产品管理 - Tab1 基本信息
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_life_ext`;
CREATE TABLE `ins_product_life_ext` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '关联产品ID（ins_product_info.id）',
    `life_category`         VARCHAR(50)     NOT NULL COMMENT '寿险险种枚举：LIFE-寿险/CRITICAL_ILLNESS-重疾/MEDICAL-医疗/ACCIDENT-意外/ANNUITY-年金/UNIVERSAL-万能险',
    `product_code_insurer`  VARCHAR(200)    NOT NULL COMMENT '保司分配的产品代码（同保司内唯一）',
    `coverage_period_type`  TINYINT         NOT NULL DEFAULT 1 COMMENT '保障期限类型：1-定期 2-终身',
    `coverage_period_year`  INT             DEFAULT NULL COMMENT '保障期限（年），coverage_period_type=1时必填',
    `payment_modes`         VARCHAR(200)    NOT NULL COMMENT '支持的缴费方式（逗号分隔：LUMP_SUM,ANNUAL,HALF_YEAR,QUARTER,MONTH）',
    `min_sum_insured`       BIGINT          DEFAULT NULL COMMENT '最低保额（元）',
    `max_sum_insured`       BIGINT          DEFAULT NULL COMMENT '最高保额（元）',
    `waiting_period_days`   INT             DEFAULT 0 COMMENT '等待期（天），0=无等待期',
    `renewal_commission_rule` VARCHAR(500)  DEFAULT NULL COMMENT '续年佣金规则说明（文字描述）',
    `category_icon`         VARCHAR(500)    DEFAULT NULL COMMENT '险种图标（C端展示用，OSS URL）',
    `is_hot`                TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否标记热销：0-否 1-是',
    `health_notice_required` TINYINT(1)     NOT NULL DEFAULT 1 COMMENT '是否需要健康告知：0-否 1-是',
    `profession_limit`      VARCHAR(500)    DEFAULT NULL COMMENT '职业限制说明',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_product_id` (`product_id`, `deleted`),
    KEY `idx_life_category` (`life_category`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险产品扩展信息表';


-- -----------------------------------------------------------------------------
-- 14. 寿险产品费率表 ins_product_life_rate
-- 按年龄段/性别/保障期/缴费期组合的费率数据，支持EasyExcel批量导入
-- 对应 PDF-170 Tab4 费率表
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_life_rate`;
CREATE TABLE `ins_product_life_rate` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '关联产品ID（ins_product_info.id）',
    `age_min`               INT             NOT NULL COMMENT '最小投保年龄（岁，含）',
    `age_max`               INT             NOT NULL COMMENT '最大投保年龄（岁，含）',
    `gender`                TINYINT         NOT NULL DEFAULT 0 COMMENT '性别：0-不限 1-男 2-女',
    `coverage_term`         INT             DEFAULT NULL COMMENT '保障期（年），NULL=终身',
    `payment_term`          INT             DEFAULT NULL COMMENT '缴费期（年），NULL=趸缴',
    `payment_mode`          VARCHAR(50)     DEFAULT NULL COMMENT '缴费方式：LUMP_SUM/ANNUAL/HALF_YEAR/QUARTER/MONTH',
    `premium_per_unit`      DECIMAL(12,4)   NOT NULL COMMENT '每万元保额对应保费（元/万元保额/年，精确到0.0001）',
    `rate_unit`             VARCHAR(50)     NOT NULL DEFAULT '元/万元保额' COMMENT '费率单位说明',
    `batch_no`              VARCHAR(100)    DEFAULT NULL COMMENT '导入批次号（每次导入生成，用于追溯）',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删（每次导入先逻辑删除旧数据）',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    KEY `idx_product_age_gender` (`product_id`, `age_min`, `age_max`, `gender`, `deleted`),
    KEY `idx_product_payment` (`product_id`, `payment_mode`, `payment_term`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险产品费率表';


-- -----------------------------------------------------------------------------
-- 15. 健康告知问卷模板表 ins_product_questionnaire_template
-- 维护健康告知问卷模板，一个产品可绑定多份问卷
-- 对应 PDF-170 Tab3 健康告知问卷
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_questionnaire_template`;
CREATE TABLE `ins_product_questionnaire_template` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `template_name`         VARCHAR(200)    NOT NULL COMMENT '问卷模板名称',
    `template_type`         TINYINT         NOT NULL DEFAULT 1 COMMENT '问卷类型：1-主问卷 2-特殊问卷',
    `questions`             JSON            NOT NULL COMMENT '问题列表（JSON数组，含题目/选项/是否必答/跳转逻辑）',
    `version`               VARCHAR(20)     DEFAULT '1.0' COMMENT '版本号',
    `status`                TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    `remark`                VARCHAR(500)    DEFAULT NULL COMMENT '备注',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    KEY `idx_tenant_status` (`tenant_id`, `status`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='健康告知问卷模板表';


-- -----------------------------------------------------------------------------
-- 16. 产品-问卷绑定表 ins_product_questionnaire_bind
-- 一个寿险产品可绑定多份健康告知问卷（主问卷+特殊问卷）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_questionnaire_bind`;
CREATE TABLE `ins_product_questionnaire_bind` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '关联产品ID',
    `template_id`           BIGINT          NOT NULL COMMENT '关联问卷模板ID',
    `bind_type`             TINYINT         NOT NULL DEFAULT 1 COMMENT '绑定类型：1-主问卷 2-特殊附加问卷',
    `sort`                  INT             NOT NULL DEFAULT 0 COMMENT '展示顺序（主问卷在前）',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-绑定中 1-已解绑',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_product_template` (`product_id`, `template_id`, `deleted`),
    KEY `idx_product_id` (`product_id`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品-健康告知问卷绑定表';


-- -----------------------------------------------------------------------------
-- 17. 寿险产品机构授权表 ins_product_life_org_auth
-- 寿险产品专用授权（与通用 ins_product_org_auth 分开，便于单独管理授权时间）
-- 对应 PDF-170 10.3 产品授权到机构
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_life_org_auth`;
CREATE TABLE `ins_product_life_org_auth` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '寿险产品ID',
    `org_id`                BIGINT          NOT NULL COMMENT '授权机构ID',
    `org_name`              VARCHAR(200)    DEFAULT NULL COMMENT '机构名称（冗余）',
    `auth_time`             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '授权时间',
    `expire_time`           DATETIME        DEFAULT NULL COMMENT '授权截止时间（NULL=永久有效）',
    `operator_id`           BIGINT          NOT NULL COMMENT '操作人ID',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-有效 1-已取消',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_product_org` (`product_id`, `org_id`, `deleted`),
    KEY `idx_org_product` (`org_id`, `product_id`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险产品机构授权表';


-- -----------------------------------------------------------------------------
-- 18. 寿险计划书申请表 ins_product_life_proposal
-- C端/业务员端申请免费计划书，异步生成PDF
-- 对应 PDF-168 阶段8 C端 2.3 寿险免费计划书
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_life_proposal`;
CREATE TABLE `ins_product_life_proposal` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `proposal_no`           VARCHAR(50)     NOT NULL COMMENT '计划书编号（唯一，如PS202401010001）',
    `product_id`            BIGINT          NOT NULL COMMENT '关联产品ID',
    `product_name`          VARCHAR(200)    NOT NULL COMMENT '产品名称（冗余）',
    `applicant_name`        VARCHAR(50)     NOT NULL COMMENT '申请人姓名',
    `applicant_phone`       VARCHAR(20)     NOT NULL COMMENT '申请人手机号',
    `insured_gender`        TINYINT         NOT NULL DEFAULT 1 COMMENT '被保人性别：1-男 2-女',
    `insured_age`           INT             NOT NULL COMMENT '被保人年龄',
    `insured_birthday`      DATE            DEFAULT NULL COMMENT '被保人生日',
    `sum_insured`           BIGINT          DEFAULT NULL COMMENT '保额（元）',
    `payment_mode`          VARCHAR(50)     DEFAULT NULL COMMENT '缴费方式（ANNUAL/MONTH等）',
    `payment_term`          INT             DEFAULT NULL COMMENT '缴费期（年）',
    `coverage_term`         INT             DEFAULT NULL COMMENT '保障期（年，NULL=终身）',
    `agent_id`              BIGINT          DEFAULT NULL COMMENT '业务员ID（业务员发起时必填）',
    `member_id`             BIGINT          DEFAULT NULL COMMENT 'C端会员ID（C端发起时填写）',
    `source`                TINYINT         NOT NULL DEFAULT 1 COMMENT '来源：1-C端小程序 2-业务员App',
    `status`                TINYINT         NOT NULL DEFAULT 0 COMMENT '状态：0-待生成 1-生成中 2-已生成 3-生成失败',
    `pdf_url`               VARCHAR(500)    DEFAULT NULL COMMENT '生成的PDF文件URL（OSS）',
    `send_email`            VARCHAR(200)    DEFAULT NULL COMMENT '计划书发送邮箱（可选）',
    `email_sent`            TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否已发送邮件：0-否 1-是',
    `fail_reason`           VARCHAR(500)    DEFAULT NULL COMMENT '生成失败原因',
    `expire_time`           DATETIME        DEFAULT NULL COMMENT '计划书有效期（默认30天）',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_proposal_no` (`proposal_no`),
    KEY `idx_product_status` (`product_id`, `status`, `deleted`),
    KEY `idx_agent_create` (`agent_id`, `create_time`),
    KEY `idx_member_create` (`member_id`, `create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险计划书申请记录表';

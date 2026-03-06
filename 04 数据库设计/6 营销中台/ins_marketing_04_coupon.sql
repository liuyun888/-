-- =============================================================================
-- 保险中介平台 - 营销中台数据库表结构
-- 模块：intermediary-module-ins-marketing
-- Schema：db_ins_marketing
-- 文件：04 - 优惠券管理（优惠券模板 / 用户券 / 兑换码 / 发放任务）
-- 表前缀：ins_mkt_coupon_
-- =============================================================================

USE `db_ins_marketing`;

-- -------------------------------------------------------------------
-- 1. 优惠券模板
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_coupon`;
CREATE TABLE `ins_mkt_coupon` (
  `id`              bigint         NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `coupon_no`       varchar(32)    NOT NULL                  COMMENT '优惠券编号(唯一)',
  `name`            varchar(100)   NOT NULL                  COMMENT '优惠券名称',
  `type`            tinyint        NOT NULL                  COMMENT '优惠券类型:1-满减券 2-折扣券 3-兑换券 4-立减券',
  `discount_type`   tinyint        NOT NULL DEFAULT 1        COMMENT '优惠方式:1-金额 2-折扣',
  `discount_value`  decimal(10,2)  NOT NULL                  COMMENT '优惠值(满减金额/折扣率如85表示85折)',
  `condition_type`  tinyint        NOT NULL DEFAULT 1        COMMENT '使用门槛:1-无门槛 2-满金额',
  `condition_value` decimal(10,2)  DEFAULT NULL              COMMENT '门槛金额(condition_type=2时有效)',
  `max_discount`    decimal(10,2)  DEFAULT NULL              COMMENT '最高优惠金额(折扣券限制用)',
  `total_count`     int            NOT NULL DEFAULT -1       COMMENT '发行总量,-1表示不限',
  `receive_count`   int            NOT NULL DEFAULT 0        COMMENT '已领取数量',
  `use_count`       int            NOT NULL DEFAULT 0        COMMENT '已使用数量',
  `product_scope`   tinyint        NOT NULL DEFAULT 1        COMMENT '产品范围:1-全部 2-指定分类 3-指定产品',
  `product_config`  json           DEFAULT NULL              COMMENT '产品范围配置JSON',
  `user_scope`      tinyint        NOT NULL DEFAULT 1        COMMENT '用户范围:1-全部 2-新用户 3-指定用户',
  `user_config`     json           DEFAULT NULL              COMMENT '用户范围配置JSON',
  `receive_type`    tinyint        NOT NULL DEFAULT 1        COMMENT '领取方式:1-手动领取 2-自动发放 3-活动发放 4-兑换码',
  `receive_limit`   int            NOT NULL DEFAULT 1        COMMENT '每人限领次数,-1不限',
  `use_limit`       int            NOT NULL DEFAULT 1        COMMENT '每人限使用次数,-1不限',
  `valid_type`      tinyint        NOT NULL DEFAULT 1        COMMENT '有效期类型:1-固定日期 2-领取后N天',
  `valid_days`      int            DEFAULT NULL              COMMENT '领取后有效天数(valid_type=2时有效)',
  `start_time`      datetime       DEFAULT NULL              COMMENT '券有效开始时间(valid_type=1时有效)',
  `end_time`        datetime       DEFAULT NULL              COMMENT '券有效结束时间(valid_type=1时有效)',
  `is_stackable`    tinyint        NOT NULL DEFAULT 0        COMMENT '是否可与其他优惠叠加:0-否 1-是',
  `description`     text           DEFAULT NULL              COMMENT '使用说明(最长500字符)',
  `status`          tinyint        NOT NULL DEFAULT 0        COMMENT '状态:0-未开始 1-进行中 2-已结束 3-已下架',
  `creator`         varchar(64)    NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime       NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         varchar(64)    NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`     datetime       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint        NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`       bigint         NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_coupon_no` (`coupon_no`),
  KEY `idx_status_del` (`status`, `deleted`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='优惠券模板';

-- -------------------------------------------------------------------
-- 2. 用户优惠券（用户领取记录）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_coupon_user`;
CREATE TABLE `ins_mkt_coupon_user` (
  `id`               bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `coupon_id`        bigint        NOT NULL                  COMMENT '优惠券模板ID',
  `user_id`          bigint        NOT NULL                  COMMENT '用户ID',
  `coupon_code`      varchar(32)   NOT NULL                  COMMENT '用户券码(唯一)',
  `receive_type`     tinyint       NOT NULL DEFAULT 1        COMMENT '领取方式:1-手动 2-自动 3-活动 4-兑换码',
  `receive_time`     datetime      NOT NULL                  COMMENT '领取时间',
  `valid_start_time` datetime      NOT NULL                  COMMENT '使用有效期开始',
  `valid_end_time`   datetime      NOT NULL                  COMMENT '使用有效期结束',
  `status`           tinyint       NOT NULL DEFAULT 1        COMMENT '状态:1-未使用 2-已使用 3-已过期 4-已锁定',
  `use_time`         datetime      DEFAULT NULL              COMMENT '使用时间',
  `order_id`         bigint        DEFAULT NULL              COMMENT '使用时关联的订单ID',
  `lock_time`        datetime      DEFAULT NULL              COMMENT '锁定时间(下单时锁定,15分钟未支付自动解锁)',
  `activity_id`      bigint        DEFAULT NULL              COMMENT '来源活动ID(活动发放时记录)',
  `create_time`      datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`        bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_coupon_code` (`coupon_code`),
  KEY `idx_user_coupon_status` (`user_id`, `coupon_id`, `status`),
  KEY `idx_coupon_status` (`coupon_id`, `status`),
  KEY `idx_valid_end_time` (`valid_end_time`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户优惠券(领取记录)';

-- -------------------------------------------------------------------
-- 3. 优惠券兑换码（兑换码批量生成）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_coupon_code`;
CREATE TABLE `ins_mkt_coupon_code` (
  `id`          bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `coupon_id`   bigint       NOT NULL                   COMMENT '关联优惠券模板ID',
  `code`        varchar(32)  NOT NULL                   COMMENT '兑换码(唯一)',
  `batch_no`    varchar(32)  DEFAULT NULL               COMMENT '批次号(批量生成时标识)',
  `status`      tinyint      NOT NULL DEFAULT 0         COMMENT '状态:0-未使用 1-已使用',
  `user_id`     bigint       DEFAULT NULL               COMMENT '使用者用户ID',
  `use_time`    datetime     DEFAULT NULL               COMMENT '兑换时间',
  `create_time` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`   bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`),
  KEY `idx_coupon_status` (`coupon_id`, `status`),
  KEY `idx_batch_no` (`batch_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='优惠券兑换码';

-- -------------------------------------------------------------------
-- 4. 优惠券自动发放规则（事件触发自动发券）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_coupon_auto_rule`;
CREATE TABLE `ins_mkt_coupon_auto_rule` (
  `id`           bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `coupon_id`    bigint       NOT NULL                   COMMENT '关联优惠券模板ID',
  `event_type`   varchar(50)  NOT NULL                   COMMENT '触发事件:USER_REGISTER/ORDER_COMPLETE/USER_BIRTHDAY/ORDER_REFUND',
  `condition`    json         DEFAULT NULL               COMMENT '触发条件配置JSON(如:首次下单/满足金额等)',
  `status`       tinyint      NOT NULL DEFAULT 1         COMMENT '状态:0-禁用 1-启用',
  `creator`      varchar(64)  NOT NULL DEFAULT ''        COMMENT '创建者',
  `create_time`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`      varchar(64)  NOT NULL DEFAULT ''        COMMENT '更新者',
  `update_time`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`      tinyint      NOT NULL DEFAULT 0         COMMENT '是否删除:0-否 1-是',
  `tenant_id`    bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_event_status` (`event_type`, `status`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='优惠券自动发放规则';

-- -------------------------------------------------------------------
-- 5. 优惠券批量发放任务（手动批量发放异步任务记录）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_coupon_send_task`;
CREATE TABLE `ins_mkt_coupon_send_task` (
  `id`             bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `coupon_id`      bigint        NOT NULL                  COMMENT '优惠券模板ID',
  `send_type`      tinyint       NOT NULL DEFAULT 1        COMMENT '发放方式:1-指定用户ID 2-上传Excel 3-用户标签',
  `send_config`    json          DEFAULT NULL              COMMENT '发放配置JSON(用户ID列表/标签等)',
  `total_count`    int           NOT NULL DEFAULT 0        COMMENT '计划发放人数',
  `success_count`  int           NOT NULL DEFAULT 0        COMMENT '发放成功人数',
  `fail_count`     int           NOT NULL DEFAULT 0        COMMENT '发放失败人数',
  `fail_detail`    text          DEFAULT NULL              COMMENT '失败明细JSON',
  `status`         tinyint       NOT NULL DEFAULT 0        COMMENT '任务状态:0-待处理 1-进行中 2-已完成 3-失败',
  `remark`         varchar(200)  DEFAULT NULL              COMMENT '发放原因',
  `creator`        varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者(发放人)',
  `create_time`    datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`    datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `tenant_id`      bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_coupon_status` (`coupon_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='优惠券批量发放任务';

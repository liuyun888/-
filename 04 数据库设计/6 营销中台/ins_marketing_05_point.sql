-- =============================================================================
-- 保险中介平台 - 营销中台数据库表结构
-- 模块：intermediary-module-ins-marketing
-- Schema：db_ins_marketing
-- 文件：05 - 积分管理（积分规则 / 用户账户 / 积分明细 / 积分等级 / 积分商城 / 兑换记录）
-- 表前缀：ins_mkt_point_
-- =============================================================================

USE `db_ins_marketing`;

-- -------------------------------------------------------------------
-- 1. 积分规则配置
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_point_rule`;
CREATE TABLE `ins_mkt_point_rule` (
  `id`              bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `name`            varchar(100)  NOT NULL                  COMMENT '规则名称(如:每日签到奖励)',
  `code`            varchar(50)   NOT NULL                  COMMENT '规则编码(唯一,字母数字,如SIGN_IN_DAILY,一旦保存不可修改)',
  `rule_type`       tinyint       NOT NULL DEFAULT 1        COMMENT '规则类型:1-获取规则 2-消费规则',
  `event_type`      tinyint       NOT NULL                  COMMENT '事件类型:1-注册 2-签到 3-消费 4-分享 5-评价 6-积分兑换 7-积分过期',
  `point_value`     int           NOT NULL                  COMMENT '积分值(获取规则为正,消费规则为负)',
  `limit_type`      tinyint       NOT NULL DEFAULT 1        COMMENT '限制类型:1-不限 2-每天 3-每周 4-每月 5-总次数',
  `limit_count`     int           DEFAULT NULL              COMMENT '限制次数(limit_type!=1时必填)',
  `valid_days`      int           NOT NULL DEFAULT -1       COMMENT '积分有效天数,-1表示永久有效',
  `condition_config` json         DEFAULT NULL              COMMENT '条件配置JSON(消费比例/连续签到等)',
  `description`     varchar(500)  DEFAULT NULL              COMMENT '规则说明(展示给用户)',
  `sort_order`      int           NOT NULL DEFAULT 0        COMMENT '排序号',
  `status`          tinyint       NOT NULL DEFAULT 1        COMMENT '状态:0-禁用 1-启用',
  `creator`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`       bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code_tenant` (`code`, `tenant_id`),
  KEY `idx_event_status` (`event_type`, `status`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='积分规则配置';

-- -------------------------------------------------------------------
-- 2. 用户积分账户
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_point_account`;
CREATE TABLE `ins_mkt_point_account` (
  `id`               bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `user_id`          bigint       NOT NULL                   COMMENT '用户ID(唯一)',
  `total_point`      int          NOT NULL DEFAULT 0         COMMENT '累计获得积分(历史总计,只增不减,用于等级计算)',
  `available_point`  int          NOT NULL DEFAULT 0         COMMENT '可用积分',
  `used_point`       int          NOT NULL DEFAULT 0         COMMENT '已使用积分',
  `frozen_point`     int          NOT NULL DEFAULT 0         COMMENT '冻结积分(退款/风控)',
  `expire_point`     int          NOT NULL DEFAULT 0         COMMENT '已过期积分',
  `level`            tinyint      NOT NULL DEFAULT 1         COMMENT '积分等级:1-普通 2-银卡 3-金卡 4-钻石',
  `level_update_time` datetime    DEFAULT NULL               COMMENT '等级最后更新时间',
  `create_time`      datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`      datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `tenant_id`        bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_id_tenant` (`user_id`, `tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户积分账户';

-- -------------------------------------------------------------------
-- 3. 积分变动明细
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_point_record`;
CREATE TABLE `ins_mkt_point_record` (
  `id`               bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `user_id`          bigint        NOT NULL                  COMMENT '用户ID',
  `rule_id`          bigint        DEFAULT NULL              COMMENT '积分规则ID(手动发放时为NULL)',
  `rule_code`        varchar(50)   DEFAULT NULL              COMMENT '规则编码快照',
  `change_type`      tinyint       NOT NULL                  COMMENT '变动类型:1-增加 2-减少 3-冻结 4-解冻 5-过期',
  `change_point`     int           NOT NULL                  COMMENT '变动积分(增加为正,减少为负)',
  `before_point`     int           NOT NULL                  COMMENT '变动前可用积分',
  `after_point`      int           NOT NULL                  COMMENT '变动后可用积分',
  `event_type`       tinyint       NOT NULL                  COMMENT '事件类型:1-注册 2-签到 3-消费 4-分享 5-评价 6-兑换 7-过期 8-手动调整',
  `biz_id`           bigint        DEFAULT NULL              COMMENT '业务ID(订单ID/活动ID等)',
  `biz_type`         varchar(50)   DEFAULT NULL              COMMENT '业务类型(ORDER/ACTIVITY/MANUAL等)',
  `valid_start_time` datetime      DEFAULT NULL              COMMENT '积分生效时间',
  `valid_end_time`   datetime      DEFAULT NULL              COMMENT '积分失效时间',
  `status`           tinyint       NOT NULL DEFAULT 1        COMMENT '状态:1-有效 2-已使用 3-已过期 4-已冻结',
  `remark`           varchar(500)  DEFAULT NULL              COMMENT '备注(手动调整时记录原因)',
  `create_time`      datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`        bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_user_status` (`user_id`, `status`),
  KEY `idx_valid_end` (`valid_end_time`, `status`),
  KEY `idx_biz` (`biz_type`, `biz_id`),
  KEY `idx_event_type` (`event_type`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='积分变动明细';

-- -------------------------------------------------------------------
-- 4. 积分等级配置（可动态调整等级阈值）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_point_level_config`;
CREATE TABLE `ins_mkt_point_level_config` (
  `id`              bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `level`           tinyint       NOT NULL                  COMMENT '等级值',
  `level_name`      varchar(50)   NOT NULL                  COMMENT '等级名称(如:金卡会员)',
  `level_icon`      varchar(200)  DEFAULT NULL              COMMENT '等级图标URL',
  `min_point`       int           NOT NULL DEFAULT 0        COMMENT '积分范围下限(包含)',
  `max_point`       int           NOT NULL DEFAULT -1       COMMENT '积分范围上限,-1表示无上限',
  `point_ratio`     decimal(4,2)  NOT NULL DEFAULT 1.00     COMMENT '积分获取倍率(如1.5表示1.5倍)',
  `benefits`        json          DEFAULT NULL              COMMENT '等级权益描述JSON数组',
  `sort_order`      int           NOT NULL DEFAULT 0        COMMENT '排序号',
  `status`          tinyint       NOT NULL DEFAULT 1        COMMENT '状态:0-禁用 1-启用',
  `creator`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `tenant_id`       bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_level_tenant` (`level`, `tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='积分等级配置';

-- 预置等级数据
INSERT INTO `ins_mkt_point_level_config` (`level`, `level_name`, `min_point`, `max_point`, `point_ratio`, `benefits`, `sort_order`, `tenant_id`)
VALUES 
(1, '普通会员',  0,     999,    1.00, '["基础积分获取倍率x1"]', 1, 0),
(2, '银卡会员',  1000,  4999,   1.20, '["积分获取x1.2","专属优惠券"]', 2, 0),
(3, '金卡会员',  5000,  19999,  1.50, '["积分获取x1.5","优先客服","生日礼包"]', 3, 0),
(4, '钻石会员',  20000, -1,     2.00, '["积分获取x2","专属客服","年度大礼包"]', 4, 0);

-- -------------------------------------------------------------------
-- 5. 积分商城兑换品
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_point_exchange`;
CREATE TABLE `ins_mkt_point_exchange` (
  `id`             bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `name`           varchar(100)  NOT NULL                  COMMENT '兑换品名称',
  `type`           tinyint       NOT NULL DEFAULT 1        COMMENT '类型:1-实物 2-优惠券 3-话费 4-现金红包',
  `image`          varchar(500)  NOT NULL                  COMMENT '兑换品图片URL',
  `point_cost`     int           NOT NULL                  COMMENT '所需积分(正整数)',
  `total_stock`    int           NOT NULL DEFAULT -1       COMMENT '总库存,-1不限(虚拟商品)',
  `remain_stock`   int           NOT NULL DEFAULT -1       COMMENT '剩余库存',
  `exchange_count` int           NOT NULL DEFAULT 0        COMMENT '已兑换次数',
  `limit_count`    int           NOT NULL DEFAULT -1       COMMENT '每人限兑次数,-1不限',
  `extra_config`   json          DEFAULT NULL              COMMENT '额外配置JSON:实物{weight,needAddress},优惠券{couponId},话费{amount},现金{amount}',
  `sort_order`     int           NOT NULL DEFAULT 0        COMMENT '排序号',
  `status`         tinyint       NOT NULL DEFAULT 0        COMMENT '状态:0-下架 1-上架',
  `start_time`     datetime      DEFAULT NULL              COMMENT '上架时间,NULL表示立即上架',
  `end_time`       datetime      DEFAULT NULL              COMMENT '下架时间,NULL表示永不下架',
  `description`    text          DEFAULT NULL              COMMENT '兑换说明',
  `creator`        varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`    datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`        varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`    datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`        tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`      bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_status_del` (`status`, `deleted`),
  KEY `idx_sort_order` (`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='积分商城兑换品';

-- -------------------------------------------------------------------
-- 6. 积分兑换记录
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_point_exchange_record`;
CREATE TABLE `ins_mkt_point_exchange_record` (
  `id`               bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `exchange_id`      bigint        NOT NULL                  COMMENT '兑换品ID',
  `user_id`          bigint        NOT NULL                  COMMENT '用户ID',
  `point_cost`       int           NOT NULL                  COMMENT '消耗积分',
  `quantity`         int           NOT NULL DEFAULT 1        COMMENT '兑换数量',
  `status`           tinyint       NOT NULL DEFAULT 1        COMMENT '状态:1-待处理/待发货 2-已发货 3-已完成 4-已取消',
  `address_id`       bigint        DEFAULT NULL              COMMENT '收货地址ID(实物兑换必填)',
  `address_snapshot` json          DEFAULT NULL              COMMENT '收货地址快照JSON(防地址修改)',
  `express_company`  varchar(50)   DEFAULT NULL              COMMENT '快递公司',
  `express_no`       varchar(50)   DEFAULT NULL              COMMENT '快递单号',
  `ship_time`        datetime      DEFAULT NULL              COMMENT '发货时间',
  `confirm_time`     datetime      DEFAULT NULL              COMMENT '确认收货时间',
  `auto_confirm_time` datetime     DEFAULT NULL              COMMENT '自动确认时间(发货后7天)',
  `remark`           varchar(500)  DEFAULT NULL              COMMENT '备注',
  `create_time`      datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`      datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `tenant_id`        bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_user_status` (`user_id`, `status`),
  KEY `idx_exchange_status` (`exchange_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='积分兑换记录';

-- -------------------------------------------------------------------
-- 7. 积分批量发放任务
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_point_send_task`;
CREATE TABLE `ins_mkt_point_send_task` (
  `id`             bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `point_value`    int           NOT NULL                  COMMENT '每人发放积分数量',
  `valid_days`     int           NOT NULL DEFAULT -1       COMMENT '积分有效天数,-1永久有效',
  `send_type`      tinyint       NOT NULL DEFAULT 1        COMMENT '发放方式:1-指定用户ID 2-上传Excel',
  `user_ids`       text          DEFAULT NULL              COMMENT '用户ID列表(逗号分隔,send_type=1时)',
  `file_url`       varchar(500)  DEFAULT NULL              COMMENT 'Excel文件URL(send_type=2时)',
  `total_count`    int           NOT NULL DEFAULT 0        COMMENT '计划发放人数',
  `success_count`  int           NOT NULL DEFAULT 0        COMMENT '发放成功人数',
  `fail_count`     int           NOT NULL DEFAULT 0        COMMENT '发放失败人数',
  `status`         tinyint       NOT NULL DEFAULT 0        COMMENT '状态:0-待处理 1-进行中 2-已完成 3-失败',
  `remark`         varchar(200)  NOT NULL                  COMMENT '发放原因(必填,最长100字符)',
  `creator`        varchar(64)   NOT NULL DEFAULT ''       COMMENT '操作人',
  `create_time`    datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`    datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `tenant_id`      bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='积分批量发放任务';

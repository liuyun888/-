-- =============================================================================
-- 保险中介平台 - 营销中台数据库表结构
-- 模块：intermediary-module-ins-marketing
-- Schema：db_ins_marketing
-- 文件：07 - 数据统计（平台访问统计 / 销售统计 / 营销统计汇总）
-- 表前缀：ins_mkt_stat_
-- =============================================================================

USE `db_ins_marketing`;

-- -------------------------------------------------------------------
-- 1. 平台访问统计（日粒度，T+1汇总）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_stat_visit_daily`;
CREATE TABLE `ins_mkt_stat_visit_daily` (
  `id`              bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `stat_date`       date         NOT NULL                   COMMENT '统计日期',
  `pv`              bigint       NOT NULL DEFAULT 0         COMMENT '页面浏览量(PV)',
  `uv`              int          NOT NULL DEFAULT 0         COMMENT '独立访客数(UV)',
  `new_user_count`  int          NOT NULL DEFAULT 0         COMMENT '新增注册用户数',
  `active_user`     int          NOT NULL DEFAULT 0         COMMENT '活跃用户数(有操作行为)',
  `platform`        varchar(20)  NOT NULL DEFAULT 'all'     COMMENT '平台:all/pc/h5/miniprogram/app',
  `create_time`     datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`       bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_date_platform_tenant` (`stat_date`, `platform`, `tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='平台访问日统计';

-- -------------------------------------------------------------------
-- 2. 热门页面排行（日粒度）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_stat_page_rank`;
CREATE TABLE `ins_mkt_stat_page_rank` (
  `id`         bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `stat_date`  date         NOT NULL                   COMMENT '统计日期',
  `page_path`  varchar(200) NOT NULL                   COMMENT '页面路径',
  `page_name`  varchar(100) DEFAULT NULL               COMMENT '页面名称',
  `pv`         bigint       NOT NULL DEFAULT 0         COMMENT 'PV',
  `uv`         int          NOT NULL DEFAULT 0         COMMENT 'UV',
  `avg_stay`   int          NOT NULL DEFAULT 0         COMMENT '平均停留时长(秒)',
  `bounce_rate` decimal(5,2) NOT NULL DEFAULT 0.00     COMMENT '跳出率(%)',
  `create_time` datetime    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`  bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_stat_date_tenant` (`stat_date`, `tenant_id`),
  KEY `idx_pv_desc` (`stat_date`, `pv`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='热门页面排行日统计';

-- -------------------------------------------------------------------
-- 3. 渠道来源统计（日粒度）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_stat_channel_daily`;
CREATE TABLE `ins_mkt_stat_channel_daily` (
  `id`           bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `stat_date`    date         NOT NULL                   COMMENT '统计日期',
  `channel`      varchar(50)  NOT NULL                   COMMENT '渠道:direct/share/push/search',
  `visit_count`  int          NOT NULL DEFAULT 0         COMMENT '访问次数',
  `user_count`   int          NOT NULL DEFAULT 0         COMMENT '用户数',
  `order_count`  int          NOT NULL DEFAULT 0         COMMENT '产生订单数',
  `order_amount` decimal(14,2) NOT NULL DEFAULT 0.00    COMMENT '产生订单金额',
  `create_time`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`    bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_date_channel_tenant` (`stat_date`, `channel`, `tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='渠道来源日统计';

-- -------------------------------------------------------------------
-- 4. 销售统计（日粒度，T+1汇总）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_stat_sale_daily`;
CREATE TABLE `ins_mkt_stat_sale_daily` (
  `id`              bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `stat_date`       date         NOT NULL                   COMMENT '统计日期',
  `order_count`     int          NOT NULL DEFAULT 0         COMMENT '订单数',
  `order_amount`    decimal(14,2) NOT NULL DEFAULT 0.00    COMMENT '订单金额',
  `pay_count`       int          NOT NULL DEFAULT 0         COMMENT '支付订单数',
  `pay_amount`      decimal(14,2) NOT NULL DEFAULT 0.00    COMMENT '支付金额(保费)',
  `refund_count`    int          NOT NULL DEFAULT 0         COMMENT '退款订单数',
  `refund_amount`   decimal(14,2) NOT NULL DEFAULT 0.00    COMMENT '退款金额',
  `ins_type`        varchar(20)  NOT NULL DEFAULT 'all'     COMMENT '险种:all/car/non_car/life',
  `create_time`     datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`       bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_date_ins_type_tenant` (`stat_date`, `ins_type`, `tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='销售日统计';

-- -------------------------------------------------------------------
-- 5. 营销效果统计汇总（活动/优惠券/积分 T+1日粒度）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_stat_marketing_daily`;
CREATE TABLE `ins_mkt_stat_marketing_daily` (
  `id`                  bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `stat_date`           date         NOT NULL                   COMMENT '统计日期',
  `coupon_send_count`   int          NOT NULL DEFAULT 0         COMMENT '当日发放优惠券数',
  `coupon_use_count`    int          NOT NULL DEFAULT 0         COMMENT '当日使用优惠券数',
  `coupon_discount`     decimal(14,2) NOT NULL DEFAULT 0.00    COMMENT '当日优惠券抵扣金额',
  `point_add`           bigint       NOT NULL DEFAULT 0         COMMENT '当日新增积分',
  `point_use`           bigint       NOT NULL DEFAULT 0         COMMENT '当日消耗积分',
  `point_expire`        bigint       NOT NULL DEFAULT 0         COMMENT '当日过期积分',
  `activity_join`       int          NOT NULL DEFAULT 0         COMMENT '当日活动参与次数',
  `activity_order`      int          NOT NULL DEFAULT 0         COMMENT '当日活动带来订单数',
  `activity_amount`     decimal(14,2) NOT NULL DEFAULT 0.00    COMMENT '当日活动带来订单金额',
  `create_time`         datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`           bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_date_tenant` (`stat_date`, `tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='营销效果日统计';

-- -------------------------------------------------------------------
-- 6. 报表导出任务（异步生成）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_stat_export_task`;
CREATE TABLE `ins_mkt_stat_export_task` (
  `id`           bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `report_type`  varchar(50)   NOT NULL                  COMMENT '报表类型:visit/sale/activity/coupon/point',
  `params`       json          DEFAULT NULL              COMMENT '查询参数JSON(时间范围/筛选条件等)',
  `file_url`     varchar(500)  DEFAULT NULL              COMMENT '生成文件URL(完成后填写)',
  `status`       tinyint       NOT NULL DEFAULT 0        COMMENT '状态:0-待处理 1-生成中 2-已完成 3-失败',
  `fail_reason`  varchar(200)  DEFAULT NULL              COMMENT '失败原因',
  `creator`      varchar(64)   NOT NULL DEFAULT ''       COMMENT '申请人',
  `create_time`  datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '申请时间',
  `complete_time` datetime     DEFAULT NULL              COMMENT '完成时间',
  `tenant_id`    bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_creator_status` (`creator`, `status`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='报表导出异步任务';

-- =============================================================================
-- 保险中介平台 - 营销中台数据库表结构
-- 模块：intermediary-module-ins-marketing
-- Schema：db_ins_marketing
-- 文件：03 - 活动管理（营销活动 / 参与记录 / B端活动推广）
-- 表前缀：ins_mkt_act_
-- =============================================================================

USE `db_ins_marketing`;

-- -------------------------------------------------------------------
-- 1. 营销活动（PC管理后台）
-- 类型：1-新人礼 2-满减 3-折扣 4-赠品 5-拼团 6-秒杀 7-积分兑换
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_act_activity`;
CREATE TABLE `ins_mkt_act_activity` (
  `id`              bigint          NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `activity_no`     varchar(32)     NOT NULL                  COMMENT '活动编号(唯一)',
  `name`            varchar(100)    NOT NULL                  COMMENT '活动名称',
  `type`            tinyint         NOT NULL                  COMMENT '活动类型:1-新人礼 2-满减 3-折扣 4-赠品 5-拼团 6-秒杀 7-积分兑换',
  `cover_image`     varchar(500)    NOT NULL                  COMMENT '封面图URL(建议750x400px)',
  `banner_images`   json            DEFAULT NULL              COMMENT '轮播图URL数组JSON(最多5张)',
  `description`     longtext        NOT NULL                  COMMENT '活动描述(富文本HTML)',
  `rule_config`     json            NOT NULL                  COMMENT '规则配置JSON(各类型配置不同)',
  `start_time`      datetime        NOT NULL                  COMMENT '活动开始时间',
  `end_time`        datetime        NOT NULL                  COMMENT '活动结束时间',
  `target_type`     tinyint         NOT NULL DEFAULT 1        COMMENT '目标用户:1-全部 2-新用户 3-老用户 4-指定用户',
  `target_config`   json            DEFAULT NULL              COMMENT '目标用户配置JSON(指定用户时存用户ID列表或标签)',
  `limit_type`      tinyint         NOT NULL DEFAULT 1        COMMENT '参与限制:1-不限 2-按次数 3-按频率(每天/周/月)',
  `limit_count`     int             DEFAULT NULL              COMMENT '限制次数',
  `limit_cycle`     varchar(10)     DEFAULT NULL              COMMENT '限制周期:day/week/month(limit_type=3时有效)',
  `product_scope`   tinyint         NOT NULL DEFAULT 1        COMMENT '产品范围:1-全部 2-指定分类 3-指定产品',
  `product_config`  json            DEFAULT NULL              COMMENT '产品范围配置JSON',
  `coupon_ids`      varchar(500)    DEFAULT NULL              COMMENT '关联优惠券ID列表(逗号分隔)',
  `point_give`      int             NOT NULL DEFAULT 0        COMMENT '参与赠送积分,0表示不赠送',
  `share_reward`    tinyint         NOT NULL DEFAULT 0        COMMENT '是否开启分享奖励:0-否 1-是',
  `share_config`    json            DEFAULT NULL              COMMENT '分享奖励配置JSON',
  `sort_order`      int             NOT NULL DEFAULT 0        COMMENT '排序号',
  `status`          tinyint         NOT NULL DEFAULT 0        COMMENT '状态:0-草稿 1-待审核 2-已通过 3-进行中 4-已结束 5-已下架',
  `audit_status`    tinyint         NOT NULL DEFAULT 0        COMMENT '审核状态:0-待审核 1-已通过 2-已驳回',
  `audit_remark`    varchar(500)    DEFAULT NULL              COMMENT '审核驳回原因',
  `auditor`         varchar(64)     DEFAULT NULL              COMMENT '审核人',
  `audit_time`      datetime        DEFAULT NULL              COMMENT '审核时间',
  `view_count`      int             NOT NULL DEFAULT 0        COMMENT '浏览量PV',
  `uv_count`        int             NOT NULL DEFAULT 0        COMMENT '浏览量UV',
  `join_count`      int             NOT NULL DEFAULT 0        COMMENT '参与人数',
  `order_count`     int             NOT NULL DEFAULT 0        COMMENT '产生订单数',
  `order_amount`    decimal(14,2)   NOT NULL DEFAULT 0.00     COMMENT '产生订单金额',
  `creator`         varchar(64)     NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         varchar(64)     NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`     datetime        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint         NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`       bigint          NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_activity_no` (`activity_no`),
  KEY `idx_status_time` (`status`, `start_time`, `end_time`),
  KEY `idx_type_status` (`type`, `status`, `deleted`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='营销活动';

-- -------------------------------------------------------------------
-- 2. 活动参与记录（C端用户参与营销活动）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_act_record`;
CREATE TABLE `ins_mkt_act_record` (
  `id`           bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `activity_id`  bigint       NOT NULL                   COMMENT '活动ID',
  `user_id`      bigint       NOT NULL                   COMMENT '用户ID',
  `join_time`    datetime     NOT NULL                   COMMENT '参与时间',
  `award_type`   tinyint      NOT NULL DEFAULT 1         COMMENT '奖励类型:1-优惠券 2-积分 3-赠品',
  `award_config` json         DEFAULT NULL               COMMENT '奖励详情JSON',
  `award_status` tinyint      NOT NULL DEFAULT 0         COMMENT '奖励状态:0-未发放 1-已发放 2-发放失败',
  `award_time`   datetime     DEFAULT NULL               COMMENT '奖励发放时间',
  `order_id`     bigint       DEFAULT NULL               COMMENT '关联订单ID',
  `status`       tinyint      NOT NULL DEFAULT 1         COMMENT '状态:1-已参与 2-已核销 3-已过期',
  `create_time`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`    bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_activity_user` (`activity_id`, `user_id`),
  KEY `idx_user_id_status` (`user_id`, `status`),
  KEY `idx_order_id` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='活动参与记录';

-- -------------------------------------------------------------------
-- 3. B端业务员活动推广（业务员App活动推广模块，区别于PC端C端活动）
-- 类型：1-业绩冲刺 2-拉新 3-产品促销 4-节日
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_act_agent_activity`;
CREATE TABLE `ins_mkt_act_agent_activity` (
  `id`                 bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `activity_name`      varchar(100)  NOT NULL                  COMMENT '活动名称',
  `activity_type`      tinyint       NOT NULL DEFAULT 1        COMMENT '活动类型:1-业绩冲刺 2-拉新 3-产品促销 4-节日',
  `cover_url`          varchar(500)  DEFAULT NULL              COMMENT '封面图URL',
  `description`        longtext      DEFAULT NULL              COMMENT '活动说明(富文本)',
  `rules`              longtext      DEFAULT NULL              COMMENT '活动规则(富文本)',
  `start_time`         datetime      NOT NULL                  COMMENT '开始时间',
  `end_time`           datetime      NOT NULL                  COMMENT '结束时间',
  `target_type`        tinyint       NOT NULL DEFAULT 1        COMMENT '目标类型:1-业绩金额 2-邀请人数 3-订单数量',
  `target_value`       int           NOT NULL DEFAULT 0        COMMENT '目标值',
  `participant_limit`  int           NOT NULL DEFAULT 0        COMMENT '参与人数上限,0=不限',
  `sort_order`         int           NOT NULL DEFAULT 0        COMMENT '排序号',
  `status`             tinyint       NOT NULL DEFAULT 0        COMMENT '状态:0-未开始 1-进行中 2-已结束 3-已取消',
  `creator`            varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`        datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`            varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`        datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`            tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`          bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_status_time` (`status`, `start_time`, `end_time`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='B端业务员活动推广';

-- -------------------------------------------------------------------
-- 4. B端活动奖励配置
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_act_agent_reward`;
CREATE TABLE `ins_mkt_act_agent_reward` (
  `id`              bigint         NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `activity_id`     bigint         NOT NULL                  COMMENT '关联活动ID',
  `reward_name`     varchar(100)   NOT NULL                  COMMENT '奖励名称(如:完成目标奖励)',
  `reward_type`     tinyint        NOT NULL DEFAULT 1        COMMENT '奖励类型:1-现金 2-积分 3-优惠券 4-实物',
  `reward_value`    decimal(10,2)  NOT NULL DEFAULT 0.00     COMMENT '奖励值(金额/积分数)',
  `condition_type`  tinyint        NOT NULL DEFAULT 1        COMMENT '发放条件:1-完成目标 2-排名',
  `condition_value` varchar(100)   DEFAULT NULL              COMMENT '条件值(排名时如"1-3"表示前三名)',
  `stock`           int            NOT NULL DEFAULT -1       COMMENT '库存,-1=无限',
  `granted_count`   int            NOT NULL DEFAULT 0        COMMENT '已发放数量',
  `create_time`     datetime       NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`       bigint         NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_activity_id` (`activity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='B端活动奖励配置';

-- -------------------------------------------------------------------
-- 5. B端业务员参与活动记录
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_act_agent_user`;
CREATE TABLE `ins_mkt_act_agent_user` (
  `id`              bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `user_id`         bigint       NOT NULL                   COMMENT '业务员用户ID',
  `activity_id`     bigint       NOT NULL                   COMMENT '活动ID',
  `join_time`       datetime     NOT NULL                   COMMENT '参与时间',
  `current_value`   int          NOT NULL DEFAULT 0         COMMENT '当前进度值',
  `target_value`    int          NOT NULL DEFAULT 0         COMMENT '目标值(参与时从活动表复制)',
  `complete_status` tinyint      NOT NULL DEFAULT 0         COMMENT '完成状态:0-未完成 1-已完成',
  `complete_time`   datetime     DEFAULT NULL               COMMENT '完成时间',
  `reward_status`   tinyint      NOT NULL DEFAULT 0         COMMENT '奖励状态:0-未发放 1-已发放',
  `reward_time`     datetime     DEFAULT NULL               COMMENT '奖励发放时间',
  `create_time`     datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time`     datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `tenant_id`       bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_activity` (`user_id`, `activity_id`),
  KEY `idx_activity_complete` (`activity_id`, `complete_status`, `reward_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='B端业务员参与活动记录';

-- -------------------------------------------------------------------
-- 6. B端团队管理（业务员树形组织结构）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_act_team_structure`;
CREATE TABLE `ins_mkt_act_team_structure` (
  `id`            bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `user_id`       bigint       NOT NULL                   COMMENT '当前节点业务员用户ID',
  `parent_id`     bigint       NOT NULL DEFAULT 0         COMMENT '上级业务员用户ID,0为顶级',
  `level`         int          NOT NULL DEFAULT 1         COMMENT '层级深度,从1开始',
  `path`          varchar(500) NOT NULL DEFAULT ''        COMMENT '完整路径,如/1/5/12/(方便树形查询)',
  `direct_count`  int          NOT NULL DEFAULT 0         COMMENT '直属下级人数',
  `total_count`   int          NOT NULL DEFAULT 0         COMMENT '团队总人数(含所有层级)',
  `creator`       varchar(64)  NOT NULL DEFAULT ''        COMMENT '创建者',
  `create_time`   datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`       varchar(64)  NOT NULL DEFAULT ''        COMMENT '更新者',
  `update_time`   datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `tenant_id`     bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_id` (`user_id`, `tenant_id`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_path` (`path`(255))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='业务员团队树形结构';

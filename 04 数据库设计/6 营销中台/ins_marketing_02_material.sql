-- =============================================================================
-- 保险中介平台 - 营销中台数据库表结构
-- 模块：intermediary-module-ins-marketing
-- Schema：db_ins_marketing
-- 文件：02 - 营销素材（海报模板 / 用户海报 / 计划书 / 邀请管理）
-- 表前缀：ins_mkt_material_
-- =============================================================================

USE `db_ins_marketing`;

-- -------------------------------------------------------------------
-- 1. 海报模板
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_material_poster_template`;
CREATE TABLE `ins_mkt_material_poster_template` (
  `id`              bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `template_name`   varchar(100)  NOT NULL                  COMMENT '模板名称',
  `template_type`   tinyint       NOT NULL DEFAULT 4        COMMENT '模板类型:1-节日 2-产品 3-活动 4-通用',
  `template_url`    varchar(500)  NOT NULL                  COMMENT '模板背景图URL(OSS)',
  `thumbnail_url`   varchar(500)  NOT NULL                  COMMENT '缩略图URL',
  `width`           int           NOT NULL DEFAULT 750      COMMENT '模板宽度(px)',
  `height`          int           NOT NULL DEFAULT 1334     COMMENT '模板高度(px)',
  `elements`        json          DEFAULT NULL              COMMENT '可编辑元素配置JSON:{texts:[],images:[]}',
  `qrcode_position` json          DEFAULT NULL              COMMENT '二维码位置JSON:{x,y,width,height}',
  `sort_order`      int           NOT NULL DEFAULT 0        COMMENT '排序号,数字越小越靠前',
  `status`          tinyint       NOT NULL DEFAULT 1        COMMENT '状态:0-禁用 1-启用',
  `use_count`       int           NOT NULL DEFAULT 0        COMMENT '使用次数',
  `creator`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`       bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_type_status` (`template_type`, `status`, `deleted`),
  KEY `idx_sort_use` (`sort_order`, `use_count`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='海报模板';

-- -------------------------------------------------------------------
-- 2. 用户生成海报记录
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_material_user_poster`;
CREATE TABLE `ins_mkt_material_user_poster` (
  `id`          bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `user_id`     bigint       NOT NULL                   COMMENT '业务员用户ID',
  `template_id` bigint       NOT NULL                   COMMENT '使用的模板ID',
  `poster_url`  varchar(500) NOT NULL                   COMMENT '生成海报图片OSS URL',
  `custom_data` json         DEFAULT NULL               COMMENT '用户自定义内容JSON:{texts:{},images:{}}',
  `share_count` int          NOT NULL DEFAULT 0         COMMENT '分享次数',
  `create_time` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '生成时间',
  `deleted`     tinyint      NOT NULL DEFAULT 0         COMMENT '是否删除:0-否 1-是',
  `tenant_id`   bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`, `deleted`),
  KEY `idx_template_id` (`template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户生成海报记录';

-- -------------------------------------------------------------------
-- 3. 计划书模板（非车险/寿险计划书模板配置）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_material_proposal_template`;
CREATE TABLE `ins_mkt_material_proposal_template` (
  `id`            bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `name`          varchar(100)  NOT NULL                  COMMENT '模板名称',
  `ins_type`      tinyint       NOT NULL DEFAULT 1        COMMENT '保险类型:1-非车险 2-寿险 3-通用',
  `template_file` varchar(500)  NOT NULL                  COMMENT '模板文件URL(Freemarker/Word模板)',
  `preview_image` varchar(500)  DEFAULT NULL              COMMENT '模板预览图URL',
  `description`   varchar(500)  DEFAULT NULL              COMMENT '模板说明',
  `sort_order`    int           NOT NULL DEFAULT 0        COMMENT '排序号',
  `status`        tinyint       NOT NULL DEFAULT 1        COMMENT '状态:0-禁用 1-启用',
  `use_count`     int           NOT NULL DEFAULT 0        COMMENT '使用次数',
  `creator`       varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`   datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`       varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`   datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`       tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`     bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_ins_type_status` (`ins_type`, `status`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='计划书模板';

-- -------------------------------------------------------------------
-- 4. 计划书记录
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_material_proposal_record`;
CREATE TABLE `ins_mkt_material_proposal_record` (
  `id`                bigint          NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `proposal_no`       varchar(32)     NOT NULL                  COMMENT '计划书编号,格式:PS+年月日+6位随机,唯一',
  `agent_id`          bigint          NOT NULL                  COMMENT '制作人业务员ID',
  `customer_id`       bigint          DEFAULT NULL              COMMENT '关联客户ID(可空)',
  `template_id`       bigint          NOT NULL                  COMMENT '使用的模板ID',
  `ins_type`          tinyint         NOT NULL DEFAULT 1        COMMENT '保险类型:1-非车险 2-寿险',
  `title`             varchar(100)    NOT NULL                  COMMENT '计划书标题',
  `applicant_name`    varchar(50)     NOT NULL                  COMMENT '投保人姓名',
  `applicant_age`     int             DEFAULT NULL              COMMENT '投保人年龄',
  `insured_name`      varchar(50)     NOT NULL                  COMMENT '被保人姓名',
  `insured_birthday`  date            DEFAULT NULL              COMMENT '被保人出生日期',
  `insured_gender`    tinyint         DEFAULT NULL              COMMENT '被保人性别:1-男 2-女',
  `insured_age`       int             DEFAULT NULL              COMMENT '被保人年龄(计算值)',
  `products`          json            NOT NULL                  COMMENT '产品方案数组JSON:[{productId,productName,amount,paymentPeriod,...}]',
  `total_premium`     decimal(12,2)   DEFAULT NULL              COMMENT '合计年缴保费',
  `coverage_summary`  json            DEFAULT NULL              COMMENT '保障责任汇总JSON',
  `cash_value_table`  json            DEFAULT NULL              COMMENT '现金价值表JSON(储蓄型产品专用)',
  `hidden_coverages`  json            DEFAULT NULL              COMMENT '业务员选择隐藏的责任项列表JSON',
  `remark`            varchar(500)    DEFAULT NULL              COMMENT '备注说明',
  `pdf_url`           varchar(500)    DEFAULT NULL              COMMENT 'PDF文件OSS地址',
  `share_token`       varchar(64)     DEFAULT NULL              COMMENT 'H5分享Token(UUID,存Redis30天)',
  `qr_code_url`       varchar(500)    DEFAULT NULL              COMMENT '分享二维码图片URL',
  `view_count`        int             NOT NULL DEFAULT 0        COMMENT '客户查看次数',
  `status`            tinyint         NOT NULL DEFAULT 1        COMMENT '状态:1-草稿 2-已生成 3-已分享',
  `creator`           varchar(64)     NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`       datetime        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`           varchar(64)     NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`       datetime        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`           tinyint         NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`         bigint          NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_proposal_no` (`proposal_no`),
  KEY `idx_agent_id_status` (`agent_id`, `status`, `deleted`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_share_token` (`share_token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='计划书记录(非车险/寿险)';

-- -------------------------------------------------------------------
-- 5. 邀请记录（客户邀请 / 代理人邀请）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_material_invite_record`;
CREATE TABLE `ins_mkt_material_invite_record` (
  `id`                bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `inviter_id`        bigint       NOT NULL                   COMMENT '邀请人用户ID(业务员)',
  `invite_code`       varchar(20)  NOT NULL                   COMMENT '邀请码(Base62,8位,唯一)',
  `invite_link`       varchar(500) DEFAULT NULL               COMMENT '邀请链接URL',
  `invite_type`       tinyint      NOT NULL DEFAULT 1         COMMENT '邀请类型:1-邀请客户注册 2-邀请代理人',
  `invitee_id`        bigint       DEFAULT NULL               COMMENT '被邀请人用户ID(注册后关联)',
  `invitee_phone`     varchar(20)  DEFAULT NULL               COMMENT '被邀请人手机号(注册时记录)',
  `register_time`     datetime     DEFAULT NULL               COMMENT '被邀请人注册时间',
  `first_order_time`  datetime     DEFAULT NULL               COMMENT '被邀请人首次下单时间',
  `parent_invite_id`  bigint       DEFAULT NULL               COMMENT '上级邀请记录ID(二级关系)',
  `create_time`       datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`         bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_invite_code` (`invite_code`),
  KEY `idx_inviter_id` (`inviter_id`),
  KEY `idx_invitee_id` (`invitee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='邀请记录';

-- -------------------------------------------------------------------
-- 6. 邀请奖励明细
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_material_invite_reward`;
CREATE TABLE `ins_mkt_material_invite_reward` (
  `id`               bigint         NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `inviter_id`       bigint         NOT NULL                  COMMENT '邀请人用户ID',
  `invite_record_id` bigint         NOT NULL                  COMMENT '关联邀请记录ID',
  `reward_type`      tinyint        NOT NULL                  COMMENT '奖励类型:1-注册奖励 2-首单奖励 3-业绩奖励',
  `reward_amount`    decimal(10,2)  NOT NULL DEFAULT 0.00     COMMENT '奖励金额',
  `reward_points`    int            NOT NULL DEFAULT 0        COMMENT '奖励积分',
  `order_id`         bigint         DEFAULT NULL              COMMENT '关联订单ID',
  `status`           tinyint        NOT NULL DEFAULT 0        COMMENT '状态:0-待发放 1-已发放 2-已取消',
  `grant_time`       datetime       DEFAULT NULL              COMMENT '实际发放时间',
  `remark`           varchar(200)   DEFAULT NULL              COMMENT '备注(如:二级邀请奖励)',
  `create_time`      datetime       NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`        bigint         NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_invite_order` (`invite_record_id`, `order_id`, `reward_type`),
  KEY `idx_inviter_status` (`inviter_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='邀请奖励明细';

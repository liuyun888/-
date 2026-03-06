-- =============================================================================
-- 保险中介平台 - 营销中台数据库表结构
-- 模块：intermediary-module-ins-marketing
-- Schema：db_ins_marketing
-- 文件：01 - 内容管理（Banner / 文章 / 知识库 / 视频 / 文案库）
-- 表前缀：ins_mkt_cms_
-- 编写说明：基于 yudao-cloud 框架规范，包含标准审计字段
-- =============================================================================

CREATE DATABASE IF NOT EXISTS `db_ins_marketing` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `db_ins_marketing`;

-- -------------------------------------------------------------------
-- 1. Banner 管理
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_cms_banner`;
CREATE TABLE `ins_mkt_cms_banner` (
  `id`                bigint        NOT NULL AUTO_INCREMENT                COMMENT '主键ID',
  `title`             varchar(100)  NOT NULL                               COMMENT 'Banner标题',
  `image_url`         varchar(500)  NOT NULL                               COMMENT 'PC端图片URL',
  `mobile_image_url`  varchar(500)  DEFAULT NULL                           COMMENT '移动端图片URL',
  `link_type`         tinyint       NOT NULL DEFAULT 3                     COMMENT '链接类型:1-内部链接 2-外部链接 3-无链接',
  `link_url`          varchar(500)  DEFAULT NULL                           COMMENT '跳转链接',
  `platform`          tinyint       NOT NULL DEFAULT 4                     COMMENT '适用平台:1-PC 2-H5 3-小程序 4-全平台',
  `position`          varchar(50)   NOT NULL DEFAULT 'home'                COMMENT '展示位置:home-首页 activity-活动页',
  `sort_order`        int           NOT NULL DEFAULT 0                     COMMENT '排序号,数字越小越靠前',
  `status`            tinyint       NOT NULL DEFAULT 0                     COMMENT '状态:0-下架 1-上架',
  `start_time`        datetime      DEFAULT NULL                           COMMENT '生效时间,NULL表示立即生效',
  `end_time`          datetime      DEFAULT NULL                           COMMENT '失效时间,NULL表示永不过期',
  `click_count`       int           NOT NULL DEFAULT 0                     COMMENT '点击量',
  `creator`           varchar(64)   NOT NULL DEFAULT ''                    COMMENT '创建者',
  `create_time`       datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`           varchar(64)   NOT NULL DEFAULT ''                    COMMENT '更新者',
  `update_time`       datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`           tinyint       NOT NULL DEFAULT 0                     COMMENT '是否删除:0-否 1-是',
  `tenant_id`         bigint        NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_position_status_del` (`position`, `status`, `deleted`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Banner管理';

-- -------------------------------------------------------------------
-- 2. 文章分类
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_cms_article_category`;
CREATE TABLE `ins_mkt_cms_article_category` (
  `id`          bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `parent_id`   bigint       NOT NULL DEFAULT 0         COMMENT '父分类ID,0为顶级',
  `name`        varchar(50)  NOT NULL                   COMMENT '分类名称',
  `code`        varchar(50)  NOT NULL                   COMMENT '分类编码,唯一,字母数字',
  `icon`        varchar(200) DEFAULT NULL               COMMENT '分类图标URL',
  `sort_order`  int          NOT NULL DEFAULT 0         COMMENT '排序号',
  `status`      tinyint      NOT NULL DEFAULT 1         COMMENT '状态:0-禁用 1-启用',
  `creator`     varchar(64)  NOT NULL DEFAULT ''        COMMENT '创建者',
  `create_time` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`     varchar(64)  NOT NULL DEFAULT ''        COMMENT '更新者',
  `update_time` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`     tinyint      NOT NULL DEFAULT 0         COMMENT '是否删除:0-否 1-是',
  `tenant_id`   bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code_tenant` (`code`, `tenant_id`, `deleted`),
  KEY `idx_parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文章分类';

-- -------------------------------------------------------------------
-- 3. 文章管理
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_cms_article`;
CREATE TABLE `ins_mkt_cms_article` (
  `id`              bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `category_id`     bigint        NOT NULL                  COMMENT '分类ID',
  `title`           varchar(200)  NOT NULL                  COMMENT '文章标题',
  `subtitle`        varchar(200)  DEFAULT NULL              COMMENT '副标题',
  `summary`         varchar(500)  NOT NULL                  COMMENT '摘要,用于列表展示',
  `cover_image`     varchar(500)  NOT NULL                  COMMENT '封面图URL',
  `author`          varchar(50)   NOT NULL                  COMMENT '作者',
  `source`          varchar(100)  DEFAULT NULL              COMMENT '来源名称',
  `source_url`      varchar(500)  DEFAULT NULL              COMMENT '来源链接',
  `tags`            varchar(500)  DEFAULT NULL              COMMENT '标签,JSON数组,最多5个',
  `content`         longtext      NOT NULL                  COMMENT '正文HTML内容',
  `seo_title`       varchar(200)  DEFAULT NULL              COMMENT 'SEO标题',
  `seo_keywords`    varchar(200)  DEFAULT NULL              COMMENT 'SEO关键词',
  `seo_description` varchar(500)  DEFAULT NULL              COMMENT 'SEO描述',
  `status`          tinyint       NOT NULL DEFAULT 0        COMMENT '状态:0-草稿 1-待审核 2-已发布 3-已下架',
  `audit_status`    tinyint       NOT NULL DEFAULT 0        COMMENT '审核状态:0-待审核 1-已通过 2-已驳回',
  `audit_remark`    varchar(500)  DEFAULT NULL              COMMENT '审核备注',
  `auditor`         varchar(64)   DEFAULT NULL              COMMENT '审核人',
  `audit_time`      datetime      DEFAULT NULL              COMMENT '审核时间',
  `publish_time`    datetime      DEFAULT NULL              COMMENT '发布时间(定时发布时为未来时间)',
  `is_top`          tinyint       NOT NULL DEFAULT 0        COMMENT '是否置顶:0-否 1-是',
  `is_recommend`    tinyint       NOT NULL DEFAULT 0        COMMENT '是否推荐:0-否 1-是',
  `is_hot`          tinyint       NOT NULL DEFAULT 0        COMMENT '是否热门:0-否 1-是',
  `sort_order`      int           NOT NULL DEFAULT 0        COMMENT '排序号',
  `view_count`      int           NOT NULL DEFAULT 0        COMMENT '浏览量',
  `like_count`      int           NOT NULL DEFAULT 0        COMMENT '点赞数',
  `share_count`     int           NOT NULL DEFAULT 0        COMMENT '分享数',
  `version`         int           NOT NULL DEFAULT 1        COMMENT '版本号',
  `creator`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`       bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_category_status` (`category_id`, `status`, `deleted`),
  KEY `idx_publish_time` (`publish_time`, `status`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文章管理';

-- -------------------------------------------------------------------
-- 4. 知识库分类
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_cms_knowledge_category`;
CREATE TABLE `ins_mkt_cms_knowledge_category` (
  `id`          bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `parent_id`   bigint       NOT NULL DEFAULT 0         COMMENT '父分类ID,0为顶级,最多三级',
  `name`        varchar(50)  NOT NULL                   COMMENT '分类名称',
  `icon`        varchar(200) DEFAULT NULL               COMMENT '分类图标URL',
  `sort_order`  int          NOT NULL DEFAULT 0         COMMENT '排序号',
  `status`      tinyint      NOT NULL DEFAULT 1         COMMENT '状态:0-禁用 1-启用',
  `creator`     varchar(64)  NOT NULL DEFAULT ''        COMMENT '创建者',
  `create_time` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`     varchar(64)  NOT NULL DEFAULT ''        COMMENT '更新者',
  `update_time` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`     tinyint      NOT NULL DEFAULT 0         COMMENT '是否删除:0-否 1-是',
  `tenant_id`   bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='知识库分类(最多三级)';

-- -------------------------------------------------------------------
-- 5. 知识库条目
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_cms_knowledge`;
CREATE TABLE `ins_mkt_cms_knowledge` (
  `id`           bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `category_id`  bigint        NOT NULL                  COMMENT '分类ID',
  `title`        varchar(200)  NOT NULL                  COMMENT '知识标题',
  `keywords`     varchar(500)  DEFAULT NULL              COMMENT '关键词,逗号分隔,最多5个,用于搜索',
  `content_md`   longtext      NOT NULL                  COMMENT 'Markdown原文内容',
  `content_html` longtext      NOT NULL                  COMMENT '渲染后HTML内容(双存)',
  `sort_order`   int           NOT NULL DEFAULT 0        COMMENT '排序号',
  `status`       tinyint       NOT NULL DEFAULT 0        COMMENT '状态:0-草稿 1-已发布 2-已下架',
  `view_count`   int           NOT NULL DEFAULT 0        COMMENT '浏览量',
  `version`      int           NOT NULL DEFAULT 1        COMMENT '版本号,每次保存自增',
  `creator`      varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`  datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`      varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`  datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`      tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`    bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_category_status` (`category_id`, `status`, `deleted`),
  FULLTEXT KEY `ft_title_keywords` (`title`, `keywords`) WITH PARSER ngram
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='知识库条目';

-- -------------------------------------------------------------------
-- 6. 知识库版本快照
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_cms_knowledge_version`;
CREATE TABLE `ins_mkt_cms_knowledge_version` (
  `id`           bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `knowledge_id` bigint       NOT NULL                   COMMENT '知识条目ID',
  `version`      int          NOT NULL                   COMMENT '版本号',
  `title`        varchar(200) NOT NULL                   COMMENT '版本快照标题',
  `content_md`   longtext     NOT NULL                   COMMENT '版本快照Markdown内容',
  `content_html` longtext     NOT NULL                   COMMENT '版本快照HTML内容',
  `change_desc`  varchar(200) DEFAULT NULL               COMMENT '变更说明',
  `creator`      varchar(64)  NOT NULL DEFAULT ''        COMMENT '操作人',
  `create_time`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '保存时间',
  `tenant_id`    bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_knowledge_version` (`knowledge_id`, `version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='知识库版本快照';

-- -------------------------------------------------------------------
-- 7. 视频分类
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_cms_video_category`;
CREATE TABLE `ins_mkt_cms_video_category` (
  `id`          bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `parent_id`   bigint       NOT NULL DEFAULT 0         COMMENT '父分类ID',
  `name`        varchar(50)  NOT NULL                   COMMENT '分类名称',
  `icon`        varchar(200) DEFAULT NULL               COMMENT '图标URL',
  `sort_order`  int          NOT NULL DEFAULT 0         COMMENT '排序号',
  `status`      tinyint      NOT NULL DEFAULT 1         COMMENT '状态:0-禁用 1-启用',
  `creator`     varchar(64)  NOT NULL DEFAULT ''        COMMENT '创建者',
  `create_time` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`     varchar(64)  NOT NULL DEFAULT ''        COMMENT '更新者',
  `update_time` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`     tinyint      NOT NULL DEFAULT 0         COMMENT '是否删除:0-否 1-是',
  `tenant_id`   bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='视频分类';

-- -------------------------------------------------------------------
-- 8. 视频管理
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_cms_video`;
CREATE TABLE `ins_mkt_cms_video` (
  `id`              bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `category_id`     bigint        NOT NULL                  COMMENT '分类ID',
  `title`           varchar(200)  NOT NULL                  COMMENT '视频标题',
  `cover_image`     varchar(500)  NOT NULL                  COMMENT '封面图URL',
  `video_url`       varchar(500)  DEFAULT NULL              COMMENT '视频文件URL(OSS直传)',
  `vod_video_id`    varchar(100)  DEFAULT NULL              COMMENT '阿里云VOD视频ID',
  `duration`        int           NOT NULL DEFAULT 0        COMMENT '视频时长(秒)',
  `description`     text          DEFAULT NULL              COMMENT '视频简介',
  `tags`            varchar(500)  DEFAULT NULL              COMMENT '标签JSON数组',
  `sort_order`      int           NOT NULL DEFAULT 0        COMMENT '排序号',
  `status`          tinyint       NOT NULL DEFAULT 0        COMMENT '状态:0-草稿 1-已上架 2-已下架',
  `view_count`      int           NOT NULL DEFAULT 0        COMMENT '播放量',
  `creator`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`       bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_category_status` (`category_id`, `status`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='视频管理';

-- -------------------------------------------------------------------
-- 9. 文案库（营销话术/朋友圈文案/短信文案）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_cms_copywriting`;
CREATE TABLE `ins_mkt_cms_copywriting` (
  `id`          bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `title`       varchar(200)  NOT NULL                  COMMENT '文案标题',
  `content`     text          NOT NULL                  COMMENT '文案内容,支持占位符{name}/{phone}/{company}/{wechat}',
  `scene_type`  tinyint       NOT NULL DEFAULT 1        COMMENT '场景类型:1-朋友圈 2-短信 3-话术',
  `use_count`   int           NOT NULL DEFAULT 0        COMMENT '使用次数',
  `sort_order`  int           NOT NULL DEFAULT 0        COMMENT '排序号',
  `status`      tinyint       NOT NULL DEFAULT 1        COMMENT '状态:0-禁用 1-启用',
  `creator`     varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time` datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`     varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time` datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`     tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`   bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_scene_status` (`scene_type`, `status`, `deleted`),
  KEY `idx_sort_use` (`sort_order`, `use_count`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文案库(营销话术/朋友圈/短信)';

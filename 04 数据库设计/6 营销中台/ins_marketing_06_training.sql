-- =============================================================================
-- 保险中介平台 - 营销中台数据库表结构
-- 模块：intermediary-module-ins-marketing
-- Schema：db_ins_marketing
-- 文件：06 - 培训管理（培训立项 / 培训计划 / 课程 / 章节 / 讲师 / 考试 / 证书 / 学习记录）
-- 表前缀：ins_mkt_train_
-- =============================================================================

USE `db_ins_marketing`;

-- -------------------------------------------------------------------
-- 1. 培训立项（培训项目）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_project`;
CREATE TABLE `ins_mkt_train_project` (
  `id`              bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `name`            varchar(100)  NOT NULL                  COMMENT '项目名称',
  `train_type`      tinyint       NOT NULL DEFAULT 1        COMMENT '培训类型:1-线上 2-线下 3-混合',
  `is_required`     tinyint       NOT NULL DEFAULT 0        COMMENT '是否必修:0-选修 1-必修',
  `plan_hours`      int           NOT NULL DEFAULT 0        COMMENT '计划学时(小时)',
  `start_date`      date          NOT NULL                  COMMENT '项目起始日期',
  `end_date`        date          NOT NULL                  COMMENT '项目截止日期',
  `cover_image`     varchar(500)  DEFAULT NULL              COMMENT '封面图URL',
  `target_ranks`    varchar(500)  DEFAULT NULL              COMMENT '适用职级JSON数组(空表示全部)',
  `objective`       varchar(500)  DEFAULT NULL              COMMENT '培训目标',
  `description`     text          DEFAULT NULL              COMMENT '项目说明',
  `status`          tinyint       NOT NULL DEFAULT 0        COMMENT '状态:0-草稿 1-进行中 2-已结束 3-已关闭',
  `creator`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`       bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_status_date` (`status`, `start_date`, `end_date`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='培训立项(培训项目)';

-- -------------------------------------------------------------------
-- 2. 讲师库
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_teacher`;
CREATE TABLE `ins_mkt_train_teacher` (
  `id`            bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `name`          varchar(50)   NOT NULL                  COMMENT '讲师姓名',
  `avatar`        varchar(500)  DEFAULT NULL              COMMENT '头像URL',
  `title`         varchar(100)  DEFAULT NULL              COMMENT '职称/头衔',
  `organization`  varchar(100)  DEFAULT NULL              COMMENT '所属机构',
  `introduction`  text          DEFAULT NULL              COMMENT '讲师介绍',
  `specialties`   varchar(500)  DEFAULT NULL              COMMENT '擅长领域(JSON数组)',
  `phone`         varchar(20)   DEFAULT NULL              COMMENT '联系电话',
  `email`         varchar(100)  DEFAULT NULL              COMMENT '邮箱',
  `status`        tinyint       NOT NULL DEFAULT 1        COMMENT '状态:0-禁用 1-启用',
  `creator`       varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`   datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`       varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`   datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`       tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`     bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_status_del` (`status`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='培训讲师库';

-- -------------------------------------------------------------------
-- 3. 培训计划（属于培训立项）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_plan`;
CREATE TABLE `ins_mkt_train_plan` (
  `id`              bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `project_id`      bigint        NOT NULL                  COMMENT '所属立项ID',
  `name`            varchar(100)  NOT NULL                  COMMENT '计划名称',
  `teacher_id`      bigint        NOT NULL                  COMMENT '培训讲师ID',
  `train_location`  varchar(200)  DEFAULT NULL              COMMENT '培训地点(线下/混合时必填)',
  `online_url`      varchar(500)  DEFAULT NULL              COMMENT '线上培训链接(线上/混合时必填)',
  `start_time`      datetime      NOT NULL                  COMMENT '开始时间(须在立项起止日期范围内)',
  `end_time`        datetime      NOT NULL                  COMMENT '结束时间',
  `enroll_deadline` datetime      NOT NULL                  COMMENT '报名截止时间(须早于开始时间)',
  `max_members`     int           NOT NULL DEFAULT 0        COMMENT '最大学员数,0表示不限',
  `enroll_count`    int           NOT NULL DEFAULT 0        COMMENT '已报名人数',
  `course_ids`      json          DEFAULT NULL              COMMENT '课程清单JSON数组(有序,可拖拽排序)',
  `description`     text          DEFAULT NULL              COMMENT '计划说明(最长1000字符)',
  `status`          tinyint       NOT NULL DEFAULT 0        COMMENT '状态:0-草稿 1-报名中 2-进行中 3-已结束',
  `creator`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`       bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_project_id_status` (`project_id`, `status`),
  KEY `idx_status_time` (`status`, `start_time`, `end_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='培训计划';

-- -------------------------------------------------------------------
-- 4. 培训计划学员报名
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_plan_member`;
CREATE TABLE `ins_mkt_train_plan_member` (
  `id`          bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `plan_id`     bigint       NOT NULL                   COMMENT '培训计划ID',
  `user_id`     bigint       NOT NULL                   COMMENT '学员用户ID',
  `enroll_time` datetime     NOT NULL                   COMMENT '报名时间',
  `status`      tinyint      NOT NULL DEFAULT 1         COMMENT '状态:1-已报名 2-已签到 3-已完成 4-已取消',
  `attend_time` datetime     DEFAULT NULL               COMMENT '签到时间',
  `complete_time` datetime   DEFAULT NULL               COMMENT '完成时间',
  `create_time` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`   bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_plan_user` (`plan_id`, `user_id`),
  KEY `idx_user_id_status` (`user_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='培训计划学员报名';

-- -------------------------------------------------------------------
-- 5. 课程分类（两级）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_course_category`;
CREATE TABLE `ins_mkt_train_course_category` (
  `id`          bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `parent_id`   bigint       NOT NULL DEFAULT 0         COMMENT '父分类ID,0为顶级',
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='课程分类(两级)';

-- -------------------------------------------------------------------
-- 6. 课程管理
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_course`;
CREATE TABLE `ins_mkt_train_course` (
  `id`            bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `category_id`   bigint        NOT NULL                  COMMENT '分类ID(末级分类)',
  `course_name`   varchar(100)  NOT NULL                  COMMENT '课程名称',
  `course_type`   tinyint       NOT NULL DEFAULT 1        COMMENT '课程类型:1-视频 2-图文 3-音频 4-直播',
  `cover_url`     varchar(500)  NOT NULL                  COMMENT '封面图URL(建议16:9)',
  `teacher_id`    bigint        DEFAULT NULL              COMMENT '讲师ID(关联ins_mkt_train_teacher)',
  `teacher_name`  varchar(50)   DEFAULT NULL              COMMENT '讲师姓名快照',
  `duration`      int           NOT NULL DEFAULT 0        COMMENT '总时长(秒)',
  `plan_hours`    int           NOT NULL DEFAULT 0        COMMENT '计划课时(小时)',
  `difficulty`    tinyint       NOT NULL DEFAULT 1        COMMENT '难度:1-入门 2-进阶 3-高级',
  `target_ranks`  varchar(500)  DEFAULT NULL              COMMENT '适用职级JSON数组(空表示全部职级)',
  `keywords`      varchar(500)  DEFAULT NULL              COMMENT '关键词(最多5个,逗号分隔)',
  `introduction`  text          DEFAULT NULL              COMMENT '课程简介',
  `is_required`   tinyint       NOT NULL DEFAULT 0        COMMENT '是否必修:0-选修 1-必修',
  `sort_order`    int           NOT NULL DEFAULT 0        COMMENT '排序号',
  `status`        tinyint       NOT NULL DEFAULT 0        COMMENT '状态:0-草稿 1-已上架 2-已下架',
  `study_count`   int           NOT NULL DEFAULT 0        COMMENT '已学人数',
  `ref_count`     int           NOT NULL DEFAULT 0        COMMENT '被培训计划引用次数',
  `creator`       varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`   datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`       varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`   datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`       tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`     bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_category_status` (`category_id`, `status`, `deleted`),
  KEY `idx_required_status` (`is_required`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='课程管理';

-- -------------------------------------------------------------------
-- 7. 课程章节
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_course_chapter`;
CREATE TABLE `ins_mkt_train_course_chapter` (
  `id`            bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `course_id`     bigint        NOT NULL                  COMMENT '课程ID',
  `chapter_name`  varchar(100)  NOT NULL                  COMMENT '章节名称',
  `content_type`  tinyint       NOT NULL DEFAULT 1        COMMENT '内容类型:1-视频 2-图文 3-音频',
  `content_url`   varchar(500)  DEFAULT NULL              COMMENT '内容URL(视频/音频文件OSS地址)',
  `vod_video_id`  varchar(100)  DEFAULT NULL              COMMENT '阿里云VOD视频ID',
  `duration`      int           NOT NULL DEFAULT 0        COMMENT '时长(秒)',
  `is_free`       tinyint       NOT NULL DEFAULT 0        COMMENT '是否免费试看:0-否 1-是',
  `sort_order`    int           NOT NULL DEFAULT 0        COMMENT '章节序号/排序',
  `status`        tinyint       NOT NULL DEFAULT 1        COMMENT '状态:0-禁用 1-启用',
  `creator`       varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`   datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`       varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`   datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`       tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`     bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_course_sort` (`course_id`, `sort_order`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='课程章节';

-- -------------------------------------------------------------------
-- 8. 用户学习记录（章节级别）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_study_record`;
CREATE TABLE `ins_mkt_train_study_record` (
  `id`              bigint       NOT NULL AUTO_INCREMENT    COMMENT '主键ID',
  `user_id`         bigint       NOT NULL                   COMMENT '学员用户ID',
  `course_id`       bigint       NOT NULL                   COMMENT '课程ID',
  `chapter_id`      bigint       NOT NULL                   COMMENT '章节ID',
  `study_duration`  int          NOT NULL DEFAULT 0         COMMENT '本章节已学时长(秒)',
  `last_position`   int          NOT NULL DEFAULT 0         COMMENT '上次播放位置(秒,用于断点续播)',
  `study_progress`  tinyint      NOT NULL DEFAULT 0         COMMENT '章节学习进度(0-100百分比)',
  `is_completed`    tinyint      NOT NULL DEFAULT 0         COMMENT '是否完成:0-未完成 1-已完成',
  `complete_time`   datetime     DEFAULT NULL               COMMENT '章节完成时间',
  `create_time`     datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '首次学习时间',
  `update_time`     datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最近学习时间',
  `tenant_id`       bigint       NOT NULL DEFAULT 0         COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_chapter` (`user_id`, `chapter_id`),
  KEY `idx_user_course` (`user_id`, `course_id`),
  KEY `idx_course_id` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户章节学习记录';

-- -------------------------------------------------------------------
-- 9. 在线考试
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_exam`;
CREATE TABLE `ins_mkt_train_exam` (
  `id`              bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `course_id`       bigint        DEFAULT NULL              COMMENT '关联课程ID(课程进度>=95%可参考)',
  `plan_id`         bigint        DEFAULT NULL              COMMENT '关联培训计划ID',
  `name`            varchar(100)  NOT NULL                  COMMENT '考试名称',
  `description`     varchar(500)  DEFAULT NULL              COMMENT '考试说明',
  `duration`        int           NOT NULL DEFAULT 60       COMMENT '考试时长(分钟)',
  `total_score`     int           NOT NULL DEFAULT 100      COMMENT '总分',
  `pass_score`      int           NOT NULL DEFAULT 60       COMMENT '及格分',
  `max_attempts`    int           NOT NULL DEFAULT 3        COMMENT '最多答题次数,-1不限',
  `questions`       json          NOT NULL                  COMMENT '题目JSON数组(含题干/选项/答案/分值)',
  `status`          tinyint       NOT NULL DEFAULT 1        COMMENT '状态:0-禁用 1-启用',
  `creator`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '更新者',
  `update_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint       NOT NULL DEFAULT 0        COMMENT '是否删除:0-否 1-是',
  `tenant_id`       bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_course_id` (`course_id`),
  KEY `idx_plan_id` (`plan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='在线考试';

-- -------------------------------------------------------------------
-- 10. 用户考试记录
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_exam_record`;
CREATE TABLE `ins_mkt_train_exam_record` (
  `id`           bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `exam_id`      bigint        NOT NULL                  COMMENT '考试ID',
  `user_id`      bigint        NOT NULL                  COMMENT '学员用户ID',
  `attempt_no`   int           NOT NULL DEFAULT 1        COMMENT '第几次答题',
  `start_time`   datetime      NOT NULL                  COMMENT '开始答题时间',
  `submit_time`  datetime      DEFAULT NULL              COMMENT '提交时间',
  `answers`      json          DEFAULT NULL              COMMENT '用户答案JSON',
  `score`        int           DEFAULT NULL              COMMENT '得分',
  `is_passed`    tinyint       DEFAULT NULL              COMMENT '是否及格:0-未及格 1-及格',
  `status`       tinyint       NOT NULL DEFAULT 1        COMMENT '状态:1-答题中 2-已提交 3-超时未交',
  `create_time`  datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`    bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_exam_user` (`exam_id`, `user_id`),
  KEY `idx_user_id_status` (`user_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户考试记录';

-- -------------------------------------------------------------------
-- 11. 学习证书配置
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_certificate_template`;
CREATE TABLE `ins_mkt_train_certificate_template` (
  `id`              bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `name`            varchar(100)  NOT NULL                  COMMENT '证书模板名称',
  `template_url`    varchar(500)  NOT NULL                  COMMENT '证书背景模板图URL',
  `elements`        json          DEFAULT NULL              COMMENT '可填充元素配置JSON(姓名/课程/日期坐标等)',
  `course_id`       bigint        DEFAULT NULL              COMMENT '关联课程ID(为空时通用)',
  `status`          tinyint       NOT NULL DEFAULT 1        COMMENT '状态:0-禁用 1-启用',
  `creator`         varchar(64)   NOT NULL DEFAULT ''       COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`       bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_course_id` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='学习证书模板';

-- -------------------------------------------------------------------
-- 12. 用户学习证书（颁发记录）
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_mkt_train_user_certificate`;
CREATE TABLE `ins_mkt_train_user_certificate` (
  `id`               bigint        NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `user_id`          bigint        NOT NULL                  COMMENT '学员用户ID',
  `course_id`        bigint        DEFAULT NULL              COMMENT '关联课程ID',
  `plan_id`          bigint        DEFAULT NULL              COMMENT '关联培训计划ID',
  `exam_record_id`   bigint        DEFAULT NULL              COMMENT '关联考试记录ID',
  `template_id`      bigint        NOT NULL                  COMMENT '证书模板ID',
  `certificate_no`   varchar(32)   NOT NULL                  COMMENT '证书编号(唯一)',
  `certificate_url`  varchar(500)  NOT NULL                  COMMENT '生成证书图片URL(OSS)',
  `issue_time`       datetime      NOT NULL                  COMMENT '颁发时间',
  `expire_time`      datetime      DEFAULT NULL              COMMENT '证书有效期(NULL表示永久有效)',
  `create_time`      datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `tenant_id`        bigint        NOT NULL DEFAULT 0        COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cert_no` (`certificate_no`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_course_id` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户学习证书(颁发记录)';

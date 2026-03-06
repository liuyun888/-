-- ============================================================
-- intermediary-module-ins-agent 数据库建表脚本
-- 模块：业务员管理 + CRM 客户管理
-- Schema: db_ins_agent
-- 表前缀: ins_agent_
-- 文档依据: 阶段1-业务逻辑-组织架构、人员管理；阶段2-PC客户CRM
-- 版本: V1.0 / 2026-03-01
-- ============================================================
-- Part 1: 组织架构 + 业务员管理
-- ============================================================

CREATE DATABASE IF NOT EXISTS `db_ins_agent` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `db_ins_agent`;

-- -----------------------------------------------------------
-- 1. 机构表（总公司/分公司/营业部）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_org` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT COMMENT '机构ID',
  `parent_id`        BIGINT       NOT NULL DEFAULT 0 COMMENT '父机构ID，0=顶级',
  `ancestors`        VARCHAR(1000) NOT NULL DEFAULT '' COMMENT '祖级ID列表，逗号分隔',
  `org_name`         VARCHAR(100) NOT NULL COMMENT '机构名称',
  `org_code`         VARCHAR(50)  NOT NULL COMMENT '机构代码（全局唯一）',
  `org_type`         TINYINT      NOT NULL COMMENT '机构类型：1-总公司 2-分公司 3-营业部',
  `leader_id`        BIGINT       DEFAULT NULL COMMENT '负责人ID（关联 system_users.id）',
  `leader_name`      VARCHAR(50)  DEFAULT NULL COMMENT '负责人姓名（冗余）',
  `phone`            VARCHAR(20)  NOT NULL COMMENT '联系电话',
  `province_code`    VARCHAR(20)  DEFAULT NULL COMMENT '省代码',
  `city_code`        VARCHAR(20)  DEFAULT NULL COMMENT '市代码',
  `district_code`    VARCHAR(20)  DEFAULT NULL COMMENT '区代码',
  `address`          VARCHAR(300) DEFAULT NULL COMMENT '详细地址',
  `establish_date`   DATE         NOT NULL COMMENT '成立日期',
  `license_no`       VARCHAR(100) NOT NULL COMMENT '营业执照号',
  `license_image`    VARCHAR(500) DEFAULT NULL COMMENT '营业执照图片URL',
  `permit_no`        VARCHAR(100) NOT NULL COMMENT '经营许可证号',
  `permit_start_date` DATE        NOT NULL COMMENT '许可证生效日期',
  `permit_end_date`  DATE         NOT NULL COMMENT '许可证到期日期',
  `status`           TINYINT      NOT NULL DEFAULT 1 COMMENT '状态：0-停用 1-启用',
  `sort`             INT          NOT NULL DEFAULT 0 COMMENT '排序',
  `remark`           VARCHAR(500) DEFAULT NULL COMMENT '备注',
  `creator`          VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
  `create_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`          VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
  `update_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`          TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除：0-否 1-是',
  `tenant_id`        BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_org_code` (`org_code`, `deleted`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_tenant`    (`tenant_id`),
  KEY `idx_status`    (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='机构表（总公司/分公司/营业部）';

-- -----------------------------------------------------------
-- 2. 部门表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_department` (
  `id`          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '部门ID',
  `org_id`      BIGINT       NOT NULL COMMENT '所属机构ID',
  `parent_id`   BIGINT       NOT NULL DEFAULT 0 COMMENT '父部门ID，0=该机构顶级',
  `ancestors`   VARCHAR(1000) NOT NULL DEFAULT '' COMMENT '祖级ID列表',
  `dept_name`   VARCHAR(50)  NOT NULL COMMENT '部门名称',
  `dept_code`   VARCHAR(50)  NOT NULL COMMENT '部门代码（全局唯一）',
  `leader_id`   BIGINT       DEFAULT NULL COMMENT '部门负责人ID',
  `leader_name` VARCHAR(50)  DEFAULT NULL COMMENT '负责人姓名（冗余）',
  `phone`       VARCHAR(20)  DEFAULT NULL COMMENT '联系电话',
  `email`       VARCHAR(100) DEFAULT NULL COMMENT '邮箱',
  `status`      TINYINT      NOT NULL DEFAULT 1 COMMENT '状态：0-停用 1-启用',
  `sort`        INT          NOT NULL DEFAULT 0 COMMENT '排序',
  `creator`     VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`     VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`     TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`   BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_dept_code` (`dept_code`, `deleted`),
  KEY `idx_org_id`    (`org_id`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_tenant`    (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='部门表';

-- -----------------------------------------------------------
-- 3. 岗位表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_post` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '岗位ID',
  `post_code`     VARCHAR(50)  NOT NULL COMMENT '岗位代码（全局唯一）',
  `post_name`     VARCHAR(100) NOT NULL COMMENT '岗位名称',
  `post_category` TINYINT      NOT NULL COMMENT '类别：1-管理岗 2-销售岗 3-职能岗 4-技术岗 5-其他',
  `status`        TINYINT      NOT NULL DEFAULT 1 COMMENT '0-停用 1-启用',
  `sort`          INT          NOT NULL DEFAULT 0,
  `remark`        VARCHAR(500) DEFAULT NULL COMMENT '职责说明',
  `creator`       VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`       VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`       TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`     BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_post_code` (`post_code`, `deleted`),
  KEY `idx_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='岗位表';

-- -----------------------------------------------------------
-- 4. 业务员扩展信息表（主表，关联 system_users）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_info` (
  `id`                   BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id`              BIGINT       NOT NULL COMMENT '关联 system_users.id',
  `agent_code`           VARCHAR(32)  NOT NULL COMMENT '工号（全局唯一，格式：AyyyyMMddNNNN）',
  `real_name`            VARCHAR(50)  NOT NULL COMMENT '真实姓名',
  `gender`               TINYINT      NOT NULL DEFAULT 1 COMMENT '性别：1-男 2-女',
  `id_card`              VARCHAR(300) NOT NULL COMMENT '身份证号（AES-256 加密）',
  `id_card_md5`          VARCHAR(64)  NOT NULL COMMENT '身份证 MD5（快速查重用）',
  `id_card_last4`        VARCHAR(4)   DEFAULT NULL COMMENT '身份证后4位明文（用于展示/搜索）',
  `mobile`               VARCHAR(20)  NOT NULL COMMENT '手机号（同 system_users.mobile）',
  `email`                VARCHAR(100) DEFAULT NULL COMMENT '邮箱',
  `birthday`             DATE         DEFAULT NULL COMMENT '出生日期',
  `avatar`               VARCHAR(500) DEFAULT NULL COMMENT '头像 URL',
  `org_id`               BIGINT       NOT NULL COMMENT '所属机构ID',
  `dept_id`              BIGINT       DEFAULT NULL COMMENT '所属部门ID',
  `post_id`              BIGINT       DEFAULT NULL COMMENT '所属岗位ID',
  `entry_date`           DATE         NOT NULL COMMENT '入职日期',
  `leave_date`           DATE         DEFAULT NULL COMMENT '离职日期',
  `emergency_contact`    VARCHAR(50)  DEFAULT NULL COMMENT '紧急联系人',
  `emergency_phone`      VARCHAR(20)  DEFAULT NULL COMMENT '紧急联系电话',
  `bank_name`            VARCHAR(100) DEFAULT NULL COMMENT '开户银行名称',
  `bank_branch`          VARCHAR(200) DEFAULT NULL COMMENT '开户支行',
  `bank_account`         VARCHAR(300) DEFAULT NULL COMMENT '银行卡号（AES-256 加密）',
  `bank_account_last4`   VARCHAR(4)   DEFAULT NULL COMMENT '银行卡号后4位（展示用）',
  `bank_account_name`    VARCHAR(50)  DEFAULT NULL COMMENT '开户名（与身份证一致）',
  `status`               TINYINT      NOT NULL DEFAULT 0 COMMENT '状态：0-待激活 1-正常 2-停用 3-离职 4-黑名单',
  `blacklist_reason`     VARCHAR(500) DEFAULT NULL COMMENT '黑名单原因',
  `blacklist_time`       DATETIME     DEFAULT NULL COMMENT '加入黑名单时间',
  `data_scope`           TINYINT      NOT NULL DEFAULT 4 COMMENT '数据权限：1-全部 2-本机构及子机构 3-本部门 4-仅本人',
  `creator`              VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`              VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`              TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`            BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_id`     (`user_id`, `deleted`),
  UNIQUE KEY `uk_agent_code`  (`agent_code`, `deleted`),
  UNIQUE KEY `uk_id_card_md5` (`id_card_md5`, `tenant_id`, `deleted`),
  KEY `idx_org_id`    (`org_id`),
  KEY `idx_dept_id`   (`dept_id`),
  KEY `idx_status`    (`status`),
  KEY `idx_tenant`    (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员扩展信息表';

-- -----------------------------------------------------------
-- 5. 业务员岗位关联（支持兼岗）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_post_rel` (
  `id`         BIGINT   NOT NULL AUTO_INCREMENT,
  `agent_id`   BIGINT   NOT NULL COMMENT '业务员ID',
  `post_id`    BIGINT   NOT NULL COMMENT '岗位ID',
  `is_primary` TINYINT  NOT NULL DEFAULT 1 COMMENT '是否主岗：1-是 0-否',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_post` (`agent_id`, `post_id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_post_id`  (`post_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员岗位关联表（支持兼岗）';

-- -----------------------------------------------------------
-- 6. 业务员资质证书表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_qualification` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `agent_id`        BIGINT       NOT NULL COMMENT '业务员ID',
  `cert_type`       TINYINT      NOT NULL COMMENT '证书类型：1-代理人证 2-经纪人证 3-公估人证',
  `cert_no`         VARCHAR(100) NOT NULL COMMENT '证书编号',
  `cert_level`      VARCHAR(20)  DEFAULT NULL COMMENT '证书等级（初级/中级/高级）',
  `cert_issue_date` DATE         NOT NULL COMMENT '发证日期',
  `cert_expire_date` DATE        NOT NULL COMMENT '到期日期',
  `cert_front_img`  VARCHAR(500) DEFAULT NULL COMMENT '证书正面图片URL',
  `cert_back_img`   VARCHAR(500) DEFAULT NULL COMMENT '证书背面图片URL',
  `verify_status`   TINYINT      NOT NULL DEFAULT 0 COMMENT '审核状态：0-待审核 1-已通过 2-已拒绝',
  `verify_remark`   VARCHAR(500) DEFAULT NULL COMMENT '审核备注/拒绝原因',
  `verify_time`     DATETIME     DEFAULT NULL COMMENT '审核时间',
  `verifier_id`     BIGINT       DEFAULT NULL COMMENT '审核人ID',
  `creator`         VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cert_no` (`cert_no`, `deleted`),
  KEY `idx_agent_id`     (`agent_id`),
  KEY `idx_expire_date`  (`cert_expire_date`),
  KEY `idx_verify_status`(`verify_status`),
  KEY `idx_tenant`       (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员资质证书表';

-- -----------------------------------------------------------
-- 7. 业务员调动记录表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_transfer_log` (
  `id`           BIGINT       NOT NULL AUTO_INCREMENT,
  `agent_id`     BIGINT       NOT NULL COMMENT '业务员ID',
  `from_org_id`  BIGINT       DEFAULT NULL COMMENT '原机构ID',
  `to_org_id`    BIGINT       NOT NULL COMMENT '目标机构ID',
  `from_dept_id` BIGINT       DEFAULT NULL COMMENT '原部门ID',
  `to_dept_id`   BIGINT       DEFAULT NULL COMMENT '目标部门ID',
  `from_post_id` BIGINT       DEFAULT NULL COMMENT '原岗位ID',
  `to_post_id`   BIGINT       DEFAULT NULL COMMENT '目标岗位ID',
  `transfer_date` DATE        NOT NULL COMMENT '调动日期',
  `operator_id`  BIGINT       NOT NULL COMMENT '操作人ID',
  `remark`       VARCHAR(500) DEFAULT NULL COMMENT '备注',
  `create_time`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`    BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_tenant`   (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员调动记录表';

-- -----------------------------------------------------------
-- 8. 业务员离职记录表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_leave_record` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT,
  `agent_id`       BIGINT       NOT NULL COMMENT '业务员ID',
  `leave_date`     DATE         NOT NULL COMMENT '离职日期',
  `leave_type`     TINYINT      NOT NULL COMMENT '离职类型：1-主动离职 2-被动离职',
  `handover_id`    BIGINT       NOT NULL COMMENT '客户接手业务员ID',
  `remark`         VARCHAR(500) DEFAULT NULL COMMENT '备注',
  `operator_id`    BIGINT       NOT NULL COMMENT '操作人ID',
  `create_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`      BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_tenant`   (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员离职记录表';

-- -----------------------------------------------------------
-- 9. 业务员黑名单申诉记录
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_blacklist_appeal` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT,
  `agent_id`      BIGINT       NOT NULL COMMENT '业务员ID',
  `appeal_reason` VARCHAR(1000) NOT NULL COMMENT '申诉理由',
  `appeal_files`  JSON         DEFAULT NULL COMMENT '申诉材料（URL数组）',
  `appeal_status` TINYINT      NOT NULL DEFAULT 0 COMMENT '0-待审核 1-通过 2-驳回',
  `review_remark` VARCHAR(500) DEFAULT NULL COMMENT '审核意见',
  `reviewer_id`   BIGINT       DEFAULT NULL COMMENT '审核人ID',
  `review_time`   DATETIME     DEFAULT NULL COMMENT '审核时间',
  `operator_id`   BIGINT       NOT NULL COMMENT '操作人（提交申诉的人）',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `tenant_id`     BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_tenant`   (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员黑名单申诉记录表';

-- -----------------------------------------------------------
-- 10. Excel 导入批次记录
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_import_log` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`     BIGINT       NOT NULL COMMENT '租户ID',
  `task_id`       VARCHAR(64)  NOT NULL COMMENT '任务ID（UUID）',
  `import_type`   TINYINT      NOT NULL COMMENT '导入类型：1-业务员 2-内勤',
  `file_name`     VARCHAR(200) NOT NULL COMMENT '原始文件名',
  `file_url`      VARCHAR(500) NOT NULL COMMENT '文件OSS地址',
  `status`        TINYINT      NOT NULL DEFAULT 0 COMMENT '状态：0-处理中 1-成功 2-部分失败 3-全部失败',
  `total_count`   INT          NOT NULL DEFAULT 0 COMMENT '总条数',
  `success_count` INT          NOT NULL DEFAULT 0 COMMENT '成功条数',
  `fail_count`    INT          NOT NULL DEFAULT 0 COMMENT '失败条数',
  `fail_file_url` VARCHAR(500) DEFAULT NULL COMMENT '失败数据文件URL',
  `operator_id`   BIGINT       NOT NULL COMMENT '操作人ID',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_id` (`task_id`),
  KEY `idx_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Excel批量导入日志表';

-- -----------------------------------------------------------
-- 11. 内勤人员表（区分业务员）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_staff` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id`          BIGINT       NOT NULL COMMENT '关联 system_users.id',
  `staff_code`       VARCHAR(32)  NOT NULL COMMENT '工号（全局唯一）',
  `real_name`        VARCHAR(50)  NOT NULL COMMENT '真实姓名',
  `gender`           TINYINT      NOT NULL DEFAULT 1 COMMENT '1-男 2-女',
  `id_card`          VARCHAR(300) NOT NULL COMMENT '身份证（AES加密）',
  `id_card_md5`      VARCHAR(64)  NOT NULL COMMENT '身份证 MD5（查重）',
  `mobile`           VARCHAR(20)  NOT NULL COMMENT '手机号',
  `email`            VARCHAR(100) DEFAULT NULL,
  `org_id`           BIGINT       NOT NULL COMMENT '所属机构ID',
  `dept_id`          BIGINT       DEFAULT NULL COMMENT '所属部门ID',
  `post_id`          BIGINT       DEFAULT NULL COMMENT '岗位ID',
  `entry_date`       DATE         NOT NULL COMMENT '入职日期',
  `leave_date`       DATE         DEFAULT NULL COMMENT '离职日期',
  `status`           TINYINT      NOT NULL DEFAULT 0 COMMENT '0-待激活 1-正常 2-停用 3-离职',
  `data_scope`       TINYINT      NOT NULL DEFAULT 2 COMMENT '数据权限：1-全部 2-本机构及子机构 3-本部门 4-仅本人',
  `creator`          VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`        BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_id`     (`user_id`, `deleted`),
  UNIQUE KEY `uk_staff_code`  (`staff_code`, `deleted`),
  UNIQUE KEY `uk_id_card_md5` (`id_card_md5`, `tenant_id`, `deleted`),
  KEY `idx_org_id`  (`org_id`),
  KEY `idx_status`  (`status`),
  KEY `idx_tenant`  (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='内勤人员表';

-- -----------------------------------------------------------
-- 12. 字段变更日志（银行卡/证件变更审计）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_change_log` (
  `id`           BIGINT       NOT NULL AUTO_INCREMENT,
  `agent_id`     BIGINT       NOT NULL COMMENT '业务员ID',
  `change_type`  VARCHAR(50)  NOT NULL COMMENT '变更类型：bank_account/id_card',
  `old_value`    VARCHAR(300) DEFAULT NULL COMMENT '旧值（脱敏）',
  `new_value`    VARCHAR(300) DEFAULT NULL COMMENT '新值（脱敏）',
  `operator_id`  BIGINT       NOT NULL COMMENT '操作人ID',
  `remark`       VARCHAR(300) DEFAULT NULL COMMENT '备注',
  `create_time`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`    BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_tenant`   (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员敏感字段变更日志';

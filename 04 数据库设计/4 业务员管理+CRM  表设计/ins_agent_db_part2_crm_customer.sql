-- ============================================================
-- intermediary-module-ins-agent 数据库建表脚本
-- Part 2: CRM 客户管理
-- Schema: db_ins_agent
-- 表前缀: ins_agent_
-- ============================================================

USE `db_ins_agent`;

-- -----------------------------------------------------------
-- 1. CRM 客户主表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_customer` (
  `id`                BIGINT       NOT NULL AUTO_INCREMENT COMMENT '客户ID',
  `customer_no`       VARCHAR(32)  NOT NULL COMMENT '客户编号（唯一，格式：CyyMMddNNNNN）',
  `name`              VARCHAR(100) NOT NULL COMMENT '客户姓名',
  `mobile`            VARCHAR(300) NOT NULL COMMENT '手机号（AES-256 加密存储）',
  `mobile_hash`       VARCHAR(64)  NOT NULL COMMENT '手机号 SHA256（用于搜索）',
  `mobile_suffix`     VARCHAR(4)   DEFAULT NULL COMMENT '手机号后4位明文（用于模糊搜索）',
  `spare_mobile1`     VARCHAR(300) DEFAULT NULL COMMENT '备用手机号1（AES加密）',
  `spare_mobile2`     VARCHAR(300) DEFAULT NULL COMMENT '备用手机号2（AES加密）',
  `id_card_type`      TINYINT      NOT NULL DEFAULT 1 COMMENT '证件类型：1-居民身份证 2-护照 3-港澳通行证 4-其他',
  `id_card`           VARCHAR(300) DEFAULT NULL COMMENT '证件号（AES-256 加密）',
  `id_card_md5`       VARCHAR(64)  DEFAULT NULL COMMENT '证件号 MD5（查重）',
  `id_card_last4`     VARCHAR(4)   DEFAULT NULL COMMENT '证件号后4位（搜索/展示）',
  `gender`            TINYINT      DEFAULT NULL COMMENT '性别：1-男 2-女 0-未知',
  `birthday`          DATE         DEFAULT NULL COMMENT '出生日期',
  `age`               INT          DEFAULT NULL COMMENT '年龄（周岁，定时更新）',
  `occupation`        VARCHAR(100) DEFAULT NULL COMMENT '职业名称',
  `occupation_class`  TINYINT      DEFAULT NULL COMMENT '职业类别：1/2/3/4类（影响核保）',
  `province_code`     VARCHAR(20)  DEFAULT NULL COMMENT '省代码',
  `city_code`         VARCHAR(20)  DEFAULT NULL COMMENT '市代码',
  `district_code`     VARCHAR(20)  DEFAULT NULL COMMENT '区代码',
  `address`           VARCHAR(300) DEFAULT NULL COMMENT '详细地址',
  `wechat`            VARCHAR(100) DEFAULT NULL COMMENT '微信号',
  `email`             VARCHAR(100) DEFAULT NULL COMMENT '邮箱',
  `agent_id`          BIGINT       NOT NULL COMMENT '归属业务员ID',
  `org_id`            BIGINT       NOT NULL COMMENT '归属机构ID',
  `source`            VARCHAR(50)  DEFAULT NULL COMMENT '客户来源：business_card/activity/referral/c_self_reg/import/other',
  `group_id`          BIGINT       DEFAULT NULL COMMENT '客户分组ID',
  `tags`              JSON         DEFAULT NULL COMMENT '标签数组（冗余，加速查询）',
  `customer_level`    VARCHAR(10)  DEFAULT 'normal' COMMENT '客户等级：normal/silver/gold/diamond',
  `status`            VARCHAR(20)  DEFAULT 'untouched' COMMENT '客户状态：untouched-未接触/contacted-已接触/closed-已成交/lost-已流失',
  `internal_code`     VARCHAR(100) DEFAULT NULL COMMENT '内部代码',
  `insurer_ids`       JSON         DEFAULT NULL COMMENT '归属保险公司（保险公司ID数组）',
  `car_plate_no`      VARCHAR(20)  DEFAULT NULL COMMENT '车牌号（车险客户）',
  `car_vin`           VARCHAR(50)  DEFAULT NULL COMMENT '车架号',
  `total_premium`     DECIMAL(15,2) NOT NULL DEFAULT 0 COMMENT '累计保费（有订单后更新）',
  `policy_count`      INT          NOT NULL DEFAULT 0 COMMENT '有效保单数量',
  `first_insure_date` DATE         DEFAULT NULL COMMENT '首次投保日期（冗余）',
  `last_follow_time`  DATETIME     DEFAULT NULL COMMENT '最后跟进时间',
  `next_follow_time`  DATETIME     DEFAULT NULL COMMENT '下次计划跟进时间',
  `remark`            TEXT         DEFAULT NULL COMMENT '备注',
  `is_high_net_worth` TINYINT      NOT NULL DEFAULT 0 COMMENT '是否高净值客户：0-否 1-是',
  `creator`           VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`           VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`           TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`         BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_customer_no` (`customer_no`, `deleted`),
  KEY `idx_mobile_hash` (`mobile_hash`, `tenant_id`),
  KEY `idx_mobile_suffix` (`mobile_suffix`, `tenant_id`),
  KEY `idx_id_card_last4` (`id_card_last4`, `tenant_id`),
  KEY `idx_agent_id`   (`agent_id`),
  KEY `idx_org_id`     (`org_id`),
  KEY `idx_status`     (`status`),
  KEY `idx_level`      (`customer_level`),
  KEY `idx_tenant`     (`tenant_id`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='CRM客户主表';

-- -----------------------------------------------------------
-- 2. 客户家庭成员表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_customer_family` (
  `id`          BIGINT       NOT NULL AUTO_INCREMENT,
  `customer_id` BIGINT       NOT NULL COMMENT '客户ID',
  `name`        VARCHAR(50)  NOT NULL COMMENT '家庭成员姓名',
  `relation`    VARCHAR(20)  NOT NULL COMMENT '关系：spouse/child/parent/sibling/other',
  `mobile`      VARCHAR(300) DEFAULT NULL COMMENT '手机号（AES加密）',
  `id_card_type` TINYINT     DEFAULT 1 COMMENT '证件类型',
  `id_card`     VARCHAR(300) DEFAULT NULL COMMENT '证件号（AES加密）',
  `birthday`    DATE         DEFAULT NULL COMMENT '出生日期',
  `gender`      TINYINT      DEFAULT NULL COMMENT '1-男 2-女',
  `remark`      VARCHAR(200) DEFAULT NULL,
  `creator`     VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`     VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`     TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`   BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_tenant`      (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户家庭成员表';

-- -----------------------------------------------------------
-- 3. 客户标签定义表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_tag` (
  `id`          BIGINT      NOT NULL AUTO_INCREMENT,
  `tag_name`    VARCHAR(50) NOT NULL COMMENT '标签名称',
  `tag_type`    TINYINT     NOT NULL DEFAULT 1 COMMENT '标签类型：1-系统预置 2-业务员自定义',
  `tag_color`   VARCHAR(20) DEFAULT NULL COMMENT '标签颜色（HEX）',
  `sort`        INT         NOT NULL DEFAULT 0 COMMENT '排序',
  `status`      TINYINT     NOT NULL DEFAULT 1 COMMENT '0-停用 1-启用',
  `creator`     VARCHAR(64) NOT NULL DEFAULT '',
  `create_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`     VARCHAR(64) NOT NULL DEFAULT '',
  `update_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`     TINYINT     NOT NULL DEFAULT 0,
  `tenant_id`   BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_tenant` (`tenant_id`),
  KEY `idx_type`   (`tag_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户标签定义表';

-- 初始化系统预置标签
INSERT INTO `ins_agent_tag` (`tag_name`, `tag_type`, `tag_color`, `sort`, `tenant_id`, `creator`)
VALUES
('已投保', 1, '#52c41a', 1, 0, 'system'),
('有意向', 1, '#1890ff', 2, 0, 'system'),
('犹豫中', 1, '#faad14', 3, 0, 'system'),
('无意向', 1, '#ff4d4f', 4, 0, 'system'),
('老客户', 1, '#722ed1', 5, 0, 'system'),
('高净值', 1, '#eb2f96', 6, 0, 'system'),
('转介绍', 1, '#13c2c2', 7, 0, 'system');

-- -----------------------------------------------------------
-- 4. 客户标签关联表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_customer_tag_rel` (
  `id`          BIGINT   NOT NULL AUTO_INCREMENT,
  `customer_id` BIGINT   NOT NULL COMMENT '客户ID',
  `tag_id`      BIGINT   NOT NULL COMMENT '标签ID',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`   BIGINT   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_customer_tag` (`customer_id`, `tag_id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_tag_id`      (`tag_id`),
  KEY `idx_tenant`      (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户标签关联表';

-- -----------------------------------------------------------
-- 5. 客户分组表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_customer_group` (
  `id`          BIGINT       NOT NULL AUTO_INCREMENT,
  `group_name`  VARCHAR(100) NOT NULL COMMENT '分组名称',
  `agent_id`    BIGINT       DEFAULT NULL COMMENT '创建人（业务员），NULL=全机构公共分组',
  `org_id`      BIGINT       NOT NULL COMMENT '所属机构',
  `remark`      VARCHAR(300) DEFAULT NULL COMMENT '备注',
  `sort`        INT          NOT NULL DEFAULT 0,
  `creator`     VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`     VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`     TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`   BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_org_id`   (`org_id`),
  KEY `idx_tenant`   (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户分组表';

-- -----------------------------------------------------------
-- 6. 客户跟进记录表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_follow_record` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT,
  `customer_id`      BIGINT       NOT NULL COMMENT '客户ID',
  `agent_id`         BIGINT       NOT NULL COMMENT '归属业务员ID（跟进记录归属方）',
  `operator_id`      BIGINT       NOT NULL COMMENT '实际操作人ID（代录时与agent_id不同）',
  `is_proxy`         TINYINT      NOT NULL DEFAULT 0 COMMENT '是否代录：0-否 1-是',
  `proxy_reason`     VARCHAR(300) DEFAULT NULL COMMENT '代录原因',
  `follow_type`      VARCHAR(20)  NOT NULL COMMENT '跟进方式：CALL/SMS/WECHAT/VISIT/OTHER',
  `attitude`         VARCHAR(20)  DEFAULT NULL COMMENT '客户态度：POSITIVE/NEUTRAL/NEGATIVE',
  `content`          VARCHAR(2000) NOT NULL COMMENT '跟进内容备注',
  `next_follow_date` DATE         DEFAULT NULL COMMENT '下次计划跟进日期',
  `is_send_quote`    TINYINT      NOT NULL DEFAULT 0 COMMENT '是否发送报价单：0-否 1-是',
  `attach_files`     JSON         DEFAULT NULL COMMENT '附件（图片/文件URL数组）',
  `creator`          VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`        BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_agent_id`    (`agent_id`),
  KEY `idx_create_time` (`create_time`),
  KEY `idx_tenant`      (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户跟进记录表';

-- -----------------------------------------------------------
-- 7. 客户移交轨迹表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_customer_transfer` (
  `id`          BIGINT       NOT NULL AUTO_INCREMENT,
  `customer_id` BIGINT       NOT NULL COMMENT '客户ID',
  `from_agent_id` BIGINT     DEFAULT NULL COMMENT '原业务员ID',
  `to_agent_id`  BIGINT      NOT NULL COMMENT '目标业务员ID',
  `from_org_id`  BIGINT      DEFAULT NULL COMMENT '原机构ID',
  `to_org_id`    BIGINT      NOT NULL COMMENT '目标机构ID',
  `reason`       VARCHAR(300) DEFAULT NULL COMMENT '移交原因',
  `operator_id`  BIGINT      NOT NULL COMMENT '操作人ID',
  `create_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`    BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_customer_id`  (`customer_id`),
  KEY `idx_from_agent`   (`from_agent_id`),
  KEY `idx_to_agent`     (`to_agent_id`),
  KEY `idx_tenant`       (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户移交轨迹表';

-- -----------------------------------------------------------
-- 8. 客户导入批次管理表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_customer_import_batch` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`     BIGINT       NOT NULL,
  `batch_no`      VARCHAR(64)  NOT NULL COMMENT '批次号（UUID）',
  `file_name`     VARCHAR(200) NOT NULL COMMENT '原始文件名',
  `file_url`      VARCHAR(500) NOT NULL COMMENT '文件OSS地址',
  `status`        TINYINT      NOT NULL DEFAULT 0 COMMENT '状态：0-处理中 1-完成 2-部分失败',
  `total_count`   INT          NOT NULL DEFAULT 0 COMMENT '总行数',
  `new_count`     INT          NOT NULL DEFAULT 0 COMMENT '新建数量',
  `update_count`  INT          NOT NULL DEFAULT 0 COMMENT '更新数量',
  `skip_count`    INT          NOT NULL DEFAULT 0 COMMENT '跳过数量',
  `fail_count`    INT          NOT NULL DEFAULT 0 COMMENT '失败数量',
  `fail_file_url` VARCHAR(500) DEFAULT NULL COMMENT '失败明细文件URL',
  `operator_id`   BIGINT       NOT NULL COMMENT '操作人ID',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`),
  KEY `idx_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户导入批次管理表';

-- -----------------------------------------------------------
-- 9. 筛选场景（客户搜索快捷入口）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_customer_search_scene` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT,
  `user_id`       BIGINT       NOT NULL COMMENT '操作人ID（场景归属）',
  `scene_name`    VARCHAR(100) NOT NULL COMMENT '筛选场景名称',
  `filter_params` JSON         NOT NULL COMMENT '筛选条件JSON',
  `scene_type`    TINYINT      NOT NULL DEFAULT 1 COMMENT '1-全部客户 2-我的客户 3-客户画像',
  `sort`          INT          NOT NULL DEFAULT 0 COMMENT '排序',
  `creator`       VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`       VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`       TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`     BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_tenant`  (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户搜索筛选场景表';

-- -----------------------------------------------------------
-- 10. 客户批量报价任务表（来自"我的客户"批量报价）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_batch_quote_task` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT,
  `task_no`        VARCHAR(64)  NOT NULL COMMENT '任务编号（UUID）',
  `agent_id`       BIGINT       NOT NULL COMMENT '报价工号业务员ID',
  `city_code`      VARCHAR(20)  NOT NULL COMMENT '投保城市代码',
  `customer_ids`   JSON         NOT NULL COMMENT '客户ID列表',
  `total_count`    INT          NOT NULL DEFAULT 0 COMMENT '总数',
  `done_count`     INT          NOT NULL DEFAULT 0 COMMENT '已完成',
  `fail_count`     INT          NOT NULL DEFAULT 0 COMMENT '失败数',
  `status`         TINYINT      NOT NULL DEFAULT 0 COMMENT '0-处理中 1-完成 2-部分失败',
  `result_url`     VARCHAR(500) DEFAULT NULL COMMENT '结果文件URL',
  `operator_id`    BIGINT       NOT NULL COMMENT '操作人ID',
  `create_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `tenant_id`      BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_no` (`task_no`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_tenant`   (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户批量报价任务表';

-- -----------------------------------------------------------
-- 11. 产品推荐规则表（客户画像-推荐险种用）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_product_recommend_rule` (
  `id`                 BIGINT       NOT NULL AUTO_INCREMENT,
  `rule_name`          VARCHAR(100) NOT NULL COMMENT '规则名称',
  `if_policy_type`     VARCHAR(50)  NOT NULL COMMENT '已持有险种类型',
  `then_product_type`  VARCHAR(50)  NOT NULL COMMENT '推荐险种类型',
  `recommend_reason`   VARCHAR(200) DEFAULT NULL COMMENT '推荐理由文案',
  `sort`               INT          NOT NULL DEFAULT 0,
  `status`             TINYINT      NOT NULL DEFAULT 1 COMMENT '0-停用 1-启用',
  `creator`            VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`            VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`            TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`          BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='产品推荐规则表（客户画像）';

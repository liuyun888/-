-- ============================================================
-- intermediary-module-ins-agent 数据库建表脚本
-- Part 3: 续期管理 / 云短信 / 企业微信 / 业绩统计
-- Schema: db_ins_agent
-- 表前缀: ins_agent_
-- ============================================================

USE `db_ins_agent`;

-- -----------------------------------------------------------
-- 1. 续期任务表（到期保单 × 跟进状态）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_renewal_task` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  `tenant_id`        BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
  `policy_id`        BIGINT       NOT NULL COMMENT '关联保单ID（跨模块引用）',
  `policy_no`        VARCHAR(64)  NOT NULL COMMENT '保单号（冗余）',
  `policy_type`      VARCHAR(20)  NOT NULL COMMENT '险种类型：car/non_car/life',
  `customer_id`      BIGINT       NOT NULL COMMENT '客户ID',
  `customer_name`    VARCHAR(50)  NOT NULL COMMENT '客户姓名（冗余）',
  `agent_id`         BIGINT       NOT NULL COMMENT '归属业务员ID',
  `org_id`           BIGINT       NOT NULL COMMENT '归属机构ID',
  `insurer_name`     VARCHAR(100) DEFAULT NULL COMMENT '保险公司名称（冗余）',
  `expiry_date`      DATE         NOT NULL COMMENT '保单到期日',
  `premium`          DECIMAL(12,2) DEFAULT NULL COMMENT '原保费',
  `status`           VARCHAR(20)  NOT NULL DEFAULT 'pending' COMMENT '续保状态：pending-未跟进/following-跟进中/closed-已成交/lost-已流失',
  `last_follow_time` DATETIME     DEFAULT NULL COMMENT '最近跟进时间',
  `last_follow_remark` VARCHAR(500) DEFAULT NULL COMMENT '最近跟进摘要',
  `renewal_policy_id` BIGINT      DEFAULT NULL COMMENT '续保后新保单ID（成交后关联）',
  `assign_time`      DATETIME     DEFAULT NULL COMMENT '分配时间',
  `assign_operator`  BIGINT       DEFAULT NULL COMMENT '分配操作人ID',
  `creator`          VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_policy_tenant` (`policy_id`, `tenant_id`, `deleted`),
  KEY `idx_agent_id`    (`agent_id`),
  KEY `idx_org_id`      (`org_id`),
  KEY `idx_expiry_date` (`expiry_date`),
  KEY `idx_status`      (`status`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_tenant`      (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='续期任务表（保单续保跟进管理）';

-- -----------------------------------------------------------
-- 2. 续期看板统计缓存表（T+1，每天凌晨汇总）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_renewal_board_stat` (
  `id`           BIGINT      NOT NULL AUTO_INCREMENT,
  `tenant_id`    BIGINT      NOT NULL DEFAULT 0,
  `stat_date`    DATE        NOT NULL COMMENT '统计日期',
  `scope_type`   TINYINT     NOT NULL COMMENT '统计范围：1-全商户 2-机构',
  `scope_id`     BIGINT      NOT NULL DEFAULT 0 COMMENT '范围ID（全商户时=0，机构时=org_id）',
  `policy_type`  VARCHAR(20) NOT NULL DEFAULT 'all' COMMENT '险种：all/car/non_car/life',
  `stat_dim`     VARCHAR(10) NOT NULL COMMENT '统计维度：vehicle/policy/premium',
  `stat_year`    YEAR        NOT NULL COMMENT '统计年份',
  `stat_month`   TINYINT     NOT NULL COMMENT '统计月份（1-12）',
  `total_cnt`    INT         NOT NULL DEFAULT 0 COMMENT '应续保总量',
  `renewed_cnt`  INT         NOT NULL DEFAULT 0 COMMENT '已续保量',
  `renewed_rate` DECIMAL(5,4) NOT NULL DEFAULT 0 COMMENT '续保率',
  `renewed_premium` DECIMAL(15,2) NOT NULL DEFAULT 0 COMMENT '续保保费',
  `create_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_stat` (`tenant_id`, `stat_date`, `scope_type`, `scope_id`, `policy_type`, `stat_dim`, `stat_year`, `stat_month`),
  KEY `idx_tenant_date` (`tenant_id`, `stat_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='续期看板统计缓存表（T+1）';

-- -----------------------------------------------------------
-- 3. 云短信模板表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_sms_template` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT,
  `template_name`    VARCHAR(100) NOT NULL COMMENT '模板名称',
  `template_content` VARCHAR(1000) NOT NULL COMMENT '模板内容（支持 {name} 等占位符）',
  `scene_type`       VARCHAR(50)  DEFAULT NULL COMMENT '适用场景：renewal/activity/birthday/custom',
  `status`           TINYINT      NOT NULL DEFAULT 1 COMMENT '0-停用 1-启用',
  `use_count`        INT          NOT NULL DEFAULT 0 COMMENT '使用次数',
  `sort`             INT          NOT NULL DEFAULT 0 COMMENT '排序',
  `is_system`        TINYINT      NOT NULL DEFAULT 0 COMMENT '是否系统预置：0-自定义 1-预置',
  `creator`          VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`        BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_tenant` (`tenant_id`),
  KEY `idx_scene`  (`scene_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='云短信模板表';

-- -----------------------------------------------------------
-- 4. 云短信发送任务表（批量发送任务）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_sms_send_task` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT,
  `task_no`       VARCHAR(64)  NOT NULL COMMENT '任务编号（UUID）',
  `task_name`     VARCHAR(100) NOT NULL COMMENT '任务名称',
  `template_id`   BIGINT       NOT NULL COMMENT '使用的短信模板ID',
  `customer_ids`  JSON         NOT NULL COMMENT '目标客户ID列表',
  `total_count`   INT          NOT NULL DEFAULT 0 COMMENT '发送总数',
  `success_count` INT          NOT NULL DEFAULT 0 COMMENT '成功数',
  `fail_count`    INT          NOT NULL DEFAULT 0 COMMENT '失败数',
  `status`        VARCHAR(20)  NOT NULL DEFAULT 'PENDING' COMMENT '任务状态：PENDING/RUNNING/DONE/CANCEL/FAILED',
  `send_time`     DATETIME     DEFAULT NULL COMMENT '计划发送时间（为NULL则立即发送）',
  `finish_time`   DATETIME     DEFAULT NULL COMMENT '完成时间',
  `cancel_reason` VARCHAR(300) DEFAULT NULL COMMENT '撤销原因',
  `operator_id`   BIGINT       NOT NULL COMMENT '操作人ID',
  `creator`       VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`       VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`       TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`     BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_no` (`task_no`),
  KEY `idx_status`  (`status`),
  KEY `idx_tenant`  (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='云短信发送任务表';

-- -----------------------------------------------------------
-- 5. 云短信发送记录表（逐条记录）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_sms_log` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT,
  `task_id`       BIGINT       NOT NULL COMMENT '所属任务ID',
  `customer_id`   BIGINT       NOT NULL COMMENT '客户ID',
  `customer_name` VARCHAR(50)  NOT NULL COMMENT '客户姓名（冗余）',
  `mobile`        VARCHAR(20)  NOT NULL COMMENT '手机号（脱敏存储：138****8888）',
  `content`       VARCHAR(1000) NOT NULL COMMENT '实际发送内容（占位符替换后）',
  `send_status`   TINYINT      NOT NULL DEFAULT 0 COMMENT '状态：0-待发送 1-发送成功 2-发送失败',
  `fail_reason`   VARCHAR(300) DEFAULT NULL COMMENT '失败原因',
  `third_msg_id`  VARCHAR(100) DEFAULT NULL COMMENT '第三方短信平台消息ID',
  `send_time`     DATETIME     DEFAULT NULL COMMENT '实际发送时间',
  `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`     BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_task_id`     (`task_id`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_send_status` (`send_status`),
  KEY `idx_tenant`      (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='云短信发送记录表';

-- -----------------------------------------------------------
-- 6. 短信黑名单（退订回调写入）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_sms_blacklist` (
  `id`              BIGINT      NOT NULL AUTO_INCREMENT,
  `mobile`          VARCHAR(20) NOT NULL COMMENT '手机号（明文）',
  `unsubscribe_time` DATETIME   NOT NULL COMMENT '退订时间',
  `source`          VARCHAR(50) DEFAULT NULL COMMENT '来源：operator/user_request',
  `create_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`       BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mobile_tenant` (`mobile`, `tenant_id`),
  KEY `idx_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='短信黑名单表（退订）';

-- -----------------------------------------------------------
-- 7. 短信系统设置表（每租户一条）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_sms_setting` (
  `id`                  BIGINT      NOT NULL AUTO_INCREMENT,
  `tenant_id`           BIGINT      NOT NULL DEFAULT 0 COMMENT '租户ID（UNIQUE）',
  `sms_provider`        VARCHAR(50) DEFAULT 'aliyun' COMMENT '短信服务商：aliyun/tencent',
  `daily_limit_per_no`  INT         NOT NULL DEFAULT 3 COMMENT '单号每日上限',
  `send_time_start`     VARCHAR(5)  NOT NULL DEFAULT '08:00' COMMENT '允许发送开始时间（HH:mm）',
  `send_time_end`       VARCHAR(5)  NOT NULL DEFAULT '21:00' COMMENT '允许发送结束时间（HH:mm）',
  `enable_birthday_sms` TINYINT     NOT NULL DEFAULT 1 COMMENT '是否开启生日祝福短信',
  `enable_renewal_sms`  TINYINT     NOT NULL DEFAULT 1 COMMENT '是否开启续期提醒短信',
  `enable_resource_type` TINYINT    NOT NULL DEFAULT 0 COMMENT '是否启用资源类型（运营商要求）',
  `update_time`         DATETIME,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='短信系统设置表（每租户一条）';

-- -----------------------------------------------------------
-- 8. 企业微信对接配置表
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_wxwork_config` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
  `corp_id`         VARCHAR(100) DEFAULT NULL COMMENT '企业ID',
  `agent_id`        VARCHAR(50)  DEFAULT NULL COMMENT '企业应用ID',
  `app_secret`      VARCHAR(300) DEFAULT NULL COMMENT '企业应用Secret（AES加密）',
  `webhook_url`     VARCHAR(500) DEFAULT NULL COMMENT '企业微信群机器人 Webhook URL',
  `is_enabled`      TINYINT      NOT NULL DEFAULT 0 COMMENT '0-未启用 1-已启用',
  `sync_customer`   TINYINT      NOT NULL DEFAULT 1 COMMENT '是否同步外部联系人（客户）：0-否 1-是',
  `sync_interval_h` INT          NOT NULL DEFAULT 4 COMMENT '同步间隔（小时）',
  `creator`         VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant` (`tenant_id`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='企业微信对接配置表';

-- -----------------------------------------------------------
-- 9. 企业微信消息发送记录
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_wxwork_msg_log` (
  `id`           BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`    BIGINT       NOT NULL DEFAULT 0,
  `to_user_ids`  JSON         NOT NULL COMMENT '目标用户ID列表（企业微信）',
  `msg_type`     VARCHAR(20)  NOT NULL COMMENT '消息类型：text/markdown/card',
  `msg_content`  TEXT         NOT NULL COMMENT '消息内容',
  `biz_type`     VARCHAR(50)  DEFAULT NULL COMMENT '业务类型：renewal_remind/task_assign/cert_expire',
  `biz_id`       BIGINT       DEFAULT NULL COMMENT '业务ID（如续期任务ID）',
  `send_status`  TINYINT      NOT NULL DEFAULT 0 COMMENT '0-待发送 1-成功 2-失败',
  `fail_reason`  VARCHAR(300) DEFAULT NULL,
  `send_time`    DATETIME     DEFAULT NULL COMMENT '实际发送时间',
  `create_time`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_biz_type_id` (`biz_type`, `biz_id`),
  KEY `idx_tenant`      (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='企业微信消息发送记录';

-- -----------------------------------------------------------
-- 10. 业绩统计汇总表（T+1，按业务员/月维度）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_performance_stat` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0,
  `stat_year`       YEAR         NOT NULL COMMENT '年份',
  `stat_month`      TINYINT      NOT NULL COMMENT '月份（1-12）',
  `agent_id`        BIGINT       NOT NULL COMMENT '业务员ID',
  `org_id`          BIGINT       NOT NULL COMMENT '机构ID',
  `new_customer_cnt` INT         NOT NULL DEFAULT 0 COMMENT '新增客户数',
  `follow_cnt`      INT          NOT NULL DEFAULT 0 COMMENT '跟进次数',
  `quote_cnt`       INT          NOT NULL DEFAULT 0 COMMENT '出单报价次数',
  `policy_cnt`      INT          NOT NULL DEFAULT 0 COMMENT '成单保单数',
  `total_premium`   DECIMAL(15,2) NOT NULL DEFAULT 0 COMMENT '签单保费合计',
  `renewal_cnt`     INT          NOT NULL DEFAULT 0 COMMENT '续保单数',
  `renewal_premium` DECIMAL(15,2) NOT NULL DEFAULT 0 COMMENT '续保保费合计',
  `target_premium`  DECIMAL(15,2) NOT NULL DEFAULT 0 COMMENT '业绩目标保费',
  `achievement_rate` DECIMAL(5,4) NOT NULL DEFAULT 0 COMMENT '目标达成率',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_month` (`tenant_id`, `agent_id`, `stat_year`, `stat_month`),
  KEY `idx_org_id`     (`org_id`),
  KEY `idx_stat_month` (`tenant_id`, `stat_year`, `stat_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员业绩统计汇总表（T+1）';

-- -----------------------------------------------------------
-- 11. 业绩目标设置表（按机构/业务员/月维度）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_performance_target` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`      BIGINT       NOT NULL DEFAULT 0,
  `target_year`    YEAR         NOT NULL COMMENT '目标年份',
  `target_month`   TINYINT      NOT NULL COMMENT '目标月份（0=全年目标）',
  `target_type`    TINYINT      NOT NULL COMMENT '维度：1-机构 2-业务员',
  `target_id`      BIGINT       NOT NULL COMMENT '机构ID或业务员ID',
  `target_premium` DECIMAL(15,2) NOT NULL DEFAULT 0 COMMENT '目标保费',
  `target_policy_cnt` INT       NOT NULL DEFAULT 0 COMMENT '目标件数',
  `operator_id`    BIGINT       NOT NULL COMMENT '操作人ID',
  `creator`        VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`        VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`        TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_target` (`tenant_id`, `target_year`, `target_month`, `target_type`, `target_id`, `deleted`),
  KEY `idx_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业绩目标设置表';

-- -----------------------------------------------------------
-- 12. 员工呼出统计表（企业微信/电话记录汇总，T+1）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_call_stat` (
  `id`           BIGINT  NOT NULL AUTO_INCREMENT,
  `tenant_id`    BIGINT  NOT NULL DEFAULT 0,
  `stat_date`    DATE    NOT NULL COMMENT '统计日期',
  `agent_id`     BIGINT  NOT NULL COMMENT '业务员ID',
  `org_id`       BIGINT  NOT NULL COMMENT '机构ID',
  `call_cnt`     INT     NOT NULL DEFAULT 0 COMMENT '电话呼出次数',
  `call_duration` INT    NOT NULL DEFAULT 0 COMMENT '总通话时长（秒）',
  `sms_cnt`      INT     NOT NULL DEFAULT 0 COMMENT '短信发送次数',
  `wxwork_cnt`   INT     NOT NULL DEFAULT 0 COMMENT '企微消息数',
  `create_time`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_date` (`tenant_id`, `agent_id`, `stat_date`),
  KEY `idx_org_date` (`tenant_id`, `org_id`, `stat_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='员工呼出统计表（T+1）';

-- -----------------------------------------------------------
-- 13. 运营监控告警配置（管理员配置告警阈值）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_monitor_alert_config` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0,
  `alert_metric`    VARCHAR(50)  NOT NULL COMMENT '监控指标：follow_rate/renewal_rate/new_customer_cnt/sms_fail_rate',
  `scope_type`      TINYINT      NOT NULL COMMENT '作用范围：1-全商户 2-机构',
  `scope_id`        BIGINT       NOT NULL DEFAULT 0 COMMENT '机构ID（全商户=0）',
  `alert_operator`  VARCHAR(10)  NOT NULL DEFAULT 'lt' COMMENT '比较运算：lt-低于/gt-高于',
  `threshold`       DECIMAL(10,4) NOT NULL COMMENT '告警阈值',
  `alert_channels`  JSON         NOT NULL COMMENT '告警渠道：[\"WXWORK\",\"EMAIL\",\"SMS\"]',
  `notify_user_ids` JSON         NOT NULL COMMENT '通知人员ID列表',
  `is_enabled`      TINYINT      NOT NULL DEFAULT 1 COMMENT '0-停用 1-启用',
  `creator`         VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_tenant`  (`tenant_id`),
  KEY `idx_metric`  (`alert_metric`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运营监控告警配置表';

-- -----------------------------------------------------------
-- 14. 客户设置表（超期未跟进阈值等，每租户一条）
-- -----------------------------------------------------------
CREATE TABLE `ins_agent_customer_setting` (
  `id`                       BIGINT  NOT NULL AUTO_INCREMENT,
  `tenant_id`                BIGINT  NOT NULL DEFAULT 0,
  `follow_overdue_days`      INT     NOT NULL DEFAULT 7 COMMENT '超期未跟进阈值（天），超过则红色预警',
  `auto_reclaim_days`        INT     NOT NULL DEFAULT 90 COMMENT '客户自动回收天数（0=不自动回收）',
  `renewal_remind_days_1`    INT     NOT NULL DEFAULT 30 COMMENT '续期提醒节点1（天前）',
  `renewal_remind_days_2`    INT     NOT NULL DEFAULT 15 COMMENT '续期提醒节点2',
  `renewal_remind_days_3`    INT     NOT NULL DEFAULT 7 COMMENT '续期提醒节点3',
  `enable_birthday_notify`   TINYINT NOT NULL DEFAULT 1 COMMENT '是否开启生日提醒：0-否 1-是',
  `birthday_notify_days`     INT     NOT NULL DEFAULT 3 COMMENT '生日提前提醒天数',
  `update_time`              DATETIME,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户管理系统设置（每租户一条）';

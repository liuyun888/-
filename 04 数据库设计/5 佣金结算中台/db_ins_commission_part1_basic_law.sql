-- =====================================================
-- 保险中介平台 · 佣金结算中台数据库设计
-- 模块: intermediary-module-ins-commission
-- Schema: db_ins_commission
-- 表前缀: ins_comm_
-- 文档版本: V1.0 | 日期: 2026-03-01
-- 对应阶段: 阶段2-PC管理后台-佣金系统（上篇+补充篇A/B）
-- Part 1: 基本法配置 + 佣金规则引擎
-- =====================================================

CREATE DATABASE IF NOT EXISTS `db_ins_commission`
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE `db_ins_commission`;

-- =====================================================
-- 1. ins_comm_basic_law  基本法主表（职级体系/版本管理）
-- 每家机构/公司可配置多套基本法，通过版本管理生效
-- 对应需求: 上篇 §2.1 职级体系管理
-- =====================================================
CREATE TABLE `ins_comm_basic_law` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `law_code`        varchar(64)   NOT NULL                               COMMENT '基本法编码（唯一）',
  `law_name`        varchar(128)  NOT NULL                               COMMENT '基本法名称，如：2026版标准基本法',
  `product_category` varchar(32)  NOT NULL                               COMMENT '险种范围: ALL/CAR/NON_CAR/LIFE',
  `version`         varchar(32)   NOT NULL                               COMMENT '版本号，如：v2.0',
  `effective_date`  date          NOT NULL                               COMMENT '生效日期',
  `expire_date`     date          DEFAULT NULL                           COMMENT '失效日期（NULL=长期有效）',
  `status`          tinyint(1)    NOT NULL DEFAULT 1                     COMMENT '状态: 1启用 0停用',
  `remark`          varchar(500)  DEFAULT NULL                           COMMENT '备注',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除: 0未删 1已删',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_law_code` (`law_code`, `tenant_id`),
  KEY `idx_product_category` (`product_category`),
  KEY `idx_effective_date` (`effective_date`, `expire_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='基本法主表（职级体系/版本管理）';


-- =====================================================
-- 2. ins_comm_rank  职级体系配置表
-- 配置职级名称、晋升规则、FYP门槛等
-- 对应需求: 上篇 §2.1 职级体系管理
-- =====================================================
CREATE TABLE `ins_comm_rank` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `basic_law_id`    bigint(20)    NOT NULL                               COMMENT '基本法ID（关联ins_comm_basic_law）',
  `rank_code`       varchar(32)   NOT NULL                               COMMENT '职级编码，如：J1/J2/M1/M2',
  `rank_name`       varchar(64)   NOT NULL                               COMMENT '职级名称，如：见习业务员/正式业务员/主任',
  `rank_level`      int           NOT NULL                               COMMENT '职级层级（数字越大级别越高，1起）',
  `rank_type`       varchar(32)   NOT NULL DEFAULT 'AGENT'               COMMENT '职级类型: AGENT业务员 MANAGER主任 DIRECTOR总监',
  `fyp_threshold`   decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '晋升所需最低FYP（首年保费当量，元）',
  `ryp_threshold`   decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '晋升所需最低RYP（续年保费，元）',
  `team_size`       int           NOT NULL DEFAULT 0                     COMMENT '晋升所需最低团队人数（0=无要求）',
  `fyc_rate`        decimal(8,4)  NOT NULL DEFAULT 0                    COMMENT 'FYC基础比例（首年佣金率，百分比小数，如0.30=30%）',
  `ryc_rate`        decimal(8,4)  NOT NULL DEFAULT 0                    COMMENT 'RYC续期佣金率',
  `override_rate`   decimal(8,4)  NOT NULL DEFAULT 0                    COMMENT '管理津贴提取比例（对下属FYC的分润比例）',
  `allowance_config` json         DEFAULT NULL                           COMMENT '津贴配置JSON（育成奖/伯乐奖等）',
  `bonus_config`    json          DEFAULT NULL                           COMMENT '奖励规则JSON（季度奖/年度奖）',
  `status`          tinyint(1)    NOT NULL DEFAULT 1                     COMMENT '状态: 1启用 0停用',
  `sort_order`      int           NOT NULL DEFAULT 0                     COMMENT '排序值（升序）',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_law_rank` (`basic_law_id`, `rank_code`, `tenant_id`),
  KEY `idx_basic_law_id` (`basic_law_id`),
  KEY `idx_rank_level` (`rank_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='职级体系配置表';


-- =====================================================
-- 3. ins_comm_rank_promotion_rule  晋升规则配置表
-- 精细化配置每个职级的晋升条件（可配多个条件，AND关系）
-- 对应需求: 上篇 §2.2 晋升规则配置
-- =====================================================
CREATE TABLE `ins_comm_rank_promotion_rule` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `rank_id`         bigint(20)    NOT NULL                               COMMENT '目标职级ID（关联ins_comm_rank）',
  `from_rank_id`    bigint(20)    DEFAULT NULL                           COMMENT '来源职级ID（NULL=任意职级均可晋升）',
  `rule_name`       varchar(128)  NOT NULL                               COMMENT '规则名称',
  `condition_type`  varchar(32)   NOT NULL                               COMMENT '条件类型: FYP/RYP/TEAM_SIZE/ACTIVE_MONTH/SELF_POLICY',
  `condition_operator` varchar(16) NOT NULL DEFAULT 'GTE'               COMMENT '比较运算: GTE>=  GT>  EQ=',
  `condition_value` decimal(14,2) NOT NULL                               COMMENT '条件阈值',
  `stat_period`     varchar(16)   DEFAULT 'MONTHLY'                     COMMENT '统计周期: MONTHLY/QUARTERLY/YEARLY',
  `continuous_months` int         DEFAULT 1                              COMMENT '需连续满足的月数',
  `remark`          varchar(500)  DEFAULT NULL                           COMMENT '备注说明',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_rank_id` (`rank_id`),
  KEY `idx_from_rank_id` (`from_rank_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='职级晋升规则配置表';


-- =====================================================
-- 4. ins_comm_allowance_config  津贴配置表
-- 配置管理津贴/育成奖/伯乐奖等非常规佣金
-- 对应需求: 上篇 §2.4 津贴配置
-- =====================================================
CREATE TABLE `ins_comm_allowance_config` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `basic_law_id`    bigint(20)    NOT NULL                               COMMENT '基本法ID',
  `rank_id`         bigint(20)    DEFAULT NULL                           COMMENT '关联职级ID（NULL=全职级适用）',
  `allowance_type`  varchar(32)   NOT NULL                               COMMENT '津贴类型: MANAGEMENT管理津贴 NURTURE育成奖 TALENT伯乐奖 QUARTER季度奖 ANNUAL年度奖',
  `allowance_name`  varchar(64)   NOT NULL                               COMMENT '津贴名称',
  `calc_basis`      varchar(32)   NOT NULL DEFAULT 'FYC'                 COMMENT '计算基础: FYC/RYC/FYP/PREMIUM',
  `calc_rate`       decimal(8,4)  DEFAULT NULL                           COMMENT '计算比例（百分比小数）',
  `calc_amount`     decimal(14,2) DEFAULT NULL                           COMMENT '固定金额（与calc_rate二选一）',
  `trigger_condition` json        DEFAULT NULL                           COMMENT '触发条件JSON（如育成奖：下属首单FYC达到N元）',
  `max_amount`      decimal(14,2) DEFAULT NULL                           COMMENT '单次最大发放金额（NULL=无上限）',
  `effective_date`  date          NOT NULL                               COMMENT '生效日期',
  `expire_date`     date          DEFAULT NULL                           COMMENT '失效日期',
  `status`          tinyint(1)    NOT NULL DEFAULT 1                     COMMENT '状态',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_basic_law_id` (`basic_law_id`),
  KEY `idx_rank_id` (`rank_id`),
  KEY `idx_allowance_type` (`allowance_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='津贴配置表（管理津贴/育成奖/伯乐奖/季度年度奖）';


-- =====================================================
-- 5. ins_comm_rule  佣金规则表
-- 存储 Groovy 脚本或 JSON 规则，支持版本管理
-- 对应需求: 上篇 §3.1 佣金规则库维护
-- =====================================================
CREATE TABLE `ins_comm_rule` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `rule_code`       varchar(64)   NOT NULL                               COMMENT '规则编码（全局唯一）',
  `rule_name`       varchar(128)  NOT NULL                               COMMENT '规则名称',
  `rule_version`    varchar(32)   NOT NULL DEFAULT 'v1.0'               COMMENT '规则版本号',
  `product_category` varchar(32)  NOT NULL                               COMMENT '适用险种: ALL/CAR/NON_CAR/LIFE',
  `commission_type` varchar(32)   NOT NULL                               COMMENT '佣金类型: FYC/RYC/OVERRIDE/BONUS/REFUND',
  `insurance_company_code` varchar(64) DEFAULT NULL                      COMMENT '保险公司编码（NULL=通用规则）',
  `rank_codes`      varchar(512)  DEFAULT NULL                           COMMENT '适用职级编码（逗号分隔，NULL=全职级）',
  `script_type`     varchar(16)   NOT NULL DEFAULT 'GROOVY'              COMMENT '脚本类型: GROOVY/JSON_RULE',
  `rule_script`     mediumtext    NOT NULL                               COMMENT 'Groovy脚本或JSON规则内容',
  `input_params`    json          DEFAULT NULL                           COMMENT '入参说明JSON（文档用途）',
  `output_params`   json          DEFAULT NULL                           COMMENT '出参说明JSON（文档用途）',
  `is_latest`       tinyint(1)    NOT NULL DEFAULT 1                     COMMENT '是否为最新版本: 1是 0否（历史版本）',
  `effective_date`  date          NOT NULL                               COMMENT '生效日期',
  `expire_date`     date          DEFAULT NULL                           COMMENT '失效日期',
  `test_case`       text          DEFAULT NULL                           COMMENT '测试用例JSON（回归测试）',
  `status`          tinyint(1)    NOT NULL DEFAULT 1                     COMMENT '状态: 1启用 0停用',
  `remark`          varchar(500)  DEFAULT NULL                           COMMENT '规则说明',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rule_code_version` (`rule_code`, `rule_version`, `tenant_id`),
  KEY `idx_product_category` (`product_category`),
  KEY `idx_commission_type` (`commission_type`),
  KEY `idx_is_latest` (`is_latest`),
  KEY `idx_effective_date` (`effective_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金规则表（Groovy脚本/JSON规则/版本管理）';


-- =====================================================
-- 6. ins_comm_rate_history  佣金比例变更历史表
-- 记录所有佣金相关配置的变更记录，合规审计用
-- 对应需求: 上篇 §2.3 佣金比例配置 + 补充篇A 留点政策变更历史
-- =====================================================
CREATE TABLE `ins_comm_rate_history` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `biz_type`        varchar(32)   NOT NULL                               COMMENT '业务类型: RANK_RATE职级佣金率 POINT_CONFIG留点政策 EXTRA_POINT加投点 MULTILEVEL多级结算',
  `biz_id`          bigint(20)    NOT NULL                               COMMENT '业务数据ID（对应各配置表主键）',
  `change_type`     varchar(16)   NOT NULL                               COMMENT '变更类型: CREATE/UPDATE/DISABLE',
  `field_name`      varchar(64)   DEFAULT NULL                           COMMENT '变更字段名',
  `old_value`       text          DEFAULT NULL                           COMMENT '变更前值',
  `new_value`       text          DEFAULT NULL                           COMMENT '变更后值',
  `change_reason`   varchar(500)  NOT NULL                               COMMENT '变更原因（必填）',
  `operator_id`     bigint(20)    NOT NULL                               COMMENT '操作人ID',
  `operator_name`   varchar(64)   NOT NULL                               COMMENT '操作人姓名',
  `operate_time`    datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '操作时间',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_biz_type_id` (`biz_type`, `biz_id`),
  KEY `idx_operate_time` (`operate_time`),
  KEY `idx_operator_id` (`operator_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金比例变更历史表（合规审计）';


-- =====================================================
-- 7. ins_comm_agent_rank_snapshot  业务员职级快照表
-- 记录业务员每月的职级状态，用于佣金计算时的历史回溯
-- 对应需求: 上篇 §2.1 职级体系（历史快照）
-- =====================================================
CREATE TABLE `ins_comm_agent_rank_snapshot` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `agent_id`        bigint(20)    NOT NULL                               COMMENT '业务员ID（关联sys_user）',
  `agent_code`      varchar(64)   NOT NULL                               COMMENT '业务员工号',
  `rank_id`         bigint(20)    NOT NULL                               COMMENT '职级ID',
  `rank_code`       varchar(32)   NOT NULL                               COMMENT '职级编码（冗余快照）',
  `rank_name`       varchar(64)   NOT NULL                               COMMENT '职级名称（冗余快照）',
  `snapshot_month`  varchar(7)    NOT NULL                               COMMENT '快照月份，格式: YYYY-MM',
  `fyc_rate`        decimal(8,4)  NOT NULL                               COMMENT 'FYC佣金率快照',
  `ryc_rate`        decimal(8,4)  NOT NULL                               COMMENT 'RYC佣金率快照',
  `override_rate`   decimal(8,4)  NOT NULL DEFAULT 0                    COMMENT '管理津贴比例快照',
  `is_manager`      tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '是否主任及以上: 1是 0否',
  `direct_manager_id` bigint(20)  DEFAULT NULL                           COMMENT '直接上级主任ID',
  `basic_law_id`    bigint(20)    NOT NULL                               COMMENT '当月适用基本法ID',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_month` (`agent_id`, `snapshot_month`, `tenant_id`),
  KEY `idx_snapshot_month` (`snapshot_month`),
  KEY `idx_rank_id` (`rank_id`),
  KEY `idx_direct_manager_id` (`direct_manager_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员职级月度快照表';

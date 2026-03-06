-- =====================================================
-- 保险中介平台 · 佣金结算中台数据库设计
-- 模块: intermediary-module-ins-commission
-- Schema: db_ins_commission
-- 表前缀: ins_comm_  (车险政策相关使用 ins_car_)
-- 文档版本: V1.0 | 日期: 2026-03-01
-- Part 3: 车险政策管理（留点/加投点/报价赋值/禁保名单）+ 多级结算政策
-- 对应需求: 补充篇A §2 车险政策管理 + §3 多级结算
-- =====================================================

USE `db_ins_commission`;

-- =====================================================
-- 17. ins_car_point_config  车险留点政策配置表
-- 配置各保司各险种的留点比例（经纪人可留存手续费比例）
-- 对应需求: 补充篇A §2.1 (PDF-66/67)
-- =====================================================
CREATE TABLE `ins_car_point_config` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `insurance_company_code` varchar(64) NOT NULL                         COMMENT '保险公司编码',
  `insurance_company_name` varchar(128) NOT NULL                        COMMENT '保险公司名称',
  `insurance_type`  varchar(32)   NOT NULL                               COMMENT '险种: COMPULSORY交强险 COMMERCIAL商业险 ALL全部',
  `org_level`       varchar(32)   DEFAULT NULL                           COMMENT '机构等级（NULL=全部机构等级适用）',
  `rank_code`       varchar(32)   DEFAULT NULL                           COMMENT '业务员职级编码（NULL=全部职级适用）',
  `point_rate_min`  decimal(8,4)  NOT NULL                               COMMENT '留点比例下限（百分比小数，如0.05=5%）',
  `point_rate_max`  decimal(8,4)  NOT NULL                               COMMENT '留点比例上限（合规控制）',
  `compliance_max_rate` decimal(8,4) DEFAULT NULL                        COMMENT '监管合规上限（来自保司配置，只读冗余）',
  `effective_date`  date          NOT NULL                               COMMENT '生效日期',
  `expire_date`     date          DEFAULT NULL                           COMMENT '失效日期（NULL=长期有效）',
  `change_reason`   varchar(500)  DEFAULT NULL                           COMMENT '最近一次变更原因',
  `status`          tinyint(1)    NOT NULL DEFAULT 1                     COMMENT '状态: 1启用 0停用',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_insurance_company` (`insurance_company_code`),
  KEY `idx_insurance_type` (`insurance_type`),
  KEY `idx_rank_code` (`rank_code`),
  KEY `idx_effective_date` (`effective_date`),
  -- 组合索引（留点政策匹配优先级查询用）
  KEY `idx_company_type_org_rank` (`insurance_company_code`, `insurance_type`, `org_level`, `rank_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='车险留点政策配置表（PDF-66/67）';


-- =====================================================
-- 18. ins_car_extra_point_batch  车险加投点政策批次表
-- 按业务员FYP阶梯档位叠加额外留点
-- 对应需求: 补充篇A §2.2 (PDF-65)
-- =====================================================
CREATE TABLE `ins_car_extra_point_batch` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `batch_no`        varchar(64)   NOT NULL                               COMMENT '批次号（唯一）',
  `insurance_company_code` varchar(64) NOT NULL                         COMMENT '保险公司编码',
  `insurance_company_name` varchar(128) NOT NULL                        COMMENT '保险公司名称',
  `insurance_type`  varchar(32)   NOT NULL                               COMMENT '险种: COMPULSORY/COMMERCIAL/ALL',
  `stat_period_type` varchar(16)  NOT NULL DEFAULT 'MONTHLY'             COMMENT '统计周期类型: MONTHLY月度 QUARTERLY季度',
  `start_date`      date          NOT NULL                               COMMENT '批次政策开始日期',
  `end_date`        date          NOT NULL                               COMMENT '批次政策结束日期',
  `tier_config`     json          NOT NULL                               COMMENT '阶梯档位配置JSON，格式: {"tiers":[{"fyp_min":0,"fyp_max":500000,"extra_rate":0.005,"label":"铜牌档"},...]}',
  `status`          tinyint(1)    NOT NULL DEFAULT 1                     COMMENT '状态: 1有效 0停用（不可物理删除）',
  `remark`          varchar(500)  DEFAULT NULL                           COMMENT '备注',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除（不可物理删除，设置deleted=1代替）',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`, `tenant_id`),
  KEY `idx_insurance_company` (`insurance_company_code`),
  KEY `idx_date_range` (`start_date`, `end_date`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='车险加投点政策批次表（PDF-65，FYP阶梯额外留点）';


-- =====================================================
-- 19. ins_car_quote_adjust_policy  车险报价赋值政策表
-- 配置报价展示层的加价/减价规则（不修改实际保费）
-- 对应需求: 补充篇A §2.3 (PDF-69/70)
-- =====================================================
CREATE TABLE `ins_car_quote_adjust_policy` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `insurance_company_code` varchar(64) NOT NULL                         COMMENT '保险公司编码',
  `insurance_company_name` varchar(128) NOT NULL                        COMMENT '保险公司名称',
  `insurance_type`  varchar(32)   NOT NULL DEFAULT 'ALL'                COMMENT '险种: COMPULSORY/COMMERCIAL/ALL',
  `adjust_type`     varchar(16)   NOT NULL                               COMMENT '赋值类型: AMOUNT金额赋值 PERCENTAGE百分比赋值',
  `adjust_direction` varchar(8)   NOT NULL                               COMMENT '赋值方向: ADD加价 MINUS减价',
  `adjust_value`    decimal(10,4) NOT NULL                               COMMENT '赋值数值（金额单位元，或百分比小数如0.05=5%）',
  `display_price_floor` decimal(14,2) DEFAULT NULL                      COMMENT '展示价格下限保护（成本价保护，不得低于此值）',
  `apply_scope`     varchar(256)  DEFAULT NULL                           COMMENT '适用范围说明（产品/渠道）',
  `effective_start` datetime      NOT NULL                               COMMENT '生效开始时间（精确到分钟）',
  `effective_end`   datetime      DEFAULT NULL                           COMMENT '生效结束时间（NULL=永不失效）',
  `status`          tinyint(1)    NOT NULL DEFAULT 1                     COMMENT '状态: 1启用 0停用',
  `remark`          varchar(500)  DEFAULT NULL                           COMMENT '备注',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_insurance_company` (`insurance_company_code`),
  KEY `idx_effective_time` (`effective_start`, `effective_end`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='车险报价赋值政策表（PDF-69/70，展示层加减价规则）';


-- =====================================================
-- 20. ins_car_underwrite_blacklist  预核保禁止投保名单
-- 记录禁止承保的车辆/车主黑名单
-- 对应需求: 补充篇A §2.4 (PDF-68)
-- =====================================================
CREATE TABLE `ins_car_underwrite_blacklist` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `blacklist_type`  varchar(32)   NOT NULL                               COMMENT '黑名单类型: PLATE_NO车牌号 VIN车架号 ID_CARD证件号 PHONE手机号',
  `blacklist_value` varchar(128)  NOT NULL                               COMMENT '黑名单值（车牌号/车架号/证件号/手机号）',
  `blacklist_value_hash` varchar(64) NOT NULL                            COMMENT '黑名单值哈希（用于快速查询，SHA256）',
  `insurance_company_code` varchar(64) DEFAULT NULL                      COMMENT '限制保司编码（NULL=全部保司）',
  `restrict_type`   varchar(16)   NOT NULL DEFAULT 'FORBID'              COMMENT '限制类型: FORBID禁止 WARN警告',
  `reason`          varchar(500)  NOT NULL                               COMMENT '加入原因',
  `effective_date`  date          NOT NULL                               COMMENT '生效日期',
  `expire_date`     date          DEFAULT NULL                           COMMENT '失效日期（NULL=永久）',
  `import_batch_id` bigint(20)    DEFAULT NULL                           COMMENT '导入批次ID（批量导入时填充）',
  `status`          tinyint(1)    NOT NULL DEFAULT 1                     COMMENT '状态: 1有效 0已过期/手动移除',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  KEY `idx_blacklist_value_hash` (`blacklist_value_hash`),
  KEY `idx_blacklist_type` (`blacklist_type`),
  KEY `idx_effective_date` (`effective_date`, `expire_date`),
  KEY `idx_status` (`status`),
  KEY `idx_import_batch_id` (`import_batch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='预核保禁止投保名单（PDF-68）';


-- =====================================================
-- 21. ins_comm_multilevel_policy  多级结算政策配置表
-- 配置组织分润链路比例（override_hierarchy JSON存储）
-- 对应需求: 补充篇A §3.1 (PDF-244/245)
-- =====================================================
CREATE TABLE `ins_comm_multilevel_policy` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT                 COMMENT '主键ID',
  `policy_name`     varchar(64)   NOT NULL                               COMMENT '政策名称（唯一）',
  `product_categories` varchar(128) NOT NULL DEFAULT 'ALL'               COMMENT '适用险种（逗号分隔: CAR,LIFE,ALL）',
  `override_hierarchy` json        NOT NULL                               COMMENT '分润链路配置JSON，示例: {"hierarchy":[{"level":1,"split_rate":0.10,"fyp_threshold":50000},...],"product_category":["CAR","LIFE"]}',
  `fyp_threshold`   decimal(14,2) NOT NULL DEFAULT 0                    COMMENT '全局最低FYP激活门槛（0=无门槛）',
  `max_total_rate`  decimal(8,4)  NOT NULL DEFAULT 0.30                 COMMENT '各级分润比例之和上限（默认30%）',
  `effective_date`  date          NOT NULL                               COMMENT '生效日期',
  `expire_date`     date          DEFAULT NULL                           COMMENT '失效日期',
  `change_reason`   varchar(500)  DEFAULT NULL                           COMMENT '最近一次变更原因',
  `status`          tinyint(1)    NOT NULL DEFAULT 1                     COMMENT '状态: 1启用 0停用',
  `creator`         varchar(64)   DEFAULT NULL                           COMMENT '创建者',
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
  `updater`         varchar(64)   DEFAULT NULL                           COMMENT '更新者',
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`         tinyint(1)    NOT NULL DEFAULT 0                     COMMENT '逻辑删除',
  `tenant_id`       bigint(20)    NOT NULL DEFAULT 0                     COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_policy_name` (`policy_name`, `tenant_id`),
  KEY `idx_effective_date` (`effective_date`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='多级结算政策配置表（PDF-244/245，分润链路JSON）';

-- =====================================================
-- 说明: sys_dept 扩展字段（ALTER方式，不新建表）
-- 在原有系统的 sys_dept 上追加多级结算字段
-- 对应需求: 补充篇A §3.1.4 负责人绑定
-- =====================================================
-- ALTER TABLE sys_dept ADD COLUMN `multi_settle_agent_id`    bigint(20) DEFAULT NULL COMMENT '多级结算负责人ID（关联sys_user）';
-- ALTER TABLE sys_dept ADD COLUMN `multi_settle_policy_id`   bigint(20) DEFAULT NULL COMMENT '绑定的多级结算政策ID（关联ins_comm_multilevel_policy）';
-- ALTER TABLE sys_dept ADD COLUMN `multi_settle_update_time` datetime   DEFAULT NULL COMMENT '最后绑定变更时间';

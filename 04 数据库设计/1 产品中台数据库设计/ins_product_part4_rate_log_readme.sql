-- =============================================================================
-- 保险产品中台 - intermediary-module-ins-product
-- Schema: db_ins_product
-- Part 4: 通用费率表（非车险）+ 产品操作日志 + Redis缓存键说明
-- =============================================================================

USE `db_ins_product`;

-- -----------------------------------------------------------------------------
-- 19. 非车险费率表 ins_product_non_vehicle_rate
-- 非车险产品费率（结构灵活，JSON存储复杂费率规则）
-- 对应业务员App非车险展业-试算功能
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_non_vehicle_rate`;
CREATE TABLE `ins_product_non_vehicle_rate` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '关联产品ID（ins_product_info.id）',
    `rate_name`             VARCHAR(200)    NOT NULL COMMENT '费率名称（如"基本险费率""附加险费率"）',
    `rate_type`             TINYINT         NOT NULL DEFAULT 1 COMMENT '费率类型：1-基础费率 2-附加费率 3-折扣系数',
    `rate_dimension`        VARCHAR(200)    DEFAULT NULL COMMENT '费率维度说明（如"按标的类型/建筑类型/保额区间"）',
    `rate_structure`        JSON            NOT NULL COMMENT '费率结构（JSON，支持多维度复杂费率：{rows:[],cols:[],data:[]}）',
    `effective_date`        DATE            DEFAULT NULL COMMENT '费率生效日期',
    `expire_date`           DATE            DEFAULT NULL COMMENT '费率失效日期（NULL=永久）',
    `version`               VARCHAR(20)     NOT NULL DEFAULT '1.0' COMMENT '费率版本（每次更新递增）',
    `status`                TINYINT         NOT NULL DEFAULT 1 COMMENT '状态：0-停用 1-启用',
    `batch_no`              VARCHAR(100)    DEFAULT NULL COMMENT '导入批次号',
    `creator`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`               VARCHAR(64)     NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`               TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '是否删除：0-未删 1-已删',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    KEY `idx_product_status` (`product_id`, `status`, `deleted`),
    KEY `idx_effective_date` (`effective_date`, `expire_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='非车险费率配置表';


-- -----------------------------------------------------------------------------
-- 20. 产品操作日志表 ins_product_operation_log
-- 记录产品关键操作（上下架/授权/费率导入等），审计用途
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_operation_log`;
CREATE TABLE `ins_product_operation_log` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '产品ID',
    `operation_type`        VARCHAR(50)     NOT NULL COMMENT '操作类型：ON_SHELF/OFF_SHELF/AUTH_ORG/IMPORT_RATE/UPDATE_COMMISSION/DELETE',
    `operation_desc`        VARCHAR(500)    NOT NULL COMMENT '操作描述',
    `before_data`           JSON            DEFAULT NULL COMMENT '操作前数据快照（关键字段）',
    `after_data`            JSON            DEFAULT NULL COMMENT '操作后数据快照（关键字段）',
    `operator_id`           BIGINT          NOT NULL COMMENT '操作人ID',
    `operator_name`         VARCHAR(100)    DEFAULT NULL COMMENT '操作人姓名',
    `operation_time`        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
    `result`                TINYINT         NOT NULL DEFAULT 1 COMMENT '操作结果：0-失败 1-成功',
    `fail_reason`           VARCHAR(500)    DEFAULT NULL COMMENT '失败原因',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    KEY `idx_product_type` (`product_id`, `operation_type`, `operation_time`),
    KEY `idx_operator_time` (`operator_id`, `operation_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品操作日志表';


-- -----------------------------------------------------------------------------
-- 21. 产品试算缓存结果表 ins_product_calc_cache
-- 存储试算请求的结果缓存，避免重复计算（配合Redis使用）
-- 对应业务员App M2-保费试算 / C端寿险试算
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_product_calc_cache`;
CREATE TABLE `ins_product_calc_cache` (
    `id`                    BIGINT          NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `product_id`            BIGINT          NOT NULL COMMENT '产品ID',
    `calc_params_hash`      VARCHAR(64)     NOT NULL COMMENT '试算参数MD5哈希（用于唯一定位缓存）',
    `calc_params`           JSON            NOT NULL COMMENT '试算入参（年龄/性别/保额/缴费方式等）',
    `calc_result`           JSON            NOT NULL COMMENT '试算结果（各缴费方式保费明细）',
    `calc_time`             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '计算时间',
    `expire_time`           DATETIME        NOT NULL COMMENT '缓存过期时间（默认24小时）',
    `tenant_id`             BIGINT          NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_product_hash` (`product_id`, `calc_params_hash`),
    KEY `idx_expire_time` (`expire_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='产品保费试算缓存表';


-- =============================================================================
-- ★ Redis 缓存键规范说明（代码注释用，非SQL语句）
-- =============================================================================
/*
 ┌────────────────────────────────────────────────────────────────────────┐
 │  ins-product 模块 Redis Key 规范                                        │
 │  前缀: ins:product:                                                      │
 ├──────────────────────────────────┬─────────────────────────────────────┤
 │  Key 格式                         │  说明                                │
 ├──────────────────────────────────┼─────────────────────────────────────┤
 │  ins:product:detail:{id}         │  产品详情，TTL=1h                    │
 │  ins:product:list:{paramsHash}   │  列表分页缓存，TTL=10min             │
 │  ins:product:hot:ids             │  热销产品ID列表，TTL=30min           │
 │  ins:product:insurer:list        │  保司列表，TTL=1h（全量，不分租户）  │
 │  ins:product:category:tree       │  险种分类树，TTL=24h                 │
 │  ins:product:rate:car:{productId}│  车险费率，TTL=2h                    │
 │  ins:product:life:rate:{productId}│ 寿险费率，TTL=2h                   │
 │  ins:product:calc:{hash}         │  试算结果，TTL=24h                   │
 │  ins:product:org:auth:{productId}│  产品授权机构ID集合（Set），TTL=1h  │
 │  life:h5:config:{key}            │  寿险H5配置，TTL=24h                │
 └──────────────────────────────────┴─────────────────────────────────────┘

  缓存失效策略：
  1. 产品状态变更（上下架/信息编辑） → 主动 DELETE ins:product:detail:{id}
  2. 费率表重新导入 → DELETE ins:product:rate:car:{productId} 或 life:rate:{productId}
  3. 授权变更 → DELETE ins:product:org:auth:{productId}
  4. 险种分类/保司列表变更 → DELETE ins:product:category:tree / ins:product:insurer:list
*/


-- =============================================================================
-- ★ 表结构汇总（本模块所有表清单）
-- =============================================================================
/*
  db_ins_product 数据库 - ins-product 模块全量表清单（共21张表）

  【保司管理】
  ├── ins_product_insurer                  保险公司档案（车/非车/寿险通用）
  ├── ins_product_insurer_life_ext         寿险保司扩展（1:1）
  └── ins_product_insurer_account          保司工号/API账号

  【险种分类】
  └── ins_product_category                 险种分类（树形，含系统预置）

  【产品主表（通用）】
  ├── ins_product_info                     产品主表（三大险种共用）
  ├── ins_product_commission_level         产品分级佣金
  ├── ins_product_commission_change_log    佣金变更日志
  ├── ins_product_org_auth                 产品机构授权（通用）
  ├── ins_product_favorite                 产品收藏（业务员）
  └── ins_product_view_log                 产品浏览记录

  【车险专属】
  └── ins_product_car_rate                 车险费率表（EasyExcel导入）

  【非车险专属】
  ├── ins_product_non_vehicle_plan         系统产品方案（政策配置数据源）
  └── ins_product_non_vehicle_rate         非车险费率（JSON灵活结构）

  【寿险专属】
  ├── ins_product_life_ext                 寿险产品扩展信息（1:1）
  ├── ins_product_life_rate                寿险费率（年龄/性别/缴费期）
  ├── ins_product_questionnaire_template   健康告知问卷模板
  ├── ins_product_questionnaire_bind       产品-问卷绑定
  ├── ins_product_life_org_auth            寿险产品机构授权
  └── ins_product_life_proposal            计划书申请记录

  【通用辅助】
  ├── ins_product_non_vehicle_rate         非车险费率配置
  ├── ins_product_operation_log            产品操作日志（审计）
  └── ins_product_calc_cache               保费试算缓存
*/


-- =============================================================================
-- 定时任务说明（配套 Spring Scheduling / xxl-job 任务）
-- =============================================================================
/*
  任务名                              执行周期    说明
  ─────────────────────────────────────────────────────────────────────────
  InsProductAutoShelfTask             每小时整点  处理定时上架/下架（auto_on/off_shelf_time）
  InsProductHotTagTask                每天凌晨2点 根据 sales_count >= 100 自动打/去 is_hot 标签
  InsProductCalcCacheCleanTask        每天凌晨3点 清理 ins_product_calc_cache 中已过期记录
  InsProductProposalTimeoutTask       每小时      处理状态=0(待生成)超30分钟的计划书，标记失败
*/

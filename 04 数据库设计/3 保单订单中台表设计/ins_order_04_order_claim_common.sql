-- ============================================================
-- 保险中介平台 - intermediary-module-ins-order（保单订单中台）
-- 数据库Schema: db_ins_order
-- 表前缀: ins_order_
-- 文件: 04 - 订单主表、理赔、附件、导入/导出等通用支撑表
-- 版本: V1.0
-- ============================================================

USE `db_ins_order`;

-- ----------------------------
-- 22. 订单主表（C端投保产生的订单，覆盖车险/非车险/寿险）
-- ----------------------------
CREATE TABLE `ins_order_main` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `order_no`            VARCHAR(64)   NOT NULL COMMENT '订单号（雪花算法）',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',

  -- 用户信息
  `user_id`             BIGINT        NOT NULL COMMENT 'C端用户ID',
  `agent_id`            BIGINT        COMMENT '归因业务员ID（分享链路追踪）',

  -- 关联申请单
  `apply_id`            BIGINT        COMMENT '关联投保申请单ID（tb_insurance_apply）',

  -- 险种类型
  `order_type`          TINYINT       NOT NULL COMMENT '订单类型：1-车险 2-非车险 3-寿险 4-寿险续期',
  `product_id`          BIGINT        COMMENT '产品ID',
  `product_name`        VARCHAR(200)  COMMENT '产品名称',
  `insurance_company_id` BIGINT       COMMENT '保险公司ID',
  `insurance_company_name` VARCHAR(100) COMMENT '保险公司名称',

  -- 金额信息（单位：分）
  `amount`              BIGINT        NOT NULL DEFAULT 0 COMMENT '应付金额（分）',
  `discount_amount`     BIGINT        DEFAULT 0 COMMENT '优惠/折扣金额（分）',
  `coupon_id`           BIGINT        COMMENT '使用的优惠券ID',
  `coupon_discount`     BIGINT        DEFAULT 0 COMMENT '优惠券优惠金额（分）',
  `points_used`         INT           DEFAULT 0 COMMENT '使用积分数量',
  `points_discount`     BIGINT        DEFAULT 0 COMMENT '积分抵扣金额（分）',
  `actual_amount`       BIGINT        NOT NULL DEFAULT 0 COMMENT '实付金额（分）',

  -- 订单状态
  `status`              TINYINT       NOT NULL DEFAULT 0 COMMENT '状态：0-待支付 1-已支付 2-已取消 3-退款中 4-已退款 5-已过期',

  -- 支付信息
  `pay_method`          VARCHAR(20)   COMMENT '支付方式：WECHAT/ALIPAY/BANK_CARD',
  `pay_time`            DATETIME      COMMENT '支付完成时间',
  `pay_order_no`        VARCHAR(64)   COMMENT '三方支付订单号',
  `expire_time`         DATETIME      NOT NULL COMMENT '订单过期时间（创建后30分钟）',

  -- 退款信息
  `refund_amount`       BIGINT        DEFAULT 0 COMMENT '退款金额（分）',
  `refund_time`         DATETIME      COMMENT '退款完成时间',
  `refund_reason`       VARCHAR(500)  COMMENT '退款原因',

  -- 保单关联（支付完成后关联）
  `policy_id`           BIGINT        COMMENT '关联保单ID（支付成功后写入）',

  -- 框架标准字段
  `creator`             VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`             VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`             TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_user_id_status` (`user_id`, `status`),
  KEY `idx_apply_id` (`apply_id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_status_expire_time` (`status`, `expire_time`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单主表（C端投保订单）';


-- ----------------------------
-- 23. 投保申请单表（C端投保过程中间状态表）
-- ----------------------------
CREATE TABLE `ins_order_insurance_apply` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `user_id`             BIGINT        NOT NULL COMMENT 'C端用户ID',
  `agent_id`            BIGINT        COMMENT '归因业务员ID',
  `product_id`          BIGINT        NOT NULL COMMENT '产品ID',
  `product_name`        VARCHAR(200)  NOT NULL COMMENT '产品名称',
  `insurance_type`      TINYINT       NOT NULL COMMENT '险种大类：1-车险 2-非车险 3-寿险',
  `insurer_id`          BIGINT        COMMENT '保险公司ID',

  -- 步骤跟踪（断点续填）
  `current_step`        TINYINT       DEFAULT 0 COMMENT '当前步骤：0-初始 1-基本信息 2-被保人 3-缴费确认 4-待支付',

  -- 投保核心信息
  `holder_info`         JSON          COMMENT '投保人信息快照',
  `insured_info`        JSON          COMMENT '被保人信息列表快照',
  `beneficiary_info`    JSON          COMMENT '受益人信息列表快照（寿险）',
  `health_notice_info`  JSON          COMMENT '健康告知问卷答案快照',
  `coverage_info`       JSON          COMMENT '保障配置信息（保额/缴费方式等）',

  -- 保费信息
  `policy_start_date`   DATE          COMMENT '起保日期',
  `policy_end_date`     DATE          COMMENT '止期',
  `premium`             BIGINT        DEFAULT 0 COMMENT '保费（分）',
  `annual_premium`      BIGINT        DEFAULT 0 COMMENT '年缴保费（分，寿险）',

  -- 核保信息
  `underwriting_result` VARCHAR(20)   COMMENT '核保结论：STANDARD/EXTRA_PREMIUM/EXCLUSION/REJECTED',
  `underwriting_conditions` JSON      COMMENT '核保附加条件',
  `underwriting_time`   DATETIME      COMMENT '核保时间',

  -- 申请单状态
  `status`              TINYINT       NOT NULL DEFAULT 0 COMMENT '状态：0-草稿 1-待支付 2-已支付 3-核保中 4-拒保 5-撤单',

  `remark`              VARCHAR(500)  COMMENT '备注',

  `creator`             VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`             VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`             TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',

  PRIMARY KEY (`id`),
  KEY `idx_user_id_status` (`user_id`, `status`),
  KEY `idx_product_id` (`product_id`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='投保申请单表（C端投保中间状态）';


-- ----------------------------
-- 24. 寿险投保草稿表（C端分步填写，断点续填）
-- ----------------------------
CREATE TABLE `ins_order_life_draft` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `draft_id`            VARCHAR(64)   NOT NULL COMMENT '草稿ID（UUID）',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `user_id`             BIGINT        NOT NULL COMMENT 'C端用户ID',
  `agent_id`            BIGINT        COMMENT '归因业务员ID',
  `product_id`          BIGINT        NOT NULL COMMENT '产品ID',
  `insurer_id`          BIGINT        COMMENT '保险公司ID',

  -- 分步状态（断点续填）
  `current_step`        TINYINT       DEFAULT 0 COMMENT '当前步骤：0-健康告知 1-填写信息 2-缴费确认 3-已提交',
  `health_step_done`    TINYINT(1)    DEFAULT 0 COMMENT '健康告知步骤完成：0-否 1-是',
  `insured_step_done`   TINYINT(1)    DEFAULT 0 COMMENT '被保人步骤完成：0-否 1-是',
  `payment_step_done`   TINYINT(1)    DEFAULT 0 COMMENT '缴费信息步骤完成：0-否 1-是',

  -- 各步骤数据暂存（JSON）
  `health_notice_data`  JSON          COMMENT '健康告知答案数据',
  `holder_info`         JSON          COMMENT '投保人信息',
  `insured_info`        JSON          COMMENT '被保人信息列表',
  `beneficiary_info`    JSON          COMMENT '受益人信息列表',
  `payment_info`        JSON          COMMENT '缴费方式/首次缴费日等信息',
  `coverage_info`       JSON          COMMENT '保额/缴费期等配置',
  `premium`             BIGINT        COMMENT '计算的年缴保费（分）',

  -- 核保暂存
  `underwriting_result` VARCHAR(20)   COMMENT '核保结论',
  `underwriting_conditions` JSON      COMMENT '核保附加条件',

  -- 草稿状态
  `status`              TINYINT       NOT NULL DEFAULT 0 COMMENT '状态：0-进行中 1-已提交 2-已过期 3-已放弃',
  `expire_time`         DATETIME      NOT NULL COMMENT '过期时间（创建后24小时）',

  `creator`             VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`             VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`             TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_draft_id` (`draft_id`),
  KEY `idx_user_id_status` (`user_id`, `status`),
  KEY `idx_product_id` (`product_id`),
  KEY `idx_expire_time` (`expire_time`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='寿险投保草稿表（C端分步填写）';


-- ----------------------------
-- 25. 理赔案件主表（寿险+非车险+C端通用）
-- ----------------------------
CREATE TABLE `ins_order_claim_record` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `claim_no`            VARCHAR(30)   NOT NULL COMMENT '报案号（CLME+年月日+8位流水）',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `policy_id`           BIGINT        NOT NULL COMMENT '关联保单ID',
  `policy_no`           VARCHAR(100)  NOT NULL COMMENT '保单号',
  `policy_type`         TINYINT       NOT NULL COMMENT '保单类型：1-车险 2-非车险 3-寿险',
  `user_id`             BIGINT        COMMENT 'C端用户ID（C端报案时）',
  `agent_id`            BIGINT        COMMENT '负责业务员ID',
  `agent_name`          VARCHAR(100)  COMMENT '负责业务员姓名',
  `insurance_company_id` BIGINT       COMMENT '保险公司ID',
  `org_id`              BIGINT        COMMENT '所属机构ID',

  -- 出险信息
  `accident_time`       DATETIME      NOT NULL COMMENT '出险时间',
  `accident_location`   VARCHAR(500)  COMMENT '出险地点',
  `accident_lng`        DECIMAL(10,7) COMMENT '出险地点经度',
  `accident_lat`        DECIMAL(10,7) COMMENT '出险地点纬度',
  `accident_type`       VARCHAR(50)   NOT NULL COMMENT '出险类型：身故/全残/重大疾病/轻症/住院/意外/火灾等',
  `accident_desc`       TEXT          NOT NULL COMMENT '出险经过',
  `injury_level`        TINYINT       COMMENT '伤亡情况：0-无伤亡 1-轻伤 2-重伤 3-死亡',
  `estimated_amount`    BIGINT        COMMENT '预估损失金额（分）',

  -- 联系人（C端报案使用）
  `contact_name`        VARCHAR(50)   COMMENT '联系人姓名',
  `contact_mobile`      VARCHAR(20)   COMMENT '联系人电话',
  `scene_images`        JSON          COMMENT '现场照片URL列表',

  -- 保司理赔跟进
  `case_no`             VARCHAR(100)  COMMENT '保司赔案号（后续补录）',
  `submitted_docs`      JSON          COMMENT '已提交材料清单（枚举：死亡证明/医疗报告等）',

  -- 赔付结果
  `claim_amount`        DECIMAL(15,2) COMMENT '赔付金额（元）',
  `claim_date`          DATE          COMMENT '赔付日期',
  `claim_account`       VARCHAR(200)  COMMENT '赔付账号信息',
  `claim_result_desc`   VARCHAR(500)  COMMENT '赔付结果说明',
  `reject_reason`       VARCHAR(500)  COMMENT '拒赔原因',

  -- 案件状态
  `status`              VARCHAR(20)   NOT NULL DEFAULT 'PROCESSING' COMMENT '状态：PROCESSING-处理中 SETTLED-已结案 REJECTED-已拒赔 WITHDRAWN-已撤案',
  `report_source`       TINYINT       DEFAULT 1 COMMENT '报案来源：1-PC后台 2-C端自助',

  `creator`             VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`             VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`             TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_claim_no` (`claim_no`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_status` (`status`),
  KEY `idx_accident_type` (`accident_type`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='理赔案件主表';


-- ----------------------------
-- 26. 理赔跟进记录表
-- ----------------------------
CREATE TABLE `ins_order_claim_follow_record` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `claim_id`        BIGINT        NOT NULL COMMENT '关联理赔案件ID',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `follow_time`     DATETIME      NOT NULL COMMENT '跟进时间',
  `progress`        TEXT          NOT NULL COMMENT '处理进展描述',
  `doc_require`     VARCHAR(500)  COMMENT '保司要求补交材料清单',
  `attachment_urls` JSON          COMMENT '跟进附件URL列表',
  `operator_id`     BIGINT        NOT NULL COMMENT '操作人ID',
  `operator_name`   VARCHAR(100)  NOT NULL COMMENT '操作人名称',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_claim_id` (`claim_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='理赔跟进记录表';


-- ----------------------------
-- 27. 理赔材料模板配置表（C端报案所需材料清单）
-- ----------------------------
CREATE TABLE `ins_order_claim_material_template` (
  `id`                    BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenant_id`             BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `product_category_id`   BIGINT        NOT NULL COMMENT '险种分类ID',
  `accident_type`         VARCHAR(50)   COMMENT '适用出险类型（为空=通用）',
  `material_name`         VARCHAR(100)  NOT NULL COMMENT '材料名称',
  `material_desc`         TEXT          COMMENT '材料说明（需清晰可见、大小限制等）',
  `is_required`           TINYINT(1)    DEFAULT 1 COMMENT '是否必传：0-否 1-是',
  `sort`                  INT           DEFAULT 0 COMMENT '排序号',
  `status`                TINYINT(1)    DEFAULT 1 COMMENT '状态：1-启用 0-停用',
  `creator`               VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `deleted`               TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  KEY `idx_product_category` (`product_category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='理赔材料模板配置表';


-- ----------------------------
-- 28. 理赔材料上传记录表
-- ----------------------------
CREATE TABLE `ins_order_claim_material` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `claim_id`        BIGINT        NOT NULL COMMENT '关联理赔案件ID',
  `template_id`     BIGINT        NOT NULL COMMENT '关联材料模板ID',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `file_url`        VARCHAR(500)  NOT NULL COMMENT '文件OSS地址',
  `file_name`       VARCHAR(200)  COMMENT '文件原始名称',
  `file_type`       VARCHAR(20)   COMMENT '文件类型：image/pdf',
  `file_size`       BIGINT        COMMENT '文件大小（字节）',
  `upload_time`     DATETIME      NOT NULL COMMENT '上传时间',
  `uploader_id`     BIGINT        COMMENT '上传人ID',
  `status`          TINYINT       DEFAULT 1 COMMENT '状态：1-有效 0-已删除',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_claim_id` (`claim_id`),
  KEY `idx_template_id` (`template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='理赔材料上传记录表';


-- ----------------------------
-- 29. 保单附件表（通用，覆盖三大险种影像件管理）
-- ----------------------------
CREATE TABLE `ins_order_policy_attachment` (
  `id`                BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_id`         BIGINT        NOT NULL COMMENT '关联保单ID',
  `policy_type`       TINYINT       NOT NULL COMMENT '保单类型：1-车险 2-非车险 3-寿险',
  `tenant_id`         BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `category`          VARCHAR(50)   NOT NULL COMMENT '附件分类：POLICY_COVER-保单首页/CLAUSE-条款页/HEALTH_NOTICE-健康告知书/OTHER-其他',
  `file_name`         VARCHAR(200)  NOT NULL COMMENT '文件名',
  `file_url`          VARCHAR(500)  NOT NULL COMMENT '文件OSS地址',
  `file_type`         VARCHAR(20)   COMMENT '文件类型：image/pdf',
  `file_size`         BIGINT        COMMENT '文件大小（字节）',
  `upload_time`       DATETIME      NOT NULL COMMENT '上传时间',
  `operator_id`       BIGINT        COMMENT '上传人ID',
  `operator_name`     VARCHAR(100)  COMMENT '上传人名称',
  `status`            TINYINT       DEFAULT 1 COMMENT '状态：1-有效 0-已删除',
  `creator`           VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `deleted`           TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除',
  PRIMARY KEY (`id`),
  KEY `idx_policy_id_type` (`policy_id`, `policy_type`),
  KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='保单附件表（影像件管理，通用）';


-- ----------------------------
-- 30. 批量导入日志表（EasyExcel 导入记录）
-- ----------------------------
CREATE TABLE `ins_order_import_log` (
  `id`                BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `batch_no`          VARCHAR(64)   NOT NULL COMMENT '批次编号',
  `tenant_id`         BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `import_type`       VARCHAR(50)   NOT NULL COMMENT '导入类型：CAR_POLICY/NON_CAR_POLICY/LIFE_POLICY/CAR_ENDORSEMENT/NON_CAR_ENDORSEMENT/LIFE_CONSERVATION',
  `file_name`         VARCHAR(200)  NOT NULL COMMENT '导入文件名',
  `file_url`          VARCHAR(500)  COMMENT '导入文件OSS地址（保存原文件）',
  `total_count`       INT           DEFAULT 0 COMMENT '总行数',
  `success_count`     INT           DEFAULT 0 COMMENT '成功行数',
  `fail_count`        INT           DEFAULT 0 COMMENT '失败行数',
  `status`            TINYINT       NOT NULL DEFAULT 0 COMMENT '导入状态：0-解析中 1-待确认 2-导入中 3-已完成 4-失败',
  `error_file_url`    VARCHAR(500)  COMMENT '失败明细文件OSS地址',
  `operator_id`       BIGINT        NOT NULL COMMENT '操作人ID',
  `operator_name`     VARCHAR(100)  NOT NULL COMMENT '操作人名称',
  `start_time`        DATETIME      COMMENT '导入开始时间',
  `end_time`          DATETIME      COMMENT '导入结束时间',
  `error_detail`      TEXT          COMMENT '错误摘要（前100条错误信息）',
  `creator`           VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`           VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`),
  KEY `idx_tenant_id` (`tenant_id`),
  KEY `idx_import_type` (`import_type`),
  KEY `idx_operator_id` (`operator_id`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='批量导入日志表';


-- ----------------------------
-- 31. 异步导出任务表（通用，覆盖各模块大数据量导出）
-- ----------------------------
CREATE TABLE `ins_order_export_task` (
  `id`                BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `task_no`           VARCHAR(64)   NOT NULL COMMENT '任务编号（UUID）',
  `tenant_id`         BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `export_type`       VARCHAR(50)   NOT NULL COMMENT '导出类型：CAR_POLICY/NON_CAR_POLICY/LIFE_POLICY/LIFE_ORPHAN_LOG等',
  `task_name`         VARCHAR(200)  COMMENT '任务描述（如：寿险保单导出-2025-01-01）',
  `query_params`      JSON          COMMENT '查询条件JSON快照（用于异步执行时重新查询）',
  `total_count`       INT           DEFAULT 0 COMMENT '导出总行数',
  `status`            TINYINT       NOT NULL DEFAULT 0 COMMENT '状态：0-等待中 1-处理中 2-已完成 3-失败',
  `file_url`          VARCHAR(500)  COMMENT '导出文件OSS地址',
  `file_name`         VARCHAR(200)  COMMENT '导出文件名',
  `error_msg`         VARCHAR(500)  COMMENT '错误信息',
  `start_time`        DATETIME      COMMENT '开始处理时间',
  `end_time`          DATETIME      COMMENT '完成时间',
  `operator_id`       BIGINT        NOT NULL COMMENT '操作人ID',
  `operator_name`     VARCHAR(100)  NOT NULL COMMENT '操作人名称',
  `creator`           VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`           VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`           TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '是否删除（用户点删除后）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_no` (`task_no`),
  KEY `idx_operator_id` (`operator_id`),
  KEY `idx_status` (`status`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='异步导出任务表（通用）';


-- ----------------------------
-- 32. 保单验真日志表（C端保单验真记录）
-- ----------------------------
CREATE TABLE `ins_order_policy_verify_log` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `policy_no`       VARCHAR(100)  NOT NULL COMMENT '保单号',
  `policy_id`       BIGINT        COMMENT '关联保单ID（若匹配到）',
  `verify_ip`       VARCHAR(50)   COMMENT '验证来源IP',
  `verify_device`   VARCHAR(200)  COMMENT '验证设备信息（UA）',
  `verify_result`   TINYINT       NOT NULL COMMENT '验真结果：1-有效 0-无效',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '验真时间',
  PRIMARY KEY (`id`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='保单验真日志表';


-- ----------------------------
-- 33. 支付记录表（关联订单支付流水）
-- ----------------------------
CREATE TABLE `ins_order_payment_record` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `order_id`        BIGINT        NOT NULL COMMENT '关联订单ID',
  `order_no`        VARCHAR(64)   NOT NULL COMMENT '关联订单号',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID',
  `user_id`         BIGINT        NOT NULL COMMENT '用户ID',
  `pay_method`      VARCHAR(20)   NOT NULL COMMENT '支付方式：WECHAT/ALIPAY/BANK_CARD',
  `pay_amount`      BIGINT        NOT NULL COMMENT '支付金额（分）',
  `third_order_no`  VARCHAR(64)   COMMENT '三方支付单号',
  `pay_status`      TINYINT       NOT NULL DEFAULT 0 COMMENT '支付状态：0-待支付 1-成功 2-失败 3-已关闭',
  `pay_time`        DATETIME      COMMENT '支付完成时间',
  `pay_response`    TEXT          COMMENT '支付回调原始报文（JSON）',
  `expire_time`     DATETIME      NOT NULL COMMENT '支付链接过期时间',
  `creator`         VARCHAR(64)   DEFAULT '' COMMENT '创建者',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`         VARCHAR(64)   DEFAULT '' COMMENT '更新者',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_order_no` (`order_no`),
  KEY `idx_third_order_no` (`third_order_no`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_pay_status` (`pay_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='支付记录表';

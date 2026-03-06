-- =====================================================================
-- 保险中介平台 · 合规双录模块数据库设计
-- Schema: db_ins_compliance
-- 表前缀: ins_comp_
-- 对应模块: intermediary-module-ins-compliance
-- 对应阶段: 阶段5-合规双录（双录引擎 + AI质检 + 存证管理）
-- 技术框架: yudao-cloud（intermediary-cloud 微服务版）
-- 编写日期: 2026-03-01
-- 版本: V1.0
-- =====================================================================

CREATE DATABASE IF NOT EXISTS `db_ins_compliance`
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE `db_ins_compliance`;

-- =====================================================================
-- 一、双录引擎（双录会话主表）
-- =====================================================================

-- -------------------------------------------------------------------
-- 1.1 双录记录主表 ins_comp_recording_session
-- 职责：记录每次双录的全生命周期信息，包含RTC房间、参与者、音视频路径、质检结果
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_comp_recording_session`;
CREATE TABLE `ins_comp_recording_session` (
  `id`                    BIGINT        NOT NULL AUTO_INCREMENT COMMENT '双录记录ID（主键）',
  `record_code`           VARCHAR(50)   NOT NULL COMMENT '双录编号，规则：DR+yyyyMMdd+Redis自增6位序号，如DR202602140001',
  `policy_no`             VARCHAR(100)  DEFAULT NULL COMMENT '关联保单号（投保完成后回填）',
  `order_id`              BIGINT        DEFAULT NULL COMMENT '关联订单ID（ins_order模块）',

  -- 参与者信息
  `agent_id`              BIGINT        NOT NULL COMMENT '发起双录的业务员ID（ins_agent模块）',
  `agent_name`            VARCHAR(50)   NOT NULL COMMENT '业务员姓名（冗余快照）',
  `agent_org_id`          BIGINT        DEFAULT NULL COMMENT '业务员所属机构ID',
  `customer_id`           BIGINT        NOT NULL COMMENT '客户ID（ins_agent模块CRM）',
  `customer_name`         VARCHAR(50)   NOT NULL COMMENT '客户姓名（冗余快照）',
  `customer_id_card`      VARCHAR(200)  NOT NULL COMMENT '客户身份证号（AES-256-CBC加密存储，密钥由Nacos KMS管理）',
  `customer_mobile`       VARCHAR(20)   DEFAULT NULL COMMENT '客户手机号（AES-256加密）',
  `customer_id_card_img`  VARCHAR(500)  DEFAULT NULL COMMENT '客户身份证照片OSS路径（用于人脸比对）',

  -- 产品信息
  `product_id`            BIGINT        NOT NULL COMMENT '产品ID（ins_product模块）',
  `product_name`          VARCHAR(200)  NOT NULL COMMENT '产品名称（冗余快照）',
  `product_type`          TINYINT       NOT NULL COMMENT '产品类型：1-分红险 2-万能险 3-投连险 4-普通寿险 5-健康险 6-意外险',
  `premium`               DECIMAL(12,2) NOT NULL COMMENT '保费金额（元）',

  -- 双录基本属性
  `record_type`           TINYINT       NOT NULL COMMENT '双录类型：1-现场面签 2-远程视频',
  `record_scene`          TINYINT       NOT NULL COMMENT '触发场景：1-年龄≥60岁 2-趸交≥5万 3-期交≥2万 4-新型产品 5-保司要求',
  `record_status`         TINYINT       NOT NULL DEFAULT 0 COMMENT '状态：0-待开始 1-进行中 2-已完成 3-质检中 4-质检通过 5-质检不通过 6-已作废',

  -- 时间记录
  `start_time`            DATETIME      DEFAULT NULL COMMENT '双录开始时间',
  `end_time`              DATETIME      DEFAULT NULL COMMENT '双录结束时间',
  `duration`              INT           DEFAULT NULL COMMENT '实际双录时长（秒）',

  -- 音视频存储（声网Cloud Recording服务端录制）
  `video_url`             VARCHAR(500)  DEFAULT NULL COMMENT '录制视频OSS路径，格式：{tenant_id}/double-record/{yyyy}/{MM}/{record_code}_video.mp4',
  `video_size`            BIGINT        DEFAULT NULL COMMENT '视频文件大小（字节）',
  `audio_url`             VARCHAR(500)  DEFAULT NULL COMMENT '录制音频OSS路径（MP3）',

  -- 声网RTC房间信息
  `rtc_room_id`           VARCHAR(100)  DEFAULT NULL COMMENT '声网RTC频道名称（channelName），现场双录时为null',
  `rtc_session_id`        VARCHAR(100)  DEFAULT NULL COMMENT '声网服务端录制SessionID',
  `rtc_token`             VARCHAR(1000) DEFAULT NULL COMMENT '声网RTC Token（业务员端，有效期8小时）',
  `invite_token`          VARCHAR(500)  DEFAULT NULL COMMENT '客户端邀请Token（JWT签名，含recordId+有效期30min）',
  `invite_url`            VARCHAR(1000) DEFAULT NULL COMMENT '客户端邀请链接（远程双录时生成）',

  -- 话术模板
  `template_id`           BIGINT        NOT NULL COMMENT '使用的话术模板ID（ins_comp_script_template）',
  `template_snapshot`     JSON          DEFAULT NULL COMMENT '话术模板快照（防止模板修改后影响历史记录）',
  `total_nodes`           INT           NOT NULL COMMENT '话术总节点数（从模板复制）',
  `must_node_indexes`     JSON          DEFAULT NULL COMMENT '必读节点索引数组，如[1,2,3]（从模板复制）',
  `node_completed`        JSON          DEFAULT NULL COMMENT '已完成的节点索引数组，如[1,2,3]',
  `node_duration_log`     JSON          DEFAULT NULL COMMENT '各节点实际耗时JSON，如[{"index":1,"duration":25},...]',
  `current_node`          INT           DEFAULT 0 COMMENT '当前进行中的节点索引（0表示未开始）',

  -- 重录管理
  `retry_count`           INT           DEFAULT 0 COMMENT '已重录次数',
  `last_retry_time`       DATETIME      DEFAULT NULL COMMENT '最后一次重录时间',

  -- AI质检结果（汇总）
  `ai_check_status`       TINYINT       DEFAULT 0 COMMENT 'AI质检状态：0-未质检 1-质检中 2-已完成 9-质检失败待人工',
  `ai_check_result`       JSON          DEFAULT NULL COMMENT 'AI质检汇总结果JSON，含score/violations/keywords等',
  `ai_final_score`        DECIMAL(5,2)  DEFAULT NULL COMMENT 'AI质检最终得分（满分100）',
  `violation_count`       INT           DEFAULT 0 COMMENT 'AI质检发现的违规次数',

  -- 人工质检结果
  `manual_check_user_id`  BIGINT        DEFAULT NULL COMMENT '人工质检员ID',
  `manual_check_user_name` VARCHAR(50)  DEFAULT NULL COMMENT '人工质检员姓名',
  `manual_check_time`     DATETIME      DEFAULT NULL COMMENT '人工质检完成时间',
  `manual_check_result`   TINYINT       DEFAULT NULL COMMENT '人工质检结论：1-通过 2-不通过',
  `manual_check_remark`   VARCHAR(1000) DEFAULT NULL COMMENT '人工质检备注（不通过时必填，至少20字）',

  -- 区块链存证（冗余到主表，便于快速查询）
  `blockchain_hash`       VARCHAR(256)  DEFAULT NULL COMMENT '区块链存证交易Hash',
  `blockchain_time`       DATETIME      DEFAULT NULL COMMENT '区块链存证时间',

  -- 质检报告
  `report_url`            VARCHAR(500)  DEFAULT NULL COMMENT '质检报告PDF OSS路径（生成后缓存）',

  -- 通用字段
  `remark`                VARCHAR(500)  DEFAULT NULL COMMENT '备注（记录异常信息，如RTC断线时间等）',
  `creator`               VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '创建者（业务员账号）',
  `create_time`           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`               VARCHAR(64)   NOT NULL DEFAULT '' COMMENT '更新者',
  `update_time`           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`               BIT(1)        NOT NULL DEFAULT b'0' COMMENT '逻辑删除（0-未删除 1-已删除）',
  `tenant_id`             BIGINT        NOT NULL DEFAULT 0 COMMENT '租户ID（多租户隔离）',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_record_code` (`record_code`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_agent_id` (`agent_id`, `create_time`),
  KEY `idx_customer_id` (`customer_id`),
  KEY `idx_agent_org_id` (`agent_org_id`),
  KEY `idx_record_status` (`record_status`, `create_time`),
  KEY `idx_ai_check_status` (`ai_check_status`),
  KEY `idx_product_id` (`product_id`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='双录会话主表（RTC房间/参与者/节点进度/质检状态）';


-- -------------------------------------------------------------------
-- 1.2 重录日志表 ins_comp_retry_log
-- 职责：记录每次申请重录的原因、操作人、审批状态，支持审计追溯
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_comp_retry_log`;
CREATE TABLE `ins_comp_retry_log` (
  `id`              BIGINT        NOT NULL AUTO_INCREMENT COMMENT '日志ID',
  `session_id`      BIGINT        NOT NULL COMMENT '双录会话ID（关联ins_comp_recording_session）',
  `record_code`     VARCHAR(50)   NOT NULL COMMENT '双录编号（冗余，便于查询）',
  `retry_seq`       INT           NOT NULL COMMENT '第几次重录（从1开始）',
  `from_node_index` INT           NOT NULL COMMENT '从第几个节点开始重录',
  `retry_reason`    VARCHAR(500)  NOT NULL COMMENT '重录原因',
  `operator_id`     BIGINT        NOT NULL COMMENT '申请重录的操作人ID',
  `operator_name`   VARCHAR(50)   NOT NULL COMMENT '操作人姓名',

  -- 超限审批（retry_count >= max_retry时需主管审批）
  `need_approve`    BIT(1)        NOT NULL DEFAULT b'0' COMMENT '是否需要主管审批',
  `approve_user_id` BIGINT        DEFAULT NULL COMMENT '审批人ID',
  `approve_result`  TINYINT       DEFAULT NULL COMMENT '审批结果：1-同意 2-拒绝',
  `approve_remark`  VARCHAR(500)  DEFAULT NULL COMMENT '审批备注',
  `approve_time`    DATETIME      DEFAULT NULL COMMENT '审批时间',

  `creator`         VARCHAR(64)   NOT NULL DEFAULT '',
  `create_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         VARCHAR(64)   NOT NULL DEFAULT '',
  `update_time`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         BIT(1)        NOT NULL DEFAULT b'0',
  `tenant_id`       BIGINT        NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  KEY `idx_session_id` (`session_id`),
  KEY `idx_record_code` (`record_code`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='双录重录日志表（记录每次重录申请及审批记录）';


-- =====================================================================
-- 二、话术模板（脚本节点/关键词/禁用词配置）
-- =====================================================================

-- -------------------------------------------------------------------
-- 2.1 话术模板主表 ins_comp_script_template
-- 职责：配置双录话术节点（节点JSON）、全局关键词、禁用词、版本管理
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_comp_script_template`;
CREATE TABLE `ins_comp_script_template` (
  `id`                  BIGINT        NOT NULL AUTO_INCREMENT COMMENT '模板ID',
  `template_code`       VARCHAR(50)   NOT NULL COMMENT '模板编号（租户内唯一），如TMPL_FENHONG_V1',
  `template_name`       VARCHAR(100)  NOT NULL COMMENT '模板名称，如分红险标准话术V1.0',
  `product_type`        TINYINT       NOT NULL COMMENT '适用产品类型：0-通用 1-分红险 2-万能险 3-投连险 4-普通寿险 5-健康险',
  `age_min`             INT           DEFAULT NULL COMMENT '适用客户最小年龄（含），null表示不限',
  `age_max`             INT           DEFAULT NULL COMMENT '适用客户最大年龄（含），null表示不限',

  -- 话术节点配置（核心字段）
  -- JSON结构示例：
  -- [
  --   {
  --     "nodeIndex": 1,
  --     "nodeName": "身份确认",
  --     "nodeType": "MUST",           // MUST=必读 OPTIONAL=选读
  --     "scriptContent": "您好，我是XX...",
  --     "expectedResponse": "客户口头确认本人身份",
  --     "keyWords": ["本人", "代理人"],
  --     "forbiddenWords": ["保本"],
  --     "minDuration": 10             // 最短停留秒数
  --   }
  -- ]
  `script_nodes`        JSON          NOT NULL COMMENT '话术节点配置数组（含nodeIndex/nodeName/nodeType/scriptContent/keyWords/forbiddenWords/minDuration）',
  `total_nodes`         INT           NOT NULL COMMENT '节点总数（保存时自动计算）',
  `must_node_indexes`   JSON          DEFAULT NULL COMMENT '必读节点的nodeIndex数组，如[1,2,3]（保存时自动计算）',

  -- 全局关键词与禁用词（节点内单独配置的优先级高于全局）
  `key_words`           JSON          DEFAULT NULL COMMENT '全局必读关键词列表（ASR检测范围：整个双录全文）',
  `forbidden_words`     JSON          DEFAULT NULL COMMENT '全局禁用词列表（违规则扣20分/词）',

  -- 时长与重录控制
  `min_duration`        INT           DEFAULT NULL COMMENT '整个双录最短时长（秒），低于此值记录警告',
  `max_retry`           INT           NOT NULL DEFAULT 3 COMMENT '允许的最大重录次数（默认3，最大10）',

  -- 版本管理
  `version`             VARCHAR(20)   NOT NULL DEFAULT '1.0' COMMENT '版本号，如1.0、2.1',
  `is_active`           BIT(1)        NOT NULL DEFAULT b'1' COMMENT '是否启用（同类型仅最新版本启用）',

  `remark`              VARCHAR(500)  DEFAULT NULL COMMENT '备注',
  `creator`             VARCHAR(64)   NOT NULL DEFAULT '',
  `create_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`             VARCHAR(64)   NOT NULL DEFAULT '',
  `update_time`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`             BIT(1)        NOT NULL DEFAULT b'0',
  `tenant_id`           BIGINT        NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_template_code` (`template_code`, `tenant_id`),
  KEY `idx_product_type` (`product_type`, `is_active`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='话术模板表（节点JSON/关键词/禁用词/版本管理）';

-- script_nodes字段JSON结构补充说明（以注释形式记录）:
-- nodeType枚举: MUST=必读节点（不可跳过），OPTIONAL=选读节点
-- 模板匹配优先级: product_type精确匹配 > product_type=0(通用)；同类型取version最大且is_active=1的


-- =====================================================================
-- 三、AI质检结果
-- =====================================================================

-- -------------------------------------------------------------------
-- 3.1 AI质检结果主表 ins_comp_quality_check
-- 职责：记录AI质检（ASR转写/关键词/禁用词/人脸识别/证件识别）的完整结果，支持人工复核
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_comp_quality_check`;
CREATE TABLE `ins_comp_quality_check` (
  `id`                       BIGINT        NOT NULL AUTO_INCREMENT COMMENT '质检记录ID',
  `session_id`               BIGINT        NOT NULL COMMENT '双录会话ID（关联ins_comp_recording_session）',
  `record_code`              VARCHAR(50)   NOT NULL COMMENT '双录编号（冗余）',
  `check_type`               TINYINT       NOT NULL COMMENT '质检类型：1-AI自动质检 2-人工质检',
  `check_status`             TINYINT       NOT NULL DEFAULT 0 COMMENT '质检状态：0-待处理 1-检测中 2-已完成 9-失败待人工',
  `check_round`              INT           NOT NULL DEFAULT 1 COMMENT '质检轮次（重录后重新质检则+1）',

  -- ===== ASR语音转文字 =====
  `asr_task_id`              VARCHAR(100)  DEFAULT NULL COMMENT '阿里云ASR任务ID（用于定时轮询）',
  `asr_text`                 MEDIUMTEXT    DEFAULT NULL COMMENT 'ASR识别全文（完整转写文本，可能数千字）',
  `asr_confidence`           DECIMAL(5,4)  DEFAULT NULL COMMENT 'ASR识别整体置信度（0.0~1.0）',
  `asr_detail`               JSON          DEFAULT NULL COMMENT 'ASR分段结果（含时间戳）: [{"start":0,"end":5000,"text":"..","confidence":0.95}]',
  `asr_status`               TINYINT       DEFAULT 0 COMMENT 'ASR状态：0-未提交 1-提交中 2-已完成 9-失败',

  -- ===== 关键词检测结果 =====
  -- JSON结构：{"hitCount":3,"totalCount":5,"missingKeywords":["犹豫期","风险等级"],"hitDetail":[{"keyword":"本人","nodeIndex":1,"found":true}]}
  `keyword_check_result`     JSON          DEFAULT NULL COMMENT '关键词检测结果JSON',
  `keyword_hit_count`        INT           DEFAULT 0 COMMENT '命中的关键词数量',
  `keyword_total_count`      INT           DEFAULT 0 COMMENT '应该命中的关键词总数',
  `keyword_score_deduct`     DECIMAL(5,2)  DEFAULT 0 COMMENT '关键词漏读扣分（每个遗漏-5分）',

  -- ===== 禁用词检测结果 =====
  -- JSON结构：[{"word":"保本","nodeIndex":2,"timeOffset":35,"deduct":20},...]
  `forbidden_word_result`    JSON          DEFAULT NULL COMMENT '禁用词命中记录JSON（含时间偏移、节点、扣分）',
  `forbidden_word_hit_count` INT           DEFAULT 0 COMMENT '命中的禁用词次数',
  `forbidden_score_deduct`   DECIMAL(5,2)  DEFAULT 0 COMMENT '禁用词扣分（每次命中-20分）',

  -- ===== 节点完成度检测 =====
  -- JSON结构：[{"nodeIndex":1,"required":true,"completed":true,"actualDuration":25,"minDuration":10}]
  `node_check_result`        JSON          DEFAULT NULL COMMENT '节点完成度检测结果JSON',
  `node_skip_count`          INT           DEFAULT 0 COMMENT '跳过的必读节点数量',
  `node_score_deduct`        DECIMAL(5,2)  DEFAULT 0 COMMENT '节点跳过扣分（每个必读节点-15分）',

  -- ===== 人脸识别检测 =====
  `face_check_result`        TINYINT       DEFAULT NULL COMMENT '人脸识别结论：1-通过 2-不通过 3-检测失败',
  `face_similarity_score`    DECIMAL(5,2)  DEFAULT NULL COMMENT '人脸相似度得分（0~100，≥80通过）',
  `face_frame_url`           VARCHAR(500)  DEFAULT NULL COMMENT '视频截帧图片OSS路径（用于人脸比对）',
  `face_score_deduct`        DECIMAL(5,2)  DEFAULT 0 COMMENT '人脸识别扣分（不通过-30分）',

  -- ===== 证件OCR识别检测 =====
  `idcard_check_result`      TINYINT       DEFAULT NULL COMMENT '证件检测结论：1-通过 2-翻拍 3-信息不符 4-检测失败',
  `idcard_ocr_name`          VARCHAR(50)   DEFAULT NULL COMMENT 'OCR识别的姓名',
  `idcard_ocr_no`            VARCHAR(50)   DEFAULT NULL COMMENT 'OCR识别的身份证号（脱敏存储：前6后4）',
  `idcard_is_original`       BIT(1)        DEFAULT NULL COMMENT '是否为原件（非翻拍）',
  `idcard_match_result`      BIT(1)        DEFAULT NULL COMMENT 'OCR结果与投保人信息是否一致',
  `idcard_score_deduct`      DECIMAL(5,2)  DEFAULT 0 COMMENT '证件检测扣分（翻拍-30分，信息不符-50分）',

  -- ===== 评分汇总 =====
  `base_score`               DECIMAL(5,2)  NOT NULL DEFAULT 100 COMMENT '基础分（100分）',
  `total_deduct`             DECIMAL(5,2)  NOT NULL DEFAULT 0 COMMENT '总扣分',
  `final_score`              DECIMAL(5,2)  DEFAULT NULL COMMENT '最终得分（满分100，<60不合格）',
  `score_level`              VARCHAR(10)   DEFAULT NULL COMMENT '评分等级：EXCELLENT(90-100)/GOOD(80-89)/PASS(60-79)/FAIL(<60)',

  -- ===== 违规项明细 =====
  -- JSON结构：[{"type":"FORBIDDEN_WORD","description":"使用禁用词：保本","timeOffset":35,"nodeIndex":2,"deduct":20}]
  `violation_items`          JSON          DEFAULT NULL COMMENT '违规项明细列表JSON（用于质检报告展示）',

  -- ===== 人工质检信息 =====
  `check_user_id`            BIGINT        DEFAULT NULL COMMENT '质检员用户ID（人工质检时填写）',
  `check_user_name`          VARCHAR(50)   DEFAULT NULL COMMENT '质检员姓名',
  `check_result`             TINYINT       DEFAULT NULL COMMENT '质检结论：1-通过 2-不通过',
  `check_remark`             VARCHAR(1000) DEFAULT NULL COMMENT '质检意见（不通过时必填，≥20字）',
  `check_time`               DATETIME      DEFAULT NULL COMMENT '质检完成时间',

  -- ===== 系统触发信息 =====
  `trigger_source`           VARCHAR(50)   DEFAULT 'MQ' COMMENT '触发来源：MQ/SCHEDULE/MANUAL（手动补跑）',
  `fail_reason`              VARCHAR(500)  DEFAULT NULL COMMENT '质检失败原因（如ASR调用异常）',
  `retry_count`              INT           DEFAULT 0 COMMENT 'AI服务调用重试次数',

  `creator`                  VARCHAR(64)   NOT NULL DEFAULT '',
  `create_time`              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`                  VARCHAR(64)   NOT NULL DEFAULT '',
  `update_time`              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`                  BIT(1)        NOT NULL DEFAULT b'0',
  `tenant_id`                BIGINT        NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  KEY `idx_session_id` (`session_id`),
  KEY `idx_record_code` (`record_code`),
  KEY `idx_check_status` (`check_status`, `create_time`),
  KEY `idx_check_type` (`check_type`, `check_status`),
  KEY `idx_asr_task_id` (`asr_task_id`),
  KEY `idx_check_user_id` (`check_user_id`),
  KEY `idx_score_level` (`score_level`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='AI质检结果表（ASR文本/命中关键词/评分/人工复核）';

-- 评分规则备注：
-- FORBIDDEN_WORD: 每命中一个禁用词 -20分
-- MISSING_KEYWORD: 每遗漏一个必读关键词 -5分
-- SKIP_MUST_NODE: 每跳过一个必读节点 -15分
-- FACE_FAIL: 人脸识别不通过 -30分
-- ID_CARD_FAKE: 证件翻拍 -30分
-- ID_CARD_MISMATCH: 证件信息不符 -50分
-- 等级: 90-100=EXCELLENT 80-89=GOOD 60-79=PASS <60=FAIL


-- =====================================================================
-- 四、区块链存证
-- =====================================================================

-- -------------------------------------------------------------------
-- 4.1 存证记录主表 ins_comp_evidence_record
-- 职责：记录区块链存证的文件信息、链上哈希、验证状态，支持蚂蚁链/腾讯至信链
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_comp_evidence_record`;
CREATE TABLE `ins_comp_evidence_record` (
  `id`                    BIGINT        NOT NULL AUTO_INCREMENT COMMENT '存证记录ID',
  `evidence_code`         VARCHAR(50)   NOT NULL COMMENT '存证编号（系统生成唯一编号，用于公开验证）',

  -- 关联信息
  `session_id`            BIGINT        DEFAULT NULL COMMENT '关联双录会话ID（ins_comp_recording_session）',
  `record_code`           VARCHAR(50)   DEFAULT NULL COMMENT '双录编号（冗余）',
  `order_id`              BIGINT        DEFAULT NULL COMMENT '关联订单ID',
  `evidence_type`         TINYINT       NOT NULL COMMENT '存证类型：1-双录视频 2-行为轨迹 3-质检报告 4-签字确认',
  `evidence_name`         VARCHAR(200)  NOT NULL COMMENT '存证文件名称（如：双录视频-DR202602140001）',

  -- 存证文件信息
  `file_hash`             VARCHAR(256)  NOT NULL COMMENT '存证文件SHA-256哈希值（存证前计算）',
  `file_url`              VARCHAR(500)  NOT NULL COMMENT '文件OSS存储路径',
  `file_size`             BIGINT        NOT NULL COMMENT '文件大小（字节）',
  `file_type`             VARCHAR(20)   DEFAULT NULL COMMENT '文件类型（如：mp4/pdf/json）',

  -- 区块链信息
  `blockchain_type`       TINYINT       NOT NULL COMMENT '区块链平台：1-蚂蚁链(AntChain) 2-腾讯至信链',
  `blockchain_tx_id`      VARCHAR(256)  NOT NULL COMMENT '区块链交易ID（Transaction Hash）',
  `blockchain_block_height` BIGINT      DEFAULT NULL COMMENT '所在区块高度',
  `blockchain_timestamp`  BIGINT        NOT NULL COMMENT '区块链存证时间戳（毫秒）',
  `blockchain_raw`        JSON          DEFAULT NULL COMMENT '链上原始响应JSON（用于审计）',

  -- 验证信息
  `verify_url`            VARCHAR(500)  DEFAULT NULL COMMENT '在线验证链接（可公开访问）',
  `is_verified`           BIT(1)        NOT NULL DEFAULT b'0' COMMENT '是否已完成完整性验证校验',
  `verify_time`           DATETIME      DEFAULT NULL COMMENT '最后验证时间',
  `verify_result`         TINYINT       DEFAULT NULL COMMENT '验证结果：1-验证通过 2-验证失败',

  -- 存证状态
  `evidence_status`       TINYINT       NOT NULL DEFAULT 0 COMMENT '存证状态：0-待存证 1-存证中 2-存证成功 3-存证失败',
  `fail_reason`           VARCHAR(500)  DEFAULT NULL COMMENT '存证失败原因',
  `retry_count`           INT           DEFAULT 0 COMMENT '存证重试次数',

  -- 触发信息
  `trigger_type`          VARCHAR(20)   DEFAULT 'AUTO' COMMENT '触发方式：AUTO-自动（双录完成后24h内）MANUAL-管理员手动',
  `trigger_user_id`       BIGINT        DEFAULT NULL COMMENT '手动触发的管理员ID',

  `remark`                VARCHAR(500)  DEFAULT NULL,
  `creator`               VARCHAR(64)   NOT NULL DEFAULT '',
  `create_time`           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`               VARCHAR(64)   NOT NULL DEFAULT '',
  `update_time`           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`               BIT(1)        NOT NULL DEFAULT b'0',
  `tenant_id`             BIGINT        NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_evidence_code` (`evidence_code`),
  UNIQUE KEY `uk_blockchain_tx_id` (`blockchain_tx_id`),
  KEY `idx_session_id` (`session_id`),
  KEY `idx_record_code` (`record_code`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_evidence_type` (`evidence_type`, `evidence_status`),
  KEY `idx_evidence_status` (`evidence_status`, `create_time`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='区块链存证记录表（文件哈希/链上交易ID/验证状态）';


-- =====================================================================
-- 五、行为轨迹（C端投保可回溯埋点）
-- =====================================================================

-- -------------------------------------------------------------------
-- 5.1 行为轨迹主表 ins_comp_behavior_trace
-- 职责：记录C端用户在投保关键页面的停留、交互、截图，满足监管可回溯要求
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_comp_behavior_trace`;
CREATE TABLE `ins_comp_behavior_trace` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT COMMENT '轨迹记录ID',
  `order_id`         BIGINT       NOT NULL COMMENT '投保订单ID',
  `policy_no`        VARCHAR(100) DEFAULT NULL COMMENT '保单号（成单后回填）',
  `user_id`          BIGINT       NOT NULL COMMENT 'C端用户ID（member模块）',

  -- 页面信息
  `page_type`        TINYINT      NOT NULL COMMENT '页面类型：1-产品详情 2-健康告知 3-投保须知 4-条款展示 5-支付确认',
  `page_title`       VARCHAR(100) DEFAULT NULL COMMENT '页面标题（如产品名称）',
  `page_url`         VARCHAR(500) DEFAULT NULL COMMENT '页面路径',

  -- 停留行为
  `enter_time`       DATETIME     NOT NULL COMMENT '进入页面时间',
  `leave_time`       DATETIME     DEFAULT NULL COMMENT '离开页面时间',
  `stay_duration`    INT          DEFAULT 0 COMMENT '实际停留时长（秒）',
  `min_required`     INT          DEFAULT NULL COMMENT '该页面要求最低停留时长（秒），来自系统配置',
  `is_qualified`     BIT(1)       DEFAULT NULL COMMENT '停留时长是否达标',
  `scroll_depth`     INT          DEFAULT NULL COMMENT '页面滚动深度（百分比，0-100）',

  -- 交互事件
  `event_type`       VARCHAR(50)  DEFAULT NULL COMMENT '事件类型：PAGE_ENTER/PAGE_LEAVE/ELEMENT_CLICK/SCROLL/SCREENSHOT',
  `event_detail`     JSON         DEFAULT NULL COMMENT '事件详情JSON（如健康告知各题点击时间/选择值）',

  -- 截图存证
  `screenshot_url`   VARCHAR(500) DEFAULT NULL COMMENT '页面截图OSS路径（带时间戳水印）',
  `screenshot_time`  DATETIME     DEFAULT NULL COMMENT '截图时间',

  -- 设备信息
  `device_type`      VARCHAR(20)  DEFAULT NULL COMMENT '设备类型：WECHAT_MINI/H5/APP',
  `device_info`      VARCHAR(500) DEFAULT NULL COMMENT '设备信息（UA/机型/OS）',
  `client_ip`        VARCHAR(50)  DEFAULT NULL COMMENT '客户端IP',

  `creator`          VARCHAR(64)  NOT NULL DEFAULT '',
  `create_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64)  NOT NULL DEFAULT '',
  `update_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          BIT(1)       NOT NULL DEFAULT b'0',
  `tenant_id`        BIGINT       NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_page_type` (`page_type`),
  KEY `idx_enter_time` (`enter_time`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='C端投保行为轨迹表（停留时长/交互事件/截图存证）';


-- =====================================================================
-- 六、合规系统配置
-- =====================================================================

-- -------------------------------------------------------------------
-- 6.1 双录触发规则配置表 ins_comp_trigger_rule
-- 职责：可动态配置的双录触发规则，支持多租户差异化配置
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_comp_trigger_rule`;
CREATE TABLE `ins_comp_trigger_rule` (
  `id`             BIGINT        NOT NULL AUTO_INCREMENT COMMENT '规则ID',
  `rule_code`      VARCHAR(50)   NOT NULL COMMENT '规则编码：AGE_LIMIT/SINGLE_PREMIUM/ANNUAL_PREMIUM/NEW_PRODUCT/COMPANY_REQUIRE',
  `rule_name`      VARCHAR(100)  NOT NULL COMMENT '规则名称',
  `rule_scene`     TINYINT       NOT NULL COMMENT '触发场景值（写入双录记录的record_scene字段）',
  `is_enabled`     BIT(1)        NOT NULL DEFAULT b'1' COMMENT '是否启用',
  `threshold_value` DECIMAL(12,2) DEFAULT NULL COMMENT '阈值（年龄规则为60，趸交规则为50000，期交规则为20000）',
  `threshold_unit` VARCHAR(20)   DEFAULT NULL COMMENT '阈值单位（years/yuan）',
  `description`    VARCHAR(500)  DEFAULT NULL COMMENT '规则说明',

  `creator`        VARCHAR(64)   NOT NULL DEFAULT '',
  `create_time`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`        VARCHAR(64)   NOT NULL DEFAULT '',
  `update_time`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`        BIT(1)        NOT NULL DEFAULT b'0',
  `tenant_id`      BIGINT        NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rule_code` (`rule_code`, `tenant_id`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='双录触发规则配置表（年龄/保费/产品类型等触发条件）';


-- -------------------------------------------------------------------
-- 6.2 合规系统配置表 ins_comp_system_config
-- 职责：存储合规模块的运行参数，如抽检比例、视频保留期、AI质检超时等
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `ins_comp_system_config`;
CREATE TABLE `ins_comp_system_config` (
  `id`           BIGINT        NOT NULL AUTO_INCREMENT COMMENT '配置ID',
  `config_key`   VARCHAR(100)  NOT NULL COMMENT '配置键',
  `config_value` VARCHAR(1000) NOT NULL COMMENT '配置值',
  `config_desc`  VARCHAR(500)  DEFAULT NULL COMMENT '配置说明',
  `config_type`  VARCHAR(20)   DEFAULT 'STRING' COMMENT '值类型：STRING/INT/DECIMAL/JSON/BOOLEAN',
  `is_enabled`   BIT(1)        NOT NULL DEFAULT b'1' COMMENT '是否启用',

  `creator`      VARCHAR(64)   NOT NULL DEFAULT '',
  `create_time`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`      VARCHAR(64)   NOT NULL DEFAULT '',
  `update_time`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`      BIT(1)        NOT NULL DEFAULT b'0',
  `tenant_id`    BIGINT        NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_config_key` (`config_key`, `tenant_id`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='合规系统配置表（抽检比例/存储期限/AI超时等运行参数）';

-- 初始化默认配置数据
INSERT INTO `ins_comp_system_config` (`config_key`, `config_value`, `config_desc`, `config_type`, `tenant_id`) VALUES
('manual_check_ratio',       '20',    'AI质检通过后触发人工抽检的比例（百分比，默认20%）',   'INT',     0),
('video_retention_years',    '5',     '双录视频最低保留年限（监管要求≥5年）',              'INT',     0),
('ai_check_timeout_hours',   '72',    'AI质检最大等待时长（小时），超时后进入人工处理队列',   'INT',     0),
('evidence_deadline_hours',  '24',    '双录完成后区块链存证截止时限（小时）',               'INT',     0),
('manual_check_deadline_days','7',    '人工质检最大等待工作日数，超时自动催办',             'INT',     0),
('rtc_token_expire_hours',   '8',     '声网RTC Token有效期（小时）',                     'INT',     0),
('invite_url_expire_minutes','30',    '客户端邀请链接有效期（分钟）',                      'INT',     0),
('asr_poll_interval_seconds','30',    'ASR结果轮询间隔（秒）',                          'INT',     0),
('face_pass_threshold',      '80',    '人脸识别通过阈值（相似度，0-100）',                 'DECIMAL', 0),
('forbidden_words_global',   '["保本","无风险","固定收益","保证赚钱","稳赚不赔","银行存款","储蓄险","高回报","零风险"]',
                                      '系统内置全局禁用词（各租户可在话术模板中覆盖）',     'JSON',    0);


-- =====================================================================
-- 七、索引与视图补充
-- =====================================================================

-- 为合规报表统计创建复合索引（按产品类型+创建时间统计通过率）
ALTER TABLE `ins_comp_recording_session`
  ADD KEY `idx_stat_report` (`tenant_id`, `product_type`, `record_status`, `create_time`);

ALTER TABLE `ins_comp_quality_check`
  ADD KEY `idx_stat_check` (`tenant_id`, `check_type`, `final_score`, `create_time`);


-- =====================================================================
-- 八、表结构总览说明（注释）
-- =====================================================================
-- 
-- 表名                          前缀          功能                     对应DO类
-- ──────────────────────────────────────────────────────────────────────────────
-- ins_comp_recording_session    ins_comp_    双录会话主表               InsRecordingSessionDO
-- ins_comp_retry_log            ins_comp_    重录日志                   InsRetryLogDO
-- ins_comp_script_template      ins_comp_    话术模板                   InsScriptTemplateDO
-- ins_comp_quality_check        ins_comp_    AI质检结果                 InsQualityCheckResultDO
-- ins_comp_evidence_record      ins_comp_    区块链存证记录              InsEvidenceRecordDO
-- ins_comp_behavior_trace       ins_comp_    C端行为轨迹                InsBehaviorTraceDO
-- ins_comp_trigger_rule         ins_comp_    双录触发规则配置            InsTriggerRuleDO
-- ins_comp_system_config        ins_comp_    合规系统配置                InsCompSystemConfigDO
--
-- 注：所有表均含 creator/create_time/updater/update_time/deleted/tenant_id 基础字段
--     对应框架 BaseDO，Mapper继承 BaseMapperX，支持多租户自动过滤
-- =====================================================================

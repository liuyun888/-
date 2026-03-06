-- ======================================================
-- 保险中介平台 · C端会员模块（intermediary-module-member）
-- 数据库 Schema: db_member
-- 表前缀: member_
-- 对应工程: intermediary-module-member
-- 基础框架: yudao-cloud (ruoyi-vue-pro 微服务版)
-- 创建日期: 2026-03-01
-- 版本: V1.0
-- ======================================================
-- 注意:
--   1. 所有表均继承框架 BaseDO 字段:
--      creator/updater/create_time/update_time/deleted/tenant_id
--   2. deleted 字段 0=未删除 1=已删除 (逻辑删除)
--   3. 敏感字段采用 AES 加密存储, 明文字段仅做脱敏展示
--   4. 时间字段统一 DATETIME 类型
-- ======================================================

-- ----------------------------------------------------
-- 建库（可选，由 DBA 按环境执行）
-- ----------------------------------------------------
-- CREATE DATABASE IF NOT EXISTS db_member DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE db_member;

-- ======================================================
-- 1. C端用户主表
-- ======================================================
CREATE TABLE `member_user`
(
    `id`               BIGINT      NOT NULL AUTO_INCREMENT COMMENT '用户ID',
    `mobile`           VARCHAR(11) NOT NULL COMMENT '手机号（明文）',
    `mobile_encrypt`   VARCHAR(255)         COMMENT '手机号（AES加密，备用）',
    `nickname`         VARCHAR(50)          COMMENT '昵称，默认"用户+手机号后4位"',
    `avatar`           VARCHAR(500)         COMMENT '头像OSS URL',
    `gender`           TINYINT     NOT NULL DEFAULT 0 COMMENT '性别 0未知 1男 2女',
    `birthday`         DATE                 COMMENT '出生日期',
    `province`         VARCHAR(30)          COMMENT '常住省份',
    `city`             VARCHAR(30)          COMMENT '常住城市',
    `district`         VARCHAR(30)          COMMENT '区县',
    -- 会员等级与积分
    `member_level`     TINYINT     NOT NULL DEFAULT 0 COMMENT '会员等级 0普通 1银卡 2金卡 3钻石',
    `points`           INT         NOT NULL DEFAULT 0 COMMENT '可用积分',
    `total_points`     INT         NOT NULL DEFAULT 0 COMMENT '累计获得积分（用于等级评定）',
    `balance`          BIGINT      NOT NULL DEFAULT 0 COMMENT '账户余额（分）',
    -- 实名认证
    `real_name`        VARCHAR(50)          COMMENT '真实姓名（已认证后填入）',
    `id_card_no`       VARCHAR(50)          COMMENT '身份证号脱敏，如：3101**********1234',
    `id_card_encrypt`  VARCHAR(500)         COMMENT '身份证号AES加密完整值',
    `realname_status`  TINYINT     NOT NULL DEFAULT 0 COMMENT '实名认证状态 0未认证 1认证中 2已认证 3认证失败',
    -- 人脸识别
    `face_verify_status` TINYINT   NOT NULL DEFAULT 0 COMMENT '人脸识别状态 0未认证 1已认证',
    -- 微信相关
    `wechat_openid`    VARCHAR(64)          COMMENT '微信OpenID',
    `wechat_unionid`   VARCHAR(64)          COMMENT '微信UnionID',
    `wechat_nickname`  VARCHAR(100)         COMMENT '微信昵称',
    `wechat_avatar`    VARCHAR(500)         COMMENT '微信头像URL',
    `bind_wechat_time` DATETIME             COMMENT '绑定微信时间',
    `bind_mobile_time` DATETIME             COMMENT '绑定手机号时间',
    -- 账号状态
    `status`           TINYINT     NOT NULL DEFAULT 0 COMMENT '账号状态 0正常 1冻结 2注销',
    `freeze_reason`    VARCHAR(255)         COMMENT '冻结原因',
    -- 登录记录
    `register_time`    DATETIME    NOT NULL COMMENT '注册时间',
    `last_login_time`  DATETIME             COMMENT '最后登录时间',
    `last_login_ip`    VARCHAR(50)          COMMENT '最后登录IP',
    -- 归因业务员（分享/邀请来源）
    `source_agent_id`  BIGINT               COMMENT '来源业务员ID（首次注册时的归因业务员）',
    -- BaseDO 标准字段
    `creator`          VARCHAR(64) NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`      DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`          VARCHAR(64) NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`      DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`          TINYINT     NOT NULL DEFAULT 0 COMMENT '是否删除 0否 1是',
    `tenant_id`        BIGINT      NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_mobile` (`mobile`),
    INDEX `idx_wechat_openid` (`wechat_openid`),
    INDEX `idx_wechat_unionid` (`wechat_unionid`),
    INDEX `idx_status_deleted` (`status`, `deleted`),
    INDEX `idx_member_level` (`member_level`),
    INDEX `idx_source_agent` (`source_agent_id`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = 'C端会员用户主表';


-- ======================================================
-- 2. 短信发送日志表
-- ======================================================
CREATE TABLE `member_sms_log`
(
    `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `mobile`        VARCHAR(11)  NOT NULL COMMENT '手机号',
    `code`          VARCHAR(128) NOT NULL COMMENT '验证码（MD5加密存储）',
    `scene`         TINYINT      NOT NULL COMMENT '使用场景 1注册登录 2找回密码 3绑定手机 4解绑手机',
    `verify_status` TINYINT      NOT NULL DEFAULT 0 COMMENT '验证状态 0未验证 1已验证 2已过期',
    `verify_time`   DATETIME                COMMENT '验证时间',
    `ip_address`    VARCHAR(50)             COMMENT '请求IP地址',
    `send_time`     DATETIME     NOT NULL COMMENT '发送时间',
    `expire_time`   DATETIME     NOT NULL COMMENT '过期时间（发送时间+5分钟）',
    `send_result`   TINYINT      NOT NULL DEFAULT 0 COMMENT '发送结果 0发送中 1成功 2失败',
    `fail_reason`   VARCHAR(255)            COMMENT '发送失败原因',
    `creator`       VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`       VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`       TINYINT      NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`     BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    INDEX `idx_mobile_scene_send` (`mobile`, `scene`, `send_time`),
    INDEX `idx_ip_send_time` (`ip_address`, `send_time`),
    INDEX `idx_expire_status` (`expire_time`, `verify_status`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '短信发送日志表';


-- ======================================================
-- 3. 登录日志表
-- ======================================================
CREATE TABLE `member_login_log`
(
    `id`           BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`      BIGINT      NOT NULL COMMENT '用户ID',
    `mobile`       VARCHAR(11) NOT NULL COMMENT '手机号',
    `login_ip`     VARCHAR(50)          COMMENT '登录IP',
    `login_region` VARCHAR(100)         COMMENT 'IP归属地（省-市）',
    `device_type`  VARCHAR(30)          COMMENT '设备类型 iOS/Android/H5/MiniProgram',
    `login_type`   TINYINT     NOT NULL DEFAULT 1 COMMENT '登录方式 1短信验证码 2微信授权',
    `login_result` TINYINT     NOT NULL DEFAULT 1 COMMENT '登录结果 1成功 2失败',
    `fail_reason`  VARCHAR(255)         COMMENT '失败原因',
    `login_time`   DATETIME    NOT NULL COMMENT '登录时间',
    `user_agent`   VARCHAR(500)         COMMENT '客户端UserAgent',
    `creator`      VARCHAR(64) NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`      VARCHAR(64) NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`      TINYINT     NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`    BIGINT      NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    INDEX `idx_user_login_time` (`user_id`, `login_time`),
    INDEX `idx_login_time` (`login_time`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员登录日志表';


-- ======================================================
-- 4. 实名认证记录表
-- ======================================================
CREATE TABLE `member_user_realname`
(
    `id`              BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`         BIGINT       NOT NULL COMMENT '用户ID',
    `real_name`       VARCHAR(50)  NOT NULL COMMENT '真实姓名',
    `id_card_no`      VARCHAR(50)  NOT NULL COMMENT '身份证号脱敏存储',
    `id_card_encrypt` VARCHAR(500) NOT NULL COMMENT '身份证号AES加密完整值',
    `id_card_front`   VARCHAR(500)          COMMENT '身份证正面OSS URL',
    `id_card_back`    VARCHAR(500)          COMMENT '身份证背面OSS URL',
    `status`          TINYINT      NOT NULL DEFAULT 0 COMMENT '认证状态 0审核中 1通过 2失败',
    `fail_reason`     VARCHAR(255)          COMMENT '认证失败原因',
    `submit_time`     DATETIME     NOT NULL COMMENT '提交认证时间',
    `verify_time`     DATETIME              COMMENT '认证完成时间',
    `verify_channel`  VARCHAR(50)           COMMENT '认证渠道（aliyun/tencent）',
    `third_biz_id`    VARCHAR(100)          COMMENT '第三方认证业务流水号',
    `creator`         VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`         VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`         TINYINT      NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`       BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_id` (`user_id`),
    INDEX `idx_status` (`status`, `submit_time`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员实名认证记录表';


-- ======================================================
-- 5. 人脸识别日志表
-- ======================================================
CREATE TABLE `member_face_verify_log`
(
    `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`       BIGINT       NOT NULL COMMENT '用户ID',
    `biz_token`     VARCHAR(128) NOT NULL COMMENT '第三方人脸识别业务Token',
    `similarity`    DECIMAL(5, 2)         COMMENT '相似度（0-100）',
    `verify_result` TINYINT      NOT NULL COMMENT '识别结果 1通过 2失败',
    `fail_reason`   VARCHAR(255)          COMMENT '失败原因',
    `verify_channel` VARCHAR(50)          COMMENT '识别渠道（aliyun/tencent）',
    `verify_time`   DATETIME     NOT NULL COMMENT '识别时间',
    `scene`         TINYINT      NOT NULL DEFAULT 1 COMMENT '使用场景 1高保额投保 2账户提现',
    `creator`       VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`       VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`       TINYINT      NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`     BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    INDEX `idx_user_verify_time` (`user_id`, `verify_time`),
    INDEX `idx_biz_token` (`biz_token`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员人脸识别日志表';


-- ======================================================
-- 6. 家庭成员表
-- ======================================================
CREATE TABLE `member_family`
(
    `id`          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`     BIGINT       NOT NULL COMMENT '用户ID',
    `name`        VARCHAR(50)  NOT NULL COMMENT '家庭成员姓名',
    `relation`    VARCHAR(20)  NOT NULL COMMENT '与用户关系 spouse/child/parent/sibling/other',
    `id_type`     TINYINT      NOT NULL COMMENT '证件类型 1居民身份证 2护照 3港澳通行证',
    `id_no`       VARCHAR(500) NOT NULL COMMENT '证件号码（AES加密存储）',
    `id_no_mask`  VARCHAR(50)  NOT NULL COMMENT '证件号脱敏展示',
    `gender`      TINYINT               COMMENT '性别 0未知 1男 2女',
    `birthday`    DATE         NOT NULL COMMENT '出生日期',
    `mobile`      VARCHAR(11)           COMMENT '联系手机号',
    `status`      TINYINT      NOT NULL DEFAULT 0 COMMENT '状态 0正常 1已删除',
    `sort`        INT          NOT NULL DEFAULT 0 COMMENT '排序',
    `creator`     VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`     VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`     TINYINT      NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`   BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    INDEX `idx_user_status` (`user_id`, `status`, `deleted`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员家庭成员表';


-- ======================================================
-- 7. 收货地址表
-- ======================================================
CREATE TABLE `member_address`
(
    `id`              BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`         BIGINT       NOT NULL COMMENT '用户ID',
    `receiver_name`   VARCHAR(50)  NOT NULL COMMENT '收件人姓名',
    `receiver_mobile` VARCHAR(11)  NOT NULL COMMENT '收件人手机号',
    `province`        VARCHAR(30)  NOT NULL COMMENT '省份',
    `city`            VARCHAR(30)  NOT NULL COMMENT '城市',
    `district`        VARCHAR(30)  NOT NULL COMMENT '区县',
    `detail_address`  VARCHAR(255) NOT NULL COMMENT '详细地址',
    `is_default`      TINYINT      NOT NULL DEFAULT 0 COMMENT '是否默认地址 0否 1是',
    `creator`         VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`         VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`         TINYINT      NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`       BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    INDEX `idx_user_default` (`user_id`, `is_default`, `deleted`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员收货地址表';


-- ======================================================
-- 8. 银行卡表
-- ======================================================
CREATE TABLE `member_bank_card`
(
    `id`              BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`         BIGINT       NOT NULL COMMENT '用户ID',
    `card_no_encrypt` VARCHAR(500) NOT NULL COMMENT '银行卡号（AES加密完整卡号）',
    `card_no_mask`    VARCHAR(50)  NOT NULL COMMENT '银行卡号脱敏（尾号4位展示）',
    `bank_code`       VARCHAR(20)  NOT NULL COMMENT '银行编码 ICBC/CCB/CMB/...',
    `bank_name`       VARCHAR(50)  NOT NULL COMMENT '银行名称',
    `holder_name`     VARCHAR(50)  NOT NULL COMMENT '持卡人姓名',
    `bind_mobile`     VARCHAR(11)  NOT NULL COMMENT '开户手机号（脱敏展示：138****8888）',
    `bind_mobile_encrypt` VARCHAR(255) NOT NULL COMMENT '开户手机号（加密存储）',
    `card_type`       TINYINT      NOT NULL DEFAULT 1 COMMENT '卡类型 1借记卡 2信用卡',
    `status`          TINYINT      NOT NULL DEFAULT 0 COMMENT '状态 0正常 1已解绑',
    `bind_time`       DATETIME     NOT NULL COMMENT '绑定时间',
    `unbind_time`     DATETIME              COMMENT '解绑时间',
    `creator`         VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`         VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`         TINYINT      NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`       BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    INDEX `idx_user_status` (`user_id`, `status`, `deleted`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员银行卡表';


-- ======================================================
-- 9. 产品收藏表（险种通用：车险/非车险/寿险）
--    归属 member 模块，跨业务通用
-- ======================================================
CREATE TABLE `member_favorite`
(
    `id`           BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`      BIGINT      NOT NULL COMMENT 'C端用户ID',
    `product_id`   BIGINT      NOT NULL COMMENT '产品ID',
    `product_type` VARCHAR(20) NOT NULL DEFAULT 'NON_CAR' COMMENT '险种类型 CAR/NON_CAR/LIFE',
    `creator`      VARCHAR(64) NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`      VARCHAR(64) NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`      TINYINT     NOT NULL DEFAULT 0 COMMENT '是否删除（0否=收藏 1是=取消收藏）',
    `tenant_id`    BIGINT      NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_product` (`user_id`, `product_id`, `product_type`),
    INDEX `idx_user_type` (`user_id`, `product_type`, `deleted`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员产品收藏表（险种通用）';


-- ======================================================
-- 10. 消息通知设置表
-- ======================================================
CREATE TABLE `member_notify_setting`
(
    `id`                   BIGINT  NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`              BIGINT  NOT NULL COMMENT '用户ID',
    `policy_remind`        TINYINT NOT NULL DEFAULT 1 COMMENT '保单到期提醒 0关 1开',
    `renewal_remind`       TINYINT NOT NULL DEFAULT 1 COMMENT '续保提醒 0关 1开',
    `claim_notify`         TINYINT NOT NULL DEFAULT 1 COMMENT '理赔进度通知 0关 1开',
    `activity_notify`      TINYINT NOT NULL DEFAULT 1 COMMENT '活动优惠通知 0关 1开',
    `payment_notify`       TINYINT NOT NULL DEFAULT 1 COMMENT '缴费通知 0关 1开',
    `security_notify`      TINYINT NOT NULL DEFAULT 1 COMMENT '账号安全通知 0关 1开（不可关闭）',
    `wechat_subscribe`     TINYINT NOT NULL DEFAULT 0 COMMENT '微信订阅消息 0未订阅 1已订阅',
    `creator`              VARCHAR(64) NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`          DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`              VARCHAR(64) NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`          DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`              TINYINT     NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`            BIGINT      NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_id` (`user_id`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员消息通知设置表';


-- ======================================================
-- 11. 会员消息通知记录表（站内信/推送记录）
-- ======================================================
CREATE TABLE `member_message`
(
    `id`           BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`      BIGINT       NOT NULL COMMENT '用户ID',
    `msg_type`     TINYINT      NOT NULL COMMENT '消息类型 1系统通知 2保单提醒 3活动优惠 4理赔通知 5账号安全',
    `title`        VARCHAR(100) NOT NULL COMMENT '消息标题',
    `content`      TEXT         NOT NULL COMMENT '消息内容',
    `is_read`      TINYINT      NOT NULL DEFAULT 0 COMMENT '是否已读 0未读 1已读',
    `read_time`    DATETIME              COMMENT '阅读时间',
    `biz_type`     VARCHAR(50)           COMMENT '关联业务类型（policy/claim/order）',
    `biz_id`       BIGINT                COMMENT '关联业务ID',
    `jump_url`     VARCHAR(500)          COMMENT '点击跳转URL（小程序页面路径）',
    `creator`      VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`      VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`      TINYINT      NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`    BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    INDEX `idx_user_read` (`user_id`, `is_read`, `deleted`),
    INDEX `idx_user_type_time` (`user_id`, `msg_type`, `create_time`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员消息通知记录表';


-- ======================================================
-- 12. 业务员归因追踪表
--     记录C端用户与业务员的归因关系（分享/邀请来源）
-- ======================================================
CREATE TABLE `member_agent_trace`
(
    `id`           BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`      BIGINT               COMMENT 'C端用户ID（已登录时）',
    `openid`       VARCHAR(64)          COMMENT '微信OpenID（未登录时用）',
    `agent_id`     BIGINT      NOT NULL COMMENT '归因业务员ID',
    `trace_source` VARCHAR(50) NOT NULL COMMENT '归因来源 product_share/activity/invite',
    `product_id`   BIGINT               COMMENT '归因产品ID（产品分享时）',
    `product_type` VARCHAR(20)          COMMENT '险种类型',
    `trace_time`   DATETIME    NOT NULL COMMENT '归因时间',
    `expire_time`  DATETIME    NOT NULL COMMENT '归因有效期（默认30天）',
    `creator`      VARCHAR(64) NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`      VARCHAR(64) NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`      TINYINT     NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`    BIGINT      NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    INDEX `idx_user_agent` (`user_id`, `agent_id`),
    INDEX `idx_openid` (`openid`),
    INDEX `idx_expire_time` (`expire_time`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '业务员归因追踪表';


-- ======================================================
-- 13. 会员积分账户表
--     积分增减明细由 ins-marketing 模块的 mkt_point_record 管理
--     本表仅维护聚合余额，供 member 模块快速读取
-- ======================================================
CREATE TABLE `member_point_account`
(
    `id`              BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`         BIGINT NOT NULL COMMENT '用户ID',
    `available_point` INT    NOT NULL DEFAULT 0 COMMENT '可用积分',
    `frozen_point`    INT    NOT NULL DEFAULT 0 COMMENT '冻结积分',
    `used_point`      INT    NOT NULL DEFAULT 0 COMMENT '已使用积分',
    `expired_point`   INT    NOT NULL DEFAULT 0 COMMENT '已过期积分',
    `total_point`     INT    NOT NULL DEFAULT 0 COMMENT '累计获得积分',
    `level`           TINYINT NOT NULL DEFAULT 1 COMMENT '积分等级 1普通 2银卡 3金卡 4钻石',
    `creator`         VARCHAR(64) NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`         VARCHAR(64) NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`         TINYINT     NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`       BIGINT      NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_id` (`user_id`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员积分账户表';


-- ======================================================
-- 14. 会员反馈表
-- ======================================================
CREATE TABLE `member_feedback`
(
    `id`          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id`     BIGINT       NOT NULL COMMENT '用户ID',
    `category`    VARCHAR(50)  NOT NULL COMMENT '问题分类（功能异常/操作建议/投诉/其他）',
    `content`     TEXT         NOT NULL COMMENT '反馈内容',
    `images`      JSON                  COMMENT '截图OSS URL列表，JSON数组',
    `contact`     VARCHAR(50)           COMMENT '联系方式（手机或邮箱）',
    `status`      TINYINT      NOT NULL DEFAULT 0 COMMENT '处理状态 0未处理 1处理中 2已处理',
    `reply`       TEXT                  COMMENT '客服回复内容',
    `reply_time`  DATETIME              COMMENT '回复时间',
    `reply_by`    BIGINT                COMMENT '回复人（后台用户ID）',
    `creator`     VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '创建者',
    `create_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updater`     VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '更新者',
    `update_time` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `deleted`     TINYINT      NOT NULL DEFAULT 0 COMMENT '是否删除',
    `tenant_id`   BIGINT       NOT NULL DEFAULT 0 COMMENT '租户ID',
    PRIMARY KEY (`id`),
    INDEX `idx_user_status` (`user_id`, `status`),
    INDEX `idx_status_create` (`status`, `create_time`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci COMMENT = '会员意见反馈表';


-- ======================================================
-- 初始化说明（Redis Key 规范，仅文档注释）
-- ======================================================
/*
  Redis Key 规范（member 模块）：

  短信验证码：
    sms:code:{mobile}:{scene}             TTL=300s
    sms:error:{mobile}                    TTL=1800s（累计错误次数>=5时锁定）
    sms:limit:mobile:{mobile}             TTL=60s（每分钟限发次数）
    sms:limit:ip:{ip}                     TTL=3600s（每IP每小时限发10条）

  人脸识别：
    face:token:{userId}                   TTL=300s
    face:lock:{userId}                    TTL=86400s（失败3次锁定24h）

  业务员归因：
    ins:trace:member:{member_id}          TTL=30天  value=agent_id
    ins:trace:openid:{open_id}            TTL=30天  value=agent_id

  首页缓存：
    cache:home:banners                    TTL=300s
    cache:categories:home                 TTL=600s
    cache:home:hot                        TTL=600s
    member:favorite:{user_id}            TTL=300s
*/

# 保险中介平台 · 设置模块 PRD 需求文档

> **文档版本**：V1.0  
> **编写日期**：2026-03-06  
> **所属项目**：intermediary-cloud（保险中介平台）  
> **技术栈**：yudao-cloud（Spring Cloud Alibaba 微服务版）+ MySQL 8.0 + Redis  
> **微服务归属**：框架层（`intermediary` 数据库） + 业务配置（各业务 Schema 的 `sys_config` 表）  
> **文档定位**：开发实现级别，覆盖完整业务逻辑、字段校验、DB 操作、接口定义

---

## 目录

1. [模块总览](#一模块总览)
2. [基础设置](#二基础设置)
   - 2.1 数据字典
   - 2.2 参数配置
   - 2.3 地区管理
   - 2.4 银行管理
3. [系统外观与商户配置](#三系统外观与商户配置)
4. [账号与安全设置](#四账号与安全设置)
5. [消息通知设置](#五消息通知设置)
6. [车险保单设置](#六车险保单设置)
7. [非车险系统设置](#七非车险系统设置)
8. [客户设置](#八客户设置)
9. [寿险系统管理设置](#九寿险系统管理设置)
10. [日志与监控](#十日志与监控)
11. [数据库设计汇总](#十一数据库设计汇总)
12. [API 接口清单](#十二api-接口清单)
13. [工时估算](#十三工时估算)

---

## 一、模块总览

### 1.1 模块定位

**设置模块**是保险中介平台的全局配置管理中心，负责维护整个平台的运行参数、业务规则、外观配置、权限策略等基础数据。它不直接产生业务数据，但其配置项深刻影响所有业务模块的行为。

### 1.2 功能架构

```
设置
├── 基础设置
│   ├── 数据字典（框架复用）
│   ├── 参数配置（框架复用）
│   ├── 地区管理（框架复用）
│   └── 银行管理（业务扩展）
├── 系统外观与商户配置
│   ├── 商户基础信息
│   ├── 系统 Logo / 主题色
│   └── 登录页配置
├── 账号与安全设置
│   ├── 密码策略
│   ├── 登录策略
│   └── 数据权限配置
├── 消息通知设置
│   ├── 短信配置
│   ├── 站内信配置
│   └── 推送配置
├── 车险保单设置
│   ├── 查询默认配置
│   ├── 录入规则配置
│   ├── 业务归属配置
│   └── 同步设置
├── 非车险系统设置
│   ├── 非车导入模板设置
│   └── 非车保单设置
├── 客户设置
│   ├── 基础设置
│   └── 跟进阶段 / 拨打状态设置
├── 寿险系统管理
│   ├── H5 后台配置
│   ├── 系统配置
│   └── 保司工号
└── 日志与监控（框架复用）
    ├── 操作日志
    ├── 登录日志
    ├── 接口日志
    └── 系统监控
```

### 1.3 菜单规划

| 菜单层级 | 路径 | 说明 |
|---------|------|------|
| 一级菜单 | 设置 | 右侧导航或顶部导航入口 |
| 二级菜单 | 基础设置 | 字典、参数、地区、银行 |
| 二级菜单 | 商户配置 | 外观、Logo、登录页 |
| 二级菜单 | 账号安全 | 密码策略、数据权限 |
| 二级菜单 | 消息通知 | 短信/站内信/推送配置 |
| 二级菜单 | 车险设置 | 车险保单设置、同步设置 |
| 二级菜单 | 非车设置 | 非车模板、非车保单设置 |
| 二级菜单 | 客户设置 | 客户基础配置 |
| 二级菜单 | 寿险设置 | H5配置、系统配置、保司工号 |
| 二级菜单 | 日志监控 | 操作/登录/接口日志 |

---

## 二、基础设置

### 2.1 数据字典

> **实现方式**：完全复用 yudao-cloud 框架自带的 `system_dict_type` + `system_dict_data` 表和界面，**无需二次开发前端页面**。

**业务初始化**：在项目初始化 SQL 脚本中预置以下保险业务字典：

| 字典类型 | 字典名称 | 字典项（value: label） |
|---------|---------|----------------------|
| `insurance_type` | 险种类型 | 1:车险, 2:健康险, 3:意外险, 4:寿险, 5:财产险 |
| `car_insurance_type` | 车险类型 | 1:交强险, 2:商业险 |
| `cert_type` | 证书类型 | 1:代理人证, 2:经纪人证, 3:公估人证 |
| `cert_status` | 证书状态 | 0:未认证, 1:待审核, 2:已认证, 3:已拒绝 |
| `order_status` | 订单状态 | 1:待支付, 2:已支付, 3:已完成, 4:已取消, 5:已退款 |
| `policy_status` | 保单状态 | 1:生效中, 2:已过期, 3:已退保, 4:已理赔 |
| `commission_status` | 佣金状态 | 1:待结算, 2:已结算, 3:已发放, 4:已冻结 |
| `claim_status` | 理赔状态 | 1:已报案, 2:审核中, 3:已赔付, 4:已拒赔, 5:已关闭 |
| `agent_level` | 业务员等级 | 1:初级, 2:中级, 3:高级, 4:资深 |
| `org_type` | 机构类型 | 1:总公司, 2:分公司, 3:营业部 |
| `post_category` | 岗位类别 | 1:管理岗, 2:销售岗, 3:职能岗, 4:技术岗, 5:其他 |
| `data_scope` | 数据权限级别 | 1:全部, 2:本机构及下级, 3:本部门, 4:仅本人 |

**接口路径**：复用框架 `/admin-api/system/dict-type` 和 `/admin-api/system/dict-data`

---

### 2.2 参数配置

> **实现方式**：完全复用 yudao-cloud 框架自带的 `system_config` 表和界面，**无需二次开发前端页面**。

**业务初始化**：在初始化 SQL 脚本中预置以下业务参数：

| 参数键 | 默认值 | 说明 | 影响模块 |
|--------|--------|------|---------|
| `agent.code.prefix` | A | 业务员工号前缀 | 人管 |
| `agent.default.password` | 123456 | 业务员新增时初始密码 | 人管 |
| `staff.code.prefix` | S | 内勤工号前缀 | 人管 |
| `staff.default.password` | 123456 | 内勤初始密码 | 人管 |
| `order.timeout.minutes` | 30 | 订单超时未支付自动取消（分钟） | 订单 |
| `commission.settle.day` | 5 | 每月几号结算上月佣金 | 佣金 |
| `sms.daily.limit` | 10 | 单手机号每日短信发送上限（防刷） | 短信 |
| `file.upload.max.size` | 10 | 单文件最大 MB | 上传 |
| `agent.cert.expire.alert.days` | 90 | 业务员证书到期预警天数 | 人管 |
| `org.permit.expire.alert.days` | 90 | 机构许可证到期预警天数 | 人管 |
| `customer.protection.days` | 365 | 客户保护期（天），同一客户在此期限内归属不变 | 客户 |
| `agent.code.inactive.days` | 30 | 待激活账号超期自动停用天数 | 人管 |
| `password.expire.days` | 90 | 密码到期提醒天数 | 安全 |

**读取规范**：所有参数值从 Redis 缓存读取，key 格式为 `system:config:{参数键}`，框架修改参数后自动刷新缓存。代码通过 `ConfigApi.getConfigValueByKey(key)` 获取。

**接口路径**：复用框架 `/admin-api/system/config`

---

### 2.3 地区管理

> **实现方式**：完全复用 yudao-cloud 框架自带的地区管理，**无需二次开发**。

- **数据表**：`system_area`，使用国家统计局最新行政区划数据
- **初始化**：导入省市区三级数据（约 3500+ 条记录）
- **接口**：`GET /admin-api/system/area/tree?parentId=0`（框架自带）
- **前端用途**：机构地址录入、客户地区选择等省市区三级联动

---

### 2.4 银行管理

> **实现方式**：业务扩展，新建 `biz_bank` 表 + 标准 CRUD 接口

#### 2.4.1 功能入口

菜单路径：**设置 → 基础设置 → 银行管理**

页面为列表 + 新增/编辑弹窗形式。

#### 2.4.2 字段定义

| 字段 | 是否必填 | 校验规则 | 说明 |
|------|---------|---------|------|
| 银行代码 | ★ 必填 | 全局唯一，大写字母，如 ICBC/CCB | `bank_code`，创建后不可修改 |
| 银行全称 | ★ 必填 | 最长 50 字符 | `bank_name` |
| 银行 Logo | 否 | JPG/PNG，不超过 500KB | OSS URL |
| 是否热门 | ★ 必填 | 默认否 | 热门银行在前端优先展示 |
| 状态 | ★ 必填 | 0-禁用 / 1-启用，默认启用 | |
| 排序 | ★ 必填 | ≥0，默认 0 | 小值靠前 |

#### 2.4.3 业务逻辑

- 新增：`bank_code` 全局唯一校验（`deleted=0`条件），重复则返回「银行代码已存在」
- 编辑：`bank_code` 不可修改，只读展示
- 删除：逻辑删除（`deleted=1`）；若有人员关联该银行卡则拒绝删除，提示「银行下有 N 条银行卡记录，无法删除」
- 启用/停用：停用后，关联银行卡的新增操作中该银行不再可选，已绑定不受影响

**缓存策略**：列表 Redis 缓存（key：`bank:simple_list:{tenantId}`，TTL 24 小时），增删改后主动清除缓存。

#### 2.4.4 数据库设计

```sql
CREATE TABLE `biz_bank` (
  `id`          BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键',
  `bank_code`   VARCHAR(20) NOT NULL COMMENT '银行代码（如ICBC）',
  `bank_name`   VARCHAR(50) NOT NULL COMMENT '银行全称',
  `bank_logo`   VARCHAR(500) DEFAULT NULL COMMENT 'Logo图片OSS URL',
  `is_hot`      TINYINT     NOT NULL DEFAULT 0 COMMENT '是否热门：0-否 1-是',
  `status`      TINYINT     NOT NULL DEFAULT 1 COMMENT '0-禁用 1-启用',
  `sort`        INT         NOT NULL DEFAULT 0 COMMENT '排序，小值靠前',
  `remark`      VARCHAR(200) DEFAULT NULL COMMENT '备注',
  `creator`     VARCHAR(64) DEFAULT '',
  `create_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`     VARCHAR(64) DEFAULT '',
  `update_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`     TINYINT     NOT NULL DEFAULT 0,
  `tenant_id`   BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_bank_code` (`bank_code`, `deleted`),
  KEY `idx_tenant_status` (`tenant_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='银行字典表';
```

---

## 三、系统外观与商户配置

### 3.1 功能入口

菜单路径：**设置 → 商户配置**

### 3.2 商户基础信息配置

| 配置项 | 类型 | 说明 | DB 存储 |
|--------|------|------|---------|
| 商户名称 | 文本输入 | 显示于系统顶部、报表标题等 | `sys_tenant.name` |
| 商户简称 | 文本输入 | 用于短信签名等 | `sys_tenant.short_name` |
| 联系电话 | 文本输入 | 客服电话，显示于 C 端页面底部 | `biz_tenant_config.service_phone` |
| 客服邮箱 | 文本输入 | 邮箱格式校验 | `biz_tenant_config.service_email` |
| 公司地址 | 文本输入 | 最长 200 字符 | `biz_tenant_config.address` |
| 营业执照号 | 文本输入 | 用于合规展示 | `biz_tenant_config.license_no` |

### 3.3 系统外观配置

| 配置项 | 类型 | 说明 | DB 存储 |
|--------|------|------|---------|
| 系统 Logo（深色版） | 图片上传 | 建议 200×60px，PNG 透明背景，≤200KB | `biz_tenant_config.logo_dark_url` |
| 系统 Logo（浅色版） | 图片上传 | 用于深色导航背景场景 | `biz_tenant_config.logo_light_url` |
| 浏览器标签图标 | 图片上传 | Favicon，32×32px，ICO/PNG | `biz_tenant_config.favicon_url` |
| 主题色 | 颜色选择器 | 影响按钮、选中状态等主色调，默认 `#1890FF` | `biz_tenant_config.theme_color` |
| 系统名称 | 文本输入 | 显示于浏览器标签页标题 | `biz_tenant_config.system_name` |

### 3.4 登录页配置

| 配置项 | 类型 | 说明 |
|--------|------|------|
| 登录页背景图 | 图片上传 | 建议 1920×1080px，JPG，≤2MB |
| 登录框标题 | 文本输入 | 默认「欢迎登录」 |
| 登录框副标题 | 文本输入 | 如「XX保险经纪管理系统」 |
| 是否显示公司简介 | 开关 | 开启后登录页左侧展示公司介绍文字 |
| 公司简介内容 | 富文本 | 最长 500 字符 |

### 3.5 业务逻辑

- 所有配置以 JSON 格式存入 `biz_tenant_config.extra_config` 或独立字段（按字段数量决定）
- 修改后立即生效，配置在 Redis 缓存（key：`tenant:config:{tenantId}`，TTL 30 分钟）
- 修改操作写入操作日志，追溯变更记录

### 3.6 数据库设计

```sql
CREATE TABLE `biz_tenant_config` (
  `id`              BIGINT      NOT NULL AUTO_INCREMENT,
  `tenant_id`       BIGINT      NOT NULL COMMENT '租户ID',
  `system_name`     VARCHAR(50) DEFAULT '保险中介管理系统' COMMENT '系统名称',
  `service_phone`   VARCHAR(20) DEFAULT NULL COMMENT '客服电话',
  `service_email`   VARCHAR(100) DEFAULT NULL COMMENT '客服邮箱',
  `address`         VARCHAR(200) DEFAULT NULL COMMENT '公司地址',
  `license_no`      VARCHAR(50) DEFAULT NULL COMMENT '营业执照号',
  `logo_dark_url`   VARCHAR(500) DEFAULT NULL COMMENT 'Logo-深色版 OSS URL',
  `logo_light_url`  VARCHAR(500) DEFAULT NULL COMMENT 'Logo-浅色版 OSS URL',
  `favicon_url`     VARCHAR(500) DEFAULT NULL COMMENT 'Favicon URL',
  `theme_color`     VARCHAR(20) DEFAULT '#1890FF' COMMENT '主题色',
  `login_bg_url`    VARCHAR(500) DEFAULT NULL COMMENT '登录页背景图 URL',
  `login_title`     VARCHAR(50) DEFAULT '欢迎登录' COMMENT '登录页标题',
  `login_subtitle`  VARCHAR(100) DEFAULT NULL COMMENT '登录页副标题',
  `show_intro`      TINYINT     DEFAULT 0 COMMENT '是否展示公司简介',
  `intro_content`   VARCHAR(500) DEFAULT NULL COMMENT '公司简介内容',
  `extra_config`    JSON        DEFAULT NULL COMMENT '扩展配置JSON',
  `creator`         VARCHAR(64) DEFAULT '',
  `create_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         VARCHAR(64) DEFAULT '',
  `update_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant` (`tenant_id`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='租户自定义配置表';
```

---

## 四、账号与安全设置

### 4.1 功能入口

菜单路径：**设置 → 账号安全**

### 4.2 密码策略配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 密码最小长度 | 数字输入 | 8 | 范围 6~20 |
| 密码复杂度要求 | 多选勾选框 | 大写字母+数字 | 可选：大写字母、小写字母、数字、特殊字符 |
| 密码有效期（天） | 数字输入 | 90 | 0 表示永不过期 |
| 到期前提醒天数 | 数字输入 | 7 | 提前几天在系统内提示用户修改密码 |
| 禁止重复使用历史密码次数 | 数字输入 | 3 | 0 表示不限制 |

**后端处理**：
- 密码策略保存至 `sys_config`，key 前缀 `security.password.*`
- 用户修改密码时，后端实时读取 Redis 缓存中的密码策略进行校验
- 密码到期提醒：XXL-Job 每日 05:00 扫描 `system_users`，对 `update_time` 距当前天数 >= (有效期 - 提前天数) 的用户写入系统通知

### 4.3 登录策略配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 登录失败锁定次数 | 数字输入 | 5 | 连续失败 N 次后锁定账号 |
| 锁定时长（分钟） | 数字输入 | 30 | 0 表示永久锁定，需管理员手动解锁 |
| 是否开启验证码 | 开关 | 开 | 关闭后登录页不展示图形验证码 |
| 登录有效期（小时） | 数字输入 | 8 | Token 有效时长，超时需重新登录 |
| 是否允许多端同时登录 | 开关 | 否 | 关闭后新登录设备会踢出旧设备 |
| IP 白名单 | 文本域（每行一个） | 空 | 为空则不限制；配置后仅允许白名单 IP 访问管理后台 |

**后端处理**：
- 登录失败次数用 Redis 计数器存储，key：`login:fail:{username}`，TTL 与锁定时长一致
- IP 白名单存入 `sys_config`，Gateway 过滤器每次请求时校验

### 4.4 数据权限配置

| 角色标识 | 角色名称 | 默认数据权限级别 | 说明 |
|---------|---------|----------------|------|
| `super_admin` | 超级管理员 | 全部 | 框架默认，不可修改 |
| `platform_admin` | 平台管理员 | 全部 | 管理所有机构数据 |
| `org_admin` | 机构管理员 | 本机构及下级机构 | |
| `dept_manager` | 部门经理 | 本部门 | |
| `agent` | 业务员 | 仅本人 | |
| `staff` | 内勤 | 本部门 | 可按岗位差异化配置 |
| `finance` | 财务 | 本机构及下级机构 | |

- 数据权限值存入 `system_users` 扩展字段 `data_scope`（1-全部 / 2-本机构及下级 / 3-本部门 / 4-仅本人）
- 各业务查询 Service 层方法标注 `@DataPermission`，框架自动注入 WHERE 条件

---

## 五、消息通知设置

### 5.1 短信配置

> 菜单路径：**设置 → 消息通知 → 短信配置**

#### 5.1.1 短信服务商配置

| 配置项 | 类型 | 说明 |
|--------|------|------|
| 短信服务商 | 单选：阿里云 / 腾讯云 | |
| AccessKey ID | 文本输入（加密存储） | |
| AccessKey Secret | 文本输入（加密存储，显示脱敏） | |
| 短信签名 | 文本输入 | 如「XX保险」，需与服务商申请一致 |
| 测试手机号 | 文本输入 | 用于发送测试短信验证配置是否正常 |
| 【测试发送】按钮 | — | 点击后向测试手机号发送固定内容短信，实时返回结果 |

**安全**：AccessKey Secret 使用 AES-256 加密存储，界面展示时脱敏为 `****`，不可直接复制明文。

#### 5.1.2 短信模板管理

列表展示所有已配置的短信模板，支持新增/编辑/删除。

| 字段 | 必填 | 说明 |
|------|------|------|
| 模板名称 | ★ | 如「验证码短信」、「保单到期提醒」 |
| 模板类型 | ★ | 单选：验证码 / 通知 / 营销 |
| 服务商模板 ID | ★ | 在短信服务商控制台申请的模板编号 |
| 模板内容（预览） | — | 展示服务商模板内容，含变量占位符 |
| 状态 | ★ | 启用/禁用 |
| 使用场景 | 否 | 说明该模板用于哪些业务场景 |

**预置模板清单**：

| 模板名称 | 场景 | 变量 |
|---------|------|------|
| 登录验证码 | 用户登录短信验证码 | `${code}`, `${minutes}` |
| 重置密码验证码 | 找回密码 | `${code}`, `${minutes}` |
| 保单续保提醒 | 保单到期 N 天前 | `${customerName}`, `${policyNo}`, `${expireDate}` |
| 证书到期提醒 | 业务员证书到期 | `${agentName}`, `${certType}`, `${expireDate}` |
| 客户生日祝福 | 客户生日当天 | `${customerName}`, `${companyName}` |
| 出单成功通知 | 保单出单后 | `${policyNo}`, `${productName}` |

#### 5.1.3 发送频率控制

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 单手机号每日上限 | 10 条 | 超过后当日不再发送 |
| 单手机号验证码间隔 | 60 秒 | 防止频繁请求验证码 |
| 验证码有效期 | 5 分钟 | 超过后验证码失效 |
| 全局日发送上限 | 5000 条 | 达到后当日停止发送，告警通知管理员 |

---

### 5.2 站内信配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 消息保留天数 | 数字输入 | 90 | 超过 N 天的已读消息自动清理 |
| 未读消息红点显示 | 开关 | 开 | 顶部导航铃铛图标红点 |
| 桌面通知 | 开关 | 关 | 浏览器桌面推送（需用户授权） |

---

### 5.3 App 推送配置（极光/个推）

| 配置项 | 类型 | 说明 |
|--------|------|------|
| 推送服务商 | 单选：极光 / 个推 / 阿里云 | |
| AppKey | 文本输入（加密存储） | |
| MasterSecret | 文本输入（加密存储，脱敏显示） | |
| 推送静默时段 | 时间范围输入 | 默认 22:00~08:00，该时段内营销类推送不发送 |

---

## 六、车险保单设置

> 菜单路径：**车险 → 保单管理 → 保单设置**
> 对应 PDF 编号：PDF-87（车险保单设置）

### 6.1 查询默认行为配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 默认日期类型 | 单选 | 签单日期 | 可选：签单日期 / 支付日期 / 核保日期 |
| 默认日期范围 | 单选 | 当月 | 可选：当月 / 当季 / 上月 / 自定义 |
| 是否开启多保单号逗号搜索 | 开关 | 关闭 | 开启后保单号输入框支持多个逗号分隔的保单号批量查询 |

### 6.2 保单号格式规则

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 保单号最小长度 | 数字输入 | 8 | 范围 1~30 |
| 保单号最大长度 | 数字输入 | 20 | 范围 1~50 |
| 允许特殊字符 | 多选勾选框 | 无 | 可选：横杠(-)、斜杠(/)、空格 |

### 6.3 录入规则配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 强制关联出单工号 | 开关 | 关闭 | 开启后录入表单中出单工号必填且必须选择，不可手工输入 |
| 重复保单提示模式 | 单选 | 显示录单人及日期 | 可选：显示录单人及录入日期 / 仅提示存在重复（隐私保护） |
| 工号必须与委托协议关联 | 开关 | 关闭 | 开启后工号新增/编辑时委托代理协议字段变为必填；协议到期后工号自动禁用 |
| 录单时试算手续费限制 | 组织树多选 | 不限制 | 勾选的组织下录单操作不展示「试算」按钮；如填写的金额超过政策匹配金额则弹出警告 |

### 6.4 业务归属配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 保单业务归属依据 | 单选 | 业务员 | 可选：业务员 / 出单员 / 录单员 / 工号 |
| 下游手续费修改限制 | 开关 | 关闭 | 开启后，保单修改时下游手续费不允许超过已匹配政策金额（管理员例外） |
| 财务经理不受下游限制 | 开关 | 关闭 | 总开关开启时，此项开启则财务经理也不受限 |
| 保单代理人与收款人一致检查 | 开关 | 关闭 | 开启后，业务员与收款人不一致时给出提示（不阻止保存） |
| 车险录单带出非车保单同步非车系统 | 开关 | 关闭 | 开启后车险录入时若带出非车险产品信息，自动同步到非车模块 |

**后端处理逻辑**：
- 所有配置写入 `sys_config` 表，key 格式：`ins.car.policy.{配置项名称}`
- 修改后立即生效（Redis 缓存 TTL 5 分钟）
- 影响范围：当前租户下所有用户的查询和录入行为
- 下游手续费限制：保存车险保单时，若当前用户所属机构在限制列表中，读取匹配政策的 `downstream_rate`，若超出则返回「下游手续费不能超过政策配置的 XX%」

### 6.5 同步设置（商户间保单同步）

> 本功能由运营团队/客户经理在系统级别为商户开通，普通管理员需在商户级别配置。

#### 6.5.1 前置条件

- A 商户必须在系统级别开启「录单同步功能」
- A、B 两商户必须配置了相同的保司工号

#### 6.5.2 新增同步配置

点击【新增同步配置】弹窗，填写：

| 字段 | 必填 | 说明 |
|------|------|------|
| 目标商户 | ★ | 搜索并选择目标商户 B |
| 同步账号（B商户） | ★ | B 商户的系统登录账号 |
| 同步密码（B商户） | ★ | B 商户系统密码，AES 加密存储 |
| 同步工号 | ★ | 选择同步凭证工号（须在 A、B 均已配置） |
| 禁用的录单模式 | 否 | 多选：手工 / 直连；勾选后该模式录入的保单不同步 |
| 是否启用 | ★ | 默认启用 |

**数据库设计**：

```sql
CREATE TABLE `ins_policy_sync_config` (
  `id`              BIGINT      NOT NULL AUTO_INCREMENT,
  `tenant_id`       BIGINT      NOT NULL COMMENT '源商户租户ID（A商户）',
  `target_tenant_id` BIGINT     NOT NULL COMMENT '目标商户租户ID（B商户）',
  `sync_account`    VARCHAR(50) NOT NULL COMMENT 'B商户账号',
  `sync_password`   VARCHAR(200) NOT NULL COMMENT 'B商户密码（AES加密）',
  `sync_account_no` VARCHAR(50) NOT NULL COMMENT '同步工号',
  `disabled_modes`  JSON        DEFAULT NULL COMMENT '禁用的录单模式列表',
  `status`          TINYINT     NOT NULL DEFAULT 1 COMMENT '0-禁用 1-启用',
  `creator`         VARCHAR(64) DEFAULT '',
  `create_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         VARCHAR(64) DEFAULT '',
  `update_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保单同步配置表';
```

---

## 七、非车险系统设置

### 7.1 非车导入模板设置

> 菜单路径：**非车 → 系统设置 → 导入模板设置**
> 对应 PDF 编号：PDF-105（非车导入模板设置）

#### 7.1.1 功能说明

维护非车保单批量导入时使用的 Excel 模板，支持字段自定义配置，适配不同保险公司的数据格式。

#### 7.1.2 模板列表

列表展示所有已配置的导入模板，支持新增/编辑/删除/启用停用。

| 列名 | 说明 |
|------|------|
| 模板名称 | |
| 适用险种 | 显示该模板适用的险种类型 |
| 字段数量 | 该模板配置的列字段数 |
| 状态 | 启用/停用 |
| 创建时间 | |
| 操作 | 编辑 / 复制 / 删除 / 下载模板文件 |

#### 7.1.3 新增/编辑导入模板

**基础信息**：

| 字段 | 必填 | 说明 |
|------|------|------|
| 模板名称 | ★ | 2~50 字符，同一险种下不允许重名 |
| 适用险种 | ★ | 单选，来自险种字典 |
| 模板说明 | 否 | 最长 200 字符 |
| 是否为默认模板 | — | 该险种只能有一个默认模板 |

**字段配置**（可视化拖拽排序）：

| 配置项 | 说明 |
|--------|------|
| 系统字段 | 对应保单主表字段，下拉选择 |
| Excel 列名 | 该字段在 Excel 中对应的列标题 |
| 是否必填 | 导入时该列是否为必填项 |
| 数据格式 | 文本/日期(yyyy-MM-dd)/数值/下拉字典 |
| 默认值 | 导入时若该列为空时使用的默认值 |
| 排序 | 拖拽调整列顺序，同步更新 Excel 模板 |

**后端处理**：
- 配置保存后，系统自动生成对应 Excel 模板文件并上传至 OSS
- 导入时，根据当前选择的模板和配置解析 Excel 数据，按映射关系写入保单表

**数据库设计**：

```sql
CREATE TABLE `ins_noncar_import_template` (
  `id`            BIGINT      NOT NULL AUTO_INCREMENT,
  `tenant_id`     BIGINT      NOT NULL,
  `template_name` VARCHAR(50) NOT NULL COMMENT '模板名称',
  `insurance_type_id` BIGINT  NOT NULL COMMENT '险种ID',
  `is_default`    TINYINT     NOT NULL DEFAULT 0 COMMENT '是否默认模板',
  `remark`        VARCHAR(200) DEFAULT NULL,
  `status`        TINYINT     NOT NULL DEFAULT 1,
  `creator`       VARCHAR(64) DEFAULT '',
  `create_time`   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`       VARCHAR(64) DEFAULT '',
  `update_time`   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`       TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_tenant_type` (`tenant_id`, `insurance_type_id`)
) ENGINE=InnoDB COMMENT='非车险导入模板主表';

CREATE TABLE `ins_noncar_import_template_field` (
  `id`             BIGINT     NOT NULL AUTO_INCREMENT,
  `template_id`    BIGINT     NOT NULL COMMENT '模板ID',
  `system_field`   VARCHAR(50) NOT NULL COMMENT '系统字段名',
  `excel_col_name` VARCHAR(50) NOT NULL COMMENT 'Excel列名',
  `is_required`    TINYINT    NOT NULL DEFAULT 0 COMMENT '是否必填',
  `data_format`    VARCHAR(20) DEFAULT 'text' COMMENT '数据格式：text/date/number/dict',
  `dict_type`      VARCHAR(50) DEFAULT NULL COMMENT '下拉字典类型',
  `default_value`  VARCHAR(100) DEFAULT NULL COMMENT '默认值',
  `sort`           INT        NOT NULL DEFAULT 0 COMMENT '排序',
  PRIMARY KEY (`id`),
  KEY `idx_template_id` (`template_id`)
) ENGINE=InnoDB COMMENT='非车险模板字段配置明细表';
```

---

### 7.2 非车保单设置

> 菜单路径：**非车 → 系统设置 → 保单设置**
> 对应 PDF 编号：PDF-106（非车保单设置）
> ⚠️ 注意：修改保单设置后，需**点击保存并重新登录**才能生效。

#### 7.2.1 录单设置（一）：保单业务归属

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 非车保单业务归属 | 单选 | 业务员 | 可选：业务员 / 出单员 / 录单员；影响统计分析时保单按哪个人员字段汇总归属 |

- 配置存入 `sys_config`，`config_key = non_vehicle_policy_belong_type`
- 保存后，统计分析模块中所有「按业务员」的汇总改为按所选归属人员字段查询

#### 7.2.2 录单设置（二）：下游手续费校验

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 组织维度的下游手续费上限校验 | 组织树勾选（可多选） | 不勾选 | 勾选某组织后，该组织人员修改保单时，下游手续费及跟单手续费不得超过已匹配政策的比例 |

**后端处理**：
- 配置存入 `sys_config`，`config_key = non_vehicle_downstream_check_orgs`，值为组织 ID 的 JSON 数组
- 保存非车保单时：若当前用户所属机构在校验列表中，读取该保单匹配的政策 `downstream_rate`，若用户填写的 `downstream_rate` > 政策值，返回错误「下游手续费不能超过政策配置的 XX%」

#### 7.2.3 录单设置（三）：相同保单号不同产品支持

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 允许同一险种下相同保单号录入不同产品 | 险种维度多选勾选框 | 全不勾选 | 勾选后，该险种下允许保单号相同但产品不同的保单同时存在 |

**后端处理**：
- 默认情况：`保险公司 + 保单号` 联合唯一，重复录入提示「保单号已存在」
- 开启后：唯一性校验变为 `保险公司 + 保单号 + 产品名称`（应用层逻辑处理，不修改 DB 索引）
- 配置存入 `sys_config`，`config_key = non_vehicle_same_policy_no_insurance_types`，值为险种 ID 列表

#### 7.2.4 保单查询默认设置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 默认日期类型 | 单选 | 签单日期 | 进入保单查询页时默认选中的日期类型 |
| 默认查询时间范围 | 下拉 | 近1个月 | 可选：近1个月 / 近3个月 / 当月 |
| 多保单号逗号分隔搜索 | 开关 | 关闭 | 开启后，保单号输入框支持多个逗号分隔的保单号批量查询 |
| 未录入保单统计角标 | 开关 | 关闭 | 开启后，菜单或列表页显示「待录入」数量角标 |

- 以上配置存 `sys_config` 表，影响当前租户下所有用户的非车查询默认体验
- 修改后需重新登录才生效

#### 7.2.5 提醒设置与汇率设置（预留）

> 这两项为后期非车理赔模块预留功能，**当前版本暂不实现**，页面展示「敬请期待」占位说明。

---

## 八、客户设置

> 菜单路径：**客户 → 设置**
> 对应 PDF 编号：PDF-41（客户设置）

### 8.1 基础设置

#### 8.1.1 跟进客户排序设置

| 配置项 | 类型 | 说明 |
|--------|------|------|
| 客户列表默认排序规则 | 单选 | 可选：按续保日期升序 / 续保日期降序 / 预约日期升序 / 预约日期降序 / 过期未跟进 |

#### 8.1.2 分配设置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 自动重新分配开关 | 开关 | 关闭 | 打开后每日凌晨自动将本月已分配但未进行跟进的客户重新分配 |

**后端处理（开启后）**：
- XXL-Job 每日凌晨 01:00 扫描 `ins_customer` 表
- 条件：`assign_time >= 本月1日 AND last_follow_time IS NULL AND deleted = 0`
- 操作：根据分配规则（轮询/负载均衡）重新分配，写入分配日志

#### 8.1.3 短信发送限制

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 单用户短信发送数量限制周期 | 单选 | 每周 | 可选：每周 / 每月 |
| 单用户短信上限 | 数字输入 | 50 条 | 在系统默认上限范围内，每个商户可向下调整 |

#### 8.1.4 短信退订设置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 自动追加退订字段 | 开关 | 关闭 | 打开后，发送短信时结尾自动加上「退订回T」字段 |
| 退订追加生效范围 | 单选 | — | 可选：编辑模板时生效 / 给个人发送时生效 |

#### 8.1.5 资源类型设置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 支持导入资源类型 | 开关 | 关闭 | 打开后支持导入资源类型，在客户列表中自主查询资源类型 |

**存储**：以上配置存入 `sys_config` 表，key 前缀 `customer.setting.*`

### 8.2 跟进阶段设置 / 拨打状态设置

> ⚠️ 阶段和状态为系统提前设定好的，**不支持自定义**，仅展示说明。

**跟进阶段预置清单**（只读展示）：

| 阶段值 | 阶段名称 | 说明 |
|--------|---------|------|
| NEW | 新客户 | 刚分配/刚录入，未接触 |
| CONTACTED | 已联系 | 已拨打或已回复 |
| INTERESTED | 有意向 | 客户表示有购买意向 |
| QUOTED | 已报价 | 已提供报价方案 |
| NEGOTIATING | 谈判中 | 价格/条款协商阶段 |
| DEAL | 已成交 | 完成投保出单 |
| LOST | 已流失 | 最终未成交或主动放弃 |
| PROTECTED | 保护期 | 在客户保护期内，不可被他人抢占 |

**拨打状态预置清单**（只读展示）：

| 状态值 | 状态名称 |
|--------|---------|
| ANSWERED | 已接听 |
| NO_ANSWER | 无人接听 |
| BUSY | 忙线中 |
| SHUTDOWN | 关机 |
| EMPTY_NUMBER | 空号 |
| REFUSED | 拒绝接听 |
| CALLBACK_REQUESTED | 要求回电 |

---

## 九、寿险系统管理设置

> 菜单路径：**寿险 → 系统管理**
> 对应 PDF 编号：PDF-164（寿险系统管理目录）、PDF-165（H5后台配置）、PDF-166（系统配置）、PDF-167（保司工号）

### 9.1 H5 后台配置（PDF-165）

#### 9.1.1 功能说明

维护 C 端寿险 H5 页面的展示内容，包括产品分类、在线投保配置、产品介绍、计划书、内容管理等。

#### 9.1.2 H5 产品分类管理

| 字段 | 必填 | 说明 |
|------|------|------|
| 分类名称 | ★ | 最长 20 字符 |
| 分类图标 | 否 | 图标 URL |
| 排序号 | ★ | 小值靠前 |
| 是否显示 | ★ | 不显示则 C 端不展示 |
| 关联产品 | 否 | 支持将寿险产品关联到此分类 |

#### 9.1.3 H5 在线投保配置

| 字段 | 必填 | 说明 |
|------|------|------|
| 关联产品 | ★ | 选择需要在 H5 上线的寿险产品 |
| 是否开启在线投保 | ★ | 开启后 C 端可直接投保 |
| 投保须知 | 否 | 富文本，最长 5000 字符 |
| 免责声明 | 否 | 富文本 |
| 特别提示 | 否 | 富文本 |

#### 9.1.4 内容管理（资讯 / 文章 / 知识库）

| 字段 | 必填 | 说明 |
|------|------|------|
| 内容分类 | ★ | 先创建分类，再关联内容 |
| 标题 | ★ | 最长 100 字符 |
| 封面图 | 否 | |
| 正文 | ★ | 富文本 |
| 发布状态 | ★ | 草稿 / 已发布 |
| 置顶 | 否 | 开启后该内容在 H5 端置顶展示 |

---

### 9.2 寿险系统配置（PDF-166）

> 以下配置存入 `ins_life_sys_config` 表，通过 Redis 热更新（TTL 10 分钟）。

| 配置分组 | 配置项 | 类型 | 默认值 | 说明 |
|---------|--------|------|--------|------|
| 续期跟踪 | 首次续期提醒天数 | 数字 | 60 | 提前 N 天发起续期跟踪 |
| 续期跟踪 | 续期提醒节点（天） | JSON 数组 | [60,30,15,7,1] | 到期前各节点提醒 |
| 续期跟踪 | 是否通知业务员 | 开关 | 开 | 续期提醒同时通知归属业务员 |
| 上游结算 | 默认结算周期 | 单选 | 月结 | 月结 / 季结 / 年结 |
| 上游结算 | 结算日 | 数字 | 10 | 每月几号执行结算 |
| 数据回传 | 回传失败重试次数 | 数字 | 3 | |
| 数据回传 | 回传失败重试间隔（分钟） | 数字 | 30 | |
| 双录 | 是否强制双录 | 开关 | 开 | 寿险保单是否强制进行合规双录 |
| 双录 | 双录超时时长（分钟） | 数字 | 60 | 超时后双录会话自动结束 |
| 孤儿单 | 孤儿单认定天数 | 数字 | 90 | 业务员离职 N 天后其名下保单自动转为孤儿单 |

**数据库设计**：

```sql
CREATE TABLE `ins_life_sys_config` (
  `id`          BIGINT      NOT NULL AUTO_INCREMENT,
  `tenant_id`   BIGINT      NOT NULL,
  `config_key`  VARCHAR(100) NOT NULL COMMENT '配置键',
  `config_value` TEXT       NOT NULL COMMENT '配置值（JSON或字符串）',
  `config_group` VARCHAR(50) NOT NULL COMMENT '配置分组',
  `config_desc`  VARCHAR(200) DEFAULT NULL COMMENT '配置说明',
  `value_type`  VARCHAR(20) DEFAULT 'string' COMMENT '值类型：string/number/boolean/json',
  `creator`     VARCHAR(64) DEFAULT '',
  `create_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`     VARCHAR(64) DEFAULT '',
  `update_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`     TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_key` (`tenant_id`, `config_key`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='寿险系统参数配置表';
```

---

### 9.3 保司工号管理（PDF-167）

> 菜单路径：**寿险 → 系统管理 → 保司工号**

#### 9.3.1 功能说明

管理业务员在各家保险公司的工号信息。业务员在不同保司出单时，需要使用其在该保司注册的工号，工号与业务员账号绑定。

#### 9.3.2 工号列表

列表展示所有工号信息，支持按保险公司、业务员、状态筛选。

| 列名 | 说明 |
|------|------|
| 工号 | 保司分配的工号 |
| 保险公司 | |
| 业务员姓名 | |
| 业务员工号 | 平台内部工号 |
| 工号状态 | 正常 / 禁用 / 待激活 |
| 协议状态 | 协议有效期是否正常 |
| 协议到期日 | |
| 操作 | 编辑 / 禁用 / 查看关联保单 |

#### 9.3.3 新增/编辑工号

| 字段 | 必填 | 说明 |
|------|------|------|
| 业务员 | ★ | 搜索选择，一个业务员可以有多个保司工号 |
| 保险公司 | ★ | 下拉选择，来自合作保司列表 |
| 工号 | ★ | 同一保司下工号唯一 |
| 工号姓名 | ★ | 保司系统中登记的姓名（可能与平台姓名不同） |
| 委托代理协议编号 | 条件必填 | 若系统设置中开启「工号必须与委托协议关联」则必填 |
| 协议生效日期 | 条件必填 | 同上 |
| 协议到期日期 | 条件必填 | 同上；到期后工号自动禁用 |
| 状态 | ★ | 默认启用 |

**业务逻辑**：
- 同一保司下工号不允许重复（`insurance_company_id + account_no` 联合唯一）
- 协议到期检查：XXL-Job 每日 02:00 扫描到期的工号，自动将状态改为「已禁用」并发送站内信通知管理员
- 工号禁用后，该工号关联的未出单保单录入操作将提示「该工号已禁用，请更换工号」

**数据库设计**：

```sql
CREATE TABLE `ins_life_insurer_account` (
  `id`                BIGINT      NOT NULL AUTO_INCREMENT,
  `tenant_id`         BIGINT      NOT NULL,
  `agent_id`          BIGINT      NOT NULL COMMENT '业务员ID',
  `insurer_id`        BIGINT      NOT NULL COMMENT '保险公司ID',
  `account_no`        VARCHAR(50) NOT NULL COMMENT '工号',
  `account_name`      VARCHAR(50) NOT NULL COMMENT '工号姓名',
  `agreement_no`      VARCHAR(50) DEFAULT NULL COMMENT '委托代理协议编号',
  `agreement_start`   DATE        DEFAULT NULL COMMENT '协议生效日期',
  `agreement_end`     DATE        DEFAULT NULL COMMENT '协议到期日期',
  `status`            TINYINT     NOT NULL DEFAULT 1 COMMENT '0-禁用 1-启用 2-待激活',
  `disable_reason`    VARCHAR(200) DEFAULT NULL COMMENT '禁用原因',
  `creator`           VARCHAR(64) DEFAULT '',
  `create_time`       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`           VARCHAR(64) DEFAULT '',
  `update_time`       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`           TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_insurer_account` (`insurer_id`, `account_no`, `deleted`),
  KEY `idx_agent` (`agent_id`),
  KEY `idx_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员保司工号表（寿险专用）';
```

---

## 十、日志与监控

> **实现方式**：完全复用 yudao-cloud 框架自带功能，**无需二次开发**。

### 10.1 操作日志

- 数据表：`system_operate_log`
- 记录方式：`@OperateLog` 注解，由 AOP 自动记录
- 接口：`GET /admin-api/system/operate-log/page`
- 展示字段：操作模块、操作类型、操作人、操作时间、IP 地址、请求方法、请求参数（JSON）、返回结果、耗时

### 10.2 登录日志

- 数据表：`system_login_log`
- 记录方式：由 `LoginLogService` 自动记录
- 接口：`GET /admin-api/system/login-log/page`
- 展示字段：登录用户名、IP 地址、登录时间、浏览器、操作系统、登录结果（成功/失败）、失败原因

### 10.3 接口日志

- 数据表：`infra_api_access_log`
- 记录方式：`ApiAccessLogFilter` 自动记录所有 API 请求
- 接口：`GET /admin-api/infra/api-access-log/page`

### 10.4 系统监控

使用 Spring Boot Actuator + Nacos 健康检查，监控项：

| 监控项 | 说明 |
|--------|------|
| JVM 内存 | 堆内存使用率、GC 频率 |
| HTTP 请求统计 | 请求量、响应时间分布、错误率 |
| 数据库连接池 | 连接数、等待数、超时数 |
| Redis 状态 | 连接数、内存使用、命中率 |
| 在线用户数 | 当前登录用户数 |

---

## 十一、数据库设计汇总

### 11.1 涉及数据库/表清单

| 表名 | 所属 Schema | 说明 |
|------|------------|------|
| `system_dict_type` | `intermediary` | 字典类型（框架） |
| `system_dict_data` | `intermediary` | 字典数据（框架） |
| `system_config` | `intermediary` | 参数配置（框架） |
| `system_area` | `intermediary` | 地区数据（框架） |
| `biz_bank` | `intermediary` | 银行管理 |
| `biz_tenant_config` | `intermediary` | 商户外观配置 |
| `sys_config`（各模块） | 各业务 Schema | 业务参数配置（共用表名，各 Schema 独立） |
| `ins_policy_sync_config` | `intermediary` | 车险保单同步配置 |
| `ins_noncar_import_template` | `db_ins_order` | 非车导入模板主表 |
| `ins_noncar_import_template_field` | `db_ins_order` | 非车导入模板字段配置 |
| `ins_life_sys_config` | `db_ins_life` | 寿险系统配置 |
| `ins_life_insurer_account` | `db_ins_life` | 寿险保司工号 |

### 11.2 通用 sys_config 表结构

各业务模块的 `sys_config` 表（复用结构）：

```sql
CREATE TABLE `sys_config` (
  `id`           BIGINT      NOT NULL AUTO_INCREMENT,
  `tenant_id`    BIGINT      NOT NULL DEFAULT 0,
  `config_key`   VARCHAR(100) NOT NULL COMMENT '配置键',
  `config_value` TEXT        NOT NULL COMMENT '配置值',
  `config_group` VARCHAR(50) DEFAULT 'default' COMMENT '配置分组',
  `config_desc`  VARCHAR(200) DEFAULT NULL,
  `creator`      VARCHAR(64) DEFAULT '',
  `create_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`      VARCHAR(64) DEFAULT '',
  `update_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`      TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_key` (`tenant_id`, `config_key`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统参数配置表';
```

---

## 十二、API 接口清单

### 12.1 基础设置接口

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 银行分页查询 | GET | `/admin-api/biz/bank/page` | |
| 银行简单列表 | GET | `/admin-api/biz/bank/simple-list` | 下拉选择用，Redis 缓存 |
| 银行新增 | POST | `/admin-api/biz/bank` | |
| 银行编辑 | PUT | `/admin-api/biz/bank` | |
| 银行删除 | DELETE | `/admin-api/biz/bank/{id}` | 逻辑删除 |
| 银行启用/停用 | PUT | `/admin-api/biz/bank/{id}/status` | |

### 12.2 商户配置接口

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 获取商户配置 | GET | `/admin-api/biz/tenant-config` | |
| 保存商户配置 | PUT | `/admin-api/biz/tenant-config` | 全量更新 |
| 上传 Logo | POST | `/admin-api/biz/tenant-config/upload-logo` | 返回 OSS URL |
| 上传 Favicon | POST | `/admin-api/biz/tenant-config/upload-favicon` | |
| 上传登录页背景图 | POST | `/admin-api/biz/tenant-config/upload-login-bg` | |

### 12.3 账号安全接口

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 获取密码策略 | GET | `/admin-api/biz/security/password-policy` | |
| 保存密码策略 | PUT | `/admin-api/biz/security/password-policy` | |
| 获取登录策略 | GET | `/admin-api/biz/security/login-policy` | |
| 保存登录策略 | PUT | `/admin-api/biz/security/login-policy` | |
| 获取 IP 白名单 | GET | `/admin-api/biz/security/ip-whitelist` | |
| 保存 IP 白名单 | PUT | `/admin-api/biz/security/ip-whitelist` | |

### 12.4 消息通知接口

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 获取短信配置 | GET | `/admin-api/biz/notify/sms-config` | |
| 保存短信配置 | PUT | `/admin-api/biz/notify/sms-config` | |
| 测试短信发送 | POST | `/admin-api/biz/notify/sms-test` | |
| 短信模板列表 | GET | `/admin-api/biz/notify/sms-template/page` | |
| 短信模板新增 | POST | `/admin-api/biz/notify/sms-template` | |
| 短信模板编辑 | PUT | `/admin-api/biz/notify/sms-template` | |
| 短信模板删除 | DELETE | `/admin-api/biz/notify/sms-template/{id}` | |
| 获取推送配置 | GET | `/admin-api/biz/notify/push-config` | |
| 保存推送配置 | PUT | `/admin-api/biz/notify/push-config` | |

### 12.5 车险保单设置接口

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 获取车险保单设置 | GET | `/admin-api/ins/car/policy-setting` | |
| 保存车险保单设置 | PUT | `/admin-api/ins/car/policy-setting` | |
| 同步配置列表 | GET | `/admin-api/ins/car/sync-config/page` | |
| 新增同步配置 | POST | `/admin-api/ins/car/sync-config` | |
| 编辑同步配置 | PUT | `/admin-api/ins/car/sync-config` | |
| 删除同步配置 | DELETE | `/admin-api/ins/car/sync-config/{id}` | |
| 启用/停用同步配置 | PUT | `/admin-api/ins/car/sync-config/{id}/status` | |

### 12.6 非车险系统设置接口

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 导入模板列表 | GET | `/admin-api/ins/noncar/import-template/page` | |
| 导入模板详情 | GET | `/admin-api/ins/noncar/import-template/{id}` | |
| 新增导入模板 | POST | `/admin-api/ins/noncar/import-template` | |
| 编辑导入模板 | PUT | `/admin-api/ins/noncar/import-template` | |
| 删除导入模板 | DELETE | `/admin-api/ins/noncar/import-template/{id}` | |
| 下载模板文件 | GET | `/admin-api/ins/noncar/import-template/{id}/download` | 返回 Excel 文件 |
| 获取非车保单设置 | GET | `/admin-api/ins/noncar/policy-setting` | |
| 保存非车保单设置 | PUT | `/admin-api/ins/noncar/policy-setting` | |

### 12.7 客户设置接口

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 获取客户基础设置 | GET | `/admin-api/ins/customer/setting` | |
| 保存客户基础设置 | PUT | `/admin-api/ins/customer/setting` | |
| 获取跟进阶段列表 | GET | `/admin-api/ins/customer/follow-stage/list` | 只读，系统预置 |
| 获取拨打状态列表 | GET | `/admin-api/ins/customer/call-status/list` | 只读，系统预置 |

### 12.8 寿险系统管理接口

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 获取寿险系统配置 | GET | `/admin-api/ins/life/sys-config` | |
| 保存寿险系统配置 | PUT | `/admin-api/ins/life/sys-config` | |
| 保司工号分页查询 | GET | `/admin-api/ins/life/insurer-account/page` | |
| 新增保司工号 | POST | `/admin-api/ins/life/insurer-account` | |
| 编辑保司工号 | PUT | `/admin-api/ins/life/insurer-account` | |
| 删除保司工号 | DELETE | `/admin-api/ins/life/insurer-account/{id}` | 校验关联保单 |
| 启用/停用工号 | PUT | `/admin-api/ins/life/insurer-account/{id}/status` | |
| H5产品分类列表 | GET | `/admin-api/ins/life/h5-category/list` | |
| H5产品分类新增 | POST | `/admin-api/ins/life/h5-category` | |
| H5产品分类编辑 | PUT | `/admin-api/ins/life/h5-category` | |
| H5内容列表 | GET | `/admin-api/ins/life/h5-content/page` | |
| H5内容新增 | POST | `/admin-api/ins/life/h5-content` | |
| H5内容编辑 | PUT | `/admin-api/ins/life/h5-content` | |

**统一响应格式**：
```json
{
  "code": 0,
  "data": {},
  "msg": "success"
}
```
所有 admin 接口需在 Header 携带 `Authorization: Bearer {token}`，未登录返回 401，无权限返回 403。

---

## 十三、工时估算

> 配置：1 前端 + 1 后端

| 功能模块 | 前端（天） | 后端（天） | 合计 |
|---------|-----------|-----------|------|
| 数据字典（框架复用+预置业务字典SQL） | 0.5 | 0.5 | 1 |
| 参数配置（框架复用+预置参数SQL） | 0.5 | 0.5 | 1 |
| 地区管理（框架复用+数据初始化） | 0.5 | 0.5 | 1 |
| 银行管理（CRUD+缓存） | 0.5 | 0.5 | 1 |
| 商户配置（外观+Logo+登录页） | 1 | 1 | 2 |
| 账号安全（密码策略+登录策略+IP白名单） | 1 | 1.5 | 2.5 |
| 消息通知（短信配置+模板管理+推送配置） | 1.5 | 1.5 | 3 |
| 车险保单设置 | 1 | 1 | 2 |
| 车险同步设置 | 1 | 1.5 | 2.5 |
| 非车导入模板设置 | 1 | 1 | 2 |
| 非车保单设置 | 1 | 1 | 2 |
| 客户设置（基础设置+跟进阶段只读） | 0.5 | 0.5 | 1 |
| 寿险 H5 后台配置 | 1.5 | 1.5 | 3 |
| 寿险系统配置 | 1 | 1 | 2 |
| 寿险保司工号管理 | 1 | 1 | 2 |
| 日志监控（框架复用+注解配置） | 0.5 | 0 | 0.5 |
| **合计** | **13.5** | **14** | **27.5** |
| **含 20% 缓冲** | **16.2** | **16.8** | **33** |

---

## 附录：配置键索引

| 配置键 | 存储位置 | 影响模块 | 说明 |
|--------|---------|---------|------|
| `ins.car.policy.default_date_type` | `intermediary.sys_config` | 车险 | 默认日期类型 |
| `ins.car.policy.default_date_range` | `intermediary.sys_config` | 车险 | 默认日期范围 |
| `ins.car.policy.multi_policy_search` | `intermediary.sys_config` | 车险 | 多保单号逗号搜索 |
| `ins.car.policy.belong_type` | `intermediary.sys_config` | 车险 | 业务归属依据 |
| `ins.car.policy.downstream_limit` | `intermediary.sys_config` | 车险 | 下游手续费限制开关 |
| `non_vehicle_policy_belong_type` | `sys_config（非车Schema）` | 非车 | 非车保单业务归属 |
| `non_vehicle_downstream_check_orgs` | `sys_config（非车Schema）` | 非车 | 下游手续费校验组织列表 |
| `non_vehicle_same_policy_no_insurance_types` | `sys_config（非车Schema）` | 非车 | 允许相同保单号的险种列表 |
| `customer.setting.sort_rule` | `sys_config（客户Schema）` | 客户 | 客户列表默认排序 |
| `customer.setting.auto_reassign` | `sys_config（客户Schema）` | 客户 | 自动重新分配开关 |
| `customer.setting.sms_limit_period` | `sys_config（客户Schema）` | 客户 | 短信限制周期 |
| `customer.setting.sms_limit_count` | `sys_config（客户Schema）` | 客户 | 短信单用户上限 |
| `security.password.min_length` | `intermediary.system_config` | 全局 | 密码最小长度 |
| `security.password.expire_days` | `intermediary.system_config` | 全局 | 密码有效期 |
| `security.login.fail_lock_count` | `intermediary.system_config` | 全局 | 登录失败锁定次数 |
| `agent.code.prefix` | `intermediary.system_config` | 人管 | 业务员工号前缀 |
| `commission.settle.day` | `intermediary.system_config` | 佣金 | 佣金结算日 |

---

*文档结束 | 版本 V1.0 | 下一模块：人管（人员管理）模块 PRD*

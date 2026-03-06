# 阶段1 · PC管理后台 · 业务逻辑开发文档（中）
## 人员管理：业务员 / 资质管理 / 内勤人员

> **框架**：yudao-cloud（微服务版）  
> **文档分篇**：上篇（组织架构）· **中篇（人员管理）** · 下篇（产品管理 & 系统配置）  
> **工时预估（1前端+1后端）**：前端 9天 / 后端 10.5天

---

## 一、业务员管理（biz_agent）

### 1.1 页面入口与列表

菜单路径：**人员管理 → 业务员管理**

**列表页搜索条件**：姓名（模糊）、工号（精确）、手机号（精确）、所属机构（下拉树）、所属部门（联动机构下拉）、状态（下拉：全部/待激活/正常/停用/离职/黑名单）、入职日期范围。

**列表列**：工号、姓名、性别、手机号（中间4位脱敏）、所属机构、所属部门、状态（Tag标签带颜色）、入职日期、证书到期日（临期橙色/已到期红色）、操作（查看 / 编辑 / 重置密码 / 更多[停用/启用/离职/黑名单]）。

**操作按钮**（列表页右上角）：**[+ 新增业务员] [批量导入] [导出] [下载模板]**。

**数据权限**：列表查询自动注入 `@DataPermission`，按用户 data_scope 过滤可见数据。

---

### 1.2 新增业务员

**触发方式**：点击 [+ 新增业务员] 弹出新增弹窗（分「基本信息」「执业资质」「银行信息」三个 Tab）。

#### Tab 1：基本信息

| 字段 | 是否必填 | 前端校验 | 说明 |
|---|---|---|---|
| 真实姓名 | **必填** | 2~20 字 | real_name |
| 性别 | **必填** | 单选 1/2 | gender：1-男 2-女 |
| 身份证号 | **必填** | 18位，最后一位可为X，含校验码验证 | id_card，存储前 AES 加密 |
| 手机号 | **必填** | 11位手机号格式 | mobile，同时作为系统登录账号 |
| 邮箱 | 否 | 邮箱格式 | email |
| 出生日期 | 否 | — | birthday（可从身份证自动提取） |
| 所属机构 | **必填** | 树形下拉，只显示用户有权限的机构 | org_id |
| 所属部门 | 否 | 联动机构，只显示该机构下的部门 | dept_id |
| 所属岗位 | 否 | 联动部门（岗位类别建议销售岗） | post_id |
| 入职日期 | **必填** | 不能早于所属机构成立日期 | entry_date |
| 头像 | 否 | JPG/PNG ≤2MB | avatar，上传 OSS |
| 紧急联系人 | 否 | — | emergency_contact |
| 紧急联系电话 | 否 | 11位手机号 | emergency_phone |

#### Tab 2：执业资质

| 字段 | 是否必填 | 前端校验 | 说明 |
|---|---|---|---|
| 证书类型 | **必填** | 枚举 | 1-代理人证 2-经纪人证 3-公估人证（存入 biz_agent_cert 表） |
| 证书编号 | **必填** | 全局唯一 | cert_no |
| 证书等级 | 否 | — | cert_level |
| 发证日期 | **必填** | 不能是未来日期 | cert_issue_date |
| 证书到期日 | **必填** | 必须 > 发证日期 | cert_expire_date |
| 证书正面照 | 否 | JPG/PNG ≤5MB | cert_front_img，上传 OSS |
| 证书背面照 | 否 | JPG/PNG ≤5MB | cert_back_img，上传 OSS |

#### Tab 3：银行信息

| 字段 | 是否必填 | 前端校验 | 说明 |
|---|---|---|---|
| 开户行 | 否 | 下拉选择 biz_bank | bank_name |
| 银行卡号 | 否 | 16~19位数字，Luhn算法校验 | bank_account，AES 加密存储 |
| 持卡人姓名 | 否 | — | bank_holder |

---

#### 后端处理逻辑（完整流程，加 @Transactional）

**Step 1：唯一性校验**

```sql
-- 手机号唯一（跨业务员表、内勤表、系统用户表）
SELECT COUNT(*) FROM (
  SELECT mobile FROM biz_agent WHERE mobile = #{mobile} AND deleted = 0
  UNION ALL
  SELECT mobile FROM biz_staff WHERE mobile = #{mobile} AND deleted = 0
  UNION ALL
  SELECT mobile FROM system_users WHERE mobile = #{mobile} AND deleted = 0
) t
```
count > 0 抛出：`手机号已被使用`

```sql
-- 身份证唯一（通过MD5摘要快速查重，避免全表AES解密）
SELECT COUNT(*) FROM biz_agent WHERE id_card_md5 = #{idCardMd5} AND deleted = 0
UNION ALL
SELECT COUNT(*) FROM biz_staff WHERE id_card_md5 = #{idCardMd5} AND deleted = 0
```
count > 0 抛出：`该身份证号已存在，请勿重复录入`

**Step 2：机构部门校验**

- 校验 org_id 对应机构 status = 1，否则抛出 `所属机构不存在或已停用`。
- 若填写了 dept_id，校验该部门 org_id = 当前 org_id 且 status = 1。
- 若填写了 post_id，校验该岗位 status = 1（岗位类别建议为销售岗，但不强制）。

**Step 3：证书编号唯一**
```sql
SELECT COUNT(*) FROM biz_agent_cert WHERE cert_no = #{certNo} AND deleted = 0
```
count > 0 抛出：`证书编号已存在`

**Step 4：工号自动生成**

使用 Redis 分布式锁（`AGENT_CODE_LOCK:{tenantId}`）保证并发安全：
```
前缀 = 参数配置 agent.code.prefix，默认 "A"
SELECT MAX(CAST(SUBSTRING(agent_code, LENGTH(prefix)+1) AS UNSIGNED)) FROM biz_agent WHERE tenant_id = #{tenantId} AND deleted = 0
序号 = max + 1，不足6位前补0，拼接前缀 → 如 "A000001"
锁超时时间：3秒，重试2次
```

**Step 5：创建系统用户账号**

调用 yudao-cloud `system` 模块接口，在 `system_users` 表创建一条记录：
- `username` = 业务员手机号
- `password` = BCrypt(参数配置 `agent.default.password`，默认 123456)
- `nickname` = 真实姓名
- `mobile` = 手机号
- `user_type` = 2（业务员）
- `status` = 0（待激活）
- 关联角色：系统预置的 `agent` 角色（INSERT system_user_role）

记录返回的 `user_id`。

**Step 6：业务员记录入库**

INSERT INTO biz_agent，字段包括：
- `user_id` = Step 5 返回值
- `agent_code` = Step 4 生成值
- `id_card` = AES-256加密后的密文
- `id_card_md5` = MD5(原始身份证号，全大写处理) 用于快速查重
- `bank_account` = AES-256加密后的密文（若填写）
- `status` = 0（待激活）
- `entry_date` = 入职日期

**Step 7：证书信息入库**

若 Tab2 有填写，INSERT INTO biz_agent_cert，verify_status 默认 0（待审核）。

**Step 8：岗位关联**

若填写了 post_id，INSERT INTO biz_agent_post (agent_id, post_id, is_primary = 1)。

**Step 9：发送激活短信**

调用短信服务，向 mobile 发送：`您已被录入【XX保险】系统，工号：{agentCode}，初始密码：{defaultPwd}，请及时登录修改密码`。

---

### 1.3 查看业务员详情

点击列表中的 [查看] 或工号链接，跳转到业务员详情页（只读），展示所有字段，其中：
- 身份证号、银行卡号脱敏显示（`3502**********1234`）。
- 手机号中间4位脱敏（`138****8888`）。
- 页面底部有子模块 Tab：**证书列表 / 调动记录 / 离职记录 / 操作日志**。

---

### 1.4 编辑业务员

同新增弹窗布局，但以下字段不可修改（置灰）：
- `agent_code`（工号）
- `id_card`（身份证号，若需变更须走专门的证件变更审批流程）

**手机号变更**：若修改了 mobile，重新执行 Step 1 唯一性校验（排除自身 id），同时：
- UPDATE system_users SET mobile = #{mobile}, username = #{mobile} WHERE id = #{userId}

**机构/部门变更（调动）**：
- 若 org_id 或 dept_id 发生变化，INSERT INTO biz_agent_transfer 记录调动信息：from_org_id、to_org_id、from_dept_id、to_dept_id、from_post_id、to_post_id、transfer_date（当前日期）、operator（操作人）、remark。
- 历史订单、佣金数据的 org_id 保持不变（不随调动迁移），只影响后续新产生数据。

**银行卡变更**：重新 AES 加密存储，INSERT INTO biz_change_log（old_value 和 new_value 均脱敏处理，仅保留前4位+***+后4位）。

**联动更新 system_users**：若修改了 real_name → 同步 nickname；修改了 avatar → 同步 avatar；修改了 email → 同步 email。

---

### 1.5 业务员状态管理

#### 状态流转图

```
待激活(0) ──首次登录修改密码──→ 正常(1)
正常(1)   ──管理员停用────────→ 停用(2)
停用(2)   ──管理员启用────────→ 正常(1)
正常(1)   ──办理离职────────→ 离职(3)
正常(1)/停用(2) ──加入黑名单──→ 黑名单(4)
黑名单(4) ──申诉成功解除────→ 正常(1)
```

#### 停用操作（status 1→2）

**接口**：`PUT /biz/agent/change-status`，支持批量（传 idList + targetStatus）。

后端执行：
1. UPDATE biz_agent SET status = 2 WHERE id IN (...)。
2. UPDATE system_users SET status = 1（框架内"禁用"）WHERE id IN (对应 user_id 列表)。
3. 向业务员发站内信：`您的账号已被停用，如有疑问请联系管理员`。

#### 启用操作（status 2→1）

1. 校验 org_id 对应机构 status = 1，否则抛出 `所属机构已停用，无法启用业务员`。
2. 校验 dept_id 对应部门 status = 1（若有）。
3. UPDATE biz_agent SET status = 1；UPDATE system_users SET status = 0（启用）。

#### 办理离职

**接口**：`PUT /biz/agent/leave/{id}`，弹出离职办理弹窗，需填写：

| 字段 | 是否必填 | 说明 |
|---|---|---|
| 离职日期 | **必填** | leave_date |
| 离职类型 | **必填** | 1-主动离职 2-被动离职 |
| 客户接手人 | **必填** | 从当前机构内正常状态业务员中选择 |
| 备注 | 否 | remark |

后端执行流程（@Transactional）：
1. **前置警告**（不强制阻止，由操作人确认继续）：
   - `SELECT COUNT(*) FROM biz_order WHERE agent_id=#{id} AND status IN (1,2) AND deleted=0` → 提示 `有 {count} 条进行中的订单，建议先处理完毕`。
   - `SELECT COALESCE(SUM(amount),0) FROM biz_commission WHERE agent_id=#{id} AND status=1 AND deleted=0` → 显示未结算佣金金额，提示财务需及时结算。
2. **业务移交**：`UPDATE biz_customer SET agent_id = #{handoverId} WHERE agent_id = #{id} AND deleted = 0`。
3. **状态变更**：`UPDATE biz_agent SET status = 3, leave_date = #{leaveDate} WHERE id = #{id}`。
4. `UPDATE system_users SET status = 1（禁用）WHERE id = #{userId}`。
5. `INSERT INTO biz_agent_leave_record`（leave_type、handover_id、remark）。
6. 发通知给接手业务员：`业务员【{agentName}】已离职，其名下客户已移交给您，请及时跟进`。

#### 加入黑名单

**接口**：`PUT /biz/agent/blacklist/{id}`

弹窗字段：
- 黑名单原因（必填，文本域，≥10字）
- 证据附件（上传，支持多个，JPG/PNG/PDF）

后端执行：
1. UPDATE biz_agent SET status = 4, blacklist_reason = #{reason} WHERE id = #{id}。
2. UPDATE system_users SET status = 1（永久禁用）WHERE id = #{userId}。
3. 冻结待结算佣金：`UPDATE biz_commission SET status = 4（冻结）WHERE agent_id = #{id} AND status = 1`。
4. INSERT INTO biz_blacklist_record（agent_id、reason、evidence_urls、operator_id）。

#### 黑名单申诉解除

**接口**：`PUT /biz/agent/blacklist-remove/{id}`，需填写解除原因。

后端执行：
1. UPDATE biz_agent SET status = 1（恢复正常），blacklist_reason = NULL。
2. UPDATE system_users SET status = 0（恢复启用）。
3. 解冻佣金：`UPDATE biz_commission SET status = 1 WHERE agent_id = #{id} AND status = 4`。
4. 更新 biz_blacklist_record，记录解除原因和解除人。

---

### 1.6 重置密码

**接口**：`PUT /biz/agent/reset-password/{id}`，管理员点击 [重置密码] 后弹出确认框。

后端执行：
1. 从参数配置获取默认密码：`agent.default.password`，默认 `123456`。
2. BCrypt 加密，`UPDATE system_users SET password = #{encodedPwd}, need_change_password = 1 WHERE id = #{userId}`。
3. 向业务员手机号发短信：`您的系统密码已被管理员重置为默认密码，请登录后及时修改`。
4. 记录操作日志（@OperateLog）。

---

### 1.7 业务员导入

**接口**：`POST /biz/agent/import`，上传 xlsx 文件（multipart/form-data）。

**Excel 模板列**（点击 [下载模板] 获取，`GET /biz/agent/import-template`）：

| 列名 | 是否必填 | 格式说明 |
|---|---|---|
| 真实姓名* | 必填 | — |
| 性别* | 必填 | 男/女 |
| 身份证号* | 必填 | 18位 |
| 手机号* | 必填 | 11位 |
| 入职日期* | 必填 | yyyy-MM-dd |
| 机构代码* | 必填 | 必须是已存在的机构代码 |
| 部门代码 | 否 | 必须属于上述机构 |
| 岗位代码 | 否 | — |
| 邮箱 | 否 | — |
| 证书类型 | 否 | 代理人证/经纪人证/公估人证 |
| 证书编号 | 否 | 全局唯一 |
| 证书到期日 | 否 | yyyy-MM-dd |

**后端逻辑**（异步执行，ThreadPool，不阻塞 HTTP 请求）：
1. 立即返回 `{ taskId: "xxx", msg: "导入任务已提交，请稍后查看结果" }`。
2. 后台线程：使用 EasyExcel 解析文件，逐行读取。
3. 对每行数据执行与新增业务员相同的校验（唯一性、格式等）。
4. 校验通过的行批量插入（BATCH INSERT，每批 500 条）。
5. 校验失败的行记录错误信息（行号 + 错误原因），汇总到失败结果 Excel，上传 OSS。
6. 导入完成后，将统计写入 biz_import_log 表（task_id、success_count、fail_count、fail_file_url、operator_id）。
7. 向操作人发送站内信：`本次导入完成，成功：{successCount} 条，失败：{failCount} 条`，附带失败文件下载链接。

---

### 1.8 业务员导出

**接口**：`GET /biz/agent/export`，携带当前列表页的所有搜索条件参数。

- 使用 EasyExcel 生成 xlsx，**最多导出 10000 条**，超出时前端提示 `数据量过大，请缩小筛选范围后重试`。
- 导出字段中，身份证号、银行卡号**脱敏处理**（保留前3位+`****`+后4位）。
- 文件名：`业务员列表_{yyyyMMddHHmmss}.xlsx`，以附件形式下载（Content-Disposition: attachment）。

---

### 1.9 资质管理（biz_agent_cert）

**功能位置**：
- 入口1：在业务员详情页的「证书列表」Tab 中，管理该业务员的证书。
- 入口2：菜单 **人员管理 → 资质管理** 下，统一查看所有业务员的证书状态（可按到期状态、证书类型、机构筛选）。

#### 字段定义

| 字段 | 说明 |
|---|---|
| id | 主键 |
| agent_id | 关联业务员ID |
| cert_type | 证书类型：1-代理人证 2-经纪人证 3-公估人证 |
| cert_no | 证书编号（全局唯一） |
| cert_level | 证书等级（如初级/中级/高级） |
| cert_issue_date | 发证日期 |
| cert_expire_date | 到期日期 |
| cert_front_img | 证书正面图片URL |
| cert_back_img | 证书背面图片URL（可选） |
| verify_status | 审核状态：0-待审核 1-已通过 2-已拒绝 |
| verify_remark | 审核备注/拒绝原因 |
| verify_time | 审核时间 |
| verifier_id | 审核人ID |

#### 证书到期预警定时任务

- **任务名**：`AgentCertExpireTask`，每天 02:30 执行。
- 查询：
```sql
SELECT c.*, a.real_name, a.mobile, o.leader_id as org_leader_id
FROM biz_agent_cert c
JOIN biz_agent a ON c.agent_id = a.id AND a.deleted = 0
JOIN biz_organization o ON a.org_id = o.id
WHERE DATEDIFF(c.cert_expire_date, CURDATE()) IN (90, 60, 30, 7)
  AND c.verify_status = 1
  AND c.deleted = 0
```
- 对每条记录：向对应的业务员发站内信 + 短信，向机构负责人发汇总报告。
- 通知内容：`您的【{certType}】（编号：{certNo}）将于 {certExpireDate} 到期，请及时办理续证`。

#### 证书审核

**接口**：`PUT /biz/agent/cert/audit`

请求参数：certId、verifyStatus（1-通过/2-拒绝）、verifyRemark（拒绝时必填）

后端执行：
1. 校验 verify_status 只能从 0→1 或 0→2（不允许重复审核已审核记录）。
2. UPDATE biz_agent_cert SET verify_status = #{verifyStatus}, verify_remark = #{remark}, verify_time = NOW(), verifier_id = #{currentUserId}。
3. 若通过：向业务员发站内信 `您的证书【{certNo}】已审核通过`。
4. 若拒绝：向业务员发站内信 `您的证书【{certNo}】审核未通过，原因：{verifyRemark}，请重新提交`。

---

### 1.10 数据库表结构

```sql
-- 业务员主表
CREATE TABLE `biz_agent` (
  `id`                BIGINT      NOT NULL AUTO_INCREMENT COMMENT '业务员ID',
  `user_id`           BIGINT      NOT NULL COMMENT '关联 system_users.id',
  `agent_code`        VARCHAR(30) NOT NULL COMMENT '工号（唯一）',
  `real_name`         VARCHAR(20) NOT NULL COMMENT '真实姓名',
  `mobile`            VARCHAR(11) NOT NULL COMMENT '手机号（登录账号）',
  `id_card`           VARCHAR(200) NOT NULL COMMENT '身份证号（AES-256加密）',
  `id_card_md5`       VARCHAR(32) NOT NULL COMMENT '身份证MD5（用于查重，原始号码MD5）',
  `gender`            TINYINT     NOT NULL COMMENT '1-男 2-女',
  `birthday`          DATE        DEFAULT NULL,
  `org_id`            BIGINT      NOT NULL COMMENT '所属机构',
  `dept_id`           BIGINT      DEFAULT NULL COMMENT '所属部门',
  `post_id`           BIGINT      DEFAULT NULL COMMENT '岗位',
  `entry_date`        DATE        NOT NULL COMMENT '入职日期',
  `leave_date`        DATE        DEFAULT NULL COMMENT '离职日期',
  `status`            TINYINT     NOT NULL DEFAULT 0 COMMENT '0-待激活 1-正常 2-停用 3-离职 4-黑名单',
  `blacklist_reason`  VARCHAR(500) DEFAULT NULL COMMENT '黑名单原因',
  `avatar`            VARCHAR(500) DEFAULT NULL,
  `email`             VARCHAR(50)  DEFAULT NULL,
  `bank_name`         VARCHAR(50)  DEFAULT NULL COMMENT '开户行',
  `bank_account`      VARCHAR(200) DEFAULT NULL COMMENT '银行卡号（AES-256加密）',
  `bank_holder`       VARCHAR(20)  DEFAULT NULL COMMENT '持卡人',
  `emergency_contact` VARCHAR(20)  DEFAULT NULL,
  `emergency_phone`   VARCHAR(11)  DEFAULT NULL,
  `creator`           VARCHAR(64)  DEFAULT '',
  `create_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`           VARCHAR(64)  DEFAULT '',
  `update_time`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`           TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`         BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_code`  (`agent_code`, `deleted`),
  UNIQUE KEY `uk_id_card_md5` (`id_card_md5`, `deleted`),
  UNIQUE KEY `uk_mobile`      (`mobile`, `deleted`),
  UNIQUE KEY `uk_user_id`     (`user_id`, `deleted`),
  KEY `idx_org`     (`org_id`),
  KEY `idx_dept`    (`dept_id`),
  KEY `idx_status`  (`status`),
  KEY `idx_tenant`  (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员表';

-- 业务员证书表
CREATE TABLE `biz_agent_cert` (
  `id`              BIGINT      NOT NULL AUTO_INCREMENT,
  `agent_id`        BIGINT      NOT NULL,
  `cert_type`       TINYINT     NOT NULL COMMENT '1-代理人证 2-经纪人证 3-公估人证',
  `cert_no`         VARCHAR(50) NOT NULL COMMENT '证书编号',
  `cert_level`      VARCHAR(20) DEFAULT NULL,
  `cert_issue_date` DATE        NOT NULL,
  `cert_expire_date` DATE       NOT NULL,
  `cert_front_img`  VARCHAR(500) DEFAULT NULL,
  `cert_back_img`   VARCHAR(500) DEFAULT NULL,
  `verify_status`   TINYINT     NOT NULL DEFAULT 0 COMMENT '0-待审核 1-已通过 2-已拒绝',
  `verify_remark`   VARCHAR(500) DEFAULT NULL,
  `verify_time`     DATETIME    DEFAULT NULL,
  `verifier_id`     BIGINT      DEFAULT NULL,
  `creator`         VARCHAR(64) DEFAULT '',
  `create_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         VARCHAR(64) DEFAULT '',
  `update_time`     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         TINYINT     NOT NULL DEFAULT 0,
  `tenant_id`       BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cert_no` (`cert_no`, `deleted`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_expire_date` (`cert_expire_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员证书表';

-- 业务员调动记录表
CREATE TABLE `biz_agent_transfer` (
  `id`           BIGINT      NOT NULL AUTO_INCREMENT,
  `agent_id`     BIGINT      NOT NULL,
  `from_org_id`  BIGINT      NOT NULL,
  `to_org_id`    BIGINT      NOT NULL,
  `from_dept_id` BIGINT      DEFAULT NULL,
  `to_dept_id`   BIGINT      DEFAULT NULL,
  `from_post_id` BIGINT      DEFAULT NULL,
  `to_post_id`   BIGINT      DEFAULT NULL,
  `transfer_date` DATE       NOT NULL,
  `remark`       VARCHAR(500) DEFAULT NULL,
  `creator`      VARCHAR(64) DEFAULT '',
  `create_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`    BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_agent_id` (`agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员调动记录';

-- 业务员离职记录表
CREATE TABLE `biz_agent_leave_record` (
  `id`           BIGINT      NOT NULL AUTO_INCREMENT,
  `agent_id`     BIGINT      NOT NULL,
  `leave_date`   DATE        NOT NULL,
  `leave_type`   TINYINT     NOT NULL COMMENT '1-主动离职 2-被动离职',
  `handover_id`  BIGINT      DEFAULT NULL COMMENT '接手业务员ID',
  `remark`       VARCHAR(500) DEFAULT NULL,
  `creator`      VARCHAR(64) DEFAULT '',
  `create_time`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`    BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_agent_id` (`agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='业务员离职记录';

-- 黑名单记录表
CREATE TABLE `biz_blacklist_record` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT,
  `agent_id`       BIGINT       NOT NULL,
  `reason`         VARCHAR(500) NOT NULL COMMENT '黑名单原因',
  `evidence_urls`  TEXT         DEFAULT NULL COMMENT '证据附件URL列表（JSON数组）',
  `action`         TINYINT      NOT NULL DEFAULT 1 COMMENT '1-加入黑名单 2-解除黑名单',
  `remove_reason`  VARCHAR(500) DEFAULT NULL COMMENT '解除原因',
  `operator_id`    BIGINT       NOT NULL COMMENT '操作人ID',
  `creator`        VARCHAR(64)  DEFAULT '',
  `create_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`      BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_agent_id` (`agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='黑名单记录';

-- 导入任务日志表
CREATE TABLE `biz_import_log` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT,
  `task_id`        VARCHAR(64)  NOT NULL COMMENT '任务ID（UUID）',
  `import_type`    VARCHAR(30)  NOT NULL COMMENT '导入类型：agent/staff/product等',
  `total_count`    INT          DEFAULT 0 COMMENT '总行数',
  `success_count`  INT          DEFAULT 0 COMMENT '成功行数',
  `fail_count`     INT          DEFAULT 0 COMMENT '失败行数',
  `fail_file_url`  VARCHAR(500) DEFAULT NULL COMMENT '失败明细文件OSS地址',
  `status`         TINYINT      NOT NULL DEFAULT 0 COMMENT '0-处理中 1-完成 2-失败',
  `operator_id`    BIGINT       NOT NULL,
  `creator`        VARCHAR(64)  DEFAULT '',
  `create_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `tenant_id`      BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_task_id`    (`task_id`),
  KEY `idx_operator`   (`operator_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='导入任务日志';
```

---

## 二、内勤人员管理（biz_staff）

### 2.1 功能说明

内勤人员是保险中介公司的管理/支持人员（如财务、客服、核保、IT等），与业务员的区别：
- **无佣金**，领固定工资。
- **使用 PC 管理后台**，不用业务员 App。
- 系统账号角色不同：内勤根据岗位类别自动关联不同的角色（finance / staff / org_admin 等）。

### 2.2 内勤列表与搜索

与业务员列表类似，搜索条件：姓名、工号、手机号、机构、部门、岗位、状态（无黑名单状态）。

---

### 2.3 新增内勤人员

弹窗与业务员基本相同，**差异**如下：
- 工号前缀为 `S`（Staff），读取参数 `staff.code.prefix`，分布式锁 key `STAFF_CODE_LOCK:{tenantId}`。
- **无「执业资质」Tab**（内勤不需要执业证）。
- **岗位类别**：只能选管理岗（1）、职能岗（3）、技术岗（4），销售岗仅限业务员。

#### 后端处理逻辑差异

- **Step 5 创建系统账号** → 角色分配逻辑：
  - 若 post_category = 1（管理岗）→ 关联 `org_admin` 或 `dept_manager` 角色（根据岗位代码前缀判断，如 `ORG_`开头→org_admin，`DEPT_`开头→dept_manager，否则由操作人手动选择）。
  - 若 post_category = 3（职能岗）→ 若岗位名称含"财务"则关联 `finance` 角色，否则关联默认 `staff` 角色。
  - 若 post_category = 4（技术岗）→ 关联自定义技术角色（`tech_admin`），或由管理员手动调整。
  - **以上角色分配仅作为初始建议，管理员可在「系统用户管理」中手动调整**，并在创建完成时弹出提示：`内勤创建成功，已自动关联【{roleName}】角色，如需调整请前往用户管理`。

---

### 2.4 编辑内勤人员

同业务员编辑逻辑，额外注意：
- **岗位变更影响角色**：若修改了 post_id，系统提示管理员：`岗位已变更，当前用户的系统角色可能需要同步调整，请前往【系统用户管理】确认`（不自动变更角色，由管理员手动处理，因角色变更影响较大）。

---

### 2.5 内勤人员删除

1. 查询是否存在以该内勤为操作人的审核记录或财务单据：
   ```sql
   SELECT COUNT(*) FROM biz_audit_log WHERE operator_id = #{id} AND deleted = 0
   UNION ALL
   SELECT COUNT(*) FROM biz_finance_bill WHERE operator_id = #{id} AND deleted = 0
   ```
   count > 0 则拒绝删除，提示 `该人员存在历史操作记录，不允许删除，建议使用离职功能`。
2. 无记录则逻辑删除 biz_staff（deleted=1），并同步逻辑删除 system_users（status=1 + deleted=1）。

---

### 2.6 数据库表结构

```sql
CREATE TABLE `biz_staff` (
  `id`            BIGINT      NOT NULL AUTO_INCREMENT COMMENT '内勤ID',
  `user_id`       BIGINT      NOT NULL COMMENT '关联 system_users.id',
  `staff_code`    VARCHAR(30) NOT NULL COMMENT '工号（前缀S，唯一）',
  `real_name`     VARCHAR(20) NOT NULL,
  `mobile`        VARCHAR(11) NOT NULL,
  `id_card`       VARCHAR(200) NOT NULL COMMENT 'AES-256加密',
  `id_card_md5`   VARCHAR(32) NOT NULL COMMENT '身份证MD5',
  `gender`        TINYINT     NOT NULL,
  `birthday`      DATE        DEFAULT NULL,
  `org_id`        BIGINT      NOT NULL,
  `dept_id`       BIGINT      DEFAULT NULL,
  `post_id`       BIGINT      DEFAULT NULL,
  `entry_date`    DATE        NOT NULL,
  `leave_date`    DATE        DEFAULT NULL,
  `status`        TINYINT     NOT NULL DEFAULT 0 COMMENT '0-待激活 1-正常 2-停用 3-离职',
  `avatar`        VARCHAR(500) DEFAULT NULL,
  `email`         VARCHAR(50)  DEFAULT NULL,
  `bank_name`     VARCHAR(50)  DEFAULT NULL,
  `bank_account`  VARCHAR(200) DEFAULT NULL COMMENT 'AES-256加密',
  `bank_holder`   VARCHAR(20)  DEFAULT NULL,
  `creator`       VARCHAR(64) DEFAULT '',
  `create_time`   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`       VARCHAR(64) DEFAULT '',
  `update_time`   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`       TINYINT     NOT NULL DEFAULT 0,
  `tenant_id`     BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_staff_code`  (`staff_code`, `deleted`),
  UNIQUE KEY `uk_id_card_md5` (`id_card_md5`, `deleted`),
  UNIQUE KEY `uk_mobile`      (`mobile`, `deleted`),
  UNIQUE KEY `uk_user_id`     (`user_id`, `deleted`),
  KEY `idx_org`    (`org_id`),
  KEY `idx_dept`   (`dept_id`),
  KEY `idx_status` (`status`),
  KEY `idx_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='内勤人员表';
```

---

## 三、待激活账号超期处理（定时任务）

- **任务名**：`AgentCodeInactiveTask`，每天 04:00 执行。
- 查询：
  ```sql
  SELECT id, user_id, agent_code, org_id FROM biz_agent
  WHERE status = 0
    AND DATEDIFF(CURDATE(), create_time) >= #{agent.code.inactive.days}
    AND deleted = 0
  ```
- 执行：
  1. `UPDATE biz_agent SET status = 2 WHERE id IN (...)`（停用）。
  2. `UPDATE system_users SET status = 1 WHERE id IN (...)`（禁用登录）。
  3. 向各机构管理员发站内信：`以下业务员工号已超期未激活，已自动停用：{agentCodes}`。
- 同理处理 biz_staff 中的待激活内勤账号。

---

## 四、密码到期提醒（定时任务）

- **任务名**：`PasswordExpireAlertTask`，每天 05:00 执行。
- 查询 system_users 中 `DATEDIFF(CURDATE(), password_update_time) >= #{password.expire.days}` 且 status = 0（启用）的账号。
- 向这些用户发站内信：`您的登录密码已超过 {days} 天未修改，为保障账号安全，请及时更换密码`。
- 若 DATEDIFF > password.expire.days + 7，则下次登录时强制弹出修改密码页（system_users 增加 `force_change_password` 字段控制）。

---

## 五、接口清单汇总

| 模块 | 方法 | 路径 | 说明 |
|---|---|---|---|
| 业务员 | GET | `/biz/agent/page` | 分页列表 |
| 业务员 | GET | `/biz/agent/{id}` | 详情 |
| 业务员 | POST | `/biz/agent` | 新增 |
| 业务员 | PUT | `/biz/agent` | 编辑 |
| 业务员 | DELETE | `/biz/agent/{id}` | 删除（仅待激活状态） |
| 业务员 | PUT | `/biz/agent/change-status` | 批量停用/启用 |
| 业务员 | PUT | `/biz/agent/leave/{id}` | 办理离职 |
| 业务员 | PUT | `/biz/agent/blacklist/{id}` | 加入黑名单 |
| 业务员 | PUT | `/biz/agent/blacklist-remove/{id}` | 申诉解除黑名单 |
| 业务员 | PUT | `/biz/agent/reset-password/{id}` | 重置密码 |
| 业务员 | POST | `/biz/agent/import` | Excel导入（异步） |
| 业务员 | GET | `/biz/agent/export` | Excel导出 |
| 业务员 | GET | `/biz/agent/import-template` | 下载导入模板 |
| 业务员 | GET | `/biz/agent/import-result?taskId=` | 查询导入进度/结果 |
| 证书 | GET | `/biz/agent/cert/page` | 证书分页列表（带到期状态） |
| 证书 | POST | `/biz/agent/cert` | 新增证书 |
| 证书 | PUT | `/biz/agent/cert` | 编辑证书 |
| 证书 | PUT | `/biz/agent/cert/audit` | 审核证书（通过/拒绝） |
| 证书 | DELETE | `/biz/agent/cert/{id}` | 删除证书 |
| 内勤 | GET | `/biz/staff/page` | 分页列表 |
| 内勤 | GET | `/biz/staff/{id}` | 详情 |
| 内勤 | POST | `/biz/staff` | 新增 |
| 内勤 | PUT | `/biz/staff` | 编辑 |
| 内勤 | DELETE | `/biz/staff/{id}` | 删除（有历史记录时拒绝） |
| 内勤 | PUT | `/biz/staff/change-status` | 批量停用/启用 |
| 内勤 | PUT | `/biz/staff/leave/{id}` | 办理离职 |
| 内勤 | PUT | `/biz/staff/reset-password/{id}` | 重置密码 |
| 内勤 | POST | `/biz/staff/import` | Excel导入 |
| 内勤 | GET | `/biz/staff/export` | Excel导出 |

---

## 六、本篇工时估算（1前端 + 1后端）

| 功能点 | 前端(天) | 后端(天) | 合计 |
|---|---|---|---|
| 业务员列表（分页+搜索+数据权限） | 1 | 0.5 | 1.5 |
| 业务员新增（3Tab+9步事务） | 1 | 2 | 3 |
| 业务员编辑+状态管理（停用/启用/批量） | 1 | 1.5 | 2.5 |
| 业务员离职办理 | 0.5 | 1 | 1.5 |
| 黑名单管理（加入+解除） | 0.5 | 0.5 | 1 |
| 业务员导入（异步+模板下载） | 0.5 | 1 | 1.5 |
| 业务员导出+密码重置 | 0.5 | 0.5 | 1 |
| 资质证书管理（CRUD+审核+预警任务） | 1 | 1 | 2 |
| 内勤人员管理（CRUD） | 1 | 1 | 2 |
| 待激活超期+密码到期定时任务 | 0 | 1.5 | 1.5 |
| **合计** | **7** | **10.5** | **17.5** |

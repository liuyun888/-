# 阶段1 · PC管理后台 · 业务逻辑开发文档（上）
## 组织架构管理：机构 / 部门 / 岗位 / 角色权限

> **框架**：yudao-cloud（微服务版）  
> **数据库前缀**：`biz_`  
> **接口前缀**：`/admin-api/biz/`  
> **读者**：后端开发、前端开发  
> **文档分篇**：**上篇（组织架构）**· 中篇（人员管理）· 下篇（产品管理 & 系统配置）  
> **工时预估（1前端+1后端）**：前端 4.5天 / 后端 5天

---

## 一、机构管理（biz_organization）

### 1.1 页面入口

菜单路径：**系统管理 → 机构管理**

页面布局为左右两栏：左侧为机构树（懒加载），右侧为选中机构的详情卡片，卡片底部有 **[编辑] [删除] [添加下级]** 三个按钮。页面右上角有 **[+ 新增机构]** 按钮。

---

### 1.2 新增机构

**触发方式**：点击 [+ 新增机构] 或机构卡片上的 [添加下级]，弹出新增弹窗。

#### 弹窗字段与校验规则

| 字段 | 类型 | 是否必填 | 前端校验 | 说明 |
|---|---|---|---|---|
| 上级机构 | 树形下拉 | 否 | — | 不选则为顶级机构，parent_id = 0 |
| 机构名称 | 文本 | **必填** | 2~50 字符 | org_name |
| 机构代码 | 文本 | **必填** | 唯一，仅允许字母数字下划线 | org_code，创建后不可修改 |
| 机构类型 | 单选 | **必填** | 1/2/3 | 1-总公司 2-分公司 3-营业部 |
| 负责人 | 人员选择器 | 否 | — | 选择已存在的内勤/业务员 |
| 联系电话 | 文本 | **必填** | 11位手机号正则 | phone |
| 省市区 | 级联选择 | 否 | — | province_code / city_code / district_code |
| 详细地址 | 文本 | 否 | 最多200字符 | address |
| 成立日期 | 日期选择器 | **必填** | 不能是未来日期 | establish_date |
| 营业执照号 | 文本 | **必填** | — | license_no |
| 营业执照图片 | 上传 | 否 | 仅 JPG/PNG，≤5MB | license_image，上传到 OSS，存 URL |
| 经营许可证号 | 文本 | **必填** | — | permit_no |
| 许可证有效期 | 日期范围 | **必填** | 结束日期 > 开始日期 | permit_start_date / permit_end_date |
| 状态 | 单选 | **必填** | 默认启用 | status：0-停用 1-启用 |
| 排序 | 数字 | **必填** | 默认 0，≥0 | sort |
| 备注 | 文本域 | 否 | 最多500字符 | remark |

#### 后端处理逻辑（按顺序执行）

1. **机构代码唯一性校验**：`SELECT COUNT(*) FROM biz_organization WHERE org_code = #{orgCode} AND deleted = 0`，count > 0 则抛出 `机构代码已存在`。
2. **上级机构有效性校验**：若 parent_id ≠ 0，查询父机构的 status，若父机构不存在或 status = 0，抛出 `上级机构不存在或已停用，不允许在其下创建子机构`。
3. **许可证日期校验**：permit_end_date ≤ permit_start_date，抛出 `许可证到期日期必须晚于生效日期`。
4. **机构层级限制**：计算 ancestors 中的逗号数量（即层级深度），超过 5 级抛出 `机构层级不能超过5级`。
5. **祖级列表自动构建**：
   - parent_id = 0：`ancestors = "0"`
   - parent_id ≠ 0：`ancestors = 父机构.ancestors + "," + 父机构.id`
6. **负责人冗余存储**：若选择了 leader_id，查询 biz_agent 或 biz_staff 表获取姓名，填充 leader_name。
7. **自动填充**：creator / create_time / tenant_id 从 SecurityFrameworkUtils 当前登录上下文获取，deleted = 0，status 默认 1。
8. **入库**：INSERT INTO biz_organization，返回新记录 id。
9. **清除机构树缓存**：删除 Redis key `org:tree:{tenant_id}`。

---

### 1.3 编辑机构

**触发方式**：点击机构卡片上的 [编辑] 按钮，弹出编辑弹窗，字段与新增相同，但以下字段置灰不可编辑：

- `org_code`（机构代码）：一旦创建永不可改。

#### 后端处理逻辑

1. **机构代码防篡改**：若请求体中的 org_code 与数据库不一致，直接抛出 `机构代码不允许修改`，不继续执行。
2. **上级机构变更时批量更新 ancestors**（若 parent_id 发生变化）：
   - 校验新的 parent_id 不能是当前机构自己，也不能是当前机构的子孙机构（防止形成环形）。
   - 计算当前机构新的 ancestors。
   - 查询所有 `ancestors LIKE '%,{当前机构id}%'` 的子孙机构。
   - 将子孙机构的 ancestors 中旧前缀替换为新前缀（批量 UPDATE）。
   - 以上操作在同一个 `@Transactional` 事务中执行。
3. **停用联动**（status 从 1 → 0）：
   - 将所有子机构（ancestors LIKE '%,{当前id}%'）的 status 全部改为 0。
   - 将该机构下所有业务员（biz_agent.org_id = 当前机构 id）的 status 改为 2（停用）。
   - 将 biz_product_org 中该机构相关的授权记录 status 改为 0。
   - 向机构负责人发送站内信通知（调用消息服务）。
4. **启用限制**（status 从 0 → 1）：检查 parent_id 对应的父机构 status 是否为 1，否则抛出 `上级机构已停用，无法启用当前机构`。
5. **负责人变更同步**：若 leader_id 改变，重新查询新负责人姓名并更新 leader_name，同时写一条变更日志。
6. **更新入库**：updater / update_time 自动填充。
7. **清除缓存**：删除 Redis key `org:tree:{tenant_id}`。

---

### 1.4 删除机构

**触发方式**：点击机构卡片上的 [删除] 按钮，弹出二次确认框 "确认删除该机构？此操作不可恢复"。

#### 后端处理逻辑（依次校验，任一不通过则拒绝删除）

1. `SELECT COUNT(*) FROM biz_organization WHERE parent_id = #{id} AND deleted = 0` → count > 0，抛出 `存在下级机构，请先删除下级机构`。
2. `SELECT COUNT(*) FROM biz_agent WHERE org_id = #{id} AND deleted = 0` → count > 0，抛出 `机构下存在 {count} 个业务员，不允许删除`。
3. `SELECT COUNT(*) FROM biz_order WHERE org_id = #{id} AND deleted = 0` → count > 0，抛出 `机构存在 {count} 条历史订单，不允许删除`。
4. `SELECT COUNT(*) FROM biz_product_org WHERE org_id = #{id} AND deleted = 0` → count > 0，抛出 `机构存在产品授权记录，请先取消授权`。
5. `SELECT COUNT(*) FROM biz_commission WHERE org_id = #{id} AND deleted = 0` → count > 0，抛出 `机构存在佣金记录，不允许删除`。
6. 以上校验全部通过后执行**逻辑删除**：`UPDATE biz_organization SET deleted = 1, updater = #{operator}, update_time = NOW() WHERE id = #{id}`。
7. **清除缓存**：删除 Redis key `org:tree:{tenant_id}`。

---

### 1.5 机构树查询

- **接口**：`GET /admin-api/biz/organization/tree`
- **策略**：一次性 `SELECT * FROM biz_organization WHERE tenant_id = #{tenantId} AND status = 1 AND deleted = 0 ORDER BY sort ASC`，在内存中递归构建树形结构（不用递归 SQL）。
- **数据权限**：若当前登录用户有 org_id 限制，则追加 `AND (id = #{currentOrgId} OR ancestors LIKE '%,{currentOrgId}%')` 过滤只属于自己机构及其下级。
- **Redis 缓存**：key = `org:tree:{tenantId}`，TTL = 1 小时；机构任何增删改操作后主动 delete 该 key。
- **懒加载支持**：若组织规模大（建议 > 1000 个机构），改用接口 `GET /tree/lazy?parentId=0`，每次只返回指定 parentId 的直接子节点。

---

### 1.6 许可证到期预警（定时任务）

- **任务名称**：`OrgPermitExpireTask`，使用 XXL-Job，每天 02:00 执行。
- **逻辑**：`SELECT * FROM biz_organization WHERE DATEDIFF(permit_end_date, CURDATE()) <= 90 AND DATEDIFF(permit_end_date, CURDATE()) >= 0 AND status = 1 AND deleted = 0`。
- 对查询到的机构，向 leader_id 对应的用户发送站内信和短信，内容为：`您管理的机构【{orgName}】经营许可证将于 {permitEndDate} 到期，请及时办理续期`。
- 同时向平台超管发送汇总邮件。

---

### 1.7 数据库表结构

```sql
CREATE TABLE `biz_organization` (
  `id`               BIGINT      NOT NULL AUTO_INCREMENT COMMENT '机构ID',
  `parent_id`        BIGINT      NOT NULL DEFAULT 0 COMMENT '父机构ID，顶级为0',
  `ancestors`        VARCHAR(500) DEFAULT '' COMMENT '祖级ID列表，逗号分隔',
  `org_name`         VARCHAR(50) NOT NULL COMMENT '机构名称',
  `org_code`         VARCHAR(30) NOT NULL COMMENT '机构代码（唯一）',
  `org_type`         TINYINT     NOT NULL COMMENT '机构类型：1-总公司 2-分公司 3-营业部',
  `leader_id`        BIGINT      DEFAULT NULL COMMENT '负责人ID',
  `leader_name`      VARCHAR(20) DEFAULT NULL COMMENT '负责人姓名（冗余）',
  `phone`            VARCHAR(11) NOT NULL COMMENT '联系电话',
  `province_code`    VARCHAR(20) DEFAULT NULL COMMENT '省代码',
  `city_code`        VARCHAR(20) DEFAULT NULL COMMENT '市代码',
  `district_code`    VARCHAR(20) DEFAULT NULL COMMENT '区代码',
  `address`          VARCHAR(200) DEFAULT NULL COMMENT '详细地址',
  `establish_date`   DATE        NOT NULL COMMENT '成立日期',
  `license_no`       VARCHAR(50) NOT NULL COMMENT '营业执照号',
  `license_image`    VARCHAR(500) DEFAULT NULL COMMENT '营业执照图片URL',
  `permit_no`        VARCHAR(50) NOT NULL COMMENT '经营许可证号',
  `permit_start_date` DATE       NOT NULL COMMENT '许可证生效日期',
  `permit_end_date`  DATE        NOT NULL COMMENT '许可证到期日期',
  `status`           TINYINT     NOT NULL DEFAULT 1 COMMENT '状态：0-停用 1-启用',
  `sort`             INT         NOT NULL DEFAULT 0 COMMENT '排序',
  `remark`           VARCHAR(500) DEFAULT NULL COMMENT '备注',
  `creator`          VARCHAR(64) DEFAULT '' COMMENT '创建者',
  `create_time`      DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64) DEFAULT '' COMMENT '更新者',
  `update_time`      DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          TINYINT     NOT NULL DEFAULT 0 COMMENT '逻辑删除：0-否 1-是',
  `tenant_id`        BIGINT      NOT NULL DEFAULT 0 COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_org_code` (`org_code`, `deleted`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_tenant`    (`tenant_id`),
  KEY `idx_status`    (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='机构表';
```

---

## 二、部门管理（biz_department）

### 2.1 页面入口

菜单路径：**系统管理 → 部门管理**

页面顶部有机构选择下拉框（必选，默认显示当前用户所属机构）。选择机构后，左侧展示该机构的部门树，右侧展示选中部门的详情。操作按钮：**[+ 新增部门] [编辑] [删除] [添加下级]**。

---

### 2.2 新增部门

**触发方式**：点击 [+ 新增部门] 或 [添加下级]。

#### 弹窗字段与校验规则

| 字段 | 是否必填 | 前端校验 | 说明 |
|---|---|---|---|
| 所属机构 | **必填** | 不可更改（从当前页面机构继承） | org_id |
| 上级部门 | 否 | 必须属于同一机构 | parent_id；不选则为该机构顶级部门 |
| 部门名称 | **必填** | 2~30 字符 | dept_name |
| 部门代码 | **必填** | 全局唯一；建议格式：机构代码-部门序号 | dept_code，创建后不可改 |
| 部门负责人 | 否 | 必须是该机构下的启用状态人员 | leader_id |
| 联系电话 | 否 | 11位手机号 | phone |
| 邮箱 | 否 | 邮箱格式 | email |
| 状态 | **必填** | 默认启用 | status |
| 排序 | **必填** | 默认 0，≥0 | sort |

#### 后端处理逻辑

1. **机构存在且启用**：校验 org_id 对应机构 status = 1，否则抛出 `所属机构不存在或已停用`。
2. **部门代码唯一**：`SELECT COUNT(*) FROM biz_department WHERE dept_code = #{deptCode} AND deleted = 0`，count > 0 抛出 `部门代码已存在`。
3. **父部门校验**：若 parent_id ≠ 0，验证该父部门 org_id 与当前 org_id 相同且 status = 1，否则抛出 `上级部门不属于当前机构或已停用`。
4. **层级限制**：ancestors 中逗号数量 ≥ 4 时（即超过 4 级），抛出 `部门层级不能超过4级`。
5. **祖级列表构建**：同机构表逻辑。
6. **负责人校验**：若指定 leader_id，校验该人员 org_id = 当前 org_id 且 status 正常，否则抛出 `负责人不属于当前机构或已停用`；同时查询姓名填充 leader_name。
7. **入库**，自动填充公共字段，**清除缓存** key = `dept:tree:{orgId}`。

---

### 2.3 编辑部门

- org_id（所属机构）和 dept_code（部门代码）置灰，不可修改。
- **上级部门变更**：若 parent_id 变化，执行以下校验与操作：
  1. 新 parent_id ≠ 当前部门 id（自引用检查）。
  2. 新 parent_id 不在当前部门的子孙部门 id 列表中（`SELECT id FROM biz_department WHERE ancestors LIKE '%,#{currentId}%'`）。
  3. 新父部门与当前部门 org_id 相同。
  4. 批量更新当前部门及子孙部门的 ancestors（同机构管理编辑逻辑），事务保证。
- **状态停用联动**（status 0）：递归停用所有子部门 → 停用该部门下所有岗位（biz_post.dept_id）→ 停用该部门下所有人员（biz_agent.dept_id / biz_staff.dept_id 改 status = 2）→ 发通知。
- **状态启用校验**：父部门 status = 1 且所属机构 status = 1，否则不允许启用。
- **清除缓存** key = `dept:tree:{orgId}`。

---

### 2.4 删除部门

依次校验，任一不通过则拒绝：

1. `SELECT COUNT(*) FROM biz_department WHERE parent_id = #{id} AND deleted = 0` → 存在则抛出 `存在下级部门，请先删除下级`。
2. `SELECT COUNT(*) FROM biz_post WHERE dept_id = #{id} AND deleted = 0` → 存在则抛出 `部门下存在 {count} 个岗位，不允许删除`。
3. `SELECT COUNT(*) FROM biz_agent WHERE dept_id = #{id} AND deleted = 0` → 存在则抛出 `部门下存在 {count} 个业务员，不允许删除`。
4. `SELECT COUNT(*) FROM biz_staff WHERE dept_id = #{id} AND deleted = 0` → 存在则抛出 `部门下存在 {count} 个内勤人员，不允许删除`。
5. 校验通过后逻辑删除，**清除缓存**。

---

### 2.5 数据库表结构

```sql
CREATE TABLE `biz_department` (
  `id`          BIGINT      NOT NULL AUTO_INCREMENT COMMENT '部门ID',
  `org_id`      BIGINT      NOT NULL COMMENT '所属机构ID',
  `parent_id`   BIGINT      NOT NULL DEFAULT 0 COMMENT '父部门ID',
  `ancestors`   VARCHAR(500) DEFAULT '' COMMENT '祖级ID列表',
  `dept_name`   VARCHAR(30) NOT NULL COMMENT '部门名称',
  `dept_code`   VARCHAR(30) NOT NULL COMMENT '部门代码（全局唯一）',
  `leader_id`   BIGINT      DEFAULT NULL COMMENT '部门负责人ID',
  `leader_name` VARCHAR(20) DEFAULT NULL COMMENT '负责人姓名（冗余）',
  `phone`       VARCHAR(11) DEFAULT NULL COMMENT '联系电话',
  `email`       VARCHAR(50) DEFAULT NULL COMMENT '邮箱',
  `status`      TINYINT     NOT NULL DEFAULT 1 COMMENT '状态：0-停用 1-启用',
  `sort`        INT         NOT NULL DEFAULT 0 COMMENT '排序',
  `creator`     VARCHAR(64) DEFAULT '',
  `create_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`     VARCHAR(64) DEFAULT '',
  `update_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`     TINYINT     NOT NULL DEFAULT 0,
  `tenant_id`   BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_dept_code` (`dept_code`, `deleted`),
  KEY `idx_org_id`    (`org_id`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_tenant`    (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='部门表';
```

---

## 三、岗位管理（biz_post）

### 3.1 页面入口

菜单路径：**系统管理 → 岗位管理**，展示列表页（分页），支持按岗位名称、岗位代码、状态筛选。操作列：**[编辑] [删除]**。列表页右上角有 **[+ 新增岗位]** 按钮。

---

### 3.2 新增岗位

点击 [+ 新增岗位] 弹出弹窗。

#### 弹窗字段与校验规则

| 字段 | 是否必填 | 前端校验 | 说明 |
|---|---|---|---|
| 岗位代码 | **必填** | 全局唯一 | post_code，创建后不可改 |
| 岗位名称 | **必填** | 2~50字符 | post_name；同一机构下名称不重复（可同名提示但不强制） |
| 岗位类别 | **必填** | 枚举 | 1-管理岗 2-销售岗 3-职能岗 4-技术岗 5-其他 |
| 状态 | **必填** | 默认启用 | — |
| 排序 | **必填** | 默认 0 | — |
| 备注/职责说明 | 否 | 最多500字符 | remark |

#### 后端处理逻辑

1. **岗位代码唯一**：`SELECT COUNT(*) FROM biz_post WHERE post_code = #{postCode} AND deleted = 0`，count > 0 抛出 `岗位代码已存在`。
2. 自动填充公共字段，入库。

> **注意**：岗位是全局概念，不直接关联 dept_id。岗位与部门的关联通过人员表中的 `dept_id + post_id` 联合确定。岗位类别影响内勤人员创建时的系统角色自动匹配逻辑（见中篇）。

---

### 3.3 编辑岗位

- post_code 置灰不可修改。
- **岗位停用联动**（status 从 1 → 0）：查询该岗位下的所有人员（biz_agent.post_id = #{id} 或 biz_staff.post_id = #{id}），向他们发送站内信 `您的岗位【{postName}】已停用，请联系管理员处理`。但不强制停用人员账号。
- **岗位启用前校验**：无特殊限制。

---

### 3.4 删除岗位

1. `SELECT COUNT(*) FROM biz_agent WHERE post_id = #{id} AND deleted = 0` → 存在则抛出 `岗位下有 {count} 个业务员，请先调整人员岗位`。
2. `SELECT COUNT(*) FROM biz_staff WHERE post_id = #{id} AND deleted = 0` → 存在则抛出 `岗位下有 {count} 个内勤人员，请先调整人员岗位`。
3. 校验通过后逻辑删除。

---

### 3.5 数据库表结构

```sql
CREATE TABLE `biz_post` (
  `id`            BIGINT      NOT NULL AUTO_INCREMENT COMMENT '岗位ID',
  `post_code`     VARCHAR(30) NOT NULL COMMENT '岗位代码（全局唯一）',
  `post_name`     VARCHAR(50) NOT NULL COMMENT '岗位名称',
  `post_category` TINYINT     NOT NULL COMMENT '类别：1-管理岗 2-销售岗 3-职能岗 4-技术岗 5-其他',
  `status`        TINYINT     NOT NULL DEFAULT 1 COMMENT '0-停用 1-启用',
  `sort`          INT         NOT NULL DEFAULT 0,
  `remark`        VARCHAR(500) DEFAULT NULL COMMENT '职责说明',
  `creator`       VARCHAR(64) DEFAULT '',
  `create_time`   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`       VARCHAR(64) DEFAULT '',
  `update_time`   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`       TINYINT     NOT NULL DEFAULT 0,
  `tenant_id`     BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_post_code` (`post_code`, `deleted`),
  KEY `idx_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='岗位表';
```

---

## 四、角色权限（复用 yudao-cloud 框架）

### 4.1 说明

角色管理、菜单管理、权限分配完全复用 yudao-cloud 框架自带的 `system_role`、`system_menu`、`system_role_menu`、`system_user_role` 等表和接口，无需二次开发。

保险业务需要在框架基础上**预置以下角色**，在项目初始化（数据库初始化脚本）时插入：

| 角色标识 | 角色名称 | 说明 |
|---|---|---|
| `super_admin` | 超级管理员 | 全部权限（框架默认） |
| `platform_admin` | 平台管理员 | 管理所有机构的数据 |
| `org_admin` | 机构管理员 | 只能管理本机构数据 |
| `dept_manager` | 部门经理 | 只能管理本部门数据 |
| `agent` | 业务员 | 只能查看自己数据 |
| `staff` | 内勤 | 后台操作，按岗位差异配置菜单 |
| `finance` | 财务 | 佣金/对账/报表权限 |

### 4.2 数据权限扩展

yudao-cloud 框架的数据权限通过 `@DataPermission` + `DeptDataPermissionRule` 实现。保险业务需扩展以下数据权限规则：

- **机构维度**：在查询 SQL 中追加 `AND org_id IN (...)` 条件，仅查询当前用户有权限的机构 id 列表（从 Redis 缓存中获取用户的机构权限集合）。
- **数据权限级别**（存入 system_user 的扩展字段 `data_scope`）：
  - `1`：全部（超管）
  - `2`：本机构及下级机构
  - `3`：本部门
  - `4`：仅本人
- 各业务查询接口的 Service 层方法需标注 `@DataPermission`，框架自动注入 WHERE 条件。

### 4.3 菜单初始化脚本

需在项目初始化脚本中预置保险业务的完整菜单树，建议菜单结构如下：

```
系统管理
├── 机构管理
├── 部门管理
├── 岗位管理
├── 角色管理（框架自带）
├── 菜单管理（框架自带）
└── 用户管理（框架自带）

人员管理
├── 业务员管理
├── 内勤管理
└── 资质管理

产品管理
├── 保险公司
├── 产品分类
├── 产品列表
├── 费率维护
└── 产品授权

系统配置
├── 数据字典（框架自带）
├── 参数配置（框架自带）
├── 地区管理（框架自带）
└── 银行管理

日志监控
├── 操作日志（框架自带）
├── 登录日志（框架自带）
├── 接口日志（框架自带）
└── 系统监控（框架自带）
```

---

## 五、接口清单汇总

| 模块 | 方法 | 路径 | 说明 |
|---|---|---|---|
| 机构管理 | GET | `/biz/organization/tree` | 获取机构树 |
| 机构管理 | GET | `/biz/organization/tree/lazy` | 懒加载子节点 |
| 机构管理 | GET | `/biz/organization/{id}` | 获取机构详情 |
| 机构管理 | POST | `/biz/organization` | 新增机构 |
| 机构管理 | PUT | `/biz/organization` | 编辑机构 |
| 机构管理 | DELETE | `/biz/organization/{id}` | 删除机构 |
| 部门管理 | GET | `/biz/department/tree` | 获取部门树（指定 orgId） |
| 部门管理 | GET | `/biz/department/{id}` | 获取部门详情 |
| 部门管理 | POST | `/biz/department` | 新增部门 |
| 部门管理 | PUT | `/biz/department` | 编辑部门 |
| 部门管理 | DELETE | `/biz/department/{id}` | 删除部门 |
| 岗位管理 | GET | `/biz/post/page` | 分页查询岗位 |
| 岗位管理 | GET | `/biz/post/simple-list` | 下拉用简单列表 |
| 岗位管理 | POST | `/biz/post` | 新增岗位 |
| 岗位管理 | PUT | `/biz/post` | 编辑岗位 |
| 岗位管理 | DELETE | `/biz/post/{id}` | 删除岗位 |

---

## 六、通用开发规范说明

- 所有表必须包含：`creator / create_time / updater / update_time / deleted / tenant_id`。
- 所有业务操作使用**逻辑删除**（deleted = 1），禁止物理删除。
- 涉及多表操作的接口必须加 `@Transactional(rollbackFor = Exception.class)`。
- 业务异常统一抛出 `ServiceException`（框架内置），由全局异常处理器返回错误信息。
- 敏感字段（身份证、银行卡号）存储时使用 AES 加密，日志输出时脱敏。
- 所有增删改接口加 `@OperateLog` 注解，自动记录操作日志。
- 树形结构查询优先采用内存构建树方式（单次查询 + 内存递归），避免多次数据库查询。
- Redis 缓存 key 命名规范：`{模块}:{类型}:{标识}`，例如 `org:tree:{tenantId}`，`dept:tree:{orgId}`。

---

## 七、本篇工时估算（1前端 + 1后端）

| 功能点 | 前端(天) | 后端(天) | 合计 |
|---|---|---|---|
| 机构管理（树形列表+缓存） | 1 | 1 | 2 |
| 机构新增 | 0.5 | 1 | 1.5 |
| 机构编辑与停用联动 | 0.5 | 1 | 1.5 |
| 机构删除（多表前置校验） | 0.5 | 0.5 | 1 |
| 部门管理（CRUD） | 1 | 1 | 2 |
| 岗位管理（CRUD） | 0.5 | 0.5 | 1 |
| 角色权限（框架复用+预置角色+data_scope扩展） | 1 | 1 | 2 |
| **合计** | **4.5** | **5** | **9.5** |

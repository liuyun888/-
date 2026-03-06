# PC管理后台 · 客户CRM 业务需求设计文档【中篇】
## 模块：客户续期管理 + 客户工具（云短信）

> **文档版本**：V2.0（已根据操作手册补充细节）
> **对应排期**：阶段2-PC管理后台-客户CRM
> **技术栈**：yudao-cloud（Spring Cloud Alibaba）、MySQL 8.x、Redis、阿里云/腾讯云SMS SDK
> **工时估算**：前端 7天 + 后端 5天
>
> **PDF操作手册对应关系**：
> - `28号` → 客户-续期-目录
> - `29号` → 客户-续期-客户跟进
> - `30号` → 客户-续期-续期看板
> - `31号` → 客户-续期-保单列表
> - `32号` → 客户-工具-目录
> - `33号` → 客户-工具-云短信
> - `41号` → 客户-设置（含短信设置）

---

## 一、续期看板（PC端）
> 📄 **对应操作手册：30号（客户-续期-续期看板）**

### 1.1 页面入口与总体结构

菜单路径：`客户 → 续期 → 续期看板`

页面包含以下区域（操作手册30号）：
- **商户看板**：支持按车辆、保单、保费维度统计商户每年每月的续保情况，点击数字可查看到对应保单数据
- **机构看板**：支持按车辆、保单、保费维度统计机构的续保排名，点击数字可查看到对应保单数据；点击机构名称可查看机构详情
- **续保提醒**：可查看提醒天数范围内，对应的可续保量及已续保量的数据
- **续保跟踪**：根据组织或者业务员、日期（自定义日期或月份）进行筛选
- **续期管理**：列表管理，支持筛选、分配、营销、导出等操作

> ⚠️ **注意**：自定义数据查询范围支持2个自然月内的时间范围查询（操作手册30号）

### 1.2 顶部统计卡片

后端接口 `GET /admin-api/crm/renewal/board/stats` 返回以下数据（实时查询保单到期日期区间）：

| 卡片名称 | 计算逻辑 |
|---|---|
| 30天内到期保单数 | COUNT(保单.expiry_date BETWEEN 今天 AND 今天+30) |
| 30天内到期客户数 | COUNT(DISTINCT 保单.customer_id，同上条件) |
| 60天内到期保单数 | COUNT(保单.expiry_date BETWEEN 今天 AND 今天+60) |
| 60天内到期客户数 | COUNT(DISTINCT 客户，同上) |
| 90天内到期保单数 | COUNT(保单.expiry_date BETWEEN 今天 AND 今天+90) |
| 90天内到期客户数 | COUNT(DISTINCT 客户，同上) |

数据权限：管理员查全机构，业务员只查本人名下。

### 1.3 筛选条件

| 字段 | 组件 | 说明 |
|---|---|---|
| 归属业务员 | 搜索输入+下拉 | 管理员可选择指定业务员 |
| 归属机构 | 树形下拉 | 含子机构 |
| 险种类型 | 多选下拉 | 车险/非车险/寿险 |
| 到期日期范围 | 日期区间选择器 | 默认近90天，最大查询范围2个自然月 |
| 续保状态 | 多选下拉 | 未跟进/跟进中/已成交/已流失 |

### 1.4 日历视图

基于 ECharts 日历热力图实现：
- X轴：月份（按到期日分布），Y轴：每周的天
- 颜色深浅：当天到期保单数量越多颜色越深
- 点击某天：右侧弹出该天到期的保单列表（保单号、客户名、险种、金额）

### 1.5 列表视图（核心功能）

列表按"到期紧急程度"分组标注颜色：
- **红色（< 15天到期）**：紧急，列行背景色红色浅色
- **橙色（15-30天）**：较紧急
- **黄色（30-60天）**：一般

**列表字段**：

| 字段 | 来源 | 说明 |
|---|---|---|
| 保单号 | `ins_policy.policy_no` | 可点击跳转保单详情 |
| 客户姓名 | `ins_customer.name` | 可点击跳转客户详情（查看客户的基本信息、跟进情况、车辆信息、历史信息、客户标签） |
| 险种 | `ins_policy.policy_type` | |
| 保险公司 | `ins_insurance_company.name` | |
| 到期日期 | `ins_policy.expiry_date` | |
| 剩余天数 | 计算字段 | expiry_date - 今天，若<0显示"已到期X天" |
| 归属业务员 | `sys_user.nickname` | |
| 续保状态 | `ins_renewal_task.status` | 未跟进/跟进中/已成交/已流失 |
| 最近跟进时间 | `ins_follow_record.create_time` | 最新一条 |

**操作列**：
- **查看详情**：跳转客户详情页
- **发起报价**：携带车牌号/客户信息跳转至报价模块，URL参数传递 `customerId` 和 `policyId`
- **记录跟进**：弹出跟进记录录入弹窗（参见跟进记录章节）
- **转移给他人**：弹出转移弹窗，选择目标业务员，更新 `ins_renewal_task.agent_id`

### 1.6 批量操作功能
> 📄 **操作手册30号：** "可通过筛选条件，筛选出数据后，对于数据进行分配客户、客户营销、以及导出数据，点击客户姓名可查看客户的具体信息"

**【分配客户】**（操作手册30号）：
- 选择数据，点击分配客户，按照实际情况勾选，点击保存
- 后端加分布式锁（Redis SET NX）防止并发分配冲突，批量更新 `ins_renewal_task.agent_id`
- 批量插入分配轨迹到 `ins_renewal_task_log`

**【客户营销】**（操作手册30号）：
- 可对与筛选出来的客户进行发短信推送信息
- 点击后跳转至云短信发送流程，预填接收对象为已选客户

**【导出】**（操作手册30号特别说明）：
- 点击【导出】按钮，增加下拉导出选项：**导出页面数据** 和 **导出续回保单数据**
- **续回保单**：指去年在系统内出的保单，今年又在系统出单了的（即真正续保成功的）
- 支持导出累计续回保单数据，导出表格内容见附件格式

### 1.7 续保看板按维度统计（操作手册30号）

**【按保单】或【按保费】统计显示数据**（操作手册30号）：
- 商户看板和机构看板均支持在"按车辆"/"按保单"/"按保费"三个维度间切换
- 点击统计数字可查看到对应保单数据的明细列表

---

## 二、续期客户跟进记录（PC端）
> 📄 **对应操作手册：29号（客户-续期-客户跟进）**

### 2.1 页面入口与权限

菜单路径：`客户 → 续期 → 客户跟进`

**权限控制**：
- 普通业务员：只能查看并操作自己的跟进记录
- 内勤/主管及以上：可查看本机构所有业务员的跟进进度，且可代业务员录入跟进记录（需有 `crm:follow:proxy` 权限）

### 2.2 列表展示

**搜索条件**：业务员姓名（模糊）、客户姓名（模糊）、跟进方式、时间范围、续保状态

**列表字段**：保单号、客户姓名、归属业务员、险种、到期日期、最近跟进时间、跟进方式、跟进态度、续保状态、操作

**排序支持**（操作手册29号）：
- 根据续保日期、预约日期和过期未跟进进行升序或降序显示客户

### 2.3 历史保单
> 📄 **操作手册29号：** "展示该车的历史保单"

在续期跟进客户详情中，包含【历史保单】Tab，展示该车辆的历史保单记录，便于业务员了解客户的历史续保情况。

### 2.4 录入跟进记录

点击操作列【记录跟进】或代录时点击【代录跟进】：

弹出跟进记录录入弹窗，字段如下：

| 字段 | 必填 | 说明 |
|---|---|---|
| 跟进方式 | ✅ | 下拉：电话联系/短信/微信/上门拜访/其他 |
| 客户态度 | ✅ | 下拉：积极/中性/消极 |
| 跟进内容 | ✅ | 多行文本，限500字 |
| 下次跟进日期 | 否 | 日期选择器 |
| 是否发送报价单 | 否 | 开关，开启后显示发送报价单按钮 |
| 代录原因 | 代录时必填 | 文本输入，仅主管以上才能看到此字段 |

**后端处理**：
1. 判断当前用户是否是代录（`operator_id != agent_id`），记录 `is_proxy=1`、`proxy_reason=xxx`
2. 校验代录权限（若 `is_proxy=1` 但用户无 `crm:follow:proxy` 权限，返回403）
3. 插入 `ins_follow_record` 表
4. 更新续保任务状态：若当前状态为"未跟进"，自动更新为"跟进中"（`ins_renewal_task.status = 'FOLLOWING'`）
5. 若跟进内容含成交信息（用户手动标记），更新状态为"已成交"

### 2.5 导出跟进记录

点击【导出】按钮：以当前筛选条件查询所有跟进记录（不分页），EasyExcel生成Excel，字段包含：客户姓名、保单号、归属业务员、跟进时间、跟进方式、跟进内容、下次计划、是否代录、操作人。

---

## 三、续期保单列表
> 📄 **对应操作手册：31号（客户-续期-保单列表）**

### 3.1 功能定位

菜单路径：`客户 → 续期 → 保单列表`

此页面专门服务于"续保"场景，展示即将到期或已到期的保单清单，**不是全量保单管理**（全量保单在车险/非车险保单管理模块）。

### 3.2 搜索与列表

**搜索条件**：保单号（精确）、客户姓名（模糊）、险种（多选）、保险公司（多选）、到期日期范围、续保状态（多选）、归属业务员

**列表字段**：

| 字段 | 来源 | 备注 |
|---|---|---|
| 保单号 | `ins_policy.policy_no` | |
| 客户姓名 | `ins_customer.name` | |
| 险种 | `ins_policy.policy_type` | |
| 保险公司 | | |
| 到期日期 | `ins_policy.expiry_date` | |
| 剩余天数 | 计算 | 颜色编码：绿(>30天)/橙(15-30天)/红(<15天)/灰(已到期) |
| 归属业务员 | | |
| 续保状态 | `ins_renewal_task.status` | 未跟进/跟进中/已成交/已流失 |

**操作列**：发起续保报价（跳转报价模块）、查看跟进记录、导出

### 3.3 续保状态与报价模块联动

当业务员在报价模块完成报价并出单后，系统自动更新关联的 `ins_renewal_task.status = 'DEAL'`（已成交），通过以下方式实现：
- 保单出单成功后，触发领域事件 `PolicyCreatedEvent`
- 消费者（CRM模块监听）查找与该保单关联的续期任务（匹配客户ID + 上一年度保单到期日），存在则更新状态为已成交

### 3.4 数据库表设计

```sql
-- 续期任务表
CREATE TABLE ins_renewal_task (
    id              BIGINT      NOT NULL AUTO_INCREMENT,
    tenant_id       BIGINT      NOT NULL,
    policy_id       BIGINT      NOT NULL COMMENT '原保单ID',
    customer_id     BIGINT      NOT NULL COMMENT '客户ID',
    agent_id        BIGINT      NOT NULL COMMENT '归属业务员ID',
    org_id          BIGINT      COMMENT '归属机构ID',
    policy_type     VARCHAR(20) COMMENT '险种类型',
    expiry_date     DATE        NOT NULL COMMENT '到期日期',
    status          VARCHAR(20) DEFAULT 'PENDING' COMMENT '状态：PENDING-未跟进/FOLLOWING-跟进中/DEAL-已成交/LOST-已流失',
    last_follow_time DATETIME   COMMENT '最近跟进时间',
    next_follow_date DATE       COMMENT '下次计划跟进日期',
    del_flag        TINYINT     DEFAULT 0,
    create_time     DATETIME,
    update_time     DATETIME,
    PRIMARY KEY (id),
    INDEX idx_agent_expiry (agent_id, expiry_date),
    INDEX idx_customer_id (customer_id),
    INDEX idx_expiry_date (expiry_date)
) COMMENT = '续期任务表';

-- 续期任务分配轨迹
CREATE TABLE ins_renewal_task_log (
    id              BIGINT      NOT NULL AUTO_INCREMENT,
    task_id         BIGINT      NOT NULL COMMENT '续期任务ID',
    from_agent_id   BIGINT      COMMENT '原业务员ID',
    to_agent_id     BIGINT      NOT NULL COMMENT '目标业务员ID',
    operator_id     BIGINT      NOT NULL COMMENT '操作人ID',
    create_time     DATETIME,
    PRIMARY KEY (id),
    INDEX idx_task_id (task_id)
) COMMENT = '续期任务分配轨迹';
```

---

## 四、云短信（PC端批量发送）
> 📄 **对应操作手册：33号（客户-工具-云短信）、41号（客户-设置-系统设置）**

### 4.1 功能概览

菜单路径：`客户 → 工具 → 云短信`

页面包含两个Tab：**模板管理** 和 **短信任务**

### 4.2 模板管理
> 📄 **操作手册33号（模板管理）：** "新增短信模板，新增后可以编辑/删除"

#### 4.2.1 查看与权限（操作手册33号）
- **客服专员**：只能看到自己创建的短信模板
- **客服经理和主管**：可以看到当前组织下的所有短信模板

#### 4.2.2 新增短信模板

点击【新增模板】，弹出新增弹窗：

| 字段 | 必填 | 说明 |
|---|---|---|
| 模板名称 | ✅ | 限50字 |
| 短信内容 | ✅ | 限350字，支持变量插入（如 `{客户姓名}`、`{车牌号}`） |
| 模板类型 | ✅ | 营销类/服务类/通知类 |

**后端处理**：
- 插入 `ins_sms_template` 表，`create_by` = 当前用户ID，`org_id` = 当前用户所属机构ID
- 营销类模板若开启了"退订设置"（`ins_sms_setting.append_unsubscribe=1`），保存时自动在内容末尾追加"回T退订"

#### 4.2.3 编辑/删除模板
- 点击【编辑】：弹出编辑弹窗（同新增），修改后更新 `ins_sms_template`
- 点击【删除】：弹出二次确认，逻辑删除（若有正在进行的任务引用该模板，提示不允许删除）

### 4.3 短信任务
> 📄 **操作手册33号（短信任务）：** 详细描述了权限控制和发送规则

#### 4.3.1 权限说明（操作手册33号重要规则）

| 角色 | 任务可见范围 | 模板可见范围 | 客户可见范围 |
|---|---|---|---|
| 客服专员 | 只能看到自己创建的短信任务 | 只能看到自己创建的短信模板 | 只能看到自己的客户 |
| 客服经理/主管 | 可以看到当前组织下的所有短信任务 | 可以看到当前组织下的所有短信模板 | 可以看到当前组织以及授权组织下的所有客户 |

#### 4.3.2 短信计费规则（操作手册33号）

> 📄 **操作手册33号：** "已送达/客户总数：已成功发送的客户/总共发送的客户，70个字符为一条短信，超过70按67/条计算短信条数"

- 70个字符以内：按1条短信计费
- 超过70字符：按每67字符一条短信计费（超长短信拆分发送）
- 页面实时显示：当前字符数、预计发送条数、预计消耗短信数量

#### 4.3.3 发送频率限制（操作手册33号）

> 📄 **操作手册33号：** "不管是单条发送还是任务发送，系统设置，每个客户每周只能发送最多3条短信，每月最多10条短信（可以在系统设置的范围内，每个商户可以向下调整发送短信的频次）"

- **默认限制**：每个客户每周最多发送3条短信，每月最多10条短信
- **商户调整**：可在系统设置中，在全局上限范围内向下调整本商户的频次限制
- **实现方式**：Redis 计数器 + TTL 控制

#### 4.3.4 新建短信任务

点击【新建任务】，按以下步骤操作：

**步骤1：选择模板**
- 显示模板列表（按权限过滤），选择一个模板
- 右侧实时预览短信内容，底部显示"当前字符：XX，约发X条短信（70字/条，超70按67字/条计算）"

**步骤2：选择接收对象**（以下方式四选一或组合）：
- **按标签选择**：选择客户标签（多选），系统自动查询该标签下的客户
- **按分组选择**：选择客户分组（多选）
- **手动输入手机号**：文本框中粘贴手机号，每行一个或逗号分隔
- **导入Excel手机号**：上传xlsx，仅读取第一列手机号

**步骤3：预览发送内容**
- 展示：接收人数、短信内容、预计消耗短信条数、短信余量
- **黑名单过滤提示**：系统自动过滤退订客户（`ins_sms_blacklist`），并提示"已过滤X个退订用户"
- **发送频率检查提示**：检查是否有客户"7天内已收到≥3条短信"，若有提示"X个客户因超出频率限制被过滤"

**步骤4：设置发送时间**
- 发送方式：立即发送 / 定时发送（选择日期时间，需在当前时间5分钟后）
- 点击【确认发送】提交任务

**后端处理（创建任务）**：
1. 插入 `ins_sms_task` 表，状态为 `PENDING`（待发送）或 `SCHEDULED`（定时）
2. 解析接收对象，查询手机号列表，批量查询黑名单过滤，批量查询频率过滤（Redis `sms:count:{phone}:{week}` 计数）
3. 生成发送明细，批量插入 `ins_sms_task_detail` 表（每条记录含手机号、客户ID、发送状态）
4. 若立即发送：推送到短信发送队列（RocketMQ），消费者调用阿里云/腾讯云SMS API发送
5. 若定时发送：Xxl-Job 定时任务在指定时间触发发送

#### 4.3.5 发送频率Redis限制实现

```
Key: sms:send:count:{phone_suffix}:{week}   (按手机后4位+当前年周)
Type: STRING (计数器)
TTL: 7天
操作：发送前 INCR，发送成功后不回滚，超过3则拒绝
```

同时维护月度计数：
```
Key: sms:send:count:{phone_suffix}:{year_month}
TTL: 31天
操作：INCR，超过10则拒绝
```

> 注意：系统配置表 `ins_sms_setting` 中可配置上限，优先读配置表值（对应操作手册41号中的"单用户短信发送数量设置"）。

#### 4.3.6 短信任务列表

**列表字段**：任务名称、模板名称、发送人数、已送达数、失败数、创建时间、发送时间、状态（待发送/发送中/已完成/失败）、操作（查看明细/撤销）

**撤销任务**：仅状态为"待发送"的定时任务可撤销，点击撤销后更新状态为 `CANCELLED`

#### 4.3.7 查看发送明细

点击【查看明细】：弹出明细列表，字段：手机号（脱敏）、客户姓名、发送状态（成功/失败/退订）、发送时间、运营商回执码

### 4.4 短信余量

页面右上角固定展示"剩余短信：XXX条"（调用短信服务商API查询），点击可跳转到购买页面（配置购买链接即可）。

### 4.5 短信退订设置（操作手册41号）

> 📄 **操作手册41号：** "短信退订设置：打开本开关后，在发送短信时结尾自动加上退订回T字段，可有效提升发送率；点编辑可以选择在编辑模板时生效还是给个人发送时生效"

退订处理逻辑：
- 用户回复"T"后，运营商回调接口触发退订处理
- 将该手机号写入 `ins_sms_blacklist` 表，`reason = 'UNSUB'`
- 后续发送时自动跳过该号码

### 4.6 数据库表设计

```sql
-- 短信模板表
CREATE TABLE ins_sms_template (
    id          BIGINT      NOT NULL AUTO_INCREMENT,
    tenant_id   BIGINT      NOT NULL,
    org_id      BIGINT      NOT NULL COMMENT '归属机构',
    name        VARCHAR(50) NOT NULL COMMENT '模板名称',
    content     VARCHAR(500) NOT NULL COMMENT '短信内容',
    type        VARCHAR(20) COMMENT '类型：MARKETING/SERVICE/NOTIFY',
    del_flag    TINYINT     DEFAULT 0,
    create_by   BIGINT,
    create_time DATETIME,
    update_time DATETIME,
    PRIMARY KEY (id)
) COMMENT = '短信模板';

-- 短信任务表
CREATE TABLE ins_sms_task (
    id              BIGINT      NOT NULL AUTO_INCREMENT,
    tenant_id       BIGINT      NOT NULL,
    task_name       VARCHAR(100) COMMENT '任务名称',
    template_id     BIGINT      NOT NULL COMMENT '短信模板ID',
    total_count     INT         DEFAULT 0 COMMENT '总发送人数',
    success_count   INT         DEFAULT 0 COMMENT '成功数',
    fail_count      INT         DEFAULT 0 COMMENT '失败数',
    filter_count    INT         DEFAULT 0 COMMENT '过滤数（黑名单+频率）',
    send_type       VARCHAR(20) COMMENT '发送类型：IMMEDIATE/SCHEDULED',
    scheduled_time  DATETIME    COMMENT '定时发送时间',
    send_time       DATETIME    COMMENT '实际发送开始时间',
    status          VARCHAR(20) DEFAULT 'PENDING' COMMENT 'PENDING/RUNNING/DONE/FAILED/CANCELLED',
    del_flag        TINYINT     DEFAULT 0,
    create_by       BIGINT      COMMENT '创建人',
    org_id          BIGINT,
    create_time     DATETIME,
    update_time     DATETIME,
    PRIMARY KEY (id),
    INDEX idx_tenant_status (tenant_id, status)
) COMMENT = '短信任务';

-- 短信发送明细表
CREATE TABLE ins_sms_task_detail (
    id              BIGINT      NOT NULL AUTO_INCREMENT,
    task_id         BIGINT      NOT NULL COMMENT '任务ID',
    customer_id     BIGINT      COMMENT '客户ID',
    phone_no        VARCHAR(255) NOT NULL COMMENT '手机号（加密）',
    phone_suffix    VARCHAR(4)  COMMENT '手机后4位',
    actual_content  VARCHAR(500) COMMENT '实际发送内容（变量替换后）',
    status          VARCHAR(20) DEFAULT 'PENDING' COMMENT 'PENDING/SUCCESS/FAILED/UNSUB',
    send_time       DATETIME,
    carrier_code    VARCHAR(50) COMMENT '运营商回执码',
    PRIMARY KEY (id),
    INDEX idx_task_id (task_id),
    INDEX idx_phone_suffix (phone_suffix)
) COMMENT = '短信发送明细';

-- 短信黑名单
CREATE TABLE ins_sms_blacklist (
    id          BIGINT      NOT NULL AUTO_INCREMENT,
    tenant_id   BIGINT      NOT NULL,
    phone_no    VARCHAR(255) NOT NULL COMMENT '手机号（加密）',
    phone_suffix VARCHAR(4),
    reason      VARCHAR(100) COMMENT '加入原因：UNSUB-退订 COMPLAINT-投诉',
    create_time DATETIME,
    PRIMARY KEY (id),
    UNIQUE KEY uk_phone (tenant_id, phone_no)
) COMMENT = '短信黑名单';

-- 短信系统设置表
CREATE TABLE ins_sms_setting (
    id                      BIGINT      NOT NULL AUTO_INCREMENT,
    tenant_id               BIGINT      NOT NULL,
    weekly_limit            INT         DEFAULT 3  COMMENT '每周发送上限（条）',
    monthly_limit           INT         DEFAULT 10 COMMENT '每月发送上限（条）',
    append_unsubscribe      TINYINT     DEFAULT 0  COMMENT '是否追加退订语：0否 1是',
    unsubscribe_trigger     VARCHAR(20) DEFAULT 'TASK' COMMENT '退订追加时机：TEMPLATE-编辑模板时/TASK-发送时',
    enable_resource_type    TINYINT     DEFAULT 0  COMMENT '是否启用资源类型',
    update_time             DATETIME,
    PRIMARY KEY (id),
    UNIQUE KEY uk_tenant (tenant_id)
) COMMENT = '短信系统设置';
```

---

## 五、API接口清单（续期管理 + 云短信）

### 续期管理接口

| 接口 | 方法 | 路径 | 说明 | 对应PDF |
|---|---|---|---|---|
| 续期看板统计 | GET | `/admin-api/crm/renewal/board/stats` | 30/60/90天统计 | 30号 |
| 商户看板数据 | GET | `/admin-api/crm/renewal/board/merchant` | 按年月/维度统计 | 30号 |
| 机构看板数据 | GET | `/admin-api/crm/renewal/board/org-rank` | 机构续保排名 | 30号 |
| 续保提醒数据 | GET | `/admin-api/crm/renewal/board/remind` | 可续保量/已续保量 | 30号 |
| 续保跟踪数据 | GET | `/admin-api/crm/renewal/board/track` | 按组织/业务员/日期 | 30号 |
| 续期保单列表 | GET | `/admin-api/crm/renewal/policy/page` | 分页 | 31号 |
| 批量分配任务 | POST | `/admin-api/crm/renewal/task/batch-assign` | 加分布式锁 | 30号 |
| 跟进记录列表 | GET | `/admin-api/crm/follow/page` | 分页 | 29号 |
| 新增跟进记录 | POST | `/admin-api/crm/follow/create` | 支持代录 | 29号 |
| 导出跟进记录 | GET | `/admin-api/crm/follow/export` | EasyExcel | 29号 |
| 导出续回保单 | GET | `/admin-api/crm/renewal/policy/export-renewed` | 导出真实续回保单 | 30号 |

### 云短信接口

| 接口 | 方法 | 路径 | 说明 | 对应PDF |
|---|---|---|---|---|
| 模板列表 | GET | `/admin-api/crm/sms/template/list` | 按权限过滤 | 33号 |
| 新增模板 | POST | `/admin-api/crm/sms/template/create` | | 33号 |
| 编辑模板 | PUT | `/admin-api/crm/sms/template/update` | | 33号 |
| 删除模板 | DELETE | `/admin-api/crm/sms/template/delete` | | 33号 |
| 创建发送任务 | POST | `/admin-api/crm/sms/task/create` | | 33号 |
| 任务列表 | GET | `/admin-api/crm/sms/task/page` | | 33号 |
| 任务明细 | GET | `/admin-api/crm/sms/task/detail?taskId=` | | 33号 |
| 撤销任务 | POST | `/admin-api/crm/sms/task/cancel` | 仅PENDING可撤销 | 33号 |
| 短信余量查询 | GET | `/admin-api/crm/sms/balance` | 调用短信服务商API | 33号 |
| 短信设置查询 | GET | `/admin-api/crm/sms/setting/get` | | 41号 |
| 短信设置更新 | PUT | `/admin-api/crm/sms/setting/update` | | 41号 |
| 退订回调 | POST | `/admin-api/crm/sms/unsubscribe/callback` | 运营商回调写黑名单 | 33号 |

---

> **下一篇**：客户CRM业务需求设计-下篇-客户数据分析

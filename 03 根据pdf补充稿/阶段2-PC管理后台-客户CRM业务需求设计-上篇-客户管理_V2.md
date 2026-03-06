# PC管理后台 · 客户CRM 业务需求设计文档【上篇】
## 模块：客户管理（PC客户管理）

> **文档版本**：V2.0（已根据操作手册补充细节）
> **对应排期**：阶段2-PC管理后台-客户CRM
> **技术栈**：yudao-cloud（Spring Cloud Alibaba）、MySQL 8.x、EasyExcel、Redis
> **工时估算**：前端 6天 + 后端 5天
>
> **PDF操作手册对应关系**：
> - `24号` → 客户-客户-导入客户
> - `25号` → 客户-客户-全部客户
> - `26号` → 客户-客户-我的客户
> - `27号` → 客户-客户-客户画像

---

## 一、全部客户列表
> 📄 **对应操作手册：25号（客户-客户-全部客户）**

### 1.1 页面入口与布局

菜单路径：`客户 → 客户 → 全部客户`

页面分为两个区域：
- **顶部搜索区**：多条件筛选表单 + 查询/重置按钮
- **底部列表区**：分页表格 + 操作列 + 顶部工具栏（新增、导入、导出、自定义表头）

### 1.2 搜索条件

| 搜索字段 | 组件类型 | 说明 |
|---|---|---|
| 客户姓名 | 文本输入 | 模糊匹配，LIKE '%xxx%' |
| 手机号后4位 | 文本输入 | 匹配 phone_no LIKE '%xxxx' |
| 证件号后4位 | 文本输入 | 匹配 id_card LIKE '%xxxx' |
| 标签 | 多选下拉 | 关联 ins_customer_tag 表，IN 查询 |
| 客户状态 | 单选下拉 | 未接触 / 已接触 / 已成交 / 已流失 |
| 归属机构 | 树形下拉 | 级联选择机构，查询该机构及所有子机构下的客户 |
| 归属业务员 | 搜索输入 | 输入姓名模糊匹配业务员 |

**筛选场景功能**（操作手册25号描述）：
- 点击【筛选】→【添加筛选条件】可多选字段组合，填完条件后点击【保存为筛选场景】，后续可直接点击场景名快速召回该组合条件
- 场景数据存入 `ins_customer_search_scene` 表，关联当前用户 ID
- 支持自定义表头设置：点击右上角【小齿轮】图标，按需勾选字段并排序，点击确定后保存列配置

### 1.3 列表列定义

| 列名 | 字段来源 | 说明 |
|---|---|---|
| 客户ID | `ins_customer.id` | 系统自增ID |
| 姓名 | `ins_customer.name` | 明文展示，可点击跳转客户详情 |
| 手机号 | `ins_customer.phone_no` | 展示脱敏格式：138\*\*\*\*8888 |
| 证件号 | `ins_customer.id_card` | 展示脱敏：3202\*\*\*\*\*\*\*\*1234 |
| 归属业务员 | `sys_user.nickname` | 关联 agent_id → sys_user |
| 归属机构 | `ins_org.name` | 关联 org_id → ins_org |
| 首次投保日期 | `ins_customer.first_insure_date` | 取该客户保单最早签单日期（JOIN 保单表聚合）|
| 累计保费 | 聚合计算 | SUM(保单.total_premium) |
| 客户等级 | `ins_customer.level` | 枚举：普通/银牌/金牌/钻石 |
| 最近跟进时间 | `ins_follow_record.create_time` | 取最新一条跟进记录时间 |
| 操作 | - | 查看详情、编辑、删除、打标签 |

**排序支持**：点击列头"客户等级"和"首次投保日期"可切换升降序，对应 ORDER BY 动态拼接。

**自定义表头**：点击右上角小齿轮图标，弹出字段勾选面板，可拖拽排序，点击确定后前端本地化存储列配置，刷新后保持。

### 1.4 新增客户
> 📄 **操作手册25号：** "点击【新增客户】填写姓名、车牌号、车架号等相关信息，填写完成后点击空白处即可添加成功，添加成功后在全部客户列表显示"

点击【新增客户】按钮，弹出侧边抽屉（宽720px），填写以下信息：

**必填字段**：姓名、手机号
**选填字段**：备用电话1、备用电话2、证件类型+证件号、性别、出生日期、客户来源（下拉）、归属保险公司（多选）、地址（省市区）、标签（多选）、内部代码、备注、车牌号、车架号（车险客户）

**后端校验**：
1. 手机号格式校验（11位，1开头）
2. 手机号在当前商户下唯一性检查：`SELECT id FROM ins_customer WHERE phone_no=? AND tenant_id=?`，存在则提示"该手机号已存在，请勿重复添加"
3. 证件号格式校验（身份证18位）

**入库操作**：
- 插入 `ins_customer` 表，`create_by` = 当前登录用户ID，`agent_id` = 创建人（若创建人是业务员身份则自动归属）
- `status` 默认为 `UNTOUCHED`（未接触）
- 成功后列表刷新，不跳转页面

### 1.5 批量操作功能
> 📄 **操作手册25号：** "可对客户信息操作分配客户、回收客户等操作"

勾选一条或多条客户记录后，工具栏显示批量操作按钮：

**【批量报价】**（操作手册25号）
- 选择数据，点击批量报价，按照实际情况选择投保地区、投保公司等，选择后点击确定
- 系统创建批量报价任务，点击【任务列表】可查看批量报价和导出的具体明细
- 后端异步执行，任务完成后站内信通知

**【添加到分组】**（操作手册25号）
- 选择数据，点击添加到分组，勾选分组后点击确定
- 批量关联 `ins_customer_group_rel` 表

**【分配客户】**（操作手册25号）
- 选择数据，点击分配客户，按照实际情况勾选目标业务员，点击保存
- 批量更新 `ins_customer.agent_id`，插入分配轨迹

**【变更组织】**（操作手册25号）
- 选择数据，点击变更组织，选择变更的组织后点击确定
- 批量更新 `ins_customer.org_id`

**【回收客户】**（操作手册25号）
- 选择数据，点击回收客户，点击确定
- 已经分配的人员回收成功，回收后可在进行再次分配客户
- 后端：将 `agent_id` 置空，状态回退为 UNTOUCHED，插入回收记录

**【打标签】**
- 选中一条或多条记录，点击工具栏【打标签】按钮
- 弹出标签选择弹窗（树形多选），标签数据来自 `ins_tag` 表
- 点击确定：批量执行 `INSERT INTO ins_customer_tag_rel (customer_id, tag_id)` ON DUPLICATE KEY IGNORE

**【删除】**
- 弹出二次确认弹窗"确定删除选中的X条客户信息吗？删除后不可恢复"
- 点击确定执行逻辑删除（`del_flag=1`），列表刷新

### 1.6 任务列表（批量报价专用）
> 📄 **操作手册25号：** "点击【任务列表】可以查询批量报价和导出的具体明细"

点击右上角【任务列表】按钮，弹出任务列表面板：

| 列名 | 说明 |
|---|---|
| 任务编号 | 系统自动生成 |
| 任务类型 | 批量报价 / 批量导出 |
| 创建时间 | 任务发起时间 |
| 执行状态 | 等待中 / 进行中 / 已完成 / 失败 |
| 成功/失败数 | X 成功 / Y 失败 |
| 操作 | 查看详情 / 下载结果 |

### 1.7 查看客户详情

点击客户姓名超链接，跳转至客户详情页（新Tab），详情页含以下Tab：
- **客户信息**：基本信息表单（可编辑）
- **跟进记录**：时间轴形式展示，PC端查看全量记录
- **历史报价**：关联该客户的全部报价单列表
- **历史保单**：关联该客户的全部保单列表
- **客户画像**：（详见第三节）

### 1.8 导出Excel

点击【导出】按钮，弹出导出配置弹窗，用户可选择导出字段（默认全选），确认后：
1. 后端以当前搜索条件查询，最大10000条（超过提示"数据量超过10000条，请缩小筛选范围"）
2. 手机号、证件号导出时**保持脱敏**格式（不允许导出明文）
3. 使用 EasyExcel 异步生成，生成完毕后通过站内信通知下载链接

---

## 二、我的客户（业务员归属视图）
> 📄 **对应操作手册：26号（客户-客户-我的客户）**

### 2.1 页面入口与权限

菜单路径：`客户 → 客户 → 我的客户`

**适用场景**（操作手册26号）：可以查看隶属为本人的全部数据

**数据权限逻辑**：
- 普通业务员：只能看 `agent_id = 当前用户ID` 的客户
- 内勤/管理员：页面顶部显示【业务员切换下拉框】，可选择指定业务员查看其客户，不选则查看全机构客户（按数据权限范围）
- 权限判断入口：后端 `@DataPermission` 注解 + 自定义数据权限处理器

### 2.2 搜索条件
> 📄 **操作手册26号：** "可根据姓名、手机号等信息点放大镜筛选；可直接点击【筛选】可添加筛选条件进行查询；可新建筛选场景筛选，点击【筛选】-【添加筛选条件】选择所需条件并勾选，点击保存为筛选场景"

| 搜索字段 | 说明 |
|---|---|
| 客户姓名 | 模糊匹配 |
| 手机号 | 后4位匹配 |
| 标签 | 多选 |
| 客户状态 | 单选 |
| 归属业务员（管理员可见） | 切换查看其他业务员 |

**筛选场景**：同全部客户，可保存为筛选场景复用。

### 2.3 页面特有功能

**自定义表头设置**（操作手册26号）：
- 支持自定义表头设置，点击【小齿轮】按照需要展示的字段进行勾选、排序

**超期未跟进红色标注**：
- 规则：最近跟进时间距今超过7天（可在客户设置中配置阈值）
- 实现：列表查询时 JOIN `ins_follow_record` 取最新跟进时间，计算天数差，前端对该行设置红色背景样式

**距下次跟进倒计时列**：
- 字段：`ins_follow_record.next_follow_date`（最新跟进记录中的"下次计划跟进日期"）
- 展示：计算距今天数，如"距到期 3天"（绿色），若已过期则显示"已超期 X天"（红色）

**打标签**：
- 选中一条或多条记录，点击工具栏【打标签】按钮
- 弹出标签选择弹窗（树形多选），标签数据来自 `ins_tag` 表
- 点击确定：批量执行 `INSERT INTO ins_customer_tag_rel (customer_id, tag_id)` ON DUPLICATE KEY IGNORE

### 2.4 批量操作功能
> 📄 **操作手册26号：** "点击【客户】—【我的客户】勾选客户信息，点击【批量报价】选择投保城市和报价工号，点击【确定】，点击任务列表可查看报价详情"

**【批量报价】**（操作手册26号特别说明）：
- 点击【客户】—【我的客户】勾选客户信息，点击【批量报价】
- 选择投保城市和报价工号，点击【确定】
- 点击任务列表可查看报价详情

**【添加到分组】**：
- 可对查询的客户数据进行分组，点击添加到分组，勾选后点击确定（操作手册27号）

**【分配客户】**（操作手册27号）：
- 可对查询的客户数据进行分配，点击分配客户，按照实际情况勾选，点击保存

### 2.5 批量移交客户

选中一条或多条客户，点击【移交客户】按钮（需权限：`crm:customer:transfer`）：
1. 弹出移交弹窗，搜索选择目标业务员（必填），填写移交原因（选填）
2. 点击确认：
   - 校验当前用户是否有权操作（只能移交自己名下或本机构下的客户）
   - 批量更新 `ins_customer.agent_id = 目标业务员ID`
   - 插入移交轨迹记录到 `ins_customer_transfer_log` 表（包含：原业务员、新业务员、移交原因、操作时间、操作人）
   - 事务提交，失败回滚
3. 成功后刷新列表，被移交的客户从当前视图消失

---

## 三、客户画像展示
> 📄 **对应操作手册：27号（客户-客户-客户画像）**

### 3.1 客户画像独立菜单入口
> 📄 **操作手册27号：** "点击【客户】-【客户画像】-【查询】；给客户打标签，便于后期精准营销"

菜单路径1（独立入口）：`客户 → 客户 → 客户画像`
菜单路径2（详情内嵌）：客户详情页 → 客户画像Tab

**客户画像独立列表页**：
- 提供搜索查询功能，查询方式同全部客户
- 列表展示客户基本信息+画像标签摘要
- 支持自定义表头设置，点击【小齿轮】按照需要展示的字段进行勾选排序

### 3.2 画像Tab内容（客户详情页内嵌）

客户详情页新增"客户画像"Tab（在原有客户信息/跟进记录/历史报价/历史保单的基础上追加）

#### 3.2.1 保险偏好（险种分布饼图）
- 数据来源：统计该客户名下所有保单，按 `policy_type`（险种类型）分组计算件数与保费
- ECharts 饼图展示：各险种占比，鼠标悬停显示具体数值
- 后端接口：`GET /admin-api/crm/customer/{id}/portrait/insurance-preference`，返回 `[{type:"车险",count:5,premium:12000},...]`

#### 3.2.2 消费能力（近12个月保费柱状图）
- 数据来源：统计该客户近12个自然月的签单保费（`policy.sign_date`）
- ECharts 柱状图，X轴为月份（2024-03 ~ 2025-02），Y轴为保费金额（元）
- 后端接口：`GET /admin-api/crm/customer/{id}/portrait/premium-trend`

#### 3.2.3 跟进活跃度评分
- 评分规则（可配置，默认如下）：
  - 近30天有跟进记录：+30分
  - 近30天有报价记录：+20分
  - 近30天有成交保单：+50分
  - 超过30天无任何跟进：-20分
- 展示：ECharts 仪表盘（0~100分），配分段颜色（0-40红/40-70橙/70-100绿）
- 评分实时计算，不缓存（数据量小，实时聚合）

#### 3.2.4 推荐险种标签
- 规则：基于已购险种推断缺口险种，例如：已买车险未买驾乘意外险 → 推荐驾乘意外险
- 实现：`ins_product_recommend_rule` 表存储规则配置（IF 已有险种A THEN 推荐险种B）
- 展示：横排标签组件，点击标签可跳转到对应产品报价页

### 3.3 批量操作客户（客户画像入口）
> 📄 **操作手册27号：** "可对客户信息操作分配客户、导出等操作"

**【添加到分组】**：可对查询的客户数据进行分组，点击添加到分组，勾选后点击确定

**【分配客户】**：可对查询的客户数据进行分配，点击分配客户，按照实际情况勾选，点击保存

### 3.4 客户基本信息增强

在"客户信息"Tab中，在原有基本信息下方增加：
- **家庭成员**：展示 `ins_customer_family` 关联表中的成员列表，可新增/编辑/删除家庭成员（姓名、关系、手机号、证件号、出生日期）
- **跟进记录时间轴**（PC端）：加载该客户全量跟进记录（`ins_follow_record`），App端只查最近10条（接口参数 `page_size=10` 控制）

---

## 四、客户批量导入（Excel）
> 📄 **对应操作手册：24号（客户-客户-导入客户）**

### 4.1 下载导入模板

点击【导入客户】→【下载模板】按钮：
- 后端提供固定模板文件（存于OSS或classpath），返回文件流
- 模板包含：说明行（第1行为红字说明）、表头行（第2行），带 `*` 号标注必填列
- 必填列：`*姓名`、`*手机号`
- 选填列：证件类型、证件号、性别、出生日期、归属业务员工号、标签（多个用逗号分隔）、备注

### 4.2 上传与预解析

点击【导入】→【选择文件】，选择 `.xlsx` 文件（限制：仅 xlsx 格式，文件大小 < 10MB）：
1. 前端上传文件到后端接口 `POST /admin-api/crm/customer/import/preview`
2. 后端使用 EasyExcel 读取前20行（`headRowNumber=2` 跳过说明+表头），执行以下校验：
   - 姓名不为空
   - 手机号格式校验（正则：`^1[3-9]\d{9}$`）
   - 证件号格式校验（若填写）
   - 重复手机号检测（在当前上传文件内检测重复）
3. 返回预解析结果给前端展示：展示前20行数据表格，每行右侧显示校验状态（✅ 正常 / ❌ 错误原因）
4. 若预解析发现必填字段缺失等严重错误，用红色提示并禁用确认按钮

### 4.3 确认批量导入

点击【确认导入】：
1. 后端异步执行完整文件解析（EasyExcel 流式读取，每500条一批处理）
2. **去重合并策略**（以手机号为唯一键）：
   - 手机号在系统中不存在 → **新建**：INSERT 新客户记录
   - 手机号在系统中已存在 → **更新**：只更新导入文件中非空的字段（空字段不覆盖已有数据）
3. 手机号、证件号存储前执行加密（AES加密，密文存库，查询时解密比较）
4. 批量处理完毕后，发送站内信通知（`ins_notice` 表）：
   > "导入完成：成功新建 N 条，更新 M 条，失败 X 条。[点击下载失败数据]"
5. 失败数据（格式错误/逻辑错误行）生成失败Excel文件存OSS，提供下载链接，有效期24小时

### 4.4 管理导入批次
> 📄 **操作手册24号：** "点击【删除】可删除已上传的客户批次；点击【分配】按钮，可分配该批次的客户"

导入批次管理功能：
- **删除批次**：点击【删除】可删除已上传的客户批次（逻辑删除批次记录，不删除已导入的客户数据）
- **分配批次客户**：点击【分配】按钮，可将该批次的客户统一分配给指定业务员

**后端表设计**：`ins_customer_import_batch` 表记录每次导入批次信息（导入人、导入时间、成功数、失败数、文件路径）

### 4.5 数据库表设计

```sql
-- 客户主表
CREATE TABLE ins_customer (
    id           BIGINT      NOT NULL AUTO_INCREMENT COMMENT '客户ID',
    tenant_id    BIGINT      NOT NULL COMMENT '租户ID',
    name         VARCHAR(50) NOT NULL COMMENT '客户姓名',
    phone_no     VARCHAR(255) NOT NULL COMMENT '手机号（AES加密存储）',
    phone_suffix VARCHAR(4)  COMMENT '手机后4位（明文，用于搜索）',
    id_card      VARCHAR(255) COMMENT '证件号（AES加密存储）',
    id_card_suffix VARCHAR(4) COMMENT '证件后4位（明文）',
    id_card_type TINYINT     COMMENT '证件类型：1-身份证 2-护照 3-港澳台',
    gender       TINYINT     COMMENT '性别：1-男 2-女',
    birthday     DATE        COMMENT '出生日期',
    agent_id     BIGINT      COMMENT '归属业务员ID（关联sys_user）',
    org_id       BIGINT      COMMENT '归属机构ID（关联ins_org）',
    level        TINYINT     DEFAULT 1 COMMENT '客户等级：1普通 2银牌 3金牌 4钻石',
    status       VARCHAR(20) DEFAULT 'UNTOUCHED' COMMENT '状态：UNTOUCHED/CONTACTED/DEAL/LOST',
    source       VARCHAR(50) COMMENT '客户来源',
    address      VARCHAR(200) COMMENT '地址',
    first_insure_date DATE    COMMENT '首次投保日期',
    remark       VARCHAR(500) COMMENT '备注',
    del_flag     TINYINT     DEFAULT 0 COMMENT '删除标志：0-正常 1-删除',
    create_by    BIGINT      COMMENT '创建人',
    create_time  DATETIME    COMMENT '创建时间',
    update_by    BIGINT      COMMENT '更新人',
    update_time  DATETIME    COMMENT '更新时间',
    PRIMARY KEY (id),
    INDEX idx_phone_suffix (phone_suffix),
    INDEX idx_agent_id (agent_id),
    INDEX idx_org_id (org_id),
    INDEX idx_tenant (tenant_id, del_flag)
) COMMENT = 'CRM客户表';

-- 客户移交轨迹表
CREATE TABLE ins_customer_transfer_log (
    id              BIGINT   NOT NULL AUTO_INCREMENT,
    customer_id     BIGINT   NOT NULL COMMENT '客户ID',
    from_agent_id   BIGINT   COMMENT '原业务员ID',
    to_agent_id     BIGINT   NOT NULL COMMENT '目标业务员ID',
    reason          VARCHAR(200) COMMENT '移交原因',
    operator_id     BIGINT   NOT NULL COMMENT '操作人ID',
    create_time     DATETIME COMMENT '操作时间',
    PRIMARY KEY (id),
    INDEX idx_customer_id (customer_id)
) COMMENT = '客户移交轨迹';

-- 跟进记录表
CREATE TABLE ins_follow_record (
    id              BIGINT      NOT NULL AUTO_INCREMENT,
    customer_id     BIGINT      NOT NULL COMMENT '客户ID',
    agent_id        BIGINT      NOT NULL COMMENT '跟进业务员ID',
    operator_id     BIGINT      COMMENT '实际操作人ID（代录时与agent_id不同）',
    is_proxy        TINYINT     DEFAULT 0 COMMENT '是否代录：0否 1是',
    proxy_reason    VARCHAR(200) COMMENT '代录原因',
    follow_type     VARCHAR(20) COMMENT '跟进方式：CALL/SMS/WECHAT/VISIT/OTHER',
    attitude        VARCHAR(20) COMMENT '客户态度：POSITIVE/NEUTRAL/NEGATIVE',
    content         VARCHAR(1000) COMMENT '跟进内容备注',
    next_follow_date DATE        COMMENT '下次计划跟进日期',
    is_send_quote   TINYINT     DEFAULT 0 COMMENT '是否发送报价单',
    create_time     DATETIME,
    PRIMARY KEY (id),
    INDEX idx_customer_id (customer_id),
    INDEX idx_agent_id (agent_id)
) COMMENT = '客户跟进记录';

-- 客户导入批次记录表
CREATE TABLE ins_customer_import_batch (
    id              BIGINT      NOT NULL AUTO_INCREMENT,
    tenant_id       BIGINT      NOT NULL,
    batch_no        VARCHAR(50) NOT NULL COMMENT '批次编号',
    file_name       VARCHAR(200) COMMENT '原始文件名',
    file_url        VARCHAR(500) COMMENT '文件OSS路径',
    total_count     INT         DEFAULT 0 COMMENT '总行数',
    success_count   INT         DEFAULT 0 COMMENT '新建成功数',
    update_count    INT         DEFAULT 0 COMMENT '更新成功数',
    fail_count      INT         DEFAULT 0 COMMENT '失败数',
    fail_file_url   VARCHAR(500) COMMENT '失败数据文件URL',
    status          VARCHAR(20) DEFAULT 'PENDING' COMMENT 'PENDING/PROCESSING/DONE/FAILED',
    operator_id     BIGINT      NOT NULL COMMENT '操作人',
    del_flag        TINYINT     DEFAULT 0,
    create_time     DATETIME,
    update_time     DATETIME,
    PRIMARY KEY (id),
    INDEX idx_tenant_status (tenant_id, status)
) COMMENT = '客户导入批次记录';

-- 筛选场景表
CREATE TABLE ins_customer_search_scene (
    id          BIGINT      NOT NULL AUTO_INCREMENT,
    tenant_id   BIGINT      NOT NULL,
    user_id     BIGINT      NOT NULL COMMENT '创建用户ID',
    scene_name  VARCHAR(50) NOT NULL COMMENT '场景名称',
    conditions  TEXT        COMMENT '筛选条件JSON',
    create_time DATETIME,
    PRIMARY KEY (id),
    INDEX idx_user_id (user_id)
) COMMENT = '客户筛选场景';
```

---

## 五、客户设置（补充）
> 📄 **对应操作手册：41号（客户-设置）**

菜单路径：`客户 → 设置`

### 5.1 基础设置（操作手册41号）

点击【客户】—【系统设置】-【基础设置】

**跟进客户排序设置**：配置客户列表默认排序规则（按续保日期/预约日期/过期未跟进进行升序或降序显示）

**分配设置**：打开本开关，每日凌晨自动将本月已分配但未进行跟进的客户重新分配

**单用户短信发送数量设置**：可以针对员工给客户每周/每月发送短信的条数进行限制，避免费用浪费或客户投诉（在系统默认上限范围内，每个商户可向下调整）

**短信退订设置**：打开本开关后，在发送短信时结尾自动加上"退订回T"字段；点编辑可以选择在编辑模板时生效还是给个人发送时生效

**资源类型设置**：打开本开关后，支持导入资源类型，自主查询资源类型

### 5.2 跟进阶段设置/拨打状态设置（操作手册41号）

点击【客户】—【设置】—【跟进阶段设置/拨打状态设置】

> ⚠️ 阶段和状态为系统提前设定好的，不支持自定义

---

## 六、API 接口清单（客户管理模块）

| 接口 | 方法 | 路径 | 说明 | 对应PDF |
|---|---|---|---|---|
| 全部客户列表 | GET | `/admin-api/crm/customer/page` | 分页查询，支持多条件 | 25号 |
| 新增客户 | POST | `/admin-api/crm/customer/create` | | 25号 |
| 修改客户 | PUT | `/admin-api/crm/customer/update` | | 25号 |
| 删除客户 | DELETE | `/admin-api/crm/customer/delete` | 逻辑删除 | 25号 |
| 客户详情 | GET | `/admin-api/crm/customer/get?id=` | | 25号 |
| 批量分配客户 | POST | `/admin-api/crm/customer/assign` | | 25号 |
| 批量变更组织 | POST | `/admin-api/crm/customer/change-org` | | 25号 |
| 回收客户 | POST | `/admin-api/crm/customer/recycle` | | 25号 |
| 批量移交 | POST | `/admin-api/crm/customer/transfer` | | 26号 |
| 批量报价 | POST | `/admin-api/crm/customer/batch-quote` | 异步，返回任务ID | 25/26号 |
| 任务列表查询 | GET | `/admin-api/crm/customer/task/page` | 批量报价/导出任务 | 25号 |
| 下载导入模板 | GET | `/admin-api/crm/customer/import/template` | | 24号 |
| 导入预解析 | POST | `/admin-api/crm/customer/import/preview` | multipart/form-data | 24号 |
| 确认导入 | POST | `/admin-api/crm/customer/import/confirm` | 异步任务 | 24号 |
| 导出客户 | GET | `/admin-api/crm/customer/export` | 异步，下载链接站内信通知 | 25号 |
| 导入批次列表 | GET | `/admin-api/crm/customer/import/batch/page` | | 24号 |
| 删除导入批次 | DELETE | `/admin-api/crm/customer/import/batch/delete` | | 24号 |
| 分配导入批次客户 | POST | `/admin-api/crm/customer/import/batch/assign` | | 24号 |
| 画像-险种偏好 | GET | `/admin-api/crm/customer/{id}/portrait/insurance-preference` | | 27号 |
| 画像-保费趋势 | GET | `/admin-api/crm/customer/{id}/portrait/premium-trend` | | 27号 |
| 画像-活跃度评分 | GET | `/admin-api/crm/customer/{id}/portrait/activity-score` | | 27号 |
| 保存筛选场景 | POST | `/admin-api/crm/customer/search-scene/save` | | 25/26号 |
| 获取筛选场景列表 | GET | `/admin-api/crm/customer/search-scene/list` | | 25/26号 |

---

> **下一篇**：客户CRM业务需求设计-中篇-续期管理与云短信

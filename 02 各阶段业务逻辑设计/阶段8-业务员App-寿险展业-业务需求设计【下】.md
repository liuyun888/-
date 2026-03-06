# 阶段8 - 业务员App - 寿险展业 业务需求设计文档【下篇】

> 版本：V1.0  
> 模块范围：寿险保单管理（App端）、续期提醒与跟踪、寿险客户管理（App端）  
> 对应工程：`intermediary-module-ins-order`（寿险保单）、`intermediary-module-ins-life`（续期）、`intermediary-module-ins-agent`（CRM）  
> 前端工程：`intermediary-ui-agent-uniapp`

---

## 一、模块概览

| 功能点 | 前端工时 | 后端工时 | 负责人 |
|--------|---------|---------|--------|
| 个险保单录入（App） | 2天 | 0.5天 | 前端1+后端1 |
| 我的寿险保单（App） | 1.5天 | 0.5天 | 前端1+后端1 |
| 续期提醒与跟踪（App） | 1.5天 | 0.5天 | 前端1+后端1 |
| 寿险客户列表（App） | 1天 | 0.5天 | 前端1+后端1 |
| 寿险客户详情（App） | 1.5天 | 0.5天 | 前端1+后端1 |

---

## 二、个险保单录入（App端）

### 2.1 功能说明

App 端提供三步式保单录入向导，与 PC 端共用后端接口（`AdminInsPolicyLifeController` 对应的 Service 层接口），前端独立开发移动端 UI。

入口：App 首页 → 【订单服务】→【个险订单】→ 右上角【+录入】按钮。

### 2.2 第一步：选择产品与保司

**页面内容：**

- 顶部显示步骤条（第1步共3步）。
- 保险公司下拉选择（从 `ins_insurer` 表读取，`type` 含寿险的保司列表，按名称排序）：必填。
- 产品选择（根据所选保司过滤产品列表，从 `ins_life_product` 表读取 `ON_SALE` 产品）：必填。
- 选择保险公司后联动刷新产品列表；选择产品后在选择框下方展示产品简介（保障期限、缴费期限）。
- 点击【下一步】进行前端非空校验，通过后进入第二步。

**数据暂存：** 每步数据前端暂存（vuex/pinia），不提前写库。

### 2.3 第二步：基本信息与关系人信息

页面分为两个 Section：

**Section A：保单基本信息**

| 字段 | 控件 | 必填 | 校验 |
|------|------|------|------|
| 保单号 | 文本输入 | 是 | 不超过50字符，同一业务员名下不可重复（提交时后端校验） |
| 保单生效日期 | 日期选择器 | 是 | 不早于1年前，不晚于今天+1年 |
| 保单终止日期 | 日期选择器 | 是 | 必须晚于生效日期 |
| 缴费方式 | 单选（年缴/月缴/季缴/趸缴） | 是 | 根据产品 `paymentMode` 过滤 |
| 缴费期限 | 单选 | 是 | 根据产品 `payment_period_options` 过滤 |
| 年度保费 | 数字输入（元，两位小数） | 是 | 大于0 |
| 保额 | 数字输入（元） | 是 | 大于0 |
| 标保 | 数字输入（元，两位小数） | 否 | 留空时后端不参与佣金计算分子 |
| 投保渠道 | 单选（自主开发/转介绍/其他） | 是 | |
| 备注 | 多行文本 | 否 | 不超过500字 |

**Section B：关系人信息（投保人 + 被保人）**

每类关系人操作入口：【选择客户】按钮 + 手动填写两种方式。

**【选择客户】流程：** 点击按钮弹出客户选择弹窗 → 支持按姓名/手机号搜索（调用 `/app-api/ins/customer/search` 接口，限定当前业务员名下客户）→ 点击客户行自动填充以下字段。

**投保人信息字段：**

| 字段 | 控件 | 必填 | OCR辅助 |
|------|------|------|---------|
| 姓名 | 文本输入 | 是 | 是 |
| 证件类型 | 下拉（居民身份证/护照/港澳台通行证） | 是 | |
| 证件号码 | 文本输入 | 是 | 是（OCR识别身份证号） |
| 性别 | 单选 | 是 | 是（从身份证号解析） |
| 出生日期 | 日期选择 | 是 | 是（从身份证号解析） |
| 手机号 | 数字输入 | 是 | 否 |
| 与被保人关系 | 下拉（本人/配偶/父母/子女/其他） | 是 | |

**被保人信息字段（同投保人，去掉"与被保人关系"）：**

若投保人与被保人相同勾选【与投保人相同】复选框，自动同步投保人数据到被保人，被保人字段变为只读。

**身份证OCR操作：** 在姓名/证件号字段右侧展示【扫描证件】图标，点击后：

1. 调起相机或相册选图；
2. 调用 OCR 接口（`/app-api/ocr/id-card`，后端接入阿里云 OCR）；
3. 解析返回的 `name`、`id_number`、`gender`、`birth_date` 字段，自动填充对应输入框；
4. 识别失败时 Toast 提示"识别失败，请手动填写"，输入框保持可编辑状态。

点击【下一步】进行前端校验（所有必填字段非空，身份证格式校验），通过后进入第三步。

### 2.4 第三步：附件上传

**标题提示文字：** "请拍照上传相关保单影像件"

**附件类型列表（逐项显示上传区域）：**

| 附件类型 | 字段 `attachment_type` | 必填 | 说明 |
|---------|----------------------|------|------|
| 保单首页 | `POLICY_COVER` | 是 | 必须上传 |
| 健告书 | `HEALTH_NOTICE` | 是 | 必须上传 |
| 投保单 | `APPLICATION_FORM` | 否 | 建议上传 |
| 其他 | `OTHER` | 否 | 可多张 |

**每个附件上传区：**

- 显示一个"+"虚线框占位区（默认状态）；
- 点击"+"调起相机/相册；
- 选择图片后上传至 OSS（调用 `/app-api/file/upload`，返回 `fileUrl`）；
- 上传成功后占位框变为缩略图，右上角显示"×"删除按钮；
- 每类附件支持最多5张；
- 上传过程中显示进度条，失败时 Toast 提示"上传失败，请重试"。

**提交流程：**

1. 前端校验：`POLICY_COVER`、`HEALTH_NOTICE` 各至少1张。
2. 点击【提交】按钮，调用提交接口。
3. 接口返回成功后，弹出【提交成功】弹窗，弹窗内容：
   - "保单录入成功！"
   - 预计佣金金额：**￥XXXX.XX**（后端预计算返回）
   - 按钮：【查看保单】（跳转保单详情）、【继续录入】（清空表单返回第一步）
4. 接口返回失败时，弹窗展示具体错误信息（如"保单号重复"）。

### 2.5 提交接口

**POST** `/app-api/ins/life/policy/create`

请求体（合并三步数据）：

```json
{
  "insurerId": 10,
  "productId": 1,
  "policyNo": "P2025001",
  "effectiveDate": "2025-03-01",
  "expireDate": "2055-03-01",
  "paymentMode": "ANNUAL",
  "paymentPeriod": 20,
  "annualPremium": 12000.00,
  "sumInsured": 500000,
  "standardPremium": 12000.00,
  "channel": "SELF_DEVELOP",
  "remark": "备注信息",
  "policyHolder": {
    "name": "张三",
    "idType": "ID_CARD",
    "idNo": "110101199001011234",
    "gender": "M",
    "birthday": "1990-01-01",
    "mobile": "13800138000",
    "relationToInsured": "SELF"
  },
  "insured": {
    "name": "张三",
    "idType": "ID_CARD",
    "idNo": "110101199001011234",
    "gender": "M",
    "birthday": "1990-01-01",
    "mobile": "13800138000"
  },
  "attachments": [
    {"type": "POLICY_COVER", "fileUrl": "https://oss.../1.jpg"},
    {"type": "HEALTH_NOTICE", "fileUrl": "https://oss.../2.jpg"}
  ]
}
```

**后端处理逻辑：**

1. **参数校验：**
   - 校验 `policyNo` 在当前租户下是否已存在（查 `ins_policy_life.policy_no`，重复返回 400 "保单号已存在"）；
   - 校验 `effectiveDate < expireDate`；
   - 校验 `productId` 存在且 `product_status=ON_SALE`；
   - 校验投保人、被保人身份证号格式（18位）；
   - 校验 `POLICY_COVER`、`HEALTH_NOTICE` 附件存在。

2. **客户档案匹配/创建（自动）：** 根据投保人手机号查 `ins_customer` 表：
   - 查到：关联 `customer_id`；
   - 未查到：自动创建客户记录（`ins_customer`），关联当前业务员为 `agent_id`，来源标记 `source=POLICY_INPUT`。
   - 被保人同理处理。

3. **保单写入：** 写入 `ins_policy_life` 表（字段见下），写入 `ins_policy_life_insured` 表（投保人+被保人分别一条记录）。

4. **附件写入：** 遍历 `attachments`，写入 `ins_policy_attachment` 表（`policy_id`, `policy_type=LIFE`, `attachment_type`, `file_url`）。

5. **佣金预计算：** 调用 `InsCommissionService.preCalculate(policyId)`：
   - 从 `ins_life_rate_policy` 查匹配当前业务员机构+保司+产品的政策；
   - 预估佣金 = `annualPremium × commissionRate`；
   - 写入 `ins_commission_pre` 表（状态 `PRE_CALC`）；
   - 返回预计佣金金额。

6. **MQ 异步：** 发送 `LifePolicyCreatedEvent` 消息到 RocketMQ（触发后续佣金正式计算、续期任务初始化等）。

响应体：

```json
{
  "policyId": 500,
  "policyNo": "P2025001",
  "estimatedCommission": 1800.00
}
```

### 2.6 相关数据库表

**`ins_policy_life`（`db_ins_order` 库）：**

```sql
CREATE TABLE ins_policy_life (
  id                  BIGINT        PRIMARY KEY AUTO_INCREMENT,
  tenant_id           BIGINT        NOT NULL,
  agent_id            BIGINT        NOT NULL COMMENT '录入业务员ID',
  insurer_id          BIGINT        NOT NULL COMMENT '保险公司ID',
  product_id          BIGINT        NOT NULL COMMENT '寿险产品ID',
  product_name        VARCHAR(100)  NOT NULL COMMENT '产品名称快照',
  policy_no           VARCHAR(50)   NOT NULL COMMENT '保单号',
  policy_holder_id    BIGINT        COMMENT '投保人客户ID',
  insured_id          BIGINT        COMMENT '被保人客户ID',
  effective_date      DATE          NOT NULL,
  expire_date         DATE          NOT NULL,
  payment_mode        VARCHAR(20)   NOT NULL COMMENT 'ANNUAL/MONTHLY/QUARTERLY/LUMP_SUM',
  payment_period      INT           NOT NULL COMMENT '缴费期限（年），趸缴为1',
  annual_premium      DECIMAL(15,2) NOT NULL COMMENT '年度保费',
  sum_insured         DECIMAL(15,2) NOT NULL COMMENT '保额',
  standard_premium    DECIMAL(15,2) COMMENT '标保',
  channel             VARCHAR(30)   COMMENT '投保渠道',
  policy_status       VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE' COMMENT 'ACTIVE/PENDING_RENEWAL/SURRENDERED/LAPSED',
  remark              VARCHAR(500),
  input_source        VARCHAR(20)   DEFAULT 'APP' COMMENT 'APP/PC/IMPORT',
  created_time        DATETIME      NOT NULL,
  updated_time        DATETIME      NOT NULL,
  creator             BIGINT        NOT NULL,
  deleted             BIT(1)        DEFAULT 0,
  UNIQUE KEY uk_policy_no_tenant (policy_no, tenant_id),
  INDEX idx_agent_id (agent_id),
  INDEX idx_policy_status (policy_status),
  INDEX idx_expire_date (expire_date)
) COMMENT='寿险保单主表';
```

**`ins_policy_life_insured`（`db_ins_order` 库）：**

```sql
CREATE TABLE ins_policy_life_insured (
  id                  BIGINT      PRIMARY KEY AUTO_INCREMENT,
  policy_id           BIGINT      NOT NULL,
  role                VARCHAR(20) NOT NULL COMMENT 'HOLDER=投保人，INSURED=被保人，BENEFICIARY=受益人',
  customer_id         BIGINT      COMMENT '关联客户ID',
  name                VARCHAR(50) NOT NULL,
  id_type             VARCHAR(20) NOT NULL,
  id_no               VARCHAR(30) NOT NULL,
  gender              CHAR(1)     NOT NULL,
  birthday            DATE        NOT NULL,
  mobile              VARCHAR(20),
  relation_to_insured VARCHAR(20) COMMENT 'SELF/SPOUSE/PARENT/CHILD/OTHER',
  created_time        DATETIME    NOT NULL,
  deleted             BIT(1)      DEFAULT 0,
  INDEX idx_policy_id (policy_id),
  INDEX idx_id_no (id_no)
) COMMENT='寿险被保人/投保人/受益人表';
```

---

## 三、我的寿险保单（App端）

### 3.1 页面入口

App 底部导航栏 → 【订单】→ 顶部 Tab 中新增【寿险】Tab（原有：全部、车险、非车险）。

### 3.2 列表页

**默认排序：** 录入时间倒序。

**搜索栏：** 顶部搜索框，支持按保单号、被保人姓名、险种名称（产品名称）模糊搜索。

**状态 Tab（横向二级 Tab）：**

| Tab | 对应 `policy_status` | 说明 |
|-----|---------------------|------|
| 全部 | 不过滤 | |
| 有效 | `ACTIVE` | 保单在有效期内 |
| 待续保 | `PENDING_RENEWAL` | 距到期≤90天且未续保 |
| 已退保 | `SURRENDERED` | |

**保单卡片展示字段：**

| 字段 | 来源 |
|------|------|
| 产品名称 | `ins_policy_life.product_name` |
| 保险公司 | 关联查 `ins_insurer.name` |
| 保单号 | `ins_policy_life.policy_no` |
| 被保人姓名 | 关联 `ins_policy_life_insured`（`role=INSURED`）.name |
| 保额 | `ins_policy_life.sum_insured` |
| 到期日 | `ins_policy_life.expire_date`（格式：XXXX-XX-XX），到期≤30天显示红色 |
| 佣金状态 | 关联 `ins_commission_pre`：未结算/已结算/结算中 |
| 状态标签 | `policy_status` 对应中文（有效/待续保/已退保/失效） |

**上拉加载：** 每页15条。

### 3.3 保单详情页

点击卡片进入保单详情页，详情页分多个 Section 展示：

**Section：保单基本信息**（保单号、保险公司、产品名称、保额、年度保费、缴费方式、缴费期限、生效日期、到期日）

**Section：投保人信息**（姓名、证件号脱敏显示：身份证后4位明文其余掩码、手机号、与被保人关系）

**Section：被保人信息**（同投保人字段）

**Section：佣金信息**（预计佣金、实结佣金、结算状态、结算时间）

**Section：附件**（展示上传的附件缩略图，点击可全屏预览）

**底部操作按钮区（有效/待续保状态时显示）：**

| 按钮 | 操作 |
|------|------|
| 【编辑】 | 进入保单编辑页（仅允许修改非核心字段：备注、附件，保单号/保额/被保人不可改） |
| 【发起保全】 | 跳转"保全申请"页（见3.4） |
| 【续期跟踪】 | 跳转"续期跟踪"页（见四） |
| 【分享给客户】 | 生成保单信息 H5 链接（含保单摘要）并调起微信分享/复制链接 |

**分享保单信息 H5：**

- 调用 `/app-api/ins/life/policy/share/{policyId}`，后端生成含保单摘要的 H5 链接（有效期7天，路径：`/h5/policy-summary/{shareToken}`）；
- H5 内容：产品名称、保险公司、保单号（部分脱敏）、被保人姓名（脱敏）、保额、到期日、业务员联系信息。

### 3.4 保单接口

**GET** `/app-api/ins/life/policy/page`

请求参数：`keyword`、`policyStatus`、`pageNo`、`pageSize`，后端自动按当前 token 的 `agent_id` 过滤。

**GET** `/app-api/ins/life/policy/detail/{policyId}`

后端校验：`policyId` 必须属于当前登录业务员（`agent_id` 校验），否则返回 403。

---

## 四、续期提醒与跟踪（App端）

### 4.1 首页续期提醒卡片

App 首页展示"续期待办"提醒卡片（固定在首页快捷入口区域）：

**卡片展示内容：**

| 内容项 | 数据来源 | 说明 |
|--------|---------|------|
| 近30天到期 | 统计当前业务员名下 `expire_date` 在今天+30天内且 `policy_status=ACTIVE` 的保单数 | 红色数字 |
| 近31-60天到期 | 同上，范围 31-60天 | 橙色数字 |
| 近61-90天到期 | 同上，范围 61-90天 | 黄色数字 |
| 待跟进 | 需要跟进但未录入跟进记录超过3天的保单数 | 灰色数字 |

点击卡片跳转"续期待办"页面。

**卡片数据接口：** **GET** `/app-api/ins/life/renewal/summary`，后端用 Redis 缓存（TTL 5分钟），key：`renewal_summary:{agentId}`。

### 4.2 续期待办列表页

**Tab 切换：**

| Tab | 过滤条件 |
|-----|---------|
| 全部 | 无过滤 |
| 紧急（<15天） | `expire_date` ≤ 今天+15天 |
| 即将到期（15-30天） | `expire_date` 在今天+15天~+30天 |
| 跟进中 | 已有跟进记录但未完成续保 |

**保单卡片展示字段：**

| 字段 | 说明 |
|------|------|
| 产品名称 | |
| 被保人姓名 | |
| 到期日期 | 格式：MM月DD日到期 |
| 剩余天数 | 计算 `expire_date - today`，红色（<15天）、橙色（15-30天）、正常（>30天） |
| 客户手机号 | 脱敏：138****0000 |
| 最后跟进时间 | 最近一条跟进记录的时间，无记录显示"未跟进" |
| 跟进状态 | 意向高/意向中/意向低/已续保/拒绝续保 |

**快捷操作（每张卡片右侧）：**

点击电话图标 → 调用系统拨号盘，号码为客户手机号（不脱敏）。
点击微信图标 → 若客户已关联企业微信，跳转企业微信会话；否则 Toast 提示"该客户未绑定企业微信"。

### 4.3 录入跟进记录

点击保单卡片或卡片右侧【跟进】按钮 → 底部弹出「跟进记录」Sheet：

**表单字段：**

| 字段 | 控件 | 必填 | 说明 |
|------|------|------|------|
| 跟进方式 | 单选（电话/微信/面访/短信/其他） | 是 | |
| 联系结果 | 单选（已接通/未接通/已读未复/已面访） | 是 | |
| 续保意向 | 单选（意向高/意向中/意向低/拒绝续保/已续保） | 是 | 选"已续保"触发自动更新保单状态 |
| 跟进备注 | 多行文本 | 否 | 不超过200字 |
| 下次跟进时间 | 日期时间选择器 | 否 | 选择后系统在该时间发起极光推送提醒 |

**点击【保存】：**

1. 前端非空校验（必填字段）。
2. 调用 `/app-api/ins/life/renewal/track/add` 接口写入跟进记录。
3. 若 `renewalIntent = RENEWED`（已续保）：后端同步更新 `ins_policy_life.policy_status = ACTIVE`，清除待续保状态；Toast 提示"已标记续保成功🎉"。
4. 若设置了下次跟进时间：后端写入 `ins_life_renewal_remind` 表，定时任务（`InsLifeRenewalAlertJob`，每分钟扫描）到时间后调用极光推送 API 推送消息（消息内容："[产品名称]即将到期，请及时跟进客户[姓名]"）。
5. Sheet 关闭，列表刷新当前保单卡片的跟进状态和时间。

### 4.4 接口定义

**GET** `/app-api/ins/life/renewal/page`

请求参数：`urgencyLevel`（ALL/URGENT/NEAR_DUE/FOLLOWING）、`pageNo`、`pageSize`

**POST** `/app-api/ins/life/renewal/track/add`

请求体：

```json
{
  "policyId": 500,
  "trackWay": "PHONE",
  "contactResult": "CONNECTED",
  "renewalIntent": "HIGH",
  "remark": "客户说下周确认",
  "nextFollowTime": "2025-04-01 10:00:00"
}
```

**后端写入 `ins_life_renewal_track` 表：**

```sql
CREATE TABLE ins_life_renewal_track (
  id                BIGINT      PRIMARY KEY AUTO_INCREMENT,
  policy_id         BIGINT      NOT NULL,
  agent_id          BIGINT      NOT NULL,
  track_way         VARCHAR(20) NOT NULL COMMENT 'PHONE/WECHAT/VISIT/SMS/OTHER',
  contact_result    VARCHAR(20) NOT NULL,
  renewal_intent    VARCHAR(20) NOT NULL COMMENT 'HIGH/MEDIUM/LOW/REFUSED/RENEWED',
  remark            VARCHAR(200),
  next_follow_time  DATETIME,
  created_time      DATETIME    NOT NULL,
  creator           BIGINT      NOT NULL,
  deleted           BIT(1)      DEFAULT 0,
  INDEX idx_policy_id (policy_id),
  INDEX idx_agent_id (agent_id),
  INDEX idx_next_follow_time (next_follow_time)
) COMMENT='寿险续期跟踪记录';
```

若 `renewal_intent = RENEWED`，后端额外执行：

```sql
UPDATE ins_policy_life SET policy_status = 'ACTIVE', updated_time = NOW() WHERE id = #{policyId};
```

同时发 MQ 消息 `LifePolicyRenewedEvent`（触发佣金续期计算）。

---

## 五、寿险客户列表（App端）

### 5.1 页面入口

App 底部导航栏 → 【我的】→【我的客户】→ 顶部 Tab 新增【寿险客户】Tab（复用非车险 CRM 客户列表 UI 组件，按险种类型过滤数据）。

### 5.2 列表展示

**客户卡片字段：**

| 字段 | 说明 |
|------|------|
| 客户头像 | 头像（无则显示姓名首字符彩色默认头像） |
| 客户姓名 | |
| 手机号 | 脱敏显示（138****0000） |
| 持有寿险保单数 | 统计 `ins_policy_life` 中该客户作为投保人/被保人的保单数（`policy_status != SURRENDERED`） |
| 最近跟进时间 | 最后一条跟进记录的 `created_time`，无则显示"从未跟进" |
| 客户等级 | `ins_customer.level`（S/A/B/C），对应颜色标签 |

**排序选项（右上角排序按钮）：** 持单数（降序）、最近跟进时间（降序）、客户等级（S→A→B→C）。

**搜索：** 按姓名或手机号搜索（后端模糊查询，手机号支持全号或后4位匹配）。

**长按批量操作：** 长按任意卡片进入批量选择模式，底部出现：

| 操作 | 说明 |
|------|------|
| 添加标签 | 弹出标签选择弹窗（自定义标签，从 `ins_customer_tag` 表读取当前租户标签列表），选择后批量写入 `ins_customer_tag_relation` 表 |
| 移入跟进计划 | 批量设置 `ins_customer.in_follow_plan = true`，方便后续统一跟进 |

### 5.3 接口定义

**GET** `/app-api/ins/customer/page`

请求参数：`insuranceType=LIFE`（关键过滤参数）、`keyword`、`sortField`（`POLICY_COUNT`/`LAST_FOLLOW`/`LEVEL`）、`sortOrder`（`DESC`）、`pageNo`、`pageSize`

**后端查询逻辑：**

1. 查 `ins_customer` 表，过滤 `agent_id = currentAgentId`；
2. 过滤条件 `insuranceType=LIFE`：`EXISTS (SELECT 1 FROM ins_policy_life WHERE insured_id = c.id OR policy_holder_id = c.id AND deleted = 0)`；
3. LEFT JOIN 统计保单数（子查询）；
4. LEFT JOIN 最后跟进时间（子查询最大 `created_time`）；
5. 按排序字段排序。

---

## 六、寿险客户详情（App端）

### 6.1 页面入口

客户列表点击任意客户卡片进入详情页。

### 6.2 页面结构

**顶部信息区（固定）：** 客户头像、姓名、手机号、客户等级标签、【拨打电话】图标。

**多 Section 滚动展示：**

**Section 1：基本信息**

姓名、性别、出生日期（计算年龄）、证件类型、证件号（脱敏）、工作单位（选填）、地址（选填）。

点击右上角【编辑】进入客户信息编辑页（姓名、手机号、地址、工作单位可修改；证件号不可修改）。

**Section 2：联系方式**

手机号（点击可拨号）、微信（若有企业微信绑定显示头像+名称）、邮箱。

**Section 3：家庭成员**

列表展示（从 `ins_customer_family` 表查询）：成员姓名、关系、是否有保单标识（若该成员也在系统中有保单，显示小图标）。

点击【添加家庭成员】按钮弹出表单（姓名/关系/手机号，选填），写入 `ins_customer_family` 表。

**Section 4：跟进记录时间轴**

按时间倒序展示该客户的所有跟进记录（查 `ins_life_renewal_track` 表 + 通用跟进记录表 `ins_customer_follow`），每条记录展示：时间、跟进方式图标、跟进内容摘要、业务员姓名。

最多展示10条，点击【查看全部】跳转跟进记录列表页（全量分页展示）。

**Section 5：寿险保单清单**

列表展示该客户名下的寿险保单（作为投保人或被保人），每条展示：产品名称、保额、到期日、保单状态。

点击某条保单跳转到"我的寿险保单 → 保单详情页"。

**Section 6：健康档案（寿险专属）**

展示该客户在历次投保中填写的健康告知答案摘要，字段：

| 字段 | 来源 | 权限控制 |
|------|------|---------|
| 是否吸烟 | `ins_customer_health.smoking` | 所有人可见 |
| 是否有慢性病史 | `ins_customer_health.chronic_disease` | 所有人可见 |
| 具体疾病记录 | `ins_customer_health.disease_detail` | **敏感字段，仅该客户的归属业务员可见；其他人（含主管）一律显示"***"** |
| 健告答案快照 | `ins_policy_life.health_notice_answer_json` 中高风险问题答案 | 同上权限 |

**权限控制实现：** 后端在 `/app-api/ins/customer/detail/{customerId}` 接口中，获取当前登录 `agentId`，若 `customerId` 的 `agent_id != currentAgentId`，则 `disease_detail` 返回 `"***"`，前端直接展示脱敏值（不做前端判断，以后端为准）。

**Section 7：寿险专属操作按钮**

| 按钮 | 操作 |
|------|------|
| 【制作计划书】 | 携带 `customerId`（自动填充客户姓名、年龄）跳转计划书制作页 |
| 【发起保全】 | 弹出保全申请 Sheet（需关联具体保单，先弹保单选择列表） |
| 【记录续期】 | 弹出跟进记录 Sheet（同续期跟踪页的跟进 Sheet，需先选保单） |

### 6.3 接口定义

**GET** `/app-api/ins/customer/detail/{customerId}`

响应包含上述所有 Section 数据（合并查询，避免前端多次请求），敏感字段后端脱敏处理。

---

## 七、极光推送配置（续期提醒）

**推送触发时机：** `InsLifeRenewalAlertJob`（每分钟执行）扫描 `ins_life_renewal_remind` 表，查 `remind_time <= NOW() AND push_status = 'PENDING'`，批量调用极光推送 API。

**推送内容模板：**

```
标题：续期提醒
内容：您的客户【{customerName}】持有的【{productName}】保单将于 {expireDate} 到期，
      距到期还有 {daysLeft} 天，请及时跟进！
点击跳转：续期待办列表页（deeplink：app://renewal/list?policyId={policyId}）
```

**推送失败处理：** 极光推送失败时，更新 `push_status = 'FAILED'`，`retry_count +1`，最多重试3次，超过3次写入告警日志。

**`ins_life_renewal_remind` 表：**

```sql
CREATE TABLE ins_life_renewal_remind (
  id              BIGINT      PRIMARY KEY AUTO_INCREMENT,
  policy_id       BIGINT      NOT NULL,
  agent_id        BIGINT      NOT NULL,
  remind_time     DATETIME    NOT NULL COMMENT '提醒时间',
  push_status     VARCHAR(20) DEFAULT 'PENDING' COMMENT 'PENDING/SUCCESS/FAILED',
  retry_count     INT         DEFAULT 0,
  created_time    DATETIME    NOT NULL,
  INDEX idx_remind_time_status (remind_time, push_status),
  INDEX idx_agent_id (agent_id)
) COMMENT='续期提醒推送记录';
```

---

## 八、与 PC 端共用接口说明

App 端寿险保单相关功能**复用 PC 端 Service 层**，Controller 层分别在 `app/` 和 `admin/` 目录，但调用同一 Service 方法：

| App 端 Controller | PC 端 Controller | 共用 Service |
|------------------|-----------------|-------------|
| `AppInsLifePolicyController.create()` | `AdminInsPolicyLifeController.create()` | `InsPolicyLifeService.createPolicy()` |
| `AppInsLifePolicyController.page()` | `AdminInsPolicyLifeController.page()` | `InsPolicyLifeService.pagePolicy()` |
| `AppInsLifePolicyController.detail()` | `AdminInsPolicyLifeController.detail()` | `InsPolicyLifeService.getDetail()` |

区别：App 端 Controller 的查询条件强制附加 `agentId = currentLoginAgentId`（数据隔离），PC 端管理员可查所有。

---

> 两篇文档合计覆盖阶段8所有11个功能点（前端16天+后端6天）  
> 如需数据库 DDL 汇总或接口 Swagger 注解模板，可单独输出

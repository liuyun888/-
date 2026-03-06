# 阶段2-B端业务员App-非车险展业 详细功能设计文档（中）

> **项目：** 保险中介全域数字化平台  
> **模块：** 业务员App - 非车险展业  
> **技术栈：** yudao-cloud（Spring Cloud Alibaba + Vue3）  
> **文档版本：** v3.0（业务逻辑重写版）  
> **涵盖模块：** M3-计划书制作 · M4-客户管理CRM

---

## M3 计划书制作

### 业务背景

计划书是业务员向客户展示保障方案的核心销售工具，包含被保人信息、保障方案配置、保障责任汇总、现金价值表、利益演示等内容，最终生成 PDF 文件或 H5 链接发送给客户。

### M3-F1 计划书模板选择

#### 业务流程

**入口：**
1. 底部导航"计划书"Tab → 新建计划书；
2. 试算结果页点击【制作计划书】按钮（带入当前试算参数）；
3. 客户详情页点击【制作计划书】按钮（带入客户信息）。

**模板选择页面：**
- 展示系统预置模板列表，卡片形式，每张卡展示：模板预览缩略图 + 模板名称 + 适用场景说明；
- 平台预置模板分类：个人版 / 家庭版 / 企业版；
- 业务员可在"自定义模板"Tab查看自己保存的历史模板配置；
- 点击模板进入预览，确认后点击【使用此模板】进入下一步。

**后端接口：** `GET /insurance/proposal/template/list`

**返回字段：**
```
id            Long      模板ID
name          String    模板名称（如"个人保障版"、"家庭综合版"）
description   String    适用场景（如"适合单身/年轻人"）
thumbnailUrl  String    缩略图URL
category      Integer   分类：1-个人 2-家庭 3-企业
isDefault     Boolean   是否为默认模板
sortOrder     Integer   排序
```

---

### M3-F2 方案配置

#### 业务流程

选好模板后，进入方案配置页。此页面是计划书制作的核心步骤，分为三个区域：

**区域一：被保人/投保人信息**

| 字段 | 必填 | 校验规则 |
|---|---|---|
| 计划书标题 | 是 | 1-50字符，默认值为"【客户姓名】的专属保障计划" |
| 投保人姓名 | 是 | 2-20个中文字符 |
| 投保人年龄 | 是 | 18-70周岁整数 |
| 被保人姓名 | 是 | 2-20个中文字符 |
| 被保人出生日期 | 是 | 不得是未来日期；周岁不超过100岁 |
| 被保人性别 | 是 | 男/女 |
| 关联客户 | 否 | 可从客户列表中选择已有客户（自动填入姓名/生日/性别）；若选择，计划书生成后自动关联到该客户档案 |

**区域二：产品方案配置**

支持配置"主险 + 多个附加险"的组合方案。

**添加主险：**
- 点击【+ 添加主险】，弹出产品选择弹窗（同产品列表，支持筛选搜索）；
- 选中产品后，展开该产品的参数配置：

| 字段 | 必填 | 说明 |
|---|---|---|
| 保额 | 是 | 在产品 min_amount~max_amount 内选择，步进 amount_increment |
| 缴费期限 | 是 | 从产品 payment_period_options 中选择 |
| 保障期限 | 是 | 从产品 coverage_period_options 中选择 |
| 年缴保费 | 自动 | 配置完保额/期限后自动调用试算接口计算并填入，不可手动修改 |

**添加附加险：**
- 主险配置完成后，显示【+ 添加附加险】按钮；
- 弹窗只展示与主险兼容的附加险（通过 `compatible_main_product_ids` 字段匹配）；
- 每个附加险同样需配置保额、缴费期限；
- 附加险保额校验：不得超过主险保额；
- 最多添加 5 个附加险。

**删除产品：** 长按产品卡片，显示删除按钮；主险删除时同时清空所有附加险（弹 Dialog 确认）。

**区域三：方案摘要（实时更新）**

页面底部固定展示：
- 所有产品合计年缴保费（实时累加）
- 产品数量：共 N 个险种

---

**整体校验（点击【生成计划书】时触发）：**
1. 计划书标题非空；
2. 被保人信息完整；
3. 至少配置 1 个主险；
4. 所有已配置产品的年缴保费均已计算成功（非0、非空）；
5. 附加险保额不超过对应主险保额；
6. 调用后端"预验证"接口（校验所有产品当前仍在售）。

---

### M3-F3 保障演示（保障责任汇总）

#### 业务流程

方案配置完成后，系统自动聚合所有选中产品的保障责任，生成"保障责任汇总表"。

**页面展示：**
- 以卡片列表形式展示各保障责任，按责任类型分组（身故保障/重疾保障/轻症保障/医疗保障/意外保障等）；
- 每项保障显示：责任名称 / 保障金额 / 来源产品名称；
- 同一类责任多产品叠加时，标注"A险 50万 + B险 30万 = 80万"。

**业务员可选操作：**
- 点击任意保障卡片，可查看该责任的详细保障条款（弹窗）；
- 可在此页选择是否显示某项责任（用于隐藏不想展示给客户的条款），通过开关控制，入库时记录 `hidden_coverages` 字段。

---

### M3-F4 现金价值表

#### 业务流程

仅当方案中包含**储蓄型产品**（年金险/增额终身寿险）时展示此步骤。

**页面展示：**
- 以表格形式展示逐年数据（年度/年末年龄/累计保费/现金价值/可领取生存金/累计领取）；
- 表格数据可左右滑动查看，默认展示前20年，点击"查看全部"展开；
- 底部展示关键指标：回本年限 / IRR（XX%）；
- 以折线图直观展示现金价值 vs 累计保费趋势。

**数据来源：**
- 调用 M2 保费试算中的 `POST /insurance/quotation/benefit` 接口；
- 每个产品分别计算后合并显示。

---

### M3-F5 计划书生成（PDF）

#### 业务流程

完成所有配置后，点击【生成计划书】按钮。

**生成流程（用户视角）：**
1. 点击【生成计划书】，页面显示全屏 Loading "正在生成，请稍候..."；
2. 后端异步生成 PDF，前端轮询状态（每2秒查询一次，最长等待60秒）；
3. 生成成功后，Loading 消失，展示成功页面：
   - 计划书缩略预览图（PDF首页截图）
   - 按钮：【预览计划书】【分享给客户】【下载PDF】【重新编辑】；
4. 若60秒内未生成成功，提示"生成超时，请稍后在计划书列表查看"。

**后端接口：** `POST /insurance/proposal/generate`

**请求参数（完整计划书数据）：**
```json
{
  "templateId": 1,
  "title": "张三的专属保障计划",
  "applicantName": "张三",
  "applicantAge": 35,
  "insuredName": "张三",
  "insuredBirthday": "1990-01-01",
  "insuredGender": 1,
  "customerId": 100,
  "products": [
    {
      "productId": 123,
      "productName": "XX重大疾病保险",
      "amount": 500000,
      "paymentPeriod": "20年",
      "coveragePeriod": "终身",
      "annualPremium": 6580.00
    }
  ],
  "hiddenCoverages": ["特定疾病额外赔"],
  "remark": "备注说明"
}
```

**后端处理逻辑：**
1. 校验 templateId 有效；
2. 校验所有 productId 当前 status=1（在售），否则返回错误，提示具体产品名称；
3. 生成计划书编号（规则：`PS+年月日+6位随机数`，如 `PS202502180001`）；
4. 聚合所有产品保障责任，按 `hiddenCoverages` 过滤；
5. 如果包含储蓄型产品，批量调用利益演示接口获取现金价值表；
6. 将所有数据写入 `ins_proposal` 表（status=1 草稿）；
7. 发送异步消息到 MQ，由 PDF 生成服务消费；
8. PDF 生成服务使用 Freemarker 填充 HTML 模板，再用 wkhtmltopdf 或 iText 转 PDF；
9. PDF 文件上传 OSS，获取访问 URL；
10. 更新 `ins_proposal` 的 `pdf_url` 字段，`status` 改为 2（已生成）；
11. 前端轮询接口 `GET /insurance/proposal/status/{id}` 获取状态。

**ins_proposal 入库字段：**
```
id                BIGINT      自增主键
proposal_no       VARCHAR(32) 计划书编号，唯一
agent_id          BIGINT      业务员ID（当前登录用户）
customer_id       BIGINT      关联客户ID（可空）
template_id       BIGINT      模板ID
title             VARCHAR(100) 计划书标题
applicant_name    VARCHAR(50) 投保人姓名
applicant_age     INT         投保人年龄
insured_name      VARCHAR(50) 被保人姓名
insured_birthday  DATE        被保人出生日期
insured_gender    TINYINT     被保人性别（1男2女）
insured_age       INT         被保人年龄（计算值，根据生日计算当前周岁）
products          JSON        产品方案数组（含productId/名称/保额/期限/保费）
total_premium     DECIMAL     合计年缴保费
coverage_summary  JSON        保障责任汇总
cash_value_table  JSON        现金价值表（含逐年数据+IRR）
hidden_coverages  JSON        业务员选择隐藏的责任项列表
pdf_url           VARCHAR(255) PDF文件OSS地址
status            TINYINT     1-草稿 2-已生成 3-已分享
create_time       DATETIME    创建时间
update_time       DATETIME    更新时间
deleted           TINYINT     逻辑删除
tenant_id         BIGINT      租户ID
```

---

### M3-F6 计划书分享

#### 业务流程

计划书生成成功后，点击【分享给客户】按钮。

**分享方式：**

**方式一：生成 H5 链接**
- 后端生成专属分享链接（如 `https://h5.domain.com/proposal/view?token=xxx`）；
- 链接有效期：30天（可在管理后台配置）；
- 业务员可点击"复制链接"发送给客户（微信/短信等）；
- 链接设置防盗链：仅允许微信内置浏览器或直接访问，禁止被其他网站嵌入。

**方式二：生成二维码**
- 同时生成该 H5 链接对应的二维码图片；
- 业务员可保存二维码图片，发送给客户扫描查看；
- 二维码图片存储在 OSS，保存到 `ins_proposal.qr_code` 字段。

**H5 计划书页面（客户端）：**
- 无需登录即可访问；
- 展示内容：封面（含业务员姓名/联系方式）→ 方案摘要 → 保障责任 → 现金价值图表（如有）→ 业务员联系方式；
- 底部固定展示"联系我们"按钮（点击跳转拨号或微信）；
- 不可下载 PDF，仅可在线查看（防止计划书内容被他人窃取）。

**后端接口：** `POST /insurance/proposal/share/{id}`

**后端处理逻辑：**
1. 检查 proposal 存在且属于当前业务员（`agent_id = 当前用户ID`）；
2. 检查 `pdf_url` 已生成（status=2），否则返回"计划书还未生成完成"；
3. 生成 H5 Token（UUID，存储在 Redis，Key:`proposal:share:{token}`，Value:proposalId，TTL 30天）；
4. 拼接 H5 链接 URL；
5. 调用二维码生成库（如 zxing）生成二维码图片，上传 OSS；
6. 更新 `ins_proposal`：`h5_url`、`qr_code`、`status=3`（已分享）；
7. 返回 h5_url、qr_code_url。

---

### M3-F7 查看追踪

#### 业务流程

业务员可以知道客户是否已查看计划书，以便跟进。

**展示位置：**
- 计划书列表中，每条计划书显示"已查看 N 次 / 最近查看 XX时间前"；
- 进入计划书详情，查看"查看记录"列表（时间 + 设备类型 + 大概地区）。

**后端处理逻辑（客户端 H5 触发）：**
1. 客户通过 H5 Token 访问计划书时，后端解析 Token 获取 proposalId；
2. 异步记录查看日志到 `ins_proposal_view_log`（proposalId / IP / User-Agent / 访问时间）；
3. 更新 `ins_proposal.view_count = view_count + 1`；
4. 同时向业务员推送 App 消息通知（通过消息中心）："您的客户刚刚查看了计划书《XXX》"（同一个 IP 24小时内仅推送一次，避免骚扰）。

**ins_proposal_view_log 入库字段：**
```
id            BIGINT
proposal_id   BIGINT
ip            VARCHAR(50)   客户端IP（脱敏展示时只显示前两段）
user_agent    VARCHAR(500)  设备信息
region        VARCHAR(100)  IP归属地（通过IP库解析，如"浙江省杭州市"）
view_time     DATETIME
```

---

### M3 计划书列表

**入口：** 底部导航"计划书"Tab。

**列表展示字段：**
- 计划书标题
- 被保人姓名
- 险种摘要（如"重疾险+医疗险，年缴￥8,580"）
- 创建时间
- 状态（草稿/已生成/已分享）
- 查看次数徽标（已分享的计划书展示）

**操作：**
- 点击卡片 → 进入计划书详情页；
- 右滑卡片 → 出现【分享】【编辑】【删除】操作按钮；
- 计划书状态为"草稿"时可编辑；已生成后仅可查看，不可修改（需要修改则创建新版本）；
- 删除：逻辑删除（`deleted=1`），同时 Redis 中的 share token 不删除（避免 H5 链接失效）。

**列表接口：** `GET /insurance/proposal/page`，参数：pageNo/pageSize/status（筛选）

---

## M4 客户管理CRM

### M4-F1 客户列表

#### 业务流程

**入口：** 底部导航"客户"Tab。

**页面布局：**
- 顶部搜索框（实时搜索）
- 筛选按钮（标签/跟进状态/客户分组）
- 客户列表（卡片样式）
- 右上角【+ 新增客户】按钮

**列表卡片展示字段：**
- 头像（姓名首字生成，或客户上传头像）
- 客户姓名
- 手机号（脱敏：138****1234）
- 客户标签（最多显示3个，溢出显示"+N"）
- 最近跟进时间（如"3天前"）
- 保单数量
- 下次跟进时间（超期未跟进时字体显示红色）

**搜索规则：**
- 输入姓名/手机号（后4位）/身份证后4位，实时触发搜索（防抖300ms）；
- 手机号搜索：将输入与加密手机号的 `mobile_hash` 字段匹配（SHA256哈希）。

**筛选规则：**
| 筛选维度 | 可选项 | 后端处理 |
|---|---|---|
| 客户标签 | 展示该业务员下的全部自定义标签 | `JSON_CONTAINS(tags, ?)` |
| 跟进状态 | 今日待跟进/本周待跟进/超期未跟进 | 按 `next_follow_time` 范围过滤 |
| 客户分组 | 展示该业务员的全部分组 | `WHERE group_id = ?` |
| 客户等级 | A/B/C/D类 | `WHERE customer_level = ?` |

**数据权限：** 业务员只能查看自己的客户（`WHERE agent_id = 当前用户ID`）。

**后端接口：** `GET /insurance/customer/page`

---

### M4-F2 新增/编辑客户

#### 业务流程

点击右上角【+ 新增客户】，进入新增客户页面。

**表单字段：**

| 字段 | 必填 | 校验规则 |
|---|---|---|
| 客户姓名 | 是 | 2-20个中文字符 |
| 手机号 | 是 | 11位数字，正则：`1[3-9]\d{9}`；校验同一业务员下是否已有相同手机号（提示"该手机号已存在，是否查看"） |
| 出生日期 | 否 | 不得是未来日期；不得超过100周岁 |
| 性别 | 否 | 男/女 单选 |
| 身份证号 | 否 | 18位，校验位合规校验；校验同一业务员下是否重复 |
| 职业 | 否 | 文本输入，50字以内 |
| 职业类别 | 否 | 下拉（1-6类） |
| 省市 | 否 | 级联选择器（省→市） |
| 详细地址 | 否 | 100字以内 |
| 微信号 | 否 | 50字以内 |
| 客户来源 | 否 | 下拉：自然认识/朋友介绍/活动获客/老客户转介绍/网络获客/其他 |
| 备注 | 否 | 500字以内 |
| 客户分组 | 否 | 从该业务员的分组列表选择 |
| 客户标签 | 否 | 多选，从已有标签中选择或输入新标签 |

**手机号重复处理逻辑：**
1. 输入手机号后立即（失焦时）调用查重接口；
2. 若该业务员下已有此手机号的客户，弹 Dialog 提示："已有客户张三（138****1234）手机号相同，是否直接查看？"；
3. 点击"查看"跳转到已有客户详情；
4. 点击"继续新增"允许继续（不同业务员可以有相同手机号的客户）。

**后端接口：**
- 新增：`POST /insurance/customer`
- 编辑：`PUT /insurance/customer/{id}`

**后端校验（新增）：**
1. 手机号格式校验；
2. 同一 `agent_id` + `mobile_hash` 唯一性校验；
3. 身份证格式校验（若填写）；
4. 生成客户编号（规则：`C+年份后2位+月日+4位序列，如 C25021800001`）；
5. 手机号 AES-256 加密存储，同时存储手机号 SHA256 哈希（`mobile_hash` 字段，用于搜索）；
6. 身份证 AES-256 加密存储，存储后4位明文（`id_card_last4`）。

**ins_customer 入库字段（新增时）：**
```
id               BIGINT     自增主键
customer_no      VARCHAR(32) 客户编号，唯一
agent_id         BIGINT     业务员ID（当前登录用户）
name             VARCHAR(50) 客户姓名
mobile           VARCHAR(200) 手机号（AES加密密文）
mobile_hash      VARCHAR(64)  手机号SHA256哈希（用于搜索）
id_card          VARCHAR(300) 身份证（AES加密，前14位密文|后4位明文）
id_card_last4    VARCHAR(4)   身份证后4位明文
gender           TINYINT     性别
birthday         DATE        出生日期
age              INT         年龄（当前周岁，可定时更新）
occupation       VARCHAR(100) 职业名称
occupation_class TINYINT     职业类别
province         VARCHAR(20)
city             VARCHAR(20)
address          VARCHAR(200)
wechat           VARCHAR(50)
source           VARCHAR(50)  客户来源
group_id         BIGINT      分组ID
tags             JSON        标签数组（如["有意向","已投保"]）
customer_level   VARCHAR(2)  客户等级（A/B/C/D，初始为D，由系统评分计算）
total_premium    DECIMAL     累计保费（初始0，有订单后更新）
policy_count     INT         保单数量（初始0）
last_follow_time DATETIME    最后跟进时间（初始为创建时间）
next_follow_time DATETIME    下次跟进时间
remark           TEXT        备注
-- 框架标准字段
creator          VARCHAR(64)
create_time      DATETIME
updater          VARCHAR(64)
update_time      DATETIME
deleted          TINYINT
tenant_id        BIGINT
```

---

### M4-F3 客户详情（360度画像）

#### 业务流程

点击客户卡片，进入客户详情页。页面采用 Tab 结构：

**Tab1：基本信息**
- 头像 + 姓名（大字体）
- 基础字段展示（手机号脱敏/生日/职业/地址等）
- 右上角【编辑】按钮

**Tab2：跟进记录**
- 时间轴形式展示所有跟进记录（最新在上）
- 每条记录：跟进方式图标 + 跟进时间 + 跟进内容摘要（超100字截断显示"展开"）
- 右下角浮动【+ 添加跟进】按钮
- 若有附件（图片/文件），以缩略图展示

**Tab3：保障清单**
- 该客户名下的所有订单列表（关联 ins_order 表，`customer_id = 当前客户ID`）
- 每条展示：产品名称/保额/保费/承保日期/保单状态

**Tab4：计划书记录**
- 该业务员为该客户制作的所有计划书（关联 ins_proposal 表）
- 点击可查看计划书详情

**Tab5：标签管理**
- 展示当前标签，点击可添加/删除标签

---

### M4-F4 客户标签

#### 业务流程

**标签来源：**
- 系统预置标签：已投保/有意向/犹豫中/无意向/老客户/高净值/转介绍
- 业务员自定义标签：在标签管理页面创建

**打标签操作（两个入口）：**
1. 客户详情 Tab5 点击【+ 添加标签】；
2. 客户列表长按客户卡片 → 弹出"批量打标签"。

**批量打标签流程：**
1. 长按客户卡片，进入多选模式；
2. 勾选多个客户；
3. 底部弹出操作栏，点击【打标签】；
4. 弹出标签选择弹窗（多选）；
5. 确认后，选中的标签追加到所有勾选客户的 `tags` 字段（JSON数组去重合并）。

**后端接口：**
- 更新单客户标签：`PUT /insurance/customer/{id}/tags`，Body: `{"tags": ["有意向","高净值"]}`
- 批量打标签：`POST /insurance/customer/batch/tags`，Body: `{"customerIds":[1,2,3], "tags":["有意向"]}`

**后端处理逻辑（批量打标签）：**
1. 校验 customerIds 全部属于当前 agent_id；
2. 每个客户：先查当前 tags JSON，将新标签追加进去（Set去重），再 UPDATE；
3. 批量更新限制：单次最多50个客户。

---

### M4-F5 跟进记录

#### 业务流程

**添加跟进记录入口：**
- 客户详情 Tab2 底部浮动按钮【+ 添加跟进】；
- 点击后从底部弹出"添加跟进"半屏弹窗。

**弹窗字段：**

| 字段 | 必填 | 校验规则 |
|---|---|---|
| 跟进方式 | 是 | 单选：电话 / 微信 / 面访 / 其他 |
| 跟进时间 | 是 | 默认当前时间，可修改；不得晚于当前时间（不允许记录未来的跟进） |
| 跟进内容 | 是 | 文本域，10-500字 |
| 下次跟进时间 | 否 | 日期时间选择器；必须晚于跟进时间 |
| 附件 | 否 | 可上传图片（最多9张，单张<5MB）或文档（PDF/Word，单个<10MB） |

**提交后端处理：**
1. 插入 `ins_customer_follow` 记录；
2. 更新 `ins_customer` 的 `last_follow_time = 当前时间`；
3. 若填写了下次跟进时间，更新 `ins_customer.next_follow_time`；
4. 若附件不为空，上传文件到 OSS，将 OSS URL 存入 `attachments` JSON 字段。

**ins_customer_follow 入库字段：**
```
id               BIGINT
customer_id      BIGINT     关联客户ID
agent_id         BIGINT     操作业务员ID（当前用户）
follow_type      TINYINT    1-电话 2-微信 3-面访 4-其他
follow_content   TEXT       跟进内容（明文存储）
follow_time      DATETIME   跟进时间
next_follow_time DATETIME   下次计划跟进时间
attachments      JSON       附件列表，格式：[{"type":"image","url":"xxx","name":"xxx"}]
create_time      DATETIME
```

---

### M4-F6 跟进提醒

#### 业务流程

当业务员设置了"下次跟进时间"后，系统在该时间当天早上9点推送 App 消息通知。

**消息内容格式：** "您有客户待跟进：张三（下次跟进时间：今天）"

**提醒规则（定时任务，每日 8:55 执行）：**
1. 查询 `ins_customer` 表中 `DATE(next_follow_time) = CURDATE() AND deleted=0`；
2. 按 `agent_id` 分组，每个业务员合并一条提醒（"您有N位客户今日待跟进"）；
3. 通过 `ins_message` 消息中心表插入消息，App 端通过轮询或 WebSocket 接收。

**超期提醒（另一个定时任务，每日 9:00 执行）：**
1. 查询 `next_follow_time < CURDATE() AND deleted=0`，且最近7天内未推过超期提醒的客户；
2. 推送提醒："您有N位客户跟进已超期，请尽快联系"；
3. 避免每日重复推送：`ins_remind_log` 表记录推送记录，同一客户超期提醒每3天最多1次。

---

### M4-F7 客户导入（Excel）

#### 业务流程

**入口：** 客户列表右上角菜单 → 【批量导入】。

**导入步骤：**

**Step 1：下载模板**
- 页面提供"下载导入模板"按钮；
- 模板为 Excel 文件，包含列：姓名/手机号/性别/出生日期/职业/省份/城市/客户来源/备注/标签（逗号分隔）；
- 模板第一行为标题行，第二行为示例数据行。

**Step 2：选择文件上传**
- 支持 .xlsx / .xls 格式；
- 文件大小限制：10MB 以内；
- 上传成功后前端展示"解析中..."提示。

**Step 3：数据预览与校验**
- 后端解析 Excel，返回解析结果预览；
- 页面展示表格：每行数据 + 校验状态（✅通过 / ❌有误，显示具体错误原因）；
- 错误类型包括：
  - 姓名为空
  - 手机号格式错误
  - 手机号与已有客户重复（标注"该手机号已存在，跳过"）
  - 出生日期格式错误
- 业务员可查看错误行并决定：忽略错误行仅导入正确行 / 取消导入去修改文件。

**Step 4：确认导入**
- 点击【确认导入】，后端批量插入校验通过的记录；
- 返回导入结果：成功 N 条，跳过 M 条（手机号重复），失败 X 条（数据错误）；
- 导入成功的客户自动设置 `source = "批量导入"`，`agent_id = 当前业务员ID`。

**后端接口：**
- 上传解析：`POST /insurance/customer/import/parse`，multipart/form-data
- 确认导入：`POST /insurance/customer/import/confirm`，Body: `{"importTaskId": "xxx"}`

**后端处理逻辑（confirm）：**
1. 从 Redis 读取 importTaskId 对应的解析结果（TTL 30分钟）；
2. 过滤掉标记为"重复"和"错误"的行；
3. 批量插入（每次500条）`ins_customer` 表；
4. 手机号加密 + hash 处理同单条新增；
5. 导入完成后返回汇总结果，并清除 Redis 中的临时数据。

---

### M4-F8 客户分组

#### 业务流程

**功能定位：** 业务员对客户进行自由分组管理（如"家庭保障组"、"年金客户组"、"待跟进组"）。

**分组管理：**
- 入口：客户列表顶部"分组"筛选器旁边的"管理分组"入口；
- 可以新建/重命名/删除分组；
- 删除分组不删除客户，只清空客户的 group_id 字段（置为null）；
- 每个业务员最多创建20个分组。

**将客户加入分组（两种方式）：**
1. 进入客户详情，编辑"所属分组"字段；
2. 客户列表多选后，底部操作栏点击【移入分组】。

**ins_customer_group 表：**
```
id            BIGINT
agent_id      BIGINT      业务员ID
name          VARCHAR(50) 分组名称
customer_count INT DEFAULT 0  该分组客户数（冗余字段，新增/删除客户时更新）
sort_order    INT DEFAULT 0
create_time   DATETIME
```

---

## 数据库核心表设计（M3、M4）

### ins_proposal（计划书表）

```sql
CREATE TABLE ins_proposal (
  id               BIGINT NOT NULL AUTO_INCREMENT,
  proposal_no      VARCHAR(32) NOT NULL COMMENT '计划书编号，如PS202502180001',
  agent_id         BIGINT NOT NULL,
  customer_id      BIGINT COMMENT '关联客户ID，可空',
  template_id      BIGINT,
  title            VARCHAR(100) NOT NULL COMMENT '计划书标题',
  applicant_name   VARCHAR(50),
  applicant_age    INT,
  insured_name     VARCHAR(50) NOT NULL,
  insured_birthday DATE NOT NULL,
  insured_age      INT COMMENT '计算值，当前周岁',
  insured_gender   TINYINT NOT NULL COMMENT '1男2女',
  products         JSON NOT NULL COMMENT '产品方案数组',
  total_premium    DECIMAL(15,2) COMMENT '合计年缴保费',
  coverage_summary JSON COMMENT '保障责任汇总',
  cash_value_table JSON COMMENT '现金价值表（仅储蓄型）',
  hidden_coverages JSON COMMENT '业务员选择隐藏的责任项',
  pdf_url          VARCHAR(500) COMMENT 'PDF文件OSS地址',
  h5_url           VARCHAR(500) COMMENT 'H5分享链接',
  h5_token         VARCHAR(64)  COMMENT 'H5访问Token',
  qr_code          VARCHAR(500) COMMENT '二维码图片OSS地址',
  view_count       INT DEFAULT 0 COMMENT '客户查看次数',
  status           TINYINT DEFAULT 1 COMMENT '1-草稿 2-已生成 3-已分享',
  remark           VARCHAR(500),
  creator          VARCHAR(64) DEFAULT '',
  create_time      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updater          VARCHAR(64) DEFAULT '',
  update_time      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted          TINYINT DEFAULT 0,
  tenant_id        BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_proposal_no (proposal_no),
  KEY idx_agent_customer (agent_id, customer_id),
  KEY idx_agent_status_time (agent_id, status, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保障计划书';
```

### ins_customer（客户表）

```sql
CREATE TABLE ins_customer (
  id               BIGINT NOT NULL AUTO_INCREMENT,
  customer_no      VARCHAR(32) NOT NULL,
  agent_id         BIGINT NOT NULL,
  name             VARCHAR(50) NOT NULL,
  mobile           VARCHAR(300) NOT NULL COMMENT '手机号AES密文',
  mobile_hash      VARCHAR(64)  NOT NULL COMMENT '手机号SHA256，用于搜索',
  id_card          VARCHAR(300) COMMENT '身份证AES密文',
  id_card_last4    VARCHAR(4)   COMMENT '身份证后4位',
  gender           TINYINT,
  birthday         DATE,
  age              INT COMMENT '当前周岁，定时任务每年1月1日更新',
  occupation       VARCHAR(100),
  occupation_class TINYINT,
  province         VARCHAR(20),
  city             VARCHAR(20),
  address          VARCHAR(200),
  wechat           VARCHAR(50),
  email            VARCHAR(100),
  source           VARCHAR(50),
  group_id         BIGINT COMMENT '客户分组ID',
  tags             JSON COMMENT '标签数组，如["有意向","高净值"]',
  customer_level   VARCHAR(2) DEFAULT 'D' COMMENT 'A/B/C/D 客户等级',
  rfm_score        DECIMAL(4,2) COMMENT 'RFM综合评分',
  total_premium    DECIMAL(15,2) DEFAULT 0,
  policy_count     INT DEFAULT 0,
  last_follow_time DATETIME,
  next_follow_time DATETIME,
  remark           TEXT,
  creator          VARCHAR(64) DEFAULT '',
  create_time      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updater          VARCHAR(64) DEFAULT '',
  update_time      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted          TINYINT DEFAULT 0,
  tenant_id        BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_customer_no (customer_no),
  KEY idx_agent_id (agent_id),
  KEY idx_mobile_hash (mobile_hash),
  KEY idx_agent_next_follow (agent_id, next_follow_time),
  KEY idx_agent_level (agent_id, customer_level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户表';
```

### ins_customer_follow（跟进记录表）

```sql
CREATE TABLE ins_customer_follow (
  id               BIGINT NOT NULL AUTO_INCREMENT,
  customer_id      BIGINT NOT NULL,
  agent_id         BIGINT NOT NULL,
  follow_type      TINYINT NOT NULL COMMENT '1-电话 2-微信 3-面访 4-其他',
  follow_content   TEXT NOT NULL,
  follow_time      DATETIME NOT NULL,
  next_follow_time DATETIME,
  attachments      JSON COMMENT '附件列表，[{type,url,name,size}]',
  create_time      DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_customer_id (customer_id),
  KEY idx_agent_time (agent_id, follow_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户跟进记录';
```

---

## 工时估算（M3+M4）

| 模块 | 功能点 | 前端工时 | 后端工时 | 合计 |
|---|---|---|---|---|
| M3 计划书 | 模板选择 | 1天 | 0.5天 | 1.5天 |
| M3 计划书 | 方案配置（主险+附加险） | 2天 | 1天 | 3天 |
| M3 计划书 | 保障演示（责任汇总） | 1天 | 1天 | 2天 |
| M3 计划书 | 现金价值表 | 1天 | 1天 | 2天 |
| M3 计划书 | PDF生成（异步+轮询） | 0.5天 | 2天 | 2.5天 |
| M3 计划书 | H5分享+二维码 | 1天 | 1天 | 2天 |
| M3 计划书 | 查看追踪 | 0.5天 | 0.5天 | 1天 |
| M4 CRM | 客户列表（搜索/筛选/分页） | 1.5天 | 0.5天 | 2天 |
| M4 CRM | 新增/编辑客户（加密处理） | 1.5天 | 1天 | 2.5天 |
| M4 CRM | 客户详情（360画像多Tab） | 2天 | 1天 | 3天 |
| M4 CRM | 客户标签（批量打标签） | 1天 | 1天 | 2天 |
| M4 CRM | 跟进记录（附件上传） | 1天 | 0.5天 | 1.5天 |
| M4 CRM | 跟进提醒（定时任务） | 0.5天 | 1天 | 1.5天 |
| M4 CRM | Excel批量导入 | 1天 | 1天 | 2天 |
| M4 CRM | 客户分组 | 0.5天 | 0.5天 | 1天 |
| **合计** | | **16天** | **13天** | **29天** |

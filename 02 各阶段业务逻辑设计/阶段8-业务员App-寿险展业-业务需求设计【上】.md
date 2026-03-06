# 阶段8 - 业务员App - 寿险展业 业务需求设计文档【上篇】

> 版本：V1.0  
> 模块范围：寿险产品展业（产品列表、产品详情、保费试算、计划书制作）  
> 对应工程：`intermediary-module-ins-product` + `intermediary-module-ins-marketing`  
> 前端工程：`intermediary-ui-agent-uniapp`（uni-app，复用已有非车险展业组件）

---

## 一、模块概览

| 功能点 | 前端工时 | 后端工时 | 负责人 |
|--------|---------|---------|--------|
| 寿险产品列表 | 1.5天 | 1天 | 前端1+后端1 |
| 寿险产品详情 | 1.5天 | 0.5天 | 前端1+后端1 |
| 寿险保费试算 | 1.5天 | 0.5天 | 前端1+后端1 |
| 寿险计划书制作 | 2天 | 1.5天 | 前端1+后端1 |

---

## 二、寿险产品列表

### 2.1 页面入口

业务员 App 底部导航栏 → 点击【产品】→ 顶部 Tab 切换，新增【寿险】Tab（原有：全部、车险、非车险）。

### 2.2 页面展示逻辑

**Tab 结构（寿险 Tab 内的二级 Tab）：**

| Tab名称 | 对应 `life_type` 枚举值 |
|---------|----------------------|
| 全部 | 不过滤 |
| 个险 | `INDIVIDUAL` |
| 团险 | `GROUP` |
| 储蓄险 | `SAVINGS` |
| 保障险 | `PROTECTION` |

切换 Tab 时重置列表数据、清空搜索关键词，重新调用列表接口。

**产品卡片字段（每张卡片展示）：**

| 字段 | 来源 | 说明 |
|------|------|------|
| 产品名称 | `ins_life_product.name` | 主标题 |
| 产品简称 | `ins_life_product.short_name` | 副标题，较小字体 |
| 保险公司 | 关联 `ins_insurer.name` | 左下角 |
| 险种类型标签 | `ins_life_product.life_type` | 右上角彩色标签（个险/团险/储蓄险/保障险） |
| 保障期限 | `ins_life_product.coverage_period` | 如：终身、20年、至60岁 |
| 缴费期限 | `ins_life_product.payment_period` | 如：10年、20年、趸缴 |
| 佣金率 | `ins_life_product.commission_rate`（当前登录业务员的基础佣金率） | 右下角，格式：佣金 XX% |
| 产品封面图 | `ins_life_product.cover_image_url` | 卡片左侧小图 |
| 收藏状态 | `ins_agent_product_collect` 表 | 右上角爱心图标，已收藏填充红色 |

**上拉加载：** 每页 20 条，`pageNo` 从 1 开始，`pageSize=20`，上拉触发加载下一页，无更多数据时显示"已全部加载"。

**搜索栏：** 页面顶部搜索框，关键词匹配产品名称、产品简称（后端 `LIKE` 查询），实时搜索（用户停止输入 500ms 后触发，前端防抖）。

**筛选按钮：** 搜索栏右侧【筛选】图标，点击弹出底部抽屉，筛选项如下：

| 筛选项 | 控件类型 | 后端字段 |
|--------|---------|---------|
| 保险公司 | 多选（从 `ins_insurer` 表读取寿险相关保司列表） | `insurer_ids` |
| 缴费方式 | 单选（年缴/月缴/趸缴/季缴） | `payment_mode` |
| 是否收藏 | 开关 | `collected_only` |

点击【重置】清空筛选条件，点击【确定】关闭抽屉并刷新列表。

**停售产品处理：** `product_status = DISCONTINUED` 的产品仍展示在列表中，但卡片整体灰色半透明，右上角显示"已停售"红色角标，无法点击收藏，点击卡片仍可进入详情（详情页操作按钮隐藏）。

### 2.3 收藏/取消收藏

- 点击卡片右上角爱心图标（不触发卡片跳转），乐观更新 UI 状态（先改 icon 再请求接口）。
- 收藏成功：写入 `ins_agent_product_collect` 表（`agent_id`, `product_id`, `product_type=LIFE`, `created_time`）。
- 取消收藏：软删除（`deleted=1`）。
- 接口幂等，重复收藏不报错。

### 2.4 接口定义

**GET** `/app-api/ins/life/product/page`

请求参数：

```
lifeType      String    险种类型（INDIVIDUAL/GROUP/SAVINGS/PROTECTION），可空
keyword       String    搜索关键词，可空
insurerIds    Long[]    保司ID数组，可空
paymentMode   String    缴费方式，可空
collectedOnly Boolean   仅显示收藏，可空
pageNo        int       页码，默认1
pageSize      int       每页条数，默认20
```

响应字段：

```json
{
  "total": 100,
  "list": [
    {
      "productId": 1,
      "name": "平安福2024",
      "shortName": "平安福",
      "insurerName": "中国平安",
      "lifeType": "INDIVIDUAL",
      "lifeTypeLabel": "个险",
      "coveragePeriod": "终身",
      "paymentPeriod": "20年",
      "commissionRate": 0.15,
      "coverImageUrl": "https://...",
      "productStatus": "ON_SALE",
      "collected": false
    }
  ]
}
```

**后端查询逻辑：**

1. 从 `ins_life_product` 表按条件查询（状态不过滤停售，均返回）。
2. 查当前登录业务员（`agent_id` 从 token 解析）对应的佣金率：查 `ins_life_rate_policy` 表，匹配业务员所在机构+保司+产品的基础费率；无匹配时返回产品默认费率 `ins_life_product.default_commission_rate`。
3. 查询 `ins_agent_product_collect` 表，标记收藏状态。
4. 若 `collectedOnly=true`，JOIN `ins_agent_product_collect` 过滤。

---

## 三、寿险产品详情

### 3.1 页面入口

产品列表页点击产品卡片（停售产品同样可点击）→ 进入产品详情页。

### 3.2 页面结构

页面顶部固定区域显示产品名称、保司、险种类型标签。

**多 Tab 展示（横向滑动切换）：**

| Tab | 内容来源 | 说明 |
|-----|---------|------|
| 产品亮点 | `ins_life_product.highlight_json` | JSON 数组，每项含标题+内容，前端渲染富文本 |
| 保障责任 | `ins_life_product.coverage_json` | JSON 数组，每项含险种项目名称+保额说明+理赔条件 |
| 费率说明 | `ins_life_product.rate_desc` | 富文本（含费率表图片或JSON费率表格） |
| 投保须知 | `ins_life_product.notice_text` | 纯文本或富文本 |
| 健康告知 | `ins_life_product.health_notice_json` | JSON 数组，每项问题；风险问题高亮红色 |
| FAQ | `ins_life_product.faq_json` | JSON 数组，每项含问题+答案，可展开收起 |

**费率表展示规则（"费率说明" Tab）：**

若 `ins_life_product.rate_table_type = JSON_TABLE`，则解析 `ins_life_product.rate_table_json` 渲染为表格：

表格维度：行=年龄，列=性别×缴费期×保额，单元格值=对应保费（元/年）。

示例数据结构（`rate_table_json`）：
```json
{
  "dimensions": ["age", "gender", "payment_period", "sum_insured"],
  "data": [
    {"age": 20, "gender": "M", "payment_period": 10, "sum_insured": 100000, "premium": 1200},
    {"age": 20, "gender": "F", "payment_period": 10, "sum_insured": 100000, "premium": 1100}
  ]
}
```

前端根据 `dimensions` 决定表头分组方式，展示为二维表格，支持左右横向滚动。

**健康告知 Tab 展示规则：**

解析 `health_notice_json` 数组，每项字段：

```json
{
  "seq": 1,
  "question": "过去两年内是否曾住院治疗？",
  "riskLevel": "HIGH",     // HIGH=红色高亮，MEDIUM=橙色，LOW=普通
  "inputType": "RADIO",    // RADIO/CHECKBOX/TEXT
  "options": ["是", "否"]
}
```

`riskLevel=HIGH` 的问题前端红色字体加粗显示，并在该行右侧展示"⚠️ 投保风险"角标。

**停售产品：** 所有 Tab 正常展示，但页面底部操作按钮区域**完全隐藏**（不显示"保费试算"和"制作计划书"按钮）。

### 3.3 页面底部固定操作区

在售产品底部固定显示两个按钮：

| 按钮 | 操作 |
|------|------|
| 【保费试算】 | 跳转"寿险保费试算"页，携带 `productId` |
| 【制作计划书】 | 跳转"寿险计划书制作"页，携带 `productId`（不需先试算，可直接制作） |

### 3.4 接口定义

**GET** `/app-api/ins/life/product/detail/{productId}`

响应字段（完整数据）：

```json
{
  "productId": 1,
  "name": "平安福2024",
  "shortName": "平安福",
  "insurerName": "中国平安",
  "insurerLogoUrl": "https://...",
  "lifeType": "INDIVIDUAL",
  "coveragePeriod": "终身",
  "paymentPeriod": "20年",
  "paymentMode": ["ANNUAL", "MONTHLY"],
  "minAge": 18,
  "maxAge": 55,
  "minSumInsured": 100000,
  "maxSumInsured": 5000000,
  "sumInsuredStep": 100000,
  "isFixedStep": true,
  "productStatus": "ON_SALE",
  "highlightJson": [...],
  "coverageJson": [...],
  "rateDesc": "...",
  "rateTableType": "JSON_TABLE",
  "rateTableJson": {...},
  "noticeText": "...",
  "healthNoticeJson": [...],
  "faqJson": [...],
  "commissionRate": 0.15,
  "collected": false
}
```

**后端逻辑：** 从 `ins_life_product` 表查询，拼装佣金率、收藏状态，直接返回，无复杂计算。接口使用 Redis 缓存（`ins_life_product:{productId}`，TTL 30分钟），产品数据被后台修改时主动 evict。

---

## 四、寿险保费试算

### 4.1 页面结构

进入页面后顶部展示产品名称+保司名称（只读），下方为试算表单。

**表单字段：**

| 字段 | 控件类型 | 必填 | 校验规则 |
|------|---------|------|---------|
| 投保人年龄 | 数字输入框（整数） | 是 | 必须在 `min_age` ~ `max_age` 范围内，超出范围时输入框下方红字提示"该产品投保年龄为X-X岁" |
| 性别 | 单选（男/女） | 是 | 无 |
| 是否吸烟 | 单选（是/否） | 部分产品必填 | 产品 `health_factors` 含 `SMOKING` 时必填 |
| 缴费方式 | 单选（年缴/月缴/季缴/趸缴） | 是 | 只展示该产品支持的缴费方式（`paymentMode` 数组） |
| 缴费期限 | 单选 | 是 | 只展示该产品支持的缴费期限（如：10年/20年/30年/终身缴） |
| 保额 | 若 `isFixedStep=true`：下拉选档位；若 `isFixedStep=false`：数字输入框 | 是 | 固定档位：从 `sumInsuredOptions` 数组选择；自由输入：须是 `sumInsuredStep` 的整数倍，且在 `minSumInsured` ~ `maxSumInsured` 范围内 |

**实时试算触发规则：** 上述所有必填字段全部有值后，自动触发试算（不需点击按钮），接口返回前展示 loading 骨架。

**试算结果展示区（在表单下方）：**

| 展示项 | 说明 |
|--------|------|
| 年缴保费 | XX元/年 |
| 月缴保费 | XX元/月（若缴费方式选择年缴，同时展示月缴参考值） |
| 首期保费 | XX元（=年缴保费，趸缴时等于总保费） |
| 保费总额 | XX元（=年缴×缴费年数，终身缴显示"趸缴金额"或不显示） |

结果区右下角展示【一键制作计划书】按钮，点击携带当前试算参数跳转计划书制作页。

### 4.2 保费试算接口

**POST** `/app-api/ins/life/product/calculate`

请求体：

```json
{
  "productId": 1,
  "age": 30,
  "gender": "M",
  "smoking": false,
  "paymentMode": "ANNUAL",
  "paymentPeriod": 20,
  "sumInsured": 500000
}
```

**后端计算逻辑：**

1. 从 `ins_life_product` 表取产品信息，校验产品状态（非 `ON_SALE` 则返回 403）。
2. 参数合法性校验：
   - `age` 在 `[min_age, max_age]` 范围；
   - `paymentMode` 在 `paymentMode` 数组中；
   - `paymentPeriod` 在产品允许期限中；
   - `sumInsured` 满足步长和范围。
3. 调用 Groovy 试算引擎（与非车险 `InsProductRateService.calculatePremium()` 相同入口，险种字段传 `LIFE`）：
   - 引擎从 Redis 缓存读取费率表（缓存键：`rate:{productId}:{age}:{gender}:{smoking}:{paymentPeriod}`）；
   - 缓存命中直接返回；缓存未命中则查 `ins_product_rate` 表，用 Groovy 脚本计算，写入 Redis（TTL 1小时）。
4. 返回年缴保费、月缴保费（年缴÷12，保留2位小数）、总保费。

响应体：

```json
{
  "annualPremium": 12000.00,
  "monthlyPremium": 1000.00,
  "firstPremium": 12000.00,
  "totalPremium": 240000.00,
  "calcParams": {
    "productId": 1,
    "age": 30,
    "gender": "M",
    "smoking": false,
    "paymentMode": "ANNUAL",
    "paymentPeriod": 20,
    "sumInsured": 500000
  }
}
```

`calcParams` 原样返回供前端跳转计划书页时透传。

---

## 五、寿险计划书制作

### 5.1 页面入口与数据初始化

两种入口：

- 从"产品详情"底部点击【制作计划书】进入：不携带试算参数，页面进入"编辑客户信息+选择方案"状态。
- 从"保费试算"点击【一键制作计划书】进入：携带 `calcParams`，自动填充方案参数，跳过填写保费参数步骤。

### 5.2 页面填写内容

**第一步：客户信息（必填）**

| 字段 | 控件 | 必填 | 说明 |
|------|------|------|------|
| 客户姓名 | 文本输入框 | 是 | 计划书封面显示 |
| 客户年龄 | 数字输入框 | 是 | 用于费率联动 |
| 客户性别 | 单选 | 是 | |
| 客户手机号 | 数字输入框 | 否 | 用于后续联系 |

填写完成点击【下一步】，客户信息字段不做数据库存储（仅用于生成计划书内容）。

**第二步：保障方案（至少填写一个方案）**

支持添加多个保障方案进行对比（最多3个），每个方案包含：

| 字段 | 控件 | 必填 |
|------|------|------|
| 方案名称 | 文本输入框（默认"方案一/二/三"） | 是 |
| 保额 | 数字输入/下拉选档位（同试算页逻辑） | 是 |
| 缴费期限 | 单选 | 是 |
| 缴费方式 | 单选 | 是 |
| 保费（自动计算） | 只读，调试算接口实时计算填充 | — |

点击【添加方案对比】增加方案行，点击每行右侧【删除】移除该方案（最少保留1个）。

**第三步：确认并生成**

点击【生成计划书】按钮，展示 loading（生成时间预计 3-8 秒）。

### 5.3 计划书内容结构

后端生成计划书（PDF + H5 两种格式），内容结构如下：

| 页面 | 内容 |
|------|------|
| 封面页 | 计划书标题（"[产品名称]保障计划"）、业务员姓名+工号+联系电话+头像、客户姓名、生成日期、公司LOGO |
| 客户信息页 | 客户姓名、年龄、性别 |
| 保障责任页 | 从 `ins_life_product.coverage_json` 渲染，表格展示各保障项目及保额 |
| 费率方案对比页 | 多方案横向对比表格（方案名称、保额、缴费期、年缴保费、月缴保费、总保费） |
| 健康告知摘要页 | 从 `ins_life_product.health_notice_json` 提取标题列表（不含风险判断，只列问题） |
| 服务承诺页 | 固定内容（从系统配置 `ins_plan_service_promise` 读取） |

### 5.4 生成计划书接口

**POST** `/app-api/ins/life/plan/create`

请求体：

```json
{
  "productId": 1,
  "customerName": "张三",
  "customerAge": 30,
  "customerGender": "M",
  "customerPhone": "13800138000",
  "schemes": [
    {
      "schemeName": "方案一",
      "sumInsured": 500000,
      "paymentPeriod": 20,
      "paymentMode": "ANNUAL",
      "annualPremium": 12000.00,
      "monthlyPremium": 1000.00,
      "totalPremium": 240000.00
    },
    {
      "schemeName": "方案二",
      "sumInsured": 1000000,
      "paymentPeriod": 20,
      "paymentMode": "ANNUAL",
      "annualPremium": 24000.00,
      "monthlyPremium": 2000.00,
      "totalPremium": 480000.00
    }
  ]
}
```

**后端处理逻辑：**

1. 校验 `productId` 存在且状态为 `ON_SALE`；校验 `schemes` 不为空（最多3个）。
2. 从当前 token 取业务员信息（姓名、工号、手机号、头像URL）。
3. 调用 `InsLifePlanGenerateService.generate()`：
   - 拼装 PDF 模板数据（使用 iText7，模板路径：`/template/life_plan_{productType}.pdf`，寿险专属模板，区别于非车险计划书模板）；
   - 生成 PDF 文件，上传至 OSS，返回 URL；
   - 生成 H5 分享链接：写入 `ins_life_plan` 表，生成 UUID 作为 `share_token`，H5 路径为 `/h5/life-plan/{share_token}`，有效期 30天（`expire_time = now + 30days`）；
   - H5 链接写入 Redis 缓存（`life_plan_share:{share_token}`，TTL 30天）。
4. 写入 `ins_life_plan` 表记录（字段见下）。

**`ins_life_plan` 表（`db_ins_marketing`库）：**

```sql
CREATE TABLE ins_life_plan (
  id            BIGINT      PRIMARY KEY AUTO_INCREMENT,
  agent_id      BIGINT      NOT NULL COMMENT '业务员ID',
  product_id    BIGINT      NOT NULL COMMENT '产品ID',
  product_name  VARCHAR(100) NOT NULL COMMENT '产品名称快照',
  customer_name VARCHAR(50) NOT NULL COMMENT '客户姓名',
  customer_age  INT         NOT NULL,
  customer_gender CHAR(1)   NOT NULL,
  customer_phone  VARCHAR(20),
  schemes_json  JSON        NOT NULL COMMENT '方案列表JSON',
  pdf_url       VARCHAR(500) COMMENT 'OSS PDF地址',
  share_token   VARCHAR(64)  NOT NULL COMMENT 'H5分享token',
  expire_time   DATETIME    NOT NULL COMMENT 'H5链接过期时间',
  view_count    INT         DEFAULT 0 COMMENT '客户查看次数',
  created_time  DATETIME    NOT NULL,
  creator       BIGINT      NOT NULL,
  deleted       BIT(1)      DEFAULT 0,
  INDEX idx_agent_id (agent_id),
  INDEX idx_share_token (share_token)
) COMMENT='寿险计划书';
```

响应体：

```json
{
  "planId": 100,
  "pdfUrl": "https://oss.../life_plan_100.pdf",
  "shareUrl": "https://h5.domain.com/life-plan/abc123def",
  "expireTime": "2026-03-27 14:00:00"
}
```

### 5.5 生成后操作

**App 展示结果页：**

| 操作 | 说明 |
|------|------|
| 【下载PDF】 | 打开浏览器下载 `pdfUrl` |
| 【分享给客户】 | 调起微信分享，`shareUrl` 作为链接，标题为"[客户姓名]的专属保障计划书" |
| 【复制链接】 | 复制 `shareUrl` 到剪贴板 |
| 【重新编辑】 | 返回上一步，不删除已生成记录 |

**H5 页面（`/h5/life-plan/{share_token}`）：**

客户打开 H5 链接时：
1. 后端查 Redis / `ins_life_plan` 表，验证 `share_token` 有效且未过期；
2. 过期则展示"该计划书已失效，请联系业务员"；
3. 有效则展示计划书内容（客户姓名、产品信息、方案对比、保障责任）；
4. 每次访问后端 +1 `view_count`，业务员可在"我的计划书"列表看到查看次数；
5. H5 底部固定按钮【立即咨询】→ 展示业务员微信二维码或拨打电话。

---

## 六、数据库表补充说明

### 寿险产品表关键字段（`ins_life_product`，属于 `db_ins_product` 库）

```sql
CREATE TABLE ins_life_product (
  id                   BIGINT      PRIMARY KEY AUTO_INCREMENT,
  product_id           BIGINT      NOT NULL COMMENT '关联ins_product_info.id',
  life_type            VARCHAR(20) NOT NULL COMMENT '个险/团险/储蓄险/保障险：INDIVIDUAL/GROUP/SAVINGS/PROTECTION',
  coverage_period      VARCHAR(50) COMMENT '保障期限，如：终身、20年',
  payment_period_options JSON      COMMENT '支持的缴费期限列表，如：[10,20,30]，终身缴用999',
  payment_mode         JSON        COMMENT '支持的缴费方式列表：[ANNUAL,MONTHLY,QUARTERLY,LUMP_SUM]',
  min_age              INT         COMMENT '最小投保年龄',
  max_age              INT         COMMENT '最大投保年龄',
  min_sum_insured      DECIMAL(15,2),
  max_sum_insured      DECIMAL(15,2),
  sum_insured_step     DECIMAL(15,2) COMMENT '保额步长，0表示固定档位',
  is_fixed_step        TINYINT(1)  DEFAULT 0,
  sum_insured_options  JSON        COMMENT '固定档位时的保额列表',
  health_factors       JSON        COMMENT '影响费率的健康因子：[SMOKING,OCCUPATION]',
  default_commission_rate DECIMAL(6,4) COMMENT '默认佣金率',
  highlight_json       JSON,
  coverage_json        JSON,
  rate_desc            TEXT,
  rate_table_type      VARCHAR(20) COMMENT 'JSON_TABLE/IMAGE/TEXT',
  rate_table_json      JSON,
  notice_text          TEXT,
  health_notice_json   JSON,
  faq_json             JSON,
  product_status       VARCHAR(20) NOT NULL DEFAULT 'ON_SALE' COMMENT 'ON_SALE/DISCONTINUED',
  cover_image_url      VARCHAR(500),
  created_time         DATETIME    NOT NULL,
  updated_time         DATETIME    NOT NULL,
  deleted              BIT(1)      DEFAULT 0,
  INDEX idx_product_id (product_id),
  INDEX idx_life_type (life_type),
  INDEX idx_product_status (product_status)
) COMMENT='寿险产品扩展表';
```

---

> 【下篇】将覆盖：寿险保单管理（App端个险保单录入、我的寿险保单）、续期提醒与跟踪  
> 【下篇】将覆盖：寿险客户管理（客户列表、客户详情）

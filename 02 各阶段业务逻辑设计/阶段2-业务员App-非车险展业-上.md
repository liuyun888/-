# 阶段2-B端业务员App-非车险展业 详细功能设计文档（上）

> **项目：** 保险中介全域数字化平台  
> **模块：** 业务员App - 非车险展业  
> **技术栈：** yudao-cloud（Spring Cloud Alibaba + Vue3）  
> **文档版本：** v3.0（业务逻辑重写版）  
> **适用读者：** 前端开发工程师、后端开发工程师  
> **涵盖模块：** M1-产品库 · M2-保费试算

---

## 说明

本文档以**业务流程 + 交互细节 + 字段校验 + 入库规则**为核心，替代原文档中大量代码示例与架构图。开发人员应依据本文档直接进行编码，如有接口细节或表结构疑问，以本文为准。

---

## M1 产品库

### M1-F1 产品列表

#### 业务流程

业务员进入"产品库"Tab页，默认加载当前平台所有**在售（status=1）**的非车险产品，按销量降序排列。

**页面布局：**

顶部为筛选栏（横向可滚动）：险种分类 / 保险公司 / 保障期限 / 缴费期限 / 年龄段 / 排序方式。

产品以**卡片列表**方式展示，每张卡片显示：
- 保险公司Logo + 产品名称
- 险种标签（重疾险/医疗险/意外险/年金险/寿险）
- 核心亮点（最多3条，从 `product_highlights` JSON数组取前3项）
- 保障期限 + 缴费期限
- 月/年均保费（参考价，取30岁男性50万保额默认试算结果）
- 佣金率徽标（如"首年60%"，仅业务员可见）
- 热销角标（`sales_count >= 100` 时展示）
- 高佣角标（`commission_rate >= 0.6` 时展示）

列表底部支持上拉加载更多（分页大小默认20条）。

**筛选逻辑：**

| 筛选项 | 可选值 | 后端处理 |
|---|---|---|
| 险种分类 | 重疾险/医疗险/意外险/年金险/寿险 | `WHERE category_id = ?` |
| 保险公司 | 下拉多选 | `WHERE insurance_company_id IN (?)` |
| 保障期限 | 终身/至70岁/20年/10年 | `WHERE coverage_period = ?` |
| 缴费期限 | 趸交/5年/10年/20年/30年 | `WHERE payment_period = ?` |
| 年龄段 | 0-17/18-40/41-60 | `WHERE min_age <= ? AND max_age >= ?` |
| 排序 | 热销优先/佣金高优先/保费低优先 | `ORDER BY sales_count/commission_rate/reference_premium` |

筛选联动规则：
- 选择保险公司后，险种分类下拉自动过滤只显示该公司有在售产品的分类；
- 选择险种分类后，保障期限/缴费期限只显示该险种支持的选项；
- 多个筛选条件叠加时为 AND 关系；
- 用户点击"重置"按钮，所有筛选条件清空，重新加载默认列表。

**后端接口：** `GET /insurance/product/page`

**请求参数：**
```
categoryId      Long      险种分类ID（选填）
companyId       Long[]    保险公司ID列表（选填）
coveragePeriod  String    保障期限（选填）
paymentPeriod   String    缴费期限（选填）
minAge          Integer   最小年龄（选填）
maxAge          Integer   最大年龄（选填）
sortField       String    排序字段: salesCount/commissionRate/referencePremium（默认salesCount）
sortOrder       String    asc/desc（默认desc）
pageNo          Integer   页码（默认1）
pageSize        Integer   每页条数（默认20）
```

**后端处理逻辑：**
1. 固定过滤条件：`deleted=0 AND status=1`；
2. 按请求参数拼接动态 WHERE 条件；
3. 查询 `ins_product` 表，分页返回结果；
4. 对每条产品额外查询当前业务员是否已收藏（join `ins_product_favorite`），返回 `isFavorite` 字段；
5. 产品列表数据优先从 Redis 缓存读取（Key: `product:list:{参数hash}`，TTL 10分钟），缓存未命中时查 MySQL 并回写缓存。

**返回字段（VO）：**
```
id              Long      产品ID
productName     String    产品名称
companyName     String    保险公司名称
companyLogo     String    公司Logo URL
categoryName    String    险种分类
highlights      List      产品亮点列表（最多3条）
coveragePeriod  String    保障期限
paymentPeriod   String    缴费期限
referencePremium BigDecimal  参考保费（月缴）
commissionRate  String    首年佣金率（如"60%"）
salesCount      Integer   销量
isFavorite      Boolean   是否已收藏
isHot           Boolean   是否热销（salesCount>=100）
isHighCommission Boolean  是否高佣（commissionRate>=0.6）
```

---

### M1-F2 产品详情

#### 业务流程

业务员在列表页点击任意产品卡片，进入产品详情页。

**页面结构（从上到下）：**

**① 产品头部区域**
- 产品名称（大字体）
- 保险公司名称 + Logo
- 险种标签 + 在售/停售状态
- 快捷操作按钮：【立即试算】【制作计划书】【收藏】

**② 产品亮点（Tabs切换内容区域顶部）**
- 最多5条亮点，图标+文字展示
- 数据来源：`product_highlights` JSON数组

**③ 保障责任（Tab1）**
- 以折叠面板方式展示 `coverage_detail` JSON字段
- 每项保障责任显示：责任名称 / 赔付条件 / 赔付比例 / 赔付次数 / 等待期
- 主险责任在前，附加险责任在后

**④ 费率说明（Tab2）**
- 列举2~3个典型投保案例：如"30岁男性，50万保额，缴费20年，年缴保费XXXX元"
- 底部放置【立即试算】蓝色大按钮，点击跳转试算页并带入当前产品ID

**⑤ 投保须知（Tab3）**
- 健康告知要点（纯文本，重要字段加红色标注）
- 免责条款（从 `exclusions` 字段读取）
- 理赔流程说明

**⑥ 常见问答（Tab4）**
- FAQ列表，从 `faq` JSON数组读取
- 默认折叠，点击标题展开答案

**⑦ 投保案例（Tab5）**
- 典型客户案例，从 `case_study` 字段读取（富文本或Markdown）

**后端接口：** `GET /insurance/product/detail/{id}`

**后端处理逻辑：**
1. 先查 Redis 缓存：`product:detail:{id}`，TTL 1小时；
2. 缓存未命中则查 `ins_product` 表（status=1 或 status=2 均可查看，停售产品详情仍可访问，但页面标注"已停售"，隐藏试算和计划书按钮）；
3. 解析 `coverage_detail`、`faq`、`product_highlights` 等 JSON 字段为结构化对象；
4. 异步写入产品浏览日志表 `ins_product_view_log`（产品ID、业务员ID、时间）；
5. 写入 Redis 缓存并返回。

**后端校验：**
- 产品 ID 不存在或 `deleted=1`：返回错误"产品不存在"；
- 产品 `status=0`（已下架）：后台仍可查看详情，但前端隐藏试算/计划书入口，页面顶部展示"该产品已下架"横幅。

---

### M1-F3 产品对比

#### 业务流程

**入口一：** 在产品列表，点击卡片右上角"对比"复选框，可选中多个产品，底部浮现固定"对比栏"，显示已选产品缩略图（最多4个）和【开始对比】按钮。

**入口二：** 在产品详情页底部，点击【加入对比】按钮。

**约束规则：**
- 最少选择 2 个产品才能点击【开始对比】，否则按钮置灰并提示"请至少选择2个产品"；
- 最多选择 4 个产品，选第5个时前端直接拦截，Toast提示"最多对比4个产品，请取消部分勾选"；
- 已选产品可在对比栏中删除；
- 仅 `status=1` 的产品可加入对比，状态变化为停售时自动从对比栏移除并Toast提示。

**对比页面布局（横向滚动表格）：**

纵轴（行）为对比维度，横轴（列）为各产品。

对比维度顺序：

| 维度分组 | 具体字段 |
|---|---|
| 基础信息 | 保险公司 / 产品类型 / 保障期限 / 缴费期限 |
| 投保条件 | 投保年龄范围 / 保额范围 / 职业限制 |
| 保障责任 | 重疾保额比例 / 轻症保额比例 / 中症 / 身故 / 特色责任 |
| 参考保费 | 30岁男50万20缴年缴 / 30岁女50万20缴年缴 |
| 增值服务 | 就医绿通 / 质子重离子 / 特药服务 |
| 佣金信息 | 首年佣金率 / 续年佣金率（仅业务员可见） |

**差异高亮规则：**
- 数值型（保费、赔付比例）：同行中最优值高亮绿色背景，最差值灰色；
- 布尔型（有/无某项服务）：有→绿色"√"，无→灰色"−"；
- 某产品独有的保障责任：用红色"⭐独有"标签标注；
- 同行所有产品值相同：不做高亮。

**后端接口：** `POST /insurance/product/compare`

**请求参数：**
```json
{ "productIds": [1, 2, 3] }
```

**后端处理逻辑：**
1. 校验 productIds 数量：2~4个，否则返回参数错误；
2. 批量查询产品信息（仅查 status=1，已下架自动过滤并在响应中标注 `filteredIds`）；
3. 解析每个产品的 `coverage_detail` JSON，提取所有保障责任项，合并去重构建责任维度列表；
4. 按责任重要性排序（核心责任 > 附加责任 > 增值服务）；
5. 标记差异项（仅部分产品有的责任标记 `isDifferent=true`）；
6. 计算同行最优值（用于前端高亮）；
7. 组装对比矩阵数据返回。

---

### M1-F4 产品收藏

#### 业务流程

**收藏操作：**
- 在产品列表卡片右上角或产品详情页顶部，点击"⭐收藏"图标；
- 已收藏时图标为金色实心星星，点击取消收藏；
- 未收藏时图标为灰色空心星星，点击添加收藏；
- 操作后即时反馈 Toast："已添加收藏" / "已取消收藏"。

**收藏夹入口：**
- 产品库页面顶部 Tab 增加"我的收藏"标签；
- 点击后展示该业务员收藏的所有产品列表；
- 支持长按卡片 → 批量移除收藏；
- 收藏列表按收藏时间倒序排列。

**后端接口：** 
- 添加收藏：`POST /insurance/product/favorite/{productId}`
- 取消收藏：`DELETE /insurance/product/favorite/{productId}`
- 收藏列表：`GET /insurance/product/favorite/list`

**后端处理逻辑（添加收藏）：**
1. 检查 `ins_product_favorite` 表中是否已存在 `(agent_id, product_id)` 记录；
2. 已存在则忽略（幂等处理）；
3. 不存在则插入记录：`(agent_id, product_id, created_time)`；
4. 同时在 Redis Set `product:favorite:{agentId}` 中加入 productId。

**入库字段（ins_product_favorite）：**
```
id              BIGINT    主键
agent_id        BIGINT    业务员ID（取当前登录用户）
product_id      BIGINT    产品ID
created_time    DATETIME  收藏时间
```

---

### M1-F5 产品搜索

#### 业务流程

产品库页面顶部固定搜索框，业务员点击搜索框后弹出搜索弹层。

**搜索行为：**
- 搜索框输入时实时显示"历史搜索"和"热门搜索词"（来自后端统计）；
- 用户输入超过1个字符时，实时触发搜索联想（防抖300ms），显示产品名称联想词；
- 用户点击搜索按钮或回车，跳转到搜索结果页；
- 搜索结果页与产品列表页布局一致，但无分类筛选栏。

**搜索支持的关键词类型：**
- 产品名称关键词：如"达尔文"、"守护神"
- 保险公司名称：如"平安"、"人寿"
- 险种名称：如"重疾险"、"医疗险"
- 保障内容关键词：如"癌症"、"住院"、"带病可保"

**后端接口：** `GET /insurance/product/search`

**请求参数：**
```
keyword     String    搜索关键词（必填，1-50字符）
pageNo      Integer   页码
pageSize    Integer   每页条数
```

**后端处理逻辑：**
1. 校验 keyword 非空，长度不超过50字符；
2. 清洗关键词：去除特殊字符（`@#!`等），保留中文、字母、数字；
3. 使用 MySQL LIKE 模糊匹配（若未部署 ES，降级到 MySQL）：
   ```sql
   WHERE status=1 AND deleted=0
   AND (product_name LIKE '%{keyword}%'
     OR insurance_company_name LIKE '%{keyword}%'
     OR category_name LIKE '%{keyword}%')
   ```
4. 排序：相关度优先（命中产品名称 > 命中公司名 > 命中分类）→ 再按 sales_count 降序；
5. 异步写入搜索日志表 `ins_search_log`（keyword、agent_id、result_count、time）；
6. 返回产品列表（结构同列表接口）。

---

## M2 保费试算

### M2-F1 试算表单

#### 业务流程

**入口：**
1. 产品详情页点击【立即试算】按钮（带入产品ID）；
2. 产品库列表页长按卡片 → 快速试算；
3. 底部导航"试算"Tab（进入后需先选产品）。

**试算表单页面字段（按填写顺序）：**

**第一步：选择产品**（如果从产品详情跳入则自动填充，跳过此步）
- 下拉搜索框：输入关键词选择产品，显示产品名称+公司名
- 必填，产品必须为在售状态

**第二步：填写被保人信息**

| 字段 | 类型 | 必填 | 校验规则 |
|---|---|---|---|
| 被保人姓名 | 文本 | 是 | 2-20个中文字符 |
| 出生日期 | 日期选择器 | 是 | 不能是未来日期；根据产品的 min_age/max_age 校验（年龄=今年-出生年，取周岁） |
| 性别 | 单选（男/女） | 是 | 无 |
| 职业类别 | 下拉（1-6类） | 是 | 部分产品要求职业类别≤3；超限时报错"该产品要求职业类别不超过X类" |

**第三步：配置投保方案**

| 字段 | 类型 | 必填 | 校验规则 |
|---|---|---|---|
| 保额 | 数字输入 | 是 | 必须在产品 min_amount ~ max_amount 范围内；必须是 amount_increment 的整数倍（如5万倍数）；超出范围提示具体边界值 |
| 缴费期限 | 单选列表 | 是 | 从产品配置的 payment_period_options 中选择（如趸交/10年/20年/30年） |
| 保障期限 | 单选列表 | 是 | 从产品配置的 coverage_period_options 中选择（如20年/至70岁/终身） |
| 是否吸烟 | 单选（是/否） | 否 | 仅重疾险/寿险展示此字段 |

**年龄校验联动：**
- 缴费期限选完后，前端立即计算"缴费结束年龄=当前年龄+缴费年数"，若>60岁则显示橙色提示"缴费将持续至X岁，请确认收入稳定性"（非阻断，可继续）；
- 选"终身"保障时，校验年龄不得超过产品 max_age；
- 选"至70岁"保障时，若被保人当前年龄 ≥ 70，报错"被保人年龄已超过保障期限"。

**页面底部：**
- 【立即计算】大按钮，点击后调用试算接口
- 已计算过一次的，结果显示在页面下半部分，修改参数后可重新计算

#### 后端接口：`POST /insurance/quotation/calculate`

**请求参数（必须字段）：**
```json
{
  "productId": 123,
  "insuredAge": 30,
  "insuredGender": 1,
  "occupationClass": 1,
  "amount": 500000,
  "paymentPeriod": "20年",
  "coveragePeriod": "终身",
  "nonSmoker": true
}
```

**后端校验（按顺序执行，首个不通过立即返回错误）：**
1. productId 对应产品存在且 status=1；
2. insuredAge 在产品 min_age ~ max_age 范围内；
3. amount 在产品 min_amount ~ max_amount 范围内，且是 amount_increment 的整数倍；
4. paymentPeriod 在产品配置的可选列表中；
5. coveragePeriod 在产品配置的可选列表中；
6. occupationClass 不超过产品配置的最大职业类别限制。

**后端计算逻辑：**
1. 构建缓存 Key（`quotation:{productId}:{age}:{gender}:{amount}:{paymentPeriod}:{coveragePeriod}:{occupationClass}:{nonSmoker}`），查询 Redis；
2. 缓存命中，直接返回；
3. 缓存未命中：
   a. 从产品表读取 `premium_formula`（Groovy脚本）和 `rate_table` JSON；
   b. 将参数传入 Groovy 脚本执行引擎（设置超时时间5秒）；
   c. 计算结果包含：年缴保费、月缴保费、总缴保费；
   d. 写入 Redis 缓存（TTL 24小时）；
4. 返回试算结果。

**返回字段：**
```
annualPremium       BigDecimal  年缴保费（元，精确到分）
monthlyPremium      BigDecimal  月缴保费（元，精确到分）
totalPremium        BigDecimal  总缴保费（元）
paymentYears        Integer     缴费年数
coverageYears       Integer     保障年数（终身=999）
calculateAt         String      计算时间（展示用）
```

---

### M2-F2 保费展示

#### 业务流程

试算结果计算完成后，页面下半区域展开展示结果卡片：

**展示内容：**
- 年缴保费（大字体，如 ¥6,580/年）
- 月缴保费（小字体辅助）
- 总缴保费
- 方案摘要：被保人姓名 / 性别 / 年龄 / 保额 / 缴费期限 / 保障期限
- 操作按钮：【制作计划书】（跳转到计划书模块，带入当前试算参数）/ 【重新试算】

**保费对比功能（可选）：**
- 同一产品，可切换不同缴费期限对比（如10年缴 vs 20年缴），并排展示年缴保费，帮助业务员向客户解释"交20年虽然年缴低，但总保费更高"。

---

### M2-F3 利益演示

#### 业务流程

利益演示仅对**年金险、增额终身寿险**类产品展示，重疾险、医疗险不展示此功能。

**触发方式：**
- 试算结果页底部出现"查看利益演示"按钮（仅年金类产品展示）；
- 点击后展开利益演示面板。

**利益演示内容：**

**逐年利益表**（分页/滚动展示）：
| 年度 | 年末年龄 | 累计保费 | 年度生存金 | 累计领取 | 现金价值 |
|---|---|---|---|---|---|
| 1 | 31 | 20000 | 0 | 0 | 15000 |
| 2 | 32 | 40000 | 0 | 0 | 32000 |
| ... | ... | ... | ... | ... | ... |
| 20 | 50 | 400000 | 30000 | 200000 | 450000 |

**关键指标展示：**
- 回本年限（累计领取 ≥ 累计保费的最早年份）
- 内部收益率 IRR（精确到两位小数，如 3.2%）

**图表展示：**
- ECharts 折线图：横轴为年龄，纵轴为金额；显示"累计保费"和"现金价值"两条线，直观展示回本时间点（两线交叉处）。

**后端接口：** `POST /insurance/quotation/benefit`

**请求参数：** 同试算接口，新增 `benefitAge`（演示到几岁，默认80岁）

**后端处理逻辑：**
1. 从产品表读取 `cash_value_table`（JSON，格式为 `{年份: {现金价值, 生存金, ...}}`）；
2. 根据保额和 `amount` 比例缩放基准现金价值表（产品现金价值表通常以10万保额为基准）；
3. 生成逐年数据：年度 / 年龄 / 累计保费 / 生存金 / 累计领取 / 现金价值；
4. 计算回本年限（遍历找到累计领取首次 ≥ 累计保费的年份）；
5. 用牛顿迭代法计算 IRR（精度 0.01%，最大迭代100次，超时则返回估算值）；
6. 返回逐年表 + 关键指标。

---

### M2-F4 保额反算（可选功能）

#### 业务流程

场景：客户说"我每年预算1万元，能买多少保额？"

**入口：** 试算表单页切换 Tab "按预算试算"

**页面字段：**
| 字段 | 必填 | 说明 |
|---|---|---|
| 年预算 | 是 | 输入1元~99999元 |
| 其余参数 | 是 | 同正常试算（年龄/性别/缴费期等） |

**后端接口：** `POST /insurance/quotation/reverse`

**计算逻辑（二分法）：**
1. 以产品 min_amount 为下限，max_amount 为上限；
2. 取中间值 mid，调用试算引擎计算年缴保费；
3. 若保费 > 预算 → 保额上限调低为 mid；若保费 ≤ 预算 → 保额下限调高为 mid；
4. 重复步骤 2-3，直到保费与预算误差 < 1%，或达到最大迭代30次；
5. 返回推荐保额（向下取整到 amount_increment 的整数倍）和对应保费。

---

## 数据库核心表设计

### ins_product（非车险产品表）

```sql
CREATE TABLE ins_product (
  id                    BIGINT NOT NULL AUTO_INCREMENT COMMENT '产品ID',
  product_code          VARCHAR(50)  NOT NULL COMMENT '产品代码，唯一',
  product_name          VARCHAR(100) NOT NULL COMMENT '产品名称',
  insurance_company_id  BIGINT NOT NULL COMMENT '保险公司ID',
  insurance_company_name VARCHAR(100) COMMENT '保险公司名称（冗余存储）',
  company_logo          VARCHAR(255) COMMENT '公司Logo URL',
  category_id           BIGINT COMMENT '险种分类ID',
  category_name         VARCHAR(50)  COMMENT '分类名称',
  product_type          TINYINT COMMENT '1-主险 2-附加险',
  coverage_period       VARCHAR(50)  COMMENT '保障期限，如终身/至70岁/20年',
  payment_period        VARCHAR(50)  COMMENT '缴费期限，如趸交/10年/20年',
  coverage_period_options JSON        COMMENT '可选保障期限列表',
  payment_period_options  JSON        COMMENT '可选缴费期限列表',
  min_age               INT COMMENT '最小投保年龄（周岁）',
  max_age               INT COMMENT '最大投保年龄（周岁）',
  min_amount            DECIMAL(15,2) COMMENT '最低保额（元）',
  max_amount            DECIMAL(15,2) COMMENT '最高保额（元）',
  amount_increment      DECIMAL(15,2) COMMENT '保额递增单位（元）',
  max_occupation_class  TINYINT DEFAULT 3 COMMENT '最大可投职业类别',
  product_highlights    JSON COMMENT '产品亮点列表',
  coverage_detail       JSON COMMENT '保障责任结构化JSON',
  exclusions            TEXT COMMENT '免责条款',
  case_study            TEXT COMMENT '投保案例（富文本）',
  faq                   JSON COMMENT '常见问答',
  premium_formula       TEXT COMMENT '保费计算Groovy脚本',
  rate_table            JSON COMMENT '费率表JSON',
  cash_value_table      JSON COMMENT '现金价值表（仅年金类产品）',
  reference_premium     DECIMAL(15,2) COMMENT '参考保费（30岁男50万20缴年缴，用于排序）',
  commission_rate       DECIMAL(5,4)  COMMENT '首年佣金率（FYC）',
  renewal_commission_rate DECIMAL(5,4) COMMENT '续年佣金率（RYC）',
  status                TINYINT DEFAULT 1 COMMENT '0-下架 1-在售 2-停售',
  sort_order            INT DEFAULT 0 COMMENT '排序权重',
  sales_count           INT DEFAULT 0 COMMENT '销售件数',
  stop_sale_date        DATE COMMENT '计划停售日期（用于定时下架）',
  -- 框架标准字段
  creator               VARCHAR(64) DEFAULT '' COMMENT '创建者',
  create_time           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updater               VARCHAR(64) DEFAULT '',
  update_time           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted               TINYINT DEFAULT 0,
  tenant_id             BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_product_code (product_code),
  KEY idx_company_category (insurance_company_id, category_id, status),
  KEY idx_status_sort (status, sort_order, sales_count)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='非车险产品表';
```

### ins_product_favorite（产品收藏表）

```sql
CREATE TABLE ins_product_favorite (
  id            BIGINT NOT NULL AUTO_INCREMENT,
  agent_id      BIGINT NOT NULL COMMENT '业务员ID',
  product_id    BIGINT NOT NULL COMMENT '产品ID',
  create_time   DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_agent_product (agent_id, product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='产品收藏表';
```

### ins_search_log（搜索日志表）

```sql
CREATE TABLE ins_search_log (
  id            BIGINT NOT NULL AUTO_INCREMENT,
  keyword       VARCHAR(100) NOT NULL,
  agent_id      BIGINT NOT NULL,
  result_count  INT DEFAULT 0,
  create_time   DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_keyword (keyword),
  KEY idx_agent_time (agent_id, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='产品搜索日志';
```

### ins_quotation_record（试算记录表）

```sql
CREATE TABLE ins_quotation_record (
  id                BIGINT NOT NULL AUTO_INCREMENT,
  agent_id          BIGINT NOT NULL COMMENT '业务员ID',
  customer_id       BIGINT COMMENT '关联客户ID（可选）',
  product_id        BIGINT NOT NULL,
  insured_name      VARCHAR(50),
  insured_age       INT,
  insured_gender    TINYINT,
  occupation_class  TINYINT,
  amount            DECIMAL(15,2),
  payment_period    VARCHAR(50),
  coverage_period   VARCHAR(50),
  annual_premium    DECIMAL(15,2),
  total_premium     DECIMAL(15,2),
  create_time       DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_agent_product (agent_id, product_id, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保费试算记录';
```

---

## 工时估算（M1+M2）

| 模块 | 功能点 | 前端工时 | 后端工时 | 合计 |
|---|---|---|---|---|
| M1 产品库 | 产品列表（筛选+排序+分页） | 2天 | 1天 | 3天 |
| M1 产品库 | 产品详情（多Tab展示） | 2天 | 0.5天 | 2.5天 |
| M1 产品库 | 产品对比（对比矩阵） | 2天 | 1天 | 3天 |
| M1 产品库 | 产品收藏 | 0.5天 | 0.5天 | 1天 |
| M1 产品库 | 产品搜索 | 0.5天 | 1天 | 1.5天 |
| M2 保费试算 | 试算表单（联动校验） | 1.5天 | 0.5天 | 2天 |
| M2 保费试算 | 试算引擎（Groovy+缓存） | 0天 | 2天 | 2天 |
| M2 保费试算 | 保费展示 | 0.5天 | 0.5天 | 1天 |
| M2 保费试算 | 利益演示（图表+IRR） | 2天 | 1.5天 | 3.5天 |
| **合计** | | **11天** | **8.5天** | **19.5天** |

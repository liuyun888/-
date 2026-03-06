# intermediary-module-ins-product 数据库设计文档

> **模块**：保险产品中台  
> **Schema**：`db_ins_product`  
> **表前缀**：`ins_product_`  
> **覆盖险种**：车险 / 非车险 / 寿险（健康险 / 意外险 / 年金险）  
> **框架规范**：yudao-cloud（`creator / updater / deleted / tenant_id` 四标准字段）  
> **文档版本**：V1.0  

---

## 一、整体设计思路

### 1.1 分层设计原则

产品中台采用"**通用主表 + 险种扩展表**"的分层策略：

- `ins_product_info` 为全险种通用主表，承载90%以上的共同字段。
- 各险种差异字段通过 1:1 扩展表隔离，避免主表字段膨胀。
- 费率表按险种独立设计（车险/非车险/寿险各有专属费率结构），支持 EasyExcel 批量导入。

### 1.2 多租户设计

- 系统预置数据（险种分类、系统产品）`tenant_id = 0`，全租户共享可见。
- 自定义产品（`product_type = 2`）归属于创建租户，`tenant_id = 具体租户ID`。
- 所有查询均须带 `tenant_id` 条件（yudao-cloud 框架自动注入）。

### 1.3 软删除规范

所有业务表均使用 `deleted TINYINT(1) DEFAULT 0` 软删除，唯一索引必须包含 `deleted` 字段避免冲突。

---

## 二、SQL 文件清单

| 文件 | 内容 | 包含表数 |
|------|------|---------|
| `ins_product_part1_insurer_category.sql` | 保险公司档案 + 险种分类 | 4张 |
| `ins_product_part2_product_main.sql` | 产品主表 + 通用配置 | 8张 |
| `ins_product_part3_life_product.sql` | 寿险专属配置 | 7张 |
| `ins_product_part4_rate_log_readme.sql` | 非车险费率 + 日志 + 说明 | 3张（+注释说明）|

执行顺序：Part1 → Part2 → Part3 → Part4

---

## 三、表结构说明（21张表）

### 3.1 保司管理（3张）

#### ins_product_insurer — 保险公司档案

车险/非车险/寿险三大险种共用，通过 `insurance_type` 字段区分归属。

| 关键字段 | 类型 | 说明 |
|---------|------|------|
| `company_code` | VARCHAR(50) | 保司编码，全局唯一，如 PICC/CPIC |
| `insurance_type` | TINYINT | 1-车险 2-非车险 3-通用（含寿险）|
| `api_enabled` | TINYINT(1) | 是否开启API对接 |
| `api_app_key` | VARCHAR(500) | AES-256加密存储 |
| `commission_rate` | DECIMAL(6,4) | 默认手续费协议比例 |

#### ins_product_insurer_life_ext — 寿险保司扩展

与 `ins_product_insurer` 1:1 关联，仅寿险保司需要维护。

| 关键字段 | 说明 |
|---------|------|
| `settlement_mode` | 结算方式：1-银行转账 2-支付宝 3-其他 |
| `bank_account_no` | 银行账号（AES-256加密） |
| `agreement_no` | 执行协议编号 |

#### ins_product_insurer_account — 保司工号/API账号

| 关键字段 | 说明 |
|---------|------|
| `insurance_type` | 1-车险 2-非车险 3-寿险 |
| `app_key` | AES-256加密，展示时仅显示后4位 |
| `org_id` | 限制可用机构（NULL=全机构可用）|

---

### 3.2 险种分类（1张）

#### ins_product_category — 险种分类（树形）

| 字段 | 说明 |
|------|------|
| `parent_id` | 父分类ID，顶级=0 |
| `category_code` | 系统枚举码，如 AUTO/LIFE/HEALTH |
| `category_type` | 1-系统预置（只读）2-自定义 |
| `insurance_type` | 1-车险 2-非车险 3-寿险/健康/意外 |

**预置数据**：AUTO（车险）/ NON_VEHICLE（非车险）/ LIFE（寿险）/ HEALTH（健康险）/ ACCIDENT（意外险）/ ANNUITY（年金险）

---

### 3.3 产品主表（8张）

#### ins_product_info — 产品主表（核心）

全险种共用，是整个产品中台的数据源。

| 关键字段 | 类型 | 说明 |
|---------|------|------|
| `product_code` | VARCHAR(100) | 产品代码（同保司内唯一，创建后不可改）|
| `insurance_type` | TINYINT | 1-车险 2-非车险 3-寿险 4-健康 5-意外 6-年金 |
| `product_type` | TINYINT | 1-系统产品 2-自定义产品 |
| `highlight_list` | JSON | 产品亮点（最多5条）|
| `coverage_detail` | JSON | 保障责任明细（结构化JSON）|
| `status` | TINYINT | 0-下架 1-上架 2-草稿 3-待审 4-停售 |
| `stock` | INT | -1=无限库存，≥0=有限库存 |
| `auto_on_shelf_time` | DATETIME | 定时上架（ProductAutoShelfTask每小时检查）|
| `commission_rate` | DECIMAL(6,4) | 默认佣金比例（可被分级佣金覆盖）|

**业务规则**：
- 上架前必须：① 产品图片不为空 ② 库存≠0 ③ 保司状态=启用 ④ 寿险产品还需费率表+机构授权
- 库存归零时自动触发下架，不自动上架
- 佣金比例变更只影响后续新订单，历史订单不变（变更记录存 `ins_product_commission_change_log`）

#### ins_product_commission_level — 分级佣金

按业务员等级（初/中/高/资深）配置不同佣金比例，支持按缴费方式区分（寿险）。

#### ins_product_org_auth — 产品机构授权（通用）

控制哪些机构可销售特定产品。寿险产品有独立授权表 `ins_product_life_org_auth`。

#### ins_product_favorite — 产品收藏

业务员App收藏产品，列表接口返回 `isFavorite` 字段。

---

### 3.4 车险专属（1张）

#### ins_product_car_rate — 车险费率表

| 关键字段 | 说明 |
|---------|------|
| `rate_key` | 组合唯一键，如 `province_310000_age_3_ncd_0.85` |
| `rate_value` | 费率值（DECIMAL精确计算，禁用float/double）|
| `rate_type` | 1-交强险基准 2-商业险基准 3-系数 |

**导入机制**：EasyExcel解析，每次导入先逻辑删除旧数据（`deleted=1`），再批量插入（每批500条），整体加 `@Transactional`。

---

### 3.5 非车险专属（2张）

#### ins_product_non_vehicle_plan — 系统产品方案

系统预置，只读。用于政策配置中"产品方案"字段的下拉数据源。

#### ins_product_non_vehicle_rate — 非车险费率

| 关键字段 | 说明 |
|---------|------|
| `rate_structure` | JSON灵活存储，支持多维度复杂费率结构 |
| `rate_type` | 1-基础费率 2-附加费率 3-折扣系数 |
| `version` | 版本号，每次更新递增 |

---

### 3.6 寿险专属（7张）

#### ins_product_life_ext — 寿险产品扩展（1:1）

| 关键字段 | 说明 |
|---------|------|
| `life_category` | 枚举：LIFE/CRITICAL_ILLNESS/MEDICAL/ACCIDENT/ANNUITY/UNIVERSAL |
| `product_code_insurer` | 保司分配的产品代码（同保司内唯一）|
| `payment_modes` | 支持的缴费方式（逗号分隔）|
| `waiting_period_days` | 等待期（天）|

#### ins_product_life_rate — 寿险费率表

| 关键字段 | 说明 |
|---------|------|
| `age_min / age_max` | 投保年龄区间 |
| `gender` | 0-不限 1-男 2-女 |
| `premium_per_unit` | 每万元保额对应保费（DECIMAL精确计算）|
| `batch_no` | 导入批次号，每次导入前逻辑删除旧数据 |

#### ins_product_questionnaire_template — 健康告知问卷模板

`questions` 字段为JSON数组，含题目/选项/跳转逻辑。

#### ins_product_questionnaire_bind — 产品-问卷绑定

一个产品可绑定多份问卷（主问卷+特殊附加问卷），`bind_type` 区分。

#### ins_product_life_org_auth — 寿险产品机构授权

含 `expire_time` 字段，支持有期限授权。

#### ins_product_life_proposal — 计划书申请记录

| 关键字段 | 说明 |
|---------|------|
| `proposal_no` | 计划书编号（唯一，如 PS202401010001）|
| `status` | 0-待生成 1-生成中 2-已生成 3-生成失败 |
| `source` | 1-C端小程序 2-业务员App |
| `pdf_url` | 生成的PDF文件OSS地址 |

---

### 3.7 辅助表（3张）

| 表名 | 用途 |
|------|------|
| `ins_product_operation_log` | 产品操作审计日志（上下架/授权/费率导入等）|
| `ins_product_calc_cache` | 保费试算结果缓存（配合Redis使用，避免重复计算）|
| `ins_product_view_log` | 产品浏览记录（异步写入，驱动热销标签打标）|

---

## 四、Redis 缓存键规范

| Key 格式 | TTL | 说明 |
|---------|-----|------|
| `ins:product:detail:{id}` | 1h | 产品详情 |
| `ins:product:list:{paramsHash}` | 10min | 列表分页缓存 |
| `ins:product:hot:ids` | 30min | 热销产品ID列表 |
| `ins:product:insurer:list` | 1h | 保司列表 |
| `ins:product:category:tree` | 24h | 险种分类树 |
| `ins:product:rate:car:{productId}` | 2h | 车险费率 |
| `ins:product:life:rate:{productId}` | 2h | 寿险费率 |
| `ins:product:calc:{hash}` | 24h | 试算结果 |
| `ins:product:org:auth:{productId}` | 1h | 授权机构集合(Set) |

**缓存失效策略**：产品状态变更/费率导入/授权变更时主动 DELETE 对应 Key。

---

## 五、定时任务清单

| 任务类 | 执行周期 | 说明 |
|--------|---------|------|
| `InsProductAutoShelfTask` | 每小时整点 | 处理定时上下架 |
| `InsProductHotTagTask` | 每天 02:00 | `sales_count >= 100` 自动打热销标签 |
| `InsProductCalcCacheCleanTask` | 每天 03:00 | 清理过期试算缓存 |
| `InsProductProposalTimeoutTask` | 每小时 | 处理30分钟未生成的计划书，标记失败 |

---

## 六、接口路径规范

| 路径前缀 | Controller | 说明 |
|---------|-----------|------|
| `/admin-api/ins/product/insurer/**` | `InsInsurerController` | PC端保司管理 |
| `/admin-api/ins/product/category/**` | `InsProductCategoryController` | 险种分类 |
| `/admin-api/ins/product/info/**` | `InsProductController` | 产品CRUD/上下架 |
| `/admin-api/ins/product/rate/**` | `InsProductRateController` | 费率表维护 |
| `/admin-api/ins/product/life/**` | `InsLifeProductController` | 寿险产品管理 |
| `/app-api/ins/product/**` | `AppInsProductController` | 业务员App产品列表/详情 |
| `/app-api/ins/life/product/**` | `AppInsLifeProductController` | 业务员App寿险列表/试算 |

---

## 七、ER 关系简图

```
ins_product_insurer (1) ──────────── (1) ins_product_insurer_life_ext
         │
         │ (1:N)
         ▼
ins_product_info (1) ─────────────── (1) ins_product_life_ext
         │                                        │
         │ (1:N)                                  │ (1:N)
         ├─► ins_product_commission_level          ├─► ins_product_life_rate
         ├─► ins_product_org_auth                  ├─► ins_product_questionnaire_bind
         ├─► ins_product_favorite                  ├─► ins_product_life_org_auth
         ├─► ins_product_view_log                  └─► ins_product_life_proposal
         ├─► ins_product_car_rate (车险)
         ├─► ins_product_non_vehicle_plan (非车险)
         ├─► ins_product_non_vehicle_rate (非车险)
         ├─► ins_product_operation_log
         └─► ins_product_calc_cache

ins_product_category (树形，parent_id自关联)
ins_product_questionnaire_template (1:N) ins_product_questionnaire_bind
ins_product_insurer_account (独立，与insurer关联)
```

---

*文档版本：V1.0 | 对应工程模块：intermediary-module-ins-product | 参考需求文档：阶段1~3 + 阶段7 + 阶段8*

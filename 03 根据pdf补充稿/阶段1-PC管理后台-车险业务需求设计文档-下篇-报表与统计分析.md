# 阶段1 · PC管理后台 · 车险业务需求设计文档【下篇：报表管理 · 统计分析】

> 版本：V1.0 | 对应排期表 Sheet：`阶段1-PC管理后台-车险业务`

---

## 八、报表管理

> 菜单路径：车险 → 报表管理 → 监管报表

### 8.1 车险监管报表

#### 页面结构

页面顶部三个子 Tab：「监管报表」 | 「财务报表」 | 「业务报表」。

---

#### 8.1.1 监管报表 Tab

**功能说明**：生成符合监管格式要求的车险手续费明细报表，用于提交监管机构。

**筛选条件**：
- 年份（年份选择器，必填）
- 季度（下拉：Q1/Q2/Q3/Q4）或月份（下拉 1-12）；季度和月份互斥，选一即可。

**报表格式**（固定列，不可自定义）：

| 列名 | 说明 |
|------|------|
| 保险公司名称 | 保司全称 |
| 手续费及佣金 | 从保司收取的手续费总额 |
| 咨询费 | 咨询费金额 |
| 向保险公司收取的其他费用 | 合计 |
| — 其中：转账 | 细分金额 |
| — 其中：现金 | 细分金额 |
| — 其中：返还保险公司 | 细分金额 |
| — 其中：公司高管员工挪用侵占 | 细分金额（通常为 0）|
| — 其中：支付无资格服务费 | 细分金额 |

**后端逻辑**：
1. 聚合 `ins_car_commission_record` 表（按 `insurance_company_id` 分组），结合 `settlement_year`、`settlement_quarter`（或 `settlement_month`）筛选。
2. 金额字段保留小数后两位（`DECIMAL(12,2)`，`BigDecimal` 精确计算，严禁 float/double）。
3. 数据口径说明（依据操作手册71号）：
   - **监管报表**：统计**已开票**的跟单手续费。即保单 `commission_record.status` 已结算且已开票的数据。开票状态需在财务模块标记。未开票的手续费不计入监管报表。
   - 若保单结算已开票后，修改了**全保费或净保费**，监管报表的保费金额会实时更新。
   - 若保单结算已开票后，修改了**跟单费用**，监管报表不会实时更新，需要重新结算后才会更新跟单费用数据。
   - 手续费及佣金字段取值来源：保险公司的**开票金额（含税合计）**（财务配置中的发票抬头作为保险公司名称）。
   - 各细分项（转账/现金/返还保险公司/挪用侵占/无资格服务费）暂由人工录入或从财务模块同步（阶段6实现，当前阶段展示「暂无数据」）。
4. 导出支持按组织机构筛选，导出该组织下的明细（适用于多机构分公司场景）。
5. 导出任务异步生成，完成后在「任务列表」下载导出文件。

**导出**：点击【导出】，EasyExcel 按固定格式导出 .xlsx，文件名格式：`车险监管报表_${year}Q${quarter}.xlsx`。

---

#### 8.1.2 财务报表 Tab

**筛选条件**：年份（必填）、季度/月份（互斥二选一）、佣金是否含税（下拉：含税/不含税/全部）。

**展示内容**：
- 数据表格列：保险公司名称（取值来源：财务配置中的**发票抬头**，而非保险公司全称）、手续费及佣金/咨询费（保险公司的开票金额含税合计）、净保费、佣金率、环比、同比。
- 支持与监管报表同数据源，增加了财务部门内部使用的分析指标列（净保费、环比、同比等）。

**注意**：保险公司名称取值位置是**财务配置中配置的发票抬头**，而不是保险公司管理中的 `company_name` 字段，确保与开票信息保持一致。

**导出**：点击【导出】，导出格式同监管报表，但包含额外的财务指标列。

---

#### 8.1.3 业务报表 Tab

**筛选条件**：年份、季度/月份（同监管报表）。

**展示内容**：
- 数据表格：行=各保险公司，列=各险种（交强险/商业险/车船税/其他），每格展示「保费（万元）」+ 「件数」+ 「手续费（万元）」。
- 横向合计行：所有保司合计数据。

**后端查询**：
```sql
SELECT ic.insurance_company_name,
       p.policy_type,
       COUNT(*) AS policy_count,
       SUM(p.premium_compulsory + p.premium_commercial) AS total_premium,
       SUM(cr.commission_amount) AS commission_amount
FROM insurance_car_policy p
LEFT JOIN ins_company ic ON p.insurance_company_id = ic.id
LEFT JOIN ins_car_commission_record cr ON cr.policy_id = p.id AND cr.status != 0
WHERE p.merchant_id = #{merchantId}
  AND YEAR(p.sign_date) = #{year}
  AND [季度/月份条件]
  AND p.is_deleted = 0
GROUP BY ic.id, p.policy_type
```

**导出**：支持导出当前视图的 Excel。

---

## 九、统计分析模块

> 菜单路径：车险 → 统计分析 → [各子菜单]

**通用说明**：
- 所有图表使用 ECharts（前端渲染）。
- 所有统计分析页面均提供【导出】按钮，导出当前视图数据为 Excel（≤5000 条同步，>5000 条异步+站内信）。
- 数据缓存：Redis，TTL 15 分钟（Key 格式：`ins:car:analysis:{merchantId}:{analysisType}:{筛选条件Hash}`），管理员可手动刷新缓存。
- 数据权限：与保单查询相同，管理员全量，业务员仅见自己数据。

---

### 9.1 业务来源分析

**菜单**：车险 → 统计分析 → 业务来源分析

**筛选条件**：日期范围（必填）、组织机构（多选树）、保险公司（多选下拉）。

**页面布局**：

**上方图表区**：
- 左图：各业务来源保单量占比——饼图（ECharts `pie`）。
- 右图：各业务来源保费金额占比——饼图。

**下方数据表格**：

| 保险公司 | 业务来源 | 件数 | 总保费 | 交强险保费 | 商业险保费 | 车船税 |
|----------|----------|------|--------|------------|------------|--------|
| 人保 | 直销 | 100 | 50万 | 20万 | 30万 | 1万 |
| ... | ... | ... | ... | ... | ... | ... |

**后端聚合 SQL**：
```sql
SELECT ic.insurance_company_name,
       p.business_source,
       COUNT(*) AS policy_count,
       SUM(p.premium_compulsory + p.premium_commercial) AS total_premium,
       SUM(p.premium_compulsory) AS compulsory_premium,
       SUM(p.premium_commercial) AS commercial_premium,
       SUM(p.vehicle_tax) AS vehicle_tax
FROM insurance_car_policy p
LEFT JOIN ins_company ic ON p.insurance_company_id = ic.id
WHERE p.merchant_id = #{merchantId}
  AND p.sign_date BETWEEN #{startDate} AND #{endDate}
  AND p.is_deleted = 0
  [AND p.insurance_company_id IN (#{companyIds})]
  [AND p.salesman_id IN (组织机构下的人员ID列表)]
GROUP BY ic.id, p.business_source
ORDER BY total_premium DESC
```

**业务来源字段**：从保单录入时的 `business_source` 字段取值，通过字典表 `ins_dict_business_source` 转换为中文显示。若 `business_source` 为空，归入「未标注」类别。

---

### 9.2 保险公司分析

**菜单**：车险 → 统计分析 → 保险公司分析

**筛选条件**：日期范围、组织机构。

**页面布局**：

**上方图表区（双饼图）**：
- 左图：各保司保单量占比（ECharts `pie`）。
- 右图：各保司保费占比（ECharts `pie`）。

**下方数据表格**：

| 保险公司 | 件数 | 总保费（总） | 净保费（净） | 上游手续费（收） | 下游手续费（支） | 利润（利） | 综合费率（率）|
|----------|------|------------|------------|----------------|---------------|-----------|-------------|

> **字段定义**（与操作手册保持一致）：
> - **总**：总保费 = 交强险保费 + 商业险保费 + 车船税
> - **净**：净保费 = 总保费 - 车船税
> - **收**：上游手续费（保司结算并已开票的跟单手续费金额）
> - **支**：下游手续费（支付给业务员/代理的佣金）
> - **利**：利润 = 收 - 支
> - **率**：利/净 = 利润 ÷ 净保费 × 100%
>
> 注意：收/支/利/率字段依赖佣金结算数据（阶段2完善），本阶段暂显示 0 或「--」。如保单结算已开票后净保费被修改，报表会实时更新；但如开票后跟单费用被修改，需重新结算才能更新。

**下钻功能**：
- 点击表格中某一保司行，或点击饼图某一扇区，页面展示该保司的**月度趋势折线图**（ECharts `line`）。
- 折线图 X 轴：月份，Y 轴：保费金额（万元），线条：总保费 / 交强险 / 商业险 三条线。
- 下钻后顶部展示面包屑「保险公司分析 > [保司名称]」，点击可返回。

**后端接口**：
- 列表数据：`GET /admin-api/ins/car/analysis/company?...`
- 下钻月度趋势：`GET /admin-api/ins/car/analysis/company/{companyId}/monthly?year=&merchantId=&...`

---

### 9.3 组织部门业绩分析

**菜单**：车险 → 统计分析 → 组织部门业绩分析

**筛选条件**：日期范围（必填）。

**页面布局**：
- 左侧：组织架构树（LazyLoad，默认展开到二级）。
- 右侧：选中节点的业绩数据表格，展示：件数、总保费、净保费、综合佣金率（阶段2后有数据）。
- 右侧下方：当前组织下一级明细展示（子部门/团队列表）。

**交互逻辑**：
- 点击左侧树节点，右侧数据刷新为该节点的汇总数据。
- 点击【展开下级】，左侧树节点异步加载子节点（避免初始化加载全量组织树导致性能问题）。
- 二次筛选：右侧可按保司/险种对当前组织数据做进一步筛选。

**后端处理**：
1. 组织树接口：`GET /admin-api/sys/dept/tree`（复用 yudao-cloud 现有接口）。
2. 节点业绩接口：`GET /admin-api/ins/car/analysis/dept/{deptId}?startDate=&endDate=&companyId=&policyType=`。
3. 后端递归查询该部门及所有子部门下的人员 ID，再聚合这些人员的保单数据（`salesman_id IN (子部门人员ID集合)`）。
4. 数据权限：只允许查询自己所在组织及下级组织的数据（通过 `@DataPermission` 注解实现）。

---

### 9.4 工号数据分析

**菜单**：车险 → 统计分析 → 工号数据分析

**筛选条件**：日期范围、保险公司（下拉）、险种类型（下拉）。

**数据表格**：

| 工号名称 | 保险公司 | 绑定人员数 | 保单量 | 总保费（万） | 上游手续费（万） | 综合费率(%) |
|----------|----------|-----------|--------|------------|----------------|------------|

**数据权限**：
- 管理员：展示本商户全量工号数据。
- 普通业务员：只展示自己绑定的工号数据（`ins_company_no_user.user_id = 当前用户`）。

**后端聚合**：按 `company_no_id` 分组，联查 `ins_company_no`（工号信息）、`ins_company_no_user`（工号绑定人数），聚合 `insurance_car_policy`（件数/保费）。

---

### 9.5 业务员业绩分析

**菜单**：车险 → 统计分析 → 业务员业绩分析

**筛选条件**：日期范围、组织机构（树形选择）、业务员姓名搜索（模糊搜索）。

**页面布局**：

**上方主表格**（按业务员汇总）：

| 业务员 | 所属部门 | 件数 | 总保费 | 人保 | 平安 | 太平洋 | ... |
|--------|----------|------|--------|------|------|--------|-----|

各保司列为动态列（根据该商户配置的保司自动生成），每格展示「件数 / 保费」。

**下方各保司明细表**（选中某业务员后展示）：

| 保险公司 | 件数 | 总保费 | 交强险保费 | 商业险保费 | 车船税 |
|----------|------|--------|------------|------------|--------|

**后端**：
- 主表格查询：按 `salesman_id` 分组，同时按 `insurance_company_id` 分组 PIVOT 动态列（或应用层处理）。
- 动态列策略：后端返回宽表 JSON，前端根据 `companyList` 动态渲染列（不用后端 PIVOT SQL）。
- 数据权限：管理员全量，业务员只见自己（`salesman_id = 自己`）。

---

### 9.6 区域占比分析

**菜单**：车险 → 统计分析 → 区域占比分析

**筛选条件**：日期范围、保险公司（多选）、组织机构（树形）。

**页面布局**：

**上方图表**（二选一，通过 Tab 切换）：
- 省份饼图：各省保单量占比（ECharts `pie`）。
- 省份热力地图：ECharts `map`，颜色深浅代表保费金额，鼠标悬浮展示省份名+保费总额。

**下方数据表格**：

| 部门 | 省份 | 人保件数 | 人保保费 | 平安件数 | 平安保费 | ... | 合计件数 | 合计保费 | 占比 |
|------|------|---------|--------|---------|--------|-----|---------|--------|-----|

**区域字段来源**：`insurance_car_policy.region_province`，该字段在录入时从车辆登记地（投保人地址 or VIN解析）获取，若为空则归入「未知地区」。

**热力地图实现**：前端引入 ECharts 中国地图（`china.json`），数据格式：`[{name: '广东', value: 1234567}]`。

---

### 9.7 交商占比分析

**菜单**：车险 → 统计分析 → 交商占比分析

**筛选条件**：日期范围、组织机构。

**页面布局**：

**图表区（三图联排）**：
- 图1：交强险 vs 商业险 件数占比饼图。
- 图2：交强险 vs 商业险 保费占比饼图。
- 图3：月度趋势折线图，X=月份，Y=保费金额（万元），两条线：交强险保费趋势、商业险保费趋势。

**下方数据表格**：

| 部门 | 交强险件数 | 交强险保费 | 商业险件数 | 商业险保费 |
|------|-----------|---------|---------|---------|

**险种判断**：`policy_type = 1` → 纯交强，`policy_type = 2` → 纯商业，`policy_type = 3` → 交商合并（按实际保费分配到对应列）。

---

### 9.8 新旧车占比分析

**菜单**：车险 → 统计分析 → 新旧车占比分析

**筛选条件**：日期范围、保险公司（多选）。

**页面布局**：

**图表区（双饼图）**：
- 左图：新车 vs 旧车 件数占比饼图。
- 右图：新车 vs 旧车 保费占比饼图。

**下方数据表格**：

| 保险公司 | 新车件数 | 新车保费 | 旧车件数 | 旧车保费 |
|----------|---------|--------|--------|--------|

**新旧车判断**：`insurance_car_policy.is_new_car`，`1=新车`，`0=旧车`（录入时由业务员选择）。

---

### 9.9 险种占比分析

**菜单**：车险 → 统计分析 → 险种占比分析

**筛选条件**：日期范围、保险公司（多选）、组织机构。

**页面布局**：

**上方图表**：各险种保单量占比饼图（ECharts `pie`）。

**下方数据表格**：

| 险种名称 | 件数 | 总保费 | 净保费 | 手续费 | 费率(%) |
|----------|------|--------|--------|--------|--------|

**险种分类**：险种来源于 `policy_type` 字段（交强/商业/交商）及产品库中的险种编码映射（`ins_product_type_code`），按险种编码分组聚合。若险种编码缺失，归入「其他险种」。

---

### 9.10 分支机构分析

**菜单**：车险 → 统计分析 → 分支机构分析

**筛选条件**：日期范围（必填）、保险公司（多选）。

**页面布局**（两个 Tab）：

**Tab1：汇总视图**
- 左侧：分支机构树（可展开到子机构）。
- 右侧表格——合计列：件数、总保费、净保费、保费比例；后续各保司分列：各保司件数、保费（动态列，按该商户配置的保司数量生成）。

**Tab2：明细视图**
- 同汇总视图结构，但按明细保单展示（件数较多时分页）。

**交互逻辑**：
- 点击左侧机构树节点，右侧数据切换为该机构汇总。
- 点击机构树节点前的展开箭头，异步加载子机构。
- 表格中保司列可横向滚动（固定「机构名」「合计」两列，其余保司列可滚动）。

**后端处理**：
- 递归查询子机构 ID，聚合该机构树下所有人员的保单。
- 按保司动态分列：后端返回 `{deptId, deptName, totalCount, totalPremium, companyBreakdown: [{companyId, companyName, count, premium}]}` 结构，前端渲染动态列。
- 缓存机构聚合数据（Redis，TTL 15分钟，Key 含机构ID+日期Range+商户ID）。
- 数据权限：只允许查询有权限的机构节点（yudao-cloud `@DataPermission` 机构维度）。

**两个 PDF 文档（82/83号）**对应两种查看视角：
- 82号=合计+各保司分列（Tab1）
- 83号=手续费费用查看（右侧按保司费用维度查看）

---

## 十、统计分析公共后端规范

### 10.1 接口路径规范

```
GET /admin-api/ins/car/analysis/{analysisType}
```

`analysisType` 枚举：`business-source` | `company` | `dept` | `company-no` | `salesman` | `region` | `compulsory-commercial` | `new-old-car` | `policy-type` | `branch`

### 10.2 通用请求参数

```java
public class InsCarAnalysisQuery {
    @NotNull
    private LocalDate startDate;     // 开始日期
    @NotNull
    private LocalDate endDate;       // 结束日期
    private List<Long> companyIds;   // 保险公司ID列表（可选）
    private Long deptId;             // 组织机构ID（可选，传0表示全量）
    private Integer policyType;      // 险种类型（可选）
}
```

### 10.3 缓存策略

- 缓存 Key：`ins:car:analysis:{merchantId}:{analysisType}:{MD5(排序后的请求参数JSON)}`
- TTL：15 分钟
- 手动刷新：管理员点击【刷新数据】，删除对应 Redis key，重新查询写入缓存。
- 注意：若当天有新保单录入，不主动失效缓存（允许 15 分钟延迟）；若执行了批量更新/删除操作，主动删除相关缓存。

### 10.4 导出规范

- 导出接口：`GET /admin-api/ins/car/analysis/{analysisType}/export`（参数同查询接口）。
- ≤ 5000 条：同步返回文件流。
- > 5000 条：返回 `{"code": 0, "msg": "正在生成，完成后站内信通知", "data": {"taskId": xxx}}`，后台异步用 EasyExcel 写文件到 OSS，完成后发站内信附链接。

---

## 十一、完整 API 接口清单（报表与统计分析模块）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/admin-api/ins/car/report/supervisory` | 监管报表数据 |
| GET | `/admin-api/ins/car/report/financial` | 财务报表数据 |
| GET | `/admin-api/ins/car/report/business` | 业务报表数据 |
| GET | `/admin-api/ins/car/report/export` | 报表导出 |
| GET | `/admin-api/ins/car/analysis/business-source` | 业务来源分析 |
| GET | `/admin-api/ins/car/analysis/company` | 保险公司分析 |
| GET | `/admin-api/ins/car/analysis/company/{id}/monthly` | 保司月度趋势下钻 |
| GET | `/admin-api/ins/car/analysis/dept` | 组织部门业绩 |
| GET | `/admin-api/ins/car/analysis/company-no` | 工号数据分析 |
| GET | `/admin-api/ins/car/analysis/salesman` | 业务员业绩分析 |
| GET | `/admin-api/ins/car/analysis/region` | 区域占比分析 |
| GET | `/admin-api/ins/car/analysis/compulsory-commercial` | 交商占比分析 |
| GET | `/admin-api/ins/car/analysis/new-old-car` | 新旧车占比分析 |
| GET | `/admin-api/ins/car/analysis/policy-type` | 险种占比分析 |
| GET | `/admin-api/ins/car/analysis/branch` | 分支机构分析 |
| GET | `/admin-api/ins/car/analysis/{type}/export` | 统计分析导出（各类型通用） |

---

## 十二、模块归属说明（yudao-cloud 微服务）

以上所有功能均归属于 `intermediary-module-ins-order` 微服务（车险/非车险保单核心模块）下的以下 Controller：

```
controller/admin/
├── AdminInsCarPolicyController.java          # 保单录入/查询/导入/导出/批量操作
├── AdminInsCarEndorsementController.java     # 批单管理
├── AdminInsCarPolicySceneController.java     # 查询场景管理
├── AdminInsCarPolicySettingsController.java  # 保单设置 & 同步设置
├── AdminInsCarReportController.java          # 报表管理
└── AdminInsCarAnalysisController.java        # 统计分析
```

Service 层对应：
```
service/
├── InsCarPolicyService / InsCarPolicyServiceImpl
├── InsCarEndorsementService / InsCarEndorsementServiceImpl
├── InsCarAnalysisService / InsCarAnalysisServiceImpl
└── InsCarReportService / InsCarReportServiceImpl
```

数据库 Schema：`db_ins_order`，表前缀 `insurance_car_` 和 `ins_car_`。

---

*完 · 三篇文档覆盖阶段1-PC管理后台-车险业务全部功能点*

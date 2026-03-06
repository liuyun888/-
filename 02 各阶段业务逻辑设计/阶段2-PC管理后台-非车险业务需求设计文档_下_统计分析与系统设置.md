# 非车险业务需求设计文档（下）
## 阶段2 - PC管理后台 - 非车险业务
### 模块：统计分析 + 系统设置

---

## 一、统计分析公共说明

### 1.1 公共筛选条件

所有统计分析页面均包含以下通用筛选条件：

| 字段 | 说明 |
|------|------|
| 日期类型 + 日期区间 | 签单日期/支付日期/起保日期，配合起止日期选择器 |
| 保险公司 | 下拉多选，不选则统计全部保司 |
| 险种 | 下拉多选，不选则统计全部险种 |
| 机构 | 树形机构选择，含下级汇总 |

点击【查询】刷新图表和数据表；点击【导出】导出当前统计结果为 Excel。

### 1.2 公共统计指标说明

所有统计分析中，各指标含义统一如下：

| 指标名 | 计算公式 | 说明 |
|--------|----------|------|
| 单量 | COUNT(policy_id) | 保单数量 |
| 总保费（总） | SUM(total_premium) | 全保费合计 |
| 净保费（净） | SUM(net_premium) | 净保费合计 |
| 上游手续费（收） | SUM(upstream_fee) | 向保险公司收取的手续费 |
| 下游手续费（支） | SUM(downstream_fee) | 付给业务员/机构的手续费 |
| 利润（利） | 上游手续费 - 下游手续费 | 即收-支 |
| 利润率（率） | 利润 / 净保费 × 100% | 即利/净 |

---

## 二、非车险别占比分析

### 2.1 入口

导航：【非车】→【统计分析】→【险别占比分析】

### 2.2 页面结构与交互

**顶部**：筛选条件区（同公共筛选）

**中部：图表区**
- 左图：**各险种单量占比饼图**（ECharts Pie），图例显示险种名称+单量+占比百分比。
- 右图：**各险种保费占比饼图**（ECharts Pie），图例显示险种名称+净保费+占比百分比。
- 图表右上角提供「切换图表类型」按钮，可在饼图/柱状图间切换。

**底部：数据明细表**

按险种分组统计，表格字段：

| 险种名称 | 单量 | 总保费 | 净保费 | 上游手续费 | 下游手续费 | 利润 |
|---------|------|-------|-------|-----------|-----------|------|
| 财产险 | ... | ... | ... | ... | ... | ... |
| 工程险 | ... | ... | ... | ... | ... | ... |
| 责任险 | ... | ... | ... | ... | ... | ... |
| 农险 | ... | ... | ... | ... | ... | ... |
| 健康险 | ... | ... | ... | ... | ... | ... |
| 其他 | ... | ... | ... | ... | ... | ... |
| **合计** | ... | ... | ... | ... | ... | ... |

### 2.3 后端接口

```
GET /non-vehicle/statistics/insurance-type-ratio
请求参数：dateType, startDate, endDate, companyIds, orgId
返回：
{
  "chartData": [{"insuranceType":"财产险", "policyCount":100, "totalPremium":500000, "netPremium":450000, "ratio":0.35},...],
  "tableData": [...],
  "total": {...汇总行...}
}
```

SQL 核心逻辑：
```sql
SELECT 
  insurance_type,
  COUNT(*) AS policy_count,
  SUM(total_premium) AS total_premium,
  SUM(net_premium) AS net_premium,
  SUM(upstream_fee) AS upstream_fee,
  SUM(downstream_fee) AS downstream_fee,
  SUM(upstream_fee - downstream_fee) AS profit
FROM ins_non_vehicle_policy
WHERE tenant_id = ? AND deleted = 0
  AND [日期条件] AND [保司条件] AND [机构条件]
GROUP BY insurance_type
ORDER BY policy_count DESC
```

---

## 三、非车分支机构分析

### 3.1 入口

导航：【非车】→【统计分析】→【分支机构分析】

### 3.2 页面结构与交互

**顶部**：筛选条件区（含保险公司筛选）

**中部：图表区**
- 按所选保险公司分列展示各机构的业绩柱状图（ECharts Bar）。
- X 轴：机构名称；Y 轴：净保费。
- 可通过图表右侧下拉切换显示「总保费」「净保费」「单量」等维度。

**左侧：机构树**
- 展示所有分支机构的树形结构，点击某节点，右侧表格只显示该机构（含下级）的数据。

**右侧：数据表**
- 行：机构列表（含层级缩进）
- 列：**合计列**（单量/总保费/净保费/利润）+ **各保险公司分列**（每个保司一列，展示该机构在此保司的净保费）。

> 若筛选了特定保司，只显示该保司的分列数据，其余保司列隐藏。

### 3.3 后端接口

```
GET /non-vehicle/statistics/org-analysis
请求参数：dateType, startDate, endDate, companyIds, orgId
返回：机构树状结构 + 每个机构节点的各保司数据对象
```

SQL 核心：按 `org_id + insurance_company_id` 做两层 GROUP BY，结果在应用层组装成树形结构。涉及多保司动态列，可在应用层做 Pivot，或前端动态渲染列。

---

## 四、非车保险公司分析

### 4.1 入口

导航：【非车】→【统计分析】→【保险公司分析】

### 4.2 页面结构与交互

**顶部**：筛选条件区

**中部：图表区（双图）**
- 左图：各保司**单量排名柱状图**（ECharts Bar，降序排列）
- 右图：各保司**保费占比饼图**（ECharts Pie）

**底部：数据明细表**

按保险公司分组统计，表格字段：

| 保险公司 | 单量 | 总保费 | 净保费 | 收（上游手续费） | 支（下游手续费） | 利（利润） | 率（利润率） |
|---------|------|-------|-------|----------------|----------------|-----------|------------|
| 平安财险 | ... | ... | ... | ... | ... | ... | ... |
| 人保财险 | ... | ... | ... | ... | ... | ... | ... |
| ... | | | | | | | |
| **合计** | ... | ... | ... | ... | ... | ... | ... |

### 4.3 后端接口

```
GET /non-vehicle/statistics/company-analysis
请求参数：dateType, startDate, endDate, insuranceTypeIds, orgId
返回：{ chartData: [...], tableData: [...], total: {...} }
```

---

## 五、非车区域占比分析

### 5.1 入口

导航：【非车】→【统计分析】→【区域占比分析】

### 5.2 页面结构与交互

**顶部**：筛选条件区（含日期/险种/保司）

**中部：图表区**
- 左图：各省市**保单量占比饼图**（ECharts Pie）或**地图热力图**（ECharts Map，中国地图，颜色深浅表示保费量大小）。
- 右图：各省市**保费占比饼图**（ECharts Pie）。
- 图表类型可切换（饼图/地图）。

**底部：数据明细表**
- 按省市+机构+保险公司三维度交叉展示数据。
- 字段：区域（省市）、机构名称、保险公司、单量、总保费、净保费、上游手续费、下游手续费、利润。

### 5.3 区域数据来源

区域字段从保单录入时的 `region`（投保区域/省市）字段获取，统计时按 `region` 做 GROUP BY。

### 5.4 后端接口

```
GET /non-vehicle/statistics/region-analysis
请求参数：dateType, startDate, endDate, companyIds, insuranceTypeIds, orgId
返回：{ mapData: [{name:'广东', value:1200000},...], tableData: [...] }
```

---

## 六、非车业务来源分析

### 6.1 入口

导航：【非车】→【统计分析】→【业务来源分析】

### 6.2 页面结构与交互

**顶部**：筛选条件区

**中部：图表区**
- 各渠道（直销/转介绍/经纪/代理/其他等）的**业务量占比饼图**和**保费占比柱状图**。

**底部：交叉统计数据表**
- 行：业务来源渠道
- 列：保险公司分列（每个保司一列，展示该渠道在此保司的单量/保费）
- 最后加「合计」行

字段：业务来源 | 单量 | 总保费 | 净保费 | 上游手续费 | 下游手续费 | 利润 | [各保司列...]

### 6.3 后端接口

```
GET /non-vehicle/statistics/business-source-analysis
请求参数：dateType, startDate, endDate, companyIds, insuranceTypeIds, orgId
返回：{ chartData: [...], tableData: [...], companies: [保司列表，用于前端动态列渲染] }
```

---

## 七、系统设置 - 产品管理

### 7.1 入口

导航：【非车】→【系统设置】→【产品管理】

页面包含三个 Tab：**险种类别** | **系统产品** | **自定义产品**

---

### 7.2 险种类别 Tab

展示平台预置的非车险种类别列表（只读展示）：
- 列表字段：险种编码、险种名称、状态
- 用于保单录入时的险种下拉数据源

---

### 7.3 系统产品 Tab

展示平台预置的标准产品库（只读，不可增删改）：
> 注：**系统产品仅适用于标的标识为「车辆」的非车保单**。

查询条件：险种类别（下拉）、产品名称（模糊）
列表字段：保险公司、险种类别、产品名称、产品方案数量、状态

---

### 7.4 自定义产品 Tab

用户自行维护的非标准产品：
> 注：**自定义产品在保单录入时，无论标的标识是人/物品/车辆，均可使用**。

#### 7.4.1 新增产品

点击【新增产品】按钮，弹出新增表单：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 保险公司 * | 下拉 | 是 | - |
| 险种类别 * | 下拉（从险种类别加载） | 是 | - |
| 产品名称 * | 文本 | 是 | 全局唯一校验（同一租户内产品名称不可重复） |

点击【确定】保存，后端校验：
1. 产品名称在当前租户内是否已存在（`ins_non_vehicle_product` 表唯一索引 `tenant_id + product_name`）。
2. 保险公司和险种类别不为空。
3. 保存成功后，产品立即在保单录入的产品下拉中可选，且在保单导入时参与险种/产品名称匹配校验。

#### 7.4.2 编辑产品

点击产品行【编辑】，可修改险种类别和产品名称（保险公司不可修改）。
> 注：若已有保单使用此产品，修改产品名称会影响已有保单的显示，需前端给出提醒。

#### 7.4.3 删除产品

点击【删除】，后端校验：是否有保单正在使用此产品（`ins_non_vehicle_policy.product_id = ?`），若有则拒绝删除并提示「该产品已被 XX 张保单使用，无法删除」。

### 7.5 数据库设计

#### `ins_non_vehicle_product`

```sql
CREATE TABLE `ins_non_vehicle_product` (
  `id`                    BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`             BIGINT       NOT NULL,
  `insurance_company_id`  BIGINT       COMMENT '保险公司ID（系统产品必填，自定义产品可选）',
  `insurance_type_id`     BIGINT       NOT NULL COMMENT '险种类别ID',
  `insurance_type_name`   VARCHAR(100) NOT NULL COMMENT '险种类别名称',
  `product_name`          VARCHAR(200) NOT NULL COMMENT '产品名称',
  `product_type`          TINYINT      NOT NULL COMMENT '1-系统产品 2-自定义产品',
  `status`                TINYINT      DEFAULT 1 COMMENT '1-启用 0-禁用',
  `creator`               BIGINT,
  `create_time`           DATETIME     DEFAULT CURRENT_TIMESTAMP,
  `updater`               BIGINT,
  `update_time`           DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`               TINYINT(1)   DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_product_name` (`tenant_id`, `product_name`, `deleted`)
) ENGINE=InnoDB COMMENT='非车险产品库';
```

---

## 八、系统设置 - 模板设置

### 8.1 入口

导航：【非车】→【系统设置】→【模板设置】

用于管理非车保单导入/导出时使用的 Excel 模板。

---

### 8.2 模板列表

展示当前租户的所有已配置模板，字段：模板名称、授权组织、创建时间、状态（启用/禁用）、操作（查看/编辑/禁用）。

---

### 8.3 新增模板

点击【新增模板】，进入模板配置页：

#### Step 1：基本信息
| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 模板名称 * | 文本 | 是 | 如「非车业务数据导出」「财责险导入模板」 |
| 授权组织 | 树形多选 | 否 | 限制哪些机构可使用此模板，不选则全部可用 |

#### Step 2：字段配置

字段分为「未选字段区」和「已选字段区」：
- 左侧「未选字段」：按大类分组（不可调整大类顺序），组内字段可单个勾选：
  - **基本信息**：保险公司、标的类型、险种编码、险种、互联网业务、涉农业务、保单状态、签单日期、起保日期、保险止期、支付日期、渠道名称、业务员、出单员、录入方式等
  - **组织结构**：归属机构、部门、团队等
  - **被保人信息**：被保人姓名、证件类型、证件号等
  - **投保人信息**：投保人名称、证件号等
  - **保单费用**：全保费、净保费
  - **上游手续费**：上游比例、上游金额、上游结算状态等
  - **下游手续费**：下游比例、下游金额、下游结算状态等
  - **批单信息**：原保单号、批改类型等
- 右侧「已选字段」：已勾选的字段列表，支持拖拽调整顺序（**同一大类内的小类可拖拽，大类顺序不变**）。

#### Step 3：保存

点击【保存】，模板配置存入 `ins_non_vehicle_template` 和 `ins_non_vehicle_template_field` 表。

---

### 8.4 编辑模板

点击已有模板的【编辑】，进入与新增相同的配置页，可修改模板名称、授权组织和字段配置。

### 8.5 禁用模板

点击【禁用】，该模板在保单导入/导出时不再出现在可选模板列表中（`status=0`）。

---

### 8.6 数据库设计

#### `ins_non_vehicle_template`

```sql
CREATE TABLE `ins_non_vehicle_template` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT,
  `tenant_id`       BIGINT       NOT NULL,
  `template_name`   VARCHAR(200) NOT NULL COMMENT '模板名称',
  `org_ids`         JSON         COMMENT '授权组织ID列表',
  `status`          TINYINT      DEFAULT 1 COMMENT '1-启用 0-禁用',
  `creator`         BIGINT,
  `create_time`     DATETIME     DEFAULT CURRENT_TIMESTAMP,
  `updater`         BIGINT,
  `update_time`     DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         TINYINT(1)   DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB COMMENT='非车险Excel模板配置表';
```

#### `ins_non_vehicle_template_field`

```sql
CREATE TABLE `ins_non_vehicle_template_field` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT,
  `template_id`     BIGINT       NOT NULL COMMENT '模板ID',
  `field_group`     VARCHAR(100) COMMENT '字段大类名称',
  `field_code`      VARCHAR(100) NOT NULL COMMENT '字段代码（对应policy表字段名）',
  `field_label`     VARCHAR(200) NOT NULL COMMENT '字段显示名称（Excel列头）',
  `is_required`     TINYINT(1)   DEFAULT 0 COMMENT '是否必填（导入时）',
  `sort`            INT          DEFAULT 0 COMMENT '排序',
  PRIMARY KEY (`id`),
  KEY `idx_template_id` (`template_id`)
) ENGINE=InnoDB COMMENT='非车险模板字段配置明细表';
```

---

## 九、系统设置 - 保单设置

### 9.1 入口

导航：【非车】→【系统设置】→【保单设置】

> 注：修改保单设置后，需**点击保存并重新登录**才能生效（某些配置项影响前端缓存）。

---

### 9.2 录单设置（一）：保单业务归属设置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|-------|------|
| 非车保单业务归属 | 单选：业务员 / 出单员 / 录单员 | 业务员 | 影响统计分析时保单按哪个人员字段汇总归属 |

- 保存后，统计分析模块中所有「按业务员」的汇总改为按所选归属人员字段查询。
- 配置存入 `sys_config` 表，`config_key = non_vehicle_policy_belong_type`。

---

### 9.3 录单设置（二）：下游手续费校验

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|-------|------|
| 组织维度的下游手续费上限校验 | 勾选框（可多选组织） | 不勾选 | 勾选某组织后，该组织人员在修改保单时，下游手续费及跟单手续费不得超过已匹配政策的比例 |

- 后端逻辑：保存非车保单时，若当前用户所属机构在此校验列表中，则读取该保单匹配的政策 `downstream_rate`，若用户填写的 `downstream_rate` > 政策 `downstream_rate`，则返回错误「下游手续费不能超过政策配置的 XX%」。
- 配置存入 `sys_config`，`config_key = non_vehicle_downstream_check_orgs`，值为组织ID的 JSON 数组。

---

### 9.4 录单设置（三）：相同保单号不同产品支持

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|-------|------|
| 允许同一险种下相同保单号录入不同产品 | 险种维度多选勾选框 | 全不勾选 | 勾选后，该险种下允许保单号相同但产品不同的保单同时存在 |

- 默认情况：`保险公司 + 保单号` 联合唯一，重复录入提示「保单号已存在」。
- 开启后：唯一索引变为 `保险公司 + 保单号 + 产品名称`（或通过应用层逻辑处理，而非修改 DB 索引）。
- 配置存入 `sys_config`，`config_key = non_vehicle_same_policy_no_insurance_types`，值为险种ID列表。

---

### 9.5 提醒设置与汇率设置

> **这两项为后期非车理赔模块预留功能，当前版本暂不实现**，页面展示「敬请期待」占位说明。

---

### 9.6 保单查询默认设置（补充）

> 此部分属于保单设置页的全局查询行为配置（补充排期表说明）：

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|-------|------|
| 默认日期类型 | 单选 | 签单日期 | 进入保单查询页时默认选中的日期类型 |
| 默认查询时间范围 | 下拉：近1个月/近3个月/当月 | 近1个月 | 进入页面时自动填充的日期区间 |
| 多保单号逗号分隔搜索 | 开关 | 关闭 | 开启后，保单号输入框支持输入多个用逗号分隔的保单号批量查询 |
| 未录入保单统计角标 | 开关 | 关闭 | 开启后，菜单或列表页显示「待录入」数量角标 |

- 以上配置存 `sys_config` 表，影响所有当前租户下用户的非车查询默认体验。

---

## 十、相关接口清单（统计分析/系统设置模块）

| 接口 | 方法 | 说明 |
|------|------|------|
| `/non-vehicle/statistics/insurance-type-ratio` | GET | 险别占比分析数据 |
| `/non-vehicle/statistics/org-analysis` | GET | 分支机构分析数据 |
| `/non-vehicle/statistics/company-analysis` | GET | 保险公司分析数据 |
| `/non-vehicle/statistics/region-analysis` | GET | 区域占比分析数据 |
| `/non-vehicle/statistics/business-source-analysis` | GET | 业务来源分析数据 |
| `/non-vehicle/statistics/export` | GET | 统计数据导出（通用，传type参数区分） |
| `/non-vehicle/product/type-list` | GET | 险种类别列表 |
| `/non-vehicle/product/system-list` | GET | 系统产品分页列表 |
| `/non-vehicle/product/custom/page` | GET | 自定义产品分页列表 |
| `/non-vehicle/product/custom/create` | POST | 新增自定义产品 |
| `/non-vehicle/product/custom/update/{id}` | PUT | 编辑自定义产品 |
| `/non-vehicle/product/custom/delete/{id}` | DELETE | 删除自定义产品 |
| `/non-vehicle/template/list` | GET | 模板列表 |
| `/non-vehicle/template/create` | POST | 新增模板 |
| `/non-vehicle/template/update/{id}` | PUT | 编辑模板 |
| `/non-vehicle/template/disable/{id}` | PUT | 禁用模板 |
| `/non-vehicle/template/field-meta` | GET | 全量可选字段元数据（按大类分组） |
| `/non-vehicle/settings/get` | GET | 获取保单设置（全量） |
| `/non-vehicle/settings/save` | POST | 保存保单设置 |

---

## 十一、前端路由规划（参考）

```
/non-vehicle
├── /policy
│   ├── /entry              # 保单录入（手工 + 批单）
│   └── /query              # 保单查询列表
├── /policy-management      # 政策管理
│   └── /list               # 非车政策列表
├── /statistics
│   ├── /insurance-type     # 险别占比分析
│   ├── /org                # 分支机构分析
│   ├── /company            # 保险公司分析
│   ├── /region             # 区域占比分析
│   └── /business-source    # 业务来源分析
└── /settings
    ├── /product            # 产品管理
    ├── /template           # 模板设置
    └── /policy-config      # 保单设置
```

---

*文档版本：V1.0 | 对应排期表：阶段2-PC管理后台-非车险业务 | 参考操作手册：97、98、99、100、101、102、103、104、105、106号*

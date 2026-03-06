# 阶段2-PC佣金系统详细需求文档【补充篇A】
## 车险政策管理模块 + 多级结算模块

> 版本：V4.0 | 日期：2026-02-26 | 技术栈：yudao-cloud（微服务版）+ MySQL 8.0 + Redis  
> 配置：1前端 + 1后端  
> 说明：本文档为原三篇文档（上/中/下篇）的补充，覆盖排期表中遗漏的功能点  
> 对应排期表：阶段2-PC管理后台-佣金系统 Sheet

---

## 一、模块总览

| 模块 | 功能点 | 对应PDF编号 | 工时（前+后） |
|------|--------|------------|---------------|
| 车险政策管理 | 留点政策配置 | PDF-66（留点设置）、PDF-67（留点政策设置） | 1+1.5 = 2.5天 |
| 车险政策管理 | 加投点政策配置（新版） | PDF-65（新版加投点政策） | 0.5+1 = 1.5天 |
| 车险政策管理 | 报价赋值政策配置 | PDF-69（报价赋值政策设置）、PDF-70（报价赋值政策设置） | 1+1.5 = 2.5天 |
| 车险政策管理 | 预核保禁止投保名单 | PDF-68（预核保禁止投保提示） | 0.5+1 = 1.5天 |
| 多级结算 | 多级结算政策配置与负责人绑定 | PDF-196（组织维护管理多级结算负责人设置）、PDF-244（多级结算负责人设置）、PDF-245（多级结算政策设置） | 1+1.5 = 2.5天 |

---

## 二、车险政策管理模块

> **菜单路径**：佣金管理 → 车险政策管理

### 2.1 留点政策配置
> 对应PDF：**PDF-66（留点设置）**、**PDF-67（留点政策设置）**

#### 2.1.1 功能说明

配置各保司、各险种（交强险/商业险）对应的留点比例（即经纪人/代理人可留存的手续费比例）。支持按机构等级和业务员职级进行差异化配置，确保留点不超过合规上限。

#### 2.1.2 留点政策列表页

**入口**：佣金管理 → 车险政策管理 → 留点政策

**展示字段**：

| 列名 | 说明 |
|------|------|
| 保险公司 | 关联的保司名称 |
| 险种 | 交强险 / 商业险 |
| 机构等级 | 一级 / 二级 / 三级等 |
| 业务员职级 | 对应职级（支持"全部"通配） |
| 留点比例下限（%） | 最低可留比例 |
| 留点比例上限（%） | 最高可留比例（合规控制） |
| 状态 | 启用 / 停用 |
| 生效日期 | 规则生效时间 |
| 操作 | 编辑 / 停用 / 查看历史 |

**搜索条件**：保险公司（下拉多选）、险种（下拉）、状态（下拉）

**操作按钮**：
- 【新增政策】→ 弹出新增弹窗
- 【批量导入】→ Excel批量上传（模板需提供）
- 【导出】→ 导出当前筛选结果

#### 2.1.3 新增/编辑留点政策弹窗

**弹窗表单字段**：

| 字段名 | 类型 | 必填 | 校验规则 | 说明 |
|--------|------|------|----------|------|
| 保险公司 | 下拉（从保司配置表取） | 是 | | |
| 险种 | 单选（交强险/商业险/全部） | 是 | | |
| 机构等级 | 下拉（从组织等级字典取） | 否 | 空=适用全部等级 | |
| 业务员职级 | 下拉（从职级表取） | 否 | 空=适用全部职级 | |
| 留点比例下限（%） | 数字输入 | 是 | 0~100，≤上限 | |
| 留点比例上限（%） | 数字输入 | 是 | 0~100，≥下限，且≤监管合规上限 | 超限则红色警告 |
| 生效日期 | 日期选择 | 是 | 不能早于今天 | |
| 变更原因 | 文本域 | 是 | 不超过500字 | 每次变更必填原因 |

**合规校验**（后端）：
1. 留点上限不得超过该保司该险种的监管返佣上限（`insurance_company_config.max_commission_rate`）
2. 若超限，接口返回错误：`留点比例上限(X%)超出监管上限(Y%)，请调整`
3. 校验通过后写入 `car_policy_point_config` 表
4. 同时在 `commission_rate_history` 写入变更记录（change_type=CREATE/UPDATE）

**点击【取消】**：关闭弹窗，不保存

#### 2.1.4 留点政策匹配优先级

报价/出单时，系统按以下优先级匹配留点政策（精确>宽泛）：

```
1. 精确匹配：保司 + 险种 + 机构等级 + 职级
2. 半精确：保司 + 险种 + 机构等级（职级=NULL通配）
3. 半精确：保司 + 险种（机构等级=NULL + 职级=NULL）
4. 兜底：保司（险种/机构等级/职级均通配）
```

同级多条规则取 `priority DESC` 最高的一条。

#### 2.1.5 数据库表

```sql
CREATE TABLE `car_policy_point_config` (
  `id`                  bigint(20)    NOT NULL AUTO_INCREMENT,
  `insurance_company`   varchar(128)  NOT NULL COMMENT '保险公司代码',
  `insurance_type`      varchar(32)   NOT NULL COMMENT 'COMPULSORY（交强险）/COMMERCIAL（商业险）/ALL',
  `org_level`           varchar(32)   DEFAULT NULL COMMENT '机构等级（NULL=通配）',
  `rank_code`           varchar(32)   DEFAULT NULL COMMENT '业务员职级代码（NULL=通配）',
  `point_rate_min`      decimal(6,4)  NOT NULL COMMENT '留点比例下限（0.2500=25%）',
  `point_rate_max`      decimal(6,4)  NOT NULL COMMENT '留点比例上限',
  `regulatory_max_rate` decimal(6,4)  DEFAULT NULL COMMENT '该保司监管上限（冗余字段）',
  `effective_date`      date          NOT NULL COMMENT '生效日期',
  `expire_date`         date          DEFAULT NULL COMMENT '失效日期（NULL=永不失效）',
  `priority`            int(11)       DEFAULT 0 COMMENT '匹配优先级（越大越优先）',
  `change_reason`       varchar(500)  DEFAULT NULL COMMENT '变更原因',
  `status`              tinyint(1)    DEFAULT 1 COMMENT '状态（0停用 1启用）',
  `creator`             varchar(64)   DEFAULT NULL,
  `create_time`         datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`             varchar(64)   DEFAULT NULL,
  `update_time`         datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`             tinyint(1)    DEFAULT 0,
  `tenant_id`           bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_company_type` (`insurance_company`, `insurance_type`),
  KEY `idx_effective_date` (`effective_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='车险留点政策配置表';
```

---

### 2.2 加投点政策配置（新版）
> 对应PDF：**PDF-65（政策优化之新版加投点政策）**

#### 2.2.1 功能说明

配置阶梯式加投点激励政策：业务员（或机构）在某结算周期内累积FYP（首年保费）达到对应档位，即可在基础留点之上额外获得加投点比例奖励。支持批次管理（每批次设有效期），历史批次版本不可删除。

#### 2.2.2 加投点政策批次列表页

**入口**：佣金管理 → 车险政策管理 → 加投点政策

**展示字段**：

| 列名 | 说明 |
|------|------|
| 批次号 | 系统自动生成（BATCH+YYYYMM+序号） |
| 保险公司 | |
| 适用险种 | 交强险/商业险/全部 |
| 批次有效期 | 开始日期 ~ 结束日期 |
| 档位数量 | 该批次配置的阶梯档位数 |
| 状态 | 有效 / 过期 / 停用 |
| 操作 | 查看档位 / 停用 |

**操作按钮**：
- 【新增批次】→ 弹出新增弹窗

#### 2.2.3 新增批次弹窗

**弹窗字段（顶部基础信息）**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 保险公司 | 下拉 | 是 | |
| 适用险种 | 单选 | 是 | 交强险/商业险/全部 |
| 批次开始日期 | 日期 | 是 | |
| 批次结束日期 | 日期 | 是 | 必须晚于开始日期 |
| 统计周期 | 下拉 | 是 | 月度/季度（影响FYP累积区间） |
| 备注 | 文本域 | 否 | |

**弹窗中部（阶梯档位表格，可动态增减行）**：

| 档位序号 | FYP区间下限（万元） | FYP区间上限（万元） | 加投点比例（%） | 说明 |
|---------|------------------|------------------|---------------|------|
| 1 | 0 | 50 | 0.5% | 铜牌档 |
| 2 | 50 | 100 | 1.0% | 银牌档 |
| 3 | 100 | 999999 | 1.5% | 金牌档 |

- 点击【+ 添加档位】在末尾新增一行
- 点击行末【删除】移除该行
- 档位区间不允许重叠，后端校验

**后端处理**：
1. 校验同一保司+险种在同一时间段内不允许存在两个有效批次（时间重叠校验）
2. 校验阶梯档位区间不重叠、下限<上限
3. 将档位数据序列化为JSON：
   ```json
   {
     "tiers": [
       {"fyp_min": 0, "fyp_max": 500000, "extra_rate": 0.005, "label": "铜牌档"},
       {"fyp_min": 500000, "fyp_max": 1000000, "extra_rate": 0.010, "label": "银牌档"},
       {"fyp_min": 1000000, "fyp_max": 9999999, "extra_rate": 0.015, "label": "金牌档"}
     ]
   }
   ```
4. 插入 `car_policy_extra_point_batch` 表，批次版本不可物理删除

#### 2.2.4 加投点计算逻辑（后端）

佣金计算时匹配加投点：
1. 取当前有效批次（批次有效期覆盖保单承保日期，且状态=启用）
2. 统计业务员在当前统计周期内的累积FYP
3. 匹配最高满足条件的档位（取最大满足的 `fyp_min`）
4. 在留点基础上叠加 `extra_rate`：`final_point_rate = point_rate + extra_rate`
5. 最终叠加后的比例仍不得超过监管上限

#### 2.2.5 数据库表

```sql
CREATE TABLE `car_policy_extra_point_batch` (
  `id`              bigint(20)    NOT NULL AUTO_INCREMENT,
  `batch_no`        varchar(64)   NOT NULL COMMENT '批次号',
  `insurance_company` varchar(128) NOT NULL COMMENT '保险公司',
  `insurance_type`  varchar(32)   NOT NULL COMMENT '险种',
  `stat_period_type` varchar(16)  NOT NULL COMMENT 'MONTHLY/QUARTERLY',
  `start_date`      date          NOT NULL COMMENT '批次开始日期',
  `end_date`        date          NOT NULL COMMENT '批次结束日期',
  `tier_config`     json          NOT NULL COMMENT '阶梯档位JSON',
  `status`          tinyint(1)    DEFAULT 1 COMMENT '1有效 0停用',
  `remark`          varchar(500)  DEFAULT NULL,
  `creator`         varchar(64)   DEFAULT NULL,
  `create_time`     datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         varchar(64)   DEFAULT NULL,
  `update_time`     datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         tinyint(1)    DEFAULT 0 COMMENT '逻辑删除（不可物理删除）',
  `tenant_id`       bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`),
  KEY `idx_company_date` (`insurance_company`, `start_date`, `end_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='车险加投点政策批次表';
```

---

### 2.3 报价赋值政策配置
> 对应PDF：**PDF-69（报价赋值政策设置）**、**PDF-70（报价赋值政策设置详细）**

#### 2.3.1 功能说明

配置报价展示层的价格赋值规则：在保司返回的基础保费上，按规则进行加价/减价/折扣显示。  
**核心原则**：赋值规则仅影响报价展示层的显示价格，**不修改实际保费**，实际成交价仍以保司核定价为准。  
**合规约束**：赋值后展示价不得低于成本（`display_price ≥ cost_price`）。

#### 2.3.2 赋值政策列表页

**入口**：佣金管理 → 车险政策管理 → 报价赋值政策

**展示字段**：

| 列名 | 说明 |
|------|------|
| 保险公司 | |
| 险种 | 交强险/商业险/全部 |
| 赋值类型 | 金额赋值 / 百分比赋值 |
| 赋值方向 | 加价（+）/ 减价（-）|
| 赋值数值 | 加/减的金额（元）或比例（%） |
| 适用范围 | 说明适用的产品或渠道 |
| 生效时间 | 开始日期 |
| 失效时间 | 结束日期（NULL=永不失效） |
| 状态 | 启用/停用 |
| 操作 | 编辑 / 停用 / 查看历史 |

**搜索条件**：保险公司、险种、状态、生效时间范围

**操作按钮**：
- 【新增政策】→ 弹出新增弹窗

#### 2.3.3 新增/编辑赋值政策弹窗

| 字段名 | 类型 | 必填 | 校验 | 说明 |
|--------|------|------|------|------|
| 保险公司 | 下拉 | 是 | | |
| 险种 | 下拉（交强险/商业险/全部） | 是 | | |
| 赋值类型 | 单选 | 是 | | 金额（元）/ 百分比（%） |
| 赋值方向 | 单选 | 是 | | 加价（+）/ 减价（-） |
| 赋值数值 | 数字输入 | 是 | >0 | 若类型=百分比，则值范围0~100 |
| 展示价下限保护 | 金额输入 | 否 | | 展示价不得低于此值（成本保护） |
| 生效开始时间 | 日期时间 | 是 | | 精确到分钟 |
| 生效结束时间 | 日期时间 | 否 | 晚于开始时间 | 空=永不失效 |
| 备注 | 文本域 | 否 | | |

**报价展示层计算逻辑（前端联动）**：
```
显示价格 = 保司基础价格 + (赋值方向=加 ? +赋值值 : -赋值值)
若赋值类型=百分比：delta = 保司基础价格 × 赋值比例/100
最终展示价 = MAX(计算结果, 展示价下限)
```

> **注意**：报价API层面仅返回赋值后的展示价给用户/业务员，实际出单时以保司确认保费为准，避免价格欺诈合规风险。

#### 2.3.4 数据库表

```sql
CREATE TABLE `car_policy_quote_adjust` (
  `id`               bigint(20)    NOT NULL AUTO_INCREMENT,
  `insurance_company` varchar(128) NOT NULL COMMENT '保险公司',
  `insurance_type`   varchar(32)   NOT NULL COMMENT '险种',
  `adjust_type`      varchar(16)   NOT NULL COMMENT 'AMOUNT（金额）/PERCENT（百分比）',
  `adjust_direction` varchar(8)    NOT NULL COMMENT 'ADD（加价）/MINUS（减价）',
  `adjust_value`     decimal(12,4) NOT NULL COMMENT '赋值数值（金额元或百分比0~100）',
  `display_min_price` decimal(12,2) DEFAULT NULL COMMENT '展示价下限保护（元）',
  `effective_start`  datetime      NOT NULL COMMENT '生效开始时间',
  `effective_end`    datetime      DEFAULT NULL COMMENT '生效结束时间（NULL=永不失效）',
  `apply_scope`      varchar(255)  DEFAULT NULL COMMENT '适用范围说明',
  `status`           tinyint(1)    DEFAULT 1,
  `remark`           varchar(500)  DEFAULT NULL,
  `creator`          varchar(64)   DEFAULT NULL,
  `create_time`      datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          varchar(64)   DEFAULT NULL,
  `update_time`      datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          tinyint(1)    DEFAULT 0,
  `tenant_id`        bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_company_type` (`insurance_company`, `insurance_type`),
  KEY `idx_effective_time` (`effective_start`, `effective_end`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='车险报价赋值政策表';
```

---

### 2.4 预核保禁止投保名单
> 对应PDF：**PDF-68（预核保禁止投保提示）**

#### 2.4.1 功能说明

管理车险预核保风控名单，从车牌号、VIN码、被保人证件号等维度配置禁止投保规则。报价或投保操作发起时实时比对名单，命中则阻止并给业务员明确提示。

#### 2.4.2 名单管理列表页

**入口**：佣金管理 → 车险政策管理 → 禁保名单

**展示字段**：

| 列名 | 说明 |
|------|------|
| 名单类型 | 车牌号 / VIN码 / 证件号 / 手机号 |
| 名单值 | 具体的车牌/VIN/证件号/手机号（脱敏展示） |
| 禁保原因 | 欺诈 / 骗保 / 高风险 / 失信 / 其他 |
| 有效期至 | NULL=永久有效 |
| 来源 | 手动录入 / Excel批量导入 / 系统自动（风控引擎触发） |
| 状态 | 有效 / 已过期 / 已移除 |
| 录入人 | |
| 录入时间 | |
| 操作 | 移除 / 延期 |

**搜索条件**：名单类型、状态、录入时间范围

**操作按钮**：
- 【新增】→ 手动单条录入
- 【批量导入】→ Excel上传（模板字段：名单类型/名单值/禁保原因/有效期至/备注）
- 【导出】→ 导出当前名单

#### 2.4.3 新增名单弹窗

| 字段 | 类型 | 必填 | 校验 | 说明 |
|------|------|------|------|------|
| 名单类型 | 下拉 | 是 | | 车牌号/VIN码/证件号/手机号 |
| 名单值 | 文本 | 是 | 格式校验（车牌/VIN/身份证/手机） | |
| 禁保原因 | 下拉+文本说明 | 是 | | 欺诈/骗保/高风险/失信/其他 |
| 禁保说明 | 文本域 | 否 | 不超过500字 | 详细备注，仅内部可见 |
| 有效期至 | 日期 | 否 | 空=永久 | 到期后自动失效 |

**后端处理**：
1. 格式校验（如VIN码17位字母数字，身份证18位加权）
2. 检查是否已存在相同的名单值（同类型），若存在则提示是否覆盖
3. 写入 `car_risk_blacklist` 表，同时将名单**同步到Redis缓存**（key=`car:blacklist:{type}:{value}`）
4. 写入操作审计日志

#### 2.4.4 名单比对逻辑（报价/投保拦截）

在报价引擎和投保前置校验中集成（**异步缓存命中，不走DB**）：

```
比对顺序：
1. Redis GET car:blacklist:PLATE:{plateNo} → 命中则拦截
2. Redis GET car:blacklist:VIN:{vinCode}  → 命中则拦截
3. Redis GET car:blacklist:ID:{idNo}     → 命中则拦截
4. Redis GET car:blacklist:MOBILE:{mobile} → 命中则拦截

拦截响应：
{
  "blocked": true,
  "reason": "欺诈",
  "message": "该车辆/人员已被列入禁保名单，禁止投保。如有疑问请联系风控部门。",
  "blockListId": 12345
}
```

名单缓存刷新策略：
- 新增/移除名单时，立即删除对应Redis key
- Redis中的value存储禁保原因和过期时间，由定时任务每日00:30清理已过期名单

#### 2.4.5 数据库表

```sql
CREATE TABLE `car_risk_blacklist` (
  `id`            bigint(20)   NOT NULL AUTO_INCREMENT,
  `list_type`     varchar(16)  NOT NULL COMMENT 'PLATE/VIN/ID_NO/MOBILE',
  `list_value`    varchar(128) NOT NULL COMMENT '名单值（原始，未脱敏）',
  `list_value_md5` varchar(32) NOT NULL COMMENT 'MD5（用于索引查询）',
  `block_reason`  varchar(32)  NOT NULL COMMENT 'FRAUD/CLAIM_FRAUD/HIGH_RISK/DISHONEST/OTHER',
  `block_desc`    varchar(500) DEFAULT NULL COMMENT '详细说明',
  `expire_date`   date         DEFAULT NULL COMMENT '有效期（NULL=永久）',
  `source`        varchar(32)  DEFAULT 'MANUAL' COMMENT 'MANUAL/EXCEL_IMPORT/SYSTEM_AUTO',
  `status`        tinyint(1)   DEFAULT 1 COMMENT '1有效 0已移除',
  `remove_reason` varchar(255) DEFAULT NULL COMMENT '移除原因',
  `remover`       varchar(64)  DEFAULT NULL,
  `remove_time`   datetime     DEFAULT NULL,
  `creator`       varchar(64)  DEFAULT NULL,
  `create_time`   datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`       varchar(64)  DEFAULT NULL,
  `update_time`   datetime     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`       tinyint(1)   DEFAULT 0,
  `tenant_id`     bigint(20)   DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_type_md5` (`list_type`, `list_value_md5`),
  KEY `idx_expire_date` (`expire_date`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='车险风控禁保名单表';
```

---

## 三、多级结算模块

> **菜单路径**：佣金管理 → 多级结算  
> 对应PDF：**PDF-196（组织维护管理多级结算负责人设置）**、**PDF-244（多级结算负责人设置）**、**PDF-245（多级结算政策设置）**、**PDF-246（奖励结算）**

### 3.1 多级结算政策配置与负责人绑定

#### 3.1.1 功能说明

多级结算是佣金系统中的高级功能，核心逻辑为：

1. **政策配置**：配置组织（团队/分公司）负责人与下级出单佣金的分润链路比例（`override_hierarchy`）
2. **负责人绑定**：在组织架构维护页面为每个组织节点绑定「多级结算负责人」，系统自动关联对应的分润政策
3. **双向联动**：组织架构变更（如换负责人、调整层级）后，多级结算自动跟随重新计算

#### 3.1.2 多级结算政策列表页

**入口**：佣金管理 → 多级结算 → 政策配置

**展示字段**：

| 列名 | 说明 |
|------|------|
| 政策名称 | 如：总部团队A级分润政策 |
| 适用组织范围 | 绑定了该政策的组织节点名称 |
| 分润层级数 | 2~5级 |
| 各级分润比例 | 如：10%-5%-3%（第1~3级） |
| FYP激活门槛 | 负责人当月最低FYP（未达门槛不激活分润） |
| 生效日期 | |
| 状态 | 启用/停用 |
| 操作 | 编辑 / 查看分润明细 / 停用 |

**操作按钮**：
- 【新增政策】→ 弹出政策配置弹窗

#### 3.1.3 多级结算政策配置弹窗

| 字段名 | 类型 | 必填 | 校验 | 说明 |
|--------|------|------|------|------|
| 政策名称 | 文本 | 是 | 不超过64字，唯一 | |
| 适用险种 | 多选 | 是 | 默认全部 | |
| 分润层级数 | 数字 | 是 | 2~5 | 支持2级至5级分润链路 |
| 各级分润比例（%） | 分层填写（动态根据层级数展示） | 是 | 各级总和≤30%，单级≤20% | |
| FYP激活门槛（元/月） | 金额 | 是 | ≥0；0表示无门槛 | 负责人当月FYP须达到此值才激活分润资格 |
| 生效日期 | 日期 | 是 | 不早于今天 | |
| 变更原因 | 文本域 | 是 | | |

**动态分润比例配置表**（分润层级数=3时展示3行）：

| 层级 | 说明 | 分润比例（%） | 激活门槛FYP（元/月） |
|------|------|--------------|-------------------|
| 第1级（直接上级） | 下级每产生1元佣金，第1级负责人获得X% | 输入框 | 输入框 |
| 第2级（隔代上级） | | 输入框 | 输入框 |
| 第3级（大区负责人） | | 输入框 | 输入框 |

**后端存储**（`override_hierarchy` JSON）：
```json
{
  "product_category": ["CAR", "LIFE", "HEALTH"],
  "hierarchy": [
    {"level": 1, "split_rate": 0.10, "fyp_threshold": 50000},
    {"level": 2, "split_rate": 0.05, "fyp_threshold": 100000},
    {"level": 3, "split_rate": 0.03, "fyp_threshold": 200000}
  ]
}
```

**后端处理逻辑**：
1. 校验各级分润比例之和不超过合规上限（默认30%，可配置）
2. 写入 `commission_multilevel_policy` 表
3. 同时在 `commission_rate_history` 写入变更记录

#### 3.1.4 负责人绑定（组织架构联动）

> 参考 **PDF-196（组织维护管理多级结算负责人设置）** 和 **PDF-244**

**操作路径**：人管 → 组织机构 → 组织维护管理 → 选中组织节点 → 【多级结算设置】

**绑定操作**：
1. 在组织节点编辑页，展示「多级结算负责人」字段（员工选择器）
2. 展示「多级结算政策」字段（下拉，从 `commission_multilevel_policy` 有效政策中选）
3. 点击【保存】后，更新 `sys_dept.multi_settle_agent_id` 和 `sys_dept.multi_settle_policy_id`

**字段联动关系**：

```
sys_dept（组织节点）
  ├── multi_settle_agent_id → 该组织的多级结算负责人（sys_user.id）
  └── multi_settle_policy_id → 适用的分润政策（commission_multilevel_policy.id）
```

**负责人变更联动**：
- 变更负责人后，**当月已生成的分润佣金**不受影响
- **变更次日起**新出单的保单按新负责人计算分润
- 历史分润链路在 `commission_split` 表中归档，可追溯

#### 3.1.5 分润链路查询页（审计视图）

**入口**：佣金管理 → 多级结算 → 分润明细

**功能**：查看某笔佣金的完整分润链路（由哪笔原始佣金分出、分到哪些负责人、每层分多少）

**展示字段**：

| 列名 | 说明 |
|------|------|
| 源佣金单号 | 下级产生的原始佣金ID |
| 源业务员 | 出单业务员 |
| 保单号 | |
| 保费 | |
| 源佣金金额 | |
| 层级 | 第1/2/3...级 |
| 分润负责人 | 获得分润的负责人 |
| 分润比例 | |
| 分润金额 | |
| 状态 | PENDING/APPROVED/PAID |

**搜索条件**：源业务员、负责人姓名/工号、保单号、结算周期、状态

#### 3.1.6 数据库表

```sql
-- 多级结算政策表
CREATE TABLE `commission_multilevel_policy` (
  `id`                bigint(20)    NOT NULL AUTO_INCREMENT,
  `policy_name`       varchar(64)   NOT NULL COMMENT '政策名称',
  `override_hierarchy` json         NOT NULL COMMENT '分润链路配置JSON',
  `fyp_threshold`     decimal(12,2) NOT NULL DEFAULT 0 COMMENT '最低激活FYP门槛（全局）',
  `effective_date`    date          NOT NULL COMMENT '生效日期',
  `expire_date`       date          DEFAULT NULL COMMENT '失效日期',
  `change_reason`     varchar(500)  DEFAULT NULL,
  `status`            tinyint(1)    DEFAULT 1,
  `creator`           varchar(64)   DEFAULT NULL,
  `create_time`       datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`           varchar(64)   DEFAULT NULL,
  `update_time`       datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`           tinyint(1)    DEFAULT 0,
  `tenant_id`         bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_policy_name` (`policy_name`),
  KEY `idx_effective_date` (`effective_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='多级结算政策配置表';

-- 组织多级结算绑定（扩展 sys_dept，添加以下字段）
-- ALTER TABLE sys_dept ADD COLUMN `multi_settle_agent_id`  bigint(20) DEFAULT NULL COMMENT '多级结算负责人ID';
-- ALTER TABLE sys_dept ADD COLUMN `multi_settle_policy_id` bigint(20) DEFAULT NULL COMMENT '绑定的分润政策ID';
-- ALTER TABLE sys_dept ADD COLUMN `multi_settle_update_time` datetime DEFAULT NULL COMMENT '最后绑定变更时间';
```

---

## 四、接口权限标识（新增）

| 权限标识 | 说明 |
|---------|------|
| `commission:car-policy:point:create` | 新增留点政策 |
| `commission:car-policy:point:update` | 修改留点政策 |
| `commission:car-policy:extra-point:create` | 新增加投点批次 |
| `commission:car-policy:quote-adjust:create` | 新增报价赋值政策 |
| `commission:car-policy:blacklist:add` | 新增禁保名单 |
| `commission:car-policy:blacklist:remove` | 移除禁保名单 |
| `commission:car-policy:blacklist:import` | 批量导入禁保名单 |
| `commission:multilevel:policy:create` | 新增多级结算政策 |
| `commission:multilevel:policy:update` | 修改多级结算政策 |
| `commission:multilevel:bind` | 组织绑定多级结算负责人 |

---

## 五、定时任务补充

| 任务名称 | Cron表达式 | 说明 |
|---------|-----------|------|
| 禁保名单过期清理 | `0 30 0 * * ?` | 每日00:30清理已过期名单（更新status=0），同时删除Redis缓存 |
| 加投点档位月度统计 | `0 0 3 1 * ?` | 每月1日03:00统计上月业务员FYP，匹配加投点档位并追加佣金记录 |

---

> **【补充篇A完】**  
> 本文档配合原三篇文档（上/中/下篇）使用。车险政策管理与基本法配置中的佣金规则共用 `commission_rate_history` 历史表，注意变更操作均需写入历史。  
> 多级结算的分润计算逻辑复用上篇「3.3.5 管理津贴分润计算逻辑」中的递归链路，以 `commission_multilevel_policy` 中的比例为准覆盖基本法中的 `OVERRIDE` 规则（政策级别更高时优先使用多级结算政策）。

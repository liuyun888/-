# 阶段2-PC佣金系统详细需求文档【上篇】
## 基本法配置模块 + 佣金计算引擎模块

> 版本：V3.0 | 日期：2026-02-18 | 技术栈：yudao-cloud（微服务版）+ MySQL 8.0 + Redis  
> 配置：1前端 + 1后端  
> 阅读对象：前后端开发工程师

---

## 一、模块总览

| 模块 | 功能点 | 工时（前+后） |
|------|--------|---------------|
| 基本法配置 | 职级体系管理 | 1+1 = 2天 |
| 基本法配置 | 晋升规则配置 | 1.5+1.5 = 3天 |
| 基本法配置 | 佣金比例配置（FYC/RYC） | 1+1 = 2天 |
| 基本法配置 | 津贴配置（管理津贴/育成奖/伯乐奖） | 1.5+1.5 = 3天 |
| 基本法配置 | 奖励规则（季度奖/年度奖） | 1+1 = 2天 |
| 佣金计算引擎 | 佣金规则库维护 | 0+2 = 2天 |
| 佣金计算引擎 | 佣金试算 | 1+1.5 = 2.5天 |
| 佣金计算引擎 | 批量佣金计算 | 0+2 = 2天 |
| 佣金计算引擎 | 佣金分摊（分红险分期） | 0+1.5 = 1.5天 |

---

## 二、基本法配置模块

### 2.1 职级体系管理

#### 2.1.1 页面入口与布局

- 菜单路径：佣金管理 → 基本法配置 → 职级管理
- 页面布局：左侧树形展示职级层级，右侧展示当前选中职级的详细信息及同级列表

#### 2.1.2 职级列表页

**展示字段**：职级代码、职级名称、职级层级、上级职级、状态（启用/停用）、创建时间、操作（编辑/停用/删除）

**搜索条件**：职级名称（模糊搜索）、职级状态（下拉：全部/启用/停用）

**操作按钮**：
- 【新增职级】按钮 → 弹出新增弹窗
- 【导出】按钮 → 导出当前筛选结果为Excel

#### 2.1.3 新增/编辑职级弹窗

**触发方式**：
- 点击列表页【新增职级】按钮 → 弹出新增弹窗，标题「新增职级」
- 点击列表行【编辑】按钮 → 弹出编辑弹窗，标题「编辑职级」，回填当前数据

**弹窗表单字段**：

| 字段名 | 类型 | 必填 | 校验规则 | 说明 |
|--------|------|------|----------|------|
| 职级代码 | 文本输入 | 是 | 仅允许大写字母和下划线，唯一，编辑时只读 | 如：SALES、SUPERVISOR、MANAGER |
| 职级名称 | 文本输入 | 是 | 不超过64字 | 如：业务员、主管、经理 |
| 职级层级 | 数字输入 | 是 | 整数1-10 | 数字越大表示层级越高 |
| 上级职级 | 下拉选择 | 否 | 从已有职级中选择，只能选比当前层级低的 | 最高级职级可不选上级 |
| 职级说明 | 文本域 | 否 | 不超过500字 | 对该职级的描述 |
| 排序 | 数字输入 | 否 | 正整数 | 同层级排序权重 |
| 状态 | 单选 | 是 | 默认启用 | 启用/停用 |

**点击【确认】后端处理逻辑**：
1. 校验职级代码唯一性（`uk_rank_code`），若重复返回错误："职级代码已存在"
2. 校验上级职级的 `rank_level` 必须小于当前 `rank_level`，否则返回错误："上级职级层级不能高于或等于当前职级"
3. 校验同一 `rank_level` 下不允许重复的 `rank_code`
4. 通过所有校验后，插入/更新 `sys_agent_rank` 表
5. 同时向 `commission_rate_history` 插入变更记录（change_type=CREATE/UPDATE）
6. 返回成功，前端刷新列表

**点击【取消】**：关闭弹窗，不保存任何数据

#### 2.1.4 停用/启用职级

**触发**：点击列表行【停用】或【启用】按钮

**后端处理**：
1. 停用时：检查该职级下是否有在职业务员，若有则返回错误："该职级下存在X名在职员工，请先迁移人员后再停用"
2. 停用时：检查是否有生效中的佣金规则引用该职级，若有则返回警告弹窗（可强制停用，但需手工确认）
3. 更新 `sys_agent_rank.status` 字段
4. 停用后该职级不再出现在规则配置的职级下拉选项中

#### 2.1.5 删除职级

**触发**：点击列表行【删除】按钮 → 弹出二次确认框：「确认删除职级「{职级名称}」？删除后不可恢复。」

**后端处理**：
1. 判断是否有下级职级引用（`parent_rank_code`），若有则提示："请先删除下级职级：{下级职级名称}"
2. 判断是否有业务员绑定该职级，若有则禁止删除
3. 逻辑删除（`deleted=1`），不物理删除
4. 插入 `commission_rate_history` 变更记录（change_type=DELETE）

#### 2.1.6 数据库表

```sql
CREATE TABLE `sys_agent_rank` (
  `id`               bigint(20)   NOT NULL AUTO_INCREMENT COMMENT '主键',
  `rank_code`        varchar(32)  NOT NULL COMMENT '职级代码，唯一，仅大写字母+下划线',
  `rank_name`        varchar(64)  NOT NULL COMMENT '职级名称',
  `rank_level`       int(11)      NOT NULL COMMENT '职级层级(1-10，数字越大层级越高)',
  `parent_rank_code` varchar(32)  DEFAULT NULL COMMENT '上级职级代码',
  `promotion_rules`  json         DEFAULT NULL COMMENT '晋升规则JSON',
  `description`      varchar(500) DEFAULT NULL COMMENT '职级说明',
  `status`           tinyint(1)   DEFAULT 1 COMMENT '状态(0停用 1启用)',
  `sort`             int(11)      DEFAULT 0 COMMENT '排序',
  `creator`          varchar(64)  DEFAULT NULL,
  `create_time`      datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          varchar(64)  DEFAULT NULL,
  `update_time`      datetime     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          tinyint(1)   DEFAULT 0,
  `tenant_id`        bigint(20)   DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rank_code` (`rank_code`),
  KEY `idx_rank_level` (`rank_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='代理人职级表';
```

---

### 2.2 晋升规则配置

#### 2.2.1 页面入口

- 菜单路径：佣金管理 → 基本法配置 → 晋升规则
- 说明：每个职级（非最高级）均可配置"晋升到下一职级"的条件

#### 2.2.2 晋升规则列表页

**展示字段**：当前职级、目标职级、考核周期、FYP要求（万元）、件数要求、团队人力要求、是否启用、操作（编辑/查看历史）

**操作按钮**：
- 【新增规则】→ 弹出新增弹窗
- 【批量导入】→ 上传Excel批量设定规则

#### 2.2.3 新增/编辑晋升规则弹窗

**弹窗表单字段**：

| 字段名 | 类型 | 必填 | 校验规则 | 说明 |
|--------|------|------|----------|------|
| 当前职级 | 下拉（从职级表取） | 是 | 不能选最高职级 | |
| 目标职级 | 下拉（自动过滤，只显示层级比当前高一级的） | 是 | | |
| 考核周期 | 数字输入（月） | 是 | 正整数，1-24 | 连续满足多少个月 |
| FYP要求 | 金额输入（元） | 否 | 数值≥0 | 最低首年保费要求 |
| 新单件数要求 | 数字输入 | 否 | 整数≥0 | |
| 团队人力要求 | 数字输入 | 否 | 整数≥0 | 直辖组最低人数 |
| 培育直辖主管数 | 数字输入 | 否 | 整数≥0 | 适用于经理级以上晋升 |
| 生效日期 | 日期选择 | 是 | | 规则从哪天开始适用 |
| 备注 | 文本域 | 否 | | |

**后端处理**：
1. 校验同一"当前职级→目标职级"不允许有两条同时启用的规则，否则提示："已存在相同的晋升规则"
2. 将各条件序列化为JSON存入 `sys_agent_rank.promotion_rules`：
   ```json
   {
     "target_rank_code": "SUPERVISOR",
     "evaluation_months": 3,
     "fyp_min": 300000,
     "policy_count_min": 10,
     "team_size_min": 3,
     "direct_supervisor_min": 0,
     "effective_date": "2026-01-01"
   }
   ```

#### 2.2.4 自动晋升评估逻辑（后端定时任务）

**执行时机**：每月1号凌晨01:00 `@Scheduled(cron = "0 0 1 1 * ?")`

**执行步骤**：
1. 查询所有状态为在职（status=NORMAL）的业务员列表
2. 对每个业务员，取其当前职级的晋升规则（promotion_rules JSON）
3. 统计其过去 N 个月（evaluation_months）的业绩数据：FYP、新单件数、团队人力
4. 判断是否满足所有条件（AND关系）
5. 满足则生成一条晋升记录到 `agent_promotion_apply` 表（status=PENDING，等待管理员审批）
6. 同时推送站内消息通知业务员和其直属上级

**晋升生效规则**：
- 审批通过后次月1号生效（不立即改变 `sys_user.rank_code`）
- 系统每月1号凌晨02:00执行"晋升生效任务"，将所有审批通过且生效日期≤今日的晋升记录对应的用户职级更新

---

### 2.3 佣金比例配置（FYC / RYC）

#### 2.3.1 功能说明

配置各险种、各职级对应的首年佣金（FYC）和续期佣金（RYC）费率。

#### 2.3.2 页面布局

页面顶部有险种Tab切换（车险 / 寿险 / 健康险），切换后展示对应险种下的费率表格：

| 职级 | 首年佣金率（FYC）| 监管上限 | 续期佣金率（RYC）| 生效日期 | 操作 |
|------|-----------------|----------|-----------------|----------|------|
| 业务员 | 25.00% | 30.00% | 5.00% | 2026-01-01 | 编辑 |
| 主管 | 27.00% | 30.00% | 6.00% | 2026-01-01 | 编辑 |

#### 2.3.3 编辑佣金费率弹窗

**弹窗字段**：

| 字段名 | 类型 | 必填 | 校验规则 |
|--------|------|------|----------|
| 险种 | 只读显示 | - | - |
| 职级 | 只读显示 | - | - |
| 首年佣金率 | 百分比输入 | 是 | 0.00%-100.00%，且不得超过监管上限 |
| 监管上限 | 百分比输入 | 是 | 来自保司报备费率，0.00%-100.00% |
| 续期佣金率 | 百分比输入 | 是 | 0.00%-监管上限 |
| 生效日期 | 日期选择 | 是 | 不能早于今日 |
| 变更原因 | 文本域 | 是 | 不超过200字 |

**后端处理**：
1. **合规校验**：`commission_rate ≤ regulatory_max_rate`，否则返回错误："佣金率超出监管上限，请重新输入"
2. 更新 `commission_base_rule` 表对应记录的 `rate_config` JSON
3. 将旧值写入 `commission_rate_history` 表（change_type=UPDATE，记录old_value和new_value）
4. 新费率仅对生效日期之后新生成的佣金记录有效，存量佣金不受影响

#### 2.3.4 数据库表（佣金规则表）

```sql
CREATE TABLE `commission_base_rule` (
  `id`               bigint(20)   NOT NULL AUTO_INCREMENT,
  `rule_code`        varchar(64)  NOT NULL COMMENT '规则代码，全局唯一',
  `rule_name`        varchar(128) NOT NULL COMMENT '规则名称',
  `rule_type`        varchar(32)  NOT NULL COMMENT '规则类型(FYC/RYC/OVERRIDE/BONUS)',
  `rank_code`        varchar(32)  DEFAULT NULL COMMENT '适用职级，NULL=全部职级',
  `product_category` varchar(32)  DEFAULT NULL COMMENT '适用险种(CAR/LIFE/HEALTH)，NULL=全部',
  `calc_formula`     text         NOT NULL COMMENT '计算公式（Groovy脚本）',
  `rate_config`      json         DEFAULT NULL COMMENT '费率配置JSON',
  `effective_date`   date         NOT NULL COMMENT '生效日期',
  `expire_date`      date         DEFAULT NULL COMMENT '失效日期，NULL=长期有效',
  `priority`         int(11)      DEFAULT 0 COMMENT '优先级，数字越大越优先',
  `remark`           varchar(500) DEFAULT NULL,
  `status`           tinyint(1)   DEFAULT 1,
  `creator`          varchar(64)  DEFAULT NULL,
  `create_time`      datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          varchar(64)  DEFAULT NULL,
  `update_time`      datetime     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          tinyint(1)   DEFAULT 0,
  `tenant_id`        bigint(20)   DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rule_code` (`rule_code`),
  KEY `idx_rank_product`    (`rank_code`, `product_category`),
  KEY `idx_effective_date`  (`effective_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金基本法规则表';
```

---

### 2.4 津贴配置（管理津贴 / 育成奖 / 伯乐奖）

#### 2.4.1 功能说明

配置上级对下级业绩的管理津贴（OVERRIDE），以及育成奖、伯乐奖等人力激励奖金。

#### 2.4.2 管理津贴配置页面

页面展示各职级的管理津贴分级表格：

| 本人职级 | 层级 | 直辖下级佣金的津贴比例 | 隔代下级佣金的津贴比例 | 最低激活要求 | 操作 |
|----------|------|----------------------|----------------------|------------|------|
| 主管 | 第1层 | 5.00% | - | 本人FYP≥5000/月 | 编辑 |
| 经理 | 第1层 | 8.00% | 3.00% | 本人FYP≥10000/月 | 编辑 |

**rate_config JSON示例**（存储在 `commission_base_rule.rate_config`）：
```json
{
  "override_hierarchy": [
    {"level": 1, "rate": 0.05, "min_personal_fyp": 5000},
    {"level": 2, "rate": 0.03, "min_personal_fyp": 5000}
  ]
}
```

#### 2.4.3 育成奖配置

**说明**：当业务员从自己团队中培养出一名新主管，可一次性获得育成奖。

**配置字段**：

| 字段 | 说明 | 必填 |
|------|------|------|
| 适用职级 | 育成者的职级（如：主管及以上） | 是 |
| 被育成职级 | 被培养人达到的职级 | 是 |
| 奖金金额（元） | 固定金额 | 是 |
| 生效日期 | 日期 | 是 |

#### 2.4.4 伯乐奖配置

**说明**：当业务员推荐的新人在入职后N月内达到指定业绩时，推荐人获得伯乐奖。

**配置字段**：

| 字段 | 说明 | 必填 |
|------|------|------|
| 考核期（月） | 从新人入职起的考核时间窗口 | 是 |
| 新人FYP达成要求 | 考核期内需完成的FYP | 是 |
| 奖金金额（元） | 固定金额 | 是 |
| 是否按比例发放 | 超额部分按比例追加 | 否 |

---

### 2.5 奖励规则配置（季度奖 / 年度奖）

#### 2.5.1 功能说明

配置基于阶梯业绩的额外奖励，如季度FYP达到不同档次获得对应奖金。

#### 2.5.2 奖励规则配置弹窗字段

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| 规则名称 | 文本 | 是 | 如：2026年Q1季度奖 |
| 奖励周期 | 下拉（季度/年度） | 是 | |
| 适用职级 | 多选下拉 | 是 | |
| 适用险种 | 多选下拉 | 否 | 空=全部险种 |
| 阶梯档位 | 动态增减行 | 是 | 每行：最低FYP、最高FYP（空=无上限）、奖金金额 |
| 生效年份 | 年份选择 | 是 | |
| 规则说明 | 文本域 | 否 | |

**阶梯档位示例**：

| 档位 | FYP下限（元） | FYP上限（元） | 奖金（元） |
|------|-------------|-------------|---------|
| 铜牌 | 50,000 | 99,999 | 500 |
| 银牌 | 100,000 | 299,999 | 1,500 |
| 金牌 | 300,000 | - | 5,000 |

**rate_config JSON**（存入 `commission_base_rule.rate_config`）：
```json
{
  "bonus_tiers": [
    {"min_fyp": 50000,  "max_fyp": 99999,  "bonus": 500},
    {"min_fyp": 100000, "max_fyp": 299999, "bonus": 1500},
    {"min_fyp": 300000, "max_fyp": null,   "bonus": 5000}
  ]
}
```

**后端计算逻辑**：
1. 每季度/年度结束后，定时任务统计各业务员对应周期内FYP总和
2. 遍历阶梯档位，匹配所在档位
3. 生成 `commission_record`（commission_type=BONUS）
4. 进入正常审核→发放流程

---

## 三、佣金计算引擎模块

### 3.1 佣金规则库维护

#### 3.1.1 功能说明

此为纯后端管理功能，提供Groovy计算公式的查看、测试、版本管理能力。前端仅有简单的规则列表展示和"规则测试"工具页面，主要工作量在后端。

#### 3.1.2 规则测试工具（前端页面）

**入口**：佣金管理 → 计算引擎 → 规则测试

**页面布局**：
- 左侧：选择规则（下拉选择 `commission_base_rule.rule_code`）
- 中间：输入测试参数（保费、职级、险种、缴费年期等）
- 右侧：实时展示计算结果和计算公式说明

**测试参数表单**：

| 字段 | 必填 | 示例 |
|------|------|------|
| 选择规则 | 是 | LIFE_FYC_SALES |
| 测试保费（元） | 是 | 10000.00 |
| 业务员职级 | 是 | SALES |
| 险种 | 是 | LIFE |
| 缴费年期（年） | 否 | 10 |

**点击【开始测试】按钮**，调用 `POST /commission/rule/test-formula`：
- 后端用Groovy Shell执行公式，返回：计算结果金额、实际使用的公式字符串、是否超出监管上限等
- 若公式有语法错误，返回错误提示

#### 3.1.3 规则版本管理

- 每次修改规则（rate_config / calc_formula / effective_date）均自动在 `commission_rate_history` 写入变更记录
- 历史记录页面可查看变更前后的JSON对比（diff展示）
- 不允许物理删除已有佣金记录引用的规则，只能停用

---

### 3.2 佣金试算

#### 3.2.1 功能说明

财务人员或管理员输入保单信息，实时预览该保单将产生的全部佣金（包含分润），但**不保存**到数据库，仅用于预判。

#### 3.2.2 试算页面

**入口**：佣金管理 → 佣金计算 → 佣金试算

**试算输入表单**：

| 字段 | 类型 | 必填 | 校验 | 说明 |
|------|------|------|------|------|
| 保单号 | 文本输入 | 否 | | 可直接从保单系统带入 |
| 险种 | 下拉 | 是 | CAR/LIFE/HEALTH | |
| 保险公司 | 下拉 | 是 | 从系统已配置保司列表取 | |
| 保费（元） | 金额输入 | 是 | >0 | |
| 缴费年期 | 数字 | 否 | 正整数 | 寿险必填 |
| 业务员 | 员工选择器 | 是 | 从系统员工中选择 | |
| 结算周期 | 年月选择 | 是 | 格式YYYYMM | |

**点击【开始试算】**，调用 `POST /commission/calculate/preview`（不保存）

**试算结果展示区域**：
```
本人佣金：
  佣金类型：FYC（首年佣金）
  适用规则：LIFE_FYC_SALES
  计算公式：10,000.00 × 25.00% = 2,500.00 元
  是否超限：否（监管上限30%）

上级分润（管理津贴）：
  直接上级（李四 - 主管）：2,500.00 × 5% = 125.00 元
  隔代上级（王五 - 经理）：2,500.00 × 3% = 75.00 元

合计产生佣金：2,700.00 元
```

#### 3.2.3 后端试算接口逻辑

接口：`POST /commission/calculate/preview`

**处理步骤**：
1. 根据（险种、职级、生效日期）查询适用规则（参考3.3节匹配算法）
2. 若未找到规则，返回错误："未找到适用的佣金规则，请先配置基本法"
3. 用Groovy Shell执行 `calc_formula`，计算本人佣金
4. 检查合规：若超出 `max_rate`，则以 `max_rate` 重新计算并标记"已按监管上限截断"
5. 查询业务员的上级链条（最多5级）
6. 对每一级上级，查询其适用的OVERRIDE规则，计算分润
7. 返回完整的试算结果（**不写库**）

---

### 3.3 批量佣金计算

#### 3.3.1 触发时机

| 触发方式 | 说明 |
|---------|------|
| 保单承保自动触发 | 监听MQ保单承保消息，30秒内异步计算 |
| 定时批量计算 | 每日凌晨03:00对前一日所有承保未计算的保单批量处理 |
| 手动触发 | 管理员在后台指定结算周期，手动触发批量计算 |

#### 3.3.2 手动批量计算页面

**入口**：佣金管理 → 佣金计算 → 批量计算

**操作步骤**：
1. 选择结算周期（年月选择，如：2026-02）
2. 可选择指定险种（多选，默认全部）
3. 点击【预检】按钮 → 后端返回：待计算保单数量、预计耗时
4. 确认无误后点击【开始计算】按钮 → 弹出确认框"将对X笔保单进行佣金计算，是否继续？"
5. 计算异步执行，页面展示进度条（轮询 Redis 中的进度key）
6. 计算完成后展示结果：成功N笔、失败N笔（可下载失败明细）

#### 3.3.3 后端批量计算逻辑

接口：`POST /commission/calculate/batch`

**核心流程**：
```
1. 从数据库查询指定周期内所有status=PENDING（待计算）的保单
2. 按每批1000条分批处理（防内存溢出）
3. 对每条保单：
   a. 查询适用规则（见3.3.4匹配算法）
   b. 执行Groovy公式计算本人佣金
   c. 合规校验（超上限按上限计算）
   d. 生成 commission_record（status=PENDING）
   e. 计算上级管理津贴，生成对应 commission_record（type=OVERRIDE）
   f. 生成 commission_split 分润关系记录
   g. 将保单标记为已计算（policy.commission_status=CALCULATED）
4. 用Redis存储进度（key=commission:task:{taskId}:progress，有效期30分钟）
5. 计算完毕发送系统通知给操作人
```

**异步执行**：使用 `@Async("commissionTaskExecutor")` 线程池，核心线程数5，队列长度500

**幂等保护**：每条保单只允许生成一条状态非REJECTED的佣金记录，若已存在则跳过（通过 `policy_id` + `commission_type` 联合唯一索引控制）

#### 3.3.4 规则匹配算法（关键）

```sql
SELECT * FROM commission_base_rule
WHERE deleted = 0
  AND status = 1
  AND rule_type = #{commissionType}       -- FYC 或 RYC
  AND (rank_code = #{agentRank} OR rank_code IS NULL)
  AND (product_category = #{productCategory} OR product_category IS NULL)
  AND effective_date <= #{policyDate}
  AND (expire_date IS NULL OR expire_date > #{policyDate})
ORDER BY
  (rank_code IS NOT NULL) DESC,           -- 精确匹配职级优先于通配
  (product_category IS NOT NULL) DESC,    -- 精确匹配险种优先于通配
  priority DESC,
  create_time DESC
LIMIT 1
```

**规则匹配说明**：
- 先精确匹配（职级+险种都匹配）
- 再半精确匹配（只有职级或只有险种匹配）
- 最后通配（职级和险种均为NULL的兜底规则）
- 若完全没有匹配规则，该保单计算失败，记录错误日志，不生成佣金记录

#### 3.3.5 管理津贴分润计算逻辑

```
输入：source_commission（下级的直接佣金记录）

1. 根据 source_agent_id 查询其组织关系（sys_user.parent_id）
2. 递归向上查找，最多5层：
   superiors = [直接上级ID, 二级上级ID, ..., 五级上级ID]

3. 对每一层上级 superior（层级差level=1,2,3...）：
   a. 查询 OVERRIDE 类型规则，匹配该上级职级
   b. 从 rate_config.override_hierarchy[level-1] 取分润比例
   c. 检查上级是否满足激活条件（如：本人当月FYP≥5000元）
      - 满足：split_amount = source_commission.commission_amount × split_rate
      - 不满足：跳过，不计算该层分润（分润不向上传递）
   d. 若满足，创建一条新的 commission_record（type=OVERRIDE）
   e. 创建 commission_split 关联记录

4. 所有分润的 commission_record 与本人佣金同步进入待审核状态
```

---

### 3.4 佣金分摊（分红险分期发放）

#### 3.4.1 功能说明

针对分红险、万能险等保单，佣金不一次性发放，而是按缴费年期分期计算（第N年续期时发放RYC）。

#### 3.4.2 分摊规则配置

在佣金规则（RYC类型）的 `rate_config` 中配置各年度费率递减：
```json
{
  "ryc_schedule": [
    {"year": 1, "rate": 0.05},
    {"year": 2, "rate": 0.04},
    {"year": 3, "rate": 0.03},
    {"year": 4, "rate": 0.02},
    {"year": 5, "rate": 0.01},
    {"year": 6, "rate": 0.005}
  ]
}
```

#### 3.4.3 后端处理（定时任务）

**执行时机**：每日凌晨04:00 `@Scheduled(cron = "0 0 4 * * ?")`

**执行逻辑**：
1. 查询当月续期应收保费的保单列表（`policy_type IN (DIVIDEND, UNIVERSAL) AND renewal_date = 本月`）
2. 查询该保单对应的原始 FYC 佣金记录，获得原始业务员和规则
3. 根据当前保单年度（第N年），从 `ryc_schedule` 中取对应费率
4. 计算续期佣金：`premium_renewal × ryc_rate`
5. 生成 `commission_record`（commission_type=RYC，policy_year=N）
6. 同样计算上级管理津贴
7. 进入待审核队列

---

## 四、数据库表汇总（本篇涉及）

| 表名 | 用途 |
|------|------|
| `sys_agent_rank` | 职级体系 |
| `commission_base_rule` | 佣金规则配置（含FYC/RYC/OVERRIDE/BONUS） |
| `commission_rate_history` | 规则变更历史记录 |
| `commission_record` | 佣金主记录（所有类型） |
| `commission_split` | 分润关系明细 |

---

```sql
-- 佣金变更历史表
CREATE TABLE `commission_rate_history` (
  `id`           bigint(20)   NOT NULL AUTO_INCREMENT,
  `rule_id`      bigint(20)   NOT NULL COMMENT '关联规则ID',
  `change_type`  varchar(32)  NOT NULL COMMENT 'CREATE/UPDATE/DELETE',
  `old_value`    json         DEFAULT NULL COMMENT '变更前值',
  `new_value`    json         NOT NULL COMMENT '变更后值',
  `change_reason` varchar(500) DEFAULT NULL COMMENT '变更原因',
  `operator`     varchar(64)  NOT NULL COMMENT '操作人',
  `operate_time` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_rule_id`      (`rule_id`),
  KEY `idx_operate_time` (`operate_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金规则变更历史表';

-- 佣金记录主表
CREATE TABLE `commission_record` (
  `id`                bigint(20)    NOT NULL AUTO_INCREMENT,
  `commission_no`     varchar(64)   NOT NULL COMMENT '佣金单号（COMM+YYYYMMDD+4位序列）',
  `policy_id`         bigint(20)    NOT NULL COMMENT '关联保单ID',
  `policy_no`         varchar(128)  NOT NULL COMMENT '保单号',
  `agent_id`          bigint(20)    NOT NULL COMMENT '业务员/上级ID',
  `agent_name`        varchar(64)   NOT NULL,
  `agent_rank`        varchar(32)   NOT NULL COMMENT '计算时的职级快照',
  `product_category`  varchar(32)   NOT NULL COMMENT 'CAR/LIFE/HEALTH',
  `product_name`      varchar(128)  DEFAULT NULL,
  `insurance_company` varchar(128)  NOT NULL,
  `premium`           decimal(12,2) NOT NULL COMMENT '保费（元）',
  `payment_period`    int(11)       DEFAULT NULL COMMENT '缴费年期',
  `policy_year`       int(11)       DEFAULT 1 COMMENT '保单年度（1=首年，2=续期第2年）',
  `commission_type`   varchar(32)   NOT NULL COMMENT 'FYC/RYC/OVERRIDE/BONUS',
  `commission_rate`   decimal(6,4)  NOT NULL COMMENT '佣金费率（0.2500=25%）',
  `commission_amount` decimal(12,2) NOT NULL COMMENT '佣金金额（元）',
  `calc_formula`      varchar(500)  DEFAULT NULL COMMENT '计算公式说明',
  `apply_rule_code`   varchar(64)   DEFAULT NULL COMMENT '适用规则代码快照',
  `settle_period`     varchar(32)   NOT NULL COMMENT '结算周期（YYYYMM）',
  `status`            varchar(32)   NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/APPROVED/PAID/REJECTED',
  `exception_type`    varchar(64)   DEFAULT NULL COMMENT '异常类型（RATE_EXCEED等）',
  `audit_time`        datetime      DEFAULT NULL,
  `auditor`           varchar(64)   DEFAULT NULL,
  `audit_remark`      varchar(500)  DEFAULT NULL,
  `pay_time`          datetime      DEFAULT NULL,
  `pay_batch_no`      varchar(64)   DEFAULT NULL,
  `pay_channel`       varchar(32)   DEFAULT NULL COMMENT 'BANK/ALIPAY/WECHAT',
  `remark`            varchar(500)  DEFAULT NULL,
  `creator`           varchar(64)   DEFAULT NULL,
  `create_time`       datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`           varchar(64)   DEFAULT NULL,
  `update_time`       datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`           tinyint(1)    DEFAULT 0,
  `tenant_id`         bigint(20)    DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_commission_no`    (`commission_no`),
  KEY `idx_policy_id`              (`policy_id`),
  KEY `idx_agent_id`               (`agent_id`),
  KEY `idx_settle_period`          (`settle_period`),
  KEY `idx_status`                 (`status`),
  KEY `idx_agent_settle`           (`agent_id`, `settle_period`),
  KEY `idx_status_create_time`     (`status`, `create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金记录主表';

-- 佣金分润关系表
CREATE TABLE `commission_split` (
  `id`                   bigint(20)    NOT NULL AUTO_INCREMENT,
  `source_commission_id` bigint(20)    NOT NULL COMMENT '下级佣金ID',
  `target_commission_id` bigint(20)    NOT NULL COMMENT '上级管理津贴ID',
  `source_agent_id`      bigint(20)    NOT NULL COMMENT '下级业务员ID',
  `target_agent_id`      bigint(20)    NOT NULL COMMENT '上级ID',
  `split_type`           varchar(32)   NOT NULL COMMENT 'OVERRIDE/TRAINING（育成）',
  `split_rate`           decimal(6,4)  NOT NULL COMMENT '分润比例',
  `split_amount`         decimal(12,2) NOT NULL COMMENT '分润金额',
  `hierarchy_level`      int(11)       NOT NULL COMMENT '层级差（1=直接上级）',
  `creator`              varchar(64)   DEFAULT NULL,
  `create_time`          datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_source_commission` (`source_commission_id`),
  KEY `idx_target_agent`      (`target_agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金分润关系表';
```

---

> **【上篇完】** 下篇内容请见《阶段2-PC佣金系统详细需求文档-中篇（佣金结算+对账管理）》

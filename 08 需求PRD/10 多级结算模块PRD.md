# 多级结算模块 · 产品需求文档（PRD）

> **项目**：保险中介平台 intermediary-cloud  
> **模块**：多级结算（ins-commission / multilevel settlement）  
> **文档版本**：V1.0  
> **编写日期**：2026-03-07  
> **对应操作手册**：PDF-243（目录）/ PDF-244（负责人设置）/ PDF-245（政策设置）/ PDF-246（奖励结算）  
> **关联排期表**：阶段2-PC管理后台-佣金系统 Sheet（功能点 #35）  
> **开发工时估算**：前端 1天 + 后端 1.5天（政策配置+负责人绑定）；分润计算引擎含于佣金计算引擎整体工时内  
> **技术栈**：yudao-cloud（Spring Cloud Alibaba）· MySQL 8.0 · Redis · MyBatis Plus

---

## 目录

1. [模块概述](#1-模块概述)
2. [业务背景与术语](#2-业务背景与术语)
3. [整体功能架构](#3-整体功能架构)
4. [功能详细设计](#4-功能详细设计)
   - 4.1 多级结算政策配置
   - 4.2 组织负责人绑定
   - 4.3 分润明细查询（审计视图）
   - 4.4 奖励结算
5. [核心业务逻辑](#5-核心业务逻辑)
   - 5.1 分润触发时机
   - 5.2 分润链路递归计算
   - 5.3 激活门槛校验
   - 5.4 合规截断机制
   - 5.5 负责人变更联动规则
6. [数据库设计](#6-数据库设计)
7. [API 接口设计](#7-api-接口设计)
8. [权限配置](#8-权限配置)
9. [定时任务](#9-定时任务)
10. [技术实现要点](#10-技术实现要点)
11. [测试用例要点](#11-测试用例要点)
12. [开发注意事项](#12-开发注意事项)

---

## 1. 模块概述

### 1.1 模块定位

多级结算是佣金结算中台（`intermediary-module-ins-commission`）的高级子模块，核心作用是：

在保险中介公司组织层级结构下，当下级业务员出单产生佣金（FYC）后，系统自动按照预先配置的**分润链路政策**，将一定比例的分润金额向上逐层传递给各级负责人（主管/经理/总监等），生成对应的 `OVERRIDE` 类型佣金记录，纳入各级负责人的薪酬结算体系。

### 1.2 模块边界

| 边界 | 说明 |
|------|------|
| **入口**（上游触发） | 佣金计算引擎完成 FYC 计算后，自动触发多级分润计算 |
| **出口**（下游影响） | 生成 OVERRIDE 类型的 `ins_comm_record` 佣金记录，进入正常结算审核发放流程 |
| **不含内容** | 基本法中的 FYC/RYC 计算、结算单生成、对账管理（见各自独立模块文档） |

### 1.3 使用角色

| 角色 | 操作权限 | 使用场景 |
|------|---------|---------|
| 系统管理员 | 全部 | 初始化政策配置 |
| 佣金配置专员 | 政策新增/编辑/停用、负责人绑定 | 日常政策维护 |
| 财务主管 | 查看分润明细、导出 | 对账核查 |
| 团队负责人（只读） | 查看自己名下的分润明细 | 薪酬核对 |

---

## 2. 业务背景与术语

### 2.1 组织架构示意

```
总公司（大区总监）
  └── 分公司（区域经理）
        └── 营业部（部门主管）
              └── 业务员（出单人）
```

当业务员出单获得 FYC = 1000 元，若配置了3级分润政策（10% / 5% / 3%）：
- 部门主管（第1级）获得：1000 × 10% = **100元 OVERRIDE**
- 区域经理（第2级）获得：1000 × 5% = **50元 OVERRIDE**
- 大区总监（第3级）获得：1000 × 3% = **30元 OVERRIDE**
- 业务员本人 FYC **不减少**，分润金额由平台利润中支出

### 2.2 核心术语

| 术语 | 说明 |
|------|------|
| FYC | First Year Commission，首年佣金，出单业务员的基础佣金 |
| RYC | Renewal Year Commission，续期佣金 |
| OVERRIDE | 管理津贴/分润佣金，上级因下级出单获得的分润收入 |
| FYP | First Year Premium，首年保费，作为业绩激活门槛的统计指标 |
| 分润链路 | 从出单业务员向上追溯各层级负责人的完整层级链条 |
| 激活门槛 | 负责人当月必须达到的最低 FYP，才能获得该层分润资格 |
| 分润层级数 | 政策配置的有效分润向上传递的最大层数（2~5级） |
| `override_hierarchy` | 存储分润链路配置的 JSON 字段 |

---

## 3. 整体功能架构

### 3.1 菜单结构

```
佣金管理
  └── 多级结算（PDF-243 目录）
        ├── 政策配置         → 多级结算政策的 CRUD 管理（PDF-245）
        ├── 负责人设置        → 与组织架构联动的负责人绑定（PDF-244）
        ├── 分润明细          → 分润链路审计查询视图
        └── 奖励结算          → 奖励类型佣金的特殊结算入口（PDF-246）
```

人管模块入口（联动）：
```
人管 → 组织机构 → 组织维护管理 → [节点编辑] → 多级结算设置
```

### 3.2 数据流向

```
ins_order（保单出单）
    ↓ MQ 消息（ORDER_INSURED）
ins_comm 佣金计算引擎
    ↓ 生成 FYC commission_record
多级结算分润计算服务（InsMultilevelSplitService）
    ↓ 递归查找上级链路
    ↓ 读取 sys_dept.multi_settle_policy_id
    ↓ 读取 ins_comm_multilevel_policy.override_hierarchy
    ↓ 校验各层激活门槛
    ↓ 计算分润金额
    ├── 生成各层 OVERRIDE commission_record
    └── 归档 ins_comm_commission_split（完整链路记录）

后续流程：OVERRIDE commission_record → 审核 → 结算单 → 发放
```

---

## 4. 功能详细设计

### 4.1 多级结算政策配置

**菜单路径**：佣金管理 → 多级结算 → 政策配置  
**对应 PDF**：PDF-245（多级结算政策设置）

#### 4.1.1 政策列表页

**页面功能**：展示所有已配置的多级结算政策，支持搜索、新增、编辑、停用操作。

**搜索条件**：

| 字段 | 类型 | 说明 |
|------|------|------|
| 政策名称 | 文本模糊 | |
| 适用险种 | 下拉多选 | 全部/车险/非车/寿险/健康险/意外险 |
| 状态 | 下拉单选 | 全部/启用/停用 |
| 生效日期范围 | 日期区间 | |

**列表展示字段**：

| 列名 | 字段 | 说明 |
|------|------|------|
| 政策名称 | policy_name | |
| 适用险种 | product_category | 标签展示 |
| 分润层级数 | 动态计算 | 解析 override_hierarchy JSON 中 hierarchy 数组长度 |
| 各级分润比例 | 动态展示 | 如：10%-5%-3% |
| FYP激活门槛（元/月） | fyp_threshold | 全局门槛 |
| 生效日期 | effective_date | YYYY-MM-DD |
| 绑定组织数量 | 动态统计 | 从 sys_dept 统计绑定该政策的组织数 |
| 状态 | status | 启用（绿色）/ 停用（灰色）标签 |
| 创建人 | creator | |
| 操作 | — | 编辑 / 查看分润明细 / 停用 |

**操作按钮区**：
- 【新增政策】→ 打开政策配置弹窗

**列表操作**：
- 【编辑】：仅 `status=ENABLE` 的政策可编辑，打开同新增弹窗（数据回填）
- 【查看分润明细】：跳转至分润明细查询页，默认按该政策 ID 筛选
- 【停用】：点击后弹出确认框"确认停用该政策？停用后绑定该政策的组织将无法正常计算分润，请先确认解绑或重新绑定其他政策。" → 确认后更新 `status=DISABLE`

**停用前置校验**（后端）：
1. 查询 `sys_dept.multi_settle_policy_id = {policyId} AND deleted=0` 的组织数量
2. 若 > 0，则在弹出确认框中增加警告："当前有 {N} 个组织绑定了该政策，停用后这些组织将无法产生分润，请谨慎操作。"

#### 4.1.2 新增/编辑政策弹窗

**弹窗标题**：新增多级结算政策 / 编辑多级结算政策

**弹窗字段**：

| 字段名 | 控件类型 | 必填 | 校验规则 | 说明 |
|--------|---------|------|---------|------|
| 政策名称 | 文本输入 | 是 | 不超过64字；同 tenant 内唯一（后端唯一索引校验） | 如：总部团队A级分润政策 |
| 适用险种 | 复选框组 | 是 | 至少选1个 | 车险(CAR) / 非车(NON_CAR) / 寿险(LIFE) / 健康险(HEALTH) / 意外险(ACCIDENT) |
| 分润层级数 | 数字输入 | 是 | 整数，范围 2~5；变更时动态刷新下方分润比例行 | |
| 全局FYP激活门槛（元/月） | 金额输入 | 是 | ≥ 0；0 表示无门槛 | 作为各层默认门槛，可被各层单独配置覆盖 |
| 生效日期 | 日期选择 | 是 | 不早于当天 | 政策生效起始日期 |
| 变更原因 | 文本域 | 是 | 不超过200字 | 记录到变更历史 |

**动态分润比例配置表**（根据「分润层级数」动态渲染行数）：

| 列名 | 说明 | 校验 |
|------|------|------|
| 层级 | 第1级/第2级/.../第N级，自动渲染 | 只读 |
| 层级说明 | 前端提示（第1级=直接上级，第2级=隔代上级，...） | 只读 |
| 分润比例（%） | 数字输入，百分比 | 必填；0 < 值 ≤ 20（单级上限20%） |
| 该层FYP激活门槛（元/月） | 数字输入 | 必填；≥ 0；若留空则继承全局门槛 |

**全局校验**（点击保存时执行）：
1. 各级分润比例之和 ≤ 30%（监管合规上限，可在系统参数中配置 `multilevel.split.max_total_rate`）
2. 若超限，弹窗内顶部显示红色警告："各级分润比例合计不得超过30%，当前合计为 X%，请调整"
3. 各级层级序号连续，不允许跳空

**后端存储格式**（`override_hierarchy` JSON）：

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

**后端处理流程**（保存时）：
1. 校验政策名称唯一性（`uk_policy_name`）
2. 校验各级比例合计 ≤ 30%
3. 写入 `ins_comm_multilevel_policy` 表（新增）或更新（编辑）
4. 写入 `ins_comm_rate_history` 变更记录：`biz_type=MULTILEVEL`，`change_type=CREATE/UPDATE`
5. 返回成功响应

---

### 4.2 组织负责人绑定

**菜单路径**：人管 → 组织机构 → 组织维护管理 → 选中节点 → 【多级结算设置】  
**对应 PDF**：PDF-244（多级结算负责人设置）、PDF-196（组织维护管理）

> 说明：负责人绑定功能在「组织维护管理」页面内嵌实现，不作为独立菜单页面。多级结算模块的「负责人设置」入口（PDF-244）跳转到此处，或提供独立列表视图。

#### 4.2.1 独立入口：负责人设置列表

**菜单路径**：佣金管理 → 多级结算 → 负责人设置

**功能**：集中查看所有已绑定多级结算负责人的组织节点，并支持直接修改绑定关系。

**列表展示字段**：

| 列名 | 说明 |
|------|------|
| 组织名称 | |
| 组织编码 | |
| 组织层级 | 如：总部/大区/分公司/营业部 |
| 上级组织 | |
| 多级结算负责人工号 | |
| 多级结算负责人姓名 | |
| 绑定的结算政策 | 政策名称 |
| 最后变更时间 | |
| 操作 | 修改绑定 |

**搜索条件**：组织名称、负责人姓名/工号、是否已绑定（全部/已绑定/未绑定）

#### 4.2.2 绑定/修改操作

点击【修改绑定】，弹出绑定弹窗：

| 字段名 | 控件类型 | 必填 | 说明 |
|--------|---------|------|------|
| 组织名称 | 只读显示 | — | |
| 多级结算负责人 | 员工选择器（弹窗选人） | 是 | 只能选该组织内在职员工；若清空则视为解除绑定 |
| 绑定政策 | 下拉选择 | 是（有负责人时必填） | 从 `ins_comm_multilevel_policy` 中查询 `status=ENABLE` 的政策 |
| 变更原因 | 文本域 | 是 | 不超过200字 |

**后端处理流程**：
1. 验证所选员工是否属于该组织（或其子组织）
2. 验证政策 `status=ENABLE`
3. 更新 `sys_dept`：
   - `multi_settle_agent_id = {选中员工ID}`
   - `multi_settle_policy_id = {选中政策ID}`
   - `multi_settle_update_time = NOW()`
4. 写入 `ins_comm_rate_history` 变更记录：`biz_type=MULTILEVEL`，`change_type=UPDATE`，记录变更前后的负责人ID和政策ID
5. **生效规则**：变更次日起新出单保单按新负责人计算分润；当月已生成分润记录不受影响

---

### 4.3 分润明细查询（审计视图）

**菜单路径**：佣金管理 → 多级结算 → 分润明细  

**功能**：提供完整的分润链路审计查询，查看每笔原始佣金触发了哪些层级的分润，分润到哪些负责人。

#### 4.3.1 查询页面

**搜索条件**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 结算周期 | 年月选择（范围） | 是 | 默认当月 |
| 源业务员姓名/工号 | 文本模糊 | 否 | 出单业务员 |
| 分润负责人姓名/工号 | 文本模糊 | 否 | 获得分润的上级负责人 |
| 保单号 | 文本精确 | 否 | |
| 所属部门 | 组织树选择 | 否 | |
| 分润层级 | 下拉（1级/2级/3级/4级/5级） | 否 | |
| 状态 | 多选 | 否 | PENDING/APPROVED/PAID |
| 险种 | 多选 | 否 | |
| 保险公司 | 多选 | 否 | |

**列表展示字段**：

| 列名 | 字段来源 | 说明 |
|------|---------|------|
| 源佣金单号 | ins_comm_commission_split.source_commission_id → ins_comm_record.commission_no | |
| 源业务员工号 | source_agent_code | |
| 源业务员姓名 | source_agent_name（JOIN ins_comm_record） | |
| 保单号 | policy_no | |
| 险种 | product_category | |
| 保险公司 | insurance_company_name | |
| 保费（元） | premium | |
| 源佣金金额（元） | source_commission_amount | |
| 分润层级 | split_level | 第1级/第2级/... |
| 分润负责人工号 | recipient_agent_code | |
| 分润负责人姓名 | recipient_agent_name | |
| 分润比例（%） | split_rate | |
| 分润金额（元） | split_amount | 红色标注若金额为0（门槛未达） |
| 结算周期 | settle_period | |
| 状态 | status | PENDING/APPROVED/PAID 标签 |
| 操作 | — | 查看详情 |

**底部汇总行**：
- 本页分润总金额（SUM 当前页 split_amount）
- 全量分润总金额（全部筛选结果合计）

**Excel 导出**：
- ≤ 5000 条：同步导出
- > 5000 条：异步任务导出，完成后站内消息通知

#### 4.3.2 分润详情弹窗

点击【查看详情】，展示某条分润记录的完整上下文：

**基本信息区**：
- 分润记录ID、源佣金单号、保单号、险种、保险公司、承保日期

**分润链路可视化**（树形展示，每层一条横线）：

```
[出单业务员 张三 | FYC ¥1,000]
  ↓ 第1级分润 10%
[部门主管 李四  | OVERRIDE ¥100 | 状态：已审核]
  ↓ 第2级分润 5%
[区域经理 王五  | OVERRIDE ¥50  | 状态：待审核]
  ↓ 第3级分润 3%  ⚠️ 未达激活门槛（当月FYP 4.5万 < 门槛 5万）
[大区总监 赵六  | OVERRIDE ¥0   | 状态：已跳过]
```

**适用政策信息**：政策名称、政策ID、生效日期

---

### 4.4 奖励结算

**菜单路径**：佣金管理 → 多级结算 → 奖励结算  
**对应 PDF**：PDF-246（奖励结算）

#### 4.4.1 功能说明

奖励结算用于处理多级结算体系下的特殊奖励发放，如：达到特定 FYP 里程碑的团队奖励、季度团队业绩奖、年度超额奖励等。这类奖励不通过自动分润计算生成，而是由财务/管理人员手动触发结算或批量导入。

#### 4.4.2 奖励结算页面

**入口**：佣金管理 → 多级结算 → 奖励结算

**页面布局**：
- 顶部：筛选区（结算周期、险种、业务员/组织）
- 操作区：【新增奖励记录】/ 【批量导入】/ 【导出】
- 列表区：奖励结算明细

**列表展示字段**：

| 列名 | 说明 |
|------|------|
| 奖励单号 | 系统生成（BWD+yyyyMMdd+6位流水） |
| 业务员工号 | |
| 业务员姓名 | |
| 所属部门 | |
| 奖励类型 | 团队业绩奖/达成里程碑奖/季度超额奖/年度奖/其他 |
| 奖励金额（元） | |
| 奖励说明 | |
| 结算周期 | |
| 状态 | 待审核/已审核/已发放 |
| 创建人 | |
| 操作 | 审核/删除（待审核时可删除） |

#### 4.4.3 新增奖励记录

**字段**：

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| 业务员 | 员工选择器 | 是 | |
| 奖励类型 | 下拉 | 是 | 团队业绩奖/达成里程碑奖/季度超额奖/年度奖/其他 |
| 奖励金额（元） | 金额输入 | 是 | > 0，保留2位小数 |
| 结算周期 | 年月选择 | 是 | 不能是未来月份 |
| 奖励说明 | 文本域 | 是 | 不超过500字 |

**后端处理**：生成 `commission_type=BONUS` 的 `ins_comm_record` 记录，`settle_period` 按选定周期，`status=PENDING`（待审核）。

#### 4.4.4 批量导入奖励记录

**模板字段（Excel）**：

| 列 | 列名 | 必填 | 格式 |
|----|------|------|------|
| A | 员工工号 | 是 | 文本 |
| B | 员工姓名 | 是 | 用于核对 |
| C | 奖励类型 | 是 | 枚举（团队业绩奖/达成里程碑奖/季度超额奖/年度奖/其他） |
| D | 奖励金额（元） | 是 | 正数，2位小数 |
| E | 结算周期 | 是 | YYYY-MM 格式 |
| F | 奖励说明 | 是 | 不超过500字 |

**导入逻辑**：同加扣款导入，逐行校验，错误行记录但不中止，导入完成后返回成功N行/失败N行汇总及错误详情。

---

## 5. 核心业务逻辑

### 5.1 分润触发时机

多级分润计算在以下时机自动触发（通过 MQ 消费）：

| 触发事件 | 消息 Topic | 处理类 |
|---------|-----------|--------|
| 保单承保成功，FYC 佣金计算完成 | `commission-fyc-calculated` | `InsMultilevelSplitConsumer` |
| 手动单笔重算完成 | `commission-recalculated` | `InsMultilevelSplitConsumer` |
| 批量计算任务完成（逐条FYC触发） | 在批量计算循环内同步调用 | `InsMultilevelSplitService` |

**注意**：RYC 续期佣金**不触发**多级分润（续期管理津贴按基本法 RYC override 规则，非多级结算）。

### 5.2 分润链路递归计算

```
输入：source_commission_record（FYC 类型佣金记录）

算法流程：
1. 获取 source_agent_id 对应的 sys_dept.id（出单业务员所属部门）

2. 递归向上查询组织链路（最多5层）：
   chain = []
   current_dept = 出单业务员所属部门
   while (chain.size() < 5):
       parent_dept = sys_dept WHERE id = current_dept.parent_id
       if parent_dept == null: break
       if parent_dept.multi_settle_agent_id != null:
           chain.add({
               dept: parent_dept,
               agent_id: parent_dept.multi_settle_agent_id,
               policy_id: parent_dept.multi_settle_policy_id,
               level: chain.size() + 1
           })
       current_dept = parent_dept

3. 对 chain 中每个节点：
   a. 加载 ins_comm_multilevel_policy.override_hierarchy JSON
   b. 取 hierarchy[level-1] 中的 split_rate 和 fyp_threshold
   c. 调用 checkFypThreshold(agent_id, settle_period) 校验激活门槛
      - 满足门槛：split_amount = source_commission.commission_amount × split_rate
      - 不满足门槛：split_amount = 0，记录跳过原因，**分润不向上传递**
   d. 若 split_amount > 0：
      - 生成 ins_comm_record（commission_type=OVERRIDE，status=PENDING）
   e. 无论是否分润，均写入 ins_comm_commission_split 归档记录（审计用）

4. 若某组织未绑定 multi_settle_policy_id，则回退到基本法的 override_hierarchy 计算
   （ins_comm_rank.override_rate × level offset）
```

### 5.3 激活门槛校验

`checkFypThreshold(agentId, settlePeriod)` 逻辑：

```sql
SELECT SUM(cr.premium) AS fyp
FROM ins_comm_record cr
WHERE cr.agent_id = #{agentId}
  AND cr.settle_period = #{settlePeriod}
  AND cr.commission_type = 'FYC'
  AND cr.deleted = 0
  AND cr.status IN ('PENDING', 'APPROVED', 'PAID')
```

将查询结果与 `fyp_threshold` 比较：
- `fyp >= fyp_threshold`：激活，正常计算分润
- `fyp < fyp_threshold`：未激活，该层分润金额 = 0，**不阻断后续层级**（各层独立校验）

> 关键说明：门槛不达标时，该层分润设为0，但不影响更上层继续计算。各层独立判断是否激活。

### 5.4 合规截断机制

在写入 `ins_comm_record` 前执行合规检查：

```
实际分润率 = split_rate（来自政策配置）
监管上限 = insurance_company_config.max_commission_rate（或系统全局参数）

if 实际分润率 > 监管上限:
    实际分润率 = 监管上限
    ins_comm_record.is_compliance_truncated = 1
    ins_comm_record.original_rate = split_rate（保存原始率）
    ins_comm_record.compliance_max_rate = 监管上限
```

### 5.5 负责人变更联动规则

| 场景 | 规则 |
|------|------|
| 变更负责人 | 变更次日起新出单保单按新负责人计算 |
| 当月已生成分润 | **不受影响**，保持原负责人收益 |
| 历史分润记录 | 已归档在 `ins_comm_commission_split`，可追溯 |
| 解绑负责人 | 清空 `sys_dept.multi_settle_agent_id = NULL`，该组织节点不参与分润链路 |
| 切换政策 | 次日起新保单按新政策，当月已计算的不变 |

---

## 6. 数据库设计

### 6.1 相关表清单

| 表名 | Schema | 说明 |
|------|--------|------|
| `ins_comm_multilevel_policy` | db_ins_commission | 多级结算政策配置主表 |
| `ins_comm_commission_split` | db_ins_commission | 佣金分润链路归档表 |
| `ins_comm_record` | db_ins_commission | 佣金明细主表（OVERRIDE类型记录由此模块生成） |
| `ins_comm_rate_history` | db_ins_commission | 佣金比例变更历史（合规审计） |
| `sys_dept`（扩展字段） | intermediary（框架库） | 扩展 multi_settle_agent_id / multi_settle_policy_id |

### 6.2 ins_comm_multilevel_policy（多级结算政策表）

```sql
CREATE TABLE `ins_comm_multilevel_policy` (
  `id`                  bigint(20)    NOT NULL AUTO_INCREMENT       COMMENT '主键ID',
  `policy_name`         varchar(64)   NOT NULL                      COMMENT '政策名称（租户内唯一）',
  `override_hierarchy`  json          NOT NULL                      COMMENT '分润链路配置JSON（见示例）',
  `fyp_threshold`       decimal(12,2) NOT NULL DEFAULT 0            COMMENT '全局最低激活FYP门槛（元/月，0=无门槛）',
  `effective_date`      date          NOT NULL                      COMMENT '生效日期',
  `expire_date`         date          DEFAULT NULL                  COMMENT '失效日期（NULL=永不失效）',
  `change_reason`       varchar(500)  DEFAULT NULL                  COMMENT '变更原因',
  `status`              tinyint(1)    NOT NULL DEFAULT 1            COMMENT '状态：1启用 0停用',
  `creator`             varchar(64)   DEFAULT NULL                  COMMENT '创建者',
  `create_time`         datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater`             varchar(64)   DEFAULT NULL                  COMMENT '更新者',
  `update_time`         datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted`             tinyint(1)    NOT NULL DEFAULT 0            COMMENT '逻辑删除',
  `tenant_id`           bigint(20)    NOT NULL DEFAULT 0            COMMENT '租户ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_policy_name_tenant` (`policy_name`, `tenant_id`),
  KEY `idx_effective_date` (`effective_date`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='多级结算政策配置表';
```

**override_hierarchy JSON 示例**：

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

### 6.3 ins_comm_commission_split（佣金分润链路归档表）

```sql
CREATE TABLE `ins_comm_commission_split` (
  `id`                        bigint(20)    NOT NULL AUTO_INCREMENT   COMMENT '主键ID',
  `source_commission_id`      bigint(20)    NOT NULL                  COMMENT '源佣金记录ID（FYC类型，触发分润的原始佣金）',
  `source_agent_id`           bigint(20)    NOT NULL                  COMMENT '源业务员ID',
  `source_agent_code`         varchar(64)   NOT NULL                  COMMENT '源业务员工号',
  `source_agent_name`         varchar(64)   NOT NULL                  COMMENT '源业务员姓名（快照）',
  `policy_no`                 varchar(64)   NOT NULL                  COMMENT '关联保单号',
  `product_category`          varchar(32)   NOT NULL                  COMMENT '险种',
  `insurance_company_code`    varchar(64)   DEFAULT NULL              COMMENT '保险公司编码',
  `settle_period`             varchar(7)    NOT NULL                  COMMENT '结算周期 YYYY-MM',
  `split_level`               int(4)        NOT NULL                  COMMENT '分润层级（1=直接上级，2=隔代上级，依次类推）',
  `recipient_agent_id`        bigint(20)    NOT NULL                  COMMENT '分润接收人ID（上级负责人）',
  `recipient_agent_code`      varchar(64)   NOT NULL                  COMMENT '分润接收人工号（快照）',
  `recipient_agent_name`      varchar(64)   NOT NULL                  COMMENT '分润接收人姓名（快照）',
  `recipient_dept_id`         bigint(20)    DEFAULT NULL              COMMENT '接收人所属组织ID',
  `multilevel_policy_id`      bigint(20)    DEFAULT NULL              COMMENT '适用的多级结算政策ID',
  `split_rate`                decimal(8,4)  NOT NULL                  COMMENT '分润比例（如0.10=10%）',
  `source_commission_amount`  decimal(14,2) NOT NULL                  COMMENT '源佣金金额（元）',
  `split_amount`              decimal(14,2) NOT NULL                  COMMENT '分润金额（元，门槛未达时为0）',
  `fyp_threshold`             decimal(12,2) DEFAULT NULL              COMMENT '该层激活门槛（元/月，快照）',
  `actual_fyp`                decimal(12,2) DEFAULT NULL              COMMENT '接收人当月实际FYP（计算时快照）',
  `is_threshold_met`          tinyint(1)    NOT NULL DEFAULT 1        COMMENT '是否达到激活门槛：1是 0否',
  `skip_reason`               varchar(200)  DEFAULT NULL              COMMENT '跳过原因（门槛未达时填写）',
  `commission_record_id`      bigint(20)    DEFAULT NULL              COMMENT '生成的OVERRIDE佣金记录ID（关联ins_comm_record，门槛未达时为NULL）',
  `status`                    varchar(16)   NOT NULL DEFAULT 'PENDING' COMMENT '状态：PENDING/APPROVED/PAID（随commission_record状态联动）',
  `is_compliance_truncated`   tinyint(1)    NOT NULL DEFAULT 0        COMMENT '是否合规截断：1是（原始比例被限制）0否',
  `original_rate`             decimal(8,4)  DEFAULT NULL              COMMENT '合规截断前的原始比例',
  `creator`                   varchar(64)   DEFAULT NULL,
  `create_time`               datetime      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`                   varchar(64)   DEFAULT NULL,
  `update_time`               datetime      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`                   tinyint(1)    NOT NULL DEFAULT 0,
  `tenant_id`                 bigint(20)    NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_source_commission_id` (`source_commission_id`),
  KEY `idx_recipient_agent_id` (`recipient_agent_id`),
  KEY `idx_source_agent_id` (`source_agent_id`),
  KEY `idx_settle_period` (`settle_period`),
  KEY `idx_policy_no` (`policy_no`),
  KEY `idx_status` (`status`),
  KEY `idx_commission_record_id` (`commission_record_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金分润链路归档表（多级结算审计）';
```

### 6.4 sys_dept 扩展字段（DDL ALTER）

```sql
-- 在框架 sys_dept 表上扩展多级结算相关字段
ALTER TABLE `sys_dept`
  ADD COLUMN `multi_settle_agent_id`    bigint(20) DEFAULT NULL COMMENT '多级结算负责人ID（sys_user.id）' AFTER `leader_user_id`,
  ADD COLUMN `multi_settle_policy_id`   bigint(20) DEFAULT NULL COMMENT '绑定的多级结算政策ID（ins_comm_multilevel_policy.id）' AFTER `multi_settle_agent_id`,
  ADD COLUMN `multi_settle_update_time` datetime   DEFAULT NULL COMMENT '多级结算设置最后变更时间' AFTER `multi_settle_policy_id`;

-- 创建索引
ALTER TABLE `sys_dept` ADD KEY `idx_multi_settle_policy_id` (`multi_settle_policy_id`);
```

---

## 7. API 接口设计

### 7.1 多级结算政策管理接口

| 接口名称 | 请求方式 | 路径 | 权限标识 |
|---------|---------|------|---------|
| 多级结算政策列表（分页） | GET | `/commission/multilevel/policy/page` | `commission:multilevel:policy:query` |
| 新增多级结算政策 | POST | `/commission/multilevel/policy/create` | `commission:multilevel:policy:create` |
| 修改多级结算政策 | PUT | `/commission/multilevel/policy/update` | `commission:multilevel:policy:update` |
| 停用多级结算政策 | PUT | `/commission/multilevel/policy/disable` | `commission:multilevel:policy:update` |
| 获取政策详情 | GET | `/commission/multilevel/policy/get` | `commission:multilevel:policy:query` |
| 获取启用政策列表（供下拉） | GET | `/commission/multilevel/policy/list-enabled` | `commission:multilevel:policy:query` |

**新增政策 Request Body**：

```json
{
  "policyName": "总部团队A级分润政策",
  "productCategories": ["CAR", "LIFE"],
  "globalFypThreshold": 50000,
  "effectiveDate": "2026-04-01",
  "changeReason": "新增三级分润政策，覆盖车险和寿险",
  "hierarchyItems": [
    {"level": 1, "splitRate": 0.10, "fypThreshold": 50000},
    {"level": 2, "splitRate": 0.05, "fypThreshold": 100000},
    {"level": 3, "splitRate": 0.03, "fypThreshold": 200000}
  ]
}
```

### 7.2 组织负责人绑定接口

| 接口名称 | 请求方式 | 路径 | 权限标识 |
|---------|---------|------|---------|
| 查询组织多级结算绑定列表（分页） | GET | `/commission/multilevel/bind/page` | `commission:multilevel:bind:query` |
| 绑定/更新组织多级结算负责人 | PUT | `/commission/multilevel/bind/update` | `commission:multilevel:bind` |
| 解绑组织多级结算负责人 | PUT | `/commission/multilevel/bind/unbind` | `commission:multilevel:bind` |

**绑定 Request Body**：

```json
{
  "deptId": 10086,
  "agentId": 20001,
  "policyId": 30001,
  "changeReason": "新部门主管上任，绑定对应分润政策"
}
```

### 7.3 分润明细查询接口

| 接口名称 | 请求方式 | 路径 | 权限标识 |
|---------|---------|------|---------|
| 分润明细列表（分页） | GET | `/commission/multilevel/split/page` | `commission:multilevel:split:query` |
| 分润明细汇总（合计） | GET | `/commission/multilevel/split/summary` | `commission:multilevel:split:query` |
| 分润明细导出 | POST | `/commission/multilevel/split/export` | `commission:multilevel:split:export` |
| 获取某笔佣金的完整分润链路 | GET | `/commission/multilevel/split/chain` | `commission:multilevel:split:query` |

**chain 接口 Response 示例**：

```json
{
  "sourceCommissionId": 123456,
  "sourcePolicyNo": "PCAR20260101001",
  "sourceAgentCode": "AG001",
  "sourceAgentName": "张三",
  "sourceCommissionAmount": 1000.00,
  "chainItems": [
    {
      "splitLevel": 1,
      "recipientAgentCode": "AG010",
      "recipientAgentName": "李四（部门主管）",
      "splitRate": 0.10,
      "splitAmount": 100.00,
      "isThresholdMet": true,
      "actualFyp": 120000.00,
      "fypThreshold": 50000.00,
      "commissionRecordId": 999001,
      "status": "APPROVED"
    },
    {
      "splitLevel": 2,
      "recipientAgentCode": "AG020",
      "recipientAgentName": "王五（区域经理）",
      "splitRate": 0.05,
      "splitAmount": 50.00,
      "isThresholdMet": true,
      "actualFyp": 250000.00,
      "fypThreshold": 100000.00,
      "commissionRecordId": 999002,
      "status": "PENDING"
    },
    {
      "splitLevel": 3,
      "recipientAgentCode": "AG030",
      "recipientAgentName": "赵六（大区总监）",
      "splitRate": 0.03,
      "splitAmount": 0.00,
      "isThresholdMet": false,
      "actualFyp": 45000.00,
      "fypThreshold": 200000.00,
      "commissionRecordId": null,
      "skipReason": "当月FYP（45,000元）未达激活门槛（200,000元）",
      "status": "SKIPPED"
    }
  ]
}
```

### 7.4 奖励结算接口

| 接口名称 | 请求方式 | 路径 | 权限标识 |
|---------|---------|------|---------|
| 奖励结算列表（分页） | GET | `/commission/multilevel/bonus/page` | `commission:multilevel:bonus:query` |
| 新增奖励记录 | POST | `/commission/multilevel/bonus/create` | `commission:multilevel:bonus:create` |
| 审核奖励记录 | PUT | `/commission/multilevel/bonus/approve` | `commission:multilevel:bonus:approve` |
| 驳回奖励记录 | PUT | `/commission/multilevel/bonus/reject` | `commission:multilevel:bonus:approve` |
| 批量导入奖励记录 | POST | `/commission/multilevel/bonus/import` | `commission:multilevel:bonus:create` |
| 下载奖励导入模板 | GET | `/commission/multilevel/bonus/import-template` | `commission:multilevel:bonus:query` |
| 导出奖励记录 | POST | `/commission/multilevel/bonus/export` | `commission:multilevel:bonus:export` |

---

## 8. 权限配置

### 8.1 菜单权限

| 菜单名称 | 菜单类型 | 权限标识 | 说明 |
|---------|---------|---------|------|
| 多级结算 | 目录 | — | |
| 政策配置 | 菜单 | — | |
| ├ 查看政策列表 | 按钮 | `commission:multilevel:policy:query` | |
| ├ 新增政策 | 按钮 | `commission:multilevel:policy:create` | |
| ├ 修改政策 | 按钮 | `commission:multilevel:policy:update` | |
| ├ 停用政策 | 按钮 | `commission:multilevel:policy:update` | |
| 负责人设置 | 菜单 | — | |
| ├ 查看绑定列表 | 按钮 | `commission:multilevel:bind:query` | |
| ├ 绑定/修改负责人 | 按钮 | `commission:multilevel:bind` | |
| ├ 解绑负责人 | 按钮 | `commission:multilevel:bind` | |
| 分润明细 | 菜单 | — | |
| ├ 查看分润明细 | 按钮 | `commission:multilevel:split:query` | |
| ├ 导出分润明细 | 按钮 | `commission:multilevel:split:export` | |
| 奖励结算 | 菜单 | — | |
| ├ 查看奖励列表 | 按钮 | `commission:multilevel:bonus:query` | |
| ├ 新增奖励 | 按钮 | `commission:multilevel:bonus:create` | |
| ├ 审核奖励 | 按钮 | `commission:multilevel:bonus:approve` | |
| ├ 导入奖励 | 按钮 | `commission:multilevel:bonus:create` | |
| ├ 导出奖励 | 按钮 | `commission:multilevel:bonus:export` | |

---

## 9. 定时任务

| 任务名称 | Cron 表达式 | 执行逻辑 | 备注 |
|---------|-----------|---------|------|
| 多级结算政策过期检查 | `0 30 0 * * ?` | 每日00:30查询 `expire_date < today` 且 `status=1` 的政策，批量更新 `status=0` | 自动到期停用 |
| 组织分润门槛月度重置 | `0 0 1 1 * ?` | 每月1日01:00清除 Redis 中各负责人的 FYP 缓存（次月重新统计） | 门槛统计重置 |
| 分润记录状态同步 | 随 commission_record 状态机联动（非独立定时任务） | 当 `ins_comm_record.status` 变为 `APPROVED/PAID` 时，同步更新对应 `ins_comm_commission_split.status` | 事件驱动 |

---

## 10. 技术实现要点

### 10.1 金额精度

所有金额字段必须使用 `BigDecimal`，禁止使用 `float/double`：

```java
// 分润金额计算
BigDecimal splitAmount = sourceCommissionAmount
    .multiply(BigDecimal.valueOf(splitRate))
    .setScale(2, RoundingMode.HALF_UP);
```

### 10.2 递归深度防护

分润链路递归向上查找时，必须设置最大层数防护：

```java
private static final int MAX_HIERARCHY_LEVEL = 5;

// 递归时传入currentLevel，达到上限则停止
if (currentLevel > MAX_HIERARCHY_LEVEL) {
    log.warn("分润链路超过最大层级 {}，停止递归，source_commission_id={}", 
             MAX_HIERARCHY_LEVEL, sourceCommissionId);
    break;
}
```

### 10.3 幂等保护

同一笔 FYC 佣金不允许重复触发分润计算，通过 `source_commission_id + split_level + recipient_agent_id` 联合唯一约束保护：

```sql
-- 在 ins_comm_commission_split 上添加唯一索引
UNIQUE KEY `uk_split_unique` (`source_commission_id`, `split_level`, `recipient_agent_id`, `tenant_id`)
```

如果插入时报唯一键冲突，则说明该分润已计算过，直接跳过（幂等处理）。

### 10.4 分布式事务

分润计算过程中，`ins_comm_record`（OVERRIDE）和 `ins_comm_commission_split` 需在同一事务中写入，使用 `@Transactional` 本地事务（两张表在同一数据库 `db_ins_commission`，无需 Seata）：

```java
@Transactional(rollbackFor = Exception.class)
public void calculateSplitForCommission(Long sourceCommissionId) {
    // 1. 查询 FYC commission_record
    // 2. 递归计算各层分润
    // 3. 批量写入 ins_comm_record（OVERRIDE）
    // 4. 批量写入 ins_comm_commission_split
}
```

### 10.5 FYP 缓存策略

激活门槛校验需要实时查询负责人当月 FYP，为避免频繁 SQL 聚合，使用 Redis 缓存：

```
Key:   commission:agent:fyp:{settlePeriod}:{agentId}
Value: 当月FYP合计（BigDecimal字符串）
TTL:   结算周期结束后 30 天自动过期

刷新时机：
- 每次新的 FYC commission_record 创建后，通过 MQ 异步更新对应缓存
- 若缓存 miss，则走 DB 查询并回填缓存
```

### 10.6 政策匹配优先级

当某组织既绑定了多级结算政策，基本法中也配置了 `OVERRIDE` 规则时，优先使用**多级结算政策**（`sys_dept.multi_settle_policy_id != null` 时，多级结算政策优先级高于基本法 override_rate）。

### 10.7 代码包结构

```
intermediary-module-ins-commission-server/
  └── src/main/java/cn/qmsk/intermediary/module/ins/commission/
      ├── controller/admin/
      │   └── AdminInsMultilevelController.java      # 多级结算政策/负责人绑定/分润明细/奖励结算接口
      ├── service/
      │   ├── InsMultilevelPolicyService.java         # 政策管理
      │   ├── InsMultilevelPolicyServiceImpl.java
      │   ├── InsMultilevelSplitService.java          # 分润计算核心
      │   └── InsMultilevelSplitServiceImpl.java
      ├── dal/
      │   ├── dataobject/
      │   │   ├── InsMultilevelPolicyDO.java
      │   │   └── InsCommissionSplitDO.java
      │   └── mysql/
      │       ├── InsMultilevelPolicyMapper.java
      │       └── InsCommissionSplitMapper.java
      ├── mq/
      │   └── consumer/InsMultilevelSplitConsumer.java  # 消费 FYC 计算完成事件
      └── convert/InsMultilevelConvert.java
```

---

## 11. 测试用例要点

| 测试场景 | 前置条件 | 操作步骤 | 预期结果 |
|---------|---------|---------|---------|
| 正常三级分润计算 | 已配置3级政策(10%/5%/3%)，3层负责人均达激活门槛 | 创建FYC=1000元的保单触发分润 | 生成3条OVERRIDE记录（100/50/30元），ins_comm_commission_split 有3行，is_threshold_met全为1 |
| 第2级未达激活门槛 | 政策同上，第2级负责人当月FYP未达门槛 | 触发分润计算 | 第1层正常100元，第2层 split_amount=0（is_threshold_met=0），第3层正常30元（各层独立校验） |
| 未绑定政策时回退基本法 | 组织未设置 multi_settle_policy_id，基本法有OVERRIDE配置 | 出单触发分润 | 按基本法 override_rate 计算分润，ins_comm_commission_split 记录 multilevel_policy_id=NULL |
| 政策停用后不生效 | 已配置政策被停用 | 停用后新出单 | 不生成分润记录（后端校验 policy.status=ENABLE） |
| 重复触发幂等保护 | 已完成某FYC分润计算 | 再次发送相同 FYC 的分润事件 | 幂等保护跳过，不产生重复记录（唯一索引阻断） |
| 变更负责人生效时机 | 已绑定负责人A，当月已有分润记录 | 当月变更为负责人B | 当月已有记录归属A不变；次日新出单归属B |
| 合规截断 | 配置分润比例超过监管上限 | 出单触发分润 | is_compliance_truncated=1，按监管上限计算，original_rate 保留原配置值 |
| 奖励导入正确性 | Excel含5行，其中1行工号不存在 | 批量导入 | 4行成功写入，1行失败，返回失败明细（行号+原因） |

---

## 12. 开发注意事项

### 12.1 数据库注意事项

1. `sys_dept` 表在框架库中，`ins_comm_multilevel_policy` 在 `db_ins_commission`，两者跨库，代码层需分开使用不同的 DataSource，不能在同一 SQL 中 JOIN。
2. `ins_comm_commission_split` 表在分润计算时为批量写入，建议使用 `insertBatch`（MyBatis Plus），单次最大500条。
3. 逻辑删除字段 `deleted=0` 过滤在所有查询中不得遗漏。

### 12.2 配置参数

在 Nacos（`prod-intermediary` 命名空间）中维护以下配置：

```yaml
# ins-commission 微服务配置
commission:
  multilevel:
    # 最大递归层级（防止无限递归）
    max-hierarchy-level: 5
    # 各级分润比例总和上限（合规要求）
    max-total-split-rate: 0.30
    # FYP 缓存 TTL（天）
    fyp-cache-ttl-days: 40
```

### 12.3 前端实现注意

1. **分润比例配置表**：层级数变更时动态增减行，使用 `v-for` 动态渲染；表单校验使用 Element Plus 的 `rules` 配合自定义 validator（校验合计 ≤ 30%）。
2. **分润链路可视化**：在分润详情弹窗中，建议使用时间线（`el-timeline`）组件横向展示各层分润，未激活的层级用灰色+删除线样式区分。
3. **员工选择器**：绑定负责人时调用人管模块的员工列表接口，支持按姓名/工号模糊搜索。
4. **金额展示**：所有金额字段使用千分位格式（`toLocaleString`），分润明细中 `split_amount=0` 时标注"未激活"说明。

### 12.4 关联模块依赖

| 依赖模块 | 依赖内容 | 说明 |
|---------|---------|------|
| `ins-order` | 保单/订单信息 | 分润计算需要保单险种、保险公司信息 |
| `ins-agent`（或 `sys-user`） | 员工/组织信息 | 查询上级链路、负责人信息 |
| `ins-commission`（佣金规则） | 基本法 OVERRIDE 规则 | 未配置多级结算政策时的回退规则 |
| `framework-redis` | Redis 缓存 | FYP 缓存、分润计算分布式锁 |
| `framework-mq` | RocketMQ | 消费 FYC 计算完成事件 |

---

## 附录：状态枚举定义

### A.1 多级结算政策状态

| 枚举值 | 数值 | 说明 |
|-------|------|------|
| ENABLE | 1 | 启用 |
| DISABLE | 0 | 停用 |

### A.2 分润记录状态

| 枚举值 | 说明 | 流转条件 |
|-------|------|---------|
| PENDING | 待审核 | 分润计算完成后初始状态 |
| APPROVED | 已审核 | 随 commission_record 状态审核通过 |
| PAID | 已发放 | 随 commission_record 状态发放完成 |
| SKIPPED | 已跳过 | 激活门槛未达，split_amount=0 |

### A.3 奖励类型枚举

| 枚举值 | 说明 |
|-------|------|
| TEAM_PERFORMANCE | 团队业绩奖 |
| MILESTONE | 达成里程碑奖 |
| QUARTERLY_BONUS | 季度超额奖 |
| ANNUAL_BONUS | 年度奖 |
| OTHER | 其他 |

---

> **文档版本历史**
>
> | 版本 | 日期 | 修改内容 | 修改人 |
> |------|------|---------|--------|
> | V1.0 | 2026-03-07 | 初稿，覆盖政策配置/负责人绑定/分润计算/奖励结算全功能 | — |

---
*End of Document*

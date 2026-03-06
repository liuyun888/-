# 阶段3 B端业务员App-营销工具 业务逻辑设计文档（中篇）
## 覆盖模块：活动推广 + 团队管理

> 本文档面向前后端开发人员，聚焦业务流程、字段规则、接口行为、数据库入库。

---

## 四、活动推广模块

### 4.1 活动列表页

#### 4.1.1 页面说明

业务员App进入「营销工具→活动推广」，展示平台当前可参与的活动。

**页面交互**：
- 顶部Tab栏：进行中 / 未开始 / 已结束（对应`status`：1-进行中 0-未开始 2-已结束）
- 活动卡片展示：
  - 活动封面图（`cover_url`）
  - 活动名称（`activity_name`）
  - 活动时间（`start_time` ~ `end_time`，格式：MM月DD日 - MM月DD日）
  - 活动类型标签（业绩冲刺/拉新/产品促销/节日活动）
  - 参与人数（`participant_count`）
  - 若用户已参与，展示「已参与」标签
- 排序：`sort ASC, start_time DESC`
- 支持下拉刷新、上拉加载（每页10条）

**后端接口**：`GET /app-api/marketing/activity/page`

**请求参数**：
| 字段 | 必填 | 说明 |
|---|---|---|
| status | 否 | 活动状态（不传则查进行中+未开始） |
| pageNo | 是 | 页码 |
| pageSize | 是 | 每页数量 |

**后端逻辑**：
1. 查询`marketing_activity`，WHERE `deleted=0 AND tenant_id=当前租户 AND status IN (0,1)`（不传status时）
2. 联查`marketing_user_activity`判断当前用户是否已参与（SELECT EXISTS）
3. 返回活动列表，包含`isJoined`字段

---

### 4.2 活动详情页

#### 4.2.1 页面说明

业务员点击活动卡片进入活动详情页。

**页面交互**：
- 顶部大图（封面图）
- 活动名称、时间、类型
- 活动说明（`description`，富文本展示）
- 活动规则（`rules`，富文本展示）
- 奖励列表：展示`marketing_activity_reward`中该活动的奖励配置，每条显示：
  - 奖励名称（`reward_name`）
  - 奖励类型（现金/积分/优惠券/实物）
  - 奖励值
  - 达成条件（如：完成目标 / 排名第1-3名）
- 我的进度区域（已参与时展示）：
  - 进度条：当前进度值 / 目标值
  - 百分比展示
  - 完成状态标签
- 底部按钮：
  - 未参与：「立即参与」（活动状态=进行中时可点击）
  - 已参与：「分享活动」

**后端接口**：`GET /app-api/marketing/activity/{id}`

**后端逻辑**：
1. 查询`marketing_activity`
2. 查询`marketing_activity_reward`列表（该活动所有奖励配置）
3. 查询`marketing_user_activity`判断当前用户参与状态和进度
4. 返回组合数据

**返回结构示例**：
```json
{
  "id": 1,
  "activityName": "Q1业绩冲刺",
  "activityType": 1,
  "coverUrl": "https://...",
  "description": "<p>...</p>",
  "rules": "<p>...</p>",
  "startTime": "2025-01-01 00:00:00",
  "endTime": "2025-03-31 23:59:59",
  "status": 1,
  "rewards": [
    {"rewardName":"完成目标奖励","rewardType":1,"rewardValue":500,"conditionType":1},
    {"rewardName":"排名第一奖励","rewardType":1,"rewardValue":2000,"conditionType":2,"conditionValue":"1"}
  ],
  "myProgress": {
    "isJoined": true,
    "currentValue": 3500,
    "targetValue": 10000,
    "completeStatus": 0,
    "rewardStatus": 0
  }
}
```

---

### 4.3 参与活动

**触发**：用户点击「立即参与」按钮。

**前端行为**：弹出确认弹窗"确认参与活动？"，点击确认后调接口。成功后，按钮变为「分享活动」，页面显示我的进度区域。

**后端接口**：`POST /app-api/marketing/activity/{id}/join`

**后端校验**（按顺序，任一不通过返回错误）：
1. 活动必须存在且`deleted=0`
2. 活动`status=1`（进行中），否则返回"活动未开始"或"活动已结束"
3. 当前时间在`start_time`和`end_time`之间
4. `participant_limit > 0`时，校验已参与人数 < `participant_limit`，超出返回"活动参与人数已满"
5. 查询`marketing_user_activity`，WHERE `user_id=当前用户 AND activity_id=活动ID`，若存在则返回"您已参与该活动"

**后端入库**：
- 向`marketing_user_activity`插入记录：
  - `user_id` = 当前用户ID
  - `activity_id` = 活动ID
  - `join_time` = 当前时间
  - `current_value` = 0
  - `target_value` = `marketing_activity.target_value`
  - `complete_status` = 0
  - `reward_status` = 0

**错误码**：
- `1_008_004_001` 活动未开始
- `1_008_004_002` 活动已结束
- `1_008_004_003` 活动参与人数已满
- `1_008_004_004` 您已参与该活动

---

### 4.4 活动分享

**触发**：用户点击「分享活动」按钮。

**前端行为**：
- 弹出分享选项弹窗（微信好友 / 朋友圈 / 复制链接）
- 分享链接：`https://h5.domain.com/activity/{id}?from=share&userId={当前用户ID}`

**后端接口**：`POST /app-api/marketing/activity/{id}/share`（记录分享次数）

**后端逻辑**：仅记录分享行为，`user_id`和`activity_id`记录到日志或`share_count+1`，无复杂逻辑。

---

### 4.5 我的奖励页面

**页面说明**：业务员进入「营销工具→活动推广→我的奖励」。

**页面交互**：
- 列表展示该用户参与并完成的活动奖励：
  - 活动名称
  - 奖励内容（金额/积分/优惠券）
  - 奖励状态：「待发放」「已到账」
  - 发放时间
- Tab：全部 / 待发放 / 已到账

**后端接口**：`GET /app-api/marketing/activity/my-rewards`

**后端逻辑**：
1. 查询`marketing_user_activity`，WHERE `user_id=当前用户 AND complete_status=1`
2. 联查`marketing_activity`获取活动名称
3. 联查奖励发放记录，返回奖励状态和金额

---

### 4.6 活动进度自动更新（后端逻辑）

**触发时机**：订单完成事件 / 邀请成功事件（MQ消息消费）

**处理逻辑**：

```
监听到事件后：
1. 获取事件中的 userId 和 事件数值（订单金额 / 邀请人数+1 / 订单数+1）
2. 查询该用户参与的、状态=进行中(status=1)的、活动目标类型匹配的 marketing_user_activity 记录
3. 对每条记录：
   - current_value = current_value + 事件数值
   - 若 current_value >= target_value：
     - complete_status = 1
     - complete_time = 当前时间
4. UPDATE marketing_user_activity
```

**活动状态自动更新**（定时任务，每小时执行）：
- 未开始(status=0) 且 当前时间 >= start_time → status=1（进行中）
- 进行中(status=1) 且 当前时间 >= end_time → status=2（已结束）
- 活动结束时触发排名奖励结算

---

### 4.7 奖励发放（定时任务，每10分钟执行）

**逻辑步骤**：
1. 查询`marketing_user_activity`，WHERE `complete_status=1 AND reward_status=0`，批量处理
2. 对每条记录，查询`marketing_activity_reward`获取奖励配置
3. 判断达成条件：
   - `condition_type=1`（完成目标）：直接发放
   - `condition_type=2`（排名）：活动结束后统一排名，按名次发放
4. 根据`reward_type`调用对应服务：
   - `reward_type=1`（现金）：调用账户服务 `accountService.addBalance(userId, amount)`
   - `reward_type=2`（积分）：调用积分服务 `pointService.addPoints(userId, points)`
   - `reward_type=3`（优惠券）：调用优惠券服务发放指定优惠券
   - `reward_type=4`（实物）：创建实物发货单
5. 更新`marketing_user_activity.reward_status=1`，`reward_time=当前时间`
6. 发站内消息通知用户

**幂等控制**：每次处理前检查`reward_status`，已发放则跳过，防止重复发放。

---

### 4.8 相关数据表

**`marketing_activity`（活动表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| activity_name | VARCHAR(100) | 活动名称 |
| activity_type | TINYINT | 1-业绩冲刺 2-拉新 3-产品促销 4-节日 |
| cover_url | VARCHAR(500) | 封面图 |
| description | TEXT | 活动说明（富文本） |
| rules | TEXT | 活动规则（富文本） |
| start_time | DATETIME | 开始时间 |
| end_time | DATETIME | 结束时间 |
| target_type | TINYINT | 1-业绩金额 2-邀请人数 3-订单数量 |
| target_value | INT | 目标值 |
| participant_limit | INT | 参与人数上限，0=不限 |
| status | TINYINT | 0-未开始 1-进行中 2-已结束 3-已取消 |
| sort | INT | 排序 |
| creator/.../tenant_id | - | 框架标准字段 |

**`marketing_activity_reward`（活动奖励表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| activity_id | BIGINT | 关联活动ID |
| reward_name | VARCHAR(100) | 奖励名称（如"完成目标奖励"） |
| reward_type | TINYINT | 1-现金 2-积分 3-优惠券 4-实物 |
| reward_value | DECIMAL(10,2) | 奖励值（金额/积分数） |
| condition_type | TINYINT | 1-完成目标 2-排名 |
| condition_value | VARCHAR(100) | 条件值（如排名"1-3"表示前三名） |
| stock | INT | 库存，-1=无限 |
| granted_count | INT | 已发放数量 |

**`marketing_user_activity`（用户参与活动表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| user_id | BIGINT | 用户ID |
| activity_id | BIGINT | 活动ID |
| join_time | DATETIME | 参与时间 |
| current_value | INT | 当前进度值 |
| target_value | INT | 目标值（参与时从活动表复制） |
| complete_status | TINYINT | 0-未完成 1-已完成 |
| complete_time | DATETIME | 完成时间 |
| reward_status | TINYINT | 0-未发放 1-已发放 |
| reward_time | DATETIME | 奖励发放时间 |
| 唯一索引 | - | `uk_user_activity(user_id, activity_id)` |

---

## 五、团队管理模块

### 5.1 团队架构页（组织架构树）

#### 5.1.1 页面说明

业务员App进入「营销工具→团队管理→团队架构」，展示以自己为根节点的团队树形结构。

**页面交互**：
- 树形节点展示，每个节点显示：
  - 成员头像、姓名（脱敏：张**）
  - 职级/角色标签（总监/经理/代理人）
  - 直属下级数量
- 支持节点展开/收起（默认展开2级，后续按需加载）
- 点击节点可进入「成员详情」页
- 顶部显示"我的团队共XX人"（包含所有层级）

**后端接口**：`GET /app-api/marketing/team/structure`

**请求参数**：maxLevel（最大展示层级，默认3）

**后端逻辑**：
1. 查询`marketing_team_structure`，WHERE `user_id=当前用户`，获取当前节点信息
2. 递归查询下级（不超过`maxLevel`层）：每次查询`parent_id=当前节点user_id`
3. 组装树形结构返回

**性能说明**：若团队规模大（>100人），改为"按需懒加载"方式：首次只返回直属下级，用户点击展开时再请求下一级。懒加载接口：`GET /app-api/marketing/team/children?parentId={userId}`

**`marketing_team_structure`（团队架构表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| user_id | BIGINT | 用户ID（唯一索引） |
| parent_id | BIGINT | 直属上级ID，0表示顶级 |
| path | VARCHAR(500) | 层级路径，如`0/10/20/30`，便于查全部下级 |
| level | TINYINT | 层级：1-一级（顶级）2-二级... |
| role_type | TINYINT | 1-总监 2-经理 3-代理人 |
| direct_count | INT | 直属下级数量（冗余字段） |
| team_count | INT | 团队总人数（含所有层级，冗余字段） |

> **团队关系建立时机**：新代理人通过邀请注册后，在`bindInviteRelation`中调用`teamService.buildTeamRelation(inviteeId, inviterId)`建立团队关系，入库`marketing_team_structure`。

---

### 5.2 直属下级列表页

**页面交互**：
- 展示直属下级成员列表（`parent_id=当前用户`的成员）
- 每条显示：头像、姓名、手机号（脱敏）、加入时间、本月业绩金额
- 右上角显示直属下级总人数
- 点击某成员进入「成员详情」

**后端接口**：`GET /app-api/marketing/team/direct-members`

**请求参数**：pageNo、pageSize

**后端逻辑**：
1. 查询`marketing_team_structure`，WHERE `parent_id=当前用户ID AND deleted=0`
2. 批量查询用户基本信息（头像、姓名、手机号）
3. 查询`marketing_team_performance`获取本月业绩（stat_type=2-月，stat_date=本月第一天）
4. 返回列表

---

### 5.3 成员详情页

**页面交互**：
- 成员基本信息：头像、姓名（脱敏）、加入时间、所在层级
- 业绩数据（Tab：本月 / 本季 / 本年）：
  - 个人订单数、订单金额、佣金收入
- 下级成员数（直属下级数量，可点击跳转）

**后端接口**：`GET /app-api/marketing/team/member/{memberId}`

**权限校验**：后端必须校验请求者与目标成员存在上下级关系（目标成员在请求者的团队`path`中），否则返回403。

**后端逻辑**：
1. 校验权限（见上）
2. 查询成员基本信息
3. 查询`marketing_team_performance`，按`stat_type`分别返回月/季/年业绩

---

### 5.4 邀请成员（生成邀请链接）

**页面交互**：
- 点击「邀请成员加入」，弹出分享弹窗
- 展示当前用户的邀请二维码和邀请链接
- 按钮：「复制链接」「保存二维码」

**后端接口**：复用客户邀请模块的`GET /app-api/marketing/invite/my-info`，取邀请链接和邀请码即可。

---

### 5.5 团队业绩统计页

**页面说明**：业务员进入「营销工具→团队管理→团队业绩」。

**页面交互**：
- 顶部数据卡片（3列）：
  - 个人业绩（订单金额）
  - 直属团队业绩
  - 全团队业绩
- 时间维度切换Tab：本月 / 本季 / 本年
- 业绩折线图：展示近30天/近12个月业绩趋势（ECharts）
- 数据明细：订单数 / 订单金额 / 佣金收入（分个人、直属团队、全团队）

**后端接口**：`GET /app-api/marketing/team/performance`

**请求参数**：
| 字段 | 必填 | 说明 |
|---|---|---|
| statType | 是 | 1-日 2-月 3-季 4-年 |

**后端逻辑**：
1. 查询`marketing_team_performance`，WHERE `user_id=当前用户 AND stat_type=请求的statType AND stat_date=对应时间段第一天`
2. 若记录不存在，返回全0（不报错）
3. 返回个人、直属团队、全团队的订单数/金额/佣金三组数据

---

### 5.6 团队业绩排名页

**页面说明**：业务员进入「营销工具→团队管理→业绩排名」。

**页面交互**：
- 顶部Tab：日榜 / 月榜 / 季榜 / 年榜
- 排名列表（Top 50）：
  - 排名序号（第1-3名展示金/银/铜奖杯图标）
  - 成员头像、姓名（脱敏）
  - 订单金额
  - 距上一名差距（第2名显示"距第1名还差¥XXX"）
- 当前登录用户高亮展示（无论排名第几都固定显示在底部"我的排名：第X名"）

**后端接口**：`GET /app-api/marketing/team/ranking`

**请求参数**：
| 字段 | 必填 | 说明 |
|---|---|---|
| rankType | 是 | 1-日 2-月 3-季 4-年 |
| topN | 否 | 返回前N名，默认50 |

**后端逻辑**：
1. 根据`rankType`确定统计日期和`stat_type`
2. 查询`marketing_team_performance`，按`self_order_amount DESC`排序，取Top N
3. 批量查询用户信息（头像、姓名）
4. 额外查询当前登录用户的排名（在结果集中的位置，若不在Top N则单独查询其排名）
5. 返回排名列表 + 当前用户排名信息

**排名规则**：
- 主排序：`self_order_amount`（个人订单金额）降序
- 次排序：`self_order_count`（订单数量）降序（金额相同时）
- 排名基于昨日（日榜）/本月以来（月榜）/本季以来（季榜）/本年以来（年榜）

---

### 5.7 团队业绩定时计算任务

**执行时间**：每天凌晨01:00执行

**计算逻辑**：
1. 取昨日日期（`stat_date = yesterday`）
2. 遍历所有代理人（`marketing_team_structure`中所有用户）
3. 对每个用户：
   - **个人日业绩**：查昨日该用户的订单表，汇总`order_count`、`order_amount`、`commission`，写入`marketing_team_performance`（`stat_type=1`）
   - **月度业绩**：累加当月每日业绩（或从订单表直接聚合），写入/更新`marketing_team_performance`（`stat_type=2`，`stat_date=本月第一天`）
   - **直属团队日业绩**：查询直属下级ID列表，汇总其个人日业绩，更新当前用户`direct_order_count`等字段
   - **全团队日业绩**：利用`path`字段`LIKE 'path前缀%'`查全部下级ID，汇总个人业绩，更新`team_order_count`等字段

**唯一键**：`UNIQUE KEY uk_user_date_type(user_id, stat_date, stat_type)`，冲突时UPDATE。

---

### 5.8 相关数据表

**`marketing_team_performance`（团队业绩表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| user_id | BIGINT | 用户ID |
| stat_date | DATE | 统计日期（日统计=具体日期，月统计=月第一天，季=季第一天，年=年第一天） |
| stat_type | TINYINT | 1-日 2-月 3-季 4-年 |
| self_order_count | INT | 个人订单数 |
| self_order_amount | DECIMAL(12,2) | 个人订单金额 |
| self_commission | DECIMAL(12,2) | 个人佣金 |
| direct_order_count | INT | 直属团队订单数 |
| direct_order_amount | DECIMAL(12,2) | 直属团队订单金额 |
| direct_commission | DECIMAL(12,2) | 直属团队佣金 |
| team_order_count | INT | 全团队订单数 |
| team_order_amount | DECIMAL(12,2) | 全团队订单金额 |
| team_commission | DECIMAL(12,2) | 全团队佣金 |
| 唯一索引 | - | `uk_user_date_type(user_id, stat_date, stat_type)` |

---

## 六、错误码定义（中篇相关）

| 错误码 | 说明 |
|---|---|
| 1_008_004_000 | 活动不存在 |
| 1_008_004_001 | 活动未开始 |
| 1_008_004_002 | 活动已结束 |
| 1_008_004_003 | 活动参与人数已满 |
| 1_008_004_004 | 您已参与该活动 |
| 1_008_005_000 | 团队成员不存在 |
| 1_008_005_001 | 无权查看该成员信息 |

---

*上篇内容：营销素材 + 客户邀请 → 见《阶段3-B端营销工具业务逻辑设计文档-上篇》*
*下篇内容：培训中心（课程、考试、证书）→ 见《阶段3-B端营销工具业务逻辑设计文档-下篇》*

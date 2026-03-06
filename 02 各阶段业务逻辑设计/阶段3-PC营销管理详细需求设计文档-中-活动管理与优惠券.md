# 阶段3-PC管理后台-营销管理详细需求设计文档（中）
## 活动管理 & 优惠券管理

> 文档版本：V2.0 | 编写日期：2026-02-19 | 定位：开发实现指南，聚焦业务逻辑与操作细节

---

## 一、活动管理

### 1.1 功能入口

菜单路径：营销管理 → 活动管理

列表页展示：封面缩略图、活动名称、活动编号、活动类型、活动时间（开始~结束）、状态标签（草稿/待审核/已通过/进行中/已结束/已下架）、浏览量、参与人数、订单数、订单金额、操作（查看/编辑/审核/上下架/数据统计/删除）。

筛选条件：活动类型（多选）、活动状态（单选）、创建时间范围、活动时间范围、创建人、关键词（名称/编号模糊搜索）。

---

### 1.2 活动创建

点击「新增活动」按钮，进入活动创建页面（步骤式表单，共4步）。

#### 第一步：基础信息

| 字段 | 是否必填 | 校验规则 |
|------|----------|----------|
| 活动名称 | 必填 | 2-100字符 |
| 活动类型 | 必填 | 单选：新人礼/满减/折扣/赠品/拼团/秒杀/积分兑换 |
| 封面图 | 必填 | JPG/PNG，不超过2MB，建议750×400px |
| 轮播图 | 非必填 | 最多5张，同封面图要求 |
| 活动开始时间 | 必填 | 不能早于当前时间 |
| 活动结束时间 | 必填 | 须晚于开始时间 |
| 活动描述 | 必填 | 富文本编辑，支持图文混排 |

#### 第二步：活动规则（根据活动类型动态展示不同配置项）

**新人礼：**
- 新用户定义：注册天数 < 30天 且 历史订单数=0（两个条件需同时满足）；
- 奖励内容：可选发优惠券（多选，选择已有优惠券）+ 赠送积分（整数，可为0）；
- 领取条件：勾选"需完成实名认证"（开关，默认关闭）；
- 每人限领次数：固定1次，不可配置；

**满减活动：**
- 满减阶梯：可新增多档（最多5档），每档填写"满X元减Y元"，X和Y均为正整数；
- 同一订单是否可叠加使用优惠券：是/否 开关；
- 适用范围内是否包邮：是/否 开关（与物流模块联动）；

**折扣活动：**
- 折扣力度：1-99（整数或保留1位小数），如 85 表示 85折；
- 折扣上限：最多优惠金额（正整数，0表示不限）；

**赠品活动：**
- 赠品列表：搜索选择赠品（如实物商品或优惠券），填写赠品数量；
- 触发条件：下拉选择「购买指定产品」或「订单满X元」，并填写对应值；

**拼团活动：**
- 成团人数：2-10人（正整数）；
- 拼团价格：正数，保留2位小数；
- 开团有效期：24/48/72小时（单选）；
- 模拟成团：开关，开启后若有效期内未达成团人数，系统自动补足；

**秒杀活动：**
- 秒杀价格：正数，保留2位小数；
- 秒杀库存：正整数；
- 每人限购：正整数，0表示不限；
- 秒杀时段：可配置多个时段（开始时间+结束时间），时段须在活动时间范围内；

#### 第三步：目标用户

| 选项 | 逻辑说明 |
|------|----------|
| 全部用户 | 不限制，所有已登录用户可参与 |
| 新用户 | 注册时间 < 30天（C端接口实时判断） |
| 老用户 | 注册时间 >= 30天 且 有过至少1笔已支付订单 |
| 指定用户 | 上传用户ID列表（Excel上传，后端解析）或选择用户标签（与CRM标签联动） |

目标用户配置以 JSON 存入 mkt_activity.target_config 字段。

#### 第四步：产品范围 & 参与限制

**产品范围：**
- 全部产品：无需额外配置；
- 指定分类：多选产品分类（树形选择器）；
- 指定产品：搜索产品名称或编码，批量添加至列表，支持 Excel 批量导入（含商品编码列）；
- 排除产品：在全部产品/指定分类下，可额外排除部分产品；
- 产品配置以 JSON 存入 mkt_activity.product_config；

**参与限制：**
- 不限：用户可无限次参与；
- 按次数限：每人限参与N次（正整数）；
- 按频率限：下拉选择每天/每周/每月，填写限制次数；

**其他配置：**
- 关联优惠券：选择已有优惠券，活动期间自动发放给参与用户；
- 赠送积分：参与活动后赠送积分，正整数，0表示不赠送；
- 分享奖励：开关，开启后可配置分享后好友注册或下单给分享人额外积分；

---

### 1.3 后端校验（创建/编辑）

1. 活动名称不可与同类型、同时间段的其他活动重名（提示即可，不强制阻止）；
2. end_time 须 > start_time；
3. 秒杀活动：秒杀时段须在活动时间范围内；
4. 满减阶梯：各档次的满减金额须单调递增（金额和优惠金额都要递增，不允许高档次优惠力度小于低档次）；
5. 指定用户上传：解析 Excel 后校验用户 ID 是否存在于系统中，不存在的 ID 跳过并在结果中提示；
6. 关联优惠券：校验优惠券是否有效（status 非下架）；

---

### 1.4 活动审核流程

**提交审核：**
- 列表行点击「提交审核」或创建页面底部点击「提交审核」按钮；
- status: 0(草稿) → 1(待审核)，audit_status=0；
- 系统发站内消息给拥有 mkt:activity:audit 权限的用户；

**审核员操作（列表点击「审核」按钮，弹出审核弹窗）：**
- 弹窗展示：活动详情、规则预览、产品信息；
- 操作：
  - 「通过」：
    - audit_status=1，status=2（已通过），auditor=当前用户，audit_time=当前时间；
    - 发送通知给活动创建者：「您的活动 [活动名称] 已审核通过」；
  - 「驳回」：
    - 填写驳回原因（必填，10-200字符）；
    - audit_status=2，status=0（回到草稿），audit_remark=填写内容；
    - 发送通知给创建者，消息内含驳回原因；

**审核记录：**
- 写入 mkt_activity_audit 表（activity_id, auditor, audit_result, audit_remark, audit_time）；

---

### 1.5 活动状态机与定时任务

```
草稿(0) → [提交审核] → 待审核(1)
待审核(1) → [审核通过] → 已通过(2)
待审核(1) → [审核驳回] → 草稿(0)
已通过(2) → [到达start_time, 定时任务] → 进行中(3)
进行中(3) → [到达end_time, 定时任务] → 已结束(4)
进行中(3) → [手动下架] → 已下架(5)
已通过(2) → [手动下架] → 已下架(5)
```

**定时任务（每分钟执行）：**
- 扫描 status=2 且 start_time <= 当前时间的记录，更新 status=3；
- 扫描 status=3 且 end_time <= 当前时间的记录，更新 status=4；
- 发送活动开始/结束通知；

**手动下架：**
- 点击「下架」按钮，弹出填写下架原因弹窗（必填，5-200字符）；
- 更新 status=5；
- 发送通知给已参与该活动但奖励未使用的用户（批量消息，异步 MQ 发送）；

**活动延期（进行中的活动）：**
- 管理员点击「申请延期」按钮，填写新的结束时间；
- 须重新走审核流程（status 重新变为1）；
- 审核通过后更新 end_time；

---

### 1.6 活动编辑限制

| 活动状态 | 可编辑内容 |
|----------|-----------|
| 草稿(0) | 全部字段 |
| 待审核(1) | 需先撤回（status→0），再编辑 |
| 已通过(2)-未开始 | 活动时间、规则配置 |
| 进行中(3) | 仅可修改活动描述、排序号（不可修改规则和时间） |
| 已结束(4)/已下架(5) | 不可修改 |

---

### 1.7 活动删除

- 草稿(0)和已下架(5)状态可删除；
- 进行中(3)和已结束(4)不可删除；
- 有参与记录的活动，执行逻辑删除（deleted=1），保留参与记录；
- 无参与记录的活动，支持物理删除（需管理员权限）；
- 删除前弹出二次确认框，显示活动基本信息和参与人数；

---

### 1.8 C端活动参与流程（供参考，后端需实现对应接口）

1. C 端用户访问活动页面，后端校验：
   - 活动 status=3（进行中）；
   - 当前用户符合目标用户条件（新用户/老用户/指定用户）；
   - 用户参与次数未超限；
2. 用户点击参与：
   - 验证登录状态；
   - 原子操作：插入参与记录（mkt_activity_record）+ 更新 join_count+1；
   - 秒杀/拼团需额外校验库存（Redis 原子减库存）；
3. 发放奖励（MQ 异步处理）：
   - 优惠券：调用优惠券发放接口，绑定到用户账户；
   - 积分：调用积分发放接口，记录积分明细；
4. 更新活动统计：order_count、order_amount 等在订单完成后异步更新；

---

### 1.9 活动数据统计

点击列表行「数据统计」按钮，进入活动统计页面，展示：

**核心指标卡：**
- 浏览UV / PV、参与人数、订单数、订单金额、转化率（参与人数/浏览UV）、客单价、ROI

**趋势图（ECharts折线图）：**
- X轴：时间（秒杀活动按小时，其他活动按天）；
- 多折线：浏览量、参与人数、订单数、订单金额；

**用户分析（饼图/柱图）：**
- 新老用户占比（基于注册时间判断）；
- 用户地域分布（Top10省份）；
- 用户来源渠道（直接访问/分享进入/活动推送）；

**产品分析（列表）：**
- 活动相关产品按销量倒序排行；
- 每个产品：销量、贡献金额、转化率；

**数据导出：**
- 支持导出 Excel，包含按天明细数据 + 汇总数据；
- 支持自定义导出时间范围；

---

### 1.10 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/mkt/activity/page | GET | 分页查询 |
| /admin-api/mkt/activity/get/{id} | GET | 活动详情 |
| /admin-api/mkt/activity/create | POST | 创建活动 |
| /admin-api/mkt/activity/update | PUT | 编辑活动 |
| /admin-api/mkt/activity/delete | DELETE | 删除活动 |
| /admin-api/mkt/activity/submit-audit | POST | 提交审核 |
| /admin-api/mkt/activity/revoke-audit | POST | 撤回审核 |
| /admin-api/mkt/activity/audit | POST | 审核（通过/驳回） |
| /admin-api/mkt/activity/offline | PUT | 手动下架 |
| /admin-api/mkt/activity/extend | POST | 申请延期 |
| /admin-api/mkt/activity/statistics/{id} | GET | 活动统计数据 |
| /admin-api/mkt/activity/statistics/export | GET | 导出统计数据 |
| /admin-api/mkt/activity/record/page | GET | 参与记录分页 |
| /admin-api/mkt/activity/product/list | GET | 活动产品列表 |
| /admin-api/mkt/activity/product/add | POST | 添加活动产品 |
| /admin-api/mkt/activity/product/remove | DELETE | 移除活动产品 |
| /admin-api/mkt/activity/upload-image | POST | 上传活动图片 |

权限标识：mkt:activity:read / mkt:activity:write / mkt:activity:delete / mkt:activity:audit / mkt:activity:status / mkt:activity:statistics

---

## 二、优惠券管理

### 2.1 功能入口

菜单路径：营销管理 → 优惠券

列表页展示：优惠券名称、编号、类型、优惠值、发行总量、已领取、已使用、领取率、使用率、有效期、状态、操作（查看/编辑/下架/统计/删除）。

---

### 2.2 创建优惠券

点击「新增优惠券」弹出创建表单（抽屉组件，较宽）。

#### 基础信息

| 字段 | 是否必填 | 校验规则 |
|------|----------|----------|
| 优惠券名称 | 必填 | 2-100字符 |
| 优惠券类型 | 必填 | 单选：满减券/折扣券/兑换券/立减券 |
| 使用说明 | 非必填 | 详细规则描述，最长500字符 |

#### 优惠规则（根据类型展示不同字段）

**满减券：**
- 满减金额：正整数，如"满100减20"（100为门槛，20为优惠）；
- 使用门槛（满足金额）：必填，正整数；
- 优惠金额：必填，正整数，须小于使用门槛；

**折扣券：**
- 折扣率：1-99的数字（支持一位小数），必填；
- 使用门槛：非必填，0表示无门槛；
- 最高优惠金额：非必填，0表示不限，正整数；

**兑换券：**
- 兑换商品：从商品列表中选择，必填；
- 兑换数量：正整数，默认1；

**立减券：**
- 立减金额：正整数，必填；
- 无门槛限制；

#### 发行设置

| 字段 | 是否必填 | 说明 |
|------|----------|------|
| 发行总量 | 必填 | 正整数，-1表示不限量 |
| 领取方式 | 必填 | 单选：手动领取/自动发放/活动发放/兑换码 |
| 每人限领次数 | 必填 | 正整数，-1不限 |
| 每人限用次数 | 必填 | 正整数，-1不限，须 <= 每人限领次数 |
| 是否可叠加使用 | 必填 | 开关，是/否 |

**选择"兑换码"领取方式时，额外配置：**
- 生成兑换码数量（与发行总量保持一致，也可独立设置）；
- 提交创建后，系统异步批量生成兑换码（格式：8-16位大写字母+数字，存入 mkt_coupon_code 表）；
- 生成完毕后可在详情页下载 Excel 兑换码列表；

#### 适用范围

**产品范围：**
- 全部产品 / 指定分类（多选）/ 指定产品（搜索添加）
- 产品配置存 JSON 至 mkt_coupon.product_config；

**用户范围：**
- 全部用户 / 新用户（注册<30天）/ 指定用户（上传 ID 列表）/ 标签用户（选择用户标签）
- 用户配置存 JSON 至 mkt_coupon.user_config；

#### 有效期设置

| 类型 | 字段 |
|------|------|
| 固定日期 | 领取开始时间（start_time）+ 领取结束时间（end_time）+ 可使用时间范围（use_start_time, use_end_time，非必填） |
| 相对日期（领取后N天） | valid_type=2，填写 valid_days（正整数），领取后从 valid_days 天后过期 |

---

### 2.3 后端创建校验

1. 折扣券：折扣率须在1-99范围内；
2. 满减券：优惠金额须小于使用门槛，否则返回错误；
3. 有效期类型为固定日期时：start_time < end_time 必须成立；
4. 每人限用次数不可大于每人限领次数；
5. 发行总量为-1时，领取方式不可为"兑换码"（兑换码需要确定数量）；
6. 生成优惠券编号：CPN + yyyyMMddHHmmss + 4位随机数，保证唯一；

**入库（mkt_coupon 表）：** 所有配置字段，receive_count 和 use_count 初始为0，status 初始为0（未开始）。

---

### 2.4 优惠券发放

#### 手动领取（C端）

1. C 端优惠券列表展示 receive_type=1 的优惠券；
2. 用户点击「立即领取」：
   - 后端校验（串行校验，任意一项失败即返回错误）：
     - a. 优惠券 status=1（进行中）；
     - b. 当前时间在 start_time ~ end_time 范围内；
     - c. 总发行量未达上限（receive_count < total_count，total_count=-1则不限）；
     - d. 用户已领取次数 < receive_limit（-1则不限）；
     - e. 用户符合 user_scope 条件；
   - 使用 Redis 分布式锁防并发超发；
   - 创建 mkt_coupon_user 记录，生成 coupon_code（UUID截取16位）；
   - mkt_coupon.receive_count +1（使用数据库乐观锁）；
   - 计算有效期：固定日期直接取 use_start_time/use_end_time；相对日期：valid_start_time=领取时间，valid_end_time=领取时间+valid_days天；
   - 发送领取成功通知（站内消息）；

#### 批量/定向发放（后台操作）

- 路径：优惠券详情页 → 「发放」按钮 → 弹出发放弹窗；
- 选择发放对象：输入用户ID（逗号分隔）或上传 Excel 用户ID 列表；
- 填写发放数量（每人发几张）；
- 后端校验总发行量是否充足；
- 通过 MQ 异步批量发放，任务完成后通知操作人；
- 批量发放任务记录写入 mkt_coupon_send_task 表（task_id, coupon_id, user_list, status, total_count, success_count, fail_count, create_time）；

---

### 2.5 优惠券使用核销

**C端下单使用流程：**
1. 下单时展示「选择优惠券」入口；
2. 后端查询用户可用券列表（status=1 未使用 + 在有效期内 + 适用当前订单产品）；
3. 用户选择优惠券后，后端验证：
   - 订单金额满足优惠券使用门槛；
   - 优惠券适用范围包含订单中的产品；
   - 用户使用次数未超 use_limit；
4. 优惠计算：
   - 满减：order_amount - discount_value（确保不小于0）；
   - 折扣：order_amount * (discount_value/100)，不超过 max_discount（若设置）；
   - 立减：order_amount - discount_value（确保不小于0）；
5. 提交订单时**锁定优惠券**：mkt_coupon_user.status=4（已锁定）；
6. 若15分钟未支付→自动解锁：status=1（未使用），定时任务每分钟扫描；
7. 支付成功→**核销优惠券**：status=2（已使用），use_time=当前时间，order_id=订单ID；mkt_coupon.use_count+1；

**退款处理：**
- 订单完成退款后，对应优惠券状态从2变回1（未使用）；
- 有效期延长：original_end_time + 7天（若原有效期已过，则 now + 7天）；

---

### 2.6 优惠券编辑规则

| 状态 | 可修改字段 |
|------|-----------|
| 未开始(0) | 全部字段 |
| 进行中(1) | 结束时间（end_time）、使用说明；不可改优惠金额/门槛/适用范围 |
| 已结束(2) | 不可修改 |

**特殊操作：**
- 「追加发行量」：在详情页点击「追加」按钮，输入追加数量，total_count += 追加量；
- 「延长有效期」：在详情页点击「延长」按钮，修改 end_time 或 valid_days；

---

### 2.7 优惠券下架

- 点击「下架」按钮，二次确认；
- status=3（已下架）；
- 已领取未使用的券**不强制失效**（仍在有效期内可使用）；
- 「强制失效」（需超级管理员权限）：将该券所有 mkt_coupon_user.status=1 的记录批量改为3（已过期），不可恢复，须二次确认并填写原因；

---

### 2.8 核销统计

**入口：** 列表行点击「统计」按钮，进入统计详情页。

**统计内容：**
- 核心指标卡：发行量 / 领取量 / 领取率 / 使用量 / 使用率 / 剩余量 / 带动GMV（使用该券的订单总额）/ 平均优惠金额；
- 趋势图：按天统计领取量和使用量，双折线；
- 用户分布：新老用户占比、用户地域分布；
- 订单明细：展示使用该券的订单列表（用户、订单号、订单金额、优惠金额、支付时间）；
- 导出：领取明细 Excel / 使用明细 Excel / 兑换码列表 Excel（仅兑换码类型）；

---

### 2.9 优惠券过期提醒（定时任务）

- 每天上午10:00执行；
- 查询用户持有的、将在3天内过期的优惠券（mkt_coupon_user 表）；
- 发送站内消息提醒：「您有X张优惠券将在3天后过期，请尽快使用」；
- 过期前1天再次提醒；
- 推送渠道：站内消息（必须）+ 短信（可选配置）；

---

### 2.10 接口列表

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/mkt/coupon/page | GET | 分页查询 |
| /admin-api/mkt/coupon/get/{id} | GET | 详情 |
| /admin-api/mkt/coupon/create | POST | 创建 |
| /admin-api/mkt/coupon/update | PUT | 编辑 |
| /admin-api/mkt/coupon/delete | DELETE | 删除 |
| /admin-api/mkt/coupon/offline | PUT | 下架 |
| /admin-api/mkt/coupon/force-expire | PUT | 强制失效（管理员） |
| /admin-api/mkt/coupon/add-count | POST | 追加发行量 |
| /admin-api/mkt/coupon/extend-time | POST | 延长有效期 |
| /admin-api/mkt/coupon/generate-code | POST | 生成兑换码 |
| /admin-api/mkt/coupon/code/list | GET | 兑换码列表 |
| /admin-api/mkt/coupon/code/export | GET | 导出兑换码 |
| /admin-api/mkt/coupon/send | POST | 手动定向发放 |
| /admin-api/mkt/coupon/batch-send | POST | 批量发放（MQ异步） |
| /admin-api/mkt/coupon/user/page | GET | 用户券列表 |
| /admin-api/mkt/coupon/statistics/{id} | GET | 统计详情 |
| /admin-api/mkt/coupon/export-receive | GET | 导出领取明细 |
| /admin-api/mkt/coupon/export-use | GET | 导出使用明细 |

权限标识：mkt:coupon:read / mkt:coupon:write / mkt:coupon:delete / mkt:coupon:send / mkt:coupon:offline / mkt:coupon:statistics

---

## 三、数据库表汇总（活动 & 优惠券模块）

### mkt_activity

```sql
CREATE TABLE `mkt_activity` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `activity_no` varchar(32) NOT NULL UNIQUE COMMENT '活动编号',
  `name` varchar(100) NOT NULL COMMENT '活动名称',
  `type` tinyint NOT NULL COMMENT '1新人礼2满减3折扣4赠品5拼团6秒杀7积分兑换',
  `cover_image` varchar(500) NOT NULL,
  `banner_images` text DEFAULT NULL COMMENT '轮播图JSON数组',
  `description` text NOT NULL,
  `rule_config` text NOT NULL COMMENT '规则配置JSON',
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  `target_type` tinyint NOT NULL DEFAULT '1' COMMENT '1全部2新用户3老用户4指定',
  `target_config` text DEFAULT NULL,
  `limit_type` tinyint NOT NULL DEFAULT '1' COMMENT '1不限2次数限制',
  `limit_count` int DEFAULT NULL,
  `product_scope` tinyint NOT NULL DEFAULT '1' COMMENT '1全部2分类3产品',
  `product_config` text DEFAULT NULL,
  `coupon_ids` varchar(500) DEFAULT NULL,
  `point_give` int DEFAULT '0',
  `sort_order` int NOT NULL DEFAULT '0',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0草稿1待审核2已通过3进行中4已结束5已下架',
  `audit_status` tinyint NOT NULL DEFAULT '0' COMMENT '0待审核1已通过2已驳回',
  `audit_remark` varchar(500) DEFAULT NULL,
  `auditor` varchar(64) DEFAULT NULL,
  `audit_time` datetime DEFAULT NULL,
  `view_count` int NOT NULL DEFAULT '0',
  `join_count` int NOT NULL DEFAULT '0',
  `order_count` int NOT NULL DEFAULT '0',
  `order_amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_status_time` (`status`, `start_time`, `end_time`)
) COMMENT='营销活动';
```

### mkt_activity_record

```sql
CREATE TABLE `mkt_activity_record` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `activity_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `join_time` datetime NOT NULL,
  `award_type` tinyint NOT NULL COMMENT '1优惠券2积分3赠品',
  `award_config` text DEFAULT NULL COMMENT '奖励详情JSON',
  `order_id` bigint DEFAULT NULL,
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '1已参与2已核销3已过期',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_activity_user` (`activity_id`, `user_id`)
) COMMENT='活动参与记录';
```

### mkt_coupon

```sql
CREATE TABLE `mkt_coupon` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `coupon_no` varchar(32) NOT NULL UNIQUE,
  `name` varchar(100) NOT NULL,
  `type` tinyint NOT NULL COMMENT '1满减2折扣3兑换4立减',
  `discount_type` tinyint NOT NULL DEFAULT '1' COMMENT '1金额2折扣',
  `discount_value` decimal(10,2) NOT NULL,
  `condition_type` tinyint NOT NULL DEFAULT '1' COMMENT '1无门槛2满金额',
  `condition_value` decimal(10,2) DEFAULT NULL,
  `max_discount` decimal(10,2) DEFAULT NULL COMMENT '最高优惠(折扣券)',
  `total_count` int NOT NULL DEFAULT '-1' COMMENT '-1不限',
  `receive_count` int NOT NULL DEFAULT '0',
  `use_count` int NOT NULL DEFAULT '0',
  `product_scope` tinyint NOT NULL DEFAULT '1',
  `product_config` text DEFAULT NULL,
  `user_scope` tinyint NOT NULL DEFAULT '1',
  `user_config` text DEFAULT NULL,
  `receive_type` tinyint NOT NULL DEFAULT '1' COMMENT '1手动2自动3活动4兑换码',
  `receive_limit` int NOT NULL DEFAULT '-1',
  `use_limit` int NOT NULL DEFAULT '-1',
  `valid_type` tinyint NOT NULL DEFAULT '1' COMMENT '1固定日期2领取后N天',
  `valid_days` int DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `use_start_time` datetime DEFAULT NULL,
  `use_end_time` datetime DEFAULT NULL,
  `is_stackable` tinyint NOT NULL DEFAULT '0',
  `description` text DEFAULT NULL,
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0未开始1进行中2已结束3已下架',
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) COMMENT='优惠券';
```

### mkt_coupon_user

```sql
CREATE TABLE `mkt_coupon_user` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `coupon_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `coupon_code` varchar(32) NOT NULL UNIQUE COMMENT '用户券码',
  `receive_type` tinyint NOT NULL DEFAULT '1',
  `receive_time` datetime NOT NULL,
  `valid_start_time` datetime NOT NULL,
  `valid_end_time` datetime NOT NULL,
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '1未使用2已使用3已过期4已锁定',
  `use_time` datetime DEFAULT NULL,
  `order_id` bigint DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_coupon` (`user_id`, `coupon_id`, `status`),
  KEY `idx_coupon_status` (`coupon_id`, `status`)
) COMMENT='用户优惠券';
```

### mkt_coupon_code

```sql
CREATE TABLE `mkt_coupon_code` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `coupon_id` bigint NOT NULL,
  `code` varchar(32) NOT NULL UNIQUE COMMENT '兑换码',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0未使用1已使用',
  `user_id` bigint DEFAULT NULL,
  `use_time` datetime DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_code` (`code`),
  KEY `idx_coupon` (`coupon_id`)
) COMMENT='优惠券兑换码';
```

---

*下一篇文档：阶段3-PC营销管理详细需求设计文档-下-积分管理与数据统计*

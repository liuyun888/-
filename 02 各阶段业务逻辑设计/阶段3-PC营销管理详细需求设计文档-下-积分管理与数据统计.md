# 阶段3-PC管理后台-营销管理详细需求设计文档（下）
## 积分管理 & 数据统计

> 文档版本：V2.0 | 编写日期：2026-02-19 | 定位：开发实现指南，聚焦业务逻辑与操作细节

---

## 一、积分管理

### 1.1 功能入口

菜单路径：营销管理 → 积分管理，下设以下子菜单：
- 积分规则
- 积分发放
- 积分兑换（积分商城管理）
- 积分明细

---

### 1.2 积分规则配置

**菜单：营销管理 → 积分管理 → 积分规则**

列表页展示：规则名称、规则编码、事件类型、积分值、限制类型、状态、排序、操作（编辑/启用禁用/删除）。

点击「新增规则」，弹出规则配置表单：

| 字段 | 是否必填 | 说明 |
|------|----------|------|
| 规则名称 | 必填 | 2-100字符，如"每日签到奖励" |
| 规则编码 | 必填 | 唯一，字母数字，如"SIGN_IN_DAILY"，一旦保存不可修改 |
| 规则类型 | 必填 | 单选：获取规则 / 消费规则 |
| 事件类型 | 必填 | 下拉单选（见下方说明） |
| 积分值 | 必填 | 整数（获取规则为正数，消费规则为负数） |
| 限制类型 | 必填 | 下拉单选：不限/每天/每周/每月/总次数 |
| 限制次数 | 条件必填 | 限制类型非"不限"时必填，正整数 |
| 积分有效天数 | 必填 | 正整数，-1表示永久有效 |
| 条件配置 | 非必填 | JSON配置额外触发条件（见下说明） |
| 规则说明 | 非必填 | 最长500字符，展示给用户的规则描述 |
| 排序号 | 必填 | 整数 |

**事件类型枚举：**

| 事件类型值 | 说明 | 典型积分值 | 典型限制 |
|-----------|------|------------|----------|
| 1 - 注册 | 新用户注册完成 | +100 | 总次数=1 |
| 2 - 签到 | 每日签到 | +10 | 每天=1 |
| 3 - 消费 | 下单支付成功（按金额比例） | 按比例 | 不限 |
| 4 - 分享 | 分享产品/活动 | +5 | 每天=5 |
| 5 - 评价 | 完成订单评价 | +20 | 每订单=1 |
| 6 - 积分兑换 | 兑换消耗积分 | -N（兑换品面值） | 由兑换品配置决定 |
| 7 - 积分过期 | 定时扣减（负向） | -N | 定时任务处理 |

**条件配置 JSON 示例（event_type=3消费时）：**
```json
{
  "min_order_amount": 100,
  "point_ratio": 1,
  "ratio_base": 1,
  "exclude_coupon_amount": true
}
```
说明：min_order_amount=最低消费金额触发；point_ratio=每ratio_base元获得的积分数；exclude_coupon_amount=是否剔除优惠券抵扣金额后计算。

**连续签到配置（event_type=2时，condition_config示例）：**
```json
{
  "base_point": 10,
  "continuous_bonus": [
    {"days": 7, "bonus": 20},
    {"days": 30, "bonus": 100}
  ]
}
```

**后端校验：**
- 规则编码不允许重复；
- 已有积分记录关联的规则，不允许删除（提示先禁用）；
- 禁用规则后，该规则的触发事件不再产生积分，已有积分记录不受影响；

**入库（mkt_point_rule 表）：** 所有配置字段，status 默认1（启用）。

---

### 1.3 积分发放逻辑

> 积分发放由后端事件触发，以下描述后端处理流程，前台页面「积分发放」仅用于管理员手动发放。

#### 事件触发发放（系统自动）

**通用流程（所有事件类型）：**
1. 业务模块发布事件消息至 MQ（如：注册成功后发布 USER_REGISTER 事件）；
2. 积分服务消费消息，根据 event_type 查询对应启用的规则（mkt_point_rule）；
3. 校验限制次数：查询 mkt_point_record 中该用户、该规则当日/周/月的记录数，是否超限；
4. 计算积分值：
   - 固定积分：直接取 point_value；
   - 消费比例：order_amount * (point_ratio / ratio_base)，向下取整；
   - 连续签到：基础积分 + 连续天数奖励；
5. 执行发放：
   - 插入 mkt_point_record 记录（change_type=1增加）；
   - UPDATE mkt_user_point SET available_point += N, total_point += N WHERE user_id = ?（使用数据库行锁）；
   - 若 valid_days != -1，计算 valid_end_time = NOW() + valid_days天；
6. 发送站内消息：「您获得了X积分，来源：[规则说明]」；
7. 检查是否需要更新积分等级（total_point 变化后重新判断等级阈值）；

**消费积分规则（event_type=3）特殊处理：**
- 订单完成（非支付时）才发放；
- 退款时：冻结该订单赠送的积分（扣减 available_point，增加 frozen_point），退款完成确认后执行扣减（冻结→过期）；

#### 手动批量发放（管理后台）

菜单：营销管理 → 积分管理 → 积分发放

**操作步骤：**
1. 点击「手动发放」按钮，弹出发放表单；
2. 填写：
   - 发放对象：输入用户ID（逗号分隔）或上传 Excel；
   - 积分数量：正整数（每人发放的积分数）；
   - 发放原因：必填，最长100字符（作为备注记录到 mkt_point_record.remark）；
   - 有效天数：正整数，-1永久有效；
3. 预览：展示将要发放的用户数量和总积分；
4. 提交：通过 MQ 异步批量发放，任务记录写入发放任务表；
5. 进度展示：列表页显示发放任务状态（进行中/已完成）和成功/失败数；

---

### 1.4 积分冻结与过期

#### 积分冻结（业务触发）

**触发场景：**
- 订单申请退款：冻结该订单赠送的积分；
- 风险账号：管理员手动冻结；

**冻结操作（后端）：**
1. 查询要冻结的 mkt_point_record 记录（通过 biz_id=order_id 查询）；
2. UPDATE mkt_user_point SET available_point -= N, frozen_point += N WHERE user_id = ?；
3. 更新 mkt_point_record.status = 4（已冻结）；

**解冻（退款取消/订单确认完成）：**
- 退款取消：available_point += N，frozen_point -= N，status=1（有效）；
- 退款完成：frozen_point -= N，expire_point += N，status=3（已过期），这部分积分不返还；

#### 积分过期定时任务

**执行时间：** 每天凌晨2:00

**执行逻辑：**
1. 查询 mkt_point_record 表，找出 valid_end_time <= 当前日期 且 status=1（有效）的记录；
2. 按 user_id 分组汇总需要过期的积分总量；
3. 对每个用户：
   - 先进先出原则（最早的记录先过期）；
   - UPDATE mkt_user_point SET available_point -= N, expire_point += N；
   - 更新对应 mkt_point_record.status = 3（已过期）；
4. 发送过期提醒通知；

**过期提醒（每天10:00执行）：**
- 查询7天内即将过期的积分记录（按 user_id 汇总）；
- 发送站内消息：「您有X积分将于YYYY-MM-DD过期，请尽快使用」；
- 过期前1天再次提醒；

---

### 1.5 积分商城管理（积分兑换）

**菜单：营销管理 → 积分管理 → 积分兑换**

列表页展示：兑换品图片、名称、类型、所需积分、总库存、剩余库存、兑换次数、状态、排序、操作（编辑/上下架/删除）。

#### 新增兑换品

点击「新增兑换品」按钮，弹出配置表单：

| 字段 | 是否必填 | 校验规则 |
|------|----------|----------|
| 兑换品名称 | 必填 | 2-100字符 |
| 兑换品类型 | 必填 | 单选：实物/优惠券/话费/现金红包 |
| 兑换品图片 | 必填 | JPG/PNG，不超过2MB |
| 所需积分 | 必填 | 正整数 |
| 总库存 | 必填 | 正整数，-1不限（虚拟商品通常不限） |
| 每人限兑次数 | 必填 | 正整数，-1不限 |
| 上架时间 | 非必填 | 留空立即上架，填写则定时上架 |
| 下架时间 | 非必填 | 留空永久上架 |
| 兑换说明 | 非必填 | 最长500字符 |
| 排序号 | 必填 | 整数 |

**兑换品类型额外配置：**

| 类型 | 额外字段 |
|------|---------|
| 实物 | 需填写重量（用于物流），是否需要收货地址（必选yes） |
| 优惠券 | 选择已有优惠券ID，兑换成功自动发放该优惠券给用户 |
| 话费 | 填写充值面额（10/30/50/100元），需对接话费充值API |
| 现金红包 | 填写红包金额，需对接微信/支付宝红包接口 |

**后端校验：**
- 所需积分须 > 0；
- 优惠券类型：选择的优惠券须处于有效状态；
- 实物类型：总库存不可为-1（必须有限量）；

**入库（mkt_point_exchange 表）：** status 初始0（下架），remain_stock = total_stock，exchange_count=0。

---

### 1.6 积分兑换流程（C端，后端实现参考）

1. C 端用户浏览积分商城（查询 status=1 且 remain_stock>0 或 remain_stock=-1 的兑换品）；
2. 用户选择兑换品，点击「立即兑换」：
3. 后端校验（串行）：
   - 用户 available_point >= 所需积分；
   - remain_stock > 0 或 remain_stock=-1；
   - 用户兑换次数 < limit_count（-1则不限）；
   - 实物商品：用户必须有收货地址；
4. 使用 Redis 分布式锁（key=`point_exchange:{exchange_id}`），防止并发超兑；
5. 扣减积分：
   - UPDATE mkt_user_point SET available_point -= N, used_point += N WHERE user_id = ?；
   - 插入 mkt_point_record（change_type=2减少，event_type=6兑换）；
6. 创建兑换记录（mkt_point_exchange_record）：status=1（待发货/待处理）；
7. 更新库存：remain_stock -= 1（不限量不更新），exchange_count += 1；
8. 发货处理：
   - **虚拟商品（优惠券/话费/现金）：** 系统自动异步处理，调用对应发放接口，status=3（已完成）；
   - **实物商品：** 运营人员在后台填写快递公司和快递单号后，status=2（已发货），发送发货通知；
9. 用户确认收货（点击确认 或 发货后7天自动确认）→ status=3（已完成）；

#### 运营后台处理实物兑换

**菜单：积分管理 → 兑换记录**

列表展示：用户名/ID、兑换品名称、所需积分、数量、收货地址、状态（待发货/已发货/已完成/已取消）、兑换时间、操作（发货/查看）。

筛选：兑换品类型、状态、时间范围。

**发货操作：** 点击「发货」按钮，弹出填写快递公司（下拉选择）和快递单号（必填）的弹窗，确认提交后：
- express_company 和 express_no 写入 mkt_point_exchange_record；
- status=2（已发货）；
- 发送发货通知给用户（含快递信息）；

---

### 1.7 积分明细查询

**菜单：营销管理 → 积分管理 → 积分明细**

**功能说明：** 管理员查询所有用户的积分变动明细。

列表字段：用户ID/手机号、规则名称/事件类型、变动类型（增加/减少/冻结/解冻/过期）、变动积分、变动前积分、变动后积分、积分来源（关联业务信息）、生效时间、失效时间、记录时间。

筛选：用户ID或手机号、事件类型、变动类型、时间范围。

支持导出 Excel。

**同时提供用户积分账户查询：**
- 查看某用户的总积分、可用积分、已使用积分、冻结积分、已过期积分；
- 展示该用户的积分等级和等级权益；
- 管理员可「手动调整积分」（加减积分，须填写原因，记录到 mkt_point_record，remark注明操作人和原因）；

---

### 1.8 积分等级体系

**等级划分（基于 total_point 累计积分）：**

| 等级 | 等级名称 | 积分范围 | 权益 |
|------|----------|----------|------|
| 1 | 普通会员 | 0-999 | 基础积分获取倍率x1 |
| 2 | 银卡会员 | 1000-4999 | 积分获取x1.2，专属优惠券 |
| 3 | 金卡会员 | 5000-19999 | 积分获取x1.5，优先客服，生日礼包 |
| 4 | 钻石会员 | 20000+ | 积分获取x2，专属客服，年度大礼包 |

**等级更新逻辑（定时任务，每天凌晨0:00执行）：**
1. 查询所有用户的 mkt_user_point.total_point；
2. 根据等级阈值重新计算等级；
3. 等级只升不降（level 只允许增大）；
4. 等级变化时发送恭喜升级通知；

**等级影响积分获取倍率：**
- 发放积分时，查询用户当前 level；
- 基础积分 × 对应倍率（向下取整）再入库；

---

### 1.9 接口列表（积分模块）

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/mkt/point/rule/page | GET | 规则列表 |
| /admin-api/mkt/point/rule/get/{id} | GET | 规则详情 |
| /admin-api/mkt/point/rule/create | POST | 新增规则 |
| /admin-api/mkt/point/rule/update | PUT | 编辑规则 |
| /admin-api/mkt/point/rule/delete | DELETE | 删除规则 |
| /admin-api/mkt/point/rule/update-status | PUT | 启用/禁用 |
| /admin-api/mkt/point/manual-give | POST | 手动发放积分 |
| /admin-api/mkt/point/exchange/page | GET | 兑换品列表 |
| /admin-api/mkt/point/exchange/get/{id} | GET | 兑换品详情 |
| /admin-api/mkt/point/exchange/create | POST | 新增兑换品 |
| /admin-api/mkt/point/exchange/update | PUT | 编辑兑换品 |
| /admin-api/mkt/point/exchange/delete | DELETE | 删除兑换品 |
| /admin-api/mkt/point/exchange/update-status | PUT | 上下架 |
| /admin-api/mkt/point/exchange-record/page | GET | 兑换记录列表 |
| /admin-api/mkt/point/exchange-record/deliver | POST | 发货（填写快递信息） |
| /admin-api/mkt/point/exchange-record/complete | POST | 确认完成 |
| /admin-api/mkt/point/record/page | GET | 积分明细查询 |
| /admin-api/mkt/point/record/export | GET | 导出明细 |
| /admin-api/mkt/point/user/page | GET | 用户积分账户列表 |
| /admin-api/mkt/point/user/get/{userId} | GET | 用户积分详情 |
| /admin-api/mkt/point/user/adjust | POST | 手动调整积分 |
| /admin-api/mkt/point/upload-image | POST | 上传兑换品图片 |

权限标识：mkt:point:rule / mkt:point:exchange / mkt:point:user / mkt:point:adjust / mkt:point:exchange-record

---

## 二、数据统计模块

### 2.1 实时看板

**菜单：营销管理 → 数据统计 → 实时看板**

页面布局：顶部日期选择器（支持：今日/昨日/近7天/近30天/自定义），下方指标卡区域 + 趋势图区域。

#### 今日概览指标卡（实时刷新，每5分钟自动刷新页面数据）

每个指标卡展示：当前值 + 对比昨日同时段的环比变化（↑X% 绿色 / ↓X% 红色）

指标卡列表（共10个）：

| 指标名称 | 说明 | 数据来源 |
|----------|------|----------|
| 今日新增用户 | 注册用户数 | Redis 实时计数 |
| 今日活跃用户 | 登录或有操作的用户数 | Redis 实时计数 |
| 今日订单数 | 提交的订单总数 | Redis 实时计数 |
| 今日支付金额 | 支付成功的订单总额 | Redis 实时计数 |
| 今日支付订单数 | 支付成功的订单数 | Redis 实时计数 |
| 今日PV | 页面浏览总次数 | Redis 实时计数 |
| 今日UV | 独立访客数（按用户ID去重） | Redis HyperLogLog |
| 转化率 | 支付订单数 / UV | 计算值 |
| 客单价 | 支付金额 / 支付订单数 | 计算值 |
| 退款率 | 退款订单数 / 支付订单数 | 计算值 |

**累计数据区（永久累计，读取 stat_daily_overview 汇总）：**
- 累计用户数、累计订单数、累计交易金额、累计发放优惠券、累计发放积分；

#### 趋势图（ECharts，可切换近7天/近30天）

- 用户趋势折线图：新增用户、活跃用户（双折线）；
- 订单趋势折线图：订单数（左轴）、支付金额（右轴，双Y轴）；
- 流量趋势折线图：PV、UV（双折线）；

#### 数据来源与更新机制

**实时数据（Redis）：**
- 使用 Redis String（incr）存储各指标当日计数；
- Key 规则：`stat:{date}:{metric}`，如 `stat:20260219:pay_amount`；
- 每天0点自动重置（定时任务）；
- 实时看板接口直接读 Redis；

**T+1历史数据（MySQL）：**
- 每天凌晨3:00执行定时任务；
- 汇总昨日所有 Redis 数据写入 stat_daily_overview 表；
- 历史查询（近7天/近30天）读 MySQL；

---

### 2.2 访问统计（UV/PV）

**菜单：营销管理 → 数据统计 → 访问统计**

**埋点设计（C端）：**
- 每次页面访问（PV）：上报 page_url、user_id（可选）、session_id、来源渠道（utm_source等）；
- UV：使用 Redis HyperLogLog（PFADD）按日统计，误差率约0.81%，满足业务需求；
- 后端接收埋点数据，写入 stat_page_visit_log 表（user_id, page_url, session_id, channel, device_type, os, browser, province, city, create_time）；

**统计页面展示：**

| 统计维度 | 展示方式 |
|----------|----------|
| PV/UV趋势 | 折线图（按天），支持日期范围筛选 |
| 热门页面排行 | 表格（页面名称、PV数、UV数、平均停留时长），Top20 |
| 设备类型分布 | 饼图（PC/手机/平板） |
| 操作系统分布 | 饼图（iOS/Android/Windows/Mac） |
| 地域分布 | 中国地图热力图 + Top10省份列表 |
| 来源渠道分析 | 饼图（直接访问/微信分享/短信链接/推送通知等） |

---

### 2.3 转化漏斗分析

**菜单：营销管理 → 数据统计 → 转化漏斗**

**购买转化漏斗（标准漏斗，固定5个步骤）：**

| 步骤 | 统计说明 |
|------|----------|
| ① 访问首页 | UV 数（使用 HyperLogLog） |
| ② 浏览产品 | 进入过任意产品详情页的 UV |
| ③ 加入购物车 | 执行过加购操作的 UV |
| ④ 提交订单 | 创建过订单的 UV |
| ⑤ 完成支付 | 支付成功的 UV |

**页面展示：**
- ECharts 漏斗图，每个步骤显示：用户数、相对上一步的转化率、相对第一步的整体转化率；
- 支持日期范围筛选；
- 支持对比功能（选择两个时间段对比漏斗数据）；
- 「差异分析」：高亮显示各步骤的环比变化；

**数据采集：**
- 各步骤数据来源于 stat_page_visit_log 表和订单表；
- 日报任务（凌晨3:00）计算各步骤数据并写入 stat_funnel_daily 表；

---

### 2.4 销售统计

**菜单：营销管理 → 数据统计 → 销售统计**

**筛选条件：** 时间范围（日期选择器）、产品分类（多选）、渠道（多选）。

**核心统计指标（卡片展示）：**
- 保费总额（支付金额）、订单总数、支付转化率、客单价、退款金额、退款率；

**产品维度分析：**
- 产品销量排行表（Top50）：产品名称、所属分类、浏览量、加购量、成单量、支付金额、转化率；
- 支持按上述字段点击表头排序；
- 支持导出 Excel；

**时间维度趋势：**
- 折线图：订单数 + 支付金额双折线，X轴为日期；
- 可切换查看：日/周/月维度汇总；

**分类维度分析：**
- 环形图：各产品分类的保费占比；
- 柱状图：各分类的订单数对比；

**数据来源：**
- 核心数据从订单表（insurance_order）实时聚合查询；
- 较大时间范围查询（如近90天）从 stat_product_analysis 汇总表读取；

---

### 2.5 核心数据表设计

#### stat_daily_overview（每日汇总）

```sql
CREATE TABLE `stat_daily_overview` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `stat_date` date NOT NULL COMMENT '统计日期',
  `new_user_count` int NOT NULL DEFAULT '0' COMMENT '新增用户数',
  `active_user_count` int NOT NULL DEFAULT '0' COMMENT '活跃用户数',
  `order_count` int NOT NULL DEFAULT '0' COMMENT '订单数',
  `order_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '订单总额',
  `pay_order_count` int NOT NULL DEFAULT '0' COMMENT '支付订单数',
  `pay_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '支付金额',
  `refund_count` int NOT NULL DEFAULT '0' COMMENT '退款订单数',
  `refund_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '退款金额',
  `pv` int NOT NULL DEFAULT '0' COMMENT '页面浏览量',
  `uv` int NOT NULL DEFAULT '0' COMMENT '独立访客数',
  `coupon_receive_count` int NOT NULL DEFAULT '0' COMMENT '优惠券领取数',
  `coupon_use_count` int NOT NULL DEFAULT '0' COMMENT '优惠券使用数',
  `point_give_count` int NOT NULL DEFAULT '0' COMMENT '积分发放数',
  `point_use_count` int NOT NULL DEFAULT '0' COMMENT '积分消费数',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_stat_date` (`stat_date`)
) COMMENT='每日数据概览汇总';
```

#### mkt_user_point（用户积分账户）

```sql
CREATE TABLE `mkt_user_point` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL UNIQUE,
  `total_point` int NOT NULL DEFAULT '0' COMMENT '累计获得积分',
  `available_point` int NOT NULL DEFAULT '0' COMMENT '可用积分',
  `used_point` int NOT NULL DEFAULT '0' COMMENT '已使用积分',
  `frozen_point` int NOT NULL DEFAULT '0' COMMENT '冻结积分',
  `expire_point` int NOT NULL DEFAULT '0' COMMENT '已过期积分',
  `level` tinyint NOT NULL DEFAULT '1' COMMENT '1普通2银卡3金卡4钻石',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) COMMENT='用户积分账户';
```

#### mkt_point_record（积分变动明细）

```sql
CREATE TABLE `mkt_point_record` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `rule_id` bigint DEFAULT NULL COMMENT '积分规则ID',
  `change_type` tinyint NOT NULL COMMENT '1增加2减少3冻结4解冻5过期',
  `change_point` int NOT NULL COMMENT '变动积分(可负)',
  `before_point` int NOT NULL COMMENT '变动前可用积分',
  `after_point` int NOT NULL COMMENT '变动后可用积分',
  `event_type` tinyint NOT NULL COMMENT '事件类型',
  `biz_id` bigint DEFAULT NULL COMMENT '业务ID(订单/活动)',
  `biz_type` varchar(50) DEFAULT NULL COMMENT '业务类型',
  `valid_start_time` datetime DEFAULT NULL COMMENT '积分生效时间',
  `valid_end_time` datetime DEFAULT NULL COMMENT '积分失效时间',
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '1有效2已使用3已过期4已冻结',
  `remark` varchar(500) DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_status` (`user_id`, `status`),
  KEY `idx_valid_end` (`valid_end_time`, `status`)
) COMMENT='积分变动明细';
```

#### mkt_point_exchange（积分兑换品）

```sql
CREATE TABLE `mkt_point_exchange` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `type` tinyint NOT NULL COMMENT '1实物2优惠券3话费4现金',
  `image` varchar(500) NOT NULL,
  `point_cost` int NOT NULL COMMENT '所需积分',
  `total_stock` int NOT NULL DEFAULT '-1' COMMENT '总库存,-1不限',
  `remain_stock` int NOT NULL DEFAULT '-1' COMMENT '剩余库存',
  `exchange_count` int NOT NULL DEFAULT '0' COMMENT '兑换次数',
  `limit_count` int NOT NULL DEFAULT '-1' COMMENT '每人限兑,-1不限',
  `extra_config` text DEFAULT NULL COMMENT '额外配置JSON',
  `sort_order` int NOT NULL DEFAULT '0',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '0下架1上架',
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `description` text DEFAULT NULL,
  `creator` varchar(64) DEFAULT '',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT '',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint NOT NULL DEFAULT '0',
  `tenant_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) COMMENT='积分兑换品';
```

#### mkt_point_exchange_record（积分兑换记录）

```sql
CREATE TABLE `mkt_point_exchange_record` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `exchange_id` bigint NOT NULL COMMENT '兑换品ID',
  `user_id` bigint NOT NULL,
  `point_cost` int NOT NULL COMMENT '消耗积分',
  `quantity` int NOT NULL DEFAULT '1' COMMENT '兑换数量',
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '1待发货2已发货3已完成4已取消',
  `address_id` bigint DEFAULT NULL COMMENT '收货地址ID',
  `express_company` varchar(50) DEFAULT NULL COMMENT '快递公司',
  `express_no` varchar(50) DEFAULT NULL COMMENT '快递单号',
  `remark` varchar(500) DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_status` (`user_id`, `status`),
  KEY `idx_exchange_status` (`exchange_id`, `status`)
) COMMENT='积分兑换记录';
```

---

### 2.6 接口列表（数据统计模块）

| 接口路径 | 方法 | 说明 |
|----------|------|------|
| /admin-api/stat/overview/realtime | GET | 实时看板数据（读Redis） |
| /admin-api/stat/overview/daily | GET | 日报数据（读MySQL） |
| /admin-api/stat/overview/trend | GET | 趋势图数据 |
| /admin-api/stat/visit/trend | GET | PV/UV趋势 |
| /admin-api/stat/visit/page-rank | GET | 热门页面排行 |
| /admin-api/stat/visit/device | GET | 设备分布 |
| /admin-api/stat/visit/region | GET | 地域分布 |
| /admin-api/stat/visit/channel | GET | 渠道分布 |
| /admin-api/stat/funnel/purchase | GET | 购买转化漏斗 |
| /admin-api/stat/funnel/compare | POST | 漏斗对比 |
| /admin-api/stat/sale/overview | GET | 销售汇总 |
| /admin-api/stat/sale/trend | GET | 销售趋势 |
| /admin-api/stat/sale/product-rank | GET | 产品销量排行 |
| /admin-api/stat/sale/category | GET | 分类分析 |
| /admin-api/stat/export | POST | 导出报表（异步生成，返回下载链接） |

权限标识：stat:read / stat:export

---

## 三、定时任务汇总

| 任务名称 | Cron表达式 | 功能说明 |
|---------|-----------|----------|
| Banner自动上下架 | 0 */5 * * * ? | 检查start_time/end_time自动更新status |
| 文章定时发布 | 0 * * * * ? | 检查publish_time到期自动发布 |
| 活动自动生效/结束 | 0 * * * * ? | 检查活动时间自动切换status |
| 优惠券锁定超时解锁 | 0 * * * * ? | 15分钟未支付自动解锁已锁定的券 |
| 积分过期处理 | 0 0 2 * * ? | 每天凌晨2点处理到期积分 |
| 积分过期提醒 | 0 0 10 * * ? | 每天10点发送7天内过期提醒 |
| 积分等级更新 | 0 0 0 * * ? | 每天0点重新计算所有用户等级 |
| 统计数据T+1汇总 | 0 0 3 * * ? | 每天凌晨3点汇总昨日数据至stat表 |
| 优惠券过期提醒 | 0 0 10 * * ? | 每天10点发送3天内过期优惠券提醒 |
| Redis统计同步MySQL | 0 0 * * * ? | 每小时同步点击量/播放量/浏览量至MySQL |
| 热门文章标记 | 0 0 4 * * ? | 每天凌晨4点根据浏览量标记热门文章 |

---

*文档完结。共分上、中、下三篇，覆盖阶段3-PC管理后台-营销管理模块全部功能点。*

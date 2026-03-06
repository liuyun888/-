# 营销中台数据库设计说明
## `intermediary-module-ins-marketing` — `db_ins_marketing`

---

## 一、文件清单

| 文件 | 覆盖模块 | 表数量 |
|------|----------|--------|
| `ins_marketing_01_content.sql` | 内容管理（Banner/文章/知识库/视频/文案库） | 9张 |
| `ins_marketing_02_material.sql` | 营销素材（海报模板/用户海报/计划书/邀请） | 6张 |
| `ins_marketing_03_activity.sql` | 活动管理（营销活动/B端活动/团队） | 6张 |
| `ins_marketing_04_coupon.sql` | 优惠券（模板/用户券/兑换码/发放任务） | 5张 |
| `ins_marketing_05_point.sql` | 积分管理（规则/账户/明细/等级/商城/兑换） | 7张 |
| `ins_marketing_06_training.sql` | 培训管理（立项/计划/课程/考试/证书） | 12张 |
| `ins_marketing_07_statistics.sql` | 数据统计（访问/销售/营销/导出） | 6张 |

**合计：51张表**

---

## 二、表前缀规范

| 子模块 | 表前缀 | 说明 |
|--------|--------|------|
| 内容管理 | `ins_mkt_cms_` | CMS内容 |
| 营销素材 | `ins_mkt_material_` | 海报/计划书/邀请 |
| 活动管理 | `ins_mkt_act_` | 营销活动/B端活动 |
| 优惠券 | `ins_mkt_coupon_` | 优惠券全链路 |
| 积分 | `ins_mkt_point_` | 积分全链路 |
| 培训 | `ins_mkt_train_` | 培训全链路 |
| 统计 | `ins_mkt_stat_` | 数据统计报表 |

---

## 三、核心设计说明

### 3.1 标准审计字段
所有业务主表均包含 yudao-cloud 框架标准审计字段：
```sql
creator     varchar(64)  -- 创建者(登录用户名)
create_time datetime     -- 创建时间
updater     varchar(64)  -- 更新者
update_time datetime     -- 更新时间(ON UPDATE)
deleted     tinyint(1)   -- 逻辑删除:0-否 1-是
tenant_id   bigint       -- 租户ID
```

### 3.2 双轨活动体系
- **C端营销活动**（`ins_mkt_act_activity`）：面向消费者，类型涵盖新人礼/满减/折扣/赠品/拼团/秒杀/积分兑换，有完整的审核状态机
- **B端业务员活动**（`ins_mkt_act_agent_activity`）：面向代理人，类型为业绩冲刺/拉新/产品促销/节日，配合奖励配置表和进度跟踪表

### 3.3 积分防并发设计
积分变动通过 `ins_mkt_point_account` 行锁保证原子性：
```sql
UPDATE ins_mkt_point_account SET available_point = available_point + N 
WHERE user_id = ? AND tenant_id = ?
```
Redis 分布式锁用于积分兑换防超兑（key: `point_exchange:{exchange_id}`）

### 3.4 优惠券防超发
- `ins_mkt_coupon.receive_count` 通过乐观锁（版本号）或数据库行锁更新
- 下单锁定（status=4）：下单时锁定，15分钟未支付定时任务自动解锁
- 兑换码（`ins_mkt_coupon_code`）批量生成通过 MQ 异步处理

### 3.5 计划书双类型支持
`ins_mkt_material_proposal_record` 通过 `ins_type` 字段区分非车险(1)/寿险(2)，`products` 字段存储 JSON 格式产品方案，`cash_value_table` 字段专用于寿险现金价值表

### 3.6 知识库版本控制
每次保存 `ins_mkt_cms_knowledge` 时，同步向 `ins_mkt_cms_knowledge_version` 写入快照，`version` 字段自增，支持历史版本回滚

### 3.7 学习记录断点续播
`ins_mkt_train_study_record.last_position` 记录秒级播放位置，支持视频/音频断点续播；`study_progress` 记录0-100进度，课程整体进度由各章节进度聚合计算

---

## 四、定时任务对应表操作

| 定时任务 | Cron | 操作表 |
|---------|------|--------|
| Banner自动上下架 | 0 */5 * * * ? | `ins_mkt_cms_banner` |
| 文章定时发布 | 0 * * * * ? | `ins_mkt_cms_article` |
| 活动自动生效/结束 | 0 * * * * ? | `ins_mkt_act_activity` |
| 优惠券锁定超时解锁 | 0 * * * * ? | `ins_mkt_coupon_user` (status=4→1) |
| 积分过期处理 | 0 0 2 * * ? | `ins_mkt_point_record`, `ins_mkt_point_account` |
| 积分等级更新 | 0 0 0 * * ? | `ins_mkt_point_account.level` |
| 培训立项自动激活/结束 | 0 0 0 * * ? | `ins_mkt_train_project` |
| 培训计划状态切换 | 0 * * * * ? | `ins_mkt_train_plan` |
| Redis统计同步MySQL | 0 0 * * * ? | `ins_mkt_cms_banner.click_count` 等 |
| 统计T+1汇总 | 0 0 3 * * ? | `ins_mkt_stat_*_daily` |
| B端活动进度更新 | 事件驱动MQ | `ins_mkt_act_agent_user.current_value` |

---

## 五、执行顺序

```bash
# 建议按以下顺序执行，避免外键依赖问题
mysql -u root -p db_ins_marketing < ins_marketing_01_content.sql
mysql -u root -p db_ins_marketing < ins_marketing_02_material.sql
mysql -u root -p db_ins_marketing < ins_marketing_03_activity.sql
mysql -u root -p db_ins_marketing < ins_marketing_04_coupon.sql
mysql -u root -p db_ins_marketing < ins_marketing_05_point.sql
mysql -u root -p db_ins_marketing < ins_marketing_06_training.sql
mysql -u root -p db_ins_marketing < ins_marketing_07_statistics.sql
```

> **注意**：本设计采用逻辑外键（应用层保证引用完整性），数据库层不设置物理 FOREIGN KEY 约束，符合 yudao-cloud 框架和高并发互联网场景的最佳实践。

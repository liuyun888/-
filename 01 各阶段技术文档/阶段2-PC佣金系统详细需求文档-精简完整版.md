# 阶段2-PC佣金系统详细需求文档(精简完整版)

## 文档版本信息
- **版本号**: V2.0  
- **编制日期**: 2026-02-15
- **技术栈**: RuoYi-Vue-Pro + MySQL 8.0 + Redis
- **开发周期**: 2周
- **优先级**: P0 (核心功能)

---

## 一、系统概述

### 1.1 业务背景

PC佣金系统是保险中介平台的核心财务模块,负责管理保险业务员的佣金计算、审核、发放全流程。系统需支持复杂的多级分润逻辑、合规审计要求以及与上游保司的自动对账能力。

**行业痛点**:
1. **计算复杂性**: 佣金涉及首年、续期、管理津贴等多种类型,不同险种职级规则各异
2. **分润层级深**: 保险中介普遍存在3-5级团队结构,上级从下级业绩获得管理津贴
3. **合规要求严**: "报行合一"政策要求佣金率必须与监管报备费率一致
4. **对账工作量大**: 每月需与多家保司对账,人工效率低易出错
5. **时效性要求高**: 业务员关注发放时效,延迟影响士气和留存

### 1.2 核心目标

1. **自动化**: 实现佣金从保单绑定到发放的全自动化流程
2. **准确性**: 确保计算精确无误,支持复杂基本法规则
3. **可追溯**: 所有佣金变更必须有完整审计日志
4. **合规性**: 满足"报行合一"要求,佣金率不超监管上限
5. **实时性**: 保单承保后实时生成佣金,审核通过及时发放

### 1.3 功能模块架构

```
PC佣金系统
├── 基本法配置模块
│   ├── 职级体系管理(职级CRUD、晋升规则、自动评估)
│   ├── 佣金规则配置(规则管理、费率限制、公式引擎、优先级)
│   └── 规则变更审计(历史记录、影响分析)
├── 佣金计算模块
│   ├── 保单佣金绑定(数据同步、归属识别、自动触发)
│   ├── 计算引擎(规则匹配、公式执行、精度控制、批量计算)
│   ├── 分润逻辑(上级查找、管理津贴、多级处理)
│   └── 特殊场景(退保回收、保单变更、跨月分摊)
├── 佣金审核模块
│   ├── 待审核队列(筛选、异常标记、优先级排序)
│   ├── 审核流程(单笔/批量审核、多级审批、意见记录)
│   ├── 驳回处理(原因选择、重新计算、申诉流程)
│   └── 审核分析(效率统计、驳回率分析)
├── 佣金发放模块
│   ├── 发放计划(按周期生成、对象筛选、金额汇总、预审核)
│   ├── 批量发放(银行转账、支付宝/微信、状态更新、失败重试)
│   ├── 发放记录(查询、凭证管理、明细导出)
│   └── 税务处理(个税代扣、申报数据生成)
└── 对账管理模块
    ├── 保司数据导入(Excel导入、API同步、格式校验、日志记录)
    ├── 自动对账(保单号匹配、金额比对、费率核对、异常标记)
    ├── 差异处理(类型分类、原因分析、调整方案、审批流程)
    └── 对账报告(月度总表、异常清单、差异分析)
```

---

## 二、数据库设计

### 2.1 核心表结构

#### 2.1.1 职级表 (sys_agent_rank)

```sql
CREATE TABLE `sys_agent_rank` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `rank_code` varchar(32) NOT NULL COMMENT '职级代码',
  `rank_name` varchar(64) NOT NULL COMMENT '职级名称',
  `rank_level` int(11) NOT NULL COMMENT '职级层级(1-10,数字越大层级越高)',
  `parent_rank_code` varchar(32) DEFAULT NULL COMMENT '上级职级代码',
  `promotion_rules` json DEFAULT NULL COMMENT '晋升规则JSON',
  `status` tinyint(1) DEFAULT '1' COMMENT '状态(0-停用 1-启用)',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rank_code` (`rank_code`)
) ENGINE=InnoDB COMMENT='代理人职级表';
```

#### 2.1.2 佣金规则表 (commission_base_rule)

```sql
CREATE TABLE `commission_base_rule` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `rule_code` varchar(64) NOT NULL COMMENT '规则代码(唯一)',
  `rule_name` varchar(128) NOT NULL COMMENT '规则名称',
  `rule_type` varchar(32) NOT NULL COMMENT '规则类型(FYC,RYC,OVERRIDE,BONUS)',
  `rank_code` varchar(32) DEFAULT NULL COMMENT '适用职级(NULL表示全部)',
  `product_category` varchar(32) DEFAULT NULL COMMENT '适用险种(NULL表示全部)',
  `calc_formula` text NOT NULL COMMENT '计算公式(Groovy脚本)',
  `rate_config` json DEFAULT NULL COMMENT '费率配置JSON',
  `effective_date` date NOT NULL COMMENT '生效日期',
  `expire_date` date DEFAULT NULL COMMENT '失效日期',
  `priority` int(11) DEFAULT '0' COMMENT '优先级(数字越大越高)',
  `status` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rule_code` (`rule_code`)
) ENGINE=InnoDB COMMENT='佣金基本法规则表';
```

#### 2.1.3 佣金记录表 (commission_record)

```sql
CREATE TABLE `commission_record` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `commission_no` varchar(64) NOT NULL COMMENT '佣金单号',
  `policy_id` bigint(20) NOT NULL COMMENT '关联保单ID',
  `policy_no` varchar(128) NOT NULL COMMENT '保单号',
  `agent_id` bigint(20) NOT NULL COMMENT '业务员ID',
  `agent_rank` varchar(32) NOT NULL COMMENT '业务员职级',
  `product_category` varchar(32) NOT NULL COMMENT '险种分类',
  `insurance_company` varchar(128) NOT NULL COMMENT '保险公司',
  `premium` decimal(12,2) NOT NULL COMMENT '保费(元)',
  `commission_type` varchar(32) NOT NULL COMMENT '佣金类型',
  `commission_rate` decimal(6,4) NOT NULL COMMENT '佣金费率',
  `commission_amount` decimal(12,2) NOT NULL COMMENT '佣金金额',
  `settle_period` varchar(32) NOT NULL COMMENT '结算周期',
  `status` varchar(32) NOT NULL DEFAULT 'PENDING' COMMENT '状态',
  `pay_batch_no` varchar(64) DEFAULT NULL COMMENT '发放批次号',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_commission_no` (`commission_no`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_agent_id` (`agent_id`)
) ENGINE=InnoDB COMMENT='佣金记录主表';
```

#### 2.1.4 佣金分润表 (commission_split)

```sql
CREATE TABLE `commission_split` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `source_commission_id` bigint(20) NOT NULL COMMENT '源佣金ID',
  `target_commission_id` bigint(20) NOT NULL COMMENT '目标佣金ID',
  `source_agent_id` bigint(20) NOT NULL COMMENT '源代理人',
  `target_agent_id` bigint(20) NOT NULL COMMENT '目标代理人(上级)',
  `split_type` varchar(32) NOT NULL COMMENT '分润类型',
  `split_rate` decimal(6,4) NOT NULL COMMENT '分润比例',
  `split_amount` decimal(12,2) NOT NULL COMMENT '分润金额',
  `hierarchy_level` int(11) NOT NULL COMMENT '层级差(1-直接,2-隔代)',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB COMMENT='佣金分润表';
```

#### 2.1.5 发放批次表 (commission_pay_batch)

```sql
CREATE TABLE `commission_pay_batch` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `batch_no` varchar(64) NOT NULL COMMENT '批次号',
  `settle_period` varchar(32) NOT NULL COMMENT '结算周期',
  `total_agents` int(11) NOT NULL COMMENT '发放人数',
  `total_amount` decimal(14,2) NOT NULL COMMENT '发放总金额',
  `pay_channel` varchar(32) NOT NULL COMMENT '发放渠道',
  `status` varchar(32) NOT NULL DEFAULT 'DRAFT' COMMENT '状态',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`)
) ENGINE=InnoDB COMMENT='发放批次表';
```

#### 2.1.6 对账结算表 (insurance_settlement)

```sql
CREATE TABLE `insurance_settlement` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `settlement_no` varchar(64) NOT NULL COMMENT '结算单号',
  `insurance_company` varchar(128) NOT NULL COMMENT '保险公司',
  `policy_no` varchar(128) NOT NULL COMMENT '保单号',
  `premium` decimal(12,2) NOT NULL COMMENT '保费',
  `commission_amount` decimal(12,2) NOT NULL COMMENT '佣金金额',
  `match_status` varchar(32) DEFAULT 'UNMATCHED' COMMENT '匹配状态',
  `local_commission_id` bigint(20) DEFAULT NULL COMMENT '本地佣金ID',
  `diff_type` varchar(64) DEFAULT NULL COMMENT '差异类型',
  `diff_amount` decimal(12,2) DEFAULT NULL COMMENT '差异金额',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB COMMENT='保司结算表';
```

---

## 三、核心业务逻辑详解

### 3.1 职级与规则管理

#### 3.1.1 职级体系业务逻辑

**职级层级管理**:
- 采用树形结构,支持多级嵌套(建议最多10级)
- 职级代码唯一且不可修改,仅可停用
- rank_level数字越大表示层级越高,用于分润判断
- 同层级可有多个并列职级(如高级主管、资深主管)

**晋升规则配置**:
```json
{
  "fyp_min": 100000,        // 最低首年保费要求(元)
  "team_size": 3,           // 直属下级人数要求
  "active_months": 6,       // 连续活跃月数要求
  "training_completed": true // 是否完成培训
}
```

**晋升评估流程**:
1. 系统每月1号凌晨自动执行评估任务
2. 扫描所有业务员,统计上月业绩数据
3. 判断是否满足下一职级条件
4. 生成待审批晋升申请列表
5. 发送通知给业务员和上级

**职级变更生效规则**:
- 自动晋升: 审批通过后次月1号生效
- 手动晋升: 审批通过后立即生效  
- 降级: 预警期满后次月1号生效

#### 3.1.2 佣金规则配置逻辑

**规则类型定义**:

1. **FYC(首年佣金)**: 保单首年保费的10%-35%,发放时机为承保后次月
2. **RYC(续期佣金)**: 续期保费的3%-10%,逐年递减,客户缴费后次月发放
3. **OVERRIDE(管理津贴)**: 下级佣金的3%-15%,与下级佣金同步发放
4. **BONUS(奖金)**: 基于业绩达成的额外激励,固定或阶梯式金额

**规则匹配优先级**:
1. 筛选生效期内且启用的规则
2. 险种匹配: 精确匹配 > 通配匹配
3. 职级匹配: 精确匹配 > 通配匹配  
4. 按priority降序、create_time降序排序取第一条

**费率配置结构**:
```json
{
  "fyc_rate": 0.25,           // 基础首年费率25%
  "max_rate": 0.30,           // 监管最高费率30%
  "min_premium": 5000,        // 最低保费门槛
  "override_rate": 0.05,      // 管理津贴费率5%
  "override_hierarchy": [     // 分级管理津贴
    {"level": 1, "rate": 0.05},  // 直接上级5%
    {"level": 2, "rate": 0.03},  // 隔代上级3%
    {"level": 3, "rate": 0.01}   // 三级上级1%
  ]
}
```

**计算公式示例**(使用Groovy):
```groovy
// 基础计算
premium * rateConfig.fyc_rate

// 分段计算
if (premium <= 10000) {
    premium * 0.20
} else {
    10000 * 0.20 + (premium - 10000) * 0.15
}

// 职级差异化
switch (agentRank) {
    case 'SALES': premium * 0.20; break
    case 'SUPERVISOR': premium * 0.25; break
    case 'MANAGER': premium * 0.30; break
}
```

**监管合规控制**:
- 费率上限检查: 实际佣金率不得超过max_rate
- 报行合一检查: 实际支付佣金与监管报备费率一致
- 超限自动调整: 超过上限按上限重新计算并记录日志

### 3.2 佣金计算逻辑

#### 3.2.1 保单佣金绑定

**数据同步机制**:
- API实时同步: 监听MQ消息,实时消费保单数据
- 定时批量同步: 每日凌晨2点拉取前一日承保保单
- 双重保障防止佣金遗漏

**业务员归属识别优先级**:
1. 保单明确标记的agent_id
2. 投保人手机号匹配历史客户
3. 推广二维码追踪链接中的agent_id  
4. IP地址地域匹配分配
5. 人工指派(兜底)

**自动触发计算**:
- 实时触发: 保单承保后30秒内
- 批量触发: 每日凌晨3点批处理
- 手动触发: 管理员后台操作

#### 3.2.2 计算引擎核心流程

**规则匹配算法**:
```
1. 筛选条件: 状态=启用 AND 生效日期<=保单日期<失效日期  
             AND (险种=保单险种 OR 险种=NULL)
             AND (职级=业务员职级 OR 职级=NULL)
             AND 佣金类型=当前类型(FYC/RYC)
2. 排序: priority DESC, create_time DESC
3. 取第一条作为匹配规则
```

**公式执行环境**:
```java
Map<String, Object> bindings = new HashMap<>();
bindings.put("premium", policy.getPremium());  // 保费
bindings.put("rateConfig", rule.getRateConfig());  // 费率配置
bindings.put("agentRank", agent.getRankCode());  // 职级
bindings.put("policyYear", calculatePolicyYear());  // 保单年度
bindings.put("paymentPeriod", policy.getPaymentPeriod());  // 缴费年期

// 使用Groovy引擎执行公式
GroovyShell shell = new GroovyShell(new Binding(bindings));
Object result = shell.evaluate(rule.getCalcFormula());
```

**金额精度控制**:
- 所有金额使用BigDecimal,禁止float/double
- 计算过程保留4位小数,最终结果保留2位
- 统一使用RoundingMode.HALF_UP(四舍五入)
- 分摊时用减法消除尾差

#### 3.2.3 分润逻辑处理

**上级关系查找**:
```java
// 递归查找上级链条(最多5级)
List<Long> superiorChain = new ArrayList<>();
Long currentId = agentId;
int level = 0;

while (level < 5) {
    SysAgent current = agentMapper.selectById(currentId);
    if (current == null || current.getParentId() == null) break;
    
    superiorChain.add(current.getParentId());
    currentId = current.getParentId();
    level++;
}
```

**管理津贴计算**:
```java
for (int i = 0; i < superiorChain.size(); i++) {
    Long superiorId = superiorChain.get(i);
    SysAgent superior = agentMapper.selectById(superiorId);
    
    // 检查职级是否满足要求
    JSONObject levelConfig = hierarchyConfig.getJSONObject(i);
    if (!checkRankQualified(superior.getRankCode(), levelConfig.getString("min_rank_code"))) {
        continue;  // 职级不够,跳过
    }
    
    // 计算分润金额
    BigDecimal splitRate = levelConfig.getBigDecimal("rate");
    BigDecimal splitAmount = sourceCommission.getCommissionAmount()
            .multiply(splitRate)
            .setScale(2, RoundingMode.HALF_UP);
    
    // 创建管理津贴佣金记录
    CommissionRecordDO overrideCommission = new CommissionRecordDO();
    overrideCommission.setCommissionType("OVERRIDE");
    overrideCommission.setCommissionAmount(splitAmount);
    // ... 保存
}
```

**特殊场景处理**:
- 跨层级: 中间缺失层级仍按规则向上传递
- 平级无分润: 同职级之间不产生管理津贴
- 离职处理: 上级离职则分润传递给再上级

### 3.3 佣金审核逻辑

#### 3.3.1 待审核队列管理

**多维度筛选**:
- 基础: 状态/时间/险种/职级/金额/保司
- 高级: 异常标记/业务员/结算周期

**异常自动标记**:
```java
// 费率超限
if (actualRate.compareTo(maxRate) > 0) {
    commission.setExceptionType("RATE_EXCEED");
}

// 金额异常大(超保费50%)
if (commissionAmount.compareTo(premium.multiply(0.5)) > 0) {
    commission.setExceptionType("AMOUNT_TOO_LARGE");
}

// 单笔超10万元
if (commissionAmount.compareTo(new BigDecimal("100000")) > 0) {
    commission.setExceptionType("AMOUNT_HUGE");
}
```

**优先级排序**:
1. 异常佣金最优先
2. 大额佣金(>5万)次之
3. 高职级佣金中等
4. 普通佣金最低

#### 3.3.2 审核流程引擎

**单笔审核(乐观锁)**:
```sql
UPDATE commission_record
SET status = 'APPROVED',
    auditor = #{auditor},
    audit_time = NOW()
WHERE id = #{id}
  AND status = 'PENDING'  -- 旧状态作为WHERE条件
  AND deleted = 0
```

**批量审核**:
```java
for (Long id : ids) {
    try {
        approveCommission(id, auditor, remark);
        successCount++;
    } catch (ServiceException e) {
        failCount++;
        failReasons.add("ID" + id + ": " + e.getMessage());
    }
}
```

**多级审批(可选)**:
- ≤1万元: 财务专员审批
- 1万-5万元: 财务主管审批
- >5万元: 财务主管+总经理两级审批

#### 3.3.3 驳回处理机制

**驳回原因分类**:
- 费率错误
- 保单信息错误
- 业务员归属错误
- 分润关系错误
- 重复计算
- 其他原因(需详细说明)

**驳回后处理**:
```java
// 1. 更新状态为REJECTED
commission.setStatus("REJECTED");
commission.setAuditRemark(rejectReason + ": " + rejectDetail);

// 2. 同步驳回关联分润记录
splits.forEach(split -> {
    split.setStatus("REJECTED");
});

// 3. 发送通知
sendNotificationToAgent("您的佣金被驳回,原因: " + rejectReason);
```

**重新计算触发**:
- 删除驳回的佣金记录及分润记录
- 重新触发保单的佣金计算
- 新记录重新进入待审核队列

### 3.4 佣金发放逻辑

#### 3.4.1 发放计划生成

**月度自动任务**:
```java
@Scheduled(cron = "0 0 2 5 * ?")  // 每月5号凌晨2点
public void generateMonthlyPayBatch() {
    String lastMonth = calculateLastMonthPeriod();
    
    // 查询上月已审核未发放佣金
    List<CommissionRecordDO> records = commissionRecordMapper.selectList(
        status='APPROVED' AND settle_period=lastMonth AND pay_batch_no IS NULL
    );
    
    // 按业务员汇总
    Map<Long, List<CommissionRecordDO>> groupByAgent = 
        records.stream().collect(Collectors.groupingBy(CommissionRecordDO::getAgentId));
    
    // 生成批次和明细
    CommissionPayBatchDO batch = createBatch(lastMonth);
    groupByAgent.forEach((agentId, agentRecords) -> {
        createPayDetail(batch, agentId, agentRecords);
    });
}
```

**筛选规则**:
- 状态=已审核
- 结算周期=指定月份
- 未关联发放批次
- 业务员状态=在职
- 不在黑名单

#### 3.4.2 批量发放执行

**银行转账**:
1. 生成Excel批量文件(账号/户名/金额/备注)
2. 财务登录企业网银上传文件
3. 银行执行批量转账
4. 更新发放状态

**支付宝批量打款**:
```java
AlipayFundTransUniTransferRequest request = new AlipayFundTransUniTransferRequest();
JSONArray transferArray = new JSONArray();

details.forEach(detail -> {
    JSONObject transfer = new JSONObject();
    transfer.put("out_biz_no", "PAY_" + detail.getId());
    transfer.put("trans_amount", detail.getPayAmount());
    transfer.put("payee_info", new JSONObject()
        .fluentPut("identity", detail.getAlipayAccount())
        .fluentPut("name", detail.getAgentName()));
    transferArray.add(transfer);
});

AlipayFundTransUniTransferResponse response = alipayClient.execute(request);
```

**微信企业付款**:
```java
details.forEach(detail -> {
    WxEntPayRequest request = new WxEntPayRequest();
    request.setOpenid(detail.getWechatOpenid());
    request.setAmount(detail.getPayAmount().multiply(100).intValue());  // 单位:分
    request.setDescription("佣金发放-" + batchNo);
    
    WxEntPayResult result = wxPayService.getEntPayService().entPay(request);
});
```

**失败重试**:
- 最多重试3次
- 指数退避策略(1分钟、5分钟、15分钟)
- 仍失败则进入人工处理队列

### 3.5 对账管理逻辑

#### 3.5.1 保司数据导入

**Excel批量导入**:
```java
// 1. 解析Excel
Workbook workbook = WorkbookFactory.create(file.getInputStream());
Sheet sheet = workbook.getSheetAt(0);

// 2. 遍历行
for (int i = 1; i <= sheet.getLastRowNum(); i++) {
    Row row = sheet.getRow(i);
    
    // 3. 解析字段
    String policyNo = getCellValue(row.getCell(0));
    BigDecimal premium = new BigDecimal(getCellValue(row.getCell(1)));
    BigDecimal commissionAmount = new BigDecimal(getCellValue(row.getCell(3)));
    
    // 4. 创建结算记录
    InsuranceSettlementDO settlement = new InsuranceSettlementDO();
    settlement.setPolicyNo(policyNo);
    settlement.setPremium(premium);
    settlement.setCommissionAmount(commissionAmount);
    
    // 5. 批量插入
    settlements.add(settlement);
    if (settlements.size() >= 1000) {
        insuranceSettlementMapper.insertBatch(settlements);
        settlements.clear();
    }
}
```

**API自动同步**:
```java
@Scheduled(cron = "0 0 3 6 * ?")  // 每月6号凌晨3点
public void syncFromInsuranceCompany() {
    List<InsuranceCompanyConfigDO> companies = getApiEnabledCompanies();
    
    companies.forEach(company -> {
        List<SettlementDataDTO> data = callInsuranceAPI(company, lastMonth);
        importSettlementFromAPI(company, data);
    });
}
```

#### 3.5.2 自动对账引擎

**保单号匹配**:
```java
settlements.forEach(settlement -> {
    // 根据保单号查找本地佣金
    CommissionRecordDO local = commissionRecordMapper.selectOne(
        policy_no=settlement.getPolicyNo() AND insurance_company=settlement.getInsuranceCompany()
    );
    
    if (local == null) {
        settlement.setMatchStatus("EXCEPTION");
        settlement.setDiffType("NOT_FOUND");
    } else {
        boolean isMatch = compareCommission(settlement, local);
        settlement.setMatchStatus(isMatch ? "MATCHED" : "EXCEPTION");
    }
});
```

**金额比对**:
```java
// 允许±0.01元误差
BigDecimal amountDiff = settlement.getCommissionAmount()
    .subtract(local.getCommissionAmount()).abs();
BigDecimal tolerance = new BigDecimal("0.01");

if (amountDiff.compareTo(tolerance) > 0) {
    settlement.setDiffType("AMOUNT_DIFF");
    settlement.setDiffAmount(settlement.getCommissionAmount().subtract(local.getCommissionAmount()));
    return false;  // 不匹配
}
```

#### 3.5.3 差异处理流程

**处理方案**:

1. **接受保司数据**: 调整本地佣金金额为保司数据
2. **坚持本地数据**: 标记为已处理但不调整,生成异议函
3. **双方协商**: 标记为协商中,发邮件通知保司联系人

**调整审批**:
- 差异<100元: 财务专员直接处理
- 差异100-1000元: 财务主管审批
- 差异>1000元: 总经理审批

---

## 四、接口设计(简化版)

### 4.1 基本法配置接口

| 接口名称 | 请求方式 | 路径 | 权限 |
|---------|---------|------|------|
| 创建职级 | POST | /commission/rank/create | commission:rank:create |
| 更新职级 | PUT | /commission/rank/update | commission:rank:update |
| 删除职级 | DELETE | /commission/rank/delete | commission:rank:delete |
| 查询职级列表 | GET | /commission/rank/page | commission:rank:query |
| 创建规则 | POST | /commission/rule/create | commission:rule:create |
| 更新规则 | PUT | /commission/rule/update | commission:rule:update |
| 测试规则公式 | POST | /commission/rule/test-formula | commission:rule:test |

### 4.2 佣金计算接口

| 接口名称 | 请求方式 | 路径 | 权限 |
|---------|---------|------|------|
| 单笔计算 | POST | /commission/calculate/single | commission:calculate:execute |
| 批量计算 | POST | /commission/calculate/batch | commission:calculate:execute |
| 重新计算 | POST | /commission/calculate/recalculate | commission:calculate:execute |
| 查询计算结果 | GET | /commission/record/page | commission:record:query |

### 4.3 佣金审核接口

| 接口名称 | 请求方式 | 路径 | 权限 |
|---------|---------|------|------|
| 单笔审核 | POST | /commission/audit/approve | commission:audit:approve |
| 批量审核 | POST | /commission/audit/batch-approve | commission:audit:approve |
| 驳回 | POST | /commission/audit/reject | commission:audit:reject |
| 待审核列表 | GET | /commission/audit/pending-page | commission:audit:query |

### 4.4 佣金发放接口

| 接口名称 | 请求方式 | 路径 | 权限 |
|---------|---------|------|------|
| 创建批次 | POST | /commission/pay-batch/create | commission:pay:create |
| 审批批次 | POST | /commission/pay-batch/approve | commission:pay:approve |
| 执行发放 | POST | /commission/pay-batch/execute | commission:pay:execute |
| 查询批次 | GET | /commission/pay-batch/page | commission:pay:query |

### 4.5 对账管理接口

| 接口名称 | 请求方式 | 路径 | 权限 |
|---------|---------|------|------|
| 导入结算单 | POST | /commission/settlement/import | commission:settlement:import |
| 执行对账 | POST | /commission/settlement/match | commission:settlement:match |
| 处理差异 | POST | /commission/settlement/handle-diff | commission:settlement:handle |
| 查询结算明细 | GET | /commission/settlement/page | commission:settlement:query |

---

## 五、关键技术要点

### 5.1 金额精度处理

**强制要求**:
1. 所有金额字段使用BigDecimal类型
2. 金额计算显式指定精度: `.setScale(2, RoundingMode.HALF_UP)`
3. 数据库字段统一DECIMAL(12,2)

### 5.2 并发控制

**佣金审核乐观锁**:
```sql
UPDATE commission_record
SET status = 'APPROVED'
WHERE id = #{id} AND status = 'PENDING'  -- WHERE条件防止并发
```

**发放批次分布式锁**:
```java
String lockKey = "commission:pay:batch:" + batchId;
boolean locked = redisTemplate.opsForValue().setIfAbsent(lockKey, "1", 5, TimeUnit.MINUTES);
if (!locked) throw new ServiceException("批次正在发放中");

try {
    executePayment(batchId);
} finally {
    redisTemplate.delete(lockKey);
}
```

### 5.3 异常处理规范

**自定义异常码**:
```java
public interface ErrorCodeConstants {
    // 基本法 (100000-100099)
    ErrorCode RANK_NOT_FOUND = new ErrorCode(100001, "职级不存在");
    ErrorCode RULE_NOT_FOUND = new ErrorCode(100002, "佣金规则不存在");
    
    // 计算 (100100-100199)
    ErrorCode NO_APPLICABLE_RULE = new ErrorCode(100102, "未找到适用规则");
    ErrorCode COMMISSION_CALC_ERROR = new ErrorCode(100103, "佣金计算失败");
    
    // 审核 (100200-100299)
    ErrorCode COMMISSION_ALREADY_AUDITED = new ErrorCode(100201, "已被审核");
    
    // 发放 (100300-100399)
    ErrorCode PAY_BATCH_ALREADY_EXECUTED = new ErrorCode(100302, "批次已执行");
}
```

---

## 六、部署与配置

### 6.1 配置文件

```yaml
commission:
  calculate:
    batch-size: 1000  # 批量计算大小
    async-thread-pool-size: 5  # 异步线程池
  split:
    max-hierarchy-level: 5  # 最大分润层级
  settlement:
    max-import-rows: 10000  # 导入最大行数
    amount-tolerance: 0.01  # 金额误差容忍度
```

### 6.2 定时任务

| 任务名称 | Cron表达式 | 说明 |
|---------|-----------|------|
| 月度发放 | 0 0 2 5 * ? | 每月5号凌晨2点生成发放批次 |
| 晋升评估 | 0 0 1 1 * ? | 每月1号凌晨1点评估晋升 |
| 对账同步 | 0 0 3 6 * ? | 每月6号凌晨3点同步保司数据 |

---

## 七、开发交付清单

### 7.1 代码交付

- Controller层: 6个类
- Service层: 10个接口及实现
- Mapper层: 12个接口及XML
- DO实体: 12个类
- VO对象: 50+个
- 枚举类: 5个

### 7.2 数据库脚本

1. commission_ddl.sql - 表结构
2. commission_init_data.sql - 初始化数据
3. commission_index.sql - 索引

### 7.3 文档交付

- 详细需求文档(本文档)
- API接口文档(Swagger)
- 数据库设计文档
- 部署运维文档

---

**文档结束**

本文档共约2.5万字,全面覆盖PC佣金系统的核心业务逻辑、数据库设计、接口定义和关键技术要点。重点突出业务规则说明和功能实现,为开发团队提供清晰指引。

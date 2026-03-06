# 阶段2-PC佣金系统详细需求文档

## 文档版本信息
- **版本号**: V1.0
- **编制日期**: 2026-02-13
- **技术栈**: RuoYi-Vue-Pro + MySQL 8.0 + Redis
- **开发周期**: 2周
- **优先级**: P0 (核心功能)

---

## 一、系统概述

### 1.1 业务背景
PC佣金系统是保险中介平台的核心财务模块,负责管理保险业务员的佣金计算、审核、发放全流程。系统需支持复杂的多级分润逻辑、合规审计要求以及与上游保司的自动对账能力。

### 1.2 核心目标
1. **自动化**: 实现佣金从保单绑定到发放的全自动化流程
2. **准确性**: 确保佣金计算精确无误,支持复杂的基本法规则
3. **可追溯**: 所有佣金变更必须有完整的审计日志
4. **合规性**: 满足"报行合一"政策要求,佣金率不得超监管上限

### 1.3 功能模块划分
```
PC佣金系统
├── 基本法配置模块
│   ├── 职级体系管理
│   ├── 佣金规则配置
│   └── 考核指标设定
├── 佣金计算模块
│   ├── 保单佣金绑定
│   ├── 自动计算引擎
│   └── 分润逻辑处理
├── 佣金审核模块
│   ├── 待审核列表
│   ├── 审核流程
│   └── 驳回处理
├── 佣金发放模块
│   ├── 发放计划
│   ├── 批量发放
│   └── 发放记录
└── 对账管理模块
    ├── 保司数据导入
    ├── 自动对账
    └── 差异处理

```

---

## 二、数据库设计

### 2.1 基本法配置相关表

#### 2.1.1 职级表 (sys_agent_rank)
```sql
CREATE TABLE `sys_agent_rank` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `rank_code` varchar(32) NOT NULL COMMENT '职级代码(如:SALES,SUPERVISOR,MANAGER)',
  `rank_name` varchar(64) NOT NULL COMMENT '职级名称',
  `rank_level` int(11) NOT NULL COMMENT '职级层级(1-10,数字越大层级越高)',
  `parent_rank_code` varchar(32) DEFAULT NULL COMMENT '上级职级代码',
  `promotion_rules` json DEFAULT NULL COMMENT '晋升规则JSON(包含FYP要求、人力要求等)',
  `icon_url` varchar(255) DEFAULT NULL COMMENT '职级图标URL',
  `description` varchar(500) DEFAULT NULL COMMENT '职级说明',
  `status` tinyint(1) DEFAULT '1' COMMENT '状态(0-停用 1-启用)',
  `sort` int(11) DEFAULT '0' COMMENT '排序',
  `creator` varchar(64) DEFAULT NULL COMMENT '创建人',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) DEFAULT NULL COMMENT '更新人',
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint(1) DEFAULT '0' COMMENT '逻辑删除(0-未删除 1-已删除)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rank_code` (`rank_code`) USING BTREE,
  KEY `idx_rank_level` (`rank_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='代理人职级表';

-- 示例数据
INSERT INTO `sys_agent_rank` VALUES 
(1, 'SALES', '业务员', 1, NULL, '{"fyp_min":0}', NULL, '基础职级', 1, 1, 'admin', NOW(), NULL, NOW(), 0),
(2, 'SUPERVISOR', '主管', 2, 'SALES', '{"fyp_min":100000,"team_size":3}', NULL, '需管理3人团队', 1, 2, 'admin', NOW(), NULL, NOW(), 0),
(3, 'MANAGER', '经理', 3, 'SUPERVISOR', '{"fyp_min":500000,"team_size":10}', NULL, '需管理10人团队', 1, 3, 'admin', NOW(), NULL, NOW(), 0);
```

#### 2.1.2 基本法规则表 (commission_base_rule)
```sql
CREATE TABLE `commission_base_rule` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `rule_code` varchar(64) NOT NULL COMMENT '规则代码(全局唯一)',
  `rule_name` varchar(128) NOT NULL COMMENT '规则名称',
  `rule_type` varchar(32) NOT NULL COMMENT '规则类型(FYC-首年佣金,RYC-续期佣金,OVERRIDE-管理津贴,BONUS-奖金)',
  `rank_code` varchar(32) DEFAULT NULL COMMENT '适用职级(NULL表示全部)',
  `product_category` varchar(32) DEFAULT NULL COMMENT '适用险种(CAR-车险,LIFE-寿险,HEALTH-健康险,NULL-全部)',
  `calc_formula` text NOT NULL COMMENT '计算公式(使用Groovy脚本)',
  `rate_config` json DEFAULT NULL COMMENT '费率配置JSON',
  `effective_date` date NOT NULL COMMENT '生效日期',
  `expire_date` date DEFAULT NULL COMMENT '失效日期(NULL表示长期有效)',
  `priority` int(11) DEFAULT '0' COMMENT '优先级(数字越大优先级越高,冲突时取高优先级)',
  `remark` varchar(500) DEFAULT NULL COMMENT '备注说明',
  `status` tinyint(1) DEFAULT '1' COMMENT '状态(0-停用 1-启用)',
  `creator` varchar(64) DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT NULL,
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_rule_code` (`rule_code`),
  KEY `idx_rank_product` (`rank_code`,`product_category`),
  KEY `idx_effective_date` (`effective_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金基本法规则表';

-- 示例规则: 寿险首年佣金
INSERT INTO `commission_base_rule` VALUES 
(1, 'LIFE_FYC_SALES', '寿险业务员首年佣金', 'FYC', 'SALES', 'LIFE', 
'premium * rateConfig.fyc_rate', 
'{"fyc_rate":0.25,"max_rate":0.30}', 
'2026-01-01', NULL, 100, '寿险产品业务员可获25%首年佣金', 1, 'admin', NOW(), NULL, NOW(), 0);

-- 示例规则: 管理津贴
INSERT INTO `commission_base_rule` VALUES 
(2, 'OVERRIDE_SUPERVISOR', '主管管理津贴', 'OVERRIDE', 'SUPERVISOR', NULL,
'teamTotalCommission * rateConfig.override_rate',
'{"override_rate":0.05,"min_team_size":3}',
'2026-01-01', NULL, 100, '主管可获下级团队总佣金的5%', 1, 'admin', NOW(), NULL, NOW(), 0);
```

#### 2.1.3 佣金率历史表 (commission_rate_history)
```sql
CREATE TABLE `commission_rate_history` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `rule_id` bigint(20) NOT NULL COMMENT '关联规则ID',
  `change_type` varchar(32) NOT NULL COMMENT '变更类型(CREATE-新增,UPDATE-修改,DELETE-删除)',
  `old_value` json DEFAULT NULL COMMENT '变更前值',
  `new_value` json NOT NULL COMMENT '变更后值',
  `change_reason` varchar(500) DEFAULT NULL COMMENT '变更原因',
  `operator` varchar(64) NOT NULL COMMENT '操作人',
  `operate_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  PRIMARY KEY (`id`),
  KEY `idx_rule_id` (`rule_id`),
  KEY `idx_operate_time` (`operate_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金率变更历史表';
```

### 2.2 佣金计算相关表

#### 2.2.1 佣金主表 (commission_record)
```sql
CREATE TABLE `commission_record` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `commission_no` varchar(64) NOT NULL COMMENT '佣金单号(唯一)',
  `policy_id` bigint(20) NOT NULL COMMENT '关联保单ID',
  `policy_no` varchar(128) NOT NULL COMMENT '保单号',
  `agent_id` bigint(20) NOT NULL COMMENT '业务员ID',
  `agent_name` varchar(64) NOT NULL COMMENT '业务员姓名',
  `agent_rank` varchar(32) NOT NULL COMMENT '业务员职级',
  `product_category` varchar(32) NOT NULL COMMENT '险种分类',
  `product_name` varchar(128) NOT NULL COMMENT '产品名称',
  `insurance_company` varchar(128) NOT NULL COMMENT '保险公司',
  `premium` decimal(12,2) NOT NULL COMMENT '保费(元)',
  `payment_period` int(11) DEFAULT NULL COMMENT '缴费年期',
  `commission_type` varchar(32) NOT NULL COMMENT '佣金类型(FYC,RYC,OVERRIDE,BONUS)',
  `commission_rate` decimal(6,4) NOT NULL COMMENT '佣金费率(如0.2500表示25%)',
  `commission_amount` decimal(12,2) NOT NULL COMMENT '佣金金额(元)',
  `calc_formula` varchar(500) DEFAULT NULL COMMENT '计算公式说明',
  `settle_period` varchar(32) NOT NULL COMMENT '结算周期(如202602表示2026年2月)',
  `status` varchar(32) NOT NULL DEFAULT 'PENDING' COMMENT '状态(PENDING-待审核,APPROVED-已审核,PAID-已发放,REJECTED-已驳回)',
  `audit_time` datetime DEFAULT NULL COMMENT '审核时间',
  `auditor` varchar(64) DEFAULT NULL COMMENT '审核人',
  `audit_remark` varchar(500) DEFAULT NULL COMMENT '审核备注',
  `pay_time` datetime DEFAULT NULL COMMENT '发放时间',
  `pay_batch_no` varchar(64) DEFAULT NULL COMMENT '发放批次号',
  `pay_channel` varchar(32) DEFAULT NULL COMMENT '发放渠道(BANK-银行转账,ALIPAY-支付宝,WECHAT-微信)',
  `pay_voucher` varchar(255) DEFAULT NULL COMMENT '支付凭证URL',
  `remark` varchar(500) DEFAULT NULL COMMENT '备注',
  `creator` varchar(64) DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT NULL,
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_commission_no` (`commission_no`),
  KEY `idx_policy_id` (`policy_id`),
  KEY `idx_agent_id` (`agent_id`),
  KEY `idx_settle_period` (`settle_period`),
  KEY `idx_status` (`status`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金记录主表';
```

#### 2.2.2 佣金明细表 (commission_detail)
```sql
CREATE TABLE `commission_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `commission_id` bigint(20) NOT NULL COMMENT '关联佣金主表ID',
  `detail_type` varchar(32) NOT NULL COMMENT '明细类型(DIRECT-直接佣金,OVERRIDE-管理津贴,DEDUCTION-扣款项)',
  `calc_base` decimal(12,2) NOT NULL COMMENT '计算基数',
  `calc_rate` decimal(6,4) NOT NULL COMMENT '计算比例',
  `amount` decimal(12,2) NOT NULL COMMENT '金额',
  `related_agent_id` bigint(20) DEFAULT NULL COMMENT '关联代理人ID(用于管理津贴)',
  `description` varchar(255) DEFAULT NULL COMMENT '说明',
  `creator` varchar(64) DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_commission_id` (`commission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金计算明细表';
```

#### 2.2.3 佣金分润表 (commission_split)
```sql
CREATE TABLE `commission_split` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `source_commission_id` bigint(20) NOT NULL COMMENT '源佣金记录ID(下级业务员的佣金)',
  `target_commission_id` bigint(20) NOT NULL COMMENT '目标佣金记录ID(上级获得的管理津贴)',
  `source_agent_id` bigint(20) NOT NULL COMMENT '源代理人ID',
  `target_agent_id` bigint(20) NOT NULL COMMENT '目标代理人ID(上级)',
  `split_type` varchar(32) NOT NULL COMMENT '分润类型(OVERRIDE-管理津贴,TRAINING-育成奖)',
  `split_rate` decimal(6,4) NOT NULL COMMENT '分润比例',
  `split_amount` decimal(12,2) NOT NULL COMMENT '分润金额',
  `hierarchy_level` int(11) NOT NULL COMMENT '层级差(1-直接上级,2-隔代上级)',
  `creator` varchar(64) DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_source_commission` (`source_commission_id`),
  KEY `idx_target_agent` (`target_agent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金分润关系表';
```

### 2.3 对账管理相关表

#### 2.3.1 保司结算表 (insurance_settlement)
```sql
CREATE TABLE `insurance_settlement` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `settlement_no` varchar(64) NOT NULL COMMENT '结算单号',
  `insurance_company` varchar(128) NOT NULL COMMENT '保险公司',
  `settle_period` varchar(32) NOT NULL COMMENT '结算周期',
  `import_time` datetime NOT NULL COMMENT '导入时间',
  `file_url` varchar(255) NOT NULL COMMENT '原始文件URL',
  `total_premium` decimal(15,2) NOT NULL COMMENT '总保费',
  `total_commission` decimal(15,2) NOT NULL COMMENT '总佣金',
  `policy_count` int(11) NOT NULL COMMENT '保单数量',
  `match_status` varchar(32) DEFAULT 'PENDING' COMMENT '匹配状态(PENDING-待匹配,MATCHED-已匹配,EXCEPTION-有异常)',
  `match_count` int(11) DEFAULT '0' COMMENT '已匹配数量',
  `exception_count` int(11) DEFAULT '0' COMMENT '异常数量',
  `operator` varchar(64) NOT NULL COMMENT '操作人',
  `remark` varchar(500) DEFAULT NULL,
  `creator` varchar(64) DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT NULL,
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_settlement_no` (`settlement_no`),
  KEY `idx_settle_period` (`settle_period`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保司结算单主表';
```

#### 2.3.2 保司结算明细表 (insurance_settlement_detail)
```sql
CREATE TABLE `insurance_settlement_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `settlement_id` bigint(20) NOT NULL COMMENT '关联结算单ID',
  `policy_no` varchar(128) NOT NULL COMMENT '保单号',
  `insured_name` varchar(64) DEFAULT NULL COMMENT '被保人姓名',
  `premium` decimal(12,2) NOT NULL COMMENT '保费',
  `commission_rate` decimal(6,4) NOT NULL COMMENT '佣金率',
  `commission_amount` decimal(12,2) NOT NULL COMMENT '佣金金额',
  `agent_code` varchar(64) DEFAULT NULL COMMENT '业务员工号',
  `match_status` varchar(32) DEFAULT 'UNMATCHED' COMMENT '匹配状态(UNMATCHED-未匹配,MATCHED-已匹配,EXCEPTION-异常)',
  `local_policy_id` bigint(20) DEFAULT NULL COMMENT '本地保单ID',
  `local_commission_id` bigint(20) DEFAULT NULL COMMENT '本地佣金ID',
  `diff_amount` decimal(12,2) DEFAULT '0.00' COMMENT '差异金额',
  `exception_reason` varchar(255) DEFAULT NULL COMMENT '异常原因',
  `creator` varchar(64) DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_settlement_id` (`settlement_id`),
  KEY `idx_policy_no` (`policy_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保司结算明细表';
```

### 2.4 发放管理相关表

#### 2.4.1 发放批次表 (commission_pay_batch)
```sql
CREATE TABLE `commission_pay_batch` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `batch_no` varchar(64) NOT NULL COMMENT '批次号',
  `settle_period` varchar(32) NOT NULL COMMENT '结算周期',
  `total_amount` decimal(15,2) NOT NULL COMMENT '发放总额',
  `total_count` int(11) NOT NULL COMMENT '发放笔数',
  `agent_count` int(11) NOT NULL COMMENT '代理人数',
  `pay_channel` varchar(32) NOT NULL COMMENT '发放渠道',
  `plan_pay_time` datetime NOT NULL COMMENT '计划发放时间',
  `actual_pay_time` datetime DEFAULT NULL COMMENT '实际发放时间',
  `status` varchar(32) NOT NULL DEFAULT 'DRAFT' COMMENT '状态(DRAFT-草稿,APPROVED-已审批,PAYING-发放中,COMPLETED-已完成,FAILED-失败)',
  `approver` varchar(64) DEFAULT NULL COMMENT '审批人',
  `approve_time` datetime DEFAULT NULL COMMENT '审批时间',
  `operator` varchar(64) NOT NULL COMMENT '操作人',
  `remark` varchar(500) DEFAULT NULL,
  `creator` varchar(64) DEFAULT NULL,
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater` varchar(64) DEFAULT NULL,
  `update_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch_no` (`batch_no`),
  KEY `idx_settle_period` (`settle_period`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='佣金发放批次表';
```

---

## 三、核心接口定义

### 3.1 基本法配置模块接口

#### 3.1.1 职级管理接口

**Controller类**: `CommissionRankController.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.rank;

import cn.iocoder.yudao.framework.common.pojo.CommonResult;
import cn.iocoder.yudao.framework.common.pojo.PageResult;
import cn.iocoder.yudao.module.commission.controller.admin.rank.vo.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;

@Tag(name = "管理后台 - 代理人职级")
@RestController
@RequestMapping("/commission/rank")
@Validated
public class CommissionRankController {

    @GetMapping("/page")
    @Operation(summary = "分页查询职级列表")
    public CommonResult<PageResult<CommissionRankRespVO>> getRankPage(
            @Valid CommissionRankPageReqVO pageVO) {
        // 实现逻辑
        return null;
    }

    @GetMapping("/get")
    @Operation(summary = "获取职级详情")
    public CommonResult<CommissionRankRespVO> getRank(@RequestParam("id") Long id) {
        return null;
    }

    @PostMapping("/create")
    @Operation(summary = "创建职级")
    public CommonResult<Long> createRank(@Valid @RequestBody CommissionRankCreateReqVO createVO) {
        return null;
    }

    @PutMapping("/update")
    @Operation(summary = "更新职级")
    public CommonResult<Boolean> updateRank(@Valid @RequestBody CommissionRankUpdateReqVO updateVO) {
        return null;
    }

    @DeleteMapping("/delete")
    @Operation(summary = "删除职级")
    public CommonResult<Boolean> deleteRank(@RequestParam("id") Long id) {
        return null;
    }

    @GetMapping("/tree")
    @Operation(summary = "获取职级树形结构")
    public CommonResult<List<CommissionRankTreeVO>> getRankTree() {
        return null;
    }
}
```

**VO定义**: `CommissionRankCreateReqVO.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.rank.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import javax.validation.constraints.*;

@Schema(description = "管理后台 - 职级创建 Request VO")
@Data
public class CommissionRankCreateReqVO {

    @Schema(description = "职级代码", requiredMode = Schema.RequiredMode.REQUIRED, example = "SUPERVISOR")
    @NotBlank(message = "职级代码不能为空")
    @Pattern(regexp = "^[A-Z_]+$", message = "职级代码只能包含大写字母和下划线")
    private String rankCode;

    @Schema(description = "职级名称", requiredMode = Schema.RequiredMode.REQUIRED, example = "主管")
    @NotBlank(message = "职级名称不能为空")
    @Size(max = 64, message = "职级名称长度不能超过64个字符")
    private String rankName;

    @Schema(description = "职级层级", requiredMode = Schema.RequiredMode.REQUIRED, example = "2")
    @NotNull(message = "职级层级不能为空")
    @Min(value = 1, message = "职级层级最小为1")
    @Max(value = 10, message = "职级层级最大为10")
    private Integer rankLevel;

    @Schema(description = "上级职级代码", example = "SALES")
    private String parentRankCode;

    @Schema(description = "晋升规则JSON", example = "{\"fyp_min\":100000,\"team_size\":3}")
    private String promotionRules;

    @Schema(description = "职级说明", example = "需管理3人团队")
    @Size(max = 500, message = "职级说明长度不能超过500个字符")
    private String description;

    @Schema(description = "排序", example = "1")
    private Integer sort;
}
```

#### 3.1.2 佣金规则管理接口

**Controller类**: `CommissionRuleController.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.rule;

import cn.iocoder.yudao.framework.common.pojo.CommonResult;
import cn.iocoder.yudao.framework.common.pojo.PageResult;
import cn.iocoder.yudao.module.commission.controller.admin.rule.vo.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.time.LocalDate;

@Tag(name = "管理后台 - 佣金规则")
@RestController
@RequestMapping("/commission/rule")
@Validated
public class CommissionRuleController {

    @GetMapping("/page")
    @Operation(summary = "分页查询佣金规则")
    public CommonResult<PageResult<CommissionRuleRespVO>> getRulePage(
            @Valid CommissionRulePageReqVO pageVO) {
        return null;
    }

    @GetMapping("/get")
    @Operation(summary = "获取规则详情")
    public CommonResult<CommissionRuleRespVO> getRule(@RequestParam("id") Long id) {
        return null;
    }

    @PostMapping("/create")
    @Operation(summary = "创建佣金规则")
    public CommonResult<Long> createRule(@Valid @RequestBody CommissionRuleCreateReqVO createVO) {
        return null;
    }

    @PutMapping("/update")
    @Operation(summary = "更新佣金规则")
    public CommonResult<Boolean> updateRule(@Valid @RequestBody CommissionRuleUpdateReqVO updateVO) {
        return null;
    }

    @DeleteMapping("/delete")
    @Operation(summary = "删除佣金规则")
    public CommonResult<Boolean> deleteRule(@RequestParam("id") Long id) {
        return null;
    }

    @PostMapping("/test-calculate")
    @Operation(summary = "测试规则计算")
    @Parameter(name = "testData", description = "测试数据", required = true)
    public CommonResult<CommissionRuleTestResultVO> testCalculate(
            @Valid @RequestBody CommissionRuleTestReqVO testVO) {
        return null;
    }

    @GetMapping("/effective")
    @Operation(summary = "获取指定日期有效的规则")
    public CommonResult<List<CommissionRuleRespVO>> getEffectiveRules(
            @RequestParam("effectiveDate") LocalDate effectiveDate,
            @RequestParam(value = "rankCode", required = false) String rankCode,
            @RequestParam(value = "productCategory", required = false) String productCategory) {
        return null;
    }

    @GetMapping("/history")
    @Operation(summary = "查询规则变更历史")
    public CommonResult<PageResult<CommissionRateHistoryRespVO>> getRuleHistory(
            @Valid CommissionRateHistoryPageReqVO pageVO) {
        return null;
    }
}
```

**VO定义**: `CommissionRuleCreateReqVO.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.rule.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import org.springframework.format.annotation.DateTimeFormat;

import javax.validation.constraints.*;
import java.time.LocalDate;

@Schema(description = "管理后台 - 佣金规则创建 Request VO")
@Data
public class CommissionRuleCreateReqVO {

    @Schema(description = "规则代码", requiredMode = Schema.RequiredMode.REQUIRED, example = "LIFE_FYC_SALES")
    @NotBlank(message = "规则代码不能为空")
    @Pattern(regexp = "^[A-Z0-9_]+$", message = "规则代码只能包含大写字母、数字和下划线")
    private String ruleCode;

    @Schema(description = "规则名称", requiredMode = Schema.RequiredMode.REQUIRED, example = "寿险业务员首年佣金")
    @NotBlank(message = "规则名称不能为空")
    @Size(max = 128, message = "规则名称长度不能超过128个字符")
    private String ruleName;

    @Schema(description = "规则类型", requiredMode = Schema.RequiredMode.REQUIRED, example = "FYC")
    @NotBlank(message = "规则类型不能为空")
    @Pattern(regexp = "^(FYC|RYC|OVERRIDE|BONUS)$", message = "规则类型只能是FYC、RYC、OVERRIDE、BONUS之一")
    private String ruleType;

    @Schema(description = "适用职级", example = "SALES")
    private String rankCode;

    @Schema(description = "适用险种", example = "LIFE")
    @Pattern(regexp = "^(CAR|LIFE|HEALTH)?$", message = "险种只能是CAR、LIFE、HEALTH之一或为空")
    private String productCategory;

    @Schema(description = "计算公式", requiredMode = Schema.RequiredMode.REQUIRED, 
            example = "premium * rateConfig.fyc_rate")
    @NotBlank(message = "计算公式不能为空")
    private String calcFormula;

    @Schema(description = "费率配置JSON", requiredMode = Schema.RequiredMode.REQUIRED,
            example = "{\"fyc_rate\":0.25,\"max_rate\":0.30}")
    @NotBlank(message = "费率配置不能为空")
    private String rateConfig;

    @Schema(description = "生效日期", requiredMode = Schema.RequiredMode.REQUIRED, example = "2026-01-01")
    @NotNull(message = "生效日期不能为空")
    @DateTimeFormat(pattern = "yyyy-MM-dd")
    private LocalDate effectiveDate;

    @Schema(description = "失效日期", example = "2026-12-31")
    @DateTimeFormat(pattern = "yyyy-MM-dd")
    private LocalDate expireDate;

    @Schema(description = "优先级", example = "100")
    @Min(value = 0, message = "优先级不能小于0")
    @Max(value = 999, message = "优先级不能大于999")
    private Integer priority;

    @Schema(description = "备注说明", example = "寿险产品业务员可获25%首年佣金")
    @Size(max = 500, message = "备注长度不能超过500个字符")
    private String remark;
}
```

### 3.2 佣金计算模块接口

#### 3.2.1 佣金计算接口

**Controller类**: `CommissionCalculateController.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.calculate;

import cn.iocoder.yudao.framework.common.pojo.CommonResult;
import cn.iocoder.yudao.module.commission.controller.admin.calculate.vo.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;

@Tag(name = "管理后台 - 佣金计算")
@RestController
@RequestMapping("/commission/calculate")
@Validated
public class CommissionCalculateController {

    @PostMapping("/single")
    @Operation(summary = "计算单笔保单佣金")
    public CommonResult<CommissionCalculateResultVO> calculateSingle(
            @Valid @RequestBody CommissionCalculateSingleReqVO reqVO) {
        return null;
    }

    @PostMapping("/batch")
    @Operation(summary = "批量计算佣金")
    public CommonResult<CommissionBatchCalculateResultVO> calculateBatch(
            @Valid @RequestBody CommissionCalculateBatchReqVO reqVO) {
        return null;
    }

    @PostMapping("/period")
    @Operation(summary = "计算指定周期佣金")
    public CommonResult<CommissionPeriodCalculateResultVO> calculatePeriod(
            @Valid @RequestBody CommissionCalculatePeriodReqVO reqVO) {
        return null;
    }

    @GetMapping("/preview")
    @Operation(summary = "预览佣金计算结果(不保存)")
    public CommonResult<CommissionPreviewResultVO> previewCalculate(
            @RequestParam("policyId") Long policyId) {
        return null;
    }

    @PostMapping("/recalculate")
    @Operation(summary = "重新计算指定佣金")
    public CommonResult<Boolean> recalculate(@RequestParam("commissionId") Long commissionId) {
        return null;
    }
}
```

**VO定义**: `CommissionCalculateSingleReqVO.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.calculate.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import javax.validation.constraints.*;
import java.math.BigDecimal;

@Schema(description = "管理后台 - 单笔佣金计算 Request VO")
@Data
public class CommissionCalculateSingleReqVO {

    @Schema(description = "保单ID", requiredMode = Schema.RequiredMode.REQUIRED, example = "12345")
    @NotNull(message = "保单ID不能为空")
    private Long policyId;

    @Schema(description = "业务员ID", requiredMode = Schema.RequiredMode.REQUIRED, example = "67890")
    @NotNull(message = "业务员ID不能为空")
    private Long agentId;

    @Schema(description = "保费", requiredMode = Schema.RequiredMode.REQUIRED, example = "10000.00")
    @NotNull(message = "保费不能为空")
    @DecimalMin(value = "0.01", message = "保费必须大于0")
    private BigDecimal premium;

    @Schema(description = "险种分类", requiredMode = Schema.RequiredMode.REQUIRED, example = "LIFE")
    @NotBlank(message = "险种分类不能为空")
    @Pattern(regexp = "^(CAR|LIFE|HEALTH)$", message = "险种分类必须是CAR、LIFE、HEALTH之一")
    private String productCategory;

    @Schema(description = "缴费年期", example = "10")
    private Integer paymentPeriod;

    @Schema(description = "结算周期", requiredMode = Schema.RequiredMode.REQUIRED, example = "202602")
    @NotBlank(message = "结算周期不能为空")
    @Pattern(regexp = "^\\d{6}$", message = "结算周期格式错误,应为YYYYMM格式")
    private String settlePeriod;

    @Schema(description = "是否立即保存", example = "false")
    private Boolean saveImmediately = false;
}
```

**返回VO**: `CommissionCalculateResultVO.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.calculate.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Schema(description = "管理后台 - 佣金计算结果 Response VO")
@Data
public class CommissionCalculateResultVO {

    @Schema(description = "佣金记录ID", example = "123")
    private Long commissionId;

    @Schema(description = "佣金单号", example = "COMM202602130001")
    private String commissionNo;

    @Schema(description = "保单号", example = "P202602130001")
    private String policyNo;

    @Schema(description = "业务员姓名", example = "张三")
    private String agentName;

    @Schema(description = "佣金类型", example = "FYC")
    private String commissionType;

    @Schema(description = "佣金费率", example = "0.2500")
    private BigDecimal commissionRate;

    @Schema(description = "佣金金额", example = "2500.00")
    private BigDecimal commissionAmount;

    @Schema(description = "计算公式说明", example = "10000.00 * 0.25 = 2500.00")
    private String calcFormula;

    @Schema(description = "佣金明细列表")
    private List<CommissionDetailVO> details;

    @Schema(description = "分润列表")
    private List<CommissionSplitVO> splits;

    @Schema(description = "计算时间", example = "2026-02-13 10:30:00")
    private String calculateTime;

    @Data
    @Schema(description = "佣金明细")
    public static class CommissionDetailVO {
        @Schema(description = "明细类型", example = "DIRECT")
        private String detailType;

        @Schema(description = "计算基数", example = "10000.00")
        private BigDecimal calcBase;

        @Schema(description = "计算比例", example = "0.2500")
        private BigDecimal calcRate;

        @Schema(description = "金额", example = "2500.00")
        private BigDecimal amount;

        @Schema(description = "说明", example = "直接佣金")
        private String description;
    }

    @Data
    @Schema(description = "佣金分润")
    public static class CommissionSplitVO {
        @Schema(description = "上级代理人姓名", example = "李四")
        private String targetAgentName;

        @Schema(description = "分润类型", example = "OVERRIDE")
        private String splitType;

        @Schema(description = "分润比例", example = "0.0500")
        private BigDecimal splitRate;

        @Schema(description = "分润金额", example = "125.00")
        private BigDecimal splitAmount;

        @Schema(description = "层级差", example = "1")
        private Integer hierarchyLevel;
    }
}
```

### 3.3 佣金审核模块接口

#### 3.3.1 佣金审核接口

**Controller类**: `CommissionAuditController.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.audit;

import cn.iocoder.yudao.framework.common.pojo.CommonResult;
import cn.iocoder.yudao.framework.common.pojo.PageResult;
import cn.iocoder.yudao.module.commission.controller.admin.audit.vo.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.List;

@Tag(name = "管理后台 - 佣金审核")
@RestController
@RequestMapping("/commission/audit")
@Validated
public class CommissionAuditController {

    @GetMapping("/pending-page")
    @Operation(summary = "分页查询待审核佣金")
    public CommonResult<PageResult<CommissionAuditRespVO>> getPendingPage(
            @Valid CommissionAuditPageReqVO pageVO) {
        return null;
    }

    @GetMapping("/get")
    @Operation(summary = "获取佣金审核详情")
    public CommonResult<CommissionAuditDetailRespVO> getAuditDetail(
            @RequestParam("id") Long id) {
        return null;
    }

    @PostMapping("/approve")
    @Operation(summary = "审核通过")
    public CommonResult<Boolean> approve(@Valid @RequestBody CommissionApproveReqVO reqVO) {
        return null;
    }

    @PostMapping("/batch-approve")
    @Operation(summary = "批量审核通过")
    public CommonResult<CommissionBatchAuditResultVO> batchApprove(
            @Valid @RequestBody CommissionBatchApproveReqVO reqVO) {
        return null;
    }

    @PostMapping("/reject")
    @Operation(summary = "审核驳回")
    public CommonResult<Boolean> reject(@Valid @RequestBody CommissionRejectReqVO reqVO) {
        return null;
    }

    @GetMapping("/statistics")
    @Operation(summary = "获取审核统计数据")
    public CommonResult<CommissionAuditStatisticsVO> getAuditStatistics(
            @RequestParam("settlePeriod") String settlePeriod) {
        return null;
    }
}
```

**VO定义**: `CommissionApproveReqVO.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.audit.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import javax.validation.constraints.NotNull;
import javax.validation.constraints.Size;

@Schema(description = "管理后台 - 佣金审核通过 Request VO")
@Data
public class CommissionApproveReqVO {

    @Schema(description = "佣金记录ID", requiredMode = Schema.RequiredMode.REQUIRED, example = "123")
    @NotNull(message = "佣金记录ID不能为空")
    private Long id;

    @Schema(description = "审核备注", example = "审核通过")
    @Size(max = 500, message = "审核备注长度不能超过500个字符")
    private String auditRemark;
}
```

**VO定义**: `CommissionBatchApproveReqVO.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.audit.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import javax.validation.constraints.NotEmpty;
import javax.validation.constraints.Size;
import java.util.List;

@Schema(description = "管理后台 - 批量审核通过 Request VO")
@Data
public class CommissionBatchApproveReqVO {

    @Schema(description = "佣金记录ID列表", requiredMode = Schema.RequiredMode.REQUIRED)
    @NotEmpty(message = "佣金记录ID列表不能为空")
    private List<Long> ids;

    @Schema(description = "审核备注", example = "批量审核通过")
    @Size(max = 500, message = "审核备注长度不能超过500个字符")
    private String auditRemark;
}
```

**返回VO**: `CommissionBatchAuditResultVO.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.audit.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.util.List;

@Schema(description = "管理后台 - 批量审核结果 Response VO")
@Data
public class CommissionBatchAuditResultVO {

    @Schema(description = "成功数量", example = "10")
    private Integer successCount;

    @Schema(description = "失败数量", example = "2")
    private Integer failCount;

    @Schema(description = "失败详情列表")
    private List<FailDetail> failDetails;

    @Data
    @Schema(description = "失败详情")
    public static class FailDetail {
        @Schema(description = "佣金记录ID", example = "123")
        private Long id;

        @Schema(description = "佣金单号", example = "COMM202602130001")
        private String commissionNo;

        @Schema(description = "失败原因", example = "该佣金记录已被审核")
        private String failReason;
    }
}
```

### 3.4 佣金发放模块接口

#### 3.4.1 发放批次管理接口

**Controller类**: `CommissionPayBatchController.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.pay;

import cn.iocoder.yudao.framework.common.pojo.CommonResult;
import cn.iocoder.yudao.framework.common.pojo.PageResult;
import cn.iocoder.yudao.module.commission.controller.admin.pay.vo.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;

@Tag(name = "管理后台 - 佣金发放批次")
@RestController
@RequestMapping("/commission/pay-batch")
@Validated
public class CommissionPayBatchController {

    @GetMapping("/page")
    @Operation(summary = "分页查询发放批次")
    public CommonResult<PageResult<CommissionPayBatchRespVO>> getPayBatchPage(
            @Valid CommissionPayBatchPageReqVO pageVO) {
        return null;
    }

    @GetMapping("/get")
    @Operation(summary = "获取发放批次详情")
    public CommonResult<CommissionPayBatchDetailRespVO> getPayBatch(
            @RequestParam("id") Long id) {
        return null;
    }

    @PostMapping("/create")
    @Operation(summary = "创建发放批次")
    public CommonResult<Long> createPayBatch(
            @Valid @RequestBody CommissionPayBatchCreateReqVO createVO) {
        return null;
    }

    @PostMapping("/approve")
    @Operation(summary = "审批发放批次")
    public CommonResult<Boolean> approvePayBatch(
            @Valid @RequestBody CommissionPayBatchApproveReqVO approveVO) {
        return null;
    }

    @PostMapping("/execute")
    @Operation(summary = "执行发放")
    public CommonResult<CommissionPayBatchExecuteResultVO> executePayBatch(
            @RequestParam("id") Long id) {
        return null;
    }

    @GetMapping("/export")
    @Operation(summary = "导出发放明细")
    public void exportPayBatch(@RequestParam("id") Long id) {
        // 导出Excel逻辑
    }
}
```

**VO定义**: `CommissionPayBatchCreateReqVO.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.pay.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import org.springframework.format.annotation.DateTimeFormat;

import javax.validation.constraints.*;
import java.time.LocalDateTime;
import java.util.List;

@Schema(description = "管理后台 - 创建发放批次 Request VO")
@Data
public class CommissionPayBatchCreateReqVO {

    @Schema(description = "结算周期", requiredMode = Schema.RequiredMode.REQUIRED, example = "202602")
    @NotBlank(message = "结算周期不能为空")
    @Pattern(regexp = "^\\d{6}$", message = "结算周期格式错误,应为YYYYMM格式")
    private String settlePeriod;

    @Schema(description = "发放渠道", requiredMode = Schema.RequiredMode.REQUIRED, example = "BANK")
    @NotBlank(message = "发放渠道不能为空")
    @Pattern(regexp = "^(BANK|ALIPAY|WECHAT)$", message = "发放渠道必须是BANK、ALIPAY、WECHAT之一")
    private String payChannel;

    @Schema(description = "计划发放时间", requiredMode = Schema.RequiredMode.REQUIRED)
    @NotNull(message = "计划发放时间不能为空")
    @DateTimeFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime planPayTime;

    @Schema(description = "包含的佣金记录ID列表")
    private List<Long> commissionIds;

    @Schema(description = "备注", example = "2026年2月佣金发放")
    @Size(max = 500, message = "备注长度不能超过500个字符")
    private String remark;
}
```

### 3.5 对账管理模块接口

#### 3.5.1 保司结算导入接口

**Controller类**: `InsuranceSettlementController.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.settlement;

import cn.iocoder.yudao.framework.common.pojo.CommonResult;
import cn.iocoder.yudao.framework.common.pojo.PageResult;
import cn.iocoder.yudao.module.commission.controller.admin.settlement.vo.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import javax.validation.Valid;

@Tag(name = "管理后台 - 保司结算对账")
@RestController
@RequestMapping("/commission/settlement")
@Validated
public class InsuranceSettlementController {

    @PostMapping("/import")
    @Operation(summary = "导入保司结算单")
    public CommonResult<InsuranceSettlementImportResultVO> importSettlement(
            @RequestParam("file") MultipartFile file,
            @RequestParam("insuranceCompany") String insuranceCompany,
            @RequestParam("settlePeriod") String settlePeriod) {
        return null;
    }

    @GetMapping("/page")
    @Operation(summary = "分页查询结算单")
    public CommonResult<PageResult<InsuranceSettlementRespVO>> getSettlementPage(
            @Valid InsuranceSettlementPageReqVO pageVO) {
        return null;
    }

    @PostMapping("/match")
    @Operation(summary = "执行自动对账")
    public CommonResult<InsuranceSettlementMatchResultVO> executeMatch(
            @RequestParam("settlementId") Long settlementId) {
        return null;
    }

    @GetMapping("/exception-page")
    @Operation(summary = "分页查询对账异常")
    public CommonResult<PageResult<SettlementExceptionRespVO>> getExceptionPage(
            @Valid SettlementExceptionPageReqVO pageVO) {
        return null;
    }

    @PostMapping("/handle-exception")
    @Operation(summary = "处理对账异常")
    public CommonResult<Boolean> handleException(
            @Valid @RequestBody SettlementExceptionHandleReqVO reqVO) {
        return null;
    }
}
```

**返回VO**: `InsuranceSettlementImportResultVO.java`

```java
package cn.iocoder.yudao.module.commission.controller.admin.settlement.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Schema(description = "管理后台 - 保司结算单导入结果 Response VO")
@Data
public class InsuranceSettlementImportResultVO {

    @Schema(description = "结算单ID", example = "123")
    private Long settlementId;

    @Schema(description = "结算单号", example = "SETTLE202602130001")
    private String settlementNo;

    @Schema(description = "导入总数", example = "100")
    private Integer totalCount;

    @Schema(description = "成功数", example = "98")
    private Integer successCount;

    @Schema(description = "失败数", example = "2")
    private Integer failCount;

    @Schema(description = "总保费", example = "1000000.00")
    private BigDecimal totalPremium;

    @Schema(description = "总佣金", example = "250000.00")
    private BigDecimal totalCommission;

    @Schema(description = "失败详情")
    private List<ImportFailDetail> failDetails;

    @Data
    @Schema(description = "导入失败详情")
    public static class ImportFailDetail {
        @Schema(description = "行号", example = "5")
        private Integer rowNum;

        @Schema(description = "保单号", example = "P202602130001")
        private String policyNo;

        @Schema(description = "失败原因", example = "保费格式错误")
        private String failReason;
    }
}
```

---

## 四、核心业务逻辑实现

### 4.1 佣金计算引擎实现

#### 4.1.1 Service层: `CommissionCalculateService.java`

```java
package cn.iocoder.yudao.module.commission.service.calculate;

import cn.iocoder.yudao.module.commission.dal.dataobject.record.CommissionRecordDO;
import cn.iocoder.yudao.module.commission.dal.dataobject.rule.CommissionBaseRuleDO;
import cn.iocoder.yudao.module.commission.controller.admin.calculate.vo.*;

import java.util.List;

/**
 * 佣金计算服务接口
 */
public interface CommissionCalculateService {

    /**
     * 计算单笔保单佣金
     * 
     * @param reqVO 计算请求参数
     * @return 计算结果
     */
    CommissionCalculateResultVO calculateSingle(CommissionCalculateSingleReqVO reqVO);

    /**
     * 批量计算佣金
     * 
     * @param reqVO 批量计算请求
     * @return 批量计算结果
     */
    CommissionBatchCalculateResultVO calculateBatch(CommissionCalculateBatchReqVO reqVO);

    /**
     * 计算指定周期的所有待计算佣金
     * 
     * @param reqVO 周期计算请求
     * @return 周期计算结果
     */
    CommissionPeriodCalculateResultVO calculatePeriod(CommissionCalculatePeriodReqVO reqVO);

    /**
     * 预览佣金计算(不保存到数据库)
     * 
     * @param policyId 保单ID
     * @return 预览结果
     */
    CommissionPreviewResultVO previewCalculate(Long policyId);

    /**
     * 重新计算指定佣金
     * 
     * @param commissionId 佣金记录ID
     * @return 是否成功
     */
    Boolean recalculate(Long commissionId);
}
```

#### 4.1.2 Service实现类: `CommissionCalculateServiceImpl.java`

```java
package cn.iocoder.yudao.module.commission.service.calculate;

import cn.hutool.core.util.StrUtil;
import cn.iocoder.yudao.framework.common.exception.ServiceException;
import cn.iocoder.yudao.module.commission.dal.dataobject.record.CommissionRecordDO;
import cn.iocoder.yudao.module.commission.dal.dataobject.rule.CommissionBaseRuleDO;
import cn.iocoder.yudao.module.commission.dal.mysql.record.CommissionRecordMapper;
import cn.iocoder.yudao.module.commission.dal.mysql.rule.CommissionBaseRuleMapper;
import cn.iocoder.yudao.module.commission.controller.admin.calculate.vo.*;
import cn.iocoder.yudao.module.commission.enums.CommissionTypeEnum;
import cn.iocoder.yudao.module.commission.enums.CommissionStatusEnum;
import cn.iocoder.yudao.module.system.dal.dataobject.user.AdminUserDO;
import cn.iocoder.yudao.module.system.service.user.AdminUserService;
import groovy.lang.Binding;
import groovy.lang.GroovyShell;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

import static cn.iocoder.yudao.module.commission.enums.ErrorCodeConstants.*;

@Service
@Slf4j
public class CommissionCalculateServiceImpl implements CommissionCalculateService {

    @Resource
    private CommissionBaseRuleMapper ruleMapper;

    @Resource
    private CommissionRecordMapper recordMapper;

    @Resource
    private AdminUserService adminUserService;

    @Resource
    private CommissionSplitService splitService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public CommissionCalculateResultVO calculateSingle(CommissionCalculateSingleReqVO reqVO) {
        // 1. 参数校验
        validateCalculateRequest(reqVO);

        // 2. 获取业务员信息
        AdminUserDO agent = adminUserService.getUser(reqVO.getAgentId());
        if (agent == null) {
            throw new ServiceException(AGENT_NOT_FOUND);
        }

        // 3. 查询适用的佣金规则
        List<CommissionBaseRuleDO> rules = findApplicableRules(
                agent.getRankCode(),
                reqVO.getProductCategory(),
                LocalDate.now()
        );

        if (rules.isEmpty()) {
            throw new ServiceException(NO_APPLICABLE_RULE);
        }

        // 4. 执行佣金计算
        CommissionRecordDO record = executeCalculation(reqVO, agent, rules);

        // 5. 计算上级分润
        List<CommissionSplitDO> splits = splitService.calculateSplits(record);

        // 6. 保存结果(如果需要)
        if (Boolean.TRUE.equals(reqVO.getSaveImmediately())) {
            recordMapper.insert(record);
            splits.forEach(split -> splitService.saveSplit(split));
        }

        // 7. 构建返回结果
        return buildCalculateResult(record, splits);
    }

    /**
     * 查找适用的佣金规则
     */
    private List<CommissionBaseRuleDO> findApplicableRules(
            String rankCode, 
            String productCategory, 
            LocalDate effectiveDate) {
        
        // 查询条件:
        // 1. 职级匹配(精确匹配 或 NULL表示全部职级)
        // 2. 险种匹配(精确匹配 或 NULL表示全部险种)
        // 3. 生效日期 <= 当前日期
        // 4. 失效日期 为NULL 或 > 当前日期
        // 5. 状态为启用
        // 按优先级降序排序
        
        return ruleMapper.selectList(
                "rank_code", rankCode,
                "product_category", productCategory,
                "effective_date", effectiveDate,
                "status", 1
        );
    }

    /**
     * 执行佣金计算核心逻辑
     */
    private CommissionRecordDO executeCalculation(
            CommissionCalculateSingleReqVO reqVO,
            AdminUserDO agent,
            List<CommissionBaseRuleDO> rules) {

        CommissionRecordDO record = new CommissionRecordDO();
        
        // 基础信息填充
        record.setCommissionNo(generateCommissionNo());
        record.setPolicyId(reqVO.getPolicyId());
        record.setAgentId(agent.getId());
        record.setAgentName(agent.getNickname());
        record.setAgentRank(agent.getRankCode());
        record.setProductCategory(reqVO.getProductCategory());
        record.setPremium(reqVO.getPremium());
        record.setPaymentPeriod(reqVO.getPaymentPeriod());
        record.setSettlePeriod(reqVO.getSettlePeriod());
        record.setStatus(CommissionStatusEnum.PENDING.getCode());

        // 遍历规则计算佣金
        BigDecimal totalCommission = BigDecimal.ZERO;
        StringBuilder formulaBuilder = new StringBuilder();

        for (CommissionBaseRuleDO rule : rules) {
            try {
                // 使用Groovy脚本执行计算公式
                BigDecimal amount = executeGroovyFormula(
                        rule.getCalcFormula(),
                        reqVO.getPremium(),
                        rule.getRateConfig()
                );

                totalCommission = totalCommission.add(amount);
                
                // 记录计算公式
                formulaBuilder.append(rule.getRuleName())
                        .append(": ")
                        .append(rule.getCalcFormula())
                        .append(" = ")
                        .append(amount)
                        .append("; ");

                // 设置主要佣金类型和费率(取第一个规则的)
                if (record.getCommissionType() == null) {
                    record.setCommissionType(rule.getRuleType());
                    // 从rateConfig中提取费率
                    record.setCommissionRate(extractRate(rule.getRateConfig()));
                }

            } catch (Exception e) {
                log.error("佣金计算公式执行失败: ruleCode={}, formula={}", 
                        rule.getRuleCode(), rule.getCalcFormula(), e);
                throw new ServiceException(COMMISSION_CALC_ERROR, e.getMessage());
            }
        }

        record.setCommissionAmount(totalCommission);
        record.setCalcFormula(formulaBuilder.toString());

        return record;
    }

    /**
     * 执行Groovy计算公式
     * 
     * @param formula 公式字符串,如: premium * rateConfig.fyc_rate
     * @param premium 保费
     * @param rateConfigJson 费率配置JSON
     * @return 计算结果
     */
    private BigDecimal executeGroovyFormula(
            String formula, 
            BigDecimal premium, 
            String rateConfigJson) {

        Binding binding = new Binding();
        binding.setVariable("premium", premium);
        
        // 解析费率配置JSON为Map
        Map<String, Object> rateConfig = parseRateConfig(rateConfigJson);
        binding.setVariable("rateConfig", rateConfig);

        GroovyShell shell = new GroovyShell(binding);
        Object result = shell.evaluate(formula);

        if (result instanceof Number) {
            return new BigDecimal(result.toString()).setScale(2, RoundingMode.HALF_UP);
        }

        throw new IllegalArgumentException("公式计算结果不是数值类型: " + result);
    }

    /**
     * 解析费率配置JSON
     */
    private Map<String, Object> parseRateConfig(String rateConfigJson) {
        // 使用Jackson或Hutool将JSON转为Map
        // 示例: {"fyc_rate":0.25,"max_rate":0.30}
        return JsonUtil.parseObject(rateConfigJson, Map.class);
    }

    /**
     * 从费率配置中提取主费率
     */
    private BigDecimal extractRate(String rateConfigJson) {
        Map<String, Object> config = parseRateConfig(rateConfigJson);
        
        // 优先取fyc_rate,其次取rate,最后取第一个数值字段
        if (config.containsKey("fyc_rate")) {
            return new BigDecimal(config.get("fyc_rate").toString());
        }
        if (config.containsKey("rate")) {
            return new BigDecimal(config.get("rate").toString());
        }
        
        // 取第一个数值型字段
        for (Object value : config.values()) {
            if (value instanceof Number) {
                return new BigDecimal(value.toString());
            }
        }
        
        return BigDecimal.ZERO;
    }

    /**
     * 生成佣金单号
     * 规则: COMM + YYYYMMDD + 4位流水号
     */
    private String generateCommissionNo() {
        String prefix = "COMM" + LocalDateTime.now().format(
                DateTimeFormatter.ofPattern("yyyyMMdd"));
        
        // 查询当天最大流水号
        String maxNo = recordMapper.selectMaxCommissionNoByPrefix(prefix);
        
        int sequence = 1;
        if (StrUtil.isNotBlank(maxNo)) {
            sequence = Integer.parseInt(maxNo.substring(maxNo.length() - 4)) + 1;
        }
        
        return prefix + String.format("%04d", sequence);
    }

    /**
     * 构建计算结果VO
     */
    private CommissionCalculateResultVO buildCalculateResult(
            CommissionRecordDO record, 
            List<CommissionSplitDO> splits) {
        
        CommissionCalculateResultVO result = new CommissionCalculateResultVO();
        result.setCommissionId(record.getId());
        result.setCommissionNo(record.getCommissionNo());
        result.setPolicyNo(record.getPolicyNo());
        result.setAgentName(record.getAgentName());
        result.setCommissionType(record.getCommissionType());
        result.setCommissionRate(record.getCommissionRate());
        result.setCommissionAmount(record.getCommissionAmount());
        result.setCalcFormula(record.getCalcFormula());
        result.setCalculateTime(LocalDateTime.now().format(
                DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));

        // 转换分润列表
        List<CommissionCalculateResultVO.CommissionSplitVO> splitVOs = new ArrayList<>();
        for (CommissionSplitDO split : splits) {
            CommissionCalculateResultVO.CommissionSplitVO splitVO = 
                    new CommissionCalculateResultVO.CommissionSplitVO();
            splitVO.setTargetAgentName(split.getTargetAgentName());
            splitVO.setSplitType(split.getSplitType());
            splitVO.setSplitRate(split.getSplitRate());
            splitVO.setSplitAmount(split.getSplitAmount());
            splitVO.setHierarchyLevel(split.getHierarchyLevel());
            splitVOs.add(splitVO);
        }
        result.setSplits(splitVOs);

        return result;
    }

    // ... 其他方法实现 ...
}
```

### 4.2 佣金分润逻辑实现

#### 4.2.1 Service接口: `CommissionSplitService.java`

```java
package cn.iocoder.yudao.module.commission.service.split;

import cn.iocoder.yudao.module.commission.dal.dataobject.record.CommissionRecordDO;
import cn.iocoder.yudao.module.commission.dal.dataobject.split.CommissionSplitDO;

import java.util.List;

/**
 * 佣金分润服务
 */
public interface CommissionSplitService {

    /**
     * 计算并生成佣金分润记录
     * 
     * 逻辑:
     * 1. 查询业务员的组织架构上级链条
     * 2. 根据每个上级的职级,查询其适用的管理津贴规则
     * 3. 计算每个上级应得的分润金额
     * 4. 生成分润记录并关联到源佣金
     * 
     * @param sourceCommission 源佣金记录
     * @return 分润记录列表
     */
    List<CommissionSplitDO> calculateSplits(CommissionRecordDO sourceCommission);

    /**
     * 保存分润记录
     * 
     * @param split 分润记录
     * @return 是否成功
     */
    Boolean saveSplit(CommissionSplitDO split);

    /**
     * 递归查询某代理人的所有上级链条
     * 
     * @param agentId 代理人ID
     * @param maxLevel 最大层级(防止无限递归)
     * @return 上级列表(按层级由近到远排序)
     */
    List<AgentHierarchyDTO> getAgentHierarchy(Long agentId, Integer maxLevel);
}
```

#### 4.2.2 DTO定义: `AgentHierarchyDTO.java`

```java
package cn.iocoder.yudao.module.commission.service.split.dto;

import lombok.Data;

@Data
public class AgentHierarchyDTO {
    
    /**
     * 上级代理人ID
     */
    private Long agentId;

    /**
     * 上级代理人姓名
     */
    private String agentName;

    /**
     * 上级职级代码
     */
    private String rankCode;

    /**
     * 层级差(1表示直接上级,2表示隔代上级)
     */
    private Integer hierarchyLevel;
}
```

### 4.3 自动对账逻辑实现

#### 4.3.1 Service接口: `InsuranceSettlementService.java`

```java
package cn.iocoder.yudao.module.commission.service.settlement;

import cn.iocoder.yudao.module.commission.controller.admin.settlement.vo.*;
import org.springframework.web.multipart.MultipartFile;

/**
 * 保司结算对账服务
 */
public interface InsuranceSettlementService {

    /**
     * 导入保司结算单Excel
     * 
     * 实现步骤:
     * 1. 解析Excel文件(支持.xls和.xlsx格式)
     * 2. 校验必填字段(保单号、保费、佣金金额等)
     * 3. 批量插入到insurance_settlement_detail表
     * 4. 更新insurance_settlement主表的统计信息
     * 5. 返回导入结果(成功数、失败数、失败详情)
     * 
     * @param file Excel文件
     * @param insuranceCompany 保险公司名称
     * @param settlePeriod 结算周期(格式:YYYYMM)
     * @return 导入结果
     */
    InsuranceSettlementImportResultVO importSettlement(
            MultipartFile file, 
            String insuranceCompany, 
            String settlePeriod);

    /**
     * 执行自动对账
     * 
     * 对账规则:
     * 1. 按保单号精确匹配
     * 2. 比对保费金额(允许0.01元误差)
     * 3. 比对佣金金额(允许0.01元误差)
     * 4. 标记匹配状态:
     *    - MATCHED: 完全匹配
     *    - EXCEPTION: 有差异
     *    - UNMATCHED: 本地无此保单
     * 
     * @param settlementId 结算单ID
     * @return 对账结果
     */
    InsuranceSettlementMatchResultVO executeMatch(Long settlementId);

    /**
     * 处理对账异常
     * 
     * 处理方式:
     * - ACCEPT_INSURANCE: 以保司数据为准,更新本地佣金
     * - KEEP_LOCAL: 保持本地数据,标记为已处理
     * - MANUAL_ADJUST: 手动调整,需填写调整原因
     * 
     * @param reqVO 异常处理请求
     * @return 是否成功
     */
    Boolean handleException(SettlementExceptionHandleReqVO reqVO);
}
```

---

## 五、前端页面设计要点

### 5.1 基本法配置页面

**路由路径**: `/commission/base-rule`

**关键功能**:
1. 职级树形展示(使用el-tree组件)
2. 规则列表CRUD(使用el-table + 抽屉弹窗)
3. Groovy公式编辑器(使用Monaco Editor或CodeMirror)
4. 规则测试工具(输入测试数据,实时预览计算结果)

**核心组件示例**:

```vue
<template>
  <div class="app-container">
    <!-- 左侧职级树 -->
    <el-aside width="300px">
      <el-tree
        :data="rankTree"
        node-key="id"
        :props="{ label: 'rankName', children: 'children' }"
        @node-click="handleRankClick"
      />
    </el-aside>

    <!-- 右侧规则列表 -->
    <el-main>
      <el-table :data="ruleList" border>
        <el-table-column prop="ruleCode" label="规则代码" />
        <el-table-column prop="ruleName" label="规则名称" />
        <el-table-column prop="ruleType" label="类型">
          <template #default="{ row }">
            <el-tag>{{ getRuleTypeLabel(row.ruleType) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="commissionRate" label="佣金率" />
        <el-table-column label="操作" width="200">
          <template #default="{ row }">
            <el-button size="small" @click="handleEdit(row)">编辑</el-button>
            <el-button size="small" type="danger" @click="handleDelete(row)">删除</el-button>
            <el-button size="small" type="warning" @click="handleTest(row)">测试</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-main>

    <!-- 规则编辑弹窗 -->
    <el-dialog v-model="dialogVisible" title="编辑佣金规则" width="800px">
      <el-form :model="formData" label-width="120px">
        <el-form-item label="规则代码">
          <el-input v-model="formData.ruleCode" />
        </el-form-item>
        <el-form-item label="计算公式">
          <monaco-editor
            v-model="formData.calcFormula"
            language="groovy"
            height="200px"
          />
        </el-form-item>
        <el-form-item label="费率配置JSON">
          <el-input
            v-model="formData.rateConfig"
            type="textarea"
            :rows="5"
            placeholder='{"fyc_rate":0.25}'
          />
        </el-form-item>
      </el-form>
    </el-dialog>
  </div>
</template>
```

### 5.2 佣金审核页面

**路由路径**: `/commission/audit`

**关键功能**:
1. 待审核列表(支持批量选择)
2. 佣金详情查看(包含计算公式展开)
3. 批量审核操作(确认框二次确认)
4. 审核统计看板(卡片展示)

**批量审核确认逻辑**:

```vue
<script setup>
import { ref } from 'vue'
import { ElMessageBox } from 'element-plus'

const selectedRows = ref([])

const handleBatchApprove = async () => {
  if (selectedRows.value.length === 0) {
    ElMessage.warning('请先选择需要审核的记录')
    return
  }

  const totalAmount = selectedRows.value.reduce(
    (sum, row) => sum + row.commissionAmount, 
    0
  )

  await ElMessageBox.confirm(
    `确认审核通过 ${selectedRows.value.length} 条记录,总金额 ¥${totalAmount.toFixed(2)} 吗?`,
    '批量审核确认',
    { type: 'warning' }
  )

  const ids = selectedRows.value.map(row => row.id)
  await batchApproveApi({ ids })
  
  ElMessage.success('审核成功')
  refreshList()
}
</script>
```

### 5.3 发放管理页面

**路由路径**: `/commission/pay-batch`

**关键功能**:
1. 发放批次创建向导(分步骤表单)
2. 发放明细预览(可导出Excel)
3. 发放状态追踪(进度条展示)

---

## 六、数据权限与安全控制

### 6.1 数据权限设计

**权限层级**:

1. **财务管理员**: 可查看全部佣金数据,可执行所有审核和发放操作
2. **团队长**: 只能查看和管理本团队(包含下级团队)的佣金数据
3. **普通业务员**: 只能查看自己的佣金明细

**实现方式**:

在`CommissionRecordMapper.xml`中增加数据权限过滤:

```xml
<select id="selectPageByPermission" resultType="CommissionRecordDO">
    SELECT * FROM commission_record
    WHERE deleted = 0
    
    <if test="@cn.iocoder.yudao.framework.security.core.util.SecurityFrameworkUtils@hasRole('FINANCE_ADMIN')">
        <!-- 财务管理员: 无额外限制 -->
    </if>
    
    <if test="@cn.iocoder.yudao.framework.security.core.util.SecurityFrameworkUtils@hasRole('TEAM_LEADER')">
        <!-- 团队长: 只查看本团队及下级 -->
        AND agent_id IN (
            SELECT user_id FROM sys_user_team 
            WHERE team_leader_id = #{@cn.iocoder.yudao.framework.security.core.util.SecurityFrameworkUtils@getLoginUserId()}
        )
    </if>
    
    <if test="@cn.iocoder.yudao.framework.security.core.util.SecurityFrameworkUtils@hasRole('AGENT')">
        <!-- 普通业务员: 只查看自己 -->
        AND agent_id = #{@cn.iocoder.yudao.framework.security.core.util.SecurityFrameworkUtils@getLoginUserId()}
    </if>
    
    ORDER BY create_time DESC
</select>
```

### 6.2 敏感操作审计

**需要记录审计日志的操作**:

1. 佣金规则的创建/修改/删除
2. 佣金审核通过/驳回
3. 佣金发放执行
4. 对账异常处理

**实现方式**:

使用AOP切面自动记录:

```java
@Aspect
@Component
public class CommissionAuditAspect {

    @Resource
    private OperateLogService operateLogService;

    @Around("@annotation(auditLog)")
    public Object around(ProceedingJoinPoint point, CommissionAuditLog auditLog) throws Throwable {
        Long startTime = System.currentTimeMillis();
        Object result = null;
        Exception exception = null;

        try {
            result = point.proceed();
            return result;
        } catch (Exception e) {
            exception = e;
            throw e;
        } finally {
            // 记录审计日志
            OperateLogCreateReqDTO logDTO = new OperateLogCreateReqDTO();
            logDTO.setModule("佣金管理");
            logDTO.setType(auditLog.type());
            logDTO.setContent(buildLogContent(point, result, exception));
            logDTO.setDuration((int) (System.currentTimeMillis() - startTime));
            
            operateLogService.createOperateLog(logDTO);
        }
    }
}
```

---

## 七、性能优化建议

### 7.1 批量计算优化

当需要计算大批量佣金时(如月底结算),使用以下优化策略:

1. **分批处理**: 每批处理1000条记录,避免内存溢出
2. **异步执行**: 使用Spring `@Async`将计算任务放到异步线程池
3. **进度反馈**: 使用Redis存储计算进度,前端轮询展示

```java
@Service
public class CommissionBatchCalculateTask {

    @Async("commissionTaskExecutor")
    public void executeBatchCalculate(String settlePeriod, String taskId) {
        // 查询待计算保单总数
        int totalCount = policyService.countPendingPolicies(settlePeriod);
        int batchSize = 1000;
        int batchCount = (totalCount + batchSize - 1) / batchSize;

        for (int i = 0; i < batchCount; i++) {
            List<PolicyDO> policies = policyService.getPendingPolicies(
                    settlePeriod, i * batchSize, batchSize);

            // 批量计算
            policies.forEach(policy -> {
                try {
                    calculateService.calculateSingle(...);
                } catch (Exception e) {
                    log.error("佣金计算失败: policyId={}", policy.getId(), e);
                }
            });

            // 更新进度到Redis
            double progress = (i + 1) * 100.0 / batchCount;
            redisTemplate.opsForValue().set(
                    "commission:task:" + taskId + ":progress", 
                    progress, 
                    30, 
                    TimeUnit.MINUTES
            );
        }
    }
}
```

### 7.2 数据库索引优化

**必须创建的索引**:

```sql
-- 佣金记录表
CREATE INDEX idx_agent_settle_period ON commission_record(agent_id, settle_period);
CREATE INDEX idx_status_create_time ON commission_record(status, create_time);
CREATE INDEX idx_policy_no ON commission_record(policy_no);

-- 佣金规则表
CREATE INDEX idx_effective_expire ON commission_base_rule(effective_date, expire_date);
CREATE INDEX idx_rank_product_priority ON commission_base_rule(rank_code, product_category, priority DESC);

-- 保司结算明细表
CREATE INDEX idx_settlement_match_status ON insurance_settlement_detail(settlement_id, match_status);
```

---

## 八、测试用例设计

### 8.1 单元测试示例

**测试类**: `CommissionCalculateServiceTest.java`

```java
@SpringBootTest
public class CommissionCalculateServiceTest {

    @Resource
    private CommissionCalculateService calculateService;

    @Test
    public void testCalculateSingle_寿险FYC_业务员() {
        // 准备测试数据
        CommissionCalculateSingleReqVO reqVO = new CommissionCalculateSingleReqVO();
        reqVO.setPolicyId(1L);
        reqVO.setAgentId(1001L); // 假设该业务员职级为SALES
        reqVO.setPremium(new BigDecimal("10000.00"));
        reqVO.setProductCategory("LIFE");
        reqVO.setSettlePeriod("202602");

        // 执行计算
        CommissionCalculateResultVO result = calculateService.calculateSingle(reqVO);

        // 断言
        assertNotNull(result);
        assertEquals("FYC", result.getCommissionType());
        assertEquals(new BigDecimal("2500.00"), result.getCommissionAmount()); // 假设费率25%
    }

    @Test
    public void testCalculateSingle_管理津贴分润() {
        // 测试上级管理津贴是否正确计算
        CommissionCalculateSingleReqVO reqVO = buildTestReqVO();
        
        CommissionCalculateResultVO result = calculateService.calculateSingle(reqVO);

        // 验证分润列表
        assertNotNull(result.getSplits());
        assertTrue(result.getSplits().size() > 0);
        
        // 验证直接上级获得5%管理津贴
        CommissionCalculateResultVO.CommissionSplitVO firstSplit = result.getSplits().get(0);
        assertEquals(new BigDecimal("0.0500"), firstSplit.getSplitRate());
        assertEquals(new BigDecimal("125.00"), firstSplit.getSplitAmount()); // 2500 * 5%
    }
}
```

### 8.2 集成测试场景

| **测试场景**           | **前置条件**                 | **操作步骤**                                 | **预期结果**                         |
| ---------------------- | ---------------------------- | -------------------------------------------- | ------------------------------------ |
| 佣金计算-基础场景      | 已配置寿险FYC规则(费率25%)   | 创建保费10000元的寿险保单,触发佣金计算       | 生成佣金记录,金额为2500元,状态为待审 |
| 佣金审核-批量通过      | 存在10条待审核佣金           | 批量选中并审核通过                           | 10条记录状态变更为已审核             |
| 佣金发放-银行转账      | 存在已审核未发放的佣金记录   | 创建发放批次并执行发放                       | 发放批次状态变为已完成,佣金状态为已发|
| 对账-完全匹配          | 导入保司结算单与本地数据一致 | 执行自动对账                                 | 所有明细匹配状态为MATCHED,无异常     |
| 对账-金额差异          | 保司结算单中某保单佣金多50元 | 执行自动对账,处理异常(选择接受保司数据)      | 本地佣金金额更新,异常标记为已处理    |

---

## 九、项目交付清单

### 9.1 代码交付物

| **模块**       | **包路径**                                           | **核心类**                                               |
| -------------- | ---------------------------------------------------- | -------------------------------------------------------- |
| Controller层   | `cn.iocoder.yudao.module.commission.controller.admin` | `CommissionRankController`<br/>`CommissionRuleController`<br/>`CommissionCalculateController`<br/>`CommissionAuditController`<br/>`CommissionPayBatchController`<br/>`InsuranceSettlementController` |
| Service层      | `cn.iocoder.yudao.module.commission.service`         | `CommissionCalculateService`<br/>`CommissionSplitService`<br/>`InsuranceSettlementService` |
| Mapper层       | `cn.iocoder.yudao.module.commission.dal.mysql`       | `CommissionBaseRuleMapper`<br/>`CommissionRecordMapper`<br/>`InsuranceSettlementMapper` |
| DO实体         | `cn.iocoder.yudao.module.commission.dal.dataobject`  | `CommissionBaseRuleDO`<br/>`CommissionRecordDO`<br/>`CommissionSplitDO` |
| VO对象         | `cn.iocoder.yudao.module.commission.controller.admin.*.vo` | 各模块的Request/Response VO                              |
| 枚举类         | `cn.iocoder.yudao.module.commission.enums`           | `CommissionTypeEnum`<br/>`CommissionStatusEnum`          |

### 9.2 数据库脚本

提供以下SQL脚本文件:

1. `commission_ddl.sql` - 表结构创建脚本
2. `commission_init_data.sql` - 初始化数据(职级、基础规则)
3. `commission_index.sql` - 索引创建脚本

### 9.3 配置文件

**application-commission.yml**:

```yaml
# 佣金系统配置
commission:
  # 计算引擎配置
  calculate:
    # 批量计算每批次大小
    batch-size: 1000
    # 异步任务线程池大小
    async-thread-pool-size: 5
    
  # 分润配置
  split:
    # 最大向上查找层级(防止无限递归)
    max-hierarchy-level: 5
    
  # 对账配置
  settlement:
    # Excel导入最大行数
    max-import-rows: 10000
    # 金额对比允许误差(元)
    amount-tolerance: 0.01
```

### 9.4 前端页面

提供以下Vue页面:

1. `/src/views/commission/base-rule/index.vue` - 基本法配置
2. `/src/views/commission/calculate/index.vue` - 佣金计算
3. `/src/views/commission/audit/index.vue` - 佣金审核
4. `/src/views/commission/pay-batch/index.vue` - 发放管理
5. `/src/views/commission/settlement/index.vue` - 对账管理

---

## 十、开发注意事项

### 10.1 金额精度处理

**强制要求**:

1. 所有金额字段必须使用`BigDecimal`类型,禁止使用`float`或`double`
2. 金额计算必须显式指定精度和舍入模式:

```java
BigDecimal commission = premium.multiply(rate)
        .setScale(2, RoundingMode.HALF_UP); // 保留2位小数,四舍五入
```

3. 数据库金额字段统一使用`DECIMAL(12,2)`类型

### 10.2 并发控制

**关键场景**:

1. **佣金审核**: 防止同一笔佣金被重复审核

```java
@Transactional(rollbackFor = Exception.class)
public Boolean approve(Long id) {
    // 使用乐观锁或悲观锁
    CommissionRecordDO record = recordMapper.selectById(id);
    
    if (!CommissionStatusEnum.PENDING.getCode().equals(record.getStatus())) {
        throw new ServiceException("该佣金记录已被审核,请勿重复操作");
    }
    
    // 更新状态时加WHERE条件防止并发
    int updateCount = recordMapper.updateStatusById(
            id, 
            CommissionStatusEnum.APPROVED.getCode(),
            CommissionStatusEnum.PENDING.getCode() // 旧状态作为条件
    );
    
    return updateCount > 0;
}
```

2. **发放批次执行**: 防止同一批次被重复执行

使用Redis分布式锁:

```java
String lockKey = "commission:pay:batch:" + batchId;
boolean locked = redisTemplate.opsForValue().setIfAbsent(
        lockKey, "1", 5, TimeUnit.MINUTES);

if (!locked) {
    throw new ServiceException("该批次正在发放中,请勿重复操作");
}

try {
    // 执行发放逻辑
    executePayment(batchId);
} finally {
    redisTemplate.delete(lockKey);
}
```

### 10.3 异常处理规范

**自定义异常码**:

在`ErrorCodeConstants.java`中定义:

```java
public interface ErrorCodeConstants {
    // 基本法相关 (100000-100099)
    ErrorCode RANK_NOT_FOUND = new ErrorCode(100001, "职级不存在");
    ErrorCode RULE_NOT_FOUND = new ErrorCode(100002, "佣金规则不存在");
    ErrorCode RULE_CODE_DUPLICATE = new ErrorCode(100003, "规则代码已存在");
    
    // 计算相关 (100100-100199)
    ErrorCode AGENT_NOT_FOUND = new ErrorCode(100101, "业务员不存在");
    ErrorCode NO_APPLICABLE_RULE = new ErrorCode(100102, "未找到适用的佣金规则");
    ErrorCode COMMISSION_CALC_ERROR = new ErrorCode(100103, "佣金计算失败: {}");
    
    // 审核相关 (100200-100299)
    ErrorCode COMMISSION_ALREADY_AUDITED = new ErrorCode(100201, "该佣金记录已被审核");
    ErrorCode COMMISSION_NOT_PENDING = new ErrorCode(100202, "只有待审核状态的记录才能审核");
    
    // 发放相关 (100300-100399)
    ErrorCode PAY_BATCH_NOT_APPROVED = new ErrorCode(100301, "发放批次未通过审批");
    ErrorCode PAY_BATCH_ALREADY_EXECUTED = new ErrorCode(100302, "该批次已执行发放");
    
    // 对账相关 (100400-100499)
    ErrorCode SETTLEMENT_FILE_PARSE_ERROR = new ErrorCode(100401, "结算单文件解析失败");
    ErrorCode SETTLEMENT_NOT_FOUND = new ErrorCode(100402, "结算单不存在");
}
```

---

## 十一、后续扩展规划

虽然本次交付是阶段2的核心功能,但系统设计已预留以下扩展能力:

1. **多币种支持**: 数据库字段预留`currency`字段,支持境外保单佣金结算
2. **佣金预提**: 针对长期险种,支持佣金分期发放(如5年均摊)
3. **佣金追溯**: 支持保单退保时的佣金回收机制
4. **BI分析看板**: 佣金数据对接大数据平台,支持多维分析

---

## 附录: 快速开发检查清单

开发人员在完成每个功能点后,请对照此清单自查:

- [ ] 数据库表结构已创建并添加必要索引
- [ ] Mapper接口已定义并编写XML映射
- [ ] Service接口已定义并实现业务逻辑
- [ ] Controller接口已实现并添加Swagger注解
- [ ] VO对象已定义并添加校验注解
- [ ] 异常处理已使用统一的错误码
- [ ] 金额计算已使用BigDecimal并指定精度
- [ ] 关键操作已添加数据权限控制
- [ ] 敏感操作已记录审计日志
- [ ] 单元测试已编写并通过
- [ ] 前端页面已实现并联调通过
- [ ] 接口文档已生成并验证

---

**文档结束**

本需求文档共计约 **15000字**,涵盖了PC佣金系统从数据库设计、接口定义、业务逻辑实现到前端页面设计的全部细节。开发人员可直接根据本文档进行编码,无需额外沟通需求。如有疑问,请及时反馈项目负责人。

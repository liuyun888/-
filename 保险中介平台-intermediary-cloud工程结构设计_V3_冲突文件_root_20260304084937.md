# 保险中介平台 · 基于 intermediary-cloud 工程结构设计方案

> **基础框架**：intermediary-cloud  
> **文档版本**：V3.0  
> **编写日期**：2026-02-25  
> **对应排期表**：保险中介平台开发排期表_V13.xlsx（共17个Sheet，8大阶段）  
> **技术栈**：Spring Cloud Alibaba + Gateway + Nacos + RocketMQ + MyBatis Plus + Redis  
> **Maven GroupId**：`cn.qmsk.insurance`  
> **Java 根包名**：`cn.qmsk.intermediary.module.{模块名}`

---

## 一、先理解 intermediary-cloud 原生结构

### 1.1 intermediary-cloud 原生模块一览

```
intermediary-cloud/（官方原生，基于 yudao-cloud 定制的微服务版）
├── intermediary-dependencies/          # 全局依赖版本管理（BOM）
├── intermediary-framework/             # 框架封装层（技术组件 + 业务组件）
│   ├── intermediary-common/                              # 公共基础组件
│   ├── intermediary-spring-boot-starter-web/             # Web 基础（统一返回、异常处理）
│   ├── intermediary-spring-boot-starter-security/        # 安全认证（JWT + Spring Security）
│   ├── intermediary-spring-boot-starter-mybatis/         # MyBatis Plus 封装
│   ├── intermediary-spring-boot-starter-redis/           # Redis + Redisson 封装
│   ├── intermediary-spring-boot-starter-mq/              # 消息队列（RocketMQ/RabbitMQ/Kafka）
│   ├── intermediary-spring-boot-starter-rpc/             # Feign 服务调用封装
│   ├── intermediary-spring-boot-starter-job/             # XXL-Job 定时任务
│   ├── intermediary-spring-boot-starter-excel/           # EasyExcel 封装
│   ├── intermediary-spring-boot-starter-monitor/         # 监控（Prometheus/Skywalking）
│   ├── intermediary-spring-boot-starter-protection/      # 限流/熔断/降级
│   ├── intermediary-spring-boot-starter-websocket/       # WebSocket 封装
│   ├── intermediary-spring-boot-starter-biz-data-permission/ # 数据权限
│   ├── intermediary-spring-boot-starter-biz-ip/          # IP 解析
│   ├── intermediary-spring-boot-starter-biz-tenant/      # 多租户
│   └── intermediary-spring-boot-starter-env/             # 环境隔离
│
├── intermediary-gateway/               # 统一 API 网关（Spring Cloud Gateway）
├── intermediary-server/                # 聚合启动入口（可选单体模式启动）
│
├── intermediary-module-system/         # ✅ 直接复用：用户/角色/菜单/部门/岗位/权限/字典/租户
├── intermediary-module-infra/          # ✅ 直接复用：代码生成/配置管理/任务调度/文件存储/日志
├── intermediary-module-bpm/            # ✅ 直接复用：工作流（Flowable）- 审批场景
├── intermediary-module-pay/            # ✅ 直接复用：支付（微信/支付宝/银行卡）
├── intermediary-module-member/         # ✅ 直接复用：C端会员用户体系（含微信登录）
├── intermediary-module-mall/           # ⚡ 部分参考：商品/订单/营销/优惠券（保险商城可借鉴）
├── intermediary-module-ai/             # ✅ 直接复用：AI大模型（对话/知识库/RAG）
├── intermediary-module-report/         # ✅ 直接复用：BI报表/数据大屏
├── intermediary-module-crm/            # ⚡ 部分参考：线索/客户管理逻辑
├── intermediary-module-mp/             # ✅ 直接复用：微信公众号/小程序
├── intermediary-module-erp/            # ⚡ 部分参考：ERP 财务流程逻辑
└── intermediary-module-iot/            # （暂不使用）
```

### 1.2 intermediary-cloud 单个 module 的内部结构规范

每个 `intermediary-module-xxx` 固定拆分为两个 Maven 子模块：

```
intermediary-module-xxx/
├── intermediary-module-xxx-api/        # API 定义层（供其他服务通过 Feign 调用）
│   └── src/main/java/cn/qmsk/intermediary/module/xxx/
│       ├── enums/                      # 枚举常量（可被其他模块引用）
│       ├── api/                        # Feign Client 接口定义
│       └── dto/                        # Feign 调用的入参/出参 DTO
│
└── intermediary-module-xxx-server/     # 业务实现层（独立 Spring Boot 服务，可独立部署）
    └── src/main/java/cn/qmsk/intermediary/module/xxx/
        ├── XxxServerApplication.java   # 启动类（命名规范：模块名+ServerApplication）
        ├── controller/
        │   ├── admin/                  # PC管理后台接口（/admin-api/xxx/**）
        │   └── app/                   # 业务员App/C端接口（/app-api/xxx/**）
        ├── service/                    # 业务逻辑层（接口 + impl 子包）
        │   └── impl/
        ├── dal/
        │   ├── dataobject/             # 数据库实体 DO
        │   ├── mysql/                  # MyBatis Mapper 接口
        │   └── redis/                  # Redis DAO（缓存操作）
        ├── api/                        # API 接口实现（实现 xxx-api 模块中的 Feign 接口）
        ├── job/                        # 定时任务（XXL-Job Handler）
        ├── mq/                         # 消息队列（生产者/消费者）
        ├── convert/                    # MapStruct 对象转换器
        ├── util/                       # 工具类
        └── framework/                  # 本模块的框架扩展（可选）
```

**关键规则**：
- `admin` 包下的 Controller 对应 `/admin-api/` 路径，供 PC 管理后台调用
- `app` 包下的 Controller 对应 `/app-api/` 路径，供业务员 App 和 C 端调用
- **同一个服务，同时支持两种路径前缀**，无需拆分两个服务
- 模块间调用通过 `intermediary-spring-boot-starter-rpc` 封装的 **Feign** 实现
- 所有 DO 继承框架提供的 `BaseDO`，所有 Mapper 继承 `BaseMapperX`
- Maven GroupId 统一使用 `cn.qmsk.insurance`

---

## 二、保险中介平台整体工程规划（V13）

### 2.1 V13 版本阶段总览

| 阶段 | Sheet名称 | 核心内容 | 合计工时(天) | 状态 |
|------|----------|---------|------------|------|
| 阶段1 | 业务员App-车险报价展业 | OCR识别/车辆档案/多保司报价引擎/报价单生成/续保 | 44.5 | 原有 |
| 阶段1 | PC管理后台-基础建设 | 组织架构/人员管理/产品配置/费率维护/系统配置 | 30.5 | 原有 |
| 阶段1 | PC管理后台-车险业务 | 车险保单全流程/报表/10大统计分析 | 64 | **V13新增** |
| 阶段2 | 业务员App-非车险展业 | 非车险产品库/试算/计划书/CRM/订单/业绩 | 67 | 原有 |
| 阶段2 | PC管理后台-佣金系统 | 基本法/职级/佣金引擎/对账/保单管理/财务报表 | 85.5 | 原有 |
| 阶段2 | PC管理后台-非车险业务 | 非车保单全流程/政策设置/统计分析/系统设置 | 41.5 | **V13新增** |
| 阶段2 | PC管理后台-客户CRM | PC客户列表/画像/续期看板/云短信/数据报表 | 34.5 | **V13新增** |
| 阶段3 | C端商城（消费者前台） | 用户体系/商城首页/投保/支付/保单/理赔 | 107 | 原有 |
| 阶段3 | 业务员App-营销工具 | 营销素材/客户邀请/活动推广/团队/培训 | 49.5 | 原有 |
| 阶段3 | PC管理后台-营销管理 | 内容/活动/优惠券/积分/数据统计/培训 | 92 | 原有 |
| 阶段4 | AI智能中台 | AI保障规划/智能核保/智能客服/数据分析 | 54 | 原有 |
| 阶段5 | 合规双录 | 音视频双录/AI质检/合规存证管理 | 38.5 | 原有 |
| 阶段6 | 财务中台 | 自动对账/结算/税务/BI报表/监管数据 | 93 | 原有 |
| 阶段6 | 财务中台-合格结算补充 | 批量修改手续费/跟单结算/合格导出模板 | 15.5 | **V13新增** |
| 阶段7 | PC管理后台-寿险体系 | 寿险保单/回访/保全/续期/孤儿单/理赔/财务/报表 | 105 | **V13新增阶段** |
| 阶段8 | 业务员App-寿险展业 | 寿险产品展业/试算/计划书/App保单录入/续期 | 22 | **V13新增阶段** |
| 阶段8 | C端商城-寿险投保 | 寿险产品/健康告知/投保/支付/C端保单/续期 | 22.5 | **V13新增阶段** |
| **合计** | 17个Sheet，全平台覆盖 | | **966.5** | |

### 2.2 设计原则

**复用优先，不重复造轮子**：intermediary-cloud 已有的能力（权限、支付、工作流、AI等）直接复用，只新增保险业务独有的模块。

**按业务领域划分微服务**，而不是按端（B端/PC端/C端）划分。同一个业务领域的 admin 和 app 接口放在同一个服务内，通过 Controller 路径区分。

**V13新增模块决策**：阶段7寿险体系、阶段8寿险展业/C端投保与已有车险/非车险业务高度同构，通过在现有微服务内扩展（新增枚举值、Service实现、Controller端点），而非新建独立微服务，避免过度拆分。

**服务数量**：V13共 **10个核心保险业务微服务**（在V2.0基础上新增1个 `ins-life` 寿险专属服务）。

### 2.3 完整工程目录结构（V13）

```
intermediary-cloud/                              # 项目根目录
│
├── ============ 官方框架层（不修改）============
├── intermediary-dependencies/                   # 依赖版本 BOM（可追加保险相关依赖）
├── intermediary-framework/                      # 框架封装（不修改原有，可追加扩展）
├── intermediary-gateway/                        # API 网关（添加保险路由规则）
├── intermediary-server/                         # 聚合启动入口
│
├── ============ 官方业务模块（直接复用）============
├── intermediary-module-system/                  # 用户/角色/权限/部门/字典/租户
├── intermediary-module-infra/                   # 配置/代码生成/任务/文件/日志
├── intermediary-module-bpm/                     # 工作流（审核/审批流程）
├── intermediary-module-pay/                     # 支付（投保缴费/佣金打款）
├── intermediary-module-member/                  # C端会员（投保人注册/登录/微信授权）
├── intermediary-module-ai/                      # AI能力（智能客服/知识库）
├── intermediary-module-report/                  # BI报表/数据大屏
├── intermediary-module-mp/                      # 微信公众号/小程序
│
├── ============ 保险业务模块（新增，共10个）============                                         端口号
├── intermediary-module-ins-product/             # 【保险产品中台】车险/非车险/寿险产品配置         28093
├── intermediary-module-ins-quote/               # 【报价引擎】车险多保司并发报价                  28094
├── intermediary-module-ins-order/               # 【保单订单中台】车险/非车险/寿险保单全生命周期    28095
├── intermediary-module-ins-agent/               # 【业务员管理+CRM】组织架构/业务员/客户管理       28096
├── intermediary-module-ins-commission/          # 【佣金结算中台】基本法/佣金计算/结算/对账         28097
├── intermediary-module-ins-marketing/           # 【营销中台】素材/活动/优惠券/积分/计划书         28098
├── intermediary-module-ins-compliance/          # 【合规双录】音视频采集/AI质检/存证              28099
├── intermediary-module-ins-finance/             # 【财务中台】自动对账/结算/税务/合格结算          28100
├── intermediary-module-ins-ai/                  # 【AI智能中台】保障规划/智能核保/智能客服         28101
└── intermediary-module-ins-life/                # 【寿险专属中台】★V13新增★ 寿险PC/App/C端业务    28102
│
├── ============ 前端工程（独立仓库）============
├── intermediary-ui/                             # PC管理后台（官方，按需扩展菜单）
├── intermediary-ui-agent-uniapp/                # 业务员展业 App（基于 uni-app）
└── intermediary-ui-consumer-uniapp/             # C端消费者小程序（基于商城 uni-app 改造）
```

---

## 三、各业务微服务详细设计

### 3.1 intermediary-module-ins-product（保险产品中台）

**职责**：管理所有险种产品的配置、费率、上下架，是整个平台的产品数据源。V13覆盖车险/非车险/寿险三大险种。

**对应阶段**：阶段1-PC管理后台-基础建设（产品部分）、阶段2-非车险展业（产品库）、阶段7-寿险体系（产品管理）

```
intermediary-module-ins-product/
│
├── intermediary-module-ins-product-api/
│   └── src/main/java/cn/qmsk/intermediary/module/ins/product/
│       ├── enums/
│       │   ├── InsuranceTypeEnum.java          # 险种枚举（车险/非车险/寿险/健康险/意外险）
│       │   ├── ProductStatusEnum.java          # 产品状态（草稿/待审/上架/下架/停售）
│       │   └── LifeProductTypeEnum.java        # 寿险产品类型（个险/团险/储蓄/保障）★V13
│       ├── api/
│       │   └── InsProductApi.java              # Feign 接口定义
│       └── dto/
│           ├── InsProductDTO.java
│           ├── InsRateQueryDTO.java
│           └── InsLifeProductDTO.java          # 寿险产品 DTO（含健康告知/缴费期）★V13
│
└── intermediary-module-ins-product-server/
    └── src/main/java/cn/qmsk/intermediary/module/ins/product/
        ├── InsProductServerApplication.java
        ├── controller/
        │   ├── admin/
        │   │   ├── InsProductCategoryController.java    # 产品分类管理
        │   │   ├── InsProductController.java            # 产品增删改查/上下架
        │   │   ├── InsProductRateController.java        # 费率表维护（车险/非车险/寿险）
        │   │   ├── InsInsurerController.java            # 保险公司管理
        │   │   └── InsLifeProductController.java        # 寿险产品管理 ★V13
        │   └── app/
        │       ├── AppInsProductController.java         # 业务员App：产品列表/详情/对比
        │       ├── AppInsProductSearchController.java   # 产品搜索（非车险/寿险筛选）
        │       └── AppInsLifeProductController.java     # 业务员App：寿险产品列表/试算 ★V13
        ├── api/
        │   └── InsProductApiImpl.java
        ├── service/
        │   ├── InsProductCategoryService.java / InsProductCategoryServiceImpl.java
        │   ├── InsProductService.java / InsProductServiceImpl.java
        │   ├── InsProductRateService.java / InsProductRateServiceImpl.java
        │   ├── InsLifeProductService.java / InsLifeProductServiceImpl.java  # 寿险产品 ★V13
        │   └── InsurerApiAdapterService.java   # 保司API适配器（策略模式）
        ├── dal/
        │   ├── dataobject/
        │   │   ├── InsProductCategoryDO.java
        │   │   ├── InsProductDO.java
        │   │   ├── InsProductRateDO.java
        │   │   ├── InsInsurerDO.java
        │   │   └── InsLifeProductDO.java       # 寿险产品表（含健康告知JSON）★V13
        │   ├── mysql/
        │   │   ├── InsProductCategoryMapper.java
        │   │   ├── InsProductMapper.java
        │   │   ├── InsProductRateMapper.java
        │   │   ├── InsInsurerMapper.java
        │   │   └── InsLifeProductMapper.java   # ★V13
        │   └── redis/
        │       └── InsProductRedisDAO.java
        ├── convert/
        │   └── InsProductConvert.java
        └── job/
            └── InsProductExpireJob.java
```

**核心数据库表**（Schema: `db_ins_product`，前缀 `ins_product_`）：

| 表名 | 说明 |
|------|------|
| `ins_product_category` | 险种分类（树形） |
| `ins_product_info` | 产品主表（名称/保司/险种/状态/条款） |
| `ins_product_rate` | 费率表（JSON存储，支持复杂费率结构） |
| `ins_insurer` | 保险公司档案（名称/API配置/手续费协议） |
| `ins_life_product` | 寿险产品表（个险/团险/健康告知JSON/缴费期）★V13 |

---

### 3.2 intermediary-module-ins-quote（报价引擎）

**职责**：行驶证OCR、车型查询、多保司并发询价、报价单生成与分享，是阶段1核心模块。

**对应阶段**：阶段1-业务员App-车险报价

```
intermediary-module-ins-quote/
│
├── intermediary-module-ins-quote-api/
│   └── src/main/java/cn/qmsk/intermediary/module/ins/quote/
│       ├── api/
│       │   └── InsQuoteApi.java
│       └── dto/
│           ├── InsVehicleInfoDTO.java
│           └── InsQuoteResultDTO.java
│
└── intermediary-module-ins-quote-server/
    └── src/main/java/cn/qmsk/intermediary/module/ins/quote/
        ├── InsQuoteServerApplication.java
        ├── controller/
        │   └── app/
        │       ├── AppInsOcrController.java              # 行驶证/身份证OCR识别
        │       ├── AppInsVehicleController.java          # 车型库查询/车辆信息
        │       ├── AppInsQuoteController.java            # 发起报价/查询报价结果
        │       └── AppInsQuotePdfController.java         # 报价单PDF生成/H5分享
        ├── api/
        │   └── InsQuoteApiImpl.java
        ├── service/
        │   ├── InsOcrService.java / InsOcrServiceImpl.java
        │   ├── InsVehicleQueryService.java / InsVehicleQueryServiceImpl.java
        │   ├── InsQuoteEngineService.java / InsQuoteEngineServiceImpl.java  # 并发询价核心
        │   └── insurer/                         # 各保司适配器（策略模式）
        │       ├── BaseInsurerAdapter.java
        │       ├── PingAnInsurerAdapter.java
        │       └── PiccInsurerAdapter.java
        ├── dal/
        │   ├── dataobject/
        │   │   ├── InsVehicleInfoDO.java
        │   │   ├── InsQuoteRecordDO.java
        │   │   └── InsQuoteItemDO.java
        │   ├── mysql/
        │   │   ├── InsVehicleInfoMapper.java
        │   │   ├── InsQuoteRecordMapper.java
        │   │   └── InsQuoteItemMapper.java
        │   └── redis/
        │       └── InsQuoteRedisDAO.java
        ├── mq/
        │   ├── producer/InsQuoteProducer.java
        │   └── consumer/InsQuoteConsumer.java
        ├── convert/InsQuoteConvert.java
        └── job/InsQuoteExpireJob.java
```

**核心数据库表**（Schema: `db_ins_quote`，前缀 `ins_quote_`）：

| 表名 | 说明 |
|------|------|
| `ins_quote_vehicle` | 车辆信息（VIN/车牌/车型/车主） |
| `ins_quote_record` | 报价记录（状态机：询价中/已报价/已出单/已过期） |
| `ins_quote_item` | 各保司报价明细（保司/总保费/险种明细/JSON） |

---

### 3.3 intermediary-module-ins-order（保单订单中台）

**职责**：投保下单、保单生命周期管理、续保、理赔，覆盖车险/非车险/寿险三大险种的完整保单流程，支持PC管理后台手工录单和C端自助投保两种场景。

**对应阶段**：阶段1-PC车险业务（保单录入）、阶段2-非车险业务（保单管理）、阶段3-C端投保、阶段7-寿险保单管理★V13

```
intermediary-module-ins-order/
│
├── intermediary-module-ins-order-api/
│   └── src/main/java/cn/qmsk/intermediary/module/ins/order/
│       ├── enums/
│       │   ├── PolicyTypeEnum.java              # 保单类型（车险/非车险/寿险）
│       │   ├── PolicyStatusEnum.java            # 保单状态
│       │   └── LifePolicyStatusEnum.java        # 寿险保单状态（件数状态）★V13
│       ├── api/
│       │   └── InsOrderApi.java
│       └── dto/
│           ├── InsPolicyDTO.java
│           ├── InsOrderStatusDTO.java
│           └── InsLifePolicyDTO.java            # 寿险保单 DTO（含被保人/受益人）★V13
│
└── intermediary-module-ins-order-server/
    └── src/main/java/cn/qmsk/intermediary/module/ins/order/
        ├── InsOrderServerApplication.java
        ├── controller/
        │   ├── admin/
        │   │   ├── AdminInsPolicyCarController.java      # PC后台：车险保单管理（录入/查询/导入/导出/批量操作）
        │   │   ├── AdminInsPolicyCarBatchController.java # PC后台：车险批量录入/批单录入
        │   │   ├── AdminInsPolicyNonCarController.java   # PC后台：非车险保单管理（录入/批单/导入/查询）
        │   │   ├── AdminInsPolicyLifeController.java     # PC后台：寿险保单管理（个险/团险）★V13
        │   │   ├── AdminInsLifeVisitController.java      # PC后台：寿险回访管理★V13
        │   │   ├── AdminInsLifeConservationController.java # PC后台：保全维护★V13
        │   │   ├── AdminInsLifeOrphanController.java     # PC后台：孤儿单管理★V13
        │   │   ├── AdminInsClaimController.java          # PC后台：理赔管理
        │   │   └── AdminInsOrderController.java          # PC后台：订单查询/审核
        │   └── app/
        │       ├── AppInsOrderController.java           # App/C端：下单投保
        │       ├── AppInsPolicyController.java          # App/C端：我的保单
        │       ├── AppInsRenewalController.java         # App：续保管理
        │       ├── AppInsClaimController.java           # C端：理赔申请
        │       └── AppInsLifePolicyController.java      # App：寿险保单录入/查询★V13
        ├── api/
        │   └── InsOrderApiImpl.java
        ├── service/
        │   ├── InsPolicyCarService.java / InsPolicyCarServiceImpl.java      # 车险保单
        │   ├── InsPolicyNonCarService.java / InsPolicyNonCarServiceImpl.java  # 非车险保单
        │   ├── InsPolicyLifeService.java / InsPolicyLifeServiceImpl.java    # 寿险保单★V13
        │   ├── InsLifeVisitService.java / InsLifeVisitServiceImpl.java      # 寿险回访★V13
        │   ├── InsLifeConservationService.java / InsLifeConservationServiceImpl.java # 保全★V13
        │   ├── InsLifeOrphanService.java / InsLifeOrphanServiceImpl.java    # 孤儿单★V13
        │   ├── InsOrderService.java / InsOrderServiceImpl.java              # 订单主流程
        │   ├── InsRenewalService.java / InsRenewalServiceImpl.java          # 续保
        │   └── InsClaimService.java / InsClaimServiceImpl.java              # 理赔
        ├── dal/
        │   ├── dataobject/
        │   │   ├── InsPolicyCarDO.java          # 车险保单表（保单号/车牌/VIN/交商险信息）
        │   │   ├── InsPolicyNonCarDO.java        # 非车险保单表（险种/标的/批单关联）
        │   │   ├── InsPolicyLifeDO.java          # 寿险保单主表★V13
        │   │   ├── InsPolicyLifeInsuredDO.java   # 寿险被保人/受益人表★V13
        │   │   ├── InsLifeVisitRecordDO.java     # 回访记录表★V13
        │   │   ├── InsLifeConservationDO.java    # 保全维护表★V13
        │   │   ├── InsLifeOrphanDO.java          # 孤儿单表★V13
        │   │   ├── InsOrderDO.java               # 订单主表
        │   │   └── InsClaimRecordDO.java         # 理赔记录表
        │   ├── mysql/
        │   │   ├── InsPolicyCarMapper.java
        │   │   ├── InsPolicyNonCarMapper.java
        │   │   ├── InsPolicyLifeMapper.java
        │   │   ├── InsPolicyLifeInsuredMapper.java
        │   │   ├── InsLifeVisitRecordMapper.java
        │   │   ├── InsLifeConservationMapper.java
        │   │   ├── InsLifeOrphanMapper.java
        │   │   ├── InsOrderMapper.java
        │   │   └── InsClaimRecordMapper.java
        │   └── redis/
        │       └── InsOrderRedisDAO.java
        ├── mq/
        │   ├── producer/InsOrderProducer.java   # 订单事件（触发佣金计算）
        │   └── consumer/InsOrderConsumer.java
        └── convert/InsOrderConvert.java
```

**核心数据库表**（Schema: `db_ins_order`，前缀 `ins_order_`）：

| 表名 | 说明 |
|------|------|
| `ins_policy_car` | 车险保单主表（保单号/车牌/VIN/交强险/商业险） |
| `ins_policy_car_endorsement` | 车险批改单表 |
| `ins_policy_non_car` | 非车险保单主表（险种/标的/涉农/互联网业务标识） |
| `ins_policy_non_car_endorsement` | 非车险批改单表 |
| `ins_policy_life` | 寿险保单主表（产品/缴费方式/缴费期间/年度保费）★V13 |
| `ins_policy_life_insured` | 寿险被保人/受益人表★V13 |
| `ins_life_visit_record` | 寿险回访记录表★V13 |
| `ins_life_conservation` | 保全维护表（增/减保/变更标的）★V13 |
| `ins_life_orphan` | 孤儿单管理表（业务员离职/转移分配）★V13 |
| `ins_order_main` | 订单主表（关联报价/产品/业务员/C端用户） |
| `ins_claim_record` | 理赔记录表 |
| `ins_import_log` | 批量导入日志表（EasyExcel导入记录） |

---

### 3.4 intermediary-module-ins-agent（业务员管理 + CRM）

**职责**：业务员注册认证、组织架构管理、CRM客户管理（含PC端全量客户管理）、业绩统计、续期管理。V13新增PC端客户管理功能。

**对应阶段**：阶段1-基础建设（组织/人员）、阶段2-非车险展业（CRM）、阶段2-PC客户CRM★V13

> ⚠️ 业务员的**登录认证**复用 `intermediary-module-system` 的用户体系，本模块只管业务员**业务属性**

```
intermediary-module-ins-agent/
│
├── intermediary-module-ins-agent-api/
│   └── src/main/java/cn/qmsk/intermediary/module/ins/agent/
│       ├── api/
│       │   └── InsAgentApi.java
│       └── dto/
│           ├── InsAgentDTO.java
│           └── InsOrgDTO.java
│
└── intermediary-module-ins-agent-server/
    └── src/main/java/cn/qmsk/intermediary/module/ins/agent/
        ├── InsAgentServerApplication.java
        ├── controller/
        │   ├── admin/
        │   │   ├── AdminInsOrgController.java           # PC后台：机构树管理（增/编辑/停用）
        │   │   ├── AdminInsAgentController.java         # PC后台：业务员审核/管理/异动
        │   │   ├── AdminInsAgentImportController.java   # PC后台：Excel批量导入
        │   │   ├── AdminInsCustomerController.java      # PC后台：全部客户列表/画像 ★V13
        │   │   ├── AdminInsRenewalController.java       # PC后台：续期看板/续期跟进 ★V13
        │   │   ├── AdminInsSmsController.java           # PC后台：云短信 ★V13
        │   │   ├── AdminInsWxWorkController.java        # PC后台：企业微信 ★V13
        │   │   └── AdminInsDataReportController.java    # PC后台：员工报表/业务报表/监控看板 ★V13
        │   └── app/
        │       ├── AppInsAgentProfileController.java    # App：个人中心/业绩查看
        │       ├── AppInsCustomerController.java        # App：CRM客户管理（我的客户）
        │       ├── AppInsFollowController.java          # App：跟进记录
        │       ├── AppInsTeamController.java            # App：我的团队
        │       └── AppInsPerformanceController.java     # App：业绩统计看板
        ├── api/
        │   └── InsAgentApiImpl.java
        ├── service/
        │   ├── InsOrgService.java / InsOrgServiceImpl.java
        │   ├── InsAgentService.java / InsAgentServiceImpl.java
        │   ├── InsCustomerService.java / InsCustomerServiceImpl.java  # PC/App双端客户管理
        │   ├── InsRenewalBoardService.java / InsRenewalBoardServiceImpl.java  # 续期看板★V13
        │   ├── InsSmsService.java / InsSmsServiceImpl.java            # 云短信★V13
        │   ├── InsWxWorkService.java / InsWxWorkServiceImpl.java      # 企业微信★V13
        │   └── InsPerformanceService.java / InsPerformanceServiceImpl.java
        ├── dal/
        │   ├── dataobject/
        │   │   ├── InsOrgDO.java
        │   │   ├── InsAgentInfoDO.java
        │   │   ├── InsAgentQualificationDO.java
        │   │   ├── InsCustomerDO.java
        │   │   ├── InsFollowRecordDO.java
        │   │   ├── InsRenewalTaskDO.java       # 续期任务表★V13
        │   │   └── InsSmsLogDO.java            # 短信记录表★V13
        │   ├── mysql/
        │   │   ├── InsOrgMapper.java
        │   │   ├── InsAgentInfoMapper.java
        │   │   ├── InsAgentQualificationMapper.java
        │   │   ├── InsCustomerMapper.java
        │   │   ├── InsFollowRecordMapper.java
        │   │   ├── InsRenewalTaskMapper.java
        │   │   └── InsSmsLogMapper.java
        │   └── redis/InsAgentRedisDAO.java
        ├── convert/InsAgentConvert.java
        └── job/
            ├── InsQualificationExpireJob.java   # 资质证书到期提醒
            └── InsRenewalRemindJob.java         # 续期任务提醒定时任务★V13
```

**核心数据库表**（Schema: `db_ins_agent`，前缀 `ins_agent_`）：

| 表名 | 说明 |
|------|------|
| `ins_org_tree` | 机构组织树（总公司/分公司/营业部） |
| `ins_agent_info` | 业务员扩展信息（关联 system_user） |
| `ins_agent_qualification` | 资质证书（代理人证/执业证） |
| `ins_customer` | CRM客户表（标签/等级/归属业务员） |
| `ins_follow_record` | 客户跟进记录 |
| `ins_renewal_task` | 续期任务表（到期日/跟进状态）★V13 |
| `ins_sms_log` | 云短信发送记录★V13 |

---

### 3.5 intermediary-module-ins-commission（佣金结算中台）

**职责**：基本法配置（职级/晋升/FYC/RYC）、佣金计算引擎、结算发放、保司对账、财务报表、薪酬管理，覆盖车险/非车险/寿险三大险种。

**对应阶段**：阶段2-PC佣金系统

```
intermediary-module-ins-commission/
│
├── intermediary-module-ins-commission-api/
│   └── src/main/java/cn/qmsk/intermediary/module/ins/commission/
│       ├── api/InsCommissionApi.java
│       └── dto/InsCommissionQueryDTO.java
│
└── intermediary-module-ins-commission-server/
    └── src/main/java/cn/qmsk/intermediary/module/ins/commission/
        ├── InsCommissionServerApplication.java
        ├── controller/
        │   ├── admin/
        │   │   ├── AdminInsBasicLawController.java      # 基本法配置（职级/晋升/佣金比例/车险政策）
        │   │   ├── AdminInsCommissionController.java    # 佣金计算/审核/结算/发放
        │   │   ├── AdminInsReconcileController.java     # 与保司对账
        │   │   ├── AdminInsStatementController.java     # 结算单/财务报表
        │   │   ├── AdminInsSalaryController.java        # 薪酬管理（工资查询/加扣款）
        │   │   └── AdminInsCarPolicyController.java     # 车险政策管理（留点/加投点/多级结算）
        │   └── app/
        │       └── AppInsCommissionController.java      # App：我的佣金/待结算
        ├── api/InsCommissionApiImpl.java
        ├── service/
        │   ├── InsBasicLawService.java / InsBasicLawServiceImpl.java
        │   ├── InsCommissionEngineService.java / InsCommissionEngineServiceImpl.java  # 佣金计算核心
        │   ├── InsCommissionSettleService.java / InsCommissionSettleServiceImpl.java
        │   ├── InsReconcileService.java / InsReconcileServiceImpl.java
        │   └── InsSalaryService.java / InsSalaryServiceImpl.java
        ├── dal/
        │   ├── dataobject/
        │   │   ├── InsBasicLawDO.java
        │   │   ├── InsCommissionRuleDO.java    # 佣金规则（Groovy脚本存储）
        │   │   ├── InsCommissionRecordDO.java  # 佣金明细记录
        │   │   ├── InsCommissionStatementDO.java
        │   │   ├── InsReconcileRecordDO.java
        │   │   └── InsCarPolicyDO.java         # 车险政策（留点/加投点配置）
        │   ├── mysql/
        │   │   ├── InsBasicLawMapper.java
        │   │   ├── InsCommissionRuleMapper.java
        │   │   ├── InsCommissionRecordMapper.java
        │   │   ├── InsCommissionStatementMapper.java
        │   │   ├── InsReconcileRecordMapper.java
        │   │   └── InsCarPolicyMapper.java
        │   └── redis/InsCommissionRedisDAO.java
        ├── mq/
        │   ├── producer/InsCommissionProducer.java
        │   └── consumer/InsCommissionConsumer.java   # 消费订单事件，触发佣金计算
        └── convert/InsCommissionConvert.java
```

**核心数据库表**（Schema: `db_ins_commission`，前缀 `ins_comm_`）：

| 表名 | 说明 |
|------|------|
| `ins_comm_basic_law` | 基本法主表（职级体系/晋升规则） |
| `ins_comm_rule` | 佣金规则表（规则脚本/比例配置/FYC/RYC） |
| `ins_comm_record` | 佣金明细记录表（每笔保单对应一条） |
| `ins_comm_statement` | 结算单表（月度/季度汇总） |
| `ins_comm_reconcile` | 对账记录表（与保司账单比对） |
| `ins_car_policy` | 车险政策表（留点/加投点/多级结算负责人） |

---

### 3.6 intermediary-module-ins-marketing（营销中台）

**职责**：营销素材（海报/文案）、Banner/文章/知识库内容管理、活动管理、优惠券、积分、计划书制作、培训中心，跨B端App和PC管理后台。

**对应阶段**：阶段3-业务员App-营销工具、阶段3-PC管理后台-营销管理

```
intermediary-module-ins-marketing/
│
├── intermediary-module-ins-marketing-api/
│   └── src/main/java/cn/qmsk/intermediary/module/ins/marketing/
│       ├── api/InsMarketingApi.java
│       └── dto/InsCouponCheckDTO.java
│
└── intermediary-module-ins-marketing-server/
    └── src/main/java/cn/qmsk/intermediary/module/ins/marketing/
        ├── InsMarketingServerApplication.java
        ├── controller/
        │   ├── admin/
        │   │   ├── AdminInsContentController.java       # Banner/文章/知识库内容管理
        │   │   ├── AdminInsActivityController.java      # 营销活动管理
        │   │   ├── AdminInsCouponController.java        # 优惠券管理
        │   │   ├── AdminInsPointController.java         # 积分规则/兑换管理
        │   │   ├── AdminInsTrainingController.java      # 培训管理（立项/计划/课程/讲师/培训班）
        │   │   └── AdminInsMarketingStatController.java # 营销数据统计看板
        │   └── app/
        │       ├── AppInsPosterController.java          # 营销海报生成/下载
        │       ├── AppInsProposalController.java        # 保险计划书制作/分享（非车险/寿险）
        │       ├── AppInsInviteController.java          # 邀请链接/邀请记录
        │       └── AppInsTrainingController.java        # 培训中心/课程/考试
        ├── api/InsMarketingApiImpl.java
        ├── service/
        │   ├── InsBannerService.java / InsBannerServiceImpl.java
        │   ├── InsArticleService.java / InsArticleServiceImpl.java
        │   ├── InsKnowledgeService.java / InsKnowledgeServiceImpl.java  # 知识库（Markdown/版本控制）
        │   ├── InsPosterService.java / InsPosterServiceImpl.java        # 海报合成
        │   ├── InsProposalService.java / InsProposalServiceImpl.java    # 计划书生成（PDF+H5）
        │   ├── InsActivityService.java / InsActivityServiceImpl.java
        │   ├── InsCouponService.java / InsCouponServiceImpl.java
        │   ├── InsPointService.java / InsPointServiceImpl.java
        │   └── InsTrainingService.java / InsTrainingServiceImpl.java
        ├── dal/
        │   ├── dataobject/
        │   │   ├── InsBannerDO.java
        │   │   ├── InsArticleDO.java
        │   │   ├── InsKnowledgeDO.java
        │   │   ├── InsKnowledgeVersionDO.java   # 知识库版本快照
        │   │   ├── InsPosterTemplateDO.java
        │   │   ├── InsProposalRecordDO.java
        │   │   ├── InsActivityDO.java
        │   │   ├── InsCouponDO.java
        │   │   ├── InsCouponUserDO.java
        │   │   ├── InsPointRecordDO.java
        │   │   └── InsTrainingDO.java
        │   ├── mysql/（同名Mapper，略）
        │   └── redis/InsMarketingRedisDAO.java
        └── convert/InsMarketingConvert.java
```

**核心数据库表**（Schema: `db_ins_marketing`，前缀 `ins_mkt_`）：

| 表名 | 说明 |
|------|------|
| `ins_mkt_banner` | Banner管理（位置/平台/定时上下架） |
| `ins_mkt_article` | 文章管理（审核流/定时发布/版本） |
| `ins_mkt_knowledge` | 知识库（Markdown/HTML双存/版本控制） |
| `ins_mkt_knowledge_version` | 知识库版本快照 |
| `ins_mkt_poster_template` | 海报模板 |
| `ins_mkt_proposal_record` | 计划书记录 |
| `ins_mkt_activity` | 营销活动 |
| `ins_mkt_coupon` | 优惠券模板 |
| `ins_mkt_coupon_user` | 用户优惠券领取记录 |
| `ins_mkt_point_record` | 积分明细 |
| `ins_mkt_training` | 培训立项/计划/课程/班级 |

---

### 3.7 intermediary-module-ins-compliance（合规双录）

**职责**：双录音视频采集（声网RTC）、AI质检（ASR+关键词+人脸识别）、区块链存证、合规报表，寿险场景尤其重要。

**对应阶段**：阶段5-合规双录

```
intermediary-module-ins-compliance/
│
├── intermediary-module-ins-compliance-api/
│   └── src/main/java/cn/qmsk/intermediary/module/ins/compliance/
│       ├── api/InsComplianceApi.java
│       └── dto/InsRecordingStatusDTO.java
│
└── intermediary-module-ins-compliance-server/
    └── src/main/java/cn/qmsk/intermediary/module/ins/compliance/
        ├── InsComplianceServerApplication.java
        ├── controller/
        │   ├── admin/
        │   │   ├── AdminInsRecordingController.java     # 录制记录查看/质检审核/存证管理
        │   │   ├── AdminInsScriptTemplateController.java # 话术模板配置（节点编排/关键词）
        │   │   └── AdminInsComplianceController.java    # 合规报表/审计日志/权限管理
        │   └── app/
        │       ├── AppInsRecordingController.java       # App：发起/继续双录（声网RTC）
        │       └── AppInsRecordingScriptController.java # App：话术节点展示
        ├── api/InsComplianceApiImpl.java
        ├── service/
        │   ├── InsRecordingService.java / InsRecordingServiceImpl.java     # 音视频录制
        │   ├── InsScriptTemplateService.java / InsScriptTemplateServiceImpl.java # 话术模板
        │   ├── InsAiQualityCheckService.java / InsAiQualityCheckServiceImpl.java # AI质检
        │   ├── InsBlockchainEvidenceService.java / InsBlockchainEvidenceServiceImpl.java # 存证
        │   └── InsTrackingService.java / InsTrackingServiceImpl.java       # 行为轨迹
        ├── dal/
        │   ├── dataobject/
        │   │   ├── InsRecordingSessionDO.java
        │   │   ├── InsScriptTemplateDO.java    # 话术模板（节点JSON）
        │   │   ├── InsQualityCheckResultDO.java
        │   │   └── InsEvidenceRecordDO.java
        │   ├── mysql/（同名Mapper，略）
        │   └── redis/InsComplianceRedisDAO.java
        └── convert/InsComplianceConvert.java
```

**核心数据库表**（Schema: `db_ins_compliance`，前缀 `ins_comp_`）：

| 表名 | 说明 |
|------|------|
| `ins_comp_recording_session` | 双录会话表（RTC房间/参与者/状态） |
| `ins_comp_script_template` | 话术模板（节点JSON/关键词/禁用词） |
| `ins_comp_quality_check` | AI质检结果（ASR文本/命中关键词/评分） |
| `ins_comp_evidence_record` | 存证记录（区块链哈希/存证时间） |

---

### 3.8 intermediary-module-ins-finance（财务中台）

**职责**：自动对账（智能匹配保司账单）、结算管理、税务管理（个税预扣）、BI经营报表、监管数据上报，V13补充合格结算特定流程。

**对应阶段**：阶段6-财务中台、阶段6-财务中台-合格结算补充★V13

```
intermediary-module-ins-finance/
│
├── intermediary-module-ins-finance-api/
│   └── src/main/java/cn/qmsk/intermediary/module/ins/finance/
│       ├── api/InsFinanceApi.java
│       └── dto/InsSettlementDTO.java
│
└── intermediary-module-ins-finance-server/
    └── src/main/java/cn/qmsk/intermediary/module/ins/finance/
        ├── InsFinanceServerApplication.java
        ├── controller/
        │   └── admin/
        │       ├── AdminInsReconcileController.java     # 自动对账/差异处理/保单导入
        │       ├── AdminInsSettlementController.java    # 结算管理/审核/发票
        │       ├── AdminInsTaxController.java           # 税务管理/个税计算/申报
        │       ├── AdminInsFinanceBiController.java     # 经营看板/保费/佣金统计
        │       ├── AdminInsUpstreamSettleController.java # 上游结算（对账/导入/撤销）
        │       ├── AdminInsQualifiedSettleController.java # 合格结算（批量修改/跟单队列）★V13
        │       └── AdminInsExportTemplateController.java # 导出模板配置（车险/非车险）★V13
        ├── api/InsFinanceApiImpl.java
        ├── service/
        │   ├── InsAutoReconcileService.java / InsAutoReconcileServiceImpl.java   # 智能对账引擎
        │   ├── InsSettlementService.java / InsSettlementServiceImpl.java
        │   ├── InsTaxService.java / InsTaxServiceImpl.java
        │   ├── InsFinanceBiService.java / InsFinanceBiServiceImpl.java
        │   ├── InsUpstreamSettleService.java / InsUpstreamSettleServiceImpl.java
        │   ├── InsQualifiedSettleService.java / InsQualifiedSettleServiceImpl.java  # 合格结算★V13
        │   └── InsExportTemplateService.java / InsExportTemplateServiceImpl.java    # 导出模板★V13
        ├── dal/
        │   ├── dataobject/
        │   │   ├── InsReconcileTaskDO.java      # 对账任务（批次）
        │   │   ├── InsReconcileDiffDO.java      # 对账差异
        │   │   ├── InsSettlementDO.java         # 结算单
        │   │   ├── InsTaxRecordDO.java          # 税务记录
        │   │   ├── InsUpstreamSettleDO.java     # 上游结算
        │   │   ├── InsQualifiedOrderDO.java     # 合格结算跟单队列★V13
        │   │   └── InsExportTemplateDO.java     # 导出模板配置★V13
        │   ├── mysql/（同名Mapper，略）
        │   └── redis/InsFinanceRedisDAO.java
        ├── job/
        │   ├── InsAutoReconcileJob.java
        │   ├── InsTaxCalculateJob.java
        │   └── InsQualifiedOrderAlertJob.java  # 跟单超期告警（默认45天）★V13
        └── convert/InsFinanceConvert.java
```

**核心数据库表**（Schema: `db_ins_finance`，前缀 `ins_fin_`）：

| 表名 | 说明 |
|------|------|
| `ins_fin_reconcile_task` | 对账任务表（导入批次/状态/进度） |
| `ins_fin_reconcile_diff` | 对账差异表（差异类型/金额差/处理状态） |
| `ins_fin_settlement` | 结算单表（月度汇总/审核状态/发票信息） |
| `ins_fin_tax_record` | 税务记录表（个税阶梯计算/申报状态） |
| `ins_fin_upstream_settle` | 上游结算表 |
| `ins_fin_qualified_order` | 合格结算跟单队列（PENDING_RATE/SKIP状态）★V13 |
| `ins_fin_export_template` | 导出模板配置表（车险/非车险字段映射）★V13 |

---

### 3.9 intermediary-module-ins-ai（AI智能中台）

**职责**：AI保障规划（问卷+缺口计算）、智能核保、智能客服，在 `intermediary-module-ai` 大模型能力基础上做保险业务封装。

**对应阶段**：阶段4-AI智能中台

```
intermediary-module-ins-ai/
│
├── intermediary-module-ins-ai-api/
│   └── src/main/java/cn/qmsk/intermediary/module/ins/ai/
│       ├── api/InsAiApi.java
│       └── dto/
│           ├── InsGapAnalysisDTO.java      # 保障缺口分析结果 DTO
│           └── InsUnderwritingDTO.java     # 智能核保结论 DTO
│
└── intermediary-module-ins-ai-server/
    └── src/main/java/cn/qmsk/intermediary/module/ins/ai/
        ├── InsAiServerApplication.java
        ├── controller/
        │   ├── admin/
        │   │   ├── AdminInsQuestionnaireController.java  # PC后台：问卷模板管理
        │   │   ├── AdminInsGapParamController.java       # PC后台：保障缺口计算参数配置
        │   │   └── AdminInsAiDataController.java         # PC后台：数据分析/用户画像
        │   └── app/
        │       ├── AppInsQuestionnaireController.java    # App/C端：发起/填写问卷/断点续答
        │       ├── AppInsGapAnalysisController.java      # App/C端：保障缺口展示/推荐方案
        │       ├── AppInsUnderwritingController.java     # App：智能核保问答
        │       └── AppInsCustomerServiceController.java  # App/C端：AI客服对话
        ├── api/InsAiApiImpl.java
        ├── service/
        │   ├── InsQuestionnaireService.java / InsQuestionnaireServiceImpl.java
        │   ├── InsGapCalculateService.java / InsGapCalculateServiceImpl.java  # BigDecimal精确计算
        │   ├── InsUnderwritingService.java / InsUnderwritingServiceImpl.java
        │   └── InsAiCustomerService.java / InsAiCustomerServiceImpl.java
        ├── dal/
        │   ├── dataobject/
        │   │   ├── InsQuestionnaireTemplateDO.java  # 问卷模板（跳题逻辑JSON）
        │   │   ├── InsQuestRecordDO.java             # 问卷作答记录
        │   │   └── InsGapAnalysisResultDO.java       # 保障缺口分析结果
        │   ├── mysql/（同名Mapper，略）
        │   └── redis/InsAiRedisDAO.java
        ├── mq/
        │   └── consumer/InsGapCalculateConsumer.java  # 消费问卷提交事件，异步触发缺口计算
        └── convert/InsAiConvert.java
```

**核心数据库表**（Schema: `db_ins_ai`，前缀 `ins_ai_`）：

| 表名 | 说明 |
|------|------|
| `ins_ai_questionnaire_template` | 问卷模板（题目/选项/跳题逻辑JSON） |
| `ins_ai_quest_record` | 问卷作答记录（支持断点续答） |
| `ins_ai_gap_analysis_result` | 保障缺口分析结果（寿险/重疾/意外/医疗象限） |

---

### 3.10 intermediary-module-ins-life（寿险专属中台）★V13新增

**职责**：寿险专有的数据回传（向保司反馈数据）、续期跟踪管理、孤儿单高级管理、寿险财务结算（上游结算/对账）、寿险监管报表、寿险系统配置（保司工号/H5配置），这些功能与车险/非车险差异较大，单独成服务。

> ⚠️ 寿险保单录入/查询/回访/保全 的 Controller/Service 已归入 `ins-order` 模块，本模块专注于寿险**独特的**业务流程。

**对应阶段**：阶段7-PC管理后台-寿险体系（财务/报表/数据回传/政策管理/系统管理部分）

```
intermediary-module-ins-life/
│
├── intermediary-module-ins-life-api/
│   └── src/main/java/cn/qmsk/intermediary/module/ins/life/
│       ├── api/InsLifeApi.java
│       └── dto/
│           ├── InsLifeSettlementDTO.java   # 寿险结算 DTO
│           └── InsLifeRenewalDTO.java      # 寿险续期状态 DTO
│
└── intermediary-module-ins-life-server/
    └── src/main/java/cn/qmsk/intermediary/module/ins/life/
        ├── InsLifeServerApplication.java
        ├── controller/
        │   └── admin/
        │       ├── AdminInsLifeRenewalController.java     # 续期跟踪（续期查询/批量导入续期需求）
        │       ├── AdminInsLifeDataReturnController.java  # 数据回传（数据回传/交互平台）
        │       ├── AdminInsLifeFinanceController.java     # 寿险财务（上游结算/机构计算/对账/薪资计算/个税）
        │       ├── AdminInsLifeReportController.java      # 寿险报表（继续率/业绩/监管报表/保单结算/产品占比）
        │       ├── AdminInsLifePolicyController.java      # 寿险政策（机构费率/上下游政策配置/折标系数/审批）
        │       ├── AdminInsLifeSystemController.java      # 系统管理（系统配置/H5后台/保司工号）
        │       └── AdminInsLifeProductController.java     # 产品管理（合作保司/寿险产品/协议管理）
        ├── api/InsLifeApiImpl.java
        ├── service/
        │   ├── InsLifeRenewalService.java / InsLifeRenewalServiceImpl.java
        │   ├── InsLifeDataReturnService.java / InsLifeDataReturnServiceImpl.java
        │   ├── InsLifeFinanceService.java / InsLifeFinanceServiceImpl.java
        │   ├── InsLifeReportService.java / InsLifeReportServiceImpl.java
        │   ├── InsLifePolicyService.java / InsLifePolicyServiceImpl.java    # 寿险政策（费率配置）
        │   └── InsLifeSystemService.java / InsLifeSystemServiceImpl.java
        ├── dal/
        │   ├── dataobject/
        │   │   ├── InsLifeRenewalTrackDO.java     # 续期跟踪记录
        │   │   ├── InsLifeDataReturnDO.java       # 数据回传批次
        │   │   ├── InsLifeFinanceSettleDO.java    # 寿险财务结算
        │   │   ├── InsLifeReportDO.java           # 寿险报表数据
        │   │   └── InsLifeRatePolicyDO.java       # 寿险费率政策
        │   ├── mysql/（同名Mapper，略）
        │   └── redis/InsLifeRedisDAO.java
        ├── job/
        │   ├── InsLifeRenewalAlertJob.java        # 续期到期提醒
        │   └── InsLifeDataReturnJob.java          # 数据回传定时任务
        └── convert/InsLifeConvert.java
```

**核心数据库表**（Schema: `db_ins_life`，前缀 `ins_life_`）：

| 表名 | 说明 |
|------|------|
| `ins_life_renewal_track` | 续期跟踪（续期状态/跟进记录） |
| `ins_life_data_return` | 数据回传批次（回传状态/回传内容） |
| `ins_life_finance_settle` | 寿险财务结算（上游保单结算/机构对账） |
| `ins_life_rate_policy` | 寿险费率政策（机构费率/上下游政策/折标系数） |

---

## 四、服务间依赖关系（V13）

```
                    ┌──────────────────────────────────────────────────────────────┐
                    │                intermediary-gateway（统一网关）                │
                    │   /admin-api/** → PC管理后台  /app-api/** → App/C端           │
                    └──────────────────────────┬───────────────────────────────────┘
                                               │ 路由分发
       ┌──────────────────────────────────────┬┼──────────────────────────────────┐
       │                                      ││                                  │
┌──────▼──────────┐          ┌────────────────▼┴───────────────┐   ┌─────────────▼──────────┐
│ module-system    │          │ module-ins-agent                 │   │ module-member           │
│ 用户/权限/租户   │◄─────────│ 业务员/组织/CRM/续期/PC客户管理   │   │ C端会员/微信登录         │
└──────────────────┘          └────────────────┬────────────────┘   └─────────────┬──────────┘
                                               │Feign查业务员                       │Feign查会员
                              ┌────────────────▼────────────────┐                  │
                              │ module-ins-product               │◄─────────────────┘
                              │ 产品中台（车/非车/寿险）            │
                              └────────────────┬────────────────┘
                                               │Feign查产品
         ┌─────────────────────────────────────┼──────────────────────────┐
         │                                     │                          │
┌────────▼───────────┐          ┌──────────────▼─────────────┐ ┌─────────▼──────────┐
│ module-ins-quote   │          │ module-ins-order            │ │ module-ins-life     │
│ 车险报价引擎         │─Feign→  │ 保单订单中台                 │ │ 寿险专属中台 ★V13   │
└────────────────────┘          │ (车险/非车险/寿险保单)         │ └────────────────────┘
                                └──────────────┬─────────────┘
                                               │MQ订单事件触发佣金
                              ┌────────────────▼────────────────┐
                              │ module-ins-commission            │
                              │ 佣金结算中台                      │
                              └────────────────┬────────────────┘
                                               │Feign提供结算数据
                   ┌──────────────────────────┬┘
                   │                          │
        ┌──────────▼─────────┐    ┌───────────▼──────────┐
        │ module-ins-finance  │    │ module-ins-compliance │
        │ 财务中台（+合格结算）│    │ 合规双录               │
        └────────────────────┘    └──────────────────────┘

module-ins-marketing ←── Feign 被 order 调用（优惠券核销）
module-ins-ai        ←── Feign 被 marketing/compliance 调用（AI质检/保障规划）
module-bpm           ←── Feign 被 agent/commission/finance/life 调用（审批流）
module-pay           ←── Feign 被 order/commission 调用（支付/打款）
module-ai            ←── Feign 被 ins-ai 调用（大模型对话/RAG知识库）
```

---

## 五、数据库 Schema 规划（V13）

| 服务模块 | 数据库 Schema | 表前缀 |
|---------|--------------|--------|
| intermediary-module-system | `db_system` | `system_` |
| intermediary-module-member | `db_member` | `member_` |
| intermediary-module-pay | `db_pay` | `pay_` |
| intermediary-module-bpm | `db_bpm` | `bpm_` |
| **ins-product** | `db_ins_product` | `ins_product_` |
| **ins-quote** | `db_ins_quote` | `ins_quote_` |
| **ins-order** | `db_ins_order` | `ins_order_` |
| **ins-agent** | `db_ins_agent` | `ins_agent_` |
| **ins-commission** | `db_ins_commission` | `ins_comm_` |
| **ins-marketing** | `db_ins_marketing` | `ins_mkt_` |
| **ins-compliance** | `db_ins_compliance` | `ins_comp_` |
| **ins-finance** | `db_ins_finance` | `ins_fin_` |
| **ins-ai** | `db_ins_ai` | `ins_ai_` |
| **ins-life** ★V13 | `db_ins_life` | `ins_life_` |

---

## 六、网关路由配置（V13）

```yaml
# intermediary-gateway/src/main/resources/application.yaml（追加）
spring:
  cloud:
    gateway:
      routes:
        # ===== 官方模块（原有，不变）=====
        - id: system-route
          uri: lb://intermediary-system-server
          predicates: [ Path=/admin-api/system/**, /app-api/system/** ]

        - id: member-route
          uri: lb://intermediary-member-server
          predicates: [ Path=/admin-api/member/**, /app-api/member/** ]

        # ===== 保险业务模块（新增）=====
        - id: ins-product-route
          uri: lb://intermediary-ins-product-server
          predicates: [ Path=/admin-api/ins/product/**, /app-api/ins/product/** ]

        - id: ins-quote-route
          uri: lb://intermediary-ins-quote-server
          predicates: [ Path=/app-api/ins/quote/** ]

        - id: ins-order-route
          uri: lb://intermediary-ins-order-server
          predicates: [ Path=/admin-api/ins/order/**, /app-api/ins/order/** ]

        - id: ins-agent-route
          uri: lb://intermediary-ins-agent-server
          predicates: [ Path=/admin-api/ins/agent/**, /app-api/ins/agent/** ]

        - id: ins-commission-route
          uri: lb://intermediary-ins-commission-server
          predicates: [ Path=/admin-api/ins/commission/**, /app-api/ins/commission/** ]

        - id: ins-marketing-route
          uri: lb://intermediary-ins-marketing-server
          predicates: [ Path=/admin-api/ins/marketing/**, /app-api/ins/marketing/** ]

        - id: ins-compliance-route
          uri: lb://intermediary-ins-compliance-server
          predicates: [ Path=/admin-api/ins/compliance/**, /app-api/ins/compliance/** ]

        - id: ins-finance-route
          uri: lb://intermediary-ins-finance-server
          predicates: [ Path=/admin-api/ins/finance/** ]

        - id: ins-ai-route
          uri: lb://intermediary-ins-ai-server
          predicates: [ Path=/admin-api/ins/ai/**, /app-api/ins/ai/** ]

        # ===== V13 新增：寿险专属中台 =====
        - id: ins-life-route
          uri: lb://intermediary-ins-life-server
          predicates: [ Path=/admin-api/ins/life/**, /app-api/ins/life/** ]
```

---

## 七、Nacos 服务注册命名规范（V13）

| 服务模块 | Nacos 服务名 | 端口（建议） |
|---------|-------------|------------|
| intermediary-gateway | `intermediary-gateway` | 8080 |
| intermediary-module-system-server | `intermediary-system-server` | 8081 |
| intermediary-module-infra-server | `intermediary-infra-server` | 8082 |
| intermediary-module-bpm-server | `intermediary-bpm-server` | 8083 |
| intermediary-module-pay-server | `intermediary-pay-server` | 8084 |
| intermediary-module-member-server | `intermediary-member-server` | 8085 |
| intermediary-module-ai-server | `intermediary-ai-server` | 8086 |
| intermediary-module-report-server | `intermediary-report-server` | 8087 |
| intermediary-module-mp-server | `intermediary-mp-server` | 8088 |
| **intermediary-module-ins-product-server** | `intermediary-ins-product-server` | 8101 |
| **intermediary-module-ins-quote-server** | `intermediary-ins-quote-server` | 8102 |
| **intermediary-module-ins-order-server** | `intermediary-ins-order-server` | 8103 |
| **intermediary-module-ins-agent-server** | `intermediary-ins-agent-server` | 8104 |
| **intermediary-module-ins-commission-server** | `intermediary-ins-commission-server` | 8105 |
| **intermediary-module-ins-marketing-server** | `intermediary-ins-marketing-server` | 8106 |
| **intermediary-module-ins-compliance-server** | `intermediary-ins-compliance-server` | 8107 |
| **intermediary-module-ins-finance-server** | `intermediary-ins-finance-server` | 8108 |
| **intermediary-module-ins-ai-server** | `intermediary-ins-ai-server` | 8109 |
| **intermediary-module-ins-life-server** ★V13 | `intermediary-ins-life-server` | 8110 |

---

## 八、Maven POM 结构规范

### 8.1 新增模块根 pom.xml 示例

```xml
<!-- intermediary-module-ins-life/pom.xml（V13新增寿险模块示例）-->
<project>
    <parent>
        <groupId>cn.qmsk.insurance</groupId>
        <artifactId>intermediary-cloud</artifactId>
        <version>${revision}</version>
    </parent>
    <modelVersion>4.0.0</modelVersion>
    <artifactId>intermediary-module-ins-life</artifactId>
    <packaging>pom</packaging>
    <name>${project.artifactId}</name>
    <description>寿险专属中台模块</description>

    <modules>
        <module>intermediary-module-ins-life-api</module>
        <module>intermediary-module-ins-life-server</module>
    </modules>
</project>
```

### 8.2 -api 子模块 pom.xml

```xml
<project>
    <parent>
        <groupId>cn.qmsk.insurance</groupId>
        <artifactId>intermediary-module-ins-life</artifactId>
        <version>${revision}</version>
    </parent>
    <artifactId>intermediary-module-ins-life-api</artifactId>
    <packaging>jar</packaging>
    <description>寿险专属中台 API，暴露给其它模块调用</description>

    <dependencies>
        <dependency>
            <groupId>cn.qmsk.insurance</groupId>
            <artifactId>intermediary-common</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-openfeign</artifactId>
            <optional>true</optional>
        </dependency>
    </dependencies>
</project>
```

### 8.3 -server 子模块 pom.xml

```xml
<project>
    <parent>
        <groupId>cn.qmsk.insurance</groupId>
        <artifactId>intermediary-module-ins-life</artifactId>
        <version>${revision}</version>
    </parent>
    <artifactId>intermediary-module-ins-life-server</artifactId>
    <packaging>jar</packaging>
    <description>寿险专属中台 Server，独立部署的微服务</description>

    <dependencies>
        <dependency>
            <groupId>cn.qmsk.insurance</groupId>
            <artifactId>intermediary-module-ins-life-api</artifactId>
            <version>${revision}</version>
        </dependency>
        <dependency>
            <groupId>cn.qmsk.insurance</groupId>
            <artifactId>intermediary-spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>cn.qmsk.insurance</groupId>
            <artifactId>intermediary-spring-boot-starter-mybatis</artifactId>
        </dependency>
        <dependency>
            <groupId>cn.qmsk.insurance</groupId>
            <artifactId>intermediary-spring-boot-starter-redis</artifactId>
        </dependency>
        <dependency>
            <groupId>cn.qmsk.insurance</groupId>
            <artifactId>intermediary-spring-boot-starter-job</artifactId>
        </dependency>
        <dependency>
            <groupId>cn.qmsk.insurance</groupId>
            <artifactId>intermediary-spring-boot-starter-excel</artifactId>
        </dependency>
        <!-- 依赖其他保险业务模块 API -->
        <dependency>
            <groupId>cn.qmsk.insurance</groupId>
            <artifactId>intermediary-module-ins-order-api</artifactId>
            <version>${revision}</version>
        </dependency>
        <dependency>
            <groupId>cn.qmsk.insurance</groupId>
            <artifactId>intermediary-module-ins-commission-api</artifactId>
            <version>${revision}</version>
        </dependency>
        <dependency>
            <groupId>cn.qmsk.insurance</groupId>
            <artifactId>intermediary-module-system-api</artifactId>
            <version>${revision}</version>
        </dependency>
    </dependencies>
</project>
```

---

## 九、前端工程说明（V13）

| 前端工程 | 对应仓库 | 覆盖阶段 | 访问端 |
|---------|---------|---------|--------|
| `intermediary-ui` | 官方仓库扩展菜单 | 阶段1/2/3/4/5/6/7 PC后台 | Web 浏览器 |
| `intermediary-ui-agent-uniapp` | 基于 uni-app 新建 | 阶段1/2/3/4/8 业务员展业App | iOS/Android |
| `intermediary-ui-consumer-uniapp` | 基于商城 uni-app 改造 | 阶段3/8 C端保险商城 | 微信小程序/H5 |

**V13新增前端菜单扩展（PC管理后台）**：
- 阶段2 → 【车险管理】菜单：保单录入/批量录入/批单/查询/统计分析10大模块
- 阶段2 → 【非车险管理】菜单：保单录入/批单/导入/查询/政策设置/统计分析/系统设置
- 阶段2 → 【客户管理】菜单：全部客户/我的客户/客户画像/续期看板/工具（云短信/企业微信）/数据报表
- 阶段7 → 【寿险管理】菜单：保单管理/回访管理/保全维护/续期跟踪/孤儿单/理赔/数据回传/财务/报表/政策/系统/产品
- 阶段8 → 业务员App 新增【寿险展业】入口：产品列表/详情/试算/计划书/保单录入/续期

---

## 十、开发启动顺序建议（V13）

```
第一步（基础设施，必须先起）：
  MySQL + Redis + Nacos + RocketMQ + XXL-Job + MinIO（或阿里云OSS）

第二步（框架服务）：
  intermediary-module-system-server        # 用户/权限基础
  intermediary-module-infra-server         # 基础设施（代码生成/文件存储）
  intermediary-gateway                     # API网关

第三步（阶段1，车险报价 + 基础建设）：
  intermediary-module-ins-agent-server     # 业务员/组织架构体系
  intermediary-module-ins-product-server   # 产品中台
  intermediary-module-ins-quote-server     # 车险报价引擎

第四步（阶段2，非车险 + 佣金 + PC业务）：
  intermediary-module-ins-order-server     # 保单订单中台（车险/非车险保单管理）
  intermediary-module-pay-server           # 支付（官方）
  intermediary-module-bpm-server           # 工作流（官方）
  intermediary-module-ins-commission-server  # 佣金中台

第五步（阶段3，C端商城 + 营销）：
  intermediary-module-member-server        # C端会员（官方）
  intermediary-module-mp-server            # 微信小程序（官方）
  intermediary-module-ins-marketing-server # 营销中台

第六步（阶段4-6，AI + 合规 + 财务）：
  intermediary-module-ai-server            # AI大模型（官方）
  intermediary-module-ins-ai-server        # AI智能中台（保障规划/智能核保）
  intermediary-module-ins-compliance-server  # 合规双录
  intermediary-module-report-server        # 报表（官方）
  intermediary-module-ins-finance-server   # 财务中台

第七步（阶段7-8，寿险体系）★V13新增：
  intermediary-module-ins-life-server      # 寿险专属中台
  （ins-order-server扩展寿险保单Controller/Service）
  （ins-product-server扩展寿险产品Controller/Service）
```

---

## 十一、包名与命名规范汇总

| 配置项 | 规范值 | 示例 |
|--------|--------|------|
| Maven GroupId | `cn.qmsk.insurance` | `cn.qmsk.insurance` |
| Java 根包名 | `cn.qmsk.intermediary.module.ins.{模块}` | `cn.qmsk.intermediary.module.ins.product` |
| Maven 工程前缀 | `intermediary-module-ins-{模块}` | `intermediary-module-ins-life` |
| Nacos 服务名 | `intermediary-ins-{模块}-server` | `intermediary-ins-life-server` |
| 数据库 Schema | `db_ins_{模块}` | `db_ins_life` |
| 表前缀 | `ins_{模块缩写}_` | `ins_life_` |
| 启动类命名 | `Ins{模块}ServerApplication.java` | `InsLifeServerApplication.java` |
| Controller（admin端） | `AdminIns{功能}Controller.java` | `AdminInsLifeRenewalController.java` |
| Controller（app端） | `AppIns{功能}Controller.java` | `AppInsLifePolicyController.java` |
| Service 接口 | `Ins{功能}Service.java` | `InsLifeRenewalService.java` |
| Service 实现 | `Ins{功能}ServiceImpl.java` | `InsLifeRenewalServiceImpl.java` |
| DO 实体类 | `Ins{功能}DO.java` | `InsLifeRenewalTrackDO.java` |
| Mapper 接口 | `Ins{功能}Mapper.java` | `InsLifeRenewalTrackMapper.java` |
| Redis DAO | `Ins{功能}RedisDAO.java` | `InsLifeRedisDAO.java` |
| MapStruct转换 | `Ins{模块}Convert.java` | `InsLifeConvert.java` |
| Feign API 接口 | `Ins{模块}Api.java` | `InsLifeApi.java` |
| Feign API 实现 | `Ins{模块}ApiImpl.java` | `InsLifeApiImpl.java` |
| MQ 消息生产者 | `Ins{功能}Producer.java` | `InsOrderProducer.java` |
| MQ 消息消费者 | `Ins{功能}Consumer.java` | `InsGapCalculateConsumer.java` |
| 定时任务 | `Ins{功能}Job.java` | `InsLifeRenewalAlertJob.java` |

---

---

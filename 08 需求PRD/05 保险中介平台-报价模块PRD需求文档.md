# 保险中介平台 · 报价模块 PRD 需求文档

---

| 项目         | 内容                              |
|------------|----------------------------------|
| **项目名称** | 保险中介全域数字化平台（intermediary-cloud） |
| **模块名称** | 报价模块（Quote Module）              |
| **技术框架** | yudao-cloud（Spring Cloud Alibaba 微服务版） |
| **微服务模块** | `intermediary-module-ins-quote`   |
| **数据库 Schema** | `db_ins_quote`（表前缀 `ins_quote_`）|
| **文档版本** | V1.0                              |
| **编写日期** | 2026-03-06                        |
| **文档状态** | 正式版                             |

---

## 目录

1. [模块概述](#1-模块概述)
2. [用户角色与使用场景](#2-用户角色与使用场景)
3. [功能架构总览](#3-功能架构总览)
4. [功能一：行驶证 OCR 识别（车险专用）](#4-功能一行驶证-ocr-识别车险专用)
5. [功能二：车辆信息录入与档案管理](#5-功能二车辆信息录入与档案管理)
6. [功能三：车险投保方案配置](#6-功能三车险投保方案配置)
7. [功能四：多保司并发报价引擎（车险）](#7-功能四多保司并发报价引擎车险)
8. [功能五：报价结果展示与比价](#8-功能五报价结果展示与比价)
9. [功能六：报价单生成与分享（车险）](#9-功能六报价单生成与分享车险)
10. [功能七：非车险保费试算](#10-功能七非车险保费试算)
11. [功能八：非车险计划书制作](#11-功能八非车险计划书制作)
12. [功能九：寿险保费试算与计划书](#12-功能九寿险保费试算与计划书)
13. [功能十：C 端在线报价（车险/非车险）](#13-功能十c-端在线报价车险非车险)
14. [功能十一：续保报价管理](#14-功能十一续保报价管理)
15. [功能十二：PC 后台报价配置管理](#15-功能十二pc-后台报价配置管理)
16. [数据库设计](#16-数据库设计)
17. [接口清单](#17-接口清单)
18. [非功能性需求](#18-非功能性需求)
19. [开发工时估算](#19-开发工时估算)

---

## 1. 模块概述

### 1.1 业务背景

传统保险中介行业报价展业的核心痛点：

- **效率低下**：业务员需逐家保司登录系统报价，单次车险询价耗时 20–30 分钟；非车险手工查阅费率表，容易出错。
- **数据孤岛**：报价结果散落在 Excel 表、纸质单据、微信记录中，无法沉淀为客户档案。
- **合规风险**：纸质单据无法溯源，口头报价与实际条款不符引发投诉。
- **客户体验差**：客户等待时间长，报价单格式不统一，难以直观对比。

### 1.2 模块定位

报价模块是整个保险中介平台的**展业起点和核心入口**，承担以下职责：

- 为业务员 App 提供**车险多保司并发询价**能力（OCR 识别 → 方案配置 → 并发报价 → 比价 → PDF 生成）；
- 为业务员 App 提供**非车险/寿险保费试算与计划书**生成能力；
- 为 C 端小程序/H5 提供消费者自助在线报价入口；
- 为 PC 管理后台提供报价配置、费率维护、保司管理等后台能力；
- 沉淀车辆档案、报价历史，支撑续保、CRM 等下游模块。

### 1.3 覆盖险种范围

| 险种 | 报价方式 | 主要用户 |
|------|---------|---------|
| 车险（交强险 + 商业险） | 调用保司 API 实时报价（多保司并发） | 业务员 App / C 端 |
| 非车险（意外险、财产险、责任险等） | Groovy 公式引擎本地试算 | 业务员 App / C 端 |
| 寿险（重疾、医疗、年金、终身寿等） | 费率表查询 + 利益演示计算 | 业务员 App / C 端 |

---

## 2. 用户角色与使用场景

| 角色 | 使用场景 | 主要入口 |
|------|---------|---------|
| **业务员（B 端）** | 客户现场报价、续保前询价、制作计划书发送客户 | 业务员 App（UniApp） |
| **团队长 / 管理员** | 查看团队报价量、转化率统计，配置方案模板 | PC 管理后台 |
| **内勤人员** | 配置保司信息、维护费率、管理投保方案模板 | PC 管理后台 |
| **消费者（C 端）** | 自助查询保费、获取方案报价 | 微信小程序 / H5 |

---

## 3. 功能架构总览

```
报价模块（ins-quote）
│
├── 车险报价子模块
│   ├── F1  行驶证 OCR 识别（腾讯云 / 阿里云）
│   ├── F2  车辆信息录入与档案管理（含车型库）
│   ├── F3  投保方案配置（模板快选 + 险种逐项配置）
│   ├── F4  多保司并发询价引擎（CompletableFuture + 策略模式）
│   ├── F5  报价结果展示与比价（费率明细 / 系数说明）
│   └── F6  报价单生成与分享（PDF / H5 分享链接）
│
├── 非车险报价子模块
│   ├── F7  保费试算（Groovy 公式引擎 + Redis 缓存）
│   └── F8  计划书制作（方案配置 → 保障演示 → PDF 生成）
│
├── 寿险报价子模块
│   └── F9  保费试算 + 利益演示 + 计划书（费率表查询 + 现金价值表）
│
├── C 端报价子模块
│   └── F10 消费者自助报价（车险 / 非车险入口）
│
├── 续保报价子模块
│   └── F11 续保任务列表 + 上年数据回填 + 一键续保询价
│
└── PC 后台配置子模块
    └── F12 保司管理 / 方案模板配置 / 费率维护 / 报价统计
```

---

## 4. 功能一：行驶证 OCR 识别（车险专用）

### 4.1 功能概述

业务员通过 App 拍摄客户行驶证正本，系统调用 OCR 接口自动识别车辆信息，自动填充报价表单，将录入时间从 5 分钟压缩至 30 秒内。

### 4.2 业务流程

```
业务员点击"拍照识别" → 调起摄像头 → 拍摄行驶证
    ↓
上传图片至 OSS → 调用 OCR 接口（腾讯云 VehicleLicenseOCR）
    ↓
识别结果解析 → 字段映射填充
    ↓
[识别成功] → 展示预填表单 → 业务员核对确认
[识别失败] → 提示失败原因 → 引导"重新拍摄"或"手动输入"
    ↓
已识别字段保留，未识别字段手动补充
    ↓
提交车辆信息
```

### 4.3 OCR 识别字段映射

| 行驶证字段 | 系统字段 | 必填 | 说明 |
|---------|---------|-----|------|
| 号牌号码 | `license_plate` | 是 | 车牌号，含新能源绿牌 |
| 车辆类型 | `vehicle_type_name` | 否 | 小型轿车/SUV 等 |
| 所有人 | `owner_name` | 是 | 车主姓名 |
| 使用性质 | `use_type` | 是 | 家用/营运/租赁 |
| 品牌型号 | `brand_model_raw` | 是 | 用于车型库匹配 |
| 发动机号 | `engine_no` | 是 | 用于续保查询 |
| 车辆识别代号（VIN） | `vin_code` | 是 | 17 位，用于保司接口 |
| 注册日期 | `register_date` | 是 | 即初登日期 |
| 发证日期 | `issue_date` | 否 | 行驶证签发日期 |
| 核定载客人数 | `seat_count` | 是 | 用于司乘险座位数 |

### 4.4 识别失败处理规则

| 失败原因 | 系统提示 | 引导操作 |
|---------|---------|---------|
| 图片模糊 | "图片不清晰，请在光线充足处重拍" | 重新拍摄 |
| 角度倾斜 | "请将行驶证摆正后拍摄" | 重新拍摄 |
| 非行驶证图片 | "未识别到有效行驶证，请重试" | 重新拍摄 |
| OCR 服务异常 | "识别服务暂时不可用，请手动填写" | 跳转手动输入 |

### 4.5 技术实现要点

- 图片上传至 MinIO/阿里云 OSS，获取 URL 后调用 OCR；
- OCR 调用超时设置 5 秒，超时自动降级为手动输入；
- 识别日志记录到 `ins_quote_ocr_log`（含耗时、成功率、失败原因）；
- 识别准确率 KPI：≥ 95%（按日统计）。

---

## 5. 功能二：车辆信息录入与档案管理

### 5.1 功能概述

管理车辆档案，支持三种录入方式：OCR 自动识别、车牌号查历史、手动输入。车辆信息作为报价的核心数据源，同时为续保模块和客户 CRM 提供数据支撑。

### 5.2 三种录入入口

| 方式 | 触发条件 | 适用场景 |
|------|---------|---------|
| **方式 A：OCR 识别** | 点击"拍照识别"按钮 | 首次报价，现场有行驶证 |
| **方式 B：车牌号查询** | 输入车牌号后系统自动匹配历史档案 | 续保客户，系统已有历史数据 |
| **方式 C：手动输入** | 直接填写表单 | OCR 失败或无行驶证 |

### 5.3 车辆信息表单字段（完整）

#### 必填字段

| 字段名 | 类型 | 校验规则 |
|-------|------|---------|
| 车牌号 | 文本 | 标准车牌正则校验，支持新能源绿牌 |
| 车架号（VIN） | 文本 | 17 位，字符范围 `[A-HJ-NPR-Z0-9]` |
| 发动机号 | 文本 | 6–20 位字符 |
| 初登日期 | 日期 | 不得晚于今日；不得早于 1990-01-01 |
| 品牌车型 | 级联选择 | 从车型库选择（品牌→车系→车款） |
| 新车购置价（万元） | 数字 | 1 ≤ 购置价 ≤ 500 |
| 核定座位数 | 数字 | 2 ≤ 座位数 ≤ 55 |
| 使用性质 | 枚举 | 家用（1）/ 营运（2）/ 租赁（3）/ 其他（4） |
| 车主姓名 | 文本 | 2–20 个中文字符 |
| 车主手机号 | 文本 | 11 位，以 1 开头 |

#### 选填字段

| 字段名 | 类型 | 说明 |
|-------|------|------|
| 车主身份证号 | 文本 | AES-256 加密存储，仅末 4 位明文展示 |
| 车辆颜色 | 文本 | 用于行驶证核对 |
| 燃料类型 | 枚举 | 汽油 / 柴油 / 纯电 / 混动 / 燃料电池 |
| 整备质量（kg） | 数字 | 保险费率计算辅助 |
| 是否新能源 | 布尔 | 影响交强险基础保费 |

### 5.4 VIN 码智能解析逻辑

输入 17 位 VIN 后，系统自动解析并回填：

1. **WMI（前 3 位）**：识别制造商（L=中国 / J=日本 / W=德国等）；
2. **第 10 位年份码**：推算车辆出厂年份，自动推算初登日期范围；
3. **车型代码（第 4-8 位）**：辅助车型库精确匹配；
4. **第 9 位校验码**：验证 VIN 格式有效性，无效则提示错误。

### 5.5 车型库联想搜索

- 数据源：对接第三方车型库（精友 / 纳鼎），定期同步；
- 支持拼音首字母联想（如输入 "bm" 显示 "宝马"）；
- 三级级联：品牌 → 车系（按年份排序）→ 车款（排量 + 变速箱筛选）；
- 匹配成功后自动回填：座位数、新车购置价（参考）；
- 未匹配时支持手动填写车款名称，记录未匹配记录供后台人工补录。

### 5.6 重复车辆判断规则

同一 `tenant_id` 下相同 `vin_code` 的车辆视为同一车辆：

- 若已存在且同归属业务员：直接复用，更新最新信息；
- 若已存在但归属其他业务员：提示"该车已在系统中，请确认客户信息"，允许覆盖；
- 相同车牌但不同 VIN：可能过户，系统提示人工确认。

---

## 6. 功能三：车险投保方案配置

### 6.1 功能概述

业务员在获取车辆信息后，进入投保方案配置页，选择险种组合和保额，生成正式报价请求。

### 6.2 方案模板快选

系统提供 3 套预设方案模板，管理员可在 PC 后台增删改：

| 模板名称 | 三者险保额 | 车损险 | 司乘险 | 主要附加险 | 适用场景 |
|---------|---------|-------|-------|---------|---------|
| **经济型** | 50 万 | ❌ | ❌ | 无 | 老旧车、价格敏感客户 |
| **标准型** | 100 万 | ✅ | 1 万/座 | 玻璃险（国产）、划痕险（新车） | 普通家用车 |
| **全面型** | 200 万 | ✅（含不计免赔）| 5 万/座 | 涉水、自燃、划痕、玻璃（进口）、轮胎 | 新车、豪车 |

**模板动态适配规则：**

- **地域适配**：南方省份（粤/闽/浙/沪/琼等）标准型和全面型默认勾选涉水险；北方省份（黑/吉/辽等）默认勾选自燃险；
- **车龄适配**：0–2 年车推荐划痕险 + 玻璃险；3–6 年推荐自燃险；7 年以上不推荐划痕险；
- **车价适配**：购置价 > 50 万的默认三者险保额设为 200 万，前端提示"建议高保额"。

### 6.3 险种配置规则

#### 6.3.1 交强险

- 强制勾选，复选框置灰，不可取消；
- 基础保费：6 座以下 950 元，6 座以上 1,100 元（保司接口返回，本步骤仅展示说明）；
- 展示文字："交强险为法律要求，已默认选中"。

#### 6.3.2 第三者责任险（三者险）

- 默认勾选，可取消；
- 保额档位（下拉单选）：5 万 / 10 万 / 20 万 / 30 万 / 50 万 / **100 万（默认）** / 150 万 / 200 万 / 300 万 / 500 万 / 1,000 万；
- 豪车特殊规则：车价 > 50 万时默认切换为 200 万，前端弹提示。

#### 6.3.3 车辆损失险（车损险）

- 默认勾选，可取消；
- 保额：系统自动计算实际价值（只读）：
  - 公式：`实际价值 = 新车购置价 × (1 - 9%)^车龄`，最大折旧 80%；
  - 示例：25 万新车，3 年车龄 → `25 × 0.91³ ≈ 18.8 万`；
- **前置险种**：取消车损险时，以下附加险自动联动取消并置灰：
  - 车损险不计免赔、发动机涉水损失险、指定专修厂险。

#### 6.3.4 司乘险（司机/乘客责任险）

- 默认勾选，可取消；
- 保额档位（每座）：1 万 / 2 万 / 5 万 / 10 万 / 20 万；
- 座位数：从车辆档案自动读取，只读展示。

#### 6.3.5 附加险完整列表与规则

| 附加险 | 前置险种 | 互斥规则 | 特殊规则 |
|-------|---------|---------|---------|
| 车损险不计免赔 | 车损险 | — | — |
| 三者险不计免赔 | 三者险 | — | — |
| 发动机涉水损失险 | 车损险 | — | 南方省份默认推荐 |
| 指定专修厂险 | 车损险 | — | 保费增加约 10–15% |
| 玻璃险（国产） | — | 与进口玻璃互斥 | 二选一 |
| 玻璃险（进口） | — | 与国产玻璃互斥 | 豪车 / 进口车推荐 |
| 划痕险 | — | — | 车龄 > 6 年置灰不可选 |
| 自燃险 | — | — | 北方省份默认推荐 |
| 盗抢险 | — | — | 高价车推荐 |
| 新增设备损失险 | — | — | 需填写设备总价值（万元） |
| 轮胎单独破损险 | — | — | — |
| 承运人责任险 | — | — | 使用性质=营运时强制勾选且置灰 |

### 6.4 增值服务配置

| 服务名称 | 包含说明 | 计费方式 |
|---------|---------|---------|
| 道路救援（基础版） | 100 公里内免费拖车 | 含在保费内（保司提供） |
| 道路救援（豪华版） | 300 公里拖车 + 油料配送 | 额外收费（后台配置金额） |
| 代驾服务 | 3 次/年免费代驾 | 额外收费 |
| 快速理赔通道 | 理赔优先处理 | 免费赠送 |

### 6.5 方案配置完成后校验

提交报价前系统校验：
1. 车辆信息必填项全部完整；
2. 交强险已选中；
3. 商业险中至少选择一种主险（车损险或三者险）；
4. 附加险依赖主险已满足；
5. 互斥险种未同时勾选；
6. 保额值在允许范围内。

---

## 7. 功能四：多保司并发报价引擎（车险）

### 7.1 功能概述

系统并发调用多家保险公司 API，在 10 秒内获取所有保司报价结果，自动聚合展示。

### 7.2 报价引擎工作流程

```
提交报价请求
    ↓
系统校验（车辆信息完整性 + 方案合法性）
    ↓
创建报价记录（ins_quote_record），状态 = QUOTING（询价中）
    ↓
并发线程池（CompletableFuture.allOf）
    ├── 调用人保财险 API    超时 10s
    ├── 调用平安车险 API    超时 10s
    ├── 调用太保车险 API    超时 10s
    ├── 调用国寿财险 API    超时 10s
    └── 调用太平洋车险 API  超时 10s
    ↓
逐个保司结果写入 ins_quote_item（成功 / 失败 / 超时）
    ↓
全部完成或超时 20s 强制返回
    ↓
更新报价记录状态 = QUOTED（已报价）
    ↓
Redis 缓存结果 30 分钟（key: quote:result:{recordId}）
```

### 7.3 报价请求参数规范

**提交至各保司的标准参数：**

| 参数分类 | 字段 |
|---------|------|
| **车辆信息** | 车牌号、VIN 码、品牌车型、新车购置价、初登日期、座位数、使用性质 |
| **投保人信息** | 姓名、身份证号、手机号 |
| **险种信息** | 交强险（是/否）、车损险（是/否 + 保额）、三者险（是/否 + 保额）、司乘险（是/否 + 每座保额 + 座位数）、各附加险选中状态 |
| **上年投保信息** | 上年保险公司、上年保单期满日期、上年出险次数、上年理赔金额 |

### 7.4 超时与重试策略

| 场景 | 策略 |
|------|------|
| 单保司网络超时（< 10s） | 超时后自动重试 1 次（间隔 2s） |
| 单保司多次网络超时 | 标记失败，展示"超时无响应"原因 |
| 保司返回"需人工核保" | 不重试，展示"需人工核保"引导 |
| 保司返回"车辆拒保" | 不重试，展示"该保司拒保"及原因 |
| 全局等待超时（20s） | 强制返回已获取的报价，未完成标记为"报价中" |
| 保司失败率 > 80%/分钟 | 自动熔断 5 分钟，熔断期内跳过该保司 |

### 7.5 保费计算逻辑（本地计算，用于参考校验）

**交强险保费计算：**

```
基础保费（6座以下）= 950 元
基础保费（6座以上）= 1,100 元

NCD 系数：
  首次投保或上年有赔付  = 1.0
  上年无赔付            = 0.9
  连续 2 年无赔付       = 0.8
  连续 3 年及以上无赔付 = 0.7

交强险最终保费 = 基础保费 × NCD 系数 × 违章系数
```

**车损险保费计算（参考）：**

```
基准保费 = 车辆实际价值 × 基准费率 + 固定保费
车辆实际价值 = 新车购置价 × (1-9%)^车龄，最大折旧 80%

NCD 系数（上年出险次数）：
  0 次 = 0.7
  1 次 = 1.0
  2 次 = 1.25
  3 次 = 1.5
  4 次及以上 = 2.0

车损险最终保费 = 基准保费 × NCD系数 × 车型系数 × 渠道系数
```

### 7.6 报价数据校验（保司返回后）

| 校验项 | 异常处理 |
|-------|---------|
| 必填字段（总保费/各分项保费）缺失 | 标记"数据异常"，不展示该保司结果 |
| 总保费 ≠ 各分项之和（误差 > 0.01） | 记录日志，标记"保费计算异常" |
| NCD 系数超出合理范围（0.6~2.0） | 记录警告日志，正常展示但标注"费率异常" |
| 报价比其他保司低 30% 以上 | 标记"价格异常低，建议核实"，仍展示 |

---

## 8. 功能五：报价结果展示与比价

### 8.1 页面展示规则

**报价列表排序（默认）：** 按总保费从低到高；可切换按服务评分、佣金比例（后者仅内部可见）排序。

**每个报价卡片展示内容：**

| 展示项 | 说明 |
|-------|------|
| 保险公司 Logo + 名称 | 平安 / 人保 / 太保等 |
| 总保费（大字体） | 突出展示，单位"元" |
| 交强险保费 | 分项展示 |
| 商业险保费 | 分项展示 |
| 车船税 | 分项展示 |
| 费率系数（可折叠） | NCD 系数 / 自主核保系数 / 渠道系数 |
| 优惠标签 | "新客立减"/ "续保优惠"等 |
| 最低价角标 | 保费最低的一家加"推荐"/ "最低价"标记 |
| 操作按钮 | 【查看明细】【选择此方案 → 出单】 |

**失败报价展示：**

| 失败类型 | 展示文案 |
|---------|---------|
| 超时未响应 | "网络超时，暂无报价" |
| 接口异常 | "系统异常，暂无报价" |
| 车辆拒保 | "该车辆风险较高，该保司暂不承保" |
| 需人工核保 | "需人工核保，请联系客服" |

### 8.2 保费明细展开说明

用户点击"查看明细"展示完整费率说明：

```
交强险：950 元
  基础保费：950 元
  NCD 系数：0.9（上年无赔付）
  最终：855 元

商业险：2,310 元
  三者险（100万）：1,200 元
    基准保费：1,500 × 0.8（NCD） = 1,200 元
  车损险（18.8万）：800 元
    基准保费：1,000 × 0.8（NCD） = 800 元
  划痕险：150 元
  司乘险（5万×5座）：160 元

车船税：360 元

合计：3,525 元
```

---

## 9. 功能六：报价单生成与分享（车险）

### 9.1 功能概述

业务员选定目标保司方案后，系统生成专业 PDF 报价单，并提供多种分享方式传递给客户。

### 9.2 PDF 报价单内容

| 版块 | 内容 |
|------|------|
| 封面 | 保险公司 Logo、标题"机动车保险报价单"、报价日期、报价单编号 |
| 车辆信息 | 车牌号、车架号、车款、初登日期、使用性质、新车购置价 |
| 投保方案明细 | 交强险 / 各商业险险种名称 + 保额 + 保费 |
| 费率说明 | NCD 系数、自主核保系数、渠道系数的数值与说明 |
| 价格汇总 | 各项保费 + 车船税 + 合计总保费 |
| 业务员名片 | 业务员姓名、手机号、所属机构、专属二维码（跳转 H5） |
| 免责声明 | 标准免责条款，报价仅供参考，以保司核保结果为准 |

### 9.3 PDF 生成技术方案

- **异步生成**：点击"生成报价单"后，前端展示 Loading，后端 MQ 异步生成；
- **前端轮询**：每 2 秒查询生成状态，最长等待 60 秒；
- **生成完成**：上传至 OSS，返回永久访问 URL；
- **PDF 模板**：基于 FreeMarker HTML 模板 + wkhtmltopdf 转换。

### 9.4 H5 分享页

- 生成与报价单对应的 H5 专属分享链接；
- 响应式布局，支持微信内直接打开；
- 行为追踪：记录客户打开时间、停留时长，通过 MQ 异步推送通知给业务员；
- 分享链接有效期：30 天。

### 9.5 分享方式

| 分享方式 | 操作 |
|---------|------|
| 微信发送 PDF | 调用微信 API 发送文件 |
| 短信发送 H5 链接 | 调用短信服务发送含短链接的短信 |
| App 内展示 | 业务员直接在 App 内向客户展示 |
| 复制链接 | 手动复制 H5 链接 |

---

## 10. 功能七：非车险保费试算

### 10.1 功能概述

业务员在非车险展业过程中，使用本地费率引擎快速计算保费，支持企业财产险、工程险、意外险、健康险、责任险等多种非车险产品试算。

### 10.2 试算输入规则

非车险产品字段差异较大，通过统一的动态表单渲染：

- 每个产品在后台配置"试算参数模板"（JSON Schema）；
- 前端根据 JSON Schema 动态渲染表单（文本/数字/下拉/日期/单选/多选）；
- 必填字段由 JSON Schema `required` 数组控制；
- 字段校验规则由 JSON Schema `validation` 节点控制。

**典型试算输入字段：**

| 险种 | 核心输入参数 |
|------|-----------|
| 意外险 | 被保人年龄、职业类别、保额、保险期限 |
| 财产险 | 标的物类型、保险价值、地域、保险期限 |
| 责任险 | 责任类型、营业规模、赔偿限额 |
| 工程险 | 工程类型、工程造价、工期、施工地点 |
| 健康险（短期） | 年龄、性别、保额、是否有社保 |

### 10.3 保费试算引擎

**技术方案：Groovy 脚本引擎（沙箱模式）**

- 每个产品在后台配置 Groovy 计算脚本（存储于数据库）；
- 系统加载脚本后在 Groovy 沙箱环境中执行；
- 脚本执行结果：年缴保费（元）、月缴保费（元，可选）；
- 脚本缓存：热点产品脚本 Redis 缓存，TTL = 1 小时；
- 执行超时：单次试算最长 3 秒，超时返回错误。

**费率表辅助：**

- 复杂产品基于费率表（`ins_product_rate`）查询；
- 费率表结构：`(product_id, province, age_range, coverage_amount) → rate_value`；
- 支持通过 EasyExcel 批量导入费率表，每批 500 条。

### 10.4 试算结果展示

- 年缴保费（元）；
- 保额 / 赔偿限额；
- 保障责任摘要（可折叠）；
- 操作按钮：【制作计划书】【加入购物车（C 端）】【直接出单】。

---

## 11. 功能八：非车险计划书制作

### 11.1 功能概述

业务员基于非车险产品组合配置制作专业 PDF 计划书，发送给客户，是非车险展业的核心销售工具。

### 11.2 计划书制作流程

```
Step 1：选择模板（个人版 / 家庭版 / 企业版）
    ↓
Step 2：方案配置
    ├── 被保人/投保人基本信息
    ├── 主险选择（产品 + 保额 + 缴费期 + 保障期）
    ├── 附加险选择（与主险兼容，≤ 5 个）
    └── 年缴保费自动试算回填
    ↓
Step 3：保障责任汇总展示（可勾选隐藏某些条款）
    ↓
Step 4（储蓄型产品专用）：现金价值表 + 利益演示
    ↓
Step 5：生成 PDF 计划书（异步，轮询状态）
    ↓
分享（微信 / 短信 / 面对面展示）
```

### 11.3 方案配置业务规则

**主险配置：**

| 字段 | 规则 |
|------|------|
| 保额 | 在产品 `min_amount`~`max_amount` 内选择，步进 `amount_increment` |
| 缴费期限 | 从 `payment_period_options` 选择 |
| 保障期限 | 从 `coverage_period_options` 选择 |
| 年缴保费 | 自动调用试算接口计算，不可手动修改 |

**附加险限制：**

- 只展示与主险兼容的附加险（`compatible_main_product_ids` 匹配）；
- 附加险保额不得超过主险保额；
- 最多添加 5 个附加险；
- 删除主险时同时清空所有附加险（弹确认对话框）。

### 11.4 计划书 PDF 内容结构

| 页面 | 内容 |
|-----|------|
| 封面 | 计划书标题、客户姓名、业务员信息、日期 |
| 保障方案概览 | 产品名称、保额、缴费期、年缴保费、总保费 |
| 保障责任详情 | 各险种保障事项、保障金额、生效条件 |
| 现金价值表（储蓄型） | 逐年数据：累计保费 / 现金价值 / 生存金 / 回本年限 / IRR |
| 利益演示折线图 | 现金价值 vs 累计保费趋势图 |
| 免责声明 | 标准合规内容 |
| 业务员名片 | 姓名、职位、联系方式、专属二维码 |

---

## 12. 功能九：寿险保费试算与计划书

### 12.1 功能概述

针对寿险产品（重疾险 / 定期寿险 / 终身寿险 / 年金险 / 万能险）提供保费试算与计划书制作，相比非车险增加了健康告知问卷和现金价值演示。

### 12.2 试算输入字段

| 字段 | 必填 | 校验 |
|------|------|------|
| 被保人姓名 | 是 | 2–20 中文字符 |
| 出生日期 | 是 | 不得是未来日期，周岁不超过 100 |
| 性别 | 是 | 男 / 女 |
| 险种选择 | 是 | 寿险/重疾/医疗/意外/年金/万能险 |
| 保额（元） | 是 | 在 `min_amount`~`max_amount` 内 |
| 保障期限 | 是 | 定期（N 年）/ 终身 |
| 缴费方式 | 是 | 趸缴 / 年缴 / 半年缴 / 季缴 / 月缴 |
| 吸烟状态 | 条件必填 | 部分重疾险/寿险要求 |

### 12.3 费率计算逻辑

寿险保费基于费率表查询（不使用 Groovy 脚本，费率表精确）：

```
查询 ins_life_product_rate：
  (product_id, age, gender, coverage_term) → premium_per_unit（元/万元保额）

年缴保费 = premium_per_unit × (保额/10000)

缴费换算：
  半年缴 = 年缴 × 0.52
  季缴   = 年缴 × 0.265
  月缴   = 年缴 × 0.09
```

### 12.4 现金价值表与利益演示

**触发条件：** 产品类型为年金险 / 增额终身寿险 / 万能险。

**展示数据：**

| 年度 | 年末年龄 | 累计保费 | 现金价值 | 可领取生存金 | 累计领取 |
|-----|---------|---------|---------|------------|---------|
| 1   | 35 岁   | 3 万    | 2.5 万  | —          | —       |
| 5   | 39 岁   | 15 万   | 14.2 万 | —          | —       |
| 10  | 44 岁   | 30 万   | 31.5 万 | 0.5 万/年  | 2.5 万  |
| ... | ...    | ...    | ...    | ...        | ...     |

**关键指标：** 回本年限、IRR（内部收益率）；以折线图展示现金价值趋势。

---

## 13. 功能十：C 端在线报价（车险/非车险）

### 13.1 功能概述

消费者通过微信小程序/H5 自助完成报价，无需业务员介入，完成报价后可直接进入投保流程。

### 13.2 C 端车险报价流程

```
消费者进入"车险报价"入口
    ↓
Step 1：车辆信息录入
  ├── 手动填写车牌号 + VIN + 初登日期 + 品牌车型 + 购置价 + 座位数
  └── 车牌号快速查询（C 端不支持 OCR，需手动输入）
    ↓
Step 2：险种方案选择
  ├── 系统预置标准方案快选（标准型 / 全面型）
  └── 自定义勾选险种和保额
    ↓
Step 3：发起报价（同业务员 App 并发报价引擎）
    ↓
Step 4：展示报价结果（按保费升序）
    ↓
Step 5：选择方案 → 填写投保人信息 → 进入投保流程
```

### 13.3 C 端与 B 端报价的差异点

| 对比项 | 业务员 App（B 端） | C 端小程序/H5 |
|-------|-----------------|-------------|
| OCR 识别 | ✅ 支持 | ❌ 不支持 |
| 报价单 PDF | ✅ 生成并分享 | ❌ 不生成 |
| 保司报价排序 | 支持按佣金排序（内部） | 仅按保费排序 |
| 后续操作 | 引导出单或记录跟进 | 直接进入投保 |
| 数据归属 | 记录至业务员报价列表 | 记录至 C 端用户报价历史 |

---

## 14. 功能十一：续保报价管理

### 14.1 功能概述

临近保单到期时，系统自动生成续保任务，业务员可一键发起续保询价，历史车辆和上年保单数据自动回填。

### 14.2 续保任务来源

| 来源 | 触发条件 |
|------|---------|
| 系统自动创建 | 保单到期前 60 / 30 / 15 / 7 天，XXL-Job 定时扫描，自动创建续保任务 |
| 手动创建 | 业务员在客户详情页手动发起续保跟进 |

### 14.3 续保报价数据回填逻辑

系统通过保司续保查询接口获取上年保单后自动回填：

1. **基础信息核对：** 对比车牌号、VIN、发动机号是否一致；
2. **不一致处理：** 标记"可能过户"，提示业务员人工确认；
3. **自动回填字段：** 上年投保公司、险种组合、保额、出险次数、上年保费；
4. **智能方案推荐：**
   - 上年无赔付 → 推荐延续原方案，提示"可享 NCD 最低折扣"；
   - 上年多次出险 → 推荐降低保额，提示"保费可能上浮"；
   - 上年仅投交强险 → 推荐补充三者险，提示风险。

### 14.4 续保提醒推送

| 推送时机 | 推送方式 | 推送对象 |
|---------|---------|---------|
| 到期前 60 天 | 系统内消息 | 归属业务员 |
| 到期前 30 天 | 系统内消息 + App 推送 | 归属业务员 |
| 到期前 15 天 | App 推送 + 短信（可配置） | 业务员 + 车主 |
| 到期前 7 天 | App 推送 + 短信 | 业务员 + 车主 |

---

## 15. 功能十二：PC 后台报价配置管理

### 15.1 保司 API 管理

菜单路径：设置 → 保险公司管理 → 报价接口配置

| 配置项 | 说明 |
|-------|------|
| 保司名称 / Logo | 展示信息 |
| API 接口地址 | 报价接口 URL |
| AppKey / AppSecret | AES-256 加密存储 |
| 超时时间（秒） | 默认 10，范围 5–30 |
| 启用/停用开关 | 停用后该保司不参与报价 |
| 分地区启用配置 | 支持省份级别独立开关 |

### 15.2 投保方案模板管理

菜单路径：设置 → 方案模板管理

- 新增/编辑/删除方案模板；
- 配置每个模板的险种默认勾选状态和默认保额；
- 配置模板的省份适配规则；
- 模板排序（影响 App 端展示顺序）。

### 15.3 增值服务价格配置

菜单路径：设置 → 增值服务配置

- 配置各增值服务的价格（元）；
- 配置开启/关闭状态；
- 配置适用地区。

### 15.4 报价统计分析

菜单路径：统计 → 报价分析

| 统计维度 | 指标 |
|---------|------|
| 报价量趋势 | 日/周/月报价次数折线图 |
| 保司报价成功率 | 各保司报价成功/失败/超时比例 |
| 报价转化率 | 报价→出单转化率（按保司、险种、业务员） |
| 平均报价保费 | 各保司平均总保费对比 |
| 业务员报价排行 | Top 20 业务员报价量 |

---

## 16. 数据库设计

### 16.1 数据库信息

- **Schema 名称：** `db_ins_quote`
- **表前缀：** `ins_quote_`
- **设计规范：** 无物理外键，应用层维护引用关系；全部继承 `BaseDO`（含 `creator/create_time/updater/update_time/deleted/tenant_id`）

### 16.2 核心表结构

#### ins_quote_vehicle（车辆档案表）

```sql
CREATE TABLE `ins_quote_vehicle` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT,
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0,
  `license_plate`    VARCHAR(20)   NOT NULL                  COMMENT '车牌号',
  `plate_type`       TINYINT       NOT NULL DEFAULT 1         COMMENT '1蓝牌 2黄牌 3绿牌(新能源)',
  `vin_code`         VARCHAR(17)   NOT NULL                  COMMENT '车架号VIN',
  `engine_no`        VARCHAR(30)   NOT NULL                  COMMENT '发动机号',
  `brand_id`         BIGINT        DEFAULT NULL              COMMENT '品牌ID',
  `series_id`        BIGINT        DEFAULT NULL              COMMENT '车系ID',
  `model_id`         BIGINT        DEFAULT NULL              COMMENT '车款ID',
  `vehicle_brand`    VARCHAR(50)   NOT NULL                  COMMENT '品牌名称',
  `vehicle_series`   VARCHAR(50)   DEFAULT NULL              COMMENT '车系名称',
  `vehicle_model`    VARCHAR(100)  NOT NULL                  COMMENT '车款名称',
  `model_year`       VARCHAR(10)   DEFAULT NULL              COMMENT '年款',
  `register_date`    DATE          NOT NULL                  COMMENT '初登日期',
  `purchase_price`   DECIMAL(10,2) NOT NULL                  COMMENT '新车购置价(万元)',
  `actual_value`     DECIMAL(10,2) DEFAULT NULL              COMMENT '当前实际价值(万元，系统计算)',
  `seat_count`       TINYINT       NOT NULL DEFAULT 5        COMMENT '核定座位数',
  `use_type`         TINYINT       NOT NULL DEFAULT 1        COMMENT '1家用 2营运 3租赁 4其他',
  `fuel_type`        TINYINT       DEFAULT 1                 COMMENT '1汽油 2柴油 3纯电 4混动 5燃料电池',
  `owner_name`       VARCHAR(50)   NOT NULL                  COMMENT '车主姓名',
  `owner_mobile`     VARCHAR(11)   NOT NULL                  COMMENT '车主手机号',
  `owner_id_no`      VARCHAR(200)  DEFAULT NULL              COMMENT '车主身份证号(AES256加密)',
  `owner_id_no_mask` VARCHAR(20)   DEFAULT NULL              COMMENT '车主身份证脱敏展示',
  `agent_id`         BIGINT        NOT NULL                  COMMENT '归属业务员ID',
  `customer_id`      BIGINT        DEFAULT NULL              COMMENT '关联客户ID',
  `ocr_image_url`    VARCHAR(500)  DEFAULT NULL              COMMENT '行驶证OCR原图URL',
  `last_quote_time`  DATETIME      DEFAULT NULL              COMMENT '最近报价时间',
  `last_policy_no`   VARCHAR(50)   DEFAULT NULL              COMMENT '上年保单号',
  `last_insurer_code`VARCHAR(20)   DEFAULT NULL              COMMENT '上年承保保司',
  `last_claim_count` TINYINT       DEFAULT 0                 COMMENT '上年出险次数',
  `creator`          VARCHAR(64)   DEFAULT ''                COMMENT '创建者',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64)   DEFAULT ''                COMMENT '更新者',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uk_vin_tenant` (`vin_code`, `tenant_id`),
  INDEX `idx_plate_tenant` (`license_plate`, `tenant_id`),
  INDEX `idx_agent_id` (`agent_id`)
) ENGINE=InnoDB COMMENT='车辆档案表';
```

#### ins_quote_record（报价记录表）

```sql
CREATE TABLE `ins_quote_record` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT,
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0,
  `quote_no`         VARCHAR(32)   NOT NULL                  COMMENT '报价单号（唯一）',
  `vehicle_id`       BIGINT        NOT NULL                  COMMENT '车辆档案ID',
  `agent_id`         BIGINT        NOT NULL                  COMMENT '发起报价的业务员ID',
  `customer_id`      BIGINT        DEFAULT NULL              COMMENT '关联客户ID',
  `source`           VARCHAR(20)   NOT NULL DEFAULT 'app'    COMMENT 'app/pc/h5/mini_program',
  `status`           VARCHAR(20)   NOT NULL DEFAULT 'QUOTING' COMMENT 'QUOTING询价中/QUOTED已报价/ORDERED已出单/EXPIRED已过期',
  `quote_time`       DATETIME      NOT NULL                  COMMENT '发起报价时间',
  `expire_time`      DATETIME      DEFAULT NULL              COMMENT '报价过期时间(通常30分钟后)',
  `selected_insurer` VARCHAR(20)   DEFAULT NULL              COMMENT '最终选定的保司代码',
  `selected_item_id` BIGINT        DEFAULT NULL              COMMENT '最终选定的报价明细ID',
  `plan_config`      JSON          NOT NULL                  COMMENT '投保方案配置JSON',
  `pdf_url`          VARCHAR(500)  DEFAULT NULL              COMMENT '生成的报价单PDF URL',
  `h5_url`           VARCHAR(500)  DEFAULT NULL              COMMENT 'H5分享链接',
  `h5_view_count`    INT           DEFAULT 0                 COMMENT 'H5分享页查看次数',
  `h5_last_view`     DATETIME      DEFAULT NULL              COMMENT '最后查看时间',
  `remark`           VARCHAR(500)  DEFAULT NULL,
  `creator`          VARCHAR(64)   DEFAULT '',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64)   DEFAULT '',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uk_quote_no` (`quote_no`),
  INDEX `idx_vehicle_id` (`vehicle_id`),
  INDEX `idx_agent_create` (`agent_id`, `create_time`),
  INDEX `idx_status` (`status`, `expire_time`)
) ENGINE=InnoDB COMMENT='报价记录表（报价请求主表）';
```

#### ins_quote_item（各保司报价明细表）

```sql
CREATE TABLE `ins_quote_item` (
  `id`                    BIGINT        NOT NULL AUTO_INCREMENT,
  `tenant_id`             BIGINT        NOT NULL DEFAULT 0,
  `record_id`             BIGINT        NOT NULL                  COMMENT '关联报价记录ID',
  `insurer_code`          VARCHAR(20)   NOT NULL                  COMMENT '保司代码(PICC/PINGAN/CPIC等)',
  `insurer_name`          VARCHAR(50)   NOT NULL                  COMMENT '保司名称',
  `status`                VARCHAR(20)   NOT NULL                  COMMENT 'SUCCESS/FAIL/TIMEOUT/REJECTED/MANUAL_REVIEW',
  `error_code`            VARCHAR(20)   DEFAULT NULL              COMMENT '失败错误码',
  `error_message`         VARCHAR(200)  DEFAULT NULL              COMMENT '失败描述',
  `ci_premium`            DECIMAL(10,2) DEFAULT NULL              COMMENT '交强险保费(元)',
  `bi_premium`            DECIMAL(10,2) DEFAULT NULL              COMMENT '商业险保费(元)',
  `vehicle_tax`           DECIMAL(10,2) DEFAULT NULL              COMMENT '车船税(元)',
  `total_premium`         DECIMAL(10,2) DEFAULT NULL              COMMENT '总保费(元)',
  `discount_amount`       DECIMAL(10,2) DEFAULT 0                COMMENT '优惠金额(元)',
  `final_premium`         DECIMAL(10,2) DEFAULT NULL              COMMENT '优惠后实际保费(元)',
  `ncd_coefficient`       DECIMAL(5,3)  DEFAULT NULL              COMMENT 'NCD无赔款优待系数',
  `auto_uw_coefficient`   DECIMAL(5,3)  DEFAULT NULL              COMMENT '自主核保系数',
  `auto_ch_coefficient`   DECIMAL(5,3)  DEFAULT NULL              COMMENT '自主渠道系数',
  `premium_detail`        JSON          DEFAULT NULL              COMMENT '各险种保费明细JSON',
  `discount_info`         JSON          DEFAULT NULL              COMMENT '优惠信息JSON',
  `insurer_quote_no`      VARCHAR(50)   DEFAULT NULL              COMMENT '保司侧报价单号',
  `valid_until`           DATETIME      DEFAULT NULL              COMMENT '报价有效期',
  `anomaly_flag`          VARCHAR(30)   DEFAULT NULL              COMMENT '异常标记:PRICE_TOO_LOW/PRICE_TOO_HIGH',
  `response_time_ms`      INT           DEFAULT NULL              COMMENT '保司接口响应时长(毫秒)',
  `is_selected`           TINYINT       NOT NULL DEFAULT 0        COMMENT '是否被选中出单',
  `sort_order`            INT           DEFAULT 0                COMMENT '展示排序(按总保费从低到高)',
  `creator`               VARCHAR(64)   DEFAULT '',
  `create_time`           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`               VARCHAR(64)   DEFAULT '',
  `update_time`           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`               TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  INDEX `idx_record_id` (`record_id`),
  INDEX `idx_insurer_status` (`insurer_code`, `status`),
  INDEX `idx_total_premium` (`record_id`, `total_premium`)
) ENGINE=InnoDB COMMENT='各保司报价明细表';
```

#### ins_quote_non_motor（非车险/寿险试算记录表）

```sql
CREATE TABLE `ins_quote_non_motor` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT,
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0,
  `quote_no`         VARCHAR(32)   NOT NULL                  COMMENT '试算单号',
  `product_id`       BIGINT        NOT NULL                  COMMENT '产品ID',
  `product_name`     VARCHAR(100)  NOT NULL                  COMMENT '产品名称（冗余）',
  `insurance_type`   TINYINT       NOT NULL                  COMMENT '2非车险 3寿险',
  `agent_id`         BIGINT        NOT NULL                  COMMENT '业务员ID',
  `customer_id`      BIGINT        DEFAULT NULL              COMMENT '关联客户ID',
  `source`           VARCHAR(20)   NOT NULL DEFAULT 'app',
  `insured_name`     VARCHAR(50)   DEFAULT NULL              COMMENT '被保人姓名',
  `insured_age`      TINYINT       DEFAULT NULL              COMMENT '被保人年龄',
  `insured_gender`   TINYINT       DEFAULT NULL              COMMENT '1男 2女',
  `coverage_amount`  BIGINT        DEFAULT NULL              COMMENT '保额(元)',
  `coverage_period`  VARCHAR(20)   DEFAULT NULL              COMMENT '保障期限',
  `payment_period`   VARCHAR(20)   DEFAULT NULL              COMMENT '缴费期限',
  `payment_freq`     TINYINT       DEFAULT 1                 COMMENT '缴费频率:1年缴2半年缴3季缴4月缴5趸缴',
  `annual_premium`   DECIMAL(10,2) DEFAULT NULL              COMMENT '年缴保费(元)',
  `input_params`     JSON          NOT NULL                  COMMENT '试算输入参数JSON',
  `calc_result`      JSON          DEFAULT NULL              COMMENT '试算结果JSON(含明细)',
  `status`           VARCHAR(20)   NOT NULL DEFAULT 'SUCCESS' COMMENT 'SUCCESS/FAIL',
  `proposal_id`      BIGINT        DEFAULT NULL              COMMENT '关联计划书ID',
  `creator`          VARCHAR(64)   DEFAULT '',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64)   DEFAULT '',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uk_quote_no` (`quote_no`),
  INDEX `idx_agent_product` (`agent_id`, `product_id`),
  INDEX `idx_customer_id` (`customer_id`)
) ENGINE=InnoDB COMMENT='非车险/寿险保费试算记录表';
```

#### ins_quote_proposal（计划书表）

```sql
CREATE TABLE `ins_quote_proposal` (
  `id`                BIGINT        NOT NULL AUTO_INCREMENT,
  `tenant_id`         BIGINT        NOT NULL DEFAULT 0,
  `proposal_no`       VARCHAR(32)   NOT NULL                  COMMENT '计划书编号',
  `title`             VARCHAR(100)  NOT NULL                  COMMENT '计划书标题',
  `template_id`       BIGINT        DEFAULT NULL              COMMENT '使用的模板ID',
  `agent_id`          BIGINT        NOT NULL                  COMMENT '制作业务员ID',
  `customer_id`       BIGINT        DEFAULT NULL              COMMENT '关联客户ID',
  `insured_name`      VARCHAR(50)   NOT NULL                  COMMENT '被保人姓名',
  `insured_birthday`  DATE          NOT NULL                  COMMENT '被保人出生日期',
  `insured_gender`    TINYINT       NOT NULL                  COMMENT '1男 2女',
  `plan_config`       JSON          NOT NULL                  COMMENT '方案配置JSON(主险+附加险)',
  `total_annual_prem` DECIMAL(10,2) DEFAULT NULL              COMMENT '合计年缴保费(元)',
  `pdf_url`           VARCHAR(500)  DEFAULT NULL              COMMENT 'PDF文件URL',
  `h5_url`            VARCHAR(500)  DEFAULT NULL              COMMENT 'H5分享链接',
  `pdf_status`        VARCHAR(20)   NOT NULL DEFAULT 'PENDING' COMMENT 'PENDING/GENERATING/SUCCESS/FAIL',
  `view_count`        INT           DEFAULT 0                COMMENT '客户查看次数',
  `last_view_time`    DATETIME      DEFAULT NULL              COMMENT '最后查看时间',
  `hidden_coverages`  JSON          DEFAULT NULL              COMMENT '隐藏的保障责任ID列表',
  `creator`           VARCHAR(64)   DEFAULT '',
  `create_time`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`           VARCHAR(64)   DEFAULT '',
  `update_time`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`           TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uk_proposal_no` (`proposal_no`),
  INDEX `idx_agent_create` (`agent_id`, `create_time`),
  INDEX `idx_customer_id` (`customer_id`)
) ENGINE=InnoDB COMMENT='保险计划书表';
```

#### ins_quote_insurer（保司配置表）

```sql
CREATE TABLE `ins_quote_insurer` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT,
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0,
  `insurer_code`     VARCHAR(20)   NOT NULL                  COMMENT '保司代码(唯一)',
  `insurer_name`     VARCHAR(50)   NOT NULL                  COMMENT '保司名称',
  `insurer_logo`     VARCHAR(500)  DEFAULT NULL              COMMENT 'Logo URL',
  `api_url`          VARCHAR(200)  NOT NULL                  COMMENT '报价接口URL',
  `app_key`          VARCHAR(100)  NOT NULL                  COMMENT 'AppKey(AES加密存储)',
  `app_secret`       VARCHAR(200)  NOT NULL                  COMMENT 'AppSecret(AES加密存储)',
  `timeout_seconds`  TINYINT       NOT NULL DEFAULT 10       COMMENT '接口超时时间(秒)',
  `enabled`          TINYINT       NOT NULL DEFAULT 1        COMMENT '是否启用',
  `sort_order`       INT           DEFAULT 0,
  `service_score`    TINYINT       DEFAULT 80                COMMENT '服务评分(0-100)',
  `region_config`    JSON          DEFAULT NULL              COMMENT '分地区启用配置JSON',
  `creator`          VARCHAR(64)   DEFAULT '',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64)   DEFAULT '',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uk_code_tenant` (`insurer_code`, `tenant_id`)
) ENGINE=InnoDB COMMENT='参与报价的保司配置表';
```

#### ins_quote_plan_template（投保方案模板表）

```sql
CREATE TABLE `ins_quote_plan_template` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT,
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0,
  `name`             VARCHAR(50)   NOT NULL                  COMMENT '模板名称',
  `description`      VARCHAR(200)  DEFAULT NULL              COMMENT '适用场景描述',
  `sort_order`       INT           DEFAULT 0,
  `is_default`       TINYINT       DEFAULT 0                 COMMENT '是否默认推荐',
  `plan_config`      JSON          NOT NULL                  COMMENT '方案配置JSON',
  `region_rules`     JSON          DEFAULT NULL              COMMENT '地域适配规则JSON',
  `age_rules`        JSON          DEFAULT NULL              COMMENT '车龄适配规则JSON',
  `creator`          VARCHAR(64)   DEFAULT '',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`          VARCHAR(64)   DEFAULT '',
  `update_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`          TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB COMMENT='投保方案模板表';
```

#### ins_quote_ocr_log（OCR 识别日志表）

```sql
CREATE TABLE `ins_quote_ocr_log` (
  `id`               BIGINT        NOT NULL AUTO_INCREMENT,
  `tenant_id`        BIGINT        NOT NULL DEFAULT 0,
  `agent_id`         BIGINT        NOT NULL,
  `image_url`        VARCHAR(500)  NOT NULL                  COMMENT 'OCR原图URL',
  `ocr_type`         VARCHAR(20)   NOT NULL DEFAULT 'VEHICLE' COMMENT 'VEHICLE行驶证/ID_CARD身份证',
  `success`          TINYINT       NOT NULL                  COMMENT '1成功 0失败',
  `fail_reason`      VARCHAR(200)  DEFAULT NULL,
  `result_json`      JSON          DEFAULT NULL              COMMENT 'OCR返回原始结果',
  `response_ms`      INT           DEFAULT NULL              COMMENT '接口响应时长(毫秒)',
  `create_time`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_agent_time` (`agent_id`, `create_time`)
) ENGINE=InnoDB COMMENT='OCR识别日志表';
```

---

## 17. 接口清单

### 17.1 业务员 App 端接口（前缀 `/app-api/ins/quote/`）

| 接口路径 | 方法 | 说明 | 权限标识 |
|---------|------|------|---------|
| `/ocr/vehicle-license` | POST | 行驶证 OCR 识别 | `ins:quote:ocr` |
| `/vehicle/save` | POST | 保存/更新车辆档案 | `ins:quote:vehicle:write` |
| `/vehicle/page` | GET | 车辆档案列表（分页） | `ins:quote:vehicle:read` |
| `/vehicle/{id}` | GET | 车辆档案详情 | `ins:quote:vehicle:read` |
| `/vehicle/query-by-plate` | GET | 按车牌查询历史档案 | `ins:quote:vehicle:read` |
| `/plan-template/list` | GET | 获取投保方案模板列表 | 登录即可 |
| `/car/init-request` | POST | 提交车险报价请求（含方案） | `ins:quote:car:quote` |
| `/car/result/{recordId}` | GET | 查询报价结果（轮询） | `ins:quote:car:quote` |
| `/car/record/page` | GET | 报价记录列表（分页） | `ins:quote:car:read` |
| `/car/generate-pdf` | POST | 异步生成 PDF 报价单 | `ins:quote:car:pdf` |
| `/car/pdf-status/{recordId}` | GET | 查询 PDF 生成状态 | `ins:quote:car:pdf` |
| `/car/share-h5` | POST | 生成 H5 分享链接 | `ins:quote:car:share` |
| `/non-motor/calc` | POST | 非车险/寿险保费试算 | `ins:quote:nonmotor:calc` |
| `/non-motor/calc-record/page` | GET | 试算记录列表（分页） | `ins:quote:nonmotor:read` |
| `/proposal/create` | POST | 新建计划书 | `ins:quote:proposal:write` |
| `/proposal/page` | GET | 计划书列表（分页） | `ins:quote:proposal:read` |
| `/proposal/{id}` | GET | 计划书详情 | `ins:quote:proposal:read` |
| `/proposal/generate-pdf` | POST | 异步生成计划书 PDF | `ins:quote:proposal:pdf` |
| `/proposal/pdf-status/{id}` | GET | 查询计划书 PDF 状态 | `ins:quote:proposal:pdf` |

### 17.2 PC 管理后台接口（前缀 `/admin-api/ins/quote/`）

| 接口路径 | 方法 | 说明 |
|---------|------|------|
| `/insurer/page` | GET | 保司配置列表 |
| `/insurer/save` | POST | 新增/更新保司配置 |
| `/insurer/{id}` | DELETE | 删除保司配置 |
| `/insurer/toggle/{id}` | PUT | 启用/停用保司 |
| `/plan-template/page` | GET | 方案模板列表 |
| `/plan-template/save` | POST | 新增/更新方案模板 |
| `/plan-template/{id}` | DELETE | 删除方案模板 |
| `/record/page` | GET | 全局报价记录列表（含跨业务员） |
| `/stat/overview` | GET | 报价统计概览 |
| `/stat/insurer-success-rate` | GET | 各保司报价成功率统计 |
| `/stat/conversion-rate` | GET | 报价转化率统计 |
| `/stat/agent-ranking` | GET | 业务员报价量排行 |

### 17.3 C 端接口（前缀 `/app-api/c/quote/`）

| 接口路径 | 方法 | 说明 |
|---------|------|------|
| `/vehicle/save` | POST | C 端保存车辆信息 |
| `/car/init-request` | POST | C 端发起车险报价 |
| `/car/result/{recordId}` | GET | C 端查询报价结果 |
| `/non-motor/calc` | POST | C 端非车险保费试算 |
| `/history/page` | GET | C 端报价历史 |

### 17.4 H5 分享页公开接口（前缀 `/open-api/quote/`）

| 接口路径 | 方法 | 说明 |
|---------|------|------|
| `/car/share/{token}` | GET | 获取 H5 分享页报价数据 |
| `/car/share/{token}/view` | POST | 记录查看行为（客户端调用） |
| `/proposal/share/{token}` | GET | 获取计划书 H5 分享页数据 |

---

## 18. 非功能性需求

### 18.1 性能指标

| 功能 | 性能指标 |
|------|---------|
| OCR 识别 | < 5 秒（图片上传 + 识别 + 返回） |
| 车险多保司并发报价（全部） | < 20 秒（强制结束时间） |
| 车险多保司并发报价（主流 3 家） | < 10 秒（90% 情况下） |
| 非车险/寿险保费试算 | < 3 秒 |
| 列表分页查询 | < 1 秒 |
| 详情查询 | < 500ms |
| PDF 生成（报价单） | < 30 秒（异步） |
| PDF 生成（计划书） | < 60 秒（异步） |

### 18.2 并发能力

- 高峰期并发报价：50 QPS；
- 目标支持 1,000+ 业务员同时使用；
- 100 并发下报价接口平均响应 < 8 秒；
- 保司接口限流：单保司每分钟最多发起 200 次报价（防封禁）；
- 业务员限流：单业务员每分钟最多发起 10 次报价请求。

### 18.3 可靠性

- 报价结果 MySQL + Redis 双写，防数据丢失；
- 保司接口支持熔断（失败率 > 80% 自动熔断 5 分钟）；
- 系统 SLA 目标：99.5%（月允许停机 < 3.6 小时）；
- OCR 识别准确率 KPI：≥ 95%（按日统计）；
- 多保司报价综合成功率 KPI：≥ 90%。

### 18.4 安全性

| 安全要求 | 实现方式 |
|---------|---------|
| 敏感数据加密 | 车主身份证号 AES-256 加密存储，手机号中间 4 位脱敏展示 |
| 保司 API 凭证 | AppKey/AppSecret AES-256 加密存储，日志不输出 |
| 传输安全 | 全站 HTTPS（TLS 1.2+） |
| 权限控制 | 业务员只能查看本人录入的车辆和报价记录；团队长可查看下属 |
| 操作审计 | 所有写操作记录操作人、时间、变更内容 |

### 18.5 缓存策略

| 缓存对象 | 缓存时长 | Cache Key 格式 |
|---------|---------|--------------|
| 车型库数据 | 1 小时 | `vehicle:brand:{brandId}:series` |
| 报价结果 | 30 分钟 | `quote:result:{recordId}` |
| 车辆基础信息 | 7 天 | `vehicle:info:{vehicleId}` |
| 非车险费率脚本 | 1 小时 | `product:rate-script:{productId}` |
| 方案模板列表 | 10 分钟 | `quote:plan-template:{tenantId}` |
| 保司配置列表 | 10 分钟 | `quote:insurer-list:{tenantId}` |

---

## 19. 开发工时估算

### 19.1 按功能点工时汇总

| 功能 | 前端（天） | 后端（天） | 合计 |
|------|---------|---------|------|
| F1 行驶证 OCR 识别 | 1.5 | 2 | 3.5 |
| F2 车辆信息录入与档案管理 | 2 | 2 | 4 |
| F3 车险投保方案配置 | 2 | 1.5 | 3.5 |
| F4 多保司并发报价引擎 | 0 | 3 | 3 |
| F5 报价结果展示与比价 | 2 | 1 | 3 |
| F6 报价单生成与分享 | 1.5 | 2.5 | 4 |
| F7 非车险保费试算 | 2 | 3 | 5 |
| F8 非车险计划书制作 | 3 | 2.5 | 5.5 |
| F9 寿险保费试算与计划书 | 2.5 | 2 | 4.5 |
| F10 C 端在线报价 | 2 | 1 | 3 |
| F11 续保报价管理 | 1.5 | 2 | 3.5 |
| F12 PC 后台配置管理 | 2 | 2 | 4 |
| **合计** | **22.5** | **22.5** | **45** |

> 以上为纯开发工时，不含联调测试（测试工时约为开发工时的 40%，即约 18 天）。

### 19.2 阶段依赖关系

```
阶段1（必须先完成）：
  F2 车辆档案 → F3 方案配置 → F4 报价引擎 → F5 结果展示 → F6 报价单生成
    ↑ F1 OCR 是 F2 的增强功能，可并行

阶段2（依赖阶段1完成后进行）：
  F11 续保管理 → 依赖 F2 车辆档案 + F4 报价引擎

阶段2（独立开发，可与阶段1并行）：
  F7 非车险试算 → F8 非车险计划书
  F9 寿险试算计划书
  F12 PC 后台配置

阶段3（依赖上述所有基础）：
  F10 C 端报价 → 复用 F4 报价引擎
```

---

## 附录 A：报价状态机说明

### 车险报价记录状态机

```
创建 → QUOTING（询价中）
           ↓ 所有保司返回结果 or 20s 超时
       QUOTED（已报价）
           ↓ 业务员选定方案 → 出单
       ORDERED（已出单）
           ↓ 过期时间到（默认30分钟）
       EXPIRED（已过期）
           ↓ 重新发起
       QUOTING（重新询价，新建记录）
```

### 计划书 PDF 状态机

```
PENDING（待生成）→ GENERATING（生成中）→ SUCCESS（生成成功）
                                       → FAIL（生成失败，可重试）
```

---

## 附录 B：险种代码字典

| 险种代码 | 险种名称 |
|---------|---------|
| `CI` | 交强险 |
| `BI_TD` | 车辆损失险（车损险） |
| `BI_TP` | 第三者责任险（三者险） |
| `BI_DS` | 司乘人员责任险（司乘险） |
| `BI_TD_DED` | 车损险不计免赔 |
| `BI_TP_DED` | 三者险不计免赔 |
| `BI_EW` | 发动机涉水损失险 |
| `BI_GD` | 玻璃单独破损险（国产） |
| `BI_GI` | 玻璃单独破损险（进口） |
| `BI_SC` | 车身划痕损失险 |
| `BI_SF` | 自然损失险 |
| `BI_SB` | 盗抢险 |
| `BI_SP` | 指定专修厂险 |
| `BI_EQ` | 新增设备损失险 |
| `BI_TL` | 轮胎单独破损险 |
| `BI_CR` | 承运人责任险 |

---

## 附录 C：保司代码字典

| 保司代码 | 保司名称 |
|---------|---------|
| `PICC` | 中国人保财险 |
| `PINGAN` | 中国平安财险 |
| `CPIC` | 太保财险 |
| `CLIC` | 中国国寿财险 |
| `PATIC` | 太平洋财险 |
| `TIANPING` | 天平车险 |
| `YONGAN` | 永安财险 |

---

*文档结束*

| 版本 | 日期 | 修改人 | 修改内容 |
|------|------|------|---------|
| V1.0 | 2026-03-06 | 系统 | 初始版本，覆盖车险/非车险/寿险三大报价场景，共 12 个功能点 |

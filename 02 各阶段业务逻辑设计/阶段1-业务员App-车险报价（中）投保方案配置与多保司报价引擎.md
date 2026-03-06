# 业务员App · 车险报价开发文档（中）
# 功能：投保方案配置 & 多保司报价引擎 & 报价结果展示

> **框架**：yudao-cloud（微服务版）  
> **模块**：`yudao-module-carins`  
> **文档范围**：报价流程第3步～第5步，从选择投保方案到查看报价结果

---

## 一、投保方案配置页（Step 3）

### 1.1 页面布局

进入页面后分为三个区：
1. **方案模板快选区**（顶部）：一键选择预设方案
2. **险种配置区**（中部）：交强险 + 商业险逐项配置
3. **增值服务区**（底部）：道路救援、代驾服务等

---

### 1.2 方案模板快选

提供以下预设模板（管理员可在 PC 后台增删改模板内容）：

| 模板名称 | 三者险保额 | 车损险 | 司乘险 | 附加险 | 适用场景 |
|---------|-----------|--------|--------|--------|---------|
| 经济型 | 50万 | ❌ | ❌ | 无 | 老旧车/价格敏感 |
| 标准型 | 100万 | ✅ | 1万/座 | 玻璃险、划痕险（新车）| 大多数家用车 |
| 全面型 | 200万 | ✅（含不计免赔） | 5万/座 | 涉水、自燃、划痕、玻璃（进口）、轮胎 | 新车/豪车 |

点击某模板后，自动将险种配置区内所有字段填充为该模板的配置，业务员可在此基础上手动调整。

**地域适配逻辑**（后端控制，在接口返回模板时带入）：
- 南方省份（粤/闽/浙/沪/琼等）：标准型、全面型默认勾选涉水险；
- 北方省份（黑/吉/辽/内蒙/甘/新等）：标准型默认勾选自燃险。

**车龄适配逻辑**（前端根据 `registerDate` 计算车龄后自动处理）：
- 车龄 0-2 年：推荐划痕险、玻璃险（进口）；
- 车龄 3-6 年：推荐自燃险、玻璃险（国产）；
- 车龄 7 年以上：不推荐划痕险，车损险保额提示「建议低于 xx 万」。

---

### 1.3 交强险配置

- **强制勾选**，复选框置灰不可取消；
- 保费由保司接口返回，本步骤不显示金额（报价前无法知晓）；
- 显示文字：「交强险为法律要求强制投保，已默认选中」。

---

### 1.4 商业险各险种配置规则

#### 1.4.1 三者险（第三者责任险）

- **是否投保**：默认勾选，可取消；
- **保额选择**：下拉单选，档位为：5万 / 10万 / 20万 / 30万 / 50万 / **100万（默认）** / 150万 / 200万 / 300万 / 500万 / 1000万；
- **豪车特殊处理**：若 `purchase_price > 50万`，默认选中 200 万，前端提示「建议高保额保障」。

#### 1.4.2 车辆损失险（车损险）

- **是否投保**：复选框，默认勾选；
- **保额**：取车辆实际价值（后端计算，前端只读展示）：
  - 计算公式：`实际价值 = 新车购置价 × (1 - 9%)^车龄`，最大折旧 80%
  - 例：25万新车，3年车龄 → `25 × 0.91³ ≈ 18.8万`
- **注意**：车损险是以下附加险的前置条件：
  - 车损险不计免赔
  - 发动机涉水损失险
  - 指定专修厂险
  - 若车损险未勾选，上述附加险置灰不可选。

#### 1.4.3 司机/乘客责任险（司乘险）

- **是否投保**：复选框，默认勾选；
- **保额档位**：1万 / 2万 / 5万 / 10万 / 20万（每座）；
- **座位数**：从车辆档案自动取，灰色不可编辑；
- **展示**：`5万/座 × 5座 = 25座险保额`（仅展示，实际以保司接口为准）。

#### 1.4.4 附加险配置

| 附加险名称 | 是否需前置险种 | 互斥规则 | 说明 |
|-----------|------------|---------|------|
| 车损险不计免赔 | 车损险 | — | 投保车损险后可勾选 |
| 三者险不计免赔 | 三者险 | — | 投保三者险后可勾选 |
| 发动机涉水损失险 | 车损险 | — | 俗称涉水险 |
| 指定专修厂险 | 车损险 | — | 保费增加约 10-15% |
| 玻璃单独破损险（国产） | — | 与「进口玻璃」互斥 | 二选一 |
| 玻璃单独破损险（进口） | — | 与「国产玻璃」互斥 | 二选一 |
| 车身划痕损失险 | — | — | 车龄 > 6年时不可选（灰色）|
| 自然损失险 | — | — | — |
| 新增设备损失险 | — | — | 需填写设备总价值（万元）|

**互斥规则前端处理**：勾选「进口玻璃」时，自动取消勾选「国产玻璃」，反之亦然；两个玻璃险不可同时勾选。

**营运车辆强制规则**：若 `use_type = 3`，「承运人责任险」强制勾选且置灰。

---

### 1.5 增值服务配置

| 服务名称 | 说明 | 计费方式 |
|---------|------|---------|
| 道路救援（基础版） | 100公里内免费拖车 | 包含在保费内（保司提供）|
| 道路救援（豪华版） | 300公里内免费拖车 + 油料配送 | 额外收费（具体金额由管理员配置）|
| 代驾服务 | 3次/年免费代驾 | 额外收费 |
| 快速理赔通道 | 理赔优先处理 | 免费赠送 |

增值服务价格在 PC 管理后台 `carins_value_added_service` 表配置，App 端通过接口动态拉取。

---

### 1.6 方案配置完成后提交

**提交接口**：`POST /app-api/carins/quote/init-request`

**请求体**：
```json
{
  "vehicleId": 10001,
  "ciSelected": true,
  "biConfig": {
    "thirdPartySelected": true,
    "thirdPartyAmount": 1000000,
    "vehicleDamageSelected": true,
    "driverPassengerSelected": true,
    "driverPassengerAmountPerSeat": 50000,
    "addons": {
      "vehicleDamageDeductibleFree": true,
      "engineWater": false,
      "glassDomestic": true,
      "glassImported": false,
      "scratch": true
    }
  },
  "valueAddedServices": ["RESCUE_BASIC"]
}
```

**后端处理**：
1. 校验 `vehicleId` 是否归属当前用户；
2. 校验险种组合的前置条件（如车损险未选却选了涉水险，返回 400）；
3. 生成 `quote_no`（格式：`QT + yyyyMMdd + 8位序列号`，如 `QT2026021500000001`）；
4. INSERT `carins_quote_request`，`status = PENDING`；
5. 返回 `quoteRequestId` + `quoteNo`，前端跳转至「报价结果页（Step 4/5）」并触发询价。

---

## 二、多保司并发报价引擎（Step 4）

### 2.1 触发询价

前端获取 `quoteRequestId` 后，立即调用询价接口。**询价为异步+轮询模式**：
1. 前端调用「发起询价」接口；
2. 后端异步并发调用各保司接口；
3. 前端每 2 秒轮询一次「查询结果」接口，直到状态为终态（成功/失败）；
4. 最长等待 20 秒，超时后直接展示已获取到的结果。

---

### 2.2 发起询价接口

- **接口**：`POST /app-api/carins/quote/start`
- **请求体**：`{ "quoteRequestId": 10001 }`
- **后端处理**：
  1. 校验报价请求存在且状态为 `PENDING`；
  2. 查询当前租户 + 当前地区已启用的保司列表（`carins_insurer_config` 表，`enabled=true`，按 `priority` 排序）；
  3. 对每家保司构建报价请求参数（字段映射见 2.4）；
  4. 使用 `CompletableFuture` 并发调用所有保司适配器（线程池隔离，每家保司独立线程池，大小 5）；
  5. 更新 `carins_quote_request.status = QUERYING`；
  6. 返回 `{ "accepted": true }`，询价在后台异步进行。

---

### 2.3 保司适配器接口规范

所有保司适配器实现统一接口 `InsurerQuoteService`，方法签名：

```
QuoteResponse quote(QuoteRequest request);
```

**QuoteRequest 标准字段**（系统内部流转，转换为各保司格式在适配器内完成）：

| 字段 | 类型 | 说明 |
|------|------|------|
| plateNo | String | 车牌号 |
| vin | String | 车架号 |
| engineNo | String | 发动机号 |
| ownerName | String | 车主姓名 |
| ownerIdNo | String | 车主身份证号（解密后传输） |
| registerDate | Date | 初登日期 |
| seatCount | Integer | 座位数 |
| useType | Integer | 使用性质 |
| ciSelected | Boolean | 是否含交强险 |
| biConfig | Object | 商业险配置（各险种保额） |
| startDate | Date | 投保起期（默认次日零时）|
| endDate | Date | 投保止期（startDate + 1年）|

---

### 2.4 保司参数字段映射规则

不同保司字段名、格式各异，适配器内完成转换：

**日期格式**（以系统标准 `yyyy-MM-dd` 为基准）：
- 人保要求：`yyyyMMdd` → 去掉连字符
- 平安要求：`yyyy-MM-dd 00:00:00` → 补时间部分
- 太保要求：`yyyy/MM/dd` → 替换分隔符

**金额格式**（系统内部单位：整数元）：
- 太保要求：`BigDecimal` 保留两位小数
- 国寿要求：单位万元 → 除以 10000

**枚举映射**（使用性质为例）：

| 系统值 | 人保 | 平安 | 太保 |
|--------|------|------|------|
| 1（家庭自用）| A | 01 | FAM |
| 2（企业自用）| B | 02 | ENT |
| 3（营运）   | C | 03 | COM |

映射关系存库：`carins_insurer_field_mapping`，支持热更新（修改数据库即生效，无需重启）。

---

### 2.5 超时与失败重试策略

| 场景 | 处理规则 |
|------|---------|
| 单保司接口超时 | 默认 10 秒超时，超时记为 E001（网络超时），自动重试 1 次，重试间隔 2 秒 |
| 全局最长等待 | 20 秒后强制聚合已有结果，未返回的保司记为超时 |
| 保司返回 5xx 错误 | 记为 E002（接口异常），自动重试 1 次 |
| 保司返回业务拒保 | 不重试，记录拒保原因（E004） |
| 保司返回需人工核保 | 不重试，记录案件号（E005），进入异步轮询队列 |

**熔断机制**（基于 Sentinel 或 Resilience4j）：
- 触发条件：某保司 1 分钟内失败率 > 80%，或连续失败 10 次；
- 熔断动作：停止调用该保司接口 5 分钟；
- 熔断期间：该保司在报价时直接跳过，前端展示「当前暂不可用」；
- 恢复机制：5 分钟后放行 1 个请求（半开），成功则恢复，失败则继续熔断。

---

### 2.6 报价结果入库

每家保司返回（或失败）后，立即 INSERT `carins_quote_result`：

| 字段 | 说明 |
|------|------|
| quote_request_id | 关联询价单ID |
| insurer_code | 保司代码（PICC/PAIC/CPIC 等）|
| status | SUCCESS / FAIL / WAITING_UNDERWRITE |
| error_code | 错误码（E001-E010）|
| error_message | 错误描述 |
| ci_premium | 交强险保费 |
| bi_premium | 商业险保费 |
| vat | 车船税 |
| total_premium | 总保费 |
| ncd_coefficient | NCD系数 |
| auto_underwrite_coeff | 自主核保系数 |
| auto_channel_coeff | 自主渠道系数 |
| final_discount_rate | 最终折扣率 |
| rate_details | JSON，各险种明细（见下方结构）|
| insurer_quote_no | 保司侧报价单号 |
| valid_until | 报价有效期 |
| cost_ms | 接口耗时（毫秒）|

**数据校验逻辑**（入库前执行）：
1. `total_premium = ci_premium + bi_premium + vat`，误差不超过 0.01，否则记录 WARNING 日志，不入库（标记 E007）；
2. `ncd_coefficient` 范围 0.6 ~ 2.0；`auto_underwrite_coeff` 和 `auto_channel_coeff` 范围 0.85 ~ 1.15；超范围记 WARNING；
3. 若某保司报价比其他保司低 30% 以上，设置 `anomaly_flag = PRICE_TOO_LOW`；
4. 若比其他保司高 50% 以上，设置 `anomaly_flag = PRICE_TOO_HIGH`。

**rate_details JSON 结构**：
```json
{
  "ci": { "base_premium": 950.00, "final_premium": 950.00 },
  "bi": {
    "vehicle_damage": { "insured_amount": 188000, "base_premium": 2800.00, "final_premium": 1436.40 },
    "third_party": { "insured_amount": 1000000, "base_premium": 1500.00, "final_premium": 769.50 },
    "driver_passenger": { "insured_amount": 50000, "seats": 5, "base_premium": 350.00, "final_premium": 179.55 },
    "glass_domestic": { "base_premium": 180.00, "final_premium": 92.34 }
  },
  "vat": { "final_amount": 420.00 },
  "coefficients": { "ncd": 0.6, "auto_underwrite": 0.95, "auto_channel": 0.9, "final": 0.513 }
}
```

---

### 2.7 轮询报价状态接口

- **接口**：`GET /app-api/carins/quote/status?quoteRequestId=10001`
- **后端逻辑**：
  1. 查询 `carins_quote_request.status`；
  2. 若状态为终态（COMPLETED / FAILED），同时返回所有 `carins_quote_result` 列表；
  3. 若仍为 `QUERYING`，返回当前已完成的结果数 / 总保司数，供前端展示进度条。
- **响应**：
  ```json
  {
    "status": "QUERYING",
    "completedCount": 2,
    "totalCount": 5,
    "results": []
  }
  ```
  当 `status = COMPLETED` 时，`results` 包含完整结果列表。

---

### 2.8 报价结果排序规则

`COMPLETED` 后，后端返回 `results` 时按以下规则排序（后端控制，前端直接展示）：

1. **成功报价优先**（status=SUCCESS 排在 FAIL/WAITING_UNDERWRITE 前面）；
2. **成功报价内部**：按 `total_premium` 升序（最低价第一，标注「推荐」角标）；
3. **价格异常标注**：`anomaly_flag = PRICE_TOO_LOW` 的方案展示「⚠️ 价格偏低，建议核实」；
4. **失败报价**：按失败类型分组，排在最后；
5. **等待核保**：展示为「审核中，预计 1 个工作日」，排在失败前面。

---

## 三、报价结果展示页（Step 5）

### 3.1 成功报价卡片展示

每家成功报价展示为一张卡片，包含：
- 保司名称 + Logo
- 总保费（大号字体，醒目显示）
- 折扣角标（如「7折」）
- 交强险 / 商业险 / 车船税 分项金额（折叠，点击展开）
- 展开后：各险种明细（险种名 + 保额 + 保费）
- 费率系数（NCD系数、自主核保系数、折扣系数）

最低价卡片额外展示：「💰 最低价 · 推荐」角标。

### 3.2 失败报价展示

以灰色卡片展示，注明失败原因：

| 错误码 | 展示文案 | 操作按钮 |
|--------|---------|---------|
| E001 | 「网络超时，请稍后重试」 | [重新询价] |
| E002 | 「接口异常，可稍后重试」 | [重新询价] |
| E004 | 「该车辆拒保，无法出单」 | [查看原因] |
| E005 | 「需人工核保，预计1个工作日」 | [查看进度] |
| E008 | 「保司系统维护中」 | [重新询价] |
| E009 | 「车辆超出承保范围」 | [查看原因] |

### 3.3 重新询价功能

业务员点击「重新询价」（整体）或单个保司的「重试」：
- 整体重新询价：**保持车辆信息和险种方案不变**，生成新 `quoteRequestId`，重新走 Step 4 流程；
- 单保司重试：`POST /app-api/carins/quote/retry-single`，请求体 `{ "quoteResultId": xxx }`，仅重新调用该保司。

### 3.4 方案在线调整功能

业务员在报价结果页可**直接修改险种方案**，无需返回 Step 3：
- 点击页面顶部「修改方案」按钮，展开险种配置区（同 Step 3 的配置区）；
- 调整后点击「重新报价」，后端以新方案覆盖旧配置，重新发起询价；
- 车辆信息不变，仅险种配置参与变更。

### 3.5 报价有效期提示

- 每张成功报价卡片底部展示 `有效期至：yyyy-MM-dd`；
- 若报价已过期（`valid_until < now()`），卡片置灰并展示「报价已过期，请重新询价」；
- 业务员打开历史报价单时，后端实时检查有效期，过期则在响应中标注 `expired=true`。

---

## 四、报价请求表结构

```sql
CREATE TABLE carins_quote_request (
  id                BIGINT        NOT NULL AUTO_INCREMENT,
  tenant_id         BIGINT        NOT NULL,
  agent_id          BIGINT        NOT NULL                COMMENT '发起报价的业务员',
  vehicle_id        BIGINT        NOT NULL                COMMENT '关联车辆档案',
  quote_no          VARCHAR(30)   NOT NULL                COMMENT '报价单号（唯一）',
  ci_selected       BIT(1)        NOT NULL DEFAULT 1      COMMENT '是否含交强险',
  bi_config         JSON                                  COMMENT '商业险配置JSON',
  value_added       JSON                                  COMMENT '增值服务配置JSON',
  status            VARCHAR(30)   NOT NULL DEFAULT 'PENDING' COMMENT '状态：PENDING/QUERYING/COMPLETED/FAILED',
  sub_status        VARCHAR(50)                           COMMENT '子状态（见业务文档）',
  scenario          VARCHAR(20)                           COMMENT '业务场景：new_quote/renewal/compare',
  source_type       VARCHAR(20)                           COMMENT '来源：app/pc/h5',
  create_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE INDEX uk_quote_no (quote_no),
  INDEX idx_agent_create (agent_id, create_time),
  INDEX idx_vehicle_id (vehicle_id)
) COMMENT '报价请求表';
```

## 五、报价结果表结构

```sql
CREATE TABLE carins_quote_result (
  id                     BIGINT         NOT NULL AUTO_INCREMENT,
  tenant_id              BIGINT         NOT NULL,
  quote_request_id       BIGINT         NOT NULL                COMMENT '关联报价请求ID',
  insurer_code           VARCHAR(20)    NOT NULL                COMMENT '保司代码',
  status                 VARCHAR(20)    NOT NULL                COMMENT 'SUCCESS/FAIL/WAITING_UNDERWRITE',
  error_code             VARCHAR(10)                           COMMENT '错误码',
  error_message          VARCHAR(500)                          COMMENT '错误描述',
  ci_premium             DECIMAL(10,2)                         COMMENT '交强险保费',
  bi_premium             DECIMAL(10,2)                         COMMENT '商业险保费',
  vat                    DECIMAL(10,2)                         COMMENT '车船税',
  total_premium          DECIMAL(10,2)                         COMMENT '总保费',
  ncd_coefficient        DECIMAL(5,3)                          COMMENT 'NCD系数',
  auto_underwrite_coeff  DECIMAL(5,3)                          COMMENT '自主核保系数',
  auto_channel_coeff     DECIMAL(5,3)                          COMMENT '自主渠道系数',
  final_discount_rate    DECIMAL(5,3)                          COMMENT '最终折扣率',
  rate_details           JSON                                  COMMENT '费率明细JSON',
  insurer_quote_no       VARCHAR(50)                           COMMENT '保司侧报价单号',
  valid_until            DATETIME                              COMMENT '报价有效期',
  anomaly_flag           VARCHAR(30)                           COMMENT '异常标记：PRICE_TOO_LOW/PRICE_TOO_HIGH',
  manual_case_no         VARCHAR(50)                           COMMENT '人工核保案件号',
  cost_ms                INT                                   COMMENT '接口耗时（毫秒）',
  create_time            DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_quote_request (quote_request_id),
  INDEX idx_insurer_create (insurer_code, create_time)
) COMMENT '报价结果表';
```

## 六、保司配置表结构

```sql
CREATE TABLE carins_insurer_config (
  id                BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id         BIGINT       NOT NULL,
  insurer_code      VARCHAR(20)  NOT NULL                COMMENT '保司代码',
  insurer_name      VARCHAR(50)  NOT NULL                COMMENT '保司名称',
  adapter_class     VARCHAR(200) NOT NULL                COMMENT '适配器全类名',
  api_base_url      VARCHAR(200)                         COMMENT '接口基础URL',
  app_key           VARCHAR(100)                         COMMENT '接口AppKey',
  app_secret        VARCHAR(200)                         COMMENT '接口AppSecret（加密存储）',
  timeout_ms        INT          NOT NULL DEFAULT 10000  COMMENT '超时时间（毫秒）',
  retry_times       TINYINT      NOT NULL DEFAULT 1      COMMENT '重试次数',
  enabled           BIT(1)       NOT NULL DEFAULT 1      COMMENT '全局启用开关',
  priority          TINYINT      NOT NULL DEFAULT 50     COMMENT '优先级（越小越优先）',
  quote_valid_days  TINYINT      NOT NULL DEFAULT 1      COMMENT '报价有效天数',
  region_config     JSON                                 COMMENT '分地区启用配置JSON',
  create_time       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE INDEX uk_tenant_insurer (tenant_id, insurer_code)
) COMMENT '保司配置表';
```

---

## 七、限流配置

通过 yudao-cloud 集成的 Spring Cloud Gateway + Sentinel 实现：

| 限流维度 | 规则 | 说明 |
|---------|------|------|
| 业务员 + 报价接口 | 每分钟最多 10 次 | 防误操作/刷单 |
| 保司 PICC | 100 QPS | 依照保司协议 |
| 保司 PAIC | 50 QPS | 依照保司协议 |

---

*文档版本：V3.0 | 范围：报价流程 Step3-Step5 | 下一篇：报价单生成分享 & 续保管理 & 数据库汇总*

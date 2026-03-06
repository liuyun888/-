# 业务员App · 车险报价开发文档（上）
# 功能：行驶证OCR识别 & 车辆信息录入确认

> **框架**：yudao-cloud（微服务版）  
> **模块**：`yudao-module-carins`  
> **文档范围**：报价流程第1步～第2步，从发起报价到车辆信息确认完成

---

## 一、入口：发起报价

### 1.1 页面位置

业务员 App 首页底部导航 → **「报价」** Tab，点击后进入报价入口页。

页面展示三个操作按钮：

| 按钮 | 说明 |
|------|------|
| 📷 拍照识别行驶证 | 调用摄像头，OCR 自动填充 |
| 🔍 输入车牌查档案 | 查已有车辆档案，直接回显 |
| ✏️ 手动录入 | 全手动填写车辆信息 |

---

## 二、方式 A：拍照识别行驶证（OCR）

### 2.1 拍照页面交互流程

1. 业务员点击「拍照识别行驶证」；
2. App 打开摄像头，展示取景框（矩形覆盖层）；
3. 前端实时检测（每帧）：
   - 是否检测到行驶证边框（四角定位）；
   - 亮度值是否 < 30（提示「光线不足，请移至明亮处」）；
   - 高光区域是否 > 20%（提示「请避免反光」）；
4. 当行驶证边框稳定 1 秒后，**自动触发拍照**（也可手动按快门）；
5. 展示预览图，业务员确认后点击「识别」按钮；
6. 上传图片到 OSS，同时调用 OCR 接口。

**注意**：首次使用时，弹出拍摄示例引导图（展示一次即关闭，记录 localStorage 标志位）。

### 2.2 图片上传接口

- **接口**：`POST /app-api/carins/ocr/upload-image`  
- **请求**：`multipart/form-data`，字段名 `file`，格式限 jpg/png，大小限 10MB
- **后端处理**：
  1. 校验文件格式与大小，不合法返回错误；
  2. 上传至阿里云 OSS，路径规则：`/{tenantId}/ocr-temp/{yyyyMMdd}/{uuid}.jpg`；
  3. 返回 `imageUrl`（临时 URL，24 小时有效）。

### 2.3 OCR 识别接口

- **接口**：`POST /app-api/carins/ocr/recognize-driving-license`  
- **请求体**：
  ```json
  { "imageUrl": "https://oss.xxx.com/xxx.jpg" }
  ```
- **后端处理**：
  1. 调用Deepseek OCR；
  4. 将 OCR 原始结果转换为系统标准字段（字段映射见 2.4）；
  5. 对每个字段执行格式校验（见 2.5）；
  6. 入库至 `carins_ocr_record` 表（记录原始结果、置信度、耗时）；
  7. 返回结构化识别结果 + 置信度 + 校验警告列表。
  
- **响应体**：
  ```json
  {
    "plateNo": "京A12345",
    "vin": "LVGBR2A5XFN123456",
    "engineNo": "ABC12345",
    "registerDate": "2020-03-15",
    "owner": "张三",
    "brand": "大众",
    "vehicleType": "小型轿车",
    "seatCount": 5,
    "confidenceMap": {
      "plateNo": 98,
      "vin": 92,
      "engineNo": 76,
      "registerDate": 95
    },
    "warnings": [
      { "field": "engineNo", "level": "RED", "message": "发动机号置信度低，请手动核对" }
    ]
  }
  ```

### 2.4 OCR 字段映射规则

| 系统标准字段 | 腾讯云 OCR 字段 | 阿里云 OCR 字段 | 说明 |
|------------|--------------|--------------|------|
| plateNo | PlateNum | plate_num | 车牌号 |
| vin | Vin | vin | 车架号 |
| engineNo | EngineNum | engine_num | 发动机号 |
| registerDate | RegisterDate | register_date | 初次登记日期 |
| owner | Owner | owner_name | 车主姓名 |
| vehicleType | VehicleType | vehicle_type | 车辆类型 |
| seatCount | SeatCount | seat_count | 核定座位数 |

### 2.5 OCR 结果字段校验规则

后端逐字段校验，不合法的字段加入 warnings 列表：

| 字段 | 校验规则 | 异常处理 |
|------|---------|---------|
| plateNo | 正则：`^[京津沪...琼使领][A-Z][A-HJ-NP-Z0-9]{5}$` | 标红，提示「车牌号格式异常，请核对」 |
| vin | 长度=17位；第9位校验码通过 ISO 3779 算法验证 | 标红，提示「车架号可能有误，请核对」 |
| engineNo | 6-8位，不含汉字，不含特殊符号 | 黄色警告，提示「请手动确认发动机号」 |
| registerDate | 不能晚于当前日期；不能早于 1990-01-01；如识别为 25XX 开头，自动修正为 20XX | 标红提示 |
| seatCount | 整数，范围 2-55 | 标红，提示「座位数异常，请核对」 |

**置信度展示规则**（前端渲染逻辑）：

| 置信度 | 前端展示 | 是否允许直接提交 |
|--------|---------|----------------|
| ≥ 95 | 正常显示（绿色对勾） | 是 |
| 80 ~ 94 | 黄色高亮 + 「建议复核」 | 是（需业务员主动确认） |
| < 80 | 红色高亮 + 「请修改」 | 否（必须手动修改后才能提交） |

### 2.6 OCR 失败处理

失败定义：接口失败，或所有字段置信度均 < 50%。

前端展示友好提示弹窗：
```
未能成功识别行驶证，请检查：
1. 行驶证完整在取景框内
2. 光线充足，避免反光
3. 镜头对焦清晰

[重新拍摄]   [手动输入]
```

部分识别成功时（≥1 个字段有结果），保留已识别字段，只对未识别/低置信度字段标红要求手动填写，**不清空已有内容**。

---

## 三、方式 B：输入车牌查档案

### 3.1 交互流程

1. 业务员点击「输入车牌查档案」；
2. 弹出输入框，业务员输入车牌号（前端实时格式校验）；
3. 输入完成后点击「查询」；
4. 后端返回该租户下匹配的车辆档案列表；
5. 如有多条，展示列表（车牌号、车主名、最近报价时间）供业务员选择；
6. 选择后，档案信息自动填充到车辆信息表单。

### 3.2 查询接口

- **接口**：`GET /app-api/carins/vehicle/query-by-plate?plateNo=京A12345`
- **权限**：业务员只能查询本人录入的档案；团队长可查询本团队；管理员可查询全租户
- **后端逻辑**：
  1. 校验车牌号格式；
  2. `WHERE plate_no = #{plateNo} AND tenant_id = #{tenantId}` + 权限过滤；
  3. 返回档案列表（按 `update_time` 倒序）；
  4. 如无结果，返回空列表，前端提示「未找到档案，请手动录入」。

---

## 四、车辆信息确认 & 补充页面

### 4.1 页面说明

无论通过哪种方式获取信息，最终都进入「车辆信息确认页」。该页面是报价前的最后一步信息校验，业务员需核对并补全所有必填字段。

### 4.2 页面字段定义

**车辆基本信息区**（必填）：

| 字段 | 类型 | 必填 | 校验规则 | 备注 |
|------|------|------|---------|------|
| 车牌号 | 文本 | 是 | 正则校验 | OCR 回填可编辑 |
| 车架号（VIN） | 文本 | 是 | 17位 + 校验码 | OCR 回填可编辑 |
| 发动机号 | 文本 | 是 | 6-8位纯字母数字 | OCR 回填可编辑 |
| 初次登记日期 | 日期选择器 | 是 | 不能晚于今天 | 影响车龄计算 |
| 座位数 | 数字选择 | 是 | 2-55 之间整数 | 影响司乘险计算 |
| 使用性质 | 下拉选择 | 是 | 枚举：家庭自用/企业自用/营运/其他 | 影响承保规则 |

**车主信息区**（必填）：

| 字段 | 类型 | 必填 | 校验规则 | 备注 |
|------|------|------|---------|------|
| 车主姓名 | 文本 | 是 | 2-20 个汉字或字母 | — |
| 车主手机号 | 文本 | 是 | 11位，1开头 | 用于续保提醒 |
| 车主证件类型 | 下拉 | 是 | 居民身份证/护照/港澳台 | — |
| 车主证件号码 | 文本 | 是 | 与证件类型匹配的格式校验 | AES-256 加密存储 |

**车型信息区**（必填）：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 品牌 | 搜索下拉 | 是 | 支持拼音首字母搜索，如输入「bs」显示「奔驰/宝马/保时捷」 |
| 车系 | 联动下拉 | 是 | 选品牌后加载，按年款排序 |
| 车款 | 联动下拉 | 是 | 精确到排量、配置（如「2.0T 自动豪华型」） |
| 新车购置价 | 数字输入 | 是 | 单位：万元，保留2位小数，最大9999.99 |

**选车款后自动回填**（不可手动修改，灰色展示）：

- 座位数（若与行驶证不一致，弹出确认框，以业务员选择为准）
- 整备质量
- 车型类别（轿车/SUV/货车等）

### 4.3 车型搜索接口

- **接口**：`GET /app-api/carins/vehicle/model/search?keyword=大众&type=brand`
- **type 枚举**：`brand`/`series`/`model`（品牌/车系/车款）
- **参数**：`parentId` 为上级选中的 ID（选车系时传品牌ID）
- **后端逻辑**：查询 `carins_vehicle_model` 车型库，LIKE 模糊匹配，结果缓存 1 小时（Redis）；停产车系标注 `discontinued=true`

### 4.4 VIN 码智能解析接口

- **接口**：`POST /app-api/carins/vehicle/parse-vin`
- **请求体**：`{ "vin": "LVGBR2A5XFN123456" }`
- **后端逻辑**：
  1. 校验 VIN 格式和校验码；
  2. 解析第 1-3 位 WMI → 推断品牌/制造商；
  3. 解析第 10 位 → 推算出厂年份（见年份代码表）；
  4. 查询车型库匹配结果（精确+模糊）；
  5. 返回推断信息供业务员参考（不强制覆盖）。
- **响应**：
  ```json
  {
    "suggestBrandName": "大众",
    "suggestYear": 2020,
    "suggestModels": [
      { "modelId": "101", "modelName": "途观L 2.0T 自动四驱豪华版", "year": 2020 }
    ],
    "vinValid": true
  }
  ```

### 4.5 历史保单数据回填（续保场景）

当该车辆存在历史出单记录时，系统从 `carins_policy` 表读取上年保单信息，在页面底部展示「上年保单参考」折叠区：

- 上年投保公司、险种组合、各险种保额
- 上年出险次数、NCD 系数（用于本次报价参考）
- 上年保费合计

业务员可一键「沿用上年方案」，自动填充投保方案（进入第 3 步时预选）。

### 4.6 提交车辆信息

**提交接口**：`POST /app-api/carins/vehicle/save-or-update`

**后端处理步骤**：

1. **必填校验**：校验所有必填字段；任何字段不合法返回 400，指明具体字段名和错误原因；
2. **VIN 重复检测**：
   - 同一租户内相同 VIN → 查询已有档案，返回「该 VIN 已有档案」提示，附已有档案 ID；
   - 前端弹确认框：「是否使用已有档案？」→ 确认则返回已有档案，取消则继续新建；
3. **车牌号重复检测**：同上；
4. **数据写入**：
   - 若新建：INSERT `carins_vehicle`，`status` = `COMPLETED`（所有必填项齐全）
   - 若更新：UPDATE，记录 `update_by`/`update_time`；
5. **证件号码加密**：入库前 AES-256 加密；
6. **关联OCR记录**：若本次经过 OCR，更新 `carins_ocr_record.vehicle_id`；
7. **返回** `vehicleId`，前端跳转至「投保方案选择页（第 3 步）」。

### 4.7 车辆档案表（carins_vehicle）核心字段

```sql
CREATE TABLE carins_vehicle (
  id             BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
  tenant_id      BIGINT       NOT NULL                COMMENT '租户ID',
  agent_id       BIGINT       NOT NULL                COMMENT '归属业务员ID',
  plate_no       VARCHAR(20)  NOT NULL                COMMENT '车牌号',
  vin            VARCHAR(17)  NOT NULL                COMMENT '车架号',
  engine_no      VARCHAR(20)  NOT NULL                COMMENT '发动机号',
  register_date  DATE         NOT NULL                COMMENT '初次登记日期',
  seat_count     TINYINT      NOT NULL                COMMENT '核定座位数',
  use_type       TINYINT      NOT NULL                COMMENT '使用性质 1家用 2企业 3营运',
  brand_name     VARCHAR(50)                          COMMENT '品牌名称',
  series_name    VARCHAR(50)                          COMMENT '车系名称',
  model_id       BIGINT                               COMMENT '关联车型库ID',
  model_name     VARCHAR(100)                         COMMENT '车款名称',
  purchase_price DECIMAL(10,2)                        COMMENT '新车购置价（万元）',
  owner_name     VARCHAR(50)  NOT NULL                COMMENT '车主姓名',
  owner_mobile   VARCHAR(11)  NOT NULL                COMMENT '车主手机号',
  id_type        TINYINT      NOT NULL DEFAULT 1      COMMENT '证件类型 1身份证 2护照',
  id_no_encrypt  VARCHAR(255) NOT NULL                COMMENT '证件号码（AES加密）',
  status         TINYINT      NOT NULL DEFAULT 1      COMMENT '档案状态 1新建 2待完善 3已完善 4已报价 5已投保 6续保中 7已失效',
  creator        BIGINT                               COMMENT '创建人',
  create_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updater        BIGINT                               COMMENT '更新人',
  update_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted        BIT(1)       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  INDEX idx_plate_no    (plate_no, tenant_id),
  INDEX idx_vin         (vin, tenant_id),
  INDEX idx_agent_id    (agent_id),
  INDEX idx_owner_mobile (owner_mobile)
) COMMENT '车辆档案表';
```

### 4.8 OCR 记录表（carins_ocr_record）

```sql
CREATE TABLE carins_ocr_record (
  id             BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id      BIGINT       NOT NULL,
  agent_id       BIGINT       NOT NULL,
  vehicle_id     BIGINT                              COMMENT '关联车辆ID（识别成功后回填）',
  image_url      VARCHAR(500) NOT NULL               COMMENT 'OSS图片URL',
  provider       VARCHAR(20)  NOT NULL               COMMENT 'OCR服务商 TENCENT/ALIYUN/BAIDU',
  raw_result     JSON                                COMMENT '原始识别结果JSON',
  plate_no       VARCHAR(20)                         COMMENT '识别到的车牌号',
  vin            VARCHAR(17)                         COMMENT '识别到的VIN',
  confidence_map JSON                                COMMENT '各字段置信度',
  warnings       JSON                                COMMENT '校验警告列表',
  cost_ms        INT                                 COMMENT '识别耗时（毫秒）',
  status         TINYINT      NOT NULL DEFAULT 1     COMMENT '1成功 2部分成功 3失败',
  create_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_agent_create (agent_id, create_time)
) COMMENT 'OCR识别记录表';
```

---

## 五、特殊场景处理

### 5.1 营运车辆特殊规则

当 `use_type = 3`（营运）时：
- 保存时后端自动在车辆档案标注 `is_commercial = true`；
- 进入投保方案选择页后，「承运人责任险」默认勾选且锁定不可取消；
- 部分保司不支持营运车报价，调用时自动跳过。

### 5.2 数据变更历史

对以下关键字段的修改，需写入 `carins_vehicle_change_log`：

| 触发字段 | 说明 |
|---------|------|
| vin | 车架号修改（可能是过户或录入错误） |
| engine_no | 发动机号修改 |
| plate_no | 车牌号修改（可能换牌） |
| owner_name / id_no | 车主变更（可能过户） |

日志字段：`vehicle_id`、`change_field`、`old_value`（脱敏）、`new_value`（脱敏）、`change_by`、`change_time`、`change_reason`（业务员手填）

当检测到 `owner_name` 或 `id_no` 变更时，前端弹出提示：
```
检测到车主信息变更，是否为车辆过户？
[是，标记过户]   [否，仅修正录入错误]
```

### 5.3 权限数据隔离规则

所有接口均通过 JWT 解析 `userId` + `tenantId`，后端执行以下隔离：

| 角色 | 数据范围 |
|------|---------|
| 业务员（AGENT） | 仅查询 `agent_id = 当前用户ID` 的数据 |
| 团队长（LEADER） | 查询本团队所有成员的数据（`dept_id IN (...)`) |
| 内勤/管理员（ADMIN） | 查询全租户数据（`tenant_id = 当前租户ID`） |

---

*文档版本：V3.0 | 范围：报价流程 Step1-Step2 | 下一篇：投保方案配置 & 多保司报价引擎*

# 阶段1 · PC管理后台 · 业务逻辑开发文档（下）
## 产品管理 / 保险公司管理 / 产品机构授权 / 系统配置

> **框架**：yudao-cloud（微服务版）  
> **文档分篇**：上篇（组织架构）· 中篇（人员管理）· **下篇（产品管理 & 系统配置）**  
> **工时预估（1前端+1后端）**：前端 8.5天 / 后端 11.5天

---

## 一、产品分类管理（biz_product_category）

### 1.1 页面入口

菜单路径：**产品管理 → 产品分类**，展示树形分类列表（如：车险 / 非车险 → 健康险 / 意外险 / 财产险）。

操作：**[新增分类] [编辑] [删除] [上移/下移]**（支持拖拽排序）。

### 1.2 新增分类

弹窗字段：

| 字段 | 必填 | 校验 | 说明 |
|---|---|---|---|
| 上级分类 | 否 | — | parent_id；不选则为顶级 |
| 分类名称 | **必填** | 2~30字符；同级下唯一 | category_name |
| 分类编码 | **必填** | 全局唯一，字母数字下划线 | category_code，创建后不可改 |
| 图标 | 否 | 图片URL | icon |
| 排序 | **必填** | 默认0 | sort |
| 状态 | **必填** | 默认启用 | status |

**后端逻辑**：
1. 校验 category_code 唯一：`SELECT COUNT(*) FROM biz_product_category WHERE category_code=#{code} AND deleted=0`，count>0 抛出 `分类编码已存在`。
2. 同级同名校验：`SELECT COUNT(*) FROM biz_product_category WHERE parent_id=#{parentId} AND category_name=#{name} AND deleted=0`，count>0 抛出 `同级分类下已存在该名称`。
3. 自动构建 ancestors，入库。
4. 清除分类树缓存（Redis key：`product_category:tree`，TTL 1小时）。

### 1.3 删除分类

依次校验，任一不通过则拒绝：
1. `SELECT COUNT(*) FROM biz_product_category WHERE parent_id=#{id} AND deleted=0` → count>0 拒绝，提示 `存在子分类，请先删除子分类`。
2. `SELECT COUNT(*) FROM biz_product WHERE category_id=#{id} AND deleted=0` → count>0 拒绝，提示 `该分类下存在 {count} 个产品，请先迁移产品`。
3. 通过后逻辑删除，清除缓存。

### 1.4 数据库表结构

```sql
CREATE TABLE `biz_product_category` (
  `id`            BIGINT      NOT NULL AUTO_INCREMENT,
  `parent_id`     BIGINT      NOT NULL DEFAULT 0,
  `ancestors`     VARCHAR(500) DEFAULT '',
  `category_name` VARCHAR(30) NOT NULL,
  `category_code` VARCHAR(30) NOT NULL COMMENT '唯一',
  `icon`          VARCHAR(500) DEFAULT NULL,
  `sort`          INT         NOT NULL DEFAULT 0,
  `status`        TINYINT     NOT NULL DEFAULT 1,
  `creator`       VARCHAR(64) DEFAULT '',
  `create_time`   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`       VARCHAR(64) DEFAULT '',
  `update_time`   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`       TINYINT     NOT NULL DEFAULT 0,
  `tenant_id`     BIGINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_category_code` (`category_code`, `deleted`),
  KEY `idx_parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='产品分类表';
```

---

## 二、保险公司管理（biz_insurance_company）

### 2.1 页面入口

菜单路径：**产品管理 → 保险公司**，展示分页列表。

搜索：公司名称（模糊）、公司类型（下拉）、状态（下拉）。

操作列：**[编辑] [停用/启用] [测试连接]**。

### 2.2 新增保险公司

弹窗字段：

| 字段 | 必填 | 校验 | 说明 |
|---|---|---|---|
| 公司代码 | **必填** | 全局唯一，大写字母+数字 | company_code，创建后不可改 |
| 公司名称 | **必填** | 2~100字符 | company_name |
| 公司类型 | **必填** | 枚举 | 1-财险 2-寿险 3-健康险 4-养老险 |
| 公司Logo | 否 | 图片，≤2MB | company_logo，上传OSS |
| 联系人 | 否 | — | contact_person |
| 联系电话 | 否 | 11位手机号 | contact_phone |
| 对接方式 | **必填** | 枚举 | 1-API对接 2-文件对接 3-人工对接 |
| API地址 | 当对接方式=1时**必填** | URL格式，HTTPS开头 | api_url |
| API密钥 | 当对接方式=1时**必填** | — | api_key，AES-256 加密存储 |
| API超时(秒) | 否 | 默认30，范围1~300 | api_timeout |
| API重试次数 | 否 | 默认3，范围0~5 | api_retry |
| 状态 | **必填** | 默认启用 | — |
| 排序 | **必填** | 默认0 | sort |

**后端逻辑**：
1. 校验 company_code 全局唯一。
2. 对接方式=1时，校验 api_url 格式（正则：`^https://.*`）和 api_key 非空。
3. api_key AES-256 加密后存储。
4. 入库，清除保险公司下拉缓存（Redis key：`insurance_company:simple_list`）。

### 2.3 测试连接

**接口**：`POST /biz/insurance-company/test-connect/{id}`

后端：
1. 读取该公司的 api_url，解密 api_key。
2. 构造 HTTP GET 请求，发送到 `{api_url}/health`（优先）或 `{api_url}/ping`，设置超时 5 秒。
3. 返回结果：`{ "status": "success/fail", "responseTime": 150, "httpCode": 200, "message": "..." }`。
4. 将最近一次连接状态（含时间戳）存入 Redis（key: `ins_company:connect:{id}`，TTL 10 分钟）。
5. 同时更新 biz_insurance_company.last_connect_status 和 last_connect_time 字段。

### 2.4 保险公司停用联动

点击 [停用] 按钮，后端：
1. 统计旗下在售产品数：`SELECT COUNT(*) FROM biz_product WHERE company_id=#{id} AND status=1 AND deleted=0`。
2. 若 count > 0，**前端**弹出确认提示：`停用该保险公司将同时下架旗下 {count} 个在售产品，确认继续？`。
3. 用户确认后（请求参数携带 `forceConfirm=true`）：
   - UPDATE biz_insurance_company SET status = 0。
   - UPDATE biz_product SET status = 0, off_shelf_time = NOW() WHERE company_id = #{id} AND status = 1 AND deleted = 0。
   - 查询受影响产品的已授权机构，批量发通知：`保险公司【{companyName}】已停用，其旗下产品【{productName}】已自动下架`。

### 2.5 数据库表结构

```sql
CREATE TABLE `biz_insurance_company` (
  `id`                 BIGINT       NOT NULL AUTO_INCREMENT,
  `company_code`       VARCHAR(30)  NOT NULL COMMENT '公司代码（唯一）',
  `company_name`       VARCHAR(100) NOT NULL COMMENT '公司名称',
  `company_type`       TINYINT      NOT NULL COMMENT '1-财险 2-寿险 3-健康险 4-养老险',
  `company_logo`       VARCHAR(500) DEFAULT NULL,
  `contact_person`     VARCHAR(20)  DEFAULT NULL,
  `contact_phone`      VARCHAR(11)  DEFAULT NULL,
  `connect_type`       TINYINT      NOT NULL DEFAULT 3 COMMENT '1-API 2-文件 3-人工',
  `api_url`            VARCHAR(200) DEFAULT NULL,
  `api_key`            VARCHAR(300) DEFAULT NULL COMMENT 'AES-256加密',
  `api_timeout`        INT          DEFAULT 30,
  `api_retry`          INT          DEFAULT 3,
  `last_connect_status` TINYINT     DEFAULT NULL COMMENT '最近连接状态：0-失败 1-成功',
  `last_connect_time`  DATETIME     DEFAULT NULL,
  `status`             TINYINT      NOT NULL DEFAULT 1,
  `sort`               INT          NOT NULL DEFAULT 0,
  `creator`            VARCHAR(64)  DEFAULT '',
  `create_time`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`            VARCHAR(64)  DEFAULT '',
  `update_time`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`            TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`          BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_company_code` (`company_code`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保险公司表';
```

---

## 三、产品管理（biz_product）

### 3.1 页面入口

菜单路径：**产品管理 → 产品列表**，展示分页列表。

搜索：产品名称（模糊）、产品代码（精确）、保险公司（下拉）、产品分类（树形下拉）、状态（下拉：全部/下架/上架）。

操作列：**[编辑] [上架/下架] [授权管理] [删除]**。列表页支持**批量上架/下架**（勾选多条）。

### 3.2 新增产品

弹窗分三个 Tab：**基本信息 / 费率配置 / 佣金配置**。

#### Tab 1：基本信息

| 字段 | 必填 | 校验 | 说明 |
|---|---|---|---|
| 产品代码 | **必填** | 全局唯一，格式建议：公司代码-险种-序号 | product_code，创建后不可改 |
| 产品名称 | **必填** | 2~100字符 | product_name |
| 保险公司 | **必填** | 下拉，只显示启用的公司 | company_id，创建后不可改 |
| 产品类型 | **必填** | 1-车险 2-非车险 | product_type，创建后不可改 |
| 产品分类 | **必填** | 树形选择，只显示启用的分类 | category_id |
| 险种类型 | **必填** | 从数据字典 insurance_type 中选 | insurance_type |
| 产品图片 | 否 | JPG/PNG ≤2MB | product_image，上传OSS；上架前必须有值 |
| 产品简介 | 否 | 最多200字 | product_summary |
| 产品详情 | 否 | 富文本（Quill/TinyMCE） | product_detail（MEDIUMTEXT） |
| 保障期限(月) | **必填** | 1~360 | coverage_period |
| 保费范围（最小） | 否 | > 0，单位：分 | min_premium |
| 保费范围（最大） | 否 | ≥ min_premium | max_premium |
| 保额范围（最小） | 否 | > 0，单位：分 | min_coverage |
| 保额范围（最大） | 否 | ≥ min_coverage | max_coverage |
| 库存预警值 | **必填** | 默认10 | stock_alert_threshold |
| 库存 | **必填** | -1=无限；≥0=有限库存 | stock，默认 -1 |
| 排序 | **必填** | 默认0 | sort |
| 定时上架时间 | 否 | 必须是未来时间 | auto_on_shelf_time |
| 定时下架时间 | 否 | 必须 > 定时上架时间 | auto_off_shelf_time |

#### Tab 2：费率配置（仅车险产品，product_type=1）

- 支持上传**费率表 Excel**（使用 EasyExcel 解析）。
- 费率表结构（行为地区/车型区间，列为 NCD 系数档位）。
- 支持**下载费率模板**（`GET /biz/product/rate/download-template`）。
- 解析后存入 `biz_product_rate` 表，字段：product_id、rate_key（如 `province_310000_age_3_ncd_0.85`）、rate_value（费率值，如 0.125 表示 12.5%）。

#### Tab 3：佣金配置

| 字段 | 必填 | 校验 | 说明 |
|---|---|---|---|
| 默认佣金比例(%) | 否 | 0~100，两位小数 | commission_rate |

**分级佣金**（可选，在 Tab3 展开配置）：

点击 [+ 添加分级佣金] 按钮，可添加多行（最多4行，按业务员等级），保存到 `biz_product_commission_level` 表。

| 业务员等级 | 说明 | 佣金比例(%) |
|---|---|---|
| 初级（1） | 入职0~1年 | 自定义 |
| 中级（2） | 入职1~3年 | 自定义 |
| 高级（3） | 入职3~5年 | 自定义 |
| 资深（4） | 入职5年以上 | 自定义 |

---

#### 后端处理逻辑（新增产品）

1. 产品代码唯一：`SELECT COUNT(*) FROM biz_product WHERE product_code=#{code} AND deleted=0`，count>0 抛出 `产品代码已存在`。
2. 校验 company_id 对应保险公司 status = 1，否则抛出 `保险公司不存在或已停用`。
3. 校验 category_id 存在且 status = 1。
4. 保费/保额范围校验：max_premium ≥ min_premium，max_coverage ≥ min_coverage。
5. 若设置了 auto_on_shelf_time，校验必须是未来时间。
6. 若同时设置了 auto_on_shelf_time 和 auto_off_shelf_time，校验 auto_off_shelf_time > auto_on_shelf_time。
7. 主记录 INSERT INTO biz_product，status 默认为 0（下架）。
8. 若有费率表文件：解析并 INSERT INTO biz_product_rate（批量，每批500条），整体加 @Transactional。
9. 若有分级佣金配置：INSERT INTO biz_product_commission_level（批量）。
10. 记录操作日志（@OperateLog）。

---

### 3.3 编辑产品

以下字段不可修改（置灰）：
- `product_code`（产品代码）
- `company_id`（保险公司）
- `product_type`（产品类型）

**库存修改规则**：
- 若 stock 从 > 0 或 -1 修改为 0：自动触发下架（status 改为 0，off_shelf_time = NOW()），reason 记录为"库存归零自动下架"，并向已授权机构发通知。
- 若 stock 从 0 修改为 > 0 或 -1：不自动上架，由操作人手动执行上架操作。

**佣金比例变更**：
- INSERT INTO biz_product_commission_change_log（product_id、old_rate、new_rate、change_time、operator_id）。
- 佣金变更**只影响后续新订单**，历史订单佣金不变。

---

### 3.4 产品上架

**触发方式**：列表页点击 [上架] 或批量操作，弹出确认框后执行。

**接口**：`PUT /biz/product/on-shelf/{id}`

**后端执行（按顺序6项前置校验）**：
1. 产品当前 status = 0（下架）才可上架，否则提示 `产品已是上架状态`。
2. 所属保险公司 status = 1，否则抛出 `保险公司已停用，无法上架产品`。
3. 产品名称不为空（product_name NOT NULL AND != ''）。
4. 产品图片不为空（product_image NOT NULL AND != ''），否则提示 `请先上传产品图片`。
5. stock ≠ 0，否则提示 `库存为0，无法上架；请调整库存后重试`。
6. 全部校验通过：`UPDATE biz_product SET status=1, on_shelf_time=NOW() WHERE id=#{id}`。
7. 查询已授权且启用的机构列表，向各机构负责人发站内信：`产品【{productName}】已上架，您的机构可以开始销售`。

---

### 3.5 产品下架

**接口**：`PUT /biz/product/off-shelf/{id}`

后端：
1. 校验产品当前 status = 1（上架），否则提示 `产品已是下架状态`。
2. `UPDATE biz_product SET status=0, off_shelf_time=NOW() WHERE id=#{id}`。
3. 向已授权且启用的机构负责人发通知：`产品【{productName}】已下架，暂停销售`。

**批量上下架**：`PUT /biz/product/batch-shelf`，参数 `productIds（List）+ action（on/off）`，逐个执行，汇总返回（成功 N 个，失败 M 个及各自失败原因列表）。

---

### 3.6 产品定时上下架（定时任务）

- **任务名**：`ProductAutoShelfTask`，每小时整点执行。
- 上架：`SELECT * FROM biz_product WHERE auto_on_shelf_time <= NOW() AND status=0 AND deleted=0 AND auto_on_shelf_time IS NOT NULL`，执行上架逻辑（同手动上架，含6项校验）。
- 下架：`SELECT * FROM biz_product WHERE auto_off_shelf_time <= NOW() AND status=1 AND deleted=0 AND auto_off_shelf_time IS NOT NULL`，执行下架+通知。
- 执行完成后清除 auto_on_shelf_time / auto_off_shelf_time（避免重复触发）。

---

### 3.7 费率表维护

**接口**：`POST /biz/product/rate/upload`，上传 Excel 文件 + productId（multipart/form-data）。

后端（@Transactional）：
1. 使用 EasyExcel 解析文件（第一行为表头，从第二行读数据）。
2. 解析每行数据，构造 rate_key（如 `province_{省份代码}_age_{车龄}_ncd_{NCD档位}`）和 rate_value（DECIMAL格式）。
3. 校验 rate_value 必须是数字且 > 0；rate_key 格式合法。
4. **先删除该产品的旧费率数据**：`DELETE FROM biz_product_rate WHERE product_id=#{productId} AND deleted=0`（逻辑删除）。
5. 批量 INSERT 新数据（每批500条）。
6. 返回：`{ "successCount": 1200, "msg": "成功导入1200条费率数据" }`。

**费率模板**：`GET /biz/product/rate/download-template`，返回标准 Excel 模板文件。  
**费率查询**：`GET /biz/product/rate/list?productId=xxx`，返回该产品的费率列表（分页）。

---

### 3.8 库存管理与预警

下单扣减库存属于**订单服务**范畴，此处只说明后台库存管理：

**库存预警定时任务**：`ProductStockAlertTask`，每天 03:00 执行。

```sql
SELECT * FROM biz_product
WHERE stock >= 0 AND stock <= stock_alert_threshold
  AND status = 1 AND deleted = 0
```

向平台 platform_admin 角色的所有用户发站内信：`产品【{productName}】库存不足，当前库存 {stock} 件（预警值：{threshold}），请及时补充`。

---

### 3.9 数据库表结构

```sql
-- 产品主表
CREATE TABLE `biz_product` (
  `id`                   BIGINT        NOT NULL AUTO_INCREMENT,
  `product_code`         VARCHAR(50)   NOT NULL COMMENT '产品代码（唯一）',
  `product_name`         VARCHAR(100)  NOT NULL,
  `company_id`           BIGINT        NOT NULL COMMENT '保险公司ID',
  `product_type`         TINYINT       NOT NULL COMMENT '1-车险 2-非车险',
  `category_id`          BIGINT        NOT NULL COMMENT '产品分类ID',
  `insurance_type`       TINYINT       NOT NULL COMMENT '险种类型（字典：insurance_type）',
  `product_image`        VARCHAR(500)  DEFAULT NULL,
  `product_summary`      VARCHAR(200)  DEFAULT NULL,
  `product_detail`       MEDIUMTEXT    COMMENT '富文本详情',
  `coverage_period`      INT           NOT NULL COMMENT '保障期限（月）',
  `min_premium`          BIGINT        DEFAULT NULL COMMENT '最小保费（分）',
  `max_premium`          BIGINT        DEFAULT NULL COMMENT '最大保费（分）',
  `min_coverage`         BIGINT        DEFAULT NULL COMMENT '最小保额（分）',
  `max_coverage`         BIGINT        DEFAULT NULL COMMENT '最大保额（分）',
  `commission_rate`      DECIMAL(5,2)  DEFAULT 0 COMMENT '默认佣金比例(%)',
  `stock`                INT           NOT NULL DEFAULT -1 COMMENT '-1无限;>=0有限库存',
  `stock_alert_threshold` INT          DEFAULT 10 COMMENT '库存预警值',
  `status`               TINYINT       NOT NULL DEFAULT 0 COMMENT '0-下架 1-上架',
  `on_shelf_time`        DATETIME      DEFAULT NULL,
  `off_shelf_time`       DATETIME      DEFAULT NULL,
  `auto_on_shelf_time`   DATETIME      DEFAULT NULL COMMENT '定时上架时间',
  `auto_off_shelf_time`  DATETIME      DEFAULT NULL COMMENT '定时下架时间',
  `sort`                 INT           NOT NULL DEFAULT 0,
  `creator`              VARCHAR(64)   DEFAULT '',
  `create_time`          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`              VARCHAR(64)   DEFAULT '',
  `update_time`          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`              TINYINT       NOT NULL DEFAULT 0,
  `tenant_id`            BIGINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_product_code` (`product_code`, `deleted`),
  KEY `idx_company_id`  (`company_id`),
  KEY `idx_category_id` (`category_id`),
  KEY `idx_status`      (`status`),
  KEY `idx_tenant`      (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='保险产品表';

-- 分级佣金配置表
CREATE TABLE `biz_product_commission_level` (
  `id`             BIGINT        NOT NULL AUTO_INCREMENT,
  `product_id`     BIGINT        NOT NULL,
  `agent_level`    TINYINT       NOT NULL COMMENT '业务员等级：1-初级 2-中级 3-高级 4-资深',
  `commission_rate` DECIMAL(5,2) NOT NULL,
  `creator`        VARCHAR(64)   DEFAULT '',
  `create_time`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted`        TINYINT       NOT NULL DEFAULT 0,
  `tenant_id`      BIGINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_product_level` (`product_id`, `agent_level`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='产品分级佣金表';

-- 费率表
CREATE TABLE `biz_product_rate` (
  `id`          BIGINT        NOT NULL AUTO_INCREMENT,
  `product_id`  BIGINT        NOT NULL,
  `rate_key`    VARCHAR(200)  NOT NULL COMMENT '费率KEY（省份_车龄_NCD等组合）',
  `rate_value`  DECIMAL(10,6) NOT NULL COMMENT '费率值（如0.125=12.5%）',
  `creator`     VARCHAR(64)   DEFAULT '',
  `create_time` DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted`     TINYINT       NOT NULL DEFAULT 0,
  `tenant_id`   BIGINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_product_id` (`product_id`),
  KEY `idx_rate_key`   (`product_id`, `rate_key`(100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='产品费率表';

-- 佣金变更日志表
CREATE TABLE `biz_product_commission_change_log` (
  `id`          BIGINT        NOT NULL AUTO_INCREMENT,
  `product_id`  BIGINT        NOT NULL,
  `old_rate`    DECIMAL(5,2)  NOT NULL COMMENT '变更前佣金比例',
  `new_rate`    DECIMAL(5,2)  NOT NULL COMMENT '变更后佣金比例',
  `change_type` TINYINT       NOT NULL DEFAULT 1 COMMENT '1-产品默认佣金 2-机构专属佣金',
  `org_id`      BIGINT        DEFAULT NULL COMMENT '机构专属佣金时的机构ID',
  `operator_id` BIGINT        NOT NULL,
  `creator`     VARCHAR(64)   DEFAULT '',
  `create_time` DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tenant_id`   BIGINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_product_id` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='产品佣金变更日志';
```

---

## 四、产品机构授权（biz_product_org）

### 4.1 功能说明

产品需要授权给机构后，该机构的业务员才能报价和出单。授权可以设置有效期和专属佣金比例（覆盖产品默认佣金）。

**业务员在 App 端发起报价前，报价服务会调用 `GET /biz/product-org/check?productId=&orgId=` 接口验证授权**，未授权则拒绝报价。

### 4.2 页面入口

**入口1**：产品列表操作列点击 [授权管理]，弹出该产品的授权机构列表对话框，可 [新增授权] [编辑授权] [停用] [续期] [删除]。

**入口2**：机构详情页底部 Tab「产品授权」，展示该机构已获得授权的产品列表（含有效期、佣金比例、状态）。

---

### 4.3 新增产品授权

**触发**：在产品授权管理弹窗中点击 [新增授权]，弹出二级弹窗。

| 字段 | 必填 | 校验 | 说明 |
|---|---|---|---|
| 授权机构 | **必填** | 机构树，单选或多选（批量） | org_id |
| 授权开始日期 | **必填** | ≥ 今天 | start_date |
| 授权到期日期 | 否 | > start_date；不填表示永久授权 | expire_date |
| 专属佣金比例(%) | 否 | 0~100，两位小数；不填则继承产品默认佣金 | commission_rate |
| 备注 | 否 | 最多200字 | remark |

**后端逻辑（单机构授权，@Transactional）**：
1. 产品有效性：`SELECT status FROM biz_product WHERE id=#{productId} AND deleted=0`，不存在或 status=0 抛出 `产品不存在或已下架`。
2. 机构有效性：`SELECT status FROM biz_organization WHERE id=#{orgId} AND deleted=0`，不存在或 status=0 抛出 `机构不存在或已停用`。
3. 重复授权检查（有效期内不能重复授权同一组合）：
   ```sql
   SELECT COUNT(*) FROM biz_product_org
   WHERE product_id=#{productId} AND org_id=#{orgId}
     AND status=1
     AND (expire_date IS NULL OR expire_date >= CURDATE())
     AND deleted=0
   ```
   count > 0 抛出 `该产品已授权给该机构（有效期内），不能重复授权`。
4. start_date 校验：必须 ≥ CURDATE()。
5. expire_date 校验：若填写，必须 > start_date。
6. commission_rate 校验：若填写，必须在 0~100 之间。
7. INSERT INTO biz_product_org，status 默认 1（启用）。
8. 向机构负责人（leader_id）发站内信 + 短信：`产品【{productName}】已授权给您的机构，授权期限：{startDate} 至 {expireDate（或"永久"）}，即可开始销售`。

**批量授权（多个机构）**：`POST /biz/product-org/batch-grant-orgs`，参数：productId + orgIds（List）+ 其他授权字段。遍历 orgIds 逐个执行上述逻辑，已授权的跳过并记录，汇总结果：`成功 N 个，跳过 M 个（已存在有效授权）`。

---

### 4.4 编辑产品授权

- product_id 和 org_id 不可修改（置灰）。
- 可修改：start_date、expire_date、commission_rate、remark、status。
- **佣金比例变更**：记录到 biz_product_commission_change_log（change_type=2，org_id=当前机构），只影响后续新订单。
- **status 变更**：
  - 停用（1→0）：机构立即不能销售新单，已有在途订单正常履约；向机构负责人发通知 `产品【{productName}】的销售授权已暂停`。
  - 启用（0→1）：需全部满足：①产品当前 status=1（上架）②机构 status=1（启用）③授权在有效期内（expire_date IS NULL 或 expire_date ≥ CURDATE()），否则各自抛出对应错误信息；校验通过后发通知。

---

### 4.5 授权续期

**接口**：`PUT /biz/product-org/renew/{authId}`，参数：newExpireDate（必填，日期格式）。

后端：
1. 查询授权记录是否存在且未逻辑删除。
2. 若当前 expire_date 为 NULL，抛出 `该授权为永久授权，无需续期`。
3. newExpireDate 必须 > 当前 expire_date，否则抛出 `续期日期必须晚于当前到期日`。
4. UPDATE biz_product_org SET expire_date = #{newExpireDate}, status = 1（若已停用则自动恢复）。
5. 发通知：`产品【{productName}】的授权已续期至 {newExpireDate}`。

---

### 4.6 删除产品授权

1. 检查是否有关联订单：`SELECT COUNT(*) FROM biz_order WHERE product_id=#{productId} AND org_id=#{orgId} AND deleted=0`，count > 0 抛出 `该授权存在 {count} 条历史订单，不允许直接删除，请使用停用功能`。
2. 无订单则逻辑删除（deleted=1），向机构负责人发通知。

---

### 4.7 授权到期自动处理（定时任务）

**任务名**：`ProductOrgExpireTask`，每天 01:00 执行。

```sql
-- 查询已到期的启用授权
SELECT p.name as product_name, o.leader_id, po.*
FROM biz_product_org po
JOIN biz_product p ON po.product_id = p.id
JOIN biz_organization o ON po.org_id = o.id
WHERE po.expire_date < CURDATE()
  AND po.status = 1
  AND po.deleted = 0
```

执行：批量 `UPDATE biz_product_org SET status = 0 WHERE id IN (...)`；向每条记录的机构负责人发通知 `产品【{productName}】的销售授权已于 {expireDate} 到期，如需续期请联系平台`。

**到期前预警任务**：`ProductOrgExpireAlertTask`，每天 02:00 执行，查询 `DATEDIFF(expire_date, CURDATE()) IN (30, 15, 7, 3, 1)` 的有效授权记录，向机构负责人发预警通知。

---

### 4.8 授权相关接口

| 接口 | 说明 |
|---|---|
| `GET /biz/product-org/page` | 分页查询授权记录，支持按 product_id、org_id、status、有效期状态筛选 |
| `GET /biz/product-org/list-by-product?productId=xxx` | 查询某产品授权了哪些机构（含过期的） |
| `GET /biz/product-org/list-by-org?orgId=xxx` | 查询某机构有哪些有效产品授权 |
| `GET /biz/product-org/check?productId=&orgId=` | **检查机构是否有该产品的有效授权**（业务员报价前调用，返回 true/false，查 Redis 缓存，cache key: `product_org:check:{productId}:{orgId}` TTL 5min） |

---

### 4.9 数据库表结构

```sql
CREATE TABLE `biz_product_org` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT,
  `product_id`      BIGINT       NOT NULL,
  `org_id`          BIGINT       NOT NULL,
  `start_date`      DATE         NOT NULL COMMENT '授权开始日期',
  `expire_date`     DATE         DEFAULT NULL COMMENT '授权到期日期（NULL表示永久）',
  `commission_rate` DECIMAL(5,2) DEFAULT NULL COMMENT '专属佣金比例（NULL则用产品默认）',
  `status`          TINYINT      NOT NULL DEFAULT 1 COMMENT '0-停用 1-启用',
  `remark`          VARCHAR(200) DEFAULT NULL,
  `creator`         VARCHAR(64)  DEFAULT '',
  `create_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`         VARCHAR(64)  DEFAULT '',
  `update_time`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`         TINYINT      NOT NULL DEFAULT 0,
  `tenant_id`       BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_product_id`  (`product_id`),
  KEY `idx_org_id`      (`org_id`),
  KEY `idx_expire_date` (`expire_date`),
  KEY `idx_status`      (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='产品机构授权表';
```

---

## 五、系统配置（复用框架 + 业务扩展）

### 5.1 数据字典

**完全复用 yudao-cloud 框架**的 `system_dict_type` + `system_dict_data` 表和页面（已有前端界面，无需二次开发）。

需要在项目**初始化 SQL 脚本**中预置以下保险业务字典：

| 字典类型 | 字典名称 | 字典项（value: label） |
|---|---|---|
| `insurance_type` | 险种类型 | 1:车险, 2:健康险, 3:意外险, 4:寿险, 5:财产险 |
| `car_insurance_type` | 车险类型 | 1:交强险, 2:商业险 |
| `cert_type` | 证书类型 | 1:代理人证, 2:经纪人证, 3:公估人证 |
| `order_status` | 订单状态 | 1:待支付, 2:已支付, 3:已完成, 4:已取消, 5:已退款 |
| `policy_status` | 保单状态 | 1:生效中, 2:已过期, 3:已退保, 4:已理赔 |
| `commission_status` | 佣金状态 | 1:待结算, 2:已结算, 3:已发放, 4:已冻结 |
| `claim_status` | 理赔状态 | 1:已报案, 2:审核中, 3:已赔付, 4:已拒赔, 5:已关闭 |
| `agent_level` | 业务员等级 | 1:初级, 2:中级, 3:高级, 4:资深 |

### 5.2 参数配置

**复用框架**的 `system_config` 表（已有前端界面，无需二次开发）。

需要在**初始化 SQL 脚本**中插入以下业务参数：

| 参数键 | 参数值 | 说明 |
|---|---|---|
| `agent.code.prefix` | A | 业务员工号前缀 |
| `agent.default.password` | 123456 | 业务员新增时的初始密码 |
| `staff.code.prefix` | S | 内勤工号前缀 |
| `staff.default.password` | 123456 | 内勤初始密码 |
| `order.timeout.minutes` | 30 | 订单超时未支付自动取消（分钟数） |
| `commission.settle.day` | 5 | 每月几号结算上月佣金 |
| `sms.daily.limit` | 10 | 单手机号每日短信发送上限（防刷） |
| `file.upload.max.size` | 10 | 单文件最大MB |
| `agent.cert.expire.alert.days` | 90 | 业务员证书到期预警天数（任务触发阈值） |
| `org.permit.expire.alert.days` | 90 | 机构许可证到期预警天数 |
| `customer.protection.days` | 365 | 客户保护期（天），同一客户在此期限内归属不变 |
| `agent.code.inactive.days` | 30 | 待激活账号超期自动停用天数 |
| `password.expire.days` | 90 | 密码到期提醒天数 |

> 所有参数值从 Redis 缓存读取（key 规范：`system:config:{参数键}`），框架修改参数后自动刷新缓存，代码中通过 `ConfigApi.getConfigValueByKey(key)` 获取。

### 5.3 地区管理

**完全复用框架**自带的地区管理：
- 数据表：`system_area`，使用国家统计局最新行政区划数据。
- 初始化脚本：导入省市区三级数据（约 3500+ 条记录）。
- 接口：`GET /system/area/tree?parentId=0`（框架自带），前端实现省市区三级联动。

### 5.4 银行管理

**接口前缀**：`/admin-api/biz/bank`

| 字段 | 必填 | 说明 |
|---|---|---|
| bank_code | **必填** | 全局唯一，如 ICBC/CCB/CMB/ABC |
| bank_name | **必填** | 银行全称，如"中国工商银行" |
| bank_logo | 否 | Logo 图片 OSS URL |
| status | **必填** | 默认启用 |
| sort | **必填** | 默认0 |

**业务逻辑**：标准 CRUD（无复杂业务逻辑）+ 列表 Redis 缓存（key：`bank:simple_list`，TTL 24小时，增删改后清除缓存）。

```sql
CREATE TABLE `biz_bank` (
  `id`          BIGINT      NOT NULL AUTO_INCREMENT,
  `bank_code`   VARCHAR(20) NOT NULL COMMENT '银行代码（如ICBC）',
  `bank_name`   VARCHAR(50) NOT NULL COMMENT '银行名称',
  `bank_logo`   VARCHAR(500) DEFAULT NULL,
  `status`      TINYINT     NOT NULL DEFAULT 1,
  `sort`        INT         DEFAULT 0,
  `creator`     VARCHAR(64) DEFAULT '',
  `create_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updater`     VARCHAR(64) DEFAULT '',
  `update_time` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted`     TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_bank_code` (`bank_code`, `deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='银行表';
```

---

## 六、日志监控（全部复用框架）

| 功能 | 使用方式 | 说明 |
|---|---|---|
| 操作日志 | `@OperateLog(module="模块名", name="操作名")` 注解加在 Controller 方法上 | 自动记录操作人/时间/IP/接口/请求参数/响应结果，存 `system_operate_log` 表 |
| 登录日志 | 框架自带 `LoginLogService`，无需额外开发 | 登录成功/失败自动记录：手机号/IP/设备/浏览器/结果，存 `system_login_log` 表 |
| 接口日志 | 框架自带 `ApiAccessLogFilter` | 所有 API 请求自动记录：URL/耗时/状态码/用户信息，存 `infra_api_access_log` 表 |
| 系统监控 | 框架集成 Spring Boot Actuator + Prometheus | 暴露 `/actuator/prometheus` 端点，配合 Grafana 仪表盘监控 JVM/GC/HTTP/DB连接池等指标 |

---

## 七、接口清单汇总

| 模块 | 方法 | 路径 | 说明 |
|---|---|---|---|
| 产品分类 | GET | `/biz/product-category/tree` | 分类树 |
| 产品分类 | POST | `/biz/product-category` | 新增 |
| 产品分类 | PUT | `/biz/product-category` | 编辑 |
| 产品分类 | DELETE | `/biz/product-category/{id}` | 删除 |
| 保险公司 | GET | `/biz/insurance-company/page` | 分页列表 |
| 保险公司 | GET | `/biz/insurance-company/simple-list` | 下拉（只含启用的） |
| 保险公司 | POST | `/biz/insurance-company` | 新增 |
| 保险公司 | PUT | `/biz/insurance-company` | 编辑 |
| 保险公司 | DELETE | `/biz/insurance-company/{id}` | 删除 |
| 保险公司 | PUT | `/biz/insurance-company/change-status/{id}` | 停用/启用（含级联下架确认） |
| 保险公司 | POST | `/biz/insurance-company/test-connect/{id}` | 测试API连接 |
| 产品 | GET | `/biz/product/page` | 分页列表 |
| 产品 | GET | `/biz/product/{id}` | 详情 |
| 产品 | POST | `/biz/product` | 新增 |
| 产品 | PUT | `/biz/product` | 编辑 |
| 产品 | DELETE | `/biz/product/{id}` | 删除 |
| 产品 | PUT | `/biz/product/on-shelf/{id}` | 上架（含6项校验） |
| 产品 | PUT | `/biz/product/off-shelf/{id}` | 下架 |
| 产品 | PUT | `/biz/product/batch-shelf` | 批量上/下架 |
| 费率 | POST | `/biz/product/rate/upload` | 上传费率表（先删后插） |
| 费率 | GET | `/biz/product/rate/download-template` | 下载费率模板 |
| 费率 | GET | `/biz/product/rate/list` | 查询费率列表 |
| 产品授权 | GET | `/biz/product-org/page` | 分页查询 |
| 产品授权 | GET | `/biz/product-org/list-by-product` | 按产品查机构 |
| 产品授权 | GET | `/biz/product-org/list-by-org` | 按机构查产品 |
| 产品授权 | GET | `/biz/product-org/check` | 检查授权（报价前调用） |
| 产品授权 | POST | `/biz/product-org` | 新增授权（单机构） |
| 产品授权 | POST | `/biz/product-org/batch-grant-orgs` | 批量授权给多机构 |
| 产品授权 | PUT | `/biz/product-org` | 编辑授权 |
| 产品授权 | PUT | `/biz/product-org/renew/{id}` | 续期 |
| 产品授权 | DELETE | `/biz/product-org/{id}` | 删除（有订单时拒绝） |
| 银行 | GET | `/biz/bank/simple-list` | 银行下拉（缓存） |
| 银行 | GET | `/biz/bank/page` | 银行分页列表 |
| 银行 | POST | `/biz/bank` | 新增 |
| 银行 | PUT | `/biz/bank` | 编辑 |
| 银行 | DELETE | `/biz/bank/{id}` | 删除 |

---

## 八、定时任务汇总

| 任务类名 | Cron表达式 | 执行时间 | 功能 |
|---|---|---|---|
| `ProductOrgExpireTask` | `0 0 1 * * ?` | 每天 01:00 | 产品授权到期自动停用 |
| `OrgPermitExpireTask` | `0 0 2 * * ?` | 每天 02:00 | 机构经营许可证到期预警 |
| `ProductOrgExpireAlertTask` | `0 5 2 * * ?` | 每天 02:05 | 产品授权到期前预警（30/15/7/3/1天） |
| `AgentCertExpireTask` | `0 30 2 * * ?` | 每天 02:30 | 业务员证书到期预警 |
| `ProductStockAlertTask` | `0 0 3 * * ?` | 每天 03:00 | 产品库存不足预警 |
| `AgentCodeInactiveTask` | `0 0 4 * * ?` | 每天 04:00 | 待激活超期账号自动停用 |
| `PasswordExpireAlertTask` | `0 0 5 * * ?` | 每天 05:00 | 密码超期提醒 |
| `ProductAutoShelfTask` | `0 0 * * * ?` | 每小时整点 | 定时自动上/下架产品 |

> 所有定时任务使用 **XXL-Job** 调度，在 XXL-Job Admin 控制台统一配置 Cron 表达式和告警策略（邮件+钉钉告警），任务失败自动告警。

---

## 九、本篇工时估算（1前端 + 1后端）

| 功能点 | 前端(天) | 后端(天) | 合计 |
|---|---|---|---|
| 保险公司管理（CRUD+测试连接+停用联动） | 1 | 1 | 2 |
| 产品分类（树形CRUD） | 0.5 | 0.5 | 1 |
| 产品新增（3Tab+费率解析+佣金分级） | 1 | 1.5 | 2.5 |
| 产品编辑+上下架（含6项校验） | 0.5 | 1 | 1.5 |
| 费率表维护（上传+解析+先删后插） | 0.5 | 1 | 1.5 |
| 产品机构授权（CRUD+批量+续期+检查） | 1 | 1 | 2 |
| 产品授权定时任务（到期停用+预警） | 0 | 0.5 | 0.5 |
| 数据字典（框架复用+预置字典） | 0.5 | 0.5 | 1 |
| 参数配置（框架复用+预置参数） | 0.5 | 0.5 | 1 |
| 地区管理（框架复用+数据初始化） | 0.5 | 0.5 | 1 |
| 银行管理（CRUD+缓存） | 0.5 | 0.5 | 1 |
| 日志监控（框架复用+注解配置） | 1 | 0 | 1 |
| 定时任务（产品库存+定时上下架+XXL-Job配置） | 0 | 2 | 2 |
| **合计** | **7** | **10.5** | **17.5** |

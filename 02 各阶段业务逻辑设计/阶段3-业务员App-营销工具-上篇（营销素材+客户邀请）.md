# 阶段3 B端业务员App-营销工具 业务逻辑设计文档（上篇）
## 覆盖模块：营销素材 + 客户邀请

> 本文档面向前后端开发人员，聚焦业务流程、字段规则、接口行为、数据库入库，去除架构说明和代码示例冗余。

---

## 一、营销素材模块

### 1.1 海报模板（模板浏览 + 生成海报 + 下载海报）

#### 1.1.1 海报模板列表页

**页面说明**：业务员App进入「营销工具→营销素材→海报模板」后，展示模板列表。

**页面交互**：
- 顶部Tab栏：全部 / 节日 / 产品 / 活动 / 通用（对应`template_type`：1-节日 2-产品 3-活动 4-通用）
- 列表展示：模板缩略图（`thumbnail_url`）、模板名称（`template_name`）
- 排序规则：按`sort`字段升序，相同时按`use_count`降序（热门优先）
- 仅展示`status=1`（启用）的模板
- 支持下拉刷新和上拉加载更多（分页，每页20条）

**后端接口**：`GET /app-api/marketing/poster-template/page`

**请求参数**：
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| templateType | Integer | 否 | 模板类型，不传则查全部 |
| pageNo | Integer | 是 | 页码，从1开始 |
| pageSize | Integer | 是 | 每页数量，固定20 |

**后端逻辑**：查询`marketing_poster_template`，WHERE `status=1 AND deleted=0 AND tenant_id=当前租户`，按`sort ASC, use_count DESC`排序。返回id、template_name、thumbnail_url、template_type。

---

#### 1.1.2 海报模板详情页（进入生成页）

**页面说明**：业务员点击某个模板后，进入海报生成页，展示完整模板预览和可编辑元素。

**页面交互**：
- 展示模板大图（`template_url`）
- 若模板有可编辑文本（`elements.texts`中`editable=true`），展示文字输入框。字段label为`name`，默认值为`defaultValue`，最大长度取`maxLength`
- 若模板有可替换图片（`elements.images`中`editable=true`），展示"上传头像"或"上传产品图"按钮
- 二维码位置固定（`qrcode_position`），无需用户干预，系统自动生成
- 底部按钮：「生成海报」

**必填校验（前端）**：
- 可编辑文本如设置了`maxLength`，前端做字符数限制
- 可替换图片为选填，不上传则使用模板默认图

**后端接口**：`GET /app-api/marketing/poster-template/{id}`

**后端逻辑**：查询`marketing_poster_template`，校验`status=1`，返回完整字段含`elements`和`qrcode_position` JSON。

---

#### 1.1.3 生成海报

**触发**：用户填写完可编辑元素后，点击「生成海报」按钮。

**前端行为**：
- 展示Loading遮罩，提示"海报生成中..."
- 将用户填写的文本、上传的图片URL（已预先上传OSS）随请求一起发给后端
- 后端返回海报URL后，展示海报预览图，按钮切换为「下载海报」「分享海报」

**后端接口**：`POST /app-api/marketing/poster/generate`

**请求体**：
```json
{
  "templateId": 1,
  "customTexts": {"title": "新春特惠", "subtitle": "车险低至5折"},
  "customImages": {"product": "https://oss.domain.com/xxx.jpg"}
}
```

**后端处理步骤**：

1. **参数校验**
   - 校验`templateId`是否存在且`status=1`，否则抛错"海报模板不存在"
   - 从`elements.texts`中获取每个文本元素的`maxLength`，校验`customTexts`中对应文本长度，超长则抛错

2. **获取/生成用户邀请码**
   - 查询当前登录用户是否已有邀请码（查`marketing_invite_record`或独立邀请码表）
   - 若无，生成新邀请码（Base62，8位，唯一性校验）并持久化
   - 构建邀请链接：`https://h5.domain.com/invite?code={inviteCode}`

3. **异步图片合成**（建议MQ异步处理）
   - 下载模板背景图到本地临时目录
   - 按`elements.images`配置，下载并裁剪自定义图片，绘制到对应坐标
   - 按`elements.texts`配置，用Java AWT绘制文本（字体、颜色、坐标、自动截断）
   - 使用ZXing生成二维码（内容为邀请链接），绘制到`qrcode_position`配置的坐标
   - 合成后图片上传OSS，获取访问URL

4. **入库**
   - 向`marketing_user_poster`表插入记录：`user_id`、`template_id`、`poster_url`（OSS URL）、`custom_data`（用户自定义数据JSON）、`share_count=0`
   - 更新`marketing_poster_template`的`use_count = use_count + 1`

5. **返回**：返回`posterUrl`给前端展示

**错误码**：
- `1_008_001_000` 海报模板不存在
- `1_008_001_001` 海报生成失败
- `1_008_001_002` 海报模板已禁用

---

#### 1.1.4 下载海报

**触发**：用户在海报预览页点击「下载海报」。

**前端行为**：调用系统图片保存API，将海报图片保存到手机相册，Toast提示"保存成功"。

**后端接口**：`GET /app-api/marketing/poster/my`（查看历史海报列表，可重新下载）

**页面说明**：我的海报列表，展示历史生成的所有海报，支持重新下载/分享。

**后端逻辑**：查询`marketing_user_poster`，WHERE `user_id=当前用户 AND deleted=0`，按`create_time DESC`，返回`poster_url`、`create_time`、关联模板名称。

---

#### 1.1.5 相关数据表

**`marketing_poster_template`（海报模板表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| template_name | VARCHAR(100) | 模板名称 |
| template_type | TINYINT | 1-节日 2-产品 3-活动 4-通用 |
| template_url | VARCHAR(500) | 模板图片URL |
| thumbnail_url | VARCHAR(500) | 缩略图URL |
| width | INT | 宽度px |
| height | INT | 高度px |
| elements | JSON | 可编辑元素配置 |
| qrcode_position | JSON | 二维码位置{x,y,width,height} |
| sort | INT | 排序，小的在前 |
| status | TINYINT | 0-禁用 1-启用 |
| use_count | INT | 使用次数 |
| creator/create_time/updater/update_time/deleted/tenant_id | - | 框架标准字段 |

**`marketing_user_poster`（用户生成海报表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| user_id | BIGINT | 用户ID |
| template_id | BIGINT | 使用的模板ID |
| poster_url | VARCHAR(500) | 海报图片OSS URL |
| custom_data | JSON | 用户自定义内容（文本+图片） |
| share_count | INT | 分享次数，初始为0 |
| create_time/deleted | - | 框架标准字段 |

---

### 1.2 文案库

#### 1.2.1 文案列表页

**页面说明**：业务员App进入「营销工具→营销素材→文案库」。

**页面交互**：
- 顶部搜索框：支持关键词搜索（模糊匹配标题和内容）
- Tab栏：全部 / 朋友圈 / 短信 / 话术（对应`scene_type`：1-朋友圈 2-短信 3-话术）
- 列表展示：文案标题、内容前50字预览、使用次数
- 排序：先按`sort`升序，再按`use_count`降序
- 仅展示`status=1`的文案

**后端接口**：`GET /app-api/marketing/copywriting/page`

**请求参数**：
| 字段 | 必填 | 说明 |
|---|---|---|
| keyword | 否 | 关键词，匹配title+content |
| sceneType | 否 | 场景类型 |
| pageNo | 是 | 页码 |
| pageSize | 是 | 每页数量 |

**后端逻辑**：查询`marketing_copywriting`，WHERE `status=1 AND deleted=0 AND tenant_id=当前租户`，keyword时做LIKE '%keyword%'，按`sort ASC, use_count DESC`排序。

---

#### 1.2.2 文案详情页（一键复制）

**页面交互**：
- 展示完整文案内容（已替换个人变量后的内容）
- 底部按钮：「复制文案」「一键分享到朋友圈」

**后端接口**：`POST /app-api/marketing/copywriting/{id}/use`

**后端逻辑**（使用文案）：
1. 查询文案内容（`marketing_copywriting.content`）
2. 查询当前登录用户信息（姓名、手机号、所属机构名称、微信号）
3. 替换文案中的占位符：
   - `{name}` → 用户姓名
   - `{phone}` → 用户手机号（或掩码：138****8888）
   - `{company}` → 所属机构名称
   - `{wechat}` → 微信号（无则保留空）
4. `use_count = use_count + 1`（异步更新，避免影响响应速度）
5. 返回替换后的文案文本

**注意**：文案中无占位符时，直接返回原文本。

---

#### 1.2.3 相关数据表

**`marketing_copywriting`（文案库表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| title | VARCHAR(200) | 文案标题 |
| content | TEXT | 文案内容，支持`{name}` `{phone}`等占位符 |
| category_id | BIGINT | 分类ID |
| scene_type | TINYINT | 1-朋友圈 2-短信 3-话术 |
| product_type | VARCHAR(50) | 产品类型标签 |
| tags | VARCHAR(200) | 标签，逗号分隔 |
| use_count | INT | 使用次数 |
| sort | INT | 排序 |
| status | TINYINT | 0-禁用 1-启用 |
| creator/create_time/.../tenant_id | - | 框架标准字段 |

---

### 1.3 短视频素材

#### 1.3.1 视频列表页

**页面说明**：业务员App进入「营销工具→营销素材→短视频素材」。

**页面交互**：
- Tab栏：全部 / 产品介绍 / 理赔案例 / 营销技巧 / 行业资讯（对应`category_id`）
- 列表展示：视频封面图（`cover_url`）、视频标题、时长（`duration`秒转分:秒格式）、播放次数
- 排序：按`sort ASC, play_count DESC`
- 仅展示`status=1`的视频

**后端接口**：`GET /app-api/marketing/video-material/page`

**请求参数**：categoryId（分类ID，选填）、pageNo、pageSize

**后端逻辑**：查询`marketing_video_material`，WHERE `status=1 AND deleted=0`，返回列表。

---

#### 1.3.2 视频播放页

**页面交互**：
- 展示视频播放器，自动播放
- 底部展示：「转发给客户」（唤起微信分享或复制链接）、「保存到本地」

**后端接口**：`POST /app-api/marketing/video-material/{id}/play`（记录播放行为）

**后端逻辑**：
- `play_count = play_count + 1`（异步更新）
- 返回视频URL（`video_url`）

---

#### 1.3.3 相关数据表

**`marketing_video_material`（视频素材表）**：
| 字段 | 类型 | 说明 |
|---|---|---|
| id | BIGINT | 主键 |
| title | VARCHAR(200) | 视频标题 |
| cover_url | VARCHAR(500) | 封面图 |
| video_url | VARCHAR(500) | 视频地址 |
| duration | INT | 时长（秒） |
| file_size | BIGINT | 文件大小（字节） |
| category_id | BIGINT | 分类ID |
| tags | VARCHAR(200) | 标签 |
| play_count | INT | 播放次数 |
| download_count | INT | 下载次数 |
| sort | INT | 排序 |
| status | TINYINT | 0-禁用 1-启用 |
| creator/.../tenant_id | - | 框架标准字段 |

---

### 1.4 朋友圈助手

#### 1.4.1 功能说明

**页面说明**：业务员在「营销工具→营销素材→朋友圈助手」，选择"一条完整的朋友圈内容"（文案+图片/视频）进行一键分享。

**页面交互**：
- 列表展示朋友圈素材（每条含配图缩略图+文案前30字）
- 点击某条素材，进入详情页
- 详情页展示完整文案和图片列表
- 底部两个按钮：「复制文案」「保存图片到相册」
- 用户自行到微信发朋友圈（无法直接唤起微信朋友圈发布，仅辅助）

**后端接口**：`GET /app-api/marketing/moments/page`（查询朋友圈素材列表）

**后端逻辑**：朋友圈助手本质是文案+图片的组合，复用文案库接口（scene_type=1），图片由多张组成，可单独建表`marketing_moments_material`关联图片列表，或直接在copywriting表增加`images` JSON字段存储图片URL列表。

> **实现建议**：在`marketing_copywriting`表增加`attach_images` JSON字段（数组，最多9张图片URL）。

**复制文案逻辑**：同文案库，调用`/use`接口，返回替换个人占位符后的文案。

---

## 二、客户邀请模块

### 2.1 邀请链接/邀请二维码

#### 2.1.1 我的邀请页面

**页面说明**：业务员App进入「营销工具→客户邀请」，展示个人邀请信息。

**页面交互**：
- 展示个人邀请数据卡片：
  - 我的邀请码（如 `A3Bx9Km2`）
  - 已邀请人数（直接邀请）
  - 累计获得奖励（已发放总额）
  - 待发放奖励
- 邀请二维码：展示包含邀请链接的二维码图片（前端用`qrcode`库生成，或后端返回图片URL）
- 邀请链接：`https://h5.domain.com/invite?code=A3Bx9Km2`（带复制按钮）
- 底部两个Tab：「我的邀请记录」「奖励说明」

**后端接口**：`GET /app-api/marketing/invite/my-info`

**后端逻辑**：
1. 查询当前用户邀请码（`marketing_invite_record`或独立`marketing_invite_code`表）
2. 若无邀请码，自动生成（8位Base62，DB唯一索引保障）并入库
3. 统计`inviter_id=当前用户`的邀请记录数
4. 汇总`marketing_invite_reward`中`inviter_id=当前用户 AND status=1（已发放）`的`reward_amount`总和
5. 汇总`status=0（待发放）`的总和
6. 构建邀请链接并返回

**返回数据**：
```json
{
  "inviteCode": "A3Bx9Km2",
  "inviteUrl": "https://h5.domain.com/invite?code=A3Bx9Km2",
  "inviteCount": 12,
  "totalReward": 360.00,
  "pendingReward": 50.00
}
```

---

#### 2.1.2 邀请二维码页面

**页面交互**：
- 展示大尺寸二维码（二维码内容为邀请链接）
- 底部按钮：「保存二维码到相册」「分享给朋友」

**实现方式**：
- 方案一（推荐）：前端使用`qrcode.js`根据邀请链接实时生成二维码，无需后端接口
- 方案二：后端生成二维码图片上传OSS，返回OSS URL。接口：`POST /app-api/marketing/invite/generate-qrcode`

---

### 2.2 邀请记录列表

#### 2.2.1 页面说明

**页面交互**：
- 列表展示我邀请的人员信息：
  - 头像、姓名（脱敏：张**）
  - 邀请时间
  - 状态标签：「已注册」「已实名」「已下单」
  - 获得奖励金额（若有）
- 支持筛选：全部 / 待实名 / 已下单

**后端接口**：`GET /app-api/marketing/invite/records`

**请求参数**：status（选填，0-未完成 1-已下单）、pageNo、pageSize

**后端逻辑**：
1. 查询`marketing_invite_record`，WHERE `inviter_id=当前用户 AND deleted=0`，按`create_time DESC`
2. 关联用户表获取被邀请人基本信息（姓名、头像，姓名做脱敏处理）
3. 关联`marketing_invite_reward`获取对应奖励金额
4. 返回列表

**入库字段说明（`marketing_invite_record`）**：
| 字段 | 说明 |
|---|---|
| id | 主键 |
| inviter_id | 邀请人ID（当前用户） |
| invitee_id | 被邀请人ID，唯一索引保证每人只被邀请一次 |
| invite_code | 使用的邀请码 |
| invite_type | 1-代理人 2-客户 |
| register_time | 被邀请人注册时间 |
| first_order_time | 被邀请人首次下单时间 |
| reward_status | 0-未发放 1-已发放 |
| reward_amount | 实际发放的奖励金额 |

---

### 2.3 邀请绑定逻辑（新用户注册时触发）

> 此流程由C端/注册模块触发，营销工具模块提供Service接口。

**绑定时机**：新用户通过邀请链接（携带`code`参数）注册时，注册完成后调用绑定接口。

**绑定接口**（内部Service方法，非对外App接口）：`InviteService.bindInviteRelation(Long inviteeId, String inviteCode)`

**绑定校验规则**（全部校验不通过则抛异常，不影响注册主流程，需做异步处理或try-catch）：
1. 邀请码必须存在且对应用户有效
2. 被邀请人（inviteeId）在`marketing_invite_record`中不存在（唯一索引`uk_invitee`保障）
3. 邀请人和被邀请人不能是同一人（`inviter_id != invitee_id`）

**入库**：
- `marketing_invite_record`插入一条记录
- `register_time`=当前时间
- 异步发放注册奖励：向`marketing_invite_reward`插入`reward_type=1（注册奖励）`，`reward_amount`按配置（默认100积分折算），`status=0（待发放）`

---

### 2.4 奖励规则说明页

**页面说明**：业务员点击「奖励说明」，弹出说明页面（H5或弹窗，内容从后台配置获取）。

**内容来源**：后台管理「营销管理→邀请奖励配置」中配置的规则文本（富文本），前端只读展示。

**后端接口**：`GET /app-api/marketing/invite/reward-rules`

**后端逻辑**：查询系统参数表（`system_config`）中key为`marketing.invite.reward_rules`的配置值，直接返回HTML文本。

---

### 2.5 邀请奖励发放逻辑（被邀请人下单时触发）

> 此流程由订单模块触发，监听订单完成事件。

**触发条件**：被邀请人的保单订单状态变为"已生效"（保单出单成功）。

**处理步骤**：

1. 根据订单的`user_id`查询`marketing_invite_record`，获取`inviter_id`（邀请人ID）
2. 若找不到邀请关系，跳过
3. 判断是否为首次下单（`first_order_time IS NULL`）：
   - 是首次下单：计算奖励 = 订单佣金 × 5%，插入`marketing_invite_reward`（`reward_type=2` 首单奖励），更新`marketing_invite_record.first_order_time`
   - 非首次下单：不发首单奖励
4. 查询邀请人的上级（二级邀请关系）：若存在，计算二级奖励 = 订单佣金 × 2%，插入`marketing_invite_reward`（`reward_type=2`，`remark`注明"二级邀请奖励"）
5. 调用账户服务，将奖励金额加入邀请人账户余额
6. 更新`marketing_invite_reward.status=1`，记录`grant_time`
7. 发送站内消息通知邀请人"您获得邀请奖励 ¥XX"

**幂等控制**：以`invite_record_id + order_id`为唯一键，防止重复发放。

**`marketing_invite_reward`（邀请奖励表）**：
| 字段 | 说明 |
|---|---|
| id | 主键 |
| inviter_id | 邀请人ID |
| invite_record_id | 关联邀请记录ID |
| reward_type | 1-注册奖励 2-首单奖励 3-业绩奖励 |
| reward_amount | 奖励金额 |
| reward_points | 奖励积分（如适用） |
| order_id | 关联订单ID |
| status | 0-待发放 1-已发放 2-已取消 |
| grant_time | 实际发放时间 |

---

## 三、错误码定义（上篇相关）

| 错误码 | 说明 |
|---|---|
| 1_008_001_000 | 海报模板不存在 |
| 1_008_001_001 | 海报生成失败 |
| 1_008_001_002 | 海报模板已禁用 |
| 1_008_002_000 | 文案不存在 |
| 1_008_003_000 | 邀请码不存在 |
| 1_008_003_001 | 您已绑定邀请关系（每人只能被邀请一次） |
| 1_008_003_002 | 不能邀请自己 |

---

*下篇内容：活动推广 + 团队管理 → 见《阶段3-B端营销工具业务逻辑设计文档-中篇》*
*下下篇内容：培训中心（课程、考试、证书）→ 见《阶段3-B端营销工具业务逻辑设计文档-下篇》*

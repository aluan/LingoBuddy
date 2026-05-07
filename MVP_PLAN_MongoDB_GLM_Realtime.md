# LingoBuddy MVP 产品 PRD：Astra 龙骑士英语冒险版

## 1. 产品目标

LingoBuddy 是面向 4-10 岁儿童的 AI 英语语音冒险伙伴 App。首版目标不是做题、背单词或课程平台，而是验证：

> 孩子是否愿意连续 7 天每天主动开口说英语 10 分钟。

首版从零搭建一个本地可运行 MVP：

- iOS 原生 SwiftUI App
- NestJS 后端
- MongoDB 持久化数据
- Redis 管理实时会话状态、缓存和限流
- 智谱 GLM-Realtime 实时语音链路

产品主角采用原创少女龙骑士 `Astra` 和一只小黑龙宝宝。底部主导航统一为：

1. Home
2. Dragons
3. Quests
4. Profile

`Voice Chat` 不再作为主 Tab，而是从 Home 的主按钮或 Quests 的任务节点进入全屏语音会话。
`Parent Panel` 和 `Parent Area` 首版都不做，避免儿童主体验混入成人数据后台。

## 2. MVP 范围

### 首版只做

- 一个主要陪伴角色：Astra
- 一个当前小龙伙伴：小黑龙宝宝
- 一个核心能力：AI 英语实时语音陪聊
- 一个主循环：聊天获得星星，完成任务推进地图，照顾小龙提升亲密度
- 四个儿童主 Tab：Home、Dragons、Quests、Profile

### 首版不做

- 多角色商业化角色池
- 复杂课程体系
- 发音纠错评分
- AI 绘本、AI 视频、真人老师
- 支付、订阅、短信登录、TestFlight 或上架配置
- Parent Area 或家长面板
- 复杂家长报告和长期学习诊断

## 3. 用户与核心场景

### 儿童用户

核心诉求：

- 想和一个可爱的伙伴玩
- 想获得星星、徽章、小龙成长和地图进度
- 不想感觉自己在上课

关键体验：

- 打开 App 后 3 秒内知道点哪里开始
- 每次开口都有鼓励反馈
- 完成一段很短的冒险就有奖励

### 家长用户

核心诉求：

- 知道孩子今天是否开口
- 知道孩子说了多久、说了多少次、学了哪些新词
- 不希望主界面太成人化或太像数据后台

家长能力不进入首版 MVP，作为后续版本的独立能力规划。

## 4. 信息架构与页面功能

### 4.1 Home

定位：今天的冒险入口。

页面内容：

- LingoBuddy Logo
- 今日星星数量
- 连续打卡天数
- Astra 与小黑龙主视觉
- 今日任务卡：例如 `Find a baby dragon`
- 主 CTA：`Talk with Astra`
- 底部 Tab：Home / Dragons / Quests / Profile

交互要求：

- 点击 `Talk with Astra` 进入全屏语音聊天页
- 首页数据在一次聊天或任务完成后自动刷新
- 今日任务完成后，任务卡展示完成状态和奖励反馈

成功标准：

- 儿童打开 App 后能在 3 秒内理解主操作是开始聊天。

### 4.2 Voice Chat Flow

定位：从 Home 或 Quest 进入的核心实时语音会话，不占用主 Tab。

页面内容：

- 全屏 Astra 或小龙陪伴场景
- 大麦克风按钮
- 实时字幕气泡
- 状态展示：idle、listening、thinking、speaking
- 星星奖励反馈
- 退出按钮返回来源页面

交互要求：

- 首次进入请求麦克风权限
- 按住或点击麦克风开始采集音频
- 支持打断当前 AI 回复
- 后端返回字幕、文本、音频和状态变化
- 会话结束后写入聊天时长、开口次数、新词、任务完成状态和奖励

### 4.3 Dragons

定位：龙伙伴陪伴与收集页。

页面内容：

- 当前小龙大图
- 小龙名字：`Night Bean`
- 等级：`Level 3`
- 亲密度：`Buddy Bond 72%`
- 今日照顾状态：Happy、Fed today、Ready to practice
- 3 个儿童大按钮：Feed、Play、Practice Words
- 小龙收藏横向列表：已解锁小黑龙 + 锁定预告卡
- 装扮槽位：首版只展示 1-2 个可解锁装扮

交互要求：

- `Feed`：消耗或触发一次免费照顾，提升少量亲密度
- `Play`：播放小龙开心反馈，提升少量亲密度
- `Practice Words`：进入一个短语音练习，完成后给星星和亲密度
- 锁定小龙卡展示明确解锁条件，例如 `Unlock in Forest Quest`

成功标准：

- 即使首版只有 1 只小龙，页面也有可用内容和回访动力。

### 4.4 Quests

定位：每日任务与地图进度页。

页面内容：

- 今日进度：`0/3`、`1/3`、`2/3`、`3/3 Done`
- 今日奖励预览：例如 `+15 Stars`
- 岛屿训练地图
- 3 个今日任务节点：
  - Talk with Astra
  - Find a baby dragon
  - Learn 3 new words
- 任务列表卡：图标、任务名、奖励、状态
- 下一站解锁提示：例如 `Next: Forest Nest`

任务状态：

- 未完成：木质节点
- 进行中：珊瑚橙发光节点
- 已完成：绿色勾选和星星反馈
- 全部完成：展示大星星徽章和地图碎片奖励

交互要求：

- 点击语音类任务进入 Voice Chat Flow
- 任务完成后更新 Home、Quests、Profile 的共享进度
- 全部完成后发放当天完成奖励

### 4.5 Profile

定位：孩子成长档案页，而不是成人数据后台。

页面内容：

- 孩子头像
- 昵称、年龄、称号：例如 `Mia / Age 6 / Little Dragon Rider`
- 总星星
- 连续打卡天数
- 英语等级：例如 `Explorer 2`
- 等级进度条
- 徽章墙：已解锁徽章和锁定徽章
- 最近学会的新词
- 喜欢的话题标签
- 基础设置入口：Sound、Language、Notifications

交互要求：

- 可编辑昵称、年龄、喜欢的话题
- 可调整声音、语言和通知偏好
- 不出现家长入口、成人数据面板或复杂设置

## 5. 奖励与任务规则

### 星星

- 完成一次有效语音聊天：+5 Stars
- 完成每日任务节点：每个 +5 Stars
- 完成当天全部 3 个任务：额外 +5 Stars 或地图碎片

### 连续打卡

- 当天完成至少 1 次有效语音聊天，计为当天打卡
- 连续天数显示在 Home 和 Profile
- 连续 7 天可解锁一个装扮或徽章

### 小龙亲密度

- Feed：+2 Bond
- Play：+2 Bond
- Practice Words：+5 Bond
- 完成当天全部任务：+5 Bond

### 地图进度

- 首版只有一个岛屿地图
- 每天完成全部任务获得 1 个地图碎片
- 达到指定碎片数后展示下一地图预告，不实际开放复杂新地图

## 6. 技术架构

### iOS 客户端

- SwiftUI
- iOS 17+
- AVFoundation 录音和播放
- WebSocket 连接本地后端
- 本地状态管理用于页面间同步 Home、Dragons、Quests、Profile 数据

### 后端

- Node.js
- NestJS
- MongoDB
- Redis
- WebSocket 代理智谱 GLM-Realtime

### AI 语音链路

- iOS 采集麦克风音频
- iOS 将音频分片发送到后端 WebSocket
- 后端连接智谱 GLM-Realtime
- 后端转发音频输入、字幕增量、文本增量和音频输出
- iOS 流式播放 Astra 的语音回复

iOS 客户端不直接保存或使用智谱 API Key。`ZHIPU_API_KEY` 只放在后端环境变量中。

## 7. 后端接口

### REST API

- `GET /home/today`：首页聚合数据，包括星星、连续天数、今日任务、Astra 状态、小龙摘要
- `GET /profile/current`：读取本地默认孩子档案
- `PATCH /profile/current`：更新昵称、年龄、喜欢话题、语言偏好
- `GET /dragons/current`：读取当前小龙、等级、亲密度、今日照顾状态
- `POST /dragons/current/care`：执行 `feed` 或 `play`，更新亲密度和照顾状态
- `GET /dragons/collection`：读取已解锁和锁定小龙列表
- `GET /quests/today`：读取今日 3 个任务、地图节点、奖励预览
- `POST /quests/:id/complete`：完成任务并发放奖励
- `GET /rewards`：读取星星、徽章、装扮、地图碎片和解锁状态

### WebSocket

后端提供 `/voice/realtime`，iOS 只连接本地后端。

iOS 到后端事件：

- `session.start`
- `audio.append`
- `audio.stop`
- `response.cancel`
- `session.end`

后端到 iOS 事件：

- `transcript.delta`
- `assistant.text.delta`
- `assistant.audio.delta`
- `state.changed`
- `reward.earned`
- `quest.completed`
- `dragon.bond.changed`
- `error`

## 8. MongoDB 集合设计

### `profiles`

保存本地孩子档案：

- 昵称
- 年龄
- 喜欢的话题
- 英语等级
- 当前称号
- 创建时间
- 更新时间

本地免登录时，后端启动后自动创建一个默认 profile。

### `daily_progress`

按 `profileId + date` 保存每日进度：

- 今日星星
- 今日开口次数
- 今日聊天秒数
- 连续天数
- 今日新单词
- 是否完成至少一次有效聊天
- 今日任务完成数量
- 是否完成全部今日任务

需要对 `profileId + date` 建唯一索引，避免同一天重复统计。

### `quests`

保存任务模板和今日任务实例：

- 任务标题
- 任务类型：voice、explore、words
- 任务场景
- 推荐 prompt hint
- 奖励星星数量
- 地图节点状态
- 是否已完成

### `dragons`

保存小龙伙伴状态：

- profileId
- dragonKey
- 名字
- 等级
- 亲密度
- 是否当前伙伴
- 是否已解锁
- 解锁条件
- 今日照顾状态
- 已解锁装扮

### `rewards`

保存奖励和解锁状态：

- 星星余额
- 徽章
- 小龙装扮
- 地图碎片
- 地图解锁状态
- 奖励发放时间

### `conversations`

保存会话元数据：

- profileId
- 开始时间
- 结束时间
- 入口来源：home、quest、dragon_practice
- 关联任务
- 会话状态

### `messages`

保存会话文本数据：

- conversationId
- 角色：child 或 astra
- 文本内容
- 创建时间
- 提取的新单词

原始音频不入库。MVP 只保存文本转写、Astra 回复和统计数据。

## 9. Redis 使用方式

Redis 不替代 MongoDB，只负责临时和实时状态：

- WebSocket session 状态
- GLM realtime 连接映射
- 临时音频流状态
- 会话超时控制
- 简单限流
- 当前任务会话上下文

## 10. GLM-Realtime 配置

默认使用智谱 GLM-Realtime：

- WebSocket 地址：`wss://open.bigmodel.cn/api/paas/v4/realtime`
- 默认模型：`glm-realtime-flash`
- 模态：`text` 和 `audio`
- 输入音频：单声道 16-bit PCM，约 100ms 分片
- 输出音频：PCM
- VAD：server VAD
- 支持打断：开启

默认 VAD 配置：

- `create_response: true`
- `interrupt_response: true`
- `prefix_padding_ms: 300`
- `silence_duration_ms: 500`
- `threshold: 0.5`

默认 Astra Prompt：

```text
You are Astra.
A warm dragon rider buddy talking to a 6-year-old child.

Rules:
- Use short English sentences.
- Use simple vocabulary.
- Always encourage.
- Never criticize.
- Make it feel like a dragon adventure.
- Ask only one question at a time.
- Keep replies under 12 words.
- If the child is stuck, offer an easy word choice.
```

如果本地没有可用的 `ZHIPU_API_KEY`，后端需要提供 mock realtime 模式，用于验证 UI 和产品流程。

## 11. 本地开发与部署

本地 Demo 使用 Docker Compose 启动：

- MongoDB
- Redis
- NestJS 后端

后端环境变量：

- `MONGODB_URI`
- `REDIS_URL`
- `ZHIPU_API_KEY`
- `GLM_REALTIME_MODEL`
- `GLM_REALTIME_MOCK`

iOS 使用本地后端地址，例如：

- `http://localhost:3000`
- 真机调试时使用 Mac 局域网 IP

## 12. 测试计划

### 后端测试

- 默认 profile 初始化
- 今日 3 个任务生成
- 星星奖励发放
- 连续天数计算
- 小龙亲密度更新
- 小龙照顾状态更新
- 地图碎片奖励更新
- 会话消息写入
- WebSocket mock GLM 事件转发
- GLM 错误和断线处理

### iOS 测试

- Home 加载并能清楚展示主 CTA
- Home 进入 Voice Chat Flow
- 麦克风权限
- 录音分片发送
- 实时字幕显示
- 音频播放
- 打断回复
- Dragons 只有 1 只小龙时仍可 Feed、Play、Practice Words
- Quests 未完成、进行中、已完成、全部完成状态展示
- Profile 展示孩子成长数据、徽章、新词和基础设置
- 一次聊天后 Home、Quests、Profile 数据同步更新

### 验收标准

- 本地后端启动后，iOS 真机可以完成一次 Astra 实时语音对话。
- 儿童打开 App 后 3 秒内能理解从 Home 开始聊天。
- 完成一次有效聊天后，Home 星星、Quests 状态、Profile 成长数据同步变化。
- Dragons 页在首版只有 1 只小龙时仍有亲密度、照顾动作和锁定预告。
- Quests 页能清楚展示未完成、已完成、全部完成三种状态。
- Profile 首版不出现 Parent Area、家长面板或成人数据后台入口。
- 没有智谱 Key 时，mock realtime 模式仍然可以跑通 UI 流程。
- 智谱 API Key 不出现在 iOS 客户端代码或仓库明文中。

## 13. 默认假设

- 交付目标是本地 Demo，不做 TestFlight、支付、短信登录或上架配置。
- 首版免登录，但仍保留后续接入家长手机号登录的接口空间。
- 首版只做 Astra 一个主要陪伴角色和 1 只当前小龙伙伴。
- `Dragons` 可以展示锁定预告，但不实现完整多龙养成系统。
- `Quests` 只实现每日 3 个任务和 1 张岛屿地图。
- Parent Area、家长面板、家长报告都不进入首版。
- MongoDB 作为首版持久化数据库，Redis 继续保留。
- 首版不做复杂事务；奖励、任务和进度更新优先使用单文档原子更新。
- 后续如果要做复杂订阅、账务或报表，再评估是否引入关系型数据库。

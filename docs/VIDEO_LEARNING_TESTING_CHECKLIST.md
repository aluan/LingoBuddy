# 哔哩哔哩视频学习功能 - 测试清单

## ✅ 编译测试（已完成）

### 后端编译
- ✅ TypeScript 编译成功
- ✅ 所有类型错误已修复
- ✅ 生成了 30 个编译文件（dist/video-learning/）
- ✅ 依赖安装完成（axios, bull, @nestjs/bull）

### 修复的问题
1. ✅ 修复了所有 `error` 类型为 `unknown` 的问题（使用类型守卫）
2. ✅ 修复了 `configService.get()` 返回 `undefined` 的问题（添加默认值）
3. ✅ 修复了 `difficultyGuide` 索引签名问题（使用 `Record<string, string>`）
4. ✅ 安装了缺失的 `axios` 依赖

---

## 📋 后续测试清单

### 1. 环境准备

#### 后端环境
```bash
# 检查系统依赖
□ 检查 Python3 是否安装
□ 检查 ffmpeg 是否安装
□ 安装 bili 命令：pip3 install bili
□ 安装 yt-dlp：pip3 install yt-dlp

# 检查服务
□ MongoDB 是否运行
□ Redis 是否运行

# 环境变量检查
□ DOUBAO_APP_ID
□ DOUBAO_APP_KEY
□ DOUBAO_TOKEN
□ DOUBAO_ASR_API_URL
□ VIDEO_STORAGE_PATH
□ REDIS_HOST
□ REDIS_PORT
```

#### iOS 环境
```bash
# Xcode 项目配置
□ 检查所有新文件是否已添加到项目
□ 检查 Target Membership
□ 检查 Build Phases
□ 运行 Xcode 编译
```

---

### 2. 后端单元测试

#### 2.1 字幕下载服务测试
```bash
# 测试命令
curl -X POST http://localhost:3000/video-learning/submit \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.bilibili.com/video/BV1xx411c7mD"}'

# 预期结果
□ 返回 videoId
□ 状态为 pending
□ 异步任务开始处理
```

#### 2.2 视频处理流程测试
```bash
# 查询处理状态
curl http://localhost:3000/video-learning/{videoId}/status

# 预期结果
□ 状态从 pending → processing → completed
□ transcriptSource 为 subtitle 或 asr
□ transcriptText 包含转录内容
□ 视频元数据正确（标题、时长）
```

#### 2.3 聊天功能测试
```bash
# 发送聊天消息
curl -X POST http://localhost:3000/video-learning/{videoId}/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "这个视频讲了什么？"}'

# 预期结果
□ 返回 AI 回复
□ 回复基于视频内容
□ conversationId 正确
```

#### 2.4 测验生成测试
```bash
# 生成测验
curl -X POST http://localhost:3000/video-learning/{videoId}/generate-quiz \
  -H "Content-Type: application/json" \
  -d '{"difficulty": "easy", "questionCount": 5}'

# 预期结果
□ 返回 quizId
□ 生成 5 道题目
□ 题目类型正确（选择题、填空题、判断题）
□ 包含正确答案和解释
```

#### 2.5 测验提交测试
```bash
# 提交答案
curl -X POST http://localhost:3000/video-learning/quizzes/{quizId}/submit \
  -H "Content-Type: application/json" \
  -d '{"answers": {"q1": "A", "q2": "B"}}'

# 预期结果
□ 返回分数
□ 返回正确/错误题目数量
□ 返回每道题的详细结果
□ 星星奖励计算正确
```

#### 2.6 语音会话测试
```bash
# 启动语音会话
curl -X POST http://localhost:3000/voice/sessions/start \
  -H "Content-Type: application/json" \
  -d '{"videoId": "{videoId}"}'

# 预期结果
□ 返回 sessionId
□ 视频上下文已注入
□ 豆包 SDK 连接成功
```

---

### 3. iOS 集成测试

#### 3.1 视频提交流程
```
测试步骤：
1. 打开 VideoLearningView
2. 输入哔哩哔哩视频 URL
3. 点击"添加视频"按钮

预期结果：
□ 跳转到 VideoProcessingView
□ 显示处理进度
□ 每 2 秒轮询状态
□ 完成后自动跳转到 VideoDetailView
```

#### 3.2 视频列表展示
```
测试步骤：
1. 打开 VideoLearningView
2. 查看视频列表

预期结果：
□ 显示所有已添加的视频
□ 卡片式布局美观
□ 显示标题、时长、状态
□ 点击卡片跳转到详情页
```

#### 3.3 文字聊天功能
```
测试步骤：
1. 在 VideoDetailView 点击"文字聊天"
2. 输入问题并发送
3. 查看 AI 回复

预期结果：
□ 消息发送成功
□ AI 回复基于视频内容
□ 消息列表正确展示
□ 自动滚动到最新消息
```

#### 3.4 语音对话功能
```
测试步骤：
1. 在 VideoDetailView 点击"语音通话"
2. 点击录音按钮说话
3. 听取 AI 回复

预期结果：
□ 录音功能正常
□ 语音识别准确
□ AI 回复基于视频内容
□ TTS 播放流畅
□ 波形动画正常
```

#### 3.5 测验功能
```
测试步骤：
1. 在 VideoDetailView 点击"开始测验"
2. 选择难度和题目数量
3. 开始答题
4. 提交答案
5. 查看结果

预期结果：
□ 测验设置界面正常
□ 题目展示清晰
□ 选项选择流畅
□ 进度条正确
□ 结果页面显示分数、正确率、星星
□ 答案回顾功能正常
```

---

### 4. 端到端测试

#### 测试场景 1：完整学习流程
```
1. 用户输入视频 URL
2. 等待转录完成
3. 进行文字聊天
4. 进行语音对话
5. 完成测验

预期结果：
□ 整个流程无错误
□ 数据一致性正确
□ 用户体验流畅
```

#### 测试场景 2：字幕降级到 ASR
```
1. 输入一个没有字幕的视频 URL
2. 观察处理流程

预期结果：
□ 字幕下载失败后自动切换到 ASR
□ 最终转录成功
□ transcriptSource 为 asr
```

#### 测试场景 3：错误处理
```
1. 输入无效的 URL
2. 输入不支持的视频平台
3. 网络断开时操作

预期结果：
□ 显示友好的错误提示
□ 不会崩溃
□ 可以重试
```

---

### 5. 性能测试

#### 5.1 转录性能
```
测试指标：
□ 字幕下载时间 < 10 秒
□ ASR 转录时间 < 视频时长 × 0.5
□ 内存使用合理
□ 临时文件正确清理
```

#### 5.2 聊天性能
```
测试指标：
□ 消息发送响应时间 < 2 秒
□ AI 回复生成时间 < 5 秒
□ 界面不卡顿
```

#### 5.3 语音性能
```
测试指标：
□ 语音识别延迟 < 1 秒
□ TTS 播放流畅
□ 无音频卡顿
```

---

### 6. 兼容性测试

#### iOS 版本
```
□ iOS 15.0+
□ iOS 16.0+
□ iOS 17.0+
```

#### 设备
```
□ iPhone SE
□ iPhone 13/14/15
□ iPhone 15 Pro Max
□ iPad
```

---

## 🐛 已知问题

### 待修复
- [ ] 无

### 待优化
- [ ] 视频内容智能摘要（处理超长视频）
- [ ] 向量检索（embedding + 向量数据库）
- [ ] WebSocket 推送替代轮询
- [ ] 视频封面展示
- [ ] 离线缓存

---

## 📊 测试结果

### 编译测试
- ✅ 后端编译：通过
- ⏳ iOS 编译：待测试

### 功能测试
- ⏳ 后端 API：待测试
- ⏳ iOS UI：待测试

### 集成测试
- ⏳ 端到端流程：待测试

---

## 🚀 下一步

1. **启动后端服务**
   ```bash
   # 启动 MongoDB
   docker-compose up -d mongodb
   
   # 启动 Redis
   docker-compose up -d redis
   
   # 启动后端
   npm run start:dev
   ```

2. **测试后端 API**
   - 使用 Postman 或 curl 测试所有端点
   - 验证数据库记录
   - 检查日志输出

3. **编译 iOS 项目**
   - 在 Xcode 中打开项目
   - 添加所有新文件到项目
   - 运行编译

4. **iOS 真机测试**
   - 测试完整用户流程
   - 检查 UI 和交互
   - 验证功能正确性

5. **性能优化**
   - 根据测试结果优化性能
   - 修复发现的 bug
   - 改进用户体验

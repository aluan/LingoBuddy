# 哔哩哔哩视频学习功能实现计划

## 上下文

LingoBuddy 是一个儿童英语学习应用，目前支持与 AI 助手 Astra 进行实时语音对话。用户希望添加新功能：输入哔哩哔哩视频 URL，自动进行语音识别（ASR）转录，然后用户可以针对视频内容进行文字聊天、语音通话，以及生成测验来检验学习效果。

### 为什么需要这个功能
- **扩展学习场景**：从单纯的对话练习扩展到基于视频内容的深度学习
- **内容理解验证**：通过测验功能检验用户是否真正理解视频内容
- **多模态交互**：支持文字和语音两种方式与 AI 讨论视频内容

### 现有架构
- **前端**：iOS SwiftUI 应用，使用豆包 SDK 进行实时语音对话
- **后端**：NestJS + MongoDB + Redis，管理会话、对话历史、用户进度
- **LLM 集成**：豆包（Doubao）实时语音 SDK，支持 ASR/TTS
- **对话上下文**：通过 `LocalDialogStore` 加载最近 20 对 Q&A 作为上下文

## 实现方案

### 架构设计

采用**后端处理视频**的策略：
1. 后端负责视频下载、音频提取、ASR 转录
2. iOS 端负责 UI 交互和进度展示
3. 转录内容作为对话上下文注入到 LLM
4. 复用现有的 `DoubaoVoiceClient` 进行语音对话

### 技术选型

| 组件 | 技术方案 | 理由 |
|------|---------|------|
| 字幕下载 | bili 命令（优先） | 直接获取官方字幕，速度快，准确度高 |
| 视频下载 | yt-dlp (Python CLI) | 字幕不可用时的备选方案 |
| 音频提取 | ffmpeg | 统一转换为 16kHz PCM/WAV 格式 |
| ASR 服务 | 豆包批量 ASR API | 字幕不可用时使用，复用现有凭证 |
| 任务队列 | Bull (基于 Redis) | 异步处理，避免阻塞 HTTP 请求 |
| 存储 | MongoDB + 文件系统 | 转录文本存数据库，音频临时存储后删除 |

## 实现步骤

### Phase 1: 后端核心功能（3-4天）

#### 1.1 创建 video-learning 模块

**新建文件**：
- `backend/src/video-learning/video-learning.module.ts`
- `backend/src/video-learning/video-learning.controller.ts`
- `backend/src/video-learning/video-learning.service.ts`
- `backend/src/video-learning/video-content.schema.ts`
- `backend/src/video-learning/video-processor.service.ts`
- `backend/src/video-learning/bilibili-subtitle.service.ts` - 字幕下载服务
- `backend/src/video-learning/bilibili-downloader.service.ts` - 音频下载服务（备选）
- `backend/src/video-learning/doubao-asr.service.ts` - ASR 服务（备选）
- `backend/src/video-learning/quiz.service.ts` - 测验生成服务
- `backend/src/video-learning/quiz.schema.ts` - 测验数据模型

#### 1.2 数据模型：VideoContent Schema

```typescript
{
  _id: ObjectId,
  profileId: ObjectId,
  url: string,                    // 哔哩哔哩视频URL
  platform: 'bilibili',
  videoId: string,                // BV号
  title: string,
  duration: number,               // 秒
  thumbnailUrl?: string,
  
  // 转录/字幕
  transcriptStatus: 'pending' | 'processing' | 'completed' | 'failed',
  transcriptSource: 'subtitle' | 'asr',  // 新增：标记来源
  transcriptText?: string,
  transcriptSegments?: [{
    startTime: number,
    endTime: number,
    text: string
  }],
  transcriptError?: string,
  
  // 音频文件
  audioFilePath?: string,
  audioFileSize?: number,
  
  // 学习数据
  conversationCount: number,
  quizCount: number,
  lastAccessedAt: Date,
  
  createdAt: Date,
  updatedAt: Date
}
```

#### 1.3 REST API 端点

```typescript
POST /video-learning/submit
  Body: { url: string }
  Response: { videoId: string, status: 'pending' }

GET /video-learning/:videoId/status
  Response: { 
    status: 'pending' | 'processing' | 'completed' | 'failed',
    progress: number,  // 0-100
    transcriptText?: string,
    error?: string
  }

GET /video-learning/list
  Response: { videos: VideoContent[] }

GET /video-learning/:videoId
  Response: VideoContent

DELETE /video-learning/:videoId

POST /video-learning/:videoId/start-session
  Response: { sessionId: string, conversationId: string }

POST /video-learning/:videoId/chat
  Body: { message: string }
  Response: { reply: string }

POST /video-learning/:videoId/generate-quiz
  Body: { difficulty: 'easy' | 'medium' | 'hard', questionCount: number }
  Response: { quizId: string, questions: [...] }

GET /video-learning/:videoId/quizzes
  Response: { quizzes: Quiz[] }

POST /video-learning/quizzes/:quizId/submit
  Body: { answers: { questionId: string, answer: string }[] }
  Response: { score: number, correctCount: number, totalCount: number, stars: number }
```

#### 1.4 核心服务实现

**BilibiliSubtitleService**（优先使用）：
- 使用 `bili` 命令下载官方字幕
- 解析字幕文件（SRT/ASS/JSON 格式）
- 提取视频元数据（标题、时长、封面）
- 返回带时间戳的字幕文本

**BilibiliDownloaderService**（备选方案）：
- 当字幕不可用时使用
- 使用 `yt-dlp` 下载音频（bestaudio 格式）
- 使用 `ffmpeg` 转换为 16kHz WAV

**DoubaoAsrService**（备选方案）：
- 当字幕不可用时使用
- 调用豆包批量 ASR API
- 支持长音频分段处理
- 返回带时间戳的转录文本

**VideoProcessorService**：
- 使用 Bull 队列管理异步任务
- 协调流程：
  1. **优先尝试**：使用 `bili` 下载字幕
  2. **备选方案**：字幕失败 → 下载音频 → ASR 转录
- 提供进度查询接口
- 完成后清理临时文件

**VideoLearningService**：
- 管理视频内容 CRUD
- 与 VoiceSessionService 集成
- 提供文字聊天接口（调用豆包 LLM API）

**QuizService**：
- 使用 LLM 根据视频转录内容生成测验题目
- 支持选择题、填空题、判断题
- 支持难度级别：easy（简单词汇）、medium（句子理解）、hard（综合理解）
- 评分和答案验证
- 与奖励系统集成（答对题目获得星星）

#### 1.5 修改现有服务

**修改 `backend/src/conversations/conversation.schema.ts`**：
```typescript
@Schema({ timestamps: true })
export class Conversation {
  // ... 现有字段
  
  @Prop({ type: Types.ObjectId })
  videoId?: Types.ObjectId;  // 新增：关联的视频ID
  
  @Prop()
  videoContext?: string;     // 新增：视频转录文本快照
}
```

**修改 `backend/src/voice/voice-session.service.ts`**：
- `startSession()` 方法增加可选参数 `videoId?: string`
- 如果提供 `videoId`，加载视频转录内容并存储到 `Conversation.videoContext`

#### 1.6 测验数据模型：Quiz Schema

```typescript
{
  _id: ObjectId,
  videoId: ObjectId,
  profileId: ObjectId,
  difficulty: 'easy' | 'medium' | 'hard',
  questions: [{
    questionId: string,
    type: 'multiple_choice' | 'fill_blank' | 'true_false',
    question: string,
    options?: string[],  // 选择题选项
    correctAnswer: string,
    explanation?: string,  // 答案解释
  }],
  
  // 答题记录
  submitted: boolean,
  submittedAt?: Date,
  answers?: { questionId: string, answer: string }[],
  score?: number,
  correctCount?: number,
  starsEarned?: number,
  
  createdAt: Date,
}
```

### Phase 2: iOS 前端功能（3-4天）

#### 2.1 新增页面

**VideoLearningView.swift**（主页面）：
- 视频 URL 输入框
- 提交按钮
- 已处理视频列表（卡片展示）
- 每个卡片显示：标题、时长、转录状态、操作按钮

**VideoProcessingView.swift**（进度页面）：
- 进度条（0-100%）
- 状态文字（"下载中..."、"转录中..."、"完成"）
- 轮询后端 `/video-learning/:videoId/status` 接口（每 2 秒）
- 完成后自动跳转到 VideoDetailView

**VideoDetailView.swift**（详情页）：
- 视频元数据展示（标题、时长、封面）
- 完整转录文本（可滚动）
- 三个操作按钮：
  - "文字聊天" → VideoTextChatView
  - "语音通话" → VideoVoiceChatView
  - "生成测验" → VideoQuizView

**VideoTextChatView.swift**（文字聊天页）：
- 聊天气泡列表（用户消息 + AI 回复）
- 底部输入框 + 发送按钮
- 调用 `POST /video-learning/:videoId/chat` 接口
- 上下文自动包含视频转录内容

**VideoVoiceChatView.swift**（语音对话页）：
- 复用 `SpeakView` 的 UI 设计
- 使用 `DoubaoVoiceClient` 进行实时语音对话
- 启动会话时传递 `videoId` 参数

**VideoQuizView.swift**（测验页）：
- 显示测验题目列表
- 支持选择题、填空题、判断题
- 实时反馈答题状态
- 提交后显示得分、正确率、星星奖励
- 显示答案解释

**QuizResultView.swift**（测验结果页）：
- 显示总分和正确率
- 显示获得的星星数量
- 显示每道题的正确答案和解释
- "再做一次"按钮

#### 2.2 新增服务类

**VideoLearningService.swift**：
```swift
@MainActor
final class VideoLearningService: ObservableObject {
    @Published var videos: [VideoContent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func submitVideo(url: String) async throws -> String
    func fetchVideoStatus(videoId: String) async throws -> VideoStatus
    func fetchVideoList() async throws -> [VideoContent]
    func fetchVideoDetail(videoId: String) async throws -> VideoContent
    func deleteVideo(videoId: String) async throws
    func startVideoSession(videoId: String) async throws -> SessionStartResponse
    func sendChatMessage(videoId: String, message: String) async throws -> String
    func generateQuiz(videoId: String, difficulty: String, questionCount: Int) async throws -> Quiz
    func fetchQuizzes(videoId: String) async throws -> [Quiz]
    func submitQuiz(quizId: String, answers: [QuizAnswer]) async throws -> QuizResult
}
```

**数据模型**：
```swift
struct VideoContent: Codable, Identifiable {
    let id: String
    let url: String
    let title: String
    let duration: Int
    let thumbnailUrl: String?
    let transcriptStatus: String
    let transcriptText: String?
    let createdAt: Date
}

struct VideoStatus: Codable {
    let status: String
    let progress: Int
    let transcriptText: String?
    let error: String?
}

struct Quiz: Codable, Identifiable {
    let id: String
    let videoId: String
    let difficulty: String
    let questions: [QuizQuestion]
    let submitted: Bool
    let score: Int?
    let createdAt: Date
}

struct QuizQuestion: Codable, Identifiable {
    let id: String
    let type: String
    let question: String
    let options: [String]?
    let correctAnswer: String
    let explanation: String?
}

struct QuizAnswer: Codable {
    let questionId: String
    let answer: String
}

struct QuizResult: Codable {
    let score: Int
    let correctCount: Int
    let totalCount: Int
    let stars: Int
}
```

#### 2.3 导航结构

在 `AppRootView.swift` 中添加新的导航路由：
```swift
enum AppRoute {
    case home
    case speak
    case videoLearning           // 新增
    case videoDetail(String)     // 新增
    case videoTextChat(String)   // 新增
    case videoVoiceChat(String)  // 新增
    case videoQuiz(String)       // 新增
    case quizResult(String)      // 新增
}
```

在 `HomeView.swift` 中添加入口按钮：
```swift
Button("Video Learning") {
    // 导航到 VideoLearningView
}
```

### Phase 3: 语音对话集成（1-2天）

#### 3.1 修改 VoiceSessionService

**修改 `LingoBuddyApp/Services/VoiceSessionService.swift`**：
```swift
func startSession(taskId: String? = nil, videoId: String? = nil) async throws -> SessionStartResponse {
    let url = URL(string: "\(baseURL)/voice/sessions/start")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = [
        "taskId": taskId as Any,
        "videoId": videoId as Any  // 新增
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    // ... 其余代码
}
```

#### 3.2 修改 DoubaoVoiceClient

**修改 `LingoBuddyApp/Services/DoubaoVoiceClient.swift`**：

在第 34 行后添加：
```swift
@Published var videoContext: String?
```

在第 78 行 `startCall()` 方法中添加参数：
```swift
func startCall(videoContext: String? = nil) {
    self.videoContext = videoContext
    // ... 现有代码
}
```

在第 251-278 行 `makeStartEngineConfig()` 方法中修改：
```swift
private func makeStartEngineConfig() -> String? {
    var dialogContext = dialogStore.recentContext(maxQAPairs: 20)
    
    // 注入视频内容上下文
    if let videoContext = videoContext {
        let systemMessage: [String: Any] = [
            "role": "system",
            "text": "Video content: \(videoContext)"
        ]
        dialogContext.insert(systemMessage, at: 0)
        debugLog("Injected video context (\(videoContext.count) chars)")
    }
    
    let payload: [String: Any] = [
        "dialog": [
            "bot_name": config.botName,
            "system_role": config.systemRole,
            "speaking_style": config.speakingStyle,
            "dialog_id": config.dialogId,
            "character_manifest": config.systemRole,
            "dialog_context": dialogContext,  // 包含视频上下文
            "extra": [
                "model": config.model
            ]
        ],
        "tts": makeTTSConfig()["tts"] as Any
    ]
    
    // ... 其余代码
}
```

#### 3.3 VideoVoiceChatView 实现

```swift
struct VideoVoiceChatView: View {
    let videoId: String
    let videoContext: String
    let onBack: () -> Void
    
    @StateObject private var realtime = DoubaoVoiceClient()
    
    var body: some View {
        // 复用 SpeakView 的 UI
        // ...
    }
    
    .onAppear {
        realtime.startCall(videoContext: videoContext)
    }
}
```

### Phase 4: 文字聊天功能（1天）

#### 4.1 后端文字聊天 API

在 `VideoLearningController` 中添加：
```typescript
@Post(':videoId/chat')
async chat(
  @Param('videoId') videoId: string,
  @Body() body: { message: string }
) {
  return this.videoLearningService.chat(videoId, body.message);
}
```

在 `VideoLearningService` 中实现：
```typescript
async chat(videoId: string, message: string) {
  const video = await this.findById(videoId);
  
  // 构造 LLM Prompt
  const systemPrompt = `You are Astra, a friendly English learning assistant. 
Here is the video content: ${video.transcriptText}`;
  
  // 调用豆包 LLM API（非实时）
  const response = await this.doubaoLLMService.chat({
    system: systemPrompt,
    messages: [{ role: 'user', content: message }]
  });
  
  return { reply: response.content };
}
```

#### 4.2 iOS 文字聊天实现

```swift
struct VideoTextChatView: View {
    let videoId: String
    @StateObject private var viewModel: VideoTextChatViewModel
    @State private var inputText = ""
    
    var body: some View {
        VStack {
            ScrollView {
                ForEach(viewModel.messages) { message in
                    ChatBubble(message: message)
                }
            }
            
            HStack {
                TextField("Ask about the video...", text: $inputText)
                Button("Send") {
                    Task {
                        await viewModel.sendMessage(inputText)
                        inputText = ""
                    }
                }
            }
        }
    }
}

@MainActor
final class VideoTextChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    private let videoId: String
    private let service = VideoLearningService()
    
    func sendMessage(_ text: String) async {
        messages.append(ChatMessage(role: "user", text: text))
        
        do {
            let reply = try await service.sendChatMessage(videoId: videoId, message: text)
            messages.append(ChatMessage(role: "assistant", text: reply))
        } catch {
            // 错误处理
        }
    }
}
```

### Phase 5: 测验功能（1-2天）

#### 5.1 后端测验生成 API

在 `QuizService` 中实现：
```typescript
async generateQuiz(videoId: string, difficulty: string, questionCount: number) {
  const video = await this.videoLearningService.findById(videoId);
  
  // 构造 LLM Prompt
  const prompt = `Based on this video transcript: ${video.transcriptText}
  
Generate ${questionCount} ${difficulty} level English learning questions for a 6-year-old child.

Question types:
- multiple_choice: 4 options, only one correct
- fill_blank: fill in the missing word
- true_false: true or false question

Return JSON format:
{
  "questions": [
    {
      "type": "multiple_choice",
      "question": "What color is the dragon?",
      "options": ["Red", "Blue", "Green", "Yellow"],
      "correctAnswer": "Red",
      "explanation": "The video says the dragon is red."
    }
  ]
}`;

  // 调用豆包 LLM API
  const response = await this.doubaoLLMService.chat({
    system: "You are a quiz generator for children's English learning.",
    messages: [{ role: 'user', content: prompt }]
  });
  
  const quizData = JSON.parse(response.content);
  
  // 保存到数据库
  const quiz = await this.quizModel.create({
    videoId,
    profileId: video.profileId,
    difficulty,
    questions: quizData.questions,
    submitted: false
  });
  
  return quiz;
}

async submitQuiz(quizId: string, answers: QuizAnswer[]) {
  const quiz = await this.quizModel.findById(quizId);
  
  // 评分
  let correctCount = 0;
  quiz.questions.forEach(q => {
    const userAnswer = answers.find(a => a.questionId === q.questionId);
    if (userAnswer && userAnswer.answer === q.correctAnswer) {
      correctCount++;
    }
  });
  
  const score = Math.round((correctCount / quiz.questions.length) * 100);
  const stars = Math.floor(score / 20); // 每20分得1颗星，最多5颗
  
  // 更新测验记录
  quiz.submitted = true;
  quiz.submittedAt = new Date();
  quiz.answers = answers;
  quiz.score = score;
  quiz.correctCount = correctCount;
  quiz.starsEarned = stars;
  await quiz.save();
  
  // 授予星星奖励
  await this.rewardsService.grantStars(quiz.profileId, stars);
  
  return {
    score,
    correctCount,
    totalCount: quiz.questions.length,
    stars
  };
}
```

#### 5.2 iOS 测验实现

**VideoQuizView.swift**：
```swift
struct VideoQuizView: View {
    let videoId: String
    @StateObject private var viewModel: VideoQuizViewModel
    @State private var selectedDifficulty = "easy"
    @State private var questionCount = 5
    
    var body: some View {
        VStack {
            if viewModel.quiz == nil {
                // 生成测验界面
                VStack(spacing: 20) {
                    Text("Generate Quiz")
                        .font(.title)
                    
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        Text("Easy").tag("easy")
                        Text("Medium").tag("medium")
                        Text("Hard").tag("hard")
                    }
                    .pickerStyle(.segmented)
                    
                    Stepper("Questions: \(questionCount)", value: $questionCount, in: 3...10)
                    
                    Button("Generate") {
                        Task {
                            await viewModel.generateQuiz(
                                difficulty: selectedDifficulty,
                                questionCount: questionCount
                            )
                        }
                    }
                }
            } else {
                // 答题界面
                ScrollView {
                    ForEach(viewModel.quiz!.questions) { question in
                        QuestionCard(
                            question: question,
                            selectedAnswer: viewModel.answers[question.id],
                            onSelect: { answer in
                                viewModel.answers[question.id] = answer
                            }
                        )
                    }
                }
                
                Button("Submit") {
                    Task {
                        await viewModel.submitQuiz()
                    }
                }
                .disabled(!viewModel.allQuestionsAnswered)
            }
        }
    }
}

@MainActor
final class VideoQuizViewModel: ObservableObject {
    @Published var quiz: Quiz?
    @Published var answers: [String: String] = [:]
    @Published var isLoading = false
    
    private let videoId: String
    private let service = VideoLearningService()
    
    var allQuestionsAnswered: Bool {
        guard let quiz = quiz else { return false }
        return quiz.questions.allSatisfy { answers[$0.id] != nil }
    }
    
    func generateQuiz(difficulty: String, questionCount: Int) async {
        isLoading = true
        do {
            quiz = try await service.generateQuiz(
                videoId: videoId,
                difficulty: difficulty,
                questionCount: questionCount
            )
        } catch {
            // 错误处理
        }
        isLoading = false
    }
    
    func submitQuiz() async {
        guard let quiz = quiz else { return }
        
        let quizAnswers = answers.map { QuizAnswer(questionId: $0.key, answer: $0.value) }
        
        do {
            let result = try await service.submitQuiz(quizId: quiz.id, answers: quizAnswers)
            // 导航到结果页面
        } catch {
            // 错误处理
        }
    }
}
```

**QuestionCard.swift**（题目卡片组件）：
```swift
struct QuestionCard: View {
    let question: QuizQuestion
    let selectedAnswer: String?
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.question)
                .font(.headline)
            
            switch question.type {
            case "multiple_choice":
                ForEach(question.options ?? [], id: \.self) { option in
                    Button(action: { onSelect(option) }) {
                        HStack {
                            Image(systemName: selectedAnswer == option ? "checkmark.circle.fill" : "circle")
                            Text(option)
                            Spacer()
                        }
                    }
                }
                
            case "fill_blank":
                TextField("Your answer", text: Binding(
                    get: { selectedAnswer ?? "" },
                    set: { onSelect($0) }
                ))
                
            case "true_false":
                HStack {
                    Button("True") { onSelect("true") }
                    Button("False") { onSelect("false") }
                }
            
            default:
                EmptyView()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
    }
}
```

## 关键文件清单

### 后端新建文件
- `/Users/aluan/LingoBuddy/backend/src/video-learning/video-learning.module.ts`
- `/Users/aluan/LingoBuddy/backend/src/video-learning/video-learning.controller.ts`
- `/Users/aluan/LingoBuddy/backend/src/video-learning/video-learning.service.ts`
- `/Users/aluan/LingoBuddy/backend/src/video-learning/video-content.schema.ts`
- `/Users/aluan/LingoBuddy/backend/src/video-learning/video-processor.service.ts`
- `/Users/aluan/LingoBuddy/backend/src/video-learning/bilibili-subtitle.service.ts` - 字幕下载（优先）
- `/Users/aluan/LingoBuddy/backend/src/video-learning/bilibili-downloader.service.ts` - 音频下载（备选）
- `/Users/aluan/LingoBuddy/backend/src/video-learning/doubao-asr.service.ts` - ASR 转录（备选）
- `/Users/aluan/LingoBuddy/backend/src/video-learning/quiz.service.ts` - 测验生成服务
- `/Users/aluan/LingoBuddy/backend/src/video-learning/quiz.schema.ts` - 测验数据模型

### 后端修改文件
- `/Users/aluan/LingoBuddy/backend/src/conversations/conversation.schema.ts` - 添加 videoId 和 videoContext 字段
- `/Users/aluan/LingoBuddy/backend/src/voice/voice-session.service.ts` - startSession 支持 videoId 参数
- `/Users/aluan/LingoBuddy/backend/src/app.module.ts` - 导入 VideoLearningModule

### iOS 新建文件
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Views/VideoLearningView.swift`
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Views/VideoProcessingView.swift`
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Views/VideoDetailView.swift`
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Views/VideoTextChatView.swift`
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Views/VideoVoiceChatView.swift`
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Views/VideoQuizView.swift` - 测验页面
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Views/QuizResultView.swift` - 测验结果页面
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Views/Components/QuestionCard.swift` - 题目卡片组件
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Services/VideoLearningService.swift`
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Models/VideoContent.swift`
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Models/Quiz.swift` - 测验数据模型

### iOS 修改文件
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Services/VoiceSessionService.swift` - startSession 支持 videoId 参数
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Services/DoubaoVoiceClient.swift` - 支持 videoContext 注入
- `/Users/aluan/LingoBuddy/LingoBuddyApp/AppRootView.swift` - 添加新路由
- `/Users/aluan/LingoBuddy/LingoBuddyApp/Views/HomeView.swift` - 添加入口按钮

## 环境配置

### 后端依赖安装

**package.json**：
```json
{
  "dependencies": {
    "yt-dlp-wrap": "^2.3.0",
    "bull": "^4.12.0",
    "@types/bull": "^4.10.0",
    "form-data": "^4.0.0"
  }
}
```

**系统依赖**（Docker 或本地）：
```bash
apt-get update
apt-get install -y python3 python3-pip ffmpeg

# 安装 bili 命令（优先）
pip3 install bili

# 安装 yt-dlp（备选）
pip3 install yt-dlp
```

**环境变量**（`.env`）：
```bash
# 现有配置
DOUBAO_APP_ID=3726144181
DOUBAO_APP_KEY=PlgvMymc7f3tQnJ6
DOUBAO_TOKEN=ii5GD5xL8FbOzqkNuFTyhmrhkKbNXV7Q

# 新增
DOUBAO_ASR_API_URL=https://openspeech.bytedance.com/api/v1/asr
VIDEO_STORAGE_PATH=/tmp/lingobuddy/videos
MAX_VIDEO_DURATION=3600
```

### iOS 无需额外依赖
复用现有的网络层和 UI 组件。

## 数据流设计

### 视频提交到转录完成流程

```
1. iOS: 用户输入 URL
   ↓
2. iOS: POST /video-learning/submit
   ↓
3. Backend: 验证 URL，创建 VideoContent (status: pending)
   ↓
4. Backend: 返回 videoId
   ↓
5. Backend: 异步任务开始
   ├─ 步骤 1: 尝试使用 bili 命令下载字幕
   │   ├─ 成功 → 解析字幕 → 更新 VideoContent (source: subtitle, status: completed)
   │   └─ 失败 → 进入步骤 2
   │
   ├─ 步骤 2: 使用 yt-dlp 下载音频
   │   └─ BilibiliDownloaderService.download()
   │
   ├─ 步骤 3: ffmpeg 转换为 16kHz WAV
   │
   ├─ 步骤 4: 调用豆包 ASR API
   │   └─ DoubaoAsrService.transcribe()
   │
   └─ 步骤 5: 更新 VideoContent (source: asr, status: completed)
   ↓
6. iOS: 轮询 GET /video-learning/:videoId/status (每 2 秒)
   ↓
7. iOS: 收到 completed 状态，跳转到详情页
```

### 基于视频内容的语音对话流程

```
1. iOS: 用户点击"语音通话"
   ↓
2. iOS: 加载视频转录内容
   ↓
3. iOS: DoubaoVoiceClient.startCall(videoContext: transcriptText)
   ↓
4. iOS: makeStartEngineConfig() 将视频内容注入到 dialog_context
   ↓
5. 豆包 SDK: 建立 WebSocket 连接
   ↓
6. 用户说话 → ASR 识别 → LLM 基于视频内容生成回复 → TTS 播放
```

### 文字聊天流程

```
1. iOS: 用户输入问题
   ↓
2. iOS: POST /video-learning/:videoId/chat
   ↓
3. Backend: 加载 VideoContent.transcriptText
   ↓
4. Backend: 构造 Prompt (system: 视频内容, user: 问题)
   ↓
5. Backend: 调用豆包 LLM API
   ↓
6. Backend: 返回 AI 回复
   ↓
7. iOS: 显示回复在聊天界面
```

## 潜在挑战与解决方案

### 1. 哔哩哔哩反爬虫机制
**问题**：直接下载可能被限流或封禁 IP  
**解决方案**：
- 使用 yt-dlp 最新版本（持续更新反爬虫策略）
- 添加 User-Agent 和 Referer 头
- 实现重试机制和指数退避
- 生产环境考虑使用代理池

### 2. 长视频 ASR 处理时间
**问题**：30 分钟视频可能需要 5-10 分钟转录  
**解决方案**：
- 使用 Bull 异步队列，避免阻塞 HTTP 请求
- 提供实时进度反馈
- 支持音频分段并行处理
- 缓存已转录内容，避免重复处理

### 3. 视频内容过长导致上下文溢出
**问题**：豆包 LLM 有 token 限制（如 8k tokens）  
**解决方案**：
- **智能摘要**：使用 LLM 先生成视频内容摘要（500-1000 字）
- **分段索引**：将转录文本分段，根据用户问题检索相关段落
- **向量检索**：使用 embedding + 向量数据库实现语义搜索（后续优化）

### 4. 音频格式兼容性
**问题**：不同视频源的音频编码格式不同  
**解决方案**：
- 使用 ffmpeg 统一转换为 16kHz PCM/WAV 格式
- 转换命令：`ffmpeg -i input.m4a -ar 16000 -ac 1 output.wav`

### 5. 存储成本
**问题**：大量视频音频文件占用磁盘空间  
**解决方案**：
- 转录完成后立即删除音频文件
- 只保留转录文本和元数据
- 实现定期清理策略（如 30 天未访问的视频）

## 验证计划

### 后端验证
1. **视频下载测试**：
   ```bash
   curl -X POST http://localhost:3000/video-learning/submit \
     -H "Content-Type: application/json" \
     -d '{"url": "https://www.bilibili.com/video/BV1xx411c7mD"}'
   ```
   验证返回 `videoId` 和 `status: pending`

2. **进度查询测试**：
   ```bash
   curl http://localhost:3000/video-learning/{videoId}/status
   ```
   验证返回进度百分比和状态

3. **转录完成测试**：
   查询 MongoDB 确认 `transcriptText` 字段已填充

4. **文字聊天测试**：
   ```bash
   curl -X POST http://localhost:3000/video-learning/{videoId}/chat \
     -H "Content-Type: application/json" \
     -d '{"message": "视频讲了什么？"}'
   ```
   验证 AI 回复基于视频内容

### iOS 验证
1. **URL 提交测试**：
   - 输入有效的哔哩哔哩 URL
   - 验证跳转到进度页面
   - 验证进度条实时更新

2. **视频列表测试**：
   - 验证已处理视频显示在列表中
   - 验证卡片显示正确的标题、时长、状态

3. **文字聊天测试**：
   - 进入视频详情页
   - 点击"文字聊天"
   - 发送问题，验证 AI 回复相关内容

4. **语音对话测试**：
   - 进入视频详情页
   - 点击"语音通话"
   - 开始通话，询问视频相关问题
   - 验证 Astra 的回复基于视频内容

### 端到端测试
1. 提交一个 5 分钟的哔哩哔哩视频
2. 等待转录完成（约 2-3 分钟）
3. 进入详情页，查看完整转录文本
4. 文字聊天：问"视频的主题是什么？"
5. 语音通话：说"Tell me more about the main topic"
6. 验证两种方式的回复都基于视频内容

## 后续扩展（可选）

### Phase 6: 性能优化（1-2天）
- 实现视频内容智能摘要
- 添加向量检索（embedding + Pinecone）
- 优化长文本处理

### Phase 7: 用户体验优化（1-2天）
- 添加视频封面展示
- 实现离线缓存
- 优化错误处理和重试
- 添加 WebSocket 推送（替代轮询）

## 总结

这个实现计划充分复用了现有架构（豆包 SDK、MongoDB、Redis、VoiceSessionService），采用后端处理视频的策略避免 iOS 端复杂性，通过上下文注入实现基于视频内容的智能对话。

**完整功能包括**：
1. 视频字幕/ASR 转录（优先字幕，备选 ASR）
2. 基于视频内容的文字聊天
3. 基于视频内容的语音对话
4. 智能测验生成和答题系统
5. 星星奖励系统集成

**预计时间**：7-9 天完成全部核心功能。

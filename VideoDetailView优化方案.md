# 视频详情页交互优化

## Context
VideoDetailView 目前存在几个明显的交互问题：封面图字段存在但未使用、转录文本困在 200pt 小框里滚动、三个大按钮视觉权重过重（占屏幕约 1/3）、没有删除视频的入口、统计数字不可交互。优化目标是让用户第一眼看到内容（封面），减少按钮压迫感，转录文本更易读。

## 修改范围

### 主要文件
- `LingoBuddyApp/Views/VideoLearning/VideoDetailView.swift` — 主要改动
- `LingoBuddyApp/Views/VideoLearning/VideoLearningView.swift` — 添加 onDelete 回调处理

### 无需修改
- `VideoLearningService.swift` — `deleteVideo(videoId:)` 已实现（line 89-100）
- `VideoContent.swift` — 模型字段已完整

---

## 新 UI 布局

```
┌────────────────────────────────────┐
│ [←]  Video Details      [···]      │  ← topBar，右端加 ellipsis 菜单
├────────────────────────────────────┤
│                                    │
│   AsyncImage（16:9 封面）          │  ← 新增 thumbnailHero
│   ┌──────────────────────────┐     │
│   │  6:38  · ASR             │     │  �� overlay：时长 + 来源 badge
│   └──────────────────────────┘     │
│   "Bluey 英语配音—BBQ"             │  ← 标题（卡片外独立显示）
│                                    │
│   Transcript                       │  ← 折叠/展开，默认 3 行
│   This is a fun episode...         │
│                      [Show more ↓] │
│                                    │
│  ┌──────┐  ┌──────┐  ┌──────┐     │  ← 三列紧凑按钮（高度从 174pt→70pt）
│  │ 💬   │  │ 🎙   │  │ 📝   │     │
│  │ Chat │  │Voice │  │ Quiz │     │
│  └──────┘  └──────┘  └──────┘     │
│                                    │
└────────────────────────────────────┘
```

---

## 实现步骤

### 1. topBar 加删除入口
- 右端加 `Menu` 按钮（`ellipsis.circle` 图标）
- 内含「Delete Video」选项 → `.confirmationDialog` 二次确认 → `onDelete?()` 回调
- `VideoDetailView` 新增参数 `var onDelete: (() -> Void)? = nil`

### 2. thumbnailHero（新 computed var）
```swift
private var thumbnailHero: some View {
    AsyncImage(url: URL(string: video.thumbnailUrl ?? "")) { phase in
        switch phase {
        case .success(let image):
            image.resizable().aspectRatio(contentMode: .fill)
        case .failure, .empty:
            Rectangle().fill(.secondary.opacity(0.15))
                .overlay(Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 40)).foregroundStyle(.secondary))
        @unknown default: EmptyView()
        }
    }
    .aspectRatio(16/9, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(alignment: .bottomLeading) {
        // 时长 + 来源 badge，渐变遮罩背景
    }
}
```
- `thumbnailUrl` 为 nil 时整个 hero 不显示，videoInfoCard 正常展示

### 3. 转录区改为可展开
- 移除 `ScrollView` + `frame(maxHeight: 200)`
- 改用 `@State private var isTranscriptExpanded = false`
- `Text(...).lineLimit(isTranscriptExpanded ? nil : 3)`
- 底部加 "Show more / Show less" 按钮，`withAnimation(.easeInOut(duration: 0.25))`
- 文本为空时只显示 "No transcript available"，不显示展开按钮

### 4. actionButtons 改为三列紧凑按钮
- 原来：`VStack` 三个全宽 `ActionButton`（约 174pt 总高）
- 改为：`HStack(spacing: 12)` 三个 `CompactActionButton`（约 70pt 总高）
- 每个按钮：`VStack { Image(systemName:) + Text(label) }` + 白色卡片背景 + 彩色图标
- 旧的 `ActionButton` struct 保留但 `actionButtons` computed var 改用新组件

### 5. VideoLearningView 添加删除处理
```swift
// VideoLearningViewModel 新增
func deleteVideo(videoId: String) async {
    try? await service.deleteVideo(videoId: videoId)
    await loadVideos()
}

// sheet 调用处
VideoDetailView(
    video: video,
    onBack: { selectedVideo = nil },
    onDelete: {
        selectedVideo = nil
        Task { await viewModel.deleteVideo(videoId: video.id) }
    }
)
```

---

## 注意事项
- Bilibili 封面 URL 可能是 `http://`，`Info.plist` 已设 `NSAllowsArbitraryLoads = true`，不需额外配置
- 删除确认用 `.confirmationDialog`（iOS 15+ 原生）
- `StatCard` action 参数默认 nil，不影响其他地方的 Preview 调用

## 验证方式
1. Xcode 编译无 error
2. 真机：进入详情页，封面图正确加载；`thumbnailUrl` 为空时无异常
3. 点「···」→ Delete → 确认 → 视频从列表消失
4. Transcript 展开/收起动画正常
5. 三列按钮点击进入对应功能正常
6. StatCard 点击正确跳转 Chat / Quiz

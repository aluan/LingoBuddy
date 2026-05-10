# Doubao SDK 配置说明

## 快速开始

### 1. 配置已完成 ✅

你的 Doubao 凭证已经配置在 `LingoBuddyApp/Config/DoubaoConfig.swift` 中：

```swift
struct DoubaoConfig {
    static let appId = "3726144181"
    static let appKey = "PlgvMymc7f3tQnJ6"
    static let token = "ii5GD5xL8FbOzqkNuFTyhmrhkKbNXV7Q"
    // ... 其他配置
}
```

### 2. 打开项目

⚠️ **重要**：必须使用 `.xcworkspace` 文件（不是 `.xcodeproj`）：

```bash
open LingoBuddy.xcworkspace
```

### 3. 配置 Xcode

在 Xcode 中设置桥接头文件：
1. 打开项目设置
2. Build Settings → Swift Compiler - General
3. 设置 "Objective-C Bridging Header" 为：`LingoBuddyApp/LingoBuddy-Bridging-Header.h`

### 4. 启动后端

```bash
cd backend
npm run start:dev
```

### 5. 运行 iOS 应用

在 Xcode 中按 ⌘R 运行

## 真机测试

在真机上测试时，需要修改 `DoubaoConfig.swift` 中的后端地址：

```swift
static let backendBaseURL = "http://192.168.3.17:3000"  // 改为你的 Mac 本地 IP
```

## 文件说明

### 配置文件（已在 .gitignore 中）
- `LingoBuddyApp/Config/DoubaoConfig.swift` - 包含敏感凭证，不会提交到 git

### 模板文件（会提交到 git）
- `LingoBuddyApp/Config/DoubaoConfig.swift.template` - 供其他开发者使用的模板

### 其他开发者如何配置

1. 复制模板文件：
```bash
cp LingoBuddyApp/Config/DoubaoConfig.swift.template LingoBuddyApp/Config/DoubaoConfig.swift
```

2. 编辑 `DoubaoConfig.swift`，填入自己的凭证

## 架构说明

### 纯 Swift 配置 ✨

不需要 Objective-C 配置文件！所有配置都在 Swift 中：

```swift
// ✅ 简洁的 Swift 配置
struct DoubaoConfig {
    static let appId = "..."
    static let appKey = "..."
}

// ❌ 不再需要 Objective-C 桥接
// const NSString* SDEF_APPID = @"...";
```

### 语音流程

```
iOS App → Doubao SDK → Doubao Cloud (语音识别和合成)
        ↓ REST API ↓
        Backend (数据持久化：对话、奖励、进度)
```

## 故障排查

### "Failed to create speech engine"
- 检查 `DoubaoConfig.swift` 中的凭证是否正确
- 确保使用 `.xcworkspace` 文件打开项目
- 确认桥接头文件配置正确

### "Failed to start session"
- 确认后端正在运行（端口 3000）
- 真机测试时，检查 `backendBaseURL` 是否使用了正确的本地 IP
- 确保 Mac 和设备在同一网络

### "Microphone permission denied"
- 检查 Info.plist 中有 `NSMicrophoneUsageDescription`
- 重置权限：设置 → 隐私 → 麦克风 → LingoBuddy

## 更多信息

详细文档请查看 `DOUBAO_INTEGRATION.md`

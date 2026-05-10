# 🔧 Xcode 项目配置步骤

## 问题：Cannot find 'DoubaoVoiceClient' in scope

这是因为新创建的 Swift 文件还没有添加到 Xcode 项目中。

## 解决方案

### 步骤 1: 打开 Xcode 项目

```bash
open LingoBuddy.xcworkspace
```

### 步骤 2: 添加新文件到项目

在 Xcode 中，需要添加以下文件：

#### 2.1 添加 DoubaoConfig.swift
1. 在 Xcode 左侧项目导航器中，右键点击 `LingoBuddyApp` 文件夹
2. 选择 "Add Files to LingoBuddy..."
3. 导航到 `/Users/aluan/AI开源项目/LingoBuddy/LingoBuddyApp/Config/`
4. 选择 `DoubaoConfig.swift`
5. 确保勾选 "Copy items if needed" 和 "Add to targets: LingoBuddy"
6. 点击 "Add"

#### 2.2 添加 DoubaoVoiceClient.swift
1. 右键点击 `LingoBuddyApp/Services` 文件夹
2. 选择 "Add Files to LingoBuddy..."
3. 导航到 `/Users/aluan/AI开源项目/LingoBuddy/LingoBuddyApp/Services/`
4. 选择 `DoubaoVoiceClient.swift`
5. 确保勾选 "Copy items if needed" 和 "Add to targets: LingoBuddy"
6. 点击 "Add"

#### 2.3 添加 VoiceSessionService.swift
1. 在同一个 `Services` 文件夹中
2. 选择 "Add Files to LingoBuddy..."
3. 选择 `VoiceSessionService.swift`
4. 确保勾选 "Copy items if needed" 和 "Add to targets: LingoBuddy"
5. 点击 "Add"

### 步骤 3: 配置 Objective-C 桥接头文件

1. 在 Xcode 中，点击项目名称（最顶层的 LingoBuddy）
2. 选择 "LingoBuddy" target
3. 点击 "Build Settings" 标签
4. 搜索 "Bridging Header"
5. 在 "Objective-C Bridging Header" 中设置：
   ```
   LingoBuddyApp/LingoBuddy-Bridging-Header.h
   ```

### 步骤 4: 清理并重新构建

1. 按 `Shift + Command + K` 清理项目
2. 按 `Command + B` 构建项目

### 步骤 5: 验证

构建成功后，`SpeakView.swift` 应该能够找到 `DoubaoVoiceClient` 了。

## 快速方法：使用命令行添加文件

如果你熟悉 Xcode 项目文件，也可以直接编辑 `project.pbxproj`，但手动在 Xcode 中添加更安全。

## 文件清单

确保以下文件都在 Xcode 项目中：

```
LingoBuddyApp/
├── Config/
│   └── DoubaoConfig.swift              ✅ 需要添加
├── Services/
│   ├── DoubaoVoiceClient.swift         ✅ 需要添加
│   ├── VoiceSessionService.swift       ✅ 需要添加
│   └── VoiceRealtimeClient.swift       (旧文件，可以移除)
├── Views/
│   └── SpeakView.swift                 (已修改，使用 DoubaoVoiceClient)
└── LingoBuddy-Bridging-Header.h        ✅ 需要配置

```

## 常见问题

### Q: 添加文件后还是找不到？
A: 确保文件的 Target Membership 包含了 "LingoBuddy"：
1. 选中文件
2. 在右侧 File Inspector 中
3. 检查 "Target Membership" 是否勾选了 "LingoBuddy"

### Q: 桥接头文件配置不生效？
A: 
1. 确保路径是相对于项目根目录的
2. 清理项目 (Shift + Command + K)
3. 删除 DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/LingoBuddy-*`
4. 重新构建

### Q: 还是报错？
A: 检查以下内容：
1. 所有新文件都在 Xcode 项目导航器中可见
2. 文件的 Target Membership 正确
3. 桥接头文件路径正确
4. CocoaPods 已安装 (`pod install` 已运行)
5. 使用的是 `.xcworkspace` 而不是 `.xcodeproj`

## 下一步

配置完成后，就可以运行应用了：
1. 启动后端：`cd backend && npm run start:dev`
2. 在 Xcode 中按 `Command + R` 运行应用

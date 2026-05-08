# LingoBuddy UI 设计稿提示词：Astra 龙骑士冒险版本

> 商用或上架时请使用原创角色与原创视觉资产。本版本将主角设定为原创少女龙骑士 Astra，仅保留“北欧幻想龙骑士英语冒险”的氛围方向。

## 全局导航与视觉规则

以下 4 个页面统一使用同一套底部主导航：

1. Home
2. Dragons
3. Quests
4. Profile

全局设计要求：

* 固定 iOS 风格底部 Tab Bar
* 半透明磨砂奶油色背景
* 圆润可爱图标
* 柔和阴影与轻漂浮感
* 当前激活 Tab 使用珊瑚橙高亮
* 图标具有龙骑士冒险感，儿童容易识别
* 所有页面都要适合 4-10 岁儿童
* 主色调为天空蓝、草地绿、木质棕、珊瑚橙、温暖米色
* 页面文字少、信息清晰、点击区域大
* 风格为高品质 iOS App UI、儿童友好、北欧幻想冒险、电影级动画质感

## 生成与切图交付规则

每个页面生成时必须同时输出两类结果：

1. **整页效果图**
   * 文件名示例：`home_full.png`、`speak_full.png`
   * 完整展示最终 UI 效果
   * 可以包含示例文字和示例数字，用于视觉确认

2. **开发切图资产包**
   * 背景图必须去掉所有动态文字、数字、字幕、任务内容、按钮文案和选中态文字
   * 可复用 UI 组件必须单独导出为透明 PNG
   * 所有文本内容后续由 App 代码动态渲染，不要烤进切图素材里
   * 切图素材边缘要干净，不要带多余背景、阴影裁切或白边
   * 组件需要保留自身阴影、高光、质感和圆角
   * 文件命名使用英文小写加下划线

动态内容不要出现在切图素材中，包括：

* 星星数量，例如 `128 Stars`
* 连续天数，例如 `7 Day Streak`
* 今日任务标题和任务内容
* 主按钮文字，例如 `Talk with Astra`
* Tab 文案和激活态文字
* 聊天字幕
* 实时状态文字，例如 `Listening`
* 家长/孩子数据数字

必须将整页效果图和每个切图资产分别输出为独立图片文件。

禁止：

* 不要把整页效果图和切图资产放在同一张图里
* 不要生成 asset sheet
* 不要生成拼图
* 不要把多个按钮、图标、卡片排在同一张 PNG 上
* 不要用白底图承载多个资产

正确交付方式：

* 一个完整页面预览图是一个单独 PNG
* 一个背景图是一个单独 PNG
* 每个按钮、图标、卡片、气泡都是各自独立的透明 PNG
* 文件名必须和提示词中列出的名称一一对应

---

## 1. Home

```text
设计一套 iPhone 竖屏高保真儿童英语 AI 陪聊 App 首页 UI 资产，App 名称为「LingoBuddy」。

页面类型：首页（Home Screen）

画布尺寸：
1290 × 2796 px

输出要求：
请同时生成：
1. `home_full.png`：完整首页效果图，包含示例文字和示例数字
2. `home_bg.png`：首页纯背景图，去掉所有文字、数字、按钮文案、Tab 文案、Tab 图标、任务文字和数据胶囊文字，只保留场景、角色、光影和氛围
3. 透明 PNG 切图资产：
   - `home_logo_badge.png`：LingoBuddy 木牌 Logo 底板，可不含文字
   - `home_stat_capsule.png`：顶部数据胶囊空底，不含星星数量和连续天数文字
   - `icon_star.png`：星星图标
   - `icon_fire.png`：火焰图标
   - `home_mission_card.png`：羊皮纸任务卡和木质标题牌空底，不含 Today’s Mission 和任务内容文字
   - `home_talk_button.png`：橙色主按钮空底，不含 Talk with Astra 文案
   - `icon_arrow_next.png`：按钮右侧箭头图标
   - `home_tab_bar_bg.png`：底部 Tab Bar 空背景
   - `tab_icon_home.png`
   - `tab_icon_dragons.png`
   - `tab_icon_quests.png`
   - `tab_icon_profile.png`

切图要求：
所有切图资产必须是独立图片文件，不要和 `home_full.png` 放在同一张图里，不要生成 asset sheet。透明 PNG 中组件居中，边缘干净，保留阴影和高光。所有动态文字和数字必须留给 SwiftUI 渲染。

整体风格：
高品质 iOS 儿童英语冒险 App UI，北欧幻想龙骑士世界，像电影级动画世界与现代移动产品设计结合。
页面目标是在 3 秒内让孩子理解：今天要和伙伴一起开始英语冒险。

主角设定：
一位原创少女龙骑士 Astra。
金色编发、柔和大眼睛、友善笑容、轻量皮革与毛绒冒险服装。
她是孩子的英语冒险伙伴，不是战斗角色，也不是老师。
整体气质温暖、自信、有陪伴感，适合 4-10 岁儿童。

伙伴设定：
一只小黑龙宝宝，圆眼睛、表情亲切、可爱不危险。
它出现在任务卡或主按钮附近，像在邀请孩子一起冒险。

场景设定：
北欧幻想海岛村庄。
背景包含：

* 温暖阳光
* 木质维京小屋
* 海湾港口
* 草地与小路
* 蓝天白云
* 远处飞龙剪影
* 轻幻想感
* 冒险氛围但不危险

页面布局：

* 顶部显示 App Logo：「LingoBuddy」
* 顶部左侧数据胶囊：星星图标 + “128 Stars”
* 顶部右侧数据胶囊：火焰图标 + “7 Day Streak”
* 主角 Astra 位于页面视觉中心，小黑龙在旁边或任务卡上
* 中下部显示羊皮纸今日任务木牌：
  “Today’s Mission”
  “Find a baby dragon”
* 页面底部上方有超大圆角主按钮：
  “Talk with Astra”
* 主按钮右侧包含清晰的箭头图标
* 所有按钮适合儿童点击
* 页面文字少，主操作非常突出
* UI 留白舒适，避免拥挤

底部 Tab Bar（必须生成）：
固定 iOS 风格底部导航栏。

Tab 包含：

1. Home
2. Dragons
3. Quests
4. Profile

设计要求：

* Home Tab 为当前激活状态
* 激活状态使用珊瑚橙高亮
* Home 图标像小木屋地图入口
* Dragons 图标像龙蛋或小龙头像
* Quests 图标像冒险卷轴地图
* Profile 图标像小龙骑士头像或盾牌
* 半透明磨砂背景
* 柔和阴影
* 漂浮感设计

视觉元素：

* 圆润羊皮纸任务卡
* 木质标签
* 星星奖励
* 小龙宝宝
* 天空与海岛纵深
* 温暖动画电影质感

重要要求：

* 必须生成完整页面预览图和开发切图资产包
* 整页效果图和每个切图资产必须分别是独立文件
* 不要只输出一张烤死文字的整页图
* 不要输出 asset sheet 或拼图
* 切图素材不要包含动态文字、数字或任务内容
* 高保真
* Production-quality mobile UI
```

---

## 2. Dragons

```text
设计一张 iPhone 竖屏高保真儿童英语 AI 陪聊 App UI 界面，App 名称为「LingoBuddy」。

页面类型：龙伙伴收藏页（Dragons Screen）

画布尺寸：
1290 × 2796 px

整体风格：
高品质 iOS 儿童收集与陪伴页面，北欧幻想龙巢训练营风格。
页面目标是让孩子感觉“我的小龙伙伴在等我”，并愿意回来照顾、互动、练习英语单词。

场景设定：
温暖的木质龙巢训练营。
背景包含：

* 圆形木屋内部或半开放龙巢
* 柔和天窗阳光
* 草垫、木桶、小旗帜
* 龙蛋、徽章、训练小道具
* 远处海岛天空
* 安全、温暖、可爱，不要战斗感

当前小龙设定：
一只小黑龙宝宝作为当前伙伴。
大眼睛、圆润、表情亲切，有一点俏皮。
位于页面上半部分视觉中心，体型较大，像可以被照顾的宠物伙伴。

页面布局：

* 顶部木牌标题：
  “My Dragons”
* 顶部右侧显示星星余额：
  星星图标 + “128”
* 顶部左侧有返回或 Home 小圆木按钮
* 当前小龙大图占据上半屏中心
* 小龙下方显示名字与等级：
  “Night Bean”
  “Level 3”
* 亲密度进度条：
  “Buddy Bond”
  进度显示 72%
* 今日照顾状态小标签：
  “Happy”
  “Fed today”
  “Ready to practice”
* 中部展示 3 个大号儿童操作按钮：
  “Feed”
  “Play”
  “Practice Words”
* 每个按钮配清晰图标：食物、玩具球、书本/麦克风
* 下半部展示横向小龙收藏列表：
  已解锁小黑龙、锁定的绿色小龙、锁定的冰蓝小龙、锁定的红色小龙
* 锁定卡片显示小锁图标与简短解锁提示：
  “Unlock in Forest Quest”
* 页面要有“即使只有 1 只小龙也内容充实”的感觉

底部 Tab Bar（必须生成）：
固定 iOS 风格底部导航栏。

Tab 包含：

1. Home
2. Dragons
3. Quests
4. Profile

设计要求：

* Dragons Tab 为当前激活状态
* 激活状态使用珊瑚橙高亮
* Dragons 图标使用可爱小龙头像或龙蛋
* Tab Bar 半透明磨砂背景
* 柔和阴影
* 漂浮感设计

视觉元素：

* 木质龙巢
* 小龙收藏卡
* 亲密度进度条
* 装扮槽位
* 星星奖励
* 圆润按钮
* 温暖米色与木质棕为主，天空蓝和草地绿点缀

重要要求：

* 单张页面
* 不要拼图
* 不要多屏
* 只生成一个 iPhone 竖屏 UI
* 高保真
* Production-quality mobile UI
```

---

## 3. Quests

```text
设计一张 iPhone 竖屏高保真儿童英语 AI 陪聊 App UI 界面，App 名称为「LingoBuddy」。

页面类型：冒险任务页（Quests Screen）

画布尺寸：
1290 × 2796 px

整体风格：
高品质 iOS 儿童任务与地图页面，北欧幻想海岛训练地图风格。
页面目标是让孩子感觉“今天只要完成一小段冒险”，任务清楚、奖励清楚、进度清楚。

场景设定：
羊皮纸冒险地图覆盖在明亮海岛世界上。
背景包含：

* 海岛训练地图
* 弯曲小路
* 森林、山丘、海湾、木桥
* 小龙巢穴
* 任务节点
* 星星奖励标记
* 柔和天空蓝背景

页面布局：

* 顶部木牌标题：
  “Today’s Quests”
* 顶部进度胶囊：
  “2 / 3 Done”
* 顶部右侧奖励预览：
  星星图标 + “+15”
* 主体为大型岛屿训练地图
* 地图路线包含 3 个今日任务节点：
  1. “Talk with Astra”
  2. “Find a baby dragon”
  3. “Learn 3 new words”
* 已完成节点使用绿色勾选徽章
* 当前节点使用发光珊瑚橙圆环
* 未完成节点使用柔和木质圆点
* 地图旁有小龙或 Astra 小头像作为当前位置标记
* 地图下方展示今日任务列表卡片：
  每条任务包含图标、任务名、奖励、完成状态
* 底部显示下一站解锁提示：
  “Next: Forest Nest”
  “Finish today to unlock a map piece”
* 全部完成状态可展示一枚大星星徽章：
  “Great training today!”

底部 Tab Bar（必须生成）：
固定 iOS 风格底部导航栏。

Tab 包含：

1. Home
2. Dragons
3. Quests
4. Profile

设计要求：

* Quests Tab 为当前激活状态
* 激活状态使用珊瑚橙高亮
* Quests 图标使用冒险卷轴地图
* Tab Bar 半透明磨砂背景
* 柔和阴影
* 漂浮感设计

任务状态要求：

* 未完成：木质节点 + 简短任务文字
* 进行中：珊瑚橙发光节点 + 小角色标记
* 已完成：绿色勾选 + 星星奖励
* 全部完成：顶部进度改为 “3 / 3 Done”，展示大星星奖励反馈

视觉元素：

* 羊皮纸地图
* 木质标题牌
* 任务节点
* 星星与徽章
* 小龙足迹
* 草地绿、天空蓝、木质棕、珊瑚橙点缀

重要要求：

* 单张页面
* 不要拼图
* 不要多屏
* 只生成一个 iPhone 竖屏 UI
* 高保真
* Production-quality mobile UI
```

---

## 4. Profile

```text
设计一张 iPhone 竖屏高保真儿童英语 AI 陪聊 App UI 界面，App 名称为「LingoBuddy」。

页面类型：孩子成长档案页（Profile Screen）

画布尺寸：
1290 × 2796 px

整体风格：
高品质 iOS 儿童成长档案页面，北欧幻想龙骑士徽章墙风格。
页面目标是让孩子感到“我正在变厉害”，首版不包含 Parent Area、家长面板或成人数据后台入口。

页面定位：
这是孩子视角的 Profile，不是家长后台。
页面内容儿童可读、奖励感强、设置入口克制。

场景设定：
龙骑士训练营荣誉小屋。
背景包含：

* 温暖木质墙面
* 羊皮纸档案卡
* 徽章墙
* 小旗帜
* 星星罐
* 小龙伙伴头像
* 柔和阳光
* 干净、温暖、有成就感

页面布局：

* 顶部木牌标题：
  “My Profile”
* 顶部右侧小齿轮设置按钮
* 上方主档案卡：
  孩子头像
  “Mia”
  “Age 6”
  “Little Dragon Rider”
* 档案卡旁展示总星星和连续天数：
  “128 Stars”
  “7 Day Streak”
* 成长等级进度条：
  “English Level”
  “Explorer 2”
  进度条显示接近下一等级
* 徽章墙区域：
  3 枚已解锁徽章
  2 枚锁定徽章
  已解锁徽章包含星星、龙蛋、麦克风
* 最近学会的新词卡片：
  “New Words”
  “dragon”
  “forest”
  “happy”
* 喜欢的话题小标签：
  “Dragons”
  “Food”
  “Animals”
* 基础设置入口以小图标列表展示：
  Sound
  Language
  Notifications
* 页面整体要像儿童荣誉档案，不像成人数据 Dashboard
* 不要生成 Parent Area、家长入口、家长数据卡片或成人管理面板

底部 Tab Bar（必须生成）：
固定 iOS 风格底部导航栏。

Tab 包含：

1. Home
2. Dragons
3. Quests
4. Profile

设计要求：

* Profile Tab 为当前激活状态
* 激活状态使用珊瑚橙高亮
* Profile 图标使用小龙骑士头像或盾牌
* Tab Bar 半透明磨砂背景
* 柔和阴影
* 漂浮感设计

视觉元素：

* 羊皮纸档案卡
* 木质徽章墙
* 成长进度条
* 星星罐
* 小龙伙伴头像
* 温暖米色、木质棕、天空蓝、草地绿、珊瑚橙点缀

重要要求：

* 单张页面
* 不要拼图
* 不要多屏
* 只生成一个 iPhone 竖屏 UI
* 高保真
* Production-quality mobile UI
```

---

## 5. AI 英语实时语音陪聊页面

```text
设计一套 iPhone 竖屏高保真 App UI 设计图和开发切图资产，尺寸 1290 × 2796 px。

App 名称：LingoBuddy
页面类型：AI 英语实时语音陪聊页面 / Real-time Voice Chat Screen
目标用户：4-10 岁儿童
主角：Astrid Hofferson，来自《驯龙高手》，她是孩子的英语冒险伙伴和龙骑士朋友
场景：使用《驯龙高手》风格的温暖北欧龙骑士冒险世界，背景可以是龙训练场、天空飞行平台、木质维京结构、训练旗帜、远处海岛、云朵和飞龙剪影

输出要求：
请同时生成：
1. `speak_full.png`：完整实时语音聊天页效果图，包含示例字幕、状态和星星数字
2. `speak_bg.png`：聊天页纯背景图，去掉返回按钮、星星胶囊、字幕气泡、状态条、麦克风按钮、底部提示文字和所有动态文字，只保留场景、Astrid、小龙、光影和氛围
3. 透明 PNG 切图资产：
   - `speak_back_button.png`：返回按钮空图标或圆形按钮背景
   - `speak_star_capsule.png`：顶部星星胶囊空底，不含数字文字
   - `icon_star.png`：星星图标
   - `chat_avatar_child.png`：孩子头像
   - `chat_avatar_astrid.png`：Astrid 头像
   - `chat_bubble_child.png`：孩子字幕气泡空底，不含文字
   - `chat_bubble_astrid.png`：Astrid 字幕气泡空底，不含文字
   - `speak_status_pill.png`：状态条空底，不含 Listening / Thinking / Speaking 文字
   - `icon_ear.png`：Listening 状态图标
   - `icon_waveform.png`：语音波形图标
   - `speak_mic_button.png`：大麦克风按钮底图
   - `icon_mic.png`：麦克风图标
   - `speak_voice_ring.png`：麦克风周围发光圆环或波纹
   - `reward_scale_badge.png`：龙鳞徽章奖励图标
   - `reward_stars_cluster.png`：星星奖励组合图标

切图要求：
所有切图资产必须是独立图片文件，不要和 `speak_full.png` 放在同一张图里，不要生成 asset sheet。透明 PNG 中组件居中，边缘干净，保留阴影、高光、发光和圆角。字幕、状态、星星数量、提示语等全部由 SwiftUI 动态渲染，不要烤进切图素材。

页面核心目标：
让孩子感觉正在和 Astrid 进行实时英语语音对话，而不是在使用 AI 工具。界面要简单、沉浸、有陪伴感，一眼就知道可以点击麦克风开始说话。

页面内容：
- 顶部左侧有返回按钮
- 顶部右侧显示今日星星数量，例如 18 stars
- Astrid Hofferson 位于视觉中心，表情亲切、自信、鼓励，像正在认真听孩子说话
- Astrid 身边可以有一只可爱小龙伙伴，增强儿童吸引力
- 中部显示实时字幕气泡，字幕要大、清晰、儿童易读
- 字幕内容示例：
  Child: I found a red apple!
  Astrid: Great job! Can you find something blue?
- 显示实时状态标签：Listening
- 状态标签可以有柔和发光或轻微波纹效果
- 底部有一个超大的圆形麦克风按钮
- 麦克风按钮应当是页面最明显的交互元素
- 麦克风按钮周围有语音波纹动画效果
- 底部可以显示一句短提示：Tap and speak
- 页面中加入轻量奖励反馈元素，例如星星、龙鳞徽章、小光点
- 不要出现复杂菜单、课程表、题目列表或工具栏

视觉风格：
- 趣味、可爱、温暖、儿童友好
- 明亮的龙骑士冒险感
- 不阴暗、不战斗化、不复杂
- 使用天空蓝、草地绿、阳光黄、珊瑚橙、温暖木色
- 圆润按钮
- 柔和阴影
- 轻量渐变
- 清晰字幕层级
- 字体大、圆润、易读
- 整体像一个会说话的动画冒险朋友
- 不要像教育培训 App
- 不要像聊天机器人工具
- 不要像企业 SaaS 或学习后台
- 高保真 iOS UI
- modern SwiftUI-feasible design
- polished production-ready mobile app interface

动效氛围：
Make the scene feel alive with subtle animated UI cues: glowing voice waves, floating stars, soft wind movement in flags, warm sunlight, and Astrid making friendly eye contact with the child.

重要要求：
- 必须生成完整页面预览图和开发切图资产包
- 整页效果图和每个切图资产必须分别是独立文件
- 不要只输出一张烤死文字的整页图
- 不要输出 asset sheet 或拼图
- 切图素材不要包含动态文字、数字、字幕或状态文案
- 高保真
- Production-quality mobile UI
```

# StartupBoard

> 启动项看板 —— macOS 14+ 的菜单栏启动项管理器，Swift + SwiftUI 原生开发，全中文界面。

> 早期版本名为「启动项管理 / startup-manager」与「LaunchDeck」，现已更名为
> **StartupBoard / 启动项看板**（Bundle ID：`app.startupboard`）。

## 功能

- **菜单栏浮层**：点菜单栏图标即可以毛玻璃面板快速开关后台启动项
- **管理窗口**：侧边栏顶部为「定时任务 / 启动项体检」入口，其余按「自定义 / 第三方 / 系统自带 / 登录项」分组，支持搜索
- **管理范围**（用户级，无需 root）：
  - `~/Library/LaunchAgents` — 当前用户启动项（可启用/停用/删除）
  - `/Library/LaunchAgents` — 所有用户启动项（可启用/停用）
  - 经典登录项（登录时打开的应用，可查看/移除）
- **添加自定义启动项**：支持指定命令/脚本与参数，并可选「登录时 / 每天 / 每周 / 间隔」四种触发方式
- **服务运行控制台**：详情页展示进程 PID、运行次数、上次退出码、CPU 与内存占用，可一键启动 / 重启 / 停止（无需 root）
- **定时任务面板**：聚合 `StartCalendarInterval`、`StartInterval` 与用户 `crontab`，把配置翻译成「每天 09:30」「每周三 18:00」这类可读描述
- **启动项体检**：检查启动程序丢失、plist 损坏、标签冲突、临时路径等常见问题，给出 0–100 评分与可一键处理的建议
- **防呆设计**：全中文界面；系统自带项（`com.apple.*`）不在菜单栏直接展示，停用前需二次确认；删除操作均需确认

## 系统要求

| 项目 | 要求 |
|---|---|
| 系统 | macOS 14.0（Sonoma）及以上，Intel 与 Apple Silicon 均可 |
| 构建工具 | Xcode Command Line Tools（**不需要**完整 Xcode） |
| 第三方依赖 | 无。不使用 SPM / CocoaPods，直接 `swiftc` 编译 |

安装命令行工具：

```sh
xcode-select --install        # 未安装时执行
xcode-select -p               # 确认路径，通常为 /Library/Developer/CommandLineTools
swiftc --version              # 确认编译器可用
```

## 从源码构建

```sh
git clone <仓库地址> StartupBoard
cd StartupBoard

make app    # 编译并打包为 build/StartupBoard.app
make run    # 打包后直接运行
```

其它目标：

```sh
make help       # 查看全部可用命令
make universal  # 编译 arm64 + x86_64 通用二进制并打包
make icon       # 仅重新生成图标（PNG + icns）
make dmg        # 生成可分发的 build/StartupBoard-<版本>.dmg（内含通用二进制）
make clean      # 清理 build/
```

`make app` 只编译当前机器架构，适合本地快速迭代；`make dmg` 会自动走 `universal`，
保证 Apple Silicon 与 Intel 都能运行。

构建参数可用环境变量覆盖，适合工具链不在默认位置或需要交叉编译的情况：

```sh
make app SDK=/path/to/MacOSX14.sdk ARCH=x86_64 DEPLOYMENT_TARGET=14.0
```

> 默认用 `xcrun --show-sdk-path` 取当前 SDK，并显式指定 `-target <arch>-apple-macos14.0`，
> 使编译器按 macOS 14 校验 API 可用性，避免在新系统上编译出无法在旧系统运行的产物。

## 首次使用

1. 首次运行会请求 **「系统事件」自动化权限**（用于读写登录项），请在弹窗中点击允许；
   若未弹出，前往 系统设置 → 隐私与安全性 → 自动化 → 启动项看板 → 开启「系统事件」。
2. 停用/启用通过 `launchctl enable/disable + bootstrap/bootout` 实现，仅影响当前用户会话，不修改厂商文件。
3. 运行状态、定时任务与体检只读取 `launchctl` 与本地配置文件，**不需要额外权限**，也不会修改任何项目；crontab 仅作只读展示。
4. 应用为菜单栏常驻（无 Dock 图标，`LSUIElement = true`），启动后自动打开管理窗口，同时在菜单栏出现图标；关闭窗口后应用不退出，点菜单栏图标可再次打开。

## 打包与分发

`make dmg` 产物内含 `StartupBoard.app` 与 `/Applications` 快捷方式，拖入即可安装。

**自编译无需处理签名问题**：产物在本机生成，不带下载隔离属性，可直接运行。

若要分发给他人，注意当前签名方式为 **ad-hoc（`codesign --sign -`）**，未经 Apple 公证，
从网络下载后首次打开会被 Gatekeeper 拦截，需接收方手动放行：

- **macOS 14 及更早**：右键点按 App → 打开 → 在弹窗中再次点「打开」
- **macOS 15 及以后**：右键打开已不再提供绕过选项。双击 App 后弹窗点「完成」，
  再前往 系统设置 → 隐私与安全性 → 拉到最底部 → 点「仍要打开」，输入密码确认
- 命令行（任意版本）：`xattr -dr com.apple.quarantine /Applications/StartupBoard.app`

要彻底消除提示，需 Apple Developer Program 账号，使用 `SIGN_IDENTITY` 指定 Developer ID 证书签名后
再执行 `xcrun notarytool submit` 公证与 `xcrun stapler staple` 装订：

```sh
make app SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

## 项目结构

```
Sources/StartupBoard/
  App.swift / AppDelegate.swift   入口与菜单栏常驻逻辑
  ItemStore.swift                 统一数据源与状态刷新
  LaunchAgentScanner.swift        扫描 LaunchAgents 目录、解析 plist
  LaunchCtl.swift                 launchctl 封装（enable/disable/bootstrap/kickstart…）
  LoginItemsBridge.swift          经典登录项读写（System Events）
  UserAgentWriter.swift           写入自定义启动项 plist
  CronScanner.swift               crontab 只读解析
  HealthCheck.swift               启动项体检规则
  ScheduleText.swift              定时配置 → 可读描述
  Models.swift / Shell.swift      数据模型与命令执行
  Views/                          SwiftUI 界面（菜单栏浮层、管理窗口、详情页）
Resources/                        Info.plist、图标源文件
Tools/MakeIcon.swift              图标生成器（make icon）
```

## 常见问题

**编译报 `redefinition of module 'SwiftBridging'`**

说明 Command Line Tools 目录混装了新旧文件（`usr/include/swift` 下同时存在
`module.modulemap` 与 `bridging.modulemap`）。Makefile 已自动检测并用 VFS overlay
把多余文件映射为空来规避，**无需 sudo，也不修改系统文件**。若仍失败，可考虑
重装命令行工具：`sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`。

**菜单栏看不到图标**

应用为 `LSUIElement` 模式，无 Dock 图标。若菜单栏条目过多被折叠，可在
系统设置 → 控制中心 → 菜单栏中检查，或直接运行 `make run` 观察是否报错退出。

**开关启动项没反应**

检查「系统设置 → 隐私与安全性 → 自动化」中「启动项看板」的「系统事件」权限是否开启。
重新编译后签名变化可能导致授权失效，需关闭再重新勾选。

**从旧版本升级后，原来的自定义启动项还在吗**

在。新版本使用 `app.startupboard.custom.` 前缀创建新项目，同时识别历史上由
`app.launchdeck.custom.` 与 `local.startup-manager.custom.` 生成的项目，可正常启停与删除。

**是否支持系统级 LaunchDaemons**

暂不支持。`/Library/LaunchDaemons` 需要 privileged helper 提权，计划在后续版本实现。

## 实现说明

- 后台启动项扫描 `LaunchAgents` 目录并解析 plist；启停状态来自 `launchctl print-disabled`（同时兼容 `=> true` 与 `=> disabled` 两种输出），已加载列表来自 `launchctl list`
- 运行时信息来自 `launchctl print gui/$UID/<label>` 与 `ps`；启动/重启/停止分别对应 `kickstart`、`kickstart -k`、`kill SIGTERM`，仅影响当前登录会话
- 定时任务来自 plist 的 `StartCalendarInterval` / `StartInterval`；用户 `crontab` 以只读方式展示（`at`/`atrun` 在 macOS 默认关闭，故不纳入）
- 体检为纯本地静态检查：校验可执行文件是否存在、plist 是否可解析、用户级与系统级标签是否冲突、可执行文件是否位于临时目录等，不修改任何配置
- 自定义项写入 `~/Library/LaunchAgents`，标签前缀 `app.startupboard.custom.`；历史前缀
  `app.launchdeck.custom.` 与 `local.startup-manager.custom.` 仅作识别兼容，不改写旧文件

## 参与贡献

欢迎提交 Issue 与 Pull Request。提交前请确认：

1. `make app` 在当前 macOS 上编译通过（仅有 warning 可接受）；
2. 界面文案保持中文，与现有风格一致；
3. 涉及 `launchctl` 的改动需说明对用户会话的影响范围。

## 许可

[MIT License](LICENSE)

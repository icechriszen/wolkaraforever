# WolkaraForever 国服 / iPhone 使用说明

[English](README.md) · [完整文档索引](docs/README.md) · [实测记录](COMPATIBILITY.md)

本仓库是 [icechriszen/wolkaraforever](https://github.com/icechriszen/wolkaraforever)，
默认上游为 [jklock/wolkaraforever](https://github.com/jklock/wolkaraforever)。
`integration/cn-ios-validated` 保存本地已验证的累计代码；`docs/cn-ios-guide`
在相同代码上整理文档。这些分支尚不是新的正式发行版。

## 已验证范围

截至 2026-11-23，使用 iPhone 17、iOS 27.2.1、付费开发者的 Developer service
模式和国服 Forever 1.60.1.71037，已完成人工操作验证：

- 国服与简体中文客户端、应用内网页登录、复用有效的网站会话及自动启动。
- 角色选择、图形设置及进入世界；包含跨库分配、地址映射和事件监控修复。
- 中文 WolkaraRoue 标准布局、快捷按钮、聊天关闭、技能位添加和轮盘手势。
- 触屏摇杆与轮盘避让，以及 USB GameSir-X5 Lite 摇杆和按键。
- 启动时有外置手柄便隐藏触屏插件和底部工具栏，拔下后下次启动恢复。
- 中文聊天进入输入框、发送一次、收到本人消息回显并显示。

尚未完成规定的两台模拟器验证、TW 客户端对照或长时间稳定性测试。
其他设备、系统、账号或客户端版本不能直接套用上述结论，详见[兼容性记录](COMPATIBILITY.md)。

## 安装与更新

需要 Apple 芯片 Mac、Xcode 及命令行工具、XcodeGen、Python 3、已生效的付费
Apple Developer 团队，以及开启开发者模式并信任 Mac 的 iPhone / iPad。
手机上为游戏和更新预留约 70 GB；源码和构建可以放在外置 SSD 上。

```sh
git clone --branch integration/cn-ios-validated https://github.com/icechriszen/wolkaraforever.git
cd wolkaraforever
cp local.env.example local.env
```

先编辑私有 `local.env`：填写自己的开发者团队、唯一 Bundle ID 和 Keychain group，
保留 `TOLKARA_MODE=developer-service`。随后运行：

```sh
wolkaraforever/tools/install_prerequisites.sh --check
wolkaraforever/tools/device_variables.sh --write
wolkaraforever/tools/preflight.sh
wolkaraforever/tools/install.sh
```

Xcode 应显示已生效的付费团队；仅有 **Personal Team** 不是本指南的配置。
安装与登记时保持手机解锁并通过 USB 连接。本地开发者服务 VPN 是应用连接设备
开发者服务的通道；当前实现只路由本地服务地址，不设置外部服务器、默认互联网路由或 DNS。

以后更新：正常退出游戏、等待保存，再从后台关闭 Wolkara。在源码目录执行
`git pull --ff-only` 和同一个 `install.sh`。保持原签名团队、Bundle ID、Keychain group
和 `local.env`，不要卸载应用。工具检测到游戏运行或更新写入时会拒绝覆盖，先退出再重试。
应用与插件分别更新，插件步骤见下文。

## 国服下载与网页登录

1. 在 **Game Settings Manager → Region / Locale** 选 China / `cn` 和简体中文 / `zhCN`。
2. 下载或继续现有客户端，等启动器就绪后点 **Play**。
3. 新配置在 **Battle.net Login (Experimental)** 启用网页登录，自行完成官方网页的登录与验证。
4. 优先在应用内完成登录。有效的网站会话会保留，但每次启动仍取得新的单次票据，网站也可能要求重新验证。

Safari 会话不会导入应用内浏览器。内置页面无法完成时才用 **Safari fallback…**。
Safari 最后提示无法打开 localhost 时，把最终地址粘贴到 Wolkara 的遮蔽输入框，
点 **Continue**。地址仅在应用内使用，不要放进聊天、Issue 或日志。
**Clear sign-in data** 会清除应用内网站会话及相关保存项。

一个应用内的游戏目录不按区域隔离。现有国服客户端不要直接切成台服做对照；
TW / `zhTW` 已实现选项，但完整对照需另一个独立安装和对应账号资格。

## 插件、标准布局与手柄

退出游戏后，在首页向上滑动，点 **Install Addons (Curse & Direct)**。
在 **My Add-ons** 更新 **WolkaraRoue (bundled)** 到 **1.0.5-cn.7**。
应用升级不会自动替换已安装插件；内置包更新不会覆盖账号的 SavedVariables。

| 需要调整的内容 | 操作 |
| --- | --- |
| 默认技能轮盘布局 | `/mobile` → General / 常规 → Layout / 布局 → **Standard** |
| 插件中文 | Language 选简体中文，或在 zhCN 客户端选 Follow game；保存并关闭设置 |
| 顶部快捷按钮 | `/mobile` → 技能轮盘 → 快捷按钮 → 开启 |
| 移动摇杆没有显示 | 展开底部工具栏，点手柄图标；轮盘负责技能，移动由原生摇杆提供 |
| 外置手柄按键失效 | 在启动器 **UI Manager** 检查 **Gamepad UI**；此开关与触屏显示切换分开 |
| 左轮加号点不到 | 检查聊天栏是否覆盖轮盘；用 `/mobile edit` 移开后完成编辑 |

启动器界面模式和插件的 **Standard / Duo** 是不同设置；标准轮盘不需要改成 Duo。
启动前接好手柄，应用关闭本轮 WolkaraRoue 自动加载及底部触屏工具栏。
正常退出、拔下手柄后再启动，两者恢复，中文、技能和原布局保留。
运行中插拔不会立即改变本轮模式。

固定紧凑摇杆的位置会在 **Play** 时同步给标准轮盘用于避让。
改动摇杆位置后需重新启动游戏；浮动摇杆和 Duo 不属于此次标准布局验证范围。

## 恢复默认设置

- 原生摇杆与工具栏：底部工具栏 → 齿轮 → **Reset to defaults** → **Done**。
- 只调整插件位置：`/mobile edit`，移动后完成；也可用插件的 **Reset positions**。
- 插件默认配置：`/mobile reset`，然后按需 `/reload`。普通轮盘和自由按钮技能保留，
  其他插件设置恢复默认。zhCN 客户端默认跟随游戏，中文包仍在。
- 启动器 **Reset to Default Wow UI Configuration** 针对游戏图形与显示配置，不是插件恢复按钮。

升级不需要重置布局。游戏分辨率通过官方图形选项调整；上述触控修复不会强行替换分辨率。

## 聊天与故障信息

标准布局使用底部键盘；“轻点输入”属于 Duo 聊天按钮。已验证发送方式为 **Classic direct**。
中文输入修复位于应用运行层，单独更新 Lua 插件不能获得这项修复。

`/mobile error` 显示插件记录的 Lua 错误；“没有错误”不代表消息已发送。
`/mobile chatdiag` 显示入口、文字、回车、发送调用、本人回显和显示处理计数。
发送调用不等于已收到回显。cn.7 只保存有限计数、长度和状态，不记录聊天正文。
诊断时复现一次、正常退出保存，先不要重开，下一次加载会重置记录。

在[本 fork 的 Issues](https://github.com/icechriszen/wolkaraforever/issues)提供版本、
设备与系统、执行模式、复现步骤和现象，日志步骤见[帮助说明](docs/SENDING_LOGS.md)。
不要公开密码、票据、完整回调地址、账号文件路径、设备标识、签名或配对文件。

本项目不包含游戏客户端、账号或签名材料。来源与许可见 [NOTICE](NOTICE.md) 和 [CONTRIBUTORS](CONTRIBUTORS.md)。

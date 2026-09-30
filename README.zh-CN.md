# FluxEUICC

[English](README.md) | **简体中文** | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [العربية](README.ar.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

**轻松添加、切换和管理你的 eSIM 套餐。**

FluxEUICC 是一款基于 [OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC) 的 Android 可拆卸 eSIM 管理应用。它将多个套餐集中在清晰的界面中，无须 ROOT，即可完成日常的套餐下载、切换与管理。

<p align="center">
  <img src="art/FluxEUICC-logo.png" alt="FluxEUICC" width="240" height="240">
</p>

## 为什么选择 FluxEUICC

- **现代、清晰的界面**：卡片式套餐列表、直观的启用状态和简洁的菜单，让常用操作更容易找到；支持系统主题配色和自适应图标。
- **更及时的切换反馈**：优化套餐切换后的重连等待，并提供清楚的操作结果提示，减少长时间等待带来的不确定感。
- **九种界面语言**：默认跟随系统，也可选择支持的语言，让不同地区的用户更容易使用。
- **面向现代 Android 设备**：适配 Android 17，专注 64 位 ARM 设备，支持现代 Android 的全面屏布局与返回手势。

## 可以做什么

- 扫描二维码或输入激活码，下载新的 eSIM 套餐。
- 查看已安装的套餐，启用、停用或切换使用中的套餐。
- 重命名套餐、删除不再需要的套餐，整理你的 eSIM 列表。
- 查看卡片信息、检查设备兼容性，并通过兼容的 USB CCID 读卡器管理卡片。

## 支持的语言

英语、简体中文、繁体中文、日语、韩语、阿拉伯语、法语、德语和西班牙语。

系统语言不在支持范围内时，界面使用英文。

## 下载与使用

当前版本：**1.1.2**。前往 [下载页面](https://github.com/Stickmin522/FluxEUICC/releases/latest) 获取 APK。

1. 在 Android 9 或更高版本的 64 位 ARM 设备上安装应用。
2. 插入兼容 OpenEUICC 的可拆卸 eSIM，或连接兼容的 USB 读卡器。
3. 手机卡槽中的卡片需授权 FluxEUICC 的签名证书；可在应用设置中查看并复制授权所需的指纹，具体步骤见发布页的中文使用说明。
4. 添加你的套餐，选择需要启用的 eSIM。

可用功能取决于手机、卡片与读卡器的兼容性。套餐切换后的网络恢复时间由卡片和手机系统决定。

## 开源与许可

FluxEUICC 基于 OpenEUICC，采用 [GPL-3.0-only 许可](LICENSE)，保留上游版权声明；依赖组件的许可证见各自目录。

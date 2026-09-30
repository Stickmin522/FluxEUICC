# FluxEUICC

[English](README.md) | [简体中文](README.zh-CN.md) | **繁體中文** | [日本語](README.ja.md) | [한국어](README.ko.md) | [العربية](README.ar.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

**輕鬆新增、切換與管理你的 eSIM 方案。**

FluxEUICC 是一款基於 [OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC) 的 Android 可拆卸 eSIM 管理應用程式。它將多個方案集中在清楚的介面中，無須 ROOT，即可完成日常的方案下載、切換與管理。

<p align="center">
  <img src="art/FluxEUICC-logo.png" alt="FluxEUICC" width="240" height="240">
</p>

## 為什麼選擇 FluxEUICC

- **現代、清楚的介面**：卡片式方案清單、直觀的啟用狀態與簡潔的選單，讓常用操作更容易找到；支援系統主題配色與自適應圖示。
- **更即時的切換回饋**：最佳化方案切換後的重新連線等待，並提供清楚的操作結果提示，減少長時間等待帶來的不確定感。
- **九種介面語言**：預設跟隨系統，也可選擇支援的語言，讓不同地區的使用者更容易使用。
- **適合現代 Android 裝置**：針對 Android 17 設計，專注於 64 位元 ARM 裝置，支援現代 Android 的全螢幕配置與返回手勢。

## 可以做什麼

- 掃描 QR Code 或輸入啟用碼，下載新的 eSIM 方案。
- 查看已安裝的方案，啟用、停用或切換使用中的方案。
- 重新命名方案、刪除不再需要的方案，整理你的 eSIM 清單。
- 查看卡片資訊、檢查裝置相容性，並透過相容的 USB CCID 讀卡機管理卡片。

## 支援的語言

英語、簡體中文、繁體中文、日語、韓語、阿拉伯語、法語、德語和西班牙語。

系統語言不在支援範圍內時，介面使用英文。

## 下載與使用

目前版本：**1.1.2**。前往 [下載頁面](https://github.com/Stickmin522/FluxEUICC/releases/latest) 取得 APK。

1. 在 Android 9 或更新版本的 64 位元 ARM 裝置上安裝應用程式。
2. 插入相容於 OpenEUICC 的可拆卸 eSIM，或連接相容的 USB 讀卡機。
3. 手機卡槽中的卡片須授權 FluxEUICC 的簽章憑證；可在應用程式設定中查看並複製授權所需的指紋，詳細步驟請參閱發行頁面的使用說明。
4. 新增你的方案，選擇要啟用的 eSIM。

可用功能取決於手機、卡片與讀卡機的相容性。方案切換後的網路恢復時間由卡片與手機系統決定。

## 開放原始碼與授權

FluxEUICC 基於 OpenEUICC，採用 [GPL-3.0-only 授權](LICENSE)，保留上游著作權聲明；相依元件的授權條款請參閱各自的目錄。

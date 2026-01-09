# Flux - Open Source V2Board Client

**Flux** 是一个完美适配 [V2Board](https://github.com/wyx2685/v2board) 的跨平台客户端。

我们致力于提供最简单、最流畅的对接体验。如果您正在运营 V2Board 面板，Flux 是您客户端的最佳选择。

---

##  核心优势

-   **极简对接**: 真的只需要**一步**！修改 API 地址即可直接使用，告别繁琐配置。
-   **全平台支持**: Android, iOS, Windows, macOS, Linux 全覆盖。
-   **开源透明**: 代码完全开源，安全可控，随时定制。

---

## 🚀 快速上手指南

只需三步，您就能拥有自己的客户端！

### 1. 下载代码

```bash
git clone https://github.com/flux-apphub/flux.git
cd flux
```

### 2. 替换 API 地址 (核心步骤)

打开文件夹 `lib` -> `services` -> `api_config.dart`。
找到下面的代码，把网址改成您自己的面板地址：

```dart
// lib/services/api_config.dart

Future<String> getBaseUrl() async {
  // 👇 只需要改这一行！
  // 例如您的面板是 https://v2board.com，那就填 https://v2board.com/api/v1
  // 注意：一定要保留后面的 /api/v1
  return 'https://您的面板域名.com/api/v1'; 
}
```

### 3. 修改 App ID (必看)

为了确保应用能正常安装且不与他人冲突，请务必在以下文件中将默认的 `com.example.yourapp` 替换为您自己的 App ID (包名)，例如 `com.yourname.project`：

*   **Android**:
    *   文件: `android/app/build.gradle.kts`
    *   修改项: `applicationId` 和 `namespace`
*   **iOS**:
    *   文件: `ios/Runner.xcodeproj/project.pbxproj`
    *   修改项: `PRODUCT_BUNDLE_IDENTIFIER` (建议搜索并全部替换)
*   **macOS**:
    *   文件: `macos/Runner/Configs/AppInfo.xcconfig`
    *   修改项: `PRODUCT_BUNDLE_IDENTIFIER`
*   **Linux**:
    *   文件: `linux/CMakeLists.txt`
    *   修改项: `APPLICATION_ID`
*   **Windows (MSIX打包配置)**:
    *   文件: `pubspec.yaml`
    *   修改项: `msix_config` 下的 `identity_name`

### 4. 开始打包

确保您已安装 Flutter 运行环境。

-   **Android (生成 APK)**:
    ```bash
    flutter build apk --release
    ```
    *产物路径: `build/app/outputs/flutter-apk/app-release.apk`*

-   **iOS (生成 IPA)**:
    ```bash
    flutter build ipa
    ```
    *注意: 需要 macOS 环境及 Apple 开发者账号签名。*
    *产物路径: `build/ios/archive/Runner.xcarchive`*

-   **Windows (生成 exe)**:
    ```bash
    flutter build windows
    ```
    *产物路径: `build/windows/runner/Release/`*

-   **macOS (生成 app)**:
    ```bash
    flutter build macos
    ```
    *产物路径: `build/macos/Build/Products/Release/flux.app`*

-   **Linux (生成可执行文件)**:
    ```bash
    flutter build linux
    ```
    *产物路径: `build/linux/x64/release/bundle/`*

---

## ☕ 请我喝杯咖啡

如果这个项目对您有帮助，欢迎请作者喝杯咖啡，支持开源开发！

| BNB Chain | Arbitrum | Ethereum |
| :---: | :---: | :---: |
| <img src="assets/images/donation/bnb.png" width="200" alt="BNB"> | <img src="assets/images/donation/arbitrum.png" width="200" alt="Arbitrum"> | <img src="assets/images/donation/eth.png" width="200" alt="Ethereum"> |

---

## 📞 定制与商业支持

如果您需要：
-   🔥 **修改 App 名称和 Logo**
-   🎨 **定制专属 UI 主题**
-   🚀 **增加高级功能**
-   🛠️ **全套上架服务 (Play Store / App Store)**

请通过 Telegram 联系我：👉 **[@xiaoxiaonihaoya](https://t.me/xiaoxiaonihaoya)**

---

## 🔗 相关项目

-   [V2Board](https://github.com/v2board/v2board): 强大的 V2Ray 面板。

---

**Flux Open Source** - Make Connection Simple.

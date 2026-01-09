# Flux - Open Source V2Board Client

**Flux** 是一个完美适配 [V2Board](https://github.com/wyx2685/v2board) 的跨平台客户端。

我们致力于提供最简单、最流畅的对接体验。如果您正在运营 V2Board 面板，Flux 是您客户端的最佳选择。

---

## 📞 定制与商业支持

如果您需要：
-   🔥 **修改 App 名称和 Logo**
-   🎨 **定制专属 UI 主题**
-   🚀 **增加高级功能**


请通过 Telegram 联系我：👉 **[@xiaoxiaonihaoya](https://t.me/xiaoxiaonihaoya)**

---

## 📱 界面预览

### 📱 App 版本

| | | |
| :---: | :---: | :---: |
| <img src="assets/images/screenshots/1.png" width="200"> | <img src="assets/images/screenshots/2.png" width="200"> | <img src="assets/images/screenshots/3.png" width="200"> |
| <img src="assets/images/screenshots/4.png" width="200"> | <img src="assets/images/screenshots/5.png" width="200"> | |

### 💻 桌面版本

| | |
| :---: | :---: |
| <img src="assets/images/screenshots/6.png" width="200"> | <img src="assets/images/screenshots/7.png" width="200"> |
| <img src="assets/images/screenshots/8.png" width="200"> | <img src="assets/images/screenshots/9.png" width="200"> |

---

## 🎉 核心优势

-   **极简对接**: 真的只需要**一步**！修改 API 地址即可直接使用，告别繁琐配置。
-   **多种协议**: 支持 VLESS, VMess, Trojan, Shadowsocks。
-   **全平台支持**: Android, iOS, Windows, macOS, Linux 全覆盖。
-   **开源透明**: 代码完全开源，安全可控，随时定制。

---

## 🔧 技术原理 & 内核揭秘

Flux 不仅仅是一个简单的 UI 壳，它底层集成了强大的路由核心，确保了跨平台的稳定连接。

### 1. 核心架构 (Core Architecture)

*   **UI 层**: 基于 **Flutter** 构建，一套代码适配 5 端，保证了视觉和交互的高度统一。
*   **逻辑层**: 通过 `UnifiedVpnService` 统一调度，根据当前运行平台自动选择最佳的流量接管方式。
*   **内核层**: 内置 **V2Ray / Xray Core**，它是流量处理的心脏，负责协议封装、加密和路由分流。

### 2. 流量转发原理 (Traffic Forwarding)

Flux 在不同平台上采用了最原生的系统级方案来接管网络流量，做到"无感"和"高效"：

#### 🤖 Android 端
*   **机制**: 使用 Android 原生 **`VpnService`** API。
*   **原理**: App 会创建一个虚拟网卡 (TUN Interface)，系统将所有网络请求转发给这个虚拟网卡。底层通过 **JNI** 调用 C++ 编写的路由核心，将流量拦截并进行规则判断，随后通过加密通道发送至服务器。
*   **优势**: 全局代理能力强，不依赖 Root 权限。

#### 🍎 iOS 端
*   **机制**: 使用 Apple **`NetworkExtension` (Packet Tunnel Provider)** 框架。
*   **原理**: 利用 iOS 系统的沙盒机制，启动一个独立的 VPN 进程 (`PacketTunnelProvider.swift`)。该进程与主 App 隔离，负责在后台持续运行核心转发服务，即使主 App 关闭也能保持连接。
*   **优势**: 极致省电，符合 App Store 上架规范。

#### 💻 桌面端 (Windows / macOS / Linux)
*   **机制**: **System Proxy (系统代理)** + **Sidecar (伴生进程)**。
*   **原理**:
    1.  Flux 启动时，会在后台静默启动一个 V2Ray/Xray 内核进程 (Sidecar)。
    2.  App 自动修改操作系统的 **系统代理设置** (HTTP/SOCKS5)，指向本地内核监听端口 (如 `127.0.0.1:10808`)。
    3.  所有浏览器和支持系统代理的应用流量会自动流向内核。
*   **优势**: 兼容性好，不干扰系统底层驱动。

### 3. 协议支持 (Supported Protocols)

得益于 Xray Core 的强大能力，Flux 支持当今主流的抗审查协议：

*   **VLESS**: 支持 `TCP`, `WS`, `TLS`, `REALITY`, `gRPC` 等多种传输组合。
*   **VMess**: 经典协议支持，兼容 `TCP`, `WS`, `TLS`, `Auto` 安全模式。
*   **Trojan**: 完整的 Trojan 协议支持，包括 `Trojan-Go` 特性兼容。
*   **Shadowsocks**: 支持标准 SS 协议 (AEAD Ciphers)。

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

## 🔗 相关项目

-   [V2Board](https://github.com/wyx2685/v2board): 强大的 V2Ray 面板。

---

**Flux Open Source** - Make Connection Simple.

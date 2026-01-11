# Flux - Ultimate Multi-Platform V2ray Client

<div align="center">

   <h1>Flux</h1>
  <p>
    <strong>Next-Gen V2ray Client for Android, Windows, Linux & macOS</strong>
  </p>
  <p>
    一个兼具极简美学与强大功能的现代化全平台代理客户端。
    <br />
    <a href="#功能特性">功能特性</a> • 
    <a href="#使用指南">使用指南</a> •
    <a href="#构建与安装">构建与安装</a> •
    <a href="#常见问题">常见问题</a>
  </p>
</div>

---

## 📖 关于 Flux (Introduction)

Flux 是一款专为追求极致体验用户打造的下一代跨平台代理客户端。我们摒弃了传统 VPN 软件繁杂的界面，采用 **玻璃拟物化 (Glassmorphism)** 设计语言，将强大的 v2ray/xray 内核封装在极简优雅的 UI 之下。

### 核心设计理念
*   **极致美学**: 全应用采用高级黑金/银灰配色，搭配深度优化的磨砂玻璃质感。
*   **隐形守护**: 零日志记录，端到端加密。
*   **性能至上**: 底层基于 Flutter + Go (xray-core) 混合架构，提供原生级的网络性能。

---

## 📚 使用指南 (User Guide)

### 1. 快速连接
Flux 的设计哲学是“即开即用”。
*   **一键连接**: 打开应用，点击主界面的硕大电源按钮即可。
*   **智能状态**: 按钮光环颜色代表不同状态——<span style="color:#FFB347">黄色呼吸</span>为连接中，<span style="color:#6CFFB8">青色常亮</span>为已保护，<span style="color:#6F7A8C">灰色</span>为断开。

### 2. 账号与订阅
在“我的”页面管理您的服务状态：
*   **订阅同步**: 支持 V2Board 面板一键登录，自动拉取最新的节点列表。
*   **流量监控**: 包含精确的流量进度条，直观展示已用/剩余流量。

### 3. 桌面端特性 (Windows/Linux/macOS)
*   **系统托盘**: 关闭主窗口后，Flux 会自动最小化到系统托盘，保持后台静默运行。
*   **右键菜单**: 在托盘图标上右键，可快速执行“连接”、“断开”或“彻底退出”操作。
*   **开机自启**: 支持跟随系统启动并自动连接。

---

## 🛠️ 构建与安装 (Build & Install)

### 1. 环境准备
*   Flutter SDK >= 3.10.0
*   **Windows**: Visual Studio 2022 (包含 C++ 桌面开发工作负载)
*   **Android**: Android Studio, NDK

### 2. 克隆代码
```bash
git clone https://github.com/zhaiqc/flux.git
cd flux
# 获取依赖
flutter pub get
```

### 3. 构建 Windows 版
Flux 支持生成 Windows 标准安装包 (.msix) 和绿色免安装版 (.exe)。

#### A. 生成安装包 (推荐)
这将生成一个 `.msix` 安装文件，支持自动更新和卸载。
```powershell
# 生成 MSIX 安装包
dart run msix:create
```
*   **产出位置**: `build/windows/x64/runner/Release/Flux VPN_1.0.0.0_x64_Test.msix`
*   **安装方法**: 双击该文件即可安装。

#### B. 生成绿色版
```powershell
flutter build windows --release
```
*   **产出位置**: `build/windows/x64/runner/Release/`
*   该目录下包含 `flux.exe` 和所有依赖文件，拷贝整个文件夹即可运行。

### 4. 构建 Android 版
构建适用于现代安卓设备的发布包：
```bash
flutter build apk --target-platform android-arm64 --release
```
*   **产出位置**: `build/app/outputs/flutter-apk/app-release.apk`

---

## ❓ 常见问题 (FAQ)

### Q: Windows 安装时提示 "此应用包没有受信任的证书" (0x800B0109)
**原因**: 开发阶段使用的是自生成的测试证书，Windows 默认不信任。

**解决方法**:

**方法一：开启开发者模式 (最简单)**
1.  打开 Windows 设置 -> **更新和安全** -> **开发者选项**。
2.  开启 "**开发人员模式**"。
3.  直接双击 `.msix` 文件即可正常安装。

**方法二：安装证书**
1.  以**管理员身份**运行项目根目录下的脚本：
    ```powershell
    ./install_cert.ps1
    ```
2.  或者手动安装：
    *   右键 `.msix` 文件 -> 属性 -> 数字签名 -> 详细信息 -> 查看证书 -> 安装证书。
    *   存储位置选择 "**本地计算机**"。
    *   证书存储选择 "**受信任的根证书颁发机构**"。

### Q: 运行 Windows 版时找不到 xray 可执行文件？
请确保构建命令执行完整。如果在 IDE 中直接运行，请先执行 `flutter clean` 清理缓存。构建脚本会自动将 `assets/bin/xray-windows-amd64.exe` 和 `xray-windows-arm64.exe` 复制到构建目录。

### Q: 托盘图标不显示？
Flux 依赖 `assets/icons/app_icon.ico`。如果自行构建，请确保不要删除 `assets` 目录下的资源文件。

---

## 📄 许可证
MIT License

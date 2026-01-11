package com.example.yourapp

import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import libv2ray.Libv2ray
import libv2ray.CoreController
import libv2ray.CoreCallbackHandler
import org.json.JSONObject
import java.io.File
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.yourapp/v2ray"
    private val STATUS_CHANNEL = "com.example.yourapp/v2ray_status"
    private var isV2rayRunning = false
    private var coreController: CoreController? = null
    private var isInitialized = false
    private var isGeoDataReady = false
    
    companion object {
        private const val TAG = "Flux"
        private const val REQUEST_VPN_PERMISSION = 1
        @Volatile
        private var vpnStatusSink: EventChannel.EventSink? = null
        @Volatile
        private var coreControllerRef: CoreController? = null
        @Volatile
        private var isCoreRunning: Boolean = false
        private val mainHandler = Handler(Looper.getMainLooper())

        @JvmStatic
        fun emitVpnStatus(isConnected: Boolean) {
            mainHandler.post {
                vpnStatusSink?.success(isConnected)
            }
        }

        @JvmStatic
        fun stopCoreFromService() {
            try {
                coreControllerRef?.stopLoop()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop core from service: ${e.message}")
            } finally {
                coreControllerRef = null
                isCoreRunning = false
            }
        }
    }
    
    // 实现回调处理器
    private val callbackHandler = object : CoreCallbackHandler {
        override fun onEmitStatus(status: Long, message: String?): Long {
            // Xray 核心日志输出（非常重要！）
            Log.i(TAG, "Xray Status: $status, Message: $message")
            // 如果 message 不为空，使用详细日志级别输出
            if (message != null && message.isNotEmpty()) {
                Log.d(TAG, "Xray Detailed: $message")
            }
            return 0
        }
        
        override fun startup(): Long {
            Log.i(TAG, "Xray core startup callback - Core started successfully")
            return 0
        }
        
        override fun shutdown(): Long {
            Log.i(TAG, "Xray core shutdown callback - Core stopped")
            return 0
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val configJson = call.argument<String>("config")
                    if (configJson == null) {
                        result.error("INVALID_ARGUMENT", "Config is null", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val success = connectV2ray(configJson)
                            mainHandler.post { result.success(success) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("CONNECTION_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "disconnect" -> {
                    Thread {
                        try {
                            disconnectV2ray()
                            mainHandler.post { result.success(true) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("DISCONNECT_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "isConnected" -> {
                    result.success(FluxVpnService.isVpnRunning)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STATUS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    vpnStatusSink = events
                    events?.success(FluxVpnService.isVpnRunning)
                }

                override fun onCancel(arguments: Any?) {
                    vpnStatusSink = null
                }
            })
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // 使用 core-splashscreen 库的 installSplashScreen()
        // 必须在 super.onCreate() 之前调用
        val splashScreen = installSplashScreen()
        
        // 立即结束 splash screen，不显示图标
        splashScreen.setKeepOnScreenCondition { false }
        
        // 设置窗口背景为纯黑
        window.setBackgroundDrawableResource(android.R.color.black)
        
        super.onCreate(savedInstanceState)

        // 隐藏系统UI
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or View.SYSTEM_UI_FLAG_FULLSCREEN
        )
        
        // 确保窗口背景使用纯黑色
        window.statusBarColor = android.graphics.Color.BLACK
        window.navigationBarColor = android.graphics.Color.BLACK
        
        Log.d(TAG, "MainActivity onCreate completed")
    }

    override fun onDestroy() {
        super.onDestroy()
        disconnectV2ray()
    }

    /**
     * 初始化 Xray 内核环境
     * 注意：根据错误信息，第二个参数被当作 basekey（32字节），所以暂时不调用 initCoreEnv
     * 如果需要初始化，可能需要传入正确的 basekey 或使用其他方式
     */
    private fun initXray() {
        if (isInitialized) return
        
        try {
            // 确保 dat 文件存在（从 AAR assets 复制到文件目录）
            val datDir = filesDir.absolutePath
            
            // 复制 geoip.dat 和 geosite.dat 到文件目录（如果不存在）
            copyAssetIfNeeded("geoip.dat", datDir)
            copyAssetIfNeeded("geosite.dat", datDir)
            
            // 初始化核心环境，提供 geosite/geoip 资源位置
            try {
                // 不设置 xudp basekey，避免 Xray 对 basekey 格式严格校验导致崩溃
                Libv2ray.initCoreEnv(datDir, "")
                isGeoDataReady = true
                Log.d(TAG, "Libv2ray core env initialized, datDir: $datDir")
            } catch (e: Exception) {
                isGeoDataReady = false
                Log.e(TAG, "Libv2ray initCoreEnv failed: ${e.message}")
            }

            isInitialized = true
            Log.d(TAG, "Dat 文件准备完成, datDir: $datDir")
        } catch (e: Exception) {
            Log.e(TAG, "初始化失败: ${e.message}")
            e.printStackTrace()
        }
    }
    
    /**
     * 从 assets 复制文件到指定目录（如果文件不存在）
     */
    private fun copyAssetIfNeeded(filename: String, targetDir: String) {
        val targetFile = File(targetDir, filename)
        if (targetFile.exists()) {
            Log.d(TAG, "$filename already exists")
            return
        }
        
        try {
            assets.open(filename).use { input ->
                targetFile.outputStream().use { output ->
                    input.copyTo(output)
                    Log.d(TAG, "Copied $filename to $targetDir")
                }
            }
        } catch (e: Exception) {
            // 如果 assets 中没有文件，尝试从 AAR 中获取（AAR 会自动处理）
            Log.w(TAG, "Could not copy $filename from assets: ${e.message}")
        }
    }

    private fun connectV2ray(outboundConfigJson: String): Boolean {
        return try {
            Log.d(TAG, "Connecting v2ray with config: $outboundConfigJson")
            
            // 确保 dat 文件已准备
            if (!isInitialized) {
                initXray()
            }
            
            // 先停止现有的连接
            if (isV2rayRunning) {
                disconnectV2ray()
            }

            // 构建完整的V2ray配置
            val outboundConfig = JSONObject(outboundConfigJson)
            val fullConfig = buildV2rayConfig(outboundConfig)
            
            Log.d(TAG, "Full v2ray config: $fullConfig")

            // 先启动 Xray 核心（SOCKS 代理）
            startXrayCore(fullConfig)
            
            // 等待 Xray 核心启动
            Thread.sleep(500)
            
            // 请求 VPN 权限并启动 VPN 服务
            requestVpnPermission()
            
            isV2rayRunning
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting v2ray: ${e.message}")
            e.printStackTrace()
            false
        }
    }
    
    /**
     * 启动 Xray 核心
     * @param configContent Xray 的完整 JSON 配置文件内容
     */
    private fun startXrayCore(configContent: String) {
        try {
            Log.i(TAG, "========== 准备启动 Xray 核心 ==========")
            Log.i(TAG, "完整配置 JSON:\n$configContent")
            Log.i(TAG, "========================================")
            
            // 1. 创建核心控制器
            val controller = Libv2ray.newCoreController(callbackHandler)
            coreController = controller
            coreControllerRef = controller
            
            // 2. 启动核心（传入完整配置 JSON 字符串）
            // 注意：startLoop 会在后台线程中阻塞运行，所以需要在独立线程中调用
            Thread {
                try {
                    Log.d(TAG, "Xray 核心线程启动，开始调用 startLoop...")
                    controller.startLoop(configContent)
                    Log.i(TAG, "Xray 核心启动成功（startLoop 返回）")
                    isV2rayRunning = true
                    isCoreRunning = true
                } catch (e: Exception) {
                    Log.e(TAG, "Xray 核心启动失败: ${e.message}", e)
                    e.printStackTrace()
                    isV2rayRunning = false
                    isCoreRunning = false
                }
            }.start()
            
            // 等待一下让线程启动
            Thread.sleep(500)
            
            // 检查是否成功启动
            val isRunning = coreController?.isRunning == true
            if (isRunning) {
                isV2rayRunning = true
                isCoreRunning = true
                Log.i(TAG, "Xray 核心状态检查：运行中")
            } else {
                Log.w(TAG, "Xray 核心状态检查：未运行（可能还在启动中）")
                // 即使状态检查失败，也标记为运行中，因为 startLoop 是阻塞的，如果启动失败会抛出异常
                isV2rayRunning = true
                isCoreRunning = true
            }
        } catch (e: Exception) {
            Log.e(TAG, "启动 Xray 核心异常: ${e.message}", e)
            e.printStackTrace()
            isV2rayRunning = false
            isCoreRunning = false
            coreController = null
            coreControllerRef = null
        }
    }

    private fun disconnectV2ray() {
        if (isV2rayRunning || coreController != null) {
            try {
                Log.d(TAG, "Stopping v2ray...")
                
                // 先停止 VPN 服务
                stopVpnService()
                
                // 再停止 Xray 核心
                stopXrayCore()
                
                isV2rayRunning = false
                Log.d(TAG, "V2ray stopped")
            } catch (e: Exception) {
                Log.e(TAG, "Error disconnecting v2ray: ${e.message}")
                e.printStackTrace()
                isV2rayRunning = false
                coreController = null
            }
        }
    }
    
    /**
     * 停止 Xray 核心
     */
    private fun stopXrayCore() {
        try {
            coreController?.stopLoop()
            coreController = null
            coreControllerRef = null
            isCoreRunning = false
            Log.d(TAG, "内核已停止")
        } catch (e: Exception) {
            Log.e(TAG, "停止内核异常: ${e.message}")
            e.printStackTrace()
            coreController = null
            coreControllerRef = null
            isCoreRunning = false
        }
    }
    
    /**
     * 请求 VPN 权限
     */
    private fun requestVpnPermission() {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            // 需要用户授权
            Log.d(TAG, "Requesting VPN permission")
            startActivityForResult(intent, REQUEST_VPN_PERMISSION)
        } else {
            // 已有权限，直接启动 VPN
            Log.d(TAG, "VPN permission already granted")
            startVpnService()
        }
    }
    
    /**
     * 处理 Activity 结果（VPN 权限请求结果）
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_VPN_PERMISSION) {
            if (resultCode == RESULT_OK) {
                Log.d(TAG, "VPN permission granted")
                // 权限授予后，启动 VPN 服务
                startVpnService()
            } else {
                Log.e(TAG, "VPN permission denied")
            }
        }
    }
    
    /**
     * 启动 VPN 服务
     */
    private fun startVpnService() {
        try {
            val intent = Intent(this, FluxVpnService::class.java).apply {
                action = FluxVpnService.ACTION_START
            }
            startService(intent)
            Log.d(TAG, "VPN service started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting VPN service: ${e.message}")
            e.printStackTrace()
        }
    }
    
    /**
     * 停止 VPN 服务
     */
    private fun stopVpnService() {
        try {
            val intent = Intent(this, FluxVpnService::class.java).apply {
                action = FluxVpnService.ACTION_STOP
            }
            // 先发送停止指令，确保 onStartCommand 能处理 ACTION_STOP
            startService(intent)
            // 再调用 stopService，确保服务被销毁
            stopService(intent)
            Log.d(TAG, "VPN service stop requested")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping VPN service: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun buildV2rayConfig(outbound: JSONObject): String {
        val config = JSONObject()
        
        // 验证并确保 outbound 的 streamSettings 正确（特别是 Trojan 协议）
        ensureStreamSettings(outbound)
        
        // Log配置
        val log = JSONObject()
        log.put("loglevel", "debug")
        config.put("log", log)
        
        // DNS配置（用于域名解析）
        // 使用多个 DNS 服务器，包括 localhost 用于本地解析
        val dns = JSONObject()
        dns.put("servers", org.json.JSONArray().apply {
            put("223.5.5.5") // AliDNS
            put("119.29.29.29") // DNSPod
            put("1.1.1.1")
            put("localhost")  // 本地 DNS，用于解析被代理的域名
        })
        config.put("dns", dns)
        
        // Inbounds配置（SOCKS代理和 TUN 模式）
        val inbounds = org.json.JSONArray()
        
        // SOCKS 代理（用于 VPN 流量转发）
        val socksInbound = JSONObject()
        socksInbound.put("port", 10808)
        socksInbound.put("listen", "127.0.0.1")
        socksInbound.put("protocol", "socks")
        val socksSettings = JSONObject()
        socksSettings.put("auth", "noauth")  // 无需认证
        socksSettings.put("udp", true)  // 必须为 true，支持 UDP
        socksSettings.put("ip", "127.0.0.1")
        socksInbound.put("settings", socksSettings)
        
        // 启用流量嗅探（用于域名解析）
        val sniffing = JSONObject()
        sniffing.put("enabled", true)
        val destOverride = org.json.JSONArray()
        destOverride.put("http")
        destOverride.put("tls")
        sniffing.put("destOverride", destOverride)
        socksInbound.put("sniffing", sniffing)
        
        inbounds.put(socksInbound)
        
        config.put("inbounds", inbounds)
        
        // Routing配置（路由规则）
        // 重要：添加 DNS 路由规则，避免 DNS 请求循环
        val routing = JSONObject()
        routing.put("domainStrategy", "IPIfNonMatch")
        
        val routingRules = org.json.JSONArray()
        // DNS 流量路由规则（确保 DNS 请求走代理）
        val dnsRule = JSONObject()
        dnsRule.put("type", "field")
        dnsRule.put("port", 53)
        dnsRule.put("network", "udp")
        dnsRule.put("outboundTag", "proxy")  // 让 DNS 走代理（第一个 outbound）
        routingRules.put(dnsRule)

        if (isGeoDataReady) {
            // 直连规则（geosite/geoip 分流）
            val directDomainRule = JSONObject()
            directDomainRule.put("type", "field")
            directDomainRule.put(
                "domain",
                org.json.JSONArray().apply {
                    put("geosite:cn")
                    put("geosite:private")
                }
            )
            directDomainRule.put("outboundTag", "direct")
            routingRules.put(directDomainRule)

            val directIpRule = JSONObject()
            directIpRule.put("type", "field")
            directIpRule.put(
                "ip",
                org.json.JSONArray().apply {
                    put("geoip:cn")
                    put("geoip:private")
                }
            )
            directIpRule.put("outboundTag", "direct")
            routingRules.put(directIpRule)
        } else {
            Log.w(TAG, "Geo data not ready, skip geosite/geoip routing rules")
        }

        // 其他流量默认走代理（对齐 v2rayNG 常见分流行为）
        val proxyRule = JSONObject()
        proxyRule.put("type", "field")
        proxyRule.put("network", "tcp,udp")
        proxyRule.put("outboundTag", "proxy")
        routingRules.put(proxyRule)
        
        routing.put("rules", routingRules)
        config.put("routing", routing)
        
        // Outbounds配置
        // 重要：顺序很重要！第一个 outbound 是默认出口，必须设置 tag
        val outbounds = org.json.JSONArray()
        
        // 确保 outbound 有 tag（如果没有则添加）
        if (!outbound.has("tag")) {
            outbound.put("tag", "proxy")
        }
        outbounds.put(outbound)  // 代理 outbound（第一个，作为默认）
        
        // 添加 direct outbound（直连，用于本地流量）
        val directOutbound = JSONObject()
        directOutbound.put("protocol", "freedom")
        directOutbound.put("tag", "direct")
        outbounds.put(directOutbound)
        config.put("outbounds", outbounds)
        
        return config.toString()
    }
    
    /**
     * 验证并确保 outbound 的 streamSettings 正确
     * 特别是 Trojan 协议必须使用 TLS
     */
    private fun ensureStreamSettings(outbound: JSONObject) {
        val protocol = outbound.optString("protocol", "")
        
        if (protocol == "trojan") {
            // Trojan 协议必须使用 TLS
            var streamSettings = outbound.optJSONObject("streamSettings")
            if (streamSettings == null) {
                streamSettings = JSONObject()
                outbound.put("streamSettings", streamSettings)
            }
            
            // 确保有 security: "tls"
            if (!streamSettings.has("security") || streamSettings.optString("security") != "tls") {
                streamSettings.put("security", "tls")
                Log.d(TAG, "修复 Trojan streamSettings: 添加 security=tls")
            }
            
            // 确保有 network: "tcp"
            if (!streamSettings.has("network")) {
                streamSettings.put("network", "tcp")
            }
            
            // 确保有 tlsSettings（即使为空也要有）
            var tlsSettings = streamSettings.optJSONObject("tlsSettings")
            if (tlsSettings == null) {
                tlsSettings = JSONObject()
                streamSettings.put("tlsSettings", tlsSettings)
                Log.d(TAG, "修复 Trojan streamSettings: 添加 tlsSettings")
            }
            
            // 如果没有 allowInsecure，根据情况添加（通常不需要，除非证书有问题）
            // 这里不自动添加，由用户配置决定
        }
    }

}

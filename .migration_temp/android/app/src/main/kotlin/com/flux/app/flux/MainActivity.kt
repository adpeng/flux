package com.flux.app.flux

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
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.BufferedReader
import java.io.InputStreamReader
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.flux.app/v2ray"
    private val STATUS_CHANNEL = "com.flux.app/v2ray_status"
    private var isV2rayRunning = false
    private var xrayProcess: Process? = null
    private var hysteria2Process: Process? = null
    private var currentProtocol: String = ""
    private var isInitialized = false
    private var isGeoDataReady = false
    
    companion object {
        private const val TAG = "Flux"
        private const val REQUEST_VPN_PERMISSION = 1
        @Volatile
        private var vpnStatusSink: EventChannel.EventSink? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        @JvmStatic
        fun emitVpnStatus(isConnected: Boolean) {
            mainHandler.post {
                vpnStatusSink?.success(isConnected)
            }
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
        val splashScreen = installSplashScreen()
        splashScreen.setKeepOnScreenCondition { false }
        window.setBackgroundDrawableResource(android.R.color.black)
        
        super.onCreate(savedInstanceState)

        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or View.SYSTEM_UI_FLAG_FULLSCREEN
        )
        
        window.statusBarColor = android.graphics.Color.BLACK
        window.navigationBarColor = android.graphics.Color.BLACK
    }

    override fun onDestroy() {
        super.onDestroy()
        disconnectV2ray()
    }

    /**
     * 获取 Xray 可执行文件路径
     * 1. 尝试从 nativeLibraryDir 获取 (libxray.so)
     * 2. 如果失败，尝试从 Assets 复制到 filesDir 并赋予执行权限
     */
    private fun getXrayExecutable(): String? {
        // 1. 尝试从 nativeLibraryDir 查找
        val libDir = applicationInfo.nativeLibraryDir
        val libFile = File(libDir, "libxray.so")
        if (libFile.exists()) {
            Log.d(TAG, "Found Xray in nativeLibraryDir: ${libFile.absolutePath}")
            return libFile.absolutePath
        }

        // 2. 尝试查找含有 xray 的文件 (针对 weird naming)
        val dir = File(libDir)
        val files = dir.listFiles { _, name -> name.contains("xray") }
        if (files != null && files.isNotEmpty()) {
            Log.d(TAG, "Found Xray (fuzzy) in nativeLibraryDir: ${files[0].absolutePath}")
            return files[0].absolutePath
        }

        // 3. 都没有，尝试从 Assets 复制到 filesDir
        Log.w(TAG, "Xray not found in nativeLibraryDir, trying to copy from assets...")
        val internalBin = File(filesDir, "libxray.so")
        
        // 尝试从 assets 复制 "libxray.so" (Flutter assets mapping needed? No, binary stays in Android assets/libs)
        // 注意：这里需要确保 binary 确实在 android assets 里。
        // 由于用户说 assets/bin 是 Flutter assets，所以 binary 必须通过 nativeLibraryDir 找到最稳。
        // 这里保留 fallback 逻辑，假设用户手动放了 assets
        if (copyBinaryFromAssets("libxray.so", internalBin)) {
             return internalBin.absolutePath
        }
        
        if (copyBinaryFromAssets("xray-android-arm64-v8a", internalBin)) {
             return internalBin.absolutePath
        }

        Log.e(TAG, "Xray binary not found in libs or assets!")
        return null
    }

    private fun copyBinaryFromAssets(assetName: String, targetFile: File): Boolean {
        try {
            assets.open(assetName).use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
            if (!targetFile.setExecutable(true, true)) {
                Runtime.getRuntime().exec("chmod 700 ${targetFile.absolutePath}").waitFor()
            }
            return true
        } catch (e: Exception) {
            return false
        }
    }

    private fun connectV2ray(outboundConfigJson: String): Boolean {
        return try {
            // dat files are now handled by Flutter side (AssetUtils)
            if (isV2rayRunning) {
                disconnectV2ray()
                // 关键修复：增加等待时间确保旧进程完全退出且端口(10808)释放
                // 否则切换协议时会因为端口被占用而启动失败
                Thread.sleep(500)
            }

            val outboundConfig = JSONObject(outboundConfigJson)
            val protocol = outboundConfig.optString("protocol", "")
            currentProtocol = protocol
            
            Log.d(TAG, "Connecting with protocol: $protocol")
            
            // 检查是否为 Hysteria2 协议
            if (protocol == "hysteria2" || protocol == "hy2") {
                return connectHysteria2(outboundConfig)
            }
            
            // 其他协议使用 Xray
            return connectXray(outboundConfig)

        } catch (e: Exception) {
            Log.e(TAG, "Error connecting: ${e.message}")
            e.printStackTrace()
            false
        }
    }
    
    /**
     * 获取 Hysteria2 可执行文件路径
     */
    private fun getHysteria2Executable(): String? {
        // 1. 尝试从 nativeLibraryDir 查找 (libhysteria2.so)
        val libDir = applicationInfo.nativeLibraryDir
        val libFile = File(libDir, "libhysteria2.so")
        if (libFile.exists()) {
            Log.d(TAG, "Found Hysteria2 in nativeLibraryDir: ${libFile.absolutePath}")
            return libFile.absolutePath
        }
        
        // 2. 如果没找到，尝试从 Assets 复制
        val targetFile = File(filesDir, "hysteria2")
        // 如果文件不存在或者大小为0，则复制
        if (!targetFile.exists() || targetFile.length() == 0L) {
            Log.d(TAG, "Hysteria2 not found in libs, trying to copy from assets...")
            
            // 确定架构
            val abis = android.os.Build.SUPPORTED_ABIS
            var assetName = ""
            
            for (abi in abis) {
                when (abi) {
                    "arm64-v8a" -> assetName = "flutter_assets/assets/bin/hysteria-android-arm64"
                    "armeabi-v7a" -> assetName = "flutter_assets/assets/bin/hysteria-android-armv7"
                    "x86_64" -> assetName = "flutter_assets/assets/bin/hysteria-android-amd64"
                    "x86" -> assetName = "flutter_assets/assets/bin/hysteria-android-386"
                }
                if (assetName.isNotEmpty()) break
            }
            
            if (assetName.isEmpty()) {
                Log.e(TAG, "Unsupported architecture: ${abis.joinToString()}")
                return null
            }
            
            Log.d(TAG, "Detected architecture, copying $assetName")
            if (copyBinaryFromAssets(assetName, targetFile)) {
                return targetFile.absolutePath
            } else {
                Log.e(TAG, "Failed to copy Hysteria2 from assets")
                return null
            }
        } else {
            // 文件已存在，直接返回
             return targetFile.absolutePath
        }
    }
    
    /**
     * 生成 Hysteria2 原生配置
     * 参考: https://v2.hysteria.network/zh/docs/advanced/Full-Client-Config/
     */
    private fun buildHysteria2Config(outbound: JSONObject): String {
        val settings = outbound.optJSONObject("settings") ?: JSONObject()
        val config = JSONObject()
        
        // 服务器地址
        // 注意：v2rayNG 日志显示它支持端口范围，例如 host:port-port
        // 这里我们直接使用传递进来的 address 和 port
        val address = settings.optString("address", "")
        val port = settings.optInt("port", 443)
        
        // 检查是否有 mport (多端口) 配置
        val mport = settings.optString("mport", "")
        if (mport.isNotEmpty()) {
             config.put("server", "$address:$mport")
        } else {
             config.put("server", "$address:$port")
        }
        
        // 验证密码
        val password = settings.optString("password", "")
        if (password.isNotEmpty()) {
            config.put("auth", password)
        }
        
        // TLS 配置
        val tls = JSONObject()
        val sni = settings.optString("sni", "")
        if (sni.isNotEmpty()) {
            tls.put("sni", sni)
        }
        val insecure = settings.optBoolean("insecure", false)
        if (insecure) {
            tls.put("insecure", true)
        }
        if (tls.length() > 0) {
            config.put("tls", tls)
        }
        
        // 混淆配置
        val obfs = settings.optJSONObject("obfs")
        if (obfs != null) {
            val obfsType = obfs.optString("type", "salamander")
            val obfsPassword = obfs.optString("password", "")
            if (obfsPassword.isNotEmpty()) {
                config.put("obfs", JSONObject()
                    .put("type", obfsType)
                    .put("salamander", JSONObject().put("password", obfsPassword))
                )
            }
        }
        
        // 传输配置 (用于端口跳跃)
        // v2rayNG 日志: "transport":{"type":"udp","udp":{"hopInterval":"30s"}}
        // 如果有 mport，通常也需要 transport 配置
        if (mport.isNotEmpty()) {
            config.put("transport", JSONObject()
                .put("type", "udp")
                .put("udp", JSONObject().put("hopInterval", "30s"))
            )
        }
        
        // 懒狗模式
        // v2rayNG 使用 lazy: true，因为它配置了 allowed/disallowed apps
        // 我们也配置了 disallowed (exclude self)，所以理论上也可以用 true
        // 但为了调试连接性，先保持 false，确保启动时就尝试连接
        config.put("lazy", false)
        
        // SOCKS5 代理
        config.put("socks5", JSONObject().put("listen", "127.0.0.1:10808"))
        
        // HTTP 代理
        config.put("http", JSONObject().put("listen", "127.0.0.1:10809"))
        
        return config.toString()
    }
    
    /**
     * 使用 Hysteria2 独立进程连接
     */
    private fun connectHysteria2(outboundConfig: JSONObject): Boolean {
        val executablePath = getHysteria2Executable()
        if (executablePath == null) {
            Log.e(TAG, "Hysteria2 binary not found!")
            return false
        }
        
        // 生成配置文件
        val configDir = filesDir.absolutePath
        val configFile = File(configDir, "hysteria2_config.json")
        val fullConfig = buildHysteria2Config(outboundConfig)
        
        Log.d(TAG, "Hysteria2 config: $fullConfig")
        
        FileOutputStream(configFile).use {
            it.write(fullConfig.toByteArray())
        }
        
        // 启动进程
        Log.d(TAG, "Starting Hysteria2 process: $executablePath")
        val pb = ProcessBuilder(
            executablePath,
            "--disable-update-check",
            "--config", configFile.absolutePath,
            "--log-level", "info",
            "client"
        )
        pb.directory(filesDir)
        
        hysteria2Process = pb.start()
        
        // 读取日志
        Thread {
            try {
                val reader = BufferedReader(InputStreamReader(hysteria2Process!!.inputStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    Log.d("Hysteria2", line ?: "")
                }
            } catch (e: Exception) {
                Log.d("Hysteria2", "Process output stream closed")
            }
        }.start()
        
        Thread {
            try {
                val reader = BufferedReader(InputStreamReader(hysteria2Process!!.errorStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    Log.e("Hysteria2", line ?: "")
                }
            } catch (e: Exception) {
                Log.d("Hysteria2", "Process error stream closed")
            }
        }.start()
        
        // 等待 Hysteria2 启动并建立连接
        // 非 lazy 模式下，Hysteria2 会立即连接服务器
        // 必须等待连接建立后再启动 VPN，否则 DNS 查询会被 VPN 拦截
        Log.d(TAG, "Waiting for Hysteria2 to establish connection...")
        Thread.sleep(2000)  // 等待 2 秒让 Hysteria2 完成 DNS 解析和连接
        
        if (hysteria2Process!!.isAlive) {
            Log.d(TAG, "Hysteria2 connection established, starting VPN service")
            isV2rayRunning = true
            requestVpnPermission()
            return true
        } else {
            Log.e(TAG, "Hysteria2 process died immediately")
            return false
        }
    }
    
    /**
     * 使用 Xray 连接（非 Hysteria2 协议）
     */
    private fun connectXray(outboundConfig: JSONObject): Boolean {
        // 1. 获取可执行文件
        val executablePath = getXrayExecutable()
        if (executablePath == null) {
            Log.e(TAG, "Xray binary not found!")
            return false
        }

        // 2. 生成配置文件
        val configDir = filesDir.absolutePath
        val configFile = File(configDir, "config.json")
        val fullConfig = buildV2rayConfig(outboundConfig)
        
        // 写入配置文件
        FileOutputStream(configFile).use { 
            it.write(fullConfig.toByteArray()) 
        }

        // 3. 启动进程
        Log.d(TAG, "Starting Xray process: $executablePath -c ${configFile.absolutePath}")
        val pb = ProcessBuilder(executablePath, "-c", configFile.absolutePath)
        pb.directory(filesDir)
        // 设置环境变量指向 dat 目录
        val env = pb.environment()
        env["xray.location.asset"] = configDir
        
        xrayProcess = pb.start()
        
        // 4. 读取日志（可选，防止 buffer 满）
        Thread {
            try {
                val reader = BufferedReader(InputStreamReader(xrayProcess!!.inputStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    Log.d("XrayCore", line ?: "")
                }
            } catch (e: Exception) {
                // Ignore exceptions when process is destroyed
                Log.d("XrayCore", "Process output stream closed")
            }
        }.start()
        
        Thread {
            try {
                val reader = BufferedReader(InputStreamReader(xrayProcess!!.errorStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    Log.e("XrayCore", line ?: "")
                }
            } catch (e: Exception) {
                // Ignore exceptions when process is destroyed
                 Log.d("XrayCore", "Process error stream closed")
            }
        }.start()

        // 等待启动
        Thread.sleep(500)
        
        if (xrayProcess!!.isAlive) {
            isV2rayRunning = true
            requestVpnPermission()
            return true
        } else {
            Log.e(TAG, "Xray process died immediately")
            return false
        }
    }

    private fun disconnectV2ray() {
        try {
            stopVpnService()
            
            // 停止 Xray 进程
            if (xrayProcess != null) {
                xrayProcess!!.destroy()
                xrayProcess = null
            }
            
            // 停止 Hysteria2 进程
            if (hysteria2Process != null) {
                hysteria2Process!!.destroy()
                hysteria2Process = null
            }
            
            isV2rayRunning = false
            currentProtocol = ""
        } catch (e: Exception) {
            Log.e(TAG, "Error disconnecting: ${e.message}")
        }
    }

    private fun requestVpnPermission() {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            startActivityForResult(intent, REQUEST_VPN_PERMISSION)
        } else {
            startVpnService()
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_VPN_PERMISSION && resultCode == RESULT_OK) {
            startVpnService()
        }
    }
    
    private fun startVpnService() {
        try {
            val intent = Intent(this, FluxVpnService::class.java).apply {
                action = FluxVpnService.ACTION_START
            }
            startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting VPN service: ${e.message}")
        }
    }
    
    private fun stopVpnService() {
        try {
            val intent = Intent(this, FluxVpnService::class.java).apply {
                action = FluxVpnService.ACTION_STOP
            }
            startService(intent)
            stopService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping VPN service: ${e.message}")
        }
    }

    private fun buildV2rayConfig(outbound: JSONObject): String {
        val config = JSONObject()
        ensureStreamSettings(outbound)
        
        // 1. Log
        val log = JSONObject().put("loglevel", "debug")
        config.put("log", log)
        
        // 2. Stats (Required for traffic monitoring)
        config.put("stats", JSONObject())
        
        // 3. Policy (Handshake & Timeout)
        val policy = JSONObject()
        val levels = JSONObject().put("0", JSONObject()
            .put("handshake", 4)
            .put("connIdle", 300)
            .put("uplinkOnly", 2)
            .put("downlinkOnly", 5)
            .put("statsUserUplink", true)
            .put("statsUserDownlink", true)
            .put("bufferSize", 4)
        )
        val system = JSONObject()
            .put("statsInboundUplink", true)
            .put("statsInboundDownlink", true)
            .put("statsOutboundUplink", true)
            .put("statsOutboundDownlink", true)
        
        policy.put("levels", levels)
        policy.put("system", system)
        config.put("policy", policy)
        
        // 4. DNS (Split DNS: Domestic -> Direct, Foreign -> Proxy)
        val dns = JSONObject()
        dns.put("queryStrategy", "UseIPv4") // 强制使用 IPv4，避免 IPv6 导致连接问题
        val dnsServers = org.json.JSONArray()
        
        // Domestic (AliDNS) with geosite:cn and geoip:cn
        val domesticDns = JSONObject()
        domesticDns.put("address", "223.5.5.5")
        
        val domesticDomains = org.json.JSONArray()
        domesticDomains.put("geosite:cn")
        
        // Add Server Address to Domestic DNS to ensure it resolves
        val settings = outbound.optJSONObject("settings")
        if (settings != null && settings.has("address")) {
            val serverAddress = settings.getString("address")
            if (serverAddress.isNotEmpty()) {
                domesticDomains.put(serverAddress)
                Log.d(TAG, "Added server address to domestic DNS: $serverAddress")
            }
        }
        
        domesticDns.put("domains", domesticDomains)
        domesticDns.put("expectIPs", org.json.JSONArray().put("geoip:cn"))
        dnsServers.put(domesticDns)

        // Foreign (Google) - fallback
        dnsServers.put("8.8.8.8")
        dnsServers.put("1.1.1.1")
        
        // Localhost for system resolver fallback
        dnsServers.put("localhost")
        
        dns.put("servers", dnsServers)
        config.put("dns", dns)
        
        // 5. Inbounds (SOCKS + HTTP)
        val inbounds = org.json.JSONArray()
        
        // SOCKS (10808)
        val socksInbound = JSONObject()
        socksInbound.put("tag", "socks")
        socksInbound.put("port", 10808)
        socksInbound.put("listen", "127.0.0.1")
        socksInbound.put("protocol", "socks")
        socksInbound.put("settings", JSONObject().put("auth", "noauth").put("udp", true))
        socksInbound.put("sniffing", JSONObject().put("enabled", true)
            .put("destOverride", org.json.JSONArray().put("http").put("tls").put("quic")))
        inbounds.put(socksInbound)
        
        // HTTP (10809) - For compatibility
        val httpInbound = JSONObject()
        httpInbound.put("tag", "http")
        httpInbound.put("port", 10809)
        httpInbound.put("listen", "127.0.0.1")
        httpInbound.put("protocol", "http")
        httpInbound.put("sniffing", JSONObject().put("enabled", true)
            .put("destOverride", org.json.JSONArray().put("http").put("tls").put("quic")))
        inbounds.put(httpInbound)
        
        config.put("inbounds", inbounds)
        
        // 6. Routing (Bypass LAN/CN, Proxy others)
        val routing = JSONObject()
        routing.put("domainStrategy", "IPIfNonMatch") // or IPOnDemand
        
        val rules = org.json.JSONArray()
        
        // Rule: Direct for private networks
        val privateRule = JSONObject()
        privateRule.put("type", "field")
        privateRule.put("outboundTag", "direct")
        privateRule.put("ip", org.json.JSONArray().put("geoip:private"))
        privateRule.put("domain", org.json.JSONArray().put("geosite:private"))
        rules.put(privateRule)

        // Rule: Direct for DNS Servers (Break Loop)
        // Ensure 8.8.8.8/1.1.1.1 traffic goes out directly to resolve proxy domain
        val dnsRule = JSONObject()
        dnsRule.put("type", "field")
        dnsRule.put("outboundTag", "direct")
        dnsRule.put("ip", org.json.JSONArray().put("8.8.8.8").put("1.1.1.1"))
        rules.put(dnsRule)

        // Rule: Direct for the Proxy Server itself (Bootstrap fix)
        // Extract address from outbound settings to prevent DNS loop
        // Reuse settings from above (line 358)
        if (settings != null && settings.has("address")) {
            val serverAddress = settings.getString("address")
            if (serverAddress.isNotEmpty()) {
                val bootstrapRule = JSONObject()
                bootstrapRule.put("type", "field")
                bootstrapRule.put("outboundTag", "direct")
                bootstrapRule.put("domain", org.json.JSONArray().put(serverAddress))
                rules.put(bootstrapRule)
                Log.d(TAG, "Added bootstrap direct rule for: $serverAddress")
            }
        }
        
        // Rule: Direct for CN (if assets exist)
        val geoip = File(filesDir, "geoip.dat")
        val geosite = File(filesDir, "geosite.dat")
        
        if (geoip.exists() && geosite.exists()) {
            Log.d(TAG, "Geo assets found, enabling split tunneling")
            
            // Domain: geosite:cn -> direct
            rules.put(JSONObject().put("type", "field").put("outboundTag", "direct").put("domain", org.json.JSONArray().put("geosite:cn")))
            
            // IP: geoip:cn -> direct
            rules.put(JSONObject().put("type", "field").put("outboundTag", "direct").put("ip", org.json.JSONArray().put("geoip:cn")))
        } else {
             Log.w(TAG, "Geo assets missing, split tunneling disabled")
        }
        
        // Rule: Proxy for everything else
        val finalRule = JSONObject()
        finalRule.put("type", "field")
        finalRule.put("outboundTag", "proxy")
        finalRule.put("network", "tcp,udp")
        rules.put(finalRule)
        
        routing.put("rules", rules)
        config.put("routing", routing)
        
        // 7. Outbounds (Proxy + Direct + Block)
        val outbounds = org.json.JSONArray()
        
        // Proxy Outbound (from Flutter)
        if (!outbound.has("tag")) outbound.put("tag", "proxy")
        // Ensure mux settings if needed (ignoring for Hysteria/UDP usually)
        outbounds.put(outbound)
        
        // Direct Outbound
        val directOutbound = JSONObject()
        directOutbound.put("protocol", "freedom")
        directOutbound.put("tag", "direct")
        directOutbound.put("settings", JSONObject().put("domainStrategy", "UseIP"))
        outbounds.put(directOutbound)
        
        // Block Outbound
        val blockOutbound = JSONObject()
        blockOutbound.put("protocol", "blackhole")
        blockOutbound.put("tag", "block")
        outbounds.put(blockOutbound)
        
        config.put("outbounds", outbounds)
        
        return config.toString()
    }
    
    private fun ensureStreamSettings(outbound: JSONObject) {
        val protocol = outbound.optString("protocol", "")
        if (protocol == "trojan") {
            var streamSettings = outbound.optJSONObject("streamSettings")
            if (streamSettings == null) {
                streamSettings = JSONObject()
                outbound.put("streamSettings", streamSettings)
            }
            if (!streamSettings.has("security")) streamSettings.put("security", "tls")
            if (!streamSettings.has("network")) streamSettings.put("network", "tcp")
            if (!streamSettings.has("tlsSettings")) streamSettings.put("tlsSettings", JSONObject())
        }
    }
}

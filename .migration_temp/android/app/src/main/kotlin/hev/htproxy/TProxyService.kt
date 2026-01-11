package hev.htproxy

/**
 * JNI 桥接类 - hev-socks5-tunnel 库期望的类
 * 这个类用于 hev-socks5-tunnel native 库的 JNI 方法注册
 * 
 * native 库会在 JNI_OnLoad 时注册这些方法
 * 库会在第一次访问这个 object 时加载（VPN 服务启动时，而不是应用启动时）
 */
object TProxyService {
    init {
        try {
            System.loadLibrary("hev-socks5-tunnel")
        } catch (e: UnsatisfiedLinkError) {
            // 库加载失败，会在调用方法时抛出异常
            throw RuntimeException("Failed to load hev-socks5-tunnel library", e)
        }
    }
    
    /**
     * 启动 TProxy 服务
     * @param configPath 配置文件路径
     * @param fd VPN 接口文件描述符
     */
    @JvmStatic
    external fun TProxyStartService(configPath: String, fd: Int)
    
    /**
     * 停止 TProxy 服务
     */
    @JvmStatic
    external fun TProxyStopService()
    
    /**
     * 获取统计信息
     * @return 统计信息数组，可能为 null
     */
    @JvmStatic
    external fun TProxyGetStats(): LongArray?
}


import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_node.dart';
import 'v2board_api.dart';

/// 订阅服务
class SubscriptionService {
  final V2BoardApi _api = V2BoardApi();

  // 订阅链接
  static const String _defaultSubscriptionUrl =
      'vless://0392ef6b-f0e1-4cc7-a091-3ae041978da3@173.242.126.188:11886?security=reality&encryption=none&pbk=V_lWOIOGx0BAd1IC-96jw0nzvBizuboeB-bfF6_ylRk&headerType=&fp=chrome&spx=%2F&type=tcp&sni=www.microsoft.com&sid=13af4c21#%E7%BE%8E%E5%9B%BDcn2-vcok0jc9';

  /// 模拟从API获取订阅链接
  /// 在实际应用中，这里应该调用真实的API
  Future<String> getSubscriptionUrl() async {
    try {
      final response = await _api.getUserSubscribe();
      final url = response['data']?['subscribe_url']?.toString();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (_) {
      // ignore and fallback
    }
    return _defaultSubscriptionUrl;
  }

  /// 下载订阅文件
  Future<String> downloadSubscription(String url) async {
    try {
      if (url.startsWith('vmess://') ||
          url.startsWith('vless://') ||
          url.startsWith('trojan://') ||
          url.startsWith('ss://')) {
        return url;
      }

      final client = http.Client();
      try {
        var current = Uri.parse(url);
        const maxRedirects = 5;
        http.Response? response;

        for (var i = 0; i < maxRedirects; i++) {
          final request = http.Request('GET', current)..followRedirects = false;
          final streamed = await client.send(request);
          response = await http.Response.fromStream(streamed);

          if (response.statusCode >= 300 && response.statusCode < 400) {
            final location = response.headers['location'];
            if (location == null || location.isEmpty) {
              throw Exception('Redirect without location');
            }
            current = current.resolve(location);
            continue;
          }

          break;
        }
        response ??= await client.get(current);

        if (response.statusCode == 200) {
          return response.body;
        } else {
          throw Exception('Failed to download subscription: ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      throw Exception('Error downloading subscription: $e');
    }
  }

  /// 检测订阅格式并解析
  /// 支持 Clash YAML 格式和传统的 base64 编码格式
  List<ServerNode> parseNodes(String subscriptionContent) {

    
    // 尝试解析为 Clash YAML 格式
    if (subscriptionContent.trim().startsWith('#') || 
        subscriptionContent.contains('proxies:') ||
        subscriptionContent.contains('port:')) {
      return _parseClashYaml(subscriptionContent);
    }
    
    // 尝试 base64 解码（传统格式）
    try {
      final cleaned = subscriptionContent.trim().replaceAll(RegExp(r'\s+'), '');
      final decoded = utf8.decode(base64Decode(cleaned));
      return _parseTraditionalFormat(decoded);
    } catch (e) {
      // 如果不是 base64，直接按传统格式解析
      return _parseTraditionalFormat(subscriptionContent);
    }
  }

  /// 解析 Clash YAML 格式
  List<ServerNode> _parseClashYaml(String yamlContent) {
    final nodes = <ServerNode>[];

    
    try {
      final yaml = loadYaml(yamlContent);
      if (yaml is! Map) return nodes;
      
      final proxies = yaml['proxies'];
      if (proxies == null || proxies is! List) return nodes;
      
      for (var proxy in proxies) {
        try {
          Map<String, dynamic>? proxyMap;
          
          // Clash 配置中的 proxies 可能是 JSON 字符串格式
          if (proxy is String) {
            // 尝试解析 JSON 字符串
            try {
              proxyMap = jsonDecode(proxy) as Map<String, dynamic>?;
            } catch (e) {
              // 如果不是 JSON，跳过
              continue;
            }
          } else if (proxy is Map) {
            // 如果是 Map，需要转换为 Map<String, dynamic>
            proxyMap = Map<String, dynamic>.from(proxy);
          }
          
          if (proxyMap != null) {
            final node = ServerNode.fromClashConfig(proxyMap);
            nodes.add(node);
          }
        } catch (_) {

        }
      }
    } catch (_) {

    }
    
    return nodes;
  }

  /// 解析传统格式（每行一个链接）
  List<ServerNode> _parseTraditionalFormat(String content) {
    final nodes = <ServerNode>[];

    final lines = content.split('\n');
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      try {
        if (line.startsWith('vmess://')) {
          final node = ServerNode.fromVmess(line);
          nodes.add(node);
        } else if (line.startsWith('vless://')) {
          final node = ServerNode.fromVless(line);
          if (node != null) nodes.add(node);
        } else if (line.startsWith('trojan://')) {
          final node = ServerNode.fromTrojan(line);
          if (node != null) nodes.add(node);
        }
        // 可以扩展支持其他协议：vless://, ss://等
      } catch (_) {

      }
    }
    
    return nodes;
  }

  /// 获取并解析订阅节点
  /// [forceRefresh] 是否强制刷新，默认为 false
  Future<List<ServerNode>> fetchNodes({bool forceRefresh = false}) async {
    try {
      // 1. 检查缓存
      if (!forceRefresh) {
        final cached = await _getCachedNodes();
        if (cached != null) {
          return cached;
        }
      }

      // 2. 从API获取订阅链接（带 token 的正式链接）
      final subscriptionUrl = await getSubscriptionUrl();

      // 3. 下载订阅文件
      final subscriptionContent = await downloadSubscription(subscriptionUrl);

      // 4. 解析节点列表（自动检测格式）
      final nodes = parseNodes(subscriptionContent);

      // 5. 保存缓存
      if (nodes.isNotEmpty) {
        await _saveSubscriptionCache(subscriptionContent);
      }

      return nodes;
    } catch (e) {
      // 如果获取失败且不是强制刷新，尝试返回过期缓存
      if (forceRefresh) {
        final cached = await _getCachedNodes(ignoreExpiration: true);
        if (cached != null) return cached;
      }
      throw Exception('Failed to fetch nodes: $e');
    }
  }

  Future<List<ServerNode>?> _getCachedNodes({bool ignoreExpiration = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt('nodes_last_update');
      
      // 如果没有记录或已过期（超过24小时）且不忽略过期
      if (!ignoreExpiration) {
        if (lastUpdate == null) return null;
        final lastTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
        if (DateTime.now().difference(lastTime).inHours >= 24) {
          return null;
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/subscription.txt');
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      if (content.isEmpty) return null;

      return parseNodes(content);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveSubscriptionCache(String content) async {
    try {
      // 保存内容
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/subscription.txt');
      await file.writeAsString(content);

      // 保存时间戳
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('nodes_last_update', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // ignore
    }
  }

  /// 保存订阅内容到本地
  Future<void> saveSubscriptionLocally(String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/subscription.txt');
      await file.writeAsString(content);
    } catch (_) {

    }
  }
}

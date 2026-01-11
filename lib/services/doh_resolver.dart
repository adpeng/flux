import 'dart:convert';
import 'package:http/http.dart' as http;

/// DNS over HTTPS (DoH) 解析器
/// 使用多个 DoH 服务器来解析域名，绕过本地 DNS 限制
class DohResolver {
  // DoH 服务器列表（优先使用 IP 地址，避免域名解析问题）
  static const List<Map<String, String>> dohServers = [
    // 国内 DNS（优先）
    {'name': '阿里DNS', 'url': 'https://223.5.5.5/resolve', 'format': 'json'},
    {'name': '腾讯DNS', 'url': 'https://120.53.53.53/resolve', 'format': 'json'},
    // Cloudflare (使用 IP 地址)
    {'name': 'Cloudflare', 'url': 'https://1.1.1.1/dns-query', 'format': 'json'},
    {'name': 'Cloudflare2', 'url': 'https://1.0.0.1/dns-query', 'format': 'json'},
    // Google (使用 IP 可能不支持，但尝试一下)
    {'name': 'Google', 'url': 'https://8.8.8.8/resolve', 'format': 'json'},
  ];

  /// 使用 DoH 解析域名
  /// 返回 IP 地址，失败返回 null
  static Future<String?> resolve(String domain) async {
    print('[DoH] Starting resolution for: $domain');
    
    // 尝试多个 DoH 服务器
    for (final server in dohServers) {
      final name = server['name']!;
      final url = server['url']!;
      
      try {
        print('[DoH] Trying $name ($url)...');
        final ip = await _resolveWithServer(url, domain);
        if (ip != null) {
          print('[DoH] ✓ Resolved $domain -> $ip via $name');
          return ip;
        }
        print('[DoH] ✗ $name returned no result');
      } catch (e) {
        print('[DoH] ✗ $name failed: $e');
      }
    }
    
    print('[DoH] All DoH servers failed for $domain');
    return null;
  }

  static Future<String?> _resolveWithServer(String serverUrl, String domain) async {
    final client = http.Client();
    
    try {
      final uri = Uri.parse('$serverUrl?name=$domain&type=A');
      final response = await client.get(
        uri,
        headers: {'Accept': 'application/dns-json'},
      ).timeout(const Duration(seconds: 5));
      
      print('[DoH] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);
          final answers = json['Answer'] as List?;
          if (answers != null && answers.isNotEmpty) {
            // 查找 A 记录 (type=1)
            for (final answer in answers) {
              if (answer['type'] == 1) {
                final ip = answer['data'] as String?;
                if (ip != null && _isValidIp(ip)) {
                  return ip;
                }
              }
            }
          }
          print('[DoH] No valid A record in response: ${response.body}');
        } catch (e) {
          print('[DoH] Failed to parse response: ${response.body}');
        }
      }
    } finally {
      client.close();
    }
    
    return null;
  }

  static bool _isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  /// 判断是否为 IP 地址
  static bool isIpAddress(String address) {
    final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    final ipv6Regex = RegExp(r'^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$');
    return ipv4Regex.hasMatch(address) || ipv6Regex.hasMatch(address);
  }
}

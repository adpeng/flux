import 'dart:convert';

/// 服务器节点模型
class ServerNode {
  final String name;
  final String address;
  final int port;
  final String protocol; // vmess, vless, trojan, ss等
  final String? uuid;
  final String? alterId;
  final String? network; // tcp, ws, kcp等
  final String? security; // none, auto, aes-128-gcm等
  final Map<String, dynamic>? rawConfig; // 原始配置
  int? latency; // 延迟（毫秒）
  bool isSelected;

  ServerNode({
    required this.name,
    required this.address,
    required this.port,
    required this.protocol,
    this.uuid,
    this.alterId,
    this.network,
    this.security,
    this.rawConfig,
    this.latency,
    this.isSelected = false,
  });

  /// 从 Clash 配置解析节点
  factory ServerNode.fromClashConfig(Map<String, dynamic> config) {
    final type = config['type'] as String? ?? '';
    final name = config['name'] as String? ?? 'Unknown';
    final server = config['server'] as String? ?? '';
    final port = int.tryParse(config['port']?.toString() ?? '0') ?? 0;

    switch (type) {
      case 'vmess':
        // 获取 network 类型
        String networkType = 'tcp';
        if (config['network'] != null) {
          networkType = config['network'] as String;
        } else if (config['ws-opts'] != null) {
          networkType = 'ws';
        }
        
        // 获取 security/cipher
        String securityType = config['cipher'] as String? ?? 
                             config['security'] as String? ?? 
                             'auto';
        
        return ServerNode(
          name: name,
          address: server,
          port: port,
          protocol: 'vmess',
          uuid: config['uuid'] as String?,
          alterId: config['alterId']?.toString() ?? '0',
          network: networkType,
          security: securityType,
          rawConfig: {
            ...config,
            // 处理 Clash 格式的 WebSocket 配置
            if (config['ws-opts'] != null) 
              'path': (config['ws-opts'] as Map?)?['path'] ?? '/',
            if (config['ws-opts'] != null)
              'host': (config['ws-opts'] as Map?)?['headers']?['Host'],
            // 处理 TLS
            if (config['tls'] == true) 'tls': 'tls',
            if (config['servername'] != null) 'sni': config['servername'],
          },
        );
      case 'trojan':
        return ServerNode(
          name: name,
          address: server,
          port: port,
          protocol: 'trojan',
          uuid: config['password'] as String?, // trojan 使用 password 作为标识
          network: config['network'] as String? ?? 'tcp',
          rawConfig: {
            ...config,
            // 统一处理 sni 字段（Clash 可能使用 servername）
            'sni': config['sni'] ?? config['servername'],
          },
        );
      case 'vless':
        return ServerNode(
          name: name,
          address: server,
          port: port,
          protocol: 'vless',
          uuid: config['uuid'] as String?,
          network: config['network'] as String? ?? 'tcp',
          rawConfig: config,
        );
      case 'ss':
         return ServerNode(
           name: name,
           address: server,
           port: port,
           protocol: 'shadowsocks',
           uuid: config['password'] as String?,
           security: config['cipher'] as String?,
           rawConfig: config,
         );
      case 'hysteria2':
         return ServerNode(
           name: name,
           address: server,
           port: port,
           protocol: 'hysteria2',
           uuid: config['password'] as String?,
           network: 'udp',
           rawConfig: {
             ...config,
             'sni': config['sni'] ?? config['peer'],
           },
         );
      default:
        // 不支持的协议类型
        return ServerNode(
          name: name,
          address: server,
          port: port,
          protocol: type,
          rawConfig: config,
        );
    }
  }

  /// 从VMess链接解析
  factory ServerNode.fromVmess(String vmessLink) {
    try {
      // vmess://base64编码的JSON
      if (!vmessLink.startsWith('vmess://')) {
        throw Exception('Invalid VMess link');
      }

      final base64Str = vmessLink.substring(8);
      final decoded = String.fromCharCodes(
        base64Decode(base64Str),
      );
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      return ServerNode(
        name: json['ps'] as String? ?? 'Unknown',
        address: json['add'] as String? ?? '',
        port: int.tryParse(json['port']?.toString() ?? '0') ?? 0,
        protocol: 'vmess',
        uuid: json['id'] as String?,
        alterId: json['aid']?.toString(),
        network: json['net'] as String? ?? 'tcp',
        security: json['scy'] as String? ?? 'auto',
        rawConfig: json,
      );
    } catch (e) {
      throw Exception('Failed to parse VMess link: $e');
    }
  }

  /// 从Trojan链接解析
  static ServerNode? fromTrojan(String trojanLink) {
    try {
      // trojan://password@server:port?params
      if (!trojanLink.startsWith('trojan://')) {
        return null;
      }

      final uri = Uri.parse(trojanLink);
      final query = uri.queryParameters;
      final password = uri.userInfo;
      final server = uri.host;
      final port = uri.port;
      final network = query['type'] ?? query['network'] ?? 'tcp';
      final security = query['security'];
      final sni = query['sni'] ?? query['peer'] ?? query['host'];
      final allowInsecure = _parseBool(query['allowInsecure'] ?? query['allowinsecure']);
      final headerType = query['headerType'] ?? query['header_type'] ?? query['header'];

      return ServerNode(
        name: uri.fragment.isNotEmpty ? uri.fragment : 'Trojan',
        address: server,
        port: port,
        protocol: 'trojan',
        uuid: password, // trojan 使用 password
        network: network,
        rawConfig: {
          'password': password,
          'server': server,
          'port': port,
          if (security != null) 'security': security,
          if (sni != null) 'sni': sni,
          if (allowInsecure == true) 'allowInsecure': true,
          if (headerType != null) 'headerType': headerType,
        },
      );
    } catch (e) {
      return null;
    }
  }

  /// 从VLESS链接解析
  static ServerNode? fromVless(String vlessLink) {
    try {
      if (!vlessLink.startsWith('vless://')) {
        return null;
      }

      final uri = Uri.parse(vlessLink);
      final query = uri.queryParameters;
      final uuid = uri.userInfo;
      final server = uri.host;
      final port = uri.port;
      final network = query['type'] ?? query['network'] ?? 'tcp';
      final security = query['security'];
      final headerType = query['headerType'] ?? query['header_type'] ?? query['header'];
      final host = query['host'];
      final path = query['path'];
      final alpn = query['alpn'];
      final allowInsecure = _parseBool(
        query['insecure'] ?? query['allowInsecure'] ?? query['allow_insecure'],
      );

      return ServerNode(
        name: _decodeNodeName(uri.fragment, fallback: 'VLESS'),
        address: server,
        port: port,
        protocol: 'vless',
        uuid: uuid,
        network: network,
        rawConfig: {
          'uuid': uuid,
          'server': server,
          'port': port,
          if (query['encryption'] != null) 'encryption': query['encryption'],
          if (query['flow'] != null) 'flow': query['flow'],
          if (security != null) 'security': security,
          if (query['sni'] != null) 'sni': query['sni'],
          if (query['fp'] != null) 'fp': query['fp'],
          if (query['pbk'] != null) 'pbk': query['pbk'],
          if (query['sid'] != null) 'sid': query['sid'],
          if (query['spx'] != null) 'spx': query['spx'],
          if (allowInsecure != null) 'allowInsecure': allowInsecure,
          if (headerType != null && headerType.isNotEmpty) 'headerType': headerType,
          if (host != null && host.isNotEmpty) 'host': host,
          if (path != null && path.isNotEmpty) 'path': path,
          if (alpn != null && alpn.isNotEmpty) 'alpn': alpn,
        },
      );
    } catch (e) {
      return null;
    }
  }

  static String _decodeNodeName(String fragment, {required String fallback}) {
    if (fragment.isEmpty) return fallback;
    try {
      return Uri.decodeComponent(fragment);
    } catch (e) {
      return fragment;
    }
  }

  /// 转换为V2ray配置JSON（返回outbound配置）
  Map<String, dynamic> toV2rayConfig() {
    if (protocol == 'vmess') {
      final outbound = <String, dynamic>{
        'protocol': 'vmess',
        'settings': {
          'vnext': [
            {
              'address': address,
              'port': port,
              'users': [
                {
                  'id': uuid ?? '',
                  'alterId': int.tryParse(alterId ?? '0') ?? 0,
                  'security': security ?? 'auto',
                }
              ]
            }
          ]
        },
      };

      // 添加streamSettings
      final streamSettings = <String, dynamic>{
        'network': network ?? 'tcp',
      };

      // WebSocket配置
      if (network == 'ws') {
        streamSettings['wsSettings'] = {
          'path': rawConfig?['path'] ?? '/',
          if (rawConfig?['host'] != null) 'headers': {
            'Host': rawConfig!['host'],
          },
        };
      }

      // TLS配置
      if (rawConfig?['tls'] != null && rawConfig!['tls'] == 'tls') {
        streamSettings['security'] = 'tls';
        if (rawConfig?['sni'] != null) {
          streamSettings['tlsSettings'] = {
            'serverName': rawConfig!['sni'],
          };
        }
      }

      outbound['streamSettings'] = streamSettings;
      return outbound;
    } else if (protocol == 'trojan') {
      // Trojan 协议配置
      final outbound = <String, dynamic>{
        'protocol': 'trojan',
        'settings': {
          'servers': [
            {
              'address': address,
              'port': port,
              'password': uuid ?? '',
            }
          ]
        },
      };

      // 添加 streamSettings
      final streamSettings = <String, dynamic>{
        'network': network ?? 'tcp',
      };

      // TLS 配置（Trojan 默认使用 TLS）
      streamSettings['security'] = 'tls';
      final sni = rawConfig?['sni'] as String?;
      final skipCertVerify = rawConfig?['skip-cert-verify'] == true ||
          rawConfig?['allowInsecure'] == true;
      
      if (sni != null || skipCertVerify) {
        streamSettings['tlsSettings'] = <String, dynamic>{
          if (sni != null) 'serverName': sni,
          if (skipCertVerify) 'allowInsecure': true,
        };
      }

      final headerType = rawConfig?['headerType'] as String?;
      if ((network ?? 'tcp') == 'tcp' && headerType != null) {
        streamSettings['tcpSettings'] = <String, dynamic>{
          'header': <String, dynamic>{
            'type': headerType,
          },
        };
      }

      outbound['streamSettings'] = streamSettings;
      return outbound;
    } else if (protocol == 'vless') {
      // VLESS 协议配置
      final outbound = <String, dynamic>{
        'protocol': 'vless',
        'settings': {
          'vnext': [
            {
              'address': address,
              'port': port,
              'users': [
                {
                  'id': uuid ?? '',
                  'encryption': rawConfig?['encryption'] ?? 'none',
                  if (rawConfig?['flow'] != null) 'flow': rawConfig!['flow'],
                }
              ]
            }
          ]
        },
      };

      // 添加 streamSettings
      final streamSettings = <String, dynamic>{
        'network': network ?? 'tcp',
      };

      final security = rawConfig?['security'] as String?;
      final headerType = rawConfig?['headerType'] as String?;
      final host = rawConfig?['host'] as String?;
      final path = rawConfig?['path'] as String?;

      if ((network ?? 'tcp') == 'tcp') {
        if (headerType == 'http') {
          streamSettings['tcpSettings'] = <String, dynamic>{
            'header': <String, dynamic>{
              'type': 'http',
              'request': <String, dynamic>{
                if (host != null && host.isNotEmpty)
                  'headers': <String, dynamic>{
                    'Host': host.split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).toList(),
                  },
                if (path != null && path.isNotEmpty)
                  'path': path.split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).toList(),
              },
            },
          };
        } else {
          streamSettings['tcpSettings'] = <String, dynamic>{
            'header': <String, dynamic>{
              'type': 'none',
            },
          };
        }
      }

      // TLS / REALITY 配置
      if (security == 'reality') {
        final sni = (rawConfig?['sni'] as String?)?.isNotEmpty == true
            ? rawConfig!['sni'] as String
            : host;
        final allowInsecure = rawConfig?['allowInsecure'] == true;
        streamSettings['security'] = 'reality';
        streamSettings['realitySettings'] = <String, dynamic>{
          if (sni != null && sni.isNotEmpty) 'serverName': sni,
          if (rawConfig?['fp'] != null) 'fingerprint': rawConfig!['fp'],
          if (rawConfig?['pbk'] != null) 'publicKey': rawConfig!['pbk'],
          if (rawConfig?['sid'] != null) 'shortId': rawConfig!['sid'],
          if (rawConfig?['spx'] != null) 'spiderX': rawConfig!['spx'],
          'allowInsecure': allowInsecure,
          'show': false,
          if (rawConfig?['alpn'] != null)
            'alpn': (rawConfig!['alpn'] as String)
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(),
        };
      } else if (rawConfig?['tls'] == true ||
          rawConfig?['tls'] == 'tls' ||
          security == 'tls') {
        streamSettings['security'] = 'tls';
        if (rawConfig?['sni'] != null) {
          streamSettings['tlsSettings'] = {
            'serverName': rawConfig!['sni'],
          };
        }
      }

      outbound['streamSettings'] = streamSettings;
      return outbound;
    } else if (protocol == 'shadowsocks') {
      // Shadowsocks 协议配置
      final outbound = <String, dynamic>{
        'protocol': 'shadowsocks',
        'settings': {
          'servers': [
            {
              'address': address,
              'port': port,
              'password': uuid ?? '',
              'method': security ?? 'aes-128-gcm',
              'uot': true,
            }
          ]
        },
      };
      return outbound;
    } else if (protocol == 'hysteria2') {
      // Hysteria2 协议配置
      final outbound = <String, dynamic>{
        'protocol': 'hysteria2',
        'settings': {
          'servers': [
            {
              'address': address,
              'port': port,
              'auth': uuid ?? '',
            }
          ]
        },
      };

      final streamSettings = <String, dynamic>{
        'network': 'udp',
        'security': 'tls',
      };
      
      final sni = rawConfig?['sni'] as String?;
      final skipCertVerify = rawConfig?['skip-cert-verify'] == true ||
          rawConfig?['allowInsecure'] == true;
          
      if (sni != null || skipCertVerify) {
        streamSettings['tlsSettings'] = <String, dynamic>{
          if (sni != null) 'serverName': sni,
          if (skipCertVerify) 'allowInsecure': true,
        };
      }
      
      outbound['streamSettings'] = streamSettings;
      return outbound;
    }
    // 不支持的协议
    return {};
  }

  @override
  String toString() => '$name ($address:$port)';
}

bool? _parseBool(String? value) {
  if (value == null) return null;
  switch (value.toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    case '0':
    case 'false':
    case 'no':
    case 'off':
      return false;
    default:
      return null;
  }
}

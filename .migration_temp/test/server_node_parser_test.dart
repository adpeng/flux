import 'package:flutter_test/flutter_test.dart';
import 'package:flux/models/server_node.dart';

void main() {
  test('ServerNode.parseFromContent handles mixed content and recursive Base64', () {
    const mixedContent = '''
hysteria2://555a23c7-fbb7-47f1-8fce-0e673a8c02b8@203.10.99.51:20000/?insecure=1&sni=www.bing.com&mport=20000-55000#%E5%89%A9%E4%BD%99%E6%B5%81%E9%87%8F%EF%BC%9A96.21%20GB
hysteria2://555a23c7-fbb7-47f1-8fce-0e673a8c02b8@203.10.99.51:20000/?insecure=1&sni=www.bing.com&mport=20000-55000#%E8%B7%9D%E7%A6%BB%E4%B8%8B%E6%AC%A1%E9%87%8D%E7%BD%AE%E5%89%A9%E4%BD%99%EF%BC%9A30%20%E5%A4%A9
vless://e76b8358-84a3-4a10-9ce0-01aebe975ff5@1.1.1.1:11111?type=tcp&encryption=none&host=&path=&headerType=none&quicSecurity=none&serviceName=&security=tls&fp=chrome&insecure=0&sni=#%F0%9F%94%A5%E5%AE%98%E7%BD%91iosbba.top
ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTpjMmNlMWNkZC1mM2ZhLTQ0YmItOTQwMi05MmEyYzkyNjEzNzU@dd.42135.top:36129#%F0%9F%87%AD%F0%9F%87%B0%20%20%7C%E9%A6%99%E6%B8%AF01%7C%E4%B8%93%E7%BA%BF
c3M6Ly9ZMmhoWTJoaE1qQXRhV1YwWmkxd2IyeDVNVE13TlRwak1tTmxNV05rWkMxbU0yWmhMVFEwWW1JdE9URXdNaTA1TW1FeVl6a3lOakV6TnpVQGhrLmRvdXlpYWN0aXZlLnRvcDoyOTgzMSMlRTklQTYlOTklRTYlQjglQUYNCnNzOi8vWTJoaFkyaGhNakF0YVdWMFppMXdiMng1TVRNd05UcGpNbU5sTVdOa1pDMW1NMlpoTFRRMFltSXRPVEV3TWkwNU1tRXlZemt5TmpFek56VUBqcC5kb3V5aWFjdGl2ZS50b3A6NDE3MjgjJUU2JTk3JUE1JUU2JTlDJUFDDQpzczovL1kyaGhZMmhoTWpBdGFXVjBaaTF3YjJ4NU1UTXdOVHBqTW1ObE1XTmtaQzFtTTJaaExUUTBZbUl0T1RFd01pMDVNbUV5WXpreU5qRXpOelVAdHcuZG91eWlhY3RpdmUudG9wOjM1NjkwIyVFNSVCRSVCNyVFNSU5QiVCRA==
''';

    final nodes = ServerNode.parseFromContent(mixedContent);

    // Verify we parsed successfully
    expect(nodes.isNotEmpty, true);
    
    // Check specific node types
    expect(nodes.any((n) => n.protocol == 'hysteria2'), true);
    expect(nodes.any((n) => n.protocol == 'vless'), true);
    expect(nodes.any((n) => n.protocol == 'shadowsocks'), true);
    
    // Verify recursion (Base64 decoded content)
    // The Base64 block contains SS links.
    // c3M6Ly9... decodes to a list starting with ss://...
    // We should find '香港' (HK) related nodes from the base64 block
    expect(nodes.any((n) => n.name.contains('香港') && n.protocol == 'shadowsocks'), true);
    
    // Print results for visual confirmation
    for (var node in nodes) {
      print('Parsed Node: \${node.protocol} - \${node.name} - \${node.address}');
    }
  });

  test('ServerNode.parseFromContent handles WireGuard', () {
    const wgLink = 'wg://myprivatekey@1.2.3.4:51820?publicKey=pubkey&ip=10.0.0.2/32#MyHG';
    final nodes = ServerNode.parseFromContent(wgLink);
    expect(nodes.length, 1);
    expect(nodes.first.protocol, 'wireguard');
    expect(nodes.first.name, 'MyHG');
  });
}

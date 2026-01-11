import 'package:flutter_test/flutter_test.dart';
import 'package:flux/models/server_node.dart';

void main() {
  test('Debug Hysteria2 Parsing', () {
    final links = [
      'hysteria2://555a23c7-fbb7-47f1-8fce-0e673a8c02b8@203.10.99.51:20000/?insecure=1&sni=www.bing.com&mport=20000-55000#%E5%89%A9%E4%BD%99%E6%B5%81%E9%87%8F%EF%BC%9A96.21%20GB',
      'hysteria2://e76b8358-84a3-4a10-9ce0-01aebe975ff5@hkk.ccooo.cc:20000/?insecure=1&sni=hkk.ccooo.cc&mport=20000-20500#%E9%A6%99%E6%B8%AF-%E7%A7%BB%E5%8A%A8%E4%BC%98%E5%8C%96',
      'hysteria2://e76b8358-84a3-4a10-9ce0-01aebe975ff5@sg.56682.top:34233/?insecure=0&sni=sg.56682.top#%E6%96%B0%E5%8A%A0%E5%9D%A1-%E4%B8%89%E7%BD%91%E4%BC%98%E5%8C%96',
      'hysteria2://e76b8358-84a3-4a10-9ce0-01aebe975ff5@us.56682.top:34233/?insecure=0&sni=us.56682.top#%E7%BE%8E%E5%9B%BD-%E4%B8%89%E7%BD%91%E4%BC%98%E5%8C%96',
      'hysteria2://e76b8358-84a3-4a10-9ce0-01aebe975ff5@jp2.ccooo.cc:20000/?insecure=1&sni=jp2.ccooo.cc&mport=20000-20500#%E6%97%A5%E6%9C%AC-%E7%94%B5%E4%BF%A1%E7%A7%BB%E5%8A%A8%E4%BC%98%E5%8C%96',
      'hysteria2://e76b8358-84a3-4a10-9ce0-01aebe975ff5@sg.ccooo.cc:20000/?insecure=1&sni=sg.ccooo.cc&mport=20000-20500#%E6%96%B0%E5%8A%A0%E5%9D%A1-%E7%A7%BB%E5%8A%A8%E4%BC%98%E5%8C%96',
    ];

    print('\n--- Parsing Debug Start ---');
    for (var link in links) {
      final node = ServerNode.fromHysteria2(link);
      print('Link: $link');
      if (node == null) {
        print('Result: NULL');
      } else {
        print('Result: Address=[${node.address}] Port=[${node.port}] Name=[${node.name}]');
        if (node.address.isEmpty) {
          print('!!! ALERT: Empty Address !!!');
        }
      }
      print('---');
    }
  });
}

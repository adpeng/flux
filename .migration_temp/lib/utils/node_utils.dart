/// 节点工具类
class NodeUtils {
  /// 从节点名称中提取国家/地区信息
  static String extractCountry(String name) {
    // 优先匹配中文国家名，避免 "cn2" 之类被误判为中国
    const chineseNames = [
      '中国',
      '美国',
      '香港',
      '台湾',
      '日本',
      '韩国',
      '新加坡',
      '英国',
      '德国',
      '法国',
      '加拿大',
      '澳大利亚',
      '荷兰',
      '俄罗斯',
      '印度',
      '巴西',
      '土耳其',
      '墨西哥',
    ];
    for (final cn in chineseNames) {
      if (name.contains(cn)) {
        return cn;
      }
    }

    // 常见国家代码映射
    final countryMap = {
      'CN': '中国',
      'US': '美国',
      'HK': '香港',
      'TW': '台湾',
      'JP': '日本',
      'KR': '韩国',
      'SG': '新加坡',
      'UK': '英国',
      'GB': '英国',
      'DE': '德国',
      'FR': '法国',
      'CA': '加拿大',
      'AU': '澳大利亚',
      'NL': '荷兰',
      'RU': '俄罗斯',
      'IN': '印度',
      'BR': '巴西',
      'TR': '土耳其',
      'MX': '墨西哥',
    };

    // 尝试从名称中提取国家代码
    final upperName = name.toUpperCase();
    
    // 检查是否有国家代码
    for (var entry in countryMap.entries) {
      if (upperName.contains(entry.key)) {
        return entry.value;
      }
    }

    // 如果没有找到，尝试提取常见模式
    // 例如: "Hong Kong", "Japan" 等
    final countryNames = {
      'HONG KONG': '香港',
      'HONGKONG': '香港',
      'TAIWAN': '台湾',
      'JAPAN': '日本',
      'SINGAPORE': '新加坡',
      'KOREA': '韩国',
      'SOUTH KOREA': '韩国',
      'CHINA': '中国',
      'USA': '美国',
      'UNITED STATES': '美国',
      'UK': '英国',
      'UNITED KINGDOM': '英国',
    };

    for (var entry in countryNames.entries) {
      if (upperName.contains(entry.key)) {
        return entry.value;
      }
    }

    // 如果都没找到，返回原始名称的前几个字符或默认值
    return name.length > 10 ? name.substring(0, 10) : name;
  }
}

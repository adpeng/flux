class Plan {
  Plan({
    required this.id,
    required this.name,
    required this.transferEnable,
    this.content,
    this.monthPrice,
    this.quarterPrice,
    this.halfYearPrice,
    this.yearPrice,
    this.twoYearPrice,
    this.threeYearPrice,
    this.onetimePrice,
    this.resetPrice,
    this.resetMethod,
  });

  final int id;
  final String name;
  final int transferEnable;
  final String? content;
  final int? monthPrice;
  final int? quarterPrice;
  final int? halfYearPrice;
  final int? yearPrice;
  final int? twoYearPrice;
  final int? threeYearPrice;
  final int? onetimePrice;
  final int? resetPrice;
  final int? resetMethod;

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Plan',
      // API 返回的 transfer_enable 单位是 GB，需要转换为字节
      transferEnable: ((json['transfer_enable'] ?? 0) as int) * 1024 * 1024 * 1024,
      content: json['content'],
      monthPrice: json['month_price'],
      quarterPrice: json['quarter_price'],
      halfYearPrice: json['half_year_price'],
      yearPrice: json['year_price'],
      twoYearPrice: json['two_year_price'],
      threeYearPrice: json['three_year_price'],
      onetimePrice: json['onetime_price'],
      resetPrice: json['reset_price'],
      resetMethod: json['reset_traffic_method'],
    );
  }
}

class PaymentMethod {
  PaymentMethod({
    required this.id,
    required this.name,
    required this.payment,
    this.icon,
  });

  final int id;
  final String name;
  final String payment;
  final String? icon;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      payment: json['payment'] ?? '',
      icon: json['icon'],
    );
  }
}

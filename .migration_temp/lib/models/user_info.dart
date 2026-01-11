class UserInfo {
  UserInfo({
    required this.email,
    required this.transferEnable,
    required this.expiredAt,
    required this.balance,
    required this.planId,
    this.avatarUrl,
    this.uuid,
  });

  final String email;
  final int transferEnable;
  final int expiredAt;
  final int balance;
  final int planId;
  final String? avatarUrl;
  final String? uuid;

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      email: json['email'] ?? '',
      transferEnable: json['transfer_enable'] ?? 0,
      expiredAt: json['expired_at'] ?? 0,
      balance: json['balance'] ?? 0,
      planId: json['plan_id'] ?? 0,
      avatarUrl: json['avatar_url'],
      uuid: json['uuid'],
    );
  }
}

class UserSubscribe {
  UserSubscribe({
    required this.planId,
    required this.token,
    required this.expiredAt,
    required this.upload,
    required this.download,
    required this.transferEnable,
    required this.email,
    required this.subscribeUrl,
  });

  final int planId;
  final String token;
  final int expiredAt;
  final int upload;
  final int download;
  final int transferEnable;
  final String email;
  final String subscribeUrl;

  factory UserSubscribe.fromJson(Map<String, dynamic> json) {
    return UserSubscribe(
      planId: json['plan_id'] ?? 0,
      token: json['token'] ?? '',
      expiredAt: json['expired_at'] ?? 0,
      upload: json['u'] ?? 0,
      download: json['d'] ?? 0,
      transferEnable: json['transfer_enable'] ?? 0,
      email: json['email'] ?? '',
      subscribeUrl: json['subscribe_url'] ?? '',
    );
  }
}

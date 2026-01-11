class Notice {
  final int id;
  final String title;
  final String content;
  final String? imgUrl;
  final DateTime createdAt;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    this.imgUrl,
    required this.createdAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      imgUrl: json['img_url'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch((json['created_at'] as int) * 1000),
    );
  }
}

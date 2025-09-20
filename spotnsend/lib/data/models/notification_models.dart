class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.seen,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool seen;
  final DateTime createdAt;

  AppNotification copyWith({String? title, String? body, bool? seen}) {
    return AppNotification(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      seen: seen ?? this.seen,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      seen: json['seen'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'seen': seen,
        'createdAt': createdAt.toIso8601String(),
      };
}

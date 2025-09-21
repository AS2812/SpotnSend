class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.seen,
    required this.createdAt,
    this.payload,
  });

  final String id;
  final String title;
  final String body;
  final bool seen;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;

  AppNotification copyWith({
    String? title,
    String? body,
    bool? seen,
    Map<String, dynamic>? payload,
  }) {
    return AppNotification(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      seen: seen ?? this.seen,
      createdAt: createdAt,
      payload: payload ?? this.payload,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] ?? json['notificationId'] ?? json['notification_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      seen: json['seen'] == true || json['seen_at'] != null,
      createdAt: DateTime.tryParse((json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()).toString()) ?? DateTime.now(),
      payload: json['payload'] is Map<String, dynamic> ? json['payload'] as Map<String, dynamic> : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'seen': seen,
        'createdAt': createdAt.toIso8601String(),
        if (payload != null) 'payload': payload,
      };
}

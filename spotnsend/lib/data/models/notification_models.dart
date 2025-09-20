class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.seen,
    required this.createdAt,
<<<<<<< HEAD
=======
    this.payload,
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768
  });

  final String id;
  final String title;
  final String body;
  final bool seen;
  final DateTime createdAt;
<<<<<<< HEAD

  AppNotification copyWith({String? title, String? body, bool? seen}) {
=======
  final Map<String, dynamic>? payload;

  AppNotification copyWith({
    String? title,
    String? body,
    bool? seen,
    Map<String, dynamic>? payload,
  }) {
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768
    return AppNotification(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      seen: seen ?? this.seen,
      createdAt: createdAt,
<<<<<<< HEAD
=======
      payload: payload ?? this.payload,
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
<<<<<<< HEAD
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      seen: json['seen'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
=======
      id: (json['id'] ?? json['notificationId'] ?? json['notification_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      seen: json['seen'] == true || json['seen_at'] != null,
      createdAt: DateTime.tryParse((json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()).toString()) ?? DateTime.now(),
      payload: json['payload'] is Map<String, dynamic> ? json['payload'] as Map<String, dynamic> : null,
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'seen': seen,
        'createdAt': createdAt.toIso8601String(),
<<<<<<< HEAD
=======
        if (payload != null) 'payload': payload,
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768
      };
}

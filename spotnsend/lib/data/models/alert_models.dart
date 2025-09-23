enum AlertStatus { active, resolved, expired }

enum AlertSeverity { low, medium, high, critical }

class Alert {
  const Alert({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.subcategory,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.severity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.reportId,
    required this.creatorId,
    this.mediaUrls = const [],
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String subcategory;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final AlertSeverity severity;
  final AlertStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String reportId;
  final String creatorId;
  final List<String> mediaUrls;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['alert_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      subcategory: json['subcategory']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 0,
      severity: AlertSeverity.values.firstWhere(
        (e) => e.name == json['severity']?.toString(),
        orElse: () => AlertSeverity.medium,
      ),
      status: AlertStatus.values.firstWhere(
        (e) => e.name == json['status']?.toString(),
        orElse: () => AlertStatus.active,
      ),
      createdAt: DateTime.parse(
          json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
      reportId: json['report_id']?.toString() ?? '',
      creatorId: json['creator_id']?.toString() ?? '',
      mediaUrls: (json['media_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'].toString())
          : null,
      resolvedBy: json['resolved_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alert_id': id,
      'title': title,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'severity': severity.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'report_id': reportId,
      'creator_id': creatorId,
      'media_urls': mediaUrls,
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolved_by': resolvedBy,
    };
  }

  Alert copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? subcategory,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    AlertSeverity? severity,
    AlertStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reportId,
    String? creatorId,
    List<String>? mediaUrls,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) {
    return Alert(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reportId: reportId ?? this.reportId,
      creatorId: creatorId ?? this.creatorId,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Alert &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.category == category &&
        other.subcategory == subcategory &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.radiusMeters == radiusMeters &&
        other.severity == severity &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.reportId == reportId &&
        other.creatorId == creatorId &&
        other.mediaUrls == mediaUrls &&
        other.resolvedAt == resolvedAt &&
        other.resolvedBy == resolvedBy;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      description,
      category,
      subcategory,
      latitude,
      longitude,
      radiusMeters,
      severity,
      status,
      createdAt,
      updatedAt,
      reportId,
      creatorId,
      mediaUrls,
      resolvedAt,
      resolvedBy,
    );
  }
}

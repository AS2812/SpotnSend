enum ReportAudience { people, government, both }

enum ReportStatus { submitted, underReview, approved, rejected, archived }

enum ReportPriority { low, normal, high, critical }

class ReportCategory {
  const ReportCategory({required this.id, required this.name, this.subcategories = const []});

  final int id;
  final String name;
  final List<ReportSubcategory> subcategories;
}

class ReportSubcategory {
  const ReportSubcategory({required this.id, required this.name});

  final int id;
  final String name;
}

class Report {
  const Report({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    required this.description,
    required this.lat,
    required this.lng,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.distanceMeters,
    this.media,
  });

  final String id;
  final int categoryId;
  final String categoryName;
  final int? subcategoryId;
  final String? subcategoryName;
  final String description;
  final double lat;
  final double lng;
  final ReportStatus status;
  final ReportPriority priority;
  final DateTime createdAt;
  final double? distanceMeters;
  final List<ReportMedia>? media;

  factory Report.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ?? json['reportStatus'] ?? 'submitted').toString().toLowerCase();
    final priorityRaw = (json['priority'] ?? 'normal').toString().toLowerCase();
    return Report(
      id: (json['id'] ?? json['reportId'] ?? json['report_id'] ?? '').toString(),
      categoryId: _coerceInt(json['categoryId'] ?? json['category_id']) ?? 0,
      categoryName: (json['categoryName'] ?? json['category_name'] ?? '').toString(),
      subcategoryId: _coerceInt(json['subcategoryId'] ?? json['subcategory_id']),
      subcategoryName: (json['subcategoryName'] ?? json['subcategory_name'])?.toString(),
      description: (json['description'] ?? '').toString(),
      lat: _coerceDouble(json['lat'] ?? json['latitude']) ?? 0,
      lng: _coerceDouble(json['lng'] ?? json['longitude']) ?? 0,
      status: _parseStatus(statusRaw),
      priority: _parsePriority(priorityRaw),
      createdAt: DateTime.tryParse((json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()).toString()) ?? DateTime.now(),
      distanceMeters: _coerceDouble(json['distanceMeters'] ?? json['distance_meters']),
      media: (json['media'] ?? json['mediaItems']) is List
          ? (json['media'] ?? json['mediaItems'])
              .whereType<Map<String, dynamic>>()
              .map(ReportMedia.fromJson)
              .toList()
          : null,
    );
  }

  String get category => categoryName;

  String get subcategory => subcategoryName ?? '';

  List<String> get mediaUrls =>
      (media == null || media!.isEmpty) ? const [] : media!.map((item) => item.url).toList(growable: false);
}

class ReportMedia {
  const ReportMedia({
    required this.url,
    this.thumbnailUrl,
    this.kind = 'image',
    this.isCover = false,
  });

  final String url;
  final String? thumbnailUrl;
  final String kind;
  final bool isCover;

  factory ReportMedia.fromJson(Map<String, dynamic> json) {
    return ReportMedia(
      url: (json['url'] ?? json['storage_url'] ?? '').toString(),
      thumbnailUrl: (json['thumbnailUrl'] ?? json['thumbnail_url'])?.toString(),
      kind: (json['kind'] ?? json['media_type'] ?? 'image').toString(),
      isCover: (json['isCover'] ?? json['is_cover'] ?? false) as bool,
    );
  }
}

class ReportFormData {
  static const _unset = Object();

  ReportFormData({
    this.categoryId,
    this.subcategoryId,
    this.categoryName,
    this.subcategoryName,
    this.description = '',
    this.mediaPaths = const [],
    this.audience = ReportAudience.people,
    this.useCurrentLocation = true,
    this.selectedLat,
    this.selectedLng,
    this.agreedToTerms = false,
    this.radiusKm = 3,
    this.notifyScope,
    this.priority,
  });

  final int? categoryId;
  final int? subcategoryId;
  final String? categoryName;
  final String? subcategoryName;
  final String description;
  final List<String> mediaPaths;
  final ReportAudience audience;
  final bool useCurrentLocation;
  final double? selectedLat;
  final double? selectedLng;
  final bool agreedToTerms;
  final double radiusKm;
  final ReportAudience? notifyScope;
  final ReportPriority? priority;

  String? get category => categoryName;

  String? get subcategory => subcategoryName;

  ReportFormData copyWith({
    Object? categoryId = _unset,
    Object? subcategoryId = _unset,
    Object? categoryName = _unset,
    Object? subcategoryName = _unset,
    String? description,
    List<String>? mediaPaths,
    ReportAudience? audience,
    bool? useCurrentLocation,
    Object? selectedLat = _unset,
    Object? selectedLng = _unset,
    bool? agreedToTerms,
    double? radiusKm,
    Object? notifyScope = _unset,
    Object? priority = _unset,
  }) {
    return ReportFormData(
      categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as int?,
      subcategoryId: identical(subcategoryId, _unset) ? this.subcategoryId : subcategoryId as int?,
      categoryName: identical(categoryName, _unset) ? this.categoryName : categoryName as String?,
      subcategoryName: identical(subcategoryName, _unset) ? this.subcategoryName : subcategoryName as String?,
      description: description ?? this.description,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      audience: audience ?? this.audience,
      useCurrentLocation: useCurrentLocation ?? this.useCurrentLocation,
      selectedLat: identical(selectedLat, _unset) ? this.selectedLat : selectedLat as double?,
      selectedLng: identical(selectedLng, _unset) ? this.selectedLng : selectedLng as double?,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
      radiusKm: radiusKm ?? this.radiusKm,
      notifyScope: identical(notifyScope, _unset) ? this.notifyScope : notifyScope as ReportAudience?,
      priority: identical(priority, _unset) ? this.priority : priority as ReportPriority?,
    );
  }
}

class ReportFilters {
  const ReportFilters({
    required this.radiusKm,
    required this.categories,
    required this.includeSavedSpots,
  });

  final double radiusKm;
  final Set<String> categories;
  final bool includeSavedSpots;

  ReportFilters copyWith({
    double? radiusKm,
    Set<String>? categories,
    bool? includeSavedSpots,
  }) {
    return ReportFilters(
      radiusKm: radiusKm ?? this.radiusKm,
      categories: categories ?? this.categories,
      includeSavedSpots: includeSavedSpots ?? this.includeSavedSpots,
    );
  }
}

ReportStatus _parseStatus(String value) {
  switch (value) {
    case 'under_review':
      return ReportStatus.underReview;
    case 'approved':
      return ReportStatus.approved;
    case 'rejected':
      return ReportStatus.rejected;
    case 'archived':
      return ReportStatus.archived;
    default:
      return ReportStatus.submitted;
  }
}

ReportPriority _parsePriority(String value) {
  switch (value) {
    case 'low':
      return ReportPriority.low;
    case 'high':
      return ReportPriority.high;
    case 'critical':
      return ReportPriority.critical;
    default:
      return ReportPriority.normal;
  }
}

int? _coerceInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _coerceDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

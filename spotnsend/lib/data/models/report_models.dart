enum ReportAudience { people, government, both }

class ReportCategory {
  const ReportCategory({required this.name, required this.subcategories});

  final String name;
  final List<String> subcategories;
}

class Report {
  const Report({
    required this.id,
    required this.category,
    required this.subcategory,
    required this.description,
    required this.mediaUrls,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String subcategory;
  final String description;
  final List<String> mediaUrls;
  final double lat;
  final double lng;
  final DateTime createdAt;

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      description: json['description'] as String,
      mediaUrls: (json['mediaUrls'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'subcategory': subcategory,
      'description': description,
      'mediaUrls': mediaUrls,
      'lat': lat,
      'lng': lng,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ReportFormData {
  ReportFormData({
    this.category,
    this.subcategory,
    this.description = '',
    this.mediaPaths = const [],
    this.audience = ReportAudience.people,
    this.useCurrentLocation = true,
    this.selectedLat,
    this.selectedLng,
    this.agreedToTerms = false,
    this.radiusKm = 3,
  });

  final String? category;
  final String? subcategory;
  final String description;
  final List<String> mediaPaths;
  final ReportAudience audience;
  final bool useCurrentLocation;
  final double? selectedLat;
  final double? selectedLng;
  final bool agreedToTerms;
  final double radiusKm;

  ReportFormData copyWith({
    String? category,
    String? subcategory,
    String? description,
    List<String>? mediaPaths,
    ReportAudience? audience,
    bool? useCurrentLocation,
    double? selectedLat,
    double? selectedLng,
    bool? agreedToTerms,
    double? radiusKm,
  }) {
    return ReportFormData(
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      description: description ?? this.description,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      audience: audience ?? this.audience,
      useCurrentLocation: useCurrentLocation ?? this.useCurrentLocation,
      selectedLat: selectedLat ?? this.selectedLat,
      selectedLng: selectedLng ?? this.selectedLng,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
      radiusKm: radiusKm ?? this.radiusKm,
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

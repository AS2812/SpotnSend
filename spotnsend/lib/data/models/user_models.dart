enum VerificationStatus { pending, verified }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.idNumber,
    required this.selfieUrl,
    required this.status,
    this.role = 'user',
    this.reportsSubmitted = 0,
    this.feedbackGiven = 0,
    this.savedSpots = const [],
  });

  final String id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String idNumber;
  final String selfieUrl;
  final VerificationStatus status;
  final String role;
  final int reportsSubmitted;
  final int feedbackGiven;
  final List<SavedSpot> savedSpots;

  bool get isVerified => status == VerificationStatus.verified;
  bool get isGovernment => role == 'government' || role == 'admin';
  bool get isAdmin => role == 'admin';

  AppUser copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? phone,
    String? idNumber,
    String? selfieUrl,
    VerificationStatus? status,
    String? role,
    int? reportsSubmitted,
    int? feedbackGiven,
    List<SavedSpot>? savedSpots,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      idNumber: idNumber ?? this.idNumber,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      status: status ?? this.status,
      role: role ?? this.role,
      reportsSubmitted: reportsSubmitted ?? this.reportsSubmitted,
      feedbackGiven: feedbackGiven ?? this.feedbackGiven,
      savedSpots: savedSpots ?? this.savedSpots,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ??
            json['accountStatus'] ??
            json['account_status'] ??
            'pending')
        .toString();
    final normalizedStatus = statusRaw.trim().toLowerCase();
    final boolStatus = _coerceBool(json['isVerified']) ||
        _coerceBool(json['is_verified']) ||
        _coerceBool(json['verified']) ||
        _coerceBool(json['email_verified']) ||
        _coerceBool(json['contactVerified']) ||
        _coerceBool(json['contact_verified']);
    final isVerified = boolStatus ||
        normalizedStatus == 'verified' ||
        normalizedStatus == 'approved';

    final phoneCountryCode =
        (json['phoneCountryCode'] ?? json['phone_country_code'])?.toString();
    final phoneNumber = (json['phone'] ?? json['phone_number'])?.toString();
    final phoneParts = [phoneCountryCode, phoneNumber]
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .toList();

    final savedSpotsJson = json['savedSpots'] ?? json['favoriteSpots'];
    final roleRaw =
        (json['role'] ?? json['userRole'] ?? json['user_role'] ?? 'user')
            .toString();
    final normalizedRole =
        roleRaw.trim().isEmpty ? 'user' : roleRaw.trim().toLowerCase();

    return AppUser(
      id: (json['id'] ?? json['userId'] ?? json['user_id'] ?? '').toString(),
      name: (json['name'] ?? json['fullName'] ?? json['full_name'] ?? '')
          .toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: phoneParts.join(' '),
      idNumber: (json['idNumber'] ?? json['id_number'] ?? '').toString(),
      selfieUrl: (json['selfieUrl'] ?? json['selfie_url'] ?? '').toString(),
      status:
          isVerified ? VerificationStatus.verified : VerificationStatus.pending,
      role: normalizedRole,
      reportsSubmitted:
          _coerceInt(json['reportsSubmitted'] ?? json['reports_count']) ?? 0,
      feedbackGiven:
          _coerceInt(json['feedbackGiven'] ?? json['feedback_count']) ?? 0,
      savedSpots: savedSpotsJson is List
          ? savedSpotsJson
              .whereType<Map<String, dynamic>>()
              .map(SavedSpot.fromJson)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'idNumber': idNumber,
      'selfieUrl': selfieUrl,
      'status': status.name,
      'role': role,
      'reportsSubmitted': reportsSubmitted,
      'feedbackGiven': feedbackGiven,
      'savedSpots': savedSpots.map((spot) => spot.toJson()).toList(),
    };
  }
}

int? _coerceInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class SavedSpot {
  const SavedSpot({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.radiusMeters,
    this.createdAt,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final double? radiusMeters;
  final DateTime? createdAt;

  factory SavedSpot.fromJson(Map<String, dynamic> json) {
    final radius =
        json['radius'] ?? json['radiusMeters'] ?? json['radius_meters'];
    final created = json['createdAt'] ?? json['created_at'];
    return SavedSpot(
      id: (json['id'] ??
              json['favoriteSpotId'] ??
              json['favorite_spot_id'] ??
              '')
          .toString(),
      name: (json['name'] ?? '').toString(),
      lat: _coerceDouble(json['lat'] ?? json['latitude']) ?? 0,
      lng: _coerceDouble(json['lng'] ?? json['longitude']) ?? 0,
      radiusMeters: radius == null ? null : _coerceDouble(radius),
      createdAt: created is String ? DateTime.tryParse(created) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        if (radiusMeters != null) 'radiusMeters': radiusMeters,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}

double? _coerceDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _coerceBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  return ['true', 't', 'yes', '1', 'verified']
      .contains(value.toString().trim().toLowerCase());
}

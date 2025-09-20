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
  final int reportsSubmitted;
  final int feedbackGiven;
  final List<SavedSpot> savedSpots;

  bool get isVerified => status == VerificationStatus.verified;

  AppUser copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? phone,
    String? idNumber,
    String? selfieUrl,
    VerificationStatus? status,
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
      reportsSubmitted: reportsSubmitted ?? this.reportsSubmitted,
      feedbackGiven: feedbackGiven ?? this.feedbackGiven,
      savedSpots: savedSpots ?? this.savedSpots,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
<<<<<<< HEAD
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      idNumber: json['idNumber'] as String,
      selfieUrl: json['selfieUrl'] as String? ?? '',
      status: (json['status'] as String) == 'verified'
          ? VerificationStatus.verified
          : VerificationStatus.pending,
      reportsSubmitted: json['reportsSubmitted'] as int? ?? 0,
      feedbackGiven: json['feedbackGiven'] as int? ?? 0,
      savedSpots: (json['savedSpots'] as List<dynamic>? ?? [])
          .map((spot) => SavedSpot.fromJson(spot as Map<String, dynamic>))
          .toList(),
=======
    final statusRaw = (json['status'] ?? json['accountStatus'] ?? json['account_status'] ?? 'pending').toString();
    final phoneCountryCode = (json['phoneCountryCode'] ?? json['phone_country_code'])?.toString();
    final phoneNumber = (json['phone'] ?? json['phone_number'])?.toString();
    final phoneParts = [phoneCountryCode, phoneNumber]
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .toList();

    final savedSpotsJson = json['savedSpots'] ?? json['favoriteSpots'];

    return AppUser(
      id: (json['id'] ?? json['userId'] ?? json['user_id'] ?? '').toString(),
      name: (json['name'] ?? json['fullName'] ?? json['full_name'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: phoneParts.join(' '),
      idNumber: (json['idNumber'] ?? json['id_number'] ?? '').toString(),
      selfieUrl: (json['selfieUrl'] ?? json['selfie_url'] ?? '').toString(),
      status: statusRaw.toLowerCase() == 'verified'
          ? VerificationStatus.verified
          : VerificationStatus.pending,
      reportsSubmitted: _coerceInt(json['reportsSubmitted'] ?? json['reports_count']) ?? 0,
      feedbackGiven: _coerceInt(json['feedbackGiven'] ?? json['feedback_count']) ?? 0,
      savedSpots: savedSpotsJson is List
          ? savedSpotsJson
              .whereType<Map<String, dynamic>>()
              .map(SavedSpot.fromJson)
              .toList()
          : const [],
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768
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
      'reportsSubmitted': reportsSubmitted,
      'feedbackGiven': feedbackGiven,
      'savedSpots': savedSpots.map((spot) => spot.toJson()).toList(),
    };
  }
}

<<<<<<< HEAD
class SavedSpot {
  const SavedSpot({required this.id, required this.name, required this.lat, required this.lng});
=======
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
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768

  final String id;
  final String name;
  final double lat;
  final double lng;
<<<<<<< HEAD

  factory SavedSpot.fromJson(Map<String, dynamic> json) {
    return SavedSpot(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
=======
  final double? radiusMeters;
  final DateTime? createdAt;

  factory SavedSpot.fromJson(Map<String, dynamic> json) {
    final radius = json['radius'] ?? json['radiusMeters'] ?? json['radius_meters'];
    final created = json['createdAt'] ?? json['created_at'];
    return SavedSpot(
      id: (json['id'] ?? json['favoriteSpotId'] ?? json['favorite_spot_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      lat: _coerceDouble(json['lat'] ?? json['latitude']) ?? 0,
      lng: _coerceDouble(json['lng'] ?? json['longitude']) ?? 0,
      radiusMeters: radius == null ? null : _coerceDouble(radius),
      createdAt: created is String ? DateTime.tryParse(created) : null,
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
<<<<<<< HEAD
      };
}
=======
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
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768

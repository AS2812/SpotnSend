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

class SavedSpot {
  const SavedSpot({required this.id, required this.name, required this.lat, required this.lng});

  final String id;
  final String name;
  final double lat;
  final double lng;

  factory SavedSpot.fromJson(Map<String, dynamic> json) {
    return SavedSpot(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
      };
}

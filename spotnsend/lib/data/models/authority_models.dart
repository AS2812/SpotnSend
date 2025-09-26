import 'package:equatable/equatable.dart';

class AuthorityContact extends Equatable {
  const AuthorityContact({
    required this.id,
    required this.name,
    this.category,
    this.subcategory,
    this.phone,
    this.email,
    this.distanceMeters,
    this.latitude,
    this.longitude,
    this.metadata = const <String, dynamic>{},
  });

  final int id;
  final String name;
  final String? category;
  final String? subcategory;
  final String? phone;
  final String? email;
  final double? distanceMeters;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> metadata;

  factory AuthorityContact.fromJson(Map<String, dynamic> json) {
    double? castDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? castInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    final id = castInt(
          json['authority_id'] ?? json['directory_id'] ?? json['id'],
        ) ??
        0;

    final metadata = Map<String, dynamic>.from(json);

    return AuthorityContact(
      id: id,
      name: (json['name'] ?? json['authority_name'] ?? 'Unknown').toString(),
      category: json['category']?.toString(),
      subcategory: json['subcategory']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      distanceMeters: castDouble(
          json['distance_m'] ?? json['distance'] ?? json['distanceMeters']),
      latitude: castDouble(json['latitude'] ?? json['lat']),
      longitude: castDouble(json['longitude'] ?? json['lng']),
      metadata: metadata,
    );
  }

  AuthorityContact copyWith({
    String? name,
    String? category,
    String? subcategory,
    String? phone,
    String? email,
    double? distanceMeters,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? metadata,
  }) {
    return AuthorityContact(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        subcategory,
        phone,
        email,
        distanceMeters,
        latitude,
        longitude,
        metadata,
      ];
}

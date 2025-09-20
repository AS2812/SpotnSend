import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/models/user_models.dart';

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});

class ReportService {
  Future<List<Report>> fetchNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    required Set<String> categories,
  }) async {
    final data = await _loadReports();
    final filtered = data.where((report) {
      final distance = _distanceInKm(lat, lng, report.lat, report.lng);
      final withinRadius = distance <= radiusKm;
      final matchesCategory = categories.isEmpty || categories.contains(report.category);
      return withinRadius && matchesCategory;
    }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered.take(20).toList();
  }

  Future<Result<Report>> submit({
    required ReportFormData formData,
    required AppUser user,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));

    if (!formData.agreedToTerms) {
      return const Failure('You must agree to the terms to continue');
    }

    if (formData.category == null || formData.subcategory == null) {
      return const Failure('Please choose a category');
    }

    final fallbackLat = 24.7136;
    final fallbackLng = 46.6753;

    final created = Report(
      id: 'rpt-${DateTime.now().millisecondsSinceEpoch}',
      category: formData.category!,
      subcategory: formData.subcategory!,
      description: formData.description,
      mediaUrls: formData.mediaPaths,
      lat: formData.selectedLat ?? fallbackLat,
      lng: formData.selectedLng ?? fallbackLng,
      createdAt: DateTime.now().toUtc(),
    );

    return Success(created);
  }

  Future<List<Report>> _loadReports() async {
    final raw = await rootBundle.loadString('fixtures/reports.json');
    final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
    return jsonList.map((item) => Report.fromJson(item as Map<String, dynamic>)).toList();
  }

  List<ReportCategory> get categories => const [
        ReportCategory(name: 'Emergency', subcategories: ['Fire', 'Medical', 'Accident']),
        ReportCategory(name: 'Infrastructure', subcategories: ['Pothole', 'Road damage', 'Broken streetlight']),
        ReportCategory(name: 'Utilities', subcategories: ['Power outage', 'Water leak', 'Gas leak']),
        ReportCategory(name: 'Environment', subcategories: ['Flooding', 'Pollution', 'Wildlife']),
        ReportCategory(name: 'Community', subcategories: ['Event', 'Noise', 'Gathering']),
        ReportCategory(name: 'Safety', subcategories: ['Suspicious activity', 'Hazard', 'Other']),
      ];

  double _distanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) + cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * (pi / 180);
}


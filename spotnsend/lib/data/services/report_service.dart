import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      categoryId: formData.categoryId ?? 0,
      categoryName: formData.category ?? 'General',
      subcategoryId: formData.subcategoryId,
      subcategoryName: formData.subcategory,
      description: formData.description,
      media: formData.mediaPaths.isEmpty
          ? null
          : formData.mediaPaths.map((path) => ReportMedia(url: path)).toList(),
      lat: formData.selectedLat ?? fallbackLat,
      lng: formData.selectedLng ?? fallbackLng,
      status: ReportStatus.submitted,
      priority: formData.priority ?? ReportPriority.normal,
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
        ReportCategory(
          id: 1,
          name: 'Emergency',
          subcategories: [
            ReportSubcategory(id: 101, name: 'Fire'),
            ReportSubcategory(id: 102, name: 'Medical'),
            ReportSubcategory(id: 103, name: 'Accident'),
          ],
        ),
        ReportCategory(
          id: 2,
          name: 'Infrastructure',
          subcategories: [
            ReportSubcategory(id: 201, name: 'Pothole'),
            ReportSubcategory(id: 202, name: 'Road damage'),
            ReportSubcategory(id: 203, name: 'Broken streetlight'),
          ],
        ),
        ReportCategory(
          id: 3,
          name: 'Utilities',
          subcategories: [
            ReportSubcategory(id: 301, name: 'Power outage'),
            ReportSubcategory(id: 302, name: 'Water leak'),
            ReportSubcategory(id: 303, name: 'Gas leak'),
          ],
        ),
        ReportCategory(
          id: 4,
          name: 'Environment',
          subcategories: [
            ReportSubcategory(id: 401, name: 'Flooding'),
            ReportSubcategory(id: 402, name: 'Pollution'),
            ReportSubcategory(id: 403, name: 'Wildlife'),
          ],
        ),
        ReportCategory(
          id: 5,
          name: 'Community',
          subcategories: [
            ReportSubcategory(id: 501, name: 'Event'),
            ReportSubcategory(id: 502, name: 'Noise'),
            ReportSubcategory(id: 503, name: 'Gathering'),
          ],
        ),
        ReportCategory(
          id: 6,
          name: 'Safety',
          subcategories: [
            ReportSubcategory(id: 601, name: 'Suspicious activity'),
            ReportSubcategory(id: 602, name: 'Hazard'),
            ReportSubcategory(id: 603, name: 'Other'),
          ],
        ),
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



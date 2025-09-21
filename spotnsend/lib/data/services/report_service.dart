import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/api_client.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

final reportServiceProvider = Provider<ReportService>((ref) {
  final client = ref.watch(apiClientProvider);
  return ReportService(client.dio);
});

class ReportService {
  ReportService(this._dio);

  final Dio _dio;

  Future<List<Report>> fetchNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    required Set<int> categoryIds,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/reports/nearby',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'radius': (radiusKm * 1000).round(),
          if (categoryIds.isNotEmpty) 'categories': categoryIds.join(','),
          'limit': 50,
          'offset': 0,
        },
      );
      final data = response.data ?? const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Report.fromJson)
          .toList(growable: false);
    } on DioException {
      // Return empty list instead of throwing to prevent UI crashes
      return const [];
    } catch (_) {
      // Return empty list for any other errors (including permission issues)
      return const [];
    }
  }

  Future<Result<Report>> submit({
    required ReportFormData formData,
    required AppUser user,
  }) async {
    if (!formData.agreedToTerms) {
      return Failure('You must agree to the terms to continue'.tr());
    }

    if (formData.categoryId == null) {
      return Failure('Please choose a category'.tr());
    }

    final fallbackSpot =
        user.savedSpots.isNotEmpty ? user.savedSpots.first : null;
    final latitude = formData.selectedLat ?? fallbackSpot?.lat ?? 24.7136;
    final longitude = formData.selectedLng ?? fallbackSpot?.lng ?? 46.6753;

    final payload = {
      'categoryId': formData.categoryId,
      if (formData.subcategoryId != null)
        'subcategoryId': formData.subcategoryId,
      'description': formData.description.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'alertRadiusMeters': (formData.radiusKm * 1000).round(),
      'notifyScope':
          _audienceToString(formData.notifyScope ?? formData.audience),
      'priority': (formData.priority ?? ReportPriority.normal).name,
    };

    try {
      final hasMedia = formData.mediaPaths.isNotEmpty;
      Response<dynamic> response;
      if (hasMedia) {
        final mediaFiles = <MultipartFile>[];
        for (final path in formData.mediaPaths) {
          if (path.isEmpty) continue;
          mediaFiles.add(await MultipartFile.fromFile(path,
              filename: path.split(Platform.pathSeparator).last));
        }
        final formDataBody = FormData.fromMap({
          ...payload,
          if (mediaFiles.isNotEmpty) 'mediaFiles': mediaFiles,
        });
        response = await _dio.post('/reports', data: formDataBody);
      } else {
        response = await _dio.post('/reports', data: payload);
      }

      final data = response.data as Map<String, dynamic>;
      return Success(Report.fromJson(data));
    } on DioException catch (error) {
      return Failure(_extractMessage(error));
    } catch (error) {
      return Failure(error.toString());
    }
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

  String _extractMessage(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      return responseData['message']?.toString() ??
          responseData['error']?.toString() ??
          'Unexpected error occurred.'.tr();
    }
    return error.message ?? 'Unexpected error occurred.'.tr();
  }

  String _audienceToString(ReportAudience audience) {
    switch (audience) {
      case ReportAudience.people:
        return 'people';
      case ReportAudience.government:
        return 'government';
      case ReportAudience.both:
        return 'both';
    }
  }
}

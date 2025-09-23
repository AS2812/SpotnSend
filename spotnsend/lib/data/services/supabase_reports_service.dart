import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/main.dart';

final supabaseReportServiceProvider = Provider<SupabaseReportService>((ref) {
  return SupabaseReportService(supabase);
});

class SupabaseReportService {
  SupabaseReportService(this._client);

  final SupabaseClient _client;

  SupabaseQueryBuilder _reports() =>
      _client.schema('civic_app').from('reports');
  SupabaseQueryBuilder _categories() =>
      _client.schema('civic_app').from('report_categories');
  SupabaseQueryBuilder _subcategories() =>
      _client.schema('civic_app').from('report_subcategories');
  SupabaseQueryBuilder _media() =>
      _client.schema('civic_app').from('report_media');

  Future<List<Report>> fetchNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    required Set<int> categoryIds,
  }) async {
    // Basic list for now (no geospatial function call, can be optimized with RPC later)
    final rows = await _reports()
        .select()
        .order('created_at', ascending: false)
        .limit(50) as List<dynamic>;
    return rows.whereType<Map<String, dynamic>>().map(Report.fromJson).toList();
  }

  Future<Result<Report>> submit({
    required ReportFormData formData,
    required AppUser user,
  }) async {
    if (!formData.agreedToTerms) {
      return const Failure('You must agree to the terms to continue');
    }
    if (formData.categoryId == null) {
      return const Failure('Please choose a category');
    }

    try {
      // Create report (using simple function for now)
      final result = await _client.rpc('create_report_simple', params: {
        'p_category_id': formData.categoryId,
        'p_subcategory_id': formData.subcategoryId,
        'p_description': formData.description.trim(),
        'p_lat':
            formData.selectedLat ?? user.savedSpots.firstOrNull?.lat ?? 24.7136,
        'p_lng':
            formData.selectedLng ?? user.savedSpots.firstOrNull?.lng ?? 46.6753,
        'p_radius': (formData.radiusKm * 1000).round(),
        'p_priority': (formData.priority ?? ReportPriority.normal).name,
        'p_notify': (formData.notifyScope ?? formData.audience).name,
      });

      final reportId = result['report_id'] as int;
      final fetched =
          await _reports().select().eq('report_id', reportId).single();
      var report = Report.fromJson(fetched);

      // Upload media if any
      if (formData.mediaPaths.isNotEmpty) {
        for (final path in formData.mediaPaths) {
          final file = File(path);
          if (!await file.exists()) continue;
          final ext = path.split('.').last;
          final storagePath =
              'reports/${report.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
          final bytes = await file.readAsBytes();
          await _client.storage
              .from('report-media')
              .uploadBinary(storagePath, bytes);
          await _media().insert({
            'report_id': report.id,
            'media_type': 'image',
            'storage_url': storagePath,
          });
        }
      }

      return Success(report);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<List<ReportCategory>> loadCategories() async {
    final cats = await _categories()
        .select('category_id,name')
        .order('sort_order') as List<dynamic>;
    final subs = await _subcategories()
        .select('subcategory_id,category_id,name')
        .order('sort_order') as List<dynamic>;
    final subByCat = <int, List<ReportSubcategory>>{};
    for (final row in subs.whereType<Map<String, dynamic>>()) {
      final catId = (row['category_id'] as num).toInt();
      (subByCat[catId] ??= []).add(ReportSubcategory(
          id: (row['subcategory_id'] as num).toInt(),
          name: (row['name'] ?? '').toString()));
    }

    return cats.whereType<Map<String, dynamic>>().map((row) {
      final id = (row['category_id'] as num).toInt();
      return ReportCategory(
          id: id,
          name: (row['name'] ?? '').toString(),
          subcategories: subByCat[id] ?? const []);
    }).toList(growable: false);
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

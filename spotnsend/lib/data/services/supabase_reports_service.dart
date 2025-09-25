// lib/data/services/supabase_reports_service.dart
import 'dart:io' show File; // safe: we guard usage on !kIsWeb
import 'package:flutter/foundation.dart';
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

  SupabaseQueryBuilder _reports() => _client.from('reports');
  SupabaseQueryBuilder _categories() => _client.from('report_categories');
  SupabaseQueryBuilder _subcategories() =>
    _client.from('report_subcategories');
  SupabaseQueryBuilder _media() => _client.from('report_media');

  /// Nearby reports via RPC with radius (meters) and optional category filter.
  Future<List<Report>> fetchNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    required Set<int> categoryIds,
  }) async {
    // Call the RPC; pass null for categories when empty.
    final params = <String, dynamic>{
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_m': (radiusKm * 1000).round(),
      if (categoryIds.isNotEmpty) 'p_category_ids': categoryIds.toList(),
    };

  final result = await _client.rpc('reports_nearby', params: params);

    // Supabase returns a List<dynamic> for set-returning functions
    final rows = (result is List) ? result : const <dynamic>[];

    return rows
        .whereType<Map<String, dynamic>>()
        .map(_normalizeNearbyRow)
        .map(Report.fromJson)
        .toList(growable: false);
  }

  /// Create a report using the simple RPC.
  /// Also uploads media (mobile/desktop only; web is skipped by design).
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
      final lat =
          formData.selectedLat ?? user.savedSpots.firstOrNull?.lat ?? 24.7136;
      final lng =
          formData.selectedLng ?? user.savedSpots.firstOrNull?.lng ?? 46.6753;

      final notifyScope = (formData.notifyScope ?? formData.audience).name;
      final priority = (formData.priority ?? ReportPriority.normal).name;

  final result = await _client.rpc('create_report_simple', params: {
        'p_category_id': formData.categoryId,
        'p_subcategory_id': formData.subcategoryId,
        'p_description': formData.description.trim(),
        'p_lat': lat,
        'p_lng': lng,
        'p_radius': (formData.radiusKm * 1000).round(),
        'p_priority': priority,
        'p_notify': notifyScope,
      });

      // The RPC may return the inserted row or just an id. Handle both.
      Map<String, dynamic>? insertedRow;
      int? newId;

      if (result is Map<String, dynamic>) {
        // If it already looks like a full row
        if (result.containsKey('report_id')) {
          insertedRow = result;
          newId = _asInt(result['report_id']);
        } else if (result.values.length == 1 && result.values.first is int) {
          newId = _asInt(result.values.first);
        }
      } else if (result is List && result.isNotEmpty) {
        final first = result.first;
        if (first is Map<String, dynamic>) {
          insertedRow = first;
          newId = _asInt(first['report_id']);
        }
      } else if (result is int) {
        newId = result;
      } else if (result is num) {
        newId = result.toInt();
      }

      // Ensure we have a full row to parse
      Map<String, dynamic> row;
      if (insertedRow != null) {
        row = insertedRow;
      } else if (newId != null) {
        row = await _reports().select().eq('report_id', newId).single();
      } else {
        return const Failure(
            'Unexpected response from server while creating report');
      }

      var report = Report.fromJson(row);

      // Upload media (skip on web to avoid dart:io issues)
      if (!kIsWeb && formData.mediaPaths.isNotEmpty) {
        for (final path in formData.mediaPaths) {
          try {
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
          } catch (_) {
            // Non-fatal: continue with next file
          }
        }

        // (Optional) re-fetch media URLs for the report if your model shows them
        // final mediaRows = await _media().select().eq('report_id', report.id);
        // report = report.copyWith(
        //   mediaUrls: mediaRows
        //       .whereType<Map<String, dynamic>>()
        //       .map((m) => (m['storage_url'] ?? '').toString())
        //       .where((s) => s.isNotEmpty)
        //       .toList(),
        // );
      }

      return Success(report);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// All categories with their subcategories (for the Report form).
  Future<List<ReportCategory>> loadCategories() async {
    final cats = await _categories()
        .select('category_id,name,sort_order')
        .order('sort_order', ascending: true) as List<dynamic>;

    final subs = await _subcategories()
        .select('subcategory_id,category_id,name,sort_order')
        .order('sort_order', ascending: true) as List<dynamic>;

    final subByCat = <int, List<ReportSubcategory>>{};
    for (final row in subs.whereType<Map<String, dynamic>>()) {
      final catId = _asInt(row['category_id'])!;
      (subByCat[catId] ??= []).add(
        ReportSubcategory(
          id: _asInt(row['subcategory_id'])!,
          name: (row['name'] ?? '').toString(),
        ),
      );
    }

    return cats.whereType<Map<String, dynamic>>().map((row) {
      final id = _asInt(row['category_id'])!;
      return ReportCategory(
        id: id,
        name: (row['name'] ?? '').toString(),
        subcategories: subByCat[id] ?? const [],
      );
    }).toList(growable: false);
  }

  /// Convert the RPC row into the shape expected by Report.fromJson.
  Map<String, dynamic> _normalizeNearbyRow(Map<String, dynamic> row) {
    final m = Map<String, dynamic>.from(row);

    // standardize keys
    m['id'] = m['id'] ?? m['report_id'];
    m['lat'] = m['lat'] ?? m['latitude'];
    m['lng'] = m['lng'] ?? m['longitude'];
    m['category'] = m['category'] ?? m['category_name'];
    m['subcategory'] = m['subcategory'] ?? m['subcategory_name'];
    m['priority'] = (m['priority'] ?? '').toString();
    m['status'] = (m['status'] ?? '').toString();

    // createdAt variations
    final created = m['createdAt'] ?? m['created_at'];
    if (created != null) {
      m['createdAt'] = created.toString();
    }

    return m;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

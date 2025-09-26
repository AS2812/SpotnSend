// lib/data/services/supabase_reports_service.dart
import 'dart:io' show File; // safe: we guard usage on !kIsWeb
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/main.dart';

const Set<String> _defaultStatusFilters = {
  'submitted',
  'under_review',
  'approved',
};

const Set<String> _allowedStatusFilters = {
  ..._defaultStatusFilters,
  'resolved',
  'in_progress',
  'pending',
};

final supabaseReportServiceProvider = Provider<SupabaseReportService>((ref) {
  return SupabaseReportService(supabase);
});

class SupabaseReportService {
  SupabaseReportService(this._client);

  final SupabaseClient _client;

  SupabaseQueryBuilder _reports() => _client.from('reports');
  SupabaseQueryBuilder _categories() => _client.from('report_categories');
  SupabaseQueryBuilder _subcategories() => _client.from('report_subcategories');
  SupabaseQueryBuilder _media() => _client.from('report_media');

  /// Nearby reports via RPC with radius (meters) and optional filters.
  Future<List<Report>> fetchNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    Set<int>? categoryIds,
    Set<int>? subcategoryIds,
    Set<String>? statuses,
    int limit = 50,
    int offset = 0,
    bool includeCurrentUser = true,
    bool viewerIsGovernment = false,
  }) async {
    final radiusM = (radiusKm * 1000).round();

    final categories = categoryIds?.toList(growable: false) ?? const <int>[];

    final subs = subcategoryIds?.toList(growable: false) ?? const <int>[];

    final Iterable<String> rawStatuses = (statuses == null || statuses.isEmpty)
        ? _defaultStatusFilters
        : statuses;
    final sanitizedStatuses = rawStatuses
        .map(_normalizeStatusLabel)
        .whereType<String>()
        .where(_allowedStatusFilters.contains)
        .toSet()
        .toList(growable: false);

    int? currentUserId;

    if (includeCurrentUser) {
      currentUserId = await _currentUserId();
    }

    try {
      final params = <String, dynamic>{
        'p_latitude': lat,
        'p_longitude': lng,
        'p_radius_meters': radiusM,
        'p_limit': limit,
        'p_offset': offset,
      };

      if (categories.isNotEmpty) params['p_category_ids'] = categories;

      if (subs.isNotEmpty) params['p_subcategory_ids'] = subs;

      if (sanitizedStatuses.isNotEmpty)
        params['p_statuses'] = sanitizedStatuses;

      final result = await _client.rpc('find_reports_nearby', params: params);

      return _mapReportsFromResult(
        result,
        viewerId: includeCurrentUser ? currentUserId : null,
        viewerIsGovernment: viewerIsGovernment,
        subcategoryFilter: subs.isEmpty ? null : subs.toSet(),
        statusFilter:
            sanitizedStatuses.isEmpty ? null : sanitizedStatuses.toSet(),
      );
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint('find_reports_nearby failed: ${e.message}');
      }

      final fallbackParams = <String, dynamic>{
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_m': radiusM,
      };

      if (categories.isNotEmpty) fallbackParams['p_category_ids'] = categories;

      if (includeCurrentUser && currentUserId != null) {
        fallbackParams['p_current_user_id'] = currentUserId;
      }

      final fallback =
          await _client.rpc('reports_nearby', params: fallbackParams);

      return _mapReportsFromResult(
        fallback,
        viewerId: includeCurrentUser ? currentUserId : null,
        viewerIsGovernment: viewerIsGovernment,
        subcategoryFilter: subs.isEmpty ? null : subs.toSet(),
        statusFilter:
            sanitizedStatuses.isEmpty ? null : sanitizedStatuses.toSet(),
      );
    }
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

      return await _executeReportInsert(
        rpcName: 'create_report_simple',
        params: {
          'p_category_id': formData.categoryId,
          'p_subcategory_id': formData.subcategoryId,
          'p_description': formData.description.trim(),
          'p_lat': lat,
          'p_lng': lng,
          'p_radius': (formData.radiusKm * 1000).round(),
          'p_priority': priority,
          'p_notify': notifyScope,
        },
        formData: formData,
        user: user,
      );
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Alternate entrypoint for the full-fat `create_report` RPC.
  Future<Result<Report>> submitDetailed({
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

      return await _executeReportInsert(
        rpcName: 'create_report',
        params: {
          'p_category_id': formData.categoryId,
          'p_subcategory_id': formData.subcategoryId,
          'p_description': formData.description.trim(),
          'p_lat': lat,
          'p_lng': lng,
          'p_radius': (formData.radiusKm * 1000).round(),
          'p_priority': priority,
          'p_notify': notifyScope,
        },
        formData: formData,
        user: user,
      );
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<Report>> _executeReportInsert({
    required String rpcName,
    required Map<String, dynamic> params,
    required ReportFormData formData,
    required AppUser user,
  }) async {
    final result = await _client.rpc(rpcName, params: params);

    Map<String, dynamic>? insertedRow;
    int? newId;

    if (result is Map<String, dynamic>) {
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

    Map<String, dynamic> row;
    if (insertedRow != null) {
      row = insertedRow;
    } else if (newId != null) {
      row = await _reports().select().eq('report_id', newId).single();
    } else {
      return const Failure(
          'Unexpected response from server while creating report');
    }

    // Ensure downstream consumers receive category metadata so newly created
    // markers can render with the correct icon immediately.
    row['report_id'] = row['report_id'] ?? newId;
    row['category_id'] = row['category_id'] ?? formData.categoryId;
    row['category_name'] =
        row['category_name'] ?? formData.categoryName ?? row['category'] ?? '';
    row['category'] = row['category'] ?? row['category_name'];
    row['subcategory_id'] = row['subcategory_id'] ?? formData.subcategoryId;
    row['subcategory_name'] = row['subcategory_name'] ??
        formData.subcategoryName ??
        row['subcategory'];
    row['notify_scope'] =
        row['notify_scope'] ?? (formData.notifyScope ?? formData.audience).name;
    row['user_id'] = row['user_id'] ??
        row['owner_user_id'] ??
        row['created_by'] ??
        _asInt(user.id) ??
        user.id;
    row['notifyScope'] = row['notifyScope'] ?? row['notify_scope'];
    row['owner_user_id'] = row['owner_user_id'] ?? row['user_id'];

    row['subcategory'] = row['subcategory'] ?? row['subcategory_name'] ?? '';

    var report = Report.fromJson(row);

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
    }

    return Success(report);
  }

  /// All categories with their subcategories (for the Report form).
  Future<List<ReportCategory>> loadCategories() async {
    final cats = await _categories()
        .select('category_id,name,slug,sort_order')
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
        slug: (row['slug'] ?? '').toString(),
        subcategories: subByCat[id] ?? const [],
      );
    }).toList(growable: false);
  }

  Future<int?> _currentUserId() async {
    if (_client.auth.currentUser == null) return null;
    try {
      final result = await _client.rpc('current_user_id');
      if (result is int) return result;
      if (result is num) return result.toInt();
    } catch (_) {
      // Optional helper; safe to ignore failures
    }
    return null;
  }

  List<Report> _mapReportsFromResult(
    dynamic result, {
    int? viewerId,
    bool viewerIsGovernment = false,
    Set<int>? subcategoryFilter,
    Set<String>? statusFilter,
  }) {
    final rows = (result is List) ? result : const <dynamic>[];
    final reports = rows
        .whereType<Map<String, dynamic>>()
        .map(_normalizeNearbyRow)
        .map((row) {
          try {
            return Report.fromJson(row);
          } catch (err, stack) {
            if (kDebugMode) {
              debugPrint('Failed to parse report row: $err');
              debugPrintStack(stackTrace: stack);
            }
            return null;
          }
        })
        .whereType<Report>()
        .toList(growable: false);

    Iterable<Report> filtered = reports;
    if (subcategoryFilter != null && subcategoryFilter.isNotEmpty) {
      filtered = filtered.where((report) =>
          report.subcategoryId != null &&
          subcategoryFilter.contains(report.subcategoryId));
    }
    if (statusFilter != null && statusFilter.isNotEmpty) {
      final normalized =
          statusFilter.map((e) => e.trim().toLowerCase()).toSet();
      filtered = filtered
          .where(
              (report) => normalized.contains(report.status.name.toLowerCase()))
          .toList(growable: false);
    }
    if (viewerId != null || viewerIsGovernment) {
      filtered = filtered.where((report) => report.canBeSeenBy(
            userId: viewerId,
            isGovernment: viewerIsGovernment,
          ));
    }
    return filtered.toList(growable: false);
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
    m['notify_scope'] =
        (m['notify_scope'] ?? m['notifyScope'] ?? m['notify'] ?? '').toString();
    m['user_id'] =
        m['user_id'] ?? m['userId'] ?? m['owner_user_id'] ?? m['created_by'];
    m['distanceMeters'] =
        m['distanceMeters'] ?? m['distance_meters'] ?? m['distance_m'];

    // createdAt variations
    final created = m['createdAt'] ?? m['created_at'];
    if (created != null) {
      m['createdAt'] = created.toString();
    }

    return m;
  }

  /// Ask Postgres to calculate the great-circle distance between two points
  /// using the database's `haversine_m` helper. Returns meters or null if the
  /// function is unavailable.
  Future<double?> distanceMeters({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final result = await _client.rpc('haversine_m', params: {
      'lat1': fromLat,
      'lon1': fromLng,
      'lat2': toLat,
      'lon2': toLng,
    });

    if (result is num) return result.toDouble();
    if (result is String) return double.tryParse(result);
    return null;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

String? _normalizeStatusLabel(String raw) {
  final cleaned = raw.trim().toLowerCase();
  if (cleaned.isEmpty) return null;
  final canonical = cleaned.replaceAll(RegExp(r'[^a-z_]'), '');
  if (canonical.isEmpty) return null;
  switch (canonical) {
    case 'underreview':
    case 'inreview':
    case 'review':
      return 'under_review';
    case 'inprogress':
    case 'progress':
      return 'in_progress';
    case 'open':
    case 'new':
      return 'submitted';
    default:
      return canonical;
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

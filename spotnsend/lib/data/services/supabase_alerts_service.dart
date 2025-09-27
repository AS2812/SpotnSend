import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/alert_models.dart';
import 'package:spotnsend/main.dart';

final supabaseAlertsServiceProvider = Provider<SupabaseAlertsService>((ref) {
  return SupabaseAlertsService(supabase);
});

class SupabaseAlertsService {
  SupabaseAlertsService(this._client);

  final SupabaseClient _client;

  SupabaseQueryBuilder _alerts() => _client.from('alerts');

  Future<List<Alert>> fetchNearby({
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    try {
      final rows = await _client.rpc('alerts_nearby', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius': (radiusKm * 1000).round(),
      }) as List<dynamic>;

      return rows
          .whereType<Map<String, dynamic>>()
          .map(Alert.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      if (_isMissingAlertsTable(e)) {
        return const [];
      }
      return _fallbackAlertsList();
    } catch (_) {
      return _fallbackAlertsList();
    }
  }

  Future<List<Alert>> _fallbackAlertsList() async {
    try {
    final rows = await _alerts()
      .select()
      .eq('status', 'active')
      .order('updated_at', ascending: false)
          .limit(50) as List<dynamic>;

      return rows
          .whereType<Map<String, dynamic>>()
          .map(Alert.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      if (_isMissingAlertsTable(e)) {
        return const [];
      }
      rethrow;
    }
  }

  bool _isMissingAlertsTable(PostgrestException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();
    return code == 'PGRST205' ||
        (message.contains('could not find the table') &&
            message.contains('alerts'));
  }

  Future<List<Alert>> fetchAll({int limit = 50}) async {
  final rows = await _alerts()
    .select()
    .eq('status', 'active')
    .order('updated_at', ascending: false)
    .limit(limit) as List<dynamic>;

    return rows.whereType<Map<String, dynamic>>().map(Alert.fromJson).toList();
  }

  Future<Result<void>> createFromReport({
    required String reportId,
    required String title,
    required String description,
    required String category,
    required String subcategory,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String severity,
    required String notifyScope,
  }) async {
    try {
      await _client.rpc('create_alert_from_report', params: {
        'p_report_id': reportId,
        'p_title': title,
        'p_description': description,
        'p_category': category,
        'p_subcategory': subcategory,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_meters': radiusMeters,
        'p_severity': severity,
        'p_notify_scope': notifyScope,
      });
      return const Success<void>(null);
    } on PostgrestException catch (e) {
      final message = e.message;
      if (message.contains('create_alert_from_report')) {
        return const Success<void>(null);
      }
      return Failure(message.isNotEmpty ? message : 'Unknown Supabase error');
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Future<Result<void>> resolveAlert(String alertId) async {
    try {
      await _client.rpc('resolve_alert', params: {
        'p_alert_id': alertId,
      });
      return const Success<void>(null);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  Stream<List<Alert>> subscribeToAlerts() {
    return _alerts().stream(primaryKey: ['alert_id']).map((data) =>
        data.whereType<Map<String, dynamic>>().map(Alert.fromJson).toList());
  }
}

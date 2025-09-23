import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotnsend/data/models/alert_models.dart';
import 'package:spotnsend/data/services/supabase_alerts_service.dart';

final nearbyAlertsProvider =
    FutureProvider.family<List<Alert>, Map<String, double>>(
        (ref, params) async {
  final alertsService = ref.watch(supabaseAlertsServiceProvider);
  return alertsService.fetchNearby(
    lat: params['lat']!,
    lng: params['lng']!,
    radiusKm: params['radiusKm'] ?? 10.0,
  );
});

final allAlertsProvider = FutureProvider<List<Alert>>((ref) async {
  final alertsService = ref.watch(supabaseAlertsServiceProvider);
  return alertsService.fetchAll();
});

final alertsControllerProvider = Provider<AlertsController>((ref) {
  final alertsService = ref.watch(supabaseAlertsServiceProvider);
  return AlertsController(ref: ref, alertsService: alertsService);
});

class AlertsController {
  AlertsController({required this.ref, required this.alertsService});

  final Ref ref;
  final SupabaseAlertsService alertsService;

  Future<void> refreshAlerts() async {
    ref.invalidate(nearbyAlertsProvider);
    ref.invalidate(allAlertsProvider);
  }

  Future<void> resolveAlert(String alertId) async {
    final result = await alertsService.resolveAlert(alertId);
    result.when(
      success: (_) => refreshAlerts(),
      failure: (message) => print('Failed to resolve alert: $message'),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotnsend/data/models/alert_models.dart';
import 'package:spotnsend/data/services/supabase_alerts_service.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';

final nearbyAlertsProvider =
    FutureProvider.autoDispose<List<Alert>>((ref) async {
  final alertsService = ref.watch(supabaseAlertsServiceProvider);
  final filters = ref.watch(mapFiltersProvider);
  final location = await ref.watch(currentLocationProvider.future);

  const fallbackLat = 24.7136;
  const fallbackLng = 46.6753;

  final lat = (location?.latitude ?? fallbackLat).toDouble();
  final lng = (location?.longitude ?? fallbackLng).toDouble();

  final alerts = await alertsService.fetchNearby(
    lat: lat,
    lng: lng,
    radiusKm: filters.radiusKm,
  );

  return alerts
      .where((alert) => alert.status == AlertStatus.active)
      .toList(growable: false);
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotnsend/data/models/alert_models.dart';
import 'package:spotnsend/data/services/supabase_alerts_service.dart';

/// Fetch alerts near a specific location
final nearbyAlertsProvider =
    FutureProvider.family<List<Alert>, Map<String, dynamic>>(
  (ref, params) async {
    final service = ref.watch(supabaseAlertsServiceProvider);
    return service.fetchNearby(
      lat: params['lat'] as double,
      lng: params['lng'] as double,
      radiusKm: params['radiusKm'] as double,
    );
  },
);

/// All alerts with auto-refresh
final alertsControllerProvider =
    AsyncNotifierProvider<AlertsController, List<Alert>>(() {
  return AlertsController();
});

class AlertsController extends AsyncNotifier<List<Alert>> {
  @override
  Future<List<Alert>> build() async {
    final service = ref.read(supabaseAlertsServiceProvider);

    // Set up a realtime subscription
    service.subscribeToAlerts().listen((alerts) {
      // Only update if we've already built once (to avoid double loading)
      if (state.isLoading == false) {
        state = AsyncData(alerts);
      }
    });

    // Return initial data
    return service.fetchAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final service = ref.read(supabaseAlertsServiceProvider);
    state = AsyncData(await service.fetchAll());
  }
}

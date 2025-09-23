import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/services/maptiler_service.dart';
import 'package:spotnsend/data/services/supabase_reports_service.dart';
import 'package:spotnsend/main.dart';

/// ----------------------
/// Location permissions
/// ----------------------

final locationServiceProvider = Provider<Location>((ref) => Location());

final locationPermissionProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final location = ref.watch(locationServiceProvider);
  bool serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      return false;
    }
  }

  var permissionStatus = await location.hasPermission();
  if (permissionStatus == PermissionStatus.denied) {
    permissionStatus = await location.requestPermission();
  }

  return permissionStatus == PermissionStatus.granted ||
      permissionStatus == PermissionStatus.grantedLimited;
});

final currentLocationProvider =
    FutureProvider.autoDispose<LocationData?>((ref) async {
  final hasPermission = await ref.watch(locationPermissionProvider.future);
  if (!hasPermission) return null;
  final location = ref.watch(locationServiceProvider);
  return location.getLocation();
});

/// ----------------------
/// Map filters / UI state
/// ----------------------

final mapFiltersProvider =
    NotifierProvider<MapFiltersNotifier, ReportFilters>(() {
  return MapFiltersNotifier();
});

class MapFiltersNotifier extends Notifier<ReportFilters> {
  @override
  ReportFilters build() {
    return const ReportFilters(
      radiusKm: 3,
      categoryIds: <int>{},
      includeSavedSpots: true,
    );
  }

  void setRadius(double radius) {
    final clamped = radius.clamp(1, 20);
    state = state.copyWith(radiusKm: clamped.toDouble());
  }

  void toggleCategory(int categoryId) {
    final updated = Set<int>.from(state.categoryIds);
    if (!updated.add(categoryId)) {
      updated.remove(categoryId);
    }
    state = state.copyWith(categoryIds: updated);
  }

  void clearCategories() {
    state = state.copyWith(categoryIds: <int>{});
  }

  void toggleSavedSpots(bool enabled) {
    state = state.copyWith(includeSavedSpots: enabled);
  }
}

final mapStyleUrlProvider = Provider<String>((ref) {
  final service = ref.watch(mapTilerServiceProvider);
  return service.styleUrl;
});

/// false = map, true = list
final mapViewModeProvider =
    NotifierProvider<MapViewModeNotifier, bool>(() => MapViewModeNotifier());

/// Which report is currently selected on the map
final selectedReportProvider =
    NotifierProvider<SelectedReportNotifier, String?>(
        () => SelectedReportNotifier());

class MapViewModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setMap() => state = false;
  void setList() => state = true;
}

class SelectedReportNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? reportId) => state = reportId;
  void clear() => state = null;
}

/// -----------------------------------------
/// Live list of reports for the map (realtime)
/// -----------------------------------------
///
/// - Loads initial batch using your SupabaseReportsService.fetchNearby()
/// - Subscribes to INSERT on civic_app.reports and adds pins instantly
/// - RLS controls who receives government-only reports
///
final mapReportsControllerProvider =
    AsyncNotifierProvider.autoDispose<MapReportsController, List<Report>>(
        () => MapReportsController());

class MapReportsController extends AsyncNotifier<List<Report>> {
  sb.RealtimeChannel? _channel;

  @override
  Future<List<Report>> build() async {
    // Read dependencies for the initial fetch
    final reportService = ref.read(supabaseReportServiceProvider);
    final filters = ref.read(mapFiltersProvider);
    final loc = await ref.read(currentLocationProvider.future);

    const fallbackLat = 24.7136;
    const fallbackLng = 46.6753;
    final lat = loc?.latitude ?? fallbackLat;
    final lng = loc?.longitude ?? fallbackLng;

    // Initial list (same as your old nearbyReportsProvider)
    final initial = await reportService.fetchNearby(
      lat: lat,
      lng: lng,
      radiusKm: filters.radiusKm,
      categoryIds: filters.categoryIds,
    );

    // Start realtime after initial fetch
    _startRealtime();

    // Clean up channel when provider is disposed
    ref.onDispose(() async {
      await _channel?.unsubscribe();
      _channel = null;
    });

    return initial;
  }

  void _startRealtime() {
    if (_channel != null) return;

    final ch = supabase.channel('reports-live');

    ch.onPostgresChanges(
      event: sb.PostgresChangeEvent.insert,
      schema: 'civic_app',
      table: 'reports',
      callback: (payload) {
        final row = payload.newRecord;

        try {
          // RLS already filtered: non-gov users won't receive gov-only rows.
          final incoming = Report.fromJson(row);

          // Merge into current state (de-dup on id)
          final cur = state.value ?? const <Report>[];
          final idx = cur.indexWhere((r) => r.id == incoming.id);
          if (idx == -1) {
            state = AsyncData([incoming, ...cur]);
          } else {
            final copy = List<Report>.from(cur);
            copy[idx] = incoming;
            state = AsyncData(copy);
          }
        } catch (e) {
          // Ignore malformed reports
          print('Error processing realtime report: $e');
        }
      },
    );

    ch.subscribe();
    _channel = ch;
  }

  /// Allow optimistic add from the Report submit flow
  void addOrReplace(Report r) {
    final cur = state.value ?? const <Report>[];
    final idx = cur.indexWhere((e) => e.id == r.id);
    if (idx == -1) {
      state = AsyncData([r, ...cur]);
    } else {
      final copy = List<Report>.from(cur);
      copy[idx] = r;
      state = AsyncData(copy);
    }
  }
}

/// -----------------------------------------
/// (Optional) simple fetch-only list
/// If you still want the old behavior somewhere else,
/// keep this provider. Otherwise you can delete it.
/// -----------------------------------------
final nearbyReportsProvider =
    FutureProvider.autoDispose<List<Report>>((ref) async {
  final reportService = ref.watch(supabaseReportServiceProvider);
  final filters = ref.watch(mapFiltersProvider);
  final locationData = await ref.watch(currentLocationProvider.future);
  const fallbackLat = 24.7136;
  const fallbackLng = 46.6753;
  final lat = locationData?.latitude ?? fallbackLat;
  final lng = locationData?.longitude ?? fallbackLng;

  return reportService.fetchNearby(
    lat: lat,
    lng: lng,
    radiusKm: filters.radiusKm,
    categoryIds: filters.categoryIds,
  );
});

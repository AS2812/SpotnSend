import 'dart:async';
import 'dart:math' as math;

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

  var serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) return false;
  }

  var status = await location.hasPermission();
  if (status == PermissionStatus.denied) {
    status = await location.requestPermission();
  }

  return status == PermissionStatus.granted ||
      status == PermissionStatus.grantedLimited;
});

final currentLocationProvider =
    FutureProvider.autoDispose<LocationData?>((ref) async {
  final ok = await ref.watch(locationPermissionProvider.future);
  if (!ok) return null;
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

  void setRadius(double radiusKm) {
    final clamped = radiusKm.clamp(1, 20).toDouble();
    state = state.copyWith(radiusKm: clamped);
  }

  void toggleCategory(int id) {
    final next = Set<int>.from(state.categoryIds);
    if (!next.add(id)) next.remove(id);
    state = state.copyWith(categoryIds: next);
  }

  void clearCategories() {
    state = state.copyWith(categoryIds: const {});
  }

  void toggleSavedSpots(bool enabled) {
    state = state.copyWith(includeSavedSpots: enabled);
  }
}

final mapStyleUrlProvider = Provider<String>((ref) {
  final svc = ref.watch(mapTilerServiceProvider);
  return svc.styleUrl;
});

/// false = map, true = list
final mapViewModeProvider =
    NotifierProvider<MapViewModeNotifier, bool>(() => MapViewModeNotifier());

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
  void select(String? id) => state = id;
  void clear() => state = null;
}

/// ----------------------
/// Live reports controller
/// ----------------------

final mapReportsControllerProvider =
    AsyncNotifierProvider.autoDispose<MapReportsController, List<Report>>(
        () => MapReportsController());

class MapReportsController extends AsyncNotifier<List<Report>> {
  sb.RealtimeChannel? _channel;

  // Current query params to keep realtime consistent with the UI.
  _QueryParams? _params;

  @override
  Future<List<Report>> build() async {
    // Re-fetch when filters change
    ref.listen<ReportFilters>(mapFiltersProvider, (_, __) async {
      await _reload();
    });

    // Re-fetch when location resolves/changes
    ref.listen<AsyncValue<LocationData?>>(currentLocationProvider,
        (prev, next) async {
      final prevLat = prev?.value?.latitude;
      final prevLng = prev?.value?.longitude;
      final nextLat = next.hasValue ? next.value?.latitude : null;
      final nextLng = next.hasValue ? next.value?.longitude : null;
      if (prevLat != nextLat || prevLng != nextLng) {
        await _reload();
      }
    });

    // Ensure cleanup
    ref.onDispose(() async {
      await _channel?.unsubscribe();
      _channel = null;
    });

    return _reload();
  }

  Future<List<Report>> _reload() async {
    final svc = ref.read(supabaseReportServiceProvider);
    final filters = ref.read(mapFiltersProvider);
    final loc = await ref.read(currentLocationProvider.future);

    const fallbackLat = 24.7136;
    const fallbackLng = 46.6753;

    final lat = (loc?.latitude ?? fallbackLat).toDouble();
    final lng = (loc?.longitude ?? fallbackLng).toDouble();
    final radiusKm = filters.radiusKm;
    final categories = filters.categoryIds;

    _params = _QueryParams(
      lat: lat,
      lng: lng,
      radiusM: (radiusKm * 1000).round(),
      categoryIds: categories,
    );

    // Load via RPC in the service (respects radius & categories)
    final data = await svc.fetchNearby(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      categoryIds: categories,
    );

    // Start/refresh realtime after we know params
    _startRealtime();

    state = AsyncData(data);
    return data;
  }

  void _startRealtime() {
    // Re-use channel if already active
    if (_channel != null) return;

    final ch = supabase.channel('realtime:reports');

    // INSERT / UPDATE: merge if it matches current filters
    void _upsert(Map<String, dynamic> row) {
      final r = Report.fromJson(row);
      final p = _params;
      if (p == null) return;

      // Client-side guards for the live feed
      if (!_categoryAllowed(r, p.categoryIds)) return;
      if (_distanceMeters(p.lat, p.lng, r.lat, r.lng) > p.radiusM + 1) return;

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

    // DELETE: remove if present
    void _remove(Map<String, dynamic> row) {
      final id = (row['report_id'] ?? row['id'] ?? '').toString();
      final cur = state.value ?? const <Report>[];
      final next = cur.where((e) => e.id != id).toList(growable: false);
      if (next.length != cur.length) {
        state = AsyncData(next);
      }
    }

    ch
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.insert,
        schema: 'civic_app',
        table: 'reports',
        callback: (payload) => _upsert(payload.newRecord),
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.update,
        schema: 'civic_app',
        table: 'reports',
        callback: (payload) => _upsert(payload.newRecord),
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.delete,
        schema: 'civic_app',
        table: 'reports',
        callback: (payload) => _remove(payload.oldRecord),
      )
      ..subscribe();

    _channel = ch;
  }

  /// Optional optimistic add from the submit flow
  void addOrReplace(Report r) {
    final p = _params;
    if (p != null) {
      if (!_categoryAllowed(r, p.categoryIds)) return;
      if (_distanceMeters(p.lat, p.lng, r.lat, r.lng) > p.radiusM + 1) return;
    }
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

/// ----------------------
/// (Legacy) fetch-only list
/// ----------------------
final nearbyReportsProvider =
    FutureProvider.autoDispose<List<Report>>((ref) async {
  final svc = ref.watch(supabaseReportServiceProvider);
  final filters = ref.watch(mapFiltersProvider);
  final loc = await ref.watch(currentLocationProvider.future);

  const fallbackLat = 24.7136;
  const fallbackLng = 46.6753;

  final lat = (loc?.latitude ?? fallbackLat).toDouble();
  final lng = (loc?.longitude ?? fallbackLng).toDouble();

  return svc.fetchNearby(
    lat: lat,
    lng: lng,
    radiusKm: filters.radiusKm,
    categoryIds: filters.categoryIds,
  );
});

/// ----------------------
/// Helpers
/// ----------------------

class _QueryParams {
  _QueryParams({
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.categoryIds,
  });

  final double lat;
  final double lng;
  final int radiusM;
  final Set<int> categoryIds;
}

bool _categoryAllowed(Report r, Set<int> catIds) {
  if (catIds.isEmpty) return true;
  final cid = int.tryParse(r.categoryId.toString());
  return cid != null ? catIds.contains(cid) : true;
}

/// Haversine distance (meters) – used to filter realtime events client-side
double _distanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const R = 6371000.0; // meters
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

double _deg2rad(double x) => x * math.pi / 180.0;

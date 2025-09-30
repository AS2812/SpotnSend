/// ----------------------
/// Map markers controller (for UI marker state)
/// ----------------------
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/models/alert_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/models/settings_models.dart';
import 'package:spotnsend/data/services/supabase_alerts_service.dart';
import 'package:spotnsend/data/services/maptiler_service.dart';
import 'package:spotnsend/data/services/supabase_reports_service.dart';
import 'package:spotnsend/data/services/translation_service.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';
import 'package:spotnsend/features/home/settings/providers/settings_providers.dart';
import 'package:spotnsend/main.dart';

/// ----------------------
/// Map markers controller (for UI marker state)
/// ----------------------
class MapMarker {
  final String id;
  final double lat;
  final double lng;
  final String type; // 'report' or 'saved_spot'
  final dynamic data;

  MapMarker({
    required this.id,
    required this.lat,
    required this.lng,
    required this.type,
    required this.data,
  });
}

final mapMarkersControllerProvider =
    AsyncNotifierProvider.autoDispose<MapMarkersController, List<MapMarker>>(
  () => MapMarkersController(),
);

class MapMarkersController extends AsyncNotifier<List<MapMarker>> {
  @override
  Future<List<MapMarker>> build() async {
    // Always recompute when filters change
    final filters = ref.watch(mapFiltersProvider);

    // Wait for reports (already filtered by radius & categories upstream)
    final reports = await ref.watch(mapReportsControllerProvider.future);

    // Optionally include saved spots (depending on toggle)
    final savedSpots = filters.includeSavedSpots
        ? await ref.watch(accountSavedSpotsProvider.future)
        : const <SavedSpot>[];

    // Compose into a single marker list
    final markers = <MapMarker>[
      // Reports
      ...reports.map((r) => MapMarker(
            id: r.id,
            lat: r.lat,
            lng: r.lng,
            type: 'report',
            data: r,
          )),
      // Saved spots
      ...savedSpots.map((s) => MapMarker(
            id: s.id,
            lat: s.lat,
            lng: s.lng,
            type: 'saved_spot',
            data: s,
          )),
    ];

    return markers;
  }

  /// Optional manual sync API if you want to push a known set
  Future<void> syncMarkers({
    List<Report>? reports,
    List<SavedSpot>? savedSpots,
  }) async {
    final markers = <MapMarker>[
      if (reports != null)
        ...reports.map((r) => MapMarker(
              id: r.id,
              lat: r.lat,
              lng: r.lng,
              type: 'report',
              data: r,
            )),
      if (savedSpots != null)
        ...savedSpots.map((s) => MapMarker(
              id: s.id,
              lat: s.lat,
              lng: s.lng,
              type: 'saved_spot',
              data: s,
            )),
    ];
    state = AsyncData(markers);
  }

  void clearMarkers() => state = const AsyncData([]);
}

const double kDefaultSearchRadiusKm = 5;
const double kMinSearchRadiusKm = 0.5;
const double kMaxSearchRadiusKm = 30;
const double kRadiusStepKm = 0.5;

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
      radiusKm: kDefaultSearchRadiusKm,
      categoryIds: <int>{},
      includeSavedSpots: true,
    );
  }

  void setRadius(double radiusKm) {
    final clamped =
        radiusKm.clamp(kMinSearchRadiusKm, kMaxSearchRadiusKm).toDouble();
    final snapped = (clamped / kRadiusStepKm).roundToDouble() * kRadiusStepKm;
    state = state.copyWith(
      radiusKm: double.parse(snapped.toStringAsFixed(2)),
    );
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
  int? _viewerUserId;
  bool _viewerIsGovernment = false;
  TranslationService? _translator;
  AppLanguage _language = AppLanguage.english;

  // Current query params to keep realtime consistent with the UI.
  _QueryParams? _params;
  static const int _maxVisibleReports = 200;

  @override
  Future<List<Report>> build() async {
    _language = ref.watch(
      settingsControllerProvider.select((state) => state.settings.language),
    );
    _translator = ref.watch(translationServiceProvider);

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
      final channel = _channel;
      _channel = null;
      if (channel != null) {
        await channel.unsubscribe();
      }
    });

    return _reload();
  }

  Future<void> refresh() async {
    await _reload();
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

    int? viewerId;
    bool viewerIsGovernment = false;
    try {
      final user = await ref.read(accountUserProvider.future);
      viewerId = user == null ? null : int.tryParse(user.id);
      viewerIsGovernment = user?.isGovernment ?? false;
    } catch (_) {
      viewerId = null;
      viewerIsGovernment = false;
    }
    _viewerUserId = viewerId;
    _viewerIsGovernment = viewerIsGovernment;

    _params = _QueryParams(
      lat: lat,
      lng: lng,
      radiusM: (radiusKm * 1000).round(),
      categoryIds: categories,
    );

    final data = await svc.fetchNearby(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      categoryIds: categories,
      viewerIsGovernment: _viewerIsGovernment,
    );

    final localized = await _localizeReports(data);
    final visible = _sortedReports(localized.where(_canSee));

    _startRealtime();

    _publish(visible);
    return visible;
  }

  bool _canSee(Report report) {
    return report.canBeSeenBy(
      userId: _viewerUserId,
      isGovernment: _viewerIsGovernment,
    );
  }

  List<Report> _sortedReports(Iterable<Report> reports) {
    final deduped = <String, Report>{};
    for (final report in reports) {
      deduped[report.id] = report;
    }
    final list = deduped.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.length > _maxVisibleReports) {
      return list.sublist(0, _maxVisibleReports);
    }
    return list;
  }

  void _publish(Iterable<Report> reports) {
    state = AsyncData(_sortedReports(reports));
  }

  void _startRealtime() {
    // Re-use channel if already active
    if (_channel != null) return;

    final ch = supabase.channel('realtime:reports');

    // INSERT / UPDATE: merge if it matches current filters
    Future<void> _upsert(Map<String, dynamic> row) async {
      debugPrint('[Realtime] UPSERT event received: row=${row.toString()}');
      var r = Report.fromJson(row);
      r = await _localizeReport(r);
      if (!_canSee(r)) {
        debugPrint('[Realtime] Report cannot be seen, skipping.');
        return;
      }
      final p = _params;
      if (p == null) {
        debugPrint('[Realtime] Params null, skipping.');
        return;
      }
      if (!_categoryAllowed(r, p.categoryIds)) {
        debugPrint('[Realtime] Category not allowed, skipping.');
        return;
      }
      if (_distanceMeters(p.lat, p.lng, r.lat, r.lng) > p.radiusM + 1) {
        debugPrint('[Realtime] Report out of radius, skipping.');
        return;
      }
      final cur = state.value ?? const <Report>[];
      final next = <Report>[r, ...cur.where((e) => e.id != r.id)];
      debugPrint('[Realtime] Publishing report list, count: \\${next.length}');
      _publish(next);
      // Invalidate marker provider so UI updates
      debugPrint('[Realtime] Invalidating mapMarkersControllerProvider');
      ref.invalidate(mapMarkersControllerProvider);
    }

    // DELETE: remove if present
    void _remove(Map<String, dynamic> row) {
      debugPrint('[Realtime] DELETE event received: row=${row.toString()}');
      final id = (row['report_id'] ?? row['id'] ?? '').toString();
      final cur = state.value ?? const <Report>[];
      if (!cur.any((e) => e.id == id)) {
        debugPrint('[Realtime] Report not found in current list, skipping.');
        return;
      }
      debugPrint('[Realtime] Removing report with id: $id');
      _publish(cur.where((e) => e.id != id));
      // Invalidate marker provider so UI updates
      debugPrint('[Realtime] Invalidating mapMarkersControllerProvider');
      ref.invalidate(mapMarkersControllerProvider);
    }

    ch
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.insert,
        schema: 'public',
        table: 'reports',
        callback: (payload) => unawaited(_upsert(payload.newRecord)),
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.update,
        schema: 'public',
        table: 'reports',
        callback: (payload) => unawaited(_upsert(payload.newRecord)),
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.delete,
        schema: 'public',
        table: 'reports',
        callback: (payload) => _remove(payload.oldRecord),
      )
      ..subscribe();

    _channel = ch;
  }

  /// Optional optimistic add from the submit flow
  void addOrReplace(Report r) {
    unawaited(() async {
      var localized = r;
      localized = await _localizeReport(localized);
      if (!_canSee(localized)) return;
      final p = _params;
      if (p != null) {
        if (!_categoryAllowed(localized, p.categoryIds)) return;
        if (_distanceMeters(p.lat, p.lng, localized.lat, localized.lng) >
            p.radiusM + 1) {
          return;
        }
      }
      final cur = state.value ?? const <Report>[];
      final next = <Report>[localized, ...cur.where((e) => e.id != localized.id)];
      _publish(next);
    }());
  }

  Future<List<Report>> _localizeReports(Iterable<Report> reports) async {
    final translator = _translator;
    if (_language != AppLanguage.arabic || translator == null) {
      return reports.toList(growable: false);
    }
    if (!translator.isEnabled) {
      return reports.toList(growable: false);
    }
    return translator.translateReports(reports);
  }

  Future<Report> _localizeReport(Report report) async {
    final translator = _translator;
    if (_language != AppLanguage.arabic || translator == null) {
      return report;
    }
    if (!translator.isEnabled) {
      return report;
    }
    return translator.translateReport(report);
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
  final user = await ref.watch(accountUserProvider.future);
  final language = ref.watch(
    settingsControllerProvider.select((state) => state.settings.language),
  );
  final translator = ref.watch(translationServiceProvider);

  const fallbackLat = 24.7136;
  const fallbackLng = 46.6753;

  final lat = (loc?.latitude ?? fallbackLat).toDouble();
  final lng = (loc?.longitude ?? fallbackLng).toDouble();

  final reports = await svc.fetchNearby(
    lat: lat,
    lng: lng,
    radiusKm: filters.radiusKm,
    categoryIds: filters.categoryIds,
    viewerIsGovernment: user?.isGovernment ?? false,
  );
  if (language != AppLanguage.arabic || !translator.isEnabled) {
    return reports;
  }
  return translator.translateReports(reports);
});

final mapAlertsControllerProvider =
    AsyncNotifierProvider.autoDispose<MapAlertsController, List<Alert>>(
        () => MapAlertsController());

class MapAlertsController extends AsyncNotifier<List<Alert>> {
  sb.RealtimeChannel? _channel;
  _AlertParams? _params;
  static const _maxVisibleAlerts = 200;

  @override
  Future<List<Alert>> build() async {
    final svc = ref.watch(supabaseAlertsServiceProvider);
    final filters = ref.watch(mapFiltersProvider);
    final loc = await ref.watch(currentLocationProvider.future);

    const fallbackLat = 24.7136;
    const fallbackLng = 46.6753;

    final lat = (loc?.latitude ?? fallbackLat).toDouble();
    final lng = (loc?.longitude ?? fallbackLng).toDouble();
    final radiusKm = filters.radiusKm;

    _params = _AlertParams(
      lat: lat,
      lng: lng,
      radiusM: (radiusKm * 1000).round(),
    );

    ref.onDispose(() {
      _channel?.unsubscribe();
      _channel = null;
    });

    final alerts = await svc.fetchNearby(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
    );

    final active = _filterAndSort(alerts);
    _startRealtime();
    return active;
  }

  Future<void> refresh() async {
    try {
      final svc = ref.read(supabaseAlertsServiceProvider);
      final filters = ref.read(mapFiltersProvider);
      final loc = await ref.read(currentLocationProvider.future);

      const fallbackLat = 24.7136;
      const fallbackLng = 46.6753;

      final lat = (loc?.latitude ?? fallbackLat).toDouble();
      final lng = (loc?.longitude ?? fallbackLng).toDouble();
      final radiusKm = filters.radiusKm;

      _params = _AlertParams(
        lat: lat,
        lng: lng,
        radiusM: (radiusKm * 1000).round(),
      );

      final alerts = await svc.fetchNearby(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
      );

      _startRealtime();
      state = AsyncData(_filterAndSort(alerts));
    } catch (err, stack) {
      state = AsyncError(err, stack);
    }
  }

  List<Alert> _filterAndSort(Iterable<Alert> alerts) {
    final params = _params;
    final deduped = <String, Alert>{};
    for (final alert in alerts) {
      deduped[alert.id] = alert;
    }
    final filtered = deduped.values.where((alert) {
      if (alert.status != AlertStatus.active) return false;
      if (params == null) return true;
      final distance = _distanceMeters(
        params.lat,
        params.lng,
        alert.latitude,
        alert.longitude,
      );
      return distance <= params.radiusM + 1;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (filtered.length > _maxVisibleAlerts) {
      return filtered.sublist(0, _maxVisibleAlerts);
    }
    return filtered;
  }

  void _startRealtime() {
    if (_channel != null) return;

    final ch = supabase.channel('realtime:alerts');

    ch
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.insert,
        schema: 'public',
        table: 'alerts',
        callback: (payload) => _handleUpsert(payload.newRecord),
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.update,
        schema: 'public',
        table: 'alerts',
        callback: (payload) => _handleUpsert(payload.newRecord),
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.delete,
        schema: 'public',
        table: 'alerts',
        callback: (payload) => _handleRemove(payload.oldRecord),
      )
      ..subscribe();

    _channel = ch;
  }

  void _handleUpsert(Map<String, dynamic> row) {
    final alert = Alert.fromJson(row);
    if (alert.status != AlertStatus.active || !_isWithinRadius(alert)) {
      _removeById(alert.id);
      return;
    }

    final current = state.value ?? const <Alert>[];
    final next = <Alert>[alert, ...current.where((a) => a.id != alert.id)];
    state = AsyncData(_filterAndSort(next));
  }

  void _handleRemove(Map<String, dynamic> row) {
    final id = (row['alert_id'] ?? row['id'] ?? '').toString();
    if (id.isEmpty) return;
    _removeById(id);
  }

  void _removeById(String id) {
    final current = state.value ?? const <Alert>[];
    if (!current.any((a) => a.id == id)) return;
    state = AsyncData(_filterAndSort(current.where((a) => a.id != id)));
  }

  bool _isWithinRadius(Alert alert) {
    final params = _params;
    if (params == null) return true;
    final distance = _distanceMeters(
      params.lat,
      params.lng,
      alert.latitude,
      alert.longitude,
    );
    return distance <= params.radiusM + 1;
  }
}

class _AlertParams {
  const _AlertParams({
    required this.lat,
    required this.lng,
    required this.radiusM,
  });

  final double lat;
  final double lng;
  final int radiusM;
}

final mapListContentProvider =
    Provider.autoDispose<AsyncValue<MapListContent>>((ref) {
  final reportsAsync = ref.watch(mapReportsControllerProvider);
  final savedSpotsAsync = ref.watch(accountSavedSpotsProvider);
  final alertsAsync = ref.watch(mapAlertsControllerProvider);

  if (reportsAsync.isLoading ||
      savedSpotsAsync.isLoading ||
      alertsAsync.isLoading) {
    return const AsyncValue<MapListContent>.loading();
  }

  Object? error;
  StackTrace? stack;
  reportsAsync.whenOrNull(error: (err, st) {
    error ??= err;
    stack ??= st;
  });
  savedSpotsAsync.whenOrNull(error: (err, st) {
    error ??= err;
    stack ??= st;
  });
  alertsAsync.whenOrNull(error: (err, st) {
    error ??= err;
    stack ??= st;
  });

  if (error != null) {
    return AsyncValue<MapListContent>.error(error!, stack ?? StackTrace.empty);
  }

  final reports = reportsAsync.value ?? const <Report>[];
  final savedSpots = savedSpotsAsync.value ?? const <SavedSpot>[];
  final alerts = alertsAsync.value ?? const <Alert>[];

  final activeReports = reports.where((report) => report.isActive).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final savedSummaries = savedSpots
      .map((spot) {
        final radius = (spot.radiusMeters ?? 5000).toDouble();
        final matches = activeReports
            .where((report) =>
                _distanceMeters(spot.lat, spot.lng, report.lat, report.lng) <=
                radius)
            .toList();
        return SavedSpotSummary(spot: spot, reports: matches);
      })
      .where((summary) => summary.reports.isNotEmpty)
      .toList()
    ..sort((a, b) => b.reports.length.compareTo(a.reports.length));

  final content = MapListContent(
    savedSpotSummaries: savedSummaries,
    reports: activeReports,
    alerts: alerts,
  );

  return AsyncValue<MapListContent>.data(content);
});

class MapListContent {
  const MapListContent({
    required this.savedSpotSummaries,
    required this.reports,
    required this.alerts,
  });

  final List<SavedSpotSummary> savedSpotSummaries;
  final List<Report> reports;
  final List<Alert> alerts;

  bool get hasContent =>
      savedSpotSummaries.isNotEmpty || reports.isNotEmpty || alerts.isNotEmpty;
}

class SavedSpotSummary {
  const SavedSpotSummary({
    required this.spot,
    required this.reports,
  });

  final SavedSpot spot;
  final List<Report> reports;
}

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

/// Haversine distance (meters) â€“ used to filter realtime events client-side
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

final mapReportsStreamProvider = StreamProvider.autoDispose<List<Report>>((ref) async* {
  final svc = ref.read(supabaseReportServiceProvider);
  final filters = ref.watch(mapFiltersProvider);
  final loc = await ref.watch(currentLocationProvider.future);
  final language = ref.watch(
    settingsControllerProvider.select((state) => state.settings.language),
  );
  final translator = ref.watch(translationServiceProvider);
  final user = await ref.watch(accountUserProvider.future);
  final viewerId = user == null ? null : int.tryParse(user.id);
  final viewerIsGovernment = user?.isGovernment ?? false;

  const fallbackLat = 24.7136;
  const fallbackLng = 46.6753;
  final lat = (loc?.latitude ?? fallbackLat).toDouble();
  final lng = (loc?.longitude ?? fallbackLng).toDouble();
  final radiusKm = filters.radiusKm;
  final categories = filters.categoryIds;

  // Initial fetch
  List<Report> current = await svc.fetchNearby(
    lat: lat,
    lng: lng,
    radiusKm: radiusKm,
    categoryIds: categories,
    viewerIsGovernment: viewerIsGovernment,
  );
  if (language == AppLanguage.arabic && translator.isEnabled) {
    current = await translator.translateReports(current);
  }
  yield current;

  // Listen to realtime changes
  final channel = supabase.channel('realtime:reports');
  StreamController<List<Report>> controller = StreamController();
  void publish() => controller.add(List<Report>.from(current));

  Future<void> upsert(Map<String, dynamic> row) async {
    var r = Report.fromJson(row);
    if (!r.canBeSeenBy(userId: viewerId, isGovernment: viewerIsGovernment)) return;
    if (categories.isNotEmpty && !categories.contains(r.categoryId)) return;
    final dist = ((lat - r.lat).abs() + (lng - r.lng).abs()); // quick filter
    if (dist > radiusKm) return;
    if (language == AppLanguage.arabic && translator.isEnabled) {
      r = await translator.translateReport(r);
    }
    current = [r, ...current.where((e) => e.id != r.id)];
    publish();
  }
  void remove(Map<String, dynamic> row) {
    final id = (row['report_id'] ?? row['id'] ?? '').toString();
    if (!current.any((e) => e.id == id)) return;
    current = current.where((e) => e.id != id).toList();
    publish();
  }
  channel
    ..onPostgresChanges(
      event: sb.PostgresChangeEvent.insert,
      schema: 'public',
      table: 'reports',
      callback: (payload) => upsert(payload.newRecord),
    )
    ..onPostgresChanges(
      event: sb.PostgresChangeEvent.update,
      schema: 'public',
      table: 'reports',
      callback: (payload) => upsert(payload.newRecord),
    )
    ..onPostgresChanges(
      event: sb.PostgresChangeEvent.delete,
      schema: 'public',
      table: 'reports',
      callback: (payload) => remove(payload.oldRecord),
    )
    ..subscribe();

  ref.onDispose(() async {
    await channel.unsubscribe();
    await controller.close();
  });

  yield* controller.stream;
});

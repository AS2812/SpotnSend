import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:location/location.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:spotnsend/core/utils/formatters.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/models/alert_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/features/home/map/providers/alerts_providers.dart';
import 'package:spotnsend/features/home/map/widgets/alert_detail_sheet.dart';
import 'package:spotnsend/features/home/map/widgets/filters_sheet.dart';
import 'package:spotnsend/features/home/map/widgets/legend.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/toasts.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  MaplibreMapController? _controller;

  // Markers by type
  final Map<Symbol, Report> _reportBySymbol = {};
  final Map<Symbol, Alert> _alertBySymbol = {};
  final Map<Symbol, SavedSpot> _savedSpotBySymbol = {};

  // User & view state
  LatLng _initialCenter = const LatLng(24.7136, 46.6753);
  LatLng? _userLocation;
  Symbol? _userLocationMarker;

  // Geodesic radius as a filled polygon (real meters)
  Fill? _radiusFill;

  @override
  void initState() {
    super.initState();
    _primeUserLocation();

    // After first frame, wire listeners to providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // User location -> recenter & redraw radius & alerts refresh
      ref.listen<AsyncValue<LocationData?>>(currentLocationProvider,
          (prev, next) {
        next.whenOrNull(data: (data) async {
          if (data == null) return;
          final where = LatLng(data.latitude!, data.longitude!);
          _userLocation = where;
          _initialCenter = where;

          if (_controller != null) {
            await _controller!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: where, zoom: 15.5),
              ),
            );
            await _putUserMarker(where);
            await _drawSearchRadius();
          }

          // pull alerts for the new location
          await _pullAlerts();
        });
      });

      // Nearby reports (use realtime-aware provider)
      ref.listen<AsyncValue<List<Report>>>(mapReportsControllerProvider,
          (prev, next) {
        next.whenOrNull(data: (reports) => _syncReportMarkers(reports));
      });

      // Saved spots (pretty cyan markers), respect filter
      ref.listen<AsyncValue<List<SavedSpot>>>(accountSavedSpotsProvider,
          (prev, next) async {
        final spots = next.value ?? const <SavedSpot>[];
        await _syncSavedSpotMarkers(spots);
      });

      // Radius knob changed: redraw circle & refresh alerts
      ref.listen<ReportFilters>(mapFiltersProvider, (prev, next) async {
        final prevRadius = prev?.radiusKm;
        final prevSaved = prev?.includeSavedSpots;

        if (prevRadius != next.radiusKm) {
          await _drawSearchRadius();
          await _pullAlerts();
        }
        if (prevSaved != next.includeSavedSpots) {
          final spots = await ref.read(accountSavedSpotsProvider.future);
          await _syncSavedSpotMarkers(spots);
        }
      });
    });
  }

  Future<void> _primeUserLocation() async {
    final loc = await ref.read(currentLocationProvider.future);
    if (loc != null) {
      final where = LatLng(loc.latitude!, loc.longitude!);
      _initialCenter = where;
      _userLocation = where;
    }
  }

  // -------------------- Markers & Overlays --------------------

  Future<void> _syncReportMarkers(List<Report> reports) async {
    if (_controller == null) return;

    for (final s in _reportBySymbol.keys) {
      await _controller!.removeSymbol(s);
    }
    _reportBySymbol.clear();

    for (final r in reports) {
      final s = await _controller!.addSymbol(
        SymbolOptions(
          geometry: LatLng(r.lat, r.lng),
          iconImage: 'marker-15',
          iconColor: '#EB3E50', // red
          iconSize: 1.4,
        ),
      );
      _reportBySymbol[s] = r;
    }
  }

  Future<void> _syncAlertMarkers(List<Alert> alerts) async {
    if (_controller == null) return;

    for (final s in _alertBySymbol.keys) {
      await _controller!.removeSymbol(s);
    }
    _alertBySymbol.clear();

    for (final a in alerts) {
      if (a.status != AlertStatus.active) continue;
      final color = switch (a.severity) {
        AlertSeverity.low => '#4CAF50',
        AlertSeverity.medium => '#FF9800',
        AlertSeverity.high => '#F44336',
        AlertSeverity.critical => '#9C27B0',
      };

      final s = await _controller!.addSymbol(
        SymbolOptions(
          geometry: LatLng(a.latitude, a.longitude),
          iconImage: 'marker-15',
          iconColor: color,
          iconSize: 1.8,
        ),
      );
      _alertBySymbol[s] = a;
    }
  }

  Future<void> _syncSavedSpotMarkers(List<SavedSpot> spots) async {
    if (_controller == null) return;

    // Clear current spot markers
    for (final s in _savedSpotBySymbol.keys) {
      await _controller!.removeSymbol(s);
    }
    _savedSpotBySymbol.clear();

    // Respect filter: only draw when enabled
    final filters = ref.read(mapFiltersProvider);
    if (!filters.includeSavedSpots) return;

    for (final sp in spots) {
      final s = await _controller!.addSymbol(
        SymbolOptions(
          geometry: LatLng(sp.lat, sp.lng),
          iconImage: 'marker-15',
          iconColor: '#00BCD4', // cyan for saved spots
          iconSize: 1.6,
        ),
      );
      _savedSpotBySymbol[s] = sp;
    }
  }

  Future<void> _putUserMarker(LatLng at) async {
    if (_controller == null) return;
    if (_userLocationMarker != null) {
      await _controller!.removeSymbol(_userLocationMarker!);
    }
    _userLocationMarker = await _controller!.addSymbol(
      SymbolOptions(
        geometry: at,
        iconImage: 'marker-15',
        iconColor: '#4CAF50', // green
        iconSize: 1.6,
      ),
    );
  }

  /// Draw a true-meters circle as a polygon fill around the user location.
  Future<void> _drawSearchRadius() async {
    if (_controller == null) return;

    // remove old fill
    if (_radiusFill != null) {
      await _controller!.removeFill(_radiusFill!);
      _radiusFill = null;
    }

    final radiusKm = ref.read(mapFiltersProvider).radiusKm;
    final center = _userLocation ?? _initialCenter;
    final polygon = _circlePolygon(center, radiusKm * 1000, 96);

    _radiusFill = await _controller!.addFill(
      FillOptions(
        geometry: [polygon], // one ring polygon
        fillColor: '#2196F3',
        fillOpacity: 0.15,
        fillOutlineColor: '#2196F3',
      ),
    );
  }

  /// Create a geodesic circle around [center] with [radiusMeters].
  /// Returns a closed ring (first == last).
  List<LatLng> _circlePolygon(LatLng center, double radiusMeters, int steps) {
    const earth = 6378137.0; // meters
    final lat = _degToRad(center.latitude);
    final lng = _degToRad(center.longitude);
    final dByR = radiusMeters / earth;

    final pts = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final brg = 2 * math.pi * (i / steps); // 0..2π
      final lat2 = math.asin(
        math.sin(lat) * math.cos(dByR) +
            math.cos(lat) * math.sin(dByR) * math.cos(brg),
      );
      final lng2 = lng +
          math.atan2(
            math.sin(brg) * math.sin(dByR) * math.cos(lat),
            math.cos(dByR) - math.sin(lat) * math.sin(lat2),
          );
      pts.add(LatLng(_radToDeg(lat2), _radToDeg(lng2)));
    }
    return pts;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
  double _radToDeg(double rad) => rad * (180.0 / math.pi);

  // -------------------- Alerts refresh helper --------------------

  Future<void> _pullAlerts() async {
    try {
      final alerts = await ref.read(nearbyAlertsProvider.future);
      await _syncAlertMarkers(alerts);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to load alerts: $e');
        debugPrintStack(stackTrace: st);
      }
    }
  }

  // -------------------- Bottom sheets --------------------

  void _openReportDetails(Report report) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ReportDetailSheet(report: report),
    );
  }

  void _openAlertDetails(Alert alert) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => AlertDetailSheet(alert: alert),
    );
  }

  // -------------------- Build --------------------

  @override
  Widget build(BuildContext context) {
    final mapStyleUrl = ref.watch(mapStyleUrlProvider);
    final filters = ref.watch(mapFiltersProvider);
    final reportsAsync = ref.watch(mapReportsControllerProvider);
    final permissionAsync = ref.watch(locationPermissionProvider);

    final missingKey = mapStyleUrl.contains('YOUR_KEY_HERE');

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MaplibreMap(
              styleString: mapStyleUrl,
              initialCameraPosition: CameraPosition(
                target: _userLocation ?? _initialCenter,
                zoom: 15.5,
              ),
              myLocationEnabled: permissionAsync.value ?? false,
              myLocationTrackingMode: permissionAsync.value == true
                  ? MyLocationTrackingMode.tracking
                  : MyLocationTrackingMode.none,
              myLocationRenderMode: permissionAsync.value == true
                  ? MyLocationRenderMode.gps
                  : MyLocationRenderMode.normal,
              compassEnabled: true,
              trackCameraPosition: true,
              onMapCreated: (controller) async {
                _controller = controller;

                controller.onSymbolTapped.add((symbol) {
                  if (_reportBySymbol.containsKey(symbol)) {
                    _openReportDetails(_reportBySymbol[symbol]!);
                    return;
                  }
                  if (_alertBySymbol.containsKey(symbol)) {
                    _openAlertDetails(_alertBySymbol[symbol]!);
                    return;
                  }
                  final spot = _savedSpotBySymbol[symbol];
                  if (spot != null) {
                    showSuccessToast(
                      context,
                      '${spot.name}\n${AppLocalizations.current.formatCoordinates(spot.lat, spot.lng)}',
                    );
                  }
                });

                // center to user once map is ready
                final loc = await ref.read(currentLocationProvider.future);
                if (loc != null) {
                  final where = LatLng(loc.latitude!, loc.longitude!);
                  _userLocation = where;
                  _initialCenter = where;
                  await controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: where, zoom: 15.5),
                    ),
                  );
                  await _putUserMarker(where);
                  await _drawSearchRadius();
                }

                // kick initial draws
                final reports =
                    await ref.read(mapReportsControllerProvider.future);
                await _syncReportMarkers(reports);

                final savedSpots =
                    await ref.read(accountSavedSpotsProvider.future);
                await _syncSavedSpotMarkers(savedSpots);

                await _pullAlerts();
              },
            ),
          ),

          // Header + radius selector
          Positioned(
            top: 32,
            left: 16,
            right: 16,
            child: Column(
              children: [
                const _MapHeader(),
                const SizedBox(height: 12),
                _RadiusSelector(selectedRadius: filters.radiusKm),
              ],
            ),
          ),

          // Bottom controls & legend
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Filter reports'.tr(),
                        variant: ButtonVariant.secondary,
                        icon: Icons.tune,
                        onPressed: _openFilters,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'List view'.tr(),
                        variant: ButtonVariant.secondary,
                        icon: Icons.view_list_rounded,
                        onPressed: () => context.goNamed('map_list_view'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const MapLegend(),
              ],
            ),
          ),

          // Recenter FAB
          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton.small(
              onPressed: () async {
                final loc = await ref.read(currentLocationProvider.future);
                if (loc == null) {
                  showErrorToast(
                      context, 'Enable location to recenter the map.'.tr());
                  return;
                }
                final target = LatLng(loc.latitude!, loc.longitude!);
                _controller?.animateCamera(CameraUpdate.newLatLng(target));
              },
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          if (reportsAsync.isLoading && !reportsAsync.hasValue)
            _LoadingOverlay(message: 'Loading nearby reports...'.tr()),
          if (missingKey) const _MissingKeyNotice(),
        ],
      ),
    );
  }

  Future<void> _openFilters() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => const MapFiltersSheet(),
    );
  }
}

// -------------------- UI bits --------------------

class _RadiusSelector extends ConsumerWidget {
  const _RadiusSelector({required this.selectedRadius});
  final double selectedRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final display = selectedRadius.clamp(1, 20).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Search radius'.tr(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider.adaptive(
                  min: 1,
                  max: 20,
                  divisions: 19,
                  value: display,
                  label: AppLocalizations.current.translate('{value} km',
                      params: {'value': display.round().toString()}),
                  onChanged: (v) =>
                      ref.read(mapFiltersProvider.notifier).setRadius(v),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.current.translate('{value} km',
                    params: {'value': display.round().toString()}),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends ConsumerWidget {
  const _MapHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spot nearby incidents'.tr(),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            auth.isPendingVerification
                ? 'Verification pending. Reporting is locked, but you can explore alerts in your area.'
                    .tr()
                : 'Stay alert with real-time safety intel from your community.'
                    .tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.18),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _MissingKeyNotice extends StatelessWidget {
  const _MissingKeyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'MapTiler key missing',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Run the app with --dart-define=MAPTILER_KEY=YOUR_KEY to enable the live map.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class ReportDetailSheet extends StatelessWidget {
  const ReportDetailSheet({super.key, required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Text(report.category, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(report.subcategory,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(report.description,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16),
              const SizedBox(width: 8),
              Text(AppFormatters.formatDateTime(report.createdAt)),
            ],
          ),
          if (report.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: report.mediaUrls
                  .map((url) => Chip(
                        avatar: const Icon(Icons.attachment_rounded, size: 18),
                        label: Text(url.split('/').last),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'View list'.tr(),
              variant: ButtonVariant.secondary,
              onPressed: () {
                Navigator.of(context).pop();
                context.goNamed('map_list_view');
              },
            ),
          ),
        ],
      ),
    );
  }
}

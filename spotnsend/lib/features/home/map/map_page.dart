import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:location/location.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:spotnsend/core/router/routes.dart';
import 'package:spotnsend/core/utils/formatters.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';
import 'package:spotnsend/features/home/map/category_icon_helpers.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/features/home/map/widgets/filters_sheet.dart';
import 'package:spotnsend/features/home/map/widgets/legend.dart';
import 'package:spotnsend/features/home/map/widgets/list_sheet.dart';
import 'package:spotnsend/features/home/map/widgets/radius_sheet.dart';
import 'package:spotnsend/features/home/report/providers/report_providers.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/toasts.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

const String _savedSpotIconKey = 'saved-spot';
const String _savedSpotSelectedIconKey = 'saved-spot-selected';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  MaplibreMapController? _controller;

  // Markers by type
  final Map<Symbol, Report> _reportBySymbol = {};
  final Map<Symbol, SavedSpot> _savedSpotBySymbol = {};
  final Map<int, String> _reportCategorySlugLookup = {};

  // User & view state
  LatLng _initialCenter = const LatLng(24.7136, 46.6753);
  LatLng? _userLocation;
  Symbol? _userLocationMarker;
  Symbol? _activeSavedSpotSymbol;
  bool _mapImagesLoaded = false;

  // Geodesic radius as a filled polygon (real meters)
  Fill? _radiusFill;

  @override
  void initState() {
    super.initState();
    _primeUserLocation();

    // After first frame, wire listeners to providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // User location -> recenter & redraw radius when GPS updates
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

      // Radius knob changed: redraw circle when the radius slider moves
      ref.listen<ReportFilters>(mapFiltersProvider, (prev, next) async {
        final prevRadius = prev?.radiusKm;
        final prevSaved = prev?.includeSavedSpots;

        if (prevRadius != next.radiusKm) {
          await _drawSearchRadius(next.radiusKm);
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

  Future<void> _ensureMapImagesLoaded() async {
    final controller = _controller;
    if (controller == null || _mapImagesLoaded) return;

    Future<void> registerPin(String key, String assetPath) async {
      try {
        final bytes = await rootBundle.load(assetPath);
        await controller.addImage(key, bytes.buffer.asUint8List());
      } catch (err, stack) {
        if (kDebugMode) {
          debugPrint('Failed to register map image $assetPath: $err');
          debugPrintStack(stackTrace: stack);
        }
      }
    }

    await registerCategoryIcons(controller);

    await registerPin(_savedSpotIconKey, 'assets/pins/saved_spot.png');
    await registerPin(
      _savedSpotSelectedIconKey,
      'assets/pins/saved_spot_selected.png',
    );

    _mapImagesLoaded = true;
  }

  Future<void> _syncReportMarkers(List<Report> reports) async {
    final controller = _controller;
    if (controller == null) return;

    await _ensureMapImagesLoaded();

    for (final symbol in _reportBySymbol.keys.toList(growable: false)) {
      await controller.removeSymbol(symbol);
    }
    _reportBySymbol.clear();

    await _ensureCategoryLookup();

    for (final report in reports) {
      final slug =
          report.categorySlug ?? _reportCategorySlugLookup[report.categoryId];
      final iconKey = mapImageKeyForSlug(slug) ??
          mapImageKeyForCategoryName(report.categoryName);
      final symbol = await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(report.lat, report.lng),
          iconImage: iconKey ?? 'marker-15',
          iconSize: iconKey != null ? 0.38 : 0.58,
          iconAnchor: 'bottom',
        ),
      );
      _reportBySymbol[symbol] = report;
    }
  }

  Future<void> _syncSavedSpotMarkers(List<SavedSpot> spots) async {
    final controller = _controller;
    if (controller == null) return;

    await _ensureMapImagesLoaded();

    for (final symbol in _savedSpotBySymbol.keys.toList(growable: false)) {
      await controller.removeSymbol(symbol);
    }
    _savedSpotBySymbol.clear();
    _activeSavedSpotSymbol = null;

    final filters = ref.read(mapFiltersProvider);
    if (!filters.includeSavedSpots) return;

    for (final spot in spots) {
      final symbol = await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(spot.lat, spot.lng),
          iconImage: _savedSpotIconKey,
          iconSize: 0.45,
          iconAnchor: 'bottom',
        ),
      );
      _savedSpotBySymbol[symbol] = spot;
    }
  }

  Future<void> _highlightSavedSpot(Symbol symbol) async {
    final controller = _controller;
    if (controller == null) return;

    if (_activeSavedSpotSymbol != null &&
        _savedSpotBySymbol.containsKey(_activeSavedSpotSymbol)) {
      await controller.updateSymbol(
        _activeSavedSpotSymbol!,
        SymbolOptions(
          iconImage: _savedSpotIconKey,
          iconSize: 0.45,
          iconAnchor: 'bottom',
        ),
      );
    }

    await controller.updateSymbol(
      symbol,
      SymbolOptions(
        iconImage: _savedSpotSelectedIconKey,
        iconSize: 0.56,
        iconAnchor: 'bottom',
      ),
    );

    _activeSavedSpotSymbol = symbol;
  }

  Future<void> _putUserMarker(LatLng at) async {
    final controller = _controller;
    if (controller == null) return;
    if (_userLocationMarker != null) {
      await controller.removeSymbol(_userLocationMarker!);
    }
    _userLocationMarker = await controller.addSymbol(
      SymbolOptions(
        geometry: at,
        iconImage: 'marker-15',
        iconColor: '#4CAF50', // green
        iconSize: 0.8,
        iconAnchor: 'bottom',
      ),
    );
  }

  /// Draw a true-meters circle as a polygon fill around the user location.
  Future<void> _drawSearchRadius([double? radiusKm]) async {
    if (_controller == null) return;

    // remove old fill
    if (_radiusFill != null) {
      await _controller!.removeFill(_radiusFill!);
      _radiusFill = null;
    }

    final effectiveRadiusKm = radiusKm ?? ref.read(mapFiltersProvider).radiusKm;
    final center = _userLocation ?? _initialCenter;
    final polygon = _circlePolygon(center, effectiveRadiusKm * 1000, 96);

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
      final brg = 2 * math.pi * (i / steps); // 0..2Ï€
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

  Future<void> _ensureCategoryLookup() async {
    if (_reportCategorySlugLookup.isNotEmpty) return;
    try {
      final categories = await ref.read(reportCategoriesProvider.future);
      for (final category in categories) {
        final slug = resolveCategorySlug(category.slug) ??
            resolveCategorySlug(category.name);
        if (slug != null) {
          _reportCategorySlugLookup[category.id] = slug;
        }
      }
    } catch (err, stack) {
      if (kDebugMode) {
        debugPrint('Failed to resolve report category lookup: $err');
        debugPrintStack(stackTrace: stack);
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

  // -------------------- Build --------------------

  @override
  Widget build(BuildContext context) {
    final mapStyleUrl = ref.watch(mapStyleUrlProvider);
    final filters = ref.watch(mapFiltersProvider);
    final reportsAsync = ref.watch(mapReportsControllerProvider);
    final permissionAsync = ref.watch(locationPermissionProvider);
    final authState = ref.watch(authControllerProvider);
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final topInset = media.padding.top + 16;
    final bottomInset = media.padding.bottom + 24;

    final radiusLabel = filters.radiusKm >= 1
        ? '${filters.radiusKm.toStringAsFixed(1)} km'
        : '${(filters.radiusKm * 1000).round()} m';

    final missingKey = mapStyleUrl.contains('YOUR_KEY_HERE');
    final errorText = reportsAsync.maybeWhen(
      error: (error, _) => error.toString(),
      orElse: () => null,
    );
    final activeCount = reportsAsync.maybeWhen(
      data: (value) => value.length,
      orElse: () => null,
    );

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
                _mapImagesLoaded = false;

                await _ensureMapImagesLoaded();

                controller.onSymbolTapped.add((symbol) {
                  if (_reportBySymbol.containsKey(symbol)) {
                    _openReportDetails(_reportBySymbol[symbol]!);
                    return;
                  }
                  final spot = _savedSpotBySymbol[symbol];
                  if (spot != null) {
                    unawaited(_highlightSavedSpot(symbol));
                    showSuccessToast(
                      context,
                      '${spot.name}\n${AppLocalizations.current.formatCoordinates(spot.lat, spot.lng)}',
                    );
                  }
                });

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

                final reports =
                    await ref.read(mapReportsControllerProvider.future);
                await _syncReportMarkers(reports);

                final savedSpots =
                    await ref.read(accountSavedSpotsProvider.future);
                await _syncSavedSpotMarkers(savedSpots);
              },
            ),
          ),
          if (missingKey)
            const Align(
              alignment: Alignment.center,
              child: _MissingKeyNotice(),
            ),
          Positioned(
            top: topInset,
            left: 16,
            right: 120,
            child: _MapOverviewCard(
              radiusLabel: radiusLabel,
              includeSavedSpots: filters.includeSavedSpots,
              isLoading: reportsAsync.isLoading,
              activeCount: activeCount,
            ),
          ),
          Positioned(
            right: 24,
            top: topInset,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    heroTag: 'map-list',
                    icon: Icons.list_alt,
                    label: 'List view'.tr(),
                    onPressed: _showListSheet,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    heroTag: 'map-filters',
                    icon: Icons.tune,
                    label: 'Filters'.tr(),
                    onPressed: _showFiltersSheet,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    heroTag: 'map-radius',
                    icon: Icons.radar,
                    label: 'Adjust radius'.tr(),
                    onPressed: _showRadiusSheet,
                  ),
                  const SizedBox(height: 20),
                  Tooltip(
                    message: 'Spot incident'.tr(),
                    triggerMode: TooltipTriggerMode.longPress,
                    child: FloatingActionButton.extended(
                      heroTag: 'map-spot-incident',
                      onPressed: () => _onSpotIncidentPressed(authState),
                      icon: const Icon(Icons.add_location_alt_rounded),
                      label: Text('Spot incident'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: bottomInset,
            child: SafeArea(
              top: false,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: MapLegend(),
                ),
              ),
            ),
          ),
          if (errorText != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset + 96,
              child: SafeArea(
                top: false,
                child: _MapErrorBanner(message: errorText),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String heroTag,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.longPress,
      child: FloatingActionButton.small(
        heroTag: heroTag,
        onPressed: onPressed,
        child: Icon(icon),
      ),
    );
  }

  Future<void> _showListSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MapListSheet(),
    );
  }

  Future<void> _showFiltersSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => const MapFiltersSheet(),
    );
  }

  Future<void> _showRadiusSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => const MapRadiusSheet(),
    );
  }

  void _onSpotIncidentPressed(AuthState authState) {
    if (authState.isPendingVerification) {
      showErrorToast(
        context,
        'Reporting is locked until verification is complete.'.tr(),
      );
      return;
    }
    context.goNamed(AppRoute.homeReport.name);
  }
}

class _MapOverviewCard extends StatelessWidget {
  const _MapOverviewCard({
    required this.radiusLabel,
    required this.includeSavedSpots,
    required this.isLoading,
    required this.activeCount,
  });

  final String radiusLabel;
  final bool includeSavedSpots;
  final bool isLoading;
  final int? activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final chips = <Widget>[
      Chip(
        avatar: const Icon(Icons.radar, size: 16),
        label: Text('Radius: ' + radiusLabel),
      ),
      Chip(
        avatar: Icon(
          includeSavedSpots ? Icons.bookmark_added : Icons.bookmark_border,
          size: 16,
        ),
        label: Text(
          includeSavedSpots ? 'Saved spots on'.tr() : 'Saved spots off'.tr(),
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Live map'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
          if (activeCount != null) ...[
            const SizedBox(height: 8),
            Text(
              'Active markers: {count}'.tr(params: {'count': '$activeCount'}),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ],
      ),
    );
  }
}

class _MapErrorBanner extends StatelessWidget {
  const _MapErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: theme.colorScheme.error.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
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

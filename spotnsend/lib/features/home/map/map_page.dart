import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:location/location.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:spotnsend/core/utils/formatters.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';
import 'package:spotnsend/widgets/app_button.dart';
import 'package:spotnsend/widgets/toasts.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/features/home/map/widgets/filters_sheet.dart';
import 'package:spotnsend/features/home/map/widgets/legend.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  MaplibreMapController? _controller;
  final Map<String, Report> _reportBySymbol = {};
  LatLng _initialCenter = const LatLng(24.7136, 46.6753);
  final double _initialZoom = 14; // Closer zoom for better user location view
  Circle? _radiusCircle;
  LatLng? _userLocation;
  Symbol? _userLocationMarker;

  @override
  void initState() {
    super.initState();
    // Immediately try to get user location and center map
    _centerToUserLocation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen<AsyncValue<LocationData?>>(currentLocationProvider,
          (previous, next) {
        next.whenOrNull(data: (data) {
          if (data != null) {
            final target = LatLng(data.latitude!, data.longitude!);
            _initialCenter = target;
            _userLocation = target;

            // Always center map to user location
            if (_controller != null) {
              _controller!.animateCamera(CameraUpdate.newLatLng(target));
              _addUserLocationMarker(target);
              _updateRadiusCircle();
            }
          }
        });
      });

      ref.listen<AsyncValue<List<Report>>>(nearbyReportsProvider,
          (previous, next) {
        next.whenOrNull(data: (reports) => _syncMarkers(reports));
      });

      // Listen to radius changes to update circle
      ref.listen<ReportFilters>(mapFiltersProvider, (previous, next) {
        if (previous?.radiusKm != next.radiusKm) {
          _updateRadiusCircle();
        }
      });
    });
  }

  Future<void> _syncMarkers(List<Report> reports) async {
    if (_controller == null) {
      return;
    }
    await _controller!.clearSymbols();
    _reportBySymbol.clear();
    for (final report in reports) {
      final symbol = await _controller!.addSymbol(
        SymbolOptions(
          geometry: LatLng(report.lat, report.lng),
          iconImage: 'marker-15',
          iconColor: '#EB3E50',
          iconSize: 1.4,
        ),
      );
      _reportBySymbol[symbol.id] = report;
    }
  }

  Future<void> _centerToUserLocation() async {
    final locationAsync = ref.read(currentLocationProvider);
    locationAsync.whenData((data) {
      if (data != null) {
        final target = LatLng(data.latitude!, data.longitude!);
        _initialCenter = target;
        _userLocation = target;
      }
    });
  }

  Future<void> _addUserLocationMarker(LatLng location) async {
    if (_controller == null) return;

    // Remove existing user marker
    if (_userLocationMarker != null) {
      await _controller!.removeSymbol(_userLocationMarker!);
    }

    // Add user location marker with distinct style
    _userLocationMarker = await _controller!.addSymbol(
      SymbolOptions(
        geometry: location,
        iconImage: 'marker-15',
        iconColor: '#4CAF50', // Green color for user location
        iconSize: 1.6,
      ),
    );
  }

  Future<void> _updateRadiusCircle() async {
    if (_controller == null || _userLocation == null) return;

    // Remove existing circle
    if (_radiusCircle != null) {
      await _controller!.removeCircle(_radiusCircle!);
    }

    // Add new circle with current radius
    final filters = ref.read(mapFiltersProvider);
    _radiusCircle = await _controller!.addCircle(
      CircleOptions(
        geometry: _userLocation!,
        circleRadius: filters.radiusKm * 1000, // Convert km to meters
        circleColor: '#2196F3',
        circleOpacity: 0.15,
        circleStrokeColor: '#2196F3',
        circleStrokeWidth: 2,
        circleStrokeOpacity: 0.6,
      ),
    );
  }

  void _openReportDetails(Report report) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => ReportDetailSheet(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapStyleUrl = ref.watch(mapStyleUrlProvider);
    final filters = ref.watch(mapFiltersProvider);
    final reportsAsync = ref.watch(nearbyReportsProvider);
    final permissionAsync = ref.watch(locationPermissionProvider);

    final missingKey = mapStyleUrl.contains('YOUR_KEY_HERE');

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MaplibreMap(
              styleString: mapStyleUrl,
              initialCameraPosition: CameraPosition(
                  target: _userLocation ?? _initialCenter, zoom: _initialZoom),
              myLocationEnabled: permissionAsync.value ?? false,
              myLocationTrackingMode: MyLocationTrackingMode.tracking,
              myLocationRenderMode: MyLocationRenderMode.gps,
              compassEnabled: true,
              trackCameraPosition: true,
              onMapCreated: (controller) async {
                _controller = controller;
                controller.onSymbolTapped.add((symbol) {
                  final report = _reportBySymbol[symbol.id];
                  if (report != null) {
                    _openReportDetails(report);
                  }
                });

                // Immediately center to user location when map is created
                final locationAsync = ref.read(currentLocationProvider);
                locationAsync.whenData((data) {
                  if (data != null) {
                    final target = LatLng(data.latitude!, data.longitude!);
                    _userLocation = target;
                    _initialCenter = target;

                    // Force camera to user location with higher zoom
                    controller.animateCamera(CameraUpdate.newCameraPosition(
                      CameraPosition(target: target, zoom: 16),
                    ));

                    _addUserLocationMarker(target);
                    _updateRadiusCircle();
                  }
                });
              },
            ),
          ),
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
                        onPressed: () => _openFilters(),
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
          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton.small(
              onPressed: () async {
                final location = await ref.read(currentLocationProvider.future);
                if (location == null) {
                  showErrorToast(context,
                      'Enable location permissions to recenter the map.'.tr());
                  return;
                }
                final target = LatLng(
                    location.latitude ?? _initialCenter.latitude,
                    location.longitude ?? _initialCenter.longitude);
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => const MapFiltersSheet(),
    );
  }
}

class _RadiusSelector extends ConsumerWidget {
  const _RadiusSelector({required this.selectedRadius});

  final double selectedRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final displayValue = selectedRadius.clamp(1, 20);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10)),
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
                  value: displayValue.toDouble(),
                  label: AppLocalizations.current.translate('{value} km',
                      params: {'value': displayValue.round().toString()}),
                  onChanged: (value) =>
                      ref.read(mapFiltersProvider.notifier).setRadius(value),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                  AppLocalizations.current.translate('{value} km',
                      params: {'value': displayValue.round().toString()}),
                  style: theme.textTheme.titleMedium),
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
    final authState = ref.watch(authControllerProvider);
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
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spot nearby incidents'.tr(),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            authState.isPendingVerification
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.key, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            'MapTiler key missing'.tr(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Run the app with --dart-define=MAPTILER_KEY=YOUR_KEY to enable the live map.'
                .tr(),
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
                borderRadius: BorderRadius.circular(8)),
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
              Text(formatDateTime(report.createdAt)),
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

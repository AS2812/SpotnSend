import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';

import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/services/maptiler_service.dart';
import 'package:spotnsend/data/services/report_service.dart';

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

  PermissionStatus permissionStatus = await location.hasPermission();
  if (permissionStatus == PermissionStatus.denied) {
    permissionStatus = await location.requestPermission();
  }

  return permissionStatus == PermissionStatus.granted ||
      permissionStatus == PermissionStatus.grantedLimited;
});

final currentLocationProvider =
    FutureProvider.autoDispose<LocationData?>((ref) async {
  final hasPermission = await ref.watch(locationPermissionProvider.future);
  if (!hasPermission) {
    return null;
  }
  final location = ref.watch(locationServiceProvider);
  return location.getLocation();
});

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

final mapViewModeProvider =
    Provider<bool>((ref) => false); // false = map, true = list

final selectedReportProvider = Provider<String?>((ref) => null);

final nearbyReportsProvider =
    FutureProvider.autoDispose<List<Report>>((ref) async {
  final reportService = ref.watch(reportServiceProvider);
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

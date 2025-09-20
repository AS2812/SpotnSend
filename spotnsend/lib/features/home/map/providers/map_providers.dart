import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:location/location.dart';

import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/services/maptiler_service.dart';
import 'package:spotnsend/data/services/report_service.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';

final locationServiceProvider = Provider<Location>((ref) => Location());

final locationPermissionProvider = FutureProvider.autoDispose<bool>((ref) async {
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

  return permissionStatus == PermissionStatus.granted || permissionStatus == PermissionStatus.grantedLimited;
});

final currentLocationProvider = FutureProvider.autoDispose<LocationData?>((ref) async {
  final hasPermission = await ref.watch(locationPermissionProvider.future);
  if (!hasPermission) {
    return null;
  }
  final location = ref.watch(locationServiceProvider);
  return location.getLocation();
});

final mapFiltersProvider = StateNotifierProvider<MapFiltersNotifier, ReportFilters>((ref) {
  return MapFiltersNotifier();
});

class MapFiltersNotifier extends StateNotifier<ReportFilters> {
  MapFiltersNotifier()
      : super(const ReportFilters(
          radiusKm: 3,
          categories: {},
          includeSavedSpots: true,
        ));

  void setRadius(double radius) {
    state = state.copyWith(radiusKm: radius);
  }

  void toggleCategory(String category) {
    final updated = Set<String>.from(state.categories);
    if (!updated.add(category)) {
      updated.remove(category);
    }
    state = state.copyWith(categories: updated);
  }

  void clearCategories() {
    state = state.copyWith(categories: {});
  }

  void toggleSavedSpots(bool enabled) {
    state = state.copyWith(includeSavedSpots: enabled);
  }
}

final mapStyleUrlProvider = Provider<String>((ref) {
  final service = ref.watch(mapTilerServiceProvider);
  return service.styleUrl;
});

final mapViewModeProvider = StateProvider<bool>((ref) => false); // false = map, true = list

final selectedReportProvider = StateProvider<String?>((ref) => null);

final nearbyReportsProvider = FutureProvider.autoDispose<List<Report>>((ref) async {
  final reportService = ref.watch(reportServiceProvider);
  final filters = ref.watch(mapFiltersProvider);
  final locationData = await ref.watch(currentLocationProvider.future);
  final fallbackLat = 24.7136;
  final fallbackLng = 46.6753;
  final lat = locationData?.latitude ?? fallbackLat;
  final lng = locationData?.longitude ?? fallbackLng;

  return reportService.fetchNearby(
    lat: lat,
    lng: lng,
    radiusKm: filters.radiusKm,
    categories: filters.categories,
  );
});






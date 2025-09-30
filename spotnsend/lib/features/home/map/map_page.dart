import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:location/location.dart';

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:spotnsend/main.dart';

import 'package:spotnsend/core/router/routes.dart';

import 'package:spotnsend/core/utils/formatters.dart';

import 'package:spotnsend/data/models/report_models.dart';

import 'package:spotnsend/data/models/user_models.dart';

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

class _MapPageState extends ConsumerState<MapPage> with WidgetsBindingObserver {
  // Map state
  MaplibreMapController? _mapController;
  SymbolManager? _symbolManager;
  
  // Location and UI state
  LatLng _initialCenter = const LatLng(24.7136, 46.6753);
  LatLng? _userLocation;
  Symbol? _userLocationMarker;
  bool _markersInitialized = false;
  bool _imagesLoaded = false;
  double _currentZoom = 15.5;
  double? _lastScaledZoom;
  
  // Map interaction state
  String? _selectedSavedSpotId;
Map<int, String> _reportCategorySlugLookup = {};
  final List<sb.RealtimeChannel> _channels = [];
  StreamSubscription<sb.AuthState>? _authSub;
  
  // Live GeoJSON mode using Supabase
  bool _useLiveGeoJson = true;
  final Map<String, Map<String, dynamic>> _incidentsById = {};
  final Map<String, Map<String, dynamic>> _spotsById = {};
  Timer? _incidentsDebounce;
  Timer? _spotsDebounce;
  Duration _pushDebounce = const Duration(milliseconds: 16);
  
  // Geodesic radius as a filled polygon (real meters)
  Fill? _radiusFill;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = supabase.auth.onAuthStateChange.listen((_) async {
      await _unsubscribeAll();
      await _subscribeLiveChannels();
      await _pushAll();
    });
    _primeUserLocation();
    
    // Load markers immediately when the page is created
    _loadMarkersImmediately();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1) User location updates -> recenter & redraw radius
      ref.listen<AsyncValue<LocationData?>>(currentLocationProvider,
          (prev, next) async {
        next.whenOrNull(data: (data) async {
          if (data == null) return;
          final where = LatLng(data.latitude!, data.longitude!);
          _userLocation = where;
          _initialCenter = where;
          if (_mapController != null) {
            await _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: where, zoom: 15.5),
              ),
            );
            await _putUserMarker(where);
            await _drawSearchRadius();
          }
        });
      });
      
      // 2) Listen to the markers controller directly for instant updates
      ref.listen<AsyncValue<List<MapMarker>>>(mapMarkersControllerProvider, 
          (prev, next) async {
        if (_useLiveGeoJson) return; // skip legacy symbol syncing in live mode
        final controller = _mapController;
        if (controller == null) return;
        if (next.hasValue) {
          final markers = next.value ?? [];
          debugPrint('[MapPage] Markers from controller: count=${markers.length}');
          await _syncAllMarkers();
        }
      });
      
      // 3) Filters -> redraw radius, toggle saved spots, refresh reports
      ref.listen<ReportFilters>(mapFiltersProvider, (prev, next) async {
        final prevRadius = prev?.radiusKm;
        final prevSaved = prev?.includeSavedSpots;
        final prevCategories = prev?.categoryIds;
        final radiusChanged = prevRadius != next.radiusKm;
        final savedChanged = prevSaved != next.includeSavedSpots;
        final categoriesChanged = prevCategories == null
            ? next.categoryIds.isNotEmpty
            : !(prevCategories.containsAll(next.categoryIds) &&
                next.categoryIds.containsAll(prevCategories));
        if (radiusChanged) {
          await _drawSearchRadius(next.radiusKm);
        }
      });
    });
  }
  
  // Load markers immediately when the page is created
  void _loadMarkersImmediately() {
    final markersAsync = ref.read(mapMarkersControllerProvider);
    if (markersAsync.hasValue) {
      final markers = markersAsync.value ?? [];
      debugPrint('[MapPage] Loading markers immediately: count=${markers.length}');
      // We'll sync these markers when the map is created
    }
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
    final controller = _mapController;

    if (controller == null) return;
    
    // Reset flag to force reload
    _imagesLoaded = false;
    
    debugPrint('[MapPage] Loading map images...');

    Future<void> registerPin(String key, String assetPath) async {
      try {
        debugPrint('[MapPage] Loading pin image: $key from $assetPath');
        final bytes = await rootBundle.load(assetPath);
        await controller.addImage(key, bytes.buffer.asUint8List());
        debugPrint('[MapPage] Successfully loaded pin image: $key');
      } on PlatformException catch (error) {
        // Treat alreadyExists as success to avoid blocking repeated loads
        if (error.code == 'alreadyExists') {
          debugPrint('[MapPage] Pin image already registered: $key');
          return;
        }
        debugPrint('[MapPage] PlatformException registering image $key: ${error.message}');
      } catch (err, stack) {
        debugPrint('Failed to register map image $assetPath: $err');
        debugPrintStack(stackTrace: stack);
      }
    }
    
    // Add default report pin
    await registerPin('report_pin', 'assets/pins/select.png');
    
    // Register category icons
    await registerCategoryIcons(controller);

    // Register saved spot pins
    await registerPin(_savedSpotIconKey, 'assets/pins/saved_spot.png');
    await registerPin(
      _savedSpotSelectedIconKey,
      'assets/pins/saved_spot_selected.png',
    );

    debugPrint('[MapPage] All map images loaded successfully');
    _imagesLoaded = true;
  }

  Future<void> _ensureCategoryLookup() async {
    if (_reportCategorySlugLookup.isNotEmpty) return;

    try {
      final categories = await ref.read(reportCategoriesProvider.future);

      for (final category in categories) {
        _reportCategorySlugLookup[category.id] = category.slug;
      }
    } catch (_) {
      // Ignore failures; we'll fall back to the icon by category name.
    }
  }

  // -------------------- Live GeoJSON (Supabase) --------------------

  Future<void> _ensureLiveSourcesAndLayers() async {
    final c = _mapController;
    if (c == null) return;

    try {
      await c.addSource(
        'reports_src',
        GeojsonSourceProperties(
          data: {
            'type': 'FeatureCollection',
            'features': [],
          },
          cluster: true,
          clusterRadius: 50,
        ),
      );
    } catch (_) {}
    try {
      await c.addSymbolLayer(
        'reports_src',
        'reports_layer',
        SymbolLayerProperties(
          // Use per-feature icon with fallback to default
          iconImage: ['coalesce', ['get', 'icon'], 'report_pin'],
          iconSize: [
            'interpolate', ['linear'], ['zoom'],
            12, ['*', 0.6, ['to-number', ['get', 'rscale'], 1.0]],
            15.5, ['*', 0.85, ['to-number', ['get', 'rscale'], 1.0]],
            17, ['*', 1.15, ['to-number', ['get', 'rscale'], 1.0]],
          ],
          iconAnchor: 'bottom',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          // Rotate based on optional bearing property
          iconRotate: ['to-number', ['get', 'bearing'], 0],
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
      );
    } catch (_) {}

    try {
      await c.addSource(
        'spots_src',
        GeojsonSourceProperties(
          data: {
            'type': 'FeatureCollection',
            'features': [],
          },
        ),
      );
    } catch (_) {}
    try {
      await c.addSymbolLayer(
        'spots_src',
        'spots_layer',
        SymbolLayerProperties(
          iconImage: _savedSpotIconKey,
          iconSize: [
            'interpolate', ['linear'], ['zoom'],
            12, ['*', 0.5, ['to-number', ['get', 'rscale'], 1.0]],
            15.5, ['*', 0.8, ['to-number', ['get', 'rscale'], 1.0]],
            17, ['*', 1.05, ['to-number', ['get', 'rscale'], 1.0]],
          ],
          iconAnchor: 'bottom',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
      );
    } catch (_) {}
  }

  Map<String, dynamic> _featureCollection(Iterable<Map<String, dynamic>> features) {
    return {
      'type': 'FeatureCollection',
      'features': features.toList(growable: false),
    };
  }

  Map<String, dynamic> _pointFeature({
    required String id,
    required double lat,
    required double lng,
    Map<String, dynamic>? properties,
  }) {
    return {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'Point',
        'coordinates': [lng, lat],
      },
      'properties': properties ?? <String, dynamic>{},
    };
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _radiusScale(double radiusKm) {
    // 10km baseline = 1.0 scale; clamp to friendly range
    final s = radiusKm / 10.0;
    if (s < 0.8) return 0.8;
    if (s > 1.3) return 1.3;
    return s;
  }

  Future<void> _pushReports() async {
    final c = _mapController;
    if (c == null) return;
    try {
      final filters = ref.read(mapFiltersProvider);
      final center = _userLocation ?? _initialCenter;
      final activeCategoryIds = filters.categoryIds;
      final radiusKm = filters.radiusKm;
      final filtered = _incidentsById.values.where((feat) {
        final props = feat['properties'] as Map<String, dynamic>? ?? {};
        final coords = feat['geometry']['coordinates'] as List;
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        final withinRadius = _haversineKm(lat, lng, center.latitude, center.longitude) <= radiusKm;
        final cid = (props['category_id'] as num?)?.toInt();
        final matchesCategory = activeCategoryIds.isEmpty || (cid != null && activeCategoryIds.contains(cid));
        return withinRadius && matchesCategory;
      }).map((feat) {
        final props = Map<String, dynamic>.from(feat['properties'] as Map<String, dynamic>? ?? {});
        props['rscale'] = _radiusScale(radiusKm);
        return {
          ...feat,
          'properties': props,
        };
      });
      final fc = _featureCollection(filtered);
      await c.setGeoJsonSource('reports_src', fc);
    } catch (_) {}
  }

  Future<void> _pushFavoriteSpots() async {
    final c = _mapController;
    if (c == null) return;
    try {
      final filters = ref.read(mapFiltersProvider);
      if (!filters.includeSavedSpots) {
        await c.setGeoJsonSource('spots_src', _featureCollection(const []));
        return;
      }
      final center = _userLocation ?? _initialCenter;
      final radiusKm = filters.radiusKm;
      final filtered = _spotsById.values.where((feat) {
        final coords = feat['geometry']['coordinates'] as List;
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        return _haversineKm(lat, lng, center.latitude, center.longitude) <= radiusKm;
      }).map((feat) {
        final props = Map<String, dynamic>.from(feat['properties'] as Map<String, dynamic>? ?? {});
        props['rscale'] = _radiusScale(radiusKm);
        return {
          ...feat,
          'properties': props,
        };
      });
      final fc = _featureCollection(filtered);
      await c.setGeoJsonSource('spots_src', fc);
    } catch (_) {}
  }

  void _schedulePushReports() {
    _incidentsDebounce?.cancel();
    _incidentsDebounce = Timer(_pushDebounce, () {
      _pushReports();
    });
  }

  void _schedulePushFavoriteSpots() {
    _spotsDebounce?.cancel();
    _spotsDebounce = Timer(_pushDebounce, () {
      _pushFavoriteSpots();
    });
  }

  double _deg2rad(double deg) => deg * math.pi / 180.0;
  double _rad2deg(double rad) => rad * 180.0 / math.pi;
  double _bearingDegrees(double fromLat, double fromLng, double toLat, double toLng) {
    final dLon = _deg2rad(toLng - fromLng);
    final a = math.sin(dLon) * math.cos(_deg2rad(toLat));
    final b = math.cos(_deg2rad(fromLat)) * math.sin(_deg2rad(toLat)) -
        math.sin(_deg2rad(fromLat)) * math.cos(_deg2rad(toLat)) * math.cos(dLon);
    var brng = math.atan2(a, b);
    brng = _rad2deg(brng);
    return (brng + 360) % 360;
  }

  Future<void> _initialLoadAndSubscribe() async {
    final bounds = await _mapController?.getVisibleRegion();
    final minLat = bounds?.southwest.latitude ?? (_userLocation?.latitude ?? _initialCenter.latitude);
    final minLng = bounds?.southwest.longitude ?? (_userLocation?.longitude ?? _initialCenter.longitude);
    final maxLat = bounds?.northeast.latitude ?? (_userLocation?.latitude ?? _initialCenter.latitude);
    final maxLng = bounds?.northeast.longitude ?? (_userLocation?.longitude ?? _initialCenter.longitude);

    try {
      final initialReports = await supabase
          .from('reports')
          .select('*')
          .gte('latitude', minLat)
          .lte('latitude', maxLat)
          .gte('longitude', minLng)
          .lte('longitude', maxLng)
          .filter('deleted_at', 'is', null);
      for (final row in initialReports.whereType<Map<String, dynamic>>()) {
        final id = (row['report_id'] ?? row['id']).toString();
        final lat = (row['latitude'] as num).toDouble();
        final lng = (row['longitude'] as num).toDouble();
        await _ensureCategoryLookup();
        final cid = (row['category_id'] as num?)?.toInt();
        final slug = cid != null ? _reportCategorySlugLookup[cid] : null;
        final iconKey = mapImageKeyForSlug(slug) ?? 'report_pin';
        final props = {
          'icon': iconKey,
          'category_id': cid,
          'created_at': row['created_at'],
        };
        _incidentsById[id] = _pointFeature(id: id, lat: lat, lng: lng, properties: props);
      }
      _schedulePushReports();

      final initialSpots = await supabase
          .from('favorite_spots')
          .select('*')
          .gte('latitude', minLat)
          .lte('latitude', maxLat)
          .gte('longitude', minLng)
          .lte('longitude', maxLng);
      for (final row in initialSpots.whereType<Map<String, dynamic>>()) {
        final id = (row['favorite_spot_id'] ?? row['id']).toString();
        final lat = (row['latitude'] as num).toDouble();
        final lng = (row['longitude'] as num).toDouble();
        final props = {
          'user_id': row['user_id'],
          'created_at': row['created_at'],
        };
        _spotsById[id] = _pointFeature(id: id, lat: lat, lng: lng, properties: props);
      }
      _schedulePushFavoriteSpots();
    } catch (_) {}

    final incCh = supabase.channel('public:reports')
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.insert,
        schema: 'public',
        table: 'reports',
        callback: (payload) {
          final r = payload.newRecord;
          if (r == null) return;
          final id = (r['report_id'] ?? r['id']).toString();
          final lat = (r['latitude'] as num).toDouble();
          final lng = (r['longitude'] as num).toDouble();
          final cid = (r['category_id'] as num?)?.toInt();
          final slug = cid != null ? _reportCategorySlugLookup[cid] : null;
          final iconKey = mapImageKeyForSlug(slug) ?? 'report_pin';
          final props = {
            'icon': iconKey,
            'category_id': cid,
            'created_at': r['created_at'],
          };
          _incidentsById[id] = _pointFeature(id: id, lat: lat, lng: lng, properties: props);
          _schedulePushReports();
        },
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.update,
        schema: 'public',
        table: 'reports',
        callback: (payload) {
          final r = payload.newRecord;
          if (r == null) return;
          final id = (r['report_id'] ?? r['id']).toString();
          final lat = (r['latitude'] as num).toDouble();
          final lng = (r['longitude'] as num).toDouble();
          final prev = _incidentsById[id];
          final cid = (r['category_id'] as num?)?.toInt();
          final slug = cid != null ? _reportCategorySlugLookup[cid] : null;
          final iconKey = mapImageKeyForSlug(slug) ?? 'report_pin';
          final props = {
            'icon': iconKey,
            'category_id': cid,
            'created_at': r['created_at'],
          };
          double? bearing;
          if (prev != null) {
            final coords = prev['geometry']['coordinates'] as List;
            final prevLng = (coords[0] as num).toDouble();
            final prevLat = (coords[1] as num).toDouble();
            bearing = _bearingDegrees(prevLat, prevLng, lat, lng);
          }
          final nextProps = {
            ...?prev?['properties'] as Map<String, dynamic>?,
            ...props,
            if (bearing != null) 'bearing': bearing,
          };
          _incidentsById[id] = _pointFeature(id: id, lat: lat, lng: lng, properties: nextProps);
          _schedulePushReports();
        },
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.delete,
        schema: 'public',
        table: 'reports',
        callback: (payload) {
          final r = payload.oldRecord;
          if (r == null) return;
          final id = (r['report_id'] ?? r['id']).toString();
          _incidentsById.remove(id);
          _schedulePushReports();
        },
      );
    await incCh.subscribe();
    _channels.add(incCh);

    final spotsCh = supabase.channel('public:favorite_spots')
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.insert,
        schema: 'public',
        table: 'favorite_spots',
        callback: (payload) {
          final r = payload.newRecord;
          if (r == null) return;
          final id = (r['favorite_spot_id'] ?? r['id']).toString();
          final lat = (r['latitude'] as num).toDouble();
          final lng = (r['longitude'] as num).toDouble();
          final props = {
            'user_id': r['user_id'],
            'created_at': r['created_at'],
          };
          _spotsById[id] = _pointFeature(id: id, lat: lat, lng: lng, properties: props);
          _schedulePushFavoriteSpots();
        },
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.update,
        schema: 'public',
        table: 'favorite_spots',
        callback: (payload) {
          final r = payload.newRecord;
          if (r == null) return;
          final id = (r['favorite_spot_id'] ?? r['id']).toString();
          final lat = (r['latitude'] as num).toDouble();
          final lng = (r['longitude'] as num).toDouble();
          final props = {
            'user_id': r['user_id'],
            'created_at': r['created_at'],
          };
          _spotsById[id] = _pointFeature(id: id, lat: lat, lng: lng, properties: props);
          _schedulePushFavoriteSpots();
        },
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.delete,
        schema: 'public',
        table: 'favorite_spots',
        callback: (payload) {
          final r = payload.oldRecord;
          if (r == null) return;
          final id = (r['favorite_spot_id'] ?? r['id']).toString();
          _spotsById.remove(id);
          _schedulePushFavoriteSpots();
        },
      );
    await spotsCh.subscribe();
    _channels.add(spotsCh);

    _startTtlSweeper();
  }

  Timer? _ttlSweeper;
  void _startTtlSweeper() {
    _ttlSweeper?.cancel();
    _ttlSweeper = Timer.periodic(const Duration(seconds: 45), (_) {
      final now = DateTime.now().toUtc();
      final toRemove = <String>[];
      _incidentsById.forEach((id, feat) {
        final props = feat['properties'] as Map<String, dynamic>;
        // If deleted_at is present and before now, remove; otherwise respect TTL if provided
        final deletedAt = props['deleted_at'];
        if (deletedAt != null) {
          try {
            final dt = deletedAt is String ? DateTime.parse(deletedAt).toUtc() : (deletedAt as DateTime).toUtc();
            if (dt.isBefore(now)) toRemove.add(id);
          } catch (_) {}
        } else {
          final ttlMinutes = (props['ttl_minutes_override'] as num?)?.toInt();
          final createdAt = props['created_at'];
          if (ttlMinutes != null && createdAt != null) {
            try {
              final created = createdAt is String ? DateTime.parse(createdAt).toUtc() : (createdAt as DateTime).toUtc();
              final ttlUntil = created.add(Duration(minutes: ttlMinutes));
              if (ttlUntil.isBefore(now)) toRemove.add(id);
            } catch (_) {}
          }
        }
      });
      for (final id in toRemove) {
        _incidentsById.remove(id);
      }
      if (toRemove.isNotEmpty) _schedulePushReports();
    });
  }

  Future<void> _pushAll() async {
    if (_useLiveGeoJson) {
      await _pushReports();
      await _pushFavoriteSpots();
    } else {
      await _syncAllMarkers();
    }
  }

  Future<void> _unsubscribeAll() async {
    for (final ch in _channels) {
      try {
        await ch.unsubscribe();
      } catch (_) {}
    }
    _channels.clear();
  }

  Future<void> _subscribeLiveChannels() async {
    // Reports channel
    final incCh = supabase.channel('public:reports')
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.insert,
        schema: 'public',
        table: 'reports',
        callback: (payload) {
          final r = payload.newRecord;
          if (r == null) return;
          final id = (r['report_id'] ?? r['id']).toString();
          final lat = (r['latitude'] as num).toDouble();
          final lng = (r['longitude'] as num).toDouble();
          final cid = (r['category_id'] as num?)?.toInt();
          final slug = cid != null ? _reportCategorySlugLookup[cid] : null;
          final iconKey = mapImageKeyForSlug(slug) ?? 'report_pin';
          final props = {
            'icon': iconKey,
            'category_id': cid,
            'created_at': r['created_at'],
          };
          _incidentsById[id] = _pointFeature(id: id, lat: lat, lng: lng, properties: props);
          _schedulePushReports();
        },
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.update,
        schema: 'public',
        table: 'reports',
        callback: (payload) {
          final r = payload.newRecord;
          if (r == null) return;
          final id = (r['report_id'] ?? r['id']).toString();
          final lat = (r['latitude'] as num).toDouble();
          final lng = (r['longitude'] as num).toDouble();
          final prev = _incidentsById[id];
          final cid = (r['category_id'] as num?)?.toInt();
          final slug = cid != null ? _reportCategorySlugLookup[cid] : null;
          final iconKey = mapImageKeyForSlug(slug) ?? 'report_pin';
          final props = {
            'icon': iconKey,
            'category_id': cid,
            'created_at': r['created_at'],
          };
          double? bearing;
          if (prev != null) {
            final coords = prev['geometry']['coordinates'] as List;
            final prevLng = (coords[0] as num).toDouble();
            final prevLat = (coords[1] as num).toDouble();
            bearing = _bearingDegrees(prevLat, prevLng, lat, lng);
          }
          final nextProps = {
            ...?prev?['properties'] as Map<String, dynamic>?,
            ...props,
            if (bearing != null) 'bearing': bearing,
          };
          _incidentsById[id] = _pointFeature(id: id, lat: lat, lng: lng, properties: nextProps);
          _schedulePushReports();
        },
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.delete,
        schema: 'public',
        table: 'reports',
        callback: (payload) {
          final r = payload.oldRecord;
          if (r == null) return;
          final id = (r['report_id'] ?? r['id']).toString();
          _incidentsById.remove(id);
          _schedulePushReports();
        },
      );
    await incCh.subscribe();
    _channels.add(incCh);

    // Favorite spots channel
    final spotsCh = supabase.channel('public:favorite_spots')
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.insert,
        schema: 'public',
        table: 'favorite_spots',
        callback: (payload) {
          final r = payload.newRecord;
          if (r == null) return;
          final id = (r['favorite_spot_id'] ?? r['id']).toString();
          final lat = (r['latitude'] as num).toDouble();
          final lng = (r['longitude'] as num).toDouble();
          final props = {
            'user_id': r['user_id'],
            'created_at': r['created_at'],
          };
          _spotsById[id] = _pointFeature(id: id, lat: lat, lng: lng, properties: props);
          _schedulePushFavoriteSpots();
        },
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.update,
        schema: 'public',
        table: 'favorite_spots',
        callback: (payload) {
          final r = payload.newRecord;
          if (r == null) return;
          final id = (r['favorite_spot_id'] ?? r['id']).toString();
          final lat = (r['latitude'] as num).toDouble();
          final lng = (r['longitude'] as num).toDouble();
          final props = {
            'user_id': r['user_id'],
            'created_at': r['created_at'],
          };
          _spotsById[id] = _pointFeature(id: id, lat: lat, lng: lng, properties: props);
          _schedulePushFavoriteSpots();
        },
      )
      ..onPostgresChanges(
        event: sb.PostgresChangeEvent.delete,
        schema: 'public',
        table: 'favorite_spots',
        callback: (payload) {
          final r = payload.oldRecord;
          if (r == null) return;
          final id = (r['favorite_spot_id'] ?? r['id']).toString();
          _spotsById.remove(id);
          _schedulePushFavoriteSpots();
        },
      );
    await spotsCh.subscribe();
    _channels.add(spotsCh);
  }

  

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-initialize style-dependent state and re-push data
      () async {
        await _unsubscribeAll();
        _imagesLoaded = false;
        await _ensureMapImagesLoaded();
        if (_useLiveGeoJson) {
          await _ensureLiveSourcesAndLayers();
        }
        await _pushAll();
        await _subscribeLiveChannels();
      }();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _authSub?.cancel();
    } catch (_) {}
    _ttlSweeper?.cancel();
    _incidentsDebounce?.cancel();
    _spotsDebounce?.cancel();
    for (final ch in _channels) {
      try {
        ch.unsubscribe();
      } catch (_) {}
    }
    _channels.clear();
    super.dispose();
  }

  /// Sync all markers to the map
  Future<void> _syncAllMarkers() async {
    if (_mapController == null) {
      debugPrint('[MapPage] Cannot sync markers: controller is null');
      return;
    }

    // Ensure all images are loaded before we try to render them
    if (!_imagesLoaded) {
      await _ensureMapImagesLoaded();
    }
    
    // Also ensure we have category data to map icons correctly (non-blocking)
    unawaited(_ensureCategoryLookup());

    try {
      debugPrint('[MapPage] Starting marker sync...');
      
      // Clear existing symbols first
      await _mapController!.clearSymbols();
      debugPrint('[MapPage] Cleared existing symbols');

      // Get current markers
      final markersAsync = ref.read(mapMarkersControllerProvider);
      if (!markersAsync.hasValue) {
        debugPrint('[MapPage] No markers data available');
        return;
      }

      final markers = markersAsync.value ?? [];
      debugPrint('[MapPage] Syncing ${markers.length} markers');

      // Add markers to map
      for (final marker in markers) {
        await _addMarkerToMap(marker);
      }

      debugPrint('[MapPage] Marker sync completed successfully');
    } catch (e, stack) {
      debugPrint('[MapPage] Error syncing markers: $e');
      debugPrint('[MapPage] Stack trace: $stack');
    }
  }

  /// Add a single marker to the map
  Future<void> _addMarkerToMap(MapMarker marker) async {

    try {
      String iconImage;
      double iconSize;

      if (marker.type == 'report') {
        final report = marker.data as Report;
        iconImage = _iconImageForReport(report);
        iconSize = _iconSizeForZoom(_mapController!.cameraPosition?.zoom ?? 10.0);
      } else if (marker.type == 'saved_spot') {
        // Use the registered saved spot icon key
        iconImage = _savedSpotIconKey;
        iconSize = _savedSpotIconSize(_mapController!.cameraPosition?.zoom ?? 10.0);
      } else {
        debugPrint('[MapPage] Unknown marker type: ${marker.type}');
        return;
      }

      // Create symbol options
      final symbolOptions = SymbolOptions(
        geometry: LatLng(marker.lat, marker.lng),
        iconImage: iconImage,
        iconSize: iconSize,
        iconAnchor: 'bottom',
      );

      // Add symbol to map
      await _mapController!.addSymbol(symbolOptions);
      debugPrint('[MapPage] Added ${marker.type} marker: ${marker.id}');
      
    } catch (e) {
      debugPrint('[MapPage] Error adding marker ${marker.id}: $e');
      
      // Try with fallback icon
      try {
        final fallbackOptions = SymbolOptions(
          geometry: LatLng(marker.lat, marker.lng),
          iconImage: 'report_pin', // Default fallback
          iconSize: 0.5,
          iconAnchor: 'bottom',
        );
        await _mapController!.addSymbol(fallbackOptions);
        debugPrint('[MapPage] Added fallback marker for: ${marker.id}');
      } catch (fallbackError) {
        debugPrint('[MapPage] Failed to add fallback marker: $fallbackError');
      }
    }
  }

  /// Get icon image name for a report
  String _iconImageForReport(Report report) {
    try {
      // Prefer explicit slug if available, otherwise derive from category name
      final keyFromSlug = mapImageKeyForSlug(report.categorySlug);
      final keyFromName = keyFromSlug ?? mapImageKeyForCategoryName(report.categoryName);

      if (keyFromName != null) {
        debugPrint('[MapPage] Using category icon key: $keyFromName');
        return keyFromName;
      }

      // Fallback to default report icon
      debugPrint('[MapPage] Using fallback icon for category: ${report.category}');
      return 'report_pin';
    } catch (e) {
      debugPrint('[MapPage] Error getting icon for report: $e');
      return 'report_pin';
    }
  }

  double _iconSizeForZoom(double zoom) {
    const base = 0.8;
    if (zoom >= 17) return base * 1.2;
    if (zoom >= 15.5) return base * 1.05;
    if (zoom >= 14) return base * 0.9;
    if (zoom >= 12) return base * 0.75;
    return base * 0.6;
  }

  double _savedSpotIconSize(double zoom) {
    if (zoom >= 17) return 0.95;
    if (zoom >= 15.5) return 0.85;
    if (zoom >= 14) return 0.75;
    if (zoom >= 12) return 0.65;
    return 0.5;
  }

  Future<void> _applyMarkerScaling() async {
    final controller = _mapController;
    if (controller == null || _symbolManager == null) return;

    if (_lastScaledZoom != null &&
        (_currentZoom - _lastScaledZoom!).abs() < 0.12) {
      return;
    }

    _lastScaledZoom = _currentZoom;

    // For now, we'll re-sync all markers to apply new scaling
    // In a full implementation, you'd track individual symbols and update them
    await _syncAllMarkers();
  }

  /// Handle symbol tap events
  void _onSymbolTapped(Symbol symbol) async {
    try {
      final markersAsync = ref.read(mapMarkersControllerProvider);
      if (!markersAsync.hasValue) return;

      final markers = markersAsync.value ?? [];

      final geometry = symbol.options.geometry;
      if (geometry == null) return;

      final tappedLat = geometry.latitude;
      final tappedLng = geometry.longitude;

      // Match markers by position (small tolerance for float precision)
      const tolerance = 0.000001;
      final match = markers.where((m) =>
          (m.lat - tappedLat).abs() < tolerance &&
          (m.lng - tappedLng).abs() < tolerance);
      final matchingMarker = match.isNotEmpty ? match.first : null;

      if (matchingMarker == null) return;

      if (matchingMarker.type == 'report') {
        final report = matchingMarker.data as Report;
        _openReportDetails(report);
      } else if (matchingMarker.type == 'saved_spot') {
        final savedSpot = matchingMarker.data as SavedSpot;
        _selectedSavedSpotId = savedSpot.id;
        await _highlightSavedSpot(savedSpot.id);
      }
    } catch (e) {
      debugPrint('[MapPage] Error handling symbol tap: $e');
    }
  }

  Future<void> _highlightSavedSpot(String savedSpotId) async {
    final controller = _mapController;
    if (controller == null) return;

    try {
      // For now, we'll just show a toast since we don't have direct symbol-to-marker mapping
      // In a full implementation, you'd need to track symbols by their data
      final savedSpots = ref.read(accountSavedSpotsProvider).value ?? [];
      final match = savedSpots.where((spot) => spot.id == savedSpotId);
      final SavedSpot? savedSpot = match.isNotEmpty ? match.first : null;
      
      if (savedSpot != null) {
        showSuccessToast(
          context,
          '${savedSpot.name}\n${AppLocalizations.current.formatCoordinates(savedSpot.lat, savedSpot.lng)}',
        );
      }
    } catch (e) {
      debugPrint('[MapPage] Error highlighting saved spot: $e');
    }
  }

  Future<void> _putUserMarker(LatLng at) async {
    final controller = _mapController;

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
    final controller = _mapController;

    if (controller == null) return;

    final effectiveRadiusKm = radiusKm ?? ref.read(mapFiltersProvider).radiusKm;

    final center = _userLocation ?? _initialCenter;

    final ring = _buildCircleRing(center, effectiveRadiusKm);

    if (ring == null) {
      if (_radiusFill != null) {
        try {
          await controller.removeFill(_radiusFill!);
        } catch (_) {
          // ignore stale handle removal errors
        }

        _radiusFill = null;
      }

      return;
    }

    final fillOptions = FillOptions(
      geometry: [ring],
      fillColor: '#4285F4',
      fillOpacity: 0.12,
      fillOutlineColor: '#4285F4',
    );

    if (_radiusFill == null) {
      _radiusFill = await controller.addFill(fillOptions);

      return;
    }

    try {
      await controller.updateFill(_radiusFill!, fillOptions);
    } catch (_) {
      try {
        await controller.removeFill(_radiusFill!);
      } catch (_) {
        // ignore cleanup failure and recreate below
      }

      _radiusFill = await controller.addFill(fillOptions);
    }
  }

  List<LatLng>? _buildCircleRing(LatLng center, double radiusKm) {
    if (radiusKm <= 0) {
      return null;
    }

    const double earthRadiusMeters = 6378137.0;

    const int segments = 128;

    final double radiusMeters = radiusKm * 1000;

    final double latRadians = center.latitude * math.pi / 180;

    final List<LatLng> ring = <LatLng>[];

    for (int i = 0; i <= segments; i++) {
      final double theta = (i / segments) * 2 * math.pi;

      final double latitude = center.latitude +
          (radiusMeters / earthRadiusMeters) *
              (180 / math.pi) *
              math.cos(theta);

      final double longitude = center.longitude +
          (radiusMeters / earthRadiusMeters) *
              (180 / math.pi) *
              math.sin(theta) /
              math.cos(latRadians);

      ring.add(LatLng(latitude, longitude));
    }

    return ring;
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

  void _handleBack() {
    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  // -------------------- Build --------------------

  @override
  Widget build(BuildContext context) {
    final mapStyleUrl = ref.watch(mapStyleUrlProvider);

    final filters = ref.watch(mapFiltersProvider);

    final reportsAsync = ref.watch(mapReportsStreamProvider); // Use stream provider

    final permissionAsync = ref.watch(locationPermissionProvider);

    final media = MediaQuery.of(context);

    final theme = Theme.of(context);

    final topInset = media.padding.top + 16;

    final bottomInset = media.padding.bottom + 24;

    final canNavigateBack = Navigator.of(context).canPop();

    final radiusLabel = filters.radiusKm >= 1
        ? '${filters.radiusKm.toStringAsFixed(1)} km'
        : '${(filters.radiusKm * 1000).round()} m';

    final missingKey = mapStyleUrl.contains('YOUR_KEY_HERE');

    final String? errorText = reportsAsync.maybeWhen<String?>(
      error: (error, _) => error.toString(),
      orElse: () => null,
    );

    final int? activeCount = reportsAsync.maybeWhen<int?>(
      data: (value) => value.length,
      orElse: () => null,
    );

    // Build markers from reports and saved spots
    final reports = reportsAsync.value ?? [];
    debugPrint('[MapPage] build() reports count: \\${reports.length}');
    for (final r in reports) {
      debugPrint('[MapPage] build() Report: id=\\${r.id}, lat=\\${r.lat}, lng=\\${r.lng}');
    }
    final savedSpots = ref.watch(accountSavedSpotsProvider).value ?? [];
    final markers = [
      ...reports.map((r) => MapMarker(
        id: r.id,
        lat: r.lat,
        lng: r.lng,
        type: 'report',
        data: r,
      )),
      ...savedSpots.map((s) => MapMarker(
        id: s.id,
        lat: s.lat,
        lng: s.lng,
        type: 'saved_spot',
        data: s,
      )),
    ];
    debugPrint('[MapPage] build() markers count: \\${markers.length}');

    // Debug: show marker coordinates in the UI
    Widget markerDebugWidget = const SizedBox.shrink();
    if (markers.isNotEmpty) {
      final coords = markers
          .map((m) => '(${m.lat.toStringAsFixed(5)}, ${m.lng.toStringAsFixed(5)})')
          .join('\n');
      markerDebugWidget = Positioned(
        right: 10,
        bottom: 10,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Markers:\n$coords',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      );
    }

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
              onCameraIdle: () async {
                final position = _mapController?.cameraPosition;
                if (position != null) {
                  _currentZoom = position.zoom;
                }
                await _applyMarkerScaling();
              },
              onStyleLoadedCallback: () async {
                _imagesLoaded = false;
                await _ensureMapImagesLoaded();
                await _drawSearchRadius();
                if (_useLiveGeoJson) {
                  await _ensureLiveSourcesAndLayers();
                  // Immediately show cached data, then ensure subscriptions
                  await _pushAll();
                  if (_incidentsById.isEmpty && _spotsById.isEmpty) {
                    await _initialLoadAndSubscribe();
                  } else if (_channels.isEmpty) {
                    await _subscribeLiveChannels();
                  }
                } else {
                  await _syncAllMarkers();
                }
              },
              onMapClick: (point, latLng) async {
                try {
                  final rendered = await _mapController?.queryRenderedFeatures(
                    math.Point<double>(point.x, point.y),
                    ['reports_layer', 'spots_layer'],
                    const [],
                  );
                  if (rendered == null || rendered.isEmpty) return;
                  final props = rendered.first.properties ?? <String, dynamic>{};
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(props.toString())));
                } catch (e) {
                  debugPrint('queryRenderedFeatures error: $e');
                }
              },
              onMapCreated: (controller) async {
                _mapController = controller;

                _imagesLoaded = false;
                await _ensureMapImagesLoaded();

                final symbolManager = controller.symbolManager;
                if (symbolManager != null) {
                  await symbolManager.setIconAllowOverlap(true);
                  await symbolManager.setIconIgnorePlacement(true);
                  await symbolManager.setTextAllowOverlap(true);
                  await symbolManager.setTextIgnorePlacement(true);
                }

                controller.onSymbolTapped.add((symbol) {
                  _onSymbolTapped(symbol);
                });

                // Immediately load and display markers
                final markersAsync = ref.read(mapMarkersControllerProvider);
                if (markersAsync.hasValue) {
                  final markersToShow = markersAsync.value ?? [];
                  debugPrint('[MapPage] Displaying markers on map creation: ${markersToShow.length}');
                  await _syncAllMarkers();
                  _markersInitialized = true;
                } else {
                  await _syncAllMarkers();
                }

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
              },
            ),
          ),

          // Debug widget for marker coordinates (sibling in the Stack)
          if (markers.isNotEmpty) markerDebugWidget,

          if (missingKey)
            const Align(
              alignment: Alignment.center,
              child: _MissingKeyNotice(),
            ),

          Positioned(
            top: topInset,
            left: canNavigateBack ? 72 : 16,
            right: 120,
            child: _MapOverviewCard(
              radiusLabel: radiusLabel,
              includeSavedSpots: filters.includeSavedSpots,
              isLoading: reportsAsync.isLoading,
              activeCount: activeCount,
            ),
          ),

          if (canNavigateBack)
            Positioned(
              top: topInset,
              left: 16,
              child: SafeArea(
                bottom: false,
                child: FloatingActionButton.small(
                  heroTag: 'map-back',
                  onPressed: _handleBack,
                  child: const Icon(Icons.arrow_back_rounded),
                ),
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

    Widget infoPill({
      required IconData icon,
      required String text,
    }) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final chips = <Widget>[
      infoPill(
        icon: Icons.radar,
        text: 'Radius: $radiusLabel',
      ),
      infoPill(
        icon: includeSavedSpots ? Icons.bookmark_added : Icons.bookmark_border,
        text:
            includeSavedSpots ? 'Saved spots on'.tr() : 'Saved spots off'.tr(),
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

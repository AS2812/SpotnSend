import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';

class LocationPicker extends ConsumerStatefulWidget {
  const LocationPicker({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
  });

  final LatLng? initialLocation;
  final Function(LatLng location) onLocationSelected;

  @override
  ConsumerState<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<LocationPicker> {
  MaplibreMapController? _controller;
  LatLng? _selectedLocation;
  Symbol? _selectedSymbol;
  static const _selectionIconKey = 'location-picker-selection';
  bool _hasCustomSelectionIcon = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _primeInitialLocation();
  }

  Future<void> _primeInitialLocation() async {
    if (_selectedLocation != null) return;
    try {
      final location = await ref.read(currentLocationProvider.future);
      final lat = location?.latitude;
      final lng = location?.longitude;
      if (lat != null && lng != null) {
        setState(() {
          _selectedLocation = LatLng(lat, lng);
        });
      }
    } catch (_) {
      // ignore; fallback to default camera
    }
  }

  Future<void> _onMapCreated(MaplibreMapController controller) async {
    _controller = controller;
    await _ensureSelectionIcon();

    final initial = _selectedLocation ?? widget.initialLocation;
    if (initial != null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: initial, zoom: 15),
        ),
      );
      await _addMarker(initial);
    }

    // Set up tap handler
    _controller!.onSymbolTapped.add((symbol) {
      // Allow tapping the existing marker to move it
    });
  }

  Future<void> _ensureSelectionIcon() async {
    if (_controller == null) return;
    try {
      final bytes = await rootBundle.load('assets/pins/select.png');
      await _controller!.addImage(
        _selectionIconKey,
        bytes.buffer.asUint8List(),
      );
      _hasCustomSelectionIcon = true;
    } on PlatformException catch (error) {
      // treat "already exists" as success so we can use the custom icon
      if (error.code == 'alreadyExists') {
        _hasCustomSelectionIcon = true;
        return;
      }
      _hasCustomSelectionIcon = false;
    } catch (_) {
      // silently fall back to default glyph
      _hasCustomSelectionIcon = false;
    }
  }

  void _onMapTapped(LatLng coordinates) async {
    setState(() {
      _selectedLocation = coordinates;
    });
    await _addMarker(coordinates);
  }

  Future<void> _addMarker(LatLng location) async {
    if (_controller == null) return;

    // Remove existing marker
    if (_selectedSymbol != null) {
      await _controller!.removeSymbol(_selectedSymbol!);
    }

    await _ensureSelectionIcon();
  final icon = _hasCustomSelectionIcon ? _selectionIconKey : 'marker-15';
    _selectedSymbol = await _controller!.addSymbol(
      SymbolOptions(
        geometry: location,
        iconImage: icon,
        iconColor: '#2196F3',
        iconSize: icon == _selectionIconKey ? 0.65 : 0.9,
        iconAnchor: 'bottom',
      ),
    );
  }

  Future<void> _centerOnCurrentLocation() async {
    try {
      final location = await ref.read(currentLocationProvider.future);
      final lat = location?.latitude;
      final lng = location?.longitude;
      if (lat == null || lng == null) return;
      final target = LatLng(lat, lng);
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 15.5),
        ),
      );
      setState(() {
        _selectedLocation = target;
      });
      await _addMarker(target);
    } catch (_) {
      // ignore when location unavailable
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapStyleUrl = ref.watch(mapStyleUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location'.tr()),
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: () {
                widget.onLocationSelected(_selectedLocation!);
                Navigator.of(context).pop();
              },
              child: Text('Done'.tr()),
            ),
        ],
      ),
      body: Stack(
        children: [
          MaplibreMap(
            styleString: mapStyleUrl,
            onMapCreated: _onMapCreated,
            onMapClick: (_, coordinates) => _onMapTapped(coordinates),
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ??
                  widget.initialLocation ??
                  const LatLng(24.7136, 46.6753),
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.none,
            myLocationRenderMode: MyLocationRenderMode.gps,
          ),
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'picker-my-location',
              onPressed: _centerOnCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          // Instructions overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap on the map to select a location'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom location info
          if (_selectedLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Location'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                      'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Confirm Location'.tr(),
                      onPressed: () {
                        widget.onLocationSelected(_selectedLocation!);
                        Navigator.of(context).pop();
                      },
                      icon: Icons.check,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Extension method to show the location picker
extension LocationPickerExtension on BuildContext {
  Future<LatLng?> showLocationPicker({LatLng? initialLocation}) async {
    LatLng? selectedLocation;

    await Navigator.of(this).push(
      MaterialPageRoute<void>(
        builder: (context) => LocationPicker(
          initialLocation: initialLocation,
          onLocationSelected: (location) {
            selectedLocation = location;
          },
        ),
        fullscreenDialog: true,
      ),
    );

    return selectedLocation;
  }
}

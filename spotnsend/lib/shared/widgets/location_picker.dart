import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  Future<void> _onMapCreated(MaplibreMapController controller) async {
    _controller = controller;

    // Add initial marker if location is provided
    if (widget.initialLocation != null) {
      await _addMarker(widget.initialLocation!);
    }

    // Set up tap handler
    _controller!.onSymbolTapped.add((symbol) {
      // Allow tapping the existing marker to move it
    });
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

    // Add new marker
    _selectedSymbol = await _controller!.addSymbol(
      SymbolOptions(
        geometry: location,
        iconImage: 'marker-15',
        iconColor: '#2196F3',
        iconSize: 1.2,
      ),
    );
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
              target: widget.initialLocation ?? const LatLng(24.7136, 46.6753),
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.none,
            myLocationRenderMode: MyLocationRenderMode.gps,
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

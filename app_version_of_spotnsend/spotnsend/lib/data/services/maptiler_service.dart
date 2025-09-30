import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/config/app_config.dart';

final mapTilerKeyProvider = Provider<String>((ref) {
  return AppConfig.mapTilerKey;
});

final mapTilerServiceProvider = Provider<MapTilerService>((ref) {
  final key = ref.watch(mapTilerKeyProvider);
  return MapTilerService(key);
});

class MapTilerService {
  const MapTilerService(this.key);

  final String key;

  String get styleUrl => 'https://api.maptiler.com/maps/streets-v2/style.json?key=$key';
}

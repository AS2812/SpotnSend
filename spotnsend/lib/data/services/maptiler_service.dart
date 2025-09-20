import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

const _fallbackMapTilerKey = 'baucnweLIulZSBRwopDh';

final mapTilerKeyProvider = Provider<String>((ref) {
  const envKey = String.fromEnvironment('MAPTILER_KEY', defaultValue: '');
  return envKey.isNotEmpty ? envKey : _fallbackMapTilerKey;
});

final mapTilerServiceProvider = Provider<MapTilerService>((ref) {
  final key = ref.watch(mapTilerKeyProvider);
  return MapTilerService(key);
});

class MapTilerService {
  const MapTilerService(this.key);

  final String key;

  String get styleUrl => 'https://api.maptiler.com/maps/streets-v2/style.json?key=' + key;
}


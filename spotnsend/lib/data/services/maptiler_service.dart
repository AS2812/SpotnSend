<<<<<<< HEAD
import 'package:flutter_riverpod/flutter_riverpod.dart';
=======
﻿import 'package:flutter_riverpod/flutter_riverpod.dart';
<<<<<<< HEAD
import 'package:flutter_riverpod/legacy.dart';

const _fallbackMapTilerKey = 'baucnweLIulZSBRwopDh';

final mapTilerKeyProvider = Provider<String>((ref) {
  const envKey = String.fromEnvironment('MAPTILER_KEY', defaultValue: '');
  return envKey.isNotEmpty ? envKey : _fallbackMapTilerKey;
=======
>>>>>>> 12476f4562425887d3e031348f0a8cc3344211f0

import 'package:spotnsend/core/config/app_config.dart';

final mapTilerKeyProvider = Provider<String>((ref) {
  return AppConfig.mapTilerKey;
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768
});

final mapTilerServiceProvider = Provider<MapTilerService>((ref) {
  final key = ref.watch(mapTilerKeyProvider);
  return MapTilerService(key);
});

class MapTilerService {
  const MapTilerService(this.key);

  final String key;

<<<<<<< HEAD
  String get styleUrl => 'https://api.maptiler.com/maps/streets-v2/style.json?key=' + key;
}

=======
  String get styleUrl => 'https://api.maptiler.com/maps/streets-v2/style.json?key=$key';
}
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768

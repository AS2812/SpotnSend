import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static String get apiBaseUrl {
    final value = dotenv.maybeGet('API_BASE_URL');
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
    return 'http://10.0.2.2:8080/api';
  }

  static String get mapTilerKey {
    final value = dotenv.maybeGet('MAPTILER_KEY');
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
    return 'baucnweLIulZSBRwopDh';
  }
}

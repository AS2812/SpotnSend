import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static String get mapTilerKey {
    final value = dotenv.maybeGet('MAPTILER_KEY');
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
    return 'baucnweLIulZSBRwopDh';
  }
}

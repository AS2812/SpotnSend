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

  static String? get geminiApiKey {
    final value = dotenv.maybeGet('GEMINI_API_KEY');
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}

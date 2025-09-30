import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/settings_models.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

class SettingsService {
  AppSettings _settings = const AppSettings(
    notificationsOn: true,
    twoFactorEnabled: false,
    language: AppLanguage.english,
    themeMode: AppThemeMode.system,
    contactEmail: 'support@spotnsend.com',
    appVersion: 'v1.0.0',
  );

  Future<AppSettings> get() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return _settings;
  }

  Future<Result<AppSettings>> update(AppSettings settings) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _settings = settings;
    return Success(_settings);
  }
}




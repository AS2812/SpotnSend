import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/data/models/settings_models.dart';
import 'package:spotnsend/data/services/settings_service.dart';

final settingsControllerProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SettingsController(service)..load();
});

class SettingsState {
  const SettingsState({required this.settings, this.isLoading = true});

  final AppSettings settings;
  final bool isLoading;

  ThemeMode get themeMode {
    switch (settings.themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Locale get locale => settings.locale;

  SettingsState copyWith({AppSettings? settings, bool? isLoading}) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this.service)
      : super(SettingsState(
          settings: const AppSettings(
            notificationsOn: true,
            twoFactorEnabled: false,
            language: AppLanguage.english,
            themeMode: AppThemeMode.system,
            contactEmail: 'support@spotnsend.com',
            appVersion: 'v1.0.0',
          ),
          isLoading: true,
        ));

  final SettingsService service;

  Future<void> load() async {
    final settings = await service.get();
    state = state.copyWith(settings: settings, isLoading: false);
  }

  Future<void> updateNotifications(bool value) async {
    final updated = state.settings.copyWith(notificationsOn: value);
    state = state.copyWith(settings: updated);
    await service.update(updated);
  }

  Future<void> updateTwoFactor(bool value) async {
    final updated = state.settings.copyWith(twoFactorEnabled: value);
    state = state.copyWith(settings: updated);
    await service.update(updated);
  }

  Future<void> updateLanguage(AppLanguage language) async {
    final updated = state.settings.copyWith(language: language);
    state = state.copyWith(settings: updated);
    await service.update(updated);
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    final updated = state.settings.copyWith(themeMode: mode);
    state = state.copyWith(settings: updated);
    await service.update(updated);
  }
}





